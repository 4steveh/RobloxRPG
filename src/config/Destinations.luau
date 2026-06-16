--!strict
-- DESTINATION + GATE catalog — the teleport registry and the gating DAG (progression §2).
-- MVL chain Bayou → Appalachia → Alaska, plus a Rockies (T3) post-launch STUB and a Deep Sea (T7)
-- fishing-only FIXTURE. Gates are DATA: inserting Rockies = re-pointing Alaska's prerequisiteDestinations,
-- zero logic change (proven by tests/Gate.spec.luau).
--
-- gate.milestoneTargets are the PREREQUISITE's conquest targets (loop-aware via the catalog); the
-- gate is satisfied for the milestone half when one of them has been conquered on an offered loop.
-- prerequisiteDestinations are the DAG edges (⊆ conqueredDestinations) — the field the Rockies test re-threads.

local Enums = require("@src/types/Enums")
local Schema = require("@src/types/Schema")
local Ids = require("@src/types/Ids")

type Destination = Schema.Destination

local D = Ids.Destination
local L = Enums.Loop

local rows: { Destination } = {
	{
		id = D.Bayou,
		name = "Louisiana Bayou",
		tier = 1,
		offeredLoops = { L.Hunting, L.Fishing },
		gate = {
			requiredTier = 0, -- free starter: no gear gate, no prerequisites
			milestoneTargets = {},
			prerequisiteDestinations = {},
		},
		teleportTarget = "Bayou.ArrivalClearing",
		notes = "The free STARTER. Accessible from spawn; unlockedDestinations seeds with it (freshProfile).",
	},
	{
		id = D.Appalachia,
		name = "Appalachia / Midwest",
		tier = 2,
		offeredLoops = { L.Hunting, L.Fishing },
		gate = {
			requiredTier = 2, -- EHT ≥ 2 OR EFT ≥ 2 (first time armor enters the bill, hunter side)
			milestoneTargets = { "bayou_american_alligator", "bayou_blue_catfish" }, -- conquer the Bayou
			prerequisiteDestinations = { D.Bayou },
		},
		teleportTarget = "Appalachia.OutpostCabin",
		notes = "First difficulty step; first commitment point.",
	},
	{
		id = D.Rockies,
		name = "Rocky Mountains / Canada",
		tier = 3,
		offeredLoops = { L.Hunting, L.Fishing },
		gate = {
			requiredTier = 3, -- EHT ≥ 3 OR EFT ≥ 3
			milestoneTargets = { "appalachia_wild_boar", "appalachia_trophy_largemouth_bass" }, -- conquer Appalachia
			prerequisiteDestinations = { D.Appalachia },
		},
		teleportTarget = "Rockies.Arrival",
		notes = "POST-LAUNCH STUB. Proves DAG insertion: inserting it re-threads Alaska's prerequisiteDestinations.",
	},
	{
		id = D.Alaska,
		name = "Alaska",
		tier = 4,
		offeredLoops = { L.Hunting, L.Fishing },
		gate = {
			requiredTier = 4, -- EHT ≥ 4 OR EFT ≥ 4 (expedition-grade)
			milestoneTargets = { "appalachia_wild_boar", "appalachia_trophy_largemouth_bass" }, -- conquer Appalachia (MVL)
			prerequisiteDestinations = { D.Appalachia }, -- MVL wiring; re-points to {Rockies} when Rockies ships
		},
		teleportTarget = "Alaska.HarborCamp",
		notes = "MVL top tier. The Coastal Skiff (accessGrant=coastal) gates the coastal fishing sub-area, NOT entry"
			.. " (enforcement Steps 5/11). Grizzly + giant halibut are co-op-only apexes (no T5 gear at MVL).",
	},
	{
		id = D.DeepSea,
		name = "Deep Sea / Open Ocean",
		tier = 7,
		offeredLoops = { L.Fishing }, -- SINGLE-LOOP fixture: proves the gate reads offeredLoops, not max(EHT,EFT)
		gate = {
			requiredTier = 7,
			milestoneTargets = {}, -- empty so the fixture isolates the single-loop TIER path
			prerequisiteDestinations = {},
		},
		teleportTarget = "DeepSea.Arrival",
		notes = "Fishing-only gate FIXTURE: a maxed hunter (high EHT, low EFT) must NOT qualify.",
	},
}

local catalog: { [Ids.DestinationId]: Destination } = {}
for _, dst in rows do
	if catalog[dst.id] ~= nil then
		error("Destinations: duplicate id '" .. dst.id .. "'")
	end
	catalog[dst.id] = dst
end

return catalog
