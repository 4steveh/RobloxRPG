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

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- REPRODUCIBLE WORLD BUILD — so the visual layer rebuilds from the repo + the asset-ID manifest, not just a
-- saved .rbxl. ensureTemplates() reloads the Creator-Store/generated assets into RS.WildWorldArt; the
-- build<World>() fns sculpt terrain + clone-scatter props/creatures + assemble the Lodge. Idempotent
-- (fresh folders, re-sculpt) + run ONCE per session (marker attr). HEAVY. Authored from the validated MCP
-- build (2026-06-19); asset loads are pcall-safe (degrade to boxes/empty on failure). ⚠ Expect a debug
-- pass on first real deploy (the Rojo plugin was disconnected, so this exact code path is not yet Play-run).
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local Shells = require("../../config/Shells")
local InsertService = game:GetService("InsertService")
local AssetService = game:GetService("AssetService")
local worldOffsets = { bayou = Vector3.new(0,0,0), appalachia = Vector3.new(2000,0,0), alaska = Vector3.new(4000,0,0) }
local Terrain = workspace.Terrain

local function box(parent, name, size, pos, color, material)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.Size, p.Position, p.Color = name, true, size, pos, color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function terrainY(x, z, ignore)
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore or {}
	local r = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), rp)
	return r and r.Position.Y or -1e9
end
local function freshFolder(name)
	local f = workspace:FindFirstChild(name); if f then f:Destroy() end
	f = Instance.new("Folder"); f.Name = name; f.Parent = workspace; return f
