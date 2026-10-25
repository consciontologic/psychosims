# Static Flutter web application

`lib/main.dart` starts `lib/browser/browser_app.dart`. The browser controller
reuses `psycore`, `psychemas`, configuration, dialogue validation and the original
Material/deep-purple style. `lib/shared/openrouter_client.dart` handles optional
online dialogue with a memory-only key. No native plugins, server, database,
account SDK or model download is in this package's dependency graph.

`lib/browser/browser_store.dart` defines the atomic local-save seam; the web
implementation uses localStorage. Full transcripts and deterministic replay data
are saved; credentials are excluded. Conflicting tabs and storage failure block
writes visibly. Navigation uses hash routes for static hosting.

Build and test from the repository root with `make verify`. Publish only
`app/build/web` after review. See [hosting](../docs/guides/STATIC_HOSTING.md) and
[architecture](../docs/code/ARCHITECTURE.md). Use `make web.serve` for the dedicated
`http://localhost:18763` preview. Retired native/server code and tests have been
removed under explicit user authorization; current core/app tests remain.
