-- Type of blahaj config/rustfs-iam/owners.json
-- (schema_id tinyland.blahaj.rustfs-bucket-iam.v1).
--
-- blahaj owns that file; this repo carries the type because TIN-5105 commissions
-- the agent-switchboard-tofu-state owner row in it (G4, G8; R-C196). The check
-- reads the JSON into this type with json-to-dhall (strict records, so an
-- unknown field fails) and renders it back with dhall-to-json; the two must be
-- equal after `jq -S`. Optional fields are omitted from the rendering when
-- None, which is how the JSON leaves them out. R-C229.
let Map = ./Map.dhall

let Consumer =
      { workload : Text
      , secret : Text
      , field_prefix : Optional Text
      , keys : List Text
      , note : Optional Text
      }

let Owner =
      { owner : Text
      , store : Text
      , buckets : List Text
      , iam_user : Text
      , iam_policy : Text
      , policy_document : Text
      , ceremony_secret : Text
      , consumers : List Consumer
      , cutover_order : Optional Natural
      , blast_radius : Text
      , status : Optional Text
      , consumer_probe_note : Optional Text
      , object_keys : Optional (Map Text (List Text))
      }

let Store =
      { kind : Text
      , node : Text
      , endpoint : Text
      , root_credential_secret : Text
      , root_credential_fields : { access : Text, secret : Text }
      , note : Optional Text
      , root_rotation_blockers : Optional (List Text)
      }

let UnmanagedBucket =
      { bucket : Text, store : Text, reason : Text, owner_repo : Text }

let RootCredentialCoupling =
      { secret : Text, fields : Map Text Text, observed : Text, hazard : Text }

let OutOfScopeStore =
      { store : Text
      , node : Text
      , reason : Text
      , out_of_scope_for : Text
      , in_scope_for : Text
      , root_credential_coupling : Optional RootCredentialCoupling
      }

in  { schema_id : Text
    , schema_version : Natural
    , authority_doc : Text
    , runbook : Text
    , ensure_script : Text
    , carrier_sweep_script : Text
    , scope :
        { statement : Text
        , not_a_generalized_primitive : Text
        , field_naming : Text
        , credential_handling : Text
        }
    , namespace : Text
    , stores : Map Text Store
    , iam_user_secret_field : Text
    , owners : List Owner
    , unmanaged_buckets : List UnmanagedBucket
    , out_of_scope_stores : List OutOfScopeStore
    }
