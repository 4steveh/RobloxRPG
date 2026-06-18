--!strict
-- Step 14 §F — the rewarded-ad faucet handler: a bounded, opt-in, `ad`-tagged (loop=none) Cash reward,
-- frequency-bounded by a server-time cooldown entitlement, that NEVER advances a milestone. The ad-SDK
-- completion attestation is Studio; this is the headless bounded/capped/tagged injection.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Monetization = require("@src/logic/Monetization")
local RewardedAdHandler = require("@src/server/monetization/RewardedAdHandler")

return function(t: Harness.T)
	local AD = Catalog.tuning.monetization.adReward

	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, RewardedAdHandler.new({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
		return reg
	end
	local function deps(now: number): Gauntlet.Deps
		return {
			config = Catalog,
			now = now,
			saveFn = function()
				return true
			end,
			markDirty = function() end,
			telemetry = Fakes.newTelemetry(),
		}
	end
	local function claim(p: any, now: number): Gauntlet.HandleResult
		return Gauntlet.handle(newReg(), { intent = "claimAdReward", playerId = 1, payload = {} }, { playerId = 1, profile = p, live = true }, deps(now))
	end

	t.section("§F a rewarded-ad claim pays a bounded, ad-tagged, loop=none faucet")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1 }) -- T1 → the reward scales off Income(1)
		local r = claim(p, 1000)
		t.ok("the claim succeeds", r.ok)
		t.eq("exactly one ledger entry", #p.cash.tail, 1)
		t.ok("tagged 'ad', loop=none (separable; the routine-hour reconciliation is untouched)", p.cash.tail[1].type == "ad" and p.cash.tail[1].loop == "none")
		t.ok("the amount is the bounded reward (≤ absoluteCap)", p.cash.tail[1].amount == Monetization.adReward(Catalog, 1) and p.cash.tail[1].amount <= AD.absoluteCap)
		t.ok("the milestone/conquest set is untouched (an ad never advances a gate)", next(p.conqueredDestinations) == nil)
	end

	t.section("§F frequency-bounded by a server-time cooldown (opt-in, never spammed)")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1 })
		t.ok("first claim succeeds", claim(p, 0).ok)
		t.ok("a second claim within the cooldown is rejected", claim(p, AD.cooldownSeconds - 1).ok == false)
		t.eq("…no second faucet (bounded)", #p.cash.tail, 1)
		t.ok("after the cooldown elapses, a new claim succeeds (server time; offline counts)", claim(p, AD.cooldownSeconds + 1).ok)
		t.eq("…now two faucets", #p.cash.tail, 2)
	end
end
