--!nonstrict
-- STUDIO-ONLY. A procedural bolt-action HUNTING RIFLE welded to the player's right hand so the hunt has a
-- believable weapon (was 3 flat boxes — review gap #5). Built in a local "grip frame" (origin = the trigger
-- grip, barrel down -Z, up +Y) and welded so it sits IN the hand; ArmRig poses the arms around it (two-handed
-- grip + ADS raise + recoil). Exposes a BarrelTip Attachment at the muzzle (HuntingFeel reads it for the
-- muzzle-flash + tracer origin). Rebuilds on respawn. Registers "rifle" mode with ArmRig.
--
-- NOTE on cylinders: a Part with Shape=Cylinder has its LENGTH along local X (Size.X), circular cross-section
-- in Y-Z. To lay a barrel/scope along the rifle's -Z (forward) we size length in X and yaw the part +90° about
-- Y so local +X points down -Z.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local ArmRig = require(script.Parent:WaitForChild("ArmRig"))

-- where the rifle sits relative to the hand (the trigger grip in the palm). TUNE in Studio.
local GRIP = CFrame.new(0.05, -0.15, -0.5) * CFrame.Angles(math.rad(-6), 0, 0)

local WOOD = Color3.fromRGB(78, 52, 33)
local WOOD_HI = Color3.fromRGB(96, 66, 42)
local METAL = Color3.fromRGB(38, 39, 44)
local BLACK = Color3.fromRGB(22, 22, 24)
local YAW = CFrame.Angles(0, math.rad(90), 0) -- lay a cylinder's X-length along -Z

local function build(char)
	if char:FindFirstChild("HeldRifle") then
		return
	end
	local hand = char:FindFirstChild("RightHand") or char:WaitForChild("RightHand", 8) or char:FindFirstChild("Right Arm")
	if hand == nil then
		return
	end

	local model = Instance.new("Model")
	model.Name = "HeldRifle"

	local parts = {}
	local function part(name, size, localCF, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		parts[p] = localCF
		return p
	end

	-- boxes (Z = forward)
	part("Receiver", Vector3.new(0.26, 0.40, 1.05), CFrame.new(0, 0.12, -0.05), METAL, Enum.Material.Metal)
	part("Grip", Vector3.new(0.22, 0.46, 0.30), CFrame.new(0, -0.12, 0.16) * CFrame.Angles(math.rad(18), 0, 0), WOOD, Enum.Material.Wood)
	part("Stock", Vector3.new(0.30, 0.52, 1.15), CFrame.new(0, 0.04, 0.92) * CFrame.Angles(math.rad(-4), 0, 0), WOOD, Enum.Material.Wood)
	part("Comb", Vector3.new(0.24, 0.16, 0.66), CFrame.new(0, 0.30, 0.74), WOOD_HI, Enum.Material.Wood)
	part("ButtPad", Vector3.new(0.32, 0.56, 0.12), CFrame.new(0, 0.02, 1.50), BLACK, Enum.Material.SmoothPlastic)
	part("ForeEnd", Vector3.new(0.21, 0.24, 1.0), CFrame.new(0, 0.07, -0.95), WOOD, Enum.Material.Wood)
	part("Magazine", Vector3.new(0.18, 0.34, 0.44), CFrame.new(0, -0.20, -0.10) * CFrame.Angles(math.rad(6), 0, 0), METAL, Enum.Material.Metal)
	part("TriggerGuard", Vector3.new(0.10, 0.16, 0.30), CFrame.new(0, -0.16, 0.02), METAL, Enum.Material.Metal)
	part("ScopeRingF", Vector3.new(0.10, 0.18, 0.10), CFrame.new(0, 0.31, -0.55), BLACK, Enum.Material.Metal)
	part("ScopeRingB", Vector3.new(0.10, 0.18, 0.10), CFrame.new(0, 0.31, 0.05), BLACK, Enum.Material.Metal)

	-- cylinders (length along X → yaw to lie along -Z)
	local barrel = part("Barrel", Vector3.new(2.3, 0.135, 0.135), CFrame.new(0, 0.20, -1.55) * YAW, METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	part("Muzzle", Vector3.new(0.22, 0.17, 0.17), CFrame.new(0, 0.20, -2.62) * YAW, BLACK, Enum.Material.Metal, Enum.PartType.Cylinder)
	part("ScopeTube", Vector3.new(0.95, 0.15, 0.15), CFrame.new(0, 0.40, -0.25) * YAW, BLACK, Enum.Material.Metal, Enum.PartType.Cylinder)
	local lensF = part("LensF", Vector3.new(0.04, 0.13, 0.13), CFrame.new(0, 0.40, -0.73) * YAW, Color3.fromRGB(120, 170, 200), Enum.Material.Glass, Enum.PartType.Cylinder)
	lensF.Reflectance = 0.3
	local lensB = part("LensB", Vector3.new(0.04, 0.13, 0.13), CFrame.new(0, 0.40, 0.22) * YAW, Color3.fromRGB(40, 50, 60), Enum.Material.Glass, Enum.PartType.Cylinder)
	lensB.Reflectance = 0.2
	-- bolt handle (sticks out to the right, +X)
	part("Bolt", Vector3.new(0.30, 0.085, 0.085), CFrame.new(0.20, 0.16, 0.18), METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	part("BoltKnob", Vector3.new(0.10, 0.10, 0.10), CFrame.new(0.37, 0.16, 0.18), BLACK, Enum.Material.Metal, Enum.PartType.Ball)

	model.PrimaryPart = barrel

	for p, localCF in parts do
		p.CFrame = hand.CFrame * GRIP * localCF
		local w = Instance.new("Weld")
		w.Part0 = hand
		w.Part1 = p
		w.C0 = hand.CFrame:ToObjectSpace(p.CFrame)
		w.Parent = p
	end

	-- the muzzle end (HuntingFeel muzzle-flash / tracer origin). Set in WORLD space from the grip frame so it
	-- is independent of the barrel's local cylinder rotation; the weld then carries it with the hand.
	local tip = Instance.new("Attachment")
	tip.Name = "BarrelTip"
	tip.Parent = barrel
	tip.WorldPosition = (hand.CFrame * GRIP * CFrame.new(0, 0.20, -2.78)).Position

	model.Parent = char
	ArmRig.setMode("rifle")
end

local function onChar(char)
	task.defer(build, char)
end

if player.Character then
	onChar(player.Character)
end
player.CharacterAdded:Connect(onChar)
