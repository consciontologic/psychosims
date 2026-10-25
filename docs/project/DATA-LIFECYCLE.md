# Browser data lifecycle

The current application has no account service or server-side game database.
Data is scoped to the browser profile and origin. `localhost:18763`,
`psychosim.com`, and another hostname or port each have separate saves/caches.

| Data | Location and lifetime |
|---|---|
| API key and validated model authorization | Tab memory only; forgotten on reload or explicit key removal. |
| State, loadout, career, transcripts, partial attempts and completed sessions | One localStorage snapshot, retained until the user deletes site data or the browser clears/evicts it. |
| Exported save | User-downloaded JSON, without credentials; managed by the user. |
| App code, fonts, icons, renderer and scenario assets | Versioned Cache Storage inventory; previous versions removed during activation of a complete update. |
| Fictional prompt and relevant dialogue | Sent to OpenRouter only for a deliberate online AI action; provider policy is external to browser storage. |

Saves are unencrypted browser data, not a secret vault. A person using the same
profile can read them. Avoid real personal or health information. Privacy routing
requests no provider collection or retention; that request does not independently
verify a provider's compliance.

A snapshot is validated for version, checksum, types, bounds and deterministic
replay before restore. Corrupt, unavailable or full storage produces a visible
recovery state rather than overwriting the previous save. Concurrent tabs detect
changed data and require an explicit load-latest action. Keys never enter saved
snapshots, exported JSON, logs or the service worker cache.

Settings provides export and confirmed local deletion. Browser site-data controls
can remove both saves and caches. Export important progress before clearing data;
there is no cloud backup or account-based restore. Cache upgrades preserve saves.
The current regression suites and offline browser acceptance are recorded in the
[PWA report](../reports/2026-10-23-static-pwa.md).
