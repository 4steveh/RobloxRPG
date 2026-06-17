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
