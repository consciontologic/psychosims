# Psychosims charter

## Vision

A fictional psychology-practice game with approachable card-based sessions,
deterministic outcomes and local career progression. A static Flutter web PWA
runs on mobile, tablet and desktop; optional online OpenRouter AI voices the
patients. Existing fictional scenarios, rules and visual style remain the base.

## Current scope

- Reuse the existing deterministic core, patient manifest, cards and progression.
- Bundle all runtime assets and fonts; cache the complete static build for
  offline navigation, saved transcripts and local mechanics.
- Keep saves in the browser and API keys only in tab memory.
- Pause AI requests offline; preserve partial dialogue and require explicit retry.
- Validate generated dialogue before accepting it; AI never owns game outcomes.
- Deploy static files through a manual GitHub Pages workflow to psychosim.com
  after human review, with documented domain/DNS/HTTPS steps.
- Maintain accessible responsive controls, keyboard focus, touch targets and
  reduced-motion behavior.

## Boundaries

No application backend, database, native inference or downloaded models are
required or deployed. Local saves are user-editable and cannot certify a shared
multiplayer economy. Retired server/native code, binaries, models and tests have
been removed under explicit user authorization; reusable core tests remain.
There is no cloud synchronization, cross-player ownership or online account.

This is fictional simulation, not real therapy. Preserve the fictional taxonomy
and do not solicit real health data. Public deployment and DNS/account changes
require a separate owner decision; preparation and local verification are authorized.

## Acceptance

A production Flutter web build passes core and deterministic AI tests, reloads
offline with saved state/transcripts, supports hash deep links and responsive
layouts, and contains no keys or backend runtime. Public DNS/HTTPS acceptance
is reported separately from local test evidence.