end
local function stripAndAnchor(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false end
	end
end
local function uprightPivot(model)
	local cf, s = model:GetBoundingBox()
	pcall(function() model.WorldPivot = CFrame.new(cf.X, cf.Y - s.Y/2, cf.Z) end)
end
local function poolFrom(folder)
	local p = {}
	if folder then for _, t in ipairs(folder:GetChildren()) do if t:IsA("Model") then table.insert(p, t) end end end
	return p
end
-- scatter cloned trees from a pool onto terrain (raycast-placed, height-normalized, optionally frosted)
local function scatterTrees(pool, offX, clusters, folder, opts)
	if #pool == 0 then return 0 end
	opts = opts or {}; local rng = Random.new(opts.seed or 1); local placed = 0
	for _, cl in ipairs(clusters) do
		for _ = 1, cl[4] do
			local a, d = rng:NextNumber(0, 6.28), rng:NextNumber(2, cl[3])
			local wx, z = offX + cl[1] + math.cos(a)*d, cl[2] + math.sin(a)*d
			local gy = terrainY(wx, z, { folder })
			if gy > (opts.minY or 0.3) then
				local t = pool[rng:NextInteger(1, #pool)]:Clone()
				local _, ts = t:GetBoundingBox()
				pcall(function() t:ScaleTo(t:GetScale() * rng:NextNumber(opts.minH or 22, opts.maxH or 40) / math.max(ts.Y, 1)) end)
				if opts.frost then for _, p in ipairs(t:GetDescendants()) do if p:IsA("BasePart") then p.Color = p.Color:Lerp(Color3.fromRGB(226,233,242), 0.4) end end end
				t:PivotTo(CFrame.new(wx, gy - 0.5, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0))
				t.Parent = folder; placed += 1
			end
		end
	end
	return placed
end
local function placeCreature(creatures, name, parent, wx, lz, yaw, recolor, scale)
	local t = creatures:FindFirstChild(name); if not t then return end
	local c = t:Clone(); if scale then c:ScaleTo(scale) end
	if recolor then for _, d in ipairs(c:GetDescendants()) do if d:IsA("BasePart") then d.Color = recolor end end end
	c:PivotTo(CFrame.new(wx, terrainY(wx, lz, {}), lz) * CFrame.Angles(0, yaw, 0))
	c.Parent = parent
	return c
end

-- ── ensureTemplates: rebuild the RS.WildWorldArt model library from manifest asset IDs (idempotent) ──
-- ⚠ RUNTIME LIMITATION (verified 2026-06-19): InsertService:LoadAsset only authorizes assets the PLACE
-- OWNER owns/created. The GENERATED meshes (the gator, via AssetService:CreateMeshPartAsync) reload fine,
-- but the third-party CREATOR-STORE models (deer/rabbit/duck/trees/…) FAIL LoadAsset ("not authorized").
-- ⇒ For those, ensureModel no-ops when the template is MISSING (it relies on the BAKED RS template that is
-- saved with the .rbxl). So: fully fresh-place reproducible for generated meshes + the deterministic
-- terrain/scatter/lodge build; the Creator-Store TEMPLATE library needs the saved place (or the owner to
-- "take" those assets so LoadAsset authorizes them). The manifest IDs + the MCP insert_asset path remain the
-- full out-of-game rebuild recipe.
function M.ensureTemplates()
	local root = ReplicatedStorage:FindFirstChild("WildWorldArt") or Instance.new("Folder")
	root.Name = "WildWorldArt"; root.Parent = ReplicatedStorage
	local props = root:FindFirstChild("Props") or Instance.new("Folder"); props.Name = "Props"; props.Parent = root
	local creatures = root:FindFirstChild("Creatures") or Instance.new("Folder"); creatures.Name = "Creatures"; creatures.Parent = root
	local A = ArtAssets

	local function loadMainModel(assetId)
		local ok, container = pcall(function() return InsertService:LoadAsset(tonumber(assetId)) end)
		if not ok or not container then return nil end
		local best, bestN = nil, -1
		for _, c in ipairs(container:GetChildren()) do
			local n = #c:GetDescendants()
			if n > bestN then best, bestN = c, n end
		end
		return best
	end
	local function ensureModel(id, parent, name, scale)
		if not id or parent:FindFirstChild(name) then return end
		local m = loadMainModel(id)
		if m then
			m.Name = name; stripAndAnchor(m)
			if scale then pcall(function() m:ScaleTo(scale) end) end
			uprightPivot(m); m.Parent = parent
		else
			warn(("[WildWorldArt] template '%s' (asset %s) not loadable at runtime (likely a non-owned Creator-Store asset) — relying on the baked .rbxl template if present"):format(name, tostring(id)))
		end
	end
	local cr = A.creatures
	ensureModel(A.props.cypress and A.props.cypress.modelAssetId, props, "Cypress")
	ensureModel(cr.bayou_swamp_rabbit and cr.bayou_swamp_rabbit.modelAssetId, creatures, "SwampRabbit")
	ensureModel(cr.bayou_wood_duck and cr.bayou_wood_duck.modelAssetId, creatures, "WoodDuck", 0.045)
	ensureModel(cr.bayou_great_egret and cr.bayou_great_egret.modelAssetId, creatures, "Heron", 0.7)
	ensureModel(cr.bayou_painted_turtle and cr.bayou_painted_turtle.modelAssetId, creatures, "Turtle")
	ensureModel(A.fish.bayou_leviathan and A.fish.bayou_leviathan.modelAssetId, creatures, "Leviathan")
	ensureModel(cr.appalachia_whitetail_deer and cr.appalachia_whitetail_deer.modelAssetId, creatures, "Deer")
	ensureModel(cr.alaska_bull_moose and cr.alaska_bull_moose.modelAssetId, creatures, "Moose")
	ensureModel(cr.alaska_grizzly_bear and cr.alaska_grizzly_bear.modelAssetId, creatures, "Bear")

	-- conifer pool (one wrapper Model → many "Tree" children) → Props.Forest folder
	if A.props.forest and not props:FindFirstChild("Forest") then
		local pack = loadMainModel(A.props.forest.modelAssetId)
		if pack then
			local ff = Instance.new("Folder"); ff.Name = "Forest"; ff.Parent = props
			for _, t in ipairs(pack:GetDescendants()) do
				if t:IsA("Model") and t.Name == "Tree" then stripAndAnchor(t); uprightPivot(t); t.Parent = ff end
			end
			pack:Destroy()
		end
	end

	-- generated MESH creatures (gator) → MeshPart from meshId, wrapped in a Model
	local gd = cr.bayou_american_alligator
	if gd and gd.meshId and not creatures:FindFirstChild("Alligator") then
		local ok, mp = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromUri(gd.meshId)) end)
		if ok and mp then
			mp.Anchored, mp.CanCollide = true, false
			if gd.textureId then pcall(function() mp.TextureID = gd.textureId end) end
			local m = Instance.new("Model"); m.Name = "Alligator"; mp.Parent = m; m.PrimaryPart = mp
			uprightPivot(m); m.Parent = creatures
		end
	end
	-- Grizzly = brown recolor of Bear (texture stripped)
	if creatures:FindFirstChild("Bear") and not creatures:FindFirstChild("Grizzly") then
		local g = creatures.Bear:Clone(); g.Name = "Grizzly"
		for _, d in ipairs(g:GetDescendants()) do
			if d:IsA("BasePart") then d.Color = Color3.fromRGB(122,88,56) end
			if d:IsA("MeshPart") then d.TextureID = "" end
		end
		g.Parent = creatures
	end
end

-- ── BAYOU (offset 0): blackwater basin + hummocks, cypress grove + Old Cypress, reeds, duckweed, slough ──
function M.buildBayou()
	local shell = Shells.byDestination.bayou
	local tw = ArtAssets.terrain.water
	Terrain.WaterColor, Terrain.WaterTransparency, Terrain.WaterReflectance = c3(tw.color), tw.transparency, tw.reflectance
	Terrain.WaterWaveSize, Terrain.WaterWaveSpeed = tw.waveSize, tw.waveSpeed
	for mat, col in ArtAssets.terrain.materialColors do pcall(function() Terrain:SetMaterialColor(Enum.Material[mat], c3(col)) end) end
	Terrain:FillBlock(CFrame.new(0, -4, 100), Vector3.new(470, 8, 580), Enum.Material.Water)
	for _, z in shell.zones do
		if z.kind ~= "fishing" and z.kind ~= "rareSite" then
			Terrain:FillBlock(CFrame.new(z.center.x, -3, z.center.z), Vector3.new(z.size.x+26, 10, z.size.z+26), Enum.Material.Mud)
			Terrain:FillBlock(CFrame.new(z.center.x, -2, z.center.z), Vector3.new(z.size.x+8, 12, z.size.z+8), Enum.Material.LeafyGrass)
		end
	end
	local cypress = ReplicatedStorage.WildWorldArt.Props:FindFirstChild("Cypress")
	local grove = freshFolder("WildWorldArt_Cypress")
	if cypress then
		local rng = Random.new(20260619)
		for _, c in ipairs({{24,12,22,4},{120,70,30,6},{-110,80,34,8},{60,110,30,5},{-60,20,26,4},{85,-10,28,4},{-40,135,28,5},{145,25,26,4},{5,185,22,3},{-125,15,24,4}}) do
			for _ = 1, c[4] do
				local a, d = rng:NextNumber(0,6.28), rng:NextNumber(3, c[3])
				local t = cypress:Clone(); t:ScaleTo(rng:NextNumber(0.8,1.4))
				t:PivotTo(CFrame.new(c[1]+math.cos(a)*d, -1, c[2]+math.sin(a)*d) * CFrame.Angles(0, rng:NextNumber(0,6.28), 0))
				t.Parent = grove
			end
		end
		Terrain:FillBall(Vector3.new(55,-1,110), 16, Enum.Material.LeafyGrass); Terrain:FillBall(Vector3.new(55,1.5,110), 11, Enum.Material.LeafyGrass)
		local hero = cypress:Clone(); hero.Name = "TheOldCypress"; hero:ScaleTo(2.4); hero:PivotTo(CFrame.new(55,1,110)*CFrame.Angles(0,math.rad(20),0)); hero.Parent = grove
	end
	-- reeds (procedural cattails ringing each zone)
	local reeds = freshFolder("WildWorldArt_Reeds"); local rng2 = Random.new(3312)
	local function clump(cx, cz)
		for _ = 1, rng2:NextInteger(6,13) do
			local a, d = rng2:NextNumber(0,6.28), rng2:NextNumber(0,2.6)
			local h = rng2:NextNumber(3.5,7)
			local s = box(reeds, "Reed", Vector3.new(0.22,h,0.22), Vector3.new(cx+math.cos(a)*d, h/2-0.5, cz+math.sin(a)*d), Color3.fromRGB(70+rng2:NextInteger(-4,6), 104+rng2:NextInteger(-15,22), 46+rng2:NextInteger(-3,4)), Enum.Material.Grass)
			s.CFrame = CFrame.new(s.Position) * CFrame.Angles(rng2:NextNumber(-0.18,0.18), rng2:NextNumber(0,6.28), rng2:NextNumber(-0.18,0.18))
			s.CanCollide, s.CanQuery, s.CastShadow = false, false, false
		end
	end
	for _, z in ipairs({{-45,-45,22,18},{0,-50,30,12},{24,12,20,10},{120,70,26,9},{0,255,22,8},{0,0,18,6},{-110,80,28,14}}) do
		for i = 1, z[4] do local a = (i/z[4])*6.28 + rng2:NextNumber(-0.3,0.3); local rr = z[3]+rng2:NextNumber(-6,8); clump(z[1]+math.cos(a)*rr, z[2]+math.sin(a)*rr) end
	end
	-- duckweed (muted dark algae clusters on still water, off the land)
	local duck = freshFolder("WildWorldArt_Duckweed"); local rng3 = Random.new(7731)
	local land = {{0,-50,52},{-45,-45,46},{0,0,34},{0,255,40}}
	local function onLand(x,z) for _,L in ipairs(land) do if (Vector2.new(x,z)-Vector2.new(L[1],L[2])).Magnitude < L[3] then return true end end return false end
	local mats = 0
	while mats < 26 do
		local cx, cz = rng3:NextNumber(-185,185), rng3:NextNumber(-70,330)
		if not onLand(cx,cz) then
			mats += 1
			for _ = 1, rng3:NextInteger(8,16) do
				local a, d = rng3:NextNumber(0,6.28), rng3:NextNumber(0, rng3:NextNumber(6,16))
				local x, z = cx+math.cos(a)*d, cz+math.sin(a)*d
				if not onLand(x,z) then
					local sz = rng3:NextNumber(4,11)
					local p = box(duck, "Algae", Vector3.new(sz,0.18,sz*rng3:NextNumber(0.7,1.3)), Vector3.new(x,0.08,z), Color3.fromRGB(58+rng3:NextInteger(-4,6),72+rng3:NextInteger(-10,14),44+rng3:NextInteger(-3,4)), Enum.Material.Mud)
					p.CFrame = CFrame.new(p.Position)*CFrame.Angles(0,rng3:NextNumber(0,6.28),0); p.CanCollide,p.CanQuery,p.CastShadow=false,false,false; p.Transparency=rng3:NextNumber(0.12,0.3)
				end
			end
		end
	end
	-- Ghost-Gator slough (pale gator + particle mist) + ambient dragonflies + wildlife
	M.buildBayouLife()
end

-- Bayou ambient life: Ghost Gator in the misty slough, open-water gator, rabbits/ducks/herons/turtles, dragonflies
function M.buildBayouLife()
	local creatures = ReplicatedStorage.WildWorldArt.Creatures
	local sf = freshFolder("WildWorldArt_Slough")
	local gtpl = creatures:FindFirstChild("Alligator")
	if gtpl then
		local ghost = gtpl:Clone(); ghost.Name = "GhostGator"; ghost:ScaleTo(1.15)
		for _, d in ipairs(ghost:GetDescendants()) do if d:IsA("MeshPart") then d.TextureID=""; d.Color=Color3.fromRGB(228,224,210) end end
		ghost:PivotTo(CFrame.new(-95,0,68)*CFrame.Angles(0,math.rad(150),0))
		local c, s = ghost:GetBoundingBox(); ghost:PivotTo(ghost:GetPivot()+Vector3.new(0,-0.5-(c.Position.Y-s.Y/2),0)); ghost.Parent = sf
	end
	local mrng = Random.new(22)
	for _ = 1, 9 do
		local a = box(sf, "MistAnchor", Vector3.new(2,2,2), Vector3.new(-110+mrng:NextNumber(-42,42), 2.5, 80+mrng:NextNumber(-38,38)), Color3.new(1,1,1)); a.Transparency=1; a.CanCollide,a.CanQuery=false,false
		local pe = Instance.new("ParticleEmitter", a)
		pe.Texture="rbxasset://textures/particles/smoke_main.dds"; pe.Color=ColorSequence.new(Color3.fromRGB(216,216,206))
		pe.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,16),NumberSequenceKeypoint.new(1,34)})
		pe.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.3,0.85),NumberSequenceKeypoint.new(0.75,0.88),NumberSequenceKeypoint.new(1,1)})
		pe.Rate=1.6; pe.Lifetime=NumberRange.new(9,15); pe.Speed=NumberRange.new(0.3,0.9); pe.SpreadAngle=Vector2.new(18,18); pe.LightInfluence=1; pe.RotSpeed=NumberRange.new(-3,3)
	end
	local wf = freshFolder("WildWorldArt_Wildlife"); local rng = Random.new(8080)
	if gtpl then -- open-water gator (set dressing)
		local og = placeCreature(creatures, "Alligator", wf, 48, 30, math.rad(-50))
		if og then local c,s=og:GetBoundingBox(); og:PivotTo(og:GetPivot()+Vector3.new(0,-0.45-(c.Position.Y-s.Y/2),0)) end
	end
	for i = 1, 3 do local x=-16+i*12+rng:NextNumber(-4,4); local z=-50+rng:NextNumber(-12,12); local r=placeCreature(creatures,"SwampRabbit",wf,x,z,rng:NextNumber(0,6.28)); if r then r:PivotTo(CFrame.new(x,4,z)*CFrame.Angles(0,rng:NextNumber(0,6.28),0)) end end
	for i = 1, 6 do local x=16+rng:NextNumber(-8,18); local z=8+rng:NextNumber(-10,14); local du=placeCreature(creatures,"WoodDuck",wf,x,z,rng:NextNumber(0,6.28)); if du then du:PivotTo(CFrame.new(x,0.2,z)*CFrame.Angles(0,rng:NextNumber(0,6.28),0)) end end
	placeCreature(creatures, "Heron", wf, -16, 34, math.rad(120)); placeCreature(creatures, "Heron", wf, 96, 92, math.rad(-60))
	placeCreature(creatures, "Turtle", wf, 8, -44, 1.2); placeCreature(creatures, "Turtle", wf, 118, 60, 2.5); placeCreature(creatures, "Turtle", wf, -40, -40, 0.3)
	-- dragonfly swarms over the water
	local amb = freshFolder("WildWorldArt_Ambient")
	for _, s in ipairs({{24,12},{120,70},{40,30},{-20,-18},{80,50},{-60,40},{10,80}}) do
		local a = box(amb, "Swarm", Vector3.new(1,1,1), Vector3.new(s[1],3.2,s[2]), Color3.new(1,1,1)); a.Transparency=1; a.CanCollide,a.CanQuery=false,false
		local pe = Instance.new("ParticleEmitter", a); pe.Color=ColorSequence.new(Color3.fromRGB(38,48,42)); pe.Size=NumberSequence.new(0.42); pe.Transparency=NumberSequence.new(0.1)
		pe.Rate=16; pe.Lifetime=NumberRange.new(2,4); pe.Speed=NumberRange.new(2,5); pe.SpreadAngle=Vector2.new(180,180); pe.Drag=2.5; pe.LightInfluence=1
	end
