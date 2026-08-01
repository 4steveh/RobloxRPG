--!nonstrict
-- STUDIO-ONLY ModuleScript. WHAT A SHOT LOOKS AND SOUNDS LIKE WHERE IT LANDS.
--
-- Before this, a shot produced a tracer that simply stopped: no dust, no splash, no reaction from the animal,
-- and the only hit confirmation was the aim highlight's outline briefly turning red plus a text toast reading
-- "hit 12". The bullet had no consequence at the point of contact, which is the single place a player is
-- looking when they pull the trigger.
--
-- Everything here is CLIENT-PREDICTED and fired the instant the trigger goes down, from the same aim ray the
-- server will use. Impact must be instantaneous — waiting for the round trip makes a hit feel like lag. The
-- server still owns the OUTCOME (damage, kill, payout); this owns only the sensation.
--
-- Material-keyed, because a round into swamp water, into a cypress trunk and into a gator have nothing in
-- common. The material comes from the raycast result, so it is free and always correct.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local M = {}

-- Engine-bundled sounds only (rbxasset://) — they resolve locally with no CDN fetch, so they cannot fail on
-- a cold client the way an uploaded asset id can.
local SOUND = {
	dirt = "rbxasset://sounds/action_falling.mp3",
	water = "rbxasset://sounds/impact_water.mp3",
	stone = "rbxasset://sounds/impact_generic.mp3",
	wood = "rbxasset://sounds/impact_generic.mp3",
	flesh = "rbxasset://sounds/impact_generic.mp3",
	snow = "rbxasset://sounds/action_falling.mp3",
}

-- One row per impact class: the debris colour range, particle colour, and how much the camera should feel it.
local CLASS = {
	dirt = { colors = { Color3.fromRGB(96, 78, 54), Color3.fromRGB(120, 100, 70) }, puff = Color3.fromRGB(146, 128, 98), shake = 0.10, chips = 5 },
	grass = { colors = { Color3.fromRGB(84, 104, 52), Color3.fromRGB(112, 132, 68) }, puff = Color3.fromRGB(132, 144, 96), shake = 0.10, chips = 6 },
	water = { colors = { Color3.fromRGB(176, 200, 200), Color3.fromRGB(210, 226, 226) }, puff = Color3.fromRGB(224, 236, 238), shake = 0.08, chips = 7 },
	stone = { colors = { Color3.fromRGB(112, 110, 104), Color3.fromRGB(146, 144, 136) }, puff = Color3.fromRGB(178, 176, 168), shake = 0.16, chips = 6 },
	wood = { colors = { Color3.fromRGB(96, 72, 50), Color3.fromRGB(132, 102, 70) }, puff = Color3.fromRGB(150, 126, 96), shake = 0.13, chips = 6 },
	snow = { colors = { Color3.fromRGB(226, 232, 240), Color3.fromRGB(246, 250, 255) }, puff = Color3.fromRGB(250, 252, 255), shake = 0.07, chips = 7 },
	flesh = { colors = { Color3.fromRGB(128, 40, 34), Color3.fromRGB(88, 26, 22) }, puff = Color3.fromRGB(120, 38, 32), shake = 0.22, chips = 8 },
}

-- Roblox material -> impact class. Terrain reports its own materials, so this covers both parts and ground.
local MATERIAL_CLASS = {
	Grass = "grass",
	LeafyGrass = "grass",
	Ground = "dirt",
	Mud = "dirt",
	Sand = "dirt",
	Sandstone = "dirt",
	Rock = "stone",
	Slate = "stone",
	Basalt = "stone",
	Limestone = "stone",
	Concrete = "stone",
	Cobblestone = "stone",
	Brick = "stone",
	Marble = "stone",
	Pebble = "stone",
	Wood = "wood",
	WoodPlanks = "wood",
	Snow = "snow",
	Glacier = "snow",
	Ice = "snow",
	Water = "water",
	Fabric = "flesh",
	Leather = "flesh",
}

local function playAt(class, position)
	local id = SOUND[class]
	if id == nil then
		return
	end
	pcall(function()
		local anchor = Instance.new("Part")
		anchor.Anchored, anchor.Transparency, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch =
			true, 1, false, false, false
		anchor.Size = Vector3.one
		anchor.CFrame = CFrame.new(position)
		anchor.Parent = workspace
		local snd = Instance.new("Sound")
		snd.SoundId = id
		snd.Volume = if class == "flesh" then 0.7 else 0.45
		snd.PlaybackSpeed = 0.9 + math.random() * 0.35
		snd.RollOffMaxDistance = 180
		snd.Parent = anchor
		snd:Play()
		Debris:AddItem(anchor, 2.5)
	end)
end

-- The impact burst: a cone of small debris chips thrown along the surface normal, plus an expanding puff.
-- Chips are ANCHORED and tweened rather than physics-driven — a dozen unanchored parts per shot would put
-- real bodies into the physics solver for something on screen for 400 ms.
function M.burst(position, normal, material, opts)
	opts = opts or {}
	local class = opts.class or MATERIAL_CLASS[tostring(material)] or "dirt"
	local spec = CLASS[class] or CLASS.dirt
	local n = (normal or Vector3.yAxis)
	if n.Magnitude < 1e-3 then
		n = Vector3.yAxis
	end
	n = n.Unit
	local scale = opts.scale or 1

	-- expanding puff: one neon-free sphere that grows and fades
	local puff = Instance.new("Part")
	puff.Shape = Enum.PartType.Ball
	puff.Anchored, puff.CanCollide, puff.CanQuery, puff.CanTouch = true, false, false, false
	puff.Material = Enum.Material.SmoothPlastic
	puff.Color = spec.puff
	puff.Transparency = 0.35
	puff.CastShadow = false
	puff.Size = Vector3.one * 0.6 * scale
	puff.CFrame = CFrame.new(position + n * 0.3)
	puff.Parent = workspace
	TweenService:Create(puff, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 4.2 * scale,
		Transparency = 1,
	}):Play()
	Debris:AddItem(puff, 0.4)

	-- water gets a vertical column instead of a lateral cone: a splash goes UP
	local spreadAxis = if class == "water" then Vector3.yAxis else n

	for i = 1, spec.chips do
		local chip = Instance.new("Part")
		chip.Anchored, chip.CanCollide, chip.CanQuery, chip.CanTouch = true, false, false, false
		chip.CastShadow = false
		chip.Material = if class == "water" then Enum.Material.SmoothPlastic else Enum.Material.Slate
		chip.Color = spec.colors[(i % #spec.colors) + 1]
		local s = (0.14 + math.random() * 0.2) * scale
		chip.Size = Vector3.new(s, s * (0.6 + math.random()), s)
		chip.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6.28, math.random() * 6.28, 0)
		chip.Parent = workspace
		-- scatter within a cone around the surface normal
		local az = math.random() * math.pi * 2
		local perp = spreadAxis:Cross(if math.abs(spreadAxis.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis).Unit
		local perp2 = spreadAxis:Cross(perp).Unit
		local lateral = (perp * math.cos(az) + perp2 * math.sin(az)) * (0.5 + math.random() * 1.6) * scale
		local travel = spreadAxis * (1.4 + math.random() * 2.6) * scale + lateral
		TweenService:Create(chip, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = chip.CFrame + travel + Vector3.new(0, -0.7 * scale, 0),
			Transparency = 1,
		}):Play()
		Debris:AddItem(chip, 0.5)
	end

	playAt(class, position)
	return spec.shake * scale
end

-- ── creature flinch ───────────────────────────────────────────────────────────────────────────────────
-- A Highlight rather than per-part recolouring: a creature carries 20-50 visual parts, and saving and
-- restoring every Color3 per hit is both slower and a state-corruption risk if two hits overlap. One
-- Highlight is a single instance with a single animated property, and it reads more clearly at distance.

local flinch = Instance.new("Highlight")
flinch.FillColor = Color3.fromRGB(255, 120, 96)
flinch.OutlineColor = Color3.fromRGB(255, 190, 170)
flinch.FillTransparency = 1
flinch.OutlineTransparency = 1
flinch.DepthMode = Enum.HighlightDepthMode.Occluded
flinch.Enabled = false
flinch.Parent = workspace

local flinchToken = 0

function M.flinch(model, lethal)
	if model == nil or model.Parent == nil then
		return
	end
	flinchToken += 1
	local token = flinchToken
	flinch.Adornee = model
	flinch.Enabled = true
	flinch.FillTransparency = if lethal then 0.25 else 0.55
	flinch.OutlineTransparency = 0
	TweenService:Create(flinch, TweenInfo.new(if lethal then 0.42 else 0.2), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	}):Play()
	task.delay(if lethal then 0.45 else 0.24, function()
		-- only the most recent flinch may turn the highlight off, or a fast second hit would cancel itself
		if flinchToken == token then
			flinch.Enabled = false
			flinch.Adornee = nil
		end
	end)
