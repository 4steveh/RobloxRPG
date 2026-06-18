--!strict
-- Step 12 — the TWO-PROFILE atomic transaction (parallel to the single-profile Transaction.run). Trading's
-- atomic swap touches BOTH traders' profiles; this snapshots both, runs the mutation as ONE no-yield section
-- over the pair, persists both, and — if EITHER save fails — restores BOTH in place (table identity kept, so
-- the held session references stay valid). All-or-nothing over both profiles: never a half-committed state.
-- The residual two-key CRASH window (key A persisted, server dies before key B) is NOT covered here — it is
-- closed by the two-sided trade record (TradeSwap writes it to both tradeLogs) + reconcile-on-reload (README).

local Copy = require("@src/server/persistence/Copy")
local Schema = require("@src/types/Schema")

type PlayerData = Schema.PlayerData

local M = {}

export type RunResult = { ok: boolean, reason: string? }

-- run(A, B, mutate, saveA, saveB): snapshot both → mutate(A, B) (no yield) → saveA() and saveB() →
-- if either failed, restore BOTH from snapshots and return save_failed; else ok.
function M.run(profileA: PlayerData, profileB: PlayerData, mutate: (PlayerData, PlayerData) -> (), saveA: () -> boolean, saveB: () -> boolean): RunResult
	local snapA = Copy.deep(profileA)
	local snapB = Copy.deep(profileB)
	mutate(profileA, profileB) -- atomic in-memory; the whole pair-pipeline is one synchronous section
	local okA = saveA()
	local okB = saveB()
	if not (okA and okB) then
		Copy.restoreInto(profileA :: any, snapA)
		Copy.restoreInto(profileB :: any, snapB)
		return { ok = false, reason = "save_failed" }
	end
	return { ok = true }
end

return M
