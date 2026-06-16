--!strict
local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Balance = require("@src/logic/Balance")

return function(t: Harness.T)
	t.section("Balance — derived as a fold over the append-only ledger")

	t.eq("empty ledger → 0", Balance.balanceOf(Util.mkProfile(Catalog, {})), 0)
	t.eq("single faucet → that amount", Balance.balanceOf(Util.mkProfile(Catalog, { ledger = { 4913 } })), 4913)
	t.eq("faucet/sink mix +100 −30 +5 → 75", Balance.balanceOf(Util.mkProfile(Catalog, { ledger = { 100, -30, 5 } })), 75)
	t.eq("all sinks → negative", Balance.balanceOf(Util.mkProfile(Catalog, { ledger = { -10, -20, -3000 } })), -3030)

	-- Balance is DERIVED: it depends only on the ledger, never on equipped gear or any stored int.
	local geared = Util.mkProfile(Catalog, { weapon = 4, armor = 4, rod = 4, reel = 4, ledger = { 6000, -6000 } })
	t.eq("balance ignores equipped gear; only the ledger counts", Balance.balanceOf(geared), 0)
end
