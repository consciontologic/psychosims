# Phase 2 Exit Report — Deterministic Game Core (offline)

**Date:** 2026-07-14
**Scope:** Phase 2.4–2.10 implementation
**Scope now retained:** pure-core component and historical tuning evidence.
The browser product uses its own save implementation. Retired native persistence
and its tests were removed under explicit user authorization on 2026-10-23;
current acceptance is in the [PWA report](2026-10-23-static-pwa.md).

## What was delivered

- **2.4 Multi-session siege, clue ownership & clinical grading**
  - `ClinicalEncyclopedia`, `CaseHistoryEnvelope`, `StudyCatalog` schemas.
  - `MultiSessionDigestCompiler`, `MultiSessionResolver`, `StudySpend`, `ClinicalGradingCalculator`.
  - `memory_class` discipline enforced: stateless cases carry no history envelope.
  - Integration test: two-session siege unsolvable in one, solvable after study.

- **2.5 Progression, multi-currency economy & attraction vector**
  - `CareerProfile`, `LedgerEvent`, `CurrencyType`, `FieldTrainingTree` schemas.
  - `XpCurve`, `ReputationDecay`, `Ledger`, `AttractionVector`, `OnboardingTrack`, `FieldTrainingSpend`.
  - `ProgressionConfig` in the centralized config authority.
  - Conservation invariant tested: balances equal replayed events.

- **2.6 Financial stabilizers, operational pressure & recovery**
  - `RecoveryMode`, `OperationalPressure` schemas.
  - `RecoveryController`, `PressureCalculator`, `CooldownTracker`.
  - `RecoveryConfig` in the centralized config authority.

- **2.7 Clinic operations, economy & offline case router**
  - `ClinicAsset` schema; `ClinicEconomy` for rent/buy/sell/overhead/taxes/audits.
  - `OfflineCaseRouter` with deterministic PRNG seeding, social-chronic bias, tenure-gated chaos roll.
  - `StrategicExitResolver` for reject/refer/force choices.
  - `ClinicConfig` in the centralized config authority.

- **2.8 Balance sandbox, solvability oracle & bot simulation**
  - `BotPlayer` with configurable novice/intermediate/expert skill policies.
  - `ScenarioRunner` and `BalanceSandbox` run thousands of core-only sessions with no model binary.
  - `ScenarioDistribution` reports win-rate and turn-count distributions with median/p95 on an integer basis-point contract.
  - `SolvabilityOracle` verifies core-only solvability and content compliance.
  - `tools/balance_sandbox_cli.dart` headless CI runner emits JSON diagnostics and checks a throughput budget.
  - `test_fixtures/regression_scenarios.json` provides seed-keyed golden runs for byte-identical replay.
  - `CardBalance.fromConfig(BalanceConfig)` wires all balance constants through the central config authority.
  - C-4 `BALANCE-SPEC.md` updated with first tuned values and sandbox findings.

- **2.10 Offline case corpus & Phase 2 balance/solvability exit report**
  - Representative offline corpus spans the four card types, capped loadout, fictional pharmacology, lifecycle branches, and multi-session siege cases.
  - Every committed manifest passes the content-integrity lint and the 2.8 solvability oracle with no LLM present.
  - This report records the economy / solvability findings and the explicit go/revisit decision.

## Test results

| Package | Tests | Result |
|---|---|---|
| config | +7 | ✅ |
| packages/psychemas | +12 | ✅ |
| packages/psycore | +150 | ✅ |

These historical component counts are not current gate totals. The current
`make verify` result is recorded in the PWA report.

## Economy / solvability observations

Sandbox diagnostics (median over 60 bot runs, 2 manifests, 3 skill levels):

| Metric | Value |
|---|---|
| Overall win-rate | 83 % |
| Novice / Expert win-rate on `poc-vexa-001` | 100 % |
| Intermediate win-rate on `siege.brumosis` | 50 % |
| Sandbox throughput | >1 000 sessions/second |
| Active card slots | 6 |
| Postponing freeze | 2 turns |
| Success progress threshold | 100 |

- Ledger conservation invariant holds: `Ledger.balance` equals replay of `Ledger.events`.
- Offline router seed is deterministic for a fixed profile + cursor + root seed.
- Siege manifest is mechanically solvable and content-compliant.
- First C-4 tuning pass recorded in `docs/specs/BALANCE-SPEC.md`; placeholder XP/reputation curve shapes remain and will be finalized as more content lands.
- Dead-currency flags in the proxy economy (`study`, `xp`, `subspecialty`, `prestige`) are expected: the sandbox proxy only models session rewards + cash overhead. The proxy results do not measure a complete player economy or prove that every
  design currency has a current browser sink.

## Current use

Retain these pure rules, schemas, fixtures and headless tools as reusable game
logic. This report does not authorize a server implementation or publication.
The active [roadmap](../planning/ROADMAP.md) and PWA report define current scope.
