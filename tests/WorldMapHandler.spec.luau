--!strict
-- Step 9 — opening the World Map (the Travel Desk) is the server-authoritative event that completes the
-- WORLD_MAP funnel beat (Step 7's pass-through made real) AND runs the commitUnlocks catch-all.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Onboarding = require("@src/logic/Onboarding")
local WorldMapHandler = require("@src/server/progression/WorldMapHandler")
local Ids = require("@src/types/Ids")

local D = Ids.Destination

return function(t: Harness.T)
	local function openMap(p: any, saveOk: boolean): Gauntlet.HandleResult
		local reg = Gauntlet.new()
		Gauntlet.register(reg, WorldMapHandler.new({ telemetry = Fakes.newTelemetry() }))
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		return Gauntlet.handle(reg, { intent = "openWorldMap", playerId = 1, payload = {} }, session, {
			config = Catalog, now = 100, saveFn = function() return saveOk end, markDirty = function() end, telemetry = Fakes.newTelemetry(),
		})
	end

	t.section("WorldMap — opening the map at the WORLD_MAP beat completes it (the reveal beat made real)")
	do
		local p = Util.mkProfile(Catalog, {})
		p.onboarding.funnelBeat = "WORLD_MAP"
		t.ok("the open succeeds", openMap(p, true).ok)
		t.ok("the WORLD_MAP beat advanced past (no longer WORLD_MAP)", p.onboarding.funnelBeat ~= "WORLD_MAP")
	end

	t.section("WorldMap — opening the map runs the commitUnlocks catch-all")
	do
		local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, conquered = { D.Bayou } }) -- qualifies for Appalachia
		t.ok("Appalachia not yet committed", p.unlockedDestinations[D.Appalachia] == nil)
		assert(openMap(p, true).ok)
		t.ok("opening the map committed the pending unlock (the catch-all)", p.unlockedDestinations[D.Appalachia] == true)
	end
end
