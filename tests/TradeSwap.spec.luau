--!strict
-- Step 12 — the rigor-critical core: a successful two-sided swap moves each artifact LIVE to its new owner and
-- TOMBSTONES the old, applies the tradepay-out/tradepay-in/tradetax triple, writes the trade record to both;
-- a forced CAS mismatch transfers NOTHING (both unchanged); a forced save failure reverts BOTH profiles.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Ledger = require("@src/server/ledger/Ledger")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local TradeSwap = require("@src/server/trading/TradeSwap")

return function(t: Harness.T)
	-- ONE shared mint generator across the whole spec → globally-distinct artifact ids (the game mints from a
	-- single monotonic generator; a fresh generator per mint would collide a1 and b1 on the same id).
	local mintGen = Fakes.newIdGenerator()
	local function owner(ledger: number): any
		return Util.mkProfile(Catalog, { ledger = { ledger } })
	end
	local function mintEscrowed(p: any, key: string, sourceId: string): string
		local a = ArtifactStore.mint(p, { kind = "trophy", tradeable = true, owner = key, sourceId = sourceId, validatingEventId = "ev" }, mintGen, 1)
		assert(ArtifactStore.transition(p, a.artifactId, "HELD", "ESCROWED").ok)
		return a.artifactId
	end
	local function args(pa, pb, aIds, bIds, payer, gross, saveA, saveB): any
		return {
			aProfile = pa, bProfile = pb, aOwner = "u1", bOwner = "u2", aArtifactIds = aIds, bArtifactIds = bIds,
			payer = payer, cashGross = gross, config = Catalog, idGen = Fakes.newIdGenerator(), now = 100,
			saveA = saveA, saveB = saveB, telemetry = Fakes.newTelemetry(),
		}
	end

	t.section("TradeSwap — a successful item-for-item-plus-Cash swap: live to new, tombstone old, tax triple")
	do
		local pa = owner(5000) -- A pays 1000 Cash + gives item a1
		local pb = owner(0)
		local a1 = mintEscrowed(pa, "u1", "bayou_white_alligator")
		local b1 = mintEscrowed(pb, "u2", "bayou_leviathan")
		local r = TradeSwap.commit(args(pa, pb, { a1 }, { b1 }, "a", 1000, function() return true end, function() return true end))
		t.ok("the swap succeeds", r.ok)
		t.ok("a1 LIVE in B (owner u2, HELD, owned)", pb.artifacts[a1].owner == "u2" and pb.artifacts[a1].disposition == "HELD" and pb.inventory.artifactIds[a1] == true)
		t.ok("a1 TOMBSTONED in A, not in A's owned set", pa.artifacts[a1].tombstoned == true and pa.inventory.artifactIds[a1] == nil)
		t.ok("b1 LIVE in A (owner u1)", pa.artifacts[b1].owner == "u1" and pa.inventory.artifactIds[b1] == true)
		t.ok("b1 TOMBSTONED in B", pb.artifacts[b1].tombstoned == true and pb.inventory.artifactIds[b1] == nil)
		t.ok("no artifact LIVE in two profiles", (pa.inventory.artifactIds[a1] == nil) and (pb.inventory.artifactIds[b1] == nil))
		t.eq("tax = 50", r.tax, 50)
		t.eq("payer A debited gross (5000→4000)", Ledger.balanceOf(pa.cash), 4000)
		t.eq("payee B credited gross−tax (0→950)", Ledger.balanceOf(pb.cash), 950)
		t.eq("A tradeLog has the record", #pa.tradeLog, 1)
		t.eq("B tradeLog has the record", #pb.tradeLog, 1)
		t.ok("the record carries both sides + tax", pa.tradeLog[1].tax == 50 and pa.tradeLog[1].cashGross == 1000 and #pa.tradeLog[1].aArtifactIds == 1 and #pa.tradeLog[1].bArtifactIds == 1)
	end

	t.section("TradeSwap — zero-Cash item-for-item: zero tax, no Cash legs")
	do
		local pa = owner(0)
		local pb = owner(0)
		local a1 = mintEscrowed(pa, "u1", "bayou_white_alligator")
		local b1 = mintEscrowed(pb, "u2", "bayou_leviathan")
		local r = TradeSwap.commit(args(pa, pb, { a1 }, { b1 }, "none", 0, function() return true end, function() return true end))
		t.ok("succeeds", r.ok)
		t.eq("zero tax", r.tax, 0)
		t.eq("no Cash moved A", Ledger.balanceOf(pa.cash), 0)
		t.eq("no Cash moved B", Ledger.balanceOf(pb.cash), 0)
	end

	t.section("TradeSwap — forced CAS mismatch: one artifact NOT escrowed → nothing transfers, both unchanged")
	do
		local pa = owner(0)
		local pb = owner(0)
		local a1 = mintEscrowed(pa, "u1", "bayou_white_alligator")
		local b = ArtifactStore.mint(pb, { kind = "trophy", tradeable = true, owner = "u2", sourceId = "bayou_leviathan", validatingEventId = "ev" }, mintGen, 1)
		local b1 = b.artifactId -- left HELD (not escrowed) → the swap's ESCROWED precondition fails
		local r = TradeSwap.commit(args(pa, pb, { a1 }, { b1 }, "none", 0, function() return true end, function() return true end))
		t.ok("the commit fails (CAS mismatch)", r.ok == false)
		t.ok("a1 untouched: still ESCROWED in A, not in B", pa.artifacts[a1].disposition == "ESCROWED" and pa.inventory.artifactIds[a1] == true and pb.artifacts[a1] == nil)
		t.ok("b1 untouched: still HELD in B, not tombstoned", pb.artifacts[b1].disposition == "HELD" and pb.artifacts[b1].tombstoned == false)
		t.ok("nothing written to either tradeLog", #pa.tradeLog == 0 and #pb.tradeLog == 0)
	end

	t.section("TradeSwap — forced save failure: BOTH profiles revert (no dupe, no orphan)")
	do
		local pa = owner(5000)
		local pb = owner(0)
		local a1 = mintEscrowed(pa, "u1", "bayou_white_alligator")
		local b1 = mintEscrowed(pb, "u2", "bayou_leviathan")
		local r = TradeSwap.commit(args(pa, pb, { a1 }, { b1 }, "a", 1000, function() return true end, function() return false end))
		t.ok("the commit fails (save_failed)", r.ok == false and r.reason == "save_failed")
		t.ok("a1 reverted: still ESCROWED+owned in A, NOT in B", pa.artifacts[a1].disposition == "ESCROWED" and pa.inventory.artifactIds[a1] == true and pb.inventory.artifactIds[a1] == nil)
		t.ok("b1 reverted: still ESCROWED+owned in B, NOT in A", pb.artifacts[b1].disposition == "ESCROWED" and pb.inventory.artifactIds[b1] == true and pa.inventory.artifactIds[b1] == nil)
		t.eq("A Cash reverted", Ledger.balanceOf(pa.cash), 5000)
		t.eq("B Cash reverted", Ledger.balanceOf(pb.cash), 0)
		t.ok("no orphan trade record", #pa.tradeLog == 0 and #pb.tradeLog == 0)
	end

	t.section("TradeSwap — a pure-Cash trade (no artifacts) is rejected at the primitive (|items| ≥ 1)")
	do
		local pa = owner(5000)
		local pb = owner(0)
		local r = TradeSwap.commit(args(pa, pb, {}, {}, "a", 1000, function() return true end, function() return true end))
		t.ok("rejected: no_items", r.ok == false and r.reason == "no_items")
		t.eq("no Cash moved", Ledger.balanceOf(pa.cash), 5000)
	end

	t.section("TradeSwap — insufficient payer balance is rejected before any mutation")
	do
		local pa = owner(100) -- can't afford 1000
		local pb = owner(0)
		local a1 = mintEscrowed(pa, "u1", "bayou_white_alligator")
		local r = TradeSwap.commit(args(pa, pb, { a1 }, {}, "a", 1000, function() return true end, function() return true end))
		t.ok("rejected: insufficient_funds", r.ok == false and r.reason == "insufficient_funds")
		t.ok("a1 untouched (still escrowed in A)", pa.artifacts[a1].disposition == "ESCROWED" and pa.inventory.artifactIds[a1] == true)
	end
end
