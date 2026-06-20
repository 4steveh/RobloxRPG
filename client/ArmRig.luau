--!nonstrict
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- STUDIO-ONLY ModuleScript. THE WEAPON-HANDLING RIG — the "hold a gun & rod appropriately + aim before
-- shooting" layer, the #1 review gap (player actions, far-below-bar). One shared module (ModuleScript →
-- cached → every controller sees the same instance) that owns:
--   • PROCEDURAL ARM POSING — overrides the two arms (shoulders + elbows) each frame so the character grips
--     the weapon with BOTH hands, raises it on ADS, and kicks on recoil. Legs/torso keep the default
--     Animator, so walk/idle locomotion is untouched.
--   • THE ADS CAMERA — hold-to-aim drops to an over-the-shoulder offset + a tighter FOV (zoom), faces the
--     character toward the aim, and a settling sway. Release returns to hip.
--   • RECOIL — a transient kick shared across the arm pose + the camera FOV.
--
-- HOW THE POSE WINS OVER THE ANIMATOR (standard R15 technique): the Humanoid Animator writes each Motor6D's
-- `.Transform` at Enum.RenderPriority.Character. We bind a step at Character+1 and re-write the four arm
-- joints AFTER it, so our pose renders. Poses are RELATIVE deltas (Transform layers on the joint C0).
--
-- AUTHORITY IS UNCHANGED. The shot is still the camera-centre raycast (FireController → server). ADS only
-- changes the CAMERA + the cosmetic arm pose, so this stays a safe, self-contained client layer with zero
-- gameplay coupling. Input lives in AimController.client.luau; FireController calls M.recoil() on a shot.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local M = {}

-- ── pose tunables (degrees; iterate these in Studio) ─────────────────────────────────────────────────
local function d(x, y, z)
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

-- RIFLE — trigger hand = RIGHT, support hand = LEFT (on the fore-end).
local RIFLE = {
	idle = { -- "low ready": rifle held diagonally across the chest, muzzle forward-down
		RightShoulder = d(-34, -10, 16),
		RightElbow = d(-50, 0, -10),
		LeftShoulder = d(-40, 28, -24),
		LeftElbow = d(-66, 0, 12),
	},
	aim = { -- "shouldered": rifle raised toward eye line, both hands up, tight
		RightShoulder = d(-88, -12, 10),
		RightElbow = d(-30, 0, -6),
		LeftShoulder = d(-82, 32, -16),
		LeftElbow = d(-56, 0, 8),
	},
}

-- ROD — the cast hand = RIGHT (rod butt), LEFT rests near the reel.
local ROD = {
	idle = {
		RightShoulder = d(-30, -6, 10),
		RightElbow = d(-60, 0, -12),
		LeftShoulder = d(-14, 8, -16),
		LeftElbow = d(-42, 0, 6),
	},
	aim = { -- rod swept back over the shoulder, wound for the cast
		RightShoulder = d(-126, -18, 16),
		RightElbow = d(-46, 0, -10),
		LeftShoulder = d(-22, 10, -18),
		LeftElbow = d(-48, 0, 6),
	},
}

local JOINT_NAMES = { "RightShoulder", "RightElbow", "LeftShoulder", "LeftElbow" }

-- ── camera tunables ──────────────────────────────────────────────────────────────────────────────────
local BASE_FOV = 70
local ADS_FOV = 48
local ADS_OFFSET = Vector3.new(2.0, 0.6, 0) -- over the right shoulder (Humanoid.CameraOffset)
local HIP_OFFSET = Vector3.new(0, 0, 0)

-- ── live state ───────────────────────────────────────────────────────────────────────────────────────
local joints = {} -- name -> Motor6D
local char, humanoid, hrp = nil, nil, nil
local mode = "none" -- "rifle" | "rod" | "none"
local aiming = false
local blend = 0 -- 0 = idle pose / hip cam, 1 = aim pose / ADS cam
local recoil = 0 -- arm kick, decays
local camRecoil = 0 -- fov kick, decays
local curOffset = Vector3.new(0, 0, 0)
local bound = false

-- R15 joint → its parent part. The Motor6Ds assemble a frame or two AFTER the limb parts, so binding is
-- LAZY + idempotent: re-run each frame until all four resolve (and re-resolve after a respawn). Binding once
-- in onChar raced the assembly and left joints empty → the arms never posed (the rifle hung at the hip).
local JOINT_PARENT = { RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm", LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm" }
local function bindJoints(c)
	for jointName, parentName in pairs(JOINT_PARENT) do
		if joints[jointName] == nil or joints[jointName].Parent == nil then
			local p = c:FindFirstChild(parentName)
			local j = p and p:FindFirstChild(jointName)
			-- accept BOTH joint kinds: classic Motor6D AND the new AnimationConstraint rig (this place's avatar
			-- uses AnimationConstraints — both expose a settable `.Transform` we override the same way).
			if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
				joints[jointName] = j
			end
		end
	end
