--!strict
-- SPAWN-DENSITY config (LOC_01 §8.4 values, set WITHIN combat's cap mechanism — SYS_combat §5). Per
-- (Destination, loop): routine spawn AREAS (each a server-owned MaxConcurrentTargets + RespawnInterval)
-- and the SpawnThroughputCeiling knob. LOOP-AGNOSTIC by construction — fishing (Step 5) plugs the same
-- shape under `.fishing` and reuses Spawner.luau unchanged. NOT required by Catalog (it depends on the
-- Step-3 zones); Shells.luau validates it against the shell on load.
--
-- The ceiling is an economy-CRITICAL invariant, not cosmetic: it bounds ExpectedTargetsPerHour by target
-- AVAILABILITY, not player kill speed, so an over-geared player farming Bayou game earns ≈ Income(1) —
-- strictly worse than their own tier (the anti-low-tier-farming guarantee). Per §8.4 the exact ceiling is
-- a tuning KNOB in the ~80–90/hr band; the binding part is "capped near Income(1)". Ambiance is NOT here
-- (it never consumes the reward-bearing ceiling). Rares are condition-gated independent spawns (the
-- catalog's rare fields + spawn.conditions via Spawner.rareSpawnEligible), never a per-kill upgrade roll.

local Ids = require("@src/types/Ids")

local D = Ids.Destination

export type AreaSpawn = { maxConcurrentTargets: number, respawnIntervalSeconds: number }
export type LoopSpawn = { ceilingPerHour: number, areas: { [string]: AreaSpawn } }
export type DestinationSpawn = { hunting: LoopSpawn?, fishing: LoopSpawn? }

local Spawning = {}

-- Bayou hunting (LOC §8.4): 3 routine spawn areas, each ~3 concurrent / ~35 s respawn; ceiling 85/hr
-- (mid of the ~80–90 band). Zone ids resolve against the Step-3 Bayou shell (validated on load).
local bayouHunting: LoopSpawn = {
	ceilingPerHour = 85,
	areas = {
		sunny_levee = { maxConcurrentTargets = 3, respawnIntervalSeconds = 35 },
		reed_edges = { maxConcurrentTargets = 3, respawnIntervalSeconds = 35 },
		channel_banks = { maxConcurrentTargets = 3, respawnIntervalSeconds = 35 },
	},
}

-- Bayou FISHING (LOC §8.4): 2 shore-accessible waters; MaxConcurrentBites ~2–3 / BiteRespawnInterval ~30 s;
-- BiteThroughputCeiling in the ~60–70/hr band (knob; the binding part is "capped near Income(1)"). Local
-- spot-depletion is a Studio spawner detail; the ceiling is this shared headless cap.
local bayouFishing: LoopSpawn = {
	ceilingPerHour = 65,
	areas = {
		channel_banks = { maxConcurrentTargets = 3, respawnIntervalSeconds = 30 },
		catfish_hole = { maxConcurrentTargets = 2, respawnIntervalSeconds = 30 },
	},
}

local byDestination: { [Ids.DestinationId]: DestinationSpawn } = {
	[D.Bayou] = { hunting = bayouHunting, fishing = bayouFishing },
}
Spawning.byDestination = byDestination

return Spawning
