# Wild World — Step 10: Appalachia & Alaska Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** Flow the already-authored Appalachia (T2) and Alaska (T4) rosters through the existing
combat/fishing/spawner/economy/gating systems, prove the cross-tier difficulty is legible and co-op-soluble
(the systems-rigor headline), ship the spawn config + shell zone data + the Boat sub-area marker, and build
the two worlds + the fast-travel execution in Studio.

**Architecture:** No new systems. Two kinds of work: (1) **headless** — supply the deferred derivation
*inputs* (KillWindow seconds), fix two derivation *defects* (the survival-window convention + the apex
offset), and replace the **provably-unachievable** strict `derived==authored` cross-tier assertion with the
spec-faithful **floor/ceiling semantic** assertions the user approved; author the Appalachia/Alaska shell
zone data, spawn config, and the coastal/interior Boat marker. (2) **Studio** — the two worlds' geometry,
the `TeleportService` execution closing the Step-9 TODO, and telemetry. The headless half is the
DoD-gated rigor; the Studio half is the README playtest checklist.

**Tech Stack:** Luau (`--!strict`), Rojo, the headless toolchain at `~/.local/bin` (`luau`,
`luau-analyze`, `rojo`). `./run-tests.sh` is the Definition-of-Done gate.

## Global Constraints

- **Git root is the nested dir** `/home/toor/claude/RobloxRPG/RobloxRPG/` — run all `git`,
  `./run-tests.sh`, `luau`, `rojo` from there. Branch off `main` (Steps 1–9 merged): `git checkout -b
  step-10-appalachia-alaska`.
- **`./run-tests.sh` must print `ALL GREEN ✓`** after every task: `--!strict` clean on every headless
  module, all specs pass, the negative fixtures still FAIL analysis, `rojo build` succeeds.
- **Headless modules reference NO Roblox globals.** Roblox-API code lives only in `*.server.luau` /
  `*.client.luau` / `client/**` (excluded from analysis; verified by the README playtest checklist). A
  ModuleScript cannot be `.server` — Studio glue is the one place `game:GetService` is allowed.
- **config (data) vs logic (pure):** `src/config/` holds every content value; `src/logic/` is pure
  functions over `(profile, config)` with zero content literals. `Catalog.luau` runs `Validation.luau` at
  require-time — a malformed catalog fails the `require`.
- **Specs are the source of truth.** Cite by section. Priority: `02_DATA_SCHEMA` → `04_GLOSSARY` →
  `SYS_progression`/`SYS_economy`/`EQUIPMENT_MASTER` → `SYS_data_integrity`. **Do NOT re-author the
  rosters** (creatures/fish/rares/milestone flags/co-op-only markers exist). *Fix* a stat that is a defect;
  *add* the deferred derivation inputs; *flag* a model gap — never re-author wholesale.
- **Two binding decisions already made with the user (do not re-litigate):**
  1. **Derivation rigor = spec-faithful semantic assertion** (NOT strict `derived==authored`, which the
     probe proved unachievable: `deriveMinTiers` computes the *physical-minimum* gear while the authored
     values are the *design role-anchor* floor=T−1 / mid=T / apex=T+1, and for fish there is no input to
     add). Keep the authored min-tiers; assert **sufficiency** (killable/landable at the authored tier),
     **the wall** (co-op-only apex not soloable at T4 but co-op-soluble via the real co-op math), and **the
     role band** (floor=T−1, mid/milestone=T, apex=T+1; co-op-only iff minTier > 4).
  2. **King Salmon stays coastal/Boat-gated** (follow LOC_04 §4/§7 + the existing catalog; build-prompt §D's
     "interior" claim contradicts the binding spec and is rejected). Alaska stays solo-conquerable via the
     **Moose** (hunting milestone, Boat-free); the pure-fisher path to the same conquest flag waits for the
     Boat (Step 11).
- **Deferred — do NOT build:** the Boat item + coastal sub-area *enforcement* (Step 11); the dogs
  (Pointer/Husky, Step 11); the Rockies (post-launch); Lodge visit/instancing, trading, liveops (own steps);
  any new combat/fishing/economy/gating *system*. Confirm the Snowshoes/Ice-Fishing Kit are present in
  `Equipment.luau` (LOC §6); do not re-create them.

---

## Background: what the investigation established (read before starting)

The probe (`Combat.deriveMinTiers` / `Fishing.deriveMinTiers` run over the current catalog) found:

- **Creatures lack the KillWindow inputs.** Appalachia/Alaska creatures carry no `escapeWindowSeconds`
  (fleers) or `attackIntervalSeconds` (aggressors), so every survival/escape window is infinite → all derive
  to minWeapon 1 / minArmor 0. The attack intervals ARE authored in the LOC `## 3` prose (boar 3.0, coyote
  2.0, cougar 2.7, moose 3.0, grizzly 2.5); the escape windows are not numeric in the LOC and are authored
  here, design-consistent (faster/warier ⇒ shorter), per LOC §3 flavor + speeds.
- **Two derivation defects** (the "latent bug" the build prompt flagged):
  1. **Survival window.** `survivalWindow` uses `playerBaseHP/(taken/interval)` = `hitsToDown · interval`.
     The spec (`SYS_combat §3` worked examples: boar, cougar, grizzly) uses **`(hitsToDown − 1) · interval`**
     where `hitsToDown = ceil(playerBaseHP / damageTaken)`. Fix it.
  2. **Apex offset.** Apexes "are tuned to hit *as if* one tier higher" (`SYS_combat §4`). The DR in the
     survival check must treat an apex creature as `tier + 1`. Without it the grizzly reads soloable at T4
     (wrong). Marker: `coop == "party"` (cougar/catamount/grizzly/glacier — the design "needs a party" set).
  - With BOTH fixes, the derivation reproduces every `SYS_combat §3` worked soloability: boar soloable at
    T2; cougar not-soloable at T2 / soloable at T3; grizzly not-soloable at T4 / soloable at T5.
- **Strict `derived==authored` is still impossible** for floor/mid even with the fixes, because the windows
  are generous (the boar is killable at T1 by the inequality; authored minW2 is the design "mid=T" anchor).
  Hence the **semantic** approach (decision 1).
- **Fish:** the inputs are fixed (FightDifficulty + weight). The derivation diverges (grayling reel→1 vs
  authored 3; muskie reel→10 because reel is derived at a *parity rod that snaps*; halibut reel→6 vs 5).
  Strict equality is unachievable; the semantic assertion (landable at authored rod+reel) holds.
- **Halibut co-op data snag.** `representativeWeight = typicalWeightKg.max` (Step-5 rule) × the authored
  `max = 180` gives StaminaToLand 931, so `coopNetDrain` at partyCap STILL can't land it (38.6 > LandWindow
  37.2) → it would read "wall, not co-op-soluble." The spec's worked halibut uses weight ~80 (stamina 441 →
  co-op FightTime 18.3 ≤ 37.2 → lands). Reconcile the authored `typicalWeightKg` so the apex is co-op-soluble
  (Phase 2, Task 2.6).

### File structure (what each touched file owns)

- `src/logic/Combat.luau` — fix `survivalWindow` ((hits−1) + apex-tier param); add `M.isApex`,
  `M.soloableAt(config, creature, weaponTier, armorTier)`, `M.coopSoloableAt(config, creature, gearTier,
  partySize)`. Pure.
- `src/logic/Fishing.luau` — add `M.landableAt(config, fish, rodTier, reelTier)`,
  `M.coopLandableAt(config, fish, gearTier, partySize)`, and `M.requiresBoat(fish)` (the coastal marker
  helper). Pure.
- `src/config/Creatures.luau` — DATA only: add `escapeWindowSeconds`/`attackIntervalSeconds` + `spawnZones`
  to every non-ambiance Appalachia/Alaska creature; fix the 4 non-threat-fleer `minArmorTierToSurvive`
  1→0. No roster changes.
- `src/config/Fish.luau` — DATA only: add `spawnZones` to every Appalachia/Alaska fish; reconcile the
  halibut/ghost `typicalWeightKg` for co-op-solubility. No roster changes.
- `src/config/Spawning.luau` — add Appalachia + Alaska hunting/fishing `LoopSpawn` (areas + ceilings).
- `src/config/Shells.luau` — add the Appalachia + Alaska shell zone DATA; wire `validatePlacement` for both.
- `src/config/Validation.luau` — replace the `bayou`-fenced `derived==authored` block with the semantic
  assertions; extend universally; add the re-skin behavior-template check.
- `tests/CrossTier.spec.luau` — NEW: the cross-tier derivation rigor (sufficiency, wall, co-op-soluble,
  role band, the T2→T4 survival-step quantification). Wired into `tests/run.luau`.
- `tests/Combat.spec.luau`, `tests/Fishing.spec.luau`, `tests/Spawner.spec.luau`, `tests/Shell.spec.luau`,
  `tests/Validation.spec.luau` — extend with the new helpers + the Appalachia/Alaska coverage.
