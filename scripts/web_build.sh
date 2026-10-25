#!/usr/bin/env bash
# Reproducible static-only production build; accepts no injected Dart secrets.
set -euo pipefail
PSY_WEB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PSY_WEB_ROOT"
pwd
test "$PWD" = "$PSY_WEB_ROOT"
if [ "$#" -ne 0 ]; then
  echo "web_build.sh accepts no arguments; domain/base path are reviewed source configuration." >&2
  exit 64
fi
flutter --version --machine | python3 -c 'import json,sys; actual=json.load(sys.stdin)["frameworkVersion"]; expected="3.38.5"; assert actual == expected, f"Flutter {expected} required, found {actual}"'
python3 scripts/web_finalize.py --clean
cd "$PSY_WEB_ROOT/app"
pwd
test "$PWD" = "$PSY_WEB_ROOT/app"
flutter pub get --enforce-lockfile
flutter build web --release --base-href / --pwa-strategy=none --no-web-resources-cdn
cd "$PSY_WEB_ROOT"
python3 scripts/web_finalize.py
