--!strict
-- Step 8 — the evergreen Cash sink (SYS_economy §9 inflation ballast). Buying a slot (escalating price) or a
-- decor SKU is a normal atomic ledger sink: debit Cash, grant the count-based owned slot/decor, server-
-- authoritative (the client never asserts ownership), tagged for the evergreen-sink telemetry. Insufficient
-- funds rejects with NO partial state; a failed write reverts both (no orphan). Placement is cosmetic layout.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Ledger = require("@src/server/ledger/Ledger")
local Economy = require("@src/logic/Economy")
local Gauntlet = require("@src/server/authority/Gauntlet")
local LodgeShopHandler = require("@src/server/lodge/LodgeShopHandler")

return function(t: Harness.T)
	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, LodgeShopHandler.buySlotHandler({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
		Gauntlet.register(reg, LodgeShopHandler.buyDecorHandler({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
		Gauntlet.register(reg, LodgeShopHandler.placeDecorHandler({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
		return reg
	end
	local function handle(p: any, intent: string, payload: any, saveOk: boolean): Gauntlet.HandleResult
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		local deps: Gauntlet.Deps = { config = Catalog, now = 100, saveFn = function() return saveOk end, markDirty = function() end, telemetry = Fakes.newTelemetry() }
		return Gauntlet.handle(newReg(), { intent = intent, playerId = 1, payload = payload }, session, deps)
	end

	t.section("Sink — buySlot debits the escalating price + grants a count-based slot (server-authoritative)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 20000 } })
		local r1 = handle(p, "buySlot", {}, true)
		t.ok("the 1st slot buy succeeds", r1.ok)
		t.eq("debited slotExpansionPrice(0) = 5000 (20000 → 15000)", Ledger.balanceOf(p.cash), 15000)
		t.eq("boughtSlots is now 1", p.lodge.boughtSlots, 1)
		local r2 = handle(p, "buySlot", {}, true)
		t.ok("the 2nd slot buy succeeds", r2.ok)
		t.eq("debited the ESCALATING price(1) = 7500 (15000 → 7500)", Ledger.balanceOf(p.cash), 7500)
		t.eq("boughtSlots is now 2", p.lodge.boughtSlots, 2)
	end

	t.section("Sink — buySlot insufficient funds rejects with NO partial state")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 100 } })
		local r = handle(p, "buySlot", {}, true)
		t.ok("rejected: insufficient funds", r.ok == false and r.reason == "insufficient_funds")
		t.eq("no Cash debited", Ledger.balanceOf(p.cash), 100)
		t.eq("no slot granted", p.lodge.boughtSlots, 0)
	end

	t.section("Sink — buySlot is atomic: a failed write reverts the debit + the grant (no orphan)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 20000 } })
		local r = handle(p, "buySlot", {}, false)
		t.ok("persist_failed", r.ok == false and r.reason == "persist_failed")
		t.eq("Cash reverted", Ledger.balanceOf(p.cash), 20000)
		t.eq("no orphan slot", p.lodge.boughtSlots, 0)
	end

	t.section("Sink — buyDecor debits Cash + grants the count-based owned decor (evergreen-tagged ledger entry)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 1000 } })
		local r = handle(p, "buyDecor", { itemId = "decor_rustic_rug" }, true)
		t.ok("the decor buy succeeds", r.ok)
		t.eq("debited the rug's Cash price 500 (1000 → 500)", Ledger.balanceOf(p.cash), 500)
		t.eq("owned-decor count for the rug is 1", p.lodge.ownedDecor["decor_rustic_rug"], 1)
		-- the sink is tagged: the ledger tail carries a "decor" sink entry
		local tagged = false
		for _, e in p.cash.tail do
			if e.type == "decor" then
				tagged = true
			end
		end
		t.ok("the ledger entry is tagged 'decor' for the evergreen-sink telemetry", tagged)
	end

	t.section("Sink — buyDecor: unknown SKU + insufficient funds reject cleanly")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 100 } })
		t.ok("an unknown decor id is rejected", handle(p, "buyDecor", { itemId = "decor_nope" }, true).ok == false)
		t.ok("insufficient funds rejected (rug 500 > balance 100)", handle(p, "buyDecor", { itemId = "decor_rustic_rug" }, true).ok == false)
		t.eq("no decor granted on rejection", next(p.lodge.ownedDecor), nil)
	end

	t.section("Sink — placeDecor requires ownership; records the cosmetic layout")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 1000 } })
		t.ok("placing un-owned decor is rejected", handle(p, "placeDecor", { itemId = "decor_rustic_rug", slotKey = "wall_1" }, true).ok == false)
		assert(handle(p, "buyDecor", { itemId = "decor_rustic_rug" }, true).ok)
		t.ok("placing owned decor succeeds", handle(p, "placeDecor", { itemId = "decor_rustic_rug", slotKey = "wall_1" }, true).ok)
		t.eq("one placement recorded", #p.lodge.placements, 1)
		t.ok("the placement points at the owned decor + its layout slot", p.lodge.placements[1].itemId == "decor_rustic_rug" and p.lodge.placements[1].slotKey == "wall_1")
	end
end
