--!nonstrict
-- STUDIO-ONLY ModuleScript (required by FireController — a .client LocalScript cannot be required).
-- Hunting game-feel: an aim highlight on the creature under the crosshair, plus shot/hit/kill FX
-- (muzzle flash, tracer, FOV recoil punch, hit-marker pulse, a "Down!" float on a kill). All procedural;
-- self-cleaning via Debris. No RemoteEvents — driven by FireController's existing fire path + replies.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera

local CameraFeel = require(script.Parent:WaitForChild("CameraFeel"))
local Impact = require(script.Parent:WaitForChild("ImpactFeel"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local M = {}

-- ── sound (best-effort): engine-bundled rbxasset:// ids (load locally, no CDN); silent on any failure ──
local SOUNDS = {
	fire = "rbxasset://sounds/snap.wav",
	hit = "rbxasset://sounds/hit.wav",
	kill = "rbxasset://sounds/bass.wav",
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


-- ── screen-space hit-marker ────────────────────────────────────────────────────────────────────────
-- The old confirmation was the aim highlight's OUTLINE briefly turning red — a change to a thing the
-- player is not looking at, on the target rather than under the crosshair. Four ticks that pop outward
-- from screen centre put the confirmation exactly where the eye already is.
local marker = Instance.new("Frame")
marker.Name = "HitMarker"
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Position = UDim2.fromScale(0.5, 0.5)
marker.Size = UDim2.fromOffset(48, 48)
marker.BackgroundTransparency = 1
marker.Visible = false
marker.ZIndex = 40
marker.Parent = Hud.gui

local ticks = {}
for i, spec in ipairs({
	{ UDim2.new(0.5, 0, 0, 0), Vector2.new(0.5, 0), UDim2.fromOffset(3, 11) },
	{ UDim2.new(0.5, 0, 1, 0), Vector2.new(0.5, 1), UDim2.fromOffset(3, 11) },
	{ UDim2.new(0, 0, 0.5, 0), Vector2.new(0, 0.5), UDim2.fromOffset(11, 3) },
	{ UDim2.new(1, 0, 0.5, 0), Vector2.new(1, 0.5), UDim2.fromOffset(11, 3) },
}) do
	local t = Instance.new("Frame")
	t.BorderSizePixel = 0
	t.Position = spec[1]
	t.AnchorPoint = spec[2]
	t.Size = spec[3]
	t.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	t.Parent = marker
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = t
	ticks[i] = t
end

local markerToken = 0
local function popMarker(vital)
	markerToken += 1
	local token = markerToken
	marker.Visible = true
	marker.Size = UDim2.fromOffset(if vital then 30 else 34, if vital then 30 else 34)
	local col = if vital then Color3.fromRGB(255, 222, 120) else Color3.fromRGB(255, 255, 255)
	for _, t in ipairs(ticks) do
		t.BackgroundColor3 = col
		t.BackgroundTransparency = 0
	end
	TweenService:Create(marker, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(if vital then 62 else 54, if vital then 62 else 54),
	}):Play()
	for _, t in ipairs(ticks) do
		TweenService:Create(t, TweenInfo.new(0.22), { BackgroundTransparency = 1 }):Play()
	end
	task.delay(0.26, function()
		if markerToken == token then
			marker.Visible = false
		end
	end)
end

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

	-- recoil camera FOV punch is owned by ArmRig (M.recoil) so it composes with the ADS zoom instead of
	-- fighting it. The ANGULAR kick is CameraFeel's, applied after the camera has been positioned.
	CameraFeel.kick(1)
	playSound("fire", 0.45)

	-- Predicted impact, fired NOW rather than on the server's reply: a shot has to have a consequence at the
	-- point of contact the same frame the trigger goes down, or it reads as lag. The server still owns the
	-- outcome. `hit` is the same raycast the tracer endpoint came from, so this is free.
	local info = Impact.classify(hit)
	M.lastImpact = info
	if info ~= nil then
		local amount = Impact.burst(info.position, info.normal, info.material, { class = info.class })
		CameraFeel.shakeCamera(amount)
	end
end

-- `damage` is the server's authoritative per-shot number; the impact position comes from the client's own
-- predicted raycast at fire time, which is the same aim the server used.
function M.onHit(damage)
	local info = M.lastImpact
	local vital = info ~= nil and info.zone == "vital"
	popMarker(vital)
	if info ~= nil then
		Impact.damageNumber(info.position, tonumber(damage) or 0, vital)
		if info.model ~= nil then
			Impact.flinch(info.model, false)
		end
	end
	CameraFeel.hitConfirm(if vital then 0.55 else 0.35)
	playSound("hit", 0.5)
end

function M.onKill(_projection)
	local info = M.lastImpact
	popMarker(true)
	if info ~= nil then
		if info.model ~= nil then
			Impact.flinch(info.model, true)
		end
		-- a heavier burst on the killing blow, at the same contact point
		Impact.burst(info.position, info.normal, info.material, { class = info.class, scale = 1.7 })
	end
	CameraFeel.hitConfirm(0.8)
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
	playSound("kill", 0.55)
	playSound("cash", 0.5)
end

return M