end

-- ── APPALACHIA (offset 2000): mountain terrain + conifer forest + deer herd + bears ──
function M.buildAppalachia()
	local OX = 2000
	pcall(function() Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(88,106,60)) end)
	pcall(function() Terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(80,100,54)) end)
	pcall(function() Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(98,94,86)) end)
	Terrain:FillBlock(CFrame.new(OX,-5,40), Vector3.new(380,12,500), Enum.Material.LeafyGrass)
	Terrain:FillBall(Vector3.new(OX,2,-130),48,Enum.Material.Rock); Terrain:FillBall(Vector3.new(OX,30,-130),26,Enum.Material.Rock); Terrain:FillBall(Vector3.new(OX,52,-130),12,Enum.Material.Slate)
	Terrain:FillBall(Vector3.new(OX-120,6,60),42,Enum.Material.LeafyGrass); Terrain:FillBall(Vector3.new(OX-120,22,60),22,Enum.Material.LeafyGrass); Terrain:FillBall(Vector3.new(OX+110,3,50),36,Enum.Material.LeafyGrass)
	Terrain:FillBlock(CFrame.new(OX-90,0,-80),Vector3.new(74,10,64),Enum.Material.Air); Terrain:FillBlock(CFrame.new(OX-90,-3,-80),Vector3.new(74,6,64),Enum.Material.Water)
	Terrain:FillBlock(CFrame.new(OX+100,0,-60),Vector3.new(64,10,44),Enum.Material.Air); Terrain:FillBlock(CFrame.new(OX+100,-3,-60),Vector3.new(64,6,44),Enum.Material.Water)
	local grove = freshFolder("WildWorldArt_AP_Forest")
	scatterTrees(poolFrom(ReplicatedStorage.WildWorldArt.Props:FindFirstChild("Forest")), OX,
		{{-120,60,32,16},{-90,95,26,8},{0,80,42,10},{110,50,30,10},{60,125,28,8},{-40,-45,30,9},{45,-65,26,7},{-135,-25,24,7},{0,-180,30,10}},
		grove, { seed = 2026, minH = 24, maxH = 42 })
	local creatures = ReplicatedStorage.WildWorldArt.Creatures
	local wf = freshFolder("WildWorldArt_AP_Wildlife"); local rng = Random.new(77)
	for i = 1, 4 do placeCreature(creatures, "Deer", wf, OX-20+i*12+rng:NextNumber(-6,6), 80+rng:NextNumber(-15,15), rng:NextNumber(0,6.28)) end
	placeCreature(creatures, "Bear", wf, OX+100, 55, math.rad(220)); placeCreature(creatures, "Bear", wf, OX-100, 40, math.rad(60))
