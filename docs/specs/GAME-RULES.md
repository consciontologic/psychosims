# Session rule model

This specification preserves the shapes of the deterministic mechanics in
`packages/psycore/`. [BALANCE-SPEC](BALANCE-SPEC.md) owns the numeric design
reference; source configuration and current tests are the executable contract.
The [core mechanics report](../reports/implemented-gameplay-rules.md) describes
implemented behavior, including library capabilities beyond the current browser UI.

The pure core computes state and outcomes. Patient dialogue supplies voice only;
validated model text cannot change rewards, rules or state independently.
The [local lifecycle](PATIENT-LIFECYCLE.md), [prompt budget](PROMPT-TOKEN-BUDGET.md)
and [fictional content rules](../code/CONTENT_INTEGRITY.md) own their boundaries.

Values quoted as placeholders describe the original rule shape; preserve them
as design context and use the tuned/configured values for actual play.
New browser sessions use ruleset `0.2.0`; saved `0.1.0` sessions retain their
original replay until the player explicitly chooses New game.

## 1. Session state model (`SimState`)

The typed state is owned by the core.
All fields are **bounded integers or fixed-point** and are **clamped to
range after every applied delta** — no float, no wall-clock, no ambient
randomness.

| Field | Type / range (shape) | Meaning |
|---|---|---|
| `trustScore` | int `[0, MAX_TRUST]` | therapeutic alliance |
| `agitationLevel` | int `[0, MAX_AGITATION]` | acute distress / crisis pressure |
| `activeDefense` | enum (fixed catalogue) | the patient's current defensive posture |
| `sessionProgress` | int `[0, 100]` | accumulated session pace; not sufficient by itself for current success |
| `turn` | nonnegative int | accepted choices; current sessions end by turn 16 |
| `approachMask` | bounded bit mask | accepted approach history used for current rapport/exploration gates |
| `medicationState` | typed | prescribed fictional-drug tokens, dosage band, tolerance, dependency |
| `clueProgress` | set of collected clue tokens | drives siege / breakthrough design |

Ranges (`MAX_*`) are **shapes**; the exact caps are BALANCE-SPEC values. The
state serializes through canonical schemas and is replayed when restoring
a browser save.

## 2. Card-resolution band function

Every card play resolves through one function shape:

1. **Context-fit** `fit ∈ {aligned, partial, mismatched}` is computed from the
   card's `signature` against the current state (`trustScore`, `agitationLevel`,
   `activeDefense`) and the patient's axes.
2. Each card type has a **base effect vector** over the state fields.
3. The **band** (the spread of the deterministic draw around the base) is
   **narrow and favourable when `aligned`**, and **widens and shifts unfavourable
   as fit degrades to `partial` then `mismatched`**.
4. Resolution: `draw = prng.nextInt(width)` (integer only); the applied
   delta = `base ± g(draw, band)`. Aligned → tight band centred on the strong
   effect; mismatched → wide band centred lower and less predictable.

This is the **signature principle** made mechanical: a card is strong and
predictable *in-context*, weaker and less stable *out-of-context* — reading the
scene beats memorising a deck. The band widths, centres, and the `fit` cut-points
are **BALANCE-SPEC numbers**; the *function form* is owned here. Fixed `(state, card,
seed)` → fixed `fit` → fixed band → **byte-identical** outcome.

## 3. The four card types (functional roles)

Each type is a role, not a fixed win/lose button. Numbers are BALANCE-SPEC.

| Type | Signature context (aligned when…) | Primary effect | Special rule |
|---|---|---|---|
| **Disclosing** | a truth/insight is "due" (defense crackable) | large `agitation↓`, `trust↑`, cracks defense, emits due clue | breakthrough tool |
| **Relatable** | rapport-safe, trauma not yet touched | small `trust↑` (placeholder +2..+5), prevents crisis | buffer / stall while gathering clues |
| **Postponing** | crisis pressure needs to be bled off | freezes state 1–2 turns (placeholder) | **multi-session decay**: repeated use raises *baseline* starting agitation across sessions (injected clock) |
| **Manipulative** | defense too rigid for rapport, trust high enough to gamble | three-way partition (below) | high-risk; future Doubt transfer mechanics are not active |

## 4. Manipulative three-way partition

A Manipulative play partitions on **trust state** (and accumulated leverage) into
three deterministic outcomes:

- **Success** (high-trust band): defense shattered, hidden insight / core node
  unlocked, can bypass a study-gate.
- **Partial** (mid band): a new vulnerability exposed, patient more unstable, next
  turn more dangerous.
- **Derangement** (low-trust band): proposes a **derangement mutation as a bounded,
  enumerated structured delta** — a selection from a fixed catalogue of
  secondary-pathology states, **never free text and never an in-place manifest
  rewrite**. The local deterministic result has no cross-player authority;
  a server-derived Trauma Severity multiplier is not part of this product.

The partition **cut-points are BALANCE-SPEC numbers**; the three-way shape and the
enumerated-delta rule are owned here.

## 5. Outcome engine (turn → {succeed, fail, stabilize, crisis})

After a play's delta is applied and clamped, ruleset `0.2.0` checks in order:

