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

	-- commodities: deterministic order weapon(1), rod(2), reel(3); all equipped; intra-tier level 0; NO armor.
	local commodities: { Commodity } = {
		{ catalogId = starterWeapon.id, intraLevel = 0, equipped = true },
		{ catalogId = starterRod.id, intraLevel = 0, equipped = true },
		{ catalogId = starterReel.id, intraLevel = 0, equipped = true },
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
			weapon = 1,
			armor = nil, -- empty armor slot (armor is not a gating slot at Tier 1)
			rod = 2,
			reel = 3,
		},
		artifacts = {},
		cashLedger = {}, -- balance 0
		logoutTimestamp = 0, -- Step 2 owns WRITING it
		activeEntitlements = {},
	}
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
		provenance = args.provenance or {},
	}
end

return M
