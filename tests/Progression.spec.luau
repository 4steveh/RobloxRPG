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
local Fakes = require("@src/server/persistence/Fakes")
local Gauntlet = require("@src/server/authority/Gauntlet")
local FireHandler = require("@src/server/combat/FireHandler")
local EquipHandler = require("@src/server/authority/handlers/EquipHandler")
local Combat = require("@src/logic/Combat")

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

	-- ─── Handler wiring tests (Task 3) ───────────────────────────────────────────
	-- Build a server-enriched lethal shot payload for the milestone alligator using T2 entry weapon.
	-- T2 entry weapon vital shot at distance 5: weaponDamage=20, zoneMultiplier=2.5, falloff=1.0 → 50 dmg.
	-- Gator health = 48, so accumulatedDamageBefore=0 is already lethal (0+50 ≥ 48).
	-- (Mirrors the payload-derivation pattern from tests/FireHandler.spec.luau.)
	local function gatorShot(): any
		local wl = Combat.gearLevelOf(0) -- intraLevel 0 → "entry"
		local dmg = Combat.shotDamage(
			Combat.weaponDamage(Catalog, 2, wl),
			Combat.zoneMultiplier(Catalog, "vital"),
			Combat.rangeFalloff(Catalog, 2, 5)
		)
		return {
			targetId = "bayou_american_alligator",
			zone = "vital",
			distance = 5,
			claimedDamage = dmg,
			lastShotAt = 0,
			rayHitTargetId = "bayou_american_alligator",
			targetAlive = true,
			accumulatedDamageBefore = 0,
			owner = "u1",
			partySize = 1,
		}
	end

	t.section("Progression wiring — conquering the Bayou while T2-geared unlocks Appalachia (atomic with the kill)")
	do
		-- a T2-equipped hunter whose shot is lethal on the milestone gator.
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, rod = 1, reel = 1 })
		local function fire(saveOk: boolean): Gauntlet.HandleResult
			local reg = Gauntlet.new()
			Gauntlet.register(reg, FireHandler.new({ idGen = Fakes.newIdGenerator(), payoutFn = function() return 1 end, telemetry = Fakes.newTelemetry() }))
			local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
			return Gauntlet.handle(reg, { intent = "fire", playerId = 1, payload = gatorShot() }, session, {
				config = Catalog, now = 100, saveFn = function() return saveOk end, markDirty = function() end, telemetry = Fakes.newTelemetry(),
			})
		end
		t.ok("the milestone kill succeeds", fire(true).ok)
		t.ok("the Bayou is conquered", p.conqueredDestinations["bayou"] == true)
		t.ok("Appalachia is unlocked atomically with the conquest", p.unlockedDestinations[D.Appalachia] == true)
	end

	t.section("Progression wiring — a forced save failure reverts the conquest AND the unlock (no orphan)")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, rod = 1, reel = 1 })
		local reg = Gauntlet.new()
		Gauntlet.register(reg, FireHandler.new({ idGen = Fakes.newIdGenerator(), payoutFn = function() return 1 end, telemetry = Fakes.newTelemetry() }))
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		local r = Gauntlet.handle(reg, { intent = "fire", playerId = 1, payload = gatorShot() }, session, {
			config = Catalog, now = 100, saveFn = function() return false end, markDirty = function() end, telemetry = Fakes.newTelemetry(),
		})
		t.ok("persist_failed", r.ok == false and r.reason == "persist_failed")
		t.ok("conquest reverted", p.conqueredDestinations["bayou"] == nil)
		t.ok("the unlock reverted with it (no orphan unlock)", p.unlockedDestinations[D.Appalachia] == nil)
	end

	t.section("Progression wiring — equipping T2 gear after conquering the Bayou unlocks Appalachia (the gear-change path)")
	do
		-- conquered the Bayou, has T1 weapon equipped, owns T2 weapon+armor but has NOT equipped them yet.
		-- EHT=1: weaponTier=1 < armorGatingStartTier=2, so the armor floor rule gives armorTierOrFloor=1.
		-- (T1 armor does not exist in the catalog; the floor rule is what makes armorless T1 work.)
		local p = Util.mkProfile(Catalog, { weapon = 1, conquered = { D.Bayou } })
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
end
