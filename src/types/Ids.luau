--!strict
-- Stable string identifiers. IDs are the join keys across every catalog; they never change.
-- DestinationId is a first-class registry (the teleport framework + gate DAG key, 01/progression).

local Ids = {}

-- Destinations are referenced by a stable id everywhere (gates, teleport, milestone home lookup).
export type DestinationId = string

-- The canonical MVL + near-term registry. The DeepSea entry is the fishing-only gate fixture.
Ids.Destination = table.freeze({
	Bayou = "bayou" :: DestinationId, -- Tier 1 (free starter)
	Appalachia = "appalachia" :: DestinationId, -- Tier 2
	Rockies = "rockies" :: DestinationId, -- Tier 3 (post-launch stub — proves DAG insertion)
	Alaska = "alaska" :: DestinationId, -- Tier 4 (MVL top)
	DeepSea = "deep_sea" :: DestinationId, -- Tier 7 fishing-only fixture (single-loop gate path)
})

-- Creatures, fish, and equipment share the TargetId/ItemId string space (distinct prefixes by convention).
export type TargetId = string -- a creature or fish id
export type ItemId = string -- an equipment id
export type ArtifactId = string -- a server-minted unique id (Step 2 mints these)

return table.freeze(Ids)
