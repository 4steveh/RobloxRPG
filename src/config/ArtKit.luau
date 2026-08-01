--!strict
-- THE ART KIT — every visual value in Wild World, as pure data. src/logic/ArtGen.luau turns these recipes
-- into part descriptors; src/server/world/WorldArt.server.luau instantiates them; client/BiomeLook applies
-- the lighting. Nothing here references a Roblox global, so the whole art direction is headless-verifiable.
--
-- CALIBRATED AGAINST THE REFERENCE. The target bar is Roblox's own "Pirate Island" Studio template, read
-- live out of Studio (2026-08-01). What that measurement established, and what this file therefore does:
--   * 15,364 plain Parts, ZERO MeshParts, ZERO SurfaceAppearance → polish comes from part DENSITY and
--     per-part colour variation, not from imported assets. Every recipe here is parts-only.
--   * A single template tree is 39-41 Block parts: ~25 tapering Wood "Branch" parts on one bark colour,
--     ~15 flat Grass "Leaf" slabs drawn from FIVE greens. The multi-colour foliage palette is the single
--     highest-impact trick and every foliage recipe below carries 4-6 hues.
--   * Landmasses are sculpted smooth Terrain with per-material colour overrides, not parts.
--   * The lighting stack (Brightness 2.44, ShadowSoftness 0.85, EnvironmentDiffuse/Specular 1, Atmosphere
--     density 0.30, Bloom 1/2/24, SunRays 0.25, DoF far 0.025) does the rest.
--
-- ONE PLACE, THREE BIOMES: the three destinations sit 2000 studs apart in one place, so `Lighting` is
-- shared. Per-biome looks are therefore applied CLIENT-SIDE (client/BiomeLook.luau) from the presets in
-- `looks` below — a server-side Lighting write would give every player the same biome's sky. Terrain
-- material colours ARE global, which is why each biome is assigned its own disjoint material set.

local Art = require("../types/Art")
-- Required for its TYPES only (BiomeTerrainSpec / HeightBand), the same way Shells.luau reaches for
-- logic/Shell's types. No behaviour crosses the boundary: ArtKit calls nothing.
local TerrainGenTypes = require("../logic/TerrainGen")

type RGB = Art.RGB
type TreeRecipe = Art.TreeRecipe
type RockRecipe = Art.RockRecipe
type ClusterRecipe = Art.ClusterRecipe
type CabinRecipe = Art.CabinRecipe
type MaterialName = Art.MaterialName
type TerrainMaterialName = Art.TerrainMaterialName

local M = Art.Material
local TM = Art.TerrainMaterial
local S = Art.Shape

local ArtKit = {}

ArtKit.version = 2

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════
-- PALETTES. Each element type carries 4-6 hues; the generators pick per part. Values are RGB 0-255.
-- Discipline: within one element type the hues share a family and differ mainly in VALUE and slightly in
-- hue — that is what reads as one material lit unevenly, rather than as confetti.
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════

ArtKit.palettes = {
	bayou = {
		-- wet cypress bark: grey-brown, low saturation, wide value range for the buttressed base
		bark = { { 87, 70, 60 }, { 100, 78, 63 }, { 114, 87, 65 }, { 128, 96, 65 } } :: { RGB },
		-- cypress needle green: soft, slightly yellow, five steps
		foliage = { { 87, 81, 58 }, { 98, 102, 56 }, { 92, 117, 49 }, { 72, 133, 39 }, { 33, 148, 25 } } :: { RGB },
		-- Spanish moss: desaturated sage, the signature Bayou silhouette element
		moss = { { 138, 135, 121 }, { 150, 150, 123 }, { 155, 163, 124 }, { 157, 176, 123 }, { 152, 189, 121 } } :: { RGB },
		reed = { { 97, 89, 61 }, { 111, 112, 58 }, { 107, 128, 51 }, { 90, 143, 41 }, { 57, 158, 27 } } :: { RGB },
		fern = { { 78, 79, 52 }, { 80, 93, 50 }, { 72, 107, 45 }, { 51, 121, 36 }, { 24, 135, 34 } } :: { RGB },
		duckweed = { { 92, 89, 58 }, { 97, 109, 53 }, { 84, 126, 44 }, { 51, 143, 30 } } :: { RGB },
		log = { { 88, 74, 58 }, { 72, 60, 46 }, { 102, 88, 70 } } :: { RGB },
		stone = { { 77, 75, 73 }, { 94, 91, 86 }, { 111, 107, 98 }, { 128, 124, 108 } } :: { RGB },
		lilypad = { { 86, 92, 60 }, { 83, 109, 55 }, { 64, 126, 47 }, { 33, 143, 42 } } :: { RGB },
	},
	appalachia = {
		bark = { { 92, 74, 62 }, { 105, 83, 64 }, { 119, 92, 65 }, { 133, 101, 65 } } :: { RGB },
		birchBark = { { 194, 191, 186 }, { 207, 203, 195 }, { 221, 216, 203 }, { 235, 230, 211 } } :: { RGB },
		-- late-summer hardwood: deep greens with two warm turning hues so the ridge reads with depth
		foliage = { { 102, 99, 68 }, { 108, 117, 64 }, { 97, 133, 56 }, { 70, 148, 44 }, { 28, 163, 32 } } :: { RGB },
		autumn = { { 140, 67, 58 }, { 157, 84, 51 }, { 173, 108, 42 }, { 190, 140, 29 }, { 207, 184, 14 } } :: { RGB },
		needle = { { 48, 61, 43 }, { 45, 74, 44 }, { 42, 87, 48 }, { 36, 99, 56 }, { 28, 112, 70 } } :: { RGB },
		stone = { { 82, 79, 76 }, { 99, 94, 88 }, { 116, 110, 100 }, { 133, 126, 110 } } :: { RGB },
		fern = { { 81, 84, 55 }, { 82, 98, 53 }, { 73, 112, 47 }, { 52, 126, 38 }, { 27, 140, 38 } } :: { RGB },
		log = { { 92, 78, 62 }, { 76, 64, 50 }, { 106, 92, 74 } } :: { RGB },
		grassTuft = { { 99, 96, 63 }, { 107, 115, 60 }, { 96, 131, 52 }, { 69, 146, 40 }, { 30, 161, 30 } } :: { RGB },
	},
	alaska = {
		bark = { { 66, 54, 48 }, { 80, 63, 54 }, { 94, 72, 57 }, { 107, 81, 59 } } :: { RGB },
		-- frosted spruce: cold, dark, low chroma — the cue that reads "north" before any snow does
		needle = { { 40, 54, 39 }, { 40, 65, 42 }, { 38, 77, 48 }, { 34, 88, 58 }, { 28, 99, 73 } } :: { RGB },
		snow = { { 228, 232, 235 }, { 233, 239, 245 }, { 237, 245, 255 } } :: { RGB },
		ice = { { 177, 196, 204 }, { 182, 204, 218 }, { 186, 210, 231 }, { 188, 215, 245 } } :: { RGB },
		stone = { { 82, 84, 87 }, { 95, 98, 104 }, { 107, 110, 121 }, { 117, 120, 138 } } :: { RGB },
		tundra = { { 92, 77, 67 }, { 109, 95, 69 }, { 126, 119, 67 }, { 133, 143, 61 } } :: { RGB },
		log = { { 82, 70, 58 }, { 66, 56, 46 }, { 96, 84, 70 } } :: { RGB },
	},
	-- Cross-biome elements. Dead wood and snow-laden foliage appear in more than one destination, so they
	-- live here rather than being duplicated (or worse, inlined at the recipe, which is how a palette drifts).
	shared = {
		-- sun-bleached standing deadwood: bark discipline (narrow hue, narrow saturation, wide value)
		deadwood = { { 128, 118, 104 }, { 145, 134, 118 }, { 161, 150, 132 }, { 178, 166, 146 } } :: { RGB },
		-- snow sitting ON dark needles: deliberately BIMODAL, not a ramp. The whole read is the value gap
		-- between lit snow and the shadowed needle underneath, so the two clusters must stay far apart.
		snowLaden = { { 34, 88, 58 }, { 210, 218, 226 }, { 40, 65, 42 }, { 233, 239, 245 }, { 28, 99, 73 } } :: { RGB },
	},
	lodge = {
		-- interior wood, warm: the hub must feel lit and lived-in against three cold exteriors
		log = { { 115, 86, 67 }, { 130, 96, 68 }, { 145, 106, 69 }, { 161, 117, 67 } } :: { RGB },
		trim = { { 84, 60, 40 }, { 72, 50, 34 }, { 96, 70, 48 } } :: { RGB },
		roof = { { 74, 62, 54 }, { 62, 52, 46 }, { 86, 72, 62 } } :: { RGB },
		floor = { { 138, 110, 76 }, { 122, 96, 66 }, { 152, 124, 88 } } :: { RGB },
		stone = { { 104, 100, 94 }, { 88, 84, 80 }, { 118, 112, 104 }, { 74, 72, 68 } } :: { RGB },
		brass = { { 198, 162, 84 }, { 176, 142, 72 }, { 214, 180, 104 } } :: { RGB },
		fabric = { { 128, 58, 46 }, { 108, 48, 38 }, { 146, 70, 54 } } :: { RGB },
		glass = { 186, 206, 214 } :: RGB,
		lampWarm = { 255, 214, 158 } :: RGB,
		fireWarm = { 255, 168, 88 } :: RGB,
	},
}

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════
-- TREES. `targetHeight` is the finished silhouette height; the generator normalises to it, so a recipe's
-- segment numbers control SHAPE and the height band controls SCALE independently.
-- Part-count budget (asserted in tests/ArtGen.spec.luau): hero ≤ 260, canopy ≤ 130, filler ≤ 60.
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════

