--!strict
-- Headless test entry point: `luau tests/run.luau`. Aggregates every spec into one harness and exits
-- non-zero if any assertion failed (so CI / run-tests.sh can gate on it).

local Harness = require("@tests/harness")
local t = Harness.new("Wild World — Step 1")

local specs: { (Harness.T) -> () } = {
	require("@tests/Catalog.spec"),
	require("@tests/EffectiveTier.spec"),
	require("@tests/Gate.spec"),
	require("@tests/Balance.spec"),
	require("@tests/Profile.spec"),
	require("@tests/Validation.spec"),
}

for _, spec in specs do
	spec(t)
end

-- The luau CLI sandbox has no os.exit; raise on failure so the process exits non-zero for CI.
if t.finish() ~= 0 then
	error("test failures (see the summary above)")
end
