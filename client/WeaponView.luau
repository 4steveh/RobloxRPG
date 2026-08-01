--!nonstrict
-- STUDIO-ONLY ModuleScript. THE FIRST-PERSON WEAPON VIEW — what makes aiming read as shouldering a rifle.
--
-- THE PROBLEM IT SOLVES. Aim-down-sights was an over-the-shoulder camera offset plus a narrower field of
-- view. That is a ZOOM, not an aim: the player is still watching their character from behind, the sights are
-- never on the optical axis, and the scope is decoration. Every shooter that feels good puts the CAMERA
-- behind the sight.
--
-- HOW. As the aim blend rises, three things happen together:
--   1. the camera dollies from third person to first person (zoom -> 0.5),
--   2. the character's own arms and weapon are hidden LOCALLY (other players still see them),
--   3. a view model — the same published weapon template — is parented to the camera and positioned so its
--      SIGHT POINT lands exactly on the camera origin, with the bore down the camera's look vector.
--
-- Position 3 is the whole trick, and it is why the sight point is an attribute on the published template
-- rather than a number guessed here: the third-person weapon and this view model come from one definition,
-- so they cannot disagree about where the scope is.
--
-- Field of view is derived from the scope's magnification rather than hand-picked, with a floor: a true 4x
-- would be about 17 degrees, which is unusable for finding an animal, so it is clamped.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmRig = require(script.Parent:WaitForChild("ArmRig"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local M = {}

-- ── tuning ────────────────────────────────────────────────────────────────────────────────────────────
local HIP_ZOOM_MIN, HIP_ZOOM_MAX = 8, 14 -- matches CharacterController's third-person framing
local ADS_ZOOM = 0.5 -- Roblox treats this as first person
local BASE_FOV = 70
local MIN_ADS_FOV = 22 -- a true 4x is ~17 degrees: too tight to find an animal in
-- Where the weapon sits at the hip, relative to the camera: down, right, and forward, canted inward.
local HIP_OFFSET = CFrame.new(1.05, -1.15, -1.35) * CFrame.Angles(math.rad(-6), math.rad(-14), math.rad(4))
-- How far the view model lags the camera when you swing — the weapon has mass and does not turn instantly.
local SWAY_LAG = 9
local SWAY_MAX = math.rad(5)
-- The blend at which the scope picture takes over. Below it the view model is visible and you watch the
-- rifle come up to the shoulder; at it, the model is swapped for the scope overlay in the SAME frame, so the
-- swap is masked by the overlay appearing rather than reading as the weapon popping out of existence.
local SCOPED_AT = 0.88

-- ── state ─────────────────────────────────────────────────────────────────────────────────────────────
local viewModel = nil
local sightPoint = Vector3.zero
local magnification = 1
local hasScope = false
local swayCF = CFrame.new()
local lastLook = nil
local hiddenParts = {} -- part -> original LocalTransparencyModifier
local visible = false
local bobPhase = 0

-- Non-blocking: called every frame from the render step until it resolves, so it must never yield.
-- The blocking wait belongs in ViewModel, which runs once per character.
local function template()
	local root = ReplicatedStorage:FindFirstChild("WildWorldWeapons")
	return root and root:FindFirstChild("HuntingRifle")
end

function M.build()
	if viewModel ~= nil then
		return true
	end
	local tpl = template()
	if tpl == nil then
		return false
	end
	local m = tpl:Clone()
	m.Name = "WeaponView"
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			-- a view model must never be occluded by the world it is drawn in front of
			d.LocalTransparencyModifier = 1
		end
	end
	-- PIVOT: Model:GetPivot returns PrimaryPart.CFrame WHEN PrimaryPart IS SET, and only falls back to
	-- WorldPivot otherwise. So setting WorldPivot alone did nothing and PivotTo kept aligning the RECEIVER,
	-- which sits 0.143 studs above the grip origin — the scope came out exactly that far below the camera
	-- axis. Clearing PrimaryPart on the clone makes WorldPivot authoritative, and the template's parts are
	-- authored around the grip origin, so identity IS the grip frame.
	m.PrimaryPart = nil
	m.WorldPivot = CFrame.new()
	sightPoint = tpl:GetAttribute("sightPoint") or Vector3.zero
	magnification = tpl:GetAttribute("magnification") or 1
	hasScope = tpl:GetAttribute("hasScope") == true
	m.Parent = camera
	viewModel = m
	return true
end

function M.hasScope()
	return hasScope
end

-- ── local character hiding ────────────────────────────────────────────────────────────────────────────
-- LocalTransparencyModifier hides a part for THIS client only; the server and every other player still see
-- the full character holding its rifle. Using Transparency directly would replicate and hide the hunter
-- from everyone.
local function setCharacterHidden(hidden)
	local char = player.Character
	if char == nil then
		return
	end
	if hidden then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") and hiddenParts[d] == nil then
				hiddenParts[d] = d.LocalTransparencyModifier
				d.LocalTransparencyModifier = 1
			elseif d:IsA("Decal") and hiddenParts[d] == nil then
				hiddenParts[d] = d.Transparency
				d.Transparency = 1
			end
		end
	else
		for inst, original in pairs(hiddenParts) do
			if inst.Parent ~= nil then
				if inst:IsA("BasePart") then
					inst.LocalTransparencyModifier = original
				else
					inst.Transparency = original
				end
			end
		end
		table.clear(hiddenParts)
	end
end

local function setViewVisible(on)
	if viewModel == nil or visible == on then
		return
	end
	visible = on
	for _, d in ipairs(viewModel:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = on and 0 or 1
		end
	end
	setCharacterHidden(on)
end

-- ── per-frame ─────────────────────────────────────────────────────────────────────────────────────────

local function onRender(dt)
	camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	if viewModel == nil and not M.build() then
		return
	end
	dt = math.min(dt, 1 / 20)

	local blend = ArmRig.aimAlpha()

	-- 1. dolly the camera from third person to first person
	local zoomMin = HIP_ZOOM_MIN + (ADS_ZOOM - HIP_ZOOM_MIN) * blend
	local zoomMax = HIP_ZOOM_MAX + (ADS_ZOOM - HIP_ZOOM_MAX) * blend
	player.CameraMinZoomDistance = math.min(zoomMin, zoomMax)
	player.CameraMaxZoomDistance = math.max(zoomMin, zoomMax)

	-- 2. field of view from the scope, not from a hand-picked number
	local adsFov = if hasScope then math.max(MIN_ADS_FOV, BASE_FOV / magnification) else 45
	camera.FieldOfView = BASE_FOV + (adsFov - BASE_FOV) * blend

	-- 3. The view model shows from the moment we are in first person up to the point the scope takes over.
	--
	--    It MUST be hidden once fully scoped. The camera sits at the eye point, 0.7 studs behind the
	--    eyepiece, so the scope's own tube, eyepiece and glass are directly in front of the lens: the first
	--    build produced a perfectly aligned sight picture that was almost entirely BLACK, because the player
	--    was looking at the inside of the scope body. Real optics do not have that problem; a view model
	--    does. The overlay is the scope picture from here on.
	--
	--    An iron-sighted weapon keeps its model at full aim — there is no overlay to replace it with.
	local scoped = hasScope and blend >= SCOPED_AT
	setViewVisible(blend > 0.55 and not scoped)

	-- weapon lag: the muzzle trails a fast camera swing and catches up, so the rifle has mass
	local look = camera.CFrame.LookVector
	if lastLook ~= nil then
		local dx = look:Cross(lastLook)
		local yaw = math.clamp(dx.Y * 2.2, -SWAY_MAX, SWAY_MAX)
		local pitch = math.clamp((look.Y - lastLook.Y) * -2.6, -SWAY_MAX, SWAY_MAX)
		swayCF = swayCF:Lerp(CFrame.Angles(pitch, yaw, yaw * 0.6), math.clamp(dt * SWAY_LAG, 0, 1))
	end
	lastLook = look

	-- a light walk bob at the hip that all but disappears when shouldered
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local speed = hum and hum.MoveDirection.Magnitude * hum.WalkSpeed or 0
	bobPhase += dt * (6 + speed * 0.35)
	local bobAmount = math.clamp(speed / 16, 0, 1) * (1 - blend * 0.86)
	local bob = CFrame.new(
		math.sin(bobPhase) * 0.045 * bobAmount,
		math.sin(bobPhase * 2) * 0.03 * bobAmount,
		0
	)

	-- 4. THE ALIGNMENT. Placing the model at -sightPoint puts the scope's optical axis exactly on the camera
	--    origin, with the bore down the camera's look vector.
	local aimCF = CFrame.new(-sightPoint)
	local target = HIP_OFFSET:Lerp(aimCF, blend)
	viewModel:PivotTo(camera.CFrame * swayCF * bob * target)
end

function M.start()
	RunService:BindToRenderStep("WildWorldWeaponView", Enum.RenderPriority.Camera.Value + 2, onRender)
end

-- rebuild on respawn: the character's parts change identity, so the hidden-part table must be dropped
player.CharacterAdded:Connect(function()
	table.clear(hiddenParts)
	visible = false
	if viewModel ~= nil then
		viewModel:Destroy()
		viewModel = nil
	end
end)

return M
