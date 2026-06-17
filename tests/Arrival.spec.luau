--!strict
local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Shells = require("@src/config/Shells")
local ArrivalService = require("@src/server/ArrivalService")
local Profile = require("@src/logic/Profile")
local Onboarding = require("@src/logic/Onboarding")
local Enums = require("@src/types/Enums")
local Ids = require("@src/types/Ids")

return function(t: Harness.T)
	t.section("Arrival — a first-time player lands in the Bayou arrival anchor (the gate-less root)")
	local p = Profile.freshProfile(Catalog)
	local a = ArrivalService.resolveArrival(p, Shells, Catalog)
	t.ok("kind is 'destination'", a.kind == "destination")
	t.ok("destination is the Bayou (free-starter, requiredTier 0)", a.destinationId == Ids.Destination.Bayou)
	t.ok("zone is the arrival clearing", a.zoneId == "arrival_clearing")
	local clearing = Shells.byDestination[Ids.Destination.Bayou].zones.arrival_clearing
	t.ok("anchor is the arrival clearing center", a.anchor.x == clearing.center.x and a.anchor.z == clearing.center.z)

	t.section("Arrival — a funnel-COMPLETE player lands in the LODGE (the Step-8 returning-player branch)")
	local p2 = Profile.freshProfile(Catalog)
	-- drive the funnel to COMPLETE the only way it can: authoritative events (no client flag).
	Onboarding.advance(p2, "kill", 1)
	Onboarding.advance(p2, "catch", 2)
	Onboarding.advance(p2, "gearUpgrade", 3)
	Onboarding.advance(p2, "worldMapOpen", 4) -- Step 9: WORLD_MAP is now a real beat
	Onboarding.advance(p2, "kill", 5)
	Onboarding.advance(p2, "kill", 6)
	Onboarding.advance(p2, "catch", 7)
	Onboarding.advance(p2, "dailyClaim", 8)
	t.ok("the funnel reached COMPLETE", Onboarding.isOnboardingComplete(p2))
	local a2 = ArrivalService.resolveArrival(p2, Shells, Catalog)
	t.ok("kind is 'lodge'", a2.kind == "lodge")
	t.ok("a COMPLETE player is NOT routed to a Destination (the Lodge is the hub, not a Destination)", a2.destinationId == nil)
	t.ok("the Lodge arrival zone + anchor come from Shells.lodge", a2.zoneId == Shells.lodge.zoneId and a2.anchor.z == Shells.lodge.anchor.z)

	t.section("resolveDestinationArrival — Appalachia fast-travel anchor")
	local ap = ArrivalService.resolveDestinationArrival("appalachia", Shells, Catalog)
	t.ok("kind is 'destination'", ap.kind == "destination")
	t.ok("destinationId is 'appalachia'", ap.destinationId == "appalachia")
	local apArrivalZone = Shells.byDestination["appalachia"].zones[Shells.byDestination["appalachia"].arrivalZoneId]
	t.ok("anchor equals Appalachia arrival-zone center", ap.anchor.x == apArrivalZone.center.x and ap.anchor.z == apArrivalZone.center.z)

	t.section("resolveDestinationArrival — Alaska fast-travel anchor (harbor_camp)")
	local ak = ArrivalService.resolveDestinationArrival("alaska", Shells, Catalog)
	t.ok("kind is 'destination'", ak.kind == "destination")
	t.ok("destinationId is 'alaska'", ak.destinationId == "alaska")
	local akArrivalZone = Shells.byDestination["alaska"].zones[Shells.byDestination["alaska"].arrivalZoneId]
	t.ok("anchor equals Alaska arrival-zone center (harbor_camp)", ak.anchor.x == akArrivalZone.center.x and ak.anchor.z == akArrivalZone.center.z)

	t.section("resolveDestinationArrival — unknown destination raises (no shell)")
	t.errs("deep_sea has no shell → assert fires", function()
		ArrivalService.resolveDestinationArrival("deep_sea", Shells, Catalog)
	end)
end