- `src/server/world/WorldServer.server.luau`, `src/server/ArrivalService.luau`,
  `src/server/DestinationService.luau` — **Studio** (`.server`) / arrival resolution: world blockout for the
  two new shells, `teleportTarget`→anchor resolution, the `TeleportService` execution (Step-9 TODO).
- `README.md` — Step 10 section + the deferred-table updates.

---

## Phase 0 — Shared derivation infrastructure (the rigor core)

> Pure-logic + assertion-framework changes that BOTH destinations need. The load-time Validation min-tier
> assertion stays `bayou`-fenced through Phase 0 (no data exists yet for the new destinations, so the fence
> must stay or the `require` fails). Phase 1/2 supply data and lift the fence per-destination.

### Task 0.1: Fix the survival-window convention + add the apex offset (Combat)

**Files:**
- Modify: `src/logic/Combat.luau` (the `survivalWindow` local + `deriveMinTiers`)
- Test: `tests/Combat.spec.luau`

**Interfaces:**
- Produces: `M.isApex(creature): boolean` (apex iff `creature.coop == Enums.Coop.party`);
  `survivalWindow(config, creature, armorTier)` now computes `max(ceil(HP/taken) − 1, 0) · interval` with DR
  evaluated at `creature.tier + (isApex and 1 or 0)`.

- [ ] **Step 1: Write the failing test.** In `tests/Combat.spec.luau`, after the existing "derivation has
      teeth" section, add:

```lua
	t.section("Combat — survival window uses (hitsToDown−1)·interval + the apex behaves-as-T+1 offset")
	do
		-- Boar (mid, NOT apex): H88 dmg40 interval3.0. At T2 armor (parity, DR 0.50): taken 20,
		-- hitsToDown ceil(100/20)=5, window (5−1)·3 = 12 s. Killable at T2 (4 shots·1.4 = 5.6 ≤ 12).
		local boar = Catalog.creatures.appalachia_wild_boar
		t.ok("boar is NOT flagged apex (coop != party)", Combat.isApex(boar) == false)
		t.ok("boar soloable at authored T2 weapon+armor (tense, safe)", Combat.soloableAt(Catalog, boar, 2, 2))
		-- Cougar (apex, behaves-as-T3): H100 dmg76 interval2.7. NOT soloable at T2, soloable at T3.
		local cougar = Catalog.creatures.appalachia_mountain_lion
		t.ok("cougar IS flagged apex (coop == party)", Combat.isApex(cougar))
		t.ok("cougar NOT soloable at T2 (4 shots·1.4 = 5.6 > 5.4 s window)", Combat.soloableAt(Catalog, cougar, 2, 2) == false)
		t.ok("cougar soloable at T3 (the apex needs T+1 solo)", Combat.soloableAt(Catalog, cougar, 3, 3))
	end
```

- [ ] **Step 2: Run it, confirm it fails.** `luau tests/run.luau` (or trim `tests/run.luau`'s spec list to
      just `Combat.spec` temporarily). Expected: FAIL — `Combat.isApex`/`Combat.soloableAt` are nil.

- [ ] **Step 3: Implement in `src/logic/Combat.luau`.** Replace the `survivalWindow` local (currently
      `playerBaseHP / (taken/interval)` at `creature.tier`) and add the public helpers:

```lua
-- An apex is tuned to hit AS IF one tier higher (§4). The design marker is the co-op recommendation:
-- a `party` creature is the tier's apex (cougar/catamount/grizzly/glacier). NOT a hardcoded id list.
function M.isApex(creature: Creature): boolean
	return creature.coop == "party"
end

-- The survival-bounded KillWindow (§3): the player can absorb (hitsToDown − 1) intervals before the
-- last hit downs them. DR uses the creature's EFFECTIVE tier (apex = +1). Non-damaging / non-lethal /
-- intervalless creatures have no survival clock → unbounded.
local function survivalWindow(config: Config, creature: Creature, armorTier: number): number
	local interval = creature.attackIntervalSeconds
	if interval == nil or interval <= 0 then
		return math.huge
	end
	local effTier = creature.tier + (if M.isApex(creature) then 1 else 0)
	local taken = M.damageTaken(creature.damageToPlayer, M.dr(config, armorTier, effTier))
	if taken <= 0 then
		return math.huge
	end
	local hitsToDown = math.ceil(config.tuning.combat.playerBaseHP / taken)
	return math.max(hitsToDown - 1, 0) * interval
end

-- Soloability at a specific (weaponTier, armorTier) — the §3 inequality with the chosen gear. Escape-
-- bounded creatures use their TimeToFlee; survival-bounded use the (hits−1) window above.
function M.soloableAt(config: Config, creature: Creature, weaponTier: number, armorTier: number): boolean
	local escape = creature.behavior == "passive" or creature.behavior == "flees"
	local window: number
	if escape then
		window = creature.escapeWindowSeconds or math.huge
	elseif M.isNonLethal(config, creature) then
		window = math.huge
	else
		window = survivalWindow(config, creature, armorTier)
	end
	local stk = M.shotsToKill(creature.health, M.weaponDamage(config, weaponTier, "mid"), config.tuning.skill.Z_expected, config.tuning.weapon.rangeFalloffInBand)
	return M.isKillable(stk, window, M.cycleTime(config, weaponTier))
end
```

  Then update `deriveMinTiers` so its internal `windowAtParity` and the min-armor loop call the new
  `survivalWindow(config, creature, armorTier)` signature (the apex offset + (hits−1) are now inside it).
  The existing `isEscapeBounded` local stays. **Note:** `deriveMinTiers` keeps returning the physical-min
  (its job is unchanged — it is no longer the cross-tier load assertion; the semantic helpers are).

- [ ] **Step 4: Run tests, confirm pass.** `luau tests/run.luau`. Expected: the new section passes; the
      existing Bayou `deriveMinTiers` `{1,0}` assertions still pass (Bayou is non-lethal → `survivalWindow`
      returns `huge` regardless; escape-bounded Bayou uses `escapeWindowSeconds` unchanged). Then
      `./run-tests.sh` → `ALL GREEN ✓`.

- [ ] **Step 5: Commit.** `git add -A && git commit -m "Step 10 (0.1): fix survival window ((hits−1)·interval) + apex behaves-as-T+1 offset"`

### Task 0.2: Add the co-op-soluble helper (Combat) + the fishing landable/co-op helpers (Fishing)

**Files:**
- Modify: `src/logic/Combat.luau`, `src/logic/Fishing.luau`
- Test: `tests/Combat.spec.luau`, `tests/Fishing.spec.luau`

**Interfaces:**
- Produces: `Combat.coopSoloableAt(config, creature, gearTier, partySize): boolean`;
  `Fishing.landableAt(config, fish, rodTier, reelTier): boolean`;
  `Fishing.coopLandableAt(config, fish, gearTier, partySize): boolean`.

- [ ] **Step 1: Write the failing tests.** In `tests/Combat.spec.luau`:

```lua
	t.section("Combat — the co-op-only apex is co-op-soluble (not a wall) via the real co-op math")
	do
		local grizzly = Catalog.creatures.alaska_grizzly_bear
		t.ok("grizzly NOT soloable at T4 even maxed (the wall — no T5 gear)", Combat.soloableAt(Catalog, grizzly, 4, 4) == false)
		t.ok("grizzly soloable at T5 (the T+1 that doesn't exist at MVL)", Combat.soloableAt(Catalog, grizzly, 5, 5))
		t.ok("grizzly co-op-soluble at T4 with a full party (partyCap)", Combat.coopSoloableAt(Catalog, grizzly, 4, Catalog.tuning.combat.coop.partyCap))
		t.ok("grizzly NOT co-op-soluble solo (party of 1 == solo wall)", Combat.coopSoloableAt(Catalog, grizzly, 4, 1) == false)
	end
```

  In `tests/Fishing.spec.luau`:

```lua
	t.section("Fishing — landable-at-tier helper + the co-op-only halibut")
	do
		local king = Catalog.fish.alaska_king_salmon  -- milestone, T4-soloable
		local halibut = Catalog.fish.alaska_giant_halibut  -- co-op-only apex
		t.ok("king salmon landable at authored rod4/reel4 (T4-soloable milestone)", Fishing.landableAt(Catalog, king, 4, 4))
		t.ok("halibut NOT landable solo at T4 (throws — no T5 reel)", Fishing.landableAt(Catalog, halibut, 4, 4) == false)
		t.ok("halibut co-op-soluble at T4 with a full party", Fishing.coopLandableAt(Catalog, halibut, 4, Catalog.tuning.combat.coop.partyCap))
	end
```

  *(These reference Alaska data authored in Phase 2 — they will fail now on the data and the helpers; that
  is expected. Implement the helpers here; the Alaska assertions go green once Phase 2 lands the data +
  the halibut weight reconciliation. To keep this task self-contained and green, see Step 3's note: assert
  the helpers against the Bayou/synthetic targets here, and move the Alaska assertions to Phase 2 Task 2.6.)*

- [ ] **Step 2: Run, confirm fail** (helpers nil).

- [ ] **Step 3: Implement.** In `src/logic/Combat.luau`:

