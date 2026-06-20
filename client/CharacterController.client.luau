--!nonstrict
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- STUDIO-ONLY (NOT headless-analyzed). Mobile-first character controller — a LocalScript in
-- StarterPlayerScripts. "Pragmatic, not a custom physics engine" (build prompt): it leans on Roblox's
-- built-in touch controls (thumbstick + jump) and dynamic camera, and tunes the third-person camera for
-- phones. WalkSpeed/JumpPower are applied SERVER-side from the Shells.movement config (BayouBlockout);
-- this script owns only the camera/control feel. Verified by the Studio playtest, not CI.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Third-person camera zoom tuned for a phone (closer than the desktop default). These mirror
-- Shells.movement.cameraMinZoom / cameraMaxZoom — the config is the source of truth; a client LocalScript
-- can't require a ServerScriptService module, so the two values are inlined here (Studio-only duplication;
-- a ReplicatedStorage shared-config or a replicated attribute is the clean Step-6+ home).
local CAMERA_MIN_ZOOM = 8
local CAMERA_MAX_ZOOM = 14

player.CameraMinZoomDistance = CAMERA_MIN_ZOOM
player.CameraMaxZoomDistance = CAMERA_MAX_ZOOM
player.CameraMode = Enum.CameraMode.Classic -- free third-person look (good on touch)

-- NOTE: DevTouchMovementMode / DevComputerMovementMode are intentionally NOT set here. Setting them from a
-- plain LocalScript throws "lacking capability RobloxScript" on modern Roblox (a security-capability change)
-- — it errored every spawn (Studio console). The engine defaults are already UserChoice (thumbstick + jump on
-- touch), so these are true no-ops; the right home for an override is StarterPlayer properties in Studio, not
-- a runtime script. (Removed the throwing assignments.)
