--!strict
-- PURE LIVEOPS SCHEDULER (Step 13 — SYS_liveops_calendar §7/§C). The headless, server-authoritative core:
-- given SERVER TIME and the event config, compute which events are live and the WorldState `event` clause the
-- spawn predicate already reads (Spawner.rareSpawnEligible). It NEVER touches the predicate, the 1-in-N, or a
-- spawn entry — liveops owns the SCHEDULE, the mechanism of none. No Roblox globals, no persistence: the
-- Studio tick (WorldServer) calls these with `os.time()`; here `now` is an injected number.
--
-- THE PER-TICK RECOMPUTE (binding): activeness is `start ≤ now ≤ end` computed every call, so an event goes
-- active at `start` and REVERTS after `end` purely from server time — never latched. `world.event` is a single
-- string matched by equality, so one spawn-gating event at a time (sufficient for MVL; the build-time guard
-- in Validation forbids overlapping spawn-gating windows so this is unambiguous).

local Schema = require("../types/Schema")
local Economy = require("./Economy")

type Config = Schema.Config
type EventConfig = Schema.EventConfig
type Entitlement = Schema.Entitlement
type Quest = Schema.Quest

local DAY_SECONDS = 86400

local function round(x: number): number
	return math.floor(x + 0.5)
end

-- The spawner's world inputs (structurally Spawner.WorldState; re-declared to avoid coupling logic→logic).
export type WorldState = { time: string?, weather: string?, season: string?, event: string? }

local M = {}

-- An event is live iff server time is within its inclusive window. Unknown ids are never active.
function M.isEventActive(config: Config, eventId: string, now: number): boolean
	local e = config.liveOps.events[eventId]
	if e == nil then
		return false
	end
	return now >= e.startTime and now <= e.endTime
end

-- The set of currently-live event ids (only live ids are keys; absent = not live).
function M.activeEventIds(config: Config, now: number): { [string]: boolean }
	local live: { [string]: boolean } = {}
	for id, e in config.liveOps.events do
		if now >= e.startTime and now <= e.endTime then
			live[id] = true
		end
	end
	return live
end

-- The single spawn-gating event live now (its imposes.event). One at a time — the build-time non-overlap
-- guard (Validation.validateLiveOps) guarantees ≤1 spawn-gating window is ever active, so this is unambiguous.
function M.activeWorldEvent(config: Config, now: number): string?
	for _, e in config.liveOps.events do
		if e.imposes.event ~= nil and now >= e.startTime and now <= e.endTime then
			return e.imposes.event
		end
	end
	return nil
end

-- The WorldState the calendar imposes at `now`: the active spawn-gating event's `imposes` overlaid. Ambient
-- time/weather/season (the day-night + weather + real-season systems) are merged on top by the Studio tick;
-- this is the event-driven half (what makes the event-gated rares eligible).
function M.worldStateAt(config: Config, now: number): WorldState
	local ws: WorldState = {}
	for _, e in config.liveOps.events do
		if e.imposes.event ~= nil and now >= e.startTime and now <= e.endTime then
			ws.event = e.imposes.event
			ws.season = e.imposes.season or ws.season
			ws.time = e.imposes.time or ws.time
			ws.weather = e.imposes.weather or ws.weather
		end
	end
	ws.weather = ws.weather or M.activeWeather(config, now) -- weather-only windows still drive `weather`
	return ws
end

