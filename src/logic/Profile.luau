--!strict
-- PlayerData constructors. freshProfile() produces a valid new player: the free Tier-1 starter
-- weapon + rod + reel (all equipped), an EMPTY armor slot, everything else empty, ranks 0, an empty
-- ledger (balance 0), and unlockedDestinations = { the free starter Destination }. The starter loadout
-- and the starter Destination are DERIVED FROM CONFIG (items flagged availableAt=StarterLoadout; the
-- Destination with requiredTier 0) — so this logic carries zero hardcoded content.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Validation = require("@src/config/Validation")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type Artifact = Schema.Artifact
type Commodity = Schema.Commodity
type EquipmentItem = Schema.EquipmentItem

local M = {}

local function findStarter(config: Config, category: Enums.Category): EquipmentItem
	local found: EquipmentItem? = nil
	for _, it in config.equipment do
		if it.availableAt == Enums.Vendor.StarterLoadout and it.category == category then
			assert(found == nil, "freshProfile: more than one StarterLoadout " .. category .. " in the catalog")
			found = it
		end
	end
	return assert(found, "freshProfile: no StarterLoadout " .. category .. " item in the catalog")
end

-- freshProfile(config) — valid new player. Result satisfies EHT = EFT = 1 (asserted in tests).
function M.freshProfile(config: Config): PlayerData
	local starterWeapon = findStarter(config, Enums.Category.weapon)
	local starterRod = findStarter(config, Enums.Category.rod)
	local starterReel = findStarter(config, Enums.Category.reel)

	-- commodities: deterministic order weapon, rod, reel; all equipped; intra-tier level 0; NO armor.
	-- Each carries a stable instanceId (the equipped refs point at these, not list positions).
	local commodities: { Commodity } = {
		{ instanceId = "ci1", catalogId = starterWeapon.id, intraLevel = 0, equipped = true },
		{ instanceId = "ci2", catalogId = starterRod.id, intraLevel = 0, equipped = true },
		{ instanceId = "ci3", catalogId = starterReel.id, intraLevel = 0, equipped = true },
	}

	-- The free, gate-less starter Destination (requiredTier 0) seeds unlockedDestinations.
	local starterDestinationId: string? = nil
	for _, dst in config.destinations do
		if dst.gate.requiredTier == 0 then
			assert(starterDestinationId == nil, "freshProfile: more than one free-starter (requiredTier 0) Destination")
			starterDestinationId = dst.id
		end
	end
	local starterId = assert(starterDestinationId, "freshProfile: no free-starter (requiredTier 0) Destination")

	local unlocked: { [string]: boolean } = {}
	unlocked[starterId] = true

	return {
		unlockedDestinations = unlocked,
		conqueredDestinations = {},
		hunterRankXP = 0,
		anglerRankXP = 0,
		inventory = {
			fungible = {},
			commodities = commodities,
			artifactIds = {},
		},
		equipped = {
			weapon = "ci1",
			armor = nil, -- empty armor slot (armor is not a gating slot at Tier 1)
			rod = "ci2",
			reel = "ci3",
		},
		artifacts = {},
		cash = { checkpoint = { balance = 0, compactedCount = 0, lastEntryId = 0 }, tail = {} }, -- balance 0
		nextCommodityInstanceSeq = 4, -- ci1..ci3 used; next mint is ci4 (Step 6 buys mint from here)
		redeemedPurchaseIds = {},
		logoutTimestamp = 0, -- Step 2 writes it at clean session-end
		lastSaveTimestamp = 0,
		sessionOpen = false,
		activeEntitlements = {},
	}
end

-- COMMODITY MINT (Step 6) — grant a new gear instance into the inventory with a fresh, stable instanceId
-- from the monotonic per-player sequence (the same scheme freshProfile seeds). The shop's buy handler calls
-- this after a successful Cash debit; the starter grant (freshProfile) is the same mint's first, free use.
-- NOT equipped on mint (equip is the separate EquipHandler) — so buying a slot does not change EHT/EFT until
-- the player equips it, and never satisfies a Gate by itself.
function M.mintCommodity(profile: PlayerData, catalogId: string, intraLevel: number): Commodity
	local instanceId = "ci" .. profile.nextCommodityInstanceSeq
	profile.nextCommodityInstanceSeq += 1
	local commodity: Commodity = { instanceId = instanceId, catalogId = catalogId, intraLevel = intraLevel, equipped = false }
	table.insert(profile.inventory.commodities, commodity)
	return commodity
end

-- Artifact constructor — rejects an illegal disposition for the kind (DISPLAYED/SALVAGED are Trophy-only).
-- The single safe path to create an Artifact value; the negative test passes a non-trophy DISPLAYED here.
function M.newArtifact(args: {
	artifactId: string,
	owner: string,
	kind: Enums.ArtifactKind,
	disposition: Enums.Disposition,
	tradeable: boolean,
	provenance: Schema.Provenance?,
}): Artifact
	Validation.assertDispositionLegal(args.kind, args.disposition)
	return {
		artifactId = args.artifactId,
		owner = args.owner,
		kind = args.kind,
		disposition = args.disposition,
		tradeable = args.tradeable,
		tombstoned = false,
		provenance = args.provenance or {},
	}
end

return M