local P = ArtKit.palettes

ArtKit.trees = {
	-- ── Bayou ────────────────────────────────────────────────────────────────────────────────────────
	-- Bald cypress: buttressed flared base standing in water, high spreading crown, moss drape.
	baldCypress = {
		name = "BaldCypress",
		limb = {
			radius = 1.5,
			length = 6.6,
			segments = 4,
			radiusTaper = 0.84,
			lengthTaper = 0.9,
			lean = 0.05,
			levels = 2,
			-- branching starts high: a cypress carries its crown well above the waterline, and it also
			-- holds the recipe near the reference template's ~40-part-per-tree budget.
			branchStart = 0.8,
			childMin = 2,
			childMax = 3,
			spread = { min = 0.45, max = 0.95 },
			childRadiusScale = 0.58,
			childLengthScale = 0.7,
			upBias = 0.22,
		},
		foliage = {
			kind = "slab" :: Art.FoliageKind,
			countMin = 1,
			countMax = 2,
			size = { x = 9.5, y = 2.1, z = 9.5 },
			sizeJitter = 0.3,
			spread = 4.5,
			rise = 1.8,
			tilt = 0.34,
			material = M.Grass,
			colors = P.bayou.foliage,
		},
		flare = { count = 7, radius = 2.8, height = 3.4, thickness = 1.4 },
		-- moss hangs from TERMINAL limbs only (minLevel = levels): draping every limb tripled the part
		-- count for silhouette the player cannot resolve anyway.
		drape = {
			count = 1,
			length = { min = 3.5, max = 8 },
			thickness = 0.34,
			material = M.Grass,
			colors = P.bayou.moss,
			minLevel = 2,
		},
		barkMaterial = M.Wood,
		barkColors = P.bayou.bark,
		contactShade = 0.4,
		targetHeight = { min = 26, max = 40 },
	} :: TreeRecipe,
	-- The Old Cypress — the §2.2 wayfinding beacon. Same species, hero mass, heavier drape.
	oldCypress = {
		name = "TheOldCypress",
		limb = {
			radius = 3.1,
			length = 8.4,
			segments = 5,
			radiusTaper = 0.86,
			lengthTaper = 0.92,
			lean = 0.04,
			levels = 3,
			branchStart = 0.5,
			childMin = 2,
			childMax = 3,
			spread = { min = 0.4, max = 0.9 },
			childRadiusScale = 0.6,
			childLengthScale = 0.72,
			upBias = 0.2,
		},
		foliage = {
			kind = "slab" :: Art.FoliageKind,
			countMin = 1,
			countMax = 2,
			size = { x = 11, y = 2.4, z = 11 },
			sizeJitter = 0.3,
			spread = 5.5,
			rise = 2,
			tilt = 0.32,
			material = M.Grass,
			colors = P.bayou.foliage,
		},
		flare = { count = 10, radius = 5.2, height = 6, thickness = 2.2 },
		drape = {
			count = 2,
			length = { min = 5, max = 13 },
			thickness = 0.42,
			material = M.Grass,
			colors = P.bayou.moss,
			minLevel = 2,
		},
		barkMaterial = M.Wood,
		barkColors = P.bayou.bark,
		contactShade = 0.45,
		targetHeight = { min = 62, max = 68 },
	} :: TreeRecipe,
	-- Dead snag: bare, pale, no foliage. Breaks up a grove and reads as swamp attrition.
	snag = {
		name = "Snag",
		limb = {
			radius = 1.1,
			length = 4.6,
			segments = 6,
			radiusTaper = 0.84,
			lengthTaper = 0.9,
			lean = 0.11,
			levels = 2,
			branchStart = 0.45,
			childMin = 1,
			childMax = 2,
			spread = { min = 0.6, max = 1.25 },
			childRadiusScale = 0.52,
			childLengthScale = 0.6,
			upBias = 0.1,
		},
		foliage = {
			kind = "none" :: Art.FoliageKind,
			countMin = 0,
			countMax = 0,
			size = { x = 1, y = 1, z = 1 },
			sizeJitter = 0,
			spread = 0,
			rise = 0,
			tilt = 0,
			material = M.Wood,
			colors = P.shared.deadwood,
		},
		barkMaterial = M.Wood,
		barkColors = P.shared.deadwood,
		contactShade = 0.32,
		targetHeight = { min = 18, max = 30 },
	} :: TreeRecipe,

	-- ── Appalachia ───────────────────────────────────────────────────────────────────────────────────
	-- Broad oak: the wide-crown hardwood that gives a ridge its skyline.
	oak = {
		name = "Oak",
		limb = {
			radius = 1.8,
			length = 5.8,
			segments = 3,
			radiusTaper = 0.8,
			lengthTaper 	= 0.88,
			lean = 0.07,
			levels = 2,
			branchStart = 0.4,
			childMin = 2,
			childMax = 3,
			spread = { min = 0.55, max = 1.15 },
			childRadiusScale = 0.6,
			childLengthScale = 0.76,
			upBias = 0.18,
		},
		foliage = {
			kind = "slab" :: Art.FoliageKind,
			countMin = 1,
			countMax = 2,
			size = { x = 10.5, y = 2.6, z = 10.5 },
			sizeJitter = 0.32,
			spread = 5,
			rise = 1.6,
			tilt = 0.4,
			material = M.Grass,
			colors = P.appalachia.foliage,
		},
		flare = { count = 5, radius = 2.4, height = 2.6, thickness = 1.3 },
		barkMaterial = M.Wood,
		barkColors = P.appalachia.bark,
		contactShade = 0.38,
		targetHeight = { min = 24, max = 38 },
	} :: TreeRecipe,
	-- Turning maple: same form, autumn palette. Two or three per grove is what sells the season.
	maple = {
		name = "Maple",
		limb = {
			radius = 1.5,
			length = 5.4,
			segments = 3,
			radiusTaper = 0.82,
			lengthTaper = 0.88,
			lean = 0.08,
			levels = 2,
			branchStart = 0.45,
			childMin = 2,
			childMax = 3,
			spread = { min = 0.5, max = 1.05 },
			childRadiusScale = 0.58,
			childLengthScale = 0.74,
			upBias = 0.24,
		},
		foliage = {
			kind = "slab" :: Art.FoliageKind,
			countMin = 1,
			countMax = 2,
			size = { x = 9, y = 2.4, z = 9 },
			sizeJitter = 0.3,
			spread = 4.4,
			rise = 1.5,
			tilt = 0.4,
			material = M.Grass,
			colors = P.appalachia.autumn,
		},
		barkMaterial = M.Wood,
		barkColors = P.appalachia.bark,
		contactShade = 0.36,
		targetHeight = { min = 20, max = 32 },
	} :: TreeRecipe,
	birch = {
		name = "Birch",
		limb = {
			radius = 0.75,
			length = 6.4,
			segments = 5,
			radiusTaper = 0.9,
			lengthTaper = 0.94,
			lean = 0.035,
			levels = 1,
			branchStart = 0.6,
			childMin = 2,
			childMax = 3,
			spread = { min = 0.4, max = 0.85 },
			childRadiusScale = 0.5,
			childLengthScale = 0.6,
			upBias = 0.35,
		},
		foliage = {
			kind = "slab" :: Art.FoliageKind,
			countMin = 2,
			countMax = 3,
			size = { x = 6, y = 2, z = 6 },
			sizeJitter = 0.3,
			spread = 3,
			rise = 1.4,
			tilt = 0.42,
			material = M.Grass,
			colors = P.appalachia.foliage,
		},
		barkMaterial = M.Wood,
		barkColors = P.appalachia.birchBark,
		contactShade = 0.18,
		targetHeight = { min = 20, max = 30 },
	} :: TreeRecipe,
	-- Eastern hemlock/pine: the conifer that fills the ridge behind the hardwoods.
	pine = {
		name = "Pine",
		limb = {
			radius = 1.2,
			length = 6.2,
			segments = 7,
			radiusTaper = 0.88,
			lengthTaper = 0.94,
			lean = 0.02,
			levels = 0,
			branchStart = 1,
			childMin = 0,
			childMax = 0,
			spread = { min = 0, max = 0 },
			childRadiusScale = 0.5,
			childLengthScale = 0.6,
			upBias = 0,
		},
		foliage = {
			kind = "tier" :: Art.FoliageKind,
			countMin = 5,
			countMax = 9,
			size = { x = 8.5, y = 1.5, z = 8.5 },
			sizeJitter = 0.22,
			spread = 8,
			rise = 0.6,
			tilt = 0.42,
			material = M.Grass,
			colors = P.appalachia.needle,
		},
		barkMaterial = M.Wood,
		barkColors = P.appalachia.bark,
		contactShade = 0.34,
		targetHeight = { min = 30, max = 46 },
	} :: TreeRecipe,

	-- ── Alaska ───────────────────────────────────────────────────────────────────────────────────────
	-- Sitka spruce: tall, narrow, dark. Narrower tiers than the Appalachian pine, which is the whole
	-- visual difference between a temperate ridge and a boreal one.
	spruce = {
		name = "Spruce",
		limb = {
			radius = 1.15,
			length = 6.6,
			segments = 8,
			radiusTaper = 0.89,
			lengthTaper = 0.95,
			lean = 0.015,
			levels = 0,
			branchStart = 1,
			childMin = 0,
			childMax = 0,
			spread = { min = 0, max = 0 },
			childRadiusScale = 0.5,
			childLengthScale = 0.6,
			upBias = 0,
		},
		foliage = {
			kind = "tier" :: Art.FoliageKind,
			countMin = 5,
			countMax = 8,
			size = { x = 6.5, y = 1.4, z = 6.5 },
			sizeJitter = 0.2,
			spread = 6.2,
			rise = 0.5,
			tilt = 0.5,
			material = M.Grass,
			colors = P.alaska.needle,
		},
		barkMaterial = M.Wood,
		barkColors = P.alaska.bark,
		contactShade = 0.32,
		targetHeight = { min = 30, max = 50 },
	} :: TreeRecipe,
	-- Snow-laden spruce: same form, snow palette mixed into the needles. Scatter these nearer the drifts.
	snowSpruce = {
		name = "SnowSpruce",
		limb = {
			radius = 1.1,
			length = 6.2,
			segments = 7,
			radiusTaper = 0.89,
			lengthTaper = 0.95,
			lean = 0.02,
			levels = 0,
			branchStart = 1,
			childMin = 0,
			childMax = 0,
			spread = { min = 0, max = 0 },
			childRadiusScale = 0.5,
			childLengthScale = 0.6,
			upBias = 0,
		},
		foliage = {
			kind = "tier" :: Art.FoliageKind,
			countMin = 5,
			countMax = 8,
			size = { x = 6.2, y = 1.5, z = 6.2 },
			sizeJitter = 0.2,
			spread = 6,
			rise = 0.5,
			tilt = 0.5,
			material = M.Snow,
			colors = P.shared.snowLaden,
		},
		barkMaterial = M.Wood,
		barkColors = P.alaska.bark,
		contactShade = 0.3,
		targetHeight = { min = 24, max = 40 },
	} :: TreeRecipe,
}

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════
-- ROCK. `sink` buries part of the form so stone grows out of the ground instead of resting on it.
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════

