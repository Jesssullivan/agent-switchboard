//! SQLite coordination state. Mutations and their receipts commit in one writer
//! transaction (SWB-R02, SWB-R09, SWB-R14, SWB-R46).

use hmac::{Hmac, Mac};
use rusqlite::{Connection, OptionalExtension, TransactionBehavior, params};
use serde_json::{Value, json};
use sha2::Sha256;
use std::path::Path;
use std::sync::Mutex;
use std::time::Duration;
use ulid::Ulid;

pub const RETENTION_ACKED_DAYS: u32 = 7;
pub const RETENTION_UNACKED_DAYS: u32 = 30;
pub const DEFAULT_TTL_HOURS: u32 = 72;
pub const MAX_TTL_DAYS: u32 = 14;

pub fn effective_ttl_hours(requested: Option<u32>) -> u32 {
    requested
        .unwrap_or(DEFAULT_TTL_HOURS)
        .clamp(1, MAX_TTL_DAYS * 24)
}

pub struct Store(Mutex<Connection>);
#[derive(Debug)]
pub struct SendOutcome {
    pub envelope: Value,
    pub created: bool,
}

fn field<'a>(v: &'a Value, key: &str) -> Result<&'a str, String> {
    v.get(key)
        .and_then(Value::as_str)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| format!("missing {key}"))
}
fn valid_agent_id(id: &str) -> bool {
    let parts: Vec<_> = id.split(':').collect();
    parts.len() == 4
        && matches!(
            parts[0],
            "claude" | "kimi" | "codex" | "junie" | "opencode" | "pi"
        )
        && !parts[1].is_empty()
        && parts[2].parse::<u32>().is_ok()
        && !parts[3].is_empty()
        && parts[1..].iter().all(|p| {
            p.chars()
                .all(|c| c.is_ascii_alphanumeric() || "._-".contains(c))
        })
}
fn valid_ulid(s: &str) -> bool {
    s.len() == 26 && s.parse::<Ulid>().is_ok_and(|id| id.to_string() == s)
}
fn clean(s: &str) -> String {
    s.chars().filter(|c| !c.is_control()).collect()
}
fn sql_err(e: rusqlite::Error) -> String {
    e.to_string()
}

