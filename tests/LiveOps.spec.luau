--!strict
-- Step 13 — the pure LiveOps scheduler/budget/rotation/alarm engine + the scarcity-discipline guard.
-- Synthetic mini-configs drive the scheduler so server-time activation is exercised deterministically.

local LiveOps = require("@src/logic/LiveOps")
local Catalog = require("@src/config/Catalog")
local Validation = require("@src/config/Validation")
local Schema = require("@src/types/Schema")
local Harness = require("@tests/harness")

type EventConfig = Schema.EventConfig
type NewScarcityDecl = Schema.NewScarcityDecl

-- A fake Config carrying only what the scheduler reads (liveOps + real tuning for the income formula).
local function fakeConfig(events: { [string]: EventConfig }, pool: { Schema.Quest }?): Schema.Config
	return (
		{ liveOps = { events = events, dailyQuestPool = pool or {} }, tuning = Catalog.tuning, decor = {} } :: any
	) :: Schema.Config
end

return function(t: Harness.T)
	t.section("LiveOps scheduler — server-time activation (start → active → REVERT after end)")
	do
		local winter: EventConfig = {
			id = "winter_freeze",
			name = "Winter Freeze",
			kind = "limitedTime",
			startTime = 1000,
			endTime = 2000,
			imposes = { event = "Winter Freeze" },
			cashBudget = 0,
			newScarcity = {},
			notes = "",
		}
		local salmon: EventConfig = {
			id = "salmon_run",
			name = "Salmon Run",
			kind = "seasonal",
			startTime = 3000,
			endTime = 4000,
			imposes = { event = "Salmon Run", season = "Salmon Run" },
			cashBudget = 0,
			newScarcity = {},
			notes = "",
		}
		local cfg = fakeConfig({ winter_freeze = winter, salmon_run = salmon })

		t.ok("active AT start (inclusive)", LiveOps.isEventActive(cfg, "winter_freeze", 1000))
		t.ok("active AT end (inclusive)", LiveOps.isEventActive(cfg, "winter_freeze", 2000))
		t.ok("inactive just before start", LiveOps.isEventActive(cfg, "winter_freeze", 999) == false)
		t.ok("inactive just after end (the per-tick recompute REVERTS)", LiveOps.isEventActive(cfg, "winter_freeze", 2001) == false)
		t.ok("unknown event id is never active", LiveOps.isEventActive(cfg, "nope", 1500) == false)

		t.eq("world.event driven in the winter window", LiveOps.activeWorldEvent(cfg, 1500), "Winter Freeze")
		t.eq("world.event reverts to nil after the window", LiveOps.activeWorldEvent(cfg, 2500), nil)
		t.eq("world.event driven in the salmon window", LiveOps.activeWorldEvent(cfg, 3500), "Salmon Run")

		t.eq("worldStateAt imposes the event clause", LiveOps.worldStateAt(cfg, 1500).event, "Winter Freeze")
		t.eq("worldStateAt imposes the season clause (salmon)", LiveOps.worldStateAt(cfg, 3500).season, "Salmon Run")
		t.eq("worldStateAt is empty outside any window", LiveOps.worldStateAt(cfg, 2500).event, nil)

		local liveIds = LiveOps.activeEventIds(cfg, 1500)
		t.ok("activeEventIds includes the live event", liveIds["winter_freeze"] == true)
		t.ok("activeEventIds excludes a not-yet-live event", liveIds["salmon_run"] == nil)
	end

	t.section("LiveOps entitlements — server-time absolute (offline counts; only `now` matters)")
	do
		local ent: Schema.Entitlement = { kind = "winterFreeze", expiryTimestamp = 2000 }
		t.ok("active before expiry", LiveOps.entitlementActive(ent, 1999))
		t.ok("inactive AT expiry (boundary)", LiveOps.entitlementActive(ent, 2000) == false)
		t.ok("inactive after expiry (logging off banks nothing)", LiveOps.entitlementActive(ent, 2001) == false)
	end

	t.section("LiveOps budgets — PEAK instantaneous concurrent sum (not a naive sum-of-touching)")
	do
		local function ev(id: string, s: number, e: number, b: number): EventConfig
			return { id = id, name = id, kind = "limitedTime", startTime = s, endTime = e, imposes = {}, cashBudget = b, newScarcity = {}, notes = "" }
		end
		-- The v2 case: E overlaps B and E overlaps C, but B and C do NOT overlap each other. A naive
		-- "sum every window touching E" = 600; the PEAK concurrent sum = max(E+B, E+C) = 400.
		local cfg = fakeConfig({
			E = ev("E", 0, 100, 200),
			B = ev("B", 10, 20, 200),
			C = ev("C", 80, 90, 200),
		})
		t.eq("peak is max(E+B, E+C) = 400, NOT the naive 600", LiveOps.peakConcurrentCashBudget(cfg), 400)

		-- Two genuinely simultaneous Cash faucets DO stack to the bound.
		local cfg2 = fakeConfig({ A = ev("A", 0, 100, 300), B = ev("B", 50, 150, 300) })
		t.eq("two overlapping faucets stack", LiveOps.peakConcurrentCashBudget(cfg2), 600)

		-- A zero-budget spawn-only event (e.g. a seasonal window) contributes no Cash to the peak.
		local cfg3 = fakeConfig({ A = ev("A", 0, 100, 300), Z = ev("Z", 0, 100, 0) })
		t.eq("zero-budget events add nothing to the faucet peak", LiveOps.peakConcurrentCashBudget(cfg3), 300)
	end

	t.section("LiveOps budgets — per-event payout is capped at the declared budget")
	do
		local function ev(b: number): EventConfig
			return { id = "x", name = "x", kind = "limitedTime", startTime = 0, endTime = 100, imposes = {}, cashBudget = b, newScarcity = {}, notes = "" }
		end
		local cfg = fakeConfig({})
		-- Income(1)=1000 → 0.25·1000 = 250 < 500 budget → uncapped.
		t.eq("payout below budget is the scaled amount", LiveOps.eventPayout(cfg, ev(500), 1), 250)
		-- Income(4)=4913 → 0.25·4913 ≈ 1228 > 500 budget → capped to the budget.
		t.eq("payout above budget is capped to the budget", LiveOps.eventPayout(cfg, ev(500), 4), 500)
	end

	t.section("LiveOps daily rotation — cross-loop pair preserved, deterministic, themed")
	do
		local pool: { Schema.Quest } = {
			{ id = "h1", loop = "Hunting", objective = "Bag 3 caribou" },
			{ id = "h2", loop = "Hunting", objective = "Bag 1 black bear" },
			{ id = "f1", loop = "Fishing", objective = "Catch 5 trout" },
			{ id = "f2", loop = "Fishing", objective = "Catch 1 halibut" },
			{ id = "e1", loop = "either", objective = "Earn 1000 Cash" },
			{ id = "winter", loop = "either", objective = "Land 3 burbot through the ice", themedFor = "winter_freeze" },
		}
		local cfg = fakeConfig({}, pool)
		local function loops(set: { Schema.Quest }): (number, number)
			local h, f = 0, 0
			for _, q in set do
				if q.loop == "Hunting" then h += 1 elseif q.loop == "Fishing" then f += 1 end
			end
			return h, f
		end

		local day0 = 0
		local set = LiveOps.dailyQuestSet(cfg, day0, nil)
		t.eq("the set is the configured size", #set, 3)
		local h, f = loops(set)
		t.ok("≥1 hunting quest (cross-loop pair)", h >= 1)
		t.ok("≥1 fishing quest (cross-loop pair)", f >= 1)

		-- Deterministic within a server-day; the set rotates across days.
		t.eq("same day → identical set", LiveOps.dailyQuestSet(cfg, day0 + 3600, nil), set)
		local nextDay = LiveOps.dailyQuestSet(cfg, 86400 * 5, nil)
		local h2, f2 = loops(nextDay)
		t.ok("a later day still preserves the cross-loop pair", h2 >= 1 and f2 >= 1)

		-- Seasonal theming: an active beat surfaces its themed quest.
		local themed = LiveOps.dailyQuestSet(cfg, day0, "winter_freeze")
		local hasThemed = false
		for _, q in themed do
			if q.themedFor == "winter_freeze" then hasThemed = true end
		end
		t.ok("an active event themes the daily board", hasThemed)

		-- An INACTIVE event's themed quests must NEVER leak onto the board (they'd be uncompletable off-window).
		local function noThemedLeak(config: Schema.Config): boolean
			for d = 0, 29 do
				for _, q in LiveOps.dailyQuestSet(config, d * 86400, nil) do
					if q.themedFor ~= nil then
						return false
					end
				end
			end
			return true
		end
		t.ok("no themed quest leaks across 30 days when no event is active (synthetic pool)", noThemedLeak(cfg))
		t.ok("no themed quest leaks across 30 days when no event is active (real config pool)", noThemedLeak(Catalog))
	end

	t.section("LiveOps inflation SLA — Cash-priced-only decor quota + the evergreen-sink alarm")
	do
		-- The SLA counts Cash-priced SKUs only; a game-pass / real-money cosmetic is revenue, not ballast.
		local decorCfg = (
			{
				tuning = Catalog.tuning,
				decor = {
					a = { id = "a", cost = { cash = 100 } },
					b = { id = "b", cost = { cash = 250 } },
					gp = { id = "gp", cost = { realMoney = { kind = "gamepass" } } },
				},
				liveOps = { events = {}, dailyQuestPool = {} },
			} :: any
		) :: Schema.Config
		t.eq("counts only Cash-priced decor (game-pass excluded)", LiveOps.cashPricedDecorCount(decorCfg), 2)
		t.ok("quota met when enough Cash-priced SKUs ship", LiveOps.meetsDecorReplenishQuota(2, decorCfg))
		t.ok("quota missed below the cadence", LiveOps.meetsDecorReplenishQuota(1, decorCfg) == false)

		local cfg = fakeConfig({})
		t.ok("alarm fires below the threshold (catalog saturating)", LiveOps.evergreenSinkAlarm(0.10, cfg))
		t.ok("alarm silent AT the threshold", LiveOps.evergreenSinkAlarm(0.25, cfg) == false)
		t.ok("alarm silent above the threshold (sink healthy)", LiveOps.evergreenSinkAlarm(0.40, cfg) == false)
	end

	t.section("LiveOps scarcity-discipline guard (RD1 — build-time; the moat-structural piece)")
	do
		-- An event referencing/minting scarcity; resolved against the REAL catalog (tyee_king = Legendary,
		-- gated by event="Salmon Run"; king_salmon = Uncommon; arctic_grayling = Common).
		local function evt(over: { [string]: any }): EventConfig
			local e: EventConfig = {
				id = "test_event",
				name = "Test Event",
				kind = "limitedTime",
				startTime = 1000,
				endTime = 2000,
				imposes = { event = "Test Event" },
				cashBudget = 100,
				newScarcity = {},
				notes = "",
			}
			for k, v in over do
				(e :: any)[k] = v
			end
			return e
		end

		-- ACCEPT: schedule a window for an EXISTING rare at its unchanged rate (RD1a).
		t.test("referenceWindow to an existing rare is ACCEPTED", function()
			Validation.assertEventConfig(
				evt({
					id = "salmon_run",
					imposes = { event = "Salmon Run" },
					newScarcity = { { kind = "referenceWindow", targetId = "alaska_tyee_king" } },
				}),
				Catalog
			)
		end)
		-- ACCEPT: a genuinely-new scarcity id (not present in any catalog).
		t.test("a genuinely-new scarcity id is ACCEPTED", function()
			Validation.assertNewScarcityId("alaska_winter_burbot_brand_new", Catalog)
		end)

		-- REJECT (clone evasion): a 'new' id colliding with an existing catalog id.
		t.errs("a new-scarcity id colliding with an existing catalog id is REJECTED", function()
			Validation.assertNewScarcityId("alaska_tyee_king", Catalog)
		end)
		t.errs("a new-scarcity id colliding with an existing EQUIPMENT id is REJECTED", function()
			Validation.assertNewScarcityId("tackle_ice_fishing_kit", Catalog)
		end)
		-- REJECT (re-release / dilution): mintNew naming an EXISTING standing rare (not in this event's mintsFish).
		t.errs("mintNew naming an existing standing rare (re-release) is REJECTED", function()
			Validation.assertEventConfig(
				evt({
					imposes = { event = "Test Event" },
					newScarcity = { { kind = "mintNew", targetId = "alaska_tyee_king" } },
				}),
				Catalog
			)
		end)
		-- REJECT (the review's same-clause attack): re-pointing/matching a standing rare's OWN spawn clause and
		-- declaring mintNew. Rejected because tyee_king is NOT in this event's mintsFish (and can't be — the
		-- Catalog merge rejects a minted id that collides with the base catalog). Genuine-newness is structural.
		t.errs("mintNew re-releasing an existing rare under its own clause is REJECTED (same-clause attack)", function()
			Validation.assertEventConfig(
				evt({
					imposes = { event = "Salmon Run" }, -- matches alaska_tyee_king's real spawn clause
					newScarcity = { { kind = "mintNew", targetId = "alaska_tyee_king" } },
				}),
				Catalog
			)
		end)
		-- REJECT: referenceWindow to a non-existent target.
		t.errs("referenceWindow to a non-existent target is REJECTED", function()
			Validation.assertEventConfig(evt({ newScarcity = { { kind = "referenceWindow", targetId = "nope_no_such" } } }), Catalog)
		end)
		-- REJECT: referenceWindow to a non-rare (RD1 governs SCARCITY only).
		t.errs("referenceWindow to a non-rare (Uncommon) target is REJECTED", function()
			Validation.assertEventConfig(evt({ newScarcity = { { kind = "referenceWindow", targetId = "alaska_king_salmon" } } }), Catalog)
		end)
		-- REJECT: a cashBudget over the economy ceiling.
		t.errs("a cashBudget over the eventPayoutBudgetCeiling is REJECTED", function()
			Validation.assertEventConfig(evt({ cashBudget = Catalog.tuning.economy.eventPayoutBudgetCeiling + 1 }), Catalog)
		end)
		-- REJECT: a window with start ≥ end.
		t.errs("a window with start ≥ end is REJECTED", function()
			Validation.assertEventConfig(evt({ startTime = 2000, endTime = 2000 }), Catalog)
		end)
	end

	t.section("LiveOps validateLiveOps — aggregate PEAK ceiling + one-spawn-gating-event-at-a-time")
	do
		local function spawnEvt(id: string, s: number, e: number, b: number): EventConfig
			return { id = id, name = id, kind = "limitedTime", startTime = s, endTime = e, imposes = { event = id }, cashBudget = b, newScarcity = {}, notes = "" }
		end
		local function cashEvt(id: string, s: number, e: number, b: number): EventConfig
			return { id = id, name = id, kind = "limitedTime", startTime = s, endTime = e, imposes = {}, cashBudget = b, newScarcity = {}, notes = "" }
		end

		t.test("non-overlapping spawn-gating events within budget VALIDATE", function()
			Validation.validateLiveOps(fakeConfig({ a = spawnEvt("a", 1000, 2000, 100), b = spawnEvt("b", 3000, 4000, 0) }))
		end)
		t.errs("overlapping spawn-gating events are REJECTED (one world.event at a time)", function()
			Validation.validateLiveOps(fakeConfig({ a = spawnEvt("a", 1000, 2000, 0), b = spawnEvt("b", 1500, 2500, 0) }))
		end)
		t.errs("concurrent Cash faucets over the aggregate PEAK ceiling are REJECTED", function()
			-- three simultaneous non-spawn faucets at 400 each (each ≤ the 500 per-event ceiling) → peak 1200 > 1000.
			Validation.validateLiveOps(fakeConfig({
				a = cashEvt("a", 0, 100, 400),
				b = cashEvt("b", 0, 100, 400),
				c = cashEvt("c", 0, 100, 400),
			}))
		end)
	end

	t.section("LiveOps real config — Winter Freeze + Salmon Run + Frozen Lake content (end to end)")
	do
		-- The real Catalog already self-validated under the guard at require time (a malformed config would
		-- have failed the require). These assert the live records + the genuinely-new Frozen Lake scarcity.
		local wf = Catalog.liveOps.events.winter_freeze
		local sr = Catalog.liveOps.events.salmon_run
		t.ok("Winter Freeze event exists", wf ~= nil)
		t.ok("Salmon Run event exists", sr ~= nil)
		t.eq("Winter Freeze drives world.event = 'Winter Freeze'", wf.imposes.event, "Winter Freeze")
		t.ok("Winter Freeze mints genuinely-new scarcity (mintNew)", wf.newScarcity[1] ~= nil and wf.newScarcity[1].kind == "mintNew")

		-- The new winter catch: a genuinely-new permanently-scarce Legendary artifact, kit-gated, event-gated.
		local burbot = Catalog.fish["alaska_burbot"]
		t.ok("the genuinely-new winter catch exists", burbot ~= nil)
		t.eq("the winter catch is rare-and-above (artifact mint, no Cash)", burbot.reward.kind, "artifact")
		t.eq("the winter catch is gated by the Winter Freeze event clause", (burbot.spawn.conditions :: any).event, "Winter Freeze")
		t.eq("the winter catch requires the Ice-Fishing Kit (item-ownership gate)", burbot.requiresItem, "tackle_ice_fishing_kit")

		-- The whitefish: the calmer routine Frozen-Lake catch (Cash), also kit + event gated.
		local whitefish = Catalog.fish["alaska_lake_whitefish"]
		t.ok("the routine Frozen-Lake catch exists", whitefish ~= nil)
		t.eq("the routine catch pays Cash (Common)", whitefish.reward.kind, "cash")
		t.eq("the routine catch also requires the Kit", whitefish.requiresItem, "tackle_ice_fishing_kit")

		-- Server-time activation on the REAL config: active in-window, reverts after.
		local wfMid = math.floor((wf.startTime + wf.endTime) / 2)
		local srMid = math.floor((sr.startTime + sr.endTime) / 2)
		t.eq("the real scheduler drives Winter Freeze in its window", LiveOps.activeWorldEvent(Catalog, wfMid), "Winter Freeze")
		t.eq("the real scheduler drives Salmon Run in its window", LiveOps.activeWorldEvent(Catalog, srMid), "Salmon Run")
		t.eq("the real scheduler reverts to nil after Winter Freeze", LiveOps.activeWorldEvent(Catalog, wf.endTime + 1000000), nil)

		-- The guard ACCEPTS the real mintNew (the burbot is genuinely-new + event-exclusive).
		t.test("the real Winter Freeze config passes the scarcity guard", function()
			Validation.assertEventConfig(wf, Catalog)
		end)
	end

	t.section("Validation — a fish's requiresItem must resolve to a real equipment item (typo guard)")
	do
		t.test("a resolving requiresItem is accepted", function()
			Validation.assertFishItemRefs(Catalog.fish["alaska_burbot"], Catalog)
		end)
		t.errs("a requiresItem that does not resolve is rejected", function()
			local bad = table.clone(Catalog.fish["alaska_burbot"])
			bad.requiresItem = "tackle_does_not_exist"
			Validation.assertFishItemRefs(bad, Catalog)
		end)
		t.test("a fish with no requiresItem is fine", function()
			Validation.assertFishItemRefs(Catalog.fish["alaska_arctic_grayling"], Catalog)
		end)
	end

	t.section("LiveOps weather windows — activeWeather / activeTraits / nextWindowChangeAt")
	do
		local storm: EventConfig = {
			id = "w_storm", name = "Storm Window", kind = "weatherWindow",
			startTime = 1000, endTime = 1299, imposes = { weather = "storm" },
			cashBudget = 0, newScarcity = {}, notes = "", traitsGranted = { "stormTouched", "moonlit" },
		}
		local snow: EventConfig = {
			id = "w_snow", name = "Snow Window", kind = "weatherWindow",
			startTime = 1300, endTime = 1599, imposes = { weather = "snow" },
			cashBudget = 0, newScarcity = {}, notes = "", traitsGranted = { "frostbitten" },
		}
		local cfg = fakeConfig({ w_storm = storm, w_snow = snow })

		t.eq("activeWeather inside the storm window", LiveOps.activeWeather(cfg, 1100), "storm")
		t.eq("activeWeather at the inclusive end", LiveOps.activeWeather(cfg, 1299), "storm")
		t.eq("activeWeather reverts at end+1 (now the snow window)", LiveOps.activeWeather(cfg, 1300), "snow")
		t.eq("activeWeather nil in a gap after all windows", LiveOps.activeWeather(cfg, 2000), nil)

		local traits = LiveOps.activeTraits(cfg, 1100)
		t.ok("activeTraits has the storm window's traits", traits.stormTouched == true and traits.moonlit == true)
		t.ok("activeTraits excludes other windows' traits", traits.frostbitten == nil)
		t.ok("activeTraits empty in a gap", next(LiveOps.activeTraits(cfg, 2000)) == nil)

		t.eq("nextWindowChangeAt inside storm -> storm end+1", LiveOps.nextWindowChangeAt(cfg, 1100), 1300)
		t.eq("nextWindowChangeAt before all -> first start", LiveOps.nextWindowChangeAt(cfg, 500), 1000)
		t.eq("nextWindowChangeAt after all -> nil", LiveOps.nextWindowChangeAt(cfg, 9999), nil)
	end

	t.section("LiveOps weather overlay — weather rotates UNDER a spawn-gating seasonal event")
	do
		local salmon: EventConfig = {
			id = "salmon_run", name = "Salmon Run", kind = "seasonal",
			startTime = 1000, endTime = 2000, imposes = { event = "Salmon Run", season = "Salmon Run" },
			cashBudget = 0, newScarcity = {}, notes = "",
		}
		local stormSub: EventConfig = {
			id = "w_storm2", name = "Storm Window", kind = "weatherWindow",
			startTime = 1100, endTime = 1399, imposes = { weather = "storm" },
			cashBudget = 0, newScarcity = {}, notes = "", traitsGranted = { "stormTouched" },
		}
		local cfg = fakeConfig({ salmon_run = salmon, w_storm2 = stormSub })
		local ws = LiveOps.worldStateAt(cfg, 1200)
		t.eq("the seasonal event clause is preserved", ws.event, "Salmon Run")
		t.eq("the weather-only window overlays weather simultaneously", ws.weather, "storm")
		t.eq("season still imposed by the seasonal event", ws.season, "Salmon Run")
		local ws2 = LiveOps.worldStateAt(cfg, 1500)
		t.eq("event persists after weather ends", ws2.event, "Salmon Run")
		t.eq("weather cleared after its own window", ws2.weather, nil)
	end


	t.section("LiveOps weather rotation — the SHIPPED config validates + drives traits")
	do
		local anyWeather: EventConfig? = nil
		for _, e in Catalog.liveOps.events do
			if e.kind == "weatherWindow" then
				anyWeather = e
				break
			end
		end
		t.ok("the config ships weatherWindow records", anyWeather ~= nil)
		local w = anyWeather :: EventConfig
		t.eq("activeWeather sees the real window at its start", LiveOps.activeWeather(Catalog, w.startTime), w.imposes.weather)
		t.ok("activeTraits is non-empty inside the real window", next(LiveOps.activeTraits(Catalog, w.startTime)) ~= nil)
		t.ok("nextWindowChangeAt is defined inside the real window", LiveOps.nextWindowChangeAt(Catalog, w.startTime) ~= nil)
	end

end