ArtKit.rocks = {
	bayouStone = {
		name = "BayouStone",
		size = { x = 6, y = 3.4, z = 6 },
		sizeJitter = 0.35,
		slabMin = 4,
		slabMax = 7,
		slabScale = { min = 0.45, max = 0.8 },
		tilt = 0.3,
		sink = 0.3,
		material = M.Rock,
		colors = P.bayou.stone,
		wedgeChance = 0.25,
	} :: RockRecipe,
	boulder = {
		name = "Boulder",
		size = { x = 11, y = 7.5, z = 11 },
		sizeJitter = 0.4,
		slabMin = 6,
		slabMax = 11,
		slabScale = { min = 0.4, max = 0.78 },
		tilt = 0.34,
		sink = 0.25,
		material = M.Rock,
		colors = P.appalachia.stone,
		wedgeChance = 0.3,
	} :: RockRecipe,
	outcrop = {
		name = "Outcrop",
		size = { x = 26, y = 19, z = 20 },
		sizeJitter = 0.3,
		slabMin = 10,
		slabMax = 18,
		slabScale = { min = 0.35, max = 0.7 },
		tilt = 0.24,
		sink = 0.18,
		material = M.Slate,
		colors = P.appalachia.stone,
		wedgeChance = 0.4,
	} :: RockRecipe,
	glacialErratic = {
		name = "GlacialErratic",
		size = { x = 14, y = 9, z = 13 },
		sizeJitter = 0.35,
		slabMin = 6,
		slabMax = 12,
		slabScale = { min = 0.4, max = 0.75 },
		tilt = 0.3,
		sink = 0.22,
		material = M.Basalt,
		colors = P.alaska.stone,
		wedgeChance = 0.32,
	} :: RockRecipe,
	iceShard = {
		name = "IceShard",
		size = { x = 9, y = 15, z = 9 },
		sizeJitter = 0.4,
		slabMin = 4,
		slabMax = 8,
		slabScale = { min = 0.3, max = 0.6 },
		tilt = 0.42,
		sink = 0.16,
		material = M.Glacier,
		colors = P.alaska.ice,
		wedgeChance = 0.55,
	} :: RockRecipe,
}

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════
-- GROUND SCATTER. The layer that decides whether a world reads as "built" or as "a terrain mesh".
-- All of it is non-collidable and non-queryable so it never blocks a player or eats a hunting raycast.
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════

local FREE = { castShadow = true, canCollide = false, canQuery = false }

