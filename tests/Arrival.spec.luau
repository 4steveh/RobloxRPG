--!strict
local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Shells = require("@src/config/Shells")
local ArrivalService = require("@src/server/ArrivalService")
local Profile = require("@src/logic/Profile")
local Ids = require("@src/types/Ids")

return function(t: Harness.T)
	t.section("Arrival — login resolves to the Bayou arrival anchor (the gate-less root)")
	local p = Profile.freshProfile(Catalog)
	local a = ArrivalService.resolveArrival(p, Shells, Catalog)
	t.ok("destination is the Bayou (free-starter, requiredTier 0)", a.destinationId == Ids.Destination.Bayou)
	t.ok("zone is the arrival clearing", a.zoneId == "arrival_clearing")
	local clearing = Shells.byDestination[Ids.Destination.Bayou].zones.arrival_clearing
	t.ok("anchor is the arrival clearing center", a.anchor.x == clearing.center.x and a.anchor.z == clearing.center.z)

	t.section("Arrival — unconditional in Step 3 (returning→Lodge is Step 8)")
	local p2 = Profile.freshProfile(Catalog)
	p2.conqueredDestinations[Ids.Destination.Bayou] = true
	p2.unlockedDestinations[Ids.Destination.Appalachia] = true
	local a2 = ArrivalService.resolveArrival(p2, Shells, Catalog)
	t.ok("a progressed profile STILL arrives in the Bayou (no returning branch yet)", a2.destinationId == Ids.Destination.Bayou)
end
