# Wild World — Step 9: World Map, Fast-Travel & Destination Gating — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the unlock-commit transition, the gated fast-travel flow, the World-Map / Passport surface data, and make the onboarding `WORLD_MAP` beat real — *calling* the existing gate machinery (`Gate.evaluateGate`, `EffectiveTier`, the teleport scaffold, the persisted Passport sets), reimplementing none of it.

**Architecture:** A thin progression-integrity-adjacent core: a pure `commitUnlocks` that re-evaluates every gate and adds newly-unlocked Destinations to the **persisted** `unlockedDestinations` set (never a live derivation), wired into the events that actually change its inputs (conquest + equip), plus the login/Travel-Desk catch-all; an enforced `DestinationService.travelTo` that validates the target against the persisted set (the gate-bypass guard); pure World-Map pin + Passport-count surface builders; and the `WORLD_MAP` funnel beat flipped from pass-through to a real `worldMapOpen` completion. The map UI, the `TeleportService` execution, and the Passport-readout feel are Studio.

**Tech Stack:** Luau (`--!strict` headless modules; `.server.luau` Studio glue), Rojo, the headless harness (`tests/run.luau` + `tests/harness.luau`), `./run-tests.sh` as the DoD gate.

## Global Constraints

- **Server-authority is mandatory.** Effective tiers, gate satisfaction, the unlock/conquer sets, and fast-travel eligibility are computed/validated server-side; the client may *display* a predicted state but never asserts unlock/conquer/tier/travel.
- **The unlocked set is persisted truth, NOT a live derivation.** `commitUnlocks` only ever *adds* (the one-time threshold crossing); a Destination already in `unlockedDestinations` stays unlocked even after the player sells/unequips the qualifying gear. `evaluateGate` is the trigger to *add*, never re-checked to *keep* membership. **Never derive the unlocked set live.**
- **Fast-travel cannot bypass a gate.** A travel target must be in the persisted `unlockedDestinations` set (NOT a live `evaluateGate` pass); this is the integrity line.
- **The legibility contract holds.** Every locked pin states its unmet requirements as `Gate.evaluateGate(...).unmetReasons` (actionable-noun strings); the UI consumes them, never re-deriving gate logic. No abstract tier number on the map.
- **Gates and the chain are data.** The DAG is keyed by `prerequisiteDestinations` (checked against **conquered**) in the Destination config; inserting Rockies is a data edit, proven by the re-thread test.
- **Conquest is idempotent set membership** (already true); the unlock-commit it triggers is likewise idempotent — farming a milestone re-grants and re-unlocks nothing.
- **`commitUnlocks` is one pass over all Destinations** — no candidate-scoping, no multi-pass fixpoint (the gate checks `prerequisiteDestinations ⊆ conquered`, a stable player action, so there is no unlock→unlock cascade).
- **Bounding:** only the Bayou is a playable Destination until Step 10. Step 9 owns the gating *logic*, the map *surface data*, and the fast-travel *mechanism + enforcement*; the worlds behind the gates (Appalachia/Alaska) are Step 10. Fast-travel's real target now is the Bayou (a funnel-COMPLETE player travels Lodge→Bayou); locked higher-tier pins show with their requirement strings but aren't travel-able.
- `--!strict` clean; Rojo-syncable; **`./run-tests.sh` ALL GREEN**; Steps 1–8 stay green. The World-Map UI, teleport execution, Passport readout, and onboarding reveal feel are Studio, enumerated honestly (unchecked).
- **Run all commands from the git root `/home/toor/claude/RobloxRPG/RobloxRPG/`.** Work on branch `step-9-worldmap` (off `main`).

## Decisions made (settle/flag per the prompt's prerequisites)

