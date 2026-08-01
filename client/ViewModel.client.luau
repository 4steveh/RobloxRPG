--!nonstrict
-- STUDIO-ONLY. Puts the HuntingRifle in the character's right hand (third person) by cloning the template
-- the server publishes to ReplicatedStorage.WildWorldWeapons.
--
-- It used to rebuild the rifle here from ~20 hand-placed parts. That meant two definitions of the same
-- weapon — this one and whatever the aiming code assumed — and no way for the first-person view model to
-- know where the sights actually were. Now the geometry comes from src/config/ArtKit through
-- src/logic/ArtGen, is asserted headlessly, and carries its muzzle and sight-line anchors as attributes.
--
-- This script also starts the rest of the weapon-handling stack: Stance (sprint/crouch/aim-walk),
-- WeaponView (the first-person view model) and the scope overlay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local ArmRig = require(script.Parent:WaitForChild("ArmRig"))
local Stance = require(script.Parent:WaitForChild("Stance"))
local WeaponView = require(script.Parent:WaitForChild("WeaponView"))
local ScopeOverlay = require(script.Parent:WaitForChild("ScopeOverlay"))

-- WHERE THE RIFLE IS CARRIED, AND WHY IT IS NOT IN THE HAND.
--
-- This avatar is an AnimationConstraint rig, not Motor6D: its arm joints are AnimationConstraints and the
-- engine's animator rewrites their .Transform after any RenderStep priority, so ArmRig's procedural arm pose
-- is INERT here (verified live — the shoulder reads the idle animation's -5 degrees, not the rig's -34).
-- Overriding an AnimationConstraint rig needs an uploaded Animation asset, which cannot be authored from this
-- repository and would reintroduce exactly the asset dependency the art rewrite removed.
--
-- So the rifle is welded to the TORSO in a low-ready carry rather than to a hand whose pose we cannot
-- control. Third person then reads as a hunter carrying a rifle across the body — deliberate, and stable
-- whatever the locomotion animation does — and the SHOULDERING feel is delivered where the player actually
-- experiences it: the first-person view model, whose sights are aligned to the camera axis exactly.
-- Angled ACROSS the body, not straight ahead. A rifle carried parallel to the look direction is almost
-- entirely hidden behind the character from the default rear camera — it was there and measured correctly
-- and still read as "no gun". 30 degrees of yaw puts the muzzle clear of the left shoulder line so the
-- weapon is in the silhouette.
local CARRY = CFrame.new(0.62, -0.05, -0.15) * CFrame.Angles(math.rad(-8), math.rad(30), math.rad(6))
-- fallback if a torso is somehow absent
local HAND_GRIP = CFrame.new(0.05, -0.15, -0.5) * CFrame.Angles(math.rad(-6), 0, 0)

local function build(char)
	if char:FindFirstChild("HeldRifle") then
		return
	end
	-- prefer the torso (stable under any locomotion animation); fall back to the hand
	local anchor = char:FindFirstChild("UpperTorso") or char:WaitForChild("UpperTorso", 8)
	local mount = CARRY
	if anchor == nil then
		anchor = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
		mount = HAND_GRIP
	end
	if anchor == nil then
		return
	end
	-- WaitForChild on the FOLDER returns as soon as the folder replicates; its children may still be in
	-- flight, so the model needs its own wait. Missing this left the hunter empty-handed on every join.
	local root = ReplicatedStorage:WaitForChild("WildWorldWeapons", 20)
	local tpl = root and root:WaitForChild("HuntingRifle", 20)
	if tpl == nil then
		warn("[ViewModel] no published HuntingRifle template — the hunter will be empty-handed")
		return
	end

	local model = tpl:Clone()
	model.Name = "HeldRifle"
	local muzzle = tpl:GetAttribute("muzzle") or Vector3.new(0, 0.3, -3)

	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			local localCF = p.CFrame -- template parts are authored in the grip frame at the origin
			p.CFrame = anchor.CFrame * mount * localCF
			local w = Instance.new("Weld")
			w.Part0 = anchor
			w.Part1 = p
			w.C0 = anchor.CFrame:ToObjectSpace(p.CFrame)
			w.Parent = p
		end
	end

	-- the muzzle end (HuntingFeel reads it for the flash and tracer origin)
	local anchorPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if anchorPart ~= nil then
		local tip = Instance.new("Attachment")
		tip.Name = "BarrelTip"
		tip.Parent = anchorPart
		tip.WorldPosition = (anchor.CFrame * mount * CFrame.new(muzzle)).Position
	end

	model.Parent = char
	ArmRig.setMode("rifle")
end

local function onChar(char)
	task.defer(build, char)
end

if player.Character then
	onChar(player.Character)
end
player.CharacterAdded:Connect(onChar)

-- start the weapon-handling stack (idempotent: these bind once)
Stance.start()
WeaponView.start()

-- drive the scope picture off the same aim blend everything else uses
RunService.RenderStepped:Connect(function(dt)
	local blend = ArmRig.aimAlpha()
	-- the SAME threshold WeaponView uses to hide the model, so the overlay appears in the frame the model
	-- disappears and the swap is invisible
	local scoped = WeaponView.hasScope() and blend >= 0.88
	ScopeOverlay.setVisible(scoped)
	ScopeOverlay.update(dt, blend)
end)
