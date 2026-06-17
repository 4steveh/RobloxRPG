--!strict
-- THE DAILY-QUEST CLAIM (Step 7 skeleton) as a server-authoritative Gauntlet handler. Claiming the
-- cross-loop pair (one hunt + one catch this window) credits the daily faucet + the breadth bonus through
-- the idempotent ledger and completes the DAILY_INTRO funnel beat — the "come back tomorrow" handoff. The
-- amounts are economy's (scaled off T_current = max(EHT, EFT)); the daily window resets off the server clock.
-- `critical` → the credit + the claim flag + the beat advance commit atomically. Content/rotation is Step 13.

local Schema = require("@src/types/Schema")
local Economy = require("@src/logic/Economy")
local Daily = require("@src/logic/Daily")
local Onboarding = require("@src/logic/Onboarding")
local EffectiveTier = require("@src/logic/EffectiveTier")
local Ledger = require("@src/server/ledger/Ledger")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx
type PlayerData = Schema.PlayerData
type Config = Schema.Config

local M = {}

export type ClaimDeps = { telemetry: Types.Telemetry? }

-- T_current = max(EHT, EFT) — the idle resolution; the daily amounts scale off the tier the player can play.
local function currentTier(profile: PlayerData, config: Config): number
	return math.max(EffectiveTier.effectiveHuntingTier(profile, config), EffectiveTier.effectiveFishingTier(profile, config))
end

function M.new(deps: ClaimDeps): Gauntlet.IntentHandler
	return {
		intent = "claimDaily",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			Daily.maybeReset(ctx.profile.daily, ctx.now) -- roll the window off the SERVER clock first
			if not Daily.canClaimCrossLoop(ctx.profile.daily) then
				return false, "nothing_to_claim" -- needs both loops this window, and not already claimed
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local tier = currentTier(ctx.profile, ctx.config)
			-- the daily faucet + the cross-loop breadth bonus, both server-validated atomic ledger entries
			Ledger.applyEntry(ctx.profile.cash, {
				type = "dailyQuest",
				amount = Economy.dailyQuestReward(ctx.config, tier),
				tier = tier,
				loop = "none",
				validatingEventId = "dailyQuest:" .. tostring(ctx.profile.daily.resetBasis),
			}, ctx.now)
			Ledger.applyEntry(ctx.profile.cash, {
				type = "crossLoopBonus",
				amount = Economy.crossLoopBonus(ctx.config, tier),
				tier = tier,
				loop = "none",
				validatingEventId = "crossLoopBonus:" .. tostring(ctx.profile.daily.resetBasis),
			}, ctx.now)
			ctx.profile.daily.claimed = true -- idempotent per window (re-claim rejected at authority)
			Onboarding.advance(ctx.profile, "dailyClaim", ctx.now) -- completes DAILY_INTRO → COMPLETE
			if deps.telemetry ~= nil then
				deps.telemetry.incr("daily.claim", 1)
			end
		end,
	}
end

return M