1. **`requiredAccessItems` — ADD, as an OPTIONAL field (`{ Ids.ItemId }?`).** The spec's Gate has it; the code `Gate` doesn't. The MVL needs none (no Destination is *entry*-gated by an access item — Alaska's Boat gates the *coastal sub-area*, enforced inside Alaska, Step 10/11). Making it **optional** adds the field + the entry-gate half to `evaluateGate` with **zero churn** to the 8 existing gate literals (5 in `Destinations.luau`, 3 in `Gate.spec`) — they omit it → treated as empty. Tested with a synthetic access-gated Destination. The sub-area Boat gate is explicitly NOT this (Step 10/11).
2. **The gear-change unlock hook is `EquipHandler`, NOT `ShopHandler` (a codebase-grounded correction of the prompt's wording).** The prompt says "after a gear purchase/upgrade — in ShopHandler's commit (buying gear may meet a requiredTier)." But in this codebase **buy mints an *unequipped* commodity (EHT unchanged until equipped) and upgrade is intra-tier (never changes EHT)** — so a `commitUnlocks` in `ShopHandler` would be a guaranteed no-op for the gear half. The action that changes EHT/EFT is **equip** (`EquipHandler`). So the gear-half-newly-met trigger goes in `EquipHandler.commit`; the conquest trigger goes in `FireHandler`/`CatchHandler` (gated on `result.conquestNewlySet`); and the login/Travel-Desk `openWorldMap` catch-all (critical) provides the write-through guarantee. **No hook in `ShopHandler`** (it would be dead code). This mirrors the prompt's own v2 placement corrections. (Flagged to the user in the SDD pre-flight.)
3. **`worldMapPins` is a distinct assembler, not a zip of the projection's `gates`.** A pin's `unlocked` MUST come from the **persisted** `unlockedDestinations` set, NOT `evaluateGate(...).unlocked` (which would re-lock on a gear sale). `unmetReasons` come from `evaluateGate` (only for locked pins). The projection's existing `gates[id].unlocked` is the *live* eval and is the wrong source for the pin — so `worldMapPins` exists to combine the set + the reasons correctly, and is the server-authoritative surface the projection exposes.
4. **The Rockies re-thread is already proven at the `evaluateGate` level** (`Gate.spec` lines 48–67). Step 9 ADDS a **`commitUnlocks`-level** re-thread test (a synthetic re-pointed config) proving the *unlock-commit* (the new code) is data-driven too — no progression-code change.

---

## File Structure

**Create (headless `--!strict`):**
- `src/logic/Progression.luau` — `commitUnlocks` (the unlock-commit) + `worldMapPins` + `passportCounts` (the Passport/surface operations; pure logic, mutates only `profile.unlockedDestinations`).
- `src/server/progression/WorldMapHandler.luau` — the `"openWorldMap"` gauntlet intent (advance the `WORLD_MAP` beat + run the `commitUnlocks` catch-all; `critical`).
- `tests/Progression.spec.luau` — `commitUnlocks` (idempotent, survives gear-sale, both-halves, one-pass, the commitUnlocks-level Rockies re-thread); the equip→unlock integration; `worldMapPins` (persisted-truth) + `passportCounts`.
- `tests/Travel.spec.luau` — `DestinationService.travelTo` enforcement (unlocked→ok+teleportTarget; locked→rejected; the gate-bypass guard against the persisted set).
- `tests/WorldMapHandler.spec.luau` — the `openWorldMap` intent completes the `WORLD_MAP` beat + runs `commitUnlocks`.

**Modify (headless):**
- `src/types/Schema.luau` — add optional `requiredAccessItems: { ItemId }?` to the `Gate` type.
- `src/logic/Gate.luau` — add the access-item entry-gate half to `evaluateGate`.
- `src/server/combat/FireHandler.luau` + `src/server/fishing/CatchHandler.luau` — `commitUnlocks` in commit, gated on `result.conquestNewlySet`.
- `src/server/authority/handlers/EquipHandler.luau` — `commitUnlocks` in commit (the gear-change trigger).
- `src/server/DestinationService.luau` — replace the `travelTo` stub with the enforced flow.
- `src/server/authority/Replication.luau` — add `worldMap` (pins) + `passport` (counts) to the projection.
- `src/logic/Onboarding.luau` — `WORLD_MAP` beat: pass-through → real `worldMapOpen` completion.
- `tests/Gate.spec.luau` — add the access-item access-half assertions (synthetic gated Destination).
- `tests/Onboarding.spec.luau` — fix the two funnel-to-COMPLETE sequences + the pass-through assertion for the now-real `WORLD_MAP` beat.
- `tests/Arrival.spec.luau` — insert `worldMapOpen` into the funnel-to-COMPLETE sequence.
- `tests/run.luau` — register the 3 new specs.
- `README.md` — the Step-9 section + module map + deferred table + DoD status.

**Modify (Studio-only `.server.luau`, NOT headless-analyzed):**
- `src/server/world/WorldServer.server.luau` — register `WorldMapHandler`; call `commitUnlocks` at login; wire the Travel Desk fixture to open the map (`openWorldMap`) + execute travel (`DestinationService.travelTo`).

**Not changed:** `Destinations.luau` (the optional `requiredAccessItems` is omitted = no entry access gate, correct for MVL); `EffectiveTier`, the persisted sets, the conquest write (all reused).

---

## Task 1: `requiredAccessItems` on the Gate + the entry-gate half

**Files:**
- Modify: `src/types/Schema.luau` (add optional `requiredAccessItems` to `Gate`)
- Modify: `src/logic/Gate.luau` (the access-item half of `evaluateGate`)
- Test: `tests/Gate.spec.luau` (a synthetic access-gated Destination)

**Interfaces:**
- Produces: `Schema.Gate.requiredAccessItems: { Ids.ItemId }?` (optional); `evaluateGate` now also reports a reason per unmet access item. Ownership = a commodity in `profile.inventory.commodities` whose `catalogId == itemId`.
- Note: optional field → the 5 `Destinations.luau` rows and the 3 existing `Gate.spec` literals need NO change.

- [ ] **Step 1: Write the failing test** — `tests/Gate.spec.luau`, add a new section before the final `t.section("Gate — Bayou is the free, always-unlocked root")`:

```luau
	t.section("Gate — required_access_items entry-gate half (synthetic water-locked Destination)")
	do
		-- a synthetic Destination entry-gated by owning an access item (the future water-locked case).
		local waterLocked: Schema.Destination = {
			id = "synthetic_island",
			name = "Synthetic Island",
			tier = 1,
			offeredLoops = { Enums.Loop.Fishing },
			gate = { requiredTier = 0, milestoneTargets = {}, prerequisiteDestinations = {}, requiredAccessItems = { "synthetic_boat" } },
			teleportTarget = "fixture",
		}
		local noBoat = Util.mkProfile(Catalog, { rod = 1, reel = 1 })
		local rNoBoat = Gate.evaluateGate(noBoat, waterLocked, Catalog)
		t.ok("locked without the access item", rNoBoat.unlocked == false)
		t.ok("the unmet reason names the access item (actionable noun)", Util.anyContains(rNoBoat.unmetReasons, "synthetic_boat") or Util.anyContains(rNoBoat.unmetReasons, "Boat"))
		-- own the access item: a commodity whose catalogId is the required item id.
		local withBoat = Util.mkProfile(Catalog, { rod = 1, reel = 1 })
		table.insert(withBoat.inventory.commodities, { instanceId = "boat1", catalogId = "synthetic_boat", intraLevel = 0, equipped = false })
		t.ok("unlocked once the access item is owned", Gate.evaluateGate(withBoat, waterLocked, Catalog).unlocked)
	end
```

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | tail -5`
Expected: failure — `requiredAccessItems` is not a legal `Gate` field (strict) and/or `evaluateGate` ignores it.

- [ ] **Step 3: Add the optional field to the `Gate` type** — `src/types/Schema.luau`, in the `Gate` type:

```luau
export type Gate = {
	requiredTier: number,
	milestoneTargets: { TargetId }, -- the prerequisite's conquest targets; loop-aware via the catalog
	prerequisiteDestinations: { DestinationId }, -- the DAG edges (⊆ conqueredDestinations)
	-- Step 9: entry-gate access items the player must OWN (e.g. a Boat for a water-locked Destination).
	-- OPTIONAL: MVL Destinations omit it (no entry is access-gated; Alaska's Boat gates a sub-area, Step 10/11).
	requiredAccessItems: { ItemId }?,
}
```

- [ ] **Step 4: Add the access-item half to `evaluateGate`** — `src/logic/Gate.luau`. Add a local ownership helper (after `targetName`):

```luau
-- Owns an access item iff a commodity with that catalogId is in the inventory (vehicles are commodities).
local function ownsAccessItem(profile: PlayerData, itemId: string): boolean
	for _, c in profile.inventory.commodities do
		if c.catalogId == itemId then
			return true
		end
	end
	return false
end
```

  In `evaluateGate`, after the milestone-half loop (before `return`), add the access half:

```luau
	-- ── Access half (entry-gate only): the player must OWN each required access item (§2). Optional —
	-- nil/empty for every MVL Destination. The sub-area Boat gate (Alaska coastal fishing) is NOT this.
	for _, itemId in (gate.requiredAccessItems or {}) do
		if not ownsAccessItem(profile, itemId) then
			local item = config.equipment[itemId]
			local itemName = item ~= nil and item.name or itemId
			table.insert(reasons, string.format("Acquire %s to reach %s", itemName, destination.name))
		end
	end
```

- [ ] **Step 5: Run the suite**

Run: `./run-tests.sh 2>&1 | tail -20`
Expected: ALL GREEN ✓ (the access-gated synthetic Destination locks without the item, unlocks with it; the 8 existing gate literals are unaffected by the optional field).

- [ ] **Step 6: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 9 (1/7): requiredAccessItems entry-gate half on evaluateGate (optional, spec-completeness)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `commitUnlocks` — the unlock-commit transition (the core headless piece)

**Files:**
- Create: `src/logic/Progression.luau`
- Test: `tests/Progression.spec.luau`
- Modify: `tests/run.luau` (register `Progression.spec`)

**Interfaces:**
- Consumes: `Gate.evaluateGate(profile, destination, config) -> { unlocked, unmetReasons }`; `profile.unlockedDestinations` / `conqueredDestinations` (persisted sets); `config.destinations`.
- Produces:
  - `Progression.commitUnlocks(profile: PlayerData, config: Config): { newlyUnlocked: { Ids.DestinationId } }` — re-evaluate EVERY Destination; for each `evaluateGate(...).unlocked` and NOT already in `profile.unlockedDestinations`, add it; return the list newly added. Idempotent; one pass; only ever adds.
- Used by: `FireHandler`/`CatchHandler`/`EquipHandler` commits (Task 3), `WorldMapHandler` (Task 6), `WorldServer` login (Task 7). `worldMapPins`/`passportCounts` are added in Task 5.

- [ ] **Step 1: Write the failing test** — create `tests/Progression.spec.luau`:

```luau
--!strict
-- Step 9 — commitUnlocks: re-evaluate every gate and ADD newly-unlocked Destinations to the PERSISTED
-- unlockedDestinations set. The unlocked set is persisted truth, NOT a live derivation: once added, a
-- Destination stays unlocked even after the qualifying gear is sold/unequipped. Idempotent; one pass;
-- only ever adds. (The handler wiring + the surface builders are later tasks.)

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Progression = require("@src/logic/Progression")
local Ids = require("@src/types/Ids")

local D = Ids.Destination

return function(t: Harness.T)
	t.section("Progression.commitUnlocks — conquest + gear both met → the Destination is added to the set")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, conquered = { D.Bayou } }) -- EHT 2 + Bayou conquered
		t.ok("Appalachia not yet in the persisted set", p.unlockedDestinations[D.Appalachia] == nil)
		local r = Progression.commitUnlocks(p, Catalog)
		t.ok("Appalachia is now unlocked (added to the set)", p.unlockedDestinations[D.Appalachia] == true)
		t.ok("the newly-unlocked list reports it", Util.anyContains(r.newlyUnlocked, D.Appalachia))
	end

	t.section("Progression.commitUnlocks — idempotent: a second pass adds nothing new")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, conquered = { D.Bayou } })
		Progression.commitUnlocks(p, Catalog)
		local r2 = Progression.commitUnlocks(p, Catalog)
		t.eq("nothing newly unlocked on the second pass", #r2.newlyUnlocked, 0)
		t.ok("Appalachia still unlocked", p.unlockedDestinations[D.Appalachia] == true)
	end

	t.section("Progression.commitUnlocks — PERSISTED TRUTH: a Destination stays unlocked after selling the gear")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, conquered = { D.Bayou } })
		Progression.commitUnlocks(p, Catalog)
		t.ok("Appalachia unlocked", p.unlockedDestinations[D.Appalachia] == true)
		-- drop the qualifying gear (unequip): EHT now 0; evaluateGate would re-lock — but the SET must not.
		p.equipped.weapon = nil
		p.equipped.armor = nil
		local r = Progression.commitUnlocks(p, Catalog)
		t.ok("Appalachia STAYS unlocked after the gear is gone (persisted truth, not re-derived)", p.unlockedDestinations[D.Appalachia] == true)
		t.eq("and nothing is newly unlocked / nothing re-locked", #r.newlyUnlocked, 0)
	end

	t.section("Progression.commitUnlocks — both halves required: conquest alone or gear alone does NOT unlock")
	do
		local conqOnly = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1, conquered = { D.Bayou } }) -- conquered, T1 gear
		Progression.commitUnlocks(conqOnly, Catalog)
		t.ok("conquest without the T2 gear does NOT unlock Appalachia", conqOnly.unlockedDestinations[D.Appalachia] == nil)
		local gearOnly = Util.mkProfile(Catalog, { weapon = 2, armor = 2 }) -- geared, nothing conquered
		Progression.commitUnlocks(gearOnly, Catalog)
		t.ok("gear without conquering the Bayou does NOT unlock Appalachia", gearOnly.unlockedDestinations[D.Appalachia] == nil)
	end

	t.section("Progression.commitUnlocks — one pass re-evaluates ALL Destinations (no cascade to iterate)")
	do
		-- A maxed dual-loop player who has conquered both Bayou AND Appalachia unlocks Appalachia AND Alaska
		-- in a SINGLE pass (the gate checks conquered, not unlocked — so one pass suffices).
		local p = Util.mkProfile(Catalog, { weapon = 4, armor = 4, conquered = { D.Bayou, D.Appalachia } })
		local r = Progression.commitUnlocks(p, Catalog)
		t.ok("Appalachia unlocked", p.unlockedDestinations[D.Appalachia] == true)
		t.ok("Alaska unlocked in the SAME pass", p.unlockedDestinations[D.Alaska] == true)
		t.ok("both reported newly unlocked", Util.anyContains(r.newlyUnlocked, D.Appalachia) and Util.anyContains(r.newlyUnlocked, D.Alaska))
	end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | tail -5`
Expected: error — `Progression` module does not exist.

- [ ] **Step 3: Create the module** — `src/logic/Progression.luau`:

```luau
--!strict
-- PROGRESSION OPERATIONS (SYS_progression §2/§3). The unlock-COMMIT + the Passport/World-Map surface.
-- commitUnlocks is the one-time threshold crossing: it re-evaluates every Destination's gate (via the
-- single source of truth, Gate.evaluateGate) and ADDS each newly-unlocked Destination to the PERSISTED
-- unlockedDestinations set. The set is authoritative truth — once added, a Destination stays unlocked even
-- if the player later sells/unequips the qualifying gear (§2: "you upgraded and lost Alaska" is the bug we
-- forbid). evaluateGate is the trigger to ADD, never re-checked to KEEP membership; the set is NEVER derived
-- live. Idempotent + one pass (the gate checks prerequisiteDestinations ⊆ CONQUERED — a stable player
-- action — so unlocking A never mechanically unlocks B; no cascade, no fixpoint). Pure: reads profile +
-- config, mutates only profile.unlockedDestinations (the Onboarding.advance / Daily.recordAction pattern).

