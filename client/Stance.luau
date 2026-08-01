--!nonstrict
-- STUDIO-ONLY ModuleScript. MOVEMENT STANCE — sprint, crouch, and the aim walk.
--
-- The character had exactly one speed and one posture. A hunter who closes on an animal at the same pace
-- they cross open ground, and who cannot slow down or get low, has no movement decisions to make — which is
-- why stalking never felt like anything even after the creatures started reacting.
--
-- Stance is CLIENT-OWNED because WalkSpeed for your own character is client-authoritative in Roblox, and
-- because this is feel, not authority: the server still owns every shot, payout and gate. The base speed is
-- read from whatever the server set at spawn rather than hard-coded, so the Shells.movement config stays the
-- source of truth and this only ever applies a multiplier to it.
--
-- Crouch lowers the camera through Humanoid.CameraOffset. ArmRig also writes CameraOffset for its
-- over-the-shoulder aim pose, so the two are composed in ONE place (see M.cameraOffset) rather than fighting
-- each other frame to frame.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local M = {}

-- multipliers on the server-provided base walk speed
local SPRINT_MULT = 1.55
local CROUCH_MULT = 0.42
local AIM_MULT = 0.45
local SPRINT_AIM_BLOCK = 0.25 -- above this aim blend, sprinting is not allowed

local CROUCH_CAMERA_DROP = 1.6
local SPEED_LERP = 7

local baseSpeed = nil
local sprinting = false
local crouching = false
local aimBlend = 0
local crouchAmount = 0 -- 0..1, smoothed
local humanoid = nil

function M.isSprinting()
	return sprinting and aimBlend <= SPRINT_AIM_BLOCK
end

function M.isCrouching()
	return crouching
end

-- 0..1 — how settled the shooter is. Used by the weapon sway: a sprinting hunter cannot hold a sight
-- picture, a crouched one can.
function M.steadiness()
	local s = 1
    if M.isSprinting() then
		s -= 0.75
	end
	if crouching then
		s += 0.35
	end
	if humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.05 then
		s -= 0.3
	end
	return math.clamp(s, 0, 1.35)
end

function M.cameraOffset()
	return Vector3.new(0, -CROUCH_CAMERA_DROP * crouchAmount, 0)
end

function M.setAimBlend(v)
	aimBlend = v or 0
end

local function bind(char)
	humanoid = char:WaitForChild("Humanoid", 10)
	baseSpeed = nil -- re-read the server's value for the new character
end

local function onStep(dt)
	local char = player.Character
	if char == nil then
		return
	end
	if humanoid == nil or humanoid.Parent == nil then
		humanoid = char:FindFirstChildOfClass("Humanoid")
	end
	if humanoid == nil then
		return
	end
	-- Latch the server's spawn speed once, so the multiplier composes with the config rather than replacing
	-- it. Re-latched per character, because the server may set a different speed per destination.
	if baseSpeed == nil and humanoid.WalkSpeed > 0 then
		baseSpeed = humanoid.WalkSpeed
	end
	if baseSpeed == nil then
		return
	end

	crouchAmount += ((crouching and 1 or 0) - crouchAmount) * math.clamp(dt * 9, 0, 1)

	local mult = 1
	if M.isSprinting() then
		mult = SPRINT_MULT
	elseif crouching then
		mult = CROUCH_MULT
	end
	-- aiming always slows you, and stacks with crouch
	mult *= (1 - (1 - AIM_MULT) * aimBlend)

	local goal = baseSpeed * mult
	humanoid.WalkSpeed += (goal - humanoid.WalkSpeed) * math.clamp(dt * SPEED_LERP, 0, 1)
end

-- ── input ─────────────────────────────────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		sprinting = true
	elseif input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonB then
		crouching = not crouching
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		sprinting = false
	end
end)

function M.setSprinting(on)
	sprinting = on == true
end

function M.toggleCrouch()
	crouching = not crouching
end

function M.start()
	if player.Character then
		bind(player.Character)
	end
	player.CharacterAdded:Connect(bind)
	RunService.Heartbeat:Connect(onStep)
end

return M
