--!strict
-- THE WORLD-MAP / TRAVEL-DESK OPEN (Step 9) as a server-authoritative gauntlet intent. Opening the map (a)
-- completes the WORLD_MAP funnel beat (Step 7's pass-through made real — the aspiration reveal) and (b) runs
-- the commitUnlocks CATCH-ALL (re-evaluate every gate; cheap + idempotent; makes the unlock set eventually
-- consistent even if a conquest/equip-time commit ever didn't persist). `critical` → the beat advance + any
-- unlock commit write through atomically. The map UI itself is Studio (WorldServer fires this intent).

local Onboarding = require("@src/logic/Onboarding")
local Progression = require("@src/logic/Progression")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx

local M = {}

export type WorldMapDeps = { telemetry: Types.Telemetry? }

function M.new(deps: WorldMapDeps): Gauntlet.IntentHandler
	return {
		intent = "openWorldMap",
		critical = true, -- the funnel-beat advance + any unlock commit are write-through triggers
		authority = function(_ctx: Ctx): (boolean, string?)
			return true, nil -- opening the map is always permitted; it asserts nothing about state
		end,
		commit = function(ctx: Ctx)
			Onboarding.advance(ctx.profile, "worldMapOpen", ctx.now) -- completes the WORLD_MAP beat (no-op past it)
			local r = Progression.commitUnlocks(ctx.profile, ctx.config) -- the catch-all re-evaluation
			if deps.telemetry ~= nil then
				for _, id in r.newlyUnlocked do
					deps.telemetry.incr("progression.unlock:" .. id, 1)
				end
			end
		end,
	}
end

return M
