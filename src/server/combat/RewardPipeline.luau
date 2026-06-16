--!strict
-- THE SHARED REWARD PIPELINE (SYS_combat §build-notes, ordered) — the Step-2 substrate's first real
-- caller. On a validated kill/catch it runs, IN ORDER: ambiance check (early-return zero) → the Reward XOR
-- (routine → economy Payout via Ledger.applyEntry; rare → ArtifactStore.mint, no Cash) → Hunter/Angler
-- Rank XP (active-play, difficulty/rarity weighted) → idempotent conquest → the rare clean-kill moment hook.
--
-- LOOP-AGNOSTIC: the ONLY loop-specific code is the `describe` descriptor (which catalog, which Rank field,
-- the ledger type). The XOR / mint / ledger / conquest path below is SHARED so the two loops can never
-- diverge (the integrity model forbids duplicating it). Step 5 (fishing) adds only the Fishing branch of
-- `describe`. The CALLER wraps resolve() in a Transaction (the FireHandler does) so it commits atomically.
--
-- The Cash AMOUNT is economy's Payout (Step 6) — taken from a pluggable PayoutFn, stubbed here exactly as
-- Idle stubs its amount. We do NOT read the catalog's illustrative cash:{min,max}.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Combat = require("@src/logic/Combat")
local Fishing = require("@src/logic/Fishing")
local Ledger = require("@src/server/ledger/Ledger")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local Types = require("@src/server/persistence/Types")

type PlayerData = Schema.PlayerData
type Config = Schema.Config

local M = {}

export type PayoutFn = (config: Config, tier: number, rarity: string, loop: string) -> number

-- STUB economy Payout — a positive amount so the atomic commit is exercised; Step 6 swaps in the real
-- Payout(T, rarity, loop) = Income(T)/ExpectedTargetsPerHour × RarityMultiplier. Modeled on Idle.stubAmount.
function M.stubPayout(config: Config, _tier: number, rarity: string, _loop: string): number
	local rarityMult = (config.tuning.economy.rarityMultiplier :: { [string]: number })[rarity] or 1
	return math.floor(12.5 * rarityMult + 0.5) -- illustrative baseline ≈ Income(1)/ETPH(1); TODO(step-6)
end

export type PipelineDeps = {
	idGen: Types.IdGenerator,
	now: number,
	payoutFn: PayoutFn?,
	telemetry: Types.Telemetry?,
}
export type KillEvent = {
	targetId: string,
	owner: string,
	validatingEventId: string,
	loop: Enums.Loop, -- "Hunting" | "Fishing"
	partySize: number?,
}
export type Result = {
	ambiance: boolean,
	cash: number,
	mintedArtifactId: string?,
	rankXP: number,
	conquestNewlySet: boolean,
	cleanKillMoment: string?,
}

local function incr(deps: PipelineDeps, metric: string)
	if deps.telemetry ~= nil then
		deps.telemetry.incr(metric, 1)
	end
end

-- The loop-agnostic reward descriptor — the ONLY loop branch. Everything downstream is shared.
type Descriptor = {
	ambiance: boolean,
	rarity: Enums.Rarity,
	tier: number,
	isMilestone: boolean,
	destinationId: string,
	reward: Schema.Reward?,
	rare: Schema.RareFields?,
	rankXP: number,
	rankField: string, -- "hunterRankXP" | "anglerRankXP"
	ledgerType: string, -- "kill" | "catch"
}

local function describe(config: Config, event: KillEvent): Descriptor
	if event.loop == Enums.Loop.Hunting then
		local c = assert(config.creatures[event.targetId], "RewardPipeline: unknown creature '" .. event.targetId .. "'")
		return {
			ambiance = c.ambianceOnly,
			rarity = c.rarity,
			tier = c.tier,
			isMilestone = c.isMilestoneTarget == true,
			destinationId = c.destinationId,
			reward = c.reward,
			rare = c.rare,
			rankXP = Combat.rankXP(config, c),
			rankField = "hunterRankXP",
			ledgerType = "kill",
		}
	end
	-- Fishing (Step 5): the ONLY loop-specific addition — config.fish, Angler Rank XP (fish have no
	-- archetype → Fishing.anglerRankXP, not Combat.rankXP), ledgerType "catch". No MVL fish are ambiance.
	-- Everything downstream (the Reward XOR / mint / ledger / conquest) is the SHARED path below.
	local f = assert(config.fish[event.targetId], "RewardPipeline: unknown fish '" .. event.targetId .. "'")
	return {
		ambiance = false,
		rarity = f.rarity,
		tier = f.tier,
		isMilestone = f.isMilestoneTarget == true,
		destinationId = f.destinationId,
		reward = f.reward,
		rare = f.rare,
		rankXP = Fishing.anglerRankXP(config, f),
		rankField = "anglerRankXP",
		ledgerType = "catch",
	}
end

-- resolve — the ordered pipeline. MUST be called inside a Transaction by the caller (FireHandler does) so
-- ledger + XP + mint + conquest land together or not at all.
function M.resolve(profile: PlayerData, config: Config, event: KillEvent, deps: PipelineDeps): Result
	local d = describe(config, event)
	local result: Result =
		{ ambiance = false, cash = 0, mintedArtifactId = nil, rankXP = 0, conquestNewlySet = false, cleanKillMoment = nil }

	-- 1. Ambiance FIRST — an ambiance creature can never be a faucet, milestone, or Rank-XP exploit.
	if d.ambiance then
		incr(deps, "combat.ambiance_zero")
		result.ambiance = true
		return result -- no Cash, no Rank XP, no drop, no conquest (indifference, not a penalty)
	end

	-- 2. Reward XOR (integrity-critical: Cash OR artifact, never both, never neither-counted).
	local reward = assert(d.reward, "RewardPipeline: a non-ambiance target must carry a reward")
	if reward.kind == "artifact" then
		local art = ArtifactStore.mint(profile, {
			kind = Enums.ArtifactKind.trophy, -- a kill/catch rare is always a trophy artifact
			tradeable = reward.artifact.tradeable,
			owner = event.owner,
			sourceId = event.targetId,
			validatingEventId = event.validatingEventId,
		}, deps.idGen, deps.now)
		result.mintedArtifactId = art.artifactId
		incr(deps, "combat.mint")
		if d.rare ~= nil then
			result.cleanKillMoment = d.rare.intendedContentMoment -- the flourish itself is Studio feel
			incr(deps, "combat.clean_kill_moment")
		end
	else
		local payoutFn = deps.payoutFn or M.stubPayout
		local amount = payoutFn(config, d.tier, d.rarity, event.loop)
		Ledger.applyEntry(profile.cash, {
			type = d.ledgerType,
			amount = amount,
			tier = d.tier,
			loop = event.loop,
			validatingEventId = event.validatingEventId,
		}, deps.now)
		result.cash = amount
		incr(deps, "combat.payout:tier" .. tostring(d.tier))
	end

	-- 3. Hunter/Angler Rank XP — active-play only (idle never calls this). Difficulty/rarity weighted.
	local profileAny = profile :: any
	profileAny[d.rankField] += d.rankXP
	result.rankXP = d.rankXP

	-- 4. Conquest — idempotent set membership; a legal milestone for the current Destination only.
	if d.isMilestone and not profile.conqueredDestinations[d.destinationId] then
		profile.conqueredDestinations[d.destinationId] = true
		result.conquestNewlySet = true
		incr(deps, "combat.conquest:" .. d.destinationId)
	end

	incr(deps, "combat.reward_resolved")
	return result
end

return M
