# Determinism contract

The pure core (`packages/psycore/`) guarantees that fixed state, action and seed
produce the same structured outcome. This supports save replay, mechanical
solvability tests and consistent gameplay across Dart VM and JavaScript.

All nondeterminism is injected: `SeededPrng` provides seeded randomness and
`InjectedClock` supplies testable time. No wall clock, ambient randomness or
platform-dependent floating point belongs in pure rules code. There is no online
server clock or ownership-lease reconciliation in the browser game.

Currency, ratios and percentages use integer/fixed-point arithmetic. Full-width
PRNG values, derived seeds and overflow-sensitive intermediates use `BigInt` to
preserve exact 64-bit behavior under JavaScript. JSON boundaries requiring full
precision use decimal strings rather than rounded JavaScript numbers.

`packages/psycore/test/` covers deterministic outcomes, seed derivation,
fixed-point rounding and replay. `scripts/web_core_parity.sh` compares the
committed pre-port trace with current VM and compiled JavaScript execution.
The [PWA report](../reports/2026-10-23-static-pwa.md) records accepted evidence.
