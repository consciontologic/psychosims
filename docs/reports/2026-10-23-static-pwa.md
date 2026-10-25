# Static offline PWA implementation — 23 October 2026

## Outcome and review boundary

The production application is a static Flutter web PWA, built locally for
`https://psychosim.com`. No backend, database, native inference engine, downloaded
model or developer credential is needed to build or run it. Publication and
DNS/account mutations remain separate human decisions. Changes are prepared
for review; no commit or push is performed by the agent.

The release directory is `app/build/web/`; it is ignored generated output.
A ready-to-serve review archive is `app/build/psychosims-pwa-review.zip`
(16,793,153 bytes), SHA-256
`6921d4154a3f864fc9705a57ed8f668dcba1334e6c9b295fe980bd5dc7ba74cb`.
The ZIP contains the build files at its root, including `.nojekyll` and `CNAME`;
it contains no backend, source repository or user credentials.
The [hosting guide](../guides/STATIC_HOSTING.md) includes complete build commands,
manifest/workflow snippets, DNS record values, domain-verification instructions,
HTTPS/redirect checks and the live DNS/TLS observations. CI uploads the build
and browser evidence. The Pages workflow requires an explicit manual publish
decision on `main` and supports administrator-configured environment reviewers.

The current review artifact includes the later **New game and painterly noir**
refresh described at the end of this report. Earlier migration and cleanup
results below are retained as dated evidence, with their original build IDs.

## Preserved game and changed boundaries

The original implemented **The Restless Hour** scenario and manifest checksum,
four interaction patterns, cards/loadouts, focus/emotional-delivery controls,
turn rules, trust/agitation/progress, outcomes, multi-session history and local
XP/study/cash progression are reused. Patient copy and existing game content
are retained; the later user-requested noir visual refresh is recorded below.
No new patient corpus or previously
unimplemented roadmap mechanic is claimed.

Local practice uses the original fallback dialogue and deterministic mechanics.
AI mode sends the fictional prompt and recent dialogue only after an explicit
online action. New model output must pass the existing clue, first-person,
brevity, refusal, instruction-leak and advice checks before one turn is applied.
Rejected or interrupted text remains visibly incomplete; retry is manual.
Reconnection, reloading and model-list changes cannot silently replay a request.

Browser saves contain the complete local state, transcripts, partial attempts
and completed sessions in one atomic snapshot. Restore checks the version,
checksum, types, loadout bounds, replayed state and terminal history. Corrupt,
unavailable or full storage is reported without overwriting the prior save.
Concurrent tabs detect a changed save and offer an explicit load-latest action.
Export and confirmed local deletion are available in Settings. The earlier
ephemeral-transcript/server-authority policy is superseded for this local game.

Keys and validated model authorization exist only in tab memory. Reloading or
forgetting a key clears them; saves and exports never contain credentials.
The public asset cache contains only enumerated same-origin static resources.
The [architecture](../code/ARCHITECTURE.md) records the Worthhit/wfform source
adaptations, file identities, request privacy policy and transport limits.

The user subsequently authorized deleting the retired implementation, binaries,
models, tests and obsolete docs. The cleanup preserves shared deterministic
rules/content, current core/app tests and this PWA's production evidence; see
the cleanup manifest below. Active verification assertions were not weakened.

## Browser and offline behavior

The application uses root-relative assets and Flutter hash routing, such as
`/#/session`. A single Flutter router owns history; ordinary static servers and
GitHub Pages need no rewrite rules. All five routes reload offline after the
complete cache is installed. Back/forward navigation preserves the game.

CanvasKit, local Roboto fonts, icons, scenario data and shaders are enumerated
and hashed. The worker verifies each response before reporting **Ready offline**.
An incomplete installation is removed, while a failed update preserves the old
working cache. Updates wait for every open app tab to close; they never replace
code or reload during a session. Saves are separate from asset-cache versions.

Screens use safe areas, scrolling content, constrained desktop width, padded
touch controls and visible keyboard focus. Responsive checks cover 360, 480,
600, 768, 1024 and 1440 px, plus resizing without losing transcript/state.
Widget coverage also exercises 200% text, high contrast and reduced motion.

## Initial migration verification evidence

`make verify` passed in a fresh process against the final source: **352 tests**,
plus **3 secret-scanner self-tests**. The release inventory contains
**34 cached resources / 26,315,996 bytes**, build ID
`e8b8a522cc8d77fd3ff1d7d9`. The final rebuild has the exact same inventory/build
identity as the production-browser acceptance run. This includes the icon font required by adaptive
Flutter controls, with no missing-font build warning.

