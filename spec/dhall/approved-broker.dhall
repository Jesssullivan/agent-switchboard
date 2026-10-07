-- Source of docs/releases/approved-broker.json. `just spec-dhall` (and the
-- flake check spec-dhall) renders this with dhall-to-json and fails unless it
-- is identical, after `jq -S`, to the committed JSON. Edit this file and the
-- JSON together; release-check.py keeps reading the JSON. SWB-R57 (R-C411), R-C229.
let ApprovedRelease = ./ApprovedRelease.dhall

in    { file_sha256 =
          [ { mapKey = ".bazelversion", mapValue = "1b9487d55bea47fea50d226cc9c53bc548877ad2a318bac8fbc8b320f429e5c5" }
          , { mapKey = "BUILD.bazel", mapValue = "208faf29666f08fd4b43cda1d858ba8920d5fb1eede941acd1d0f680b69a2d01" }
          , { mapKey = "Cargo.lock", mapValue = "48feda0978d1982d72090cb2b1f201a17d5e73814c60f401bf2f318413752d66" }
          , { mapKey = "Cargo.toml", mapValue = "396952aa0065d3c7901942dcc6d1b9122235f86030e4480dad3f5b0a07e610e8" }
          , { mapKey = "MODULE.bazel", mapValue = "35135ac0bca7d6d1a66d17fa62e3bc021b3d0eb9014712b864121892974765fe" }
          , { mapKey = "MODULE.bazel.lock", mapValue = "f8f3d1035bb7a86e0823319b7c550a79320ec9c50da7127342069697210ba694" }
          , { mapKey = "cargo-bazel-lock.json", mapValue = "a2c491898792d731cbf2947019c54171fc2a1c42fed1fd5c5986e7f87b29db40" }
          , { mapKey = "crates/swb-agentd/BUILD.bazel", mapValue = "4c53792c73662c8cf3737e36559acc042f53a28c4c5d638586e177df1f56adb7" }
          , { mapKey = "crates/swb-agentd/Cargo.toml", mapValue = "bd1e24061d70fa7e774eadcb87a83e81ff002e38c626603ba5d9e0462cfb0220" }
          , { mapKey = "crates/swb-agentd/src/lib.rs", mapValue = "03c8ff21db3b6556a4de5436ecf22589bf4ed43303cd6504b743394ad218bef7" }
          , { mapKey = "crates/swb-broker/BUILD.bazel", mapValue = "7bfc5fe7429424f4b9a9fd1c4a090854e78cdbf41a633d97bd61dddb3425accc" }
          , { mapKey = "crates/swb-broker/Cargo.toml", mapValue = "630fefce1b21b5b104f42c7a40bd36c6b965b8563be40ef37c75be69fca3531d" }
          , { mapKey = "crates/swb-broker/src/lib.rs", mapValue = "a584c6e62689188c698e7f194dff6efe0bb28feda8bc92ea8f7c271e038e8bae" }
          , { mapKey = "crates/swb-broker/tests/stamp.rs", mapValue = "f07fa0a5d40fbb81aa4062354d87f3baf216aa03f66b15520ce0bb6897b117f3" }
          , { mapKey = "crates/swb-proto/BUILD.bazel", mapValue = "f886fc6c14a076e6f5996fb862f857e487454afcfe6271037988e52e03b35f1c" }
          , { mapKey = "crates/swb-proto/Cargo.toml", mapValue = "af016b200f0a54f49e374ad058825af9b79490b001af20e6136ab27d4f3fd4c3" }
          , { mapKey = "crates/swb-proto/src/lib.rs", mapValue = "6965fd48241e8a14969114a7154fcc984f562540f0229a36693b01d51a1cd1ec" }
          , { mapKey = "crates/swb-store/BUILD.bazel", mapValue = "f2c380aae0ff2697183171ceac6f3de5ddef63e4702899779e7a3829a7efa39d" }
          , { mapKey = "crates/swb-store/Cargo.toml", mapValue = "41e95b19c399e874202c2725a57425883381d96ac6e98072307702841fc0f437" }
          , { mapKey = "crates/swb-store/src/lib.rs", mapValue = "7614f3c91aa4201e16850817bda03963cf86ea067cf0302cbe4d581e961679fc" }
          , { mapKey = "crates/swb/BUILD.bazel", mapValue = "6eba47ac963e621f40a16d1327996021574cda3bddb592d1f38150c6af408215" }
          , { mapKey = "crates/swb/Cargo.toml", mapValue = "601bbc80f9ec9f76ee0be84a6ea6e8b264a291a1563b37910cd0f7c5fdf46cb1" }
          , { mapKey = "crates/swb/src/channel.rs", mapValue = "311e3e792cea8a8e28074f3ca765355ea5c94311d140e5f17c69e9bbe02dad16" }
          , { mapKey = "crates/swb/src/main.rs", mapValue = "2df1b56657e699fbef871e59ed7265b1380ea5bd19082a964d80d62eed0c39c1" }
          , { mapKey = "deploy/BUILD.bazel", mapValue = "3cd551dea3f25ba65dc536d1b0c0da05b4b40614f955fec7d26ef818abf9f9ae" }
          , { mapKey = "platforms/BUILD.bazel", mapValue = "6d5c7d3dada37113084e621e8065a05e4e58e0c7dd7d206dfd7f0cb3f4507d25" }
          , { mapKey = "tools/BUILD.bazel", mapValue = "d7ae7983138ad3c50004efd36fb29cac5583647b5dc3f46189f594f2470bd31c" }
          , { mapKey = "tools/clippy_test.sh", mapValue = "1a0c16f7e334bdfae84d8f25dab84cc2dfb45a8adcd95189e0d9662d10559261" }
          ]
      , image = "ghcr.io/xoxd-ai/agent-switchboard@sha256:66e439667c25791002e6af86d3bf088c5cbe5b35021874437fd9e1b202284555"
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
          [ { mapKey = "23", mapValue = "efceed56f2b191cfee919788309360f6fe18a9aa" }
          ]
      , publication_receipt =
          "PENDING: v0.2.0 release workflow registry readback; ratified R-C411, TIN-5770 comment cdeb84f6-d8a4-4d17-a3ca-72aee9b02014"
      , qualification = "published-candidate-only"
      , rulings = [ "SWB-R57", "R-C411", "R-N13" ]
      , schema = "swb.approved-release.v1"
      , source = "26f38b9ac4652866ea30d6553bac2374f7494e4d"
      , source_inputs =
          [ ".bazelversion", "BUILD.bazel", "MODULE.bazel", "MODULE.bazel.lock", "Cargo.toml", "Cargo.lock", "cargo-bazel-lock.json", "crates/", "deploy/", "platforms/", "tools/" ]
      , upstream_main = "4854872f0852482170b532b063d03166967681ac"
      }
    : ApprovedRelease
