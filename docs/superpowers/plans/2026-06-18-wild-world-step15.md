# Wild World — Step 15: Analytics Instrumentation + the `T_current` resolution (FINAL Phase-4 step)

Branch `step-15-analytics`. Phase 4, Step 15 of `03_BUILD_PLAN.md` — the final step, **rigor-critical** on
**measurement integrity** (the metrics drive the launch decision: D1 > 25% target / ~15% floor). Consolidates
the ~30 existing telemetry hooks into a typed taxonomy, adds the retention substrate (D1/D7/D30), surfaces
the dual-loop balance as a **measured** metric, and **resolves the `T_current` seam**.

## Inherited substrate (consolidate onto it; do NOT re-instrument)

- The `Adapters.telemetry(metric, value)` sink + ~30 `incr(...)` hooks at their event points; the
  `Fakes.newTelemetry` (`incr`/`snapshot`) for tests.
- `Onboarding` BEATS + `beatStartedAt` (the funnel drop-off substrate); `Enums.FunnelBeat` order.
- `Economy` §6 reconciliation (by-construction); the `T_current` comments at the idle + daily lines.
- `EffectiveTier.effectiveTier(profile, config, loop)` — already per-loop EHT/EFT.
- The `Ledger` typed/tagged entries (per-faucet Cash truth); the `gauntlet.*`/swap/pay-proof canaries +
  the Step-13 evergreen-sink alarm.
- `SessionService.login/logout` (the session boundaries; where retention timestamps go); `Profile`/`Schema`.

## What Step 15 builds (headless)

1. **`T_current` resolution — ONE function.** `Economy.currentTier(profile, config, loop?)`: `loop` given →
   `EffectiveTier.effectiveTier` (the loop's tier); omitted → `max(EHT, EFT)`. The SOLE definition — idle
   (loop-agnostic → max), the daily quests (per-loop), event rewards (loop-agnostic → max), AND the analytics
   current-tier metric all call it. The daily becomes per-loop: a hunting daily scales to EHT, a fishing daily
   to EFT (a maxed-hunter fishing daily pays EFT-tier, not max — the farming-vector closure). **FLAG for
   Steve**: the at-parity daily total rises by one `dailyQuestReward` vs the old single-entry skeleton (the
   deliberate consequence of resolving the seam; the Step-7 daily amounts were always "economy's to ratify").
2. **Retention substrate.** `firstSeenAt`/`lastSeenAt` on `PlayerData` (server time); `SessionService.login`
   sets them (firstSeenAt once, on the fresh profile) + emits session-start; `logout` emits session-end.
   D1/D7/D30 = PINNED rolling-24h windows from `firstSeenAt` (`Analytics.retentionDay`/`isRetainedOnDay`,
   timezone-free). Cohort rollup = AnalyticsService (ops).
3. **`logic/Analytics.luau` (pure).** The typed event taxonomy (`Category` + a registry `categoryOf` covering
   every existing hook + the new events); the retention classification; the funnel drop-off
   (`funnelDropoff` — lastBeat/dwell/abandon from `onboarding` + the beat order); the **measured** per-loop
   balance (`realizedLoopCash` from the ledger's kill/catch faucets + `perLoopBalanceRatio` = realized ÷
   realized, NOT the modeled tautology); the canary health layer (`healthReport` vs thresholds); typed emit
   helpers (server-values only — measurement integrity). The `Event` type carries NO PII field (the guard).
4. **`Tuning.analytics`** — the D1 target/floor, the retention window, the canary thresholds.
5. **Negative fixture** `analytics_pii.luau` — reading a PII field off `Analytics.Event` fails analysis.

## Cross-cutting invariants (tested)

- **Measurement integrity**: events emit from the server-validated RESULT only; a client-supplied count
  cannot move a metric (no client→emit path; the emit helpers take server values).
- **`T_current` is one function** — no parallel basis; idle/daily/event/analytics all call `currentTier`.
- **Server-time everywhere** — session boundaries + retention windows on server time.
- **The ledger is Cash truth** — per-faucet share + realized loop Cash read the existing tagged entries.
- **No PII** — the event schema is behavioral, keyed by opaque id; no personal field (asserted + fixture).
- **Consolidate, don't duplicate** — one sink, one taxonomy; existing hooks map onto it (no re-emit).

## Out of scope (Studio/ops)

The AnalyticsService aggregation (cohort D1/D7/D30 rollups, funnel-viz, ARPU), the dashboards, the external
pipeline, the live alarm/paging; the wall-clock per-loop active-time accumulation+emission (the session
feeds the headless ratio). No re-instrumentation of existing hooks.

## DoD

`--!strict` clean; Steps 1–14 stay green; the by-construction reconciliation untouched. `T_current` = one
function (per-loop daily / max idle / per-target payout, farming-vector closure asserted); measurement
integrity (client count can't move a metric); retention substrate (server-time, pinned rolling-24h);
funnel drop-off; the realized-÷-realized balance ratio with teeth; the canary layer with thresholds; no PII.
`./run-tests.sh` ALL GREEN. **This is the final Phase-4 step** — MVL feature-complete (Steps 1–15); what
remains is the Studio/ops layer (geometry, UI, platform, dashboards) + playtest tuning.
