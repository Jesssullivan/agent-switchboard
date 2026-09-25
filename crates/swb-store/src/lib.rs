//! Coordination store for agent-switchboard (P1a stub).
//!
//! P1b backs this with SQLite (WAL, `synchronous=FULL`, one writer) on a PVC.
//! It holds coordination state only; findings stay in repo notes or Linear.
//! The retention and TTL values below are ruled (ADR-0001, SWB-R09).

/// Acked messages are kept this many days.
pub const RETENTION_ACKED_DAYS: u32 = 7;

/// Unacked messages are kept this many days.
pub const RETENTION_UNACKED_DAYS: u32 = 30;

/// Default message TTL, in hours.
pub const DEFAULT_TTL_HOURS: u32 = 72;

/// Longest TTL a sender may request, in days.
pub const MAX_TTL_DAYS: u32 = 14;

/// The TTL the store applies: the default when none is requested, clamped to
/// the ruled maximum otherwise.
pub fn effective_ttl_hours(requested: Option<u32>) -> u32 {
    requested
        .unwrap_or(DEFAULT_TTL_HOURS)
        .clamp(1, MAX_TTL_DAYS * 24)
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
}