| Gate | Result | Local evidence |
|---|---|---|
| Current Dart/Flutter suites | 291 passed: config21, schemas21, core183, tools7, app59 | `/tmp/agent-runs/pwa-final-current-verify--20261023T111043Z-246371.log` |
| Analyzer, format and source/content gates | Five analyzers clean; 155 files format-clean; logging/env/localization/purity/content checks pass | Same combined verification log |
| Static cache and output policies | 8 Node worker/shell tests and 7 Python build-policy tests pass | Same combined verification log |
| Bootstrap and repository gate regressions | 46 Python tests pass | Same combined verification log |
| Native/JavaScript gameplay and arithmetic | Original fixture, current VM and compiled JS identical; boundary checks pass | `/tmp/agent-runs/psychosims-parity-uaj7uS/` |
| Production browser acceptance | All ten acceptance checks pass in Chromium 156.0.8078.47; no uncaught errors | [Machine-readable results](static-pwa-2026-10-23/results.json) |
| Independent application review | Save/routing/tax findings repaired; final accessibility/reconnect review has no actionable findings and 28 tests pass | `/tmp/agent-runs/reviewer-accessibility-reconnect--20261023T111122Z-250240.log` |
| Secret scanner | 3 planted-key/exception tests pass; 3.98 MB worktree scan has no findings | `/tmp/agent-runs/pwa-final-current-secrets--20261023T111053Z-247669.log` |
| Repository doctor | Pass | `/tmp/agent-runs/pwa-final-doctor--20261023T105235Z-183305.log` |

The browser harness serves the release directory with an ordinary static file
server and no rewrite fallback. It checks the actual service worker/cache,
Chromium installability diagnostics, navigation, saved turns, offline reloads,
six widths and an intercepted OpenRouter catalog/SSE interaction. All AI replies
are deterministic fixtures; no real key, charge or provider inference is used.
Screenshots and machine-readable results are written to `test-results/pwa/` and
uploaded by CI. Normal temporary profiles are used because private/incognito
Chromium deliberately disables installation.

The accepted run proves a real blocked network request, offline reload with
byte-identical saved state, continued local turns, all five offline deep links,
and exactly one validated streamed AI turn from a deterministic fixture.
Reloading retains that dialogue but forgets the key; reconnecting makes no
request. The two external request URLs in the results are intercepted fixtures,
not contacts with the live provider. Neither storage area contains the test
credential, and the public cache contains no API URL.

Durable evidence is included under `docs/reports/static-pwa-2026-10-23/`:
[verification inventory](static-pwa-2026-10-23/verification.json),
[360 px](static-pwa-2026-10-23/session-360.png),
[768 px](static-pwa-2026-10-23/session-768.png),
[1440 px](static-pwa-2026-10-23/session-1440.png),
[offline reload](static-pwa-2026-10-23/offline-reload.png), and
[mocked AI response](static-pwa-2026-10-23/mocked-ai-response.png).
The intermediate-width captures are retained alongside them. Visual inspection
found readable dialogue, wrapped action controls and visible navigation without
horizontal clipping. Accessibility assertions check spoken transcript content,
isolated input labels and keyboard navigation; physical screen-reader/device
acceptance remains distinct from these automated and visual checks.

The exact-core regression retains a pre-port native trace: six seeds, 120
full-width random draws, 600 bounded draws, 72 turn seeds, six router seeds and
96 canonical turns. The current VM and dart2js/Node outputs must match that
fixture byte-for-byte. Additional boundary checks cover 64-bit fixed-point and
tax arithmetic. The trusted outcome catalog retains all three proof payloads;
only hashes of intentionally changed source files differ.

Review-driven fixes include invalid loadout caps, terminal saves without matching
history, exception-safe busy-state cleanup, browser route reporting, isolated AI
field labels, readable transcript semantics and exact large-number arithmetic.
Recovery logs retain the initial failures and passing
regressions rather than concealing them through retries or skipped tests.

The migration is recorded under tracking run `pwa-20261023`, followed by
`pwa-cleanup-20261023` for the authorized retirement and local preview. The
complete change set is staged for human review; generated build output stays
outside Git.

## Authorized cleanup and local preview

On 23 October the user explicitly authorized removal of old game code,
binaries and docs. Retired `legacy_app/`, `server/`, `native/`, downloaded models,
platform build outputs and their scripts/tests were removed. This includes the
207 former native-client tests, not current browser/core coverage. The cleanup
removed **10,689,661,292 bytes** of retired implementation/build/model material.

