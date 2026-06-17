--!strict
local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Profile = require("@src/logic/Profile")
local EHT = require("@src/logic/EffectiveTier")
local Balance = require("@src/logic/Balance")
local Ids = require("@src/types/Ids")
local Schema = require("@src/types/Schema")

return function(t: Harness.T)
	t.section("freshProfile — a valid Tier-1 starter (asserted invariants)")

	local p = Profile.freshProfile(Catalog)

	t.eq("EHT = 1", EHT.effectiveHuntingTier(p, Catalog), 1)
	t.eq("EFT = 1", EHT.effectiveFishingTier(p, Catalog), 1)
	t.eq("balance = 0 (empty ledger)", Balance.balanceOf(p), 0)
	t.ok("Bayou ∈ unlockedDestinations", p.unlockedDestinations[Ids.Destination.Bayou] == true)
	t.ok("only the Bayou is unlocked", (function()
		local n = 0
		for _ in p.unlockedDestinations do
			n += 1
		end
		return n == 1
	end)())
	t.ok("conqueredDestinations empty", next(p.conqueredDestinations) == nil)
	t.ok("armor slot empty", p.equipped.armor == nil)
	t.ok("weapon/rod/reel equipped", p.equipped.weapon ~= nil and p.equipped.rod ~= nil and p.equipped.reel ~= nil)
	t.eq("hunter + angler rank XP = 0", p.hunterRankXP + p.anglerRankXP, 0)
	t.eq("exactly 3 commodities (weapon, rod, reel)", #p.inventory.commodities, 3)
	t.ok("all commodities equipped", (function()
		for _, c in p.inventory.commodities do
			if not c.equipped then
				return false
			end
		end
		return true
	end)())
	t.ok("no entitlements, no artifacts, no fungibles", #p.activeEntitlements == 0 and next(p.artifacts) == nil and next(p.inventory.fungible) == nil)
	t.ok("onboarding begins at FIRST_HUNT (Step 7)", p.onboarding ~= nil and p.onboarding.funnelBeat == "FIRST_HUNT")
	t.ok("a fresh profile has not completed onboarding", p.onboarding ~= nil and p.onboarding.completedAt == nil)
	t.ok("the daily state is zeroed (no objectives done, unclaimed)", p.daily ~= nil and p.daily.huntDone == false and p.daily.fishDone == false and p.daily.claimed == false)

	-- the equipped starter weapon resolves (by stable instanceId) to a Tier-1 catalog item
	local weaponInstanceId = assert(p.equipped.weapon)
	local starterWeaponItem: Schema.EquipmentItem? = nil
	for _, c in p.inventory.commodities do
		if c.instanceId == weaponInstanceId then
			starterWeaponItem = Catalog.equipment[c.catalogId]
		end
	end
	local starterWeapon = assert(starterWeaponItem, "equipped weapon instanceId resolves to an owned commodity")
	t.ok("equipped starter weapon is Tier 1", starterWeapon.tier == 1)
	t.ok("equipped starter weapon is from the StarterLoadout (free)", starterWeapon.availableAt == "StarterLoadout")

	t.section("mintCommodity — grants a new gear instance (the Step-6 shop primitive)")
	do
		local mp = Profile.freshProfile(Catalog) -- 3 starter commodities; nextCommodityInstanceSeq = 4
		local c = Profile.mintCommodity(mp, "weapon_lever_action_rifle", 0)
		t.ok("minted with a fresh stable instanceId (ci4)", c.instanceId == "ci4")
		t.ok("NOT equipped on mint, entry intra-level", c.equipped == false and c.intraLevel == 0)
		t.eq("appended to inventory.commodities (now 4)", #mp.inventory.commodities, 4)
		t.eq("nextCommodityInstanceSeq advanced to 5", mp.nextCommodityInstanceSeq, 5)
		local c2 = Profile.mintCommodity(mp, "armor_field_jacket", 0)
		t.ok("a second mint is monotonic (ci5)", c2.instanceId == "ci5")
		t.ok("buying does NOT equip → EHT unchanged until the player equips it", EHT.effectiveHuntingTier(mp, Catalog) == 1)
	end
end
