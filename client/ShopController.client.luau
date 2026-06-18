--!nonstrict
-- STUDIO-ONLY. The Outfitter / Tackle Shop terminal. Attaches ProximityPrompts to the vendor parts the server
-- builds (Bayou shell anchors + Lodge fixtures), opens a minimal buy/equip/upgrade panel from the server's
-- listing, and routes the player's choice through ShopRequest. The client asserts NOTHING — it shows the
-- server's prices/ownership and sends an itemId/instanceId; the server validates + debits.
local Net = require(script.Parent:WaitForChild("Net"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local VENDORS = { Outfitter = true, TackleShop = true }
local currentBalance = nil

-- the panel
local panel = Instance.new("Frame")
panel.Name = "ShopPanel"
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

local function rowLabel(parent, text, width, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(0, width, 1, 0)
	l.Position = UDim2.fromOffset(8, 0)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size or 15
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = Color3.fromRGB(235, 235, 220)
	l.Text = text
	l.Parent = parent
	return l
end

local function rowButton(parent, text, enabled, cb)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -6, 0.5, 0)
	b.Size = UDim2.fromOffset(104, 30)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.BackgroundColor3 = enabled and Color3.fromRGB(50, 90, 70) or Color3.fromRGB(60, 60, 60)
	b.TextColor3 = Color3.fromRGB(240, 240, 230)
	b.AutoButtonColor = enabled
	b.Text = text
	b.Parent = parent
	if enabled and cb ~= nil then
		b.Activated:Connect(cb)
	end
	return b
end

local function render(vendor, listing, projection)
	if projection ~= nil and projection.balance ~= nil then
		currentBalance = projection.balance
	end
	clearRows()
	local title = rowLabel(row(34), vendor .. "   $ " .. tostring(currentBalance or "—"), 400, 20)
	title.Font = Enum.Font.GothamBold

	rowLabel(row(20), "For sale", 400).TextColor3 = Color3.fromRGB(170, 200, 160)
	for _, it in listing.forSale do
		local r = row(36)
		rowLabel(r, string.format("%s (T%d) — $%d", it.name, it.tier, it.price), 270)
		if it.owned then
			rowButton(r, "owned", false, nil)
		else
			local canAfford = currentBalance ~= nil and currentBalance >= it.price
			rowButton(r, canAfford and "BUY" or "need $", canAfford, function()
				Net.shop:FireServer("buy", it.itemId, vendor)
			end)
		end
	end

	rowLabel(row(20), "Your gear", 400).TextColor3 = Color3.fromRGB(170, 200, 160)
	for _, c in listing.owned do
		local r = row(36)
		local tag = c.equipped and "  [equipped]" or ""
		rowLabel(r, string.format("%s (T%d) Lv%d%s", c.name, c.tier, c.intraLevel, tag), 250)
		if not c.equipped then
			rowButton(r, "EQUIP", true, function()
				Net.shop:FireServer("equip", c.instanceId, vendor)
			end)
		elseif c.intraLevel < 2 then
			rowButton(r, "UPGRADE", true, function()
				Net.shop:FireServer("upgrade", c.instanceId, vendor)
			end)
		end
	end

	rowButton(row(40), "CLOSE", true, function()
		panel.Visible = false
	end)
	panel.Visible = true
end

Net.shop.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "listing" then
		Hud.applyProjection(c) -- c = projection
		render(a, b, c) -- a = vendor, b = listing, c = projection
	elseif kind == "result" then
		-- a = op, b = ok, c = reason
		if b then
			Hud.toast(tostring(a) .. " ok", Color3.fromRGB(150, 230, 140)) -- a fresh "listing" follows + re-renders
		else
			Hud.toast(tostring(a) .. " failed: " .. tostring(c), Color3.fromRGB(230, 150, 140))
		end
	end
end)

-- attach proximity prompts to the server-built vendor anchors + Lodge fixtures
local function attachPrompt(part, vendor)
	if part:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Open " .. vendor
	p.ObjectText = vendor
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 12
	p.Parent = part
	p.Triggered:Connect(function()
		Net.shop:FireServer("open", vendor)
	end)
end

local function vendorFromName(name)
	local base = (string.gsub(name, "_Anchor$", "")) -- "Outfitter_Anchor"→"Outfitter"; "TackleShop"→"TackleShop"
	if VENDORS[base] then
		return base
	end
	return nil
end

local function scan(container)
	if container == nil then
		return
	end
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then
			local v = vendorFromName(d.Name)
			if v ~= nil then
				attachPrompt(d, v)
			end
		end
	end
end

task.spawn(function()
	scan(workspace:WaitForChild("BayouShell_Placeholder", 30))
	scan(workspace:WaitForChild("Lodge_Placeholder", 30))
end)