end

-- ── ALASKA (offset 4000): snowy tundra + glacier + frozen lake + coastal water + frosted spruce + moose/caribou/grizzly ──
function M.buildAlaska()
	local OX = 4000
	pcall(function() Terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(238,242,250)) end)
	pcall(function() Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(116,118,128)) end)
	pcall(function() Terrain:SetMaterialColor(Enum.Material.Glacier, Color3.fromRGB(198,220,238)) end)
	Terrain:FillBlock(CFrame.new(OX+25,-5,-35), Vector3.new(430,12,500), Enum.Material.Snow)
	Terrain:FillBlock(CFrame.new(OX,18,-250), Vector3.new(120,56,70), Enum.Material.Glacier)
	Terrain:FillBall(Vector3.new(OX,50,-250),34,Enum.Material.Glacier); Terrain:FillBall(Vector3.new(OX-32,38,-244),22,Enum.Material.Glacier); Terrain:FillBall(Vector3.new(OX+36,42,-256),24,Enum.Material.Glacier)
	Terrain:FillBall(Vector3.new(OX+90,6,-70),40,Enum.Material.Rock); Terrain:FillBall(Vector3.new(OX+90,34,-70),22,Enum.Material.Rock); Terrain:FillBall(Vector3.new(OX+78,22,-58),16,Enum.Material.Rock)
	Terrain:FillBall(Vector3.new(OX-110,5,30),38,Enum.Material.Snow)
	Terrain:FillBlock(CFrame.new(OX+60,0,-50),Vector3.new(40,10,92),Enum.Material.Air); Terrain:FillBlock(CFrame.new(OX+60,-3,-50),Vector3.new(40,6,92),Enum.Material.Water)
	Terrain:FillBlock(CFrame.new(OX+175,0,-165),Vector3.new(190,10,190),Enum.Material.Air); Terrain:FillBlock(CFrame.new(OX+175,-3,-165),Vector3.new(190,6,190),Enum.Material.Water)
	Terrain:FillBlock(CFrame.new(OX-150,0,-160),Vector3.new(82,10,82),Enum.Material.Air); Terrain:FillBlock(CFrame.new(OX-150,0.5,-160),Vector3.new(82,3,82),Enum.Material.Glacier)
	Terrain:FillBall(Vector3.new(OX-60,3,-90),26,Enum.Material.Rock); Terrain:FillBlock(CFrame.new(OX-60,-2,-78),Vector3.new(30,6,42),Enum.Material.Water)
	local grove = freshFolder("WildWorldArt_AK_Forest")
	scatterTrees(poolFrom(ReplicatedStorage.WildWorldArt.Props:FindFirstChild("Forest")), OX,
		{{-110,30,34,16},{-70,60,26,8},{-40,20,28,8},{20,45,30,8},{-58,-88,22,7},{45,85,26,7}},
		grove, { seed = 404, minH = 22, maxH = 38, frost = true })
	local creatures = ReplicatedStorage.WildWorldArt.Creatures
	local wf = freshFolder("WildWorldArt_AK_Wildlife"); local rng = Random.new(900)
	placeCreature(creatures, "Moose", wf, OX-110, 35, math.rad(40)); placeCreature(creatures, "Moose", wf, OX-92, 16, math.rad(-100))
	for i = 1, 5 do placeCreature(creatures, "Deer", wf, OX-30+i*14+rng:NextNumber(-6,6), 50+rng:NextNumber(-18,18), rng:NextNumber(0,6.28), Color3.fromRGB(150,140,128)) end
	placeCreature(creatures, "Grizzly", wf, OX-60, -82, math.rad(150)); placeCreature(creatures, "Grizzly", wf, OX-50, -96, math.rad(20))
