# Decision log

Current decisions for the static browser game. The user-authorized retirement
on 2026-10-23 removed superseded native/server decisions and their implementation;
the append-only [tracking history](../tracking/tracking.csv) remains intact.
New reversals of the decisions below should append a row rather than rewrite one.

| ID | Date | Decision | Consequence |
|---|---|---|---|
| PWA-01 | 2026-10-23 | Ship a static Flutter web game on GitHub Pages | No application backend, database, native runtime or model weights are required. |
| PWA-02 | 2026-10-23 | Preserve deterministic gameplay and fictional content | The shared core owns outcomes; dialogue cannot grant rewards or change rules. |
| PWA-03 | 2026-10-23 | Persist complete local state and transcripts | Browser saves replace the former ephemeral-transcript policy; no cloud synchronization or cross-player authority. |
| PWA-04 | 2026-10-23 | Use a user OpenRouter key only in tab memory | Reload forgets the key; no key enters saves, exports, cache, source or build configuration. |
| PWA-05 | 2026-10-23 | Require explicit online AI actions and validated output | Offline practice continues; reconnect does not replay requests; incomplete output stays visible. |
| PWA-06 | 2026-10-23 | Cache only the complete static build inventory | Hash routes reload without server rewrites; updates wait for open tabs to close. |
| PWA-07 | 2026-10-23 | Keep deployment and DNS changes separately approved | Local verification and staging do not authorize public publication or account mutations. |
| PWA-08 | 2026-10-23 | Remove the retired implementation, binaries, tests and docs | Keep reusable core/content tests, PWA evidence and generic agent/framework tooling. |
| PWA-09 | 2026-10-23 | Version new sessions to bounded 0.2.0 pacing after user-approved gameplay fixes | Preserve old saves; health and varied approaches govern success within 12–16 choices. |
| PWA-10 | 2026-10-23 | Validate exact free ZDR endpoints, not only model-level metadata | Retain strict privacy and zero price limits; provider availability does not justify weaker routing. |

Fictional taxonomy, contextual card choices and the separation between pure rules
and dialogue remain foundational. See [game design](../design/STARTER.md),
[configuration](../design/DESIGN-centralized-configuration.md), and
[architecture](../code/ARCHITECTURE.md).