local Schema = require("@src/types/Schema")
local Gate = require("@src/logic/Gate")
local Ids = require("@src/types/Ids")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type DestinationId = Ids.DestinationId

local M = {}

export type CommitResult = { newlyUnlocked: { DestinationId } }

-- commitUnlocks(profile, config): re-evaluate ALL gates; add each now-unlocked, not-already-in-set
-- Destination to the persisted set. Returns the list newly added (for telemetry). ONLY adds, never removes.
function M.commitUnlocks(profile: PlayerData, config: Config): CommitResult
	local newlyUnlocked: { DestinationId } = {}
	for id, destination in config.destinations do
		if profile.unlockedDestinations[id] ~= true and Gate.evaluateGate(profile, destination, config).unlocked then
			profile.unlockedDestinations[id] = true
			table.insert(newlyUnlocked, id)
		end
	end
	return { newlyUnlocked = newlyUnlocked }
end

return M
```

- [ ] **Step 4: Register the spec** — `tests/run.luau`, add after the Step-8 block:

```luau
	-- Step 9 (World Map, fast-travel, gating)
	require("@tests/Progression.spec"),
```

- [ ] **Step 5: Run the suite**

Run: `./run-tests.sh 2>&1 | tail -20`
Expected: ALL GREEN ✓ (commitUnlocks adds on both-halves-met, idempotent, persisted-truth survives gear sale, both halves required, one pass unlocks the whole chain).

- [ ] **Step 6: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 9 (2/7): commitUnlocks (persisted-truth unlock set, idempotent, one pass)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Wire `commitUnlocks` into its triggers (conquest + equip), atomically

**Files:**
- Modify: `src/server/combat/FireHandler.luau` (commit, gated on `result.conquestNewlySet`)
- Modify: `src/server/fishing/CatchHandler.luau` (commit, gated on `result.conquestNewlySet`)
- Modify: `src/server/authority/handlers/EquipHandler.luau` (commit — the gear-change trigger)
- Test: extend `tests/Progression.spec.luau` (conquest→unlock atomic; equip→unlock)

**Interfaces:**
- Consumes: `Progression.commitUnlocks` (Task 2); `RewardPipeline.Result.conquestNewlySet` (already exposed); the gauntlet `critical` Transaction (FireHandler/CatchHandler are `critical = true`; a save failure reverts the whole commit incl. the unlock).
- Produces: conquering the Bayou while T2-geared → Appalachia in the persisted set, atomically with the conquest; equipping T2 gear after conquering the Bayou → Appalachia unlocked.
- Note: NOT wired into `ShopHandler` — buy mints an *unequipped* commodity and upgrade is intra-tier; neither changes EHT, so a hook there would be a no-op (Decision 2). The equip hook + the login/Travel-Desk catch-all cover the gear path.

- [ ] **Step 1: Write the failing test** — append to `tests/Progression.spec.luau` (add the requires at the top):

```luau
local Fakes = require("@src/server/persistence/Fakes")
local Gauntlet = require("@src/server/authority/Gauntlet")
local FireHandler = require("@src/server/combat/FireHandler")
local EquipHandler = require("@src/server/authority/handlers/EquipHandler")
local RewardPipeline = require("@src/server/combat/RewardPipeline")
```

  Append these sections (the FireHandler payload mirrors `tests/FireHandler.spec.luau` — read it for the exact fields if a field is unclear). The Bayou hunting milestone target is `bayou_american_alligator`:

```luau
	t.section("Progression wiring — conquering the Bayou while T2-geared unlocks Appalachia (atomic with the kill)")
	do
		-- a T2-equipped hunter whose accumulated damage will be lethal on the milestone gator.
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, rod = 1, reel = 1 })
		local gator = Catalog.creatures["bayou_american_alligator"]
		local function fire(saveOk: boolean): Gauntlet.HandleResult
			local reg = Gauntlet.new()
			Gauntlet.register(reg, FireHandler.new({ idGen = Fakes.newIdGenerator(), payoutFn = function() return 1 end, telemetry = Fakes.newTelemetry() }))
			local payload = {
				targetId = "bayou_american_alligator", zone = "vital", distance = 5,
				lastShotAt = 0, rayHitTargetId = "bayou_american_alligator", targetAlive = true,
				accumulatedDamageBefore = gator.health, owner = "u1", partySize = 1, claimedDamage = nil,
			}
			local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
			return Gauntlet.handle(reg, { intent = "fire", playerId = 1, payload = payload }, session, {
				config = Catalog, now = 100, saveFn = function() return saveOk end, markDirty = function() end, telemetry = Fakes.newTelemetry(),
			})
		end
		-- NOTE: if the payload above does not produce a lethal/valid shot for the gator, copy the exact
		-- milestone-kill payload shape from tests/FireHandler.spec.luau (claimedDamage re-derivation etc.).
		t.ok("the milestone kill succeeds", fire(true).ok)
		t.ok("the Bayou is conquered", p.conqueredDestinations["bayou"] == true)
		t.ok("Appalachia is unlocked atomically with the conquest", p.unlockedDestinations[D.Appalachia] == true)
	end

	t.section("Progression wiring — a forced save failure reverts the conquest AND the unlock (no orphan)")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, rod = 1, reel = 1 })
		local gator = Catalog.creatures["bayou_american_alligator"]
		local reg = Gauntlet.new()
		Gauntlet.register(reg, FireHandler.new({ idGen = Fakes.newIdGenerator(), payoutFn = function() return 1 end, telemetry = Fakes.newTelemetry() }))
		local payload = {
			targetId = "bayou_american_alligator", zone = "vital", distance = 5, lastShotAt = 0,
			rayHitTargetId = "bayou_american_alligator", targetAlive = true,
			accumulatedDamageBefore = gator.health, owner = "u1", partySize = 1, claimedDamage = nil,
		}
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		local r = Gauntlet.handle(reg, { intent = "fire", playerId = 1, payload = payload }, session, {
			config = Catalog, now = 100, saveFn = function() return false end, markDirty = function() end, telemetry = Fakes.newTelemetry(),
		})
		t.ok("persist_failed", r.ok == false and r.reason == "persist_failed")
		t.ok("conquest reverted", p.conqueredDestinations["bayou"] == nil)
		t.ok("the unlock reverted with it (no orphan unlock)", p.unlockedDestinations[D.Appalachia] == nil)
	end

	t.section("Progression wiring — equipping T2 gear after conquering the Bayou unlocks Appalachia (the gear-change path)")
	do
		-- conquered the Bayou, owns T2 weapon+armor but has NOT equipped them yet (EHT still 1).
		local p = Util.mkProfile(Catalog, { weapon = 1, armor = 1, conquered = { D.Bayou } })
		-- mint owned-but-unequipped T2 weapon + armor (find real T2 items from the catalog).
		local function t2(category: string): string
			for _, it in Catalog.equipment do
				if it.category == category and it.tier == 2 then return it.id end
			end
			error("no T2 " .. category)
		end
		local w = { instanceId = "w2", catalogId = t2("weapon"), intraLevel = 0, equipped = false }
		local a = { instanceId = "a2", catalogId = t2("armor"), intraLevel = 0, equipped = false }
		table.insert(p.inventory.commodities, w)
		table.insert(p.inventory.commodities, a)
		local reg = Gauntlet.new()
		Gauntlet.register(reg, EquipHandler)
		local function equip(instanceId: string)
			local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
			return Gauntlet.handle(reg, { intent = "equip", playerId = 1, payload = { commodityInstanceId = instanceId } }, session, {
				config = Catalog, now = 100, saveFn = function() return true end, markDirty = function() end, telemetry = Fakes.newTelemetry(),
			})
		end
		assert(equip("w2").ok)
		t.ok("Appalachia not yet unlocked with only the weapon equipped (armor still T1)", p.unlockedDestinations[D.Appalachia] == nil)
		assert(equip("a2").ok)
		t.ok("equipping the T2 armor (EHT now 2) unlocks Appalachia", p.unlockedDestinations[D.Appalachia] == true)
	end
