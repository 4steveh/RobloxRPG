--!strict
-- PURE READ-ONLY VIEW — the player's OWNED equippable gear, grouped by the four equip slots, each row
-- marked `equipped` DERIVED from `profile.equipped` (never the denormalized `commodity.equipped` flag).
-- Zero content literals; the slot set comes from Enums.TIER_INPUT_CATEGORIES. Feeds the field-inventory
-- client panel via the InventoryRequest server handler. Same row shape as the shop's owned listing.
local Schema = require("../types/Schema")
local Enums = require("../types/Enums")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type Category = Enums.Category

export type GearRow = {
	instanceId: string,
	catalogId: string,
	name: string,
	tier: number,
	intraLevel: number,
	equipped: boolean,
}
export type Loadout = {
	weapon: { GearRow },
	armor: { GearRow },
	rod: { GearRow },
	reel: { GearRow },
}

local M = {}

-- The equipped commodity instanceId for a category. Explicit per-slot (strict-safe — EquippedRefs is a
-- named struct, not a string-indexed map). nil = empty slot.
local function equippedInstanceId(profile: PlayerData, category: Category): string?
	local e = profile.equipped
	if category == Enums.Category.weapon then
		return e.weapon
	elseif category == Enums.Category.armor then
		return e.armor
	elseif category == Enums.Category.rod then
		return e.rod
	elseif category == Enums.Category.reel then
		return e.reel
	end
	return nil
end

function M.ownedEquippableBySlot(profile: PlayerData, config: Config): Loadout
	local out: Loadout = { weapon = {}, armor = {}, rod = {}, reel = {} }
	for _, c in profile.inventory.commodities do
		local item = config.equipment[c.catalogId]
		if item ~= nil and Enums.TIER_INPUT_CATEGORIES[item.category] then
			local rowData: GearRow = {
				instanceId = c.instanceId,
				catalogId = c.catalogId,
				name = item.name,
				tier = item.tier,
				intraLevel = c.intraLevel,
				equipped = equippedInstanceId(profile, item.category) == c.instanceId,
			}
			-- item.category is guaranteed one of the four by TIER_INPUT_CATEGORIES above
			if item.category == Enums.Category.weapon then
				table.insert(out.weapon, rowData)
			elseif item.category == Enums.Category.armor then
				table.insert(out.armor, rowData)
			elseif item.category == Enums.Category.rod then
				table.insert(out.rod, rowData)
			elseif item.category == Enums.Category.reel then
				table.insert(out.reel, rowData)
			end
		end
	end
	return out
end

return M
