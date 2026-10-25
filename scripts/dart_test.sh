#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶️  Dart tests"
if [[ $# -ne 0 ]]; then
  echo "usage: $0" >&2
  exit 64
fi

for pkg in config packages/psychemas packages/psycore tools; do
  echo "  • $pkg"
  (cd "$pkg" && dart pub get --enforce-lockfile && dart test)
done

echo "  • trusted outcome source and fixture consistency"
(cd tools && dart run compile_outcomes.dart \
  --spec ../test_fixtures/outcomes/build_spec.json \
  --out ../test_fixtures/outcomes/trusted_catalog_v1.json --check)

if command -v flutter >/dev/null 2>&1; then
  echo "  • app"
  (cd app && pwd && flutter pub get --enforce-lockfile && flutter test)
else
  echo "❌ flutter is required for the full Dart/app test gate" >&2
  exit 127
fi

echo "✅ Dart tests passed"
