--!strict
-- Step 8 — salvage a trophy: ONE atomic operation (transition → SALVAGED + salvageFloor Cash credit, in one
-- Transaction). The CAS precondition makes it idempotent (no double-credit on a re-salvage / a concurrently
-- escrowed artifact); SALVAGED is terminal; DISPLAYED → SALVAGED is the §4 atomic un-display-then-salvage.
-- Reuses the Step-6 no-orphan proof shape (a forced save failure leaves the artifact un-salvaged + no Cash).

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Ledger = require("@src/server/ledger/Ledger")
local Economy = require("@src/logic/Economy")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local Gauntlet = require("@src/server/authority/Gauntlet")
local SalvageHandler = require("@src/server/lodge/SalvageHandler")

return function(t: Harness.T)
	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, SalvageHandler.new({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
		return reg
	end
	local function deps(saveOk: boolean): Gauntlet.Deps
		return { config = Catalog, now = 100, saveFn = function() return saveOk end, markDirty = function() end, telemetry = Fakes.newTelemetry() }
	end
	local function handle(p: any, payload: any, saveOk: boolean): Gauntlet.HandleResult
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		return Gauntlet.handle(newReg(), { intent = "salvage", playerId = 1, payload = payload }, session, deps(saveOk))
	end
	local function mintTrophy(p, sourceId)
		return ArtifactStore.mint(p, { kind = "trophy", tradeable = true, owner = "u1", sourceId = sourceId, validatingEventId = "ev" }, Fakes.newIdGenerator(), 1)
	end
	-- the expected credit for a Legendary hunting trophy (bayou_white_alligator), computed from the primitive
	local function expectedFloor(sourceId: string): number
		local idx = Catalog.targetIndex[sourceId]
		return Economy.salvageFloor(Catalog, idx.tier, idx.rarity, idx.loop)
	end

	t.section("Salvage — credits salvageFloor + transitions HELD→SALVAGED, atomically")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 100 } })
		local a = mintTrophy(p, "bayou_white_alligator")
		local r = handle(p, { artifactId = a.artifactId }, true)
		t.ok("the salvage succeeds", r.ok)
		t.ok("artifact is SALVAGED + tombstoned (terminal)", p.artifacts[a.artifactId].disposition == "SALVAGED" and p.artifacts[a.artifactId].tombstoned == true)
		t.ok("it left the owned set", p.inventory.artifactIds[a.artifactId] == nil)
		t.eq("Cash credited the (low) salvage floor", Ledger.balanceOf(p.cash), 100 + expectedFloor("bayou_white_alligator"))
	end

	t.section("Salvage — atomic: a failed write-through leaves the artifact un-salvaged AND no Cash (no orphan)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 100 } })
		local a = mintTrophy(p, "bayou_white_alligator")
		local r = handle(p, { artifactId = a.artifactId }, false)
		t.ok("a failed persist returns persist_failed", r.ok == false and r.reason == "persist_failed")
		t.ok("artifact reverted to HELD, NOT tombstoned (no orphan transition)", p.artifacts[a.artifactId].disposition == "HELD" and p.artifacts[a.artifactId].tombstoned == false)
		t.ok("still in the owned set", p.inventory.artifactIds[a.artifactId] == true)
		t.eq("no Cash credited (no orphan credit)", Ledger.balanceOf(p.cash), 100)
	end

	t.section("Salvage — idempotent: re-salvaging a SALVAGED artifact fails the CAS precondition (no double-credit)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 100 } })
		local a = mintTrophy(p, "bayou_white_alligator")
		t.ok("first salvage succeeds", handle(p, { artifactId = a.artifactId }, true).ok)
		local balAfterFirst = Ledger.balanceOf(p.cash)
		local r2 = handle(p, { artifactId = a.artifactId }, true)
		t.ok("the re-salvage is rejected (already salvaged / tombstoned)", r2.ok == false)
		t.eq("NO double-credit", Ledger.balanceOf(p.cash), balAfterFirst)
	end

	t.section("Salvage — DISPLAYED → SALVAGED is ONE atomic transition (un-display-then-salvage)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 0 } })
		local a = mintTrophy(p, "bayou_leviathan") -- Mythic fishing
		assert(ArtifactStore.transition(p, a.artifactId, "HELD", "DISPLAYED").ok) -- on the wall
		local r = handle(p, { artifactId = a.artifactId }, true)
		t.ok("salvaging a DISPLAYED trophy succeeds in one transition", r.ok and p.artifacts[a.artifactId].disposition == "SALVAGED")
		t.eq("credited the Mythic salvage floor", Ledger.balanceOf(p.cash), expectedFloor("bayou_leviathan"))
	end

	t.section("Salvage — a non-trophy (escrowable) artifact cannot be salvaged (§4: SALVAGED is Trophy-only)")
	do
		local p = Util.mkProfile(Catalog, { ledger = { 0 } })
		local dog = ArtifactStore.mint(p, { kind = "trackingDog", tradeable = true, owner = "u1", sourceId = "bayou_white_alligator" }, Fakes.newIdGenerator(), 1)
		t.ok("a tracking dog is not salvageable here", handle(p, { artifactId = dog.artifactId }, true).ok == false)
	end
end
