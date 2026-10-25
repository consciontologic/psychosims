# Glossary

| Term | Meaning |
|---|---|
| Agitation | Bounded core state measuring pressure within a fictional session. |
| Card taxonomy | Disclosing, Relatable, Postponing and Manipulative interaction roles. |
| Clue token | Required fictional scene text checked before generated dialogue is accepted. |
| Config authority | Typed, validated shared configuration in `config/`. |
| Dialogue layer | Optional online OpenRouter response; voices the patient but does not decide outcomes. |
| Hash route | Bookmarkable `/#/...` URL whose navigation needs no host rewrite rule. |
| Loadout | The capped set of cards and controls selected for a session. |
| Local practice | The original fallback dialogue and deterministic turns, available offline. |
| Manifest | Versioned structured patient/scenario definition bundled with the game. |
| Memory-only key | User credential kept only in the current tab and forgotten on reload. |
| Partial attempt | Interrupted or rejected model text retained without applying a turn. |
| Ready offline | The service worker has the complete verified static resource inventory. |
| Ruleset version | Identity of the deterministic rules used to resolve/replay actions. |
| Sandbox | Headless bot-driven tests of the pure rules and balance. |
| Signature principle | A card's effect depends on its fit to the current scene and controls. |
| Simulation core | Pure deterministic mechanics in `packages/psycore/`; no network/model calls. |
| Study points / XP / cash | Local career progression values, without a shared online economy. |
| Transcript | Saved player and patient dialogue; excludes API credentials. |
| Trust | Bounded core state describing alliance within the fictional case. |

The reusable core also includes clinic, recovery and multi-session mechanics;
these library capabilities do not imply a corresponding screen or online service.
See [implemented core mechanics](../reports/implemented-gameplay-rules.md).
