--!strict
-- DESTINATION SHELL registry (Step 3). The Bayou as DATA: the §2.3 named zones, the §2.2 landmarks, the
-- §2.6 onboarding-seam anchors, ambiance placement, and the §2.5 fog budget — keyed by DestinationId so a
-- second Destination (Appalachia, Step 10) plugs in the same way. Positions are plain {x,y,z} (headless);
-- the world blockout converts to Vector3. Coordinates are chosen to satisfy §2.6's measurable layout
-- constraints (asserted in tests). Self-validates on load via Shell.validateShell.

local Schema = require("@src/types/Schema")
local Ids = require("@src/types/Ids")
local Enums = require("@src/types/Enums")
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

-- Appalachia (LOC_02 §2): the mountain-south world. Vendor outpost + travel signpost co-located at the
-- Outpost Cabin (§2.6.3). Coordinates are a compact planar footprint; the Studio blockout converts to
-- Vector3. Y=0 is the reference ground plane for all centers and anchors.
local apOutpostAnchor = v(0, 0, 200)

local appalachia: Schema.Shell = {
	destinationId = D.Appalachia,
	arrivalZoneId = "outpost_cabin",
	zones = {
		outpost_cabin = {
			id = "outpost_cabin",
			name = "Outpost Cabin",
			kind = "vendor",
			center = apOutpostAnchor,
			size = v(40, 1, 40),
			description = "The mountain trailhead cabin: vendor outpost (Outfitter + Tackle Shop) and travel signpost. Arrival zone.",
		},
		old_field = {
			id = "old_field",
			name = "Old Field",
			kind = "hunting",
			center = v(0, 0, 80),
			size = v(80, 1, 60),
			description = "Brushy fallow ground — deer, cottontail, turkey. The Ghost Buck and Piebald Whitetail dawn-light condition site.",
		},
		oak_ridges = {
			id = "oak_ridges",
			name = "Oak Ridges",
			kind = "hunting",
			center = v(-120, 0, 60),
			size = v(70, 1, 60),
			description = "Dense mid-slope oak stands — boar territory; a bruising Uncommon wall requiring T2 kit.",
		},
		creek_bottoms = {
			id = "creek_bottoms",
			name = "Creek Bottoms",
			kind = "hunting",
			center = v(110, 0, 50),
			size = v(70, 1, 60),
			description = "Shaded draws and brush-choked creek-flats — coyote pack territory; the co-op tutorial ground.",
		},
		lookout_ridge = {
			id = "lookout_ridge",
			name = "Lookout Ridge",
			kind = "hunting",
			center = v(0, 0, -130),
			size = v(70, 1, 60),
			description = "High open ridge — mountain lion apex territory and the Black Catamount night-fog condition site.",
		},
		hollow_creek = {
			id = "hollow_creek",
			name = "Hollow Creek",
			kind = "fishing",
			center = v(100, 0, -60),
			size = v(60, 1, 40),
			description = "Clear-water fly fishing — brook trout and smallmouth bass; the signature Appalachia trout water.",
		},
		mill_pond = {
			id = "mill_pond",
			name = "Mill Pond",
			kind = "fishing",
			center = v(-90, 0, -80),
			size = v(70, 1, 60),
			description = "Deep impoundment — panfish, bass, pike, muskie. The Trophy Largemouth and Tiger Muskie condition site.",
		},
	},
	landmarks = {
		lookout_ridge = {
			id = "lookout_ridge",
			name = "Lookout Ridge",
			anchor = v(0, 0, -130),
			isBeacon = true,
			description = "The hero vista — the primary wayfinding beacon visible across the mountain. Also the cougar apex zone.",
		},
		hollow_creek = {
			id = "hollow_creek",
			name = "Hollow Creek",
			anchor = v(100, 0, -60),
			isBeacon = false,
			description = "The fly-water landmark — navigate by the sound of the riffle.",
		},
		mill_pond = {
			id = "mill_pond",
			name = "Mill Pond",
			anchor = v(-90, 0, -80),
			isBeacon = false,
			description = "The old mill impoundment — the signature stillwater landmark.",
		},
		the_old_field = {
			id = "the_old_field",
			name = "The Old Field",
			anchor = v(0, 0, 80),
			isBeacon = false,
			description = "The first hunting ground visible from the cabin — the onboarding hunting landmark.",
		},
		outpost_cabin = {
			id = "outpost_cabin",
			name = "Outpost Cabin",
			anchor = apOutpostAnchor,
			isBeacon = false,
			description = "The social hub + vendor outpost + travel signpost at the trailhead.",
		},
	},
	vendorOutpostAnchor = apOutpostAnchor,
	travelSignpostAnchor = apOutpostAnchor, -- co-located with the vendor outpost (§2.6.3)
	ambiancePlacements = {
		-- ambianceOnly species ONLY (target species are placed by the Steps 4/5 spawner, not here).
		appalachia_gray_squirrel = "old_field", -- the sole ambianceOnly Appalachia creature (LOC_02)
	},
	render = { fogStart = 90, fogEnd = 340, drawDistance = 340 }, -- LOC_02 §2.5 dawn-fog budget
}

