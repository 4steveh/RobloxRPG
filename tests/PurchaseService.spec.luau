--!strict
-- Step 14 — the real-money grant logic (the headless half of the MarketplaceService boundary): the
-- currency-pack idempotent inject (ONCE per Roblox PurchaseId; a re-delivered receipt is a no-op), the boost
-- / premium-pack / game-pass grants, game-pass OWNERSHIP idempotency, and the PAY-PROOF property (NO grant
-- writes the conquest set — bought Cash hits the same milestone wall idle Cash does).

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Enums = require("@src/types/Enums")
local Ledger = require("@src/server/ledger/Ledger")
local Monetization = require("@src/logic/Monetization")
local PurchaseService = require("@src/server/monetization/PurchaseService")
local Fakes = require("@src/server/persistence/Fakes")

return function(t: Harness.T)
	local P = Catalog.products
	local MON = Catalog.tuning.monetization

	t.section("§C currency pack — atomic currencypack inject, idempotent per PurchaseId")
	do
		local p = Util.mkProfile(Catalog, {})
		local pack = P.pack_cash_small
		local amount = (pack.grant :: any).amount
		local r1 = PurchaseService.processReceipt(p, Catalog, pack, "PURCH-1", 100, Fakes.newTelemetry())
		t.ok("first delivery grants", r1.granted and not r1.alreadyGranted)
		t.eq("balance rose by the pack amount", Ledger.balanceOf(p.cash), amount)
		t.eq("exactly one ledger entry", #p.cash.tail, 1)
		t.ok("the entry is currencypack-tagged real money, keyed on the PurchaseId", p.cash.tail[1].type == "currencypack" and p.cash.tail[1].realMoneyTag == "realmoney:currencypack" and p.cash.tail[1].validatingEventId == "PURCH-1")
		-- ProcessReceipt RE-FIRES: a re-delivered receipt with the SAME PurchaseId grants nothing twice
		local r2 = PurchaseService.processReceipt(p, Catalog, pack, "PURCH-1", 200, Fakes.newTelemetry())
		t.ok("re-delivery is a no-op (alreadyGranted)", (not r2.granted) and r2.alreadyGranted)
		t.eq("…still exactly one entry (no double-credit)", #p.cash.tail, 1)
		t.eq("…balance unchanged on re-delivery", Ledger.balanceOf(p.cash), amount)
		-- a DIFFERENT PurchaseId for the same product grants again (a second genuine purchase)
		local r3 = PurchaseService.processReceipt(p, Catalog, pack, "PURCH-2", 300, Fakes.newTelemetry())
		t.ok("a new PurchaseId grants again", r3.granted)
		t.eq("…two entries now", #p.cash.tail, 2)
	end

	t.section("§D the 2x boost dev-product grants a time-limited multiplier entitlement")
	do
		local p = Util.mkProfile(Catalog, {})
		PurchaseService.processReceipt(p, Catalog, P.boost_2x_cash, "B-1", 100, nil)
		t.eq("the active multiplier is now 2x", Monetization.activeCashMultiplier(Catalog, p, 100), MON.multipliers["2xBoost"])
		t.eq("…and reverts to 1.0 after the boost window (server time)", Monetization.activeCashMultiplier(Catalog, p, 100 + MON.boostDurationSeconds + 1), 1.0)
		-- re-buying the boost REFRESHES (it does not silently stack the SAME boost to 4x)
		PurchaseService.processReceipt(p, Catalog, P.boost_2x_cash, "B-2", 200, nil)
		t.eq("re-buying refreshes, never stacks the SAME boost", Monetization.activeCashMultiplier(Catalog, p, 200), MON.multipliers["2xBoost"])
	end

	t.section("§A premium-bait dev-product pack grants a fungible stack (not a commodity)")
	do
		local p = Util.mkProfile(Catalog, {})
		local qty = (P.devproduct_premium_lure_pack.grant :: any).quantity
		PurchaseService.processReceipt(p, Catalog, P.devproduct_premium_lure_pack, "L-1", 100, nil)
		t.eq("the premium lure stack landed in inventory.fungible", p.inventory.fungible.bait_premium_lure, qty)
		t.eq("no commodity minted for a fungible grant", #p.inventory.commodities, 0)
	end

	t.section("§E game-pass Boat tier — grants the existing Boat item, ownership-idempotent")
	do
		local p = Util.mkProfile(Catalog, {})
		local r1 = PurchaseService.grantGamePass(p, Catalog, P.gamepass_coastal_skiff, 0, nil)
		t.ok("first ownership check grants the Skiff", r1.granted and not r1.alreadyOwned)
		local count = 0
		for _, c in p.inventory.commodities do
			if c.catalogId == "vehicle_coastal_skiff" then
				count += 1
			end
		end
		t.eq("the Coastal Skiff commodity is owned (access, not power)", count, 1)
		-- calling again every login is idempotent — no duplicate grant
		local r2 = PurchaseService.grantGamePass(p, Catalog, P.gamepass_coastal_skiff, 0, nil)
		t.ok("re-checking ownership is a no-op (alreadyOwned)", (not r2.granted) and r2.alreadyOwned)
		local count2 = 0
		for _, c in p.inventory.commodities do
			if c.catalogId == "vehicle_coastal_skiff" then
				count2 += 1
			end
		end
		t.eq("exactly one Skiff (no duplicate on re-login)", count2, 1)
	end

	t.section("§E game-pass flagship cosmetic — balance-free identity grant")
	do
		local p = Util.mkProfile(Catalog, {})
		PurchaseService.grantGamePass(p, Catalog, P.gamepass_founders_skin, 0, nil)
		local item = Catalog.equipment.cosmetic_founders_skin
		t.ok("the cosmetic is balance-free (cosmeticOnly, no stats)", item.cosmeticOnly and item.tierInput == false)
		local owned = false
		for _, c in p.inventory.commodities do
			if c.catalogId == "cosmetic_founders_skin" then
				owned = true
			end
		end
		t.ok("the founder's skin commodity is owned", owned)
	end

	t.section("§E VIP game pass — persistent multiplier, idempotent on ownership")
	do
		local p = Util.mkProfile(Catalog, {})
		PurchaseService.grantGamePass(p, Catalog, P.vip_pass, 0, nil)
		t.eq("VIP multiplier active", Monetization.activeCashMultiplier(Catalog, p, 0), MON.multipliers.vip)
		t.ok("VIP persists (no expiry — a game pass is owned)", Monetization.activeCashMultiplier(Catalog, p, 10 ^ 12) == MON.multipliers.vip)
		local r2 = PurchaseService.grantGamePass(p, Catalog, P.vip_pass, 0, nil)
		t.ok("re-granting VIP on login is a no-op", (not r2.granted) and r2.alreadyOwned)
		local n = 0
		for _, e in p.activeEntitlements do
			if e.kind == Monetization.multiplierEntitlementKind(Enums.CashMultiplier.vip) then
				n += 1
			end
		end
		t.eq("exactly one VIP entitlement (no pile-up across logins)", n, 1)
	end

	t.section("§B pay-proof — NO grant writes the conquest/unlock set (the milestone is played, never bought)")
	do
		for id, product in P do
			local p = Util.mkProfile(Catalog, {})
			if product.kind == Enums.RealMoneyKind.devproduct then
				PurchaseService.processReceipt(p, Catalog, product, "PP-" .. id, 0, nil)
			else
				PurchaseService.grantGamePass(p, Catalog, product, 0, nil)
			end
			t.ok(id .. ": the purchase wrote NO conquest (pay-proof — bought Cash hits the milestone wall)", next(p.conqueredDestinations) == nil)
			t.ok(id .. ": …and no unlocked Destination (Cash buys the purchasable half, never the milestone)", next(p.unlockedDestinations) == nil)
		end
	end
end
