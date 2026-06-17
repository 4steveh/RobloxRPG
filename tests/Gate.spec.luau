--!strict
local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Gate = require("@src/logic/Gate")
local Ids = require("@src/types/Ids")
local Enums = require("@src/types/Enums")
local Schema = require("@src/types/Schema")

local D = Ids.Destination
local appalachia = Catalog.destinations[D.Appalachia]
local alaska = Catalog.destinations[D.Alaska]
local deepSea = Catalog.destinations[D.DeepSea]

return function(t: Harness.T)
	t.section("Gate — MVL chain Bayou → Appalachia → Alaska")

	-- under-geared, nothing conquered → Appalachia locked (both halves unmet)
	local underGeared = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1 })
	local rA = Gate.evaluateGate(underGeared, appalachia, Catalog)
	t.ok("Appalachia locked for a fresh under-geared player", rA.unlocked == false)
	t.ok("…has ≥ 2 unmet reasons (gear + conquest)", #rA.unmetReasons >= 2)

	-- T2 hunter who conquered the Bayou → Appalachia unlocked
	local huntT2 = Util.mkProfile(Catalog, { weapon = 2, armor = 2, conquered = { D.Bayou } })
	t.ok("Appalachia unlocked: T2 hunter + conquered Bayou", Gate.evaluateGate(huntT2, appalachia, Catalog).unlocked)

	-- pure fisher (no weapon/armor) qualifies via the OR-gate (EFT path)
	local fishT2 = Util.mkProfile(Catalog, { rod = 2, reel = 2, conquered = { D.Bayou } })
	t.ok("Appalachia unlocked: pure fisher via EFT (dual-loop completability)", Gate.evaluateGate(fishT2, appalachia, Catalog).unlocked)

	-- conquered Bayou but still T1 gear → gear half fails
	local t1Conq = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1, conquered = { D.Bayou } })
	local rGear = Gate.evaluateGate(t1Conq, appalachia, Catalog)
	t.ok("Appalachia locked when only the gear half is unmet", rGear.unlocked == false)
	t.ok("…the lone reason is the gear reason", #rGear.unmetReasons == 1 and Util.anyContains(rGear.unmetReasons, "Tier-2"))

	-- qualified for Alaska: a pure T4 hunter who conquered Appalachia (two-tier MVL jump)
	local huntT4 = Util.mkProfile(Catalog, { weapon = 4, armor = 4, conquered = { D.Appalachia } })
	t.ok("Alaska unlocked: T4 hunter + conquered Appalachia", Gate.evaluateGate(huntT4, alaska, Catalog).unlocked)

	-- mismatched-slot under-geared for Alaska: weapon T4 but armor T2 → EHT 2; rod T4 but reel T2 → EFT 2
	local mismatched = Util.mkProfile(Catalog, { weapon = 4, armor = 2, rod = 4, reel = 2, conquered = { D.Appalachia } })
	local rM = Gate.evaluateGate(mismatched, alaska, Catalog)
	t.ok("Alaska locked for the mismatched-slot player (EHT=EFT=2 < 4)", rM.unlocked == false)
	t.ok("…the unmet reason is the gear half (Tier-4)", Util.anyContains(rM.unmetReasons, "Tier-4"))

	t.section("Gate — Rockies (T3) DAG insertion, ZERO logic change")

	-- Re-thread Alaska's prerequisiteDestinations from {Appalachia} to {Rockies}; same evaluateGate fn.
	local alaskaRethreaded: Schema.Destination = {
		id = alaska.id,
		name = alaska.name,
		tier = alaska.tier,
		offeredLoops = alaska.offeredLoops,
		gate = {
			requiredTier = alaska.gate.requiredTier,
			milestoneTargets = {}, -- post-insert these become Rockies' targets; immaterial to the DAG outcome
			prerequisiteDestinations = { D.Rockies },
		},
		teleportTarget = alaska.teleportTarget,
	}
	local geared = Util.mkProfile(Catalog, { weapon = 4, armor = 4, conquered = { D.Appalachia } })
	t.ok("before insert: Alaska unlocked (prereq Appalachia conquered)", Gate.evaluateGate(geared, alaska, Catalog).unlocked)
	t.ok("after re-thread: SAME profile now LOCKED (prereq Rockies not conquered)", Gate.evaluateGate(geared, alaskaRethreaded, Catalog).unlocked == false)
	local gearedRockies = Util.mkProfile(Catalog, { weapon = 4, armor = 4, conquered = { D.Appalachia, D.Rockies } })
	t.ok("after re-thread + conquer Rockies: Alaska unlocked again", Gate.evaluateGate(gearedRockies, alaskaRethreaded, Catalog).unlocked)

	t.section("Gate — dual-loop OR-gate vs a fishing-only Destination (offeredLoops, not blind max)")

	-- A fishing-only Destination at requiredTier 4 makes the test SHARP: a maxed hunter has EHT 4 ≥ 4,
	-- so a blind max(EHT,EFT) WOULD admit them — but the correct logic reads offeredLoops = {Fishing}.
	local fishingOnly4: Schema.Destination = {
		id = "deep_sea_req4_fixture",
		name = "Deep Sea (req-4 fixture)",
		tier = 7,
		offeredLoops = { Enums.Loop.Fishing },
		gate = { requiredTier = 4, milestoneTargets = {}, prerequisiteDestinations = {} },
		teleportTarget = "fixture",
	}
	local maxedHunter = Util.mkProfile(Catalog, { weapon = 4, armor = 4 }) -- EHT 4, EFT 0
	local maxedFisher = Util.mkProfile(Catalog, { rod = 4, reel = 4 }) -- EFT 4, EHT 0
	t.ok("maxed HUNTER does NOT qualify for a fishing-only Destination (EFT 0 < 4)", Gate.evaluateGate(maxedHunter, fishingOnly4, Catalog).unlocked == false)
	t.ok("maxed FISHER qualifies (EFT 4 ≥ 4)", Gate.evaluateGate(maxedFisher, fishingOnly4, Catalog).unlocked)

	-- Against the real Deep Sea T7 fixture: the gear reason names only fishing slots (rod/reel), never weapon/armor.
	local rDeep = Gate.evaluateGate(maxedHunter, deepSea, Catalog)
	t.ok("real Deep Sea (req 7) locked for the maxed hunter", rDeep.unlocked == false)
	t.ok("…reason names fishing slots (rod/reel), scoped to offeredLoops",
		Util.anyContains(rDeep.unmetReasons, "rod") or Util.anyContains(rDeep.unmetReasons, "reel"))
	t.ok("…reason does NOT name hunting slots (weapon/armor)",
		not Util.anyContains(rDeep.unmetReasons, "weapon") and not Util.anyContains(rDeep.unmetReasons, "armor"))

	t.section("Gate — single-loop conquest path (fishing-only prereq + milestone)")
	-- A fishing-only Destination gated behind conquering a fishing target: exercises the milestone half
	-- and loop-aware naming through the single-loop path (not just the dual-loop MVL chain).
	local singleLoopChained: Schema.Destination = {
		id = "deep_sea_chained_fixture",
		name = "Deep Sea (chained fixture)",
		tier = 7,
		offeredLoops = { Enums.Loop.Fishing },
		gate = { requiredTier = 4, milestoneTargets = { "alaska_king_salmon" }, prerequisiteDestinations = { D.Alaska } },
		teleportTarget = "fixture",
	}
	local fisherUnconq = Util.mkProfile(Catalog, { rod = 4, reel = 4 }) -- EFT 4 meets the tier; Alaska not conquered
	local rSL = Gate.evaluateGate(fisherUnconq, singleLoopChained, Catalog)
	t.ok("locked when the fishing-only prerequisite is not conquered", rSL.unlocked == false)
	t.ok("…tier half is satisfied (only the milestone is unmet)", #rSL.unmetReasons == 1)
	t.ok("…milestone reason names the King Salmon via the single (fishing) loop", Util.anyContains(rSL.unmetReasons, "King"))
	t.ok("…and names no hunting verb/target (single-loop scoping)", not Util.anyContains(rSL.unmetReasons, "down the"))
	local fisherConq = Util.mkProfile(Catalog, { rod = 4, reel = 4, conquered = { D.Alaska } })
	t.ok("unlocked once the fishing-only prerequisite is conquered", Gate.evaluateGate(fisherConq, singleLoopChained, Catalog).unlocked)

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

	t.section("Gate — Bayou is the free, always-unlocked root")
	local fresh = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1 })
	t.ok("Bayou unlocked with no gear and nothing conquered", Gate.evaluateGate(fresh, Catalog.destinations[D.Bayou], Catalog).unlocked)

	t.section("Gate — legibility contract: actionable nouns")
	-- Appalachia, fully unmet → reasons name a gear item AND the conquest (place + target nouns)
	local reasons = Gate.evaluateGate(underGeared, appalachia, Catalog).unmetReasons
	t.ok("gear reason names a slot + the tier", Util.anyContains(reasons, "Tier-2") and (Util.anyContains(reasons, "weapon") or Util.anyContains(reasons, "rod")))
	t.ok("conquest reason names the Bayou", Util.anyContains(reasons, "Bayou"))
	t.ok("conquest reason names a milestone target (Alligator or Blue Catfish)",
		Util.anyContains(reasons, "Alligator") or Util.anyContains(reasons, "Blue Catfish"))

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
end
