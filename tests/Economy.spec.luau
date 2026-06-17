--!strict
-- Step 6 (economy) — the real formulas that replace the three stubs, and the marquee proofs: the per-loop
-- routine-hour reconciliation (01 risk #3, parity by construction), ceiling slackness, and the MVL
-- gear-Cash jump. All headless-pure. The shop UI + the LIVE (measured) reconciliation are Studio/telemetry.

local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Economy = require("@src/logic/Economy")
local Spawner = require("@src/logic/Spawner")
local Enums = require("@src/types/Enums")

local function approx(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return function(t: Harness.T)
	local H, F = Enums.Loop.Hunting, Enums.Loop.Fishing

	t.section("Economy — the income/gear/intra-tier curves (reads the EXISTING Tuning.economy constants)")
	do
		t.ok("Income: T1 1000 · T2 1700 · T3 2890 · T4 4913", approx(Economy.income(Catalog, 1), 1000) and approx(Economy.income(Catalog, 2), 1700) and approx(Economy.income(Catalog, 3), 2890) and approx(Economy.income(Catalog, 4), 4913))
		t.ok("GearCostSlot: T1 free (0) · T2 3000 · T4 8670", Economy.gearCostSlot(Catalog, 1) == 0 and approx(Economy.gearCostSlot(Catalog, 2), 3000) and approx(Economy.gearCostSlot(Catalog, 4), 8670))
		t.ok("IntraTierClimb(1) = m·Income(1) = 2500", approx(Economy.intraTierClimb(Catalog, 1), 2500))
		t.ok("IntraTierUpgradeCost(1): entry→mid 1100, mid→maxed 1400 (q-curve split, sums to 2500)", Economy.intraTierUpgradeCost(Catalog, 1, "entry") == 1100 and Economy.intraTierUpgradeCost(Catalog, 1, "mid") == 1400)
		t.ok("RarityMultiplier ladder", Economy.rarityMultiplier(Catalog, "Common") == 1 and Economy.rarityMultiplier(Catalog, "Uncommon") == 1.6 and Economy.rarityMultiplier(Catalog, "Mythic") == 16)
	end

	t.section("Economy — gating gear catalog prices match the formula (drift check)")
	do
		t.ok("every tier-input gating item with a Cash cost is priced at GearCostSlot(tier)", (function()
			for _, item in Catalog.equipment do
				if item.tierInput and (item.cost :: any).cash ~= nil then
					if (item.cost :: any).cash ~= Economy.gearCostSlot(Catalog, item.tier) then
						return false
					end
				end
			end
			return true
		end)())
	end

	t.section("Economy — routine payout is normalized per loop (band = routine mix, RD5)")
	do
		t.ok("AvgRoutineMultiplier: Bayou hunting 1.15, fishing 1.3", approx(Economy.avgRoutineMultiplier(Catalog, "bayou", H), 1.15) and approx(Economy.avgRoutineMultiplier(Catalog, "bayou", F), 1.3))
		t.eq("a routine Common hunt (wood duck) pays 11", Economy.payout(Catalog, 1, "Common", "bayou", H), 11)
		t.eq("a routine Uncommon catch (blue catfish) pays 21", Economy.payout(Catalog, 1, "Uncommon", "bayou", F), 21)
	end

	t.section("Economy — DUAL-LOOP RECONCILIATION: each loop's routine hour sums to Income(T) (01 risk #3)")
	do
		-- parity by CONSTRUCTION (the per-loop normalization), not a raw hunting≈fishing compare
		t.ok("Bayou (T1): hunting hour = fishing hour = Income(1) = 1000", approx(Economy.routineHourSum(Catalog, "bayou", H), 1000) and approx(Economy.routineHourSum(Catalog, "bayou", F), 1000))
		t.ok("Appalachia (T2): both loops = Income(2) = 1700", approx(Economy.routineHourSum(Catalog, "appalachia", H), 1700) and approx(Economy.routineHourSum(Catalog, "appalachia", F), 1700))
		t.ok("Alaska (T4): both loops = Income(4) = 4913", approx(Economy.routineHourSum(Catalog, "alaska", H), 4913) and approx(Economy.routineHourSum(Catalog, "alaska", F), 4913))
	end

	t.section("Economy — ceiling slackness (the at-tier complement to the anti-farming bound)")
	do
		-- if a ceiling were set BELOW the modeled rate, the at-tier player would be spawn-starved < Income(T)
		local hunt = (Catalog :: any) -- read the Spawning ceilings via the config? they live in Spawning, asserted here against modeled
		t.ok("Bayou hunting modeled 80 ≤ ceiling 85", Spawner.modeledRatePerHour(Catalog, 1, H) <= 85)
		t.ok("Bayou fishing modeled 60 ≤ ceiling 65", Spawner.modeledRatePerHour(Catalog, 1, F) <= 65)
	end

	t.section("Economy — the MVL two-tier gear-Cash jump (§4, pure formula)")
	do
		local normalStep = Economy.gearCostSlot(Catalog, 2) * 2 / Economy.income(Catalog, 1) -- T1→T2, two slots
		t.ok("a normal tier step costs 2c = 6 hrs", approx(normalStep, 6))
		local mvlJump = Economy.gearCostSlot(Catalog, 4) * 2 / Economy.income(Catalog, 2) -- buy T4 gear on T2 income
		t.ok("the Appalachia→Alaska jump costs 2c·g ≈ 10.2 hrs (≈1.7× a normal step)", approx(mvlJump, 10.2))
	end

	t.section("Economy — the salvage floor is deliberately LOW (Step 8 credits it on →SALVAGED)")
	do
		local fullFaucetValue = (Economy.income(Catalog, 1) / Spawner.modeledRatePerHour(Catalog, 1, H)) * Economy.rarityMultiplier(Catalog, "Mythic")
		t.ok("a Mythic's salvage floor is far below its conceptual faucet value", Economy.salvageFloor(Catalog, 1, "Mythic", H) < fullFaucetValue * 0.25)
		t.ok("the salvage floor is positive", Economy.salvageFloor(Catalog, 1, "Legendary", H) > 0)
	end

	t.section("Economy — the daily-quest faucet + cross-loop bonus (Step 7; scale off Income(T_current))")
	do
		t.eq("dailyQuestReward(1) = 0.25 · Income(1) = 250", Economy.dailyQuestReward(Catalog, 1), 250)
		t.eq("crossLoopBonus(1) ≈ 0.5 hr of Income(1) = 500", Economy.crossLoopBonus(Catalog, 1), 500)
		t.ok("both scale with the player's current tier", Economy.dailyQuestReward(Catalog, 2) > Economy.dailyQuestReward(Catalog, 1) and Economy.crossLoopBonus(Catalog, 2) > Economy.crossLoopBonus(Catalog, 1))
	end
end
