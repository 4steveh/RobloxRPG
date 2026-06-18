--!strict
-- THE ONBOARDING FUNNEL STATE MACHINE (SYS_onboarding_funnel build-notes) — server-owned, DATA-DRIVEN, and
-- pure. Beats are declared data (reorder/cut = a config edit, so the reveal-beat and chain-length knobs are
-- A/B-tunable against live D1 without a code change). `advance` is the headless step the gauntlet handlers
-- call INSIDE their atomic commit, so a beat advances with the reward (a failed save reverts both),
-- idempotently. COMPLETE is one-shot — a returning player never re-enters. The felt FTUE (arrows, pings,
-- "+Cash" juice, pacing, aim-assist) and every D1 metric are Studio/telemetry, NOT here.

local Schema = require("../types/Schema")
local Enums = require("../types/Enums")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type Loop = Enums.Loop
type FunnelBeat = Enums.FunnelBeat
type OnboardingState = Schema.OnboardingState

local M = {}

local B = Enums.FunnelBeat

-- Each beat declares the authoritative event(s) that complete it, how many, the next beat, and whether it's
-- a pass-through (entered and immediately exited). WORLD_MAP is pass-through at MVL — Step 9 replaces it with
-- the real World-Map reveal + a real completion predicate (a config/handler swap, no machine change).
type BeatDef = { completesOn: { [string]: boolean }?, requiredCount: number, next: FunnelBeat?, passThrough: boolean }
local BEATS: { [string]: BeatDef } = {
	[B.FIRST_HUNT] = { completesOn = { kill = true }, requiredCount = 1, next = B.FIRST_CATCH, passThrough = false },
	[B.FIRST_CATCH] = { completesOn = { catch = true }, requiredCount = 1, next = B.FIRST_PURCHASE, passThrough = false },
	[B.FIRST_PURCHASE] = { completesOn = { gearUpgrade = true }, requiredCount = 1, next = B.WORLD_MAP, passThrough = false },
	[B.WORLD_MAP] = { completesOn = { worldMapOpen = true }, requiredCount = 1, next = B.LOOP_CONFIRM, passThrough = false }, -- Step 9: real reveal beat (was pass-through)
	[B.LOOP_CONFIRM] = { completesOn = { kill = true, catch = true }, requiredCount = 3, next = B.DAILY_INTRO, passThrough = false },
	[B.DAILY_INTRO] = { completesOn = { dailyClaim = true }, requiredCount = 1, next = B.COMPLETE, passThrough = false },
	[B.COMPLETE] = { completesOn = nil, requiredCount = 1, next = nil, passThrough = false },
}

-- The arrival-proximate first-spawn area per (destination, loop) — the ONLY place the first-of-each guarantee
-- is allowed (the no-farming-leak scope). MVL: the Bayou only. (LOC_01 owns the placement; this is the scope.)
local ONBOARDING_AREAS: { [string]: { [string]: string } } = {
	bayou = { Hunting = "sunny_levee", Fishing = "channel_banks" },
}

export type AdvanceResult = { advanced: boolean, beat: FunnelBeat }

local function transition(ob: OnboardingState, toBeat: FunnelBeat, now: number)
	ob.funnelBeat = toBeat
	ob.beatStartedAt = now
	ob.progress = 0
	-- chain through any pass-through beats so the funnel lands on a real (player-actionable) beat
	while BEATS[ob.funnelBeat].passThrough do
		ob.funnelBeat = assert(BEATS[ob.funnelBeat].next, "a pass-through beat must declare a next")
		ob.beatStartedAt = now
	end
	if ob.funnelBeat == B.COMPLETE then
		ob.completedAt = now -- one-time threshold; the returning-player marker
	end
end

-- advance(profile, eventKind, now): advances iff the authoritative event matches the current beat's
-- predicate; otherwise a no-op. Server-authoritative — a client "I'm done" flag has no path here.
function M.advance(profile: PlayerData, eventKind: string, now: number): AdvanceResult
	local ob = profile.onboarding
	if ob.funnelBeat == B.COMPLETE then
		return { advanced = false, beat = ob.funnelBeat } -- one-shot; never re-grants
	end
	local def = BEATS[ob.funnelBeat]
	if def.completesOn ~= nil and def.completesOn[eventKind] then
		ob.progress += 1
		if ob.progress >= def.requiredCount then
			transition(ob, assert(def.next, "a completable beat must declare a next"), now)
			return { advanced = true, beat = ob.funnelBeat }
		end
	end
	return { advanced = false, beat = ob.funnelBeat }
end

-- The structural no-real-money-in-funnel gate (Step 14's store gates on this) — and the returning-player test.
function M.isOnboardingComplete(profile: PlayerData): boolean
	return profile.onboarding.funnelBeat == B.COMPLETE
end

-- The first-of-each-loop guaranteed-spawn ELIGIBILITY (the headless half of the first-spawn guarantee; the
-- spawn itself is Studio). True ONLY for a first-time player, in the loop's arrival-proximate area, at the
-- beat that first needs that loop's target — so it returns false for a post-first / non-arrival / returning
-- case. The Studio service calls this to decide whether to bypass the density cap; the caps hold for the rest.
function M.firstSpawnEligible(_config: Config, profile: PlayerData, destinationId: string, areaId: string, loop: Loop): boolean
	if M.isOnboardingComplete(profile) then
		return false
	end
	local areas = ONBOARDING_AREAS[destinationId]
	if areas == nil or areas[loop] ~= areaId then
		return false
	end
	local firstBeat = if loop == Enums.Loop.Hunting then B.FIRST_HUNT else B.FIRST_CATCH
	return profile.onboarding.funnelBeat == firstBeat
end

return M
