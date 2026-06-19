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
	props = {}, -- [propId] = { meshId = "rbxassetid://N", scale = n, color = {r,g,b}, count = n, zones = {..} }
	creatures = {}, -- [creatureId] = { scale = n, parts = { { name=, meshId=, size={x,y,z}, hitZone=, offset={x,y,z} } } }
	fish = {}, -- [fishId] = { meshId = "rbxassetid://N", scale = n, color = {r,g,b} }
	lodge = {}, -- { materials = {..}, lights = {..}, fixtures = {..} } — Phase D
}

return ArtAssets