```

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | tail -8`
Expected: failures — the handlers don't call `commitUnlocks` yet (no unlock after conquest/equip).

- [ ] **Step 3: Wire `FireHandler`** — `src/server/combat/FireHandler.luau`. Add the require:

```luau
local Progression = require("@src/logic/Progression")
```

  In `commit`, after the existing `if not result.ambiance then ... end` block, add:

```luau
				-- Step 9: a NEW conquest may newly satisfy a downstream gate's milestone half → re-evaluate
				-- unlocks atomically with the kill (the gauntlet's Transaction reverts both on a failed save).
				if result.conquestNewlySet then
					Progression.commitUnlocks(ctx.profile, ctx.config)
				end
```

- [ ] **Step 4: Wire `CatchHandler`** — `src/server/fishing/CatchHandler.luau`. Add the require:

```luau
local Progression = require("@src/logic/Progression")
```

  In `commit`, after the existing `if not result.ambiance then ... end` block, add the identical guard:

```luau
				-- Step 9: a new conquest may newly satisfy a downstream gate's milestone half (atomic with the catch).
				if result.conquestNewlySet then
					Progression.commitUnlocks(ctx.profile, ctx.config)
				end
```

- [ ] **Step 5: Wire `EquipHandler`** — `src/server/authority/handlers/EquipHandler.luau`. Add the require:

```luau
local Progression = require("@src/logic/Progression")
```

  At the END of `commit` (after `commodity.equipped = true`), add:

```luau
		-- Step 9: equipping changes EHT/EFT, which may newly meet a gate's gear half → re-evaluate unlocks.
		-- (Buy/upgrade do NOT change EHT — buy mints unequipped, upgrade is intra-tier — so the gear-change
		-- unlock hook is here, not in ShopHandler. Rides equip's dirty-flag; the login/Travel-Desk catch-all
		-- + the critical conquest path provide the write-through guarantee.)
		Progression.commitUnlocks(ctx.profile, ctx.config)
```

- [ ] **Step 6: Run the suite**

Run: `./run-tests.sh 2>&1 | tail -20`
Expected: ALL GREEN ✓ (conquest→unlock atomic; save-fail reverts both; equip→unlock; Steps 1–8 stay green). If the FireHandler test payload doesn't produce a valid lethal shot, align it with `tests/FireHandler.spec.luau`'s milestone-kill payload (note in Step 1).

- [ ] **Step 7: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 9 (3/7): wire commitUnlocks into conquest (Fire/Catch) + equip handlers (atomic)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: The gated fast-travel flow (`DestinationService.travelTo`)

**Files:**
- Modify: `src/server/DestinationService.luau` (replace the `travelTo` stub)
- Test: `tests/Travel.spec.luau`
- Modify: `tests/run.luau` (register `Travel.spec`)

**Interfaces:**
- Consumes: `profile.unlockedDestinations` (the PERSISTED set — the enforcement reads this, NOT `evaluateGate`); `Catalog.destinations[id].teleportTarget`.
- Produces: `DestinationService.travelTo(profile, destinationId) -> TravelResult` where `TravelResult = { ok: boolean, reason: string?, teleportTarget: string? }`. `ok` iff the target is registered AND in `profile.unlockedDestinations`; on `ok`, `teleportTarget` is the destination's `teleportTarget`. The Studio caller executes `TeleportService` with `teleportTarget`.

- [ ] **Step 1: Write the failing test** — create `tests/Travel.spec.luau`:

```luau
--!strict
-- Step 9 — gated fast-travel ENFORCEMENT. travelTo validates the target against the PERSISTED
-- unlockedDestinations set (NOT a live evaluateGate) — the gate-bypass guard. A locked target is rejected
-- server-side; an unlocked target resolves its teleportTarget for the Studio TeleportService to execute.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local DestinationService = require("@src/server/DestinationService")
local Ids = require("@src/types/Ids")

local D = Ids.Destination

return function(t: Harness.T)
	t.section("Travel — an UNLOCKED target succeeds and resolves its teleportTarget")
	do
		local p = Util.mkProfile(Catalog, {}) -- freshProfile-like: Bayou seeded as the requiredTier-0 root
		p.unlockedDestinations[D.Bayou] = true
		local r = DestinationService.travelTo(p, D.Bayou)
		t.ok("travel to the unlocked Bayou is allowed", r.ok)
		t.eq("the teleportTarget resolves", r.teleportTarget, Catalog.destinations[D.Bayou].teleportTarget)
	end

	t.section("Travel — a LOCKED target is rejected server-side (the gate-bypass guard)")
	do
		local p = Util.mkProfile(Catalog, {}) -- Appalachia NOT in the unlocked set
		local r = DestinationService.travelTo(p, D.Appalachia)
		t.ok("travel to a locked Destination is rejected", r.ok == false and r.reason == "locked")
		t.eq("no teleportTarget is handed back", r.teleportTarget, nil)
	end

	t.section("Travel — the guard reads the SET, not a live gate eval (can't bypass by being 'qualified')")
	do
		-- a player who WOULD pass evaluateGate for Appalachia (T2 + conquered Bayou) but whose unlock was
		-- never committed to the set cannot travel — the persisted set is the only travel authority.
		local qualified = Util.mkProfile(Catalog, { weapon = 2, armor = 2, conquered = { D.Bayou } })
		-- deliberately do NOT call commitUnlocks; the set stays empty for Appalachia.
		t.ok("being gate-qualified but not in the unlocked set still cannot travel", DestinationService.travelTo(qualified, D.Appalachia).ok == false)
		-- and conversely: in the set but now under-geared (gear sold) STILL travels (persisted truth).
		local unlockedThenSold = Util.mkProfile(Catalog, {})
		unlockedThenSold.unlockedDestinations[D.Appalachia] = true -- committed earlier
		t.ok("in the set but no longer gate-qualified STILL travels (persisted truth)", DestinationService.travelTo(unlockedThenSold, D.Appalachia).ok)
	end

	t.section("Travel — an unknown DestinationId is rejected")
	do
		local p = Util.mkProfile(Catalog, {})
		t.ok("an unknown id is rejected", DestinationService.travelTo(p, "no_such_place").ok == false)
	end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | tail -5`
Expected: error — `travelTo` still raises the `TODO(step-9)` stub error.

