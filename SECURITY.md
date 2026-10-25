# Security policy

## Current static PWA boundary (2026-10-23)

The release artifact contains only static public files. There is no application
backend, database, account login, server-held credential, receipt endpoint or
native inference engine. Local career data is editable by its owner; it provides
no shared economy or cross-player certification.

OpenRouter is the only AI network destination. The user enters their own key in
the app; it lives only in tab memory, is never a build/deployment secret, and is
forgotten on reload. Never log credentials, request bodies or raw provider errors.
The catalog is validated before selection. Provider routing uses restrictive
privacy options; lack of a compatible provider is a visible failure, not a reason
to relax privacy or silently select another model. The external provider receives
the fictional scenario and relevant conversation for each explicit AI request.

AI text is untrusted. Existing prompt/output constraints remain in force; core
rules alone compute outcomes. Streaming has explicit terminal/error/cancel states,
bounded timeouts and preserved partial output. Reconnection does not resend a
request. A retry is a new deliberate API request and may incur provider usage.

Saved game state and transcripts are browser-local **unencrypted** data. They are not sent to a Psychosims server. Anyone
using the same browser profile can read them. Do not enter real personal or health
information. Browser clearing/eviction can remove data; use the app's local data
controls and browser site-data settings. Exported saves never include API keys.
The PWA worker caches only its generated same-origin static resource inventory;
API calls, authorization-bearing requests and non-static URLs are excluded.

## Gates and release limits

`make verify` checks current browser/core behavior, static cache policy, analysis,
formatting and the production build. `make security.secrets` uses the existing
redacting scanner. Browser acceptance uses `make web.smoke`. These prove the local
artifact; they do not prove live model quality, external DNS/account settings,
GitHub environment reviewer protection, native installation on iOS/Android or
public release. See the [hosting guide](docs/guides/STATIC_HOSTING.md).

## Responsible disclosure

Report security issues privately to the repository maintainer through an existing
private contact channel. Do not open a public issue containing an undisclosed
exploit, credentials or personal data.
