--!strict
-- PURE DERIVATION — Destination gate satisfaction (progression §2). evaluateGate is the SINGLE source
-- of truth for "why can't I go yet"; its unmetReasons are actionable-noun strings the UI consumes
-- directly (the UI never re-derives gate logic). Derived, never stored. Zero content literals.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local EffectiveTier = require("@src/logic/EffectiveTier")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type Destination = Schema.Destination
type Loop = Enums.Loop

export type GateResult = { unlocked: boolean, unmetReasons: { string } }

local M = {}

local function offers(destination: Destination, loop: Loop): boolean
	for _, l in destination.offeredLoops do
		if l == loop then
			return true
		end
	end
	return false
end

-- The slots below `requiredTier` on a loop — the exact weak slots to name (the legibility contract).
local function weakSlots(profile: PlayerData, config: Config, loop: Loop, requiredTier: number): { string }
	local weak: { string } = {}
	if loop == Enums.Loop.Hunting then
		if EffectiveTier.weaponTier(profile, config) < requiredTier then
			table.insert(weak, "weapon")
		end
		if EffectiveTier.armorTierOrFloor(profile, config) < requiredTier then
			table.insert(weak, "armor")
		end
	else
		if EffectiveTier.rodTier(profile, config) < requiredTier then
			table.insert(weak, "rod")
		end
		if EffectiveTier.reelTier(profile, config) < requiredTier then
			table.insert(weak, "reel")
		end
	end
	return weak
end

local function targetName(config: Config, targetId: string): string
	local c = config.creatures[targetId]
	if c ~= nil then
		return c.name
	end
	local f = config.fish[targetId]
	if f ~= nil then
		return f.name
	end
	return targetId
end

-- Verb by loop for the legibility string.
local function takeVerb(loop: Loop): string
	return loop == Enums.Loop.Hunting and "down" or "land"
end

-- evaluateGate(profile, destination, config) -> { unlocked, unmetReasons }.
-- Two gate halves (progression §2): the GEAR half (OR across offered loops — never a blind max(EHT,EFT))
-- and the MILESTONE half (conquer the prerequisite Destination(s); the gate.milestoneTargets name HOW).
function M.evaluateGate(profile: PlayerData, destination: Destination, config: Config): GateResult
	local reasons: { string } = {}
	local gate = destination.gate

	-- ── Gear half: required_tier is met if EHT ≥ N on ANY offered loop OR EFT ≥ N on any offered loop.
	if gate.requiredTier > 0 then
		local met = false
		for _, loop in destination.offeredLoops do
			if EffectiveTier.effectiveTier(profile, config, loop) >= gate.requiredTier then
				met = true
				break
			end
		end
		if not met then
			local paths: { string } = {}
			for _, loop in destination.offeredLoops do
				local slots = weakSlots(profile, config, loop, gate.requiredTier)
				if #slots > 0 then
					table.insert(paths, table.concat(slots, " + ") .. " (" .. loop .. ")")
				end
			end
			table.insert(
				reasons,
				string.format("Reach Tier-%d gear — upgrade %s", gate.requiredTier, table.concat(paths, " OR "))
			)
		end
	end

	-- ── Milestone half: every prerequisite Destination must be CONQUERED (⊆ conqueredDestinations).
	-- The gate.milestoneTargets that live in each unmet prerequisite supply the actionable nouns:
	-- conquering a Destination IS taking one of its designated targets on an offered loop (unified conquest).
	for _, prereq in gate.prerequisiteDestinations do
		if not profile.conqueredDestinations[prereq] then
			local prereqDst = config.destinations[prereq]
			local prereqName = prereqDst ~= nil and prereqDst.name or prereq
			local how: { string } = {}
			for _, targetId in gate.milestoneTargets do
				local entry = config.targetIndex[targetId]
				if entry ~= nil and entry.destinationId == prereq and offers(destination, entry.loop) then
					table.insert(how, takeVerb(entry.loop) .. " the " .. targetName(config, targetId))
				end
			end
			if #how > 0 then
				table.insert(reasons, string.format("Conquer %s — %s", prereqName, table.concat(how, " or ")))
			else
				table.insert(reasons, string.format("Conquer %s", prereqName))
			end
		end
	end

	return { unlocked = #reasons == 0, unmetReasons = reasons }
end

return M