1. **fail** — agitation reaches the walkout threshold (95).
2. **succeed** — at least 12 choices, progress 100, trust at least 50, agitation
   at most 35, and both Validate and an exploration approach (Open question or
   Reframe) have been used.
3. **fail** — turn 16 is reached without success; archive for review without
   success rewards.
4. **crisis**, **stabilize**, or **ongoing** — retain the pressure/rapport
   classifications below while the bounded session continues.

A fresh carried-over session may begin under walkout pressure. Its first
action must resolve into recovery or an explicit terminal outcome; only a
previously completed session rejects further actions. Set boundary reduces
pressure, while Validate rebuilds rapport; their numeric effects are in
[BALANCE-SPEC](BALANCE-SPEC.md).

Legacy `0.1.0` and PoC replay retains this original ordering:

1. **fail** — agitation reaches the configured walkout threshold.
2. **crisis** — agitation reaches the configured crisis threshold.
3. **succeed** — progress reaches the configured success threshold.
4. **stabilize** — agitation is at/below the calm threshold and trust is at/above
   the stable-trust floor.
5. **ongoing** — continue when no condition above holds.

Threshold numbers belong to BALANCE-SPEC and configuration. Clues and defense
remain important scene/design inputs, but they do not replace this implemented
classification order. The engine is pure and replay-stable.

## 6. Transference Spike & reclassification

In a high-trauma state, **Relatable plays reclassify as Manipulative plays** when
the configured trauma and agitation guards hold. The resulting trust partition
still resolves deterministically. This is driven by core state, never the model.

## 7. Fictional pharmacology model

- **Prescribe** a fictional-drug token (drawn from the fictional-taxonomy
  registry; passes the no-real-label lint) at a dosage band.
- **Tolerance** accrues per dose; **dependency** accrues under sustained dosing;
  both are typed integer fields on `medicationState`.
- Each drug **class** has a **side-effect vector** that shifts *case pressure /
  pacing* (e.g. dampens agitation now, raises baseline later) — resolved by the
  core.
- The medication **style filter changes dialogue delivery only**. The separate
  core pressure/pacing shift can affect later outcome thresholds; model wording
  cannot override that mechanical effect.
- A `persistent`-`memory_class` case **inherits chemical dependency from its
  history**, feeding multi-session carry-over and the core over-medication audit.

Effect magnitudes, tolerance/dependency rates, and side-effect vectors are **BALANCE-SPEC
numbers**; the model (what accrues, what it feeds, the rules/dialogue split) is owned here.

## 8. Progression & economy curve *shapes* (numbers → BALANCE-SPEC)

Only the *forms* live here; every coefficient and table entry is a BALANCE-SPEC value.

- **difficulty → XP**: monotone-increasing, **convex** (a harder case is worth
  proportionally more), with **diminishing returns** on grinding trivial cases.
  Implemented as an **integer XP-by-tier table** (no float).
- **reputation**: **event-sourced, recency-weighted** (not a lifetime ratio),
  with **decay via an integer decay table** (no float `exp`) and a
  **credential-based floor** of the form `total_study_fields × base_competency_constant`. Recency uses the **injected clock**, never the device clock.
- **patient-attraction vector**: `reputation + price-accessibility +
  study-coverage`, surfaced as a **UI readout mean** — explicitly **not** the
  routing function; the reusable offline router has its own deterministic logic.

## 9. Determinism & integrity invariants

- Every rule is **pure**, integer / fixed-point, on the seeded PRNG + injected
  clock — a fixed `(state, action, seed)` replays **byte-identically** across
  architectures.
- State is **clamped to range after every delta**; the economy holds the
  **ledger-conservation invariant** — rounding never mints or destroys value.
- Core outcomes are **structured deltas**. Browser transcripts are separately
  saved local presentation data and never determine mechanics.
- The rule model + PRNG constants are **pinned to `ruleset_version`**: a
  change to any rule *shape* is a tracked ruleset bump, not a silent replay break.

## 10. Separate contracts

Numbers belong to [BALANCE-SPEC](BALANCE-SPEC.md); local history/lifecycle to
[PATIENT-LIFECYCLE](PATIENT-LIFECYCLE.md); prompt assembly to
[PROMPT-TOKEN-BUDGET](PROMPT-TOKEN-BUDGET.md); fictional content to
[CONTENT_INTEGRITY](../code/CONTENT_INTEGRITY.md).

## Core test obligations

- **Card taxonomy:** each type's signature-in-context beats its
  mismatched-out-of-context outcome across seeds; the Manipulative partition splits
  cleanly by trust; determinism is byte-identical for fixed inputs.
- **Outcome engine:** all outcome classifications reached; boundary thresholds
  exercised; a fixed multi-turn case pinned by a golden fixture.
- **Pharmacology:** tolerance/dependency accrue monotonically; medication
  style filtering never overrides mechanics; pressure/pacing effects remain
  deterministic and testable.
- **Curves:** difficulty→XP convex + diminishing; reputation decays, floors,
  and shock-responds; no currency minted/destroyed by rounding.

## Design tuning notes

- Exact band widths, fit cut-points, outcome thresholds, partitions and curve
  tables belong to **[BALANCE-SPEC](BALANCE-SPEC.md)** and source configuration.
- Preserve the current defense enum and case-specific clue conditions when
  changing content; validate against the current core fixtures.
