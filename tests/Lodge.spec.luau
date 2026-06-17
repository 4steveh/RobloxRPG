--!strict
-- Step 8 (Lodge & Trophy Hall) — the count-based slot/decor SCHEMA + the escalating slot-expansion price.
-- (The decor CATALOG load + the balance-free assertion are added in Task 2; the Trophy Hall view, the
-- salvage/display/sink flows, and the arrival branch have their own specs.)

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Economy = require("@src/logic/Economy")
local Profile = require("@src/logic/Profile")
local Validation = require("@src/config/Validation")
local Enums = require("@src/types/Enums")

return function(t: Harness.T)
	t.section("Lodge — freshProfile + mkProfile seed the count-based lodge state (slots 0, no decor, empty layout)")
	do
		local fresh = Profile.freshProfile(Catalog)
		t.ok("freshProfile has lodge state", fresh.lodge ~= nil)
		t.eq("no bought slots at start", fresh.lodge.boughtSlots, 0)
		t.eq("no owned decor at start", next(fresh.lodge.ownedDecor), nil)
		t.eq("empty decor layout at start", #fresh.lodge.placements, 0)
		local mk = Util.mkProfile(Catalog, {})
		t.ok("mkProfile also carries lodge state", mk.lodge ~= nil and mk.lodge.boughtSlots == 0)
	end

	t.section("Lodge — slotExpansionPrice is escalating + uncapped (base · growth^boughtSlots)")
	do
		t.eq("the 1st bought slot (boughtSlots 0) = base 5000", Economy.slotExpansionPrice(Catalog, 0), 5000)
		t.eq("the 2nd (boughtSlots 1) = round(5000·1.5) = 7500", Economy.slotExpansionPrice(Catalog, 1), 7500)
		t.eq("the 3rd (boughtSlots 2) = round(5000·1.5^2) = 11250", Economy.slotExpansionPrice(Catalog, 2), 11250)
		t.ok("strictly escalating (each costs more than the last — the unbounded sink)",
			Economy.slotExpansionPrice(Catalog, 5) > Economy.slotExpansionPrice(Catalog, 4))
	end

	t.section("Decor — the catalog loads, is non-empty, and every SKU is Cash-priced + balance-free")
	do
		local n = 0
		for id, d in Catalog.decor do
			n += 1
			t.ok(id .. ": id matches the key", d.id == id)
			t.ok(id .. ": Cash-priced (no real-money decor at MVL — Step 14)", (d.cost :: any).cash ~= nil)
			t.ok(id .. ": typed-owned (tradeable=false)", d.tradeable == false)
		end
		t.ok("the starter MVL decor catalog is non-empty (the sink must function)", n > 0)
	end

	t.section("Decor — assertDecorItem rejects a NON-balance-free SKU (the existing cosmetic discipline)")
	do
		t.errs("a decor with a non-identity (power-progression) role is rejected at load", function()
			Validation.assertDecorItem({
				id = "decor_bad", name = "Bad", kind = Enums.DecorKind.decor,
				cost = { cash = 100 }, tradeable = false,
				monetizationRoles = { Enums.MonetizationRole.powerProgression }, notes = "illegal",
			})
		end)
		t.errs("a real-money-priced decor is rejected here (real-money decor is Step 14)", function()
			Validation.assertDecorItem({
				id = "decor_rm", name = "RM", kind = Enums.DecorKind.decor,
				cost = { realMoney = { kind = Enums.RealMoneyKind.gamepass } }, tradeable = false,
				monetizationRoles = { Enums.MonetizationRole.identity }, notes = "illegal here",
			})
		end)
		t.errs("a tradeable decor is rejected here (tradeable = the rare-cosmetic artifact path)", function()
			Validation.assertDecorItem({
				id = "decor_tr", name = "Tr", kind = Enums.DecorKind.decor,
				cost = { cash = 100 }, tradeable = true,
				monetizationRoles = { Enums.MonetizationRole.identity }, notes = "illegal here",
			})
		end)
		t.errs("a decor with an EMPTY monetizationRoles set is rejected (an empty set would skip the identity-only rule)", function()
			Validation.assertDecorItem({
				id = "decor_empty", name = "Empty", kind = Enums.DecorKind.decor,
				cost = { cash = 100 }, tradeable = false,
				monetizationRoles = {}, notes = "illegal — bypasses the balance-free guarantee",
			})
		end)
	end
end
