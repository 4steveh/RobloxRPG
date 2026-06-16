# Wild World Step 6 — Economy & Shops — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Ship the real economy formulas and replace the three `Payout`/idle **stubs** (idle, hunting, fishing) running since Steps 2/4/5; build the **gear-purchase sinks** (Outfitter/Tackle Shop) as server-authoritative gauntlet handlers; and **prove the dual-loop reconciliation** + the MVL gear-Cash jump (01 risk #3, headless).

**Architecture:** `Economy.luau` (pure: Income/GearCost/IntraTierClimb/Payout/salvageFloor/reconciliation) reads the existing `Tuning.economy` constants. `RewardPipeline`'s default `payoutFn` becomes `Economy.payout` (routine band **normalized per loop** so each loop's routine hour sums to `Income(T)` by construction). `Idle` gets the real amount at `T_idle = max(EHT, EFT)`. Shops mint commodities via a new `Profile.mintCommodity` primitive and debit via `Ledger.attemptDebit`. Shop UI + live (measured) reconciliation are Studio/telemetry.

**Tech Stack:** Luau `--!strict`, `./run-tests.sh` gate.

## Global Constraints

- The constants **already exist** in `Tuning.economy` (`B=1000, g=1.7, c=3, m=2.5`, the rarity ladder, `idleFraction=0.15`, `idleCapHours=8`). Step 6 implements the **functions**, does **not** re-add constants. Only the **salvage floor** is new config.
- **Server-authority over all Cash is absolute** — client asserts no price/balance/credit/debit/idle/milestone; every movement is a server-validated atomic ledger transaction.
- **Band = routine (Common/Uncommon) only; rares are bonus-on-top** (RD5) — and a rare's value is realized at **salvage/trade**, not the kill/catch faucet (the XOR holds; the pipeline mints rares, never pays Cash for them).
- **Payout denominator = the modeled engagement rate** (`3600/(find+active+overhead)`), NOT the ceiling-clamped rate. The ceiling is the anti-farming bound, slack at-tier by design.
- **Dual-loop balance is a derivation, not a coincidence** — assert each loop's normalized routine hour sums to `Income(T)` (true by construction), not a raw hunting≈fishing compare.
- **Idle is idle-proof** — funds the gear half of a gate, never the milestone; single `idle` entry; never Rank XP/conquest.
- **Not-a-timer / no-pay-to-win** — basic ammo/bait trivially priced; no target takeable only with a premium consumable.
- **Bayou + the MVL formula tiers** are in scope; the combat **difficulty** T2→T4 check stays Step 10 (the economy **gear-Cash** jump check is owed here — pure formula).
- **Steps 4–5 tests must stay green** (the reward pipeline now runs real `Payout` through the same XOR/atomic path).

## Findings (from tracing the codebase)

- **The starter-loadout grant EXISTS** in production: `Profile.freshProfile` mints the 3 starter commodities and `SessionService.login` calls it for a new player (`acq.data or Profile.freshProfile`). The prompt's "appears absent" is incorrect — **report it, don't rebuild**. (Step 6 still builds `Profile.mintCommodity` for shop buys.)
- `stubPayout`: defined in `RewardPipeline.luau` (+ default fallback) and asserted in `RewardPipeline.spec` (×2) → replace with `Economy.payout`.
- `Idle.stubAmount`: the `Idle.spec` mechanism tests use it as a deterministic amount-fn (clamp/idempotency/crash-fallback) — **keep it as the mechanism helper**; add `Idle.economyAmount` (real) and switch the `SessionService` default to it; add a focused real-amount test.

## Formulas