-- The single weather tag imposed now (the active weatherWindow's imposes.weather). Independent of the
-- spawn-gating `event` clause: a weatherWindow may impose ONLY weather. Build-time non-overlap of
-- weatherWindow events (Validation) guarantees <=1 at any instant, so first-match is unambiguous.
function M.activeWeather(config: Config, now: number): string?
	for _, e in config.liveOps.events do
		if e.kind == "weatherWindow" and e.imposes.weather ~= nil and now >= e.startTime and now <= e.endTime then
			return e.imposes.weather
		end
	end
	return nil
end

-- The traits ELIGIBLE to roll at `now` — the union of traitsGranted across live events (in practice the single
-- active weatherWindow, by the non-overlap guard). Empty set = no trait can roll (a base catch).
function M.activeTraits(config: Config, now: number): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, e in config.liveOps.events do
		if e.traitsGranted ~= nil and now >= e.startTime and now <= e.endTime then
			for _, tr in e.traitsGranted do
				set[tr] = true
			end
		end
	end
	return set
end

-- The next server-time instant at which the live weatherWindow set CHANGES (the next start OR end+1 of any
-- weatherWindow strictly after `now`). The countdown's source of truth. nil = no upcoming boundary.
function M.nextWindowChangeAt(config: Config, now: number): number?
	local best: number? = nil
	for _, e in config.liveOps.events do
		if e.kind == "weatherWindow" then
			for _, boundary in { e.startTime, e.endTime + 1 } do
				if boundary > now and (best == nil or boundary < best) then
					best = boundary
				end
			end
		end
	end
	return best
end

-- A timed entitlement (window-bounded boost / event access) is valid iff `now` is before its absolute
-- server-time expiry. Offline time counts — logging off banks nothing (SYS_data_integrity §6); only `now`
-- matters, never a client-reported elapsed.
function M.entitlementActive(entitlement: Entitlement, now: number): boolean
	return now < entitlement.expiryTimestamp
end

-- ── §6 budgets ──────────────────────────────────────────────────────────────────────────────────────
-- The PEAK instantaneous concurrent Cash faucet: the MAX over the timeline of the summed cashBudgets of
-- SIMULTANEOUSLY-live events — a sweep line, NOT a naive "sum every window that touches E" (which overcounts
-- events that overlap E but not each other). Windows are inclusive [start,end]; an event contributes through
-- `end` (delta removed at end+1). At a shared instant, ends are applied before starts so a 1-second gap is
-- truly non-overlapping. Zero-budget (spawn-only / seasonal) events add nothing to the faucet.
function M.peakConcurrentCashBudget(config: Config): number
	type Delta = { t: number, d: number }
	local deltas: { Delta } = {}
	for _, e in config.liveOps.events do
		if e.cashBudget > 0 then
			table.insert(deltas, { t = e.startTime, d = e.cashBudget })
			table.insert(deltas, { t = e.endTime + 1, d = -e.cashBudget })
		end
	end
	table.sort(deltas, function(a: Delta, b: Delta): boolean
		if a.t ~= b.t then
			return a.t < b.t
		end
		return a.d < b.d -- ends (negative) before starts (positive) at the same instant
	end)
	local running, peak = 0, 0
	for _, delta in deltas do
		running += delta.d
		if running > peak then
			peak = running
		end
	end
	return peak
end

-- The thin participation Cash an event pays at a tier: a fraction of current-tier income (economy's scale —
-- reusing the daily-quest fraction), CAPPED at the event's declared per-window budget (RD2 — events deliver
-- scarce/identity value, not Cash; the faucet exposure is bounded by construction). loop="none" at the ledger.
function M.eventPayout(config: Config, event: EventConfig, tier: number): number
	local scaled = round(config.tuning.economy.dailyQuestFraction * Economy.income(config, tier))
	return math.min(scaled, event.cashBudget)
end