impl Store {
    fn prune(&self) -> Result<(), String> {
        let db = self.0.lock().map_err(|_| "store lock poisoned")?;
        db.execute("DELETE FROM messages WHERE (state='acked' AND acked_at<=unixepoch()-604800) OR (state!='acked' AND created_at<=unixepoch()-2592000)", []).map_err(sql_err)?;
        Ok(())
    }
    pub fn open(path: impl AsRef<Path>) -> Result<Self, String> {
        let db = Connection::open(path).map_err(sql_err)?;
        Self::init(db)
    }
    pub fn memory() -> Result<Self, String> {
        Self::init(Connection::open_in_memory().map_err(sql_err)?)
    }
    fn init(db: Connection) -> Result<Self, String> {
        db.busy_timeout(Duration::from_secs(5)).map_err(sql_err)?;
        db.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON;
            CREATE TABLE IF NOT EXISTS sessions (
              agent_id TEXT PRIMARY KEY, harness TEXT NOT NULL, host TEXT NOT NULL,
              proc_start TEXT NOT NULL, last_seen INTEGER NOT NULL, ended INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS messages (
              msg_id TEXT PRIMARY KEY, thread_id TEXT NOT NULL, seq INTEGER NOT NULL,
              sender TEXT NOT NULL, recipient TEXT NOT NULL, body TEXT NOT NULL,
              envelope TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'queued',
              delivery_count INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL,
              expires_at INTEGER NOT NULL, acked_at INTEGER,
              UNIQUE(thread_id,seq));
            CREATE INDEX IF NOT EXISTS messages_inbox ON messages(recipient,state,created_at);
            CREATE TABLE IF NOT EXISTS counters (name TEXT PRIMARY KEY, value INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS settings (name TEXT PRIMARY KEY, value BLOB NOT NULL);").map_err(sql_err)?;
        let mut key = [0u8; 32];
        std::fs::File::open("/dev/urandom")
            .and_then(|mut f| std::io::Read::read_exact(&mut f, &mut key))
            .map_err(|e| format!("audit key generation: {e}"))?;
        db.execute(
            "INSERT OR IGNORE INTO settings(name,value) VALUES('audit_hmac_key',?1)",
            [&key[..]],
        )
        .map_err(sql_err)?;
        Ok(Self(Mutex::new(db)))
    }
    pub fn body_hmac(&self, body: &str) -> Result<String, String> {
        let db = self.0.lock().map_err(|_| "store lock poisoned")?;
        let key: Vec<u8> = db
            .query_row(
                "SELECT value FROM settings WHERE name='audit_hmac_key'",
                [],
                |r| r.get(0),
            )
            .map_err(sql_err)?;
        let mut mac = Hmac::<Sha256>::new_from_slice(&key).map_err(|e| e.to_string())?;
        mac.update(body.as_bytes());
        Ok(mac
            .finalize()
            .into_bytes()
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect())
    }
    pub fn register(&self, input: &Value) -> Result<Value, String> {
        let harness = field(input, "harness")?;
        if !matches!(
            harness,
            "claude" | "kimi" | "codex" | "junie" | "opencode" | "pi"
        ) {
            return Err("invalid harness".into());
        }
        let host = field(input, "host")?;
        let pid = input
            .get("pid")
            .and_then(Value::as_u64)
            .filter(|p| *p > 0)
            .ok_or("invalid pid")?;
        let session_id = field(input, "session_id")?;
        let proc_start = field(input, "proc_start")?;
        let id = format!("{harness}:{host}:{pid}:{session_id}");
        if !valid_agent_id(&id) {
            return Err("invalid agent id".into());
        }
        let db = self.0.lock().map_err(|_| "store lock poisoned")?;
        db.execute("INSERT INTO sessions(agent_id,harness,host,proc_start,last_seen) VALUES(?1,?2,?3,?4,unixepoch())
                    ON CONFLICT(agent_id) DO UPDATE SET proc_start=excluded.proc_start,last_seen=excluded.last_seen,ended=0",
            params![id,harness,host,proc_start]).map_err(sql_err)?;
        Ok(json!({"agent_id":id,"lease_seconds":900}))
    }
    pub fn peers(&self) -> Result<Value, String> {
        let db = self.0.lock().map_err(|_| "store lock poisoned")?;
        let mut stmt = db.prepare("SELECT agent_id,harness,host,proc_start,last_seen,ended FROM sessions ORDER BY agent_id").map_err(sql_err)?;
        let rows = stmt.query_map([], |r| {
            let seen: i64 = r.get(4)?; let ended: i64 = r.get(5)?;
            Ok(json!({"agent_id":r.get::<_,String>(0)?,"harness":r.get::<_,String>(1)?,"host":r.get::<_,String>(2)?,
                "proc_start":r.get::<_,String>(3)?,"last_seen":seen,
                "state":if ended != 0 {"ended"} else if seen >= now()-900 {"live"} else if seen >= now()-21600 {"idle"} else {"gone"}}))
        }).map_err(sql_err)?;
        rows.collect::<Result<Vec<_>, _>>()
            .map(|v| json!({"peers":v}))
            .map_err(sql_err)
    }
    pub fn send(&self, input: &Value) -> Result<SendOutcome, String> {
        self.prune()?;
        if let Some(id) = input
            .get("msg_id")
            .and_then(Value::as_str)
            .filter(|id| valid_ulid(id))
        {
            let db = self.0.lock().map_err(|_| "store lock poisoned")?;
            let stored: Option<(String, String, String)> = db
                .query_row(
                    "SELECT sender,body,envelope FROM messages WHERE msg_id=?1",
                    [id],
                    |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
                )
                .optional()
                .map_err(sql_err)?;
            if let Some((old_sender, old_body, envelope)) = stored {
                if input.get("from").and_then(Value::as_str) != Some(old_sender.as_str())
                    || input
                        .get("body")
                        .and_then(Value::as_str)
                        .map(clean)
                        .as_deref()
                        != Some(old_body.as_str())
                {
                    return Err("msg_id conflict".into());
                }
                return serde_json::from_str(&envelope)
                    .map(|envelope| SendOutcome {
                        envelope,
                        created: false,
                    })
                    .map_err(|e| e.to_string());
            }
        }
        let sender = field(input, "from")?;
        let recipient = field(input, "to")?;
        if !valid_agent_id(sender) || !valid_agent_id(recipient) {
            return Err("invalid agent id".into());
        }
        let body = clean(
            input
                .get("body")
                .and_then(Value::as_str)
                .ok_or("missing body")?,
        );
        if body.len() > 16384 {
            return Err("body exceeds 16 KiB".into());
        }
        let ticket = field(input, "ticket")?;
        if ticket != "none"
            && (!ticket.starts_with("TIN-")
                || !ticket[4..].chars().all(|c| c.is_ascii_digit())
                || ticket.len() == 4)
        {
            return Err("invalid ticket".into());
        }
        let directed = input
            .get("operator_directed")
            .and_then(Value::as_bool)
            .unwrap_or(false);
        if input
            .get("operator_directed")
            .is_some_and(|v| !v.is_boolean())
        {
            return Err("invalid operator_directed".into());
        }
        if directed
            && input
                .get("ruling")
                .and_then(Value::as_str)
                .filter(|s| !s.is_empty())
                .is_none()
        {
            return Err("operator_directed requires ruling".into());
        }
        if input
            .get("artifacts")
            .and_then(Value::as_array)
            .is_some_and(|v| v.len() > 20)
        {
            return Err("too many artifacts".into());
        }
        if let Some(artifacts) = input.get("artifacts") {
            let items = artifacts.as_array().ok_or("invalid artifacts")?;
            let mut seen = std::collections::HashSet::new();
            for item in items {
                let reference = item
                    .as_str()
                    .filter(|s| !s.is_empty() && s.len() <= 2048)
                    .ok_or("invalid artifact reference")?;
                if !seen.insert(reference) {
                    return Err("duplicate artifact reference".into());
                }
            }
        }
        if input
            .get("in_reply_to")
            .is_some_and(|v| !v.as_str().is_some_and(valid_ulid))
        {
            return Err("invalid in_reply_to".into());
        }
        for key in ["ruling", "reply_format"] {
            if input.get(key).is_some_and(|v| {
                !v.as_str()
                    .is_some_and(|s| s.len() <= 512 && !s.chars().any(char::is_control))
            }) {
                return Err(format!("invalid {key}"));
            }
        }
        let msg_id = input
            .get("msg_id")
            .and_then(Value::as_str)
            .map(str::to_owned)
            .unwrap_or_else(|| Ulid::new().to_string());
        let thread_id = input
            .get("thread_id")
            .and_then(Value::as_str)
            .map(str::to_owned)
            .unwrap_or_else(|| msg_id.clone());
        if !valid_ulid(&msg_id) || !valid_ulid(&thread_id) {
            return Err("invalid ULID".into());
        }
        let ttl = effective_ttl_hours(
            input
                .get("ttl_hours")
                .and_then(Value::as_u64)
                .map(|n| n.min(u32::MAX as u64) as u32),
        );
        let mut db = self.0.lock().map_err(|_| "store lock poisoned")?;
        let tx = db
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(sql_err)?;
        let old: Option<(String, String, String)> = tx
            .query_row(
                "SELECT sender,body,envelope FROM messages WHERE msg_id=?1",
                [&msg_id],
                |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
            )
            .optional()
            .map_err(sql_err)?;
        if let Some((old_sender, old_body, envelope)) = old {
            // SWB-R46: disclose neither the stored receipt nor its metadata on conflict.
            if old_sender != sender || old_body != body {
                return Err("msg_id conflict".into());
            }
            return serde_json::from_str(&envelope)
                .map(|envelope| SendOutcome {
                    envelope,
                    created: false,
                })
                .map_err(|e| e.to_string());
        }
        let seq: i64 = tx
            .query_row(
                "SELECT COALESCE(MAX(seq),0)+1 FROM messages WHERE thread_id=?1",
                [&thread_id],
                |r| r.get(0),
            )
            .map_err(sql_err)?;
        let mut envelope = input.clone();
        let map = envelope.as_object_mut().ok_or("expected object")?;
        map.insert("v".into(), json!(3));
        map.insert("msg_id".into(), json!(msg_id));
        map.insert("thread_id".into(), json!(thread_id));
        map.insert("seq".into(), json!(seq));
        map.insert("authority".into(), json!("peer"));
        map.insert("transport".into(), json!("broker"));
        map.insert("body".into(), json!(body));
        map.insert("operator_directed".into(), json!(directed));
        map.insert("reply_to".into(), json!(format!("ag:{sender}")));
        map.remove("ttl_hours");
        let sent_at: String = tx
            .query_row("SELECT strftime('%Y-%m-%dT%H:%M:%SZ','now')", [], |r| {
                r.get(0)
            })
            .map_err(sql_err)?;
        map.insert("sent_at".into(), json!(sent_at));
        let expires_at: String = tx
            .query_row(
                "SELECT strftime('%Y-%m-%dT%H:%M:%SZ','now',?1)",
                [format!("+{} seconds", i64::from(ttl) * 3600)],
                |r| r.get(0),
            )
            .map_err(sql_err)?;
        map.insert("expires_at".into(), json!(expires_at));
        tx.execute("INSERT INTO messages(msg_id,thread_id,seq,sender,recipient,body,envelope,created_at,expires_at)
                    VALUES(?1,?2,?3,?4,?5,?6,?7,unixepoch(),unixepoch()+?8)",
            params![msg_id,thread_id,seq,sender,recipient,body,envelope.to_string(),i64::from(ttl)*3600]).map_err(sql_err)?;
        tx.execute("INSERT INTO counters(name,value) VALUES('messages_total',1) ON CONFLICT(name) DO UPDATE SET value=value+1",[]).map_err(sql_err)?;
        tx.commit().map_err(sql_err)?;
        Ok(SendOutcome {
            envelope,
            created: true,
        })
    }
    pub fn inbox(&self, me: &str, limit: u32) -> Result<Value, String> {
        self.prune()?;
        if !valid_agent_id(me) {
            return Err("invalid agent id".into());
        }
        let mut db = self.0.lock().map_err(|_| "store lock poisoned")?;
        let tx = db
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .map_err(sql_err)?;
        tx.execute("UPDATE messages SET state='expired' WHERE state!='acked' AND state!='expired' AND expires_at<=unixepoch()",[]).map_err(sql_err)?;
        let messages: Vec<(String, String)> = {
            let mut stmt = tx.prepare("SELECT msg_id,envelope FROM messages WHERE recipient=?1 AND state IN ('queued','notified','fetched') ORDER BY created_at,seq LIMIT ?2").map_err(sql_err)?;
            let rows = stmt
                .query_map(params![me, limit.min(100)], |r| Ok((r.get(0)?, r.get(1)?)))
                .map_err(sql_err)?;
            rows.collect::<Result<_, _>>().map_err(sql_err)?
        };
        for (id, _) in &messages {
            tx.execute("UPDATE messages SET state='fetched',delivery_count=delivery_count+1 WHERE msg_id=?1",[id]).map_err(sql_err)?;
        }
        let values = messages
            .into_iter()
            .map(|(id, body)| {
                let mut v: Value = serde_json::from_str(&body).map_err(|e| e.to_string())?;
                let count: i64 = tx
                    .query_row(
                        "SELECT delivery_count FROM messages WHERE msg_id=?1",
                        [&id],
                        |r| r.get(0),
                    )
                    .map_err(sql_err)?;
                v["delivery_count"] = json!(count);
                Ok(v)
            })
            .collect::<Result<Vec<_>, String>>()?;
        tx.commit().map_err(sql_err)?;
        Ok(json!({"messages":values}))
    }
    pub fn ack(&self, me: &str, msg_id: &str) -> Result<Value, String> {
        if !valid_agent_id(me) || !valid_ulid(msg_id) {
            return Err("invalid identity or msg_id".into());
        }
        let db = self.0.lock().map_err(|_| "store lock poisoned")?;
        let n = db.execute("UPDATE messages SET state='acked',acked_at=unixepoch() WHERE msg_id=?1 AND recipient=?2 AND expires_at>unixepoch() AND state IN ('queued','notified','fetched')",params![msg_id,me]).map_err(sql_err)?;
        if n == 0 {
            let prior: Option<String> = db
                .query_row(
                    "SELECT state FROM messages WHERE msg_id=?1 AND recipient=?2",
                    params![msg_id, me],
                    |r| r.get(0),
                )
                .optional()
                .map_err(sql_err)?;
            if prior.as_deref() != Some("acked") {
                return Err("message unavailable".into());
            }
        }
        Ok(json!({"msg_id":msg_id,"state":"acked"}))
    }
    pub fn metrics(&self) -> Result<String, String> {
        let db = self.0.lock().map_err(|_| "store lock poisoned")?;
        let sent: i64 = db
            .query_row(
                "SELECT COALESCE(value,0) FROM counters WHERE name='messages_total'",
                [],
                |r| r.get(0),
            )
            .optional()
            .map_err(sql_err)?
            .unwrap_or(0);
        let unacked: i64 = db
            .query_row(
                "SELECT COUNT(*) FROM messages WHERE state NOT IN ('acked','expired')",
                [],
                |r| r.get(0),
            )
            .map_err(sql_err)?;
        let live: i64 = db
            .query_row(
                "SELECT COUNT(*) FROM sessions WHERE ended=0 AND last_seen>=unixepoch()-900",
                [],
                |r| r.get(0),
            )
            .map_err(sql_err)?;
        Ok(format!(
            "# TYPE swb_messages_total counter\nswb_messages_total {sent}\n# TYPE swb_mailbox_unacked gauge\nswb_mailbox_unacked {unacked}\n# TYPE swb_sessions gauge\nswb_sessions{{state=\"live\"}} {live}\n"
        ))
    }
}
fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |d| d.as_secs() as i64)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ttl_defaults_and_clamps() {
        assert_eq!(effective_ttl_hours(None), 72);
        assert_eq!(effective_ttl_hours(Some(10_000)), 336);
        assert_eq!(effective_ttl_hours(Some(0)), 1);
    }
    #[test]
    fn round_trip_and_opaque_conflict() {
        let s = Store::memory().unwrap();
        let me = "claude:honey:1:a";
        let to = "pi:sting:2:b";
        s.register(
            &json!({"harness":"claude","host":"honey","pid":1,"session_id":"a","proc_start":"1"}),
        )
        .unwrap();
        let input = json!({"from":me,"to":to,"ticket":"TIN-4655","body":"hello","msg_id":"01ARZ3NDEKTSV4RRFFQ69G5FAV"});
        let sent = s.send(&input).unwrap();
        assert_eq!(sent.envelope["authority"], "peer");
        assert!(sent.created);
        let retry = s.send(&input).unwrap();
        assert_eq!(retry.envelope["seq"], 1);
        assert!(!retry.created);
        let conflict=s.send(&json!({"from":me,"to":to,"ticket":"TIN-4655","body":"different","msg_id":"01ARZ3NDEKTSV4RRFFQ69G5FAV"})).unwrap_err();
        assert_eq!(conflict, "msg_id conflict");
        let got = s.inbox(to, 10).unwrap();
        assert_eq!(got["messages"][0]["delivery_count"], 1);
        assert_eq!(
            s.ack(to, "01ARZ3NDEKTSV4RRFFQ69G5FAV").unwrap()["state"],
            "acked"
        );
        assert!(
            s.inbox(to, 10).unwrap()["messages"]
                .as_array()
                .unwrap()
                .is_empty()
        );
    }
    #[test]
    fn wal_survives_reopen_and_sequences_thread() {
        let path = std::env::temp_dir().join(format!("swb-{}.sqlite3", Ulid::new()));
        let from = "claude:honey:1:a";
        let to = "pi:sting:2:b";
        let thread = "01ARZ3NDEKTSV4RRFFQ69G5FAV";
        {
            let s = Store::open(&path).unwrap();
            let mode: String =
                s.0.lock()
                    .unwrap()
                    .query_row("PRAGMA journal_mode", [], |r| r.get(0))
                    .unwrap();
            assert_eq!(mode, "wal");
            let first = s
                .send(
                    &json!({"from":from,"to":to,"ticket":"none","body":"first","thread_id":thread}),
                )
                .unwrap();
            assert_eq!(first.envelope["seq"], 1);
        }
        {
            let s = Store::open(&path).unwrap();
            let second = s.send(&json!({"from":from,"to":to,"ticket":"none","body":"second","thread_id":thread})).unwrap();
            assert_eq!(second.envelope["seq"], 2);
            assert_eq!(
                s.inbox(to, 10).unwrap()["messages"]
                    .as_array()
                    .unwrap()
                    .len(),
                2
            );
        }
        let _ = std::fs::remove_file(&path);
        let _ = std::fs::remove_file(format!("{}-wal", path.display()));
        let _ = std::fs::remove_file(format!("{}-shm", path.display()));
    }
}
