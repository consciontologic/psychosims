# Error handling contract

| Failure | Required behavior |
|---|---|
| Offline AI action | Pause with a visible message; preserve local actions/history and make no request. |
| Missing key or stale/invalid model | Require explicit configuration/refresh; do not silently select a replacement. |
| Network, timeout, cancel, malformed stream | Preserve received text as incomplete; release busy state; retry only on user action. |
| Rejected model output | Keep the attempted text visible; do not apply the deterministic turn. |
| Corrupt, unavailable or full local storage | Show recovery/export controls; do not overwrite the previous save or claim success. |
| Another tab changed the save | Block conflicting writes and offer explicit load-latest. |
| Incomplete asset cache | Do not report offline-ready; leave the existing complete cache usable on failed update. |
| Invalid core input | Reject invalid loadout/state/ruleset rather than silently repair mechanical meaning. |

Messages must not include credentials, raw request bodies or raw provider errors.
Tests cover these boundaries in the current browser and OpenRouter suites.
