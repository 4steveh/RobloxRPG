--!nonstrict
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- STUDIO-ONLY MODULE (src/server/studio/ is excluded from run-tests.sh — see the note below). THE ART
-- INSTANTIATOR.
--
-- WHY THIS IS A MODULESCRIPT and not the boot Script itself: Roblox discards everything Play mode builds
-- when you stop, so the world has to be sculpted in EDIT mode to persist into the .rbxl — and edit mode
-- never runs Scripts. Exposing the builder as a module means it can be driven from the command bar (or the
-- Studio MCP bridge) to bake the world, AND required by world/WorldArt.server.luau to build at runtime on a
-- fresh server. src/server/world/WorldArt.server.luau is now a thin boot script over this.
--
-- src/server/studio/ is the ONE directory under src/ that may use Roblox globals in a non-.server/.client
-- file. run-tests.sh excludes it explicitly, because the headless gate cannot type-check `workspace`.
--
-- This file makes NO art decisions. Every dimension, colour, count, palette, band and anchor comes from
-- src/config/ArtKit.luau; every shape comes from src/logic/ArtGen.luau and src/logic/TerrainGen.luau, which
-- are pure, --!strict, and asserted by 1932 headless assertions. All this script does is translate
-- descriptor tables into Instances and voxels. That split is deliberate: it is what lets the LOOK be
-- regression-tested at all, and it is why this rewrite has no external asset dependency.
--
-- WHAT CHANGED, AND WHY (the previous version of this file):
--   1. It was DORMANT. Everything was gated behind `workspace:GetAttribute("WildWorldArt") == true`, an
--      attribute nothing in the repository ever set. The art had therefore never rendered for a player.
--      This version is active by default and builds once per place.
--   2. It depended on InsertService:LoadAsset for every tree and animal, and its own header documented that
--      LoadAsset cannot authorise assets the place owner does not own — so the intended look was not
--      reproducible from the repo even in principle. All of that is gone; geometry is generated.
--   3. Terrain was a handful of FillBlock slabs and FillBall blobs. It is now a real sculpted heightfield
--      written with WriteVoxels.
--
-- Lighting: this script applies a sane DEFAULT look. Per-biome looks are applied CLIENT-side by
-- client/BiomeLook.client.luau, because Lighting is one shared object and three players in three biomes
-- must not share one biome's sky.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Terrain = workspace.Terrain

-- Relative requires only: @-aliases do NOT resolve in Roblox (only in the headless luau CLI).
-- studio/ sits at the same depth as world/, so the ../../ prefixes are unchanged.
local ArtKit = require("../../config/ArtKit")
local ArtGen = require("../../logic/ArtGen")
local TerrainGen = require("../../logic/TerrainGen")
local Shells = require("../../config/Shells")

local RES = 4 -- Terrain voxel resolution; WriteVoxels only accepts 4
local ART_FOLDER = "WildWorldArt"
local BUILT_ATTR = "WildWorldArt_Built"
local REBUILD_ATTR = "WildWorldArt_Rebuild"
local VERSION_ATTR = "WildWorldArt_Version"

-- Each destination's world-space X offset. Matches WorldServer's placeholder layout.
local WORLD_OFFSET = { bayou = 0, appalachia = 2000, alaska = 4000 }
local LODGE_ANCHOR = Vector3.new(0, 0, 600)

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local PART_SHAPE = {
	block = Enum.PartType.Block,
	ball = Enum.PartType.Ball,
	cylinder = Enum.PartType.Cylinder,
}

local M = {}

-- ── the global look ───────────────────────────────────────────────────────────────────────────────────

-- Applies an ArtKit look to Lighting. Used server-side for the default and client-side per biome.
function M.applyLook(look)
	Lighting.ClockTime = look.clockTime
	Lighting.GeographicLatitude = look.geographicLatitude
	Lighting.Brightness = look.brightness
	Lighting.ExposureCompensation = look.exposureCompensation
	Lighting.ShadowSoftness = look.shadowSoftness
	Lighting.Ambient = c3(look.ambient)
	Lighting.OutdoorAmbient = c3(look.outdoorAmbient)
	Lighting.ColorShift_Top = c3(look.colorShiftTop)
	Lighting.ColorShift_Bottom = c3(look.colorShiftBottom)
	-- Image-based lighting. At 0 every part renders with no sky bounce and reads FLAT; this pair is the
	-- single highest-leverage lighting property in the whole stack.
	Lighting.EnvironmentDiffuseScale = look.environmentDiffuseScale
	Lighting.EnvironmentSpecularScale = look.environmentSpecularScale
	Lighting.GlobalShadows = true
	Lighting.FogColor = c3(look.fogColor)
	Lighting.FogStart = look.fogStart
	Lighting.FogEnd = look.fogEnd
	-- Technology is not scriptable at runtime; it is a place setting. Attempt it anyway for the edit-time
	-- build path, where it does take.
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	local function child(className, name)
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

	local a = look.atmosphere
	local atm = child("Atmosphere", "Atmosphere")
	atm.Density, atm.Offset, atm.Glare, atm.Haze = a.density, a.offset, a.glare, a.haze
	atm.Color, atm.Decay = c3(a.color), c3(a.decay)

	local b = look.bloom
	local bloom = child("BloomEffect", "Bloom")
	bloom.Intensity, bloom.Size, bloom.Threshold = b.intensity, b.size, b.threshold

	local cc = look.colorCorrection
	local cce = child("ColorCorrectionEffect", "ColorCorrection")
	cce.Contrast, cce.Saturation, cce.Brightness, cce.TintColor =
		cc.contrast, cc.saturation, cc.brightness, c3(cc.tint)

	local sr = look.sunRays
	local sun = child("SunRaysEffect", "SunRays")
	sun.Intensity, sun.Spread = sr.intensity, sr.spread

	local df = look.depthOfField
	local dof = child("DepthOfFieldEffect", "DepthOfField")
	dof.FocusDistance, dof.InFocusRadius = df.focusDistance, df.inFocusRadius
	dof.FarIntensity, dof.NearIntensity = df.farIntensity, df.nearIntensity
	dof.Enabled = df.farIntensity > 0

	-- Clouds must be parented to Terrain to render.
	local cl = look.clouds
	local clouds = Terrain:FindFirstChildOfClass("Clouds")
	if clouds == nil then
		clouds = Instance.new("Clouds")
		clouds.Parent = Terrain
	end
	clouds.Cover, clouds.Density, clouds.Color, clouds.Enabled = cl.cover, cl.density, c3(cl.color), true

	local w = look.water
	Terrain.WaterColor = c3(w.color)
	Terrain.WaterTransparency = w.transparency
	Terrain.WaterReflectance = w.reflectance
	Terrain.WaterWaveSize = w.waveSize
	Terrain.WaterWaveSpeed = w.waveSpeed

	-- Wind drives the engine's own foliage sway on parts tagged for it; free motion, no per-frame script.
	local dir = look.windDirection
	workspace.GlobalWind = Vector3.new(dir.x, dir.y, dir.z).Unit * look.windSpeed
