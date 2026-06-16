--!strict
-- Step 4 (hunting) — the "fire" intent handler filling the Gauntlet's pluggable step-3 (simulation) hook
-- with server-authoritative SHOT RESOLUTION, and driving the shared RewardPipeline in its commit (critical
-- → wrapped in a Transaction by the gauntlet). The actual aim/fire/raycast/feel is Studio; here we drive
-- the handler through the gauntlet with server-enriched payloads to prove the validators + reward wiring.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Combat = require("@src/logic/Combat")
local Gauntlet = require("@src/server/authority/Gauntlet")
local FireHandler = require("@src/server/combat/FireHandler")

return function(t: Harness.T)
	-- a server-enriched, authoritative shot payload (client claims only targetId/zone; the rest is server-set)
	local function shot(targetId: string, zone: string, distance: number, accumBefore: number): any
		local wl = Combat.gearLevelOf(0) -- mkProfile weapon is intra-level 0 → "entry"
		local dmg = Combat.shotDamage(Combat.weaponDamage(Catalog, 1, wl), Combat.zoneMultiplier(Catalog, zone), Combat.rangeFalloff(Catalog, 1, distance))
		return {
			targetId = targetId,
			zone = zone,
			distance = distance,
			claimedDamage = dmg,
			lastShotAt = 0,
			rayHitTargetId = targetId,
			targetAlive = true,
			accumulatedDamageBefore = accumBefore,
			owner = "u1",
		}
	end

	local function newReg(): Gauntlet.Registry
		local reg = Gauntlet.new()
		Gauntlet.register(reg, FireHandler.new({ idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry() }))
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

	t.section("FireHandler — a valid lethal shot drives the reward pipeline end-to-end")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1 })
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		-- a vital shot on the 15-HP duck (entry weapon 14 · 2.5 = 35 ≥ 15) one-shots
		local r = Gauntlet.handle(newReg(), { intent = "fire", playerId = 1, payload = shot("bayou_wood_duck", "vital", 10, 0) }, session, deps(true))
		t.ok("the fire succeeds", r.ok)
		t.eq("one Cash faucet entry written (routine kill, stub Payout)", #p.cash.tail, 1)
		t.ok("Hunter Rank XP awarded", p.hunterRankXP > 0)
		t.ok("projection reflects the new balance", r.projection ~= nil and (r.projection :: any).balance == p.cash.tail[1].amount)
	end

	t.section("FireHandler — the alligator milestone kill sets conquest (validated, not client-asserted)")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1 })
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		-- gator HP 48; vital entry shot = 35; pre-accumulated 13 → the lethal blow
		local r = Gauntlet.handle(newReg(), { intent = "fire", playerId = 1, payload = shot("bayou_american_alligator", "vital", 10, 13) }, session, deps(true))
		t.ok("the milestone kill succeeds", r.ok)
		t.ok("the Bayou conquest flag is set (server-validated)", p.conqueredDestinations.bayou == true)
		t.ok("the projection carries the conquest for the UI/gate", r.projection ~= nil and (r.projection :: any).conqueredDestinations.bayou == true)
	end

	t.section("FireHandler — anti-exploit: the gauntlet rejects spoofed/illegal shots (no reward)")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1 })
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		local function fire(payload: any): Gauntlet.HandleResult
			return Gauntlet.handle(newReg(), { intent = "fire", playerId = 1, payload = payload }, session, deps(true))
		end
		-- damage spoof
		local spoof = shot("bayou_wood_duck", "vital", 10, 0)
		spoof.claimedDamage = 999
		t.ok("a 999-damage claim is rejected (damage spoof)", fire(spoof).ok == false)
		-- fire-rate hack: lastShotAt == now (0 elapsed < CycleTime)
		local fast = shot("bayou_wood_duck", "vital", 10, 0)
		fast.lastShotAt = 100
		t.ok("a shot faster than CycleTime is rejected (fire-rate hack)", fire(fast).ok == false and fire(fast).reason == "fire_rate")
		-- through-wall: the raycast hit something other than the claimed target
		local wall = shot("bayou_wood_duck", "vital", 10, 0)
		wall.rayHitTargetId = "a_tree"
		t.ok("a through-wall / wrong-target shot is rejected (LOS)", fire(wall).ok == false and fire(wall).reason == "los")
		-- out of range
		local far = shot("bayou_wood_duck", "vital", 999, 0)
		t.ok("an out-of-range shot is rejected", fire(far).ok == false)
		-- a dead target (server spawn state) — authority rejects
		local dead = shot("bayou_wood_duck", "vital", 10, 0)
		dead.targetAlive = false
		t.ok("firing at an already-dead target is rejected at authority", fire(dead).ok == false and fire(dead).reason == "target_not_alive")
		t.eq("no exploit produced any reward (no ledger entries)", #p.cash.tail, 0)
		t.eq("no exploit awarded Rank XP", p.hunterRankXP, 0)
	end

	t.section("FireHandler — a kill whose write-through FAILS reverts cleanly (no orphan reward)")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1 })
		local session: Gauntlet.Session = { playerId = 1, profile = p, live = true }
		local r = Gauntlet.handle(newReg(), { intent = "fire", playerId = 1, payload = shot("bayou_american_alligator", "vital", 10, 13) }, session, deps(false))
		t.ok("a failed persist returns persist_failed", r.ok == false and r.reason == "persist_failed")
		t.eq("the reward was REVERTED — no orphan ledger entry", #p.cash.tail, 0)
		t.eq("no orphan Rank XP", p.hunterRankXP, 0)
		t.ok("no orphan conquest", p.conqueredDestinations.bayou == nil)
	end
end
