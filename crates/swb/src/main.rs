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
        Some("serve" | "agentd" | "whoami" | "inbox") => 3,
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
        Some(other @ ("serve" | "agentd" | "whoami" | "inbox")) => {
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
        assert_eq!(exit_status(Some("serve")), 3);
        assert_eq!(exit_status(None), 2);
    }
}