end

-- ── LODGE (0,0,600): enclosed log cabin + hearth + warm light rig + service stations + trophy wall ──
function M.buildLodge()
	local CX, CZ = 0, 600
	local lf = freshFolder("WildWorldArt_Lodge")
	local function lbox(n, s, p, c, m) return box(lf, n, s, p, c, m) end
	local WOOD, PLANK, STONE, BEAM, BRASS = Color3.fromRGB(88,68,50), Color3.fromRGB(84,58,38), Color3.fromRGB(96,96,102), Color3.fromRGB(62,42,26), Color3.fromRGB(196,160,82)
	lbox("Floor", Vector3.new(86,1,86), Vector3.new(CX,-0.5,CZ), PLANK, Enum.Material.WoodPlanks)
	lbox("WallN", Vector3.new(86,22,2), Vector3.new(CX,11,CZ+42), WOOD, Enum.Material.Wood)
	lbox("WallE", Vector3.new(2,22,86), Vector3.new(CX+42,11,CZ), WOOD, Enum.Material.Wood)
	lbox("WallW", Vector3.new(2,22,86), Vector3.new(CX-42,11,CZ), WOOD, Enum.Material.Wood)
	lbox("WallS1", Vector3.new(35,22,2), Vector3.new(CX-25,11,CZ-42), WOOD, Enum.Material.Wood)
	lbox("WallS2", Vector3.new(35,22,2), Vector3.new(CX+25,11,CZ-42), WOOD, Enum.Material.Wood)
	lbox("Lintel", Vector3.new(16,6,2), Vector3.new(CX,19,CZ-42), WOOD, Enum.Material.Wood)
	lbox("Ceiling", Vector3.new(86,1,86), Vector3.new(CX,22.5,CZ), Color3.fromRGB(74,56,40), Enum.Material.Wood)
	for i = -2, 2 do lbox("Beam"..i, Vector3.new(86,1.6,1.6), Vector3.new(CX,21,CZ+i*16), BEAM, Enum.Material.Wood) end
	for _, c in ipairs({{-40,-40},{40,-40},{-40,40},{40,40}}) do lbox("Post", Vector3.new(2.6,22,2.6), Vector3.new(CX+c[1],11,CZ+c[2]), BEAM, Enum.Material.Wood) end
	lbox("Hearth", Vector3.new(18,16,5), Vector3.new(CX,8,CZ+40), STONE, Enum.Material.Slate)
	lbox("Chimney", Vector3.new(8,20,5), Vector3.new(CX,25,CZ+41), STONE, Enum.Material.Slate)
	lbox("Firebox", Vector3.new(10,8,3), Vector3.new(CX,5,CZ+38.5), Color3.fromRGB(18,14,10), Enum.Material.Slate)
	local logs = lbox("HearthLogs", Vector3.new(6,2,2.4), Vector3.new(CX,2.5,CZ+38.5), Color3.fromRGB(70,46,28), Enum.Material.Wood)
	local fire = Instance.new("Fire", logs); fire.Heat=10; fire.Size=7; fire.Color=Color3.fromRGB(255,150,60); fire.SecondaryColor=Color3.fromRGB(255,90,30)
	local hl = Instance.new("PointLight", logs); hl.Color=Color3.fromRGB(255,170,90); hl.Brightness=5; hl.Range=32; hl.Shadows=true
	local function plight(pos, b, r) local a=lbox("Lt", Vector3.new(0.4,0.4,0.4), pos, Color3.fromRGB(255,240,214)); a.Transparency=1; local l=Instance.new("PointLight",a); l.Color=Color3.fromRGB(255,240,214); l.Brightness=b; l.Range=r end
	plight(Vector3.new(CX-18,17,CZ-8), 0.9, 38); plight(Vector3.new(CX+18,17,CZ-8), 0.9, 38); plight(Vector3.new(CX,12,CZ), 0.65, 38); plight(Vector3.new(CX,6,CZ-36), 0.5, 26)
	-- service stations (counters + brass trim + signs)
	local function station(label, x, z)
		lbox(label.."_C", Vector3.new(9,4,3), Vector3.new(x,2,z), WOOD, Enum.Material.Wood)
		lbox(label.."_T", Vector3.new(9.3,0.4,3.3), Vector3.new(x,4.2,z), BRASS, Enum.Material.Metal)
		local sa=lbox(label.."_S", Vector3.new(0.4,0.4,0.4), Vector3.new(x,7.5,z), WOOD); sa.Transparency=1
		local bg=Instance.new("BillboardGui",sa); bg.Size=UDim2.fromOffset(190,38); bg.MaxDistance=130; bg.LightInfluence=0
		local t=Instance.new("TextLabel",bg); t.Size=UDim2.fromScale(1,1); t.BackgroundTransparency=1; t.Font=Enum.Font.GothamBold; t.TextSize=22; t.TextColor3=Color3.fromRGB(255,226,172); t.TextStrokeTransparency=0.3; t.Text=label
		local la=lbox(label.."_L", Vector3.new(0.3,0.3,0.3), Vector3.new(x,6,z), BRASS); la.Transparency=1; local l=Instance.new("PointLight",la); l.Color=Color3.fromRGB(255,224,180); l.Brightness=1.1; l.Range=15
	end
	station("OUTFITTER",-34,582); station("TACKLE SHOP",-34,602); station("KENNEL & STABLE",-34,622)
	station("TRAVEL DESK",34,582); station("TRADING POST",34,602); station("BOAT DEALER",34,622)
	lbox("Rug", Vector3.new(22,0.2,15), Vector3.new(0,0.16,614), Color3.fromRGB(122,54,42), Enum.Material.Fabric)
	lbox("Bench1", Vector3.new(11,1.4,2.6), Vector3.new(-10,1,614), Color3.fromRGB(76,50,32), Enum.Material.Wood)
	lbox("Bench2", Vector3.new(11,1.4,2.6), Vector3.new(10,1,614), Color3.fromRGB(76,50,32), Enum.Material.Wood)
	lbox("Table", Vector3.new(7,1.2,4.5), Vector3.new(0,1.1,614), Color3.fromRGB(68,46,28), Enum.Material.Wood)
	-- trophy wall (mounts flanking the hearth, rarity-framed)
	local creatures = ReplicatedStorage.WildWorldArt.Creatures
	local function trophy(x, frameColor, tplName, scale, yaw, spotB, spotColor)
		lbox("TFrame", Vector3.new(8,9,0.5), Vector3.new(x,11,639.7), frameColor, Enum.Material.Metal)
		lbox("TPanel", Vector3.new(6.6,7.6,0.4), Vector3.new(x,11,639.4), Color3.fromRGB(44,30,18), Enum.Material.Wood)
		if tplName and creatures:FindFirstChild(tplName) then
			local m = creatures[tplName]:Clone(); if scale then m:ScaleTo(scale) end
			m:PivotTo(CFrame.new(x,11,636.7)*CFrame.Angles(0,yaw,0)); m.Parent = lf
		end
		if spotB then local a=lbox("TSpot", Vector3.new(0.3,0.3,0.3), Vector3.new(x,15.5,634.5), spotColor); a.Transparency=1; local l=Instance.new("SpotLight",a); l.Color=spotColor; l.Brightness=spotB; l.Range=20; l.Angle=55; l.Face=Enum.NormalId.Bottom end
	end
	trophy(-30, Color3.fromRGB(216,180,100), "Leviathan", 0.72, math.rad(90), 5, Color3.fromRGB(255,224,150))
	trophy(-16, Color3.fromRGB(196,160,82), "Alligator", 0.8, math.rad(90), 2.4, Color3.fromRGB(255,238,202))
	trophy(16, Color3.fromRGB(74,74,82), "WoodDuck", nil, math.rad(180), nil, nil)
	trophy(30, Color3.fromRGB(60,60,66), nil)
