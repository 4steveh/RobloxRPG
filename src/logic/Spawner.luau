--!strict
-- PURE SPAWNER LOGIC (SYS_combat §5) — the loop-agnostic cap/engagement accounting the server enforces.
-- The PHYSICAL spawn (Workspace placement, respawn timers, positions) is server-authoritative and lives
-- in the Studio HuntingService; this module is the headless-provable economy core: the engagement rate,
-- the anti-low-tier-farming cap, the ambiance exclusion, the condition-gated rare predicate, and the
-- build-time placement guarantee. Zero content literals — values come from `config` + the Spawning config.
-- Step 5 (fishing) reuses every function here unchanged (a kill and a catch are the same Income(T) math).

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Spawning = require("@src/config/Spawning")

type Config = Schema.Config
type Shell = Schema.Shell
type LoopSpawn = Spawning.LoopSpawn

local M = {}

-- ── §5 engagement rate ──
-- TimePerTarget(T) = TimeToFind + TimeToKill + Overhead; ExpectedTargetsPerHour = min(3600/TPT, ceiling).
function M.timePerTarget(config: Config, tier: number, killSeconds: number): number
	local e = assert(config.tuning.combat.engagement[tier], "Spawner: no engagement model for tier " .. tier)
	return e.timeToFind + killSeconds + e.overhead
end

-- The realized routine rate for ANY kill speed — the ceiling binds it regardless of how fast the player
-- kills (the anti-farming invariant: an over-geared player → tiny killSeconds → still capped at ceiling).
function M.realizedRoutineRatePerHour(config: Config, tier: number, ceilingPerHour: number, killSeconds: number): number
	return math.min(3600 / M.timePerTarget(config, tier, killSeconds), ceilingPerHour)
end

-- The modeled rate for a normal at-tier player (killSeconds = the tier's modeled TimeToKill).
function M.expectedTargetsPerHour(config: Config, tier: number, ceilingPerHour: number): number
	local e = assert(config.tuning.combat.engagement[tier], "Spawner: no engagement model for tier " .. tier)
	return M.realizedRoutineRatePerHour(config, tier, ceilingPerHour, e.timeToKill)
end

-- ── the reward-bearing ROUTINE population of a zone ── (§8 / RD5)
-- The Common/Uncommon non-ambiance targets the ceiling normalizes over. AMBIANCE is excluded (it occupies
-- world density for atmosphere but can never pad/starve the farmable population) and so are RARES (bonus
-- on top — condition-gated independent spawns, not part of the routine band).
function M.routineTargetsInZone(config: Config, destinationId: string, zoneId: string): { string }
	local ids: { string } = {}
	for id, c in config.creatures do
		local routine = c.destinationId == destinationId
			and not c.ambianceOnly
			and Enums.RarityRank[c.rarity] < Enums.RARE_AND_ABOVE_RANK
			and c.spawnZones ~= nil
		if routine then
			for _, z in c.spawnZones :: { string } do
				if z == zoneId then
					table.insert(ids, id)
					break
				end
			end
		end
	end
	return ids
end

-- ── condition-gated RARE spawn predicate ── (§5 / RD-E)
-- A rare is eligible iff every present condition field matches the current world. This is a per-WINDOW
-- presence check — explicitly NOT coupled to kill rate (no per-kill upgrade roll; the 1-in-N roll is
-- separate and the LiveOps calendar owns condition frequency, Step 13). Token semantics (e.g. parsing
-- "dawn or dusk") is a Studio/LiveOps concern; here equality of present fields proves the mechanism.
export type WorldState = { time: string?, weather: string?, season: string?, event: string? }
function M.rareSpawnEligible(creature: Schema.Creature, world: WorldState): boolean
	local cond = creature.spawn.conditions
	if cond == nil then
		return true
	end
	local function ok(c: string?, w: string?): boolean
		return c == nil or c == w
	end
	return ok(cond.time, world.time) and ok(cond.weather, world.weather) and ok(cond.season, world.season) and ok(cond.event, world.event)
end

-- ── build-time placement guarantee (Step 4 P1) ──
-- Every routine spawn AREA resolves to a real Step-3 zone, and every non-ambiance hunting TARGET's
-- spawnZones resolve to real zones in this shell. Called from Shells.luau on load (a bad map fails require).
function M.validatePlacement(config: Config, shell: Shell, huntingSpawn: LoopSpawn)
	for zoneId in huntingSpawn.areas do
		assert(shell.zones[zoneId] ~= nil, "Spawner: routine area zone '" .. zoneId .. "' is not a zone in shell '" .. shell.destinationId .. "'")
	end
	for _, c in config.creatures do
		if c.destinationId == shell.destinationId and not c.ambianceOnly then
			local zones = assert(c.spawnZones, c.id .. ": a non-ambiance target must carry spawnZones (Step 4 P1)")
			for _, zoneId in zones do
				assert(shell.zones[zoneId] ~= nil, c.id .. ": spawnZone '" .. zoneId .. "' is not a real zone in shell '" .. shell.destinationId .. "'")
			end
		end
	end
end

return M
