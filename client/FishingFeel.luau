--!nonstrict
-- STUDIO-ONLY ModuleScript (required by FishingController — a .client LocalScript cannot be required).
-- Fishing game-feel: a held rod (mode-swapped with the rifle), the cast line + bobber + splash, the bite
-- jerk, the reel-in pull, and the landed-fish reveal + float. All procedural; self-cleaning via Debris.
-- No RemoteEvents — driven by FishingController's existing cast/bite/fight/landed flow. The ambient bite
-- spawn-balls are hidden locally so only the cast bobber shows.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

local M = {}

-- ── sound (best-effort): engine-bundled rbxasset:// (load locally, no CDN); silent on failure ────────
local SOUNDS = {
	cast = "rbxasset://sounds/impact_water.mp3",
	reel = "rbxasset://sounds/clickfast.wav",
	land = "rbxasset://sounds/impact_water.mp3",
	cash = "rbxasset://sounds/electronicpingshort.wav",
}
local function playSound(key, volume)
	local id = SOUNDS[key]
	if id == nil then
		return
	end
	pcall(function()
		local snd = Instance.new("Sound")
		snd.SoundId = id
		snd.Volume = volume or 0.5
		snd.Parent = SoundService
		snd:Play()
		Debris:AddItem(snd, 5)
	end)
end

-- ── the held rod (built per character; hidden until fishing) ──────────────────────────────────────────
local rodModel = nil