end

-- ── AMBIENT SOUNDSCAPE: positional looping Sounds per world (Linear rolloff keeps each biome local + fading
-- out before the next world 2000 studs away; the Lodge fire stays tight to the hearth). Free Pro Sound FX. ──
function M.buildSoundscape()
	local snd = ArtAssets.sound; if not snd then return end
	local f = freshFolder("WildWorldArt_Sound")
	local function emit(name, pos, id, vol, minD, maxD)
		if not id then return end
		local p = box(f, name, Vector3.new(1,1,1), pos, Color3.new(1,1,1))
		p.Transparency, p.CanCollide, p.CanQuery = 1, false, false
		local s = Instance.new("Sound"); s.SoundId = "rbxassetid://"..id; s.Looped = true; s.Volume = vol
		s.RollOffMinDistance, s.RollOffMaxDistance, s.RollOffMode = minD, maxD, Enum.RollOffMode.Linear
		s.Playing = true; s.Parent = p
	end
	emit("BayouFrogs1", Vector3.new(0,5,10), snd.bayouFrogs, 0.5, 60, 420)
	emit("BayouFrogs2", Vector3.new(40,5,130), snd.bayouFrogs, 0.45, 60, 420)
	emit("AppalachiaWoods", Vector3.new(2000,20,40), snd.appalachiaWoods, 0.45, 80, 720)
	emit("AlaskaWind", Vector3.new(4000,18,-35), snd.alaskaWind, 0.42, 100, 950)
	emit("LodgeFire", Vector3.new(0,4,639), snd.lodgeFire, 0.6, 8, 55)
