--!strict
-- DECOR catalog (Step 8) — the starter MVL Lodge decor/theme/framing SKUs: SYS_economy §9's PRIMARY
-- evergreen inflation ballast. Cash-priced, balance-free (identity-only monetization; NO stats field),
-- tradeable=false typed-owned commodities. This is the SEED catalog; the ongoing SKU cadence is the LiveOps
-- SLA (Step 13, SYS_liveops_calendar) and the full table is EQUIPMENT_MASTER §4.9's. A malformed SKU fails
-- the require via Catalog → Validation.assertDecorItem.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Ids = require("@src/types/Ids")

type DecorItem = Schema.DecorItem
local K = Enums.DecorKind
local M = Enums.MonetizationRole

local function cash(n: number): Schema.Cost
	return { cash = n }
end

local rows: { DecorItem } = {
	{
		id = "decor_rustic_rug" :: Ids.ItemId,
		name = "Rustic Bayou Rug",
		kind = K.decor,
		cost = cash(500),
		tradeable = false,
		monetizationRoles = { M.identity },
		notes = "Standard Cash-priced floor decor; identity only.",
	},
	{
		id = "decor_lantern_set" :: Ids.ItemId,
		name = "Hanging Lantern Set",
		kind = K.decor,
		cost = cash(750),
		tradeable = false,
		monetizationRoles = { M.identity },
		notes = "Wall/lighting decor; identity only.",
	},
	{
		id = "theme_bayou_cabin" :: Ids.ItemId,
		name = "Rustic Bayou Cabin Theme",
		kind = K.theme,
		cost = cash(6000),
		tradeable = false,
		monetizationRoles = { M.identity },
		notes = "Cohesive room re-skin — the high-value identity unit; the natural regional/seasonal drop.",
	},
	{
		id = "theme_alaska_lodge" :: Ids.ItemId,
		name = "Alaska Expedition Lodge Theme",
		kind = K.theme,
		cost = cash(9000),
		tradeable = false,
		monetizationRoles = { M.identity },
		notes = "Cohesive room re-skin; identity only.",
	},
	{
		id = "framing_brass_plaque" :: Ids.ItemId,
		name = "Brass Trophy Plaque",
		kind = K.framing,
		cost = cash(1200),
		tradeable = false,
		monetizationRoles = { M.identity },
		notes = "Per-trophy framing upgrade — spend on a trophy you already own; additive flair, never a fix for a cheap default.",
	},
	{
		id = "framing_mythic_frame" :: Ids.ItemId,
		name = "Mythic Display Frame",
		kind = K.framing,
		cost = cash(3000),
		tradeable = false,
		monetizationRoles = { M.identity },
		notes = "Premium per-trophy frame; identity only.",
	},
}

local catalog: { [Ids.ItemId]: DecorItem } = {}
for _, d in rows do
	if catalog[d.id] ~= nil then
		error("Decor: duplicate decor id '" .. d.id .. "'")
	end
	catalog[d.id] = d
end

return catalog