local function buildRod(char)
	if char:FindFirstChild("HeldRod") then
		rodModel = char.HeldRod
		return
	end
	local hand = char:FindFirstChild("RightHand") or char:WaitForChild("RightHand", 8) or char:FindFirstChild("Right Arm")
	if hand == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = "HeldRod"
	local function part(name, size, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.Material = Enum.Material.SmoothPlastic
		p.LocalTransparencyModifier = 1 -- hidden until fishing
		p.Parent = model
		return p
	end
	local handle = part("Handle", Vector3.new(0.22, 0.22, 0.9), Color3.fromRGB(60, 40, 28))
	local shaft = part("Shaft", Vector3.new(0.1, 0.1, 4.2), Color3.fromRGB(150, 120, 70))
	model.PrimaryPart = handle
	local base = hand.CFrame * CFrame.new(0, -0.1, -0.7) * CFrame.Angles(math.rad(-35), 0, 0)
	handle.CFrame = base
	shaft.CFrame = base * CFrame.new(0, 0, -2.4)
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			local w = Instance.new("Weld")
			w.Part0 = hand
			w.Part1 = p
			w.C0 = hand.CFrame:ToObjectSpace(p.CFrame)
			w.Parent = p
		end
	end
	local tip = Instance.new("Attachment")
	tip.Name = "RodTip"
	tip.Position = Vector3.new(0, 0, -2.1)
	tip.Parent = shaft
	model.Parent = char
	rodModel = model
end

local function setModelHidden(model, hidden)
	if model then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = hidden and 1 or 0
			end
		end
	end
end

function M.enterFishing()
	setModelHidden(rodModel, false)
	local char = player.Character
	setModelHidden(char and char:FindFirstChild("HeldRifle"), true)
end

function M.exitFishing()
	setModelHidden(rodModel, true)
	local char = player.Character
	setModelHidden(char and char:FindFirstChild("HeldRifle"), false)
end

-- ── tackle state + helpers ───────────────────────────────────────────────────────────────────────────
local activeBobber, activeLine, activeFish = nil, nil, nil

local function rodTip()
	local char = player.Character
	local rod = char and char:FindFirstChild("HeldRod")
	local shaft = rod and rod:FindFirstChild("Shaft")
	return shaft and shaft:FindFirstChild("RodTip")
end

local function nearestBite()
	local char = player.Character
	local origin = char and char.PrimaryPart and char.PrimaryPart.Position
	local bites = workspace:FindFirstChild("FishingBites")
	if not bites or not origin then
		return nil
	end
	local best, bd = nil, math.huge
	for _, m in ipairs(bites:GetChildren()) do
		if m:IsA("BasePart") then
			local d = (m.Position - origin).Magnitude
			if d < bd then
				bd = d
				best = m
			end
		end
	end
	return best
end

local function clearTackle()
	for _, inst in ipairs({ activeLine, activeBobber, activeFish }) do
		if inst then
			inst:Destroy()
		end
	end
	activeLine, activeBobber, activeFish = nil, nil, nil
end

local function splash(pos)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Color = Color3.fromRGB(200, 230, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.3
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.5), { Size = Vector3.new(0.2, 7, 7), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.6)
end

local function floatText(pos, text, color)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(pos)
	anchor.Parent = workspace
	local bg = Instance.new("BillboardGui")
	bg.Size = UDim2.fromOffset(170, 44)
	bg.AlwaysOnTop = true
	bg.Adornee = anchor
	bg.Parent = anchor
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 22
	lbl.TextColor3 = color
	lbl.TextStrokeTransparency = 0.3
	lbl.Text = text
	lbl.Parent = bg
	TweenService:Create(anchor, TweenInfo.new(1.2), { CFrame = anchor.CFrame + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(lbl, TweenInfo.new(1.2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.3)
end

-- hide the ambient bite spawn-balls locally so only the cast bobber shows
local function hideBite(m)
	if m:IsA("BasePart") then
		m.LocalTransparencyModifier = 1
	end
end
task.spawn(function()
	local bites = workspace:WaitForChild("FishingBites", 30)
	if not bites then
		return
	end
	for _, m in ipairs(bites:GetChildren()) do
		hideBite(m)
	end
	bites.ChildAdded:Connect(hideBite)
end)

-- ── hooks ─────────────────────────────────────────────────────────────────────────────────────────
function M.onCast()
	M.enterFishing()
	playSound("cast", 0.5)
	clearTackle()
	local bite = nearestBite()
	if bite == nil then
		return
	end
	local bpos = bite.Position
	local bob = Instance.new("Part")
	bob.Shape = Enum.PartType.Ball
	bob.Size = Vector3.new(0.8, 0.8, 0.8)
	bob.Color = Color3.fromRGB(220, 60, 50)
	bob.Material = Enum.Material.SmoothPlastic
	bob.Anchored = true
	bob.CanCollide = false
	bob.CanQuery = false
	bob.CFrame = CFrame.new(bpos)
	bob.Parent = workspace
	local att = Instance.new("Attachment")
	att.Name = "BobAtt"
	att.Parent = bob
	activeBobber = bob
	splash(bpos)
	local tip = rodTip()
	if tip then
		local beam = Instance.new("Beam")
		beam.Attachment0 = tip
		beam.Attachment1 = att
		beam.Width0 = 0.06
		beam.Width1 = 0.06
		beam.Color = ColorSequence.new(Color3.fromRGB(240, 240, 230))
		beam.FaceCamera = true
		beam.CurveSize0 = 4
		beam.Parent = bob
		activeLine = beam
	end
end

function M.onBite()
	if activeBobber == nil then
		return
	end
	local base = activeBobber.CFrame
	splash(base.Position)
	TweenService:Create(activeBobber, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { CFrame = base - Vector3.new(0, 0.7, 0) }):Play()
	task.delay(0.14, function()
		if activeBobber then
			TweenService:Create(activeBobber, TweenInfo.new(0.12), { CFrame = base }):Play()
		end
	end)
	playSound("reel", 0.4)
end

function M.onReel(_progress)
	if activeBobber == nil then
		return
	end
	local char = player.Character
	local hrp = char and char.PrimaryPart
	if hrp == nil then
		return
	end
	local b = activeBobber.Position
	local toPlayer = Vector3.new(hrp.Position.X, b.Y, hrp.Position.Z)
	local nextPos = b:Lerp(toPlayer, 0.12)
	local flatDist = (Vector3.new(nextPos.X, 0, nextPos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude
	if flatDist > 3.5 then
		TweenService:Create(activeBobber, TweenInfo.new(0.14), { CFrame = CFrame.new(nextPos) }):Play()
	end
	playSound("reel", 0.25)
end

function M.onLanded(fishId, _projection)
	playSound("land", 0.55)
	playSound("cash", 0.5)
	local bob = activeBobber
	local pos = (bob and bob.Position) or (cam.CFrame * CFrame.new(0, 0, -10)).Position
	splash(pos)
	-- a small procedural fish on the line
	local fish = Instance.new("Part")
	fish.Size = Vector3.new(0.5, 0.7, 1.8)
	fish.Color = Color3.fromRGB(120, 140, 160)
	fish.Material = Enum.Material.SmoothPlastic
	fish.Anchored = true
	fish.CanCollide = false
	fish.CanQuery = false
	fish.CFrame = CFrame.new(pos)
	fish.Parent = workspace
	activeFish = fish
	local char = player.Character
	local hrp = char and char.PrimaryPart
	local liftTo = (hrp and (hrp.Position + hrp.CFrame.LookVector * 4 + Vector3.new(0, 2.5, 0))) or (pos + Vector3.new(0, 4, 0))
	if activeLine then
		activeLine.Attachment1 = fish:FindFirstChild("BobAtt") or activeLine.Attachment1
	end
	TweenService:Create(fish, TweenInfo.new(0.7, Enum.EasingStyle.Back), { CFrame = CFrame.new(liftTo) * CFrame.Angles(0, 0, math.rad(20)) }):Play()
	if bob then
		TweenService:Create(bob, TweenInfo.new(0.7), { CFrame = CFrame.new(liftTo) }):Play()
	end
	local name = "Fish"
	if typeof(fishId) == "string" then
		name = (fishId:gsub("^%a+_", ""):gsub("_", " "))
	end
	floatText(liftTo + Vector3.new(0, 1.6, 0), "Landed " .. name .. "!", Color3.fromRGB(150, 230, 140))
	task.delay(1.3, clearTackle)
	task.delay(1.45, M.exitFishing)
end

function M.onIdle()
	clearTackle()
	M.exitFishing()
end

-- build the rod on the current + future characters
local function onChar(char)
	task.defer(buildRod, char)
end
if player.Character then
	onChar(player.Character)
end
player.CharacterAdded:Connect(onChar)

return M
