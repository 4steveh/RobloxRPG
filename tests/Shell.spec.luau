--!strict
local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Shells = require("@src/config/Shells")
local Shell = require("@src/logic/Shell")
local Ids = require("@src/types/Ids")

return function(t: Harness.T)
	local bayou = Shells.byDestination[Ids.Destination.Bayou]
	local WS = Shells.movement.walkSpeed

	t.section("Shell — the §2.3 named zones exist with stable ids")
	for _, zid in { "arrival_clearing", "sunny_levee", "reed_edges", "channel_banks", "catfish_hole", "cottonmouth_slough", "the_landing" } do
		t.ok("zone present + id stable: " .. zid, bayou.zones[zid] ~= nil and bayou.zones[zid].id == zid)
	end
	t.ok("arrivalZoneId resolves to a zone", bayou.zones[bayou.arrivalZoneId] ~= nil)

	t.section("Shell — §2.2 landmarks: the Landing + the Old Cypress beacon")
	t.ok("The Landing landmark present", bayou.landmarks.the_landing ~= nil)
	t.ok("The Old Cypress is the wayfinding beacon", bayou.landmarks.the_old_cypress ~= nil and bayou.landmarks.the_old_cypress.isBeacon == true)

	t.section("Shell — §2.6 layout constraints (measurable; sightlines/feel are Studio-only)")
	local arrival = Shell.arrivalAnchor(bayou)
	local landingWalk = Shell.walkSeconds(arrival, bayou.vendorOutpostAnchor, WS)
	t.ok("§2.6.2 The Landing is a ~15–20 s walk from arrival", landingWalk >= 14 and landingWalk <= 21)
	t.ok("§2.6.1 a channel bank is a few steps from arrival (< 40 studs)", Shell.horizontalDistance(arrival, bayou.zones.channel_banks.center) < 40)
	t.ok("§2.6.1 the arrival clearing faces the Sunny Levee (adjacent, < 70 studs)", Shell.horizontalDistance(arrival, bayou.zones.sunny_levee.center) < 70)
	t.ok("§2.6.3 the travel signpost is co-located with the vendor outpost", bayou.travelSignpostAnchor.x == bayou.vendorOutpostAnchor.x and bayou.travelSignpostAnchor.z == bayou.vendorOutpostAnchor.z)
	t.ok("§2.4 the whole map is crossable on foot well under a minute", Shell.crossingSeconds(bayou, WS) < 60)

	t.section("Shell — ambiance placed; TARGET species absent (Steps 4/5 own targets)")
	for cid, c in Catalog.creatures do
		if c.destinationId == "bayou" and c.ambianceOnly then
			local z = Shell.ambianceZoneOf(bayou, cid)
			t.ok("ambiance placed in a valid zone: " .. cid, z ~= nil and bayou.zones[z :: string] ~= nil)
		end
	end
	t.ok("no TARGET species in ambiancePlacements", (function()
		for sid in bayou.ambiancePlacements do
			local c = Catalog.creatures[sid]
			if c == nil or not c.ambianceOnly then
				return false
			end
		end
		return true
	end)())
	t.ok("a known TARGET (the Wood Duck) is NOT placed in the shell", bayou.ambiancePlacements["bayou_wood_duck"] == nil)

	t.section("Shell — validateShell rejects malformed shells (negative)")
	t.errs("placing a TARGET species is rejected", function()
		local bad = table.clone(bayou)
		bad.ambiancePlacements = { bayou_wood_duck = "sunny_levee" }
		Shell.validateShell(bad, Catalog)
	end)
	t.errs("a non-co-located travel signpost is rejected", function()
		local bad = table.clone(bayou)
		bad.travelSignpostAnchor = { x = 999, y = 0, z = 999 }
		Shell.validateShell(bad, Catalog)
	end)
	t.errs("an ambianceOnly species with NO home zone is rejected (coverage)", function()
		local bad = table.clone(bayou)
		bad.ambiancePlacements = { bayou_painted_turtle = "catfish_hole", bayou_songbird = "reed_edges" } -- egret unplaced
		Shell.validateShell(bad, Catalog)
	end)

	t.section("Shell — framework keyed by DestinationId (reusable for a 2nd Destination)")
	t.ok("the registry is keyed by DestinationId", bayou.destinationId == Ids.Destination.Bayou)
end
