# Local case and session lifecycle

The browser loads the bundled fictional scenario, applies validated actions
through the deterministic core, records terminal outcomes in local history and
updates local career progression once. Saved actions and history are checked
by replay before restore. A completed session cannot silently accept another
turn; beginning a new session is explicit.

The reusable `CaseLifecycle` schema retains `pool`, `owned`, `hospitalized`,
`cured` and `archived` states for core simulations. In the static game these are
local fictional state, not a distributed owner record. Crisis, cure and walkout
behavior comes from the existing turn resolver; multi-session history carries
only the core's defined persistent fields.

No global pool, ownership lease, referral server or cross-player exclusivity
exists. Do not interpret a local schema identifier as online authority. The
browser saves complete dialogue separately from structured core history;
stateless/persistent manifest rules still govern the core history envelope.

See [game rules](GAME-RULES.md), [implemented mechanics](../reports/implemented-gameplay-rules.md),
and [data lifecycle](../project/DATA-LIFECYCLE.md). Current browser tests cover
terminal history, duplicate completion prevention, corrupt restore and conflicting tabs.
