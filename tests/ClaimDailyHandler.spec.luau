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
		-- Step 15: the pair pays the hunting daily @EHT + the fishing daily @EFT + the breadth bonus @max.
		-- At EHT=EFT=1 that is dailyQuestReward(1) + dailyQuestReward(1) + crossLoopBonus(1).
		local expected = 2 * Economy.dailyQuestReward(Catalog, 1) + Economy.crossLoopBonus(Catalog, 1)
		t.eq("per-loop dailies + cross-loop bonus credited", Ledger.balanceOf(p.cash), expected)
		t.ok("marked claimed", p.daily.claimed == true)
		t.eq("the funnel handed off and COMPLETED", p.onboarding.funnelBeat, "COMPLETE")
		local r2 = claim(p, true)
		t.ok("a second claim the same day is rejected (idempotent per window)", r2.ok == false)
		t.eq("balance unchanged on the rejected re-claim", Ledger.balanceOf(p.cash), expected)
	end

	t.section("ClaimDaily — the T_current resolution: a maxed hunter's FISHING daily pays EFT-tier, not max")
	do
		-- EHT 4 (weapon+armor T4), EFT 1 (rod+reel T1): the per-loop basis closes the low-tier-farming vector —
		-- the fishing daily must pay dailyQuestReward(EFT=1), NOT dailyQuestReward(max=4).
		local p = Util.mkProfile(Catalog, { weapon = 4, armor = 4, rod = 1, reel = 1 })
		p.daily.huntDone = true
		p.daily.fishDone = true
		t.ok("the claim succeeds", claim(p, true).ok)
		local huntAmt, fishAmt = 0, 0
		for _, e in p.cash.tail do
			if string.find(e.validatingEventId, "dailyQuest:Hunting", 1, true) then
				huntAmt = e.amount
			elseif string.find(e.validatingEventId, "dailyQuest:Fishing", 1, true) then
				fishAmt = e.amount
			end
		end
		t.eq("the hunting daily pays EHT-tier (4)", huntAmt, Economy.dailyQuestReward(Catalog, 4))
		t.eq("the FISHING daily pays EFT-tier (1), NOT max-tier (the farming-vector closure)", fishAmt, Economy.dailyQuestReward(Catalog, 1))
		t.ok("EFT-tier ≠ max-tier here (the vector would otherwise be open)", Economy.dailyQuestReward(Catalog, 1) ~= Economy.dailyQuestReward(Catalog, 4))
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
