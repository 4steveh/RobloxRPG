--!strict
-- LIVEOPS EVENT CONFIG (Step 13 — SYS_liveops_calendar §A/§E). The data-driven event calendar + the
-- daily-quest pool, joined into the aggregated `Config` (Catalog) as `config.liveOps`. A new event/season is
-- a CONFIG RECORD here, NOT code (RD4). The scheduler (src/logic/LiveOps.luau) recomputes which events are
-- live from SERVER TIME every tick and drives the WorldState `event` clause the spawn predicate reads; the
-- scarcity-discipline guard (Validation.validateLiveOps) validates this whole module at require time.
--
-- WINDOW TIMES are server-time-absolute epoch seconds and are ILLUSTRATIVE DEFAULTS — live-ops edits them to
-- the real calendar (the config-not-code property). They are NON-OVERLAPPING because both are spawn-gating
-- (one world.event at a time — the guard enforces it). Cash VALUES are economy's (cited, not authored): event
-- value is scarce/identity (a rare mint writes NO Cash, RD2), so the Cash budgets are thin/zero.

local Schema = require("@src/types/Schema")
local Ids = require("@src/types/Ids")

local E = Ids.Event

-- Illustrative absolute windows (epoch seconds). Salmon Run ≈ the real summer run; Winter Freeze ≈ deep
-- winter — disjoint by construction. Live-ops re-dates these per the real calendar (no code change).
local SALMON_RUN_START = 1780272000 -- ~2026-06-01 (the real fishing/hunting season — LOC_04 §9)
local SALMON_RUN_END = 1788220800 -- ~2026-09-01
local WINTER_FREEZE_START = 1796083200 -- ~2026-12-01 (the lake freezes)
local WINTER_FREEZE_END = 1803772800 -- ~2027-02-28

local events: Schema.EventCatalog = {
	-- §3.2 SEASONAL — the canonical Alaska tentpole. Opens windows for EXISTING rares at their UNCHANGED
	-- 1-in-N (RD1a — referenceWindow): the Tyee King (Legendary fish) and the Glacier Grizzly (Legendary
	-- creature, the co-op apex the run makes LIVE, LOC_04 §9). It mints NOTHING new and writes NO Cash.
	[E.SalmonRun] = {
		id = E.SalmonRun,
		name = "The Salmon Run",
		kind = "seasonal",
		startTime = SALMON_RUN_START,
		endTime = SALMON_RUN_END,
		imposes = { event = "Salmon Run", season = "Salmon Run" }, -- drives both clauses the run species read
		cashBudget = 0, -- pure scarcity/content beat; the value is the catch, not Cash (RD2)
		newScarcity = {
			{ kind = "referenceWindow", targetId = "alaska_tyee_king" }, -- existing Legendary fish, rate untouched
			{ kind = "referenceWindow", targetId = "alaska_glacier_grizzly" }, -- existing Legendary apex, rate untouched
		},
		notes = "Seasonal: concentrates the run rares at unchanged 1-in-N (RD1a). The co-op apex becomes live.",
	},
	-- §3.3 LIMITED-TIME — the MVL's one concrete event. Opens the seasonal Frozen Lake (doubly-gated: active
	-- window AND Ice-Fishing-Kit ownership) and MINTS a genuinely-new permanently-scarce winter catch (RD1b —
	-- mintNew, the Burbot). A thin budget-capped participation Cash reward; the value is the new trophy.
	[E.WinterFreeze] = {
		id = E.WinterFreeze,
		name = "Winter Freeze",
		kind = "limitedTime",
		startTime = WINTER_FREEZE_START,
		endTime = WINTER_FREEZE_END,
		imposes = { event = "Winter Freeze" }, -- the single spawn-gating clause the Frozen-Lake fish read
		cashBudget = 500, -- ≤ economy's eventPayoutBudgetCeiling; the thin participation faucet (RD2)
		newScarcity = {
			{ kind = "mintNew", targetId = "alaska_burbot" }, -- the genuinely-new event-exclusive Legendary
		},
		notes = "Limited-time: opens the doubly-gated Frozen Lake (window + Ice-Fishing Kit) and mints the Burbot (RD1b).",
	},
}

-- §5 daily-quest pool — MECHANICAL objectives (not narrative). The pool must be able to form the cross-loop
-- pair (≥1 Hunting + ≥1 Fishing — the guard enforces it); the scheduler's dailyQuestSet picks ~3/day with
-- the pair preserved and themes to an active beat. Reward SCALE is economy's (ClaimDailyHandler), not here.
local dailyQuestPool: { Schema.Quest } = {
	{ id = "dq_hunt_caribou", loop = "Hunting", objective = "Bag 3 caribou" },
	{ id = "dq_hunt_deer", loop = "Hunting", objective = "Take 1 Sitka blacktail deer" },
	{ id = "dq_fish_grayling", loop = "Fishing", objective = "Catch 5 Arctic grayling" },
	{ id = "dq_fish_king", loop = "Fishing", objective = "Land 1 King Salmon" },
	{ id = "dq_either_haul", loop = "either", objective = "Earn 2,000 Cash from the day's haul" },
	-- Seasonal/event theming: surfaced only while the named beat is live (the board feels part of the calendar).
	{ id = "dq_winter_burbot", loop = "Fishing", objective = "Land 3 catches through the ice", themedFor = E.WinterFreeze },
	{ id = "dq_salmon_sockeye", loop = "Fishing", objective = "Land 4 sockeye in the run", themedFor = E.SalmonRun },
	{ id = "dq_salmon_falls", loop = "Hunting", objective = "Hunt the Salmon Falls draw", themedFor = E.SalmonRun },
}

local LiveOps: Schema.LiveOpsConfig = {
	events = events,
	dailyQuestPool = dailyQuestPool,
}

return LiveOps