```lua
-- Co-op solubility (§6): a party clears the co-op-scaled Health with combined DPS; the worst-case tank
-- (holds aggro the whole fight) must survive the fight's duration. Soluble iff the tank's accumulated
-- post-armor hits over the kill time stay under playerBaseHP. Uses coopEffectiveHealth + the (apex) DR.
function M.coopSoloableAt(config: Config, creature: Creature, gearTier: number, partySize: number): boolean
	local n = math.min(math.max(partySize, 1), config.tuning.combat.coop.partyCap)
	if n <= 1 then
		return M.soloableAt(config, creature, gearTier, gearTier) -- solo == the wall
	end
	local effHealth = M.coopEffectiveHealth(config, creature.health, n)
	local perPlayerDamage = M.weaponDamage(config, gearTier, "mid") * config.tuning.skill.Z_expected * config.tuning.weapon.rangeFalloffInBand
	if perPlayerDamage <= 0 then
		return false
	end
	local killTime = (effHealth / (n * perPlayerDamage)) * M.cycleTime(config, gearTier)
	local interval = creature.attackIntervalSeconds
	if interval == nil or interval <= 0 then
		return true -- no survival threat (e.g. a non-lethal/escape target) → trivially co-op-soluble
	end
	local effTier = creature.tier + (if M.isApex(creature) then 1 else 0)
	local taken = M.damageTaken(creature.damageToPlayer, M.dr(config, gearTier, effTier))
	local tankHits = math.floor(killTime / interval) -- hits the aggro-holder eats over the fight
	return tankHits * taken < config.tuning.combat.playerBaseHP
end
```

  In `src/logic/Fishing.luau`:

```lua
-- Landability at a specific (rodTier, reelTier) at the §3 mid-gear / E_expected reference. The direct
-- analog of Combat.soloableAt — the catch lands iff FightTime ≤ LandWindow with the chosen gear.
function M.landableAt(config: Config, fish: Fish, rodTier: number, reelTier: number): boolean
	local E = config.tuning.fishingFight.E_expected
	local ft = M.fightTime(M.staminaToLand(config, fish), M.netDrain(M.reelDrainMax(config, reelTier, "mid"), E, M.fishRecovery(config, fish)))
	return M.landable(ft, M.landWindow(config, rodTier, reelTier, fish, "mid"))
end

-- Co-op landability (§9): a party adds NetDrain sublinearly (coopNetDrain), shortening FightTime, so a
-- tier's apex lands on T gear that would throw solo. At the MVL top tier (Alaska) the apex (halibut) is
-- co-op-only — no T+1 reel — so this is where the property first does real work.
function M.coopLandableAt(config: Config, fish: Fish, gearTier: number, partySize: number): boolean
	local E = config.tuning.fishingFight.E_expected
	local baseNet = M.netDrain(M.reelDrainMax(config, gearTier, "mid"), E, M.fishRecovery(config, fish))
	local ft = M.fightTime(M.staminaToLand(config, fish), M.coopNetDrain(config, baseNet, partySize))
	return M.landable(ft, M.landWindow(config, gearTier, gearTier, fish, "mid"))
end
```

  For THIS task's green bar, assert the helpers against existing Bayou data (e.g.
  `Fishing.landableAt(Catalog, Catalog.fish.bayou_blue_catfish, 1, 1) == true`;
  `Combat.coopSoloableAt(Catalog, Catalog.creatures.bayou_american_alligator, 1, 4) == true`) and move the
  Alaska-specific assertions above into Phase 2 Task 2.6 (where the data exists). Adjust the Step-1 tests
  accordingly so this commit is green.

- [ ] **Step 4: Run, confirm pass** (`luau tests/run.luau`, then `./run-tests.sh` → `ALL GREEN ✓`).
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (0.2): co-op-soluble (Combat) + landable/co-op helpers (Fishing)"`

### Task 0.3: The re-skin behavior-template-reuse check (scope C)

**Files:**
- Modify: `src/config/Validation.luau` (in the `c.reskinOf ~= nil` branch)
- Test: `tests/Validation.spec.luau`

**Interfaces:**
- Consumes: the existing reskin tier check (Validation:152-157). Produces: an added assertion that a
  re-skin reuses its origin's `behavior` (the template), proving re-skins are droppable data over shared
  behavior templates (progression §6).

- [ ] **Step 1: Write the failing test.** In `tests/Validation.spec.luau`, add a section:

```lua
	t.section("Validation — a re-skin reuses its origin's behavior template (progression §6)")
	t.test("every catalog re-skin shares its origin's behavior", function()
		for _, c in Catalog.creatures do
			if c.reskinOf ~= nil then
				local origin = Catalog.creatures[c.reskinOf]
				assert(origin ~= nil, c.id .. ": reskinOf must resolve")
				assert(c.behavior == origin.behavior, c.id .. ": a re-skin must reuse its origin's behavior template")
			end
		end
	end)
	t.errs("a re-skin that changes behavior is rejected", function()
		local bad = table.clone(Catalog.creatures.appalachia_piebald_whitetail)
		bad.behavior = "aggressive" -- origin (whitetail) is `flees`
		Validation.assertCreatureReskin(bad, Catalog)
	end)
```

  **Note the catalog already conforms** EXCEPT `appalachia_spirit_moose`-class cases — verify: the reskins
  are leucistic_wood_duck(flees→flees ✓), white_alligator(aggressive→aggressive ✓),
  eastern_cottontail(flees→flees ✓), piebald_whitetail(flees→flees ✓), ghost_buck(flees→flees ✓),
  black_catamount(aggressive→aggressive ✓), arctic_hare(flees, origin swamp_rabbit flees ✓),
  spirit_moose(**flees**, origin bull_moose **aggressive** ✗!), glacier_grizzly(aggressive→aggressive ✓).
  **`alaska_spirit_moose` is `flees` but its origin `alaska_bull_moose` is `aggressive`** — a real conflict
  the check surfaces. Resolution: the spirit moose is "a find, takeable solo" (LOC_04 §5) deliberately
  *calmer* than the bull. Per LOC_04 §5 it shares the moose's *stat* template but flees rather than
  charges. **Reconcile by making the behavior-template check apply to re-skins whose origin is a
  fightable-template** — OR set `spirit_moose.behavior = "aggressive"` to match (it still derives/plays as
  a moose). **Recommended:** keep `spirit_moose` as `flees` (the spec's intent — a calm find) and scope the
  behavior check to assert the re-skin's behavior is in the origin's *archetype family* (both are valid
  archetypes; the check is "reuses a behavior template that exists," not "identical"). Simplest faithful
  rule: **a re-skin's behavior must equal its origin's OR be `flees`/`passive`** (a find can always be a
  calmer flee variant of an aggressive origin — LOC_04 §5). Encode that.

- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Implement** in `src/config/Validation.luau`. Extract the reskin checks into
      `V.assertCreatureReskin(c, config)` (so the negative test can call it directly) and call it from the
      `c.reskinOf ~= nil` branch of `validateConfig`:

```lua
function V.assertCreatureReskin(c: Creature, config: Config)
	local source = assert(config.creatures[c.reskinOf], c.id .. ": reskinOf '" .. tostring(c.reskinOf) .. "' must resolve to a creature")
	assert(c.tier >= source.tier, c.id .. ": a re-skin's displayed tier (" .. c.tier .. ") must be ≥ its origin's (" .. source.tier .. ")")
	-- Re-skins reuse a behavior TEMPLATE (progression §6). It must reuse the origin's archetype, OR be a
	-- calmer flee/passive 'find' variant of an aggressive/pack origin (LOC §5 — e.g. the Spirit Moose).
	local reusesTemplate = c.behavior == source.behavior or c.behavior == "flees" or c.behavior == "passive"
	assert(reusesTemplate, c.id .. ": a re-skin must reuse its origin's behavior template (progression §6)")
end
```

  Replace the inline tier assert in `validateConfig` with `V.assertCreatureReskin(c, config)`.

- [ ] **Step 4: Run, confirm pass** (`./run-tests.sh` → `ALL GREEN ✓`).
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (0.3): re-skin behavior-template-reuse check (progression §6, scope C)"`

---

## Phase 1 — Appalachia content (T1→T2) + the semantic assertion

### Task 1.1: Author Appalachia creature KillWindow inputs + spawnZones; fix the non-threat-fleer armor

**Files:**
- Modify: `src/config/Creatures.luau` (the 8 Appalachia non-ambiance creature blocks)
- Test: `tests/Combat.spec.luau`

**Interfaces:**
- Produces: every non-ambiance Appalachia creature carries `spawnZones` (resolving to the Appalachia shell
  zones authored in Task 1.3) and a KillWindow input (`escapeWindowSeconds` for fleers,
  `attackIntervalSeconds` for aggressors). Non-threat fleers' `minArmorTierToSurvive` is 0 (n/a).

- [ ] **Step 1: Write the failing test.** In `tests/Combat.spec.luau`, add:

```lua
	t.section("Combat — Appalachia KillWindow inputs + spawnZones (LOC_02 §3)")
	do
		local boar = Catalog.creatures.appalachia_wild_boar
		local coyote = Catalog.creatures.appalachia_coyote
		local cougar = Catalog.creatures.appalachia_mountain_lion
		local deer = Catalog.creatures.appalachia_whitetail_deer
		t.ok("boar attackInterval = 3.0 s (LOC_02 §3)", boar.attackIntervalSeconds == 3.0)
		t.ok("coyote attackInterval = 2.0 s", coyote.attackIntervalSeconds == 2.0)
		t.ok("cougar attackInterval = 2.7 s", cougar.attackIntervalSeconds == 2.7)
		t.ok("whitetail carries an escape window + spawnZones", deer.escapeWindowSeconds ~= nil and deer.spawnZones ~= nil)
		t.ok("non-threat fleer minArmor is n/a (0), matching the derivation", deer.minArmorTierToSurvive == 0)
		t.ok("every non-ambiance Appalachia creature carries spawnZones", (function()
			for _, c in Catalog.creatures do
				if c.destinationId == "appalachia" and not c.ambianceOnly and (c.spawnZones == nil or #(c.spawnZones :: any) == 0) then return false end
			end
			return true
		end)())
	end
```

- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Edit `src/config/Creatures.luau`.** Add the fields below to each Appalachia non-ambiance
      block (keep the prose `spawnLocation`; add `spawnZones` + the KillWindow input; fix `minArmor`):

  | id | add `spawnZones` | add window | `minArmorTierToSurvive` |
  |---|---|---|---|
  | `appalachia_eastern_cottontail` | `{ "old_field" }` | `escapeWindowSeconds = 4` | **0** (was 1) |
  | `appalachia_whitetail_deer` | `{ "old_field" }` | `escapeWindowSeconds = 4.5` | **0** (was 1) |
  | `appalachia_coyote` | `{ "creek_bottoms" }` | `attackIntervalSeconds = 2.0` | 3 (keep) |
  | `appalachia_wild_boar` | `{ "oak_ridges" }` | `attackIntervalSeconds = 3.0` | 2 (keep) |
  | `appalachia_mountain_lion` | `{ "lookout_ridge" }` | `attackIntervalSeconds = 2.7` | 3 (keep) |
  | `appalachia_piebald_whitetail` | `{ "old_field" }` | `escapeWindowSeconds = 4.5` | **0** (was 1) |
  | `appalachia_ghost_buck` | `{ "old_field" }` | `escapeWindowSeconds = 4.5` | **0** (was 1) |
  | `appalachia_black_catamount` | `{ "lookout_ridge" }` | `attackIntervalSeconds = 2.7` | 3 (keep) |

  Escape-window rationale (LOC_02 §3): the deer is the worked H50 floor (`ceil(50/18)=3` shots at T1 must
  fit ⇒ window ≥ 4.5 s); the cottontail is a re-skin of the Bayou rabbit (escape 5 → re-tagged 4, warier).
  These are design-consistent, not reverse-engineered to a tier (the role band, not the window, fixes the
  authored minWeapon under the semantic approach). Comment each with the LOC cite, mirroring the Bayou rows.

- [ ] **Step 4: Run, confirm pass.** `./run-tests.sh` will still pass the EXISTING Bayou-fenced Validation
      (Appalachia not yet asserted). `ALL GREEN ✓`.
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (1.1): Appalachia KillWindow inputs + spawnZones; non-threat fleer armor 0"`

### Task 1.2: Author Appalachia fish spawnZones

**Files:**
- Modify: `src/config/Fish.luau` (the 7 Appalachia fish blocks)
- Test: `tests/Fishing.spec.luau`

- [ ] **Step 1: Write the failing test** in `tests/Fishing.spec.luau`:

```lua
	t.section("Fishing — every Appalachia fish carries spawnZones")
	t.ok("Appalachia fish all carry spawnZones resolving later to the shell", (function()
		for _, f in Catalog.fish do
			if f.destinationId == "appalachia" and (f.spawnZones == nil or #(f.spawnZones :: any) == 0) then return false end
		end
		return true
	end)())
```

- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Edit `src/config/Fish.luau`** — add `spawnZones` to each Appalachia fish:

  | id | `spawnZones` |
  |---|---|
  | `appalachia_bluegill` | `{ "mill_pond" }` |
  | `appalachia_brook_trout` | `{ "hollow_creek" }` |
  | `appalachia_smallmouth_bass` | `{ "hollow_creek", "mill_pond" }` |
  | `appalachia_trophy_largemouth_bass` | `{ "mill_pond" }` |
  | `appalachia_northern_pike` | `{ "mill_pond" }` |
  | `appalachia_record_muskie` | `{ "mill_pond" }` |
  | `appalachia_tiger_muskie` | `{ "mill_pond" }` |

- [ ] **Step 4: Run, confirm pass** (`./run-tests.sh` → `ALL GREEN ✓`).
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (1.2): Appalachia fish spawnZones (Hollow Creek / Mill Pond)"`

### Task 1.3: Author the Appalachia shell zone data + wire validatePlacement

**Files:**
- Modify: `src/config/Shells.luau` (add the `appalachia` shell + register it + wire placement)
- Test: `tests/Shell.spec.luau`

**Interfaces:**
- Consumes: `Schema.Shell`, `Shell.validateShell`, `Spawner.validatePlacement` (mirror the Bayou wiring at
  `Shells.luau:130-142`). Produces: `Shells.byDestination[D.Appalachia]` with zones matching the spawnZones
  from 1.1/1.2 and the spawn areas from 1.4. **`validatePlacement` is the real teeth** — it asserts every
  non-ambiance Appalachia creature/fish has spawnZones resolving to a real zone.

- [ ] **Step 1: Write the failing test** in `tests/Shell.spec.luau` (mirror the Bayou shell assertions):

```lua
	t.section("Shell — Appalachia shell registered, zones resolve")
	do
		local ap = Catalog and nil -- (Shells requires Catalog; require Shells in this spec's header)
		local shell = Shells.byDestination.appalachia
		t.ok("Appalachia shell exists", shell ~= nil)
		t.ok("arrival zone is the Outpost Cabin", shell.zones[shell.arrivalZoneId] ~= nil)
		t.ok("hunting + fishing zones present", shell.zones.old_field ~= nil and shell.zones.lookout_ridge ~= nil and shell.zones.hollow_creek ~= nil and shell.zones.mill_pond ~= nil)
	end
```

  *(Add `local Shells = require("@src/config/Shells")` to the spec header if not present.)*

- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Implement** in `src/config/Shells.luau`. Add an `appalachia` shell mirroring the `bayou`
      shell shape (LOC_02 §2 layout — terrain/landmarks/zones). Zones (`ZoneKind` ∈
      arrival/hunting/fishing/rareSite/vendor):

  - `outpost_cabin` (arrival; also the vendor outpost — set `arrivalZoneId = "outpost_cabin"`,
    `vendorOutpostAnchor`/`travelSignpostAnchor` here)
  - `old_field` (hunting — deer/turkey/cottontail; the Ghost Buck dawn site)
  - `oak_ridges` (hunting — boar, brushy mid-slopes)
  - `creek_bottoms` (hunting — coyote packs, draws)
  - `lookout_ridge` (hunting — the cougar apex range + the panoramic arrival vista; also the Black
    Catamount rare site)
  - `hollow_creek` (fishing — brook trout, the fly water)
  - `mill_pond` (fishing — panfish/bass/pike/muskie; the Lowland Lake basin)
  - `landmarks`: `lookout_ridge` (`isBeacon = true` — the wayfinding beacon + hero shot), `hollow_creek`,
    `mill_pond`, `the_old_field`, `outpost_cabin`.
  - `ambiancePlacements`: `appalachia_gray_squirrel = "old_field"` (the only ambiance-only Appalachia
    creature in the catalog).
  - `render`: dawn-fog budget, e.g. `{ fogStart = 90, fogEnd = 340, drawDistance = 340 }` (LOC_02 §2.5).
  - Coordinates: plain `{x,y,z}` via the existing `v()` helper; choose a compact legible footprint (the
    Bayou's are illustrative — match the scale; centers just need to be distinct + inside their zones).

  Register and validate (mirror `Shells.luau:127-142`):

```lua
local byDestination: { [Ids.DestinationId]: Schema.Shell } = { [D.Bayou] = bayou, [D.Appalachia] = appalachia }
-- ...
Shell.validateShell(appalachia, Catalog)
local apSpawn = Spawning.byDestination[D.Appalachia]
if apSpawn ~= nil and apSpawn.hunting ~= nil then
	Spawner.validatePlacement(Catalog, appalachia, apSpawn.hunting, Enums.Loop.Hunting)
end
if apSpawn ~= nil and apSpawn.fishing ~= nil then
	Spawner.validatePlacement(Catalog, appalachia, apSpawn.fishing, Enums.Loop.Fishing)
end
```

  **Ordering note:** `Spawning.byDestination[D.Appalachia]` must exist (Task 1.4) before this validates the
  areas; do 1.4 and 1.3 together (or 1.4 first). The `validatePlacement` call requires both. If you commit
  1.3 before 1.4, guard with the `~= nil` checks already shown (so the build stays green until 1.4 lands the
  spawn config).

- [ ] **Step 4: Run, confirm pass** (`./run-tests.sh` → `ALL GREEN ✓`; `rojo build` confirms sync).
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (1.3): Appalachia shell zone data + validatePlacement wiring"`

### Task 1.4: Author the Appalachia spawn config (LOC_02 §8)

**Files:**
- Modify: `src/config/Spawning.luau`
- Test: `tests/Spawner.spec.luau`

- [ ] **Step 1: Write the failing test** in `tests/Spawner.spec.luau`:

```lua
	t.section("Spawner — Appalachia spawn config (LOC_02 §8.4)")
	do
		local ap = Spawning.byDestination.appalachia
		t.ok("Appalachia hunting + fishing LoopSpawn present", ap ~= nil and ap.hunting ~= nil and ap.fishing ~= nil)
		t.ok("hunting ceiling is slack over the modeled ~45/hr (anti-farming)", ap.hunting.ceilingPerHour > Spawner.modeledRatePerHour(Catalog, 2, Enums.Loop.Hunting))
		t.ok("fishing ceiling is slack over the modeled ~38/hr", ap.fishing.ceilingPerHour > Spawner.modeledRatePerHour(Catalog, 2, Enums.Loop.Fishing))
	end
```

- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Implement** in `src/config/Spawning.luau` (mirror `bayouHunting`/`bayouFishing`; values from
      LOC_02 §8.4):

```lua
-- Appalachia hunting (LOC_02 §8.4): modeled ~45/hr at T2; ceiling 48 (slack — the anti-farming bound).
local appalachiaHunting: LoopSpawn = {
	ceilingPerHour = 48,
	areas = {
		old_field = { maxConcurrentTargets = 6, respawnIntervalSeconds = 45 },     -- deer/turkey/cottontail
		oak_ridges = { maxConcurrentTargets = 3, respawnIntervalSeconds = 90 },     -- boar
		creek_bottoms = { maxConcurrentTargets = 2, respawnIntervalSeconds = 180 }, -- coyote packs (crowd cap)
		lookout_ridge = { maxConcurrentTargets = 1, respawnIntervalSeconds = 300 }, -- mountain lion (apex)
	},
}
-- Appalachia fishing (LOC_02 §8.4): modeled ~38/hr at T2; ceiling 40 (slack). Shore-accessible, no Boat.
local appalachiaFishing: LoopSpawn = {
	ceilingPerHour = 40,
	areas = {
		hollow_creek = { maxConcurrentTargets = 4, respawnIntervalSeconds = 40 }, -- trout (fly water)
		mill_pond = { maxConcurrentTargets = 5, respawnIntervalSeconds = 40 },    -- panfish/bass/pike/muskie
	},
}
```

  Add to `byDestination`: `[D.Appalachia] = { hunting = appalachiaHunting, fishing = appalachiaFishing }`.

- [ ] **Step 4: Run, confirm pass** (`./run-tests.sh` → `ALL GREEN ✓`). The Shell `validatePlacement` from
      1.3 now resolves every Appalachia area zone + every target spawnZone.
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (1.4): Appalachia spawn config (zones/ceilings/caps, LOC_02 §8.4)"`

### Task 1.5: The semantic cross-tier assertion — Appalachia (replace the strict-equality block)

**Files:**
- Modify: `src/config/Validation.luau` (the creature + fish min-tier blocks in `validateConfig`)
- Test: `tests/CrossTier.spec.luau` (NEW), wired into `tests/run.luau`

**Interfaces:**
- Consumes: `Combat.soloableAt`, `Combat.isApex`, `Fishing.landableAt`, the destination tiers. Produces: a
  load-time assertion set — **sufficiency** (every non-co-op-only target is soloable/landable at its
  authored min-tier), **the role band** (floor=T−1, mid/milestone=T, apex=T+1; co-op-only iff minTier > 4),
  applied to bayou + appalachia. (Alaska added in Phase 2; the co-op-only WALL + co-op-soluble assertions
  live in CrossTier.spec, Phase 2.)

- [ ] **Step 1: Create `tests/CrossTier.spec.luau`** and wire it into `tests/run.luau` (add
      `require("@tests/CrossTier.spec")` after the Step-9 block). Initial content asserts Appalachia
      sufficiency + role band:

```lua
--!strict
-- Step 10 — the cross-tier (T1→T2→T4) difficulty rigor. The strict `derived==authored` equality is
-- provably unachievable cross-tier (deriveMinTiers computes physical-min; the catalog authors the
-- design role-anchor floor=T−1/mid=T/apex=T+1). Per the binding decision we assert the spec's
-- floor/ceiling SEMANTICS (progression §5, SYS_combat/§fishing §3): sufficiency, the wall, co-op-soluble.
local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Combat = require("@src/logic/Combat")
local Fishing = require("@src/logic/Fishing")

local MAX_MVL_TIER = 4

return function(t: Harness.T)
	t.section("CrossTier — Appalachia: routine soloable ≤ T2; sufficiency at the authored tier")
	for _, c in Catalog.creatures do
		if c.destinationId == "appalachia" and not c.ambianceOnly then
			local dTier = c.tier -- creature.tier == destination tier for these
			if c.minWeaponTierToKill <= MAX_MVL_TIER then -- soloable band (not co-op-only)
				t.ok(c.id .. " soloable at its authored weapon+armor tier", Combat.soloableAt(Catalog, c, c.minWeaponTierToKill, math.max(c.minArmorTierToSurvive, c.minWeaponTierToKill)))
				t.ok(c.id .. " authored minWeapon in the role band [T-1, T+1]", c.minWeaponTierToKill >= dTier - 1 and c.minWeaponTierToKill <= dTier + 1)
			end
		end
	end
	for _, f in Catalog.fish do
		if f.destinationId == "appalachia" and require("@src/types/Enums").RarityRank[f.rarity] < 3 then
			t.ok(f.id .. " landable at its authored rod+reel", Fishing.landableAt(Catalog, f, f.minRodTier, f.minReelTier))
			t.ok(f.id .. " authored minRod in the role band", f.minRodTier >= f.tier - 1 and f.minRodTier <= f.tier + 1)
		end
	end
end
```

- [ ] **Step 2: Run, confirm pass for the test** (these assert the catalog as-authored; they should pass
      because the windows from 1.1 make every soloable target killable at its authored tier, and the
      authored tiers sit in the band). If the cougar (minW3 = T2+1 = apex wall) fails the band, confirm
      `3 <= 2+1` ✓. If any fails, the failure is a real defect — investigate the stat per the build prompt.

- [ ] **Step 3: Replace the strict block in `src/config/Validation.luau`.** Change the creature min-tier
      block (currently fenced `if c.destinationId == "bayou"`) to extend to appalachia AND switch
      cross-tier targets from strict equality to sufficiency + band. The Bayou keeps its existing
      `derived==authored` (it holds there + the build prompt wants it preserved). Concretely:

```lua
		-- Step-4/10 (SYS_combat §3): min-tier fields are DERIVED, not authored. The Bayou keeps the strict
		-- derived==authored assertion (it holds — Bayou is T1, the physical-min == the design floor). The
		-- cross-tier destinations cannot satisfy strict equality (physical-min ≠ design role-anchor; the
		-- probe + the user-approved decision), so they assert the spec's floor/ceiling SEMANTICS instead.
		if not c.ambianceOnly then
			assert(c.spawnZones ~= nil and #(c.spawnZones :: { string }) > 0, c.id .. ": a hunting target must carry structured spawnZones")
			if c.destinationId == "bayou" then
				local derived = Combat.deriveMinTiers(config, c)
				assert(derived.minWeaponTier == c.minWeaponTierToKill, ...) -- (keep existing)
				assert(derived.minArmorTier == c.minArmorTierToSurvive, ...) -- (keep existing)
			elseif c.destinationId == "appalachia" then
				if c.minWeaponTierToKill <= 4 then -- soloable band (not a co-op-only apex)
					assert(Combat.soloableAt(config, c, c.minWeaponTierToKill, math.max(c.minArmorTierToSurvive, c.minWeaponTierToKill)),
						c.id .. ": must be soloable at its authored min-tier (floor/ceiling sufficiency, §3)")
					assert(c.minWeaponTierToKill >= c.tier - 1 and c.minWeaponTierToKill <= c.tier + 1,
						c.id .. ": authored minWeaponTier must sit in the role band [T-1, T+1]")
				end
			end
		end
```

  Apply the analogous change to the fish block (extend the `if f.destinationId == "bayou"` to also handle
  `appalachia` via `Fishing.landableAt` + the band, keeping the rare exclusion). **Keep the spawnZones
  requirement universal** (it already is for the loop; just drop the bayou fence on it).

- [ ] **Step 4: Run, confirm pass** (`./run-tests.sh` → `ALL GREEN ✓`). The require now validates
      appalachia; a future mis-stat fails the load.
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (1.5): semantic floor/ceiling assertion extended to Appalachia (sufficiency + role band)"`

---

## Phase 2 — Alaska content + the co-op-only apex + the Boat marker

### Task 2.1: Author Alaska creature KillWindow inputs + spawnZones

**Files:** Modify `src/config/Creatures.luau`; Test `tests/Combat.spec.luau`.

- [ ] **Step 1: Write the failing test** (mirror 1.1 for `alaska_*`: moose `attackIntervalSeconds == 3.0`,
      grizzly `== 2.5`, glacier_grizzly `== 2.5`; every non-ambiance Alaska creature carries spawnZones; the
      fleers carry escape windows).
- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Edit `src/config/Creatures.luau`** — add to each Alaska non-ambiance block:

  | id | `spawnZones` | window |
  |---|---|---|
  | `alaska_arctic_hare` | `{ "tundra_flats" }` | `escapeWindowSeconds = 3.0` |
  | `alaska_sitka_deer` | `{ "spruce_riverbottom" }` | `escapeWindowSeconds = 3.5` |
  | `alaska_caribou` | `{ "tundra_flats" }` | `escapeWindowSeconds = 4.0` |
  | `alaska_bull_moose` | `{ "spruce_riverbottom", "tundra_flats" }` | `attackIntervalSeconds = 3.0` |
  | `alaska_grizzly_bear` | `{ "salmon_falls" }` | `attackIntervalSeconds = 2.5` |
  | `alaska_cross_fox` | `{ "tundra_flats" }` | `escapeWindowSeconds = 3.5` |
  | `alaska_spirit_moose` | `{ "spruce_riverbottom" }` | `escapeWindowSeconds = 4.0` (it's `flees`) |
  | `alaska_glacier_grizzly` | `{ "salmon_falls" }` | `attackIntervalSeconds = 2.5` |

  *(The catalog has no `dall_sheep`; LOC_04 §3 lists it but the catalog is representative — do not add it.
  Sitka deer's `spawnLocation` is "spruce edges and lower slopes" → `spruce_riverbottom`.)* Comment each
  with the LOC_04 §3 cite.

- [ ] **Step 4: Run, confirm pass** (Validation still fences Alaska — green). `ALL GREEN ✓`.
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (2.1): Alaska KillWindow inputs + spawnZones (LOC_04 §3)"`

### Task 2.2: Author Alaska fish spawnZones

**Files:** Modify `src/config/Fish.luau`; Test `tests/Fishing.spec.luau`.

- [ ] **Step 1: Failing test** (every Alaska fish carries spawnZones).
- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Edit `src/config/Fish.luau`** — add `spawnZones`:

  | id | `spawnZones` | (water) |
  |---|---|---|
  | `alaska_arctic_grayling` | `{ "interior_river" }` | river (interior) |
  | `alaska_dolly_varden` | `{ "interior_river" }` | river (interior) |
  | `alaska_sockeye_salmon` | `{ "interior_river" }` | river (interior) |
  | `alaska_rockfish_cod` | `{ "coastal_inlet" }` | coastal (Boat) |
  | `alaska_lingcod` | `{ "coastal_inlet" }` | coastal (Boat) |
  | `alaska_king_salmon` | `{ "coastal_inlet" }` | coastal (Boat — milestone) |
  | `alaska_giant_halibut` | `{ "open_gulf" }` | coastal (Boat — apex) |
  | `alaska_tyee_king` | `{ "coastal_inlet" }` | coastal (Boat) |
  | `alaska_ghost_of_the_gulf` | `{ "open_gulf" }` | coastal (Boat — Mythic) |

- [ ] **Step 4: Run, confirm pass.** `ALL GREEN ✓`.
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (2.2): Alaska fish spawnZones (interior river / coastal inlet / open Gulf)"`

### Task 2.3: The Boat sub-area marker (scope D — data only, no enforcement)

**Files:**
- Modify: `src/logic/Fishing.luau` (the `requiresBoat` helper), `src/config/Validation.luau` (the
  coastal/interior split assertion)
- Test: `tests/Fishing.spec.luau`

**Interfaces:**
- Produces: `Fishing.requiresBoat(fish): boolean` — `true` iff `fish.waterType` is a Boat-gated water type
  (`coastal` or `deepSea`); the marker Step 11's enforcement reads. NO Boat, NO enforcement built.

- [ ] **Step 1: Write the failing test** in `tests/Fishing.spec.luau`:

```lua
	t.section("Fishing — Boat sub-area marker (coastal = Boat-gated; interior = no Boat). Data only (Step 11 enforces)")
	do
		t.ok("the King Salmon MILESTONE is coastal/Boat-gated (LOC_04 §4/§7 — spec, not the build prompt)", Fishing.requiresBoat(Catalog.fish.alaska_king_salmon))
		t.ok("the Giant Halibut apex is Boat-gated", Fishing.requiresBoat(Catalog.fish.alaska_giant_halibut))
		t.ok("interior grayling/dolly/sockeye are NOT Boat-gated (shore-accessible)", (function()
			return not Fishing.requiresBoat(Catalog.fish.alaska_arctic_grayling)
				and not Fishing.requiresBoat(Catalog.fish.alaska_dolly_varden)
				and not Fishing.requiresBoat(Catalog.fish.alaska_sockeye_salmon)
		end)())
		t.ok("Bayou/Appalachia fish are shore-accessible (no Boat at the MVL's first two)", Fishing.requiresBoat(Catalog.fish.bayou_blue_catfish) == false and Fishing.requiresBoat(Catalog.fish.appalachia_trophy_largemouth_bass) == false)
	end
```

- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Implement** in `src/logic/Fishing.luau`:

```lua
-- Boat sub-area marker (SYS_fishing §7): coastal / deep-sea water is Boat-gated (a vehicle with the
-- matching accessGrant opens the cell). pond/river/lake are shore-accessible. This is the DATA marker
-- Step 11's coastal sub-area enforcement reads; Step 10 builds NO Boat and NO enforcement.
local BOAT_GATED_WATER: { [string]: boolean } = { coastal = true, deepSea = true }
function M.requiresBoat(fish: Fish): boolean
	return BOAT_GATED_WATER[fish.waterType] == true
end
```

  In `src/config/Validation.luau`, add a coastal/interior integrity assertion in `validateConfig` (after
  the fish loop): the King Salmon milestone is coastal (the spec, follow it), and assert the Alaska roster's
  interior/coastal split matches the spec so a mis-tag fails the load:

```lua
	-- Boat sub-area data integrity (LOC_04 §4/§7): the King Salmon MILESTONE is coastal/Boat-gated (per
	-- spec — the pure-fisher conquest waits for the Boat, Step 11); the interior run species are not.
	assert(Fishing.requiresBoat(config.fish.alaska_king_salmon), "king salmon must be coastal/Boat-gated (LOC_04 §4/§7)")
	assert(not Fishing.requiresBoat(config.fish.alaska_sockeye_salmon), "interior sockeye must be shore-accessible (no Boat)")
```

- [ ] **Step 4: Run, confirm pass.** `ALL GREEN ✓`.
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (2.3): Boat sub-area marker (Fishing.requiresBoat) + coastal/interior integrity (data only)"`

### Task 2.4: Author the Alaska shell zone data + wire validatePlacement

**Files:** Modify `src/config/Shells.luau`; Test `tests/Shell.spec.luau`.

- [ ] **Step 1: Failing test** (Alaska shell registered; arrival = Harbor Camp; zones present:
      `tundra_flats`, `spruce_riverbottom`, `the_crags`, `salmon_falls`, `interior_river`, `coastal_inlet`,
      `open_gulf`, `frozen_lake`).
- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Implement** in `src/config/Shells.luau` — add an `alaska` shell (LOC_04 §2). Zones:
  - `harbor_camp` (arrival + vendor; `arrivalZoneId = "harbor_camp"`; vendor/travel anchors here)
  - `tundra_flats` (hunting — hare, caribou, moose interior)
  - `spruce_riverbottom` (hunting — sitka deer, moose, grizzly approach)
  - `the_crags` (hunting — Dall sheep range; no catalog target but keep the zone for completeness/Studio)
  - `salmon_falls` (hunting / rareSite — the grizzly co-op apex + Glacier Grizzly)
  - `interior_river` (fishing — grayling/dolly/sockeye; shore-accessible)
  - `coastal_inlet` (fishing — rockfish/lingcod/king salmon; Boat-gated cell, walled until Step 11)
  - `open_gulf` (fishing / rareSite — halibut + Ghost of the Gulf; Boat-gated)
  - `frozen_lake` (fishing — seasonal ice-fishing; no MVL catalog target, zone present for §9)
  - `landmarks`: `the_glacier` (`isBeacon = true` — hero shot/wayfinding), `harbor_camp`, `tundra_flats`,
    `salmon_falls`, `the_crags`, `open_gulf`, `frozen_lake`.
  - `ambiancePlacements`: none required (the catalog has no `alaska_*` ambianceOnly creature — the LOC §3
    ambiance list (ptarmigan/fox/eagle/otter) is not in the representative catalog; leave `{}`).
  - `render`: snow-glare budget, e.g. `{ fogStart = 100, fogEnd = 380, drawDistance = 380 }` (LOC_04 §2.5).
  - Register `[D.Alaska] = alaska` in `byDestination`; `Shell.validateShell(alaska, Catalog)`; wire
    `Spawner.validatePlacement` for hunting + fishing (mirror 1.3). **`ZoneKind` has no "coastal" value** —
    coastal zones use `kind = "fishing"`; the Boat-gating lives on the fish `waterType`, not the zone.
- [ ] **Step 4: Run, confirm pass** (`rojo build` confirms sync). `ALL GREEN ✓`.
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (2.4): Alaska shell zone data (interior + coastal sub-area) + validatePlacement"`

### Task 2.5: Author the Alaska spawn config (LOC_04 §8.4)

**Files:** Modify `src/config/Spawning.luau`; Test `tests/Spawner.spec.luau`.

- [ ] **Step 1: Failing test** (Alaska hunting + fishing LoopSpawn present; ceilings slack over the modeled
      ~28/hr hunting, ~22/hr fishing).
- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Implement** in `src/config/Spawning.luau` (values from LOC_04 §8.4):

```lua
-- Alaska hunting (LOC_04 §8.4): modeled ~28/hr at T4; ceiling 30 (slack — anti-farming). Interior, Boat-free.
local alaskaHunting: LoopSpawn = {
	ceilingPerHour = 30,
	areas = {
		tundra_flats = { maxConcurrentTargets = 4, respawnIntervalSeconds = 40 },        -- hare singles + caribou herds
		spruce_riverbottom = { maxConcurrentTargets = 3, respawnIntervalSeconds = 60 },  -- sitka deer + bull moose
		the_crags = { maxConcurrentTargets = 2, respawnIntervalSeconds = 120 },          -- Dall sheep
		salmon_falls = { maxConcurrentTargets = 1, respawnIntervalSeconds = 300 },       -- grizzly (1 per Destination)
	},
}
-- Alaska fishing (LOC_04 §8.4): modeled ~22/hr at T4; ceiling 24 (slack). Interior shore + coastal (Boat).
local alaskaFishing: LoopSpawn = {
	ceilingPerHour = 24,
	areas = {
		interior_river = { maxConcurrentTargets = 4, respawnIntervalSeconds = 45 }, -- grayling/dolly/sockeye (shore)
		coastal_inlet = { maxConcurrentTargets = 4, respawnIntervalSeconds = 55 },  -- rockfish/lingcod/king (Boat)
		open_gulf = { maxConcurrentTargets = 3, respawnIntervalSeconds = 60 },      -- halibut (Boat, apex)
	},
}
```

  Add `[D.Alaska] = { hunting = alaskaHunting, fishing = alaskaFishing }` to `byDestination`. (`frozen_lake`
  is a seasonal event zone — not a routine spawn area; omit it from the spawn config.)

- [ ] **Step 4: Run, confirm pass.** `ALL GREEN ✓` (Shell `validatePlacement` from 2.4 now resolves Alaska
      areas + spawnZones; every coastal fish zone resolves; the moose's two zones resolve).
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (2.5): Alaska spawn config (interior + coastal zones/ceilings, LOC_04 §8.4)"`

### Task 2.6: Reconcile the apex weights + lift the fence + the co-op-only apex assertions (the headline)

**Files:**
- Modify: `src/config/Fish.luau` (halibut/ghost `typicalWeightKg`), `src/config/Validation.luau` (lift the
  fence to Alaska; add the co-op-only wall + soloable-band)
- Test: `tests/CrossTier.spec.luau`

**Interfaces:**
- Consumes: `Combat.soloableAt`/`coopSoloableAt`, `Fishing.landableAt`/`coopLandableAt`. Produces: the
  proven co-op-only apex property (grizzly + halibut: not soloable at T4, co-op-soluble at partyCap,
  soloable at the non-existent-at-MVL T5) + the soloable-band for Alaska routine + milestones, plus the
  T2→T4 survival-step quantification.

- [ ] **Step 1: Write the failing assertions** in `tests/CrossTier.spec.luau` — extend with an Alaska
      section:

```lua
	t.section("CrossTier — Alaska: routine + milestones ≤ T4-solo; co-op-only apex is a wall but co-op-soluble")
	local king = Catalog.fish.alaska_king_salmon
	local moose = Catalog.creatures.alaska_bull_moose
	t.ok("moose milestone soloable at T4 (gate passable solo, RD-A)", Combat.soloableAt(Catalog, moose, 4, 4))
	t.ok("king salmon milestone landable solo at T4 (Decision 7)", Fishing.landableAt(Catalog, king, 4, 4))
	-- Co-op-only apexes (keyed off minTier > 4, NOT a hardcoded id list):
	for _, c in Catalog.creatures do
		if c.destinationId == "alaska" and not c.ambianceOnly and c.minWeaponTierToKill > 4 then
			t.ok(c.id .. " above T4-solo (co-op-only, no MVL gear)", c.minWeaponTierToKill > 4)
			t.ok(c.id .. " NOT soloable at T4 even maxed (the wall, apex offset)", Combat.soloableAt(Catalog, c, 4, 4) == false)
			t.ok(c.id .. " co-op-soluble at T4 with a full party (not impossible)", Combat.coopSoloableAt(Catalog, c, 4, Catalog.tuning.combat.coop.partyCap))
			t.ok(c.id .. " soloable at T5 (the T+1 that ships post-launch)", Combat.soloableAt(Catalog, c, 5, 5))
		end
	end
	local halibut = Catalog.fish.alaska_giant_halibut
	t.ok("halibut above T4-solo reel (co-op-only)", halibut.minReelTier > 4)
	t.ok("halibut NOT landable solo at T4 (throws)", Fishing.landableAt(Catalog, halibut, 4, 4) == false)
	t.ok("halibut co-op-soluble at T4 with a full party (co-op-soluble, not a wall)", Fishing.coopLandableAt(Catalog, halibut, 4, Catalog.tuning.combat.coop.partyCap))

	t.section("CrossTier — the T2→T4 jump is a step, not a cliff (progression §2's flagged risk, quantified)")
	do
		-- Arriving at Alaska you survive its floor (non-lethal, dmg 0) trivially; the real survival beat is
		-- the soloable milestone moose. Quantify the survival margin at T4 armor and confirm it degrades
		-- gracefully (a step), not to a cliff: the moose stays soloable at T4, the floor is always safe.
		t.ok("moose: survival window at T4 armor comfortably exceeds the T4 kill time (tense, safe)", Combat.soloableAt(Catalog, moose, 4, 4))
		t.ok("Alaska floor (arctic hare, dmg 0) is non-lethal — survivable on arrival gear regardless of armor", Catalog.creatures.alaska_arctic_hare.damageToPlayer == 0)
	end
```

- [ ] **Step 2: Run, confirm fail.** The halibut co-op assertion fails: `typicalWeightKg.max = 180` →
      stamina 931 → even partyCap can't land it (38.6 > LandWindow 37.2). The wall/soloable-band assertions
      should pass (the grizzly with the apex offset reads not-soloable-at-T4, soloable-at-T5).

- [ ] **Step 3a: Reconcile the halibut weight** in `src/config/Fish.luau`. The Step-5 rule
      `representativeWeight = typicalWeightKg.max` × the authored `max = 180` over-states the fight vs the
      spec's worked weight (~80, stamina 441). Set `alaska_giant_halibut.typicalWeightKg = { min = 70, max =
      100 }` (still a "barn door"; `recordWeightKg = 230` keeps the legend; max 100 → stamina ≈ 539 → solo
      throws (FightTime ≈ 55.8 > 37.2) AND partyCap lands (FightTime ≈ 22.3 ≤ 37.2)). Verify the exact
      numbers with a scratch run before committing the value — pick the `max` that makes solo throw and
      partyCap land with margin (target `max` in the 90–110 range). Comment with the LOC_04 §4 /
      EQUIPMENT_MASTER §4.4 cite and the Step-5 `representativeWeight` rule.
      `alaska_ghost_of_the_gulf` is Mythic (rare+, excluded from the band assertion) — leave its weight as
      the colossal flavor, but note in a comment it is co-op-only by the same mechanism.

- [ ] **Step 3b: Lift the fence to Alaska** in `src/config/Validation.luau` — add an `elseif
      c.destinationId == "alaska"` arm mirroring the appalachia arm (soloable-band + role band for
      `minWeaponTierToKill <= 4`), and the same for fish via `Fishing.landableAt`. The co-op-only apexes
      (`minWeaponTierToKill > 4`) are EXCLUDED from the soloable-band claim but the band assertion still
      holds (`5 <= T+1 = 5`). With both appalachia + alaska arms present, the block is effectively
      universal — collapse the per-destination arms into a single non-bayou path if cleaner:

```lua
			else -- appalachia / alaska / any future destination: spec-faithful semantics (not strict equality)
				if c.minWeaponTierToKill <= 4 then -- soloable band
					assert(Combat.soloableAt(config, c, c.minWeaponTierToKill, math.max(c.minArmorTierToSurvive, c.minWeaponTierToKill)),
						c.id .. ": must be soloable at its authored min-tier (floor/ceiling sufficiency)")
				end
				assert(c.minWeaponTierToKill >= c.tier - 1 and c.minWeaponTierToKill <= c.tier + 1,
					c.id .. ": authored minWeaponTier must sit in the role band [T-1, T+1]")
```

- [ ] **Step 4: Run, confirm pass** (`./run-tests.sh` → `ALL GREEN ✓`). The require now validates ALL
      destinations; the co-op-only apex is proven a wall AND co-op-soluble.
- [ ] **Step 5: Commit.** `git commit -am "Step 10 (2.6): co-op-only apex proven (grizzly/halibut: wall + co-op-soluble); halibut weight reconciled; fence lifted; T2→T4 step quantified"`

---

## Phase 3 — Studio: the two worlds + fast-travel execution + telemetry (NOT headless)

> These are verified by the README **playtest checklist**, not `./run-tests.sh`. Each `.server.luau` change
> is excluded from analysis. Keep all `game:GetService`/`Workspace`/`TeleportService` calls inside
> `*.server.luau`. Mirror the Bayou blockout pattern (`WorldServer.server.luau:107-169` reads
> `Shells.byDestination` and converts `{x,y,z}`→`Vector3` via `vec()`).

### Task 3.1: Appalachia + Alaska world blockout

- [ ] Generalize the `WorldServer.server.luau` blockout so it builds a world for ANY shell in
      `Shells.byDestination` (it is currently Bayou-hardcoded). For each new shell: place zone placeholder
      parts (center/size, tagged with zoneId/kind), landmark beacons (the Lookout Ridge / the Glacier as
      `isBeacon` hero anchors), the vendor outpost + travel signpost anchors, and the ambiance scatter.
- [ ] Apply LOC §2.5 mobile budget: low-poly placeholders, fog-as-cull (`shell.render` fogStart/fogEnd/
      drawDistance), one Destination streamed at a time (hub-and-spoke). Distant ridges/glacier as
      silhouette/billboard LOD, not full geometry.
- [ ] Alaska: build the **interior** (huntable, King-Salmon-fishable-once-Boated) and the **coastal
      sub-area** (`coastal_inlet` + `open_gulf`) as distinct space, with the coastal cell **walled off**
      (no traversal/launch) until the Boat ships (Step 11). The seam exists as geometry; enforcement is
      Step 11.
- [ ] **Verify (Studio playtest checklist):** both worlds render within the mobile budget;
      navigate-by-looking landmarks legible (Lookout Ridge; the Glacier hero shot); terrain/zones read.

### Task 3.2: `teleportTarget` → arrival anchor resolution

- [ ] Resolve the `Destinations.luau` `teleportTarget` strings (`"Appalachia.OutpostCabin"`,
      `"Alaska.HarborCamp"`) to a physical spawn. Extend `ArrivalService` with a
      `resolveTeleportTarget(string) → Arrival` (or a shell lookup): the arrival zone of the destination's
      shell (`shell.zones[shell.arrivalZoneId].center`). Mirror `ArrivalService.resolveArrival`.

### Task 3.3: The `TeleportService` execution (close the Step-9 `TODO(step-10)`)

- [ ] In `WorldServer.server.luau:510-513`, replace the placeholder client-fire with the real
      `TeleportService` place/spawn execution for unlocked Appalachia/Alaska, resolving
      `result.teleportTarget` to the place id + spawn anchor (Task 3.2). The **gate is already enforced**
      (`DestinationService.travelTo` validates the persisted `unlockedDestinations` — Step 9); Step 10 only
      provides the execution into the destinations.
- [ ] **Verify (playtest):** a player who has unlocked Appalachia/Alaska fast-travels and lands at the right
      world's arrival anchor (Outpost Cabin / Harbor Camp); a locked destination still rejects (Step-9
      enforcement intact).

### Task 3.4: The co-op apex in Studio + telemetry

- [ ] **Verify (playtest):** the grizzly/halibut are fightable by a party and infeasible solo at T4 (the
      co-op-soluble property, felt) — using the existing co-op math (`coopEffectiveHealth`/`coopNetDrain`),
      now exercised for real.
- [ ] Wire telemetry (alongside the existing telemetry sink in `WorldServer`): per-Destination
      time-to-conquer (the Moose / King-Salmon milestones); the co-op-apex attempt/success split
      (grizzly/halibut — are parties forming and winning?); the T2→T4 gate drop-off (gear-afford vs
      milestone — the highest-risk-jump canary); per-Destination routine income vs the modeled band.
- [ ] **Verify (telemetry):** the four streams populate in a Studio session.

---

## Phase 4 — Close-out

### Task 4.1: README + the deferred table

- [ ] Add a "Step 10 — Appalachia & Alaska" section to `README.md`: the rosters-already-built note
      (verified/extended, NOT re-authored); **the cross-tier rigor as the discharged T2→T4 risk, recorded
      honestly** — strict `derived==authored` was proven unachievable (physical-min ≠ design role-anchor),
      so the spec-faithful floor/ceiling semantics (sufficiency + wall + co-op-soluble + role band) were
      asserted instead, with the two derivation defects fixed (the (hits−1) survival window + the apex
      offset); the co-op-only-apex / soloable-milestone split; the spawn-config + re-skin-behavior-check +
      Boat-marker additions; the halibut weight reconciliation. Name the deferrals: **Boat enforcement →
      Step 11, dogs → Step 11, Rockies → post-launch**.
- [ ] Record the binding reconciliations in the README "Binding-spec reconciliations" section: (a) the
      semantic-assertion decision (with the user's sign-off); (b) **King Salmon stays coastal/Boat-gated —
      build-prompt §D's "interior" claim contradicts LOC_04 §4/§7 and was rejected**; (c) the non-threat
      fleer `minArmor` 1→0; (d) the halibut `typicalWeightKg` reconciliation for co-op-solubility.
- [ ] Update the Studio playtest checklist with the Phase-3 items.
- [ ] **Commit.** `git commit -am "Step 10 (4.1): README — Step 10 section + reconciliations + deferred table"`

### Task 4.2: Full DoD gate + reconciliation green

- [ ] Run `./run-tests.sh` → `ALL GREEN ✓` (strict-clean every headless module; all specs incl. the new
      `CrossTier.spec`; negative fixtures still FAIL; `rojo build` succeeds).
- [ ] Confirm the **economy reconciliation stays green for both**: the existing
      `routineHourSum("appalachia") == income(2) == 1700` and `routineHourSum("alaska") == income(4) ==
      4913` tests in `tests/Economy.spec.luau` (both loops). They do not depend on spawnZones/Spawning, so
      they should be untouched — verify.
- [ ] Confirm **Steps 1–9 stay green** (the full suite is one run).
- [ ] Confirm **no stray probe files** in `tests/` (`tests/_probe_*` deleted).
- [ ] **Commit** any final fixups.

---

## Self-Review (run against the build prompt's scope A–G + DoD)

- **A (cross-tier derivation):** Phase 0 (defect fixes + helpers) + 1.5 + 2.6 (semantic assertions,
  universal; co-op-only apex wall + co-op-soluble; role band; T2→T4 step). Strict equality consciously
  replaced per the user decision — recorded in README. ✓
- **B (spawn config):** Tasks 1.3/1.4 (Appalachia) + 2.4/2.5 (Alaska); `validatePlacement` extends the
  spawnZones-on-every-target requirement to both. ✓
- **C (re-skin behavior-template check):** Task 0.3 (tier check already existed; behavior-template added). ✓
- **D (Boat markers, data only):** Task 2.3 (`Fishing.requiresBoat` + coastal/interior integrity; King
  Salmon coastal per the spec decision). No enforcement. ✓
- **E (geometry):** Task 3.1 (Studio, enumerated). ✓
- **F (TeleportService):** Tasks 3.2/3.3 (Studio, closes the Step-9 TODO). ✓
- **G (telemetry):** Task 3.4 (Studio, enumerated). ✓
- **DoD headless:** survival-window/apex fixes, semantic assertions extended to both destinations, spawn
  config, re-skin check, Boat markers, reconciliation green, Steps 1–9 green. ✓
- **Out of scope honored:** no roster re-authoring (only deferred inputs + flagged stat fixes), no Boat/dogs/
  Rockies/new systems. ✓

**Type-consistency check:** helper names used consistently — `Combat.isApex`, `Combat.soloableAt`,
`Combat.coopSoloableAt`, `Fishing.landableAt`, `Fishing.coopLandableAt`, `Fishing.requiresBoat`,
`Validation.assertCreatureReskin`. Shell zone ids used in Creatures/Fish spawnZones (1.1/1.2/2.1/2.2) match
those authored in the shells (1.3/2.4) and the spawn areas (1.4/2.5): Appalachia {outpost_cabin, old_field,
oak_ridges, creek_bottoms, lookout_ridge, hollow_creek, mill_pond}; Alaska {harbor_camp, tundra_flats,
spruce_riverbottom, the_crags, salmon_falls, interior_river, coastal_inlet, open_gulf, frozen_lake}.
