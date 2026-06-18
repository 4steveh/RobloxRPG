--!strict
-- Step 12 — the two-profile atomic transaction: snapshot both, mutate both in one no-yield section, save both,
-- and restore BOTH on any save failure (the two-profile no-orphan / no-dupe substrate the swap rides).

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local PairTransaction = require("@src/server/authority/PairTransaction")

return function(t: Harness.T)
	t.section("PairTransaction — both saves ok: both mutations stick")
	do
		local a = Util.mkProfile(Catalog, { weapon = 1 })
		local b = Util.mkProfile(Catalog, { weapon = 1 })
		local r = PairTransaction.run(a, b, function(pa, pb)
			pa.hunterRankXP = 10
			pb.hunterRankXP = 20
		end, function()
			return true
		end, function()
			return true
		end)
		t.ok("ok", r.ok)
		t.eq("A mutated", a.hunterRankXP, 10)
		t.eq("B mutated", b.hunterRankXP, 20)
	end

	t.section("PairTransaction — B save fails: BOTH revert (all-or-nothing, no half-commit)")
	do
		local a = Util.mkProfile(Catalog, { weapon = 1 })
		local b = Util.mkProfile(Catalog, { weapon = 1 })
		local r = PairTransaction.run(a, b, function(pa, pb)
			pa.hunterRankXP = 10
			pb.hunterRankXP = 20
		end, function()
			return true
		end, function()
			return false
		end)
		t.ok("save_failed", r.ok == false and r.reason == "save_failed")
		t.eq("A reverted (even though A's save 'succeeded')", a.hunterRankXP, 0)
		t.eq("B reverted", b.hunterRankXP, 0)
	end

	t.section("PairTransaction — A save fails: BOTH revert; held references stay valid (identity preserved)")
	do
		local a = Util.mkProfile(Catalog, { weapon = 1 })
		local b = Util.mkProfile(Catalog, { weapon = 1 })
		local aRef = a -- a held reference (the session) must survive the revert
		local r = PairTransaction.run(a, b, function(pa, pb)
			pa.anglerRankXP = 5
			pb.anglerRankXP = 7
		end, function()
			return false
		end, function()
			return true
		end)
		t.ok("save_failed", r.ok == false)
		t.eq("A reverted via the SAME table (identity preserved)", aRef.anglerRankXP, 0)
		t.eq("B reverted", b.anglerRankXP, 0)
	end
end
