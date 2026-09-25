//! Per-host push adapter for agent-switchboard (P1a stub).
//!
//! P2 runs `swb agentd` as a launchd agent (PZM, and neo per SWB-R17) or a
//! systemd user unit (honey, sting, bumble). It long-polls the broker and
//! writes a one-line, body-less notice to a verified Claude socket at most
//! once per [`NOTICE_MIN_INTERVAL_SECS`]. It never unlinks a socket and never
//! signals a process (R-N11).

/// Minimum spacing between notices to one session.
pub const NOTICE_MIN_INTERVAL_SECS: u64 = 60;

/// The notice text. It names the sender and ticket and never carries a body.
pub fn notice_line(unread: usize, from: &str, ticket: &str) -> String {
    format!("{unread} unread from {from} ({ticket}) - `ag inbox`")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn notice_is_one_line() {
        let line = notice_line(2, "codex:sting:4242:t1", "TIN-4655");
        assert_eq!(
            line,
            "2 unread from codex:sting:4242:t1 (TIN-4655) - `ag inbox`"
        );
        assert!(!line.contains('\n'));
    }
}
