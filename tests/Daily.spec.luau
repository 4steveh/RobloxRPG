--!strict
-- Step 7 (daily-quest skeleton) — the cross-loop pair's per-day objective state + the server-time reset
-- (never client-reported elapsed, the same discipline idle uses). Content/rotation/cadence is Step 13;
-- this is the board-claim skeleton the funnel hands off to.

local Harness = require("@tests/harness")
local Daily = require("@src/logic/Daily")
local Enums = require("@src/types/Enums")

local DAY = 86400

return function(t: Harness.T)
	local H, F = Enums.Loop.Hunting, Enums.Loop.Fishing

	t.section("Daily — recordAction sets the per-loop objective; the cross-loop pair needs BOTH")
	do
		local d = { resetBasis = 100, huntDone = false, fishDone = false, claimed = false }
		Daily.recordAction(d, H, 200)
		t.ok("a kill satisfies the hunting objective", d.huntDone == true and d.fishDone == false)
		t.ok("one loop alone cannot claim the cross-loop pair", Daily.canClaimCrossLoop(d) == false)
		Daily.recordAction(d, F, 300)
		t.ok("a catch satisfies the fishing objective → the pair is claimable", d.fishDone == true and Daily.canClaimCrossLoop(d))
	end

	t.section("Daily — a new SERVER-day resets the objectives (never client elapsed)")
	do
		local d = { resetBasis = 100, huntDone = true, fishDone = true, claimed = true }
		Daily.maybeReset(d, 100 + 2 * DAY) -- two server-days later
		t.ok("the new window clears the day's objectives + claim", d.huntDone == false and d.fishDone == false and d.claimed == false)
		t.ok("the reset basis advanced to the new window", d.resetBasis == 100 + 2 * DAY)
	end

	t.section("Daily — within the same window, recordAction does NOT reset (same-day actions accumulate)")
	do
		local d = { resetBasis = 1000, huntDone = false, fishDone = false, claimed = false }
		Daily.recordAction(d, H, 1000 + 60) -- 60 s later, same day
		t.ok("a same-window action keeps the basis and the prior flags", d.resetBasis == 1000 and d.huntDone == true)
	end

	t.section("Daily — claimed blocks a re-claim within the window (idempotent per day)")
	do
		local d = { resetBasis = 100, huntDone = true, fishDone = true, claimed = false }
		t.ok("claimable before claiming", Daily.canClaimCrossLoop(d))
		d.claimed = true
		t.ok("not claimable once claimed this window", Daily.canClaimCrossLoop(d) == false)
	end
end
