-- Type of docs/releases/approved-broker.json (schema swb.approved-release.v1).
--
-- scripts/release-check.py stays the verifier of what the values mean (source
-- ancestry, per-file sha256, OCI evidence). This type only fixes the shape, so
-- a missing, renamed or mistyped field fails `dhall type` before release-check
-- ever reads the file. SWB-R53, R-N13, R-C229.
let Map = ./Map.dhall

let Platform =
      { architecture : Text
      , cmd : List Text
      , entrypoint : List Text
      , os : Text
      , user : Text
      }

in  { file_sha256 : Map Text Text
    , image : Text
    , live_acceptance : Bool
    , manifest_size : Natural
    , platform : Platform
    , pr_heads : Map Text Text
    , publication_receipt : Text
    , qualification : Text
    , rulings : List Text
    , schema : Text
    , source : Text
    , source_inputs : List Text
    , upstream_main : Text
    }