ArtKit.clusters = {
	cattail = {
		name = "Cattail",
		countMin = 7,
		countMax = 14,
		radius = 2.6,
		shape = S.block,
		size = { x = 0.22, y = 5.4, z = 0.22 },
		sizeJitter = 0.35,
		tilt = 0.18,
		rise = -0.4,
		material = M.Grass,
		colors = P.bayou.reed,
		castShadow = false,
		canCollide = FREE.canCollide,
		canQuery = FREE.canQuery,
	} :: ClusterRecipe,
	swampFern = {
		name = "SwampFern",
		countMin = 5,
		countMax = 9,
		radius = 1.7,
		shape = S.block,
		size = { x = 2.6, y = 0.18, z = 2.6 },
		sizeJitter = 0.3,
		tilt = 0.5,
		rise = 0.25,
		material = M.Grass,
		colors = P.bayou.fern,
		castShadow = false,
		canCollide = FREE.canCollide,
		canQuery = FREE.canQuery,
	} :: ClusterRecipe,
	duckweed = {
		name = "Duckweed",
		countMin = 8,
		countMax = 16,
		radius = 7,
		shape = S.block,
		size = { x = 7, y = 0.16, z = 5.5 },
		sizeJitter = 0.4,
		tilt = 0,
		rise = 0.05,
		material = M.Mud,
		colors = P.bayou.duckweed,
		transparency = 0.18,
		castShadow = false,
		canCollide = FREE.canCollide,
		canQuery = FREE.canQuery,
	} :: ClusterRecipe,
	lilyPad = {
		name = "LilyPad",
		countMin = 3,
		countMax = 7,
		radius = 3.2,
		shape = S.cylinder,
		size = { x = 0.14, y = 2.4, z = 2.4 },
		sizeJitter = 0.32,
		tilt = 0,
		rise = 0.06,
		material = M.Grass,
		colors = P.bayou.lilypad,
		castShadow = false,
		canCollide = FREE.canCollide,
		canQuery = FREE.canQuery,
	} :: ClusterRecipe,
	fallenLog = {
		name = "FallenLog",
		countMin = 1,
		countMax = 2,
		radius = 1.2,
		shape = S.cylinder,
		size = { x = 9.5, y = 1.5, z = 1.5 },
		sizeJitter = 0.3,
		tilt = 1.5,
		rise = 0.2,
		material = M.Wood,
		colors = P.bayou.log,
		canCollide = true,
		canQuery = true,
	} :: ClusterRecipe,
	grassTuft = {
		name = "GrassTuft",
		countMin = 6,
		countMax = 11,
		radius = 2.2,
		shape = S.block,
		size = { x = 0.3, y = 2.2, z = 0.3 },
		sizeJitter = 0.4,
		tilt = 0.35,
		rise = -0.3,
		material = M.Grass,
		colors = P.appalachia.grassTuft,
		castShadow = false,
		canCollide = FREE.canCollide,
		canQuery = FREE.canQuery,
	} :: ClusterRecipe,
	mountainFern = {
		name = "MountainFern",
		countMin = 5,
		countMax = 10,
		radius = 2,
		shape = S.block,
		size = { x = 2.4, y = 0.2, z = 2.4 },
		sizeJitter = 0.3,
		tilt = 0.55,
		rise = 0.2,
		material = M.Grass,
		colors = P.appalachia.fern,
		castShadow = false,
		canCollide = FREE.canCollide,
		canQuery = FREE.canQuery,
	} :: ClusterRecipe,
	mossyLog = {
		name = "MossyLog",
		countMin = 1,
		countMax = 2,
		radius = 1.4,
		shape = S.cylinder,
		size = { x = 11, y = 1.8, z = 1.8 },
		sizeJitter = 0.3,
		tilt = 1.5,
		rise = 0.3,
		material = M.Wood,
		colors = P.appalachia.log,
		canCollide = true,
		canQuery = true,
	} :: ClusterRecipe,
	snowDrift = {
		name = "SnowDrift",
		countMin = 3,
		countMax = 6,
		radius = 5,
		shape = S.ball,
		size = { x = 9, y = 2.6, z = 7 },
		sizeJitter = 0.4,
		tilt = 0.1,
		rise = -1.1,
		material = M.Snow,
		colors = P.alaska.snow,
		canCollide = FREE.canCollide,
		canQuery = FREE.canQuery,
	} :: ClusterRecipe,
	tundraTuft = {
		name = "TundraTuft",
		countMin = 5,
		countMax = 10,
		radius = 2.4,
		shape = S.block,
		size = { x = 0.34, y = 1.5, z = 0.34 },
		sizeJitter = 0.4,
		tilt = 0.5,
		rise = -0.25,
		material = M.Grass,
		colors = P.alaska.tundra,
		castShadow = false,
		canCollide = FREE.canCollide,
		canQuery = FREE.canQuery,
	} :: ClusterRecipe,
	driftwood = {
		name = "Driftwood",
		countMin = 2,
		countMax = 4,
		radius = 2.6,
		shape = S.cylinder,
		size = { x = 7, y = 1.1, z = 1.1 },
		sizeJitter = 0.4,
		tilt = 1.5,
		rise = 0.15,
		material = M.Wood,
		colors = P.alaska.log,
		canCollide = FREE.canCollide,
		canQuery = FREE.canQuery,
	} :: ClusterRecipe,
}

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════
-- THE LODGE. A real log building with coursed walls, perforated window openings, a gabled roof, a porch
-- and a stone chimney — replacing the six-flat-box shell that prior review flagged as the weakest surface.
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════

ArtKit.cabins = {
	lodge = {
		name = "Lodge",
		width = 76,
		depth = 60,
		wallHeight = 21,
		logCourses = 9,
		roofPitch = 0.62,
		roofOverhang = 4.5,
		doorWidth = 12,
		doorHeight = 13,
		windows = {
			{ wall = "east", offset = -16, width = 9, height = 9, sill = 7 },
			{ wall = "east", offset = 2, width = 9, height = 9, sill = 7 },
			{ wall = "east", offset = 20, width = 9, height = 9, sill = 7 },
			{ wall = "west", offset = -16, width = 9, height = 9, sill = 7 },
			{ wall = "west", offset = 2, width = 9, height = 9, sill = 7 },
			{ wall = "west", offset = 20, width = 9, height = 9, sill = 7 },
			{ wall = "south", offset = -24, width = 8, height = 8, sill = 8 },
			{ wall = "south", offset = 24, width = 8, height = 8, sill = 8 },
			{ wall = "north", offset = -26, width = 7, height = 7, sill = 9 },
			{ wall = "north", offset = 26, width = 7, height = 7, sill = 9 },
		},
		porchDepth = 12,
		chimney = { width = 11, depth = 7, height = 34, offset = 0 },
		logColors = P.lodge.log,
		trimColors = P.lodge.trim,
		roofColors = P.lodge.roof,
		floorColors = P.lodge.floor,
		stoneColors = P.lodge.stone,
		logMaterial = M.Wood,
		roofMaterial = M.Slate,
		floorMaterial = M.WoodPlanks,
		stoneMaterial = M.Slate,
		glassColor = P.lodge.glass,
	} :: CabinRecipe,
	-- The Landing outpost: a small open-sided shelter at the Bayou vendor/travel anchor.
	outpost = {
		name = "Outpost",
		width = 22,
		depth = 16,
		wallHeight = 12,
		logCourses = 5,
		roofPitch = 0.55,
		roofOverhang = 3,
		doorWidth = 9,
		doorHeight = 9,
		windows = {
			{ wall = "east", offset = 0, width = 10, height = 6, sill = 5 },
			{ wall = "west", offset = 0, width = 10, height = 6, sill = 5 },
		},
		porchDepth = 7,
		chimney = nil,
		logColors = P.lodge.log,
		trimColors = P.lodge.trim,
		roofColors = P.lodge.roof,
		floorColors = P.lodge.floor,
		stoneColors = P.lodge.stone,
		logMaterial = M.Wood,
		roofMaterial = M.Slate,
		floorMaterial = M.WoodPlanks,
		stoneMaterial = M.Slate,
		glassColor = P.lodge.glass,
	} :: CabinRecipe,
}

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════
-- LOOKS — per-biome lighting, applied CLIENT-SIDE (see the header note on shared Lighting).
-- Baselines are the measured reference values; each biome then departs from them deliberately.
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════