- [ ] **Step 3: Replace the `travelTo` stub** — `src/server/DestinationService.luau`. Replace the stub function with:

```luau
export type TravelResult = { ok: boolean, reason: string?, teleportTarget: string? }

-- The GATED fast-travel flow (Step 9). Server-authoritative ENFORCEMENT: the target must be REGISTERED and
-- in the player's PERSISTED unlockedDestinations set (the gate-bypass guard — NOT a live evaluateGate, so a
-- gear sale never re-locks travel and a not-yet-committed unlock can't be bypassed). On success it resolves
-- the teleportTarget; the actual TeleportService place/spawn execution is Studio (WorldServer consumes this).
function M.travelTo(profile: PlayerData, destinationId: DestinationId): TravelResult
	local dst = Catalog.destinations[destinationId]
	if dst == nil then
		return { ok = false, reason = "unknown_destination" }
	end
	if profile.unlockedDestinations[destinationId] ~= true then
		return { ok = false, reason = "locked" } -- the integrity line: travel reads the persisted set
	end
	return { ok = true, teleportTarget = dst.teleportTarget }
end
```

- [ ] **Step 4: Register the spec** — `tests/run.luau`, in the Step-9 block:

```luau
	require("@tests/Travel.spec"),
```

- [ ] **Step 5: Run the suite**

Run: `./run-tests.sh 2>&1 | tail -20`
Expected: ALL GREEN ✓ (unlocked→ok+teleportTarget; locked→rejected; the set-not-eval guard both ways; unknown rejected).

- [ ] **Step 6: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 9 (4/7): gated fast-travel enforcement (travelTo validates the persisted unlocked set)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: World-Map + Passport surface data (+ projection wiring)

**Files:**
- Modify: `src/logic/Progression.luau` (add `worldMapPins` + `passportCounts`)
- Modify: `src/server/authority/Replication.luau` (add `worldMap` + `passport` to the projection)
- Test: extend `tests/Progression.spec.luau` (pins persisted-truth + unmetReasons; counts; projection carries them)

**Interfaces:**
- Consumes: `Gate.evaluateGate`; `profile.unlockedDestinations` / `conqueredDestinations`; `config.destinations`.
- Produces:
  - `Progression.Pin = { unlocked: boolean, conquered: boolean, unmetReasons: { string } }`
  - `Progression.worldMapPins(profile, config): { [DestinationId]: Pin }` — `unlocked` from the PERSISTED set; `conquered` from the set; `unmetReasons` from `evaluateGate` ONLY for locked pins (empty for unlocked).
  - `Progression.passportCounts(profile, config): { unlocked: number, conquered: number, total: number }`
  - `Replication.Projection.worldMap: { [string]: Progression.Pin }` and `Replication.Projection.passport: { unlocked, conquered, total }`.
- Note: the pin `unlocked` MUST be the persisted set, NOT `evaluateGate(...).unlocked` (Decision 3). `Gauntlet.spec` reads the projection loosely (`.eht`/`.balance`/`~= nil`) so the added fields are safe; confirm by the full gate.

- [ ] **Step 1: Write the failing test** — append to `tests/Progression.spec.luau` (add `local Replication = require("@src/server/authority/Replication")` at the top):

```luau
	t.section("Progression.worldMapPins — pin.unlocked is PERSISTED truth (stays unlocked after a gear sale)")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, conquered = { D.Bayou } })
		Progression.commitUnlocks(p, Catalog)
		p.equipped.weapon = nil -- sell/unequip: evaluateGate would now re-lock Appalachia
		local pins = Progression.worldMapPins(p, Catalog)
		t.ok("the Appalachia pin reads UNLOCKED from the set (not the live gate eval)", pins[D.Appalachia].unlocked == true)
		t.eq("an unlocked pin carries no unmet reasons", #pins[D.Appalachia].unmetReasons, 0)
	end

	t.section("Progression.worldMapPins — a locked pin carries the actionable-noun unmetReasons")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1 }) -- Appalachia locked, both halves unmet
		local pins = Progression.worldMapPins(p, Catalog)
		t.ok("the Bayou pin is unlocked (the requiredTier-0 root, committed via login/freshProfile-equivalent)", pins[D.Bayou] ~= nil)
		t.ok("the Appalachia pin is locked", pins[D.Appalachia].unlocked == false)
		t.ok("…and states a gear reason (Tier-2) and a conquest reason (Bayou)",
			Util.anyContains(pins[D.Appalachia].unmetReasons, "Tier-2") and Util.anyContains(pins[D.Appalachia].unmetReasons, "Bayou"))
	end

	t.section("Progression.passportCounts — counts derive from the persisted sets")
	do
		local p = Util.mkProfile(Catalog, {})
		p.unlockedDestinations[D.Bayou] = true
		p.unlockedDestinations[D.Appalachia] = true
		p.conqueredDestinations[D.Bayou] = true
		local c = Progression.passportCounts(p, Catalog)
		t.eq("2 unlocked", c.unlocked, 2)
		t.eq("1 conquered", c.conquered, 1)
		t.ok("total is the Destination count", c.total >= 2)
	end

	t.section("Progression — the projection exposes worldMap + passport (the client renders from this shadow)")
	do
		local p = Util.mkProfile(Catalog, {})
		p.unlockedDestinations[D.Bayou] = true
		local proj = Replication.buildProjection(p, Catalog)
		t.ok("the projection carries the worldMap pins", proj.worldMap ~= nil and proj.worldMap[D.Bayou].unlocked == true)
		t.ok("the projection carries the passport counts", proj.passport ~= nil and proj.passport.unlocked >= 1)
	end
```

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | tail -5`
Expected: failure — `Progression.worldMapPins`/`passportCounts` and `proj.worldMap`/`proj.passport` don't exist.

- [ ] **Step 3: Add the surface builders** — `src/logic/Progression.luau`, after `commitUnlocks`:

```luau
-- The World-Map pin per Destination: unlocked + conquered from the PERSISTED sets (NOT a live gate eval —
-- a sold-gear Destination must read unlocked); unmetReasons from evaluateGate ONLY for a still-locked pin
-- (the legibility-contract strings). One source of truth: the UI renders this, never re-deriving gate logic.
export type Pin = { unlocked: boolean, conquered: boolean, unmetReasons: { string } }
function M.worldMapPins(profile: PlayerData, config: Config): { [DestinationId]: Pin }
	local pins: { [DestinationId]: Pin } = {}
	for id, destination in config.destinations do
		local unlocked = profile.unlockedDestinations[id] == true
		pins[id] = {
			unlocked = unlocked,
			conquered = profile.conqueredDestinations[id] == true,
			unmetReasons = if unlocked then {} else Gate.evaluateGate(profile, destination, config).unmetReasons,
		}
	end
	return pins
end

-- The Passport readout: counts derived from the persisted sets (the Lodge "N of M unlocked / K conquered").
export type PassportCounts = { unlocked: number, conquered: number, total: number }
function M.passportCounts(profile: PlayerData, config: Config): PassportCounts
	local unlocked, conquered, total = 0, 0, 0
	for id in config.destinations do
		total += 1
		if profile.unlockedDestinations[id] == true then
			unlocked += 1
		end
		if profile.conqueredDestinations[id] == true then
			conquered += 1
		end
	end
	return { unlocked = unlocked, conquered = conquered, total = total }
end
```

- [ ] **Step 4: Wire the projection** — `src/server/authority/Replication.luau`. Add the require:

```luau
local Progression = require("@src/logic/Progression")
```

  Add to the `Projection` type (after `gates: { [string]: Gate.GateResult },`):

```luau
	-- Step 9: the World-Map pins (unlocked from the PERSISTED set, unmetReasons for locked pins) + the
	-- Passport counts — the server-authoritative progression surface the client renders (never re-derives).
	worldMap: { [string]: Progression.Pin },
	passport: Progression.PassportCounts,
```

  In `buildProjection`, add to the returned table (after `gates = gates,`):

```luau
		worldMap = Progression.worldMapPins(profile, config),
		passport = Progression.passportCounts(profile, config),
