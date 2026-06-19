--!nonstrict
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- STUDIO-ONLY (NOT headless-analyzed — *.server.luau is excluded by run-tests.sh). THE DECOUPLED ART LAYER.
-- Builds the grounded-naturalistic look for the Bayou + Lodge as an ADDITIVE pass that touches NO gameplay
-- file: it runs alongside WorldServer, sets the global look (Lighting/Atmosphere/Clouds/post-FX), builds
-- terrain + water + props, suppresses WorldServer's placeholder boxes, and UPGRADES spawned creature/fish
-- models IN PLACE (preserving PrimaryPart + the maxHealth/currentHealth/targetId/creatureId attrs + the
-- hitZone-tagged queryable parts) so the fire-raycast / health bars / death anim keep working untouched.
-- It does NOT build creature locomotion (that is the gameplay terminal's s2-creature-movement lane); its
-- one Heartbeat loop drives COSMETIC secondary motion only (breathing/head-track/flutter), reading
-- PrimaryPart and never setting world position.
-- Spec: docs/superpowers/specs/2026-06-18-bayou-visual-overhaul-design.md
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- relative require-by-string (matches WorldServer's `require("../../config/Catalog")` convention; @-aliases
-- do NOT resolve in Roblox — only relative paths do, per the S2 boot fix).
local ArtAssets = require("../../config/ArtAssets")

-- {r,g,b} 0-255 → Color3
local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- find-or-create a singleton child (so re-runs update rather than duplicate)
local function findOrNew(parent, className, name)
	local inst = parent:FindFirstChild(name)
	if inst == nil or not inst:IsA(className) then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
	end
	return inst
end

-- module-level state populated by the build functions (added per task)
local M = { animated = {} } -- M.animated[model] = { creatureId = .., joints = {..}, phase = .. }

-- ── A2: the global look (reproducible source; the same values are also baked into the place via the MCP).
-- Sets only the SCRIPTABLE props; the non-scriptable LightingStyle=Realistic/PrioritizeLightingQuality are a
-- place setting, and the dawn Sky (ArtAssets.sky.modelAssetId) is inserted/baked under Lighting separately.
function M.applyGlobalLook()
	local A = ArtAssets
	local L = A.lighting.bayouDawn
	Lighting.ClockTime = L.clockTime
	Lighting.GeographicLatitude = L.geographicLatitude
	Lighting.Brightness = L.brightness
	Lighting.ExposureCompensation = L.exposureCompensation
	Lighting.Ambient = c3(L.ambient)
	Lighting.OutdoorAmbient = c3(L.outdoorAmbient)
	Lighting.ColorShift_Top = c3(L.colorShiftTop)

	local at = A.atmosphere
	local atm = findOrNew(Lighting, "Atmosphere", "Atmosphere")
	atm.Density, atm.Offset, atm.Color, atm.Decay, atm.Glare, atm.Haze =
		at.density, at.offset, c3(at.color), c3(at.decay), at.glare, at.haze

	local cl = A.clouds
	local clouds = findOrNew(workspace.Terrain, "Clouds", "Clouds") -- Clouds MUST live under Terrain to render
	clouds.Cover, clouds.Density, clouds.Color, clouds.Enabled = cl.cover, cl.density, c3(cl.color), true

	local b = A.post.bloom
	local bloom = findOrNew(Lighting, "BloomEffect", "Bloom")
	bloom.Intensity, bloom.Size, bloom.Threshold = b.intensity, b.size, b.threshold

	local cc = A.post.colorCorrection
	local cce = findOrNew(Lighting, "ColorCorrectionEffect", "ColorCorrection")
	cce.Contrast, cce.Saturation, cce.Brightness, cce.TintColor =
		cc.contrast, cc.saturation, cc.brightness, c3(cc.tint)

	local sr = A.post.sunRays
	local sun = findOrNew(Lighting, "SunRaysEffect", "SunRays")
	sun.Intensity, sun.Spread = sr.intensity, sr.spread

	local df = A.post.depthOfField
	local dof = findOrNew(Lighting, "DepthOfFieldEffect", "DepthOfField")
	dof.FocusDistance, dof.InFocusRadius, dof.FarIntensity, dof.NearIntensity, dof.Enabled =
		df.focusDistance, df.inFocusRadius, df.farIntensity, df.nearIntensity, false
end

-- (buildTerrain / scatterProps / buildLodge / upgradeCreature / the Heartbeat loop land as tasks B1+ settle)

-- ── DORMANT BY DEFAULT. The art build runs ONLY when explicitly opted in (workspace attribute
-- "WildWorldArt" == true), so this script never alters a session uninvited — critically, the gameplay
-- terminal's creature-movement playtests. The static look/terrain/sky are also baked into the place, so the
-- visual layer is present even with this dormant; this gated path is the reproducible rebuild.
if workspace:GetAttribute("WildWorldArt") == true then
	M.applyGlobalLook()
	print("[WildWorldArt] global look applied (opted in)")
else
	print(("[WildWorldArt] online — manifest v%d (dormant; set workspace attr 'WildWorldArt'=true to build)"):format(ArtAssets.version))
end
