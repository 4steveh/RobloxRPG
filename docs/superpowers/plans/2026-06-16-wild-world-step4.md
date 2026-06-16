# Wild World Step 4 — The Hunting System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build hunting — the first gameplay verb — as a server-authoritative, loop-agnostic **target spawner + shot-resolution + reward pipeline**, driving the Step-2 substrate (Gauntlet step-3 hook → Transaction → Ledger/ArtifactStore/conquest) for the first time, and implementing the deferred EQUIPMENT_MASTER §1 combat/armor curves.

**Architecture:** The rigor-critical core is **pure & headless** (`src/logic/Combat.luau` math + anti-exploit validators + min-tier derivation; `src/logic/Spawner.luau` cap/engagement accounting; `src/server/combat/RewardPipeline.luau` ordered atomic reward; `src/server/combat/FireHandler.luau` wiring the Gauntlet step-3 hook). The **spawner and reward pipeline are loop-agnostic** — Step 5 (fishing) reuses them. **Game feel + the live shot + physical spawn placement + the LOS raycast are Studio-only** (`*.server.luau`), excluded from the headless harness and carried by the README playtest checklist.

**Tech Stack:** Luau `--!strict`, require-by-string aliases (`@src`/`@tests`), the `tests/harness.luau` assert harness, `./run-tests.sh` DoD gate (analyze + unit + negative fixtures + rojo build).

## Global Constraints

