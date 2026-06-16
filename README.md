# Wild World — Build Step 1: Project Skeleton & Data Model

The data-driven foundation for *Wild World* (a Roblox/Luau hunting-and-fishing RPG): the content
catalogs, the canonical player-state schema, and the pure derivation logic. **Shape + pure logic
only** — no persistence, gameplay, or UI yet. Everything is strict Luau (`--!strict`), server-side,
and Rojo-syncable.

> This is Phase 4, Step 1 of `03_BUILD_PLAN.md`. The binding design corpus lives alongside this
> README (`00_*`–`05_*`, `SYS_*`, `LOC_*`, `EQUIPMENT_MASTER.md`). Source of truth, in priority order:
> `02_DATA_SCHEMA_AND_TEMPLATES.md` (units/templates), `04_GLOSSARY.md` (names), `SYS_progression.md`,
> `SYS_economy.md`, `EQUIPMENT_MASTER.md`, `SYS_data_integrity.md` §1/§4.

## Quick start

```bash
./run-tests.sh        # strict type-check + unit tests + negative fixtures + rojo build
```

Toolchain (install once; binaries go on `PATH`):
- **`luau`** — runs the headless test harness (`luau tests/run.luau`).
- **`luau-analyze`** — `--!strict` type-checker (config in `.luaurc`, `languageMode=strict`).
- **`rojo`** — `rojo build default.project.json` proves the project syncs into a Roblox place.

Requires are resolved by Luau **require-by-string** via `.luaurc` aliases (`@src/...`, `@tests/...`),
honored by `luau`, `luau-analyze`, and luau-lsp. `default.project.json` maps `src/` →
`ServerScriptService.WildWorld`. *(Wiring runtime requires into live services is Step 2.)*

## The one rule: config (data) vs logic (behavior)

- **`src/config/`** holds **all content values** — every Cash number, creature stat, destination, item
  row, and tuning constant. Data only.
- **`src/logic/`** holds **pure functions** with **zero hardcoded content** — they read state
  (`profile`) and data (`config`) passed as arguments. (`run-tests.sh`-adjacent grep proves logic
  contains no destination ids, item ids, or magic numbers.)

If you find yourself typing a creature stat, a Cash number, or a destination name inside a logic
module — stop; it belongs in config.

## Module map

```
src/
  types/
    Ids.luau            DestinationId / TargetId / ItemId / ArtifactId + the Destination registry
    Enums.luau          every closed string-set (Rarity, Category, Behavior, Disposition, ArtifactKind,
                        MonetizationRole, RankPerkCategory, Loop, WaterType, Vendor) as union types
                        + frozen runtime tables; RarityRank + the Rare-and-above boundary; the
                        tier-input category set; the non-trophy disposition set
    Schema.luau         all record TYPES: EquipmentItem, Reward (XOR union), Creature, Fish, RareFields,
                        Gate, Destination, RankPerk, PlayerData (+ Inventory/Commodity/Artifact/
                        LedgerEntry/Entitlement), and the aggregated Config the logic consumes
  config/
    Tuning.luau         the ENTIRE EQUIPMENT_MASTER §1 constant set (offensive/defensive/fishing-fight
                        curves' constants, κ, Z/E_expected, economy B/g/c/m + RarityMultiplier, boat/
                        mount/dog multipliers, armorGatingStartTier, idle*, TierCoefficient hook) — DATA
    Equipment.luau      MVL line Tiers 1–4 (EQUIPMENT_MASTER §4), STRUCTURAL FIELDS ONLY (no stats);
                        tierInput derived from category; the tradeable matrix; Coastal Skiff accessGrant
    Creatures.luau      Bayou/Appalachia/Alaska hunting rosters (Template C) — floor/mid/apex/ambiance/rares
    Fish.luau           Bayou/Appalachia/Alaska rosters + a Deep Sea fixture entry (Template D)
    Destinations.luau   Bayou/Appalachia/Alaska + Rockies (T3) stub + Deep Sea (T7) fishing-only fixture;
                        the gate DAG
    RankPerks.luau      Hunter/Angler perk registry — category ∈ {identity, convenience}, never power
    Validation.luau     build-time schema assertions (XOR, disposition-kind, no-power, tierInput, gate refs)
    Catalog.luau        aggregates everything into a Config + a target→(loop, home, tier, rarity, milestone)
                        index, and runs validateConfig() ON LOAD (a malformed catalog fails the require)
  logic/                (pure; take state + config; nothing here is a stored field)
    EffectiveTier.luau  effectiveHuntingTier / effectiveFishingTier — the min/weakest-slot rule + empty-armor floor
    Gate.luau           evaluateGate → { unlocked, unmetReasons } — the single source of truth for "why can't I go"
    Balance.luau        balanceOf — fold over the append-only Cash ledger
    Profile.luau        freshProfile() + newArtifact() (disposition-kind-checked)
  server/
    DestinationService.luau  teleport REGISTRY + interface (canTravel preview); travelTo is a Step-9 stub
    PersistenceStub.luau     load/save/session-lock interface — Step-2 stub (names what Step 2 owns)
tests/                  hand-rolled harness + specs; tests/negative/ MUST fail analysis (unrepresentability)
docs/superpowers/plans/ the implementation plan
```

