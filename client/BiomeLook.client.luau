-- STUDIO-ONLY LocalScript (excluded from run-tests.sh). PER-BIOME LIGHTING.
--
-- WHY THIS IS CLIENT-SIDE. Wild World's three destinations sit 2000 studs apart in ONE place, and Lighting
-- is a single shared object. A server-side write would give every player the same biome's sky — so a player
-- fishing the Alaskan coast would be lit by a Louisiana dawn. Applying the look locally, per player, is the
-- only way each biome can have its own time of day, haze, exposure and water.
--
-- The look VALUES are never hard-coded here. WorldArt.server.luau publishes src/config/ArtKit.luau's
-- `looks` table as JSON on ReplicatedStorage.WildWorldLooks (a LocalScript cannot require anything under
-- ServerScriptService), and this script interpolates between them. ArtKit stays the single source of truth.
--
-- Transitions are lerped over ~2.5 s rather than snapped: an instant exposure/atmosphere change on
-- fast-travel reads as a rendering glitch, and the interpolation costs one cheap RenderStepped pass.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local TRANSITION_SECONDS = 2.5
-- Half-width of a biome's X band. The destinations are 2000 studs apart, so 1000 splits them exactly.
local BIOME_HALF_WIDTH = 1000

local payloadValue = ReplicatedStorage:WaitForChild("WildWorldLooks", 30)
if payloadValue == nil then
	warn("[BiomeLook] ReplicatedStorage.WildWorldLooks never appeared — per-biome lighting is off")
	return
end

local ok, payload = pcall(function()
	return HttpService:JSONDecode(payloadValue.Value)
end)
if not ok or type(payload) ~= "table" or type(payload.looks) ~= "table" then
	warn("[BiomeLook] could not decode the published looks — per-biome lighting is off")
	return
end

local LOOKS = payload.looks
local OFFSETS = payload.offsets or { bayou = 0, appalachia = 2000, alaska = 4000 }
local LODGE = payload.lodge or { x = 0, z = 600, radius = 90 }

-- ── the interpolated state ────────────────────────────────────────────────────────────────────────────
-- A look is flattened to a flat map of numeric channels so one generic lerp covers everything. Colours are
-- carried as three channels each; nothing here needs to know which property is a Color3.

local NUMERIC = {
	"clockTime",
	"geographicLatitude",
	"brightness",
	"exposureCompensation",
	"shadowSoftness",
	"environmentDiffuseScale",
	"environmentSpecularScale",
	"fogStart",
	"fogEnd",
	"windSpeed",
}
local COLORS = { "ambient", "outdoorAmbient", "colorShiftTop", "colorShiftBottom", "fogColor" }
local NESTED_NUM = {
	{ "atmosphere", { "density", "offset", "glare", "haze" } },
	{ "clouds", { "cover", "density" } },
	{ "bloom", { "intensity", "size", "threshold" } },
	{ "colorCorrection", { "contrast", "saturation", "brightness" } },
	{ "sunRays", { "intensity", "spread" } },
	{ "depthOfField", { "focusDistance", "inFocusRadius", "farIntensity", "nearIntensity" } },
	{ "water", { "transparency", "reflectance", "waveSize", "waveSpeed" } },
}
local NESTED_COL = {
	{ "atmosphere", { "color", "decay" } },
	{ "clouds", { "color" } },
	{ "colorCorrection", { "tint" } },
	{ "water", { "color" } },
}

local function flatten(look: any): { [string]: number }
	local f: { [string]: number } = {}
	for _, key in ipairs(NUMERIC) do
		f[key] = look[key] or 0
	end
	for _, key in ipairs(COLORS) do
		local c = look[key] or { 0, 0, 0 }
		f[key .. ".r"], f[key .. ".g"], f[key .. ".b"] = c[1], c[2], c[3]
	end
	for _, group in ipairs(NESTED_NUM) do
		local tbl = look[group[1]] or {}
		for _, key in ipairs(group[2]) do
			f[group[1] .. "." .. key] = tbl[key] or 0
		end
	end
	for _, group in ipairs(NESTED_COL) do
		local tbl = look[group[1]] or {}
		for _, key in ipairs(group[2]) do
			local c = tbl[key] or { 0, 0, 0 }
			local base = group[1] .. "." .. key
			f[base .. ".r"], f[base .. ".g"], f[base .. ".b"] = c[1], c[2], c[3]
		end
	end
	-- wind direction is a unit vector, lerped componentwise then re-normalised on apply
	local wd = look.windDirection or { x = 1, y = 0, z = 0 }
	f["wind.x"], f["wind.y"], f["wind.z"] = wd.x, wd.y, wd.z
	return f
end

local FLAT: { [string]: { [string]: number } } = {}
for name, look in pairs(LOOKS) do
	FLAT[name] = flatten(look)
end

local function col3(f: { [string]: number }, base: string): Color3
	return Color3.fromRGB(f[base .. ".r"], f[base .. ".g"], f[base .. ".b"])
end

-- ── applying ──────────────────────────────────────────────────────────────────────────────────────────

local function ensure(className: string, name: string): Instance
	local inst = Lighting:FindFirstChild(name)
	if inst == nil or not inst:IsA(className) then
		if inst then
			inst:Destroy()
		end
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
	end
	return inst
end