-- Alaska (LOC_04 §2): the sub-Arctic frontier world. Harbor Camp is the vendor outpost + arrival zone.
-- Vendor outpost and travel signpost are co-located at Harbor Camp (§2.6.3). The coastal sub-area
-- (coastal_inlet, open_gulf) is walled until Step 11 (Boat unlock); Boat-gating lives on fish waterType.
-- Snow-glare fog budget: fogStart=100, fogEnd=380, drawDistance=380 (LOC_04 §2.5).
local akOutpostAnchor = v(0, 0, 180)

local alaska: Schema.Shell = {
	destinationId = D.Alaska,
	arrivalZoneId = "harbor_camp",
	zones = {
		harbor_camp = {
			id = "harbor_camp",
			name = "Harbor Camp",
			kind = "vendor",
			center = akOutpostAnchor,
			size = v(50, 1, 50),
			description = "The dockside base camp: vendor outpost (Outfitter + Tackle Shop) and travel signpost. Arrival zone.",
		},
		tundra_flats = {
			id = "tundra_flats",
			name = "Tundra Flats",
			kind = "hunting",
			center = v(0, 0, 50),
			size = v(120, 1, 80),
			description = "Open tundra interior — hare, caribou, and moose grounds. The broad floor-game flat.",
		},
		spruce_riverbottom = {
			id = "spruce_riverbottom",
			name = "Spruce Riverbottom",
			kind = "hunting",
			center = v(-110, 0, 30),
			size = v(80, 1, 70),
			description = "Dense spruce-edge draws along the river bottom — Sitka deer, moose, and grizzly approach corridor.",
		},
		the_crags = {
			id = "the_crags",
			name = "The Crags",
			kind = "hunting",
			center = v(90, 0, -70),
			size = v(70, 1, 60),
			description = "High broken-rock terrain — Dall sheep range. Kept for Studio/completeness; no catalog target at MVP.",
		},
		salmon_falls = {
			id = "salmon_falls",
			name = "Salmon Falls",
			kind = "rareSite",
			center = v(-60, 0, -90),
			size = v(70, 1, 60),
			description = "The grizzly co-op apex zone. Glacier Grizzly (Legendary) condition site. The marquee Alaska hunt.",
		},
		interior_river = {
			id = "interior_river",
			name = "Interior River",
			kind = "fishing",
			center = v(60, 0, -50),
			size = v(70, 1, 50),
			description = "Shore-accessible river fishing — grayling, Dolly Varden, sockeye salmon (seasonal run).",
		},
		coastal_inlet = {
			id = "coastal_inlet",
			name = "Coastal Inlet",
			kind = "fishing",
			center = v(140, 0, -120),
			size = v(80, 1, 60),
			description = "Boat-gated coastal cell (walled until Step 11) — rockfish/lingcod/king salmon. waterType=coastal.",
		},
		open_gulf = {
			id = "open_gulf",
			name = "Open Gulf",
			kind = "fishing",
			center = v(200, 0, -200),
			size = v(90, 1, 90),
			description = "Deep Boat-gated water — Giant Halibut (Uncommon apex, co-op) + Ghost of the Gulf (Mythic). waterType=coastal.",
		},
		frozen_lake = {
			id = "frozen_lake",
			name = "Frozen Lake",
			kind = "fishing",
			center = v(-150, 0, -160),
			size = v(80, 1, 80),
			description = "Seasonal ice-fishing lake (§9). No MVL catalog target; zone present for future content.",
		},
	},
	landmarks = {
		the_glacier = {
			id = "the_glacier",
			name = "The Glacier",
			anchor = v(0, 0, -250),
			isBeacon = true,
			description = "The towering glacier terminus — the primary wayfinding beacon visible across the entire map (LOC_04 §2.2).",
		},
		harbor_camp = {
			id = "harbor_camp",
			name = "Harbor Camp",
			anchor = akOutpostAnchor,
			isBeacon = false,
			description = "The social hub + vendor outpost + travel signpost at the dockside base.",
		},
		tundra_flats = {
			id = "tundra_flats",
			name = "Tundra Flats",
			anchor = v(0, 0, 50),
			isBeacon = false,
			description = "The open hunting flat — navigate by the open sky above the treeline.",
		},
		salmon_falls = {
			id = "salmon_falls",
			name = "Salmon Falls",
			anchor = v(-60, 0, -90),
			isBeacon = false,
			description = "The falls landmark — the sound of rushing water and grizzly apex ground.",
		},
		the_crags = {
			id = "the_crags",
			name = "The Crags",
			anchor = v(90, 0, -70),
			isBeacon = false,
			description = "The high broken-rock bluff — Dall sheep country and a distant sight-line marker.",
		},
		open_gulf = {
			id = "open_gulf",
			name = "Open Gulf",
			anchor = v(200, 0, -200),
			isBeacon = false,
			description = "The distant coastal expanse — the Boat-gated horizon landmark.",
		},
		frozen_lake = {
			id = "frozen_lake",
			name = "Frozen Lake",
			anchor = v(-150, 0, -160),
			isBeacon = false,
			description = "The ice-fishing lake — a still white mirror in the tundra winter.",
		},
	},
	vendorOutpostAnchor = akOutpostAnchor,
	travelSignpostAnchor = akOutpostAnchor, -- co-located with the vendor outpost (§2.6.3)
	ambiancePlacements = {
		-- The catalog has NO ambianceOnly Alaska creatures (ptarmigan/fox/eagle/otter in LOC_04 §3 ambiance
		-- list are NOT in the representative catalog). Coverage loop finds none → passes. Empty is correct.
	},
	render = { fogStart = 100, fogEnd = 380, drawDistance = 380 }, -- LOC_04 §2.5 snow-glare budget
}

