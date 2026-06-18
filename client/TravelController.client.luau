--!nonstrict
-- STUDIO-ONLY. Minimal fast-travel terminal (off the S1 milestone critical path — included for completeness).
-- Prompts on the travel signpost / Lodge travel desk open the world map; the server enforces the gate
-- (DestinationService.travelTo) and executes the within-place pivot. This script lists destinations and sends
-- the travel intent; it does NOT re-derive unlock state — a locked target is rejected server-side ("denied").
local Net = require(script.Parent:WaitForChild("Net"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local panel = Instance.new("Frame")
panel.Name = "TravelPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(320, 320)
panel.BackgroundColor3 = Color3.fromRGB(22, 26, 30)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = Hud.gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = panel

local function clear()
	for _, ch in panel:GetChildren() do
		if not ch:IsA("UIListLayout") then
			ch:Destroy()
		end
	end
end

local function button(text, color, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -12, 0, 40)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 16
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.fromRGB(240, 240, 230)
	b.Text = text
	b.Parent = panel
	b.Activated:Connect(cb)
	return b
end

local function renderMap(pins)
	clear()
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -12, 0, 32)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(235, 235, 220)
	title.Text = "World Map"
	title.Parent = panel
	for destId in pins do
		button(destId, Color3.fromRGB(50, 80, 70), function()
			Net.travel:FireServer("travel", destId)
		end)
	end
	button("CLOSE", Color3.fromRGB(70, 50, 50), function()
		panel.Visible = false
	end)
	panel.Visible = true
end

Net.travel.OnClientEvent:Connect(function(kind, a, b)
	if kind == "map" then
		renderMap(a) -- a = pins ({ [destId] = Pin })
	elseif kind == "traveling" then
		panel.Visible = false
		Hud.toast("Traveling to " .. tostring(a), Color3.fromRGB(150, 200, 230))
	elseif kind == "denied" then
		Hud.toast("Travel denied: " .. tostring(b), Color3.fromRGB(230, 150, 140))
	end
end)

local function attachPrompt(part)
	if part == nil or part:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "World Map"
	p.ObjectText = "Travel"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 12
	p.Parent = part
	p.Triggered:Connect(function()
		Net.travel:FireServer("openMap")
	end)
end

task.spawn(function()
	local bayou = workspace:WaitForChild("BayouShell_Placeholder", 30)
	if bayou then
		attachPrompt(bayou:FindFirstChild("TravelSignpost_Anchor"))
	end
	local lodge = workspace:WaitForChild("Lodge_Placeholder", 30)
	if lodge then
		attachPrompt(lodge:FindFirstChild("TravelDesk_WorldMap"))
	end
end)
