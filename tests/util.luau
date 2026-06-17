--!strict
-- Test-only helpers. Builds PlayerData profiles with specified EQUIPPED gear tiers, conquered/unlocked
-- sets, and a Cash ledger — by resolving real catalog items (data-driven, like the game would).

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type EquipmentItem = Schema.EquipmentItem

local U = {}

local function findByCatTier(config: Config, category: Enums.Category, tier: number): EquipmentItem
	for _, it in config.equipment do
		if it.category == category and it.tier == tier then
			return it
		end
	end
	error(string.format("test util: no %s item at tier %d in the catalog", category, tier))
end

export type Equip = {
	weapon: number?,
	armor: number?,
	rod: number?,
	reel: number?,
	conquered: { string }?,
	unlocked: { string }?,
	ledger: { number }?, -- signed Cash amounts → ledger entries
}

-- mkProfile(config, equip): a PlayerData with the given equipped gear tiers (nil = empty slot).
function U.mkProfile(config: Config, equip: Equip): PlayerData
	local commodities: { Schema.Commodity } = {}
	local seq = 0
	local function addSlot(category: Enums.Category, tier: number?): string?
		if tier == nil then
			return nil
		end
		local it = findByCatTier(config, category, tier)
		seq += 1
		local instanceId = "ci" .. seq
		table.insert(commodities, { instanceId = instanceId, catalogId = it.id, intraLevel = 0, equipped = true })
		return instanceId
	end

	local equipped: Schema.EquippedRefs = {
		weapon = addSlot(Enums.Category.weapon, equip.weapon),
		armor = addSlot(Enums.Category.armor, equip.armor),
		rod = addSlot(Enums.Category.rod, equip.rod),
		reel = addSlot(Enums.Category.reel, equip.reel),
	}

	local conquered: { [string]: boolean } = {}
	for _, id in equip.conquered or {} do
		conquered[id] = true
	end
	local unlocked: { [string]: boolean } = {}
	for _, id in equip.unlocked or {} do
		unlocked[id] = true
	end
	local tail: { Schema.LedgerEntry } = {}
	for i, amt in equip.ledger or {} do
		table.insert(tail, { entryId = i, type = "test", amount = amt, timestamp = i, validatingEventId = "test:" .. i })
	end

	return {
		unlockedDestinations = unlocked,
		conqueredDestinations = conquered,
		hunterRankXP = 0,
		anglerRankXP = 0,
		inventory = { fungible = {}, commodities = commodities, artifactIds = {} },
		equipped = equipped,
		artifacts = {},
		cash = { checkpoint = { balance = 0, compactedCount = 0, lastEntryId = #tail }, tail = tail },
		nextCommodityInstanceSeq = seq + 1,
		redeemedPurchaseIds = {},
		logoutTimestamp = 0,
		lastSaveTimestamp = 0,
		sessionOpen = false,
		activeEntitlements = {},
		onboarding = { funnelBeat = Enums.FunnelBeat.FIRST_HUNT, beatStartedAt = 0, completedAt = nil, progress = 0 },
		daily = { resetBasis = 0, huntDone = false, fishDone = false, claimed = false },
	}
end

-- True if any string in `list` contains `needle` (case-sensitive substring).
function U.anyContains(list: { string }, needle: string): boolean
	for _, s in list do
		if string.find(s, needle, 1, true) ~= nil then
			return true
		end
	end
	return false
end

return U
