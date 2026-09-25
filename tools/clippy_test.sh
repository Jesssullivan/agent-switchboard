#!/usr/bin/env bash
# Test carrier for //:clippy_lint. The work happens at build time: Bazel cannot
# run this test until every rust_clippy output has succeeded. Do not rediscover
# .clippy.ok marker files at runtime.
set -euo pipefail

if [[ "${1:-}" != "clippy-aspect-complete" ]]; then
  echo "Bazel clippy test carrier was invoked without its analysis token" >&2
  exit 1
fi
