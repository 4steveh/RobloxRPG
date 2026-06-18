--!strict
-- Step 13 — the event participation-reward handler (§D): a budget-capped, validated, atomic, EVENT-FAUCET-
-- tagged ledger entry, idempotent per window via a SERVER-TIME entitlement (offline counts; logging off
-- banks nothing). Reuses the Ledger/Economy substrate wholesale — no event-specific Cash path.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Gauntlet = require("@src/server/authority/Gauntlet")
local EventRewardHandler = require("@src/server/liveops/EventRewardHandler")

return function(t: Harness.T)
	local wf = Catalog.liveOps.events.winter_freeze
	local inWindow = math.floor((wf.startTime + wf.endTime) / 2)
	local outWindow = wf.endTime + 1000000

	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, EventRewardHandler.new({ telemetry = Fakes.newTelemetry() }))
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
		return Gauntlet.handle(newReg(), { intent = "claimEventReward", playerId = 1, payload = { eventId = "winter_freeze" } }, { playerId = 1, profile = p, live = true }, deps(now))
	end

	t.section("EventRewardHandler — budget-capped, event-faucet-tagged, atomic ledger entry")
	do
		local p = Util.mkProfile(Catalog, { rod = 4, reel = 4 }) -- T4 → the tier the payout scales off
		local r = claim(p, inWindow)
		t.ok("a claim while the event is live succeeds", r.ok)
		t.eq("exactly one ledger entry", #p.cash.tail, 1)
		t.eq("tagged as the event faucet (separable in telemetry)", p.cash.tail[1].type, "eventReward")
		t.eq("loop=none — does NOT disturb the routine-hour reconciliation", p.cash.tail[1].loop, "none")
		t.ok("the payout is within the declared per-event budget", p.cash.tail[1].amount > 0 and p.cash.tail[1].amount <= wf.cashBudget)
		t.ok("a window-bounded entitlement is granted", #p.activeEntitlements >= 1)
	end

	t.section("EventRewardHandler — idempotent per window (server-time entitlement; offline counts)")
	do
		local p = Util.mkProfile(Catalog, { rod = 4, reel = 4 })
		t.ok("first claim succeeds", claim(p, inWindow).ok)
		t.ok("a second claim in the SAME window is rejected", claim(p, inWindow + 5000).ok == false)
		t.eq("…still exactly one ledger entry (no double-credit)", #p.cash.tail, 1)
		t.ok("re-claim stays blocked right up to the window's end (server-time, not client elapsed)", claim(p, wf.endTime - 1).ok == false)
		-- the inclusive-window BOUNDARY: the event is live at now==endTime, so the claim marker must also block
		-- there (else the exclusive `now < expiry` check lets an unbounded re-claim drain the faucet at endTime).
		t.ok("re-claim blocked at EXACTLY endTime (inclusive boundary)", claim(p, wf.endTime).ok == false)
		t.eq("…still exactly one ledger entry at the boundary", #p.cash.tail, 1)
		-- and on a fresh profile, the FIRST claim at endTime must self-block any second claim at endTime.
		local q = Util.mkProfile(Catalog, { rod = 4, reel = 4 })
		t.ok("first claim at endTime succeeds", claim(q, wf.endTime).ok)
		t.ok("a second claim at endTime is rejected (no unbounded boundary drain)", claim(q, wf.endTime).ok == false)
		t.eq("…exactly one entry at the boundary", #q.cash.tail, 1)
	end

	t.section("EventRewardHandler — server-authoritative window: an inactive event pays nothing")
	do
		local p = Util.mkProfile(Catalog, { rod = 4, reel = 4 })
		local r = claim(p, outWindow)
		t.ok("a claim outside the window is rejected", r.ok == false)
		t.eq("no event faucet is written", #p.cash.tail, 0)
		local rUnknown = Gauntlet.handle(newReg(), { intent = "claimEventReward", playerId = 1, payload = { eventId = "no_such_event" } }, { playerId = 1, profile = p, live = true }, deps(inWindow))
		t.ok("an unknown event id is rejected", rUnknown.ok == false)
	end

	t.section("Event rares deliver scarce value, not Cash (RD2)")
	do
		-- The event-exclusive burbot mints an artifact (no Cash leg) — the bulk of event value never touches
		-- the faucet (the full no-Cash catch is proven end-to-end in CatchHandler.spec).
		t.eq("the event-exclusive rare is an artifact mint (no Cash at mint)", Catalog.fish.alaska_burbot.reward.kind, "artifact")
	end
end
