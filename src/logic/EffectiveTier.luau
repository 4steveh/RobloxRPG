--!strict
-- PURE DERIVATION — Effective Hunting/Fishing Tier (progression §1). Derived from EQUIPPED item tiers,
-- never stored. The weakest-required-slot rule: effective tier = MIN of the gating slots (not max/avg).
-- Contains ZERO content literals — every value comes from `profile` (state) and `config` (data).

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type Loop = Enums.Loop

local M = {}

-- Resolve an equipped slot to a tier: ref → commodity → catalog item.tier. Empty/unresolved = Tier 0.
local function tierOfSlot(profile: PlayerData, config: Config, slotIndex: number?): number
	if slotIndex == nil then
		return 0
	end
	local commodity = profile.inventory.commodities[slotIndex]
	if commodity == nil then
		return 0
	end
	local item = config.equipment[commodity.catalogId]
	if item == nil then
		return 0
	end
	return item.tier
end

function M.weaponTier(profile: PlayerData, config: Config): number
	return tierOfSlot(profile, config, profile.equipped.weapon)
end

function M.rodTier(profile: PlayerData, config: Config): number
	return tierOfSlot(profile, config, profile.equipped.rod)
end

function M.reelTier(profile: PlayerData, config: Config): number
	return tierOfSlot(profile, config, profile.equipped.reel)
end

-- Armor is a gating slot only from `armorGatingStartTier` onward. An EMPTY armor slot is treated as
-- Tier 1 below that start tier (so a T1 armorless player still computes EHT 1 in the Bayou) and Tier 0
-- at/above it (so a T2+ weapon with no armor cannot clear a T2+ gate — armor becomes the weak slot).
-- The decision is made against the weapon tier (the tier the player is operating at).
function M.armorTierOrFloor(profile: PlayerData, config: Config): number
	if profile.equipped.armor ~= nil then
		return tierOfSlot(profile, config, profile.equipped.armor)
	end
	local weaponTier = M.weaponTier(profile, config)
	local startTier = config.tuning.progression.armorGatingStartTier
	if weaponTier < startTier then
		return 1 -- below the armor-gating start tier: armorless still counts as Tier 1
	end
	return 0 -- at/above: an empty armor slot drags the effective tier to 0
end

-- EHT = min(weaponTier, armorTierOrFloor). Empty weapon = Tier 0 (you cannot hunt with no weapon).
function M.effectiveHuntingTier(profile: PlayerData, config: Config): number
	return math.min(M.weaponTier(profile, config), M.armorTierOrFloor(profile, config))
end

-- EFT = min(rodTier, reelTier). Empty rod or reel = Tier 0.
function M.effectiveFishingTier(profile: PlayerData, config: Config): number
	return math.min(M.rodTier(profile, config), M.reelTier(profile, config))
end

-- The per-loop effective tier the gate consumes. NEVER a blind max(EHT, EFT) — the gate iterates a
-- Destination's offeredLoops and asks this for each, so a single-loop Destination reads only its loop.
function M.effectiveTier(profile: PlayerData, config: Config, loop: Loop): number
	if loop == Enums.Loop.Hunting then
		return M.effectiveHuntingTier(profile, config)
	else
		return M.effectiveFishingTier(profile, config)
	end
end

return M
