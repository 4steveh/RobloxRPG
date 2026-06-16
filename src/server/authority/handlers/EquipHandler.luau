--!strict
-- THE ONE REFERENCE INTENT HANDLER — `equip Y` (§2). Proves the gauntlet end-to-end with the simplest
-- real intent: a pure inventory-state mutation (no Cash, no artifact, no teleport). Its Authority check
-- is just "owns this commodity AND it is an equippable gating category". It also exercises the stable
-- equipped-ref key (carry-over fix #2): equip writes the commodity's instanceId into the slot.
-- (Other intent handlers register in their owning steps — buy/sell → 6, salvage/display → 8, etc.)

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Gauntlet = require("@src/server/authority/Gauntlet")

type Ctx = Gauntlet.Ctx
type Commodity = Schema.Commodity
type EquipmentItem = Schema.EquipmentItem

-- The four gating categories map 1:1 to equipped slot names. Only these are equippable.
local SLOT: { [Enums.Category]: string } = { weapon = "weapon", armor = "armor", rod = "rod", reel = "reel" }

local function resolve(ctx: Ctx): (Commodity?, EquipmentItem?)
	local instanceId = ctx.payload.commodityInstanceId
	if type(instanceId) ~= "string" then
		return nil, nil
	end
	for _, c in ctx.profile.inventory.commodities do
		if c.instanceId == instanceId then
			return c, ctx.config.equipment[c.catalogId]
		end
	end
	return nil, nil
end

local EquipHandler: Gauntlet.IntentHandler = {
	intent = "equip",
	critical = false, -- equip is NOT a criticalSaveTrigger → dirty-flag autosave
	simulate = nil, -- pure inventory mutation; no domain simulation

	authority = function(ctx: Ctx): (boolean, string?)
		local commodity, item = resolve(ctx)
		if commodity == nil then
			return false, "not_owned"
		end
		if item == nil then
			return false, "unknown_item"
		end
		if SLOT[item.category] == nil then
			return false, "not_equippable" -- bait/mount/dog/boat/tool/cosmetic have no slot
		end
		return true, nil
	end,

	commit = function(ctx: Ctx)
		local commodity, item = resolve(ctx)
		assert(commodity ~= nil and item ~= nil, "equip commit: authority should have caught this")
		local slot = SLOT[item.category]
		local equipped = ctx.profile.equipped :: any
		-- unset the previously-equipped commodity in this slot (maintain the equipped flags)
		local prev = equipped[slot]
		if prev ~= nil then
			for _, c in ctx.profile.inventory.commodities do
				if c.instanceId == prev then
					c.equipped = false
				end
			end
		end
		equipped[slot] = commodity.instanceId
		commodity.equipped = true
	end,
}

return EquipHandler
