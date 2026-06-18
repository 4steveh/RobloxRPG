--!strict
local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")

return function(t: Harness.T)
	local idGen = Fakes.newIdGenerator()
	local p = Util.mkProfile(Catalog, {})

	t.section("ArtifactStore — mint: one unique id, HELD at mint, provenance")
	local a = ArtifactStore.mint(p, {
		kind = "trophy",
		tradeable = true,
		owner = "u1",
		sourceId = "bayou_leviathan",
		validatingEventId = "catch-1",
	}, idGen, 1000)
	t.ok("artifact has a unique id", a.artifactId == "art-1")
	t.ok("disposition is HELD at mint", a.disposition == "HELD")
	t.ok("owner + provenance recorded", a.owner == "u1" and a.provenance.sourceId == "bayou_leviathan" and a.provenance.mintedAt == 1000)
	t.ok("added to the artifacts map and the owned set", p.artifacts["art-1"] ~= nil and p.inventory.artifactIds["art-1"] == true)
	t.ok("not tombstoned at mint", a.tombstoned == false)

	t.section("ArtifactStore — CAS transition rejects a wrong precondition")
	local r1 = ArtifactStore.transition(p, "art-1", "DISPLAYED", "HELD") -- expected DISPLAYED but it's HELD
	t.ok("CAS rejects a precondition mismatch (the double-spend defense)", r1.ok == false and r1.reason == "precondition_mismatch")
	local r2 = ArtifactStore.transition(p, "art-1", "HELD", "DISPLAYED") -- correct precondition
	t.ok("HELD→DISPLAYED succeeds for a trophy", r2.ok and p.artifacts["art-1"].disposition == "DISPLAYED")

	t.section("ArtifactStore — kind-gating (DISPLAYED/SALVAGED are Trophy-only)")
	local dog = ArtifactStore.mint(p, { kind = "trackingDog", tradeable = true, owner = "u1" }, idGen, 1001)
	t.ok("non-trophy dog CANNOT be DISPLAYED", ArtifactStore.transition(p, dog.artifactId, "HELD", "DISPLAYED").ok == false)
	t.ok("non-trophy dog CANNOT be SALVAGED", ArtifactStore.transition(p, dog.artifactId, "HELD", "SALVAGED").ok == false)
	t.ok("non-trophy dog CAN be ESCROWED (the HELD↔ESCROWED primitive Step 12 builds on)", ArtifactStore.transition(p, dog.artifactId, "HELD", "ESCROWED").ok)
	t.ok("…and ESCROWED→HELD reverts (escrow cancel)", ArtifactStore.transition(p, dog.artifactId, "ESCROWED", "HELD").ok)

	t.section("ArtifactStore — salvage tombstones (marked, never erased)")
	local rsalv = ArtifactStore.transition(p, "art-1", "DISPLAYED", "SALVAGED") -- DISPLAYED→SALVAGED (trophy)
	t.ok("DISPLAYED→SALVAGED succeeds", rsalv.ok)
	t.ok("artifact tombstoned + disposition SALVAGED", p.artifacts["art-1"].tombstoned == true and p.artifacts["art-1"].disposition == "SALVAGED")
	t.ok("salvaged leaves the owned set but stays in the artifacts map (audit reconstructability)", p.inventory.artifactIds["art-1"] == nil and p.artifacts["art-1"] ~= nil)
	t.ok("a tombstoned artifact cannot transition again (terminal)", ArtifactStore.transition(p, "art-1", "SALVAGED", "HELD").ok == false)

	t.section("ArtifactStore — the §4 transition table is a CLOSED edge set (illegal edges rejected)")
	local trophy = ArtifactStore.mint(p, { kind = "trophy", tradeable = true, owner = "u1" }, idGen, 1002) -- art-3, HELD
	t.ok("HELD→ESCROWED is a legal edge", ArtifactStore.transition(p, trophy.artifactId, "HELD", "ESCROWED").ok)
	local e1 = ArtifactStore.transition(p, trophy.artifactId, "ESCROWED", "SALVAGED")
	t.ok("ESCROWED→SALVAGED REJECTED (can't salvage an item locked in a live trade)", e1.ok == false and e1.reason == "illegal_transition")
	t.ok("ESCROWED→DISPLAYED REJECTED (not an edge in the table)", ArtifactStore.transition(p, trophy.artifactId, "ESCROWED", "DISPLAYED").ok == false)
	t.ok("ESCROWED→ESCROWED (self-transition) REJECTED", ArtifactStore.transition(p, trophy.artifactId, "ESCROWED", "ESCROWED").ok == false)
	t.ok("ESCROWED→HELD is legal (escrow cancel)", ArtifactStore.transition(p, trophy.artifactId, "ESCROWED", "HELD").ok)
	t.ok("HELD→DISPLAYED then DISPLAYED→ESCROWED REJECTED (must go via HELD first)", (function()
		assert(ArtifactStore.transition(p, trophy.artifactId, "HELD", "DISPLAYED").ok)
		return ArtifactStore.transition(p, trophy.artifactId, "DISPLAYED", "ESCROWED").ok == false
	end)())

	t.section("ArtifactStore — transferOwnership: live to new owner, TOMBSTONE (not erased) on the old (Step 12)")
	do
		local from = Util.mkProfile(Catalog, {})
		local to = Util.mkProfile(Catalog, {})
		local a = ArtifactStore.mint(from, { kind = "trophy", tradeable = true, owner = "u1", sourceId = "bayou_white_alligator", validatingEventId = "ev" }, Fakes.newIdGenerator(), 1)
		assert(ArtifactStore.transition(from, a.artifactId, "HELD", "ESCROWED").ok) -- escrow before the swap
		local r = ArtifactStore.transferOwnership(from, to, a.artifactId, "ESCROWED", "u2")
		t.ok("the transfer succeeds", r.ok)
		t.ok("LIVE in the new owner: owner flipped, HELD, owned, not tombstoned", to.artifacts[a.artifactId] ~= nil and to.artifacts[a.artifactId].owner == "u2" and to.artifacts[a.artifactId].disposition == "HELD" and to.inventory.artifactIds[a.artifactId] == true and to.artifacts[a.artifactId].tombstoned == false)
		t.ok("TOMBSTONE in the old owner: marked, NOT erased, NOT in the owned set", from.artifacts[a.artifactId] ~= nil and from.artifacts[a.artifactId].tombstoned == true and from.inventory.artifactIds[a.artifactId] == nil)
		t.ok("provenance preserved on the live record (immutable history)", to.artifacts[a.artifactId].provenance.sourceId == "bayou_white_alligator")
		t.ok("the anti-dupe invariant: NOT live in two profiles", (from.inventory.artifactIds[a.artifactId] == nil) and (to.inventory.artifactIds[a.artifactId] == true))
	end

	t.section("ArtifactStore — transferOwnership CAS: a non-ESCROWED source is rejected (no transfer)")
	do
		local from = Util.mkProfile(Catalog, {})
		local to = Util.mkProfile(Catalog, {})
		local a = ArtifactStore.mint(from, { kind = "trophy", tradeable = true, owner = "u1", sourceId = "bayou_white_alligator", validatingEventId = "ev" }, Fakes.newIdGenerator(), 1)
		-- still HELD (not escrowed) → expected=ESCROWED CAS fails
		local r = ArtifactStore.transferOwnership(from, to, a.artifactId, "ESCROWED", "u2")
		t.ok("rejected: precondition_mismatch (CAS)", r.ok == false and r.reason == "precondition_mismatch")
		t.ok("nothing transferred: old keeps it live, new has nothing", from.inventory.artifactIds[a.artifactId] == true and to.artifacts[a.artifactId] == nil)
	end
end
