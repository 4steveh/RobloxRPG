--!strict
-- Step 15 — the measurement layer. The typed event TAXONOMY (categoryOf is total over the inherited hooks +
-- the new events), the RETENTION classification (pinned rolling-24h windows from firstSeenAt) + the
-- SessionService substrate, the FUNNEL drop-off, the MEASURED per-loop balance (realized ÷ realized, with
-- TEETH — not the by-construction tautology), the consolidated CANARY layer, MEASUREMENT INTEGRITY (a client
-- count cannot move a metric), and the NO-PII privacy guarantee.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Enums = require("@src/types/Enums")
local Analytics = require("@src/logic/Analytics")
local Fakes = require("@src/server/persistence/Fakes")
local RewardPipeline = require("@src/server/combat/RewardPipeline")
local SessionService = require("@src/server/SessionService")

local function approx(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

-- a synthetic ledger from {type, amount, loop} rows (the realized-grant shape realizedLoopCash reads).
local function ledgerWith(rows: { { type: string, amount: number, loop: string } }): any
	local tail = {}
	for i, e in rows do
		table.insert(tail, { entryId = i, type = e.type, amount = e.amount, loop = e.loop, timestamp = i, validatingEventId = "t" .. i })
	end
	return { checkpoint = { balance = 0, compactedCount = 0, lastEntryId = #tail }, tail = tail }
end

return function(t: Harness.T)
	local WIN = Catalog.tuning.analytics.retentionWindowSeconds
	local C = Analytics.Category

	t.section("§A taxonomy — categoryOf is TOTAL over every emitted metric (no orphan escapes the taxonomy)")
	do
		local known = {
			"session.login_ok", "session.start", "session.end", "session.retention:d1",
			"combat.payout:tier1", "combat.conquest:bayou", "combat.mint", "combat.rare_spawned:x", "fishing.coastalCatch",
			"economy.buy:tier2", "economy.upgrade:tier2", "economy.evergreenSink:decor", "daily.claim",
			"liveops.eventParticipation", "liveops.eventFaucet:winter_freeze", "lodge.salvage:Rare",
			"monetization.purchase:pack_cash_small", "monetization.boostFaucet", "monetization.adReward",
			"trade.swap_precondition_failed", "gauntlet.persist_failed", "gauntlet.rejected_authority", "save.ok",
			"funnel.beat_reached:FIRST_HUNT", "funnel.beat_dwell:FIRST_HUNT", "funnel.beat_abandoned:FIRST_HUNT",
			"travel.fast_travel:alaska",
		}
		local allMapped = true
		for _, name in known do
			if Analytics.categoryOf(name) == nil then
				allMapped = false
			end
		end
		t.ok("every known emitted metric maps to a category (the consolidation guarantee)", allMapped)
		t.eq("combat.* → gameplay", Analytics.categoryOf("combat.payout:tier1"), C.gameplay)
		t.eq("economy.* → economy", Analytics.categoryOf("economy.buy:tier2"), C.economy)
		t.eq("monetization.* → monetization", Analytics.categoryOf("monetization.purchase:x"), C.monetization)
		t.eq("gauntlet.* → integrity", Analytics.categoryOf("gauntlet.persist_failed"), C.integrity)
		t.eq("funnel.* → funnel", Analytics.categoryOf("funnel.beat_abandoned:FIRST_HUNT"), C.funnel)
		t.eq("an unregistered metric maps to nothing (a taxonomy gap stays visible)", Analytics.categoryOf("bogus.thing"), nil)
	end

	t.section("§B retention — PINNED rolling-24h windows from firstSeenAt (server time, timezone-free)")
	do
		local first = 1000000
		t.eq("the install session is day 0", Analytics.retentionDay(Catalog, first, first), 0)
		t.eq("exactly 24h later is day 1 (window [N·24h,(N+1)·24h))", Analytics.retentionDay(Catalog, first, first + WIN), 1)
		t.eq("just before 24h is still day 0", Analytics.retentionDay(Catalog, first, first + WIN - 1), 0)
		t.eq("a session 25h later is day 1", Analytics.retentionDay(Catalog, first, first + WIN + 3600), 1)
		t.eq("7 days later is day 7", Analytics.retentionDay(Catalog, first, first + 7 * WIN), 7)
		t.ok("isRetainedOnDay matches the window (d7 yes, d6 no)", Analytics.isRetainedOnDay(Catalog, first, first + 7 * WIN, 7) and not Analytics.isRetainedOnDay(Catalog, first, first + 7 * WIN, 6))
		t.eq("a clock before firstSeenAt clamps to day 0 (no negative window)", Analytics.retentionDay(Catalog, first, first - 5000), 0)
	end

	t.section("§B retention substrate — SessionService stamps firstSeenAt ONCE + lastSeenAt every login")
	do
		local store = Fakes.newDataStore()
		local clockNow = 5000
		local svc = SessionService.new({
			store = store,
			clock = { now = function(): number
				return clockNow
			end },
			config = Catalog,
			serverId = "s1",
		})
		local r1 = SessionService.login(svc, 1)
		t.ok("first login ok", r1.ok)
		local prof = (r1.session :: any).profile
		t.eq("firstSeenAt stamped to now on the fresh profile", prof.firstSeenAt, 5000)
		t.eq("lastSeenAt = now", prof.lastSeenAt, 5000)
		SessionService.logout(svc, 1)
		clockNow = 5000 + WIN + 100 -- return a day later
		local r2 = SessionService.login(svc, 1)
		local prof2 = (r2.session :: any).profile
		t.eq("firstSeenAt PRESERVED across the return (the cohort anchor)", prof2.firstSeenAt, 5000)
		t.eq("lastSeenAt bumped to the return time", prof2.lastSeenAt, 5000 + WIN + 100)
		t.eq("the return classifies as a day-1 session (rolling window from firstSeenAt)", Analytics.retentionDay(Catalog, prof2.firstSeenAt, prof2.lastSeenAt), 1)
	end

	t.section("§C funnel drop-off — lastBeat / dwell / abandon from the beats + beatStartedAt")
	do
		local p = Util.mkProfile(Catalog, {})
		p.onboarding.funnelBeat = "FIRST_PURCHASE"
		p.onboarding.beatStartedAt = 1000
		local d = Analytics.funnelDropoff(p.onboarding, 1090)
		t.eq("lastBeat = the current beat", d.lastBeat, "FIRST_PURCHASE")
		t.eq("dwell = now − beatStartedAt", d.dwellSeconds, 90)
		t.ok("not COMPLETE → an abandon point", d.reachedComplete == false)
		t.ok("beatIndex orders the funnel (FIRST_HUNT < COMPLETE)", Analytics.beatIndex("FIRST_HUNT") < Analytics.beatIndex("COMPLETE"))
		-- session-end emits the abandon + dwell for a stalled funnel
		local tel = Fakes.newTelemetry()
		Analytics.recordSessionEnd(tel, p, 1090)
		local snap = tel.snapshot()
		t.eq("session.end emitted", snap["session.end"], 1)
		t.eq("the abandon is recorded against the stalled beat", snap["funnel.beat_abandoned:FIRST_PURCHASE"], 1)
		t.eq("the beat dwell is recorded (value = seconds)", snap["funnel.beat_dwell:FIRST_PURCHASE"], 90)
		-- a COMPLETE player emits NO abandon (they finished the funnel)
		local q = Util.mkProfile(Catalog, {})
		q.onboarding.funnelBeat = "COMPLETE"
		local tel2 = Fakes.newTelemetry()
		Analytics.recordSessionEnd(tel2, q, 100)
		t.eq("a COMPLETE player is NOT an abandon", tel2.snapshot()["funnel.beat_abandoned:COMPLETE"], nil)
	end

	t.section("§D the per-loop balance metric — REALIZED ÷ REALIZED (not the tautology), with TEETH")
	do
		local balanced = Analytics.realizedLoopCash(ledgerWith({
			{ type = "kill", amount = 300, loop = "Hunting" },
			{ type = "catch", amount = 300, loop = "Fishing" },
		}))
		t.eq("realized hunting Cash summed from the kill faucets", balanced.Hunting, 300)
		t.eq("realized fishing Cash summed from the catch faucets", balanced.Fishing, 300)
		-- balanced: equal realized Cash, equal realized active seconds → ratio ≈ 1.0
		t.ok("balanced → ratio ≈ 1.0 (within tolerance)", Analytics.isBalanced(Catalog, Analytics.perLoopBalanceRatio(300, 3600, 300, 3600)))
		-- TEETH: a forced imbalance (more realized hunting Cash at the SAME realized time) moves the ratio off 1.0
		local r2 = Analytics.perLoopBalanceRatio(600, 3600, 300, 3600)
		t.ok("forced imbalance → ratio 2.0, OFF balance (the metric catches a regression)", approx(r2, 2.0) and not Analytics.isBalanced(Catalog, r2))
		-- the tautology trap avoided: realizedLoopCash counts ONLY the routine kill/catch faucets — idle/daily/
		-- boost (loop-agnostic, loop="none") never pollute the per-loop routine income.
		local mixed = Analytics.realizedLoopCash(ledgerWith({
			{ type = "kill", amount = 100, loop = "Hunting" },
			{ type = "idle", amount = 9999, loop = "none" },
			{ type = "dailyQuest", amount = 9999, loop = "none" },
			{ type = "boostBonus", amount = 9999, loop = "none" },
		}))
		t.eq("only kill/catch routine faucets count (idle/daily/boost excluded)", mixed.Hunting, 100)
		t.eq("…and fishing stays 0 (no catch faucet present)", mixed.Fishing, 0)
		-- insufficient data is NOT "balanced" (the divide guard)
		t.ok("zero fishing time/Cash → ratio 0 (insufficient data, not a false 1.0)", Analytics.perLoopBalanceRatio(300, 3600, 0, 0) == 0)
	end

	t.section("§F the canary health layer — each canary has a documented threshold (a breach is a DEFINED alarm)")
	do
		local function inputs(over: { [string]: number }): Analytics.HealthInputs
			local base: Analytics.HealthInputs = { payProofViolations = 0, swapPreconditionFailures = 0, persistFailedRate = 0.0, evergreenSinkShare = 0.5, balanceRatio = 1.0 }
			for k, v in over do
				(base :: any)[k] = v
			end
			return base
		end
		t.ok("all canaries pass on a healthy snapshot", Analytics.allHealthy(Analytics.healthReport(Catalog, inputs({}))))
		t.ok("a single pay-proof violation trips the alarm (=0 threshold, structurally 0)", not Analytics.allHealthy(Analytics.healthReport(Catalog, inputs({ payProofViolations = 1 }))))
		t.ok("a swap-precondition failure trips the alarm (a dupe attempt/bug)", not Analytics.allHealthy(Analytics.healthReport(Catalog, inputs({ swapPreconditionFailures = 1 }))))
		t.ok("evergreen-sink share below the §9 floor trips the inflation alarm", not Analytics.allHealthy(Analytics.healthReport(Catalog, inputs({ evergreenSinkShare = 0.0 }))))
		t.ok("a balance ratio of 2.0 trips the dual-loop alarm", not Analytics.allHealthy(Analytics.healthReport(Catalog, inputs({ balanceRatio = 2.0 }))))
		t.ok("a high persist-failed rate trips the anomaly alarm", not Analytics.allHealthy(Analytics.healthReport(Catalog, inputs({ persistFailedRate = 0.5 }))))
		local found: { [string]: boolean } = {}
		for _, s in Analytics.healthReport(Catalog, inputs({})) do
			found[s.name] = true
		end
		t.ok("the report covers pay-proof / swap / persist / evergreen / balance", found.payProof and found.swapPrecondition and found.persistFailed and found.evergreenSinkShare and found.balanceRatio)
	end

	t.section("§A measurement integrity — events emit from the SERVER RESULT; a client count cannot move a metric")
	do
		-- a kill emits exactly ONE gameplay payout from the validated RESULT — there is no client-payload/count
		-- parameter on the emit path, so N validated server kills = N events, never a client-claimed number.
		local tel = Fakes.newTelemetry()
		local p = Util.mkProfile(Catalog, {})
		for i = 1, 3 do
			RewardPipeline.resolve(p, Catalog, { targetId = "bayou_wood_duck", owner = "u1", validatingEventId = "k" .. i, loop = Enums.Loop.Hunting }, { idGen = Fakes.newIdGenerator(), now = 1000, telemetry = tel })
		end
		t.eq("3 validated kills → exactly 3 payout events (server-derived count, not a client number)", tel.snapshot()["combat.payout:tier1"], 3)
		t.eq("the server-emitted payout is a gameplay event", Analytics.categoryOf("combat.payout:tier1"), C.gameplay)
		-- retention emits are derived from the server-stamped firstSeenAt, never a client "I returned" claim
		local tel2 = Fakes.newTelemetry()
		local q = Util.mkProfile(Catalog, {})
		q.firstSeenAt = 1000
		Analytics.recordSessionStart(tel2, Catalog, q, 1000 + 7 * WIN)
		t.eq("the retention day is derived from server timestamps (day 7)", tel2.snapshot()["session.retention:d7"], 1)
	end

	t.section("§G privacy — the analytics Event carries NO PII (behavioral, keyed by an opaque id)")
	do
		local e: Analytics.Event = { category = C.session, name = "session.start", value = 1 }
		t.ok("an Event is behavioral (category/name/value only — no personal field)", e.category == "session" and e.name == "session.start" and e.value == 1)
		-- (the negative fixture analytics_pii.luau proves reading a PII field off an Event fails analysis)
	end
end
