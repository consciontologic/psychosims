# Progression and private AI follow-up — 23 October 2026

This follow-up supersedes the progression/pacing and routing findings in the
[earlier playtest](2026-10-23-playtest.md). Scope is local implementation and
verification only. No commit, push, publication, DNS or account change occurred.

## Implemented gameplay repair

New games use versioned ruleset **0.2.0**. Successful sessions finish in **12–16
choices** with progress 100, trust at least 50, agitation at most 35, and both
validation and exploration (Open question or Reframe). Any unresolved session
ends for review at turn 16 without success rewards. Agitation 95 can cause an
earlier walkout. Progress alone cannot grant a win.

Boundaries reduce pressure enough to create a recovery window; validation
rebuilds rapport, and questions remain useful after defenses fall. Contextual
guidance names the next unmet goal. The existing authored practice responses,
patient scenario, painterly artwork, career and reward amounts remain intact.

Existing saves retain their original rules and exact transcripts. A visible
notice explains how New game adopts the shorter rules while keeping completed
history and career. Failed replacement saves roll back safely. The core's old
golden replay bytes and native/JavaScript parity remain unchanged; 18 new traces
cover the new version separately. A carried-over case starting at extreme
pressure can resolve its first action rather than become unplayable.

## OpenRouter 404 diagnosis and privacy

Model-level ZDR discovery included free variants whose **paid base model** had
private endpoints. Selecting such a free variant then produced a policy-mismatch
404. Catalog refresh now intersects the public model catalog with the exact
`model_id` values in OpenRouter's [ZDR endpoint listing](https://openrouter.ai/docs/api/api-reference/endpoints/preview-the-impact-of-zdr-on-the-available-endpoints).
Endpoint status, prices, context, capabilities and provider tags are validated;
conflicting duplicate identities fail closed. The selected request uses only
the validated provider tags.

The [provider routing requirements](https://openrouter.ai/docs/guides/routing/provider-selection)
remain strict: `zdr:true`, `data_collection:"deny"`, zero price limits,
`allow_fallbacks:false`, and an exact `provider.only` allowlist. Keys live only
in tab memory. Catalog requests are anonymous; API traffic bypasses both HTTP
and service-worker caches. There is no automatic retry, account-policy change,
paid fallback or silent model replacement.

Live public discovery admitted `xingchen-agi/xing4.0-29b-a4b:free` on `phala`.
Both a bounded direct diagnostic and one explicit Validate action in the actual
production browser returned **429**, rather than the reproduced 404. The app
kept turn 0, the empty committed transcript and rewards unchanged, with a
visible pause message and an explicit retry control
([screenshot](progression-ai-2026-10-23/live-provider-429.png)). A read-only
[key-limit check](https://github.com/OpenRouterTeam/docs/blob/main/api_reference/limits.mdx)
returned 50 daily free requests remaining, so the evidence does not indicate
exhaustion of that daily quota. Provider availability remains an external
limitation; **successful live patient dialogue has not been verified**.

The temporary key was explicitly forgotten in Settings after the test. No
credential or raw authenticated response is included in these artifacts.

## Verification and production artifact

The local preview is served at `http://localhost:18763/`. The final resource
inventory, archive checksum and browser evidence are in
[the evidence folder](progression-ai-2026-10-23/). The review archive is
`app/build/psychosims-pwa-review.zip` and the static directory is `app/build/web`.
Build **`1b9610030c2fd789cec17ec9`** caches **40 resources / 34,092,388 bytes**.
The browser was closed/reopened through the normal waiting-worker update path,
then reloaded with current turn 2 and both authored replies preserved. The
preview remains open in local practice with no key
([screenshot](progression-ai-2026-10-23/local-review-preview.png)).

| Gate | Evidence |
|---|---|
| Full repository gate | PASS: `make verify`; 360 Dart/Flutter tests (21 config, 21 schema, 200 core, 7 tools, 111 app), 8 service-worker tests, 53 Python tests; analysis, format, content, purity and native/JavaScript parity. `/tmp/agent-runs/progression-verified-build--20261023T132438Z-745893.log`. |
| Final app changes | PASS: 68 lifecycle/session/widget tests plus analysis/format after fixing a duplicate legacy-rule notice. `/tmp/agent-runs/progression-final-build--20261023T132551Z-751583.log`. |
| Final production browser | PASS: 8 Fetch transport tests and 21 acceptance checks, Chromium 156.0.8078.47; 98 actual choices across 7 strategies (97 pointer, 1 keyboard), no action scrolling, no runtime exceptions or missing assets. Every reply is fully within the viewport and all outer-surface scroll offsets remain zero. `/tmp/agent-runs/progression-private-bounds-final--20261023T133525Z-784795.log`; [results](progression-ai-2026-10-23/results.json), [per-turn evidence](progression-ai-2026-10-23/playthrough.json). |
| Secrets and privacy | PASS: worktree/index secret scan and acceptance checks; 69 privacy tests. `/tmp/agent-runs/progression-final-security--20261023T133542Z-786286.log`. |
| Independent review | No actionable findings after repairing first-turn carry-over pressure, legacy guidance and the browser harness. Review covered the changed rules, save compatibility, exact private endpoint selection and final evidence boundaries. |
| Regression process | Red tests reproduced the free/base endpoint mismatch, unbounded rules, duplicate legacy notice and first-turn pressure lock. Corrected the source-hashed catalog fixture using its canonical compiler; only build metadata changed. |

The browser playtest covers a mixed 12-choice success; four repeated approaches
ending without success rewards (Validate 16, Open question 16, Reframe 8,
Boundary 16); objective delivery failing at trust 27 despite progress 100; and
a deterministic seed-0 crisis recovery from agitation 81 through boundaries to
success at turn 14. The crisis fixture is explicitly seeded, not a randomly
discovered run. All choices use the actual production controls.

Offline checks cover reload, complete transcripts, completed history, rewards,
New game, all five hash routes and no replay on reconnect. Mocked SSE covers
partial preservation, cancellation, explicit retry and validated application;
mocked 404 retains the turn and identical privacy constraints on explicit retry.
Responsive checks include 360, 480, 600, 768, 1024 and 1440px and short 360x640
screens, plus runtime resizing. Chromium installability and the complete static
cache are checked. These results do not claim physical iOS/Safari acceptance.

Screenshot review caught a false positive in the initial browser harness:
Playwright's locator auto-scroll panned Flutter's canvas during the crisis
sequence. Actual pointer clicks and keyboard Enter kept the surface at zero
offset throughout the same sequence. The permanent harness now uses observed
button centers for gameplay and asserts horizontal as well as vertical bounds,
plus zero outer-canvas scroll every turn. The keyboard transition remains in
the crisis regression. The earlier evidence is retained locally, not presented
as the final visual pass. A separate footer synchronization failure after offline
reload was repaired by checking the visible restored turn and exact saved career
before scrolling to the lazily rendered footer; no product assertion was removed.

## Gameplay assessment and remaining boundary

The former hundred-choice loop now has a visible short arc. Single-action
repetition cannot earn success rewards, and pressure recovery changes the
outcome within the same session. Replay and failure preserve earned career data.
These are observed mechanics and usability improvements, not evidence that
every player will find the game enjoyable. One active case and four available
cards still limit longer-term variety; this scope did not invent new content.

Keep deployment on hold as requested. Live conversation quality/cancellation
must be checked when an eligible provider accepts requests under the unchanged
privacy policy. The separate GitHub Pages, domain and HTTPS steps remain in
[STATIC_HOSTING](../guides/STATIC_HOSTING.md); none were performed here.