local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
local correction = ensure("ColorCorrectionEffect", "ColorCorrection") :: ColorCorrectionEffect
local sunRays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
local dof = ensure("DepthOfFieldEffect", "DepthOfField") :: DepthOfFieldEffect
local terrain = workspace.Terrain
local clouds = terrain:FindFirstChildOfClass("Clouds")
if clouds == nil then
	clouds = Instance.new("Clouds")
	clouds.Parent = terrain
end

local function apply(f: { [string]: number })
	Lighting.ClockTime = f.clockTime
	Lighting.GeographicLatitude = f.geographicLatitude
	Lighting.Brightness = f.brightness
	Lighting.ExposureCompensation = f.exposureCompensation
	Lighting.ShadowSoftness = f.shadowSoftness
	Lighting.EnvironmentDiffuseScale = f.environmentDiffuseScale
	Lighting.EnvironmentSpecularScale = f.environmentSpecularScale
	Lighting.Ambient = col3(f, "ambient")
	Lighting.OutdoorAmbient = col3(f, "outdoorAmbient")
	Lighting.ColorShift_Top = col3(f, "colorShiftTop")
	Lighting.ColorShift_Bottom = col3(f, "colorShiftBottom")
	Lighting.FogColor = col3(f, "fogColor")
	Lighting.FogStart = f.fogStart
	Lighting.FogEnd = f.fogEnd

	atmosphere.Density = f["atmosphere.density"]
	atmosphere.Offset = f["atmosphere.offset"]
	atmosphere.Glare = f["atmosphere.glare"]
	atmosphere.Haze = f["atmosphere.haze"]
	atmosphere.Color = col3(f, "atmosphere.color")
	atmosphere.Decay = col3(f, "atmosphere.decay")

	clouds.Cover = f["clouds.cover"]
	clouds.Density = f["clouds.density"]
	clouds.Color = col3(f, "clouds.color")

	bloom.Intensity = f["bloom.intensity"]
	bloom.Size = f["bloom.size"]
	bloom.Threshold = f["bloom.threshold"]

	correction.Contrast = f["colorCorrection.contrast"]
	correction.Saturation = f["colorCorrection.saturation"]
	correction.Brightness = f["colorCorrection.brightness"]
	correction.TintColor = col3(f, "colorCorrection.tint")

	sunRays.Intensity = f["sunRays.intensity"]
	sunRays.Spread = f["sunRays.spread"]

	dof.FocusDistance = f["depthOfField.focusDistance"]
	dof.InFocusRadius = f["depthOfField.inFocusRadius"]
	dof.FarIntensity = f["depthOfField.farIntensity"]
	dof.NearIntensity = f["depthOfField.nearIntensity"]
	dof.Enabled = f["depthOfField.farIntensity"] > 0.001

	terrain.WaterColor = col3(f, "water.color")
	terrain.WaterTransparency = f["water.transparency"]
	terrain.WaterReflectance = f["water.reflectance"]
	terrain.WaterWaveSize = f["water.waveSize"]
	terrain.WaterWaveSpeed = f["water.waveSpeed"]

	local dir = Vector3.new(f["wind.x"], f["wind.y"], f["wind.z"])
	if dir.Magnitude > 1e-4 then
		workspace.GlobalWind = dir.Unit * f.windSpeed
	end
end

-- ── which biome am I in ───────────────────────────────────────────────────────────────────────────────

local function lookNameFor(pos: Vector3): string
	-- the Lodge is an interior sitting inside the Bayou's X band, so it is tested first, by proximity
	if LOOKS.lodge ~= nil then
		local dx, dz = pos.X - LODGE.x, pos.Z - LODGE.z
		if math.sqrt(dx * dx + dz * dz) <= LODGE.radius then
			return "lodge"
		end
	end
	local best, bestD = "bayou", math.huge
	for name, offsetX in pairs(OFFSETS) do
		if LOOKS[name] ~= nil then
			local d = math.abs(pos.X - offsetX)
			if d < bestD then
				best, bestD = name, d
			end
		end
	end
	-- beyond half the biome spacing from every destination, keep whatever is nearest rather than snapping
	if bestD > BIOME_HALF_WIDTH * 2 then
		return best
	end
	return best
end

-- ── the loop ──────────────────────────────────────────────────────────────────────────────────────────

local current: { [string]: number } = {}
for k, v in pairs(FLAT.bayou or select(2, next(FLAT))) do
	current[k] = v
end
local targetName = "bayou"
local target = FLAT[targetName] or current
apply(current)

local function rootPosition(): Vector3?
	local char = player.Character
	if char == nil then
		return nil
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	return root and (root :: BasePart).Position or nil
end

local sinceCheck = 0
RunService.RenderStepped:Connect(function(dt)
	sinceCheck += dt
	-- position only needs polling a few times a second; the lerp runs every frame
	if sinceCheck >= 0.25 then
		sinceCheck = 0
		local pos = rootPosition()
		if pos then
			local name = lookNameFor(pos)
			if name ~= targetName and FLAT[name] then
				targetName = name
				target = FLAT[name]
			end
		end
	end

	-- exponential approach: frame-rate independent, and it never overshoots
	local alpha = 1 - math.exp(-dt / (TRANSITION_SECONDS / 3))
	local moved = false
	for k, goal in pairs(target) do
		local now = current[k] or goal
		local delta = goal - now
		if math.abs(delta) > 1e-4 then
			current[k] = now + delta * alpha
			moved = true
		elseif now ~= goal then
			current[k] = goal
			moved = true
		end
	end
	if moved then
		apply(current)
	end
end)

print("[BiomeLook] per-biome lighting active (looks v" .. tostring(payload.version) .. ")")