- `--!strict` clean for every headless module; Studio scripts are `*.server.luau`/`*.client.luau` (excluded from analyze + tests, per `run-tests.sh` find filter).
- **config (data) vs logic (pure):** `src/config/` holds content values; `src/logic/` is pure functions reading `profile`+`config` args, zero content literals.
- **closed enums live once** in `src/types/Enums.luau` (literal union + frozen table). No string synonyms.
- **configs self-validate on load** (a malformed catalog fails the `require`).
- **derive, don't store:** Cash balance, EHT/EFT, gate, **and now min-weapon/min-armor-tier** are functions, not stored truth — assert authored == derived.
- **Server-authority over every kill is absolute:** authoritative Health/position/weapon-stats/kill-declaration server-side; client predicts, asserts nothing (no client-kill route on the Gauntlet).
- **Reward XOR at runtime:** one Rare+-kill → exactly one mint + NO Cash; routine → Cash via stub `Payout`; never both. Whole pipeline = one atomic `Transaction`.
- **Per-kill Cash is economy's `Payout`** — pluggable stub here (model: `Idle.stubAmount`); Step 6 owns the real formula. **Never** read the catalog `cash:{min,max}` as authoritative.
- **Spawn-density cap is an economy-critical invariant**, server-enforced. Ambiance never consumes the reward-bearing ceiling.
- **Rank XP + conquest are active-play only**, conquest idempotent (set membership).
- **Bayou scope only.** Validate the Bayou T1 floor bands; the MVL T2→T4 difficulty check is **owed at Step 10** (Appalachia/Alaska creatures' survival-bounded KillWindow inputs are left nil/flagged — no premature cross-tier checks).
- **Illustrative numbers** are calibration knobs (the corpus convention); the formulas/relationships are the design.

---

## Prerequisites (Step-1 schema gaps — do FIRST)

**P1 — `spawnZones`.** Add `spawnZones: { string }?` to `Schema.Creature` (structured Step-3 zone ids); keep the prose `spawn.location`. Populate for every **Bayou non-ambiance** creature, mapping to real Step-3 zone ids (`sunny_levee`, `reed_edges`, `channel_banks`, `cottonmouth_slough`). Ambiance keeps its `Shells.ambiancePlacements` placement (untouched). Validate (at `Shells` load, which already has both catalog + shell) that every Bayou hunting target's `spawnZones` resolve to real zones.

**P2 — KillWindow inputs.** Add `escapeWindowSeconds: number?` (TimeToFlee, escape-bounded) and `attackIntervalSeconds: number?` (survival-bounded DPS) to `Schema.Creature`. Populate the Bayou creatures from LOC_01 §3:
- Wood Duck (flees): `escapeWindowSeconds = 4`
- Swamp Rabbit (flees): `escapeWindowSeconds = 5`
- Nutria (flees, **new row** — LOC §3 floor creature): `escapeWindowSeconds = 6`, health 30
- American Alligator (aggressive, non-lethal): `attackIntervalSeconds = 3` (no escape window — survival-in-form but non-lethal → window unbounded in the Bayou)
- Leucistic Wood Duck (rare, reskin of duck): `escapeWindowSeconds = 4`
- White Alligator (rare, reskin of gator): `attackIntervalSeconds = 3`
- Appalachia/Alaska: **leave nil** (survival-bounded derivation owed at Step 10). The escape-bounded fleers there *could* be filled but are out-of-scope (Bayou only).

---

## Binding numbers (copy verbatim into Tuning / configs)

**Weapon curve (already in `Tuning.offensive`/`Tuning.weapon`):** `WeaponDamage(T,ℓ)=round(D1·ρ^(T−1)·q(ℓ))`, `D1=18`, `ρ=1.4`, `q={entry .78, mid 1.0, maxed 1.28}`. So `WeaponDamage(1,mid)=18`. CycleTime: T1 1.5, T2 1.4, T3 1.3, T4 1.25, then −0.04/tier floor 1.0. Range `= 36 + 12·(T−1)`; falloff in-band 1.0 → floor 0.4.

**Armor DR (already in `Tuning.defensive`):** `DR=clamp(0.50 + 0.12·(armorTier−creatureTier), 0, 0.85)`.

**Derivation skill reference (already in `Tuning.skill`):** `Z_expected = 1.0 (=Z_body)`, `Z_vital = 2.5`.

**New `Tuning.combat` (this step):** `zone={vital 2.5, body 1.0, limb 0.5}`; `playerBaseHP=100`; `nonLethalMinHP=1`; `nonLethalDestinations={bayou=true}`; `coop={hCoop 0.5, partyCap 4}`; `range={falloffExtension 1.5}` (max effective = 1.5×optimal; beyond → out-of-range, damage 0); `fireRateToleranceSeconds=0.05`; `damageToleranceAbs=1` (rounding slack for the spoof check); `engagement` per tier `{timeToFind, timeToKill, overhead}` — T1 `{25,10,10}` (→ ~80/hr), T2 `{45,20,15}`, T4 `{75,35,20}` (combat §5 table); `rankXP={base=10, rarityWeight={Common 1, Uncommon 1.5, Rare 3, Epic 6, Legendary 12, Mythic 25}, tierStep=0.5 (per tier above 1), archetypeWeight={passive 1, flees 1, aggressive 1.5, pack 1.75, ambush 2}}`; `settle` placeholder + `aimAssist` placeholder (both Studio/feel, commented).

**Spawn-density (LOC §8.4 → new `src/config/Spawning.luau`):** Bayou hunting: 3 areas `sunny_levee`/`reed_edges`/`channel_banks`, each `maxConcurrentTargets=3`, `respawnIntervalSeconds=35`; `ceilingPerHour=85` (the ~80–90 knob — the binding invariant is "capped near Income(1)"; the exact value is the tuning knob, per §8.4). Fishing: `TODO(step-5)`.

**LOC creature stat checks (the derivation must reproduce these authored `minWeaponTierToKill` for Bayou, `Z_expected=1.0`, `WeaponDamage(1,mid)=18`, `CycleTime(1)=1.5`):**
- Wood Duck H15 → `ceil(15/18)=1` shot; window 4s/1.5=2.67 ≥ 1 → **minWeapon 1**; minArmor 0 (n/a).
- Swamp Rabbit H22 → `ceil(22/18)=2`; 5/1.5=3.33 ≥ 2 → **minWeapon 1**; minArmor 0.
- Nutria H30 → `ceil(30/18)=2`; 6/1.5=4 ≥ 2 → **minWeapon 1**; minArmor 0.
- Alligator H48 → `ceil(48/18)=3`; non-lethal → window ∞ ≥ 3 → **minWeapon 1**; minArmor 0 (n/a, non-lethal).
- Leucistic Duck / White Gator (reskins) → inherit base → minWeapon 1, minArmor 0.
- **min-armor-tier is n/a (0) Bayou-wide** (no survival-bounded lethal creature). The full survival-bounded branch is exercised at Step 10.

---

## File Structure

| File | Create/Modify | Responsibility |
|---|---|---|
| `src/types/Schema.luau` | Modify | Add `spawnZones`, `escapeWindowSeconds`, `attackIntervalSeconds` to `Creature`. |
| `src/config/Creatures.luau` | Modify | Add the 3 new fields to Bayou rows; add the **Nutria** row; thread inputs through the `creature()` builder. |
| `src/config/Tuning.luau` | Modify | Add `Tuning.combat` (zones, HP, non-lethal, co-op, range, tolerances, engagement, rankXP, settle/aim placeholders). |
| `src/config/Spawning.luau` | **Create** | Per-(destination,loop) routine area caps + `ceilingPerHour`; loop-agnostic; Bayou hunting populated, fishing TODO(step-5). Self-checked by `Spawner.validatePlacement` at `Shells` load. |
| `src/logic/Combat.luau` | **Create** | Pure combat math: curves, ShotDamage/ShotsToKill/TimeToKill, DR/DamageTaken, KillWindow inequality, co-op EffectiveHealth, non-lethal clamp, min-tier derivation, anti-exploit validators (damage-spoof, fire-rate, range, zone, LOS-decision). |
| `src/logic/Spawner.luau` | **Create** | Pure cap/engagement accounting: `expectedTargetsPerHour`, the over-geared bound, ambiance exclusion, rare condition-predicate eval; `validatePlacement(catalog, shell, spawning)`. |
| `src/config/Validation.luau` | Modify | Assert authored `minWeaponTierToKill`/`minArmorTierToSurvive` == `Combat.deriveMinTiers` for **Bayou** creatures; assert non-ambiance Bayou creatures carry `spawnZones`. |
| `src/config/Shells.luau` | Modify | Call `Spawner.validatePlacement(Catalog, bayou, Spawning)` at load (build-time guarantee; runs in the headless test set). |
| `src/server/combat/RewardPipeline.luau` | **Create** | Loop-agnostic ordered reward: ambiance→zero · Reward XOR (stub Payout→Ledger / ArtifactStore.mint) · Rank XP (weighted) · conquest (idempotent) · rare clean-kill hook. Pluggable `PayoutFn` + `stubPayout`. Caller wraps in `Transaction`. |
| `src/server/combat/FireHandler.luau` | **Create** | `FireHandler.new(deps) -> Gauntlet.IntentHandler` (`intent="fire"`, `critical=true`): authority (weapon equipped + target live huntable), simulate (shot-resolution validators + lethality gate), commit (RewardPipeline.resolve). |
| `src/server/world/HuntingService.server.luau` | **Create (Studio-only)** | Physical spawner placement (Shells zones → Workspace), fire RemoteEvent, raycast LOS, position authority, non-lethal Humanoid clamp, downed→free respawn at Bayou arrival. Excluded from headless; README checklist. |
| `tests/Combat.spec.luau` | **Create** | Math + validators + non-lethal clamp + co-op + min-tier derivation. |
| `tests/Spawner.spec.luau` | **Create** | Placement validation + cap/anti-farming + ambiance-exclusion + rare predicate. |
| `tests/RewardPipeline.spec.luau` | **Create** | XOR + ambiance-zero + conquest idempotent + atomic-no-orphan. |
| `tests/FireHandler.spec.luau` | **Create** | Gauntlet end-to-end fire→reward; exploit rejections; critical revert. |
| `tests/run.luau` | Modify | Register the 4 new specs under a "Step 4" group. |
| `README.md` | Modify | Step-4 section: headless-vs-Studio split, named stubs (Payout→6, revive→6/14, Rank-XP magnitudes), playtest checklist, deferred-table updates. |

**Interfaces (exact signatures later tasks rely on):**

```
-- Combat (config-as-first-arg pure module; config = Catalog)
Combat.weaponDamage(config, tier: number, level: ("entry"|"mid"|"maxed")?) -> number   -- default "mid"
Combat.cycleTime(config, tier: number) -> number
Combat.weaponRange(config, tier: number) -> number
Combat.rangeFalloff(config, tier: number, distance: number) -> number                  -- 0 beyond max effective
Combat.maxEffectiveRange(config, tier: number) -> number
Combat.shotDamage(weaponDamage: number, zoneMult: number, rangeFalloff: number) -> number
Combat.shotsToKill(health: number, weaponDamage: number, zoneMult: number, rangeFalloff: number) -> number
Combat.timeToKill(shotsToKill: number, cycleTime: number) -> number
Combat.dr(config, armorTier: number, creatureTier: number) -> number
Combat.damageTaken(creatureDamage: number, dr: number) -> number
Combat.coopEffectiveHealth(config, baseHealth: number, partySize: number) -> number
Combat.isNonLethal(config, creature) -> boolean
Combat.resolvePlayerHP(config, currentHP: number, rawDamage: number, nonLethal: boolean) -> number
Combat.isKillable(shotsToKill: number, killWindowSeconds: number, cycleTime: number) -> boolean
Combat.rankXP(config, creature) -> number
Combat.deriveMinTiers(config, creature) -> { minWeaponTier: number, minArmorTier: number }
-- validators
Combat.zoneMultiplier(config, zone: ("vital"|"body"|"limb")) -> number
Combat.zoneLegal(config, zone: string) -> boolean
Combat.fireRateOk(config, lastShotAt: number, now: number, cycleTime: number) -> boolean
Combat.rangeOk(config, tier: number, distance: number) -> boolean
Combat.damageDerivable(config, tier: number, level, zone: string, distance: number, claimed: number) -> boolean
Combat.losOk(rayHitTargetId: string?, claimedTargetId: string) -> boolean

-- Spawner (pure)
Spawner.expectedTargetsPerHour(config, tier: number, ceilingPerHour: number) -> number
Spawner.realizedRoutineRatePerHour(config, tier: number, ceilingPerHour: number, killSeconds: number) -> number
Spawner.rareSpawnEligible(creature, world: { time: string?, weather: string?, season: string?, event: string? }) -> boolean
Spawner.validatePlacement(config, shell, spawning) -> ()   -- raises on a bad zone / missing spawnZones

-- Spawning config
Spawning.byDestination[destinationId].hunting -> { ceilingPerHour: number, areas: { [zoneId]: { maxConcurrentTargets: number, respawnIntervalSeconds: number } } }

-- RewardPipeline (server; caller wraps in Transaction)
RewardPipeline.stubPayout(config, tier: number, rarity: string, loop: string) -> number
type PipelineDeps = { idGen, now: number, payoutFn: PayoutFn?, telemetry: Telemetry? }
type KillEvent = { targetId: string, owner: string, validatingEventId: string, loop: ("Hunting"|"Fishing"), partySize: number? }
RewardPipeline.resolve(profile, config, event: KillEvent, deps: PipelineDeps) -> {
  ambiance: boolean, cash: number, mintedArtifactId: string?, rankXP: number,
  conquestNewlySet: boolean, cleanKillMoment: string? }

-- FireHandler
type FireDeps = { idGen, payoutFn: PayoutFn?, telemetry: Telemetry? }
FireHandler.new(deps: FireDeps) -> Gauntlet.IntentHandler
-- payload (server-authoritative fields populated by HuntingService; client claims targetId/zone only):
--   { targetId, zone, distance, claimedDamage, lastShotAt, rayHitTargetId, targetAlive, accumulatedDamageBefore }
```

---

## Tasks

> TDD throughout: write the failing spec case, run it red, implement minimal, run green, then `./run-tests.sh`, then commit. Each task ends green on the full gate.

### Task 1 — Schema + catalog fields (P1 + P2)
- Modify `Schema.Creature`: add `spawnZones: { string }?`, `escapeWindowSeconds: number?`, `attackIntervalSeconds: number?`.
- Modify `Creatures.luau`: extend `CreatureInput` + `creature()` to thread the 3 fields; add `spawnZones`/`escapeWindowSeconds` to the Bayou floor + duck-rare rows, `attackIntervalSeconds` to the gator + white-gator rows; add the **Nutria** row (Common, flees, H30, dmg0, speed35, minWeapon1, minArmor0, cash{10,15}, `spawnZones={"reed_edges"}`, `escapeWindowSeconds=6`).
- Steps: (1) add a `Validation.spec`/`Catalog.spec` assertion that `Catalog.creatures.bayou_american_alligator.attackIntervalSeconds == 3` and `bayou_wood_duck.spawnZones` contains `sunny_levee`; (2) run red; (3) implement; (4) run green + `./run-tests.sh`; (5) commit `feat(step-4): spawnZones + KillWindow schema fields + Nutria`.

### Task 2 — `Tuning.combat`
- Add the `Tuning.combat` table (binding-numbers section). Frozen.
- Test: `Combat.spec` reads `config.tuning.combat.zone.vital == 2.5`, `coop.partyCap == 4`, `nonLethalDestinations.bayou == true`. (Fold into Task 3's first run.)
- Commit folded into Task 3.

### Task 3 — `Combat.luau` curves + damage/kill math
- Implement curves (`weaponDamage`, `cycleTime`, `weaponRange`, `rangeFalloff`, `maxEffectiveRange`) + `shotDamage`/`shotsToKill`/`timeToKill` + `dr`/`damageTaken`.
- Tests (red→green): `weaponDamage(1,"mid")==18`; `weaponDamage(2,"mid")==round(18*1.4)==25`; `cycleTime(1)==1.5`, `cycleTime(5)==1.25-0.04==1.21`; `weaponRange(1)==36`; `rangeFalloff(1,30)==1.0`, `rangeFalloff(1,beyond max)==0`; `shotsToKill(48,18,1.0,1.0)==3`; `shotsToKill(15,18,1.0,1.0)==1`; `timeToKill(3,1.5)==4.5`; `dr(armor2,creature2)==0.50`, `dr(3,2)==0.62`, `dr(1,2)==0.38`, cap at 0.85; `damageTaken(70,0.38)==43.4`.
- Commit `feat(step-4): combat damage/kill curves (EQUIPMENT_MASTER §1)`.

### Task 4 — `Combat.luau` co-op + non-lethal + kill-window
- `coopEffectiveHealth` (sublinear, capped at partyCap), `isNonLethal`, `resolvePlayerHP`, `isKillable`.
- Tests: `coopEffectiveHealth(100,1)==100`, `(100,4)==100*(1+0.5*3)==250`, `(100,9)` clamps to partyCap=4 → 250; `isNonLethal(gator)==true`; **non-lethal clamp**: looping the gator's raw 15 dmg N times via `resolvePlayerHP(...,nonLethal=true)` never drops below 1 (start 100, after 100 hits still 1); a lethal creature (`nonLethal=false`) reaches 0; `isKillable(3, math.huge, 1.5)==true`, `isKillable(4, 5, 1.5)` (4 ≤ 3.33? no) ==false.
- Commit `feat(step-4): co-op scaling + Bayou-wide non-lethal clamp + kill-window`.

### Task 5 — `Combat.luau` anti-exploit validators
- `zoneMultiplier`/`zoneLegal`, `fireRateOk`, `rangeOk`, `damageDerivable`, `losOk`.
- Tests: `zoneLegal("vital")==true`, `zoneLegal("head")==false`; `fireRateOk` rejects `now-last < cycleTime` (minus tolerance), accepts ≥; `rangeOk` rejects distance beyond `maxEffectiveRange`; `damageDerivable` accepts the exactly-recomputed `shotDamage` within `damageToleranceAbs`, rejects a 999 spoof; `losOk(nil,"t")==false`, `losOk("wall","t")==false`, `losOk("t","t")==true`.
- Commit `feat(step-4): server-side anti-exploit shot validators`.

### Task 6 — `Combat.deriveMinTiers` + Validation assertion
- Implement `rankXP` and `deriveMinTiers` (iterate tiers; escape-bounded uses `escapeWindowSeconds`; survival-bounded uses `survivalKillWindow` = `playerBaseHP / (damageTaken/attackInterval)`, but **non-lethal → math.huge**; `minArmorTier` = 0 when non-lethal/escape-bounded/dmg0, else lowest armorTier making the survival window fit). Uses `WeaponDamage(T,"mid")` + `Z_expected` (§3 reference).
- Modify `Validation.validateConfig`: for each creature with `destinationId=="bayou"`, assert `deriveMinTiers == { authored minWeaponTierToKill, minArmorTierToSurvive }`; assert non-ambiance Bayou creatures carry non-nil `spawnZones`. (Requires `Validation` → `Combat`; safe — `Combat` requires only `Schema`/`Enums`, no cycle. If a require cycle appears, move the derivation assertion into a `Catalog`-load call after `Combat` is available.)
- Tests: `Combat.spec` asserts `deriveMinTiers(gator) == {1,0}`, `(rabbit)=={1,0}`, `(duck)=={1,0}`, `(nutria)=={1,0}`; a `Validation.spec` case temporarily mutates a clone of a creature (e.g. health 9999) and asserts `deriveMinTiers` no longer equals `{1,..}` (proving the assertion would catch a mis-stat). The load-time assertion is implicitly covered (a bad value fails the `require`).
- Commit `feat(step-4): derive min-weapon/armor-tier; assert authored==derived (Bayou)`.

### Task 7 — `Spawning.luau` + `Spawner.luau` + Shells hook
- Create `Spawning.luau` (Bayou hunting areas + ceiling 85; fishing TODO).
- Create `Spawner.luau`: `expectedTargetsPerHour` (`min(3600/(find+kill+overhead), ceiling)`), `realizedRoutineRatePerHour` (over-geared = tiny killSeconds → `min(3600/killSeconds, ceiling)` → ceiling), `rareSpawnEligible` (all present conditions in `creature.spawn.conditions` must match `world`; independent of any kill), `validatePlacement` (every configured area zoneId ∈ shell.zones; every non-ambiance hunting creature home=destination has `spawnZones` ⊆ shell.zones).
- Modify `Shells.luau` to call `Spawner.validatePlacement(Catalog, bayou, Spawning)` at load.
- Tests: `expectedTargetsPerHour(1,85)==min(80,85)==80`; **anti-farming**: `realizedRoutineRatePerHour(1, 85, killSeconds=0.001)==85` (bounded by ceiling, not kill speed) and `85*12.5 ≈ 1062 << Income(4) 4913`; ambiance creatures are **not** counted by a `Spawner.routineSpeciesInZone` helper (ambiance excluded from the reward-bearing population); `rareSpawnEligible(white_gator, {time="dawn or dusk",weather="fog"})` true, `(white_gator,{})` false; `validatePlacement` raises on a synthetic area pointing at a nonexistent zone.
- Commit `feat(step-4): loop-agnostic spawner — caps, engagement rate, rare predicate`.

### Task 8 — `RewardPipeline.luau`
- Implement `stubPayout` (illustrative, e.g. `round(12.5 * rarityWeight)`; **TODO(step-6)**), and `resolve` (ordered: ambiance→zero early-return; XOR routine→`Ledger.applyEntry`(type `kill`/`catch`, amount=payout, tier, loop)/rare→`ArtifactStore.mint`(kind `trophy`, provenance); Rank XP via `Combat.rankXP` to `hunterRankXP`/`anglerRankXP` by `loop`; conquest idempotent when `isMilestoneTarget`; rare → `cleanKillMoment = rare.intendedContentMoment`). Telemetry increments.
- Tests (build profile via `Util.mkProfile`, `Fakes.newIdGenerator`):
  - ambiance (`bayou_great_egret`) → `{ambiance=true, cash=0, mintedArtifactId=nil, rankXP=0, conquestNewlySet=false}`, ledger tail unchanged, ranks unchanged, no artifact, conquest unset.
  - routine (`bayou_wood_duck`) → exactly **one** ledger entry, amount==`stubPayout`, `mintedArtifactId==nil`, `hunterRankXP>0`.
  - rare (`bayou_white_alligator`) → exactly **one** mint (`art-1`, HELD, provenance.sourceId), **zero** ledger entries, `cash==0`, `hunterRankXP>0`, `cleanKillMoment ~= nil`.
  - conquest: resolve(`bayou_american_alligator`) → `conquestNewlySet==true`, `conqueredDestinations.bayou==true`; resolve again → `conquestNewlySet==false`, still true (idempotent), and (re-kill) a **second** ledger entry is fine but conquest doesn't re-trigger.
  - **atomicity**: `Transaction.run(profile, function() RewardPipeline.resolve(...) end, failingSaveFn)` with the rare → returns `ok=false`, and the profile has **no orphan**: no artifact, no ledger entry, no rankXP gain, no conquest.
- Commit `feat(step-4): shared atomic reward pipeline (Reward XOR + conquest)`.

### Task 9 — `FireHandler.luau`
- `FireHandler.new(deps)`; authority (weapon equipped via `EffectiveTier.weaponTier>=1`; `config.creatures[targetId]` exists & not ambianceOnly milestone-irrelevant; `payload.targetAlive==true`); simulate (zoneLegal, rangeOk, fireRateOk, losOk, damageDerivable — each failure a distinct reason; then lethality: `accumulatedDamageBefore + shotDamage >= creature.health` else `(false,"not_lethal")`); commit (`RewardPipeline.resolve`). `critical=true`.
- Register-and-drive via the Gauntlet (mirror `Gauntlet.spec` deps shape).
- Tests:
  - valid lethal fire on `bayou_wood_duck` → `r.ok`, ledger gained one entry, projection returned, `hunterRankXP>0`.
  - valid lethal fire on `bayou_american_alligator` → conquest set, projection shows `conqueredDestinations.bayou`.
  - damage-spoof (claimedDamage 999) → `r.ok==false`, reason `damage_spoof`.
  - fire-rate (lastShotAt == now) → reason `fire_rate`.
  - LOS through-wall (rayHitTargetId="wall") → reason `los`.
  - `targetAlive=false` → reason `target_not_alive` (authority).
  - critical write-through fails → reverts: no orphan ledger entry/conquest (mirror `Gauntlet.spec` critical-fail test).
- Commit `feat(step-4): fire intent handler — gauntlet step-3 shot resolution`.

### Task 10 — Studio integration script (not headless)
- Create `src/server/world/HuntingService.server.luau` (`--!nonstrict`): on server start, register `FireHandler.new(...)` into the gauntlet registry; spawn routine creatures per `Spawning` into Workspace at `Shells` zone centers (server-owned positions + respawn timers, cap-enforced); a `FireRequest` RemoteEvent → enrich with authoritative position/weapon/raycast LOS → `Gauntlet.handle`; apply non-lethal Humanoid clamp for Bayou; on downed → free respawn at the Bayou arrival anchor (`ArrivalService`). Header comment: Studio-only; verified by README checklist; `TODO(step-8)` Lodge respawn, `TODO(step-6)` real Payout + Cash-revive, `TODO(step-14)` ad-revive, `TODO(step-7)` first-spawn cap bypass, `TODO(step-9)` gate consume, `TODO(step-13)` rare event scheduling.
- No headless test (excluded by `run-tests.sh`). Verify it appears under the "Studio-only" list in the gate output and `rojo build` still succeeds.
- Commit `feat(step-4): Studio hunting integration (physical spawner + fire wiring)`.

### Task 11 — Wire specs + README + final gate
- Add the 4 specs to `tests/run.luau` under a "Step 4 (hunting)" group; rename the harness label if appropriate.
- README: add the Step-4 section (module map rows, the headless-vs-Studio split, the playtest checklist verbatim from the build prompt's DoD, the named stubs with owning steps, the deferred-table updates, the T2→T4 difficulty check flagged as owed at Step 10).
- Run `./run-tests.sh` → `ALL GREEN ✓`.
- Commit `docs(step-4): README hunting section + Studio playtest checklist`.

---

## Self-Review (spec coverage)

- Spawner (loop-agnostic, caps, rares-independent, ambiance-excluded) → Tasks 7,10. ✓
- Hunting verb / shot resolution / curves / armor DR / non-lethal clamp / co-op → Tasks 3,4,5,9,10. ✓
- Reward pipeline (ambiance-zero, XOR, Rank XP weighted, conquest idempotent, atomic) → Task 8. ✓
- Derive min-tiers, assert authored==derived (Bayou; n/a armor) → Task 6. ✓
- Anti-exploit (damage-spoof, fire-rate headless; range headless; LOS decision headless, raycast Studio) → Tasks 5,9,10. ✓
- Telemetry names wired → Tasks 8,9 (headless increments) + 10 (Studio). ✓
- Non-punitive death / free respawn → Task 10 (Studio); Cash/ad revive deferred (6/14). ✓
- Deferred NOT built: real Payout (6), shops/revive price (6), fishing (5 reuses), first-spawn bypass (7), gate consume (9), Lodge respawn (8), ambush/projectile (post-MVL), rare event scheduling (13), T2→T4 difficulty (10). ✓
- Game feel is Studio, reported honestly (README checklist, never green headless). ✓
