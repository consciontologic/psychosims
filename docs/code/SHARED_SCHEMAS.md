# Shared Dart schemas

[`packages/psychemas/`](../../packages/psychemas/) owns the typed manifest, cards,
loadouts, state deltas, career and case-history contracts consumed by the pure
core and browser application. It has no backend runtime dependency.

The reusable package still contains receipt/history structures used by core
replay and canonical fixtures. Their names do not imply a live receipt endpoint,
signature authority or shared online economy. The browser persists its validated
local snapshot rather than sending progression to a server.

Keep schema changes explicit and update the relevant parsing, canonical JSON and
replay tests in the same change. Save restoration additionally checks bounds and
replayed outcomes; a valid JSON object alone is not a valid saved game.
See [serialization](SERIALIZATION.md), [versioning](VERSIONING.md), and
[data lifecycle](../project/DATA-LIFECYCLE.md).
