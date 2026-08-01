--!nonstrict
-- STUDIO-ONLY ModuleScript. ADDITIVE CAMERA FEEL — recoil kick, impact shake, landing thump, and a constant
-- breathing sway.
--
-- WHY IT IS ADDITIVE. Wild World already has two things driving the camera: Roblox's default camera module
-- and ArmRig's ADS zoom. Anything that WRITES cam.CFrame outright fights them (the earlier FOV punch in
-- HuntingFeel did exactly that and had to be moved into ArmRig). This binds AFTER the camera has been
-- positioned for the frame — RenderPriority.Camera + 1 — and contributes a small rotation on top of
-- whatever CFrame the camera arrived at, as a per-frame DELTA (see the note at the bottom: the module does
-- not rewrite CFrame from scratch, so a plain post-multiply compounds). It composes with the default
-- camera, with ADS, and with any future camera work, and can never take control away from them.
--
-- WHY SUM-OF-SINES AND NOT RANDOM. Per-frame white noise reads as a glitch, not as weight: it has energy at
-- every frequency including ones the eye reads as tearing. Three incommensurate sine pairs give continuous,
-- frame-rate-independent motion that reads as a physical camera being pushed around, and it is deterministic
-- in `t` so it never stutters when the frame rate does.

local RunService = game:GetService("RunService")

local M = {}

local camera = workspace.CurrentCamera

-- ── state ─────────────────────────────────────────────────────────────────────────────────────────────
-- Recoil is a spring: an impulse raises `kick`, which decays toward zero while `kickVel` carries it back
-- past centre slightly, so a shot settles rather than snapping. Shake is an amplitude envelope that decays.
local kickPitch, kickPitchVel = 0, 0
local kickYaw, kickYawVel = 0, 0
local kickRoll, kickRollVel = 0, 0
local shake = 0
local shakeDecay = 6
local swayEnabled = true
-- the net rotation we are currently contributing; the per-frame delta is measured against it
local appliedOffset = CFrame.identity

-- Spring constants. STIFFNESS sets how fast the camera returns to centre, DAMPING how much it overshoots.
-- Tuned so a rifle shot recovers in roughly a third of a second with one small overshoot — the recovery is
-- what reads as weight; an instant snap back reads as nothing happening at all.
local STIFFNESS = 190
local DAMPING = 17
local MAX_KICK = math.rad(6)
local MAX_SHAKE = math.rad(3.2)

local function spring(value, vel, dt)
	local accel = -STIFFNESS * value - DAMPING * vel
	vel += accel * dt
	value += vel * dt
	return value, vel
end

-- ── public API ────────────────────────────────────────────────────────────────────────────────────────

-- A weapon kick: mostly upward pitch, with a little yaw and roll so repeated shots do not trace the same
-- line. `amount` is 0..1 of a full rifle recoil.
function M.kick(amount)
	amount = math.clamp(amount or 1, 0, 2)
	kickPitchVel -= amount * 5.2
	-- alternate the horizontal component per shot so a burst walks rather than climbing straight up
	local side = if math.random() < 0.5 then -1 else 1
	kickYawVel += side * amount * 1.6
	kickRollVel += side * amount * 2.4
end

-- A world impact: an omnidirectional shake with no directional bias. `intensity` is 0..1.
function M.shakeCamera(intensity)
	shake = math.clamp(shake + (intensity or 0.5), 0, 1.4)
end

-- A directional nudge, for a confirmed hit landing on a target — small, sharp, and toward the target so it
-- reads as connection rather than as another shot.
function M.hitConfirm(intensity)
	local a = math.clamp(intensity or 0.4, 0, 1)
	kickPitchVel -= a * 1.6
	shake = math.clamp(shake + a * 0.35, 0, 1.4)
end

function M.setSway(on)
	swayEnabled = on ~= false
end

-- ── the per-frame pass ────────────────────────────────────────────────────────────────────────────────

local function onRender(dt)
	-- CurrentCamera is replaced on respawn, so re-read it rather than caching it once at require time.
	camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	dt = math.min(dt, 1 / 20) -- a hitch must not launch the camera

	kickPitch, kickPitchVel = spring(kickPitch, kickPitchVel, dt)
	kickYaw, kickYawVel = spring(kickYaw, kickYawVel, dt)
	kickRoll, kickRollVel = spring(kickRoll, kickRollVel, dt)
	shake = shake * math.clamp(1 - dt * shakeDecay, 0, 1)
	if shake < 0.001 then
		shake = 0
	end

	local t = os.clock()
	local pitch = math.clamp(kickPitch, -MAX_KICK, MAX_KICK)
	local yaw = math.clamp(kickYaw, -MAX_KICK, MAX_KICK)
	local roll = math.clamp(kickRoll, -MAX_KICK, MAX_KICK)

	if shake > 0 then
		-- three incommensurate frequencies per axis: continuous, and never repeats visibly
		local s = shake * MAX_SHAKE
		pitch += s * (math.sin(t * 37.1) * 0.6 + math.sin(t * 19.3) * 0.4)
		yaw += s * (math.sin(t * 31.7) * 0.6 + math.sin(t * 23.9) * 0.4)
		roll += s * 0.7 * math.sin(t * 27.3)
	end

	if swayEnabled then
		-- Breathing. Tiny — 0.12 degrees — but its absence is what makes a held camera feel like a tripod.
		local breathe = math.rad(0.12)
		pitch += breathe * math.sin(t * 1.1)
		yaw += breathe * 1.3 * math.sin(t * 0.77)
	end

	local offset = CFrame.Angles(pitch, yaw, roll)

	-- APPLY THE DELTA, NOT THE OFFSET.
	--
	-- The obvious `cam.CFrame = cam.CFrame * offset` is only safe if the camera module rewrites CFrame from
	-- scratch every frame. It does NOT: writing a deliberately wrong CFrame and reading it back one frame
	-- later showed it moved only 0.23 degrees — the module preserves and adjusts the existing CFrame rather
	-- than replacing it. So a per-frame post-multiply stacks on its own previous result, and idle breathing
	-- sway alone measured 17.9 degrees of drift per second.
	--
	-- Applying `prevOffset:Inverse() * offset` instead means the NET rotation we have contributed is always
	-- exactly `offset`, never a running sum. When the impulses decay to nothing the delta unwinds whatever
	-- we last added, so the camera returns precisely to where the module put it — and if the module DOES
	-- write on some frame, the error is bounded by one frame's delta and self-corrects.
	local delta = appliedOffset:Inverse() * offset
	camera.CFrame = camera.CFrame * delta
	appliedOffset = offset
end

-- Bound one step AFTER the camera so the offset lands on the final camera CFrame for the frame. Binding
-- before it would be silently overwritten.
RunService:BindToRenderStep("WildWorldCameraFeel", Enum.RenderPriority.Camera.Value + 1, onRender)

return M
