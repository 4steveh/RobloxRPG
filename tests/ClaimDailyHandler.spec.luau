--!strict
-- Step 7 — the daily-quest claim as a server-authoritative gauntlet handler: claiming the cross-loop pair
-- credits the daily faucet + the breadth bonus once (idempotent per day) and completes the DAILY_INTRO beat.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Economy = require("@src/logic/Economy")
local Ledger = require("@src/server/ledger/Ledger")
local Gauntlet = require("@src/server/authority/Gauntlet")
local ClaimDailyHandler = require("@src/server/daily/ClaimDailyHandler")

return function(t: Harness.T)
	local function reg(): Gauntlet.Registry
		local r = Gauntlet.new()
		Gauntlet.register(r, ClaimDailyHandler.new({ telemetry = Fakes.newTelemetry() }))
		return r
	end
	local function deps(saveOk: boolean): Gauntlet.Deps
		return {
			config = Catalog,
			now = 100,
			saveFn = function()
				return saveOk
			end,
			markDirty = function() end,
			telemetry = Fakes.newTelemetry(),
		}
	end
	local function claim(p: any, saveOk: boolean): Gauntlet.HandleResult
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		return Gauntlet.handle(reg(), { intent = "claimDaily", playerId = 1, payload = {} }, session, deps(saveOk))
	end

	t.section("ClaimDaily — the cross-loop pair pays both faucets ONCE + completes the funnel (DAILY_INTRO→COMPLETE)")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1 }) -- EHT 1 / EFT 1 → T_current 1
		p.daily.huntDone = true
		p.daily.fishDone = true
		p.onboarding.funnelBeat = "DAILY_INTRO"
		local r = claim(p, true)
		t.ok("the claim succeeds", r.ok)
		local expected = Economy.dailyQuestReward(Catalog, 1) + Economy.crossLoopBonus(Catalog, 1) -- 250 + 500
		t.eq("both faucets credited (daily faucet + cross-loop bonus)", Ledger.balanceOf(p.cash), expected)
		t.ok("marked claimed", p.daily.claimed == true)
		t.eq("the funnel handed off and COMPLETED", p.onboarding.funnelBeat, "COMPLETE")
		local r2 = claim(p, true)
		t.ok("a second claim the same day is rejected (idempotent per window)", r2.ok == false)
		t.eq("balance unchanged on the rejected re-claim", Ledger.balanceOf(p.cash), expected)
	end

	t.section("ClaimDaily — rejects when a loop objective is missing (breadth required, never penalized)")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1 })
		p.daily.huntDone = true -- only hunted today; no catch
		local r = claim(p, true)
		t.ok("cannot claim the cross-loop pair with only one loop done", r.ok == false)
		t.eq("no Cash credited", Ledger.balanceOf(p.cash), 0)
	end

	t.section("ClaimDaily — atomic: a failed write-through reverts the credit + the claim flag")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1 })
		p.daily.huntDone = true
		p.daily.fishDone = true
		p.onboarding.funnelBeat = "DAILY_INTRO"
		local r = claim(p, false)
		t.ok("persist_failed", r.ok == false and r.reason == "persist_failed")
		t.eq("no orphan Cash", Ledger.balanceOf(p.cash), 0)
		t.ok("claim flag reverted; funnel did not complete", p.daily.claimed == false and p.onboarding.funnelBeat == "DAILY_INTRO")
	end
end
