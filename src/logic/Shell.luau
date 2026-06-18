--!strict
-- PURE shell geometry + validation (Step 3). The headless seam under the Bayou placeholder: distances,
-- walk/crossing times, and the §2.3/§2.6 layout invariants — all computable from the Shell config, so the
-- LAYOUT is verifiable even before the art exists. (The FEEL, sightlines, and frame rate are Studio-only.)
-- Zero content literals — operates on the `shell` + `config` passed in.

local Schema = require("../types/Schema")

type Shell = Schema.Shell
type Vec3 = Schema.Vec3
type Config = Schema.Config

local M = {}

-- Horizontal (XZ) distance — walking is on the ground plane; Y is terrain height.
function M.horizontalDistance(a: Vec3, b: Vec3): number
	local dx = a.x - b.x
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

function M.walkSeconds(a: Vec3, b: Vec3, walkSpeed: number): number
	return M.horizontalDistance(a, b) / walkSpeed
end

function M.arrivalAnchor(shell: Shell): Vec3
	local zone = assert(shell.zones[shell.arrivalZoneId], shell.destinationId .. ": arrivalZoneId does not resolve")
	return zone.center
end

-- Worst-case foot crossing: max pairwise distance among all zone centers + landmark anchors ÷ walkSpeed.
function M.crossingSeconds(shell: Shell, walkSpeed: number): number
	local points: { Vec3 } = {}
	for _, z in shell.zones do
		table.insert(points, z.center)
	end
	for _, l in shell.landmarks do
		table.insert(points, l.anchor)
	end
	local maxD = 0
	for i = 1, #points do
		for j = i + 1, #points do
			local d = M.horizontalDistance(points[i], points[j])
			if d > maxD then
				maxD = d
			end
		end
	end
	return maxD / walkSpeed
end

function M.ambianceZoneOf(shell: Shell, speciesId: string): string?
	return shell.ambiancePlacements[speciesId]
end

-- Build-time validation (called on load + by tests). Asserts the §2.3/§2.6 ambiance + layout invariants.
-- TARGET (huntable/catchable) species are deliberately NOT placed here — their species→zone mapping is
-- Steps 4/5; this asserts their absence so the seam stays clean.
function M.validateShell(shell: Shell, config: Config)
	local dst = shell.destinationId
	assert(shell.zones[shell.arrivalZoneId] ~= nil, dst .. ": arrivalZoneId '" .. shell.arrivalZoneId .. "' must resolve to a zone")
	for id, z in shell.zones do
		assert(z.id == id, dst .. ": zone key/id mismatch at '" .. id .. "'")
	end
	for id, l in shell.landmarks do
		assert(l.id == id, dst .. ": landmark key/id mismatch at '" .. id .. "'")
	end
	-- §2.6.3: the travel signpost is co-located with the vendor outpost.
	assert(
		shell.travelSignpostAnchor.x == shell.vendorOutpostAnchor.x
			and shell.travelSignpostAnchor.z == shell.vendorOutpostAnchor.z,
		dst .. ": the travel signpost must be co-located with the vendor outpost (§2.6.3)"
	)
	-- ambiancePlacements: each is an ambianceOnly creature of THIS Destination → a valid zone; no targets.
	for speciesId, zoneId in shell.ambiancePlacements do
		local creature = config.creatures[speciesId]
		assert(creature ~= nil, dst .. ": ambiance placement '" .. speciesId .. "' is not a creature")
		assert(creature.ambianceOnly, dst .. ": '" .. speciesId .. "' is a TARGET species — target placement is Steps 4/5, not the shell")
		assert(creature.destinationId == dst, dst .. ": ambiance '" .. speciesId .. "' belongs to a different Destination")
		assert(shell.zones[zoneId] ~= nil, dst .. ": ambiance '" .. speciesId .. "' maps to unknown zone '" .. zoneId .. "'")
	end
	-- coverage: every ambianceOnly creature of this Destination has a home zone in the shell.
	for cid, c in config.creatures do
		if c.destinationId == dst and c.ambianceOnly then
			assert(shell.ambiancePlacements[cid] ~= nil, dst .. ": ambiance species '" .. cid .. "' has no home zone in the shell")
		end
	end
end

return M
