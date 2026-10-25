# 🧠 docs/tracking/context.md — shared project context pack

> **This file is the single place for project-specific overrides.**
> All vendor entry points (`CLAUDE.md`, `CONVENTIONS.md`,
> `.github/copilot-instructions.md`, etc.) are invited to reference this file
> so context stays in sync without editing every vendor file.

---

## Project identity

- **Name**: Psychosims
- **One-liner**: Fictional psychology-practice sim; optional online OpenRouter voices patients; the deterministic core owns local outcomes in a static offline PWA.
- **Primary language**: Dart / Flutter web; static GitHub Pages hosting.
- **Blueprint**: [`STARTER.md`](../design/STARTER.md) (§1–§24).

## Key paths

| Concern | Path |
|---|---|
| Master rulebook | `AGENTS.md` |
| Project plan | `docs/planning/ROADMAP.md` |
| Tracking log | `docs/tracking/tracking.csv` |
| Skills library | `.agents/skills/` |
| Ops scripts | `xops/` |

## Active context (update as the project evolves)

The active scope is the **2026-10-23 static offline PWA migration** in
[`ROADMAP.md`](../planning/ROADMAP.md). The user explicitly replaced native
inference/server authority with online OpenRouter dialogue and browser-local
state/transcripts. The user subsequently authorized removing the retired native
client, backend, model binaries and obsolete documentation. Current core/content,
PWA evidence and append-only tracking history remain. The production build is
available locally at `http://localhost:18763/` via `make web.serve`.
No publication, DNS or external account changes are authorized.

## Project-specific conventions

- **Centralized configuration only** — no module reads raw env vars or hard-codes
  constants; everything flows through `config/` (Principle 1;
  [DESIGN-centralized-configuration](../design/DESIGN-centralized-configuration.md)).
- **Separation of concerns** — code lands in exactly one declared module per
  [`ARCHITECTURE.md`](../code/ARCHITECTURE.md); pure rules live in `core/`.
- **All balance constants are owned by the balance spec** (§9), loaded via config.
- **Transcripts persist only in browser-local saves** alongside structured game state. OpenRouter keys are memory-only and must never enter any durable store, export or cache.

## Out-of-scope / do not touch

<!-- List directories, files, or systems agents should treat as read-only.
     E.g.: "Never edit vendor/ — it is a git subtree." -->

_None yet._

## External service dependencies

<!-- List services this project calls, with the env var that holds each key.
     Do NOT include actual keys here — only the var names. -->

| Service | Env var | Notes |
|---|---|---|
| OpenRouter | None | User key entered in the app; memory-only, never a build or deployment secret |

## Agent quick-reference

```bash
make help           # all targets
make doctor         # sanity-check framework install
make git.dry        # preview pending commits (read-only)
make git            # commit + push (human runs this)
make track.add ACTION=note SUMMARY="..."   # append tracking row
make skills.find TAG=<tag>                 # search skill library
make skills.status                         # skill index with line counts
```
