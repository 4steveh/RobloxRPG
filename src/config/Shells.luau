--!strict
-- DESTINATION SHELL registry (Step 3). The Bayou as DATA: the §2.3 named zones, the §2.2 landmarks, the
-- §2.6 onboarding-seam anchors, ambiance placement, and the §2.5 fog budget — keyed by DestinationId so a
-- second Destination (Appalachia, Step 10) plugs in the same way. Positions are plain {x,y,z} (headless);
-- the world blockout converts to Vector3. Coordinates are chosen to satisfy §2.6's measurable layout
-- constraints (asserted in tests). Self-validates on load via Shell.validateShell.

local Schema = require("@src/types/Schema")
local Ids = require("@src/types/Ids")
local Catalog = require("@src/config/Catalog")
local Shell = require("@src/logic/Shell")
local Spawner = require("@src/logic/Spawner")
local Spawning = require("@src/config/Spawning")

type Vec3 = Schema.Vec3
local D = Ids.Destination

local function v(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

-- The Landing: vendor outpost AND travel signpost are co-located here (§2.6.3). ~16 s walk from arrival.
local landingAnchor = v(0, 0, 255)

local bayou: Schema.Shell = {
	destinationId = D.Bayou,
	arrivalZoneId = "arrival_clearing",
	zones = {
		arrival_clearing = {
			id = "arrival_clearing",
			name = "Arrival Clearing",
			kind = "arrival",
			center = v(0, 0, 0),
			size = v(40, 1, 40),
			description = "A sunlit levee spot beside the Landing; faces the Sunny Levee, channel bank a few steps off (§2.6.1).",
		},
		sunny_levee = {
			id = "sunny_levee",
			name = "Sunny Levee",
			kind = "hunting",
			center = v(0, 0, -50), -- the arrival clearing faces it (adjacent, §2.6.1)
			size = v(60, 1, 40),
			description = "The dry hunting flat — first-hunt ground (rabbits, duck flocks on the reed-edge).",
		},
		reed_edges = {
			id = "reed_edges",
			name = "Reed Edges",
			kind = "hunting",
			center = v(-45, 0, -45),
			size = v(50, 1, 50),
			description = "Reed beds and grassy verges — floor-game cover.",
		},
		channel_banks = {
			id = "channel_banks",
			name = "Channel Banks",
			kind = "fishing",
			center = v(24, 0, 12), -- a few steps from arrival (§2.6.1, first fish)
			size = v(40, 1, 30),
			description = "Shore-accessible fishing water (panfish, catfish); the signature alligator also lurks here.",
		},
		catfish_hole = {
			id = "catfish_hole",
			name = "The Catfish Hole",
			kind = "fishing",
			center = v(120, 0, 70),
			size = v(50, 1, 50),
			description = "The deep oxbow — the best fishing water and the rare/legendary catfish condition site.",
		},
		cottonmouth_slough = {
			id = "cottonmouth_slough",
			name = "Cottonmouth Slough",
			kind = "rareSite",
			center = v(-110, 0, 80),
			size = v(50, 1, 60),
			description = "A fog-prone back-channel of deep cypress shade — the White Gator (Ghost Gator) condition site.",
		},
		the_landing = {
			id = "the_landing",
			name = "The Landing",
			kind = "vendor",
			center = landingAnchor,
			size = v(40, 1, 40),
			description = "Dock + general-store shack: the vendor outpost (Outfitter + Tackle Shop) and the travel signpost.",
		},
	},
	landmarks = {
		the_landing = {
			id = "the_landing",
			name = "The Landing",
			anchor = landingAnchor,
			isBeacon = false,
			description = "The social anchor + vendor outpost + travel signpost — the heart of the onboarding seam (§2.6).",
		},
		the_old_cypress = {
			id = "the_old_cypress",
			name = "The Old Cypress",
			anchor = v(55, 0, 110),
			isBeacon = true,
			description = "A huge lightning-split cypress visible from most of the map — the primary wayfinding beacon (§2.2).",
		},
	},
	vendorOutpostAnchor = landingAnchor,
	travelSignpostAnchor = landingAnchor, -- co-located with the vendor outpost (§2.6.3)
	ambiancePlacements = {
		-- ambianceOnly species ONLY (target species are placed by the Steps 4/5 spawner, not here).
		bayou_great_egret = "channel_banks",
		bayou_painted_turtle = "catfish_hole",
		bayou_songbird = "reed_edges",
	},
	render = { fogStart = 80, fogEnd = 320, drawDistance = 320 }, -- §2.5 swamp fog doubles as the view-distance cull
}

local Shells = {}

-- Character-controller tunables (Tier 1 = on-foot only). walkSpeed is applied server-side; the camera
-- zoom is read by the client controller. NOT tuned vs fleeing-game speed (that's Step 4's escape window).
local movement: Schema.Movement = { walkSpeed = 16, jumpPower = 50, cameraMinZoom = 8, cameraMaxZoom = 14 }
Shells.movement = movement

local byDestination: { [Ids.DestinationId]: Schema.Shell } = { [D.Bayou] = bayou }
Shells.byDestination = byDestination

-- Build-time guarantee: a malformed shell fails the require.
Shell.validateShell(bayou, Catalog)

-- Step-4 build-time guarantee (P1): every Bayou hunting spawn area + every target's spawnZones resolve to
-- a real zone in this shell. (The fishing placement check plugs in here the same way at Step 5.)
local bayouSpawn = Spawning.byDestination[D.Bayou]
if bayouSpawn ~= nil and bayouSpawn.hunting ~= nil then
	Spawner.validatePlacement(Catalog, bayou, bayouSpawn.hunting)
end

return Shells