local Shells = {}

-- Character-controller tunables (Tier 1 = on-foot only). walkSpeed is applied server-side; the camera
-- zoom is read by the client controller. NOT tuned vs fleeing-game speed (that's Step 4's escape window).
local movement: Schema.Movement = { walkSpeed = 16, jumpPower = 50, cameraMinZoom = 8, cameraMaxZoom = 14 }
Shells.movement = movement

-- The Lodge hub arrival (Step 8). The Lodge is the player's home HUB, NOT a requiredTier-0 Destination, so
-- it does not live in `byDestination`/the gate DAG — it is its own arrival target the routing branch returns
-- for a funnel-COMPLETE (returning) player. The interior + service fixtures are Studio (WorldServer); this is
-- the headless arrival DATA the router needs. (Positions are plain {x,y,z}; the world converts to Vector3.)
Shells.lodge = { zoneId = "lodge_hub", anchor = v(0, 0, 600) }

local byDestination: { [Ids.DestinationId]: Schema.Shell } = { [D.Bayou] = bayou, [D.Appalachia] = appalachia, [D.Alaska] = alaska }
Shells.byDestination = byDestination

-- Build-time guarantee: a malformed shell fails the require.
Shell.validateShell(bayou, Catalog)

-- Step-4 build-time guarantee (P1): every Bayou hunting spawn area + every target's spawnZones resolve to
-- a real zone in this shell. (The fishing placement check plugs in here the same way at Step 5.)
local bayouSpawn = Spawning.byDestination[D.Bayou]
if bayouSpawn ~= nil and bayouSpawn.hunting ~= nil then
	Spawner.validatePlacement(Catalog, bayou, bayouSpawn.hunting, Enums.Loop.Hunting)
end
-- Step-5: the fishing placement check plugs in the same way (every Bayou fish resolves to a water zone).
if bayouSpawn ~= nil and bayouSpawn.fishing ~= nil then
	Spawner.validatePlacement(Catalog, bayou, bayouSpawn.fishing, Enums.Loop.Fishing)
end

-- Step-10 (Task 1.3): Appalachia shell build-time guarantee.
Shell.validateShell(appalachia, Catalog)

-- Step-10 (Task 1.4 wiring point): guarded validatePlacement — apSpawn is nil until Task 1.4 adds the
-- Appalachia spawn config to Spawning.luau. The guards keep Task 1.3 green; validatePlacement goes live
-- at Task 1.4 when Spawning.byDestination[D.Appalachia] is populated.
local apSpawn = Spawning.byDestination[D.Appalachia]
if apSpawn ~= nil and apSpawn.hunting ~= nil then
	Spawner.validatePlacement(Catalog, appalachia, apSpawn.hunting, Enums.Loop.Hunting)
end
if apSpawn ~= nil and apSpawn.fishing ~= nil then
	Spawner.validatePlacement(Catalog, appalachia, apSpawn.fishing, Enums.Loop.Fishing)
end

-- Step-10 (Task 2.4): Alaska shell build-time guarantee.
Shell.validateShell(alaska, Catalog)

-- Step-10 (Task 2.5 wiring point): guarded validatePlacement — akSpawn is nil until Task 2.5 adds the
-- Alaska spawn config to Spawning.luau. The guards keep Task 2.4 green; validatePlacement goes live
-- at Task 2.5 when Spawning.byDestination[D.Alaska] is populated.
local akSpawn = Spawning.byDestination[D.Alaska]
if akSpawn ~= nil and akSpawn.hunting ~= nil then
	Spawner.validatePlacement(Catalog, alaska, akSpawn.hunting, Enums.Loop.Hunting)
end
if akSpawn ~= nil and akSpawn.fishing ~= nil then
	Spawner.validatePlacement(Catalog, alaska, akSpawn.fishing, Enums.Loop.Fishing)
end

return Shells
