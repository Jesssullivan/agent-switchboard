//! Tailnet broker HTTP and MCP endpoint (SWB-R02, SWB-R14, SWB-R33, SWB-R46).
//! Audit output intentionally omits bodies until the live ACL and redaction
//! proof required by SWB-R33/34.

use serde_json::{Value, json};
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::Arc;
use swb_proto::Authority;
use swb_store::Store;

pub const HOOK_TIMEOUT_MS: u64 = 2_000;
pub fn stamped_authority() -> Authority {
    Authority::Peer
}

fn query(path: &str, key: &str) -> Option<String> {
    path.split('?').nth(1)?.split('&').find_map(|pair| {
        let (k, v) = pair.split_once('=')?;
        (k == key).then(|| percent_decode(v))
    })
}
fn percent_decode(value: &str) -> String {
    let mut bytes = Vec::new();
    let mut i = 0;
    let raw = value.as_bytes();
    while i < raw.len() {
        if raw[i] == b'%'
            && i + 2 < raw.len()
            && let (Some(a), Some(b)) = (
                (raw[i + 1] as char).to_digit(16),
                (raw[i + 2] as char).to_digit(16),
            )
        {
            bytes.push((a * 16 + b) as u8);
            i += 3;
            continue;
        }
        bytes.push(if raw[i] == b'+' { b' ' } else { raw[i] });
        i += 1;
    }
    String::from_utf8_lossy(&bytes).into_owned()
}
fn operation(store: &Store, name: &str, args: &Value) -> Result<Value, String> {
    let mut created = true;
    let result = match name {
        "register" => store.register(args),
        "peers" => store.peers(),
        "send" => {
            let outcome = store.send(args)?;
            created = outcome.created;
            Ok(outcome.envelope)
        }
        "inbox" => {
            let me = args.get("me").and_then(Value::as_str).ok_or("missing me")?;
            let limit = args
                .get("limit")
                .and_then(Value::as_u64)
                .unwrap_or(20)
                .min(100) as u32;
            let wait = args
                .get("wait_seconds")
                .and_then(Value::as_u64)
                .unwrap_or(0)
                .min(25);
            let deadline = std::time::Instant::now() + std::time::Duration::from_secs(wait);
            loop {
                let batch = store.inbox(me, limit)?;
                if batch["messages"].as_array().is_some_and(|v| !v.is_empty())
                    || std::time::Instant::now() >= deadline
                {
                    break Ok(batch);
                }
                std::thread::sleep(std::time::Duration::from_millis(250));
            }
        }
        "ack" => store.ack(
            args.get("me").and_then(Value::as_str).ok_or("missing me")?,
            args.get("msg_id")
                .and_then(Value::as_str)
                .ok_or("missing msg_id")?,
        ),
        _ => Err("unknown operation".into()),
    }?;
    if created && matches!(name, "register" | "send" | "ack") {
        // The body and stored receipt never enter stdout before SWB-R33/34 proof.
        let body = result.get("body").and_then(Value::as_str).unwrap_or("");
        let body_hmac = if name == "send" {
            Some(store.body_hmac(body)?)
        } else {
            None
        };
        println!(
            "{}",
            json!({"ts":std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map_or(0,|d|d.as_secs()),
                "op":name,"me":args.get("me").or_else(||args.get("from")),"to":result.get("to"),
                "ticket":result.get("ticket"),"ruling":result.get("ruling"),
                "msg_id":result.get("msg_id"),"size":body.len(),"body_hmac":body_hmac,
                "agent_id":result.get("agent_id"),"state":result.get("state")})
        );
    }
    Ok(result)
}
fn tools() -> Value {
    json!({"tools":[
        {"name":"register","description":"Register a self-asserted agent session","inputSchema":{"type":"object","required":["harness","host","pid","session_id","proc_start"]}},
        {"name":"peers","description":"List current broker session leases","inputSchema":{"type":"object"}},
        {"name":"send","description":"Send a peer-authority message","inputSchema":{"type":"object","required":["from","to","ticket","body"]}},
        {"name":"inbox","description":"Fetch unacked messages","inputSchema":{"type":"object","required":["me"]}},
        {"name":"ack","description":"Acknowledge a received message","inputSchema":{"type":"object","required":["me","msg_id"]}}
    ]})
}
fn mcp(store: &Store, request: &Value) -> Value {
    let id = request.get("id").cloned().unwrap_or(Value::Null);
    let method = request.get("method").and_then(Value::as_str).unwrap_or("");
    let result = match method {
        "initialize" => Ok(
            json!({"protocolVersion":"2025-03-26","capabilities":{"tools":{}},"serverInfo":{"name":"agent-switchboard","version":"0.1.0"}}),
        ),
        "ping" | "notifications/initialized" => Ok(json!({})),
        "tools/list" => Ok(tools()),
        "tools/call" => {
            let params = request.get("params").unwrap_or(&Value::Null);
            let name = params.get("name").and_then(Value::as_str).unwrap_or("");
            let args = params.get("arguments").unwrap_or(&Value::Null);
            operation(store, name, args).map(
                |v| json!({"content":[{"type":"text","text":v.to_string()}],"structuredContent":v}),
            )
        }
        _ => Err("unknown method".into()),
    };
    match result {
        Ok(v) => json!({"jsonrpc":"2.0","id":id,"result":v}),
        Err(e) => json!({"jsonrpc":"2.0","id":id,"error":{"code":-32602,"message":e}}),
    }
}
fn dispatch(
    store: &Store,
    method: &str,
    path: &str,
    body: &[u8],
    metrics_only: bool,
) -> (u16, &'static str, String) {
    if metrics_only {
        return if method == "GET" && path == "/metrics" {
            match store.metrics() {
                Ok(v) => (200, "text/plain; version=0.0.4", v),
                Err(e) => (500, "text/plain", e),
            }
        } else {
            (404, "text/plain", "not found".into())
        };
    }
    if method == "POST" && path == "/mcp" {
        return match serde_json::from_slice::<Value>(body) {
            Ok(v)
                if v.get("method").and_then(Value::as_str) == Some("notifications/initialized") =>
            {
                (202, "application/json", String::new())
            }
            Ok(v) => (200, "application/json", mcp(store, &v).to_string()),
            Err(_) => (
                400,
                "application/json",
                json!({"error":"invalid JSON"}).to_string(),
            ),
        };
    }
    let name = path
        .split('?')
        .next()
        .unwrap_or("")
        .strip_prefix("/v1/")
        .unwrap_or("");
    let args = if method == "GET" {
        json!({"me":query(path,"me"),"limit":query(path,"limit").and_then(|s|s.parse::<u64>().ok()),"wait_seconds":query(path,"wait_seconds").and_then(|s|s.parse::<u64>().ok())})
    } else {
        match serde_json::from_slice::<Value>(body) {
            Ok(v) => v,
            Err(_) => {
                return (
                    400,
                    "application/json",
                    json!({"error":"invalid JSON"}).to_string(),
                );
            }
        }
    };
    if (method == "POST" && matches!(name, "register" | "send" | "ack"))
        || (method == "GET" && matches!(name, "peers" | "inbox"))
    {
        match operation(store, name, &args) {
            Ok(v) => (200, "application/json", v.to_string()),
            Err(e) => (
                if e == "msg_id conflict" { 409 } else { 400 },
                "application/json",
                json!({"error":e}).to_string(),
            ),
        }
    } else {
        (
            404,
            "application/json",
            json!({"error":"not found"}).to_string(),
        )
    }
}
fn handle(mut stream: TcpStream, store: &Store, metrics_only: bool) -> std::io::Result<()> {
    stream.set_read_timeout(Some(std::time::Duration::from_secs(30)))?;
    let mut request = Vec::new();
    let mut buf = [0u8; 4096];
    let header_end = loop {
        let n = stream.read(&mut buf)?;
        if n == 0 {
            return Ok(());
        }
        request.extend_from_slice(&buf[..n]);
        if let Some(p) = request.windows(4).position(|w| w == b"\r\n\r\n") {
            break p + 4;
        }
        if request.len() > 65536 {
            return Ok(());
        }
    };
    let header = String::from_utf8_lossy(&request[..header_end]).into_owned();
    let mut lines = header.lines();
    let first = lines.next().unwrap_or("");
    let mut words = first.split_whitespace();
    let method = words.next().unwrap_or("");
    let path = words.next().unwrap_or("");
    let length = lines
        .filter_map(|line| line.split_once(':'))
        .find_map(|(k, v)| {
            k.eq_ignore_ascii_case("content-length")
                .then(|| v.trim().parse::<usize>().ok())
                .flatten()
        })
        .unwrap_or(0);
    if length > 65536 {
        return Ok(());
    }
    while request.len() - header_end < length {
        let n = stream.read(&mut buf)?;
        if n == 0 {
            return Ok(());
        }
        request.extend_from_slice(&buf[..n]);
    }
    let (status, kind, response) = dispatch(
        store,
        method,
        path,
        &request[header_end..header_end + length],
        metrics_only,
    );
    let reason = match status {
        200 => "OK",
        202 => "Accepted",
        400 => "Bad Request",
        404 => "Not Found",
        409 => "Conflict",
        _ => "Internal Server Error",
    };
    write!(
        stream,
        "HTTP/1.1 {status} {reason}\r\nContent-Type: {kind}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{response}",
        response.len()
    )?;
    stream.flush()
}
pub fn serve(store: Arc<Store>, listen: &str, metrics_listen: &str) -> std::io::Result<()> {
    let metrics = TcpListener::bind(metrics_listen)?;
    let main = TcpListener::bind(listen)?;
    let metric_store = Arc::clone(&store);
    std::thread::spawn(move || {
        for stream in metrics.incoming().flatten() {
            let s = Arc::clone(&metric_store);
            std::thread::spawn(move || {
                let _ = handle(stream, &s, true);
            });
        }
    });
    for stream in main.incoming().flatten() {
        let s = Arc::clone(&store);
        std::thread::spawn(move || {
            let _ = handle(stream, &s, false);
        });
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn broker_stamps_peer() {
        assert_eq!(stamped_authority(), Authority::Peer);
    }
    #[test]
    fn mcp_lists_five_tools() {
        let s = Store::memory().unwrap();
        let r = mcp(&s, &json!({"id":1,"method":"tools/list"}));
        assert_eq!(r["result"]["tools"].as_array().unwrap().len(), 5);
    }
    #[test]
    fn conflict_does_not_expose_receipt() {
        let s = Store::memory().unwrap();
        let msg = "01ARZ3NDEKTSV4RRFFQ69G5FAV";
        let a = json!({"from":"claude:honey:1:a","to":"pi:sting:2:b","body":"A","ticket":"none","msg_id":msg});
        s.send(&a).unwrap();
        let b = json!({"from":"claude:honey:1:a","to":"pi:sting:2:b","body":"B","ticket":"none","msg_id":msg});
        let (code, _, body) = dispatch(&s, "POST", "/v1/send", b.to_string().as_bytes(), false);
        assert_eq!(code, 409);
        assert_eq!(body, "{\"error\":\"msg_id conflict\"}");
    }
    #[test]
    fn http_mcp_initialize_round_trip() {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        let store = Arc::new(Store::memory().unwrap());
        let server = std::thread::spawn(move || {
            let (stream, _) = listener.accept().unwrap();
            handle(stream, &store, false).unwrap();
        });
        let body = json!({"jsonrpc":"2.0","id":7,"method":"initialize","params":{}}).to_string();
        let mut client = TcpStream::connect(address).unwrap();
        write!(
            client,
            "POST /mcp HTTP/1.1\r\nHost: localhost\r\nContent-Length: {}\r\n\r\n{body}",
            body.len()
        )
        .unwrap();
        client.flush().unwrap();
        let mut response = String::new();
        client.read_to_string(&mut response).unwrap();
        server.join().unwrap();
        assert!(response.starts_with("HTTP/1.1 200 OK"));
        let payload: Value =
            serde_json::from_str(response.split("\r\n\r\n").nth(1).unwrap()).unwrap();
        assert_eq!(payload["result"]["serverInfo"]["name"], "agent-switchboard");
    }
}
