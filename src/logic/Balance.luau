--!strict
-- PURE DERIVATION — Cash balance (economy / data-integrity §3). Cash is an APPEND-ONLY ledger; the
-- balance is a fold over signed entries, NEVER a stored mutable int. (The checkpoint+tail persistence
-- optimization is Step 2; here the in-memory ledger is the source.) Zero content literals.

local Schema = require("@src/types/Schema")

type PlayerData = Schema.PlayerData

local M = {}

function M.balanceOf(profile: PlayerData): number
	local sum = 0
	for _, entry in profile.cashLedger do
		sum += entry.amount
	end
	return sum
end

return M
