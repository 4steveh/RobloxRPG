--!strict
-- Step 8 — the Trophy Hall is a VIEW over disposition==DISPLAYED artifacts, NOT a stored structure. These
-- assert: the filter returns exactly the displayed set; the plaque reads the artifact's provenance (one
-- source of truth, never re-entered); slot usage is derived; and there is NO parallel "trophyWall" list on
-- the profile (the wall is computed, never persisted).

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local TrophyHall = require("@src/logic/TrophyHall")
local Replication = require("@src/server/authority/Replication")

return function(t: Harness.T)
	local function mintTrophy(p, idGen, sourceId, now)
		return ArtifactStore.mint(p, { kind = "trophy", tradeable = true, owner = "u1", sourceId = sourceId, validatingEventId = "ev" }, idGen, now)
	end

	t.section("TrophyHall — displayed() is filter(artifacts, DISPLAYED); HELD/SALVAGED are not on the wall")
	do
		local p = Util.mkProfile(Catalog, {})
		local idGen = Fakes.newIdGenerator()
		local a = mintTrophy(p, idGen, "bayou_white_alligator", 1000) -- Legendary hunting
		local b = mintTrophy(p, idGen, "bayou_leviathan", 1001) -- Mythic fishing
		mintTrophy(p, idGen, "bayou_leucistic_wood_duck", 1002) -- stays HELD
		t.eq("nothing displayed at mint (held-then-choose)", TrophyHall.countDisplayed(p), 0)
		assert(ArtifactStore.transition(p, a.artifactId, "HELD", "DISPLAYED").ok)
		assert(ArtifactStore.transition(p, b.artifactId, "HELD", "DISPLAYED").ok)
		local wall = TrophyHall.displayed(p)
		t.eq("exactly the two DISPLAYED trophies are on the wall", #wall, 2)
		t.ok("both wall entries have DISPLAYED disposition", wall[1].disposition == "DISPLAYED" and wall[2].disposition == "DISPLAYED")
		-- take one down → it leaves the view immediately (re-render from authoritative state)
		assert(ArtifactStore.transition(p, a.artifactId, "DISPLAYED", "HELD").ok)
		t.eq("taking one down removes it from the view (no stale wall)", TrophyHall.countDisplayed(p), 1)
	end

	t.section("TrophyHall — the plaque reads the artifact's provenance (one source of truth, not re-entered)")
	do
		local p = Util.mkProfile(Catalog, {})
		local idGen = Fakes.newIdGenerator()
		local a = mintTrophy(p, idGen, "bayou_leviathan", 4242) -- Mythic fishing
		assert(ArtifactStore.transition(p, a.artifactId, "HELD", "DISPLAYED").ok)
		local pl = TrophyHall.plaque(Catalog, p.artifacts[a.artifactId])
		t.eq("what: the source species name (from the catalog, via provenance.sourceId)", pl.what, Catalog.fish["bayou_leviathan"].name)
		t.eq("where: the source's home Destination (derived, not stored on the wall)", pl.where, "bayou")
		t.eq("when: the artifact's mintedAt (provenance, not re-entered)", pl.when, 4242)
		t.eq("loop derived from the target index", pl.loop, "Fishing")
		t.eq("rarity derived from the target index", pl.rarity, "Mythic")
		t.eq("tier derived from the target index", pl.tier, Catalog.targetIndex["bayou_leviathan"].tier)
	end

	t.section("TrophyHall — slot usage is derived (base + bought); the wall is NOT a persisted list")
	do
		local p = Util.mkProfile(Catalog, {})
		local idGen = Fakes.newIdGenerator()
		t.eq("total slots = baseTrophySlots + boughtSlots (8 + 0)", TrophyHall.totalSlots(p, Catalog), 8)
		p.lodge.boughtSlots = 2
		t.eq("buying 2 slots raises the total to 10", TrophyHall.totalSlots(p, Catalog), 10)
		local a = mintTrophy(p, idGen, "bayou_white_alligator", 1)
		assert(ArtifactStore.transition(p, a.artifactId, "HELD", "DISPLAYED").ok)
		local usage = TrophyHall.slotUsage(p, Catalog)
		t.ok("slotUsage reports used/total from authoritative state", usage.used == 1 and usage.total == 10)
		t.ok("the profile has NO parallel trophyWall structure (the wall is a view, not a store)", (p :: any).trophyWall == nil and (p.lodge :: any).trophyWall == nil)
	end

	t.section("TrophyHall — the projection exposes the wall as a read-only server-computed shadow")
	do
		local p = Util.mkProfile(Catalog, {})
		local idGen = Fakes.newIdGenerator()
		local a = mintTrophy(p, idGen, "bayou_white_alligator", 1)
		assert(ArtifactStore.transition(p, a.artifactId, "HELD", "DISPLAYED").ok)
		local proj = Replication.buildProjection(p, Catalog)
		t.ok("the projection carries the trophyHall view", proj.trophyHall ~= nil)
		t.eq("one trophy on the projected wall", #proj.trophyHall.displayed, 1)
		t.ok("slot usage is projected (used 1 / total 8)", proj.trophyHall.slotsUsed == 1 and proj.trophyHall.slotsTotal == 8)
		-- it is a copy, not a handle: mutating the shadow changes nothing server-side
		proj.trophyHall.displayed[1].disposition = "HELD"
		t.ok("the projected wall is a deep copy (server state untouched)", p.artifacts[a.artifactId].disposition == "DISPLAYED")
	end
end
