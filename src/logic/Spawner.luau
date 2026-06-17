--!strict
-- PURE SPAWNER LOGIC (SYS_combat §5 / SYS_fishing §6) — the LOOP-AGNOSTIC cap/engagement accounting the
-- server enforces. The PHYSICAL spawn (Workspace placement, respawn timers, positions, spot-depletion) is
-- server-authoritative and lives in the Studio Hunting/Fishing services; this module is the headless-
-- provable economy core: the engagement rate, the anti-low-tier-farming cap, the ambiance/rare exclusion,
-- the condition-gated rare predicate, and the build-time placement guarantee.
--
-- GENERALIZED for both loops (Step 5): the anti-farming `min(3600/TimePerTarget, ceiling)` line is
-- SINGLE-SOURCED in `ratePerHour`; the per-loop differences (engagement table, target collection,
-- ambiance handling) are parameterized by `loop` (default Hunting → Step-4 callers are unchanged). A kill
-- and a catch are the same Income(T) math; only the inputs differ.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Spawning = require("@src/config/Spawning")
local Fishing = require("@src/logic/Fishing")

type Config = Schema.Config
type Shell = Schema.Shell
type Loop = Enums.Loop
type LoopSpawn = Spawning.LoopSpawn
type PlayerData = Schema.PlayerData

local M = {}

-- The per-loop engagement profile, normalized to {find, active, overhead} so the rate math is loop-agnostic.
-- Hunting: TimeToFind + TimeToKill + Overhead; Fishing: TimeToBite + FightTime + Overhead.
local function engagementFor(config: Config, tier: number, loop: Loop): { find: number, active: number, overhead: number }
	if loop == Enums.Loop.Fishing then
		local e = assert(config.tuning.fishing.engagement[tier], "Spawner: no fishing engagement model for tier " .. tier)
		return { find = e.timeToBite, active = e.fightTime, overhead = e.overhead }
	end
	local e = assert(config.tuning.combat.engagement[tier], "Spawner: no hunting engagement model for tier " .. tier)
	return { find = e.timeToFind, active = e.timeToKill, overhead = e.overhead }
end

-- THE single anti-farming line (both loops): the ceiling binds the rate independent of how fast the player
-- kills/catches — an over-geared player → tiny active time → still capped at the ceiling.
local function ratePerHour(timePerTarget: number, ceilingPerHour: number): number
	return math.min(3600 / timePerTarget, ceilingPerHour)
end

-- TimePerTarget(T) = find + active + overhead. `loop` defaults to Hunting (Step-4 callers unchanged).
function M.timePerTarget(config: Config, tier: number, activeSeconds: number, loop: Loop?): number
	local e = engagementFor(config, tier, loop or Enums.Loop.Hunting)
	return e.find + activeSeconds + e.overhead
end

-- The realized routine rate for ANY active time (the anti-farming proof: over-geared → capped at ceiling).
function M.realizedRoutineRatePerHour(config: Config, tier: number, ceilingPerHour: number, activeSeconds: number, loop: Loop?): number
	return ratePerHour(M.timePerTarget(config, tier, activeSeconds, loop), ceilingPerHour)
end