export type Look = {
	clockTime: number,
	geographicLatitude: number,
	brightness: number,
	exposureCompensation: number,
	shadowSoftness: number,
	ambient: RGB,
	outdoorAmbient: RGB,
	colorShiftTop: RGB,
	colorShiftBottom: RGB,
	environmentDiffuseScale: number,
	environmentSpecularScale: number,
	fogColor: RGB,
	fogStart: number,
	fogEnd: number,
	atmosphere: { density: number, offset: number, color: RGB, decay: RGB, glare: number, haze: number },
	clouds: { cover: number, density: number, color: RGB },
	bloom: { intensity: number, size: number, threshold: number },
	colorCorrection: { contrast: number, saturation: number, brightness: number, tint: RGB },
	sunRays: { intensity: number, spread: number },
	depthOfField: { focusDistance: number, inFocusRadius: number, farIntensity: number, nearIntensity: number },
	water: { color: RGB, transparency: number, reflectance: number, waveSize: number, waveSpeed: number },
	windSpeed: number,
	windDirection: { x: number, y: number, z: number },
}

ArtKit.looks = {
	-- Bayou, early morning: warm low sun, humid haze, black water. The hero look.
	bayou = {
		clockTime = 7.1,
		geographicLatitude = 29,
		brightness = 2.5,
		exposureCompensation = 0.1,
		shadowSoftness = 0.7,
		ambient = { 44, 42, 36 },
		outdoorAmbient = { 96, 92, 78 },
		colorShiftTop = { 255, 226, 176 },
		colorShiftBottom = { 40, 44, 34 },
		environmentDiffuseScale = 1,
		environmentSpecularScale = 1,
		fogColor = { 206, 192, 158 },
		fogStart = 120,
		fogEnd = 720,
		atmosphere = {
			density = 0.36,
			offset = 0.25,
			color = { 208, 196, 164 },
			decay = { 124, 110, 84 },
			glare = 0.22,
			haze = 1.5,
		},
		clouds = { cover = 0.5, density = 0.16, color = { 248, 240, 224 } },
		bloom = { intensity = 0.85, size = 24, threshold = 1.4 },
		colorCorrection = { contrast = 0.1, saturation = 0.06, brightness = 0, tint = { 255, 248, 234 } },
		sunRays = { intensity = 0.22, spread = 0.9 },
		depthOfField = { focusDistance = 40, inFocusRadius = 110, farIntensity = 0.06, nearIntensity = 0 },
		water = { color = { 46, 58, 40 }, transparency = 0.24, reflectance = 0.6, waveSize = 0.05, waveSpeed = 4 },
		windSpeed = 12,
		windDirection = { x = 0.8, y = 0, z = 0.6 },
	} :: Look,
	-- Appalachia, clear midday: the reference template's own numbers, warmed slightly for a hardwood ridge.
	appalachia = {
		clockTime = 13.6,
		geographicLatitude = 37,
		brightness = 2.45,
		exposureCompensation = 0,
		shadowSoftness = 0.85,
		ambient = { 38, 38, 38 },
		outdoorAmbient = { 72, 74, 70 },
		colorShiftTop = { 0, 0, 0 },
		colorShiftBottom = { 0, 0, 0 },
		environmentDiffuseScale = 1,
		environmentSpecularScale = 1,
		fogColor = { 168, 186, 190 },
		fogStart = 240,
		fogEnd = 1400,
		atmosphere = {
			density = 0.3,
			offset = 0.25,
			color = { 196, 200, 198 },
			decay = { 106, 116, 128 },
			glare = 0.05,
			haze = 0.7,
		},
		clouds = { cover = 0.42, density = 0.12, color = { 252, 252, 252 } },
		bloom = { intensity = 1, size = 24, threshold = 2 },
		colorCorrection = { contrast = 0.08, saturation = 0.04, brightness = 0, tint = { 255, 253, 250 } },
		sunRays = { intensity = 0.25, spread = 1 },
		depthOfField = { focusDistance = 50, inFocusRadius = 140, farIntensity = 0.035, nearIntensity = 0 },
		water = { color = { 34, 74, 78 }, transparency = 0.34, reflectance = 0.85, waveSize = 0.09, waveSpeed = 7 },
		windSpeed = 20,
		windDirection = { x = 1, y = 0, z = 0.2 },
	} :: Look,
	-- Alaska, overcast late afternoon: cold, flat, high haze. Contrast comes from value, not colour.
	alaska = {
		clockTime = 16.2,
		geographicLatitude = 61,
		brightness = 2.1,
		exposureCompensation = 0.15,
		shadowSoftness = 1,
		ambient = { 46, 50, 56 },
		outdoorAmbient = { 108, 116, 128 },
		colorShiftTop = { 196, 214, 236 },
		colorShiftBottom = { 60, 68, 80 },
		environmentDiffuseScale = 1,
		environmentSpecularScale = 1,
		fogColor = { 214, 224, 236 },
		fogStart = 160,
		fogEnd = 1100,
		atmosphere = {
			density = 0.44,
			offset = 0.3,
			color = { 216, 226, 238 },
			decay = { 152, 168, 188 },
			glare = 0.02,
			haze = 2,
		},
		clouds = { cover = 0.82, density = 0.24, color = { 226, 232, 240 } },
		bloom = { intensity = 0.7, size = 28, threshold = 1.8 },
		colorCorrection = { contrast = 0.12, saturation = -0.1, brightness = 0.01, tint = { 236, 244, 255 } },
		sunRays = { intensity = 0.08, spread = 1 },
		depthOfField = { focusDistance = 45, inFocusRadius = 120, farIntensity = 0.09, nearIntensity = 0 },
		water = { color = { 30, 62, 76 }, transparency = 0.3, reflectance = 0.75, waveSize = 0.11, waveSpeed = 8 },
		windSpeed = 34,
		windDirection = { x = -0.7, y = 0, z = 0.7 },
	} :: Look,
	-- Lodge interior: warm, low ambient so the hearth and lamps carry the room.
	lodge = {
		clockTime = 8.4,
		geographicLatitude = 29,
		brightness = 1.5,
		exposureCompensation = 0.2,
		shadowSoftness = 0.6,
		ambient = { 52, 44, 36 },
		outdoorAmbient = { 92, 84, 72 },
		colorShiftTop = { 255, 232, 196 },
		colorShiftBottom = { 48, 40, 32 },
		environmentDiffuseScale = 0.8,
		environmentSpecularScale = 0.9,
		fogColor = { 196, 178, 150 },
		fogStart = 90,
		fogEnd = 620,
		atmosphere = {
			density = 0.3,
			offset = 0.25,
			color = { 210, 196, 170 },
			decay = { 118, 104, 84 },
			glare = 0.1,
			haze = 1.1,
		},
		clouds = { cover = 0.45, density = 0.14, color = { 248, 242, 228 } },
		bloom = { intensity = 1.1, size = 20, threshold = 1.1 },
		colorCorrection = { contrast = 0.12, saturation = 0.08, brightness = 0.01, tint = { 255, 244, 224 } },
		sunRays = { intensity = 0.15, spread = 0.8 },
		depthOfField = { focusDistance = 24, inFocusRadius = 70, farIntensity = 0.12, nearIntensity = 0 },
		water = { color = { 46, 58, 40 }, transparency = 0.24, reflectance = 0.6, waveSize = 0.05, waveSpeed = 4 },
		windSpeed = 2,
		windDirection = { x = 1, y = 0, z = 0 },
	} :: Look,
}

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════
-- TERRAIN. Material colours are GLOBAL to the place, so each biome is assigned a disjoint material set —
-- that is the only way three biomes in one place can each have tuned ground colour. Reference values were
-- the starting point; each is then pushed toward the biome's palette.
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════

ArtKit.terrainColors = {
	-- Bayou
	LeafyGrass = { 76, 92, 50 },
	Mud = { 72, 58, 42 },
	Ground = { 88, 74, 54 },
	Sand = { 168, 154, 118 },
	-- Appalachia
	Grass = { 96, 114, 58 },
	Rock = { 100, 96, 88 },
	Sandstone = { 138, 116, 88 },
	Slate = { 86, 84, 80 },
	-- Alaska
	Snow = { 238, 244, 250 },
	Glacier = { 200, 222, 240 },
	Ice = { 206, 222, 236 },
	Basalt = { 74, 76, 84 },
	Limestone = { 202, 200, 186 },
	-- shared/structural
	Cobblestone = { 128, 124, 112 },
	WoodPlanks = { 146, 118, 82 },
} :: { [string]: RGB }

