--!strict
-- Headless test entry point: `luau tests/run.luau`. Aggregates every spec into one harness and exits
-- non-zero if any assertion failed (so CI / run-tests.sh can gate on it).

local Harness = require("@tests/harness")
local t = Harness.new("Wild World — Steps 1–7")

local specs: { (Harness.T) -> () } = {
	-- Step 1 (data model + pure logic)
	require("@tests/Catalog.spec"),
	require("@tests/EffectiveTier.spec"),
	require("@tests/Gate.spec"),
	require("@tests/Balance.spec"),
	require("@tests/Profile.spec"),
	require("@tests/Validation.spec"),
	-- Step 2 (persistence + server-authority substrate)
	require("@tests/ProfileStore.spec"),
	require("@tests/Ledger.spec"),
	require("@tests/ArtifactStore.spec"),
	require("@tests/Gauntlet.spec"),
	require("@tests/Idle.spec"),
	require("@tests/Integrity.spec"),
	-- Step 3 (movement + Bayou shell — the data/logic seams)
	require("@tests/Shell.spec"),
	require("@tests/Arrival.spec"),
	-- Step 4 (hunting — combat math, spawner, reward pipeline, fire handler)
	require("@tests/Combat.spec"),
	require("@tests/Spawner.spec"),
	require("@tests/RewardPipeline.spec"),
	require("@tests/FireHandler.spec"),
	-- Step 5 (fishing — catchability math, the shared pipeline extended, the spawner cap generalized)
	require("@tests/Fishing.spec"),
	require("@tests/CatchHandler.spec"),
	-- Step 6 (economy — the real formulas, the three-stub replacement, shops, reconciliation)
	require("@tests/Economy.spec"),
	require("@tests/ShopHandler.spec"),
	-- Step 7 (onboarding funnel — the server-owned state machine + the daily skeleton)
	require("@tests/Onboarding.spec"),
	require("@tests/Daily.spec"),
	require("@tests/ClaimDailyHandler.spec"),
	-- Step 8 (Lodge & Trophy Hall)
	require("@tests/Lodge.spec"),
	require("@tests/TrophyHall.spec"),
}

for _, spec in specs do
	spec(t)
end

-- The luau CLI sandbox has no os.exit; raise on failure so the process exits non-zero for CI.
if t.finish() ~= 0 then
	error("test failures (see the summary above)")
end