end

-- Terrain material colours are global to the place, which is why each biome owns a disjoint material set.
function M.applyTerrainColors()
	-- NOTE: Terrain.Decoration and Terrain.GrassLength are NOT scriptable members in Studio 0.732 (verified
	-- live — both report "not a valid member"). There is therefore no free engine-drawn grass to switch on,
	-- and ground detail has to come from the scatter layer instead. Wrapped anyway so a future Studio that
	-- restores the property picks it up without another crash.
	pcall(function()
		(Terrain :: any).Decoration = true
	end)
	for name, rgb in pairs(ArtKit.terrainColors) do
		local mat = Enum.Material[name]
		if mat then
			pcall(function()
				Terrain:SetMaterialColor(mat, c3(rgb))
			end)
		end
	end
end

-- ── terrain ───────────────────────────────────────────────────────────────────────────────────────────

-- Writes one biome's heightfield with WriteVoxels, chunked so a 750k-voxel biome does not stall Studio.
-- Everything about the SHAPE comes from TerrainGen; this only marshals arrays.
function M.buildTerrain(biomeName, spec, offsetX)
	local matEnum = {}
	local function mat(name)
		local e = matEnum[name]
		if e == nil then
			e = Enum.Material[name] or Enum.Material.Air
			matEnum[name] = e
		end
		return e
	end

	local span = TerrainGen.voxelSpan(spec, RES, 8)
	local pad = spec.shoreFalloff + RES * 2
	local x0 = math.floor((spec.center.x - spec.extent.x * 0.5 - pad) / RES) * RES
	local x1 = math.ceil((spec.center.x + spec.extent.x * 0.5 + pad) / RES) * RES
	local z0 = math.floor((spec.center.z - spec.extent.z * 0.5 - pad) / RES) * RES
	local z1 = math.ceil((spec.center.z + spec.extent.z * 0.5 + pad) / RES) * RES
	local yCount = (span.maxY - span.minY) / RES

	local CHUNK = 32 -- columns per axis per WriteVoxels call
	local chunks, written = 0, 0
	local cx = x0
	while cx < x1 do
		local cxEnd = math.min(cx + CHUNK * RES, x1)
		local cz = z0
		while cz < z1 do
			local czEnd = math.min(cz + CHUNK * RES, z1)
			local nx = (cxEnd - cx) / RES
			local nz = (czEnd - cz) / RES
			if nx > 0 and nz > 0 then
				local materials, occupancies = {}, {}
				for ix = 1, nx do
					local mCol, oCol = {}, {}
					-- voxel centre of this column, in LOCAL biome coordinates
					local wx = cx + (ix - 0.5) * RES
					for iy = 1, yCount do
						mCol[iy] = {}
						oCol[iy] = {}
					end
					for iz = 1, nz do
						local wz = cz + (iz - 0.5) * RES
						local col = TerrainGen.column(spec, wx, wz, RES)
						local ground = mat(col.material)
						local waterTop = col.waterTop
						for iy = 1, yCount do
							local bottom = span.minY + (iy - 1) * RES
							-- HALF-VOXEL CALIBRATION, measured not derived. With occ = (height - bottom)/RES the
							-- built surface came out a consistent +2.0 studs (exactly RES/2) above
							-- TerrainGen.heightAt at every one of 13 probe points across all three biomes:
							-- Roblox resolves a partially-filled voxel's collision surface at the voxel top, not
							-- at the occupancy fraction. Shifting the sampled height down by half a voxel makes
							-- the BUILT surface match the ANALYTIC one — which matters because
							-- tests/TerrainGen.spec asserts walkability and water coverage against the analytic
							-- height, and a 2-stud offset would have made every one of those assertions describe
							-- terrain the player never stands on.
							local occ = (col.height - RES * 0.5 - bottom) / RES
							if occ >= 1 then
								mCol[iy][iz] = ground
								oCol[iy][iz] = 1
							elseif occ > 0 then
								mCol[iy][iz] = ground
								oCol[iy][iz] = occ
							elseif waterTop ~= nil and bottom < waterTop then
								-- Partial fill so the water surface lands exactly at waterTop instead of
								-- snapping to a voxel boundary.
								mCol[iy][iz] = Enum.Material.Water
								oCol[iy][iz] = math.min(1, (waterTop - bottom) / RES)
							else
								mCol[iy][iz] = Enum.Material.Air
								oCol[iy][iz] = 0
							end
						end
					end
					materials[ix] = mCol
					occupancies[ix] = oCol
				end
				local region = Region3.new(
					Vector3.new(cx + offsetX, span.minY, cz),
					Vector3.new(cxEnd + offsetX, span.maxY, czEnd)
				)
				local ok, err = pcall(function()
					Terrain:WriteVoxels(region, RES, materials, occupancies)
				end)
				if not ok then
					warn(("[WildWorldArt] %s: WriteVoxels failed at (%d,%d): %s"):format(biomeName, cx, cz, tostring(err)))
				end
				written += nx * nz * yCount
				chunks += 1
				if chunks % 8 == 0 then
					task.wait() -- keep Studio responsive during a heavy build
				end
			end
			cz = czEnd
		end
		cx = cxEnd
	end
	print(("[WildWorldArt] %s terrain: %d chunks, %d voxels, Y %d..%d"):format(biomeName, chunks, written, span.minY, span.maxY))
