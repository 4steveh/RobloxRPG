--!nonstrict
-- STUDIO-ONLY. WORLD-SPACE WAYPOINT to the current onboarding objective (review §6 / roadmap 1.6 — the game
-- gave a new player ZERO sense of where to go). Reads the objective's target KIND from the HUD (which the
-- server populates via proj.onboarding) and points the player at the live target with:
--   • a Beam from the player to the target,
--   • a pulsing marker + distance above the target,
--   • a screen-edge arrow when the target is off-screen.
-- Focuses on the early hunt/fish beats (clear live targets — creatures, bites); the later shop/travel beats
-- are reached via the Lodge + HUD buttons, so the waypoint hides for those if it can't resolve a target.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Hud = require(script.Parent:WaitForChild("Hud"))
local cam = workspace.CurrentCamera

local ACCENT = Color3.fromRGB(150, 225, 135)

-- the moving anchor at the target (carries the beam end + the marker)
local targetAnchor = Instance.new("Part")
targetAnchor.Name = "WaypointTarget"
targetAnchor.Anchored, targetAnchor.CanCollide, targetAnchor.CanQuery = true, false, false
targetAnchor.Transparency = 1
targetAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
targetAnchor.Parent = workspace
local targetAtt = Instance.new("Attachment")
targetAtt.Parent = targetAnchor

local markerBB = Instance.new("BillboardGui")
markerBB.Name = "WaypointMarker"
markerBB.Size = UDim2.fromOffset(56, 60)
markerBB.StudsOffset = Vector3.new(0, 4.5, 0)
markerBB.AlwaysOnTop = true
markerBB.Adornee = targetAnchor
markerBB.Enabled = false
markerBB.Parent = targetAnchor
local markerIcon = Instance.new("TextLabel")
markerIcon.BackgroundTransparency = 1
markerIcon.Size = UDim2.new(1, 0, 0, 34)
markerIcon.Font = Enum.Font.GothamBold
markerIcon.TextSize = 30
markerIcon.TextColor3 = ACCENT
markerIcon.TextStrokeTransparency = 0.25
markerIcon.Text = "◆"
markerIcon.Parent = markerBB
local markerDist = Instance.new("TextLabel")
markerDist.BackgroundTransparency = 1
markerDist.Position = UDim2.new(0, 0, 0, 34)
markerDist.Size = UDim2.new(1, 0, 0, 18)
markerDist.Font = Enum.Font.GothamBold
markerDist.TextSize = 13
markerDist.TextColor3 = Color3.fromRGB(235, 235, 220)
markerDist.TextStrokeTransparency = 0.4
markerDist.Text = ""
markerDist.Parent = markerBB

local beam = Instance.new("Beam")
beam.Attachment1 = targetAtt
beam.Width0, beam.Width1 = 0.6, 0.6
beam.FaceCamera = true
beam.Color = ColorSequence.new(ACCENT)
beam.Transparency = NumberSequence.new(0.4)
beam.LightInfluence = 0
beam.Enabled = false
beam.Parent = targetAnchor

-- screen-edge arrow
local sg = Instance.new("ScreenGui")
sg.Name = "WaypointArrow"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.Parent = player:WaitForChild("PlayerGui")
local arrow = Instance.new("TextLabel")
arrow.AnchorPoint = Vector2.new(0.5, 0.5)
arrow.Size = UDim2.fromOffset(44, 44)
arrow.BackgroundTransparency = 1
arrow.Font = Enum.Font.GothamBold
arrow.TextSize = 36
arrow.TextColor3 = ACCENT
arrow.TextStrokeTransparency = 0.3
arrow.Text = "➤"
arrow.Visible = false
arrow.Parent = sg

local hrpAtt = nil

local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function ensureHrpAtt()
	local root = hrp()
	if root == nil then
		return nil
	end
	if hrpAtt == nil or hrpAtt.Parent ~= root then
		hrpAtt = root:FindFirstChild("WaypointHrpAtt") or Instance.new("Attachment")
		hrpAtt.Name = "WaypointHrpAtt"
		hrpAtt.Parent = root
		beam.Attachment0 = hrpAtt
	end
	return hrpAtt
end

local function nearestInFolder(folderName, origin)
	local f = workspace:FindFirstChild(folderName)
	if f == nil then
		return nil
	end
	local best, bd = nil, math.huge
	for _, m in ipairs(f:GetChildren()) do
		local p = (m:IsA("Model") and m.PrimaryPart and m.PrimaryPart.Position)
			or (m:IsA("BasePart") and m.Position)
		if p then
			local d = (p - origin).Magnitude
			if d < bd then
				bd, best = d, p
			end
		end
	end
	return best
end

local function findNamed(substr, origin)
	local best, bd = nil, math.huge
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, substr) then
			local dist = (d.Position - origin).Magnitude
			if dist < bd then
				bd, best = dist, d.Position
			end
		end
	end
	return best
end

local function targetPosFor(kind, origin)
	if kind == "hunt" then
		return nearestInFolder("HuntingTargets", origin)
	elseif kind == "fish" then
		return nearestInFolder("FishingBites", origin)
	elseif kind == "shop" then
		return findNamed("Outfitter", origin)
	elseif kind == "travelDesk" then
		return findNamed("Travel", origin)
	end
	return nil
end

local function hideAll()
	beam.Enabled = false
	markerBB.Enabled = false
	arrow.Visible = false
end

RunService.RenderStepped:Connect(function()
	local ob = Hud.currentObjective and Hud.currentObjective()
	local root = hrp()
	if ob == nil or ob.complete or root == nil or ensureHrpAtt() == nil then
		hideAll()
		return
	end
	local pos = targetPosFor(ob.targetKind, root.Position)
	if pos == nil then
		hideAll()
		return
	end
	targetAnchor.Position = pos
	beam.Enabled = true
	markerBB.Enabled = true
	-- pulse the marker + distance
	local pulse = 0.7 + 0.3 * math.abs(math.sin(os.clock() * 3))
	markerIcon.TextTransparency = 1 - pulse
	markerDist.Text = string.format("%dm", math.floor((pos - root.Position).Magnitude))
	-- screen-edge arrow when the target is off-screen / behind the camera
	local sp = cam:WorldToViewportPoint(pos)
	local vp = cam.ViewportSize
	local onScreen = sp.Z > 0 and sp.X > 0 and sp.X < vp.X and sp.Y > 0 and sp.Y < vp.Y
	if onScreen then
		arrow.Visible = false
	else
		local dir = Vector2.new(sp.X, sp.Y) - Vector2.new(vp.X / 2, vp.Y / 2)
		if sp.Z < 0 then
			dir = -dir
		end
		if dir.Magnitude < 1 then
			dir = Vector2.new(0, -1)
		end
		dir = dir.Unit
		local margin = 64
		local ex = math.clamp(vp.X / 2 + dir.X * vp.X, margin, vp.X - margin)
		local ey = math.clamp(vp.Y / 2 + dir.Y * vp.Y, margin, vp.Y - margin)
		arrow.Position = UDim2.fromOffset(ex, ey)
		arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X))
		arrow.Visible = true
	end
end)
