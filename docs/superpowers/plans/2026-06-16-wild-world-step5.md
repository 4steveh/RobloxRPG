# Wild World Step 5 — The Fishing System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans or subagent-driven-development. Steps use `- [ ]`.

**Goal:** Build fishing — the second half of the dual loop — by **extending** the Step-4 substrate, not rebuilding it: add the Fishing `describe` branch to the **shared** reward pipeline, **generalize** the spawner cap to single-source the anti-farming math across both loops, and add `Fishing.luau` (the catchability inequality, mirror of `Combat.luau`).

**Architecture:** `Fishing.luau` (pure: §2 `FightTime ≤ LandWindow`, min-tier derivation, Angler XP, drain validators, co-op) + `CatchHandler.luau` (the gauntlet's step-3 fight-resolution hook, mirror of `FireHandler`) + the **one-line** `describe` Fishing branch in `RewardPipeline` + the **generalized** `Spawner` (loop-parameterized, single anti-farming line) + `Spawning.fishing` config. Fight FEEL + the physical bite spawner are Studio-only.

**Tech Stack:** Luau `--!strict`, `./run-tests.sh` gate (analyze + unit + negative fixtures + rojo).

## Global Constraints

- `--!strict` clean; Studio scripts `*.server.luau` (excluded from the gate).
- **Do NOT duplicate** the Reward XOR / atomic-commit / conquest path (extend `describe` only) or the cap `min(...)` math (generalize, single-source). Duplication is the divergence the integrity model forbids.
- **Reward XOR at runtime:** rare catch → one mint, no Cash; routine → Cash via the Step-4 stub `Payout`; never both.
- **`EFT = min(rod, reel)`**; the spread-growth constant is **inherited from combat** (RD-F), not forked.
- **Bite-density cap is economy-critical** — the fishing instance of the anti-farming invariant, via the shared `Spawner` ceiling.
- **No death, no armor, no respawn** on the fishing side — losing the fish is the only failure, non-punitive (no banked Cash/inventory loss).
- **Server-authority absolute**: client sends inputs; server simulates/validates the bite, fight, and landed fish.
- **Bayou scope only.** Assert the T1 routine band; Appalachia/Alaska + reconciliation/difficulty are **owed at Step 10** (no premature cross-tier).
- **The Step-4 hunting tests must stay green** (the shared path must not regress).

## Binding numbers (all present in `Tuning` already, except the two new tables)

- Reel curve (weapon-analog): `ReelDrainMax(T,ℓ) = round(R1·ρ^(T−1)·q(ℓ))`, `R1=9` (`Tuning.offensive`).
- Rod curve (armor-analog): `BreakThreshold(T,ℓ) = round((rodP1 + rodPStep·(T−1))·rodPq(ℓ))`, `rodP1=30, rodPStep=22` (`Tuning.defensive`); `landWindowW=1.0`.
- `Tuning.fishingFight`: `k_s=0.5, W_ref=10, r(FishRecovery)=0.08, p(PeakRunForce)=0.6, E_expected=0.7` (+ **new** `dragSmooth=1.0`).
- **New `Tuning.fishing.engagement`** (SYS_fishing §5): T1 `{timeToBite 20, fightTime 18, overhead 22}` → 60/hr; T2 `{32,38,25}`; T4 `{55,80,30}`.
- **New `Tuning.fishing.rankXP`**: `{base 10, tierStep 0.5, rarityWeight {…}, fightDifficultyDivisor 100}` (Angler XP = tier × rarity × fight-difficulty).
- **`Spawning.fishing` (LOC §8.4)**: Bayou areas `channel_banks {3, 30s}`, `catfish_hole {2, 30s}`; `ceilingPerHour 65` (~60–70 band).

**Derivation check (routine Bayou fish, mid gear, E_expected 0.7) — derived == authored `1/1`:**
- Bluegill FD20 w0.5 → ft 2.23 ≤ lw 18 ✓; Bullhead FD28 w2 → ft 4.14 ≤ lw 13.2 ✓; Channel FD32 w6 → ft 6.84 ≤ lw 10.8 ✓; **Blue Catfish FD34 w9 → ft 9.02 ≤ lw 9.6 ✓** (milestone).
- **Rares excluded from the derivation assert** (RD5: bonus-on-top finds): the **Leviathan** (w 20–40) intentionally exceeds the T1 fight model (a "find", not a band target — LOC "the difficulty is reaching the condition, not the fight"). Assert routine Common/Uncommon Bayou fish only.

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `src/types/Schema.luau` | Modify | Add `spawnZones: { string }?` to `Fish` (the only schema gap; fight inputs already present). |
| `src/config/Fish.luau` | Modify | Thread `spawnZones` through the builder; populate the 6 Bayou fish → `channel_banks`/`catfish_hole`. |
| `src/config/Tuning.luau` | Modify | Add `Tuning.fishing` (engagement + rankXP); add `dragSmooth=1.0` to `fishingFight`. |
| `src/config/Spawning.luau` | Modify | Add `.fishing` for Bayou (bite caps + ceiling). |
| `src/logic/Fishing.luau` | **Create** | Pure: reel/rod curves, StaminaToLand/NetDrain/FightTime/LandWindow/landable, `deriveMinTiers`, `anglerRankXP`, `drainDerivable`/`tensionLegal`, `coopNetDrain`, `gearLevelOf`. |
| `src/logic/Spawner.luau` | Modify | **Generalize**: `engagementFor(loop)` + a single `ratePerHour` (the one anti-farming line); add optional `loop` to `expectedTargetsPerHour`/`realizedRoutineRatePerHour`/`routineTargetsInZone`/`validatePlacement` (default Hunting → Step-4 callers unchanged); generalize `rareSpawnEligible` to a structural conditions-bearer (Creature **or** Fish). |
| `src/config/Validation.luau` | Modify | Assert `Fishing.deriveMinTiers == authored` for routine Bayou fish; assert all Bayou fish carry `spawnZones`. |
| `src/config/Shells.luau` | Modify | Call `Spawner.validatePlacement(..., Loop.Fishing)` at load. |
| `src/server/combat/RewardPipeline.luau` | Modify | Replace the `error("TODO(step-5)")` with the Fishing `describe` branch (`config.fish`, `Fishing.anglerRankXP`, `ledgerType "catch"`). |
| `src/server/fishing/CatchHandler.luau` | **Create** | `CatchHandler.new(deps)` → the `catch` gauntlet handler (critical): authority (tackle + bite + basic-bait yes/no) → simulate (tension/drain-spoof + gear-adequacy + landed) → commit (reward pipeline). |
| `src/server/world/FishingService.server.luau` | **Create (Studio)** | Physical bite spawner + spot-depletion + cast/bite/fight RemoteEvents + fight resolution + non-punitive loss. Excluded from the gate; README checklist. |
| `tests/Fishing.spec.luau` | **Create** | Catchability math + derivation + Angler XP + validators + co-op. |
| `tests/Spawner.spec.luau` | Modify | Add a fishing section (rate 60, anti-farming 65, routine excludes rares, placement, rare-takes-no-bait). |
| `tests/RewardPipeline.spec.luau` | Modify | Add a fishing section (routine catch, rare mint, OR-gate idempotent both ways, atomicity); confirm hunting still green. |
| `tests/CatchHandler.spec.luau` | **Create** | Gauntlet end-to-end catch; exploit rejections; OR-gate; critical revert. |
| `tests/run.luau` | Modify | Register `Fishing.spec` + `CatchHandler.spec`. |
| `README.md` | Modify | Step-5 section: extended-not-forked pipeline, generalized cap, headless/Studio split, stubs, playtest checklist. |

## Interfaces

```
Fishing.reelDrainMax(config, tier, level?) -> number          -- mirror weaponDamage (R1 curve)
Fishing.breakThreshold(config, tier, level?) -> number        -- rod Pressure curve
Fishing.staminaToLand(config, fish) -> number                 -- uses typicalWeightKg.max (conservative)
Fishing.fishRecovery(config, fish) / peakRunForce(config, fish) -> number
Fishing.netDrain(reelDrainMax, E, fishRecovery) -> number
Fishing.fightTime(staminaToLand, netDrain) -> number          -- ∞ if netDrain ≤ 0
Fishing.landWindow(config, rodTier, reelTier, fish, rodLevel?) -> number
Fishing.landable(fightTime, landWindow) -> boolean
Fishing.tensionLegal(E) -> boolean ; Fishing.drainDerivable(config, reelTier, level, E, claimed) -> boolean
Fishing.deriveMinTiers(config, fish) -> { minRodTier: number, minReelTier: number }
Fishing.anglerRankXP(config, fish) -> number
Fishing.coopNetDrain(config, baseNetDrain, partySize) -> number     -- shared Tuning.combat.coop
Fishing.gearLevelOf(intraLevel) -> GearLevel

Spawner.expectedTargetsPerHour(config, tier, ceiling, loop?) -> number      -- loop default Hunting
Spawner.realizedRoutineRatePerHour(config, tier, ceiling, activeSeconds, loop?) -> number
Spawner.routineTargetsInZone(config, destinationId, zoneId, loop?) -> { string }
Spawner.rareSpawnEligible(target: {spawn:{conditions:SpawnConditions?}}, world) -> boolean
Spawner.validatePlacement(config, shell, loopSpawn, loop?) -> ()

RewardPipeline.resolve(profile, config, {…, loop = Loop.Fishing}, deps)   -- Fishing branch added
CatchHandler.new({ idGen, payoutFn?, telemetry? }) -> Gauntlet.IntentHandler   -- intent "catch", critical
-- catch payload (server-enriched): { targetId, biteActive, E, claimedDrain, accumulatedStaminaBefore, owner, partySize? }
```

## Tasks (TDD: red → green → `./run-tests.sh` → next)

1. **Fish `spawnZones` + Fish.luau population + `Tuning.fishing`/`dragSmooth`.** Test: `Catalog.fish.bayou_blue_catfish.spawnZones` contains `catfish_hole`; `Tuning.fishing.engagement[1].timeToBite == 20`.
2. **`Fishing.luau` curves + catchability + validators + co-op.** Tests: `reelDrainMax(1,"mid")==9`, `breakThreshold(1,"mid")==30`; `staminaToLand`/`fightTime`/`landWindow`/`landable` for blue catfish (ft 9.02 ≤ lw 9.6); `tensionLegal`/`drainDerivable` (spoof rejected); `coopNetDrain` sublinear+capped.
3. **`Fishing.deriveMinTiers` + `anglerRankXP` + Validation assert.** Tests: `deriveMinTiers` == `{1,1}` for the 4 routine Bayou fish; `anglerRankXP` positive + a Mythic > a Common; the load-time assert passes (routine band) and a mutated-FD fish would diverge.
4. **Generalize `Spawner`.** Tests (fishing): `expectedTargetsPerHour(…,Fishing)==60`; over-geared realized == 65 (ceiling, anti-farming); `routineTargetsInZone(…,Fishing)` includes the catfish, excludes the rares; `validatePlacement(…,Fishing)`; `rareSpawnEligible(leviathan,…)` ignores bait. **Step-4 hunting Spawner tests unchanged.**
5. **`Spawning.fishing` + Shells fishing placement call.** (Folded into Task 4's green.)
6. **RewardPipeline Fishing `describe` branch.** Tests: routine fish → one `catch` ledger entry + Angler XP, no mint; rare fish → one mint + no Cash; **OR-gate** (gator-then-blue-catfish and reverse leave `bayou` conquered once, `conquestNewlySet` false the 2nd time); atomicity (forced save fail → no orphan). **Hunting tests unchanged.**
7. **`CatchHandler.luau`.** Tests: valid catch (mid gear) → reward + projection; drain-spoof / illegal-tension / no-bite / missing-bait / gear-insufficient rejected; OR-gate via the handler; critical write-through fail → revert (no orphan).
8. **`FishingService.server.luau`** (Studio sketch; not analyzed) — bite spawner + spot-depletion + cast/bite/fight + non-punitive loss; `TODO` premium bait (14), bait shop/grant (6/7), Boats (11), first-bite bypass (7).
9. **Wire specs + README + final gate.** `ALL GREEN ✓`.

## Self-Review (spec coverage)

- Fishing verb / fight resolution / anti-exploit / non-punitive loss / basic-bait check → Tasks 2,7,8. ✓
- `Fishing.luau` catchability + derivation + EFT=min(rod,reel) + inherited spread constant → Tasks 2,3. ✓
- Reward pipeline extended (one `describe` branch, not forked) + OR-gate shared flag → Task 6. ✓
- Spawner generalized (single anti-farming line, not duplicated) + bite caps + condition-gated rares (no bait) → Tasks 4,5. ✓
- Co-op (generic, not Bayou-load-bearing) → Task 2. ✓
- Telemetry (dual-loop drift via the shared pipeline metrics; fishing-rate handoff) → Tasks 6,8 + README note. ✓
- Deferred NOT built: real Payout (6), shops/premium bait (6/14), Boats (11), first-bite bypass (7), gate consume (9), Alaska/reconciliation/difficulty (10), LiveOps (13). ✓
- Fight feel is Studio, reported honestly. ✓
