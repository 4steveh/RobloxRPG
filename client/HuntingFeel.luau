--!nonstrict
-- STUDIO-ONLY ModuleScript (required by FireController — a .client LocalScript cannot be required).
-- Hunting game-feel: an aim highlight on the creature under the crosshair, plus shot/hit/kill FX
-- (muzzle flash, tracer, FOV recoil punch, hit-marker pulse, a "Down!" float on a kill). All procedural;
-- self-cleaning via Debris. No RemoteEvents — driven by FireController's existing fire path + replies.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

local M = {}
local BASE_FOV = cam.FieldOfView

-- ── aim highlight ──────────────────────────────────────────────────────────────────────────────────
local highlight = Instance.new("Highlight")
highlight.FillTransparency = 0.75
highlight.FillColor = Color3.fromRGB(255, 210, 120)
highlight.OutlineColor = Color3.fromRGB(255, 230, 150)
highlight.Enabled = false
highlight.Parent = workspace

local function creatureUnderCrosshair()
	local vp = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character, highlight }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local r = workspace:Raycast(ray.Origin, ray.Direction.Unit * 500, params)
	if r == nil then
		return nil
	end
	local model = r.Instance:FindFirstAncestorOfClass("Model")
	if model and model.Parent and model.Parent.Name == "HuntingTargets" then
		return model
	end
	return nil
end

RunService.RenderStepped:Connect(function()
	local model = creatureUnderCrosshair()
	if model then
		highlight.Adornee = model
		highlight.Enabled = true
	else
		highlight.Enabled = false
	end
end)

-- ── helpers ────────────────────────────────────────────────────────────────────────────────────────
local function barrelTip()
	local c = player.Character
	local rifle = c and c:FindFirstChild("HeldRifle")
	local barrel = rifle and rifle:FindFirstChild("Barrel")
	return barrel and barrel:FindFirstChild("BarrelTip")
end

-- ── shot FX ────────────────────────────────────────────────────────────────────────────────────────
function M.onFire(aimRay)
	local tip = barrelTip()
	local origin = (tip and tip.WorldPosition) or aimRay.Origin

	-- endpoint: where the aim ray lands (creature or terrain), for a believable tracer
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(aimRay.Origin, aimRay.Direction.Unit * 500, params)
	local endpoint = (hit and hit.Position) or (aimRay.Origin + aimRay.Direction.Unit * 300)

	-- muzzle flash: a brief light + glow part at the muzzle
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.6, 0.6, 0.6)
	flash.Color = Color3.fromRGB(255, 210, 130)
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CFrame = CFrame.new(origin)
	flash.Parent = workspace
	local light = Instance.new("PointLight")
	light.Brightness = 6
	light.Range = 12
	light.Color = Color3.fromRGB(255, 200, 120)
	light.Parent = flash
	TweenService:Create(flash, TweenInfo.new(0.12), { Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) }):Play()
	Debris:AddItem(flash, 0.2)

	-- tracer: a thin neon beam origin → endpoint
	local dist = (endpoint - origin).Magnitude
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 235, 170)
	beam.Size = Vector3.new(0.12, 0.12, dist)
	beam.CFrame = CFrame.lookAt(origin, endpoint) * CFrame.new(0, 0, -dist / 2)
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	Debris:AddItem(beam, 0.2)

	-- recoil: a quick FOV punch that settles (does not fight the follow camera)
	cam.FieldOfView = BASE_FOV + 4
	TweenService:Create(cam, TweenInfo.new(0.18), { FieldOfView = BASE_FOV }):Play()
end

function M.onHit()
	-- hit-marker: flash the aim highlight outline red briefly
	highlight.OutlineColor = Color3.fromRGB(255, 90, 80)
	task.delay(0.12, function()
		highlight.OutlineColor = Color3.fromRGB(255, 230, 150)
	end)
end

function M.onKill(_projection)
	local adornee = highlight.Adornee
	local pos = (adornee and adornee.Parent and adornee:GetPivot().Position)
		or (cam.CFrame * CFrame.new(0, 0, -12)).Position
	local anchorPart = Instance.new("Part")
	anchorPart.Anchored = true
	anchorPart.Transparency = 1
	anchorPart.CanCollide = false
	anchorPart.CanQuery = false
	anchorPart.Size = Vector3.one
	anchorPart.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	anchorPart.Parent = workspace
	local bg = Instance.new("BillboardGui")
	bg.Size = UDim2.fromOffset(140, 44)
	bg.AlwaysOnTop = true
	bg.Adornee = anchorPart
	bg.Parent = anchorPart
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 24
	lbl.TextColor3 = Color3.fromRGB(150, 230, 140)
	lbl.TextStrokeTransparency = 0.3
	lbl.Text = "Down!"
	lbl.Parent = bg
	TweenService:Create(anchorPart, TweenInfo.new(1.0), { CFrame = anchorPart.CFrame + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(lbl, TweenInfo.new(1.0), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchorPart, 1.1)
end

return M
