--!strict
-- PURE ANALYTICS (Step 15 — 00 §0 / SYS_economy §6/§9 / SYS_onboarding_funnel / SYS_data_integrity). The
-- measurement layer: the typed event TAXONOMY the inherited telemetry sink emits, the RETENTION (D1/D7/D30)
-- classification, the FUNNEL drop-off, the MEASURED per-loop balance metric, and the consolidated CANARY
-- health layer. PURE — reads profile / ledger / config + server-computed values; emits through the inherited
-- sink. The AnalyticsService aggregation (cohort rollups, dashboards, ARPU) is Studio/ops; this is the
-- headless definition + measurement-integrity half. It re-instruments NOTHING (the ~30 existing hooks map
-- onto `categoryOf`); it adds no second Cash source (realized income reads the existing tagged ledger).
--
-- MEASUREMENT INTEGRITY (the rigor of this step): every emit helper takes SERVER-COMPUTED values only — there
-- is no client-payload parameter, so a client-supplied count cannot move a metric (events derive from the
-- validated handler RESULT, never a request). NO PII: the `Event` record is behavioral — category/name/value
-- + the loop/tier dimensions, nothing personal; a PII read is unrepresentable (negative fixture).

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")

type Ledger = Schema.Ledger
type OnboardingState = Schema.OnboardingState
type PlayerData = Schema.PlayerData
type Config = Schema.Config
type LedgerLoop = Schema.LedgerLoop
type FunnelBeat = Enums.FunnelBeat
-- The telemetry sink shape, declared locally so this pure logic module does NOT depend on the server layer
-- (structurally identical to server/persistence/Types.Telemetry — the real sink is accepted by structural typing).
type Telemetry = { incr: (metric: string, by: number?) -> (), snapshot: () -> { [string]: number } }

local M = {}

-- ── §A the typed event taxonomy ─────────────────────────────────────────────────────────────────────────
-- The CLOSED set of analytics categories. Every emitted metric belongs to exactly one.
export type Category = "session" | "gameplay" | "economy" | "funnel" | "monetization" | "trade" | "integrity"
M.Category = table.freeze({
	session = "session" :: Category,
	gameplay = "gameplay" :: Category,
	economy = "economy" :: Category,
	funnel = "funnel" :: Category,
	monetization = "monetization" :: Category,
	trade = "trade" :: Category,
	integrity = "integrity" :: Category,
})

-- An analytics EVENT — behavioral, keyed by an opaque id ELSEWHERE. NO PII FIELD (the privacy guarantee, 13+
-- audience): the record carries category/name/value + the loop/tier dimensions, nothing personal.
export type Event = { category: Category, name: string, value: number, loop: LedgerLoop?, tier: number? }

-- The prefix→category registry: the SINGLE source of truth that consolidates the ~30 inherited hooks (plus
-- the new session/funnel/retention events) into the taxonomy. `categoryOf` matches the LONGEST registered
-- prefix; a metric with no category is a taxonomy gap (the totality test asserts every known name maps).
local PREFIX_CATEGORY: { [string]: Category } = {
	["session."] = M.Category.session,
	["funnel."] = M.Category.funnel,
	["combat."] = M.Category.gameplay,
	["fishing."] = M.Category.gameplay,
	["travel."] = M.Category.gameplay,
	["economy."] = M.Category.economy,
	["daily."] = M.Category.economy,
	["liveops."] = M.Category.economy,
	["lodge."] = M.Category.economy,
	["monetization."] = M.Category.monetization,
	["trade."] = M.Category.trade,
	["gauntlet."] = M.Category.integrity,
	["save."] = M.Category.integrity,
}

