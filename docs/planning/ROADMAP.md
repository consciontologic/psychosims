# 🗺 Psychosims — Technical Roadmap

> **Single source of truth for sequenced work.** Agents implement against this
> file phase-by-phase, drain every `[ ]` bullet in scope, append a tracking row,
> then stage. Humans push via `make git`.
>
> **Product design:** [`STARTER.md`](../design/STARTER.md). The current
> implementation and acceptance evidence define the active delivery scope.
>
> **How to read a phase.** Each phase and sub-phase states four things on
> purpose, so any contributor (or a low-context model) can pick it up cold:
> **What** it covers · **Why** it matters · **How** it contributes to the whole ·
> and a short **Validation** line that says when it is done.
>
> **This plan is a living document.** Phases may be re-ordered, split, or
> rewritten as reality lands. Treat the sequence as the current best plan, not a
> contract carved in stone.

## Active scope — static offline PWA (2026-10-23)

**Goal:** migrate the existing game to a static Flutter web PWA for
`https://psychosim.com`, with browser-local career/transcripts and optional
online OpenRouter dialogue. This user-authorized scope supersedes the native
inference, server authority, and ephemeral-transcript requirements. The obsolete
server/native roadmap is retired under the subsequent user-authorized cleanup.

**Non-goals:** publishing, account/DNS mutations, cross-player authoritative
economy, or adding patient scenarios/mechanics that were not implemented.

**Touched files:** `app/lib/browser/`, `app/lib/main.dart`, OpenRouter shared
client/tests, `app/web/`, web build/verification scripts, workflows, and current
architecture/hosting/privacy documentation. Preserve the deterministic core,
current app tests, gameplay references and verification evidence.

**Test plan:** deterministic mocked network/unit/widget tests; all shared core
tests; static build/cache policy tests; production Chromium offline reload,
save/transcript persistence, hash deep links, resizing at 360/768/1440 and
intermediate widths; artifact dependency/secret inspection.

**Checklist:**
- [x] Browser game runtime reuses the existing deterministic rules, scenario,
  loadouts and local progression; saves/transcripts persist with visible errors.
- [x] Memory-only user key, validated OpenRouter catalog, bounded streaming,
  cancellation/partial preservation, output validation, explicit retries.
- [x] Static shell, complete local resource cache, hash deep links, accessible
  responsive UI, install/update/offline readiness, production build.
- [x] Manual GitHub Pages workflow, official DNS/HTTPS/domain instructions,
  read-only live domain checks and complete operator documentation.
- [x] Independent review, final verification, implementation report, tracking
  and staging; no commit, push, publication or external mutation.

**Risks:** browser storage can be cleared/evicted; offline readiness requires a
complete first cache; external model/provider availability changes; local
progression has no cross-player authority; DNS may be delegated outside the
registrar. Keep these states explicit and verify the built artifact.

## Authorized retirement and local preview (2026-10-23)

**What and why:** remove the retired native client, backend, downloaded models,
platform binaries and their obsolete documentation so the repository describes
and builds the current static game. The user explicitly authorized removing the
old implementation and its tests. Keep the deterministic core, current content,
PWA verification evidence and generic agent/framework tooling.

**Validation:** inspect references and dependencies, run the current verification
and browser gates, retain the production build, and show the app on its dedicated
local origin at `http://localhost:18763`.

- [x] Retire native/server/model source, binaries, scripts and old implementation
  tests; preserve current game and reusable core tests.
- [x] Remove obsolete deployment/native/model docs and historical roadmap phases;
  update indexes, architecture, privacy and gameplay references to current scope.
- [x] Verify retained documentation links and record the cleanup in the existing
  PWA implementation report.
- [x] Complete current build/test/dependency gates and confirm the local preview.
- [x] Review the complete diff, append tracking and stage for human review.

## New game and painterly noir presentation (2026-10-23)

**Goal:** make starting a fresh game obvious and give every page and the existing
patient profile the dramatic, painterly noir direction requested by the user.

**Non-goals:** new scenarios, changed clinical/mechanical rules, cleared career
history, copied game characters/artwork, publication or external account changes.

**Touched files:** browser presentation/theme, session restart lifecycle and
tests, localized copy, bundled art/fonts, web shell, browser QA and current docs.