Documentation cleanup removed **39 obsolete files**: native/server/model ADRs,
desktop/OAuth/key-custody notes, server lifecycle/cost/moderation specs, old
assessment/model/deployment reports, native telemetry/metrics contracts, the old execution
plan and the obsolete design prompt. Current docs replace server authority,
native inference and ephemeral-transcript claims with the implemented PWA
contracts. The old server/native roadmap phases are removed.

Retained: `packages/psycore/`, `packages/psychemas/`, shared configuration,
fictional manifests, canonical fixtures, pure-core tools/showcases, current
app/core tests, the PWA hosting guide and screenshot/machine evidence, generic
agent/framework docs/templates and unchanged append-only tracking history.
Library design/tuning references retain their numeric values and distinguish
unimplemented mechanics from the browser's exposed features. All **13 retained
tuned-balance rows** match the pre-cleanup reference. A local-target audit of
**71 retained Markdown documents** reports **0 missing files**; the scoped diff
whitespace check passes. Logs: `/tmp/agent-runs/pwa-cleanup-doc-links--20261023T113747Z-338903.log`
and `/tmp/agent-runs/pwa-cleanup-doc-diff--20261023T113821Z-340669.log`.

`make verify` passes after cleanup: **352 tests**, same build ID
`e8b8a522cc8d77fd3ff1d7d9`, **34 resources / 26,315,996 bytes**.
Evidence: `/tmp/agent-runs/pwa-cleanup-final-verify--20261023T113248Z-318259.log`.
The production artifact and review ZIP remain available. `make web.serve` previews
the actual build at **http://localhost:18763**; this dedicated origin avoids
unrelated caches/saves on shared localhost ports. Existing other-origin browser
storage was not cleared. Public publication remains unperformed.

The post-cleanup browser recheck exposed a test-input race: Flutter had focused
its semantic password field before attaching the input listener. The test's
immediate fill could be lost; instrumentation showed the key was absent before
history navigation, with no document reload. Keyboard entry alone also lost
its first character once. The final harness waits for the listener, types once,
asserts the accepted key and cleared field, and waits for rendered routes before
back/forward traversal. Application code and production bytes did not change.
All earlier failures remain under `test-results/pwa/` and their safe-run logs.

The repaired harness passes **10 consecutive full runs plus one final refresh**
with the same build ID, including offline reload/persistence, all five routes,
six viewport widths, installability, one mocked streamed AI turn and no replay.
[Repeatability evidence](static-pwa-2026-10-23/repeatability.json) records each
run, its assertions, harness hash and failure diagnosis. The retained screenshots
and `results.json` now come from the final refresh, at 11:45:12 UTC.
Logs: `/tmp/agent-runs/pwa-editor-ready-ten--20261023T114317Z-359711.log`
and `/tmp/agent-runs/pwa-editor-ready-final--20261023T114504Z-367856.log`.

The refreshed dependency gate covers **75 components / 66 Pub/npm versions**
with no known vulnerabilities, plus **17 inventory/scan unit tests** and **5 real
scanner acceptance tests** (including planted-secret and known-vulnerability
fixtures). Retired Go/native/model inventory entries and scanner prerequisites
are removed. The final secret scan and its three self-tests pass; an independent
cleanup review reports no actionable findings. See the updated
[verification inventory](static-pwa-2026-10-23/verification.json) for exact logs.
The local preview remains running and open for user acceptance; no deployment,
commit, push or external setting was changed.

## External acceptance still required

Public DNS currently uses `ns27/ns28.domaincontrol.com` and parking A records,
not GitHub Pages. Existing apex/www certificates are valid, but the current
landing site does not demonstrate Pages HTTPS enforcement or canonical redirects.
The Namecheap registration statement and the public DNS delegation are separate
facts; confirm the authoritative DNS account before changing records.

An owner must review/commit/push the staged changes, verify the domain with the
exact GitHub-generated TXT token, configure Pages/custom domain and environment
reviewers, approve the manual deployment, update DNS, and enable Enforce HTTPS.
Then run the hosting guide's public URL, redirects, installed-app offline reload
and two-version update checks. No authenticated Pages/Namecheap administration,
physical iOS/Android installation or live OpenRouter inference is claimed here.

Browser storage can be cleared or evicted; offline support begins only after
the complete cache is ready. Saves are local to the origin/browser profile,
not an encrypted vault or cloud backup. Export important progress before clearing
storage. Local career values have no cross-player/server authority.

## New game and painterly noir review build

The follow-up request is implemented in tracking run `pwa-noir-20261023`.
Home now has a prominent **New game** control alongside **Resume Session** when
progress exists. The Session page also offers New game. Replacing unfinished
progress requires **Start new game** confirmation; **Keep playing** preserves
the exact save. Completed sessions, career balances, preparation and in-memory
AI setup survive a restart. A failed save rolls back the replacement; active
requests, corrupt storage and stale-tab conflicts prevent it. No automatic AI
request is sent by restarting.

