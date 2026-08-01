--!nonstrict
-- STUDIO-ONLY. THE AIM INPUT LAYER.
--
-- WHY NOT RIGHT MOUSE. It used to be hold-right-mouse. Right-drag is Roblox's own camera-rotate control, so
-- binding aim to it fought the thing the player uses to look around — you could not aim and turn at the same
-- time without the camera fighting you. Right mouse is left entirely alone now.
--
-- WHY A TOGGLE, NOT A HOLD. Hunting is a waiting game: you settle into a sight picture and hold it while an
-- animal closes. A hold binding means clamping a key for thirty seconds, which is tiring and makes long
-- observation actively unpleasant. A toggle lets the player commit to the scope and use both hands to move.
-- The gamepad keeps a HOLD on the left trigger, because that is the convention there and a trigger is built
-- for it.
--
--   Keyboard: Q toggles aim (also Right-Shift, for left-handed layouts)
--   Gamepad:  hold ButtonL2
--   Touch:    the AIM button toggles
--
-- Sprinting cancels aim rather than being silently blocked: the player pressed sprint, so sprint is what
-- should happen.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local ArmRig = require(script.Parent:WaitForChild("ArmRig"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Stance = require(script.Parent:WaitForChild("Stance"))
local UISound = require(script.Parent:WaitForChild("UISound"))

local aiming = false

local function setAim(on)
	if aiming == on then
		return
	end
	aiming = on
	ArmRig.setAiming(on)
	Hud.setAimState(on)
	UISound.play(on and "open" or "close", 0.55)
end

local function toggleAim()
	setAim(not aiming)
end

-- ── keyboard: toggle ──────────────────────────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.RightShift then
		toggleAim()
	elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
		setAim(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	-- gamepad only: the trigger is a hold
	if input.KeyCode == Enum.KeyCode.ButtonL2 then
		setAim(false)
	end
end)

-- ── sprint cancels aim ────────────────────────────────────────────────────────────────────────────────
-- You cannot hold a sight picture at a run, and silently refusing the sprint would be worse: the player
-- asked to move, so drop the aim and move.
RunService.Heartbeat:Connect(function()
	if aiming and Stance.isSprinting() then
		setAim(false)
	end
end)

-- ── touch: a toggle button, labelled with its state ───────────────────────────────────────────────────
if UserInputService.TouchEnabled then
	local aimBtn = Hud.button({
		name = "AimButton",
		text = "AIM",
		position = UDim2.new(1, -20, 1, -216),
		size = UDim2.fromOffset(120, 56),
		color = Color3.fromRGB(70, 96, 120),
	})
	aimBtn.Activated:Connect(function()
		toggleAim()
		aimBtn.Text = aiming and "AIMING" or "AIM"
		aimBtn.BackgroundColor3 = aiming and Color3.fromRGB(96, 132, 160) or Color3.fromRGB(70, 96, 120)
	end)
end

-- ── discoverability ───────────────────────────────────────────────────────────────────────────────────
-- A toggle the player never finds is worse than a hold they stumble into, so the binding is stated on screen
-- until it has been used once.
if not UserInputService.TouchEnabled then
	task.delay(2, function()
		if not aiming then
			Hud.toast("Press Q to aim down the scope", Color3.fromRGB(200, 220, 240))
		end
	end)
end

return nil