-- Which terrain material each biome paints with, by role. The world builder reads this so a biome's
-- sculpt never touches another biome's material (and therefore never fights its colour).
ArtKit.terrainRoles = {
	bayou = {
		ground = TM.LeafyGrass,
		bank = TM.Mud,
		high = TM.Ground,
		beach = TM.Sand,
		cliff = TM.Slate,
	},
	appalachia = {
		ground = TM.Grass,
		bank = TM.Sandstone,
		high = TM.Rock,
		beach = TM.Sandstone,
		cliff = TM.Rock,
	},
	alaska = {
		ground = TM.Snow,
		bank = TM.Basalt,
		high = TM.Glacier,
		beach = TM.Limestone,
		cliff = TM.Basalt,
	},
} :: { [string]: { ground: TerrainMaterialName, bank: TerrainMaterialName, high: TerrainMaterialName, beach: TerrainMaterialName, cliff: TerrainMaterialName } }

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════
-- BUDGET. The instance ceiling the world build must respect, and the noise shape of each biome's terrain.
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════

ArtKit.budget = {
	-- Reference point: the template ships ~15.4k parts for four islands. Wild World has three biomes plus
	-- an interior hub, and must run on mobile, so the ceiling is set at roughly 2x the reference and the
	-- world build refuses to exceed it (asserted headlessly against the planned scatter counts).
	maxPartsPerBiome = 11000,
	maxPartsTotal = 34000,
	-- Below this many studs from a scatter point to its neighbour, a candidate is rejected.
	treeSpacing = 13,
	shrubSpacing = 5,
	-- Props further than this from any playable zone centre are not built at all.
	scatterRadiusCap = 300,
}

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════
-- SCATTER PLANS — where the props actually go, per biome, in LOCAL coordinates (the world builder adds the
-- destination's X offset). This is the single source of truth shared by the world builder and by
-- tests/ArtGen.spec.luau's budget assertion, so the headless gate constrains the real build rather than a
-- hypothetical one. Patch centres track the §2.3 zone anchors in src/config/Shells.luau (asserted in tests).
--
-- `kind` selects the recipe table; `recipes` are keys into it. The Studio side raycasts every candidate and
-- applies the ground filters below, so counts are CEILINGS — a patch over water places fewer.
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════

export type ScatterKind = "tree" | "rock" | "cluster"

export type ScatterPatch = {
	kind: ScatterKind,
	recipes: { string },
	center: { x: number, z: number },
	radius: number,
	count: number,
	spacing: number,
	scale: { min: number, max: number },
	seed: number,
	minGroundY: number?, -- reject candidates whose ground is below this (keeps trees out of open water)
	maxGroundY: number?, -- reject above this (keeps forest off the peaks and the glacier)
	maxSlope: number?, -- reject where the ground normal's Y is below this (nothing on a cliff face)
	waterOnly: boolean?, -- invert the ground test: place only ON water (lily pads, duckweed)
}

ArtKit.scatterPlans = {
	-- Bayou: a cypress basin. Density is highest around the channel and the slough, sparse on the levee so
	-- the arrival clearing keeps its sightline to the Landing (§2.6.2).
	bayou = {
		-- cypress grove, ringing the fishing water (channel_banks / catfish_hole)
		{ kind = "tree", recipes = { "baldCypress", "baldCypress", "snag" }, center = { x = 24, z = 12 }, radius = 70, count = 22, spacing = 13, scale = { min = 0.85, max = 1.2 }, seed = 1101, minGroundY = -1.5, maxSlope = 0.55 },
		{ kind = "tree", recipes = { "baldCypress", "baldCypress", "snag" }, center = { x = 120, z = 70 }, radius = 78, count = 24, spacing = 13, scale = { min = 0.85, max = 1.25 }, seed = 1102, minGroundY = -1.5, maxSlope = 0.55 },
		{ kind = "tree", recipes = { "baldCypress", "snag" }, center = { x = -110, z = 80 }, radius = 74, count = 22, spacing = 13, scale = { min = 0.9, max = 1.3 }, seed = 1103, minGroundY = -1.5, maxSlope = 0.55 },
		{ kind = "tree", recipes = { "baldCypress" }, center = { x = 55, z = 110 }, radius = 60, count = 14, spacing = 15, scale = { min = 0.9, max = 1.15 }, seed = 1104, minGroundY = -1.5, maxSlope = 0.55 },
		{ kind = "tree", recipes = { "baldCypress", "snag" }, center = { x = 0, z = 200 }, radius = 86, count = 20, spacing = 14, scale = { min = 0.85, max = 1.2 }, seed = 1105, minGroundY = -1.5, maxSlope = 0.55 },
		-- reed beds at the hunting zones (sunny_levee / reed_edges)
		{ kind = "cluster", recipes = { "cattail", "cattail", "swampFern" }, center = { x = 0, z = -50 }, radius = 44, count = 34, spacing = 5, scale = { min = 0.85, max = 1.2 }, seed = 1201, minGroundY = -1, maxSlope = 0.6 },
		{ kind = "cluster", recipes = { "cattail", "swampFern", "grassTuft" }, center = { x = -45, z = -45 }, radius = 40, count = 32, spacing = 5, scale = { min = 0.85, max = 1.2 }, seed = 1202, minGroundY = -1, maxSlope = 0.6 },
		{ kind = "cluster", recipes = { "cattail", "swampFern" }, center = { x = 24, z = 12 }, radius = 46, count = 30, spacing = 5, scale = { min = 0.85, max = 1.2 }, seed = 1203, minGroundY = -1, maxSlope = 0.6 },
		{ kind = "cluster", recipes = { "cattail", "swampFern" }, center = { x = 0, z = 0 }, radius = 34, count = 16, spacing = 6, scale = { min = 0.8, max = 1.1 }, seed = 1204, minGroundY = -1, maxSlope = 0.6 },
		{ kind = "cluster", recipes = { "swampFern", "cattail" }, center = { x = 0, z = 250 }, radius = 50, count = 26, spacing = 5, scale = { min = 0.85, max = 1.2 }, seed = 1205, minGroundY = -1, maxSlope = 0.6 },
		-- floating cover, placed only on water
		{ kind = "cluster", recipes = { "lilyPad", "duckweed" }, center = { x = 60, z = 60 }, radius = 110, count = 34, spacing = 12, scale = { min = 0.9, max = 1.3 }, seed = 1301, waterOnly = true },
		{ kind = "cluster", recipes = { "duckweed", "lilyPad" }, center = { x = -90, z = 110 }, radius = 92, count = 26, spacing = 12, scale = { min = 0.9, max = 1.3 }, seed = 1302, waterOnly = true },
		{ kind = "cluster", recipes = { "lilyPad" }, center = { x = 20, z = 170 }, radius = 90, count = 20, spacing = 12, scale = { min = 0.9, max = 1.2 }, seed = 1303, waterOnly = true },
		-- deadfall + stone, the mid-ground detail that stops the banks reading as bare terrain
		{ kind = "cluster", recipes = { "fallenLog" }, center = { x = 10, z = 20 }, radius = 150, count = 22, spacing = 22, scale = { min = 0.85, max = 1.3 }, seed = 1401, minGroundY = -0.8, maxSlope = 0.6 },
		{ kind = "rock", recipes = { "bayouStone" }, center = { x = 0, z = 40 }, radius = 160, count = 20, spacing = 20, scale = { min = 0.8, max = 1.4 }, seed = 1501, minGroundY = -0.8, maxSlope = 0.5 },
	} :: { ScatterPatch },

	-- Appalachia: a hardwood ridge. Conifers hold the high ground, hardwoods the hollows, autumn maples
	-- salted through so the season reads. Nothing above the lookout ridge's treeline.
	appalachia = {
		{ kind = "tree", recipes = { "oak", "oak", "maple" }, center = { x = 0, z = 80 }, radius = 80, count = 20, spacing = 14, scale = { min = 0.85, max = 1.2 }, seed = 2101, minGroundY = 0.5, maxGroundY = 60, maxSlope = 0.5 },
		{ kind = "tree", recipes = { "oak", "maple", "birch" }, center = { x = -120, z = 60 }, radius = 82, count = 24, spacing = 14, scale = { min = 0.85, max = 1.25 }, seed = 2102, minGroundY = 0.5, maxGroundY = 70, maxSlope = 0.5 },
		{ kind = "tree", recipes = { "oak", "birch", "maple" }, center = { x = 110, z = 50 }, radius = 78, count = 22, spacing = 14, scale = { min = 0.85, max = 1.2 }, seed = 2103, minGroundY = 0.5, maxGroundY = 70, maxSlope = 0.5 },
		{ kind = "tree", recipes = { "pine", "pine", "oak" }, center = { x = 0, z = -130 }, radius = 96, count = 26, spacing = 15, scale = { min = 0.85, max = 1.25 }, seed = 2104, minGroundY = 8, maxGroundY = 120, maxSlope = 0.45 },
		{ kind = "tree", recipes = { "pine", "birch" }, center = { x = -60, z = -40 }, radius = 90, count = 22, spacing = 15, scale = { min = 0.85, max = 1.2 }, seed = 2105, minGroundY = 2, maxGroundY = 90, maxSlope = 0.45 },
		{ kind = "tree", recipes = { "oak", "maple" }, center = { x = 100, z = -60 }, radius = 66, count = 14, spacing = 15, scale = { min = 0.85, max = 1.15 }, seed = 2106, minGroundY = 0.5, maxGroundY = 60, maxSlope = 0.5 },
		{ kind = "tree", recipes = { "pine", "oak" }, center = { x = -90, z = -80 }, radius = 66, count = 14, spacing = 15, scale = { min = 0.85, max = 1.15 }, seed = 2107, minGroundY = 0.5, maxGroundY = 70, maxSlope = 0.5 },
		{ kind = "cluster", recipes = { "grassTuft", "grassTuft", "mountainFern" }, center = { x = 0, z = 80 }, radius = 70, count = 44, spacing = 5, scale = { min = 0.85, max = 1.2 }, seed = 2201, minGroundY = 0.3, maxSlope = 0.55 },
		{ kind = "cluster", recipes = { "mountainFern", "grassTuft" }, center = { x = -120, z = 60 }, radius = 68, count = 38, spacing = 5, scale = { min = 0.85, max = 1.2 }, seed = 2202, minGroundY = 0.3, maxSlope = 0.55 },
		{ kind = "cluster", recipes = { "mountainFern", "grassTuft" }, center = { x = 110, z = 50 }, radius = 66, count = 36, spacing = 5, scale = { min = 0.85, max = 1.2 }, seed = 2203, minGroundY = 0.3, maxSlope = 0.55 },
		{ kind = "cluster", recipes = { "grassTuft" }, center = { x = 0, z = -110 }, radius = 90, count = 34, spacing = 6, scale = { min = 0.8, max = 1.1 }, seed = 2204, minGroundY = 4, maxSlope = 0.5 },
		{ kind = "cluster", recipes = { "mossyLog" }, center = { x = -20, z = 20 }, radius = 170, count = 20, spacing = 24, scale = { min = 0.85, max = 1.3 }, seed = 2301, minGroundY = 0.5, maxSlope = 0.55 },
		{ kind = "rock", recipes = { "boulder", "boulder", "outcrop" }, center = { x = 0, z = -100 }, radius = 130, count = 22, spacing = 26, scale = { min = 0.8, max = 1.35 }, seed = 2401, minGroundY = 1, maxSlope = 0.35 },
		{ kind = "rock", recipes = { "boulder" }, center = { x = 60, z = 40 }, radius = 150, count = 16, spacing = 26, scale = { min = 0.8, max = 1.3 }, seed = 2402, minGroundY = 0.5, maxSlope = 0.4 },
	} :: { ScatterPatch },

	-- Alaska: boreal coast. Spruce in the river bottoms, snow-laden spruce near the drifts, ice and erratics
	-- on the crags. Deliberately sparser than the other two — emptiness is the biome's character.
	alaska = {
		{ kind = "tree", recipes = { "spruce", "spruce", "snag" }, center = { x = -110, z = 30 }, radius = 84, count = 24, spacing = 14, scale = { min = 0.85, max = 1.25 }, seed = 3101, minGroundY = 0.5, maxGroundY = 70, maxSlope = 0.5 },
		{ kind = "tree", recipes = { "snowSpruce", "spruce" }, center = { x = 0, z = 50 }, radius = 88, count = 22, spacing = 15, scale = { min = 0.85, max = 1.2 }, seed = 3102, minGroundY = 0.5, maxGroundY = 70, maxSlope = 0.5 },
		{ kind = "tree", recipes = { "snowSpruce", "snowSpruce", "snag" }, center = { x = -60, z = -90 }, radius = 72, count = 18, spacing = 15, scale = { min = 0.85, max = 1.2 }, seed = 3103, minGroundY = 0.5, maxGroundY = 80, maxSlope = 0.45 },
		{ kind = "tree", recipes = { "spruce", "snowSpruce" }, center = { x = 60, z = -20 }, radius = 76, count = 18, spacing = 15, scale = { min = 0.85, max = 1.2 }, seed = 3104, minGroundY = 0.5, maxGroundY = 70, maxSlope = 0.5 },
		{ kind = "cluster", recipes = { "tundraTuft", "tundraTuft", "snowDrift" }, center = { x = 0, z = 50 }, radius = 92, count = 46, spacing = 6, scale = { min = 0.85, max = 1.25 }, seed = 3201, minGroundY = 0.3, maxSlope = 0.55 },
		{ kind = "cluster", recipes = { "tundraTuft", "snowDrift" }, center = { x = -110, z = 30 }, radius = 78, count = 34, spacing = 6, scale = { min = 0.85, max = 1.2 }, seed = 3202, minGroundY = 0.3, maxSlope = 0.55 },
		{ kind = "cluster", recipes = { "snowDrift", "tundraTuft" }, center = { x = 90, z = -70 }, radius = 82, count = 30, spacing = 7, scale = { min = 0.9, max = 1.35 }, seed = 3203, minGroundY = 0.3, maxSlope = 0.5 },
		{ kind = "cluster", recipes = { "driftwood" }, center = { x = 150, z = -110 }, radius = 120, count = 22, spacing = 18, scale = { min = 0.85, max = 1.3 }, seed = 3301, minGroundY = -0.5, maxGroundY = 8, maxSlope = 0.6 },
		{ kind = "rock", recipes = { "glacialErratic", "glacialErratic", "iceShard" }, center = { x = 90, z = -70 }, radius = 110, count = 22, spacing = 24, scale = { min = 0.8, max = 1.35 }, seed = 3401, minGroundY = 0.5, maxSlope = 0.35 },
		{ kind = "rock", recipes = { "iceShard", "glacialErratic" }, center = { x = 0, z = -230 }, radius = 96, count = 18, spacing = 24, scale = { min = 0.85, max = 1.4 }, seed = 3402, minGroundY = 1, maxSlope = 0.4 },
		{ kind = "rock", recipes = { "glacialErratic" }, center = { x = -140, z = -150 }, radius = 90, count = 12, spacing = 26, scale = { min = 0.8, max = 1.2 }, seed = 3403, minGroundY = 0.5, maxSlope = 0.4 },
	} :: { ScatterPatch },
} :: { [string]: { ScatterPatch } }

ArtKit.noise = {
	bayou = {
		base = { frequency = 0.0075, octaves = 4, lacunarity = 2.05, gain = 0.5 },
		detail = { frequency = 0.035, octaves = 3, lacunarity = 2.1, gain = 0.45 },
	},
	appalachia = {
		base = { frequency = 0.0042, octaves = 5, lacunarity = 2.1, gain = 0.52 },
		detail = { frequency = 0.022, octaves = 3, lacunarity = 2.2, gain = 0.42 },
	},
	alaska = {
		base = { frequency = 0.0035, octaves = 5, lacunarity = 2.15, gain = 0.5 },
		detail = { frequency = 0.018, octaves = 3, lacunarity = 2.2, gain = 0.4 },
	},
}

-- ══════════════════════════════════════════════════════════════════════════════════════════════════════
-- TERRAIN SPECS — the sculpt, per biome, in LOCAL coordinates. `flats` sit on the walkable zone anchors of
-- src/config/Shells.luau and `basins` on its water zones, so the terrain is generated FROM the gameplay
-- layout rather than sculpted and hoped over. tests/TerrainGen.spec.luau probes every zone and asserts the
-- ones you must walk on are walkable and the ones you fish in hold water.
--
-- Material bands are ascending; each biome draws only from its own material set (ArtKit.terrainRoles),
-- because terrain material COLOURS are global to the place.
-- ══════════════════════════════════════════════════════════════════════════════════════════════════════

local N = ArtKit.noise
local R = ArtKit.terrainRoles

ArtKit.terrainSpecs = {
	-- Bayou: a blackwater basin at Y=0. Most of the footprint is shallow water and mud; the hunting flats,
	-- the arrival clearing and the Landing are raised hummocks; the fishing zones are carved basins.
	bayou = {
		seed = 20260801,
		center = { x = 0, z = 100 },
		extent = { x = 420, z = 420 }, -- covers z -110..310, i.e. the Landing at z=255
		baseHeight = -3.2,
		amplitude = 7,
		detailAmplitude = 1.6,
		base = N.bayou.base,
		detail = N.bayou.detail,
		ridged = false,
		waterLevel = 0,
		shoreFalloff = 60,
		-- DRY flats (walkable zones) and WET flats (height below waterLevel = a flat-bottomed pool).
		-- Both are the same mechanism; the sign of `height` is what makes a zone land or water.
		flats = {
			{ x = 0, z = 0, radius = 15, falloff = 16, height = 2.6 }, -- arrival_clearing
			{ x = 0, z = -50, radius = 30, falloff = 26, height = 3.0 }, -- sunny_levee
			{ x = -45, z = -45, radius = 28, falloff = 24, height = 2.2 }, -- reed_edges
			{ x = 0, z = 255, radius = 36, falloff = 30, height = 3.2 }, -- the_landing (vendor + travel)
			{ x = 55, z = 110, radius = 20, falloff = 18, height = 1.6 }, -- the_old_cypress island
			{ x = 0, z = 302, radius = 24, falloff = 32, height = -5 }, -- open water off the Landing dock
			{ x = 24, z = 12, radius = 11, falloff = 17, height = -4 }, -- channel_banks (shore fishing)
			{ x = 120, z = 70, radius = 30, falloff = 26, height = -9 }, -- catfish_hole
			{ x = -110, z = 80, radius = 28, falloff = 24, height = -5 }, -- cottonmouth_slough (rare site)
		},
		-- natural depressions layered onto the noise BEFORE the flats, purely for texture
		basins = {
			{ x = 60, z = 160, radius = 40, falloff = 40, depth = 3 },
			{ x = -70, z = 200, radius = 34, falloff = 36, depth = 2.5 },
		},
		bands = {
			{ upTo = -0.6, material = TM.Mud }, -- submerged bed
			{ upTo = 0.9, material = TM.Sand }, -- the waterline strip
			{ upTo = 5.5, material = TM.LeafyGrass }, -- swamp grass on the hummocks
			{ upTo = math.huge, material = TM.Ground }, -- dry levee dirt
		},
		cliffSlope = 1.1,
		cliffMaterial = R.bayou.cliff,
	},

	-- Appalachia: a ridged hardwood range. The lookout ridge is genuinely high ground; the old field and
	-- creek bottoms are flattened benches; two carved ponds hold the fishing water.
	appalachia = {
		seed = 20260802,
		center = { x = 0, z = 35 },
		extent = { x = 400, z = 430 }, -- covers z -180..250, i.e. the outpost at z=200
		baseHeight = -6,
		amplitude = 92,
		detailAmplitude = 5,
		base = N.appalachia.base,
		detail = N.appalachia.detail,
		ridged = true,
		waterLevel = 0,
		shoreFalloff = 70,
		flats = {
			{ x = 0, z = 80, radius = 38, falloff = 34, height = 14 }, -- old_field (first-hunt bench)
			{ x = -120, z = 60, radius = 34, falloff = 30, height = 26 }, -- oak_ridges
			{ x = 110, z = 50, radius = 32, falloff = 30, height = 20 }, -- creek_bottoms
			{ x = 0, z = -130, radius = 30, falloff = 44, height = 74 }, -- lookout_ridge (the high beacon)
			{ x = 0, z = 200, radius = 34, falloff = 30, height = 12 }, -- outpost_cabin (ARRIVAL + vendor, Shells apOutpostAnchor)
			{ x = 100, z = -60, radius = 24, falloff = 30, height = -5 }, -- hollow_creek (wet)
			{ x = -90, z = -80, radius = 28, falloff = 32, height = -7 }, -- mill_pond (wet)
		},
		basins = {
			{ x = 50, z = 10, radius = 46, falloff = 48, depth = 8 }, -- the hollow between the benches
		},
		bands = {
			{ upTo = -0.5, material = TM.Sandstone }, -- creek bed
			{ upTo = 2.5, material = TM.Sandstone }, -- gravel margin
			{ upTo = 56, material = TM.Grass }, -- meadow and hardwood floor
			{ upTo = math.huge, material = TM.Rock }, -- above the treeline
		},
		cliffSlope = 0.85,
		cliffMaterial = R.appalachia.cliff,
	},

	-- Alaska: boreal coast. Land falls to a real coastline in the south-east (open_gulf / coastal_inlet),
	-- the glacier is the high beacon, and the frozen lake is a shallow carved pan.
	alaska = {
		seed = 20260803,
		center = { x = 20, z = -35 },
		extent = { x = 440, z = 520 }, -- covers z -295..225, i.e. the glacier at -250 AND the harbor at +180
		baseHeight = -10,
		amplitude = 70,
		detailAmplitude = 4,
		base = N.alaska.base,
		detail = N.alaska.detail,
		ridged = true,
		waterLevel = 0,
		shoreFalloff = 80,
		flats = {
			{ x = 0, z = 50, radius = 42, falloff = 36, height = 9 }, -- tundra_flats
			{ x = -110, z = 30, radius = 34, falloff = 30, height = 13 }, -- spruce_riverbottom
			{ x = 90, z = -70, radius = 26, falloff = 10, height = 26 }, -- the_crags (tight falloff: keeps its reach clear of interior_river 36 studs away)
			{ x = 0, z = -250, radius = 46, falloff = 46, height = 62 }, -- the_glacier (the high beacon)
			{ x = -60, z = -90, radius = 22, falloff = 24, height = 14 }, -- salmon_falls (rare site)
			{ x = 0, z = 180, radius = 34, falloff = 30, height = 7 }, -- harbor_camp (ARRIVAL + vendor, Shells akOutpostAnchor)
			{ x = 0, z = 232, radius = 28, falloff = 34, height = -8 }, -- the harbour itself: open water off the dock
			{ x = 60, z = -50, radius = 21, falloff = 14, height = -5 }, -- interior_river (wet; reach 35 < the 36 studs to the_crags)
			{ x = 140, z = -120, radius = 34, falloff = 38, height = -13 }, -- coastal_inlet (wet)
			{ x = 200, z = -200, radius = 54, falloff = 56, height = -24 }, -- open_gulf (wet, deep)
			{ x = -150, z = -160, radius = 36, falloff = 30, height = -3 }, -- frozen_lake (wet, shallow)
		},
		basins = {
			{ x = -40, z = -20, radius = 50, falloff = 50, depth = 6 }, -- interior swale
		},
		bands = {
			{ upTo = -1, material = TM.Basalt }, -- sea bed
			{ upTo = 2, material = TM.Limestone }, -- pale shingle beach
			{ upTo = 44, material = TM.Snow }, -- snowfield
			{ upTo = math.huge, material = TM.Glacier }, -- glacial ice above the snow line
		},
		cliffSlope = 0.8,
		cliffMaterial = R.alaska.cliff,
	},
} :: { [string]: TerrainGenTypes.BiomeTerrainSpec }

return table.freeze(ArtKit)
