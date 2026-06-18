--!strict
-- CATALOG — the aggregated, read-only `Config` the pure logic consumes. Joins every content catalog +
-- the tuning constants + a derived target→(loop, home, tier, rarity, milestone) index, and runs the
-- build-time validation on load (a malformed catalog fails the require — the loader/validator guarantee).

local Tuning = require("./Tuning")
local Equipment = require("./Equipment")
local Creatures = require("./Creatures")
local Fish = require("./Fish")
local Destinations = require("./Destinations")
local RankPerks = require("./RankPerks")
local Decor = require("./Decor")
local LiveOps = require("./LiveOps")
local Products = require("./Monetization")
local Validation = require("./Validation")
local Schema = require("../types/Schema")
local Enums = require("../types/Enums")

type Config = Schema.Config

-- Step 13: merge the LiveOps event-INTRODUCED fish (RD1b `mintsFish`) into the fish catalog. Each minted id
-- MUST be genuinely new — the RD1 clone-evasion guard. `Validation.assertNewScarcityId` (wired here, against
-- the BASE catalogs pre-merge) rejects a minted id colliding with ANY existing catalog id (equipment /
-- creatures / base fish / decor / destinations); the merged-table check rejects a collision across events.
-- This is what makes "a new entry must be genuinely new" structural — not a forgeable spawn-clause edit.
local baseCatalogs = { equipment = Equipment, creatures = Creatures, fish = Fish, decor = Decor, destinations = Destinations } :: any
local fish: { [string]: Schema.Fish } = {}
for id, f in Fish do
	fish[id] = f
end
for _, event in LiveOps.events do
	for _, minted in event.mintsFish or {} do
		Validation.assertNewScarcityId(minted.id, baseCatalogs :: Config) -- ∉ any existing base catalog id
		if fish[minted.id] ~= nil then
			error("Catalog: LiveOps event '" .. event.id .. "' mints fish id '" .. minted.id .. "' that collides with another event's mint")
		end
		fish[minted.id] = minted
	end
end

-- Derived index: every creature is a Hunting target, every fish (incl. event-introduced) a Fishing target.
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
for id, f in fish do
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
	fish = fish, -- base + event-introduced (merged, collision-checked)
	destinations = Destinations,
	rankPerks = RankPerks,
	decor = Decor,
	liveOps = LiveOps,
	products = Products, -- Step 14: the real-money product catalog (self-validates via assertProduct on load)
	targetIndex = targetIndex,
}

-- Build-time guarantee: validate the assembled config on load.
Validation.validateConfig(Catalog)

return Catalog
