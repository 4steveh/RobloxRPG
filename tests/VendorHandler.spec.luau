--!strict
-- Step 11 — the BoatDealer + Kennel & Stable vendors (the access sink + convenience sinks). The Step-6 atomic
-- buy pattern: server validates, debits the catalog's authored Cash price, grants the typed-owned commodity;
-- buy != equip; insufficient-funds rejects with no partial state; gear is not sold here (ShopHandler), real-
-- money packs are Step 14, and a tradeable rare breed (dog_redbone_rare) is trade-routed (Step 12), not bought.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Ledger = require("@src/server/ledger/Ledger")
local Gauntlet = require("@src/server/authority/Gauntlet")
local VendorHandler = require("@src/server/shop/VendorHandler")

return function(t: Harness.T)
	local telemetry = Fakes.newTelemetry()
	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, VendorHandler.buyHandler({ idGen = Fakes.newIdGenerator(), telemetry = telemetry }))
		return reg
	end
	local function deps(saveOk: boolean): Gauntlet.Deps
		return {
			config = Catalog,
			now = 100,
			saveFn = function()
				return saveOk
			end,
			markDirty = function() end,
			telemetry = Fakes.newTelemetry(),
		}
	end
	local function handle(p: any, payload: any, saveOk: boolean): Gauntlet.HandleResult
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		return Gauntlet.handle(newReg(), { intent = "buyVendorItem", playerId = 1, payload = payload }, session, deps(saveOk))
	end
	local function owns(p: any, catalogId: string): boolean
		for _, c in p.inventory.commodities do
			if c.catalogId == catalogId then
				return true
			end
		end
		return false
	end

	t.section("Vendor — buy the Coastal Skiff: debits 18000 + mints the (unequipped) access commodity")
	do
		local p = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 20000 } })
		local before = #p.inventory.commodities
		local r = handle(p, { itemId = "vehicle_coastal_skiff" }, true)
		t.ok("the Skiff buy succeeds", r.ok)
		t.eq("debited the authored Cash price 18000 (20000 -> 2000)", Ledger.balanceOf(p.cash), 2000)
		t.eq("a new commodity was minted", #p.inventory.commodities, before + 1)
		t.ok("the Skiff is owned", owns(p, "vehicle_coastal_skiff"))
		t.ok("the minted Skiff is NOT equipped (buy != equip; ownership is what gates)", (function()
			for _, c in p.inventory.commodities do
				if c.catalogId == "vehicle_coastal_skiff" then
					return c.equipped == false
				end
			end
			return false
		end)())
		local tagged = false
		for _, e in p.cash.tail do
			if e.type == "vehicle" then
				tagged = true
			end
		end
		t.ok("the ledger entry is tagged 'vehicle' (the access-sink telemetry)", tagged)
	end

	t.section("Vendor — buy a mount + a basic dog (the convenience sinks)")
	do
		local p = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 20000 } })
		t.ok("the Horse buy succeeds (10200)", handle(p, { itemId = "mount_horse" }, true).ok)
		t.eq("debited 10200 (20000 -> 9800)", Ledger.balanceOf(p.cash), 9800)
		t.ok("a Coonhound buy succeeds (8000)", handle(p, { itemId = "dog_coonhound" }, true).ok)
		t.eq("debited 8000 (9800 -> 1800)", Ledger.balanceOf(p.cash), 1800)
		t.ok("the mount is owned", owns(p, "mount_horse"))
		t.ok("the dog is owned", owns(p, "dog_coonhound"))
	end

	t.section("Vendor — rejections: gear is not sold here, the rare dog is trade-routed, insufficient funds")
	do
		-- gating gear (Outfitter/TackleShop) is ShopHandler's, not this vendor
		local pGear = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 99999 } })
		local rGear = handle(pGear, { itemId = "weapon_lever_action_rifle" }, true)
		t.ok("gear is rejected (not_sold_here)", rGear.ok == false and rGear.reason == "not_sold_here")

		-- the tradeable rare breed routes to the Trading Post (Step 12), never a Cash buy
		local pRare = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 99999 } })
		local before = #pRare.inventory.commodities
		local rRare = handle(pRare, { itemId = "dog_redbone_rare" }, true)
		t.ok("the rare dog is rejected (rare_trade_routed)", rRare.ok == false and rRare.reason == "rare_trade_routed")
		t.eq("no commodity minted for the rare dog", #pRare.inventory.commodities, before)

		-- unknown item
		t.ok("an unknown item is rejected", handle(pGear, { itemId = "nope" }, true).reason == "unknown_item")

		-- insufficient funds: no debit, no mint
		local pPoor = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 100 } })
		local poorBefore = #pPoor.inventory.commodities
		local rPoor = handle(pPoor, { itemId = "vehicle_coastal_skiff" }, true)
		t.ok("rejected: insufficient funds", rPoor.ok == false and rPoor.reason == "insufficient_funds")
		t.eq("no Cash debited", Ledger.balanceOf(pPoor.cash), 100)
		t.eq("no commodity minted", #pPoor.inventory.commodities, poorBefore)
	end

	t.section("Vendor — the buy is atomic: a failed write reverts the debit + the grant (no orphan)")
	do
		local p = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 20000 } })
		local before = #p.inventory.commodities
		local r = handle(p, { itemId = "vehicle_coastal_skiff" }, false)
		t.ok("persist_failed", r.ok == false and r.reason == "persist_failed")
		t.eq("Cash reverted", Ledger.balanceOf(p.cash), 20000)
		t.eq("no orphan commodity", #p.inventory.commodities, before)
	end

	t.section("Vendor — the marquee Coastal-Skiff purchase telemetry fires")
	do
		-- the telemetry fake is shared across sections, so assert the DELTA from this one buy (not an absolute).
		local before = (telemetry.snapshot() :: any)["economy.buy:coastalSkiff"] or 0
		local p = Util.mkProfile(Catalog, { rod = 1, reel = 1, ledger = { 20000 } })
		handle(p, { itemId = "vehicle_coastal_skiff" }, true)
		local after = (telemetry.snapshot() :: any)["economy.buy:coastalSkiff"] or 0
		t.ok("the coastalSkiff purchase counter incremented by exactly 1", after - before == 1)
	end
end
