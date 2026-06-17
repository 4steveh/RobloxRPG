--!strict
-- Step 10 (Task 1.5 / Task 2.6): cross-tier difficulty RIGOR for Appalachia + Alaska.
-- Asserts the spec's floor/ceiling SEMANTICS (sufficiency + role band) for every non-ambiance
-- Appalachia/Alaska hunting target and every non-rare Appalachia/Alaska fish.
-- Alaska co-op-only apex (grizzly, halibut): wall at T4 solo, co-op-soluble at T4 + partyCap.
-- Bayou strict derived==authored equality is NOT repeated here (covered by Combat/Fishing specs).

local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Combat = require("@src/logic/Combat")
local Fishing = require("@src/logic/Fishing")
local Enums = require("@src/types/Enums")

local MAX_MVL_TIER = 4

return function(t: Harness.T)
	local partyCap = Catalog.tuning.combat.coop.partyCap

	-- ── Combat sufficiency + role band (every non-ambiance Appalachia + Alaska creature) ──
	t.section("CrossTier — Appalachia+Alaska hunting: role band [T-1, T+1] (all non-ambiance)")
	do
		for _, c in Catalog.creatures do
			if (c.destinationId == "appalachia" or c.destinationId == "alaska") and not c.ambianceOnly then
				t.ok(
					c.id .. ": minWeaponTier " .. c.minWeaponTierToKill .. " ∈ [" .. (c.tier - 1) .. ", " .. (c.tier + 1) .. "] (role band)",
					c.minWeaponTierToKill >= c.tier - 1 and c.minWeaponTierToKill <= c.tier + 1
				)
			end
		end
	end

	t.section("CrossTier — Appalachia+Alaska hunting: soloable sufficiency (minWeapon ≤ T4) OR co-op-only apex proof (minWeapon > T4)")
	do
		for _, c in Catalog.creatures do
			if (c.destinationId == "appalachia" or c.destinationId == "alaska") and not c.ambianceOnly then
				if c.minWeaponTierToKill <= MAX_MVL_TIER then
					-- soloable at authored tier (sufficiency)
					local armorTier = math.max(c.minArmorTierToSurvive, c.minWeaponTierToKill)
					t.ok(
						c.id .. ": soloable at authored minWeaponTier " .. c.minWeaponTierToKill .. " (sufficiency)",
						Combat.soloableAt(Catalog, c, c.minWeaponTierToKill, armorTier)
					)
				else
					-- co-op-only apex: wall at T4 solo, co-op-soluble at partyCap, soloable at T5
					t.ok(
						c.id .. ": NOT soloable at T4 even maxed (the wall — apex offset proves co-op requirement)",
						Combat.soloableAt(Catalog, c, 4, 4) == false
					)
					t.ok(
						c.id .. ": co-op-soluble at T4 with a full party (partyCap=" .. partyCap .. ")",
						Combat.coopSoloableAt(Catalog, c, 4, partyCap)
					)
					t.ok(
						c.id .. ": soloable at T5 (post-launch T+1, the release valve)",
						Combat.soloableAt(Catalog, c, 5, 5)
					)
				end
			end
		end
	end

	-- ── Fishing sufficiency + role band (every non-rare Appalachia + Alaska fish) ──
	t.section("CrossTier — Appalachia+Alaska fishing: role band [T-1, T+1] (non-rare)")
	do
		for _, f in Catalog.fish do
			if (f.destinationId == "appalachia" or f.destinationId == "alaska") and Enums.RarityRank[f.rarity] < Enums.RARE_AND_ABOVE_RANK then
				t.ok(
					f.id .. ": minRodTier " .. f.minRodTier .. " ∈ [" .. (f.tier - 1) .. ", " .. (f.tier + 1) .. "] (role band)",
					f.minRodTier >= f.tier - 1 and f.minRodTier <= f.tier + 1
				)
			end
		end
	end

	t.section("CrossTier — Appalachia+Alaska fishing: landable sufficiency (max(rod,reel) ≤ T4) OR co-op-only wall proof (max > T4)")
	do
		for _, f in Catalog.fish do
			if (f.destinationId == "appalachia" or f.destinationId == "alaska") and Enums.RarityRank[f.rarity] < Enums.RARE_AND_ABOVE_RANK then
				if math.max(f.minRodTier, f.minReelTier) <= MAX_MVL_TIER then
					-- soloable at authored tiers (sufficiency)
					t.ok(
						f.id .. ": landable at authored rod" .. f.minRodTier .. "/reel" .. f.minReelTier .. " (sufficiency)",
						Fishing.landableAt(Catalog, f, f.minRodTier, f.minReelTier)
					)
				else
					-- co-op-only: NOT landable solo at T4 (the wall), co-op-soluble at partyCap
					t.ok(
						f.id .. ": NOT landable solo at T4 (throws — co-op-only wall)",
						Fishing.landableAt(Catalog, f, 4, 4) == false
					)
					t.ok(
						f.id .. ": co-op-soluble at T4 with a full party (partyCap=" .. partyCap .. ", not a wall)",
						Fishing.coopLandableAt(Catalog, f, 4, partyCap)
					)
				end
			end
		end
	end

	-- ── Alaska milestones soloable at T4; T2→T4 step is a step not a cliff ──
	t.section("CrossTier — milestones soloable at T4; the T2→T4 jump is a step not a cliff (progression §2)")
	do
		t.ok(
			"bull moose hunting milestone soloable at T4 (RD-A)",
			Combat.soloableAt(Catalog, Catalog.creatures.alaska_bull_moose, 4, 4)
		)
		t.ok(
			"king salmon fishing milestone landable solo at T4 (Decision 7)",
			Fishing.landableAt(Catalog, Catalog.fish.alaska_king_salmon, 4, 4)
		)
		t.ok(
			"Alaska floor (arctic hare) is non-lethal (dmg 0) — survivable on arrival gear regardless of armor",
			Catalog.creatures.alaska_arctic_hare.damageToPlayer == 0
		)
	end
end
