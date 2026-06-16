--!strict
-- Step 5 (fishing) — the "catch" intent handler filling the gauntlet's step-3 hook with server-authoritative
-- FIGHT RESOLUTION, and driving the shared RewardPipeline in its commit (critical → Transaction). Mirrors
-- FireHandler. The cast/bite/fight FEEL and the physical bite spawner are Studio; here we drive the handler
-- through the gauntlet with server-enriched payloads to prove the validators + the reward wiring + the OR-gate.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Fishing = require("@src/logic/Fishing")
local Gauntlet = require("@src/server/authority/Gauntlet")
local CatchHandler = require("@src/server/fishing/CatchHandler")

return function(t: Harness.T)
	-- a tier-1 angler at MID intra-tier gear (lands the milestone), holding the basic required bait.
	local function angler(): any
		local p = Util.mkProfile(Catalog, { rod = 1, reel = 1 })
		for _, c in p.inventory.commodities do
			c.intraLevel = 1 -- mid gear (the §3 reference; a fresh entry rig needs a cheap upgrade to land the milestone)
		end
		p.inventory.fungible["cut bait"] = 5
		p.inventory.fungible["worms"] = 5
		return p
	end

	-- a server-enriched, authoritative fight payload (client claims only the target + tension inputs).
	local function shot(targetId: string, E: number, accumBefore: number): any
		local reelDrain = Fishing.reelDrainMax(Catalog, 1, "mid")
		return {
			targetId = targetId,
			biteActive = true,
			E = E,
			claimedDrain = reelDrain * E,
			accumulatedStaminaBefore = accumBefore,
			owner = "u1",
		}
	end
	-- the accumulated Stamina that makes the next legal drain the LANDING tick for `fish`.
	local function landingAccum(fishId: string): number
		return Fishing.staminaToLand(Catalog, Catalog.fish[fishId]) - Fishing.reelDrainMax(Catalog, 1, "mid") * 0.7
	end

	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, CatchHandler.new({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
		return reg
	end
	local function deps(saveOk: boolean): Gauntlet.Deps
		return {
			config = Catalog,
			now = 100,
			saveFn = function()
				return saveOk
			end,
			markDirty = function() end,
			telemetry = Fakes.newTelemetry(),
		}
	end

	t.section("CatchHandler — a valid landed fish drives the reward pipeline end-to-end")
	do
		local p = angler()
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		local r = Gauntlet.handle(newReg(), { intent = "catch", playerId = 1, payload = shot("bayou_bluegill", 0.7, landingAccum("bayou_bluegill")) }, session, deps(true))
		t.ok("the catch succeeds", r.ok)
		t.eq("one Cash faucet entry written (routine catch)", #p.cash.tail, 1)
		t.ok("Angler Rank XP awarded (not Hunter)", p.anglerRankXP > 0 and p.hunterRankXP == 0)
		t.ok("projection reflects the new balance", r.projection ~= nil and (r.projection :: any).balance == p.cash.tail[1].amount)
	end

	t.section("CatchHandler — the Blue Catfish milestone catch sets the (shared) Bayou conquest")
	do
		local p = angler()
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		local r = Gauntlet.handle(newReg(), { intent = "catch", playerId = 1, payload = shot("bayou_blue_catfish", 0.7, landingAccum("bayou_blue_catfish")) }, session, deps(true))
		t.ok("the milestone catch succeeds", r.ok)
		t.ok("the Bayou conquest flag is set (the OR-gate's fishing route)", p.conqueredDestinations.bayou == true)
		t.ok("the projection carries the conquest", r.projection ~= nil and (r.projection :: any).conqueredDestinations.bayou == true)
	end

	t.section("CatchHandler — anti-exploit + gating rejections (no reward)")
	do
		local function fire(p: any, payload: any): Gauntlet.HandleResult
			local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
			return Gauntlet.handle(newReg(), { intent = "catch", playerId = 1, payload = payload }, session, deps(true))
		end
		-- drain spoof
		local p1 = angler()
		local spoof = shot("bayou_bluegill", 0.7, landingAccum("bayou_bluegill"))
		spoof.claimedDrain = 999
		t.ok("an instant-drain spoof is rejected", fire(p1, spoof).ok == false)
		t.eq("the spoof produced no reward", #p1.cash.tail, 0)
		-- illegal tension
		local p2 = angler()
		t.ok("an out-of-range tension (E>1) is rejected", fire(p2, shot("bayou_bluegill", 2, landingAccum("bayou_bluegill"))).ok == false)
		-- no active bite (server state)
		local p3 = angler()
		local noBite = shot("bayou_bluegill", 0.7, landingAccum("bayou_bluegill"))
		noBite.biteActive = false
		t.ok("casting at a non-active bite is rejected at authority", fire(p3, noBite).ok == false and fire(p3, noBite).reason == "no_bite")
		-- missing basic required bait
		local p4 = angler()
		p4.inventory.fungible["worms"] = nil
		t.ok("missing the basic required bait is rejected (the yes/no gate)", fire(p4, shot("bayou_bluegill", 0.7, landingAccum("bayou_bluegill"))).ok == false and fire(p4, shot("bayou_bluegill", 0.7, landingAccum("bayou_bluegill"))).reason == "missing_bait")
	end

	t.section("CatchHandler — gear that cannot clear the fight is rejected (the runtime min-tier gate)")
	do
		-- a FRESH entry-gear angler (no upgrade) cannot land the milestone blue catfish: the window collapses.
		local p = Util.mkProfile(Catalog, { rod = 1, reel = 1 }) -- intraLevel 0 = entry
		p.inventory.fungible["cut bait"] = 5
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		-- a self-consistent ENTRY-level drain (the validator is level-sensitive) so gear-adequacy is what bites
		local entryDrain = Fishing.reelDrainMax(Catalog, 1, "entry") * 0.7
		local payload = { targetId = "bayou_blue_catfish", biteActive = true, E = 0.7, claimedDrain = entryDrain, accumulatedStaminaBefore = 9999, owner = "u1" }
		local r = Gauntlet.handle(newReg(), { intent = "catch", playerId = 1, payload = payload }, session, deps(true))
		t.ok("entry gear snaps/throws on the milestone (gear_insufficient) — the player must upgrade", r.ok == false and r.reason == "gear_insufficient")
	end

	t.section("CatchHandler — a catch whose write-through FAILS reverts cleanly (no orphan reward)")
	do
		local p = angler()
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		local r = Gauntlet.handle(newReg(), { intent = "catch", playerId = 1, payload = shot("bayou_blue_catfish", 0.7, landingAccum("bayou_blue_catfish")) }, session, deps(false))
		t.ok("a failed persist returns persist_failed", r.ok == false and r.reason == "persist_failed")
		t.eq("the reward was REVERTED — no orphan ledger entry", #p.cash.tail, 0)
		t.ok("no orphan conquest / Angler XP", p.conqueredDestinations.bayou == nil and p.anglerRankXP == 0)
	end
end