-- ── §5 daily-quest rotation ─────────────────────────────────────────────────────────────────────────
-- The daily set (~dailyQuestSetSize): a deterministic per-server-day selection that ALWAYS preserves the
-- cross-loop pair (≥1 Hunting + ≥1 Fishing) and themes to an active beat. Liveops authors WHICH quests; the
-- reward SCALE is economy's (ClaimDailyHandler → Economy.dailyQuestReward, scaled by T_current — an open
-- economy call, NOT resolved here). The board's claim mechanic (Daily/ClaimDailyHandler) is unchanged.
function M.dailyQuestSet(config: Config, now: number, activeEvent: string?): { Quest }
	local pool = config.liveOps.dailyQuestPool
	local size = config.tuning.liveops.dailyQuestSetSize
	local day = math.floor(now / DAY_SECONDS)

	-- ELIGIBLE = the always-on quests (themedFor == nil) plus the active beat's themed quests. A themed quest
	-- whose event is NOT live is EXCLUDED from every pick — surfacing it would put an uncompletable objective on
	-- the board (its event-gated target cannot spawn off-window). Theming is opt-IN when active, never a leak.
	local eligible: { Quest } = {}
	local hunting: { Quest } = {}
	local fishing: { Quest } = {}
	for _, q in pool do
		if q.themedFor == nil or q.themedFor == activeEvent then
			table.insert(eligible, q)
			if q.loop == "Hunting" then
				table.insert(hunting, q)
			elseif q.loop == "Fishing" then
				table.insert(fishing, q)
			end
		end
	end

	local set: { Quest } = {}
	local chosen: { [string]: boolean } = {}
	local function add(q: Quest)
		if not chosen[q.id] and #set < size then
			chosen[q.id] = true
			table.insert(set, q)
		end
	end
	-- Take exactly ONE not-yet-chosen quest from a list (rotated by day) — used to force the cross-loop pair.
	local function takeOne(list: { Quest }, offset: number)
		local n = #list
		for i = 0, n - 1 do
			local q = list[(day + offset + i) % n + 1]
			if not chosen[q.id] then
				add(q)
				return
			end
		end
	end
	-- Fill remaining slots from a list (rotated by day), skipping already-chosen, until the set is full.
	local function fill(list: { Quest }, offset: number)
		local n = #list
		for i = 0, n - 1 do
			if #set >= size then
				break
			end
			add(list[(day + offset + i) % n + 1])
		end
	end

	takeOne(hunting, 0) -- force ≥1 Hunting (the cross-loop pair)
	takeOne(fishing, 0) -- force ≥1 Fishing (the cross-loop pair)
	if activeEvent ~= nil then -- seasonal/event theming: prefer the active beat's themed quests
		local themed: { Quest } = {}
		for _, q in eligible do
			if q.themedFor == activeEvent then
				table.insert(themed, q)
			end
		end
		fill(themed, 0)
	end
	fill(eligible, day) -- fill the rest from the eligible set (no off-event themed leak), rotated by day
	return set
end

-- ── §4 inflation SLA: the Cash-priced-only quota + the evergreen-sink alarm ──────────────────────────
-- The SLA counts the Cash-priced evergreen subset ONLY — a game-pass / real-money cosmetic is welcome
-- revenue but removes no Cash and does NOTHING for the inflation condition (so it cannot satisfy the quota).
function M.cashPricedDecorCount(config: Config): number
	local count = 0
	for _, d in config.decor do
		if (d.cost :: any).cash ~= nil then
			count += 1
		end
	end
	return count
end

-- The per-cycle replenishment quota: enough Cash-priced SKUs shipped this cycle to keep the sink ahead.
function M.meetsDecorReplenishQuota(newCashPricedSkus: number, config: Config): boolean
	return newCashPricedSkus >= config.tuning.liveops.decorReplenishCadence
end

-- The alarm override (the canary triggers a drop): when top-tier players STOP routing Cash into decor/slots
-- — the evergreen-sink share of endgame Cash falls below threshold — the catalog has saturated faster than
-- the baseline quota anticipated; fire an out-of-band decor/theme drop ahead of the cadence. The METRIC is
-- economy's §9 canary; the THRESHOLD is liveops's (it owns the response).
function M.evergreenSinkAlarm(shareOfEndgameCash: number, config: Config): boolean
	return shareOfEndgameCash < config.tuning.liveops.evergreenSinkShareAlarmThreshold
end

return M
