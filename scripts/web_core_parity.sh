#!/usr/bin/env bash
set -euo pipefail
PSY_PARITY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p /tmp/agent-runs
PSY_PARITY_DIR="$(mktemp -d /tmp/agent-runs/psychosims-parity-XXXXXX)"
cd "$PSY_PARITY_ROOT/tools"
pwd
dart run web_core_parity.dart > "$PSY_PARITY_DIR/native.json"
cmp "$PSY_PARITY_ROOT/test_fixtures/web_core_parity.json" "$PSY_PARITY_DIR/native.json"
pwd
dart compile js -O2 web_core_parity.dart -o "$PSY_PARITY_DIR/core.js"
node "$PSY_PARITY_DIR/core.js" > "$PSY_PARITY_DIR/javascript.json"
cmp "$PSY_PARITY_DIR/native.json" "$PSY_PARITY_DIR/javascript.json"
pwd
dart run web_core_boundary.dart
pwd
dart compile js -O2 web_core_boundary.dart -o "$PSY_PARITY_DIR/boundary.js"
node "$PSY_PARITY_DIR/boundary.js"
echo "Exact native / JavaScript core parity passed; evidence: $PSY_PARITY_DIR"
