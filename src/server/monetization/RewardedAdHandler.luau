--!strict
-- THE REWARDED-AD FAUCET (Step 14 §F) as a server-authoritative Gauntlet handler. An OPT-IN, BOUNDED Cash
-- reward for watching an ad: a small fraction of current-tier income, hard-capped at an absolute ceiling
-- (Monetization.adReward), `ad`-tagged + loop="none" (separable; reconciliation untouched), and frequency-
-- bounded by a server-time cooldown entitlement. NEVER required, NEVER a gate, NEVER advances a milestone
-- (it writes Cash only — the conquest set is untouched, the pay-proof property).
--
-- The ad-SDK call + the completion ATTESTATION are Studio (the rewarded-ad SDK fires this intent only after a
-- verified completion); the headless half is the bounded, tagged, cooldown-capped injection — that is what
-- this handler owns. Mirrors EventRewardHandler (the thin faucet shape): server time owns the cap, offline
-- counts, a reconnect cannot bypass the cooldown.

local Schema = require("@src/types/Schema")
local EffectiveTier = require("@src/logic/EffectiveTier")
local Monetization = require("@src/logic/Monetization")
local Ledger = require("@src/server/ledger/Ledger")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx
type PlayerData = Schema.PlayerData
type Config = Schema.Config

local M = {}

export type RewardedAdDeps = { idGen: Types.IdGenerator, telemetry: Types.Telemetry? }

local COOLDOWN_KIND = "adReward:cooldown"

-- T_current = max(EHT, EFT) — the same basis the daily/event faucets use; the ad reward scales off the tier
-- the player actually plays (capped absolutely, so it is never a low-tier-farming vector).
local function currentTier(profile: PlayerData, config: Config): number
	return math.max(EffectiveTier.effectiveHuntingTier(profile, config), EffectiveTier.effectiveFishingTier(profile, config))
end

function M.new(deps: RewardedAdDeps): Gauntlet.IntentHandler
	return {
		intent = "claimAdReward",
		critical = true, -- the faucet credit + the cooldown entitlement commit atomically (write-through)

		authority = function(ctx: Ctx): (boolean, string?)
			-- the frequency cap: an active cooldown entitlement blocks a re-claim (server-time-validated; offline
			-- counts, so a reconnect cannot reset it). The ad-completion attestation itself is Studio (SDK).
			for _, ent in ctx.profile.activeEntitlements do
				if ent.kind == COOLDOWN_KIND and ctx.now < ent.expiryTimestamp then
					return false, "ad_cooldown"
				end
			end
			return true, nil
		end,

		commit = function(ctx: Ctx)
			local tier = currentTier(ctx.profile, ctx.config)
			local amount = Monetization.adReward(ctx.config, tier) -- bounded: ≤ absoluteCap, never a gate
			if amount > 0 then
				Ledger.applyEntry(ctx.profile.cash, {
					type = "ad", -- the opt-in ad-faucet tag (separable; loop="none" keeps the routine-hour reconciliation clean)
					amount = amount,
					tier = tier,
					loop = "none",
					validatingEventId = deps.idGen.next("ad"), -- a server-minted unique id per claim
				}, ctx.now)
			end
			-- prune expired entitlements (keeps the active boost/VIP; drops stale markers), then set the cooldown.
			local kept: { Schema.Entitlement } = {}
			for _, ent in ctx.profile.activeEntitlements do
				if ctx.now < ent.expiryTimestamp then
					table.insert(kept, ent)
				end
			end
			table.insert(kept, { kind = COOLDOWN_KIND, expiryTimestamp = ctx.now + ctx.config.tuning.monetization.adReward.cooldownSeconds })
			ctx.profile.activeEntitlements = kept
			-- NOTE: no Progression.commitUnlocks, no conqueredDestinations write — an ad NEVER advances a milestone.
			if deps.telemetry ~= nil then
				deps.telemetry.incr("monetization.adReward", 1)
			end
		end,
	}
end

return M
