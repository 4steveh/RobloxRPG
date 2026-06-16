--!strict
-- NEGATIVE FIXTURE — MUST FAIL `luau-analyze`. A rank perk with category "power" is unrepresentable:
-- RankPerkCategory is identity|convenience. This proves the no-pay-to-win guarantee at build time.
local Schema = require("@src/types/Schema")

local bad: Schema.RankPerk = {
	id = "power_perk",
	name = "Damage Boost",
	category = "power", -- ← type error: "power" is not a RankPerkCategory
	track = "Hunting",
	description = "Raises weapon damage — power, not a legal rank perk.",
}

return bad
