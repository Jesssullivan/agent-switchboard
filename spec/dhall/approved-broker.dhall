-- Source of docs/releases/approved-broker.json. `just spec-dhall` (and the
-- flake check spec-dhall) renders this with dhall-to-json and fails unless it
-- is identical, after `jq -S`, to the committed JSON. Edit this file and the
-- JSON together; release-check.py keeps reading the JSON. SWB-R55 (R-C304), R-C229.
let ApprovedRelease = ./ApprovedRelease.dhall

in    { file_sha256 =
          [ { mapKey = ".bazelversion", mapValue = "1b9487d55bea47fea50d226cc9c53bc548877ad2a318bac8fbc8b320f429e5c5" }
          , { mapKey = "BUILD.bazel", mapValue = "208faf29666f08fd4b43cda1d858ba8920d5fb1eede941acd1d0f680b69a2d01" }
          , { mapKey = "Cargo.lock", mapValue = "c9d9c3a37a176def430e08e58469c218f9e3f1f449aa7766917974f18c1b3be3" }
          , { mapKey = "Cargo.toml", mapValue = "11a870860a746873ee19745102bd337b484814019642a7aedc8a7d6a65d7580c" }
          , { mapKey = "MODULE.bazel", mapValue = "de0714afdd9380d66f028ab6dda42a520e83b86bb2d1960697ece9e28b5fd089" }
          , { mapKey = "MODULE.bazel.lock", mapValue = "f8f3d1035bb7a86e0823319b7c550a79320ec9c50da7127342069697210ba694" }
          , { mapKey = "cargo-bazel-lock.json", mapValue = "21d66a705743d5572f1e7492fae2f5bfd62f8fdeb6cb7bc335e4caea7f3482b6" }
          , { mapKey = "crates/swb-agentd/BUILD.bazel", mapValue = "4c53792c73662c8cf3737e36559acc042f53a28c4c5d638586e177df1f56adb7" }
          , { mapKey = "crates/swb-agentd/Cargo.toml", mapValue = "bd1e24061d70fa7e774eadcb87a83e81ff002e38c626603ba5d9e0462cfb0220" }
          , { mapKey = "crates/swb-agentd/src/lib.rs", mapValue = "03c8ff21db3b6556a4de5436ecf22589bf4ed43303cd6504b743394ad218bef7" }
          , { mapKey = "crates/swb-broker/BUILD.bazel", mapValue = "7bfc5fe7429424f4b9a9fd1c4a090854e78cdbf41a633d97bd61dddb3425accc" }
          , { mapKey = "crates/swb-broker/Cargo.toml", mapValue = "630fefce1b21b5b104f42c7a40bd36c6b965b8563be40ef37c75be69fca3531d" }
          , { mapKey = "crates/swb-broker/src/lib.rs", mapValue = "4de8d2d05e0ad3bc704094d234187367ce207403d2b225bae36f09172b767c8b" }
          , { mapKey = "crates/swb-broker/tests/stamp.rs", mapValue = "f07fa0a5d40fbb81aa4062354d87f3baf216aa03f66b15520ce0bb6897b117f3" }
          , { mapKey = "crates/swb-proto/BUILD.bazel", mapValue = "f886fc6c14a076e6f5996fb862f857e487454afcfe6271037988e52e03b35f1c" }
          , { mapKey = "crates/swb-proto/Cargo.toml", mapValue = "af016b200f0a54f49e374ad058825af9b79490b001af20e6136ab27d4f3fd4c3" }
          , { mapKey = "crates/swb-proto/src/lib.rs", mapValue = "6965fd48241e8a14969114a7154fcc984f562540f0229a36693b01d51a1cd1ec" }
          , { mapKey = "crates/swb-store/BUILD.bazel", mapValue = "f2c380aae0ff2697183171ceac6f3de5ddef63e4702899779e7a3829a7efa39d" }
          , { mapKey = "crates/swb-store/Cargo.toml", mapValue = "41e95b19c399e874202c2725a57425883381d96ac6e98072307702841fc0f437" }
          , { mapKey = "crates/swb-store/src/lib.rs", mapValue = "7614f3c91aa4201e16850817bda03963cf86ea067cf0302cbe4d581e961679fc" }
          , { mapKey = "crates/swb/BUILD.bazel", mapValue = "4f7172ae7cb74e41e8428679f0e14d82dd69176e40889b854e620857289b3fcc" }
          , { mapKey = "crates/swb/Cargo.toml", mapValue = "fa2aa8e137e6d904cc7dbc6f5c2cb79464ee4c71324eb8ee59dccbcd31f6a706" }
          , { mapKey = "crates/swb/src/main.rs", mapValue = "6598b460f13d8f7ec6a0aa6e4f860f9fac420db6e9038b757c714dda6ecde87e" }
          , { mapKey = "deploy/BUILD.bazel", mapValue = "3cd551dea3f25ba65dc536d1b0c0da05b4b40614f955fec7d26ef818abf9f9ae" }
          , { mapKey = "platforms/BUILD.bazel", mapValue = "6d5c7d3dada37113084e621e8065a05e4e58e0c7dd7d206dfd7f0cb3f4507d25" }
          , { mapKey = "tools/BUILD.bazel", mapValue = "d7ae7983138ad3c50004efd36fb29cac5583647b5dc3f46189f594f2470bd31c" }
          , { mapKey = "tools/clippy_test.sh", mapValue = "1a0c16f7e334bdfae84d8f25dab84cc2dfb45a8adcd95189e0d9662d10559261" }
          ]
      , image = "ghcr.io/xoxd-ai/agent-switchboard@sha256:c9170c7121821322376c16230f3b0eb5f10001aebfbce7e83c20c4afa5dd2236"
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
          [ { mapKey = "13", mapValue = "14dbb1c5ed21bdaba69a8f9b5c8d52c1a7621794" }
          , { mapKey = "16", mapValue = "7da91df3c8192c1fc4bb97d8a4316e152277e58b" }
          , { mapKey = "18", mapValue = "c08ce908974ded2b9917305252f5c18260babe52" }
          ]
      , publication_receipt =
          "PENDING: v0.1.0 release workflow registry readback; ratified R-C304, TIN-4655 comment dcb5b687-dd58-4577-b609-dcb20251941b"
      , qualification = "published-candidate-only"
      , rulings = [ "SWB-R55", "R-C304", "R-N13" ]
      , schema = "swb.approved-release.v1"
      , source = "d8ebfdbf4e7c52ba43a05c2d5c3f4cca520c18e9"
      , source_inputs =
          [ ".bazelversion", "BUILD.bazel", "MODULE.bazel", "MODULE.bazel.lock", "Cargo.toml", "Cargo.lock", "cargo-bazel-lock.json", "crates/", "deploy/", "platforms/", "tools/" ]
      , upstream_main = "2e41db951a182a89e5b927336237ac6edc562d57"
      }
    : ApprovedRelease
