--!strict
-- THE DAILY-QUEST CLAIM (Step 7 skeleton) as a server-authoritative Gauntlet handler. Claiming the
-- cross-loop pair (one hunt + one catch this window) credits the daily faucet + the breadth bonus through
-- the idempotent ledger and completes the DAILY_INTRO funnel beat — the "come back tomorrow" handoff. The
-- amounts are economy's (scaled off T_current = max(EHT, EFT)); the daily window resets off the server clock.
-- `critical` → the credit + the claim flag + the beat advance commit atomically. Content/rotation is Step 13.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Economy = require("@src/logic/Economy")
local Daily = require("@src/logic/Daily")
local Onboarding = require("@src/logic/Onboarding")
local Ledger = require("@src/server/ledger/Ledger")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx

local M = {}

export type ClaimDeps = { telemetry: Types.Telemetry? }

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
			local basis = tostring(ctx.profile.daily.resetBasis)
			-- Step 15 (the T_current resolution): the cross-loop pair pays each loop's daily at THAT LOOP's
			-- effective tier (Economy.currentTier per-loop) — a hunting daily at EHT, a fishing daily at EFT. A
			-- maxed hunter's fishing daily therefore pays EFT-tier Cash, NOT max-tier (the low-tier-farming vector
			-- a single max-based basis would open is closed). The breadth bonus is the loop-AGNOSTIC kicker →
			-- max(EHT,EFT). All three are server-validated atomic ledger entries.
			local huntTier = Economy.currentTier(ctx.profile, ctx.config, Enums.Loop.Hunting)
			local fishTier = Economy.currentTier(ctx.profile, ctx.config, Enums.Loop.Fishing)
			Ledger.applyEntry(ctx.profile.cash, {
				type = "dailyQuest",
				amount = Economy.dailyQuestReward(ctx.config, huntTier),
				tier = huntTier,
				loop = "none",
				validatingEventId = "dailyQuest:Hunting:" .. basis,
			}, ctx.now)
			Ledger.applyEntry(ctx.profile.cash, {
				type = "dailyQuest",
				amount = Economy.dailyQuestReward(ctx.config, fishTier),
				tier = fishTier,
				loop = "none",
				validatingEventId = "dailyQuest:Fishing:" .. basis,
			}, ctx.now)
			local breadthTier = Economy.currentTier(ctx.profile, ctx.config) -- loop-agnostic peak (max EHT/EFT)
			Ledger.applyEntry(ctx.profile.cash, {
				type = "crossLoopBonus",
				amount = Economy.crossLoopBonus(ctx.config, breadthTier),
				tier = breadthTier,
				loop = "none",
				validatingEventId = "crossLoopBonus:" .. basis,
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