## Core derivations (pure, derived-never-stored)

| Function | Rule |
|---|---|
| `EffectiveTier.effectiveHuntingTier(profile, config)` | `min(weaponTier, armorTierOrFloor)`. Empty weapon = Tier 0. Empty armor = Tier 1 below `armorGatingStartTier`, Tier 0 at/above (decided against the weapon tier). |
| `EffectiveTier.effectiveFishingTier(profile, config)` | `min(rodTier, reelTier)`. Empty rod or reel = Tier 0. |
| `Gate.evaluateGate(profile, dst, config)` | **Gear half** met if `effectiveTier ≥ requiredTier` on ANY offered loop (never a blind `max(EHT,EFT)`). **Milestone half** met when every `prerequisiteDestinations` is in `conqueredDestinations`; `gate.milestoneTargets` supply the actionable nouns. `unmetReasons` are legibility-contract strings the UI consumes directly. |
| `Balance.balanceOf(profile)` | `Σ ledger entry.amount` — balance is derived, never a stored int. |
| `Profile.freshProfile(config)` | Free Tier-1 starter weapon+rod+reel (equipped), empty armor, empty everything else, `unlockedDestinations = { Bayou }`. Asserted: EHT = EFT = 1, balance 0. |

## Schema guarantees made structural (proven by tests, incl. failing-validation fixtures)

