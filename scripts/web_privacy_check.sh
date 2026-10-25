#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "▶️  Testing browser save integrity and memory-only credentials"
cd app
pwd
flutter test --concurrency=1 test/browser_session_test.dart test/browser_ai_lifecycle_test.dart test/openrouter_client_test.dart
