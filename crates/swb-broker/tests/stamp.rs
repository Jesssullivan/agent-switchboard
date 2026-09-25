//! Cross-crate check: the broker's stamp serializes as the wire value the
//! envelope schema pins.

use swb_broker::stamped_authority;
use swb_proto::ENVELOPE_V3_SCHEMA;

#[test]
fn stamp_matches_schema_const() {
    let wire = serde_json::to_value(stamped_authority()).unwrap();
    let schema: serde_json::Value = serde_json::from_str(ENVELOPE_V3_SCHEMA).unwrap();
    assert_eq!(wire, schema["properties"]["authority"]["const"]);
}