-- The modeled rate for a normal at-tier player (active = the tier's modeled TimeToKill / FightTime).
function M.expectedTargetsPerHour(config: Config, tier: number, ceilingPerHour: number, loop: Loop?): number
	local e = engagementFor(config, tier, loop or Enums.Loop.Hunting)
	return ratePerHour(e.find + e.active + e.overhead, ceilingPerHour)
end

-- The UNCAPPED modeled engagement rate = 3600 / TimePerTarget. This is the **economy Payout denominator**
-- (Step 6) — NOT ceiling-clamped: the ceiling is the anti-farming bound (slack at-tier, 80<85 / 60<65), so
-- dividing Income(T) by the ceiling would underpay the at-tier player. Reconciliation asserts the slackness.
function M.modeledRatePerHour(config: Config, tier: number, loop: Loop?): number
	local e = engagementFor(config, tier, loop or Enums.Loop.Hunting)
	return 3600 / (e.find + e.active + e.overhead)
end

local function zonesContain(zones: { string }?, zoneId: string): boolean
	if zones == nil then
		return false
	end
	for _, z in zones do
		if z == zoneId then
			return true
		end
	end
	return false
end

-- The reward-bearing ROUTINE population of a zone (§8 / RD5): Common/Uncommon non-ambiance targets the
-- ceiling normalizes over. AMBIANCE and RARES are excluded (ambiance occupies world density only; rares are
-- bonus-on-top condition-gated spawns). `loop` selects the target collection (creatures vs fish).
function M.routineTargetsInZone(config: Config, destinationId: string, zoneId: string, loop: Loop?): { string }
	local ids: { string } = {}
	if (loop or Enums.Loop.Hunting) == Enums.Loop.Fishing then
		for id, f in config.fish do
			if f.destinationId == destinationId and Enums.RarityRank[f.rarity] < Enums.RARE_AND_ABOVE_RANK and zonesContain(f.spawnZones, zoneId) then
				table.insert(ids, id)
			end
		end
	else
		for id, c in config.creatures do
			if c.destinationId == destinationId and not c.ambianceOnly and Enums.RarityRank[c.rarity] < Enums.RARE_AND_ABOVE_RANK and zonesContain(c.spawnZones, zoneId) then
				table.insert(ids, id)
			end
		end
	end
	return ids
end

-- ── Step 11: the PRIMARY Boat sub-area gate (SYS_fishing §7 / SYS_progression §2). A fishing zone is
-- Boat-gated iff it homes a Boat-gated fish (coastal/deep-sea water); the required vehicle is one whose
-- accessGrant matches that water. A player WITHOUT it can never be in the cell, so they are never offered its
-- spawns. Shore zones (pond/river/lake) are always accessible. Access, never power — the Boat opens the cell
-- and grants nothing inside it (the catch math reads no vehicle; CatchHandler is the independent backstop). ──
function M.canAccessZone(profile: PlayerData, config: Config, destinationId: string, zoneId: string): boolean
	local gatedWater: string? = nil
	for _, f in config.fish do
		if f.destinationId == destinationId and zonesContain(f.spawnZones, zoneId) and Fishing.requiresBoat(f) then
			gatedWater = f.waterType
			break
		end
	end
	if gatedWater == nil then
		return true -- shore-accessible: no Boat required
	end
	return Fishing.ownsBoatForWater(profile, config, gatedWater)
end

-- The PLAYER-FACING offered population = the routine population GATED by Boat access. A Boat-less player is
-- offered NOTHING from a Boat-gated fishing zone (the primary gate). routineTargetsInZone stays pure (the
-- content query, unchanged for Steps 1-10); this is the per-player projection. Hunting + shore zones are
-- unaffected (canAccessZone is vacuously true there).
function M.offeredTargetsInZone(profile: PlayerData, config: Config, destinationId: string, zoneId: string, loop: Loop?): { string }
	local lp = loop or Enums.Loop.Hunting
	if lp == Enums.Loop.Fishing and not M.canAccessZone(profile, config, destinationId, zoneId) then
		return {}
	end
	return M.routineTargetsInZone(config, destinationId, zoneId, lp)
end

-- Condition-gated RARE spawn predicate (§5 / RD-E, Decision 3/4) — works for a creature OR a fish (both
-- carry `spawn.conditions`). A rare is eligible iff every present condition field matches the world. This is
-- a per-WINDOW presence check, NOT coupled to kill/catch rate, and it takes NO bait input (Decision 4 — you
-- cannot buy your way to a rare; a basic-bait condition gates the ATTEMPT via baitRequired, not this roll).
export type WorldState = { time: string?, weather: string?, season: string?, event: string? }
export type ConditionsBearer = Schema.Creature | Schema.Fish -- both carry spawn.conditions (the only field read)
function M.rareSpawnEligible(target: ConditionsBearer, world: WorldState): boolean
	local cond = target.spawn.conditions
	if cond == nil then
		return true
	end
	local function ok(c: string?, w: string?): boolean
		return c == nil or c == w
	end
	return ok(cond.time, world.time) and ok(cond.weather, world.weather) and ok(cond.season, world.season) and ok(cond.event, world.event)
end

-- BUILD-TIME placement guarantee: every routine spawn AREA resolves to a real Step-3 zone, and every target
-- (creature/fish) home to this Destination has spawnZones resolving to real zones. `loop` selects creatures
-- vs fish. Called from Shells.luau on load (a bad map fails the require).
function M.validatePlacement(config: Config, shell: Shell, loopSpawn: LoopSpawn, loop: Loop?)
	for zoneId in loopSpawn.areas do
		assert(shell.zones[zoneId] ~= nil, "Spawner: spawn area zone '" .. zoneId .. "' is not a zone in shell '" .. shell.destinationId .. "'")
	end
	if (loop or Enums.Loop.Hunting) == Enums.Loop.Fishing then
		for _, f in config.fish do
			if f.destinationId == shell.destinationId then
				local zones = assert(f.spawnZones, f.id .. ": a fish must carry spawnZones (Step 5 prereq)")
				for _, zoneId in zones do
					assert(shell.zones[zoneId] ~= nil, f.id .. ": spawnZone '" .. zoneId .. "' is not a real zone in shell '" .. shell.destinationId .. "'")
				end
			end
		end
	else
		for _, c in config.creatures do
			if c.destinationId == shell.destinationId and not c.ambianceOnly then
				local zones = assert(c.spawnZones, c.id .. ": a non-ambiance target must carry spawnZones (Step 4 P1)")
				for _, zoneId in zones do
					assert(shell.zones[zoneId] ~= nil, c.id .. ": spawnZone '" .. zoneId .. "' is not a real zone in shell '" .. shell.destinationId .. "'")
				end
			end
		end
	end
end

return M