**Test plan:** red/green new-game lifecycle and confirmation regressions;
all existing game/privacy tests; every route at six widths and 200% text;
production browser gameplay, cache/offline reload, navigation, fresh-game action,
visual screenshots and review of the locally served updated build.

- [x] Add clear New game controls with safe active-session confirmation and
  preserved career/history; prove reset and cancellation behavior.
- [x] Bundle original noir scene/portrait artwork and expressive typography;
  apply a cohesive dramatic theme to all pages and patient profiles.
- [x] Verify responsive/accessibility behavior, gameplay, offline caching and
  production browser flow; rebuild and open the updated local preview.
- [x] Review, document art provenance/results, append tracking and stage.

**Risks:** visual density on small screens, accidental session loss and added
cache size; use responsive stacking, explicit replacement confirmation, local
asset inventory, existing core tests and manual screenshot inspection.

## External release decisions

- [ ] Human review, commit and push the staged source.
- [ ] Confirm the authoritative DNS account, verify domain ownership, configure
  Pages/custom domain and deployment-environment reviewers.
- [ ] Approve the manual deployment and DNS changes, enable HTTPS, then verify
  public redirects, installed-app offline reload and a two-version update.

The [hosting guide](../guides/STATIC_HOSTING.md) contains the exact external
steps. A locally working preview does not establish public deployment.

## End-to-end gameplay playtest (2026-10-23)

**Goal:** exercise the updated production game as a player, repair reproducible
conversation, offline and usability defects, and leave a reviewable local build.

**Non-goals:** publication, credential persistence, paid-model fallback or silent
changes to the inherited deterministic win/economy rules.

**Touched files:** browser session/UI and tests, OpenRouter client/tests where
live failures are reproduced, offline assets, production QA and this report.

**Test plan:** live free-model conversation using the user-authorized temporary
key only in memory; full local session/history/New game; offline pause/reload/
retry; short mobile and tablet/desktop layouts; meaningful regression tests,
independent review, current verification and refreshed production browser proof.

- [x] Play through online and local sessions; classify observed bugs, usability
  friction and gameplay hypotheses with concrete evidence.
- [x] Fix confirmed browser failures with regression coverage, preserving saves,
  privacy, original content authority and deterministic core rules.
- [x] Rebuild and verify full session/history/restart, offline behavior and
  mobile layouts; inspect screenshots and update the local preview.
- [x] Record evidence and remaining gameplay limitations; review and stage.

**Risks:** live-provider availability is outside the app, credentials must never
enter artifacts, and gameplay balance changes need separate explicit scope.

**Original playtest result:** local browser gates passed, but inherited pacing
and private-route findings required the authorized follow-up below. Its
[current report](../reports/2026-10-23-progression-ai.md) supersedes those findings;
no successful live patient dialogue is claimed while the eligible provider
returns a rate limit.

## Progression, pacing and private AI recovery (2026-10-23)

**Goal:** finish sessions in a reasonable number of meaningful choices, recover
from crisis, and make live AI routing usable without reducing privacy.

**Non-goals:** deployment, account/DNS changes, stored credentials, relaxed
ZDR/data-collection restrictions, silent model substitution or paid fallback.

**Touched files:** core rules/configuration and replay tests; browser lifecycle,
copy and tests; OpenRouter catalog/routing tests; browser QA and report.

**Test plan:** regress the crisis loop and low-trust success; verify bounded
new sessions, recovery choices, legacy replay/history, terminal rewards exactly
once; validate eligible model routing and 404 recovery while keeping privacy
constraints; mock and live AI acceptance; offline restart, New game, responsive
production browser playthrough and full repository gates.

- [x] Implement tested bounded progression and meaningful pacing while keeping
  existing saves replayable.
- [x] Resolve the privacy-preserving AI route where available, with tested
  eligibility/error handling and explicit user-controlled retries.
- [x] Rebuild and playtest full sessions, New game, live/mocked dialogue,
  offline mode and mobile layouts; reopen the production preview.
- [x] Review, refresh evidence/docs, append tracking and stage all local fixes.

**Risks:** changed rules must not reinterpret older action logs; live endpoint
availability can remain account-dependent; API tests must not leak credentials.
