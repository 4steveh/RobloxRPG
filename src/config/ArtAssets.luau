--!strict
-- ART ASSET MANIFEST (visual overhaul) — the single durable record of every AI-generated asset ID plus
-- per-asset visual tuning. PURE DATA: references NO Roblox globals, so it passes the headless --!strict gate
-- and lives under src/config alongside the other catalogs. The Studio-only scripts (WorldArt.server.luau,
-- WorldArtClient.client.luau) read this; nothing in src/logic or the server substrate depends on it.
--
-- Colors are {r, g, b} integers 0-255 (the Studio scripts wrap them via Color3.fromRGB). Asset IDs are
-- "rbxassetid://N" strings, filled in as meshes/skybox faces are generated. Values are STARTING POINTS:
-- the TUNE-marked numbers (lighting/atmosphere/post/water) are eyeballed at ClockTime 6.7 in Studio and
-- adjusted; see docs/superpowers/specs/2026-06-18-bayou-visual-overhaul-design.md for ENGINE-vs-TUNE.

local ArtAssets = {
	version = 1,

	-- ── GLOBAL LOOK (Bayou dawn hero; §2 of the spec) ──────────────────────────────────────────────
	lighting = {
		bayouDawn = {
			clockTime = 6.7,
			geographicLatitude = 29,
			brightness = 2,
			exposureCompensation = 0.15,
			ambient = { 54, 60, 48 },
			outdoorAmbient = { 96, 104, 86 },
			colorShiftTop = { 255, 214, 150 },
			-- image-based lighting (review §1.7): both were 0 on the saved place → flat PBR. On = sky-bounce.
			environmentDiffuseScale = 1,
			environmentSpecularScale = 1,
			fogStart = 90,
			fogEnd = 520, -- warm-haze depth cull/backstop (FogColor inherits atmosphere.color)
		},
		bayouDusk = { clockTime = 17.8 }, -- overrides only; inherits bayouDawn otherwise
	},
	atmosphere = {
		density = 0.42,
		offset = 0.25,
		color = { 208, 196, 158 },
		decay = { 140, 120, 90 },
		glare = 0.35,
		haze = 2.2,
	},
	clouds = { cover = 0.55, density = 0.18, color = { 245, 240, 228 } },
	post = {
		bloom = { intensity = 0.5, size = 24, threshold = 0.9 },
		colorCorrection = { contrast = 0.1, saturation = 0.08, brightness = 0, tint = { 255, 246, 230 } },
		sunRays = { intensity = 0.18, spread = 0.9 },
		depthOfField = { focusDistance = 50, inFocusRadius = 50, farIntensity = 0.2, nearIntensity = 0 },
	},
	-- Dawn skybox: Creator Store "Sunset Dawn Skybox" by dearjournal (warm orange/blue dawn) — inserted as a
	-- Sky under Lighting. A bespoke custom 1024² skybox (faceAssetIds) is a later polish option.
	sky = { modelAssetId = "325545295", faceAssetIds = {} :: { [string]: string } },

	-- ── BAYOU ENVIRONMENT (§3) ─────────────────────────────────────────────────────────────────────
	terrain = {
		water = { color = { 44, 56, 36 }, transparency = 0.22, reflectance = 0.55, waveSize = 0.04, waveSpeed = 4 },
		grassLength = 0.4,
		materialColors = {
			LeafyGrass = { 78, 92, 52 },
			Grass = { 88, 100, 58 },
			Mud = { 74, 59, 40 },
			Ground = { 86, 72, 52 },
		},
	},
	palette = {
		waterOpen = { 38, 48, 30 },
		waterMid = { 44, 56, 36 },
		duckweed = { 111, 138, 60 },
		foliageShadow = { 27, 51, 17 },
		foliageMid = { 45, 91, 16 },
		foliageHi = { 166, 185, 111 },
		barkMid = { 90, 77, 59 },
		barkShadow = { 58, 50, 37 },
		moss = { 154, 162, 136 },
		mud = { 74, 59, 40 },
		wetLog = { 107, 90, 69 },
	},

	-- ── ASSET TABLES (filled by the generation tasks; the manifest IS the deliverable being populated) ──
	props = {
		-- Creator Store "Realistic Swamp Bald Cypress Trees Pack Scenic" — multi-part Model (~31 parts), parked as
		-- a clone template at ReplicatedStorage.WildWorldArt.Props.Cypress (upright pivot at base center).
		cypress = { modelAssetId = "136271797295845", source = "Creator Store cypress pack", scaleRange = { 0.8, 1.4 } },
		-- Appalachia/Alaska conifer pool: 1 wrapper Model w/ 34 "Tree" variants, parked at RS.WildWorldArt.Props.Forest.
		forest = { modelAssetId = "104935044529680", source = "Creator Store conifer pack (34 variants); Alaska clones frosted" },
	},
	-- [creatureId] = visual mesh + hitZone proxy layout. Single-mesh creatures carry invisible hitZone proxy
	-- parts (vital=head, body=torso, limb=legs) so the headshot raycast keeps working after the in-place upgrade.
	creatures = {
		bayou_american_alligator = {
			meshId = "rbxassetid://75097229317873", textureId = "rbxassetid://81799021849112",
			scale = 1.0, source = "generate_mesh (validated exemplar)",
		},
		bayou_swamp_rabbit = { modelAssetId = "9564989831", scale = 1.0, source = "Creator Store rabbit" },
		bayou_wood_duck = { modelAssetId = "130991578358791", scale = 0.045, source = "Creator Store mallard (recolor for wood duck)" },
		bayou_great_egret = { modelAssetId = "13929862465", scale = 0.7, source = "Creator Store crane (heron/egret stand-in)" },
		bayou_painted_turtle = { modelAssetId = "165224066", scale = 1.0, source = "Creator Store turtle" },
		-- bayou_nutria / songbird + the rare reskins (Leucistic Duck, Ghost Gator) — pending (recolor clones / AI-gen gaps)
		-- ── Appalachia + Alaska (Creator Store; stashed in RS.WildWorldArt.Creatures as Deer/Bear/Moose/Grizzly) ──
		appalachia_whitetail_deer = { modelAssetId = "5114925772", source = "Creator Store whitetail buck (GREAT)" },
		alaska_caribou = { modelAssetId = "5114925772", source = "deer reskin (grey-brown recolor)" },
		alaska_bull_moose = { modelAssetId = "238635661", scale = "height-normalized ~7", source = "Creator Store moose" },
		alaska_grizzly_bear = { modelAssetId = "17533317792", source = "Creator Store bear, recolored brown + texture stripped → Grizzly" },
		-- appalachia_wild_boar / mountain_lion, alaska_sitka_deer / glacier_grizzly — reskins/searches pending
	},
	fish = {
		-- the Mythic Bayou Leviathan = a Creator-Store arapaima (large PBR fish w/ animations); recolor/scale per use.
		bayou_leviathan = { modelAssetId = "6889945071", scale = 1.0, source = "Creator Store arapaima" },
		-- bayou_bluegill / bullhead_catfish / channel_catfish / blue_catfish / albino — catfish AI-gen in progress
	},
	lodge = {}, -- { materials = {..}, lights = {..}, fixtures = {..} } — Phase D
	-- VEHICLES/MOUNTS/DOGS (Creator Store; stashed in RS.WildWorldArt.Vehicles; set-dressing at thematic spots)
	vehicles = {
		pirogue = { modelAssetId = "3372133622", source = "Creator Store log boat → Bayou pirogue (the_landing/channel)" },
		motorboat = { modelAssetId = "4521678016", source = "Creator Store motorboat → Alaska coastal skiff" },
		dog_coonhound = { modelAssetId = "130861786583714", source = "Creator Store labrador → hunting dog (Lodge Kennel)" },
		mount_horse = { modelAssetId = "8544555368", source = "Creator Store horse → mount (Lodge Stable)" },
	},
	-- AMBIENT SOUNDSCAPE — free Pro Sound Effects loops; positional Sounds per world (rolloff keeps each local).
	sound = {
		bayouFrogs = "9112810059",      -- Jungle Frogs (night chorus, 57s)
		appalachiaWoods = "9112806424", -- Jungle Dawn (woods birds/insects, 36s)
		alaskaWind = "9114057128",      -- Desert Wind whistley gusts (92s)
		lodgeFire = "9112780193",       -- Fireplace crackle (36s)
	},
}

return ArtAssets
