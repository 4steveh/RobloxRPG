--!strict
-- Step 8 — mount = HELD→DISPLAYED CAS; take-down = DISPLAYED→HELD CAS. No Cash moves. Slot capacity is a
-- precondition on the mount (a player cannot display more trophies than owned slots — the sink pull). A
-- non-trophy → DISPLAYED is rejected (§4). A DISPLAYED trophy has no direct trade path: it must be taken
-- down first (the take-down-to-trade handoff; escrow/swap is Step 12). These CALL the §4 CAS, never rebuild it.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local TrophyHall = require("@src/logic/TrophyHall")
local Gauntlet = require("@src/server/authority/Gauntlet")
local DisplayHandler = require("@src/server/lodge/DisplayHandler")

return function(t: Harness.T)
	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, DisplayHandler.mountHandler({ telemetry = Fakes.newTelemetry() }))
		Gauntlet.register(reg, DisplayHandler.takeDownHandler({ telemetry = Fakes.newTelemetry() }))
		return reg
	end
	local function deps(saveOk: boolean): Gauntlet.Deps
		return { config = Catalog, now = 100, saveFn = function() return saveOk end, markDirty = function() end, telemetry = Fakes.newTelemetry() }
	end
	local function handle(p: any, intent: string, payload: any): Gauntlet.HandleResult
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		return Gauntlet.handle(newReg(), { intent = intent, playerId = 1, payload = payload }, session, deps(true))
	end
	local idGen = Fakes.newIdGenerator()
	local function mintTrophy(p, sourceId)
		return ArtifactStore.mint(p, { kind = "trophy", tradeable = true, owner = "u1", sourceId = sourceId, validatingEventId = "ev" }, idGen, 1)
	end

	t.section("Display — mount HELD→DISPLAYED, take-down DISPLAYED→HELD (no Cash moves; re-render the view)")
	do
		local p = Util.mkProfile(Catalog, {})
		local a = mintTrophy(p, "bayou_white_alligator")
		t.ok("mount succeeds", handle(p, "mountTrophy", { artifactId = a.artifactId }).ok)
		t.eq("the trophy is on the wall", TrophyHall.countDisplayed(p), 1)
		t.ok("take down succeeds → back to HELD", handle(p, "takeDownTrophy", { artifactId = a.artifactId }).ok)
		t.ok("after take-down the trophy is HELD (the take-down-to-trade handoff; escrow is Step 12)", p.artifacts[a.artifactId].disposition == "HELD")
		t.eq("the wall is empty again", TrophyHall.countDisplayed(p), 0)
	end

	t.section("Display — mounting past owned slot capacity is rejected (the sink pull)")
	do
		local p = Util.mkProfile(Catalog, {}) -- baseTrophySlots = 8, boughtSlots = 0 → 8 slots
		local mints = {}
		for i = 1, 9 do
			mints[i] = mintTrophy(p, "bayou_white_alligator")
		end
		for i = 1, 8 do
			t.ok("mount " .. i .. " (within capacity) succeeds", handle(p, "mountTrophy", { artifactId = mints[i].artifactId }).ok)
		end
		t.eq("8 displayed = full", TrophyHall.countDisplayed(p), 8)
		local r = handle(p, "mountTrophy", { artifactId = mints[9].artifactId })
		t.ok("the 9th mount is rejected: slots full (take one down or buy a slot)", r.ok == false and r.reason == "slots_full")
		t.eq("still 8 displayed (no over-capacity display)", TrophyHall.countDisplayed(p), 8)
		-- buying a slot raises capacity → the 9th now mounts
		p.lodge.boughtSlots = 1
		t.ok("with a bought slot (9 total), the 9th mounts", handle(p, "mountTrophy", { artifactId = mints[9].artifactId }).ok)
	end

	t.section("Display — only trophies display (§4): a non-trophy → DISPLAYED is rejected")
	do
		local p = Util.mkProfile(Catalog, {})
		local dog = ArtifactStore.mint(p, { kind = "trackingDog", tradeable = true, owner = "u1" }, idGen, 1)
		t.ok("a tracking dog cannot be mounted in the Trophy Hall", handle(p, "mountTrophy", { artifactId = dog.artifactId }).ok == false)
	end

	t.section("Display — take-down requires a currently-DISPLAYED trophy")
	do
		local p = Util.mkProfile(Catalog, {})
		local a = mintTrophy(p, "bayou_white_alligator") -- HELD
		t.ok("taking down a HELD (not displayed) trophy is rejected", handle(p, "takeDownTrophy", { artifactId = a.artifactId }).ok == false)
	end
end
