--!nonstrict
-- STUDIO-ONLY ModuleScript (required by FishingController — a .client LocalScript cannot be required).
-- Fishing game-feel: a held rod (mode-swapped with the rifle), the cast line + bobber + splash, the bite
-- jerk, the reel tension (rod bend), and the landed-fish reveal. All procedural; self-cleaning via Debris.
-- No RemoteEvents — driven by FishingController's existing cast/bite/fight/landed flow.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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

	-- rod held angled up-and-forward from the hand
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
	tip.Position = Vector3.new(0, 0, -2.1) -- the far end of the shaft
	tip.Parent = shaft

	model.Parent = char
	rodModel = model
end

local function setRifleHidden(hidden)
	local char = player.Character
	local rifle = char and char:FindFirstChild("HeldRifle")
	if rifle then
		for _, p in ipairs(rifle:GetDescendants()) do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = hidden and 1 or 0
			end
		end
	end
end

local function setRodHidden(hidden)
	if rodModel then
		for _, p in ipairs(rodModel:GetDescendants()) do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = hidden and 1 or 0
			end
		end
	end
end

-- ── mode swap ─────────────────────────────────────────────────────────────────────────────────────
function M.enterFishing()
	setRodHidden(false)
	setRifleHidden(true)
end

function M.exitFishing()
	setRodHidden(true)
	setRifleHidden(false)
end

-- hooks (filled in F-B/F-C) ---------------------------------------------------------------------------
function M.onCast()
	M.enterFishing()
	playSound("cast", 0.5)
end

function M.onBite() end

function M.onReel(_progress) end

function M.onLanded(_fishId, _projection)
	playSound("land", 0.55)
	playSound("cash", 0.5)
	task.delay(1.4, M.exitFishing)
end

function M.onIdle()
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
