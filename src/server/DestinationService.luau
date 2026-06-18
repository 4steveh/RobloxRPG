--!strict
-- TELEPORT FRAMEWORK SCAFFOLD — the DestinationId registry + a teleport-service interface that takes a
-- DestinationId. INTERFACE AND REGISTRY ONLY. The gated teleport flow (enforcement + execution) and the
-- World Map UI are Step 9; the place/spawn resolution is also Step 9. Lives server-side (authoritative).

local Catalog = require("../config/Catalog")
local Gate = require("../logic/Gate")
local Schema = require("../types/Schema")
local Ids = require("../types/Ids")

type PlayerData = Schema.PlayerData
type DestinationId = Ids.DestinationId

local M = {}

-- The DestinationId → Destination registry (read-only projection of the catalog).
M.registry = Catalog.destinations

function M.isRegistered(id: DestinationId): boolean
	return Catalog.destinations[id] ~= nil
end

function M.getTeleportTarget(id: DestinationId): string?
	local dst = Catalog.destinations[id]
	return dst ~= nil and dst.teleportTarget or nil
end

-- READ-ONLY preview: would travel be allowed? Delegates to the single source of truth (evaluateGate).
-- This is NOT the gated flow — it asserts nothing and moves no one; it just reads gate state for the UI.
function M.canTravel(profile: PlayerData, id: DestinationId): Gate.GateResult
	local dst = assert(Catalog.destinations[id], "DestinationService.canTravel: unknown DestinationId '" .. id .. "'")
	return Gate.evaluateGate(profile, dst, Catalog)
end

export type TravelResult = { ok: boolean, reason: string?, teleportTarget: string? }

-- The GATED fast-travel flow (Step 9). Server-authoritative ENFORCEMENT: the target must be REGISTERED and
-- in the player's PERSISTED unlockedDestinations set (the gate-bypass guard — NOT a live evaluateGate, so a
-- gear sale never re-locks travel and a not-yet-committed unlock can't be bypassed). On success it resolves
-- the teleportTarget; the actual TeleportService place/spawn execution is Studio (WorldServer consumes this).
function M.travelTo(profile: PlayerData, destinationId: DestinationId): TravelResult
	local dst = Catalog.destinations[destinationId]
	if dst == nil then
		return { ok = false, reason = "unknown_destination" }
	end
	if profile.unlockedDestinations[destinationId] ~= true then
		return { ok = false, reason = "locked" } -- the integrity line: travel reads the persisted set
	end
	return { ok = true, teleportTarget = dst.teleportTarget }
end

return M
