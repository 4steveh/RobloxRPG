--!strict
local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local EHT = require("@src/logic/EffectiveTier")

return function(t: Harness.T)
	t.section("EffectiveTier — weakest-slot rule, empty slots, empty-armor floor")

	local function eht(e: Util.Equip): number
		return EHT.effectiveHuntingTier(Util.mkProfile(Catalog, e), Catalog)
	end
	local function eft(e: Util.Equip): number
		return EHT.effectiveFishingTier(Util.mkProfile(Catalog, e), Catalog)
	end

	-- min rule (not max, not avg)
	t.eq("EHT min: weapon T4 + armor T2 → 2 (not 4, not 3)", eht({ weapon = 4, armor = 2 }), 2)
	t.eq("EFT min: rod T4 + reel T2 → 2", eft({ rod = 4, reel = 2 }), 2)
	t.eq("EHT parity: weapon T4 + armor T4 → 4", eht({ weapon = 4, armor = 4 }), 4)
	t.eq("EFT parity: rod T2 + reel T2 → 2", eft({ rod = 2, reel = 2 }), 2)

	-- empty gating slots = Tier 0
	t.eq("EHT: empty weapon → 0", eht({ armor = 4 }), 0)
	t.eq("EFT: empty rod → 0", eft({ reel = 4 }), 0)
	t.eq("EFT: empty reel → 0", eft({ rod = 4 }), 0)

	-- empty-armor floor boundary around armorGatingStartTier (= 2)
	t.eq("empty armor, weapon T1 (< start) → floor 1 → EHT 1", eht({ weapon = 1 }), 1)
	t.eq("empty armor, weapon T2 (= start) → floor 0 → EHT 0", eht({ weapon = 2 }), 0)
	t.eq("empty armor, weapon T4 (> start) → floor 0 → EHT 0", eht({ weapon = 4 }), 0)

	-- the starter loadout computes EHT = EFT = 1
	t.eq("starter (weapon T1, no armor) → EHT 1", eht({ weapon = 1 }), 1)
	t.eq("starter (rod T1, reel T1) → EFT 1", eft({ rod = 1, reel = 1 }), 1)

	t.section("EffectiveTier — equipped ref is a STABLE key (survives inventory mutation)")
	-- Carry-over fix #2: equipped points at a commodity instanceId, not a list index. Reordering the
	-- commodities (here: prepend one, shifting every index) must NOT re-point the equipped weapon.
	local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2 }) -- ci1=weapon T2, ci2=armor T2; equipped.weapon="ci1"
	t.eq("EHT before mutation", EHT.effectiveHuntingTier(p, Catalog), 2)
	table.insert(p.inventory.commodities, 1, { instanceId = "ci-extra", catalogId = "bait_cut_bait", intraLevel = 0, equipped = false })
	t.eq("EHT unchanged after prepending a commodity (list indices shifted)", EHT.effectiveHuntingTier(p, Catalog), 2)
end
