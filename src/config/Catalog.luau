--!strict
-- CATALOG — the aggregated, read-only `Config` the pure logic consumes. Joins every content catalog +
-- the tuning constants + a derived target→(loop, home, tier, rarity, milestone) index, and runs the
-- build-time validation on load (a malformed catalog fails the require — the loader/validator guarantee).

local Tuning = require("@src/config/Tuning")
local Equipment = require("@src/config/Equipment")
local Creatures = require("@src/config/Creatures")
local Fish = require("@src/config/Fish")
local Destinations = require("@src/config/Destinations")
local RankPerks = require("@src/config/RankPerks")
local Decor = require("@src/config/Decor")
local Validation = require("@src/config/Validation")
local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")

type Config = Schema.Config

-- Derived index: every creature is a Hunting target, every fish a Fishing target. Reject id collisions.
local targetIndex: { [string]: Schema.TargetIndexEntry } = {}
for id, c in Creatures do
	targetIndex[id] = {
		loop = Enums.Loop.Hunting,
		destinationId = c.destinationId,
		tier = c.tier,
		rarity = c.rarity,
		isMilestone = c.isMilestoneTarget == true,
	}
end
for id, f in Fish do
	if targetIndex[id] ~= nil then
		error("Catalog: target id collision between a creature and a fish: '" .. id .. "'")
	end
	targetIndex[id] = {
		loop = Enums.Loop.Fishing,
		destinationId = f.destinationId,
		tier = f.tier,
		rarity = f.rarity,
		isMilestone = f.isMilestoneTarget == true,
	}
end

local Catalog: Config = {
	tuning = Tuning,
	equipment = Equipment,
	creatures = Creatures,
	fish = Fish,
	destinations = Destinations,
	rankPerks = RankPerks,
	decor = Decor,
	targetIndex = targetIndex,
}

-- Build-time guarantee: validate the assembled config on load.
Validation.validateConfig(Catalog)

return Catalog