end

-- ── descriptor instantiation ──────────────────────────────────────────────────────────────────────────

-- Turns one Art.PartDesc into a real part. `originCF` is the model's world CFrame; `scale` is uniform.
-- Orientation goes through ArtGen.partBasis — the SAME pure function tests/ArtGen.spec asserts bounds
-- against — so what the tests measure and what the engine builds cannot diverge.
local function buildPart(d, originCF, scale, parent)
	local inst
	if d.shape == "wedge" then
		inst = Instance.new("WedgePart")
	elseif d.shape == "cornerWedge" then
		inst = Instance.new("CornerWedgePart")
	else
		inst = Instance.new("Part")
		inst.Shape = PART_SHAPE[d.shape] or Enum.PartType.Block
	end
	inst.Name = d.name
	inst.Anchored = d.anchored ~= false
	inst.Size = Vector3.new(d.size.x * scale, d.size.y * scale, d.size.z * scale)
	inst.Color = c3(d.color)
	inst.Material = Enum.Material[d.material] or Enum.Material.SmoothPlastic
	inst.TopSurface = Enum.SurfaceType.Smooth
	inst.BottomSurface = Enum.SurfaceType.Smooth
	if d.transparency then
		inst.Transparency = d.transparency
	end
	if d.reflectance then
		inst.Reflectance = d.reflectance
	end
	inst.CastShadow = d.castShadow ~= false
	inst.CanCollide = d.canCollide ~= false
	inst.CanQuery = d.canQuery ~= false
	inst.CanTouch = false -- no art part ever needs a Touched event; this is pure saved work

	local r, u = ArtGen.partBasis(d)
	local localCF = CFrame.fromMatrix(
		Vector3.new(d.pos.x * scale, d.pos.y * scale, d.pos.z * scale),
		Vector3.new(r.x, r.y, r.z),
		Vector3.new(u.x, u.y, u.z)
	)
	inst.CFrame = originCF * localCF

	if d.texture then
		local tex = Instance.new("Texture")
		tex.Texture = d.texture.id
		tex.StudsPerTileU = d.texture.studsU
		tex.StudsPerTileV = d.texture.studsV
		if d.texture.transparency then
			tex.Transparency = d.texture.transparency
		end
		for _, face in ipairs(d.texture.faces) do
			local t = tex:Clone()
			t.Face = Enum.NormalId[face]
			t.Parent = inst
		end
		tex:Destroy()
	end

	if d.light then
		local L = d.light
		local cls = (L.kind == "spot" and "SpotLight") or (L.kind == "surface" and "SurfaceLight") or "PointLight"
		local light = Instance.new(cls)
		light.Color = c3(L.color)
		light.Brightness = L.brightness
		light.Range = L.range
		light.Shadows = L.shadows == true
		if L.angle and cls ~= "PointLight" then
			light.Angle = L.angle
		end
		if L.face and cls ~= "PointLight" then
			light.Face = Enum.NormalId[L.face]
		end
		light.Parent = inst
	end

	if d.tag then
		CollectionService:AddTag(inst, d.tag)
	end

	inst.Parent = parent
	return inst
end

-- Instantiates a whole ModelDesc at a world position with a yaw and a uniform scale. The Model is
-- assembled OUT of the DataModel and parented once, so 27k parts do not each trigger their own
-- replication pass.
function M.instantiate(desc, worldPos, yaw, scale, parent)
	local model = Instance.new("Model")
	model.Name = desc.name
	local originCF = CFrame.new(worldPos) * CFrame.Angles(0, yaw or 0, 0)
	local first
	for _, d in ipairs(desc.parts) do
		local p = buildPart(d, originCF, scale or 1, model)
		first = first or p
	end
	model.PrimaryPart = first
	model.Parent = parent
	return model
end

-- ── ground sampling ───────────────────────────────────────────────────────────────────────────────────

-- The visible surface Y at a world point. Raycast is authoritative (it reports the voxel surface the
-- player will actually stand on, which is what earlier placement bugs got wrong by assuming a flat Y),
-- with the generator's own heightAt as the fallback when the ray misses.
-- WorldServer's placeholder blockout keeps a collidable part named "Ground" as a safety floor (usually a
-- flat slab near Y = 0). suppressPlaceholders makes everything ELSE non-collidable, so a RespectCanCollide
-- ray ignores the rest — but that Ground slab would be hit wherever the real terrain sits BELOW it, which is
-- every water basin. The prop would then be placed at Y = 0, the `submerged` test would read false, and
-- cypress trees would grow out of open water. Excluding the placeholder folders is the fix.
local PLACEHOLDER_FOLDERS = {
	"BayouShell_Placeholder",
	"AppalachiaShell_Placeholder",
	"AlaskaShell_Placeholder",
	"Lodge_Placeholder",
}
local function placeholderExclusions()
	local out = {}
	for _, name in ipairs(PLACEHOLDER_FOLDERS) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(out, f)
		end
	end
	return out
