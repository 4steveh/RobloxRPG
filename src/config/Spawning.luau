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

-- Appalachia hunting (LOC_02 §8.4): modeled ~45/hr at T2; ceiling 48 (slack — the anti-farming bound).
local appalachiaHunting: LoopSpawn = {
	ceilingPerHour = 48,
	areas = {
		old_field = { maxConcurrentTargets = 6, respawnIntervalSeconds = 45 },     -- deer/turkey/cottontail
		oak_ridges = { maxConcurrentTargets = 3, respawnIntervalSeconds = 90 },     -- boar
		creek_bottoms = { maxConcurrentTargets = 2, respawnIntervalSeconds = 180 }, -- coyote packs (crowd cap)
		lookout_ridge = { maxConcurrentTargets = 1, respawnIntervalSeconds = 300 }, -- mountain lion (apex)
	},
}
-- Appalachia fishing (LOC_02 §8.4): modeled ~38/hr at T2; ceiling 40 (slack). Shore-accessible, no Boat.
local appalachiaFishing: LoopSpawn = {
	ceilingPerHour = 40,
	areas = {
		hollow_creek = { maxConcurrentTargets = 4, respawnIntervalSeconds = 40 }, -- trout (fly water)
		mill_pond = { maxConcurrentTargets = 5, respawnIntervalSeconds = 40 },    -- panfish/bass/pike/muskie
	},
}

-- Alaska hunting (LOC_04 §8.4): modeled ~28/hr at T4; ceiling 30 (slack — anti-farming). Interior, Boat-free.
local alaskaHunting: LoopSpawn = {
	ceilingPerHour = 30,
	areas = {
		tundra_flats = { maxConcurrentTargets = 4, respawnIntervalSeconds = 40 },        -- hare singles + caribou herds
		spruce_riverbottom = { maxConcurrentTargets = 3, respawnIntervalSeconds = 60 },  -- sitka deer + bull moose
		the_crags = { maxConcurrentTargets = 2, respawnIntervalSeconds = 120 },          -- Dall sheep
		salmon_falls = { maxConcurrentTargets = 1, respawnIntervalSeconds = 300 },       -- grizzly (1 per Destination)
	},
}
-- Alaska fishing (LOC_04 §8.4): modeled ~22/hr at T4; ceiling 24 (slack). Interior shore + coastal (Boat).
local alaskaFishing: LoopSpawn = {
	ceilingPerHour = 24,
	areas = {
		interior_river = { maxConcurrentTargets = 4, respawnIntervalSeconds = 45 }, -- grayling/dolly/sockeye (shore)
		coastal_inlet = { maxConcurrentTargets = 4, respawnIntervalSeconds = 55 },  -- rockfish/lingcod/king (Boat)
		open_gulf = { maxConcurrentTargets = 3, respawnIntervalSeconds = 60 },      -- halibut (Boat, apex)
		-- Step 13: the seasonal Frozen Lake (Winter Freeze event, LOC_04 §8.4 "capped low" so the calmer
		-- ice-fishing micro-activity is not an over-geared farming hole). Whitefish (routine) + burbot (rare).
		frozen_lake = { maxConcurrentTargets = 2, respawnIntervalSeconds = 55 },
	},
}

local byDestination: { [Ids.DestinationId]: DestinationSpawn } = {
	[D.Bayou] = { hunting = bayouHunting, fishing = bayouFishing },
	[D.Appalachia] = { hunting = appalachiaHunting, fishing = appalachiaFishing },
	[D.Alaska] = { hunting = alaskaHunting, fishing = alaskaFishing },
}
Spawning.byDestination = byDestination

return Spawning