```
income(T)                 = B·g^(T−1)                  -- T1 1000 · T2 1700 · T3 2890 · T4 4913
gearCostSlot(T)           = T≤1 ? 0 : c·income(T−1)    -- GearCostSlot(2)=3000, (4)=8670
intraTierClimb(T)         = m·income(T)                -- IntraTierClimb(1)=2500
intraTierUpgradeCost(T,from) = intraTierClimb(T)·(qΔ for that step)/(qMaxed−qEntry)
                            -- entry→mid: ·0.22/0.50=0.44 ; mid→maxed: ·0.28/0.50=0.56  (T1: 1100, 1400)
rarityMultiplier(rar)     = Common 1·Uncommon 1.6·Rare 2.8·Epic 5·Legendary 9·Mythic 16
modeledRate(T,loop)       = Spawner.modeledRatePerHour = 3600/(find+active+overhead)  -- Bayou: 80 hunt, 60 fish
avgRoutineMultiplier(dest,loop) = mean rarityMultiplier over the dest's routine pop (Common/Uncommon, non-ambiance/non-rare)
                            -- Bayou hunt {1,1,1,1.6}=1.15 ; Bayou fish {1,1,1.6,1.6}=1.3
payoutExact(T,rar,dest,loop) = (income(T)/modeledRate(T,loop))·(rarityMultiplier(rar)/avgRoutineMultiplier(dest,loop))
payout(...)               = round(payoutExact)         -- the faucet integer (routine only; rares mint)
salvageFloor(T,rar,loop)  = round(salvageFloorFraction·(income(T)/modeledRate(T,loop))·rarityMultiplier(rar))
                            -- salvageFloorFraction = 0.15 (deliberately low; Step 8 credits it)
routineHourSum(dest,loop) = modeledRate(tier,loop)·mean payoutExact over routine pop  ≡ income(tier)  (by construction)
```

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `src/config/Tuning.luau` | Modify | Add `economy.salvageFloorFraction = 0.15` (the one missing economy value). |
| `src/logic/Spawner.luau` | Modify | Add `modeledRatePerHour(config, tier, loop)` — the uncapped modeled rate (Payout's denominator). |
| `src/logic/Economy.luau` | **Create** | income/gearCostSlot/intraTierClimb/intraTierUpgradeCost/rarityMultiplier/avgRoutineMultiplier/payoutExact/payout/salvageFloor/routinePopulation/routineHourSum. |
| `src/logic/Profile.luau` | Modify | Add `mintCommodity(profile, catalogId, intraLevel) -> Commodity` (fresh `instanceId` from `nextCommodityInstanceSeq`). |
| `src/server/combat/RewardPipeline.luau` | Modify | Default `payoutFn = Economy.payout`; expand `PayoutFn` to `(config,tier,rarity,destinationId,loop)`; pass `d.destinationId`; **remove `stubPayout`**. |
| `src/server/idle/Idle.luau` | Modify | Add `economyAmount(profile,config,hours) = idleFraction·income(max(EHT,EFT))·hours`. |
| `src/server/SessionService.luau` | Modify | Default idle fn → `Idle.economyAmount`. |
| `src/server/shop/ShopHandler.luau` | **Create** | `buyHandler(deps)` (intent `buy`) + `upgradeHandler(deps)` (intent `upgrade`), both `critical`. |
| `tests/Economy.spec.luau` | **Create** | formulas + payout normalization + reconciliation + ceiling slackness + MVL gap + gear-cost-matches-catalog + salvage-floor-is-low. |
| `tests/ShopHandler.spec.luau` | **Create** | buy/upgrade/insufficient/atomic-revert/no-EHT-change-on-upgrade/commodity-mint. |
| `tests/RewardPipeline.spec.luau` | Modify | swap the 2 `stubPayout` asserts → `Economy.payout`. |
| `tests/Idle.spec.luau` | Modify | add an `economyAmount` real-amount test (keep the stub mechanism tests). |
| `tests/Spawner.spec.luau` | Modify | add a `modeledRatePerHour` test (80 hunt / 60 fish uncapped). |
| `tests/run.luau` | Modify | register `Economy.spec` + `ShopHandler.spec`. |
| `README.md` | Modify | Step-6 section: stubs replaced, idle-tier resolution (to ratify), reconciliation/MVL proofs, shop sinks, deferred monetization/salvage-UI. |

## Interfaces

```
Economy.income(config, tier) / gearCostSlot(config, tier) / intraTierClimb(config, tier) -> number
Economy.intraTierUpgradeCost(config, tier, fromLevel: ("entry"|"mid")) -> number
Economy.rarityMultiplier(config, rarity) -> number
Economy.avgRoutineMultiplier(config, destinationId, loop: Loop) -> number
Economy.payout(config, tier, rarity, destinationId, loop) -> number    -- routine, normalized, rounded
Economy.salvageFloor(config, tier, rarity, loop: Loop?) -> number
Economy.routineHourSum(config, destinationId, loop) -> number          -- ≡ income(dest tier), for the reconciliation test
Spawner.modeledRatePerHour(config, tier, loop: Loop?) -> number        -- uncapped 3600/timePerTarget
Profile.mintCommodity(profile, catalogId, intraLevel: number) -> Commodity
RewardPipeline.PayoutFn = (config, tier, rarity, destinationId, loop) -> number  -- default Economy.payout
ShopHandler.buyHandler({ telemetry? }) -> Gauntlet.IntentHandler        -- intent "buy", critical
ShopHandler.upgradeHandler({ telemetry? }) -> Gauntlet.IntentHandler    -- intent "upgrade", critical
-- buy payload: { itemId }            upgrade payload: { commodityInstanceId }
```

## Tasks (TDD: red → green → `./run-tests.sh` → next)

1. **`Tuning.economy.salvageFloorFraction` + `Spawner.modeledRatePerHour`.** Tests: `modeledRatePerHour(1,Hunting)==80`, `(1,Fishing)==60` (uncapped).
2. **`Economy.luau` formulas.** Tests: income 1000/1700/2890/4913; gearCostSlot(2)=3000,(4)=8670; intraTierClimb(1)=2500; intraTierUpgradeCost(1,"entry")=1100,("mid")=1400; rarityMultiplier ladder; **each gating catalog item's `cost.cash` == gearCostSlot(item.tier)** (drift check); salvageFloor(1,Legendary,Hunting) is **low** vs payoutExact×mult.
3. **`Economy.payout` + reconciliation.** Tests: `avgRoutineMultiplier(bayou,Hunting)==1.15`, `(bayou,Fishing)==1.3`; payout(wood_duck)=11, payout(blue_catfish fishing)=21; **`routineHourSum(dest,loop) ≈ income(tier)`** for Bayou/Appalachia/Alaska × both loops; **ceiling slackness** `modeledRate ≤ ceilingPerHour` per MVL dest-tier; **MVL gap** gearCostSlot(4)·2/income(2) ≈ 10.2 ≈ `2c·g`, normal step `2c=6`.
4. **Replace the Payout stubs** (RewardPipeline default = Economy.payout; expand signature; remove stubPayout; update RewardPipeline.spec). Steps 4–5 green.
5. **Idle real amount** (`economyAmount`; SessionService default; Idle.spec real-amount test). Mechanism tests green.
6. **`Profile.mintCommodity`.** Test: mints with `ci<seq>` id, bumps `nextCommodityInstanceSeq`, appends to commodities (unequipped, intraLevel as given).
7. **`ShopHandler.luau`.** Tests: buy a T2 weapon debits gearCostSlot(2)=3000 + mints an entry commodity (not equipped, EHT unchanged until equipped); insufficient funds rejects with no partial state; upgrade increments intraLevel + debits intraTierUpgradeCost, **EHT/EFT unchanged**; buy/upgrade atomic (forced save fail → no orphan Cash/gear); a non-gating item (bait) is rejected.
8. **Wire specs + README + final gate.** `ALL GREEN ✓`.

## Self-Review (spec coverage)

- Economy formulas read existing constants; salvage floor added → Tasks 1,2. ✓
- Three stubs replaced (hunting/fishing real Payout normalized per loop; idle real at max(EHT,EFT)) → Tasks 4,5. ✓
- Shops (buy/upgrade, commodity-mint, atomic, server-authoritative, intra-tier ≠ EHT) → Tasks 6,7. ✓
- Reconciliation per-loop-sum-to-Income(T) + ceiling slackness + MVL gear gap + gear-affordability → Task 3. ✓
- Salvage floor amount (Step 8 credits) → Task 2. ✓
- Starter grant: confirmed exists, reported, not rebuilt. ✓
- Deferred: monetization/multipliers/auto-sell (14), salvage UI (8), cosmetics/decor (8/14), Boats/Mounts/Dogs (11), trade tax (12), dailies (7/13), fast-travel fee (9). ✓
- Shop UI + felt pacing + live reconciliation = Studio/telemetry, reported honestly. ✓
