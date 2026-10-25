# Browser networking

The built app loads code, renderer, fonts and content from its own origin.
Its worker caches only the audited static resource inventory. Static-host
navigation uses `/#/...` fragments; no application server or route rewrite is
required. New AI content is the sole runtime external network dependency.

OpenRouter catalog refresh and completion happen only after explicit actions
while online. Catalog refresh intersects public, unauthenticated `/models` and
`/endpoints/zdr` results by exact model ID. A paid base model cannot authorize
its `:free` variant. Eligible endpoints must have zero prices, active status,
valid context/capabilities and provider tags. Completions use
the user's tab-memory key and a currently validated selected model. Neither
catalog nor completion is written to Cache Storage or the HTTP cache. Each
completion restricts `provider.only` to validated tags and requires `zdr:true`,
`data_collection:deny`, all-zero price caps and no provider fallback. Endpoint
availability can still change or be restricted by account policy. A 404/429
never relaxes these requirements or triggers automatic retry.

UTF-8/SSE parsing, request ownership, cancellation and separate first-output,
idle and total timeouts are bounded. An interrupted stream preserves partial
text and leaves the turn unapplied. Reconnect never resends. A retry is a new
explicit request; no automatic HTTP retry can silently duplicate usage.

Transport/provider errors are mapped to bounded user-safe messages without
request bodies or credentials. Offline practice, navigation and saved dialogue
continue locally. See [architecture](ARCHITECTURE.md) for exact limits and source
adaptations and [security](../../SECURITY.md) for the privacy boundary.
