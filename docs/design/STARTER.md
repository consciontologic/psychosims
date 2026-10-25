# Psychosims game design

Psychosims is a fictional psychology-practice game. The player reads a patient's
scene, selects a therapy interaction and delivery, observes the result, and
continues a local career. It is entertainment, not clinical instruction.
This document replaces the superseded native/server blueprint; the current
[roadmap](../planning/ROADMAP.md) defines authorized delivery work.

## Playable browser loop

The bundled **The Restless Hour** scenario, original patient copy and four
interaction patterns remain intact. The player prepares a capped loadout and
focus/emotional-delivery controls, starts a session, and chooses actions while
watching trust, agitation, progress and dialogue. Completed sessions feed local
history and XP, study and cash progression. Existing multi-session state is
carried through the shared rules.

Disclosing pushes an insight, Relatable builds rapport, Postponing buys time,
and Manipulative takes a consequential gamble. The signature principle makes
context matter: an aligned choice has a more favorable, narrower effect band.
The controls change fit rather than adding a second outcome authority.
Rules and exact numeric ownership are in [GAME-RULES](../specs/GAME-RULES.md)
and [BALANCE-SPEC](../specs/BALANCE-SPEC.md).

Local practice uses the original fallback dialogue. Optional online AI voices
the patient using the same fictional manifest and required clue contract.
Generated text is accepted only after validation; it cannot decide outcomes,
edit rewards or bypass loadout limits. Failure leaves the turn unapplied and
keeps partial text visible for an explicit retry. Reconnection does not resend.

## Pure rules and content

The reusable core retains cards, seeded turn resolution, pharmacology,
multi-session digests/grading, progression, clinic/recovery calculations and
sandbox tooling. These library capabilities are documented in the
[core mechanics reference](../reports/implemented-gameplay-rules.md) and
[core showcases](../reports/showcase/phase2/INDEX.md). Their existence does not
claim that every library capability is exposed as a current browser screen.

All patient, diagnosis and medication names use the fictional taxonomy.
Core outcomes are structured deterministic data; dialogue is presentation.
The same actions and seeds replay identically on Dart VM and JavaScript.
Content fixtures and original traces protect that behavior during changes.

## Presentation and accessibility

Use the user-approved painterly noir direction in [VISUAL_DIRECTION.md](VISUAL_DIRECTION.md), original icon artwork and
patient dialogue. Mobile uses safe areas, scrolling layouts and clear touch
targets; tablets and desktops use constrained readable widths, pointer/keyboard
controls and visible focus. Text scaling, high contrast and reduced motion must
remain supported. Browser evidence covers 360, 480, 600, 768, 1024 and 1440 px.
Original scene and patient portrait artwork, ink/ochre/rust/teal colors and
bundled serif typography now define the presentation. Motion is limited to
state feedback and respects reduced-motion preferences.

## Storage and connectivity

State, full transcripts, partial attempts and assets remain available offline
once the complete static cache is ready. The API key lives only in tab memory.
Saves are local to the browser, with export/deletion and visible storage errors.
There is no login, account synchronization, shared economy, patient ownership
service, community publishing or player messaging. No model weights, native
inference engine or application server ships with the game.

The [architecture](../code/ARCHITECTURE.md) and
[hosting guide](../guides/STATIC_HOSTING.md) define the implementation and
separately approved GitHub Pages publication at `https://psychosim.com`.