end

-- ── floating damage number ────────────────────────────────────────────────────────────────────────────
-- Replaces `Hud.toast("hit 12")`. A number at the point of contact tells the player WHERE they hit as well
-- as how hard, which a corner toast cannot; and it scales and colours by severity so a headshot reads
-- differently from a graze without needing to be labelled.

function M.damageNumber(position, amount, isVital)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.Transparency, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch =
		true, 1, false, false, false
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0))
	anchor.Parent = workspace

	local bg = Instance.new("BillboardGui")
	bg.Size = UDim2.fromOffset(150, 44)
	bg.AlwaysOnTop = true
	bg.MaxDistance = 260
	bg.Adornee = anchor
	bg.Parent = anchor

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextSize = if isVital then 30 else 22
	lbl.TextColor3 = if isVital then Color3.fromRGB(255, 226, 128) else Color3.fromRGB(255, 244, 236)
	lbl.TextStrokeColor3 = Color3.fromRGB(24, 14, 10)
	lbl.TextStrokeTransparency = 0.15
	lbl.Text = if isVital then ("%d!"):format(amount) else tostring(amount)
	lbl.Parent = bg

	-- drift up and slightly aside so two numbers in quick succession do not overlap into mush
	local drift = Vector3.new((math.random() - 0.5) * 1.6, 3.4, (math.random() - 0.5) * 1.6)
	TweenService:Create(anchor, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = anchor.CFrame + drift,
	}):Play()
	TweenService:Create(lbl, TweenInfo.new(0.85), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.95)
end

-- Classify a raycast result: a creature hitbox is Fabric/Leather by material, but the reliable signal is
-- that its ancestor Model sits under HuntingTargets and carries a hitZone attribute.
function M.classify(result)
	if result == nil then
		return nil
	end
	local inst = result.Instance
	local model = inst and inst:FindFirstAncestorOfClass("Model")
	local isCreature = model ~= nil and model.Parent ~= nil and model.Parent.Name == "HuntingTargets"
	local zone = inst and inst:GetAttribute("hitZone")
	return {
		position = result.Position,
		normal = result.Normal,
		material = result.Material,
		model = if isCreature then model else nil,
		zone = zone,
		class = if isCreature then "flesh" else nil,
	}
end

function M.localPlayer()
	return player
end

return M
