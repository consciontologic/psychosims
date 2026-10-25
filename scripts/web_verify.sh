#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
pwd
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --tests-only ) ]]; then
  echo 'Usage: scripts/web_verify.sh [--tests-only]' >&2
  exit 64
fi
# Current product gate: browser runtime, shared mechanics and static assets.
for pkg in config packages/psychemas packages/psycore tools; do
  (
    cd "$pkg"
    pwd
    dart pub get --enforce-lockfile
    pwd
    dart test
    if [[ $# -eq 0 ]]; then
      pwd
      dart analyze --fatal-infos
    fi
  )
done
(
  cd app
  pwd
  flutter pub get --enforce-lockfile
  tests=(test/browser_session_test.dart test/browser_ai_lifecycle_test.dart test/browser_widget_test.dart test/browser_theme_test.dart test/openrouter*_test.dart test/dialogue_sanitizer_test.dart)
  pwd
  flutter test "${tests[@]}"
  if [[ $# -eq 0 ]]; then
    pwd
    flutter analyze --fatal-infos
  fi
)
pwd
node --test scripts/web_service_worker_test.mjs
pwd
python3 -m unittest discover -s scripts -p 'web_*_test.py'
pwd
python3 -m unittest xops.test.test_bootstrap_hooks xops.test.test_project_gates
scripts/web_core_parity.sh
scripts/no_raw_print_check.sh
scripts/env_read_check.sh
scripts/check_hardcoded_strings.sh
scripts/core_purity_gate.sh
scripts/content_integrity_check.sh
if [[ $# -eq 0 ]]; then
  pwd
  dart format --output=none --set-exit-if-changed config packages app tools
  scripts/web_build.sh
fi
