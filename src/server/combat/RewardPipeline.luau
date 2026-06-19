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

local Schema = require("../../types/Schema")
local Enums = require("../../types/Enums")
local Combat = require("../../logic/Combat")
local Fishing = require("../../logic/Fishing")
local Economy = require("../../logic/Economy")
local Monetization = require("../../logic/Monetization")
local Ledger = require("../ledger/Ledger")
local ArtifactStore = require("../artifacts/ArtifactStore")
local Types = require("../persistence/Types")

type PlayerData = Schema.PlayerData
type Config = Schema.Config

local M = {}

-- The economy Payout (Step 6): the real, server-authoritative Cash a routine kill/catch pays. Takes the
-- target's destinationId (the routine-band normalization needs it) + tier + rarity + loop. Defaults to
-- Economy.payout; injectable for tests. (Rares mint — they never call this; the XOR holds.)
export type PayoutFn = (config: Config, tier: number, rarity: string, destinationId: string, loop: Enums.Loop) -> number

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
	traits: { Enums.Trait }?, -- NEW: server-rolled weather traits (nil/empty = base catch). Routine only.
}
export type Result = {
	ambiance: boolean,
	cash: number, -- total Cash granted = base routine payout + the §14 boost bonus (0 for a rare mint)
	boostCash: number, -- Step 14: the 2x/VIP active-income bonus portion of `cash` (0 = no active multiplier)
	traitCash: number, -- Step weather/traits: the weather-trait bonus portion of `cash` (0 = no trait rolled)
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
		{ ambiance = false, cash = 0, boostCash = 0, traitCash = 0, mintedArtifactId = nil, rankXP = 0, conquestNewlySet = false, cleanKillMoment = nil }

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
		local payoutFn = deps.payoutFn or Economy.payout
		local amount = payoutFn(config, d.tier, d.rarity, d.destinationId, event.loop)
		Ledger.applyEntry(profile.cash, {
			type = d.ledgerType,
			amount = amount, -- the UNMULTIPLIED routine faucet (so the dual-loop reconciliation, which reads the formula, is untouched)
			tier = d.tier,
			loop = event.loop,
			validatingEventId = event.validatingEventId,
		}, deps.now)
		result.cash = amount
		incr(deps, "combat.payout:tier" .. tostring(d.tier))

		-- Step 14 (SYS_economy §7): the 2x/VIP active-income multiplier applies HERE — at the active kill/catch
		-- GRANT, downstream of payoutFn — and NOWHERE else. The base faucet above stays the routine payout, so
		-- idle/daily/salvage (which read Economy.income, never this path) and the milestone (set below, not Cash)
		-- are NEVER multiplied. The boost is a SEPARATE, real-money-tagged, loop="none" entry → separable +
		-- bounded in telemetry (§7), and the routine-hour reconciliation is left intact. Rares mint in the IF
		-- branch above (no Cash) so the multiplier can never apply to a milestone artifact.
		local multiplier = Monetization.activeCashMultiplier(config, profile, deps.now)
		local bonus = Monetization.boostBonus(amount, multiplier)
		if bonus > 0 then
			Ledger.applyEntry(profile.cash, {
				type = "boostBonus", -- the real-money multiplier faucet subtype (separable; loop=none keeps reconciliation clean)
				amount = bonus,
				tier = d.tier,
				loop = "none",
				validatingEventId = event.validatingEventId .. ":boost",
				realMoneyTag = "realmoney:boost", -- §7 metered-separately tag (boost-active income is separable)
			}, deps.now)
			result.cash += bonus
			result.boostCash = bonus
			incr(deps, "monetization.boostFaucet")
		end
			-- WEATHER TRAIT bonus (the GH stackable-mutation analogue). Cash branch ONLY, OUTSIDE the normalized band
			-- (avgRoutineMultiplier never self-cancels it), as its own loop="none" tagged entry — the SAME separable
			-- pattern as the 2x/VIP boost, so the routine-hour reconciliation is left intact. Rares mint in the IF
			-- branch (no Cash) so a trait can never touch an artifact.
			local traits = event.traits
			if traits ~= nil and #traits > 0 then
				local traitBonus = Monetization.boostBonus(amount, Economy.traitStackMultiplier(config, traits :: { string }))
				if traitBonus > 0 then
					Ledger.applyEntry(profile.cash, {
						type = "traitBonus", -- the weather-trait faucet subtype (separable; loop=none -> reconciliation clean)
						amount = traitBonus,
						tier = d.tier,
						loop = "none",
						validatingEventId = event.validatingEventId .. ":trait",
					}, deps.now)
					result.cash += traitBonus
					result.traitCash = traitBonus
					incr(deps, "liveops.traitFaucet")
				end
			end
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
