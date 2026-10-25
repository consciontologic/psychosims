# Logging and diagnostics

The production game has no telemetry collector or application logging backend.
Diagnostics should record only bounded status categories, counts and timing when
needed for local troubleshooting. Never log API keys, authorization headers,
prompts, transcripts, saved payloads or raw provider errors.

The UI reports storage, connection, validation and stream failures visibly.
OpenRouter failures use safe messages; partial response text remains in the
player's local transcript controls, not an operational log. Automated browser
fixtures use synthetic dialogue and a fake credential and assert that the
credential never reaches storage or caches.

Build/test tools capture their output through the repository safe-run workflow.
Keep fixture and production data distinct; scrub confidential content before
sharing logs. The current source check `scripts/no_raw_print_check.sh` enforces
the repository's raw-print boundary. See [security](../../SECURITY.md).
