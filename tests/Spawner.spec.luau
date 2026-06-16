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
end
