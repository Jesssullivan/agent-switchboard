//! `swb`, the agent-switchboard binary (P1a stub).
//!
//! One binary: `swb serve | agentd | hook <harness> | whoami | inbox`.
//! Only `version` works in P1a; the rest land in P1b and P2.

use std::process::ExitCode;

const USAGE: &str = "usage: swb <serve|agentd|hook <harness>|whoami|inbox|version>";

/// Exit status for a subcommand. `hook` always exits 0, so a missing or down
/// broker never blocks a harness (ADR-0001, SWB-R10).
fn exit_status(subcommand: Option<&str>) -> u8 {
    match subcommand {
        Some("hook" | "version") => 0,
        Some("agentd" | "whoami" | "inbox") => 3,
        Some("serve") => 0,
        _ => 2,
    }
}

fn main() -> ExitCode {
    let subcommand = std::env::args().nth(1);
    match subcommand.as_deref() {
        Some("version") => println!(
            "swb (agent-switchboard) P1a scaffold, envelope v{}, retention {}d acked / {}d unacked, authority {:?}, notice spacing {}s, hook timeout {}ms",
            swb_proto::ENVELOPE_VERSION,
            swb_store::RETENTION_ACKED_DAYS,
            swb_store::RETENTION_UNACKED_DAYS,
            swb_broker::stamped_authority(),
            swb_agentd::NOTICE_MIN_INTERVAL_SECS,
            swb_broker::HOOK_TIMEOUT_MS,
        ),
        Some("hook") => {}
        Some("serve") => {
            let path =
                std::env::var("SWB_DB_PATH").unwrap_or_else(|_| "/var/lib/swb/swb.sqlite3".into());
            let listen = std::env::var("SWB_LISTEN").unwrap_or_else(|_| "0.0.0.0:8080".into());
            let metrics =
                std::env::var("SWB_METRICS_LISTEN").unwrap_or_else(|_| "0.0.0.0:9090".into());
            let store = swb_store::Store::open(&path).unwrap_or_else(|e| {
                eprintln!("store: {e}");
                std::process::exit(1)
            });
            let runtime = tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()
                .unwrap_or_else(|e| {
                    eprintln!("runtime: {e}");
                    std::process::exit(1)
                });
            if let Err(e) = runtime.block_on(swb_broker::serve(
                std::sync::Arc::new(store),
                &listen,
                &metrics,
            )) {
                eprintln!("serve: {e}");
                return ExitCode::FAILURE;
            }
        }
        Some(other @ ("agentd" | "whoami" | "inbox")) => {
            eprintln!("swb {other}: not implemented until P1b/P2");
        }
        _ => eprintln!("{USAGE}"),
    }
    ExitCode::from(exit_status(subcommand.as_deref()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hook_never_blocks() {
        assert_eq!(exit_status(Some("hook")), 0);
        assert_eq!(exit_status(Some("serve")), 0);
        assert_eq!(exit_status(None), 2);
    }
}