```

- [ ] **Step 5: Run the suite (confirm Gauntlet.spec stays green)**

Run: `./run-tests.sh 2>&1 | tail -20`
Expected: ALL GREEN ✓ — pins persisted-truth + unmetReasons; counts; the projection carries `worldMap`/`passport`; `Gauntlet.spec` (reads `.eht`/`.balance`) unaffected.

- [ ] **Step 6: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 9 (5/7): World-Map pin + Passport surface data (+ projection wiring)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Make the onboarding `WORLD_MAP` beat real

**Files:**
- Modify: `src/logic/Onboarding.luau` (`WORLD_MAP` beat: pass-through → real `worldMapOpen` completion)
- Create: `src/server/progression/WorldMapHandler.luau` (the `"openWorldMap"` gauntlet intent)
- Test: `tests/WorldMapHandler.spec.luau`
- Modify: `tests/Onboarding.spec.luau` (fix the two funnel-to-COMPLETE sequences + the pass-through assertion)
- Modify: `tests/Arrival.spec.luau` (insert `worldMapOpen` into the funnel-to-COMPLETE sequence)
- Modify: `tests/run.luau` (register `WorldMapHandler.spec`)

**Interfaces:**
- Consumes: `Onboarding.advance(profile, "worldMapOpen", now)`; `Progression.commitUnlocks` (Task 2); the gauntlet handler shape.
- Produces: `WorldMapHandler` (`Gauntlet.IntentHandler`, intent `"openWorldMap"`, `critical = true`) whose commit advances the `WORLD_MAP` beat and runs the `commitUnlocks` catch-all. `WorldMapHandler.new(deps: { telemetry: Types.Telemetry? }): Gauntlet.IntentHandler`.
- **Blast radius (must fix or the suite breaks):** flipping `WORLD_MAP` from pass-through to a real beat inserts a required `worldMapOpen` step into the funnel-to-COMPLETE chain. Every test that drives the funnel to COMPLETE via `advance` must insert a `worldMapOpen` after the `gearUpgrade` (FIRST_PURCHASE) step: `tests/Onboarding.spec.luau` (two sequences + the "passed through" assertion text) and `tests/Arrival.spec.luau` (one sequence). `tests/ClaimDailyHandler.spec.luau` pokes `funnelBeat = "DAILY_INTRO"` directly → NOT affected.

- [ ] **Step 1: Write the failing test** — create `tests/WorldMapHandler.spec.luau`:

```luau
--!strict
-- Step 9 — opening the World Map (the Travel Desk) is the server-authoritative event that completes the
-- WORLD_MAP funnel beat (Step 7's pass-through made real) AND runs the commitUnlocks catch-all.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Onboarding = require("@src/logic/Onboarding")
local WorldMapHandler = require("@src/server/progression/WorldMapHandler")
local Ids = require("@src/types/Ids")

local D = Ids.Destination

return function(t: Harness.T)
	local function openMap(p: any, saveOk: boolean): Gauntlet.HandleResult
		local reg = Gauntlet.new()
		Gauntlet.register(reg, WorldMapHandler.new({ telemetry = Fakes.newTelemetry() }))
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		return Gauntlet.handle(reg, { intent = "openWorldMap", playerId = 1, payload = {} }, session, {
			config = Catalog, now = 100, saveFn = function() return saveOk end, markDirty = function() end, telemetry = Fakes.newTelemetry(),
		})
	end

	t.section("WorldMap — opening the map at the WORLD_MAP beat completes it (the reveal beat made real)")
	do
		local p = Util.mkProfile(Catalog, {})
		p.onboarding.funnelBeat = "WORLD_MAP"
		t.ok("the open succeeds", openMap(p, true).ok)
		t.ok("the WORLD_MAP beat advanced past (no longer WORLD_MAP)", p.onboarding.funnelBeat ~= "WORLD_MAP")
	end

	t.section("WorldMap — opening the map runs the commitUnlocks catch-all")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, conquered = { D.Bayou } }) -- qualifies for Appalachia
		t.ok("Appalachia not yet committed", p.unlockedDestinations[D.Appalachia] == nil)
		assert(openMap(p, true).ok)
		t.ok("opening the map committed the pending unlock (the catch-all)", p.unlockedDestinations[D.Appalachia] == true)
	end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `luau tests/run.luau 2>&1 | tail -5`
Expected: error — `WorldMapHandler` does not exist.

- [ ] **Step 3: Make the `WORLD_MAP` beat real** — `src/logic/Onboarding.luau`, in the `BEATS` table, replace the `WORLD_MAP` line:

```luau
	[B.WORLD_MAP] = { completesOn = { worldMapOpen = true }, requiredCount = 1, next = B.LOOP_CONFIRM, passThrough = false }, -- Step 9: real reveal beat (was pass-through)
```

- [ ] **Step 4: Create the handler** — `src/server/progression/WorldMapHandler.luau`:

```luau
--!strict
-- THE WORLD-MAP / TRAVEL-DESK OPEN (Step 9) as a server-authoritative gauntlet intent. Opening the map (a)
-- completes the WORLD_MAP funnel beat (Step 7's pass-through made real — the aspiration reveal) and (b) runs
-- the commitUnlocks CATCH-ALL (re-evaluate every gate; cheap + idempotent; makes the unlock set eventually
-- consistent even if a conquest/equip-time commit ever didn't persist). `critical` → the beat advance + any
-- unlock commit write through atomically. The map UI itself is Studio (WorldServer fires this intent).

local Onboarding = require("@src/logic/Onboarding")
local Progression = require("@src/logic/Progression")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx

local M = {}

export type WorldMapDeps = { telemetry: Types.Telemetry? }

function M.new(deps: WorldMapDeps): Gauntlet.IntentHandler
	return {
		intent = "openWorldMap",
		critical = true, -- the funnel-beat advance + any unlock commit are write-through triggers
		authority = function(_ctx: Ctx): (boolean, string?)
			return true, nil -- opening the map is always permitted; it asserts nothing about state
		end,
		commit = function(ctx: Ctx)
			Onboarding.advance(ctx.profile, "worldMapOpen", ctx.now) -- completes the WORLD_MAP beat (no-op past it)
			local r = Progression.commitUnlocks(ctx.profile, ctx.config) -- the catch-all re-evaluation
			if deps.telemetry ~= nil then
				for _, id in r.newlyUnlocked do
					deps.telemetry.incr("progression.unlock:" .. id, 1)
				end
			end
		end,
	}
end

return M
```

- [ ] **Step 5: Fix the affected funnel-to-COMPLETE sequences.**

  `tests/Onboarding.spec.luau` — in the first section (the full happy-path drive), the `gearUpgrade` step now lands on `WORLD_MAP`, not `LOOP_CONFIRM`. Replace:

```luau
		Onboarding.advance(p, "gearUpgrade", 30)
		t.eq("a gearUpgrade → LOOP_CONFIRM (WORLD_MAP passed through — Step 9 makes it real)", p.onboarding.funnelBeat, "LOOP_CONFIRM")
```

  with:

```luau
		Onboarding.advance(p, "gearUpgrade", 30)
		t.eq("a gearUpgrade → WORLD_MAP (now a real reveal beat, Step 9)", p.onboarding.funnelBeat, "WORLD_MAP")
		Onboarding.advance(p, "worldMapOpen", 35)
		t.eq("opening the World Map → LOOP_CONFIRM", p.onboarding.funnelBeat, "LOOP_CONFIRM")
```

  Two more sections drive the funnel to COMPLETE via a loop over an event list (the "idempotent one-shot" section and the "isOnboardingComplete gates real-money" section). BOTH use the list `{ "kill", "catch", "gearUpgrade", "kill", "catch", "kill", "dailyClaim" }`. In BOTH, insert `"worldMapOpen"` immediately after `"gearUpgrade"` — replace each occurrence of:

```luau
		for _, e in { "kill", "catch", "gearUpgrade", "kill", "catch", "kill", "dailyClaim" } do
```

  with:

```luau
		for _, e in { "kill", "catch", "gearUpgrade", "worldMapOpen", "kill", "catch", "kill", "dailyClaim" } do
```

  (`replace_all` is safe here — both occurrences are identical and both need the same fix.) After the fix, both sections must still reach `funnelBeat == "COMPLETE"` / `isOnboardingComplete == true`.

  `tests/Arrival.spec.luau` — insert a `worldMapOpen` advance after the `gearUpgrade` line (line 26) and renumber the subsequent times:

```luau
	Onboarding.advance(p2, "kill", 1)
	Onboarding.advance(p2, "catch", 2)
	Onboarding.advance(p2, "gearUpgrade", 3)
	Onboarding.advance(p2, "worldMapOpen", 4) -- Step 9: WORLD_MAP is now a real beat
	Onboarding.advance(p2, "kill", 5)
	Onboarding.advance(p2, "kill", 6)
	Onboarding.advance(p2, "catch", 7)
	Onboarding.advance(p2, "dailyClaim", 8)
	t.ok("the funnel reached COMPLETE", Onboarding.isOnboardingComplete(p2))
```