end

local function groundInfo(worldX, worldZ, spec, localX, localZ, ignore)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = placeholderExclusions()
	for _, inst in ipairs(ignore or {}) do
		table.insert(exclude, inst)
	end
	rp.FilterDescendantsInstances = exclude
	rp.IgnoreWater = true -- we want the BED, then compare against the water line ourselves
	rp.RespectCanCollide = true
	local from = Vector3.new(worldX, 400, worldZ)
	local hit = workspace:Raycast(from, Vector3.new(0, -900, 0), rp)
	if hit then
		return hit.Position.Y, hit.Normal.Y
	end
	-- fall back to the analytic height; normal from the analytic slope
	local h = TerrainGen.heightAt(spec, localX, localZ)
	local s = TerrainGen.slopeAt(spec, localX, localZ, RES)
	return h, 1 / math.sqrt(1 + s * s)
end

-- ── scatter ───────────────────────────────────────────────────────────────────────────────────────────

local RECIPE_TABLE = { tree = "trees", rock = "rocks", cluster = "clusters" }

-- Realises one biome's scatter plan. The candidate SET is pure and asserted headlessly; this applies the
-- ground filters that need a live world (real surface height, real slope, land vs water).
function M.buildScatter(biomeName, spec, offsetX, parent)
	local plan = ArtKit.scatterPlans[biomeName]
	if plan == nil then
		return 0, 0
	end
	local placed, parts, rejected = 0, 0, 0
	for patchIndex, patch in ipairs(plan) do
		local recipes = ArtKit[RECIPE_TABLE[patch.kind]]
		local candidates = ArtGen.scatter({
			center = patch.center,
			radius = patch.radius,
			count = patch.count,
			recipeCount = #patch.recipes,
			scale = patch.scale,
			minSpacing = patch.spacing,
		}, patch.seed, 30)

		local folder = Instance.new("Folder")
		folder.Name = ("%s_%s_%d"):format(biomeName, patch.kind, patchIndex)

		for _, c in ipairs(candidates) do
			local wx, wz = c.x + offsetX, c.z
			local gy, normalY = groundInfo(wx, wz, spec, c.x, c.z, { parent })
			local slope = math.sqrt(math.max(0, 1 - normalY * normalY)) / math.max(normalY, 1e-3)
			local submerged = gy < spec.waterLevel

			local ok = true
			if patch.waterOnly then
				-- lily pads and duckweed sit ON the surface, so they need water beneath them
				ok = submerged
			else
				if submerged then
					ok = false
				end
				if patch.minGroundY and gy < patch.minGroundY then
					ok = false
				end
				if patch.maxGroundY and gy > patch.maxGroundY then
					ok = false
				end
				if patch.maxSlope and normalY < patch.maxSlope then
					ok = false
				end
			end
			-- an unused slope value would be a lint; fold it into the reject reason instead
			if ok and patch.maxSlope == nil and slope > 4 then
				ok = false
			end

			if ok then
				local key = patch.recipes[c.recipeIndex] or patch.recipes[1]
				local recipe = recipes[key]
				if recipe then
					local desc
					if patch.kind == "tree" then
						desc = ArtGen.tree(recipe, c.seed)
					elseif patch.kind == "rock" then
						desc = ArtGen.rock(recipe, c.seed)
					else
						desc = ArtGen.cluster(recipe, c.seed)
					end
					-- water-surface props sit at the water line, not on the bed
					local y = if patch.waterOnly then spec.waterLevel else gy
					M.instantiate(desc, Vector3.new(wx, y, wz), c.yaw, c.scale, folder)
					placed += 1
					parts += #desc.parts
				end
			else
				rejected += 1
			end
		end
		folder.Parent = parent
		task.wait()
	end
	print(("[WildWorldArt] %s scatter: %d props (%d parts), %d rejected by ground filter"):format(biomeName, placed, parts, rejected))
	return placed, parts
end

-- ── landmarks + buildings ─────────────────────────────────────────────────────────────────────────────

-- The §2.2 wayfinding beacons. Each destination's beacon is a hero-scale prop the player can navigate by;
-- tests/ArtGen.spec asserts the Old Cypress is measurably taller and wider than a canopy tree.
local BEACON = {
	bayou = { recipe = "oldCypress", kind = "tree" },
	appalachia = { recipe = "pine", kind = "tree", scale = 1.9 },
	alaska = { recipe = "spruce", kind = "tree", scale = 1.9 },
}

function M.buildLandmarks(biomeName, spec, offsetX, parent)
	local shell = Shells.byDestination[biomeName]
	if shell == nil then
		return
	end
	local beacon = BEACON[biomeName]
	for _, lm in pairs(shell.landmarks) do
		if lm.isBeacon and beacon then
			local recipe = ArtKit[RECIPE_TABLE[beacon.kind]][beacon.recipe]
			if recipe then
				local desc = ArtGen.tree(recipe, 4242)
				local gy = groundInfo(lm.anchor.x + offsetX, lm.anchor.z, spec, lm.anchor.x, lm.anchor.z, { parent })
				local model = M.instantiate(
					desc,
					Vector3.new(lm.anchor.x + offsetX, gy, lm.anchor.z),
					0,
					beacon.scale or 1,
					parent
				)
				model.Name = "Beacon_" .. lm.id
			end
		end
	end
