--!strict
-- Step 8 (Lodge & Trophy Hall) — the count-based slot/decor SCHEMA + the escalating slot-expansion price.
-- (The decor CATALOG load + the balance-free assertion are added in Task 2; the Trophy Hall view, the
-- salvage/display/sink flows, and the arrival branch have their own specs.)

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Economy = require("@src/logic/Economy")
local Profile = require("@src/logic/Profile")

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
end
