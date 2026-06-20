--!nonstrict
-- STUDIO-ONLY. The AIM INPUT layer for the weapon-handling rig (ArmRig). Hold to aim — drops the camera to
-- an over-the-shoulder ADS pose + FOV zoom and raises the rifle (all owned by ArmRig); release to lower.
--   • Desktop / mouse: hold Right Mouse Button.
--   • Touch: a dedicated right-edge "AIM" button (separate from FIRE — the review flagged FIRE's tap also
--     firing on touch; AIM is its own hold button so the two never collide).
--   • Gamepad: hold ButtonL2.
-- The shot itself is unchanged (FireController sends the screen-centre camera ray); aiming only tightens the
-- camera so the crosshair is precise. Crosshair state is mirrored to the HUD.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local ArmRig = require(script.Parent:WaitForChild("ArmRig"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local function setAim(on)
	ArmRig.setAiming(on)
	Hud.setAimState(on)
end

-- mouse / gamepad: hold to aim
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		setAim(true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		setAim(false)
	end
end)

-- touch: a dedicated AIM hold-button (right edge, above FIRE)
if UserInputService.TouchEnabled then
	local aimBtn = Hud.button({
		name = "AimButton", text = "AIM",
		position = UDim2.new(1, -20, 1, -216), size = UDim2.fromOffset(120, 56),
		color = Color3.fromRGB(70, 96, 120),
	})
	-- hold semantics: pressed = aim, released / finger-off = lower (never gets stuck on)
	aimBtn.MouseButton1Down:Connect(function() setAim(true) end)
	aimBtn.MouseButton1Up:Connect(function() setAim(false) end)
	aimBtn.MouseLeave:Connect(function() setAim(false) end)
end
