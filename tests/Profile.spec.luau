--!strict
local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Profile = require("@src/logic/Profile")
local EHT = require("@src/logic/EffectiveTier")
local Balance = require("@src/logic/Balance")
local Ids = require("@src/types/Ids")

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

	-- the equipped starter weapon resolves to a Tier-1 catalog item
	local wIdx = assert(p.equipped.weapon)
	local starterWeapon = Catalog.equipment[p.inventory.commodities[wIdx].catalogId]
	t.ok("equipped starter weapon is Tier 1", starterWeapon.tier == 1)
	t.ok("equipped starter weapon is from the StarterLoadout (free)", starterWeapon.availableAt == "StarterLoadout")
end
