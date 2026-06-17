# Wild World Step 11 — Boats, Mounts & Tracking Dogs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the already-authored Boat/mount/dog items teeth — enforce the Coastal-Skiff sub-area gate (zone-access + a server backstop), stand up the BoatDealer + Kennel & Stable Cash vendors, and prove the never-gate / never-power guardrail — without re-authoring any item data and without breaking Steps 1–10.

**Architecture:** Step 11 adds a thin pure-logic gate (`Fishing.ownsBoatForWater` + `Spawner.canAccessZone`/`offeredTargetsInZone`), a server-authoritative backstop in `CatchHandler`, one new vendor handler (`VendorHandler`, the atomic Step-6 buy pattern), and a build-time guardrail in `Validation`. The Boat is **access, never power**: ownership opens the coastal cell (gates which spawns a player is offered, and the catch the server will land); the fishing resolution functions take **no vehicle argument**, so the Boat structurally cannot alter a catch. The convenience lines (mounts/dogs) are sinks only — their gameplay *effects* are Studio. Everything headless is proven by `./run-tests.sh`; the world wiring + the felt effects are Studio playtest-pending.

**Tech Stack:** Luau (`--!strict`), the headless harness (`tests/harness.luau` + `tests/util.luau`), Rojo. Toolchain (`luau`, `luau-analyze`, `rojo`) on PATH at `~/.local/bin`. Require-by-string via `.luaurc` aliases `@src/...` / `@tests/...`.

## Global Constraints

- **Run all commands from the git root** `RobloxRPG/RobloxRPG/` (the nested dir with `.git`).
- **`./run-tests.sh` is the Definition-of-Done gate** — four gates: (1) `luau-analyze --!strict` clean on every headless module, (2) all unit tests pass, (3) the negative fixtures FAIL analysis, (4) `rojo build` succeeds. Baseline before Step 11: **892 passed, 0 failed, ALL GREEN**. Every task must end ALL GREEN.
- **Headless vs Studio split:** headless = `src/config/`, `src/logic/`, `src/server/**` *except* `*.server.luau`. Never put a Roblox global into a headless module. `*.server.luau` / `*.client.luau` / `client/` are Studio-only (excluded from gates 1–2; verified by the README playtest checklist) but must still `rojo build`.
- **DO NOT re-author items.** `Equipment.luau` already has every boat/mount/dog/bait fully fielded (`vehicle_coastal_skiff` `accessGrant = W.coastal` `cost cash(18000)`; mounts `cash(10200)`; dogs `cash(8000)`; `dog_redbone_rare` `tradeable = true` `cost cash(0)`). `tierInput = false` for all of them is derived, never authored. Step 11 *enforces / vends / wires*, it does not edit item data.
- **`tierInput = false` is the structural guarantee** — no vehicle/mount/dog is ever a tier input or a combat/catch power source. `EquipmentItem` carries **no** combat/catch/rarity power field at all (only `accessGrant: WaterType?` + cosmetic), and the fishing resolution (`netDrain`/`fightTime`/`landWindow`/`landable`) takes **no vehicle argument** — so the access-not-power invariant is structural, asserted by the guardrail + signatures, **not** a vacuous runtime equivalence test.
- **Error/reason codes are lowercase_with_underscores** machine codes returned to the client (e.g. `no_tackle`, `missing_bait`, `insufficient_funds`). The client maps them to actionable nouns.
- **Buying reuses the atomic Step-6 pattern** — `critical = true`; debit Cash via `Ledger.attemptDebit` + grant the typed-owned commodity via `Profile.mintCommodity` in one `Transaction`; insufficient-funds rejects with no partial state; buy ≠ equip; the rare dog is trade-routed (rejected), not Cash-bought.
- **Deferrals (do NOT build):** rare-breed *trading* → Step 12; the Winter Freeze event + the Ice-Fishing Kit's Frozen-Lake gate → Step 13; premium bait (entirely) + real-money Boat tiers → Step 14; the coastal water geometry / mount-traversal feel / dog-tracking UI → Studio; the Ocean Trawler (T7) → post-launch.

---

## File Structure

**Modify (headless — type-checked + tested):**
- `src/logic/Fishing.luau` — add `ownsBoatForWater` (the shared Boat-ownership predicate).
- `src/logic/Spawner.luau` — add `canAccessZone` (the primary sub-area gate) + `offeredTargetsInZone` (the per-player gated projection). `routineTargetsInZone` stays untouched (Steps 1–10 call it).
- `src/server/fishing/CatchHandler.luau` — add the server-authoritative `requires_boat` backstop (authority step) + the coastal-participation telemetry canary (commit).
- `src/config/Validation.luau` — extend `assertEquipmentItem` (mount/dog never-gate clause + never-power monetization-role clause) + add the gate `requiredAccessItems`-must-be-vehicle check.

**Create (headless):**
- `src/server/shop/VendorHandler.luau` — the BoatDealer + Kennel & Stable buy handler (intent `buyVendorItem`).
- `tests/VendorHandler.spec.luau` — the vendor spec.

**Modify (test specs — headless):**
- `tests/Fishing.spec.luau` — section: `ownsBoatForWater`.
- `tests/Spawner.spec.luau` — section: zone-access gate.
- `tests/CatchHandler.spec.luau` — section: the coastal backstop + access-not-power proof.
- `tests/Validation.spec.luau` — section: the never-gate / never-power guardrail.
- `tests/Gate.spec.luau` — section: convenience never changes a gate result.
- `tests/run.luau` — register `tests/VendorHandler.spec`.

**Modify (Studio-only — NOT type-checked/tested; must `rojo build`):**
- `src/server/world/WorldServer.server.luau` — require + register `VendorHandler`, flip the BoatDealer/KennelAndStable fixtures from `stub` to `built`, update the deferral comment.

**Modify (docs):**
- `README.md` — Step 11 section + the "Deferred — who owns what" table rows.

---

## Setup: branch

- [ ] **Step S1: Create the step branch** (the per-step branch model; commits are user-gated)

Run from the git root:
```bash
git checkout -b step-11-vehicles
```
Expected: `Switched to a new branch 'step-11-vehicles'`. (If the user prefers to work on `main`, skip — but branch first if on the default branch.)

- [ ] **Step S2: Confirm the baseline is green before touching anything**

Run: `./run-tests.sh 2>&1 | tail -5`
Expected: ends with `ALL GREEN ✓` and the unit line `[Wild World — Steps 1–10] 892 passed, 0 failed`.

---

## Task 1: The shared Boat-ownership predicate (`Fishing.ownsBoatForWater`)

**Files:**
- Modify: `src/logic/Fishing.luau` (add a type alias near line 13; add the function after `requiresBoat`, after line 189)
- Test: `tests/Fishing.spec.luau` (add `Util` require + a new section)

**Interfaces:**
- Consumes: `Schema.PlayerData`, `Schema.Config`; the existing `config.equipment[catalogId].accessGrant: WaterType?`; `profile.inventory.commodities` (`{ {instanceId, catalogId, intraLevel, equipped} }`).
- Produces: `Fishing.ownsBoatForWater(profile: PlayerData, config: Config, waterType: string): boolean` — true iff the player owns a vehicle (commodity) whose catalog `accessGrant` equals `waterType`. Consumed by Task 2 (`Spawner.canAccessZone`) and Task 3 (`CatchHandler` backstop).