The user-requested *Disco Elysium*-inspired presentation uses original painted
clinic and patient illustrations, ink surfaces, ochre/rust/teal accents, local
Noto Serif headings, paper dialogue and animated trust/agitation/progress bars.
All five routes share the theme. Existing patient copy, scenario content and
mechanics remain authoritative. The [visual direction](../design/VISUAL_DIRECTION.md)
records prompts, provenance, licenses and the 6.22 MB art contribution. Reduced
motion disables meter animation. No external art/font service is used.

The final production build is `cd48b7e2a12b289ba9f84556`, with **39 cached
resources / 33,818,029 bytes**. The review ZIP identified at the top of this report
contains these exact files. The local static server at `http://localhost:18763/`
serves this inventory. The existing preview upgraded through the waiting-service-
worker lifecycle; its stored session survived, and the final UI reports
**Ready offline**. Browser storage was not cleared.

Verification includes **376 tests** across the full run and the final title
regression run: 315 Dart/Flutter, 8 worker/shell and 53 Python tests. The initial
full run passed 374; the final color-only fix adds two title-contrast regressions,
and all **29 widget tests** then pass. Five analyzers, 156-file formatting,
content/source checks and unchanged VM/JavaScript gameplay parity pass. A final
format/analyzer/release build validates the corrected title. Security checks
pass 3 secret-scanner and 19 dependency/security tests; 75 inventoried components
and 66 resolved package versions have no known vulnerabilities in the checked
advisory data.

Review and visual inspection caught, reproduced and fixed two contrast issues:
error-notice text/recovery/focus in high contrast, and an app-bar title style
without an explicit foreground. Eight regressions exercise actual effective
text and focus-border colors. The existing session-replacement tests exercise
save failures, conflicts, interrupted output, busy state and retained career.

| Evidence | Log |
|---|---|
| Full verification, 374 tests | `/tmp/agent-runs/noir-final-verify--20261023T121141Z-457563.log` |
| Final 29 widget tests, including two added title checks | `/tmp/agent-runs/noir-widget-title-green--20261023T121531Z-474283.log` |
| Final format, analyzer and production build | `/tmp/agent-runs/noir-title-verify-build--20261023T121500Z-472365.log` |
| Secret, dependency and advisory checks | `/tmp/agent-runs/noir-security--20261023T121142Z-457741.log` |
| Review ZIP integrity | `/tmp/agent-runs/noir-review-archive--20261023T121617Z-477762.log` |
| Served inventory equals the release artifact | `/tmp/agent-runs/noir-preview-inventory--20261023T121744Z-482505.log` |

The final Chromium acceptance run passes all **12 checks** with no uncaught
errors against that exact artifact. It verifies all 39 cached resources,
installability, offline reload/persistence, five offline hash routes, six session
widths, one deterministic mocked AI turn, key forgetting/no replay, and the
New game cancellation/reset/offline-reload flow. Existing assertions were kept.
The taller Flutter layout needed real wheel scrolling to mount and reveal
actions; the harness now uses the explicit cache-ready contract rather than
generic network idleness and moves the pointer away from hover tooltips before
checking exact navigation labels. Diagnosed failures remain in local evidence.

Current [machine-readable results](noir-ui-2026-10-23/results.json) and
[verification inventory](noir-ui-2026-10-23/verification.json) are retained with
20 production screenshots: [desktop Home](noir-ui-2026-10-23/noir-home-1440.png),
[mobile Home](noir-ui-2026-10-23/noir-home-360.png),
[patient profile](noir-ui-2026-10-23/noir-home-profile-1440.png),
[mobile approaches](noir-ui-2026-10-23/noir-actions-360.png) and
[fresh-game offline reload](noir-ui-2026-10-23/new-game-offline.png).
Final browser log: `/tmp/agent-runs/noir-browser-final--20261023T122042Z-496868.log`.
Manual inspection found readable portraits/dialogue, visible New game controls,
wrapped action buttons and coherent ink/paper styling across phone, tablet and
desktop views. Hardware/screen-reader testing remains distinct from this
browser and widget evidence.

Public deployment, DNS/account changes, commits and pushes remain unperformed.


## Subsequent gameplay acceptance

The [end-to-end playtest report](2026-10-23-playtest.md) supersedes the build
identity and browser counts above. It records the current production artifact,
CORS/cache/font/conversation repairs, full offline mobile completion, and the
remaining live-provider and inherited progression release holds.
