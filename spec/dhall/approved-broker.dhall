-- Source of docs/releases/approved-broker.json. `just spec-dhall` (and the
-- flake check spec-dhall) renders this with dhall-to-json and fails unless it
-- is identical, after `jq -S`, to the committed JSON. Edit this file and the
-- JSON together; release-check.py keeps reading the JSON. SWB-R53, R-C229.
let ApprovedRelease = ./ApprovedRelease.dhall

in    { file_sha256 =
          [ { mapKey = ".bazelversion", mapValue = "1b9487d55bea47fea50d226cc9c53bc548877ad2a318bac8fbc8b320f429e5c5" }
          , { mapKey = "BUILD.bazel", mapValue = "d5890443842586e8be7be2dae6dbf015b9f1584edc4ffc9695438a5e3e8e7555" }
          , { mapKey = "Cargo.lock", mapValue = "c9d9c3a37a176def430e08e58469c218f9e3f1f449aa7766917974f18c1b3be3" }
          , { mapKey = "Cargo.toml", mapValue = "11a870860a746873ee19745102bd337b484814019642a7aedc8a7d6a65d7580c" }
          , { mapKey = "MODULE.bazel", mapValue = "de0714afdd9380d66f028ab6dda42a520e83b86bb2d1960697ece9e28b5fd089" }
          , { mapKey = "MODULE.bazel.lock", mapValue = "f8f3d1035bb7a86e0823319b7c550a79320ec9c50da7127342069697210ba694" }
          , { mapKey = "cargo-bazel-lock.json", mapValue = "21d66a705743d5572f1e7492fae2f5bfd62f8fdeb6cb7bc335e4caea7f3482b6" }
          , { mapKey = "crates/swb-agentd/BUILD.bazel", mapValue = "4c53792c73662c8cf3737e36559acc042f53a28c4c5d638586e177df1f56adb7" }
          , { mapKey = "crates/swb-agentd/Cargo.toml", mapValue = "bd1e24061d70fa7e774eadcb87a83e81ff002e38c626603ba5d9e0462cfb0220" }
          , { mapKey = "crates/swb-agentd/src/lib.rs", mapValue = "03c8ff21db3b6556a4de5436ecf22589bf4ed43303cd6504b743394ad218bef7" }
          , { mapKey = "crates/swb-broker/BUILD.bazel", mapValue = "cdeb7daf7282d265d25e3bffa7318b282e9de55af48aab74cb552b26d487d18b" }
          , { mapKey = "crates/swb-broker/Cargo.toml", mapValue = "8a7b086f8bbe7b2df9003c66ff9542a355c8122d72c3511ab3065361fd587121" }
          , { mapKey = "crates/swb-broker/src/lib.rs", mapValue = "273fa3daf9831d59d29f8292d1be5a0beb263d483b81299ca0b65088bac0c4e0" }
          , { mapKey = "crates/swb-broker/tests/stamp.rs", mapValue = "f07fa0a5d40fbb81aa4062354d87f3baf216aa03f66b15520ce0bb6897b117f3" }
          , { mapKey = "crates/swb-proto/BUILD.bazel", mapValue = "f886fc6c14a076e6f5996fb862f857e487454afcfe6271037988e52e03b35f1c" }
          , { mapKey = "crates/swb-proto/Cargo.toml", mapValue = "af016b200f0a54f49e374ad058825af9b79490b001af20e6136ab27d4f3fd4c3" }
          , { mapKey = "crates/swb-proto/src/lib.rs", mapValue = "6965fd48241e8a14969114a7154fcc984f562540f0229a36693b01d51a1cd1ec" }
          , { mapKey = "crates/swb-store/BUILD.bazel", mapValue = "f2c380aae0ff2697183171ceac6f3de5ddef63e4702899779e7a3829a7efa39d" }
          , { mapKey = "crates/swb-store/Cargo.toml", mapValue = "41e95b19c399e874202c2725a57425883381d96ac6e98072307702841fc0f437" }
          , { mapKey = "crates/swb-store/src/lib.rs", mapValue = "b32c37a5ad5969a2aa10c3c6196a7a5c5d8eceafad94d5dc4c9ca7c35a55441c" }
          , { mapKey = "crates/swb/BUILD.bazel", mapValue = "0e202a298520f8ef76c317de17a2f0f1257ba0ec08ec5fad6f1b907ffc1b74ed" }
          , { mapKey = "crates/swb/Cargo.toml", mapValue = "713e12dab3f38c95bb605d8a74978f99ce2be9f04556b9fc3cdd49216fcbaca5" }
          , { mapKey = "crates/swb/src/main.rs", mapValue = "ff484d315f9583ad1161a6203970e47bc06ac38fe08f890c886b72d2210541df" }
          , { mapKey = "deploy/BUILD.bazel", mapValue = "8a8b01e2d5113baf3cbbb6778b395aaaa27d71820eafed09b233fe06684027dc" }
          , { mapKey = "platforms/BUILD.bazel", mapValue = "6d5c7d3dada37113084e621e8065a05e4e58e0c7dd7d206dfd7f0cb3f4507d25" }
          , { mapKey = "tools/BUILD.bazel", mapValue = "d7ae7983138ad3c50004efd36fb29cac5583647b5dc3f46189f594f2470bd31c" }
          , { mapKey = "tools/clippy_test.sh", mapValue = "1a0c16f7e334bdfae84d8f25dab84cc2dfb45a8adcd95189e0d9662d10559261" }
          ]
      , image = "ghcr.io/xoxd-ai/agent-switchboard@sha256:b0633ecbcd28d42607f2888990a1e583e0d99c3a2b516f4af0c31afe898c6309"
      , live_acceptance = False
      , manifest_size = 4579
      , platform =
        { architecture = "amd64"
        , cmd = [ "serve" ]
        , entrypoint = [ "/usr/local/bin/swb" ]
        , os = "linux"
        , user = "65532"
        }
      , pr_heads =
          [ { mapKey = "2", mapValue = "12dd8637ef8c12888154c708b520009b94572a17" }
          , { mapKey = "3", mapValue = "db3d966c37abb99107191e0740043dab72771123" }
          , { mapKey = "4", mapValue = "5211eacd65087df1dcb750d72788a027240e88f1" }
          , { mapKey = "5", mapValue = "330d949beb16fad598a3fce6b08daba66816156f" }
          ]
      , publication_receipt =
          "https://linear.app/tinyland/issue/TIN-4655#comment-f1b8ebd7-dd58-4577-b609-dcb20251941b"
      , qualification = "published-candidate-only"
      , rulings = [ "SWB-R53", "R-N13" ]
      , schema = "swb.approved-release.v1"
      , source = "b5158729355e836a3a98ade90d7649690e7a6900"
      , source_inputs =
          [ ".bazelversion", "BUILD.bazel", "MODULE.bazel", "MODULE.bazel.lock", "Cargo.toml", "Cargo.lock", "cargo-bazel-lock.json", "crates/", "deploy/", "platforms/", "tools/" ]
      , upstream_main = "2a11acb2988a88ff0c5a6b6a7040487c6d55df0b"
      }
    : ApprovedRelease
