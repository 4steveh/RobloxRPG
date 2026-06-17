# Wild World Step 7 — The Onboarding Funnel — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Build the first-five-minutes funnel's **thin headless core** — a server-owned, data-driven `OnboardingState` machine that advances on *authoritative* events inside the existing handlers' atomic commit, a scoped first-spawn **eligibility predicate**, the no-real-money gate, and the daily-quest **skeleton** — with the deferred economy amount functions. The felt FTUE + every D1 metric are Studio/telemetry.

**Architecture:** `Onboarding.luau` (pure, data-driven beats + `advance`/`firstSpawnEligible`/`isOnboardingComplete`) + `Daily.luau` (daily-objective state + reset) called **inside** `FireHandler`/`CatchHandler`/`ShopHandler` commits (atomic with the reward, idempotent), plus a `ClaimDailyHandler`. Economy gains `dailyQuestReward`/`crossLoopBonus`. State lives in the session-locked `PlayerData`.

**Tech Stack:** Luau `--!strict`, `./run-tests.sh` gate.

## Global Constraints
- **Server-authority absolute** — beats advance only on validated kill/catch/`gearUpgrade`/claim events, never a client flag; one-shot + idempotent (like an unlocked Destination); rewards via the idempotent ledger.
- **Atomic with the reward** — `Onboarding.advance` is a headless step inside the handler's `Transaction` (a failed save reverts the beat advance too). NOT in the `.server` services.
- **First-spawn override is tightly scoped** — first-of-each-loop, arrival-area, first-time player only; caps hold for everything else (the headless piece is the eligibility *predicate*; the spawn is Studio).
- **No real-money surface pre-`COMPLETE`** — expose `isOnboardingComplete`; Step 14's store gates on it.
- **Every Cash value is economy's** — Step 7 adds the deferred *amount functions*, authors no figures.
- **Daily reset basis is a new server-time field** — keyed off `deps.clock.now()`, never client elapsed; no collision with `logoutTimestamp`/`lastSaveTimestamp`.
- **`WORLD_MAP` is pass-through here** — Step 9 swaps the pass-through for the real reveal + predicate.
- Steps 1–6 tests stay green.

## Beat chain (data-driven, in `Onboarding.luau`)
`FIRST_HUNT` —(kill)→ `FIRST_CATCH` —(catch)→ `FIRST_PURCHASE` —(gearUpgrade)→ `WORLD_MAP` (pass-through) → `LOOP_CONFIRM` —(3× kill/catch)→ `DAILY_INTRO` —(dailyClaim)→ `COMPLETE`.

## File Structure
| File | Action | Responsibility |
|---|---|---|
| `src/types/Enums.luau` | Modify | Add `FunnelBeat` union + frozen table. |
| `src/types/Schema.luau` | Modify | Add `OnboardingState` + `DailyState` types; add `onboarding`/`daily` to `PlayerData`. |
| `src/logic/Profile.luau` | Modify | `freshProfile` seeds `onboarding` (FIRST_HUNT) + `daily`. |
| `tests/util.luau` | Modify | `mkProfile` seeds `onboarding`/`daily` (so every test profile is valid). |
| `src/config/Tuning.luau` | Modify | Add `economy.dailyQuestFraction = 0.25`, `economy.crossLoopBonusHours = 0.5`. |
| `src/logic/Economy.luau` | Modify | `dailyQuestReward(config, tier)`, `crossLoopBonus(config, tier)`. |
| `src/logic/Onboarding.luau` | **Create** | Data-driven beats; `advance(profile, eventKind, now)`, `firstSpawnEligible(config, profile, dest, area, loop)`, `isOnboardingComplete(profile)`. |
| `src/logic/Daily.luau` | **Create** | `maybeReset(daily, now)`, `recordAction(daily, loop, now)`, `canClaimCrossLoop(daily)`. |
| `src/server/daily/ClaimDailyHandler.luau` | **Create** | intent `claimDaily` (critical): credits `dailyQuestReward`+`crossLoopBonus`, sets claimed, advances `DAILY_INTRO`. |
| `src/server/combat/FireHandler.luau` | Modify | commit: capture resolve result; if not ambiance → `Onboarding.advance(.., "kill", now)` + `Daily.recordAction(.., Hunting, now)`. |
| `src/server/fishing/CatchHandler.luau` | Modify | commit: `Onboarding.advance(.., "catch", now)` + `Daily.recordAction(.., Fishing, now)`. |
| `src/server/shop/ShopHandler.luau` | Modify | upgrade commit: `Onboarding.advance(.., "gearUpgrade", now)`. |
| `src/server/world/HuntingService.server.luau` / `FishingService.server.luau` | Modify (Studio) | consult `firstSpawnEligible` before a guaranteed first spawn (sketch). |
| `tests/Onboarding.spec.luau` | **Create** | chain, idempotent one-shot, pass-through, firstSpawnEligible, isOnboardingComplete, atomic-with-reward via FireHandler. |
| `tests/Daily.spec.luau` | **Create** | reset (server-time), recordAction, claim pays both once (idempotent), needs both loops. |
| `tests/Economy.spec.luau` | Modify | dailyQuestReward / crossLoopBonus amounts + scaling. |
| `tests/Profile.spec.luau` | Modify | freshProfile starts at FIRST_HUNT, not complete. |
| `tests/run.luau` | Modify | register Onboarding.spec + Daily.spec. |
| `README.md` | Modify | thin-headless-vs-Studio/telemetry split; WORLD_MAP→Step 9 seam; daily/store/idle deferrals; A/B knobs. |

