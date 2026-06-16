--!strict
-- TELEPORT FRAMEWORK SCAFFOLD — the DestinationId registry + a teleport-service interface that takes a
-- DestinationId. INTERFACE AND REGISTRY ONLY. The gated teleport flow (enforcement + execution) and the
-- World Map UI are Step 9; the place/spawn resolution is also Step 9. Lives server-side (authoritative).

local Catalog = require("@src/config/Catalog")
local Gate = require("@src/logic/Gate")
local Schema = require("@src/types/Schema")
local Ids = require("@src/types/Ids")

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

-- STUB — Step 9 owns gate ENFORCEMENT (re-check at the boundary), the unlock write-through, and the
-- actual TeleportService place/spawn execution. Step 1 ships the interface + registry only.
function M.travelTo(_profile: PlayerData, _destinationId: DestinationId): ()
	error("TODO(step-9): gated teleport flow + World Map UI + TeleportService execution. Step 1 = registry + interface only.")
end

return M
