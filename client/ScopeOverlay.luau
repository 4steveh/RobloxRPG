--!nonstrict
-- STUDIO-ONLY ModuleScript. THE SCOPE PICTURE.
--
-- Shown only when the rifle is fully shouldered AND the weapon actually has a scope, so an iron-sighted
-- weapon never gets a scope ring.
--
-- BUILT WITHOUT ANY IMAGE ASSET. The usual way to mask a scope is a full-screen PNG with a transparent
-- circle, which means an uploaded asset that can fail to load on a cold client — the same failure mode that
-- made the old art pipeline unreproducible. Instead: a circular Frame (UICorner at half its size) with a
-- transparent fill and a BLACK UIStroke whose Thickness exceeds the screen diagonal. The stroke fills
-- everything outside the circle, so the circle becomes a hole in an opaque black field. No asset, no load
-- failure, and it scales to any viewport.
--
-- The reticle is four Frames and a dot, which is also what a real duplex reticle is.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local M = {}

local gui = Instance.new("ScreenGui")
gui.Name = "WildWorldScope"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- the circular hole
local ring = Instance.new("Frame")
ring.Name = "ScopeRing"
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.BackgroundTransparency = 1
ring.BorderSizePixel = 0
ring.Parent = gui
local ringCorner = Instance.new("UICorner")
ringCorner.CornerRadius = UDim.new(1, 0)
ringCorner.Parent = ring
-- the stroke IS the mask: thicker than the screen, so everything outside the circle is opaque black
local mask = Instance.new("UIStroke")
mask.Color = Color3.new(0, 0, 0)
mask.Thickness = 2000
mask.Transparency = 0
mask.Parent = ring

-- a soft inner shadow, so the edge of the glass is not a hard cut
local vignette = Instance.new("Frame")
vignette.Name = "Vignette"
vignette.AnchorPoint = Vector2.new(0.5, 0.5)
vignette.Position = UDim2.fromScale(0.5, 0.5)
vignette.BackgroundTransparency = 1
vignette.BorderSizePixel = 0
vignette.Parent = gui
local vCorner = Instance.new("UICorner")
vCorner.CornerRadius = UDim.new(1, 0)
vCorner.Parent = vignette
local vStroke = Instance.new("UIStroke")
vStroke.Color = Color3.new(0, 0, 0)
vStroke.Thickness = 26
vStroke.Transparency = 0.45
vStroke.Parent = vignette

-- ── duplex reticle ────────────────────────────────────────────────────────────────────────────────────
local reticle = Instance.new("Frame")
reticle.Name = "Reticle"
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Position = UDim2.fromScale(0.5, 0.5)
reticle.BackgroundTransparency = 1
reticle.Parent = gui

local function bar(name, anchor, pos, size)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = anchor
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	f.BorderSizePixel = 0
	f.Parent = reticle
	return f
end

-- a duplex has THICK outer bars that thin toward the centre: it draws the eye inward without hiding the
-- target behind the crosshair
local bars = {
	thickTop = bar("ThickTop", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), UDim2.fromOffset(4, 0)),
	thickBottom = bar("ThickBottom", Vector2.new(0.5, 1), UDim2.fromScale(0.5, 1), UDim2.fromOffset(4, 0)),
	thickLeft = bar("ThickLeft", Vector2.new(0, 0.5), UDim2.fromScale(0, 0.5), UDim2.fromOffset(0, 4)),
	thickRight = bar("ThickRight", Vector2.new(1, 0.5), UDim2.fromScale(1, 0.5), UDim2.fromOffset(0, 4)),
	thinV = bar("ThinV", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(1, 0)),
	thinH = bar("ThinH", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(0, 1)),
}
local dot = bar("Dot", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(3, 3))
local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot

-- ── layout ────────────────────────────────────────────────────────────────────────────────────────────
local function layout()
	local cam = workspace.CurrentCamera
	if cam == nil then
		return
	end
	local vp = cam.ViewportSize
	if vp.X < 8 or vp.Y < 8 then
		return -- ViewportSize is (0,0) for the first frames after joining
	end
	-- the scope picture is a circle inscribed in the SHORT screen axis, slightly inset
	local d = math.min(vp.X, vp.Y) * 0.82
	ring.Size = UDim2.fromOffset(d, d)
	vignette.Size = UDim2.fromOffset(d - 2, d - 2)
	reticle.Size = UDim2.fromOffset(d, d)

	local half = d * 0.5
	local thickLen = half * 0.42
	local thinLen = half * 0.58
	bars.thickTop.Size = UDim2.fromOffset(4, thickLen)
	bars.thickBottom.Size = UDim2.fromOffset(4, thickLen)
	bars.thickLeft.Size = UDim2.fromOffset(thickLen, 4)
	bars.thickRight.Size = UDim2.fromOffset(thickLen, 4)
	bars.thinV.Size = UDim2.fromOffset(1, thinLen * 2)
	bars.thinH.Size = UDim2.fromOffset(thinLen * 2, 1)
end

-- ── show / hide ───────────────────────────────────────────────────────────────────────────────────────
local shown = false

function M.setVisible(on)
	if shown == on then
		return
	end
	shown = on
	if on then
		layout()
		gui.Enabled = true
		-- the glass "opens" rather than snapping on: a scope picture that appears instantly reads as a UI
		-- panel, not as an eye arriving behind an eyepiece
		ring.Size = UDim2.fromOffset(ring.Size.X.Offset * 1.25, ring.Size.Y.Offset * 1.25)
		layout()
	else
		gui.Enabled = false
	end
end

-- Parallax: nudge the whole picture opposite to fast camera movement, so the eye box feels physical rather
-- than painted onto the screen.
local lastLook = nil
local offset = Vector2.zero
function M.update(dt, blend)
	if not shown then
		return
	end
	local cam = workspace.CurrentCamera
	if cam == nil then
		return
	end
	local look = cam.CFrame.LookVector
	if lastLook ~= nil then
		local dx = look:Cross(lastLook)
		offset = offset:Lerp(Vector2.new(math.clamp(dx.Y * 240, -26, 26), math.clamp((look.Y - lastLook.Y) * 240, -26, 26)), math.clamp(dt * 10, 0, 1))
	end
	lastLook = look
	ring.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
	vignette.Position = ring.Position
	reticle.Position = ring.Position
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(layout)
task.defer(layout)

return M
