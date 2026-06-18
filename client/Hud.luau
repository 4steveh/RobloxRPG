--!nonstrict
-- STUDIO-ONLY. The shared client HUD (singleton ModuleScript — Roblox caches the module result, so every
-- controller that requires it shares ONE ScreenGui). Owns: the Cash/EHT/EFT header (driven by the server's
-- read-only projection), payout-delta toasts, the center crosshair, a transient toast line, the fishing
-- tension gauge, and a styled-button factory the controllers use for their on-screen inputs. Renders ONLY
-- what the server sends; asserts nothing.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local M = {}

local gui = Instance.new("ScreenGui")
gui.Name = "WildWorldHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
M.gui = gui

local function label(parent, name, pos, size, textSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = Color3.fromRGB(235, 235, 220)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextSize = textSize
	l.Text = ""
	l.Parent = parent
	return l
end

-- header (Cash / tiers)
local header = Instance.new("Frame")
header.Name = "Header"
header.Position = UDim2.fromOffset(12, 12)
header.Size = UDim2.fromOffset(230, 64)
header.BackgroundColor3 = Color3.fromRGB(20, 24, 20)
header.BackgroundTransparency = 0.35
header.BorderSizePixel = 0
header.Parent = gui
local cashLabel = label(header, "Cash", UDim2.fromOffset(10, 6), UDim2.fromOffset(210, 26), 22)
local tierLabel = label(header, "Tiers", UDim2.fromOffset(10, 36), UDim2.fromOffset(210, 20), 14)
cashLabel.Text = "$ —"
tierLabel.Text = "EHT — · EFT —"

-- crosshair
local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.Size = UDim2.fromOffset(6, 6)
crosshair.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
crosshair.BackgroundTransparency = 0.2
crosshair.BorderSizePixel = 0
crosshair.Parent = gui

-- toast
local toast = label(gui, "Toast", UDim2.new(0.5, -200, 0.16, 0), UDim2.fromOffset(400, 28), 20)
toast.TextXAlignment = Enum.TextXAlignment.Center
toast.TextStrokeTransparency = 0.4
local toastToken = 0
function M.toast(text, color)
	toastToken += 1
	local mine = toastToken
	toast.Text = text
	toast.TextColor3 = color or Color3.fromRGB(235, 235, 220)
	task.delay(2.5, function()
		if toastToken == mine then
			toast.Text = ""
		end
	end)
end

-- tension gauge (fishing)
local gaugeBack = Instance.new("Frame")
gaugeBack.Name = "Gauge"
gaugeBack.AnchorPoint = Vector2.new(0.5, 1)
gaugeBack.Position = UDim2.new(0.5, 0, 0.86, 0)
gaugeBack.Size = UDim2.fromOffset(260, 18)
gaugeBack.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
gaugeBack.BackgroundTransparency = 0.25
gaugeBack.BorderSizePixel = 0
gaugeBack.Visible = false
gaugeBack.Parent = gui
local gaugeFill = Instance.new("Frame")
gaugeFill.Name = "Fill"
gaugeFill.Size = UDim2.fromScale(0, 1)
gaugeFill.BackgroundColor3 = Color3.fromRGB(90, 180, 220)
gaugeFill.BorderSizePixel = 0
gaugeFill.Parent = gaugeBack
function M.setGauge(visible, fraction)
	gaugeBack.Visible = visible
	if fraction ~= nil then
		gaugeFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	end
end

-- projection → header (tracks last balance for payout deltas)
local lastBalance = nil
function M.applyProjection(proj)
	if proj == nil then
		return
	end
	if proj.balance ~= nil then
		if lastBalance ~= nil and proj.balance > lastBalance then
			M.toast("+$" .. tostring(proj.balance - lastBalance), Color3.fromRGB(150, 230, 140))
		end
		cashLabel.Text = "$ " .. tostring(proj.balance)
		lastBalance = proj.balance
	end
	tierLabel.Text = string.format("EHT %s · EFT %s", tostring(proj.eht), tostring(proj.eft))
end
function M.balance()
	return lastBalance
end

-- styled-button factory (controllers own their input logic)
function M.button(opts)
	local b = Instance.new("TextButton")
	b.Name = opts.name or "Button"
	b.AnchorPoint = opts.anchor or Vector2.new(1, 1)
	b.Position = opts.position
	b.Size = opts.size or UDim2.fromOffset(120, 48)
	b.BackgroundColor3 = opts.color or Color3.fromRGB(40, 60, 50)
	b.BackgroundTransparency = 0.1
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = opts.textSize or 18
	b.TextColor3 = Color3.fromRGB(240, 240, 230)
	b.Text = opts.text or ""
	b.Parent = opts.parent or gui
	return b
end

return M
