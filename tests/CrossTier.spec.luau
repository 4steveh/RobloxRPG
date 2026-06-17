--!strict
-- Step 10 (Task 1.5): cross-tier difficulty RIGOR for Appalachia.
-- Asserts the spec's floor/ceiling SEMANTICS (sufficiency + role band) for every non-ambiance
-- Appalachia hunting target (minWeaponTierToKill ≤ 4) and every non-rare Appalachia fish.
-- Bayou strict derived==authored equality is NOT repeated here (covered by Combat/Fishing specs).
-- Alaska is NOT yet asserted (no Alaska data yet — Phase 2 / Task 2.6).

local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Combat = require("@src/logic/Combat")
local Fishing = require("@src/logic/Fishing")
local Enums = require("@src/types/Enums")

return function(t: Harness.T)
	-- ── Combat sufficiency + role band (every non-ambiance Appalachia creature, minWeapon ≤ 4) ──
	t.section("CrossTier — Appalachia hunting: soloable at authored min-tier (sufficiency, LOC_02 §3)")
	do
		for _, c in Catalog.creatures do
			if c.destinationId == "appalachia" and not c.ambianceOnly and c.minWeaponTierToKill <= 4 then
				local armorTier = math.max(c.minArmorTierToSurvive, c.minWeaponTierToKill)
				t.ok(
					c.id .. ": soloable at authored minWeaponTier " .. c.minWeaponTierToKill .. " (sufficiency)",
					Combat.soloableAt(Catalog, c, c.minWeaponTierToKill, armorTier)
				)
			end
		end
	end

	t.section("CrossTier — Appalachia hunting: authored minWeaponTier in role band [T-1, T+1]")
	do
		for _, c in Catalog.creatures do
			if c.destinationId == "appalachia" and not c.ambianceOnly then
				t.ok(
					c.id .. ": minWeaponTier " .. c.minWeaponTierToKill .. " ∈ [" .. (c.tier - 1) .. ", " .. (c.tier + 1) .. "] (role band)",
					c.minWeaponTierToKill >= c.tier - 1 and c.minWeaponTierToKill <= c.tier + 1
				)
			end
		end
	end

	-- ── Fishing sufficiency + role band (every non-rare Appalachia fish) ──
	t.section("CrossTier — Appalachia fishing: landable at authored min-tier (sufficiency, LOC_02 §3)")
	do
		for _, f in Catalog.fish do
			if f.destinationId == "appalachia" and Enums.RarityRank[f.rarity] < Enums.RARE_AND_ABOVE_RANK then
				t.ok(
					f.id .. ": landable at authored rod" .. f.minRodTier .. "/reel" .. f.minReelTier .. " (sufficiency)",
					Fishing.landableAt(Catalog, f, f.minRodTier, f.minReelTier)
				)
			end
		end
	end

	t.section("CrossTier — Appalachia fishing: authored minRodTier in role band [T-1, T+1]")
	do
		for _, f in Catalog.fish do
			if f.destinationId == "appalachia" and Enums.RarityRank[f.rarity] < Enums.RARE_AND_ABOVE_RANK then
				t.ok(
					f.id .. ": minRodTier " .. f.minRodTier .. " ∈ [" .. (f.tier - 1) .. ", " .. (f.tier + 1) .. "] (role band)",
					f.minRodTier >= f.tier - 1 and f.minRodTier <= f.tier + 1
				)
			end
		end
	end
end
