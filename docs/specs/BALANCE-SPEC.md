# Balance specification

This document retains the original numeric design values and pure-core tuning
baseline. Actual gameplay consumes typed source configuration; do not duplicate
balance constants in UI code. [GAME-RULES](GAME-RULES.md) owns rule shapes.

The first tables include **design placeholders and unimplemented systems**.
Purchases, creator royalties, hiring and a shared online economy are not browser
features. The tuned table records historical core sandbox results, not a new
balance run or a claim that every core capability has a current UI screen.
No numeric value is changed by the native/server documentation cleanup.

## The currencies

| Currency | Earned by (sources) | Spent on (sinks) | Real-money? |
|---|---|---|---|
| **Clinic currency (cash)** | session fees, cures | rent/overhead, taxes, study points, emergency consultations, offices | no (earned) |
| **Study points** | play, daily login, milestones, sabbatical | core field training tree | purchasable with **in-game currency only** |
| **Subspecialty points** | high-tier play, achievements | advanced cross-disciplinary fields | small play-earned + **hard-capped** real-money top-up |
| **XP** | sessions (difficulty-scaled), milestones | leveling (role/case-tier unlocks) | no |
| **Reputation** | good outcomes (event-sourced, recency-weighted) | decays; floored by credentials | no |
| **Prestige** | endgame milestones, creator royalties | status/legacy unlocks | no |
| **Royalties** | validated fee/cure events on authored cases | paid out in clinic currency + prestige | no (payout, not purchase) |

Every currency must have **both** a modelled source and a modelled sink. The
sandbox runs sources-vs-sinks, inflation, and **dead-currency**
checks before any live tuning ships.

## Placeholder constants (the single registry)

Grouped as they load into config. All values below are **illustrative** and owned here.

### Progression
- Difficulty→XP curve: harder cases worth proportionally more; trivial-grind diminishing returns.
- Study / subspecialty point earn rates + field-tree costs (foundational cheap → advanced expensive).
- Reputation: recency-weighting half-life; credential-based floor formula; event-shock magnitudes.

### Session / cards
- Active Card Slots per loadout: **5–6** (pick one at tuning).
- Relatable trust bump: **+2..+5**; Postponing freeze: **1–2 turns**; Postponing multi-session decay rate.
- Manipulative success/partial/derangement thresholds keyed to trust state.

### Routing / ownership
- Chaos "Misfortune Roll": **~5%**, tenure-gated (does not fire below the new-player threshold).
- Doubt-driven transfer: base **~2–4%/session**, escalating under sustained pressure, hard-capped.
- Social-chronic bias thresholds (early-career level; reputation recovery floor).
- Referral reward: **+1 XP** for ethical referral.

### Economy / recovery
- Discount Practice XP penalty: **50%**; reputation critical threshold that triggers it.
- Academic Sabbatical: `reputation_floor = total_study_fields × base_competency_constant`.
- Trauma multiplier: **hard cap**, chain-decay rate, provenance carve-out window.

### Institutional (endgame)
- Employer yield: **+25%** illustrative, diminishing per associate, firm-wide hard cap.
- Employee skim rate + **2.0×** study multiplier.
- Hire slots: start 1, scale to cap **6**; associate capability ceiling **+5** levels.
- Clinic buy gate (capital + min level); structural-collapse threshold **<20%**.

## Current browser sessions: ruleset 0.2.0

New games close successfully at turns 12–16 only when progress is 100, trust
is at least 50, agitation is at most 35, and the session has used Validate
plus Open question or Reframe. Progress advances by nine points (clamped at
100). A session still missing its goals ends for review at turn 16; agitation
95 still causes an earlier walkout. A review ending grants no success rewards.

Validation builds rapport and eases tension; boundaries now reduce agitation
even with mismatched delivery, at a small trust cost. Reframing retains its
risk before trust is established. The new effect centers by aligned/partial/
mismatched fit are:

| Approach | Trust | Agitation | Resistance |
|---|---|---|---|
| Validate | +6 / +4 / 0, ±1 | −3 / −2 / 0 | unchanged |
| Set boundary | 0 / −1 / −2 | −12 / −9 / −6, ±1 | unchanged |
| Open question | +4 / +2 / 0, ±1 | unchanged | −4 / −2 / 0, ±1 |

An open question can have partial fit once trust is at least 40 and agitation
is below 60 even with low resistance; focus still adjusts fit. The core owns
all changes. AI dialogue cannot decide success or add rewards. Session limits
are pinned in the versioned profile/registry. Old saved action logs continue
to use their original effects, with an explicit New game route to shorter play.

## Retained tuned core values (legacy 0.1.0)

The core balance sandbox ran the deterministic core without inference on the
committed case corpus (`content/manifests/`). Findings and the first tuned
constants are recorded below; config is the single owner of every number.

| Constant | Tuned value | Source / rationale |
|---|---|---|
| Active card slots per loadout | **6** | Sandbox keeps all four card types relevant; 6 gives room for one of each plus flex slots. |
| Postponing freeze turns | **2** | Tempo control is meaningful but not a permanent stall. |
| Success progress threshold | **100** | Single-session cases resolve at the turn cap; multi-session siege cases are authored to require study + return. |
| Crisis threshold | **80** | Visible warning band before walkout at 95. |
| Walkout threshold | **95** | Hard fail floor. |
| Relatable aligned trust bump | **+3 centre, ±1 roll** | Expert bots build trust safely; novice random play still progresses. |
| Disclosing aligned resistance drop | **−4 centre, ±1 roll** | Cracks guarded/rigid defense in 2–3 aligned plays. |
| Manipulative success trust floor | **70** | Gambit is reliable only after rapport building. |
| Manipulative partial trust floor | **40** | Below this, derangement risk rises. |
| Transference Spike trauma floor | **70** | High-trauma Relatable plays reclassify to Manipulative failures. |
| Sandbox cash per win | **1.5 cash units** | Sources exist; overhead sink of 1.0 cash/run keeps inflation flag green. |
| Sandbox overhead per run | **1.0 cash unit** | Proxy for rent/overhead; ensures cash has a sink in the sandbox economy. |

### Sandbox diagnostics (median over 60 runs, 2 manifests, 3 skills)

- Overall win-rate: **83 %** (10 seeds × 3 skills × 2 manifests).
- Novice / Expert win-rate on `poc-vexa-001`: **100 %**.
- Intermediate win-rate on `siege.brumosis`: **50 %** — confirms the siege case
  is not trivially solved by heuristic play and rewards study unlocks.
- Throughput: **>1000 sessions/second** on the reference environment, satisfying
  the historical core throughput target.
- Dead currencies flagged in the sandbox proxy economy:
  study, xp (no sink in the proxy), subspecialty, prestige (no source yet).
  These are expected: the proxy only models session rewards + cash overhead.
  These results do not prove a complete career economy or a current browser sink
  for every design currency.

## Tuning process

1. Load all constants from config (never hard-coded).
2. Run bot scenarios across skill levels + parameter mutations.
3. Check: currency sources vs sinks balance; no runaway inflation; no dead currency;
   no dominant/degenerate strategy.
4. Record tuned values back **here**; config reads them; the sim core consumes config.

## Unresolved design tuning

- Exact difficulty→XP and reputation-decay curve shapes (placeholder shapes remain).
- Whether subspecialty real-money cap is a % of attainable — confirm the %.
- Further clinic-economy tuning (rent, tax brackets) needs a complete career
  study. These open points are retained design context, not an active server or
  publishing milestone.
