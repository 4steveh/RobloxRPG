# Wild World — Step 14: Monetization Wiring (sell *with* the player)

Branch `step-14-monetization`. Phase 4, Step 14 of `03_BUILD_PLAN.md`. The real-money layer: premium
bait/ammo, currency packs, 2x/VIP multipliers, game-pass Boat tiers + cosmetics, rewarded ads. **Not
rigor-critical**, but it carries the design's most-punished failure mode (pay-to-win), so the
**sell-with-the-player guardrails are structural**. Effects + guardrails + receipt idempotency are
headless; the MarketplaceService/ProcessReceipt/UserOwnsGamePassAsync platform calls + the store UI are
Studio.

## Inherited substrate (wire onto it; do not rebuild)

- `Enums.MonetizationRole` (incl. `power-progression`) + `RealMoneyKind`; the `Validation` power-role guard
  (Step 11).
- `Ledger.attemptRealMoneyCredit` — idempotent on the persistent `redeemedPurchaseIds` set (Step 2). THE
  currency-pack inject seam.
- `Spawner.rareSpawnEligible(target, world)` — takes NO bait/profile input (Step 13). Keep it so.
- `Spawner.routineTargetsInZone` / `Economy` routine population — Common/Uncommon **by construction**
  (`rarity < RARE_AND_ABOVE_RANK`). The premium-bait cap's structural floor.
- `RewardPipeline.resolve` — the SHARED active kill/catch grant point (both FireHandler + CatchHandler call
  it). The 2x/VIP multiplier hooks **here**, in the Cash branch, downstream of `payoutFn`. Idle/daily/salvage
  read `Economy.income`/formulas and never touch this path → never multiplied.
- `Progression.commitUnlocks` / `conquestNewlySet` — the conquest set, written only by a real kill/catch.
  No monetization path writes it.
- The Boat/cosmetic items + the Cash shop (Steps 6/8/11). Game-pass grants ride these.

## What Step 14 builds (headless)

1. **Types** — `Schema.ProductGrant = Cash | item | cosmetic | multiplier` (closed union; **no
   conquest/tier variant** → pay-to-win unrepresentable), `Product`/`ProductCatalog`, `products` on `Config`.
   `Enums` GrantKind + CashMultiplier. `Tuning.monetization` knobs.
2. **§B pay-proof guard** — `Validation.assertProduct`: role ≠ power-progression; an `item` grant is never
   tier gear (`tierInput == false`); a `cosmetic` grant is balance-free (`cosmeticOnly`); placeholder
   assetId present. Negative fixture `pay_to_win_grant.luau` (a conquest grant variant is unrepresentable).
3. **§A premium bait/ammo** (`logic/Monetization`) — pure effect (shorter TimeToBite, small LandWindow
   bonus, tighter CycleTime edge) + the **≤Uncommon routine-bias watch-knob**. Cap is structural:
   `rareSpawnEligible` is unchanged (bait-free), the bias operates only on the Common/Uncommon routine pool,
   and no target is takeable-only-with-premium-bait.
4. **§D 2x/VIP multiplier** — `Monetization.activeCashMultiplier` (multiplicative stack, capped at
   `maxStackCeiling`). Hooked in `RewardPipeline`'s Cash branch as a SEPARATE `boostBonus` ledger entry
   (`loop="none"`, real-money-tagged) so the routine kill/catch faucet stays the base payout (reconciliation
   untouched) and the boost is separable. Rares mint (no Cash) → never multiplied.
5. **§C/§E/§G PurchaseService + catalog** — `config/Monetization` product rows (placeholder asset ids).
   `server/monetization/PurchaseService`: `processReceipt` (dev product, idempotent per PurchaseId — cash via
   `attemptRealMoneyCredit`; non-cash mirror the same redeemed set), `grantGamePass` (ownership-idempotent
   item/cosmetic/vip), `applyGrant` core.
6. **§F rewarded ad** — `server/monetization/RewardedAdHandler` gauntlet intent `claimAdReward`: bounded,
   opt-in, `ad`-tagged (`loop="none"`), cooldown-capped, never gates. (Ad-completion attestation is Studio.)
7. **Wire-up** — Catalog merges `products` + validates on load; specs into `run.luau`; WorldServer Studio
   seams (ProcessReceipt / UserOwnsGamePassAsync stubs + register the ad handler); README + memory.

## Cross-cutting invariants (must hold; tested)

- **Pay-proof structural**: the grant union has no conquest/tier variant; no monetization handler writes the
  conquest set; no product carries `power-progression`. The pay-to-win alarm is structurally zero.
- **Premium-bait cap structural**: never an input to `rareSpawnEligible`; bias ≤ Uncommon (pool is
  Common/Uncommon by construction); never mandatory.
- **Cash stays non-tradeable** (no Cash-gift path).
- **Receipts idempotent**: a dev-product grant fires once per PurchaseId; re-delivery is a no-op.
- **Real-money faucets separately tagged + bounded** (currencypack / boostBonus / ad — own subtypes,
  loop="none"); the dual-loop reconciliation is untouched.

## Out of scope (Studio/platform)

MarketplaceService (`PromptProductPurchase`, the `ProcessReceipt` callback wiring, `UserOwnsGamePassAsync`,
the rewarded-ad SDK); the store UI / purchase prompts / boost-timer HUD; the real Roblox asset ids
(placeholders only). No pay-to-win surface.

## DoD

`--!strict` clean; Steps 1–13 stay green; reconciliation untouched. Pay-proof unrepresentable + guard + no
conquest write; premium-bait cap; currency-pack once-per-PurchaseId; multiplier active-only; ad bounded.
`./run-tests.sh` ALL GREEN.