end

-- ── Suppress WorldServer's RUNTIME placeholder boxes (rebuilt every session) so the baked art shows cleanly.
-- Waits out the spawn-order race, keeps SpawnLocations + a walkable invisible ground floor, leaves fixtures
-- present (transparent) for gameplay clicks, re-hides late-added children. Runs EVERY session (not Built-gated).
function M.suppressPlaceholders()
	local function hide(f)
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("BasePart") and not d:IsA("SpawnLocation") then
				d.Transparency = 1
				if d.Name ~= "Ground" then d.CanCollide = false end
			end
		end
	end
	task.spawn(function()
		for _, name in ipairs({ "BayouShell_Placeholder", "AppalachiaShell_Placeholder", "AlaskaShell_Placeholder", "Lodge_Placeholder" }) do
			local f = workspace:WaitForChild(name, 30)
			if f then
				hide(f)
				f.DescendantAdded:Connect(function(d)
					if d:IsA("BasePart") and not d:IsA("SpawnLocation") then
						d.Transparency = 1
						if d.Name ~= "Ground" then d.CanCollide = false end
					end
				end)
			end
		end
	end)
end

-- orchestrates the full reproducible build (idempotent; called once from the gate when not already built)
function M.buildAllWorlds()
	M.ensureTemplates()
	pcall(M.buildBayou); pcall(M.buildAppalachia); pcall(M.buildAlaska); pcall(M.buildLodge); pcall(M.buildSoundscape)