- [ ] **Step 1: Write the failing test** — append this section inside the `return function(t: Harness.T)` body of `tests/Fishing.spec.luau` (e.g. just before the function's final `end`):

```lua
	t.section("Fishing — ownsBoatForWater: a Coastal Skiff opens 'coastal'; a Boat-less / wrong-water angler does not (Step 11)")
	do
		local none = Util.mkProfile(Catalog, { rod = 1, reel = 1 })
		t.ok("a Boat-less angler does NOT own coastal access", Fishing.ownsBoatForWater(none, Catalog, "coastal") == false)
		local skiff = Util.mkProfile(Catalog, { rod = 1, reel = 1 })
		table.insert(skiff.inventory.commodities, { instanceId = "ci_skiff", catalogId = "vehicle_coastal_skiff", intraLevel = 0, equipped = false })
		t.ok("a Coastal-Skiff owner DOES own coastal access", Fishing.ownsBoatForWater(skiff, Catalog, "coastal"))
		local lake = Util.mkProfile(Catalog, { rod = 1, reel = 1 })
		table.insert(lake.inventory.commodities, { instanceId = "ci_jon", catalogId = "vehicle_jon_boat", intraLevel = 0, equipped = false })
		t.ok("a lake Jon Boat does NOT open coastal water (wrong accessGrant)", Fishing.ownsBoatForWater(lake, Catalog, "coastal") == false)
	end
```

Also add the `Util` require to the top of `tests/Fishing.spec.luau` (it currently imports only `Harness`, `Catalog`, `Fishing`), right after the `Catalog` require:

```lua
local Util = require("@tests/util")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `luau tests/run.luau 2>&1 | grep -iE "ownsBoatForWater|attempt to call|nil value" | head`
Expected: FAIL — a runtime error like `attempt to call a nil value (field 'ownsBoatForWater')` (the function does not exist yet).

- [ ] **Step 3: Add the `PlayerData` type alias** in `src/logic/Fishing.luau`. Find (near line 12):

```lua
type Config = Schema.Config
type Fish = Schema.Fish
```
Replace with:
```lua
type Config = Schema.Config
type Fish = Schema.Fish
type PlayerData = Schema.PlayerData
```

- [ ] **Step 4: Implement `ownsBoatForWater`** in `src/logic/Fishing.luau`. Find the `requiresBoat` block (lines 187–189):

```lua
function M.requiresBoat(fish: Fish): boolean
	return BOAT_GATED_WATER[fish.waterType] == true
end
```
Insert immediately after it (before the `-- ── §9 co-op assist` comment):
```lua

-- ── Step 11: the shared Boat-OWNERSHIP check behind BOTH the zone-access gate (Spawner.canAccessZone) and
-- the catch-level backstop (CatchHandler). A Boat is a commodity; its accessGrant lives on the catalog item,
-- never on the profile. This answers OWNERSHIP only — the fight math (netDrain/fightTime/landWindow/landable)
-- takes no vehicle, so the Boat opens the cell and grants no in-cell power (SYS_fishing §7). ──
function M.ownsBoatForWater(profile: PlayerData, config: Config, waterType: string): boolean
	for _, c in profile.inventory.commodities do
		local item = config.equipment[c.catalogId]
		if item ~= nil and item.accessGrant == waterType then
			return true
		end
	end
	return false
end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `luau tests/run.luau 2>&1 | tail -3`
Expected: `[Wild World — Steps 1–10] 895 passed, 0 failed` (892 + 3 new), no failures.

- [ ] **Step 6: Full gate**

Run: `./run-tests.sh 2>&1 | tail -3`
Expected: `ALL GREEN ✓`.

- [ ] **Step 7: Commit** (when the user authorizes commits)

```bash
git add src/logic/Fishing.luau tests/Fishing.spec.luau
git commit -m "feat(step11): add Fishing.ownsBoatForWater (the shared Boat-ownership predicate)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: The primary sub-area gate (`Spawner.canAccessZone` + `offeredTargetsInZone`)

**Files:**
- Modify: `src/logic/Spawner.luau` (add a `Fishing` require + `PlayerData` alias; add two functions after `routineTargetsInZone`, after line 97)
- Test: `tests/Spawner.spec.luau` (add `Util` require + a new section)

**Interfaces:**
- Consumes: `Fishing.requiresBoat`, `Fishing.ownsBoatForWater` (Task 1); the existing local `zonesContain`; `config.fish` (`{ destinationId, spawnZones, waterType, ... }`); `Enums.Loop`.
- Produces:
  - `Spawner.canAccessZone(profile: PlayerData, config: Config, destinationId: string, zoneId: string): boolean` — true if the zone is shore-accessible (homes no Boat-gated fish) OR the player owns a vehicle whose `accessGrant` matches the zone's Boat-gated water.
  - `Spawner.offeredTargetsInZone(profile: PlayerData, config: Config, destinationId: string, zoneId: string, loop: Loop?): { string }` — `routineTargetsInZone` gated by `canAccessZone` for the fishing loop (returns `{}` for a Boat-less player in a Boat-gated zone); identical to `routineTargetsInZone` for shore zones and the hunting loop.

- [ ] **Step 1: Write the failing test** — append this section inside the `return function(t: Harness.T)` body of `tests/Spawner.spec.luau`:

```lua
	t.section("Spawner — the Boat sub-area gate: a Coastal Skiff is required to be OFFERED coastal-zone fish (Step 11)")
	do
		local noBoat = Util.mkProfile(Catalog, { rod = 4, reel = 4 })
		local withBoat = Util.mkProfile(Catalog, { rod = 4, reel = 4 })
		table.insert(withBoat.inventory.commodities, { instanceId = "ci_skiff", catalogId = "vehicle_coastal_skiff", intraLevel = 0, equipped = false })

		-- canAccessZone: the coastal cell is gated, the interior river is not
		t.ok("coastal_inlet is LOCKED without the Skiff", Spawner.canAccessZone(noBoat, Catalog, "alaska", "coastal_inlet") == false)
		t.ok("open_gulf is LOCKED without the Skiff", Spawner.canAccessZone(noBoat, Catalog, "alaska", "open_gulf") == false)
		t.ok("coastal_inlet is OPEN with the Skiff", Spawner.canAccessZone(withBoat, Catalog, "alaska", "coastal_inlet"))
		t.ok("the interior river is shore-accessible (no Boat) for everyone", Spawner.canAccessZone(noBoat, Catalog, "alaska", "interior_river"))

		-- offeredTargetsInZone: a Boat-less angler is offered NOTHING in the coastal cell; with the Skiff, the
		-- coastal routine population (king salmon) appears. routineTargetsInZone (the content query) is unchanged.
		local function has(list: { string }, id: string): boolean
			for _, v in list do
				if v == id then return true end
			end
			return false
		end
		local offeredNone = Spawner.offeredTargetsInZone(noBoat, Catalog, "alaska", "coastal_inlet", Enums.Loop.Fishing)
		local offeredBoat = Spawner.offeredTargetsInZone(withBoat, Catalog, "alaska", "coastal_inlet", Enums.Loop.Fishing)
		t.eq("a Boat-less angler is offered NO coastal spawns", #offeredNone, 0)
		t.ok("a Skiff owner IS offered the coastal routine population (king salmon)", has(offeredBoat, "alaska_king_salmon"))
		t.ok("routineTargetsInZone (the pure content query) still lists the coastal fish regardless of ownership", has(Spawner.routineTargetsInZone(Catalog, "alaska", "coastal_inlet", Enums.Loop.Fishing), "alaska_king_salmon"))
	end
```

Add the `Util` require to the top of `tests/Spawner.spec.luau` (it does not currently import it), after the `Catalog` require:

```lua
local Util = require("@tests/util")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `luau tests/run.luau 2>&1 | grep -iE "canAccessZone|offeredTargetsInZone|nil value" | head`
Expected: FAIL — `attempt to call a nil value (field 'canAccessZone')`.

- [ ] **Step 3: Add the `Fishing` require + `PlayerData` alias** in `src/logic/Spawner.luau`. Find (lines 13–20):

```lua
local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Spawning = require("@src/config/Spawning")

type Config = Schema.Config
type Shell = Schema.Shell
type Loop = Enums.Loop
type LoopSpawn = Spawning.LoopSpawn
```
Replace with:
```lua
local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Spawning = require("@src/config/Spawning")
local Fishing = require("@src/logic/Fishing")

type Config = Schema.Config
type Shell = Schema.Shell
type Loop = Enums.Loop
type LoopSpawn = Spawning.LoopSpawn
type PlayerData = Schema.PlayerData
```
(`Fishing` requires only `Schema`, so this introduces no require cycle.)

- [ ] **Step 4: Implement the two functions** in `src/logic/Spawner.luau`. Find the end of `routineTargetsInZone` (lines 96–97):

```lua
	return ids
end
```
(the `return ids` that closes `routineTargetsInZone`, immediately before the `-- Condition-gated RARE spawn predicate` comment). Insert immediately after that `end`:
```lua

-- ── Step 11: the PRIMARY Boat sub-area gate (SYS_fishing §7 / SYS_progression §2). A fishing zone is
-- Boat-gated iff it homes a Boat-gated fish (coastal/deep-sea water); the required vehicle is one whose
-- accessGrant matches that water. A player WITHOUT it can never be in the cell, so they are never offered its
-- spawns. Shore zones (pond/river/lake) are always accessible. Access, never power — the Boat opens the cell
-- and grants nothing inside it (the catch math reads no vehicle; CatchHandler is the independent backstop). ──
function M.canAccessZone(profile: PlayerData, config: Config, destinationId: string, zoneId: string): boolean
	local gatedWater: string? = nil
	for _, f in config.fish do
		if f.destinationId == destinationId and zonesContain(f.spawnZones, zoneId) and Fishing.requiresBoat(f) then
			gatedWater = f.waterType
			break
		end
	end
	if gatedWater == nil then
		return true -- shore-accessible: no Boat required
	end
	return Fishing.ownsBoatForWater(profile, config, gatedWater)
end

-- The PLAYER-FACING offered population = the routine population GATED by Boat access. A Boat-less player is
-- offered NOTHING from a Boat-gated fishing zone (the primary gate). routineTargetsInZone stays pure (the
-- content query, unchanged for Steps 1-10); this is the per-player projection. Hunting + shore zones are
-- unaffected (canAccessZone is vacuously true there).
function M.offeredTargetsInZone(profile: PlayerData, config: Config, destinationId: string, zoneId: string, loop: Loop?): { string }
	local lp = loop or Enums.Loop.Hunting
	if lp == Enums.Loop.Fishing and not M.canAccessZone(profile, config, destinationId, zoneId) then
		return {}
	end
	return M.routineTargetsInZone(config, destinationId, zoneId, lp)
end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `luau tests/run.luau 2>&1 | tail -3`
Expected: `[Wild World — Steps 1–10] 902 passed, 0 failed` (895 + 7 new), no failures.

- [ ] **Step 6: Full gate**

Run: `./run-tests.sh 2>&1 | tail -3`
Expected: `ALL GREEN ✓`.

- [ ] **Step 7: Commit** (when authorized)

```bash
git add src/logic/Spawner.luau tests/Spawner.spec.luau
git commit -m "feat(step11): Spawner.canAccessZone + offeredTargetsInZone (the primary coastal sub-area gate)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: The server-authoritative catch backstop + coastal-participation telemetry

**Files:**
- Modify: `src/server/fishing/CatchHandler.luau` (insert in the `authority` step after the `unknown_target` block, line 69; add telemetry in `commit` after the onboarding/daily block, before the conquest hook, line 127)
- Test: `tests/CatchHandler.spec.luau` (add helpers + a new section; no new requires)

**Interfaces:**
- Consumes: `Fishing.requiresBoat`, `Fishing.ownsBoatForWater` (Task 1); the existing `ctx.profile`, `ctx.config`, `deps.telemetry`.
- Produces: a new authority-step rejection code `requires_boat` for a Boat-gated catch by a player without the matching vehicle; a `fishing.coastalCatch` telemetry increment on a committed Boat-gated catch. No signature changes (the handler shape is unchanged).

- [ ] **Step 1: Write the failing test** — append this section inside the `return function(t: Harness.T)` body of `tests/CatchHandler.spec.luau` (it already has `angler()`, `shot()`, `landingAccum()`, `newReg()`, `deps()` helpers). First add two helpers near the existing `angler`/`shot` helpers (inside the `return function` body, before the first `t.section`):

```lua
	-- a T4 coastal angler at MAXED tackle (so the T4 fish is landable — the CrossTier sufficiency proof),
	-- holding king salmon's basic required bait. `withSkiff` mints the access commodity (NOT equipped — buy ≠ equip).
	local function coastalAngler(withSkiff: boolean): any
		local p = Util.mkProfile(Catalog, { rod = 4, reel = 4 })
		for _, c in p.inventory.commodities do
			c.intraLevel = 2 -- maxed tackle
		end
		p.inventory.fungible["herring"] = 5 -- king salmon's §4 yes/no bait gate
		if withSkiff then
			table.insert(p.inventory.commodities, { instanceId = "ci_skiff", catalogId = "vehicle_coastal_skiff", intraLevel = 0, equipped = false })
		end
		return p
	end
	-- a server-enriched LANDING shot for a T4 fish at maxed tackle (mirrors `shot`, but T4 reel drain).
	local function coastalShot(targetId: string, E: number): any
		local reelDrain = Fishing.reelDrainMax(Catalog, 4, "maxed")
		local stamina = Fishing.staminaToLand(Catalog, Catalog.fish[targetId])
		return {
			targetId = targetId,
			biteActive = true,
			E = E,
			claimedDrain = reelDrain * E,
			accumulatedStaminaBefore = stamina - reelDrain * E,
			owner = "u1",
		}
	end
```

Then add the section:

```lua
	t.section("CatchHandler — the coastal sub-area BACKSTOP: a Boat-gated catch needs the matching vehicle (Step 11)")
	do
		local function fire(p: any, payload: any): Gauntlet.HandleResult
			local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
			return Gauntlet.handle(newReg(), { intent = "catch", playerId = 1, payload = payload }, session, deps(true))
		end

		-- A spoofing client (claims to be in the coastal cell) without the Skiff is rejected by the server.
		local noBoat = coastalAngler(false)
		local rNoBoat = fire(noBoat, coastalShot("alaska_king_salmon", 0.7))
		t.ok("a King Salmon catch without the Coastal Skiff is REJECTED (requires_boat)", rNoBoat.ok == false and rNoBoat.reason == "requires_boat")
		t.eq("the rejected coastal catch produced no reward", #noBoat.cash.tail, 0)

		-- access-not-power: a T1 angler WITH the Skiff + bait still cannot land the T4 fish — the Boat cleared
		-- the access gate but granted ZERO fight power (same gear_insufficient a shore angler of T1 would hit).
		local t1Skiff = Util.mkProfile(Catalog, { rod = 1, reel = 1 })
		t1Skiff.inventory.fungible["herring"] = 5
		table.insert(t1Skiff.inventory.commodities, { instanceId = "ci_skiff", catalogId = "vehicle_coastal_skiff", intraLevel = 0, equipped = false })
		local rUnderGeared = fire(t1Skiff, shot("alaska_king_salmon", 0.7, landingAccum("alaska_king_salmon")))
		t.ok("with the Skiff the access gate clears (reason is no longer requires_boat)", rUnderGeared.reason ~= "requires_boat")
		t.ok("but the Boat grants NO fight power: a T1 rig still can't land the T4 fish (gear_insufficient)", rUnderGeared.ok == false and rUnderGeared.reason == "gear_insufficient")

		-- the happy path: a T4 angler WITH the Skiff lands the coastal milestone (and the conquest sets).
		local geared = coastalAngler(true)
		local rGeared = fire(geared, coastalShot("alaska_king_salmon", 0.7))
		t.ok("a T4 angler with the Skiff lands the King Salmon", rGeared.ok)
		t.ok("the Alaska fishing conquest sets (the Boat-gated milestone route)", geared.conqueredDestinations.alaska == true)

		-- an interior fish is UNAFFECTED by the backstop (a Boat-less angler catches a shore fish normally).
		local interior = angler()
		local rInterior = fire(interior, shot("bayou_bluegill", 0.7, landingAccum("bayou_bluegill")))
		t.ok("a shore (interior) catch is unaffected by the Boat backstop", rInterior.ok)
	end
```

> Note: `shot(...)` builds a T1 reel-drain payload; for the under-geared case that is intentional (the T1 rig is what loses). `coastalShot(...)` builds the T4 landing payload for the happy path. The under-geared catch reaches `simulate` because `requires_boat` (authority) passes once the Skiff is owned, then fails the gear-adequacy check — proving the boat carries no power.

- [ ] **Step 2: Run the test to verify it fails**

Run: `luau tests/run.luau 2>&1 | grep -iE "requires_boat|coastal|King Salmon" | head`
Expected: FAIL — the no-Boat King Salmon catch currently succeeds (or fails for another reason), so `rNoBoat.reason == "requires_boat"` is false.

- [ ] **Step 3: Implement the authority backstop** in `src/server/fishing/CatchHandler.luau`. Find (lines 66–70):

```lua
				local fish = ctx.config.fish[ctx.payload.targetId]
				if fish == nil then
					return false, "unknown_target"
				end
				if ctx.payload.biteActive ~= true then
```
Replace with:
```lua
				local fish = ctx.config.fish[ctx.payload.targetId]
				if fish == nil then
					return false, "unknown_target"
				end
				-- Step 11: the server-authoritative coastal sub-area BACKSTOP (SYS_fishing §7). The PRIMARY gate is
				-- zone-access (Spawner.canAccessZone never offers a Boat-gated fish to a Boat-less player); this
				-- independently rejects a Boat-gated catch from a player lacking the matching vehicle — defense
				-- against a client that spoofs coastal-zone presence. The Boat is ACCESS, not power: the fight
				-- resolution (simulate, below) reads no vehicle, so a Boat can never out-fish a shore angler.
				if Fishing.requiresBoat(fish) and not Fishing.ownsBoatForWater(ctx.profile, ctx.config, fish.waterType) then
					return false, "requires_boat" -- the client maps this to the actionable noun ("Requires the Coastal Skiff")
				end
				if ctx.payload.biteActive ~= true then
```

- [ ] **Step 4: Implement the coastal-participation telemetry** in `src/server/fishing/CatchHandler.luau`. Find (lines 122–131, inside `commit`):

```lua
				if not result.ambiance then
					Onboarding.advance(ctx.profile, "catch", ctx.now)
					Daily.recordAction(ctx.profile.daily, Enums.Loop.Fishing, ctx.now)
				end
				-- Step 9: a new conquest may newly satisfy a downstream gate's milestone half (atomic with the catch).
				if result.conquestNewlySet then
					Progression.commitUnlocks(ctx.profile, ctx.config)
				end
```
Replace with:
```lua
				if not result.ambiance then
					Onboarding.advance(ctx.profile, "catch", ctx.now)
					Daily.recordAction(ctx.profile.daily, Enums.Loop.Fishing, ctx.now)
				end
				-- Step 11: coastal-fishing participation canary (is the 18,000-Cash Skiff translating into coastal
				-- catches?). A Boat-gated catch that reaches commit is a coastal land (the gate passed in authority).
				local caught = ctx.config.fish[ctx.payload.targetId]
				if deps.telemetry ~= nil and caught ~= nil and Fishing.requiresBoat(caught) then
					deps.telemetry.incr("fishing.coastalCatch", 1)
				end
				-- Step 9: a new conquest may newly satisfy a downstream gate's milestone half (atomic with the catch).
				if result.conquestNewlySet then
					Progression.commitUnlocks(ctx.profile, ctx.config)
				end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `luau tests/run.luau 2>&1 | tail -3`
Expected: `[Wild World — Steps 1–10] 908 passed, 0 failed` (902 + 6 new), no failures.

- [ ] **Step 6: Full gate**

Run: `./run-tests.sh 2>&1 | tail -3`
Expected: `ALL GREEN ✓`.

- [ ] **Step 7: Commit** (when authorized)

```bash
git add src/server/fishing/CatchHandler.luau tests/CatchHandler.spec.luau
git commit -m "feat(step11): CatchHandler coastal backstop (requires_boat) + access-not-power proof + participation canary

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: The BoatDealer + Kennel & Stable vendor (`VendorHandler`)

**Files:**
- Create: `src/server/shop/VendorHandler.luau`
- Create: `tests/VendorHandler.spec.luau`
- Modify: `tests/run.luau` (register the new spec)

**Interfaces:**
- Consumes: `Schema`, `Enums`, `Profile.mintCommodity`, `Ledger.attemptDebit`/`balanceOf`, `Gauntlet.IntentHandler`/`Ctx`, `Types.IdGenerator`/`Telemetry`; the catalog items' `availableAt` (`BoatDealer`/`KennelAndStable`), `tradeable`, `cost` (`{cash}` or `{realMoney}`), `category`, `tier`, `accessGrant`.
- Produces: `VendorHandler.buyHandler(deps: VendorDeps): Gauntlet.IntentHandler` — intent `buyVendorItem`, `critical = true`. Authority codes: `unknown_item`, `not_sold_here`, `rare_trade_routed`, `real_money_not_here`, `insufficient_funds`. Commit: debit `(item.cost).cash` (Ledger tag `type = item.category`) + `Profile.mintCommodity(item.id, 0)`. `export type VendorDeps = { idGen: Types.IdGenerator, telemetry: Types.Telemetry? }`.

- [ ] **Step 1: Write the failing spec** — create `tests/VendorHandler.spec.luau`:

```lua
--!strict
-- Step 11 — the BoatDealer + Kennel & Stable vendors (the access sink + convenience sinks). The Step-6 atomic
-- buy pattern: server validates, debits the catalog's authored Cash price, grants the typed-owned commodity;
-- buy != equip; insufficient-funds rejects with no partial state; gear is not sold here (ShopHandler), real-
-- money packs are Step 14, and a tradeable rare breed (dog_redbone_rare) is trade-routed (Step 12), not bought.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Ledger = require("@src/server/ledger/Ledger")
local Gauntlet = require("@src/server/authority/Gauntlet")
local VendorHandler = require("@src/server/shop/VendorHandler")

return function(t: Harness.T)
	local telemetry = Fakes.newTelemetry()
	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, VendorHandler.buyHandler({ idGen = Fakes.newIdGenerator(), telemetry = telemetry }))
		return reg
	end
	local function deps(saveOk: boolean): Gauntlet.Deps
		return {
			config = Catalog,
			now = 100,
			saveFn = function()
				return saveOk
			end,
			markDirty = function() end,
			telemetry = Fakes.newTelemetry(),
		}
	end
	local function handle(p: any, payload: any, saveOk: boolean): Gauntlet.HandleResult
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		return Gauntlet.handle(newReg(), { intent = "buyVendorItem", playerId = 1, payload = payload }, session, deps(saveOk))
	end
	local function owns(p: any, catalogId: string): boolean
		for _, c in p.inventory.commodities do
			if c.catalogId == catalogId then return true end
		end
		return false
	end

	t.section("Vendor — buy the Coastal Skiff: debits 18000 + mints the (unequipped) access commodity")
	do
		local p = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 20000 } })
		local before = #p.inventory.commodities
		local r = handle(p, { itemId = "vehicle_coastal_skiff" }, true)
		t.ok("the Skiff buy succeeds", r.ok)
		t.eq("debited the authored Cash price 18000 (20000 -> 2000)", Ledger.balanceOf(p.cash), 2000)
		t.eq("a new commodity was minted", #p.inventory.commodities, before + 1)
		t.ok("the Skiff is owned", owns(p, "vehicle_coastal_skiff"))
		t.ok("the minted Skiff is NOT equipped (buy != equip; ownership is what gates)", (function()
			for _, c in p.inventory.commodities do
				if c.catalogId == "vehicle_coastal_skiff" then return c.equipped == false end
			end
			return false
		end)())
		local tagged = false
		for _, e in p.cash.tail do
			if e.type == "vehicle" then tagged = true end
		end
		t.ok("the ledger entry is tagged 'vehicle' (the access-sink telemetry)", tagged)
	end

	t.section("Vendor — buy a mount + a basic dog (the convenience sinks)")
	do
		local p = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 20000 } })
		t.ok("the Horse buy succeeds (10200)", handle(p, { itemId = "mount_horse" }, true).ok)
		t.eq("debited 10200 (20000 -> 9800)", Ledger.balanceOf(p.cash), 9800)
		t.ok("a Coonhound buy succeeds (8000)", handle(p, { itemId = "dog_coonhound" }, true).ok)
		t.eq("debited 8000 (9800 -> 1800)", Ledger.balanceOf(p.cash), 1800)
		t.ok("the mount is owned", owns(p, "mount_horse"))
		t.ok("the dog is owned", owns(p, "dog_coonhound"))
	end

	t.section("Vendor — rejections: gear is not sold here, the rare dog is trade-routed, insufficient funds")
	do
		-- gating gear (Outfitter/TackleShop) is ShopHandler's, not this vendor
		local pGear = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 99999 } })
		local rGear = handle(pGear, { itemId = "weapon_lever_action_rifle" }, true)
		t.ok("gear is rejected (not_sold_here)", rGear.ok == false and rGear.reason == "not_sold_here")

		-- the tradeable rare breed routes to the Trading Post (Step 12), never a Cash buy
		local pRare = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 99999 } })
		local before = #pRare.inventory.commodities
		local rRare = handle(pRare, { itemId = "dog_redbone_rare" }, true)
		t.ok("the rare dog is rejected (rare_trade_routed)", rRare.ok == false and rRare.reason == "rare_trade_routed")
		t.eq("no commodity minted for the rare dog", #pRare.inventory.commodities, before)

		-- unknown item
		t.ok("an unknown item is rejected", handle(pGear, { itemId = "nope" }, true).reason == "unknown_item")

		-- insufficient funds: no debit, no mint
		local pPoor = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 100 } })
		local poorBefore = #pPoor.inventory.commodities
		local rPoor = handle(pPoor, { itemId = "vehicle_coastal_skiff" }, true)
		t.ok("rejected: insufficient funds", rPoor.ok == false and rPoor.reason == "insufficient_funds")
		t.eq("no Cash debited", Ledger.balanceOf(pPoor.cash), 100)
		t.eq("no commodity minted", #pPoor.inventory.commodities, poorBefore)
	end

	t.section("Vendor — the buy is atomic: a failed write reverts the debit + the grant (no orphan)")
	do
		local p = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 20000 } })
		local before = #p.inventory.commodities
		local r = handle(p, { itemId = "vehicle_coastal_skiff" }, false)
		t.ok("persist_failed", r.ok == false and r.reason == "persist_failed")
		t.eq("Cash reverted", Ledger.balanceOf(p.cash), 20000)
		t.eq("no orphan commodity", #p.inventory.commodities, before)
	end

	t.section("Vendor — the marquee Coastal-Skiff purchase telemetry fires")
	do
		local p = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 20000 } })
		handle(p, { itemId = "vehicle_coastal_skiff" }, true)
		t.ok("the coastalSkiff purchase counter incremented", (telemetry.snapshot() :: any)["economy.buy:coastalSkiff"] == 1)
	end
end
```

- [ ] **Step 2: Register the spec** in `tests/run.luau`. Find (lines 52–54):

```lua
	-- Step 10 (Appalachia cross-tier difficulty rigor)
	require("@tests/CrossTier.spec"),
}
```
Replace with:
```lua
	-- Step 10 (Appalachia cross-tier difficulty rigor)
	require("@tests/CrossTier.spec"),
	-- Step 11 (Boats, Mounts & Tracking Dogs — the vendor sinks)
	require("@tests/VendorHandler.spec"),
}
```

- [ ] **Step 3: Run the spec to verify it fails**

Run: `luau tests/run.luau 2>&1 | grep -iE "VendorHandler|cannot find|nil value" | head`
Expected: FAIL — `VendorHandler` module does not exist (require error / `attempt to index nil`).

- [ ] **Step 4: Implement the handler** — create `src/server/shop/VendorHandler.luau`:

```lua
--!strict
-- Step 11 — the BOAT DEALER + KENNEL & STABLE vendors (the access sink + the convenience sinks) as a single
-- server-authoritative Gauntlet handler (intent "buyVendorItem"). The precedent is ShopHandler.buyHandler /
-- LodgeShopHandler.buyDecorHandler: the CLIENT asserts nothing; the server validates, debits the catalog's
-- AUTHORED Cash price via the Ledger, and grants the typed-owned commodity. `critical` -> the debit + the
-- grant commit atomically (a failed write reverts both -- no orphan Cash or item). Buy != equip (vehicles/
-- mounts/dogs carry no equip slot; OWNERSHIP grants access -- Spawner.canAccessZone reads all commodities).
-- What this handler does NOT do: it never sells gating gear (that is ShopHandler), never sells a real-money
-- pack (Step 14), and never Cash-sells a tradeable rare breed (dog_redbone_rare -> Trading Post P2P, Step 12).
-- The Boat is ACCESS, never power: this grants no stat, only the item.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Profile = require("@src/logic/Profile")
local Ledger = require("@src/server/ledger/Ledger")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx
type EquipmentItem = Schema.EquipmentItem

local M = {}

export type VendorDeps = { idGen: Types.IdGenerator, telemetry: Types.Telemetry? }

-- The two Lodge vendors Step 6's gear shop deferred (gear -> Outfitter/TackleShop; rare breeds -> Trading Post).
local VENDOR_VENDORS: { [string]: boolean } = { BoatDealer = true, KennelAndStable = true }

local function resolve(ctx: Ctx): EquipmentItem?
	local itemId = ctx.payload.itemId
	if type(itemId) ~= "string" then
		return nil
	end
	return ctx.config.equipment[itemId]
end

function M.buyHandler(deps: VendorDeps): Gauntlet.IntentHandler
	return {
		intent = "buyVendorItem",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			local item = resolve(ctx)
			if item == nil then
				return false, "unknown_item"
			end
			if not VENDOR_VENDORS[item.availableAt] then
				return false, "not_sold_here" -- gating gear is the Outfitter/TackleShop (ShopHandler), not here
			end
			if item.tradeable then
				return false, "rare_trade_routed" -- a tradeable rare breed (dog_redbone_rare) -> Trading Post (Step 12)
			end
			local cash = (item.cost :: any).cash
			if cash == nil then
				return false, "real_money_not_here" -- a real-money pack is Step 14; this is the Cash sink
			end
			if Ledger.balanceOf(ctx.profile.cash) < cash then
				return false, "insufficient_funds"
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local item = assert(resolve(ctx), "buyVendorItem commit: authority should have caught this")
			local cash = (item.cost :: any).cash :: number
			local debit = Ledger.attemptDebit(ctx.profile.cash, cash, {
				type = item.category, -- "vehicle" | "mount" | "dog": the access/convenience sink tag (telemetry §F)
				tier = item.tier,
				loop = "none",
				validatingEventId = deps.idGen.next("vendor"),
			}, ctx.now)
			assert(debit.ok, "buyVendorItem commit: affordability verified, no yield, debit must succeed")
			Profile.mintCommodity(ctx.profile, item.id, 0) -- typed-owned at the entry floor; NOT equipped (buy != equip)
			if deps.telemetry ~= nil then
				deps.telemetry.incr("economy.buy:" .. item.category, 1) -- mount/dog adoption + vehicle access rate
				if item.accessGrant == Enums.WaterType.coastal then
					deps.telemetry.incr("economy.buy:coastalSkiff", 1) -- the marquee Alaska save-up (time-to-Skiff)
				end
			end
		end,
	}
end

return M
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `luau tests/run.luau 2>&1 | tail -3`
Expected: `[Wild World — Steps 1–10] 924 passed, 0 failed` (908 + 16 new), no failures. (The exact count may differ by ±a few if a sub-assertion is split; the bar is **0 failed**.)

- [ ] **Step 6: Full gate** (this also type-checks the new module)

Run: `./run-tests.sh 2>&1 | tail -3`
Expected: `ALL GREEN ✓`. (Confirm `src/server/shop/VendorHandler.luau` shows `✓` in gate 1.)

- [ ] **Step 7: Commit** (when authorized)

```bash
git add src/server/shop/VendorHandler.luau tests/VendorHandler.spec.luau tests/run.luau
git commit -m "feat(step11): VendorHandler — BoatDealer + Kennel & Stable Cash vendors (atomic buy, rare trade-routed)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: The never-gate / never-power guardrail (Validation + behavioral proof)

**Files:**
- Modify: `src/config/Validation.luau` (extend `assertEquipmentItem`, lines 94–103; add a `requiredAccessItems` check in the destinations loop, after line 249)
- Test: `tests/Validation.spec.luau` (add a guardrail section); `tests/Gate.spec.luau` (add a "convenience never gates" section)

**Interfaces:**
- Consumes: `Enums.Category` (`mount`/`dog`/`vehicle`), `Enums.MonetizationRole.powerProgression`, the existing `it.accessGrant`/`it.tierInput`/`it.monetizationRoles`; `dst.gate.requiredAccessItems: { ItemId }?`; `config.equipment`.
- Produces: build-time `error()` on (a) a mount/dog with an `accessGrant` or `tierInput`, (b) any non-tier-gear item carrying the `power-progression` monetization role, (c) a gate `requiredAccessItems` entry that is not a vehicle. No new public function (the checks extend `assertEquipmentItem` + `validateConfig`).

> **Why no new negative fixture:** `EquipmentItem` has **no** power field to forbid, and `tierInput`/`accessGrant` already type-check on every category — so a convenience-with-power state is not type-unrepresentable the way `category = "power"` is for a rank perk. The never-power guarantee is therefore enforced exactly like the existing **cosmetic / decor balance-free** invariants: a runtime `Validation` assertion at Catalog load + tests. Report this honestly (it is a load-time check, not a `tests/negative/*` fixture).

- [ ] **Step 1: Write the failing tests.**

(a) Append to `tests/Validation.spec.luau` (inside the `return function(t: Harness.T)` body):

```lua
	t.section("Validation — Step 11 never-gate / never-power guardrail (mount/dog can never gate or carry power)")
	do
		-- a mount that tried to gate water (accessGrant) is a build error
		local badAccess = table.clone(Catalog.equipment["mount_horse"]) :: any
		badAccess.accessGrant = "coastal"
		t.errs("a mount with an accessGrant is rejected (convenience never gates)", function()
			Validation.assertEquipmentItem(badAccess)
		end)
		-- a dog that tried to claim the power-progression monetization role is a build error
		local badPower = table.clone(Catalog.equipment["dog_coonhound"]) :: any
		badPower.monetizationRoles = { "power-progression" }
		t.errs("a dog with the power-progression role is rejected (convenience never carries power)", function()
			Validation.assertEquipmentItem(badPower)
		end)
		-- the authored mount/dog/vehicle catalog items pass cleanly (no false positive)
		t.test("the authored Horse passes", function()
			Validation.assertEquipmentItem(Catalog.equipment["mount_horse"])
		end)
		t.test("the authored Coastal Skiff passes (a vehicle MAY carry accessGrant)", function()
			Validation.assertEquipmentItem(Catalog.equipment["vehicle_coastal_skiff"])
		end)
	end
```

(b) Append to `tests/Gate.spec.luau` (inside the `return function(t: Harness.T)` body; `alaska` is already defined at the top as `Catalog.destinations[D.Alaska]`):

```lua
	t.section("Gate — convenience never gates: owning a Boat/mount/dog does NOT change a gate result (Step 11)")
	do
		-- under-geared, nothing conquered: Alaska is locked. Granting every convenience item changes nothing.
		local plain = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1 })
		local lockedPlain = Gate.evaluateGate(plain, alaska, Catalog)
		local loaded = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1 })
		table.insert(loaded.inventory.commodities, { instanceId = "ci_skiff", catalogId = "vehicle_coastal_skiff", intraLevel = 0, equipped = false })
		table.insert(loaded.inventory.commodities, { instanceId = "ci_horse", catalogId = "mount_horse", intraLevel = 0, equipped = false })
		table.insert(loaded.inventory.commodities, { instanceId = "ci_dog", catalogId = "dog_coonhound", intraLevel = 0, equipped = false })
		local lockedLoaded = Gate.evaluateGate(loaded, alaska, Catalog)
		t.ok("Alaska is locked for the plain under-geared player", lockedPlain.unlocked == false)
		t.ok("owning the Skiff + mount + dog does NOT unlock Alaska (gear/conquest only)", lockedLoaded.unlocked == false)
		t.eq("the unmet-reason count is identical with vs. without the convenience items", #lockedLoaded.unmetReasons, #lockedPlain.unmetReasons)
	end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `luau tests/run.luau 2>&1 | grep -iE "guardrail|never gate|power-progression|accessGrant" | head`
Expected: FAIL — `t.errs(...)` for the bad mount/dog do **not** raise yet (the current `assertEquipmentItem` accepts them), so those assertions fail.

- [ ] **Step 3: Extend `assertEquipmentItem`** in `src/config/Validation.luau`. Find (lines 94–104):

```lua
	if it.accessGrant ~= nil then
		assert(it.category == Enums.Category.vehicle, it.id .. ": only vehicles may carry an accessGrant")
	end
	-- monetizationRoles must be a set of legal Template-B values; cosmetics are identity-only (balance-free).
	for _, role in it.monetizationRoles do
		assert(Enums.MonetizationRoleSet[role] == true, it.id .. ": illegal monetization role '" .. tostring(role) .. "'")
		if it.category == Enums.Category.cosmetic then
			assert(role == Enums.MonetizationRole.identity, it.id .. ": a cosmetic's monetization is identity-only")
		end
	end
end
```
Replace with:
```lua
	if it.accessGrant ~= nil then
		assert(it.category == Enums.Category.vehicle, it.id .. ": only vehicles may carry an accessGrant")
	end
	-- Step 11 never-gate guardrail (SYS_progression §2 — "Mounts and Tracking Dogs never appear in a Gate,
	-- ever, for entry or sub-area"): a mount/dog can never gate (no accessGrant) and is never a tier input.
	-- accessGrant-on-non-vehicle is already rejected above and tierInput is derived; this states the mount/dog
	-- invariant explicitly with the spec citation and guards LiveOps-added convenience SKUs.
	if it.category == Enums.Category.mount or it.category == Enums.Category.dog then
		assert(it.accessGrant == nil, it.id .. ": a mount/dog can never gate (no accessGrant — convenience never gates shared content)")
		assert(it.tierInput == false, it.id .. ": a mount/dog is never a tier input (convenience, never power)")
	end
	-- monetizationRoles must be a set of legal Template-B values; cosmetics are identity-only (balance-free).
	for _, role in it.monetizationRoles do
		assert(Enums.MonetizationRoleSet[role] == true, it.id .. ": illegal monetization role '" .. tostring(role) .. "'")
		if it.category == Enums.Category.cosmetic then
			assert(role == Enums.MonetizationRole.identity, it.id .. ": a cosmetic's monetization is identity-only")
		end
		-- Step 11 never-power guardrail (EQUIPMENT_MASTER §4.5–4.7): only tier gear (weapon/armor/rod/reel) may
		-- carry the power-progression role; a vehicle/mount/dog/bait/tackle that claims it is a build-time error
		-- (access/convenience monetization can never be a combat/catch power input).
		if role == Enums.MonetizationRole.powerProgression then
			assert(it.tierInput, it.id .. ": only tier gear may carry the power-progression role (access/convenience items are never a power input)")
		end
	end
end
```

- [ ] **Step 4: Add the gate `requiredAccessItems`-must-be-vehicle check** in `src/config/Validation.luau`. Find (lines 247–249, inside the `for _, dst in config.destinations do` loop):

```lua
		for _, prereq in dst.gate.prerequisiteDestinations do
			assert(config.destinations[prereq] ~= nil, dst.id .. ": prerequisite '" .. prereq .. "' must resolve")
		end
```
Insert immediately after that block (before the `for _, targetId in dst.gate.milestoneTargets do` loop):
```lua
		-- Step 11 never-gate guardrail (SYS_progression §2): an ENTRY-gate access item must be a VEHICLE — a
		-- mount/dog can never gate. MVL Destinations carry none (requiredAccessItems nil); this is the forward
		-- guard for any future water-locked entry gate, and proves evaluateGate's access half can only ever read
		-- a Boat (never a convenience item).
		local accessItems: { string } = dst.gate.requiredAccessItems or {}
		for _, itemId in accessItems do
			local accessItem = assert(config.equipment[itemId], dst.id .. ": gate access item '" .. itemId .. "' must resolve")
			assert(accessItem.category == Enums.Category.vehicle, dst.id .. ": a gate access item must be a vehicle — convenience (mount/dog) can never gate (SYS_progression §2)")
		end
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `luau tests/run.luau 2>&1 | tail -3`
Expected: `0 failed` (≈ +7 assertions over Task 4's total).

- [ ] **Step 6: Full gate** (this re-runs `Validation.validateConfig` on the real catalog at require — confirms the new checks do not reject any authored item)

Run: `./run-tests.sh 2>&1 | tail -3`
Expected: `ALL GREEN ✓`.

- [ ] **Step 7: Commit** (when authorized)

```bash
git add src/config/Validation.luau tests/Validation.spec.luau tests/Gate.spec.luau
git commit -m "feat(step11): never-gate/never-power guardrail (Validation) + convenience-never-gates proof

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: World wiring (Studio-only) + README

**Files:**
- Modify: `src/server/world/WorldServer.server.luau` (Studio-only — NOT analyzed/tested; must `rojo build`)
- Modify: `README.md`

**Interfaces:**
- Consumes: `VendorHandler.buyHandler` (Task 4); the existing `registry`, `idGen`, `telemetry`, `fixture(...)`.
- Produces: the `buyVendorItem` handler registered in the one shared gauntlet registry; the BoatDealer + KennelAndStable fixtures marked `built`. (No headless test — verified by gate 4 `rojo build` + the README playtest checklist.)

- [ ] **Step 1: Require the handler** in `src/server/world/WorldServer.server.luau`. Find (line 35):

```lua
local ShopHandler = require("@src/server/shop/ShopHandler")
```
Insert immediately after it:
```lua
local VendorHandler = require("@src/server/shop/VendorHandler")
```

- [ ] **Step 2: Register the handler** in the same file. Find (line 101):

```lua
Gauntlet.register(registry, ShopHandler.upgradeHandler({ idGen = idGen, telemetry = telemetry }))
```
Insert immediately after it:
```lua
Gauntlet.register(registry, VendorHandler.buyHandler({ idGen = idGen, telemetry = telemetry })) -- Step 11: BoatDealer + Kennel & Stable
```

- [ ] **Step 3: Flip the fixtures from `stub` to `built`** in the same file. Find (lines 333–334):

```lua
fixture("BoatDealer", Vector3.new(30, 4, 20), Color3.fromRGB(90, 110, 140), "stub") -- Step 11
fixture("KennelAndStable", Vector3.new(-30, 4, 20), Color3.fromRGB(130, 110, 90), "stub") -- Step 11
```
Replace with:
```lua
fixture("BoatDealer", Vector3.new(30, 4, 20), Color3.fromRGB(90, 110, 140), "built") -- Step 11: Coastal Skiff + boats (Cash sink)
fixture("KennelAndStable", Vector3.new(-30, 4, 20), Color3.fromRGB(130, 110, 90), "built") -- Step 11: mounts + dogs (Cash sinks)
```

- [ ] **Step 4: Update the deferral comment** in the same file. Find (line 302):

```lua
--   • World Map (Travel Desk)  → Step 9 STUB · Trading Post → Step 12 STUB · Boat Dealer/Kennel → Step 11 STUB
```
Replace with:
```lua
--   • World Map (Travel Desk)  → Step 9 BUILT · Boat Dealer/Kennel → Step 11 BUILT · Trading Post → Step 12 STUB
```

- [ ] **Step 5: Verify rojo still builds** (gate 4; WorldServer is excluded from type-check/tests but must sync)

Run: `./run-tests.sh 2>&1 | tail -8`
Expected: gate 4 shows `✓ rojo build → /tmp/wildworld.rbxlx (… bytes)` and the overall result is `ALL GREEN ✓`. Confirm WorldServer appears under the `⌂ Studio-only` list (NOT analyzed) — that is correct.

- [ ] **Step 6: Update the README.** Add a Step 11 section mirroring the format of the existing Step 10 section, and update the "Deferred — who owns what" table. Insert the following content (adapt headers to match the README's existing section style):

````markdown
### Step 11 — Boats, Mounts & Tracking Dogs

**The items were already authored** (Equipment.luau) — Step 11 *enforces, vends, and wires* them; it re-authored nothing.

- **The Boat sub-area gate (two layers).** Coastal/deep-sea water is Boat-gated (`Fishing.requiresBoat`).
  - *Primary (zone-access):* `Spawner.canAccessZone(profile, config, destinationId, zoneId)` is false in `coastal_inlet`/`open_gulf` without a `coastal`-`accessGrant` vehicle (the Coastal Skiff), true with it; `Spawner.offeredTargetsInZone` returns `{}` for a Boat-less angler, so they are never offered coastal spawns. `routineTargetsInZone` (the pure content query) is unchanged.
  - *Backstop (server-authoritative):* `CatchHandler` independently rejects a `requiresBoat` catch (King Salmon / Halibut) from a player without the matching vehicle (`requires_boat`) — defense against a client spoofing coastal-zone presence. An interior (shore) fish is unaffected by either layer.
- **Access, never power (structural).** The vehicle item carries no combat/catch power field (only `accessGrant` + cosmetic), and the fishing resolution (`netDrain`/`fightTime`/`landWindow`/`landable`) takes **no vehicle argument** — so a Boat cannot branch the catch math. Proven by the guardrail + the access-not-power test (a T1 angler *with* the Skiff still hits `gear_insufficient` on the T4 King Salmon — the Boat opened the cell, granted zero fight power). This is asserted structurally, **not** via a vacuous runtime equivalence test.
- **The vendors (`VendorHandler`, intent `buyVendorItem`).** The Step-6 atomic buy: debit the catalog's authored Cash price + mint the typed-owned commodity in one `Transaction`; insufficient-funds rejects with no partial state; buy ≠ equip. The Coastal Skiff (18,000) is the marquee Alaska access sink; mounts (10,200) and basic dogs (8,000) are convenience sinks. Gear is `not_sold_here`; a real-money pack is `real_money_not_here` (Step 14); the tradeable rare dog (`dog_redbone_rare`) is `rare_trade_routed` (Trading Post, Step 12).
- **The never-gate / never-power guardrail (build-time, `Validation`).** A mount/dog can never carry an `accessGrant` or `tierInput`; **only** tier gear may carry the `power-progression` monetization role; a gate's `requiredAccessItems` may reference **only** a vehicle. `evaluateGate` reads no mount/dog/boat — proven behaviorally (owning the Skiff/mount/dog never changes a gate result). Like the cosmetic/decor balance-free checks, this is a load-time assertion (no `tests/negative/*` fixture — `EquipmentItem` has no power field to make type-unrepresentable).
- **Telemetry wired:** `economy.buy:coastalSkiff` (the marquee save-up), `economy.buy:vehicle|mount|dog` (adoption), `fishing.coastalCatch` (coastal participation), all ledger-tagged by category.

**Studio / telemetry (NOT headless — playtest-pending):** the physical coastal-water traversal (can't boat into the cell without the Skiff); the mount traversal/chase *feel* (no data stat); the dog detection/tracking *effect* (finds, never wins — never changes spawn rates); the live time-to-Skiff / access-not-power dashboards.

**Deferred — who owns what:** rare-breed *trading* → Step 12 (Trading Post); Winter Freeze event + Ice-Fishing Kit's Frozen-Lake gate → Step 13 (LiveOps); premium bait + real-money Boat tiers → Step 14 (monetization); coastal geometry / mount-traversal / dog-tracking UI → Studio; Ocean Trawler (T7) → post-launch.
````

Also update the README's "Deferred — who owns what" table rows: change **Boat Dealer / Kennel & Stable** from `Step 11` to **done (Step 11)**; leave Trading Post (Step 12), LiveOps/Winter Freeze (Step 13), and real-money/premium-bait (Step 14) pointing at their steps.

- [ ] **Step 7: Final full gate**

Run: `./run-tests.sh 2>&1 | tail -5`
Expected: `ALL GREEN ✓`, `0 failed`.

- [ ] **Step 8: Commit** (when authorized)

```bash
git add src/server/world/WorldServer.server.luau README.md
git commit -m "feat(step11): wire VendorHandler into WorldServer + README (Boats/Mounts/Dogs)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Definition of Done (verify all before claiming complete)

- [ ] `./run-tests.sh` → **ALL GREEN ✓**, `0 failed`, the negative fixtures still FAIL analysis, rojo builds.
- [ ] **Sub-area gate (two layers):** `canAccessZone(coastal)` false without the Skiff / true with it (so a Boat-less player is not offered coastal spawns), AND `CatchHandler` independently rejects a `requiresBoat` catch without the vehicle (`requires_boat`); an interior fish is unaffected.
- [ ] **Access-not-power (structural):** the vehicle carries no power field, the resolution signatures take no vehicle, and the T1-with-Skiff angler still gets `gear_insufficient` — asserted, not vacuously tested.
- [ ] **Vendors:** buying a boat/mount/basic-dog debits Cash + mints the commodity, atomic, insufficient-funds-rejects, buy ≠ equip; `dog_redbone_rare` Cash-buy is `rare_trade_routed`.
- [ ] **Guardrail:** a mount with `accessGrant` and a dog with `power-progression` fail at load; `evaluateGate` reads no convenience item (behavioral proof).
- [ ] **Steps 1–10 stay green** — `routineTargetsInZone` and the reconciliation are untouched (Boats/mounts/dogs are sinks, not routine income).
- [ ] **Studio/telemetry items enumerated honestly as unchecked** in the README (traversal feel, dog tracking, coastal-water feel, live dashboards).

---

## Self-Review (run after writing; fix inline)

**Spec coverage** (build-prompt section → task):
- §A Boat sub-area enforcement (primary zone-access + server backstop) → Tasks 1, 2, 3. ✓
- §B access-not-power invariant (structural) → Task 1 (no-vehicle predicate) + Task 3 (gear_insufficient proof) + Task 5 (guardrail). The resolution signatures already take no vehicle (verified in exploration; the plan adds no vehicle arg). ✓
- §C vendor buy path (BoatDealer + Kennel; rare rejected) → Task 4. ✓
- §D convenience effects (data here; gameplay Studio) → the items exist; the headless hook for the dog/mount is **ownership** (commodities), already readable; the *effects* are explicitly Studio (README). Mounts/dogs need no new data here — confirmed they must NOT change spawn rates/catch (guardrail Task 5). ✓
- §E never-gate / never-power guardrail → Task 5 (Validation) + Gate behavioral test. ✓
- §F telemetry → coastalSkiff/vehicle/mount/dog purchase counters (Task 4) + coastalCatch participation (Task 3); the live dashboards are Studio. ✓
- Out-of-scope (rare-breed trading, Winter Freeze/Ice-Fishing, premium bait/real-money, coastal geometry, Ocean Trawler) → built by none of the tasks; named in README deferrals. ✓

**Placeholder scan:** every code step shows complete code; every command shows expected output; the README task gives exact prose. No TBD/TODO. ✓

**Type/name consistency:** `ownsBoatForWater(profile, config, waterType)` is defined in Task 1 and consumed verbatim in Tasks 2–3; `canAccessZone`/`offeredTargetsInZone` signatures match between Task 2's definition and its test; `VendorDeps`/`buyHandler`/intent `buyVendorItem` match between Task 4's module, spec, and the Task 6 registration; reason codes (`requires_boat`, `not_sold_here`, `rare_trade_routed`, `real_money_not_here`, `insufficient_funds`) are used consistently. Ledger `type = item.category` is a free `string` (verified). `(item.cost :: any).cash` is the established narrowing (LodgeShopHandler). ✓

**Assertion-count note:** the "Expected" unit-test counts (895 → 902 → 908 → ~924 → +7) are guides, not gates — the only bar is **0 failed** + `ALL GREEN ✓`. If a count differs because an assertion was split/merged, that is fine.
