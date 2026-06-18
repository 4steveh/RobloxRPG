--!strict
-- ARRIVAL routing (Step 3 + Step 8). Resolves where a logging-in player spawns. Pure + server-authoritative:
-- the world bootstrap calls SessionService.login (lock + load) and then this to place the character.
--   • A FIRST-TIME player (funnel not COMPLETE) → the free, gate-less ROOT Destination (the Bayou, the
--     onboarding §0 spawn) — UNCONDITIONAL as in Step 3.
--   • A RETURNING player (funnel COMPLETE) → the LODGE (the hub; SYS_lodge_trophy §1 — spawning in and
--     returning from a Destination both land in the Lodge). The Lodge is NOT a Destination, so the result
--     carries kind="lodge" + destinationId=nil; a Destination arrival carries kind="destination".
-- This is the Step-8 routing branch the Step-3 TODO reserved.

local Schema = require("../types/Schema")
local Ids = require("../types/Ids")
local Shell = require("../logic/Shell")
local Onboarding = require("../logic/Onboarding")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type Vec3 = Schema.Vec3
type LodgeArrival = { zoneId: string, anchor: Vec3 }
type ShellRegistry = { byDestination: { [Ids.DestinationId]: Schema.Shell }, lodge: LodgeArrival }

local M = {}

-- A tagged arrival target: the Lodge hub (kind="lodge", no destinationId) or a Destination (kind="destination").
export type Arrival = { kind: "lodge" | "destination", destinationId: Ids.DestinationId?, zoneId: string, anchor: Vec3 }

-- Resolve the arrival anchor for an EXPLICIT fast-travel destination (the Studio TeleportService executor
-- calls this after DestinationService.travelTo authorises the travel). This does NOT re-check the unlock
-- gate — DestinationService.travelTo already enforces the persisted unlocked set (Step 9). This resolver
-- is the pure map: (already-authorised destinationId) → physical arrival anchor.
function M.resolveDestinationArrival(destinationId: Ids.DestinationId, shells: ShellRegistry, _config: Config): Arrival
	local shell = assert(shells.byDestination[destinationId], "ArrivalService: no shell for fast-travel destination '" .. destinationId .. "'")
	return { kind = "destination", destinationId = destinationId, zoneId = shell.arrivalZoneId, anchor = Shell.arrivalAnchor(shell) }
end

function M.resolveArrival(profile: PlayerData, shells: ShellRegistry, config: Config): Arrival
	-- Step 8: a returning (funnel-COMPLETE) player lands in the Lodge hub, not the Bayou root.
	if Onboarding.isOnboardingComplete(profile) then
		return { kind = "lodge", destinationId = nil, zoneId = shells.lodge.zoneId, anchor = shells.lodge.anchor }
	end
	-- Otherwise: the free, gate-less root — the requiredTier-0 Destination (derived from data), i.e. the Bayou.
	local rootId: Ids.DestinationId? = nil
	for id, dst in config.destinations do
		if dst.gate.requiredTier == 0 then
			assert(rootId == nil, "ArrivalService: more than one free-starter (requiredTier 0) Destination")
			rootId = id
		end
	end
	local destinationId = assert(rootId, "ArrivalService: no free-starter (requiredTier 0) Destination")
	local shell = assert(shells.byDestination[destinationId], "ArrivalService: no shell for arrival Destination '" .. destinationId .. "'")
	return { kind = "destination", destinationId = destinationId, zoneId = shell.arrivalZoneId, anchor = Shell.arrivalAnchor(shell) }
end

return M