end

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- C1/C2: IN-PLACE creature visual upgrade + cosmetic idle loop (the decoupled gameplay seam).
-- WorldServer spawns coarse BOX creatures into workspace.HuntingTargets with PrimaryPart + the
-- maxHealth/currentHealth/targetId/creatureId attrs + hitZone-tagged CanQuery parts. We DON'T edit that.
-- On ChildAdded we UPGRADE each model IN PLACE: keep the box parts as INVISIBLE hitboxes (Transparency=1,
-- CanQuery untouched → the fire raycast + headshot zones still work EXACTLY), and overlay the real mesh
-- (RS.WildWorldArt.Creatures) welded to a VisualRoot Motor6D on the PrimaryPart so it rides gameplay
-- movement. WorldServer's playDeath (fades all BaseParts + tips the model) still works on the visual.
-- Cosmetic idle = one Heartbeat loop swaying each VisualRoot's Motor6D (whole-body breathing/bob,
-- per-instance phase), reading PrimaryPart, never setting world position (locomotion stays gameplay's job).
-- ⚠ NEEDS A PLAY TEST (HuntingTargets only exist at runtime). Gated dormant by the attribute below.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local CREATURE_MAP = {
	bayou_american_alligator = "Alligator",
	bayou_white_alligator = "Alligator",      -- Ghost Gator (pale reskin)
	bayou_swamp_rabbit = "SwampRabbit",
	bayou_nutria = "SwampRabbit",             -- fallback reuse until a nutria mesh lands
	bayou_wood_duck = "WoodDuck",
	bayou_leucistic_wood_duck = "WoodDuck",   -- Pale Drake (pale reskin)
	bayou_great_egret = "Heron",
	bayou_painted_turtle = "Turtle",
	bayou_songbird = "WoodDuck",              -- fallback small bird
}
local PALE_RESKIN = { bayou_white_alligator = true, bayou_leucistic_wood_duck = true }

local function creaturesFolder()
	local root = ReplicatedStorage:FindFirstChild("WildWorldArt")
	return root and root:FindFirstChild("Creatures")
end

function M.upgradeCreature(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return end
	if model:GetAttribute("artUpgraded") then return end
	local cid = model:GetAttribute("creatureId")
	local pp = model.PrimaryPart
	local folder = creaturesFolder()
	if cid == nil or pp == nil or folder == nil then return end
	local tpl = folder:FindFirstChild(CREATURE_MAP[cid] or "")
	if tpl == nil then return end -- graceful: unknown creature keeps its box visuals
	model:SetAttribute("artUpgraded", true)

	-- 1) hide the box visuals but KEEP them as invisible hitboxes (zones/raycast unchanged)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.Transparency = 1 end
	end
	-- 2) a VisualRoot driven by a Motor6D off the PrimaryPart (the cosmetic-anim handle)
	local root = Instance.new("Part")
	root.Name = "ArtVisualRoot"; root.Size = Vector3.new(0.2, 0.2, 0.2); root.Transparency = 1
	root.CanCollide = false; root.CanQuery = false; root.Massless = true; root.Anchored = false
	root.CFrame = pp.CFrame; root.Parent = model
	local motor = Instance.new("Motor6D")
	motor.Name = "ArtVisualMotor"; motor.Part0 = pp; motor.Part1 = root; motor.Parent = pp
	-- 3) the visual mesh, scaled to the box silhouette, welded rigidly to the VisualRoot
	local visual = tpl:Clone(); visual.Name = "ArtVisual"
	local _, boxSize = model:GetBoundingBox()
	local _, tplSize = visual:GetBoundingBox()
	local factor = math.max(boxSize.X, boxSize.Z) / math.max(tplSize.X, tplSize.Z, 0.1)
	pcall(function() visual:ScaleTo(visual:GetScale() * factor) end)
	visual:PivotTo(root.CFrame)
	for _, d in ipairs(visual:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false; d.CanCollide = false; d.CanQuery = false; d.Massless = true
			local w = Instance.new("Weld"); w.Part0 = root; w.Part1 = d
			w.C0 = root.CFrame:ToObjectSpace(d.CFrame); w.Parent = d
		end
	end
	if PALE_RESKIN[cid] then
		for _, d in ipairs(visual:GetDescendants()) do
			if d:IsA("MeshPart") then d.TextureID = ""; d.Color = Color3.fromRGB(228, 224, 210) end
		end
	end
	visual.Parent = model
	M.animated[model] = { motor = motor, phase = math.random() * 6.28 }
end

function M.startCreatureUpgrades()
	-- WaitForChild handles the WorldArt-vs-WorldServer spawn-order race (the folders are created by
	-- WorldServer; we may boot first). Every upgrade is pcall-wrapped so one bad creature can't break the
	-- listener (it just stays a box — graceful degrade). Validated in-game via inline run (2026-06-19).
	task.spawn(function()
		for _, folderName in ipairs({ "HuntingTargets", "FishingBites" }) do
			local f = workspace:WaitForChild(folderName, 30)
			if f then
				for _, m in ipairs(f:GetChildren()) do
					task.spawn(function() pcall(M.upgradeCreature, m) end)
				end
				f.ChildAdded:Connect(function(m) task.defer(function() pcall(M.upgradeCreature, m) end) end)
				f.ChildRemoved:Connect(function(m) M.animated[m] = nil end)
			end
		end
	end)
end

function M.startCosmeticLoop()
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for model, a in pairs(M.animated) do
			if a.motor and a.motor.Parent then
				local bob = math.sin(t * 1.6 + a.phase) * 0.12          -- gentle vertical breathing
				local sway = math.sin(t * 0.9 + a.phase) * math.rad(2.2) -- subtle yaw sway
				a.motor.C0 = CFrame.new(0, bob, 0) * CFrame.Angles(0, sway, 0)
			else
				M.animated[model] = nil
			end
		end
	end)
end

-- ── DORMANT BY DEFAULT. Runs ONLY when opted in (workspace attribute "WildWorldArt" == true), so this
-- script never alters a session uninvited (esp. the gameplay terminal's playtests). The static look/terrain/
-- sky/props/lodge are baked into the place regardless; this gated path is the reproducible rebuild + the
-- live creature upgrade. To test: set workspace:SetAttribute("WildWorldArt", true) and Play.
if workspace:GetAttribute("WildWorldArt") == true then
	pcall(M.applyGlobalLook) -- cheap; always (re)apply the look
	pcall(M.suppressPlaceholders) -- every session: hide WorldServer's placeholder boxes so the baked art shows
	-- the heavy world build runs ONCE per place: a fresh place builds + sets the marker; a saved/baked place
	-- (marker present, or content already saved) skips it. Set workspace attr "WildWorldArt_Rebuild"=true to
	-- force a from-scratch rebuild (clears + re-sculpts everything from the manifest).
	if workspace:GetAttribute("WildWorldArt_Built") ~= true or workspace:GetAttribute("WildWorldArt_Rebuild") == true then
		task.spawn(function()
			M.buildAllWorlds()
			workspace:SetAttribute("WildWorldArt_Built", true)
			workspace:SetAttribute("WildWorldArt_Rebuild", false)
			print("[WildWorldArt] world build complete (reproducible-from-code path)")
		end)
	end
	M.startCreatureUpgrades()
	M.startCosmeticLoop()
	print("[WildWorldArt] ACTIVE — look + reproducible build + creature upgrade + cosmetic loop (opted in)")
else
	print(("[WildWorldArt] online — manifest v%d (dormant; set workspace attr 'WildWorldArt'=true to activate)"):format(ArtAssets.version))
end