- **Reward XOR** — `Reward = CashReward | ArtifactReward`. No member carries both → "cash + artifact on
  one target" is **unrepresentable** (`tests/negative/reward_both.luau` fails analysis). Common/Uncommon →
  Cash; Rare-and-above → exactly one artifact, **no Cash at mint**. No `salvageCash` field (it's derived).
- **No pay-to-win** — `RankPerkCategory` is `identity | convenience`; **`power` is unrepresentable**
  (`tests/negative/power_perk.luau` fails analysis) and rejected at runtime.
- **Tier-input invariant** — `tierInput` is derived from category; only `weapon/armor/rod/reel` gate.
  `bait/tackle/vehicle/mount/dog/tool/cosmetic` can never enter the EHT/EFT derivation (there is no
  `boat` category — Boats are `vehicle`).
- **Disposition is kind-gated** — `disposition ∈ {HELD, DISPLAYED, ESCROWED, SALVAGED}`; `DISPLAYED`/
  `SALVAGED` are **Trophy-only**. A non-trophy artifact taking either is rejected (`Profile.newArtifact`).
- **Tradeable discriminator** (data-integrity RD1) — gear/basic vehicles/dogs/cosmetics are
  `tradeable=false` (commodity path); rare-breed dogs and tradeable cosmetics are `tradeable=true`
  (unique-artifact path). Orthogonal to `tierInput`.
- **Cosmetics are balance-free** — no `accessGrant`, `tierInput=false`, `cosmeticOnly=true`.

## Deferred stubs — who owns what (do NOT implement here)

| Deferred | Owning step | Where it's stubbed / noted |
|---|---|---|
| DataStore load/save, session-locking, ledger checkpoint+tail, autosave, **writing `logoutTimestamp`**, idle accrual, RemoteEvent boundary | **Step 2** | `src/server/PersistenceStub.luau` |
| Character controller, movement, Bayou geometry | Step 3 | — |
| Combat resolution + the offensive/armor stat curves | **Step 4** | `Tuning.luau` notes (`TODO(step-4)`) |
| Fishing resolution + rod/reel fight curves | **Step 5** | `Tuning.luau` notes |
| Faucet/sink transaction logic, shop UI, spawn caps, entitlement granting | Step 6 | — |
| Onboarding funnel | Step 7 | — |
| Lodge / Trophy Hall UI, disposition-transition flows (`HELD↔DISPLAYED`, `→SALVAGED`) | Step 8 | enum defined now; transitions deferred |
| World Map UI, **gated teleport execution + enforcement** | **Step 9** | `src/server/DestinationService.luau` (`travelTo` stub) |
| Boat/mount/dog access enforcement (which water a Boat opens) | Steps 5/11 | schema *expresses* it via `accessGrant`; enforcement deferred |
| Trading (escrow, both-sides-confirm), `HELD↔ESCROWED`, ownership transfer | Step 12 | enum value defined now |
| LiveOps events / timed spawns | Step 13 | — |
| Monetization wiring | Step 14 | `cost` real-money leg expressed; wiring deferred |

## Binding-spec reconciliations (judgment calls — flagged, not silently resolved)

1. **Gate fields.** `prerequisiteDestinations ⊆ conqueredDestinations` is the re-threadable DAG edge
   (the Rockies-insertion test). `milestoneTargets` are the prerequisite's conquest targets and supply
   the loop-aware actionable nouns. Per-target *recorded kill/catch events* are `TODO(step-4/5)`; until
   then the milestone is validated against `conqueredDestinations` (the server-authoritative proxy).
2. **`monetizationRole` = `identity | convenience | access`** (build-prompt enum; no `power`).
   EQUIPMENT_MASTER's "power-progression" gating gear maps to `convenience` (its real-money touch is
   grind-compression — pay-proof); the gate role is carried by `tier` + `tierInput`, not this field.
3. **`destinationId` added to Creature/Fish** — the home Destination, needed to key catalogs and to
   resolve a milestone target's home. Beyond Template C/D's `spawn.location` string; flagged.
4. **Cash ranges on creature/fish rewards are illustrative** — computed from economy's band
   (`Income(T)/ETPH × RarityMultiplier`), not authored; the authoritative payout is economy's (Step 6).
5. **`freshProfile(config)`** takes `config` (vs the build prompt's `freshProfile()`) so the starter
   loadout and starter Destination are *derived from data* (items flagged `availableAt=StarterLoadout`;
   the `requiredTier 0` Destination), keeping the logic content-free.

## Definition of Done — status

- ✅ Rojo-syncable project; `--!strict` compiles with **no type errors** (26 modules).
- ✅ Config catalogs seeded: equipment (T1–4, structural only), creatures, fish, destinations+gates
  (Bayou/Appalachia/Alaska + Rockies stub + fishing-only fixture), the full §1 tuning set, the
  four-value disposition enum.
- ✅ `PlayerData` + `freshProfile()` (asserted: EHT = EFT = 1, Bayou unlocked, balance 0).
- ✅ Pure functions + unit tests: MVL gate chain across representative profiles; Rockies DAG insertion
  with zero logic change; weakest-slot rule + empty-armor boundary; dual-loop OR-gate (maxed hunter
  fails the fishing-only fixture).
- ✅ Failing-validation examples: power perk rejected; cash+artifact unrepresentable; non-trophy
  DISPLAYED/SALVAGED rejected.
- ✅ This README (module map, config-vs-logic, deferred-stub ownership).

**121 assertions pass; both negative fixtures fail analysis as required.**
```
$ ./run-tests.sh   →   ALL GREEN ✓
```