end

local function currentPoses()
	if mode == "rifle" then
		return RIFLE.idle, RIFLE.aim
	elseif mode == "rod" then
		return ROD.idle, ROD.aim
	end
	return nil, nil
end

-- ── the per-frame driver (bound at Character+1 so it wins over the Animator) ──────────────────────────
local function onStep(dt)
	-- smooth the aim blend toward its target (snappy up, a touch slower settling)
	local target = aiming and 1 or 0
	local speed = (target > blend) and 13 or 9
	blend += (target - blend) * math.clamp(dt * speed, 0, 1)
	recoil = recoil * math.clamp(1 - dt * 9, 0, 1)
	camRecoil = camRecoil * math.clamp(1 - dt * 8, 0, 1)
	if recoil < 0.0005 then recoil = 0 end
	if camRecoil < 0.01 then camRecoil = 0 end

	-- ── arms ── (lazy-bind each frame so the joints resolve once they assemble / after a respawn)
	if char ~= nil then bindJoints(char) end
	local idlePose, hotPose = currentPoses()
	if idlePose ~= nil then
		local t = os.clock()
		local sway = (1 - blend * 0.65) -- a steadier hold when aiming (held breath)
		local breathe = CFrame.Angles(math.sin(t * 1.3) * 0.012 * sway, math.sin(t * 0.9) * 0.01 * sway, 0)
		for _, name in ipairs(JOINT_NAMES) do
			local j = joints[name]
			if j ~= nil and j.Parent ~= nil then
				local a, b = idlePose[name], hotPose[name]
				if a ~= nil and b ~= nil then
					local pose = a:Lerp(b, blend)
					if recoil > 0 then
						if name == "RightShoulder" then
							pose = pose * CFrame.Angles(math.rad(20 * recoil), 0, math.rad(-7 * recoil))
						elseif name == "LeftShoulder" then
							pose = pose * CFrame.Angles(math.rad(9 * recoil), 0, 0)
						end
					end
					if name == "RightShoulder" or name == "LeftShoulder" then
						pose = breathe * pose
					end
					j.Transform = pose
				end
			end
		end
	end

	-- ── camera (FOV zoom + over-shoulder offset + face-the-aim) ──
	if humanoid ~= nil and humanoid.Parent ~= nil then
		local goalFov = (BASE_FOV + (ADS_FOV - BASE_FOV) * blend) + camRecoil
		camera.FieldOfView = goalFov
		curOffset = curOffset:Lerp(HIP_OFFSET:Lerp(ADS_OFFSET, blend), math.clamp(dt * 10, 0, 1))
		humanoid.CameraOffset = curOffset
		-- while aiming, face the character toward the camera's horizontal look so the rifle points downrange.
		-- (workspace attr "WW_NoFaceAim" disables this — a debug/verification escape hatch so the aim pose can
		-- be viewed from the side; harmless in production, defaults off.)
		if (not workspace:GetAttribute("WW_NoFaceAim")) and blend > 0.04 and hrp ~= nil and hrp.Parent ~= nil then
			humanoid.AutoRotate = false
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				local pos = hrp.Position
				local goalCF = CFrame.lookAt(pos, pos + flat.Unit)
				hrp.CFrame = hrp.CFrame:Lerp(goalCF, math.clamp(dt * 14 * blend, 0, 1))
			end
		elseif humanoid.AutoRotate == false and blend <= 0.04 then
			humanoid.AutoRotate = true
		end
	end
end

local function ensureBound()
	if bound then return end
	bound = true
	RunService:BindToRenderStep("WildWorldArmRig", Enum.RenderPriority.Character.Value + 1, onStep)
end

-- ── public API ───────────────────────────────────────────────────────────────────────────────────────
function M.setMode(newMode)
	mode = newMode
	if newMode == "none" then
		aiming = false
	end
end

function M.setAiming(on)
	aiming = on and mode ~= "none"
end

function M.isAiming()
	return aiming
end

function M.aimAlpha()
	return blend
end

-- a transient kick on the arms + the camera FOV (FireController calls this on a shot)
function M.recoil(amount)
	amount = amount or 1
	recoil = math.clamp(recoil + amount, 0, 1.5)
	camRecoil = math.clamp(camRecoil + amount * 5, 0, 12)
end

-- the rod uses the same blend as the cast wind-up
function M.setRodWind(on)
	M.setAiming(on)
end

local function onChar(c)
	char = c
	humanoid = nil
	hrp = nil
	task.spawn(function()
		c:WaitForChild("RightUpperArm", 8)
		c:WaitForChild("LeftUpperArm", 8)
		humanoid = c:FindFirstChildOfClass("Humanoid")
		hrp = c:FindFirstChild("HumanoidRootPart")
		bindJoints(c)
		curOffset = Vector3.new(0, 0, 0)
		ensureBound()
	end)
end

if player.Character then
	onChar(player.Character)
end
player.CharacterAdded:Connect(onChar)

return M
