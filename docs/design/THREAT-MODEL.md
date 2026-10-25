# Static PWA threat model

| Boundary | Control and limitation |
|---|---|
| User credential | Memory-only key; never saved, cached, exported or embedded at build time. A compromised page/tab can still access its live memory. |
| Model text | Bounded transport, strict terminal states and existing dialogue validator before applying one deterministic turn. |
| Network | Direct HTTPS to OpenRouter; restrictive privacy routing, no silent fallback/replay, explicit user retry. |
| Public cache | Complete hashed same-origin resource allowlist; no API, authorization-bearing, query or mutation requests cached. |
| Local saves | Atomic snapshot with checksum/type/bounds/replay checks; corruption/conflicting tabs fail visibly. Local values are not multiplayer authority. |
| Same browser profile | Saves/transcripts are readable local data; export/delete controls, no claim of encryption or cloud recovery. |
| Updates and publication | Waiting worker preserves the running session; deployment is manual with owner-configured environment protection. |

The application accepts fictional game interaction, not real health information.
Browser storage can be cleared or evicted. Provider privacy options do not prove
external retention behavior. See [security](../../SECURITY.md),
[data lifecycle](../project/DATA-LIFECYCLE.md), and
[local acceptance evidence](../reports/2026-10-23-static-pwa.md).
