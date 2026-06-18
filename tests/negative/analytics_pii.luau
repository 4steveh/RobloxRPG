--!strict
-- NEGATIVE FIXTURE — MUST FAIL `luau-analyze`. Analytics events are BEHAVIORAL (a 13+ audience / platform
-- policy): the `Analytics.Event` record carries category/name/value + the loop/tier dimensions ONLY — there
-- is NO personal field. Reading PII off an event is therefore unrepresentable, the structural privacy
-- guarantee (the same class as the pay-proof closed union and the cosmetic no-stats field).
local Analytics = require("@src/logic/Analytics")

-- ← type error: `playerName` is a field of no Event (the event stream carries no PII; it is keyed by an
-- opaque player id ELSEWHERE, never a personal field inside the behavioral record).
local function readsPII(e: Analytics.Event): any
	return e.playerName
end

return readsPII
