# Changelog

All changes below are unreleased. No deployment or publication is performed.

## [Unreleased]

### Added

- A visible New game action on Home and in-session, with confirmation before
  replacing unfinished progress; career and completed session history stay saved.
- Original painterly clinic and patient artwork, expressive serif headings,
  ink/ochre/rust/teal styling and animated state meters throughout the app.
  Artwork and fonts are bundled for offline play; reduced motion is respected.

### Changed

- New games now end within 16 choices, with success from turn 12 when trust,
  calm and varied approaches support it; saved sessions retain their original
  rules. Boundaries provide a viable recovery from crisis.

- Conversation choices and live trust/agitation stay within reach on small
  screens; each completed turn brings the latest patient reply into view.
- Local practice now uses varied, state-aware authored dialogue, with a closing
  response at session completion and guidance explaining approaches and progress.

- Psychosims now starts as a static Flutter web PWA, with local practice and
  career progression, browser-saved sessions/transcripts, and hash deep links.
- AI patient dialogue uses an optional user OpenRouter key held only for the
  current tab. Offline AI pauses; interrupted responses retain partial text and
  retry requires a deliberate action.
- The production build bundles runtime assets/fonts and caches them for offline
  use. GitHub Pages publication is prepared as a manual workflow for psychosim.com.
- Server accounts, receipts, database services, downloaded models and native
  inference are retired from the runtime, repository and CI.
- The earlier ephemeral-transcript policy is replaced for the PWA by local-only
  transcript persistence, visible storage failures and local data controls.

### Fixed

- Repeated validation or low trust no longer grants automatic session rewards.
- AI selection verifies the exact free model variant has a zero-data-retention
  endpoint, avoiding mismatched routes without relaxing privacy.

- OpenRouter requests no longer send a header rejected by browser CORS policy;
  HTTP caching, cookies and silent request replay remain disabled.
- Failed AI requests keep their explanation beside the conversation and retry.
- Local symbols font coverage is retained by body and navigation text styles,
  preventing repeated missing-font requests during offline play.

- Shared deterministic arithmetic now runs on JavaScript with exact 64-bit
  random and derived seeds; original native gameplay traces remain unchanged.

### Removed

- Retired native client, server and inference engine sources, downloaded model
  weights, platform binaries and their obsolete tests, scripts and documentation,
  with explicit user authorization. Current PWA/core tests and gameplay content
  remain; this removal does not skip or weaken active verification gates.
- Historical server/native roadmap phases and superseded deployment/privacy
  policies; current docs now describe the browser game and dedicated local preview.
