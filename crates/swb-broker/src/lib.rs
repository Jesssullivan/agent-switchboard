//! The agent-switchboard broker (P1a stub).
//!
//! P1b serves `:8080/mcp` (rmcp Streamable HTTP), a REST twin `/v1/*` for
//! hooks, and `:9090/metrics`. No tool acts on a process, a tmux pane or
//! another session's claim (R-N11).

use swb_proto::Authority;

/// Hooks give up after this long and exit 0; a down broker never blocks a
/// harness (ADR-0001, SWB-R10).
pub const HOOK_TIMEOUT_MS: u64 = 2_000;

/// The authority the broker writes on every message, whatever the sender sent.
pub fn stamped_authority() -> Authority {
    Authority::Peer
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn broker_stamps_peer() {
        assert_eq!(stamped_authority(), Authority::Peer);
    }
}
