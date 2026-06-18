--!strict
-- THE DAILY-QUEST SKELETON (Step 7, SYS_onboarding_funnel §6 / SYS_economy §6) — the cross-loop pair's
-- per-day objective state and the SERVER-TIME reset. Pure logic over the `daily` slice of the session-locked
-- profile; the Cash AMOUNTS are economy's (Economy.dailyQuestReward / crossLoopBonus). The daily window rolls
-- off the server clock (`now`), NEVER client-reported elapsed — the same anti-spoof discipline idle uses.
-- Content / rotation / cadence is Step 13 (SYS_liveops_calendar); this is just the board-claim skeleton.

local Schema = require("../types/Schema")
local Enums = require("../types/Enums")

type DailyState = Schema.DailyState
type Loop = Enums.Loop

local M = {}

local DAY_SECONDS = 86400

-- maybeReset: if `now` falls in a new server-day window vs the stored basis, clear the day's objectives +
-- claim and advance the basis. Idempotent within a window. Called at login and at claim/record time.
function M.maybeReset(daily: DailyState, now: number)
	if math.floor(now / DAY_SECONDS) ~= math.floor(daily.resetBasis / DAY_SECONDS) then
		daily.resetBasis = now
		daily.huntDone = false
		daily.fishDone = false
		daily.claimed = false
	end
end

-- recordAction: a validated kill/catch marks that loop's daily objective (within the current window).
-- Called inside the kill/catch handler commits alongside Onboarding.advance.
function M.recordAction(daily: DailyState, loop: Loop, now: number)
	M.maybeReset(daily, now)
	if loop == Enums.Loop.Hunting then
		daily.huntDone = true
	else
		daily.fishDone = true
	end
end

-- The cross-loop breadth pair is claimable iff BOTH loops were played this window and it isn't already
-- claimed (idempotent per day). Breadth-as-reward — a single-loop player simply leaves it on the table.
function M.canClaimCrossLoop(daily: DailyState): boolean
	return daily.huntDone and daily.fishDone and not daily.claimed
end

return M