- [ ] **Step 6: Register the spec** — `tests/run.luau`, in the Step-9 block:

```luau
	require("@tests/WorldMapHandler.spec"),
```

- [ ] **Step 7: Run the suite**

Run: `./run-tests.sh 2>&1 | tail -25`
Expected: ALL GREEN ✓ — the WORLD_MAP beat completes on `worldMapOpen`; the catch-all commits unlocks; the Onboarding.spec + Arrival.spec COMPLETE sequences pass with the inserted `worldMapOpen`. If any funnel test still stalls short of COMPLETE, it is missing the `worldMapOpen` insertion — add it after that test's `gearUpgrade`.

- [ ] **Step 8: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 9 (6/7): WORLD_MAP beat made real (openWorldMap handler + funnel sequence fixes)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: WorldServer wiring (Studio) + README + the final gate

**Files:**
- Modify: `src/server/world/WorldServer.server.luau` (register `WorldMapHandler`; `commitUnlocks` at login; wire the Travel Desk fixture → `openWorldMap` + `travelTo`)
- Modify: `README.md` (the Step-9 section + module map + deferred table + DoD status + assertion count)

> The `WorldServer.server.luau` change is Studio-only (`--!nonstrict`, NOT headless-analyzed). Its bar is `rojo build` succeeds + the headless suite stays green. The README is documentation.

**Interfaces:**
- Consumes: `WorldMapHandler.new`, `Progression.commitUnlocks`, `DestinationService.travelTo` (all built above).

- [ ] **Step 1: Register `WorldMapHandler` on the shared registry** — `src/server/world/WorldServer.server.luau`. Add the require with the other handler requires:

```luau
local WorldMapHandler = require("@src/server/progression/WorldMapHandler")
local Progression = require("@src/logic/Progression")
local DestinationService = require("@src/server/DestinationService")
```

  Add the registration alongside the others (after the LodgeShopHandler registrations):

```luau
Gauntlet.register(registry, WorldMapHandler.new({ telemetry = telemetry }))
```

- [ ] **Step 2: Commit pending unlocks at login** — in the `Players.PlayerAdded` handler, after `SessionService.login(...)` succeeds and the session profile is available, add a catch-all re-evaluation (cheap, idempotent — makes the unlocked set eventually consistent), then mark dirty so it persists:

```luau
		-- Step 9: re-evaluate gate unlocks at login (the catch-all — cheap, idempotent, eventually consistent).
		local session = sessionService.sessions[plr.UserId]
		if session ~= nil then
			Progression.commitUnlocks(session.profile, Catalog)
			SessionService.markDirty(sessionService, plr.UserId)
		end
```

  (Place it where the session profile is loaded; match the file's existing `sessionService.sessions[...]` access pattern.)

- [ ] **Step 3: Wire the Travel Desk fixture** — the Lodge's `TravelDesk_WorldMap` fixture (currently a `"stub"`) opens the World Map. Add a RemoteEvent + handler so the client's "open map" / "fast-travel" requests route server-side:

```luau
-- Step 9: the Travel Desk → World Map + fast-travel. Opening the map fires the openWorldMap intent (completes
-- the funnel reveal beat + the unlock catch-all); a travel request is enforced by DestinationService.travelTo
-- (the gate-bypass guard — target must be in the persisted unlocked set) and, on ok, executes the teleport.
local travelRequest = Instance.new("RemoteEvent")
travelRequest.Name = "TravelRequest"
travelRequest.Parent = ReplicatedStorage

travelRequest.OnServerEvent:Connect(function(plr, action, destinationId)
	local session = sessionService.sessions[plr.UserId]
	if session == nil then
		return
	end
	if action == "openMap" then
		Gauntlet.handle(registry, { intent = "openWorldMap", playerId = plr.UserId, payload = {} }, session, gauntletDeps(plr))
		travelRequest:FireClient(plr, "map", Progression.worldMapPins(session.profile, Catalog), Progression.passportCounts(session.profile, Catalog))
		return
	end
	if action == "travel" then
		local result = DestinationService.travelTo(session.profile, destinationId)
		if result.ok then
			-- TODO(step-10): TeleportService place/spawn to result.teleportTarget for the real Destinations;
			-- the only unlocked travel target at MVL is the Bayou (Lodge → Bayou). Return-to-Lodge is the
			-- existing leave flow (ArrivalService), not fast-travel.
			travelRequest:FireClient(plr, "traveling", destinationId, result.teleportTarget)
		else
			travelRequest:FireClient(plr, "denied", destinationId, result.reason)
		end
	end
end)
```

  Update the `TravelDesk_WorldMap` fixture's `status` attribute from `"stub"` to `"built"`.

- [ ] **Step 4: Confirm the project syncs + the headless suite is unaffected**

Run: `./run-tests.sh 2>&1 | tail -8`
Expected: ALL GREEN ✓ — gate 4 `rojo build` succeeds with the WorldServer changes; gates 1–3 unchanged.

Run: `find src client \( -name '*.server.luau' -o -name '*.client.luau' \) | sort`
Expected: exactly `client/CharacterController.client.luau` and `src/server/world/WorldServer.server.luau`.

- [ ] **Step 5: Update the README intro bullet** — `README.md`, after the Step-8 bullet:

```markdown
- **Step 9 — World Map, Fast-Travel & Destination Gating.** A thin progression-integrity-adjacent core +
  a Studio map UI. The **unlocked set is persisted truth, not a live derivation** (`commitUnlocks` only ever
  *adds* the one-time threshold crossing — selling gear never re-locks), and **fast-travel cannot bypass a
  gate** (`travelTo` validates the target against the persisted set). Step 9 *calls* `Gate.evaluateGate` /
  `EffectiveTier` / the teleport scaffold / the persisted Passport sets — it rebuilds none of them. It wires
  the unlock-commit into conquest (Fire/Catch, gated on `conquestNewlySet`) + equip + the login/Travel-Desk
  catch-all; builds the World-Map pin + Passport surface; and flips the onboarding `WORLD_MAP` beat from
  pass-through to a real reveal. **The map UI, the `TeleportService` execution, and the Passport-readout feel
  are Studio** — split honestly below.
```

- [ ] **Step 6: Update the module map** — `README.md`, in `## Module map`, add under `logic/`:

```
           · Progression (Step 9 — commitUnlocks: the persisted-truth unlock set; worldMapPins/passportCounts: the Passport surface; CALLS evaluateGate, never re-derives)
```

  add a `progression/` group under `server/` (after the `lodge/` block):

```
    progression/
      WorldMapHandler.luau    (Step 9) the "openWorldMap" intent — completes the WORLD_MAP reveal beat + the commitUnlocks catch-all (critical)
```

  and update the `DestinationService.luau` line to note travel is now enforced:

```
    DestinationService.luau  teleport registry + canTravel preview + travelTo (Step 9: gated fast-travel ENFORCEMENT — validates the persisted unlocked set, resolves teleportTarget)
```

- [ ] **Step 7: Add the Step-9 section** — `README.md`, after the `## Step 8 …` section (before `## Deferred — who owns what`):

```markdown
## Step 9 — World Map, fast-travel & gating (the bar is split, honestly)

Two properties a wrong build violates: **the unlocked set is persisted truth (not a live derivation)** —
`commitUnlocks` only ever *adds* (the one-time threshold crossing); a Destination stays unlocked after the
qualifying gear is sold (`evaluateGate` gates *entry into the set*, never continued membership) — and
**fast-travel cannot bypass the gate** — `DestinationService.travelTo` validates the target against the
**persisted** `unlockedDestinations` set, not a live gate eval. Step 9 **calls** `Gate.evaluateGate`,
`EffectiveTier`, the teleport scaffold, and the persisted sets — it rebuilds none of them.

**Headless-proven:**
- **`commitUnlocks`** (`src/logic/Progression.luau`) re-evaluates every gate in **one pass** and adds each
  newly-unlocked Destination to the persisted set: idempotent (a second pass adds nothing); **survives a gear
  sale** (unlock, then unequip → still unlocked); requires **both halves** (conquest alone or gear alone does
  not unlock); one pass unlocks the whole conquered chain (no cascade — the gate checks `prerequisite
  Destinations ⊆ conquered`, a stable player action).
- **Wired into its real triggers, atomically**: `FireHandler`/`CatchHandler` commits gated on
  `result.conquestNewlySet` (a forced save failure reverts the conquest **and** the unlock — no orphan); the
  **equip** handler (the action that actually changes EHT/EFT — see the placement note); and the
  login/Travel-Desk `openWorldMap` catch-all.
- **Gated fast-travel enforcement**: `travelTo` returns `{ ok, reason?, teleportTarget? }` — an unlocked
  target resolves its `teleportTarget`; a locked target is rejected server-side; the guard reads the
  **set** (a gate-qualified-but-uncommitted player still can't travel; an in-set-but-now-under-geared player
  still can — persisted truth).
- **Surface data**: `worldMapPins` returns `{ unlocked, conquered, unmetReasons }` per Destination — `unlocked`
  from the **persisted set** (a sold-gear Destination reads unlocked), `unmetReasons` the actionable-noun
  strings for locked pins; `passportCounts` derives the readout from the sets. Both are exposed in the
  read-only projection (`worldMap` / `passport`).
- **The Rockies re-thread** is data-driven: `Gate.spec` proves it at the `evaluateGate` level; `Progression.spec`
  proves the **`commitUnlocks`** re-evaluates a synthetic re-pointed DAG with **no code change**.
- **The onboarding `WORLD_MAP` beat is now real** — opening the map (`openWorldMap`) completes it (was a
  pass-through); the funnel-to-COMPLETE chain gained a `worldMapOpen` step (the affected specs updated).
- `requiredAccessItems` added to the `Gate` (optional; the entry-gate half of `evaluateGate`) for the future
  water-locked Destination; the MVL omits it.
- Steps 1–8 tests stay green (the conquest/equip commits now carry the unlock-commit through their existing
  atomic/dirty-flag paths).

**Studio / telemetry — NOT headless (all unchecked):**
- [ ] The **World Map** renders at the Travel Desk: lit pins for unlocked, glowing-locked pins showing their
      `unmetReasons`, higher-tier pins visible from session one — no tier number shown.
- [ ] **Fast-travel** executes (`TeleportService` place/spawn) for the real targets (Lodge ⇄ Bayou) on mobile.
- [ ] The **Passport readout** in the Lodge reads as the felt progression number ("N of M unlocked").
- [ ] The onboarding `WORLD_MAP` reveal lands as the aspiration beat in the funnel.
- [ ] Telemetry populates: per-tier time-to-unlock, **gate drop-off split gear-vs-milestone** (the single
      most useful progression chart), EHT/EFT distribution, dual-loop split, fast-travel usage.

**Placement note (codebase-grounded, flagged):** the prompt says hook the gear-change unlock into
`ShopHandler`, but in this codebase **buy mints an *unequipped* commodity and upgrade is intra-tier** —
neither changes EHT — so the gear-half-newly-met trigger is in **`EquipHandler`** (the action that changes
EHT/EFT), plus the login/Travel-Desk catch-all. A `ShopHandler` hook would be dead code.

**`Gate` prerequisite-model note:** the code checks `prerequisiteDestinations ⊆ conquered` (collapsing the
spec's `milestone_prerequisite` (conquered) and `prerequisite_destinations` (unlocked) into one) — fine for
the MVL + Rockies (a conquered milestone chain); the **unlocked-but-not-conquered** prerequisite is
unimplemented, flagged for a future Destination that needs it.

**Deferrals (named with their owning step):** the Appalachia/Alaska worlds behind the gates → **Step 10**;
Boats + the sub-area Boat-gate enforcement (Alaska coastal fishing) → **Step 11** (Boats) / **Step 10**
(sub-areas) — `requiredAccessItems` here is the *entry-gate* half only; **Hunter/Angler Rank perks** (the
registry + thresholds + cap/prestige) → **deferred** (rank XP already accrues; if ever surfaced, the registry
must be category-validated identity|convenience — power is a schema error); the `TeleportService` execution
beyond Lodge/Bayou → **Step 10**; the MVL T2→T4 combat-difficulty check → **Step 10**.
```

- [ ] **Step 8: Update the Deferred table + DoD status** — `README.md`. In `## Deferred — who owns what`, update the World-Map row:

```markdown
| ~~World Map UI, **gated teleport execution + enforcement**~~ — **enforcement + travel flow + surface data + unlock-commit DONE (Step 9)**; remaining: the map UI + the `TeleportService` execution beyond Lodge/Bayou | Step 10 |
```

  In `## Definition of Done — status`, after the **Step 8** entry:

```markdown
**Step 9:** ✅ (headless) `commitUnlocks` (persisted-truth unlock set — adds-only, idempotent, survives gear
sale, both-halves, one pass) wired into conquest (Fire/Catch on `conquestNewlySet`, atomic no-orphan) + equip
+ the `openWorldMap` catch-all; gated `travelTo` enforcement (validates the persisted set — the gate-bypass
guard, both directions); `worldMapPins`/`passportCounts` surface (persisted-truth pin `unlocked`,
actionable-noun `unmetReasons`) exposed in the projection; the optional `requiredAccessItems` entry-gate half;
the `WORLD_MAP` beat made real (`openWorldMap` completes it; funnel specs updated); the `commitUnlocks`-level
Rockies re-thread (data-only DAG re-point, no code change). ⌂ (Studio, unchecked above) the World-Map UI, the
`TeleportService` execution, the Passport readout, the onboarding reveal feel, and the progression telemetry.
Step 9 **calls** `evaluateGate`/`EffectiveTier`/the teleport scaffold — it rebuilds none of them.
```

- [ ] **Step 9: Update the headline assertion count** — get the real number:

Run: `luau tests/run.luau 2>&1 | grep passed`
Then update the README's final summary sentence (`**NNN assertions pass headless; …**`) with the actual number, and update `tests/run.luau`'s harness label `"Wild World — Steps 1–8"` → `"Steps 1–9"`. Update the title `# Wild World — Build (Steps 1–8)` → `(Steps 1–9)`.

- [ ] **Step 10: The final DoD gate**

Run: `./run-tests.sh 2>&1 | tail -30`
Expected: **ALL GREEN ✓** — all four gates pass (strict type-check every headless module incl. the new ones; all unit tests incl. the 3 new specs; both negative fixtures still fail analysis; `rojo build` succeeds).

- [ ] **Step 11: Commit**

```bash
cd /home/toor/claude/RobloxRPG/RobloxRPG
git add -A && git commit -m "Step 9 (7/7): WorldServer wiring (travel desk + login catch-all) + README + final gate

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (run after implementation; author's checklist)

**Spec coverage (every Scope item → a task):**
- A. The unlock-commit transition (persisted truth, idempotent, one pass) → **Task 2** ✓
- B. Wire into triggers (conquest + equip + login/Travel-Desk catch-all; atomic) → **Task 3** (+ login in **Task 7**, openWorldMap in **Task 6**) ✓
- C. Gated fast-travel enforcement (validate the persisted set; resolve teleportTarget) → **Task 4** ✓
- D. World-Map + Passport surface data (pins + counts; legibility-contract strings) → **Task 5** ✓
- E. The `WORLD_MAP` beat + the Travel Desk fixture → **Task 6** (beat) + **Task 7** (fixture) ✓
- F. The Rockies re-thread (data-driven DAG) → existing `Gate.spec` (evaluateGate level) + **Task 2** (commitUnlocks level) ✓
- G. Telemetry → `progression.unlock:*` emitted in **Task 6**; the rest enumerated Studio in **Task 7** ✓
- Prereq 1: `requiredAccessItems` → **Task 1** (added, optional, flagged) ✓
- Out-of-scope honored: no Appalachia/Alaska worlds, no Boats/sub-area gate, no rank perks, no teleport execution beyond Lodge/Bayou, no `ShopHandler` hook (dead code) — flagged in README ✓

**Type-consistency checks:** `commitUnlocks(profile, config): { newlyUnlocked }` used identically in Tasks 3/6/7; `Progression.Pin`/`PassportCounts` defined in Task 5 and consumed by the projection (Task 5); `travelTo(profile, id): { ok, reason?, teleportTarget? }` defined Task 4, consumed Task 7; `"worldMapOpen"` is the event kind in the beat config (Task 6 Step 3), the handler (Task 6 Step 4), and the funnel-sequence fixes (Task 6 Step 5) + Arrival.spec; `requiredAccessItems` optional everywhere.

**Persisted-truth property is locked at three layers:** `commitUnlocks` (Task 2 — stays unlocked after gear sale), `worldMapPins` (Task 5 — pin reads the set, not the live eval), `travelTo` (Task 4 — travels on the set, not the live eval).

**Between-task green:** every task ends on a green `./run-tests.sh`. Task 6 carries the WORLD_MAP-beat blast radius (the funnel-sequence fixes) so the suite stays green when the beat flips.
