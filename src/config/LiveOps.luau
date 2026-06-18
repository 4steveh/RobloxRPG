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

local Schema = require("../types/Schema")
local Ids = require("../types/Ids")
local Enums = require("../types/Enums")
local FishBuilder = require("./FishBuilder")

local E = Ids.Event
local D = Ids.Destination
local W = Enums.WaterType
local Ra = Enums.Rarity
local fish = FishBuilder.fish
local rareFields = FishBuilder.rareFields

-- The Frozen-Lake catches the Winter Freeze event INTRODUCES (RD1b genuinely-new scarcity — NOT in the base
-- Fish catalog). DOUBLY gated downstream: (a) the `event = "Winter Freeze"` spawn clause (scheduler-driven;
-- closed out-of-window) AND (b) `requiresItem = tackle_ice_fishing_kit` (the item-ownership gate in
-- CatchHandler, NOT canAccessZone). Built via the SHARED FishBuilder so the Reward XOR is enforced; merged
-- into config.fish by Catalog with a collision check (a minted id must be genuinely new — the RD1 clone guard).
local winterFreezeFish: { Schema.Fish } = {
	fish({
		id = "alaska_lake_whitefish",
		destinationId = D.Alaska,
		name = "Lake Whitefish (through the ice)",
		tier = 4,
		rarity = Ra.Common, -- the routine Frozen-Lake catch (Cash); the calmer seated ice-jig
		typicalWeightKg = { min = 0.5, max = 2 },
		recordWeightKg = 4,
		fightDifficulty = 40, -- low: a calm seated jig (landable at the interior T3 rod/reel — cross-tier band)
		minRodTier = 3,
		minReelTier = 3,
		waterType = W.lake, -- the interior lake (frozen during the event); same water type as a still pond
		requiresItem = "tackle_ice_fishing_kit", -- the seasonal required-item gate (LOC_04 §6)
		spawnZones = { "frozen_lake" },
		cash = { min = 200, max = 250 }, -- Alaska floor wage (illustrative, economy's band)
		conditions = { event = "Winter Freeze" }, -- the lake only opens during the Winter Freeze event
	}),
	fish({
		id = "alaska_burbot",
		destinationId = D.Alaska,
		name = "Burbot (the Eelpout King)",
		tier = 4,
		rarity = Ra.Legendary, -- the GENUINELY-NEW event-exclusive winter scarcity (RD1b): a new artifact, no
		-- Cash at mint, permanently scarce after the window. NOT a re-release/dilution of any existing rare.
		typicalWeightKg = { min = 3, max = 8 },
		recordWeightKg = 12,
		fightDifficulty = 62,
		minRodTier = 4,
		minReelTier = 4,
		waterType = W.lake,
		requiresItem = "tackle_ice_fishing_kit",
		spawnZones = { "frozen_lake" },
		conditions = { event = "Winter Freeze" }, -- event-exclusive: gated by THIS event's spawn clause (the guard checks it)
		rare = rareFields(1800, "the ghost-pale eelpout hauled up through the ice — the Winter Freeze exclusive trophy"),
	}),
}

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
		mintsFish = {}, -- introduces NO new fish — it only windows EXISTING rares (RD1a)
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
		mintsFish = winterFreezeFish, -- RD1b: the genuinely-new fish this event introduces (merged into config.fish)
		newScarcity = {
			{ kind = "mintNew", targetId = "alaska_burbot" }, -- the genuinely-new event-exclusive Legendary (∈ mintsFish)
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
