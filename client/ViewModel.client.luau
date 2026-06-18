--!nonstrict
-- STUDIO-ONLY. A procedural rifle welded to the player's right hand so the hunt has a visible weapon.
-- Exposes a BarrelTip Attachment at the muzzle (HuntingFeel reads it for muzzle-flash + tracer origin).
-- Rebuilds on respawn. v1 is one generic hunting rifle (tier-based variation is a later nicety).
local Players = game:GetService("Players")
local player = Players.LocalPlayer

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
		p.Parent = model
		return p
	end

	local stock = part("Stock", Vector3.new(0.28, 0.5, 1.3), Color3.fromRGB(74, 52, 36))
	local barrel = part("Barrel", Vector3.new(0.18, 0.18, 2.6), Color3.fromRGB(42, 44, 50))
	local grip = part("Grip", Vector3.new(0.22, 0.55, 0.3), Color3.fromRGB(60, 60, 66))
	model.PrimaryPart = barrel

	-- place relative to the hand (held forward), then weld so it tracks the hand
	local base = hand.CFrame * CFrame.new(0, -0.1, -1.1)
	barrel.CFrame = base
	stock.CFrame = base * CFrame.new(0, 0, 0.95)
	grip.CFrame = base * CFrame.new(0, -0.35, 0.5)
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
	tip.Name = "BarrelTip"
	tip.Position = Vector3.new(0, 0, -1.4) -- the muzzle end of the barrel
	tip.Parent = barrel

	model.Parent = char
end

local function onChar(char)
	task.defer(build, char)
end

if player.Character then
	onChar(player.Character)
end
player.CharacterAdded:Connect(onChar)
