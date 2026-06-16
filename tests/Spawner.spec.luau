--!strict
-- Step 4 (hunting) — the loop-agnostic target spawner: the spawn-density CAP (the anti-low-tier-farming
-- economy invariant), the engagement-rate model, ambiance exclusion from the reward-bearing ceiling, the
-- condition-gated rare predicate (never a per-kill roll), and the build-time placement guarantee (P1).
-- The PHYSICAL placement (Workspace), respawn timers, and the LOS raycast are Studio (README checklist).

local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Spawner = require("@src/logic/Spawner")
local Spawning = require("@src/config/Spawning")
local Shells = require("@src/config/Shells")
local Enums = require("@src/types/Enums")

local function approx(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

return function(t: Harness.T)
	local bayouHunting = (Spawning.byDestination.bayou :: any).hunting

	t.section("Spawner — engagement rate: ExpectedTargetsPerHour = min(3600/TimePerTarget, ceiling)")
	do
		-- Bayou T1: TimePerTarget = 25 + 10 + 10 = 45 s → 80/hr (below the 85 ceiling → not throttled)
		t.ok("Bayou T1 modeled rate = 80/hr (matches combat §5 table)", approx(Spawner.expectedTargetsPerHour(Catalog, 1, 85), 80))
	end

	t.section("Spawner — the spawn-density cap is the anti-low-tier-farming invariant (economy §5)")
	do
		-- An over-geared T4 player one-shotting Bayou game (killSeconds ≈ 0) is bounded by the CEILING,
		-- not by kill speed: their realized routine rate collapses to ~Income(1)/hr, strictly worse than
		-- hunting their own tier — so low-tier farming is irrational.
		local realized = Spawner.realizedRoutineRatePerHour(Catalog, 1, 85, 0.001)
		t.ok("an over-geared player's realized rate is CAPPED at the ceiling (85), not their kill speed", approx(realized, 85))
		local income1 = Catalog.tuning.economy.B
		local income4 = Catalog.tuning.economy.B * Catalog.tuning.economy.g ^ 3
		local baselinePerTarget = income1 / Spawner.expectedTargetsPerHour(Catalog, 1, 85) -- ≈ 12.5
		local overGearedIncome = realized * baselinePerTarget -- ≈ 1062/hr
		t.ok("capped Bayou farming income (~1062) is near Income(1) and ≪ Income(4) (~4913)", overGearedIncome < income4 and overGearedIncome < income1 * 1.2)
	end

	t.section("Spawner — ambiance occupies world density but NEVER the reward-bearing routine population")
	do
		local levee = Spawner.routineTargetsInZone(Catalog, "bayou", "sunny_levee")
		local function has(list: { string }, id: string): boolean
			for _, v in list do
				if v == id then
					return true
				end
			end
			return false
		end
		t.ok("Sunny Levee routine population = the floor targets (duck + rabbit)", has(levee, "bayou_wood_duck") and has(levee, "bayou_swamp_rabbit"))
		t.ok("a RARE (leucistic duck) is NOT part of the routine population (rares are bonus on top, RD5)", has(levee, "bayou_leucistic_wood_duck") == false)
		-- the Great Egret's ambiance home is the channel banks; it must never count toward that zone's ceiling
		local banks = Spawner.routineTargetsInZone(Catalog, "bayou", "channel_banks")
		t.ok("the ambiance Great Egret never enters the reward-bearing channel-banks population", has(banks, "bayou_great_egret") == false)
		t.ok("the routine gator IS in the channel-banks population", has(banks, "bayou_american_alligator"))
	end

	t.section("Spawner — rares are condition-gated independent spawns (NEVER a per-kill upgrade roll, RD-E)")
	do
		local ghost = Catalog.creatures.bayou_white_alligator -- conditions: dawn or dusk + fog
		t.ok("eligible only when ALL conditions hold (dawn/dusk + fog)", Spawner.rareSpawnEligible(ghost, { time = "dawn or dusk", weather = "fog" }))
		t.ok("a missing weather condition → not eligible", Spawner.rareSpawnEligible(ghost, { time = "dawn or dusk" }) == false)
		t.ok("no conditions at all → not eligible", Spawner.rareSpawnEligible(ghost, {}) == false)
		local pale = Catalog.creatures.bayou_leucistic_wood_duck -- conditions: dawn
		t.ok("the Pale Drake needs dawn", Spawner.rareSpawnEligible(pale, { time = "dawn" }) and Spawner.rareSpawnEligible(pale, { time = "dusk" }) == false)
	end

	t.section("Spawner — placement is validated at load (every Bayou target resolves to a real zone, P1)")
	do
		local bayouShell = Shells.byDestination.bayou
		t.test("the live Bayou placement passes validation", function()
			Spawner.validatePlacement(Catalog, bayouShell, bayouHunting)
		end)
		t.errs("a routine area pointing at a non-existent zone is rejected", function()
			local bad = { ceilingPerHour = 85, areas = { not_a_real_zone = { maxConcurrentTargets = 3, respawnIntervalSeconds = 35 } } }
			Spawner.validatePlacement(Catalog, bayouShell, bad :: any)
		end)
	end

	-- ── Step 5: the SAME cap mechanism, generalized for fishing (one anti-farming line, not duplicated) ──
	local F = Enums.Loop.Fishing
	local bayouFishing = (Spawning.byDestination.bayou :: any).fishing

	t.section("Spawner (fishing) — engagement rate runs through the SAME ceiling logic")
	do
		-- Bayou T1 fishing: TimePerCatch = 20 + 18 + 22 = 60 s → 60/hr (below the 65 ceiling, SYS_fishing §5)
		t.ok("Bayou T1 fishing rate = 60/hr", approx(Spawner.expectedTargetsPerHour(Catalog, 1, 65, F), 60))
	end

	t.section("Spawner (fishing) — the bite-density cap is the same anti-low-tier-farming invariant")
	do
		local realized = Spawner.realizedRoutineRatePerHour(Catalog, 1, 65, 0.001, F)
		t.ok("an over-geared player's realized catch-rate is CAPPED at the ceiling (65), not their catch speed", approx(realized, 65))
		local income1 = Catalog.tuning.economy.B
		local income4 = Catalog.tuning.economy.B * Catalog.tuning.economy.g ^ 3
		local baseline = income1 / Spawner.expectedTargetsPerHour(Catalog, 1, 65, F) -- ≈ 16.7
		t.ok("capped Bayou fishing income (~1085) is near Income(1) and ≪ Income(4)", realized * baseline < income4 and realized * baseline < income1 * 1.2)
	end

	t.section("Spawner (fishing) — routine population excludes rares; no ambiance fish exist")
	do
		local function has(list: { string }, id: string): boolean
			for _, v in list do
				if v == id then
					return true
				end
			end
			return false
		end
		local hole = Spawner.routineTargetsInZone(Catalog, "bayou", "catfish_hole", F)
		t.ok("the routine population includes the channel + blue catfish", has(hole, "bayou_channel_catfish") and has(hole, "bayou_blue_catfish"))
		t.ok("the Legendary Albino + Mythic Leviathan are NOT routine (rares are bonus on top, RD5)", has(hole, "bayou_albino_blue_catfish") == false and has(hole, "bayou_leviathan") == false)
	end

	t.section("Spawner (fishing) — rares are condition-gated and take NO bait input (Decision 4)")
	do
		local leviathan = Catalog.fish.bayou_leviathan -- conditions: night + storm; baitRequired: live sucker
		t.ok("eligible only when ALL conditions hold (night + storm)", Spawner.rareSpawnEligible(leviathan, { time = "night", weather = "storm" }))
		t.ok("a missing condition → not eligible", Spawner.rareSpawnEligible(leviathan, { time = "night" }) == false)
		-- the predicate reads ONLY spawn.conditions — it has no bait parameter, so bait can never buy a rare
		t.ok("the rare predicate ignores bait entirely (its signature takes none)", Spawner.rareSpawnEligible(leviathan, { time = "night", weather = "storm" }) == true)
	end

	t.section("Spawner (fishing) — placement validated at load (every Bayou fish resolves to a water zone)")
	do
		local bayouShell = Shells.byDestination.bayou
		t.test("the live Bayou fishing placement passes validation", function()
			Spawner.validatePlacement(Catalog, bayouShell, bayouFishing, F)
		end)
	end
end