end

-- The vendor outposts: one small cabin at each destination's vendor anchor, so the trade hub reads as a
-- built place rather than a floating billboard.
function M.buildOutposts(biomeName, spec, offsetX, parent)
	local shell = Shells.byDestination[biomeName]
	if shell == nil then
		return
	end
	for _, zone in pairs(shell.zones) do
		if zone.kind == "vendor" then
			local desc = ArtGen.cabin(ArtKit.cabins.outpost)
			local gy = groundInfo(zone.center.x + offsetX, zone.center.z, spec, zone.center.x, zone.center.z, { parent })
			local model = M.instantiate(
				desc,
				Vector3.new(zone.center.x + offsetX, gy, zone.center.z),
				math.pi, -- porch faces the arrival approach
				1,
				parent
			)
			model.Name = "Outpost_" .. zone.id
		end
	end
end

-- The Lodge: a real log building with a lit interior. Prior review flagged the hub as the single weakest
-- surface in the game — it was six flat boxes.
function M.buildLodge(parent)
	local desc = ArtGen.cabin(ArtKit.cabins.lodge)
	local model = M.instantiate(desc, LODGE_ANCHOR, 0, 1, parent)
	model.Name = "Lodge"

	local P = ArtKit.palettes.lodge
	local hearthPos = LODGE_ANCHOR + Vector3.new(0, 3, ArtKit.cabins.lodge.depth * 0.5 - 4)

	-- the hearth fire: the room's warm key light
	local logs = Instance.new("Part")
	logs.Name = "HearthLogs"
	logs.Anchored = true
	logs.Size = Vector3.new(6, 2, 2.6)
	logs.CFrame = CFrame.new(hearthPos)
	logs.Color = c3(P.trim[1])
	logs.Material = Enum.Material.Wood
	logs.CanCollide = false
	logs.CanTouch = false
	logs.Parent = model
	local fire = Instance.new("Fire")
	fire.Heat, fire.Size = 9, 6
	fire.Color, fire.SecondaryColor = c3(P.fireWarm), Color3.fromRGB(255, 96, 32)
	fire.Parent = logs
	local fl = Instance.new("PointLight")
	fl.Color, fl.Brightness, fl.Range, fl.Shadows = c3(P.fireWarm), 4.5, 40, true
	fl.Parent = logs

	-- lamps down the room, so the interior has depth instead of one flat ambient level
	local L = ArtKit.cabins.lodge
	for _, off in ipairs({ -L.depth * 0.28, 0, L.depth * 0.28 }) do
		for _, sx in ipairs({ -L.width * 0.3, L.width * 0.3 }) do
			local a = Instance.new("Part")
			a.Name = "Lamp"
			a.Anchored, a.Transparency, a.CanCollide, a.CanQuery, a.CanTouch = true, 1, false, false, false
			a.Size = Vector3.new(0.6, 0.6, 0.6)
			a.CFrame = CFrame.new(LODGE_ANCHOR + Vector3.new(sx, L.wallHeight - 4, off))
			a.Parent = model
			local pl = Instance.new("PointLight")
			pl.Color, pl.Brightness, pl.Range = c3(P.lampWarm), 1.1, 34
			pl.Parent = a
		end
	end
	print(("[WildWorldArt] Lodge: %d parts"):format(#desc.parts))
end

-- ── placeholder suppression ───────────────────────────────────────────────────────────────────────────

-- WorldServer rebuilds coarse placeholder blockout every session for its gameplay anchors. Hide the
-- visuals but keep the collision floor and the SpawnLocations, and keep watching for late children.
function M.suppressPlaceholders()
	local function hide(folder)
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") and not d:IsA("SpawnLocation") then
				d.Transparency = 1
				d.CastShadow = false
				if d.Name ~= "Ground" then
					d.CanCollide = false
				end
			end
		end
	end
	task.spawn(function()
		for _, name in ipairs({
			"BayouShell_Placeholder",
			"AppalachiaShell_Placeholder",
			"AlaskaShell_Placeholder",
			"Lodge_Placeholder",
		}) do
			local f = workspace:WaitForChild(name, 30)
			if f then
				hide(f)
				f.DescendantAdded:Connect(function(d)
					if d:IsA("BasePart") and not d:IsA("SpawnLocation") then
						d.Transparency = 1
						d.CastShadow = false
						if d.Name ~= "Ground" then
							d.CanCollide = false
						end
					end
				end)
			end
		end
	end)
end

-- ── cosmetic gait ─────────────────────────────────────────────────────────────────────────────────────
-- Leg swing on the generated visual. WorldServer owns POSITION and the body gait (bob/roll/lean folded into
-- its PivotTo); this owns only the legs.
--
-- WHY SERVER-SIDE AND NOT CLIENT-SIDE. Model:PivotTo writes every part's CFrame, so a client-side leg offset
-- is overwritten on the next replication tick and jitters at the tick rate. The legs have to move on the same
-- authority that moves the model.
--
-- WHY IT READS THE PUBLISHED gaitSpeed instead of differencing position. The body bob is vertical motion in
-- the same CFrame, so a position delta reads the bob as travel and the legs would twitch while the animal
-- stands still. WorldServer publishes its own integrated speed and stride phase as attributes.
--
-- Diagonal pairs swing together (fore-left with hind-right), which is what a real quadruped walk does; the
-- alternative — both fore legs together — is a bunny hop.
local GAIT_SWING = math.rad(26) -- peak hip rotation at full speed
local GAIT_DISTANCE = 170 -- studs from the nearest player; past this nobody can see a leg move
local gaitRigs = {} -- model -> { { parts = {{part, offset}}, hip = Vector3, phase = number } }

local LEG_PHASE = { ForeLegL = 0, HindLegR = 0, ForeLegR = math.pi, HindLegL = math.pi }

-- Record each leg's parts in MODEL-LOCAL space once, at upgrade time. Doing it per frame would mean
-- inverting the model pivot for every part on every tick.
local function buildGaitRig(model, visual)
	local pivot = model:GetPivot()
	local groups = {}
	for _, d in ipairs(visual:GetDescendants()) do
		if d:IsA("BasePart") and LEG_PHASE[d.Name] ~= nil then
			local g = groups[d.Name]
			if g == nil then
				g = { parts = {}, phase = LEG_PHASE[d.Name], hipY = -math.huge }
				groups[d.Name] = g
			end
			local localCF = pivot:ToObjectSpace(d.CFrame)
			table.insert(g.parts, { part = d, localCF = localCF })
			-- the hip is the top of the highest segment in the group
			local topY = localCF.Position.Y + d.Size.Y * 0.5
            if topY > g.hipY then
				g.hipY = topY
				g.hipX = localCF.Position.X
				g.hipZ = localCF.Position.Z
			end
		end
	end
	local list = {}
	for _, g in pairs(groups) do
		if #g.parts > 0 then
			g.hip = Vector3.new(g.hipX or 0, g.hipY, g.hipZ or 0)
			table.insert(list, g)
		end
	end
	if #list == 0 then
		return nil
	end
	return list
end

function M.startGaitLoop()
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		accum += dt
		if accum < 1 / 20 then -- 20 Hz is well past the point a swinging leg reads as continuous
			return
		end
		accum = 0
		-- nearest-player distance gate: with no players nearby this loop costs one distance check per creature
		local heads = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local root = char and char.PrimaryPart
			if root then
				table.insert(heads, root.Position)
			end
		end
		for model, rig in pairs(gaitRigs) do
			if model.Parent == nil then
				gaitRigs[model] = nil
			else
				local pivot = model:GetPivot()
				local near = #heads == 0
				for _, h in ipairs(heads) do
					if (h - pivot.Position).Magnitude <= GAIT_DISTANCE then
						near = true
						break
					end
				end
				if near then
					local speed = model:GetAttribute("gaitSpeed") or 0
					local phase = model:GetAttribute("gaitPhase") or 0
					local amount = math.clamp(speed / 6, 0, 1.3)
					for _, g in ipairs(rig) do
						local angle = GAIT_SWING * amount * math.sin(phase + g.phase)
						-- rotate the whole leg rigidly about its hip, in model-local space
						local hipCF = CFrame.new(g.hip)
						local swing = hipCF * CFrame.Angles(angle, 0, 0) * hipCF:Inverse()
						for _, entry in ipairs(g.parts) do
							entry.part.CFrame = pivot * swing * entry.localCF
						end
					end
				end
			end
		end
	end)
end

-- ── creature visuals ──────────────────────────────────────────────────────────────────────────────────
-- WorldServer spawns a coarse THREE-BOX hitbox per creature: torso (hitZone "body"), head ("vital") and
-- sometimes a tail ("limb"), all CanQuery = true so the hunting raycast and Combat.zoneMultiplier work.
-- This pass leaves that contract completely alone: it hides the boxes (Transparency = 1, CanQuery
-- UNTOUCHED) and adds a generated silhouette whose every part is canQuery = false.
--
-- No welds and no Motor6D. The visual parts are parented into the SAME Model, and WorldServer moves
-- creatures with model:PivotTo — which moves every part in the model rigidly. The earlier
-- Motor6D-off-the-PrimaryPart approach was solving a problem that does not exist here, and it added a
-- physics constraint per creature.
--
-- Both the hitbox and this visual are generated from ArtGen.creatureAnatomy, so the vital zone sits where
-- the head is drawn.

local UPGRADED_ATTR = "artUpgraded"

-- A fishing BITE is not a Model — WorldServer spawns it as a single queryable Part carrying a `fishId`.
-- It gets a surface-disturbance visual rather than a fish silhouette: the fish is hooked and underwater, so
-- what the player should see is rings, a fin breaking the surface, and splash.
function M.upgradeBite(part)
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return
	end
	if part:GetAttribute(UPGRADED_ATTR) then
		return
	end
	local id = part:GetAttribute("fishId") or part:GetAttribute("targetId")
	if id == nil then
		return
	end
	local recipe = ArtKit.fishArt[id]
	if recipe == nil then
		warn(("[WildWorldArt] no fish recipe for bite '%s' — it keeps its placeholder cube"):format(tostring(id)))
		return
	end
	part:SetAttribute(UPGRADED_ATTR, true)
	-- hide the cube but leave CanQuery alone: the cast has to keep hitting it
	part.Transparency = 1
	part.CastShadow = false

	local seed = 0
	local key = tostring(id)
	for i = 1, #key do
		seed += string.byte(key, i) * i
	end
	local desc = ArtGen.biteMarker(recipe, seed)
	local visual = Instance.new("Folder")
	visual.Name = "ArtVisual"
	-- the marker sits on the waterline, not at the cube's centre
	local surface = CFrame.new(part.Position.X, part.Position.Y - part.Size.Y * 0.5, part.Position.Z)
	for _, d in ipairs(desc.parts) do
		buildPart(d, surface, 1, visual)
	end
	visual.Parent = part
	return visual
end

function M.upgradeCreature(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		-- a bite marker arrives here too, since both folders share one listener
		return M.upgradeBite(model)
	end
	if model:GetAttribute(UPGRADED_ATTR) then
		return
	end
	local id = model:GetAttribute("creatureId") or model:GetAttribute("fishId") or model:GetAttribute("targetId")
	local pp = model.PrimaryPart
	if id == nil or pp == nil then
		return
	end
	local recipe = ArtKit.creatureArt[id] or ArtKit.fishArt[id]
	if recipe == nil then
		-- Surfaced, not swallowed: a silent box fallback is exactly how 22 unmapped creatures stayed grey
		-- for an entire build without anyone noticing.
		warn(("[WildWorldArt] no art recipe for '%s' — it will render as its hitbox boxes"):format(tostring(id)))
		return
	end
	model:SetAttribute(UPGRADED_ATTR, true)

	-- hide the hitboxes; CanQuery is deliberately NOT touched
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CastShadow = false
		end
	end

	-- a stable per-instance seed so the same creature keeps the same colour jitter across sessions
	local seed = 0
	for i = 1, #tostring(id) do
		seed += string.byte(tostring(id), i) * i
	end
	local desc = ArtGen.creature(recipe, seed)

	local visual = Instance.new("Folder")
	visual.Name = "ArtVisual"
	local originCF = pp.CFrame
	for _, d in ipairs(desc.parts) do
		buildPart(d, originCF, 1, visual)
	end
	visual.Parent = model
	-- record the leg rig for the cosmetic gait loop; a creature with no legs (fish, bite marker) yields nil
	local rig = buildGaitRig(model, visual)
	if rig ~= nil then
		gaitRigs[model] = rig
	end
	return visual
end

function M.startCreatureUpgrades()
	task.spawn(function()
		for _, folderName in ipairs({ "HuntingTargets", "FishingBites" }) do
			local f = workspace:WaitForChild(folderName, 30)
			if f then
				for _, m in ipairs(f:GetChildren()) do
					task.spawn(function()
						local ok, err = pcall(M.upgradeCreature, m)
						if not ok then
							warn("[WildWorldArt] creature upgrade failed: " .. tostring(err))
						end
					end)
				end
				f.ChildAdded:Connect(function(m)
					task.defer(function()
						local ok, err = pcall(M.upgradeCreature, m)
						if not ok then
							warn("[WildWorldArt] creature upgrade failed: " .. tostring(err))
						end
					end)
				end)
			end
		end
	end)
end

-- ── ambience ──────────────────────────────────────────────────────────────────────────────────────────
-- REGRESSION NOTE: the pre-rewrite WorldArt had a buildSoundscape pass and this rewrite dropped it, so the
-- world shipped silent for several builds. Restored here, driven from ArtKit.ambience.
--
-- Linear rolloff with a maxDistance well under the 2000-stud biome spacing is what keeps each bed local
-- without any code deciding which one to play.
function M.buildSoundscape(parent)
	local placed = 0
	local function emit(name, position, spec)
		if spec == nil or spec.id == nil then
			return
		end
		local anchor = Instance.new("Part")
		anchor.Name = name
		anchor.Anchored, anchor.Transparency, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch =
			true, 1, false, false, false
		anchor.Size = Vector3.one
		anchor.CastShadow = false
		anchor.Position = position
		anchor.Parent = parent
		local snd = Instance.new("Sound")
		snd.Name = "Ambience"
		snd.SoundId = "rbxassetid://" .. tostring(spec.id)
		snd.Looped = true
		snd.Volume = spec.volume
		snd.RollOffMode = Enum.RollOffMode.Linear
		snd.RollOffMinDistance = spec.minDistance
		snd.RollOffMaxDistance = spec.maxDistance
		snd.Playing = true
		snd.Parent = anchor
		placed += 1
	end

	for biome, spec in pairs(ArtKit.ambience) do
		local offsetX = WORLD_OFFSET[biome] or 0
		local terrain = ArtKit.terrainSpecs[biome]
		for i, pt in ipairs(spec.points) do
			-- lift the emitter above the local ground so it is never buried inside terrain
			local y = 8
			if terrain ~= nil then
				y = TerrainGen.heightAt(terrain, pt.x, pt.z) + 8
			end
			emit(("Ambience_%s_%d"):format(biome, i), Vector3.new(pt.x + offsetX, y, pt.z), spec)
		end
	end
	emit("Ambience_lodge_hearth", LODGE_ANCHOR + Vector3.new(0, 4, ArtKit.cabins.lodge.depth * 0.5 - 4), ArtKit.hearthSound)
	print(("[WildWorldArt] soundscape: %d emitters"):format(placed))
end

-- ── publish the looks to the client ───────────────────────────────────────────────────────────────────
-- A LocalScript cannot require anything under ServerScriptService, so the per-biome looks are published as
-- one JSON StringValue in ReplicatedStorage and client/BiomeLook.client.luau applies them. This keeps the
-- headless/Studio boundary intact (no logic module gets replicated) and keeps ArtKit the single source of
-- truth for the values — the client never hard-codes a colour.

function M.publishLooks()
	local HttpService = game:GetService("HttpService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local payload = {
		version = ArtKit.version,
		looks = ArtKit.looks,
		-- where each biome is, so the client can tell which look to apply from the player's position alone
		offsets = WORLD_OFFSET,
		lodge = { x = LODGE_ANCHOR.X, z = LODGE_ANCHOR.Z, radius = 90 },
	}
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not ok then
		warn("[WildWorldArt] could not encode looks for the client: " .. tostring(encoded))
		return
	end
	local sv = ReplicatedStorage:FindFirstChild("WildWorldLooks")
	if sv == nil or not sv:IsA("StringValue") then
		if sv then
			sv:Destroy()
		end
		sv = Instance.new("StringValue")
		sv.Name = "WildWorldLooks"
		sv.Parent = ReplicatedStorage
	end
	sv.Value = encoded
end


-- ── legacy cleanup ────────────────────────────────────────────────────────────────────────────────────
-- The saved place carries ~3,310 parts of art from the PREVIOUS overhaul, spread across sixteen
-- `WildWorldArt_*` folders built by the old Creator-Store pipeline. The new build writes a single
-- `WildWorldArt` folder, so without this step the two would render on top of each other — doubled trees,
-- old grey-box wildlife standing inside new creatures.
--
-- ReplicatedStorage.WildWorldArt is deliberately LEFT ALONE: it holds the imported Creator-Store templates,
-- which cannot be re-downloaded (LoadAsset will not authorise them) and are the only copy in existence.
-- Nothing in the new pipeline reads them, but destroying them would be irreversible.
local LEGACY_FOLDERS = {
	"WildWorldArt_Cypress",
	"WildWorldArt_OldCypress",
	"WildWorldArt_Duckweed",
	"WildWorldArt_Reeds",
	"WildWorldArt_Slough",
	"WildWorldArt_Wildlife",
	"WildWorldArt_Ambient",
	"WildWorldArt_Lodge",
	"WildWorldArt_Sound",
	"WildWorldArt_Vehicles",
	"WildWorldArt_AP_Forest",
	"WildWorldArt_AP_Wildlife",
	"WildWorldArt_AP_Weather",
	"WildWorldArt_AK_Forest",
	"WildWorldArt_AK_Wildlife",
	"WildWorldArt_AK_Weather",
}

function M.removeLegacyArt()
	local removed, parts = 0, 0
	for _, name in ipairs(LEGACY_FOLDERS) do
		local f = workspace:FindFirstChild(name)
		if f then
			for _, d in ipairs(f:GetDescendants()) do
				if d:IsA("BasePart") then
					parts += 1
				end
			end
			f:Destroy()
			removed += 1
		end
	end
	-- the old gate attribute, so a stale `true` cannot re-trigger anything
	if workspace:GetAttribute("WildWorldArt") ~= nil then
		workspace:SetAttribute("WildWorldArt", nil)
	end
	if removed > 0 then
		print(("[WildWorldArt] removed %d legacy art folders (%d parts) from the previous pipeline"):format(removed, parts))
	end
	return removed, parts
end

-- Clears the terrain the previous pipeline sculpted, so a rebuild does not leave its FillBlock slabs
-- underneath the new heightfield. Bounded to the three biome footprints plus generous margin.
function M.clearTerrain()
	for _, offsetX in pairs(WORLD_OFFSET) do
		local spec = nil
		for name, ox in pairs(WORLD_OFFSET) do
			if ox == offsetX then
				spec = ArtKit.terrainSpecs[name]
			end
		end
		if spec then
			local pad = spec.shoreFalloff + 120
			local size = Vector3.new(spec.extent.x + pad * 2, 700, spec.extent.z + pad * 2)
			local centre = Vector3.new(spec.center.x + offsetX, 60, spec.center.z)
			pcall(function()
				Terrain:FillBlock(CFrame.new(centre), size, Enum.Material.Air)
			end)
		end
	end
end

-- ── orchestration ─────────────────────────────────────────────────────────────────────────────────────

function M.buildAll()
	M.removeLegacyArt()
	local root = workspace:FindFirstChild(ART_FOLDER)
	if root then
		root:Destroy()
	end
	M.clearTerrain()
	root = Instance.new("Folder")
	root.Name = ART_FOLDER
	root.Parent = workspace

	M.applyTerrainColors()
	-- The server's default look is the Bayou's (the free starter destination and the hero look). Clients
	-- override per biome.
	M.applyLook(ArtKit.looks.bayou)

	local totalParts = 0
	for _, biomeName in ipairs({ "bayou", "appalachia", "alaska" }) do
		local spec = ArtKit.terrainSpecs[biomeName]
		local offsetX = WORLD_OFFSET[biomeName]
		if spec then
			local folder = Instance.new("Folder")
			folder.Name = biomeName
			folder.Parent = root

			local t0 = os.clock()
			M.buildTerrain(biomeName, spec, offsetX)
			-- terrain must exist before anything raycasts onto it
			task.wait()
			M.buildLandmarks(biomeName, spec, offsetX, folder)
			M.buildOutposts(biomeName, spec, offsetX, folder)
			local _, parts = M.buildScatter(biomeName, spec, offsetX, folder)
			totalParts += parts
			print(("[WildWorldArt] %s complete in %.1fs"):format(biomeName, os.clock() - t0))
		end
	end

	local lodgeFolder = Instance.new("Folder")
	lodgeFolder.Name = "lodge"
	lodgeFolder.Parent = root
	M.buildLodge(lodgeFolder)

	local soundFolder = Instance.new("Folder")
	soundFolder.Name = "ambience"
	soundFolder.Parent = root
	M.buildSoundscape(soundFolder)

	print(("[WildWorldArt] BUILD COMPLETE — %d scatter parts, budget %d"):format(totalParts, ArtKit.budget.maxPartsTotal))
	if totalParts > ArtKit.budget.maxPartsTotal then
		warn(("[WildWorldArt] over part budget: %d > %d"):format(totalParts, ArtKit.budget.maxPartsTotal))
	end
end


return M
