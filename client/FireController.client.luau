--!nonstrict
-- STUDIO-ONLY. Aim-and-render fire terminal. Sends AIM ONLY — the server raycasts from the character, finds
-- the target, and recomputes damage; this script never does hit detection or claims a payout. Aim = the
-- camera's screen-center (crosshair) ray; we ALSO send the real camera-ray origin (the server currently
-- ignores it, but sending it keeps the future "raycast-from-camera, bound the origin near the character" fix
-- forward-compatible). Renders the server's ("hit"|"kill", …) reply.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Net = require(script.Parent:WaitForChild("Net"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local FIRE_COOLDOWN = 0.15 -- client-side anti-spam only; the server enforces the authoritative fire rate
local lastFire = 0

local function aimAndFire()
	local cam = workspace.CurrentCamera
	local char = player.Character
	if cam == nil or char == nil or char.PrimaryPart == nil then
		return
	end
	local now = os.clock()
	if now - lastFire < FIRE_COOLDOWN then
		return
	end
	lastFire = now
	local vp = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	Net.fire:FireServer(ray.Origin, ray.Direction.Unit)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return -- a tap/click consumed by the HUD (e.g. a shop button) is not a shot
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		aimAndFire()
	end
end)

-- a dedicated on-screen FIRE button for touch (right edge, above the thumbstick area)
local fireBtn = Hud.button({
	name = "FireButton", text = "FIRE",
	position = UDim2.new(1, -20, 1, -150), size = UDim2.fromOffset(120, 56),
	color = Color3.fromRGB(120, 60, 55),
})
fireBtn.Activated:Connect(aimAndFire)

Net.fire.OnClientEvent:Connect(function(kind, targetId, extra)
	if kind == "kill" then
		Hud.applyProjection(extra) -- extra = projection (carries the new balance → payout-delta toast)
		Hud.toast("Down!", Color3.fromRGB(150, 230, 140))
	elseif kind == "hit" then
		Hud.toast("hit " .. tostring(extra), Color3.fromRGB(230, 220, 140)) -- extra = per-shot damage
	end
end)
