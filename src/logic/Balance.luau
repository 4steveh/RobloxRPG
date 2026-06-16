--!strict
-- PURE DERIVATION — Cash balance (economy / data-integrity §3). Cash is an APPEND-ONLY ledger; the
-- balance is a fold over signed entries, NEVER a stored mutable int. (The checkpoint+tail persistence
-- optimization is Step 2; here the in-memory ledger is the source.) Zero content literals.

local Schema = require("@src/types/Schema")

type PlayerData = Schema.PlayerData

local M = {}

-- balance = checkpoint (sum of compacted/offloaded entries) + Σ(tail). Never a stored mutable int.
-- (The checkpoint + bounded-tail storage layout is §3's Roblox concession; the invariant — balance is
-- a fold over entries — is preserved exactly. Compaction/offload is owned by the Step 2 Ledger.)
function M.balanceOf(profile: PlayerData): number
	local sum = profile.cash.checkpoint.balance
	for _, entry in profile.cash.tail do
		sum += entry.amount
	end
	return sum
end

return M
