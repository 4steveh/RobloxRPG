--!strict
-- ATOMIC MULTI-MUTATION TRANSACTION (§2 step 4 + §7). A single validated event can drive several
-- mutations (combat's reward pipeline: ledger entry + Rank XP + artifact mint + conquest flag). They
-- commit as ONE atomic in-memory unit, then ONE write-through. A crash cannot split it: if the durable
-- write fails, the in-memory profile is REVERTED to the pre-transaction snapshot — neither half lands.
-- This module builds the abstraction; the pipeline CONTENTS are Steps 4/5/6.

local Schema = require("../../types/Schema")
local Copy = require("../persistence/Copy")

type PlayerData = Schema.PlayerData

local M = {}

export type RunResult = { ok: boolean, reason: string? }

-- run(profile, mutate, saveFn):
--   1. snapshot the profile (deep copy)
--   2. apply ALL mutations synchronously (mutate must not yield — the no-yield commit, §build-notes)
--   3. write-through (saveFn persists the whole profile; returns ok)
--   4. on save failure: revert the profile in place to the snapshot (revert-to-last-good; no orphan)
-- The profile table keeps its identity across the revert, so a held reference (the session) stays valid.
function M.run(profile: PlayerData, mutate: (PlayerData) -> (), saveFn: () -> boolean): RunResult
	local snapshot = Copy.deep(profile)
	mutate(profile) -- atomic in-memory; the whole pipeline is one synchronous section
	local ok = saveFn()
	if not ok then
		Copy.restoreInto(profile :: any, snapshot)
		return { ok = false, reason = "save_failed" }
	end
	return { ok = true }
end

return M