function M.categoryOf(metricName: string): Category?
	local best: Category? = nil
	local bestLen = -1
	for prefix, category in PREFIX_CATEGORY do
		if string.sub(metricName, 1, #prefix) == prefix and #prefix > bestLen then
			best = category
			bestLen = #prefix
		end
	end
	return best
end

-- emit — the ONE typed emission surface (wraps the inherited telemetry sink). Server-computed Event only.
function M.emit(telemetry: Telemetry?, event: Event)
	if telemetry ~= nil then
		telemetry.incr(event.name, event.value)
	end
end

-- ── §B retention (D1/D7/D30 — PINNED rolling-24h windows from firstSeenAt; server time, timezone-free) ────
-- retentionDay: the integer day-window index a session at `sessionAt` falls in, relative to firstSeenAt.
-- Day 0 = the install session; a session in [N·24h, (N+1)·24h) after firstSeenAt is a "day N" return.
function M.retentionDay(config: Config, firstSeenAt: number, sessionAt: number): number
	local w = config.tuning.analytics.retentionWindowSeconds
	local elapsed = sessionAt - firstSeenAt
	if elapsed < 0 then
		return 0
	end
	return math.floor(elapsed / w)
end

-- isRetainedOnDay: did a session at `sessionAt` fall in the day-N rolling window? (DN-retained ⟺ ANY session
-- in window N — the cohort rollup over players is the AnalyticsService; this is the per-session classifier.)
function M.isRetainedOnDay(config: Config, firstSeenAt: number, sessionAt: number, n: number): boolean
	return M.retentionDay(config, firstSeenAt, sessionAt) == n
end

-- ── §C the funnel drop-off (from Onboarding's beats + beatStartedAt) ─────────────────────────────────────
-- The beat order (Enums.FunnelBeat) — the funnel spine the drop-off distribution indexes into.
local BEAT_ORDER: { FunnelBeat } = {
	Enums.FunnelBeat.FIRST_HUNT,
	Enums.FunnelBeat.FIRST_CATCH,
	Enums.FunnelBeat.FIRST_PURCHASE,
	Enums.FunnelBeat.WORLD_MAP,
	Enums.FunnelBeat.LOOP_CONFIRM,
	Enums.FunnelBeat.DAILY_INTRO,
	Enums.FunnelBeat.COMPLETE,
}
M.BEAT_ORDER = BEAT_ORDER

function M.beatIndex(beat: FunnelBeat): number
	for i, b in BEAT_ORDER do
		if b == beat then
			return i
		end
	end
	return -1
end

-- funnelDropoff: where in the funnel the player currently is, the DWELL on the current beat (now − the beat's
-- start), and whether they reached COMPLETE. The session-end emit turns "not reachedComplete" into the
-- abandon signal; the per-beat dwell is THE first-five-minutes D1 diagnostic.
export type FunnelDropoff = { lastBeat: FunnelBeat, beatIndex: number, dwellSeconds: number, reachedComplete: boolean }
function M.funnelDropoff(onboarding: OnboardingState, now: number): FunnelDropoff
	local dwell = now - onboarding.beatStartedAt
	if dwell < 0 then
		dwell = 0
	end
	return {
		lastBeat = onboarding.funnelBeat,
		beatIndex = M.beatIndex(onboarding.funnelBeat),
		dwellSeconds = dwell,
		reachedComplete = onboarding.funnelBeat == Enums.FunnelBeat.COMPLETE,
	}
end

-- ── §D the MEASURED per-loop balance metric (realized ÷ realized — NOT the by-construction tautology) ─────
-- realizedLoopCash: the actual granted ROUTINE Cash per loop, summed from the real kill/catch faucet entries
-- in the ledger tail (the server-validated grants — NOT the modeled rate). Only `kill`/`catch` faucets count
-- (the routine income the band balances); idle/daily/boost/event faucets are loop-agnostic and excluded.
export type LoopCash = { Hunting: number, Fishing: number }
function M.realizedLoopCash(cash: Ledger): LoopCash
	local out: LoopCash = { Hunting = 0, Fishing = 0 }
	for _, e in cash.tail do
		if e.amount > 0 then
			if e.type == "kill" then
				out.Hunting += e.amount
			elseif e.type == "catch" then
				out.Fishing += e.amount
			end
		end
	end
	return out
end

-- perLoopBalanceRatio: huntingCashPerHour / fishingCashPerHour from REALIZED grants ÷ REALIZED per-loop active
-- time. ≈1.0 ⟺ the dual loop is balanced at the played distribution. THIS is the metric that catches a balance
-- regression the by-construction proof can't see once real play diverges from the model (a content drop that
-- breaks the band, a mispriced target, a skill distribution favoring one loop). Returns 0 if a loop had no
-- realized time/Cash (undefined ratio → the AnalyticsService treats it as "insufficient data", not balanced).
-- The realized per-loop active SECONDS are new session instrumentation (the Studio session accumulates +
-- emits them); this pure function is fed them, so the metric is headless-testable and has teeth.
function M.perLoopBalanceRatio(huntCash: number, huntSeconds: number, fishCash: number, fishSeconds: number): number
	if huntSeconds <= 0 or fishSeconds <= 0 or fishCash <= 0 then
		return 0 -- insufficient data (a divide guard; NOT "balanced")
	end
	local huntPerHour = huntCash / (huntSeconds / 3600)
	local fishPerHour = fishCash / (fishSeconds / 3600)
	if fishPerHour <= 0 then
		return 0
	end
	return huntPerHour / fishPerHour
end

-- isBalanced: the ratio sits within the §F tolerance band of 1.0 (the balance canary's verdict).
function M.isBalanced(config: Config, ratio: number): boolean
	return ratio > 0 and math.abs(ratio - 1) <= config.tuning.analytics.canary.balanceRatioTolerance
end

-- ── §F the consolidated canary health layer (each with a documented threshold — a breach is a DEFINED alarm)
-- The inputs are populated by the AnalyticsService from the telemetry snapshot + the ledger (the rollup is
-- ops); this PURE function turns them into pass/fail verdicts against the thresholds.
export type HealthInputs = {
	payProofViolations: number, -- §14 any purchase path touching conquest state (structurally 0)
	swapPreconditionFailures: number, -- §12 swap-precondition failures (a dupe attempt/bug)
	persistFailedRate: number, -- gauntlet.persist_failed ÷ handled commits (anomaly signal)
	evergreenSinkShare: number, -- §9 endgame Cash routed to evergreen sinks (the inflation canary)
	balanceRatio: number, -- §D realized hunting/fishing Cash-per-hour ratio (≈1.0)
}
export type CanaryStatus = { name: string, value: number, threshold: number, ok: boolean }
function M.healthReport(config: Config, inputs: HealthInputs): { CanaryStatus }
	local c = config.tuning.analytics.canary
	local evergreenFloor = config.tuning.liveops.evergreenSinkShareAlarmThreshold -- reuse §9's number, don't duplicate
	return {
		{ name = "payProof", value = inputs.payProofViolations, threshold = c.payProofMaxCount, ok = inputs.payProofViolations <= c.payProofMaxCount },
		{ name = "swapPrecondition", value = inputs.swapPreconditionFailures, threshold = c.swapPreconditionMaxCount, ok = inputs.swapPreconditionFailures <= c.swapPreconditionMaxCount },
		{ name = "persistFailed", value = inputs.persistFailedRate, threshold = c.persistFailedMaxRate, ok = inputs.persistFailedRate <= c.persistFailedMaxRate },
		{ name = "evergreenSinkShare", value = inputs.evergreenSinkShare, threshold = evergreenFloor, ok = inputs.evergreenSinkShare >= evergreenFloor },
		{ name = "balanceRatio", value = inputs.balanceRatio, threshold = c.balanceRatioTolerance, ok = M.isBalanced(config, inputs.balanceRatio) },
	}
end

-- allHealthy: the launch/ops gate — every canary passes.
function M.allHealthy(report: { CanaryStatus }): boolean
	for _, s in report do
		if not s.ok then
			return false
		end
	end
	return true
end

-- ── §A/§B/§C the typed EMIT helpers for the NEW events (server-values only — the measurement-integrity core).
-- Existing hooks (combat.*/economy.*/monetization.* …) already emit at their validated event points and map
-- onto the taxonomy via categoryOf; these add the session/funnel/retention events the substrate now enables.

-- recordSessionStart: the session boundary + the retention-day classification (server time). NO client param —
-- a client cannot fake a return; the day is derived from the profile's server-stamped firstSeenAt.
function M.recordSessionStart(telemetry: Telemetry?, config: Config, profile: PlayerData, now: number)
	M.emit(telemetry, { category = M.Category.session, name = "session.start", value = 1 })
	local day = M.retentionDay(config, if profile.firstSeenAt > 0 then profile.firstSeenAt else now, now)
	M.emit(telemetry, { category = M.Category.session, name = "session.retention:d" .. tostring(day), value = 1 })
end

-- recordSessionEnd: the session boundary + the funnel ABANDON signal (a session ended without reaching
-- COMPLETE → which beat it stalled on; the drop-off distribution). Server-derived from the profile's beat.
function M.recordSessionEnd(telemetry: Telemetry?, profile: PlayerData, now: number)
	M.emit(telemetry, { category = M.Category.session, name = "session.end", value = 1 })
	local d = M.funnelDropoff(profile.onboarding, now)
	M.emit(telemetry, { category = M.Category.funnel, name = "funnel.beat_dwell:" .. d.lastBeat, value = d.dwellSeconds })
	if not d.reachedComplete then
		M.emit(telemetry, { category = M.Category.funnel, name = "funnel.beat_abandoned:" .. d.lastBeat, value = 1 })
	end
end

-- recordFunnelBeatReached: emitted from Onboarding.advance's RESULT (a server-validated beat transition) —
-- the beat-reached half of the funnel distribution. Takes the server-advanced beat, never a client claim.
function M.recordFunnelBeatReached(telemetry: Telemetry?, beat: FunnelBeat)
	M.emit(telemetry, { category = M.Category.funnel, name = "funnel.beat_reached:" .. beat, value = 1 })
end

return M
