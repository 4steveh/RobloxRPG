--!strict
-- ARRIVAL routing (Step 3). Resolves where a logging-in player spawns. Pure + server-authoritative: the
-- world blockout calls SessionService.login (lock + load) and then this to place the character. Step 3 is
-- the destination/teleport framework's first real use.

local Schema = require("@src/types/Schema")
local Ids = require("@src/types/Ids")
local Shell = require("@src/logic/Shell")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type Vec3 = Schema.Vec3
type ShellRegistry = { byDestination: { [Ids.DestinationId]: Schema.Shell } }

local M = {}

export type Arrival = { destinationId: Ids.DestinationId, zoneId: string, anchor: Vec3 }

-- resolveArrival: ALWAYS the free, gate-less root — the requiredTier-0 Destination (derived from data
-- like freshProfile), i.e. the Bayou. UNCONDITIONAL in Step 3: a fresh player and a returning player both
-- arrive here. `profile` is accepted for the Step-8 branch but unused now.
-- TODO(step-8): a returning player (funnel COMPLETE) lands in the Lodge, not the Bayou
-- (SYS_onboarding_funnel §0 vs SYS_lodge_trophy) — that routing branch is Step 8, not built here.
function M.resolveArrival(_profile: PlayerData, shells: ShellRegistry, config: Config): Arrival
	local rootId: Ids.DestinationId? = nil
	for id, dst in config.destinations do
		if dst.gate.requiredTier == 0 then
			assert(rootId == nil, "ArrivalService: more than one free-starter (requiredTier 0) Destination")
			rootId = id
		end
	end
	local destinationId = assert(rootId, "ArrivalService: no free-starter (requiredTier 0) Destination")
	local shell = assert(shells.byDestination[destinationId], "ArrivalService: no shell for arrival Destination '" .. destinationId .. "'")
	return { destinationId = destinationId, zoneId = shell.arrivalZoneId, anchor = Shell.arrivalAnchor(shell) }
end

return M
