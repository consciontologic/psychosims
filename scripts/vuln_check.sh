#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Vulnerability check"

bash scripts/sbom.sh
python3 scripts/dependency_scan.py

echo "✅ Vulnerability check passed"
