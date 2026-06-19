--!strict
local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Loadout = require("@src/logic/Loadout")

-- find a real catalog item id by category (+ optional tier) — data-driven, like the game does
local function itemId(category: string, tier: number?): string
	for _, it in Catalog.equipment do
		if it.category == category and (tier == nil or it.tier == tier) then
			return it.id
		end
	end
	error("test: no " .. category .. " item" .. (if tier ~= nil then " T" .. tier else ""))
end

return function(t: Harness.T)
	t.section("Loadout — owned equippable gear grouped by the four slots")
	local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, rod = 1, reel = 1 })
	local lo = Loadout.ownedEquippableBySlot(p, Catalog)
	t.eq("weapon slot has 1 owned", #lo.weapon, 1)
	t.eq("armor slot has 1 owned", #lo.armor, 1)
	t.eq("rod slot has 1 owned", #lo.rod, 1)
	t.eq("reel slot has 1 owned", #lo.reel, 1)
	t.ok("equipped weapon is marked equipped", lo.weapon[1].equipped)
	t.eq("weapon row carries the catalog tier", lo.weapon[1].tier, 2)
	t.ok("weapon row carries a name", lo.weapon[1].name ~= "")

	t.section("Loadout — multiple owned items in one slot; exactly one marked equipped")
	table.insert(p.inventory.commodities, { instanceId = "ci-w-extra", catalogId = itemId("weapon", nil), intraLevel = 0, equipped = false })
	lo = Loadout.ownedEquippableBySlot(p, Catalog)
	t.eq("weapon slot now lists 2 owned", #lo.weapon, 2)
	local nEquipped = 0
	for _, r in lo.weapon do if r.equipped then nEquipped += 1 end end
	t.eq("exactly one weapon equipped", nEquipped, 1)

	t.section("Loadout — equipped is DERIVED from profile.equipped, not the commodity flag")
	local p2 = Util.mkProfile(Catalog, { weapon = 2 }) -- equipped.weapon = "ci1"
	table.insert(p2.inventory.commodities, { instanceId = "ci-stale", catalogId = itemId("weapon", nil), intraLevel = 0, equipped = true }) -- stale flag, NOT the equipped ref
	local lo2 = Loadout.ownedEquippableBySlot(p2, Catalog)
	for _, r in lo2.weapon do
		if r.instanceId == "ci-stale" then
			t.ok("stale equipped=true flag overridden by derived ref → false", not r.equipped)
		elseif r.instanceId == "ci1" then
			t.ok("the profile.equipped ref is the one marked equipped", r.equipped)
		end
	end

	t.section("Loadout — non-equippable categories excluded")
	local p3 = Util.mkProfile(Catalog, { weapon = 1 })
	table.insert(p3.inventory.commodities, { instanceId = "ci-bait", catalogId = itemId("bait", nil), intraLevel = 0, equipped = false })
	local lo3 = Loadout.ownedEquippableBySlot(p3, Catalog)
	t.eq("bait is not in any equip slot (only the weapon counts)", #lo3.weapon + #lo3.armor + #lo3.rod + #lo3.reel, 1)

	t.section("Loadout — empty slots return empty lists")
	local p4 = Util.mkProfile(Catalog, { weapon = 1 })
	local lo4 = Loadout.ownedEquippableBySlot(p4, Catalog)
	t.eq("armor empty", #lo4.armor, 0)
	t.eq("rod empty", #lo4.rod, 0)
	t.eq("reel empty", #lo4.reel, 0)
end
