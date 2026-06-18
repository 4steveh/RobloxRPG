--!strict
-- SHARED Fish builder (Template D) — the XOR-enforcing constructor + the Template-E rare block. Extracted so
-- BOTH the base catalog (Fish.luau) and LiveOps event-introduced content (config/LiveOps.luau `mintsFish`)
-- build fish through the SAME validated path (Rare+ → artifact/no-Cash; Common/Uncommon → cash). A LiveOps
-- event introduces genuinely-new scarcity by authoring a Fish here and listing it in its `mintsFish` — the
-- Catalog merge then rejects any id that collides with an existing catalog id (the RD1 clone-evasion guard).

local Enums = require("../types/Enums")
local Schema = require("../types/Schema")
local Ids = require("../types/Ids")

type Fish = Schema.Fish
type Reward = Schema.Reward
type RareFields = Schema.RareFields

local M = {}

export type FishInput = {
	id: string,
	destinationId: Ids.DestinationId,
	name: string,
	tier: number,
	rarity: Enums.Rarity,
	typicalWeightKg: { min: number, max: number },
	recordWeightKg: number,
	fightDifficulty: number,
	minRodTier: number,
	minReelTier: number,
	waterType: Enums.WaterType,
	baitRequired: string?,
	requiresItem: string?,
	spawnZones: { string }?,
	conditions: Schema.SpawnConditions?,
	isMilestoneTarget: boolean?,
	cash: { min: number, max: number }?,
	rare: RareFields?,
}

function M.isRareOrAbove(rarity: Enums.Rarity): boolean
	return Enums.RarityRank[rarity] >= Enums.RARE_AND_ABOVE_RANK
end

function M.fish(i: FishInput): Fish
	local reward: Reward
	if M.isRareOrAbove(i.rarity) then
		local r = assert(i.rare, i.id .. ": Rare-and-above must carry Template-E rare fields")
		reward = { kind = "artifact", artifact = { tradeable = r.tradeable, displayableInLodge = r.displayableInLodge } }
	else
		local c = assert(i.cash, i.id .. ": Common/Uncommon must carry a cash range")
		reward = { kind = "cash", cash = c }
	end
	return {
		id = i.id,
		destinationId = i.destinationId,
		name = i.name,
		tier = i.tier,
		rarity = i.rarity,
		typicalWeightKg = i.typicalWeightKg,
		recordWeightKg = i.recordWeightKg,
		fightDifficulty = i.fightDifficulty,
		minRodTier = i.minRodTier,
		minReelTier = i.minReelTier,
		baitRequired = i.baitRequired,
		requiresItem = i.requiresItem,
		waterType = i.waterType,
		spawnZones = i.spawnZones,
		reward = reward,
		spawn = { conditions = i.conditions },
		rare = i.rare,
		isMilestoneTarget = i.isMilestoneTarget,
	}
end

function M.rareFields(spawnRate: number, moment: string): RareFields
	return {
		spawnRate = spawnRate,
		tradeable = true,
		displayableInLodge = true,
		reReleasePolicy = "NEVER",
		intendedContentMoment = moment,
	}
end

return M
