--!nonstrict
-- STUDIO-ONLY. The field inventory: a key (I) and an on-screen GEAR button toggle a panel listing the
-- player's OWNED equippable gear grouped by the four slots, with EQUIP buttons. Reuses the server's equip
-- intent via the vendor-free InventoryRequest channel. The client asserts NOTHING — it renders the server's
-- loadout and sends an instanceId; the server validates + equips. Swap-only; the held model is intentionally
-- static (tier-based held visuals are deferred). Mirrors ShopController's panel/render pattern.
local UserInputService = game:GetService("UserInputService")
local Net = require(script.Parent:WaitForChild("Net"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local SLOTS = { "weapon", "armor", "rod", "reel" }
local SLOT_TITLE = { weapon = "WEAPON", armor = "ARMOR", rod = "ROD", reel = "REEL" }

-- the panel
local panel = Instance.new("Frame")
panel.Name = "InventoryPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(430, 470)
panel.BackgroundColor3 = Color3.fromRGB(24, 28, 26)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = Hud.gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local function clearRows()
	for _, ch in panel:GetChildren() do
		if not ch:IsA("UIListLayout") then
			ch:Destroy()
		end
	end
end

local function row(height)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -16, 0, height)
	f.BackgroundTransparency = 1
	f.Parent = panel
	return f
end

local function rowLabel(parent, text, width, size, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(0, width, 1, 0)
	l.Position = UDim2.fromOffset(8, 0)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size or 15
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = color or Color3.fromRGB(235, 235, 220)
	l.Text = text
	l.Parent = parent
	return l
end

local function rowButton(parent, text, cb)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -6, 0.5, 0)
	b.Size = UDim2.fromOffset(104, 30)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.BackgroundColor3 = Color3.fromRGB(50, 90, 70)
	b.TextColor3 = Color3.fromRGB(240, 240, 230)
	b.Text = text
	b.Parent = parent
	b.Activated:Connect(cb)
	return b
end

local function render(loadout)
	clearRows()
	local titleRow = row(34)
	rowLabel(titleRow, "GEAR", 360, 20).Font = Enum.Font.GothamBold
	rowButton(titleRow, "X", function()
		panel.Visible = false
	end)
	for _, slot in SLOTS do
		rowLabel(row(20), SLOT_TITLE[slot], 400, 14, Color3.fromRGB(170, 200, 160))
		local items = loadout[slot]
		if items == nil or #items == 0 then
			rowLabel(row(26), "(none owned)", 300, 14, Color3.fromRGB(150, 150, 140))
		else
			for _, c in items do
				local r = row(36)
				local tag = c.equipped and "  [equipped]" or ""
				rowLabel(r, string.format("%s (T%d) Lv%d%s", c.name, c.tier, c.intraLevel, tag), 250)
				if not c.equipped then
					rowButton(r, "EQUIP", function()
						Net.inventory:FireServer("equip", c.instanceId)
					end)
				end
			end
		end
	end
	panel.Visible = true
end

local function toggle()
	if panel.Visible then
		panel.Visible = false
	else
		Net.inventory:FireServer("open") -- server replies "loadout" → render(...) shows the panel
	end
end

Net.inventory.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "loadout" then
		-- a = loadout, b = projection
		Hud.applyProjection(b)
		render(a)
	elseif kind == "equipped" then
		-- a = ok, b = reason, c = loadout, d = projection
		if a then
			Hud.applyProjection(d)
			render(c) -- keep the panel open + refresh the [equipped] tags
		else
			Hud.toast("equip failed: " .. tostring(b), Color3.fromRGB(230, 150, 140))
		end
	end
end)

-- input: I key (desktop) + an on-screen GEAR button (touch/console), placed above the FIRE button
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.I then
		toggle()
	end
end)

local gearBtn = Hud.button({
	name = "GearButton",
	text = "GEAR",
	position = UDim2.new(1, -20, 1, -215),
	size = UDim2.fromOffset(120, 48),
	color = Color3.fromRGB(60, 70, 90),
})
gearBtn.Activated:Connect(toggle)