## Interfaces
```
Onboarding.advance(profile, eventKind: ("kill"|"catch"|"gearUpgrade"|"dailyClaim"), now) -> { advanced: boolean, beat: string }
Onboarding.firstSpawnEligible(config, profile, destinationId, areaId, loop) -> boolean
Onboarding.isOnboardingComplete(profile) -> boolean
Daily.maybeReset(daily, now) -> () ; Daily.recordAction(daily, loop, now) -> () ; Daily.canClaimCrossLoop(daily) -> boolean
Economy.dailyQuestReward(config, tier) -> number ; Economy.crossLoopBonus(config, tier) -> number
ClaimDailyHandler.new({ telemetry? }) -> Gauntlet.IntentHandler   -- intent "claimDaily", critical
```

## Tasks (TDD)
1. **Enums.FunnelBeat + Schema (`OnboardingState`/`DailyState` + PlayerData fields) + freshProfile + mkProfile seeds.** Test: `freshProfile.onboarding.funnelBeat == "FIRST_HUNT"`, daily zeroed.
2. **`Economy.dailyQuestReward`/`crossLoopBonus` + Tuning fractions.** Test: `dailyQuestReward(1)=250`, `crossLoopBonus(1)=500`; scale with tier.
3. **`Onboarding.luau`** — beats + advance + firstSpawnEligible + isOnboardingComplete. Tests: full chain; mismatched event no-advance; pass-through (gearUpgrade → LOOP_CONFIRM); idempotent COMPLETE; firstSpawnEligible the 6 cases; isOnboardingComplete.
4. **`Daily.luau`.** Tests: maybeReset on a new server-day clears flags; recordAction sets hunt/fish; canClaimCrossLoop needs both.
5. **Wire handlers** (FireHandler/CatchHandler/ShopHandler commits) — advance + recordAction. Tests: a kill via FireHandler advances FIRST_HUNT→FIRST_CATCH **atomically** (failed save reverts the advance + reward); Steps 4–6 tests green.
6. **`ClaimDailyHandler`.** Tests: claim pays `dailyQuestReward`+`crossLoopBonus` once, advances DAILY_INTRO→COMPLETE; second claim rejected (idempotent); rejected when a loop objective is missing.
7. **Studio hooks** (HuntingService/FishingService consult `firstSpawnEligible`) — sketch, not analyzed.
8. **Wire specs + README + final gate.**

## Self-Review (spec coverage)
- `OnboardingState` machine (config-driven, server-auth, atomic, idempotent, resume) → Tasks 1,3,5. ✓
- First-spawn eligibility predicate (no farming leak) → Task 3. ✓
- No-real-money gate (`isOnboardingComplete`) → Task 3. ✓
- Daily skeleton (board claim + cross-loop pair + faucet) → Tasks 2,4,6. ✓
- Economy amounts deferred → Task 2. ✓
- WORLD_MAP pass-through (Step 9 seam) → Task 3. ✓
- Deferred: World Map surface (9), daily content (13), store/real-money (14), idle intro (session 2), co-op (later), the felt FTUE + D1 telemetry (Studio). ✓
