# Implemented deterministic core mechanics

This is a retained reference to the reusable `psycore` and `psychemas` library
mechanics, with superseded deployment assumptions removed on 2026-10-23.
It is **not a list of screens or online features in the current PWA**. The browser
exposes the preserved scenario/session/loadout/history and local career loop;
[game design](../design/STARTER.md) describes that playable scope.

Core source: [turn resolver](../../packages/psycore/lib/src/turn_resolver.dart),
[balance](../../packages/psycore/lib/src/card_balance.dart),
[schemas](../../packages/psychemas/lib/src/), and
[current browser session](../../app/lib/browser/browser_session.dart).
The detailed legacy library values below are retained; current configuration and tests
remain authoritative. Original pure-core evidence is in the
[showcase](showcase/phase2/INDEX.md).

## Current browser progression (0.2.0)

New sessions use the [bounded pacing rules](../specs/BALANCE-SPEC.md#current-browser-sessions-ruleset-020):
healthy state plus validation/exploration can succeed after 12 choices; every
session ends by 16. Repeated Validate alone no longer wins, and crisis has a
viable boundary/validation recovery path. Saved legacy sessions replay their
original rules; New game opts into 0.2.0 without clearing career/history.
The legacy bands and classification below describe 0.1.0, not new sessions.

## 1. The turn engine — the deterministic heart

turn_resolver.dart `TurnResolver.resolve(TurnInput) → TurnOutput` is a **pure function**: seeded PRNG + fixed input fully determine the outcome (no clock, no floats). One turn runs this pipeline:

1. **Guards** (invalid-action defense, all active): loadout ≤ slot cap; card ∈ loadout; card owned in library; action ∈ manifest's available patterns — each throws if violated.
2. **Seed derivation** — per-turn seed from `(caseId, turnIndex, actionName, rootSeed, rulesetProfile)`.
3. **Transference Spike** reclassification (see §3).
4. **Context-fit** computed from signature + state + controllers → `aligned / partial / mismatched`.
5. **Effect band** drawn: `roll = prng.nextInt(width) - width/2`, applied to a type-specific `(width, centre)`.
6. **Medication** side-effects applied.
7. **Session progress** +1.
8. **Outcome classification** + lifecycle transition.

**Effective win/lose conditions** (_classifyOutcome):

| Outcome | Condition | Effect |
|---|---|---|
| `fail` (walkout) | agitation ≥ **95** | terminal loss |
| `crisis` | agitation ≥ **80** | freeze/asylum branch |
| `succeed` (cure) | sessionProgress ≥ **100**, after fail/crisis checks | terminal win |
| `stabilize` | agitation ≤ **25** AND trust ≥ **40**, if not already terminal | good holding state |
| `ongoing` | otherwise | continue |

For the default core balance, progress reaches 100 while agitation must stay
below the crisis/walkout bounds. Trust ≥ 40 is the stabilization condition, not
an additional success requirement. Scenario/runtime configuration may set a
different progress threshold; the current browser uses its configured case rules.

## 2. Card taxonomy & the signature principle

Four types (card.dart), each with a `CardSignature` (breaker/buffer/freeze/gambit). **Context-fit is the whole game**: a card played in-signature gets a **narrow, favorable band**; out-of-signature gets a **wide, unfavorable band**. Real bands from the resolver:

| Type | Aligned `(width, centre)` | Mismatched | Effective role |
|---|---|---|---|
| **Disclosing** (breaker) | `(3, −4)` resistance | `(7, 0)` | Cracks defense; small trust cost. Aligned when resistance ≥ 55. |
| **Relatable** (buffer) | `(3, +3)` trust | `(7, −1)` | Builds rapport / stalls crisis. Aligned when trust ≥ 45 & agitation < 55. |
| **Postponing** (freeze) | `(2, −3)` agitation + sets `freezeTurns=2` | `(6, +1)` | Bleeds off crisis pressure, buys 1–2 turns. |
| **Manipulative** (gambit) | three-way, see §3 | — | High-risk swing keyed to trust. |

**Controllers tilt fit** (therapy_controller.dart): the Focus (Childhood↔Workspace) and Emotional-Delivery (Warm↔Objective) sliders give a deterministic **±1 fit shift** per signature (e.g., Workspace focus improves a Breaker by one band; Warm delivery improves a Buffer). Effective: matching your sliders to the card sharpens the outcome.

## 3. The Manipulative gamble & Transference Spike

**Three-way partition** by trust (_manipulativeVector) — this is the risk engine:

- **trust ≥ 70 → success**: cracks resistance + small trust gain.
- **40 ≤ trust < 70 → partial**: half resistance crack **+ agitation spike** (`+3…`).
- **trust < 40 → derangement**: **agitation + trauma damage** (`traumaDelta +2…`). This is the "manipulate-into-derangement" loop.

**Transference Spike** (_resolveEffectiveCard): if `trauma ≥ 70 AND agitation ≥ 70`, a **Relatable** play is silently reclassified to a **Manipulative gambit** — so in high-trauma states your safe rapport card flips into a gamble. Fully implemented, one deterministic rule.

## 4. Fictional pharmacology

medication_state.dart + _applyMedication. Five fictional drugs; each dosed turn: **agitation += 3 + tolerance/10**, **tolerance += 2**, **dependency += 1** (all clamped 0–100). Effective: medication is a **pressure/pacing lever with a rising cost** — the more you lean on it, the more agitation it adds (tolerance feedback). The core pressure shift can affect outcome thresholds; the dialogue style filter cannot override mechanics. Dependency is carried across sessions and penalizes the grading report (§6), but there is **no in-session withdrawal mechanic yet** (see gaps).

## 5. Multi-session siege, digest & grading

- **Carry-over** (multi_session_resolver.dart): only **three axes persist** between sessions — trauma, medication tolerance, dependency — plus enumerated **derangement mutations** and accumulated **Postponing decay** (raises next session's starting agitation, capped at 40). Everything else resets. This is where the "stall now, pay later" and "layered case" depth actually lives.
- **History digest** (multi_session_digest_compiler.dart): a hard **4-sentence cap** so the prompt stays budget-bounded no matter how many sessions accumulate — a tested invariant.
- **Attending Physician grading** (clinical_grading_report.dart): scores three dimensions deterministically from the receipt's ordered deltas — **Therapeutic Alliance** (trust net + relatable bonus − mismatched-manipulative penalty), **Diagnostic Path Efficiency** (card-type versatility + disclosure − postponing), **Pharmacological Safety** (`100 − dependency×10 − tolerance×3`).

## 6. Progression & economy

| System | File | Effective behavior |
|---|---|---|
| **XP curve** | xp_curve.dart | Difficulty scales reward per tier; **grinding the same tier past 5 sessions decays reward 0.5× per extra session** (floored 10%). |
| **Study / field tree** | field_training_spend.dart | Two-currency (study+subspecialty) gated unlocks with **single-parent prerequisites**; pure validators, 5–6 result codes. |
| **Reputation** | reputation_decay.dart | **Event-sourced, recency-weighted** via an integer half-life table (1-week half-life, weight halves per bucket, 0 after 4) + a **credential floor** (100 × unlocked fields). Integer-only, no `exp`. |
| **Ledger** | ledger.dart | **Append-only, idempotency-keyed, fixed-point micros**, with snapshot+compaction; balances are always a replay of events (conservation invariant). The browser does not submit this stream to an authority. |
| **Currencies** | currency_type.dart | cash, study, subspecialty, xp, reputation, prestige. |

## 7. Clinic, routing, recovery, pressure

- **Clinic economy** (clinic_economy.dart): rent/buy/sell offices (buy −50 units, resale 70%), monthly overhead, **progressive tax brackets** (0% / 10% / 20%), and **randomized audits** (~5% roll) that penalize over-medication history.
- **Case router** (offline_case_router.dart): weights the case stream by pricing/reputation/field coverage; **social-chronic bias** for low-rep players (~70% gentle stateless cases when reputation ≤ 20); **tenure-gated "Misfortune Roll"** (~5% chaos, only at level ≥ 3, forces a tier-3–5 crisis). Seed+cursor persist → **identical stream after an app restart**.
- **Strategic exit** (strategic_exit.dart): reject (no change) / refer (**+1 XP** ethical reward) / force (**−5 rep, +25 agitation, case lost**).
- **Recovery** (recovery_controller.dart): Discount Practice (**50% XP** when rep ≤ 30) and Academic Sabbatical (restore rep via study fields).
- **Operational pressure** (pressure_calculator.dart): accrues +100/session (+150 for tier ≥ 3), decays 20/day, buckets to healthy/strained/at-risk. Uses the **injected clock** — a device-clock rewind can't dodge it. This remains a local pure-core calculation.

## 8. Integrity & tuning backbone

- **PRNG** (prng.dart): SplitMix64, 64-bit wrapping, **rejection sampling** for unbiased `nextInt`, **integer-only** (no `nextDouble`).
- **Seed derivation** (seed_derivation.dart): FNV-1a + avalanche mix over **stable fields only** — no `DateTime.now()`, no `String.hashCode` leak → replay-identical on any machine/isolate.
- **FixedPoint** (fixed_point.dart): micros scale, **banker's rounding**, **saturating** with checked variants → rounding can't mint/destroy currency.
- **Ruleset versioning** (ruleset_profile.dart): PRNG constants pinned per version; unknown versions throw.
- **Sandbox + oracle + bots** (balance_sandbox.dart, solvability_oracle.dart, bot_player.dart): three skill-tier bots (novice/intermediate/expert heuristics) play thousands of headless sessions **with no LLM**; the sandbox reports win-rate/turns as **median+p95**, flags dead currencies and runaway inflation; the oracle proves each manifest structurally solvable + content-compliant.

## 9. Library limits and unimplemented design

The reusable library does not imply these planned systems are implemented:

- **Medication dependency** accrues and feeds carry-over + grading, but there's **no active in-session withdrawal loop** yet.
- **`ClinicAsset.tier`** exists but **hiring/associate logic is data-only** .
- **Attraction vector** (attraction_vector.dart) is a **UI readout only** — the router uses its own separate logic, not this mean.
- **`TokenCounter` / `ChatTemplate`** remain injected seams. The browser uses a
  conservative UTF-8 byte counter and plain template; there is no native tokenizer.
- **Unimplemented online design:** Trauma Severity multiplier, Doubt transfer,
  macro/environmental events, peer-healer co-op, creator royalties and shared
  patient ownership. These are not active release promises.
