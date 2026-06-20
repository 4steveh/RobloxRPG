--!nonstrict
-- STUDIO-ONLY. The harvest / catch result "field-journal plaque" (SYS_harvest_screen). Renders ONLY the
-- server-sent `harvest` envelope; asserts nothing. Routine vs rare branches on mintedArtifactId (the Reward
-- XOR). Auto-dismisses; a rapid second catch cancels the prior card. "MOUNT IT" routes the mountTrophy intent
-- through the server (Net.lodge), which the gauntlet validates — the card never mints or changes disposition.
local Hud = require(script.Parent:WaitForChild("Hud"))

local M = {}

-- rarity-keyed accent (closed Enums.Rarity values; word + tier carry meaning too, so color is not load-bearing)
local RARITY_COLOR = {
	Common = Color3.fromRGB(220, 220, 205),
	Uncommon = Color3.fromRGB(150, 200, 140),
	Rare = Color3.fromRGB(110, 165, 215),
	Epic = Color3.fromRGB(180, 130, 220),
	Legendary = Color3.fromRGB(235, 195, 110),
	Mythic = Color3.fromRGB(150, 235, 225),
}
local BONE = Color3.fromRGB(235, 235, 220)

local function lbl(parent, text, pos, size, textSize, color, bold, center)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	l.TextSize = textSize
	l.TextColor3 = color or BONE
	l.TextXAlignment = if center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
	l.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	l.TextStrokeTransparency = 0.2 -- legibility over bright sky/snow/water
	l.Text = text
	l.Parent = parent
	return l
end

local token = 0

function M.show(harvest)
	token += 1
	local mine = token
	local old = Hud.gui:FindFirstChild("HarvestCard")
	if old then
		old:Destroy()
	end

	local rarity = harvest.rarity or "Common"
	local accent = RARITY_COLOR[rarity] or BONE
	local isRare = harvest.mintedArtifactId ~= nil

	local card = Instance.new("Frame")
	card.Name = "HarvestCard"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 0.72, 24) -- lower-center, above the action bar + tension gauge
	card.Size = UDim2.fromOffset(420, if isRare then 250 else 196)
	card.BackgroundColor3 = Color3.fromRGB(28, 24, 18) -- OPAQUE (not the 0.35 HUD panels) for contrast
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.Parent = Hud.gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = math.clamp(Hud.gui.AbsoluteSize.Y / 800, 0.8, 1.3)
	scale.Parent = card

	-- species name (headline) + rarity rule
	lbl(card, string.upper(harvest.name or "?"), UDim2.fromOffset(16, 14), UDim2.fromOffset(388, 30), 26, accent, true, true)
	local rule = Instance.new("Frame")
	rule.Position = UDim2.fromOffset(40, 50)
	rule.Size = UDim2.fromOffset(340, 2)
	rule.BackgroundColor3 = accent
	rule.BackgroundTransparency = 0.3
	rule.BorderSizePixel = 0
	rule.Parent = card

	-- rarity · tier line + NEW!
	lbl(card, string.format("%s · Tier %d", string.upper(rarity), harvest.tier or 0), UDim2.fromOffset(16, 60), UDim2.fromOffset(300, 20), 15, accent, false, false)
	if harvest.isNew then
		lbl(card, "NEW!", UDim2.new(1, -76, 0, 60), UDim2.fromOffset(60, 20), 15, Color3.fromRGB(255, 230, 120), true, true)
	end

	local y = 88
	local function statRow(name, value, valueColor)
		lbl(card, name, UDim2.fromOffset(16, y), UDim2.fromOffset(160, 22), 16, Color3.fromRGB(180, 180, 165), false, false)
		lbl(card, value, UDim2.fromOffset(180, y), UDim2.fromOffset(224, 22), 18, valueColor or BONE, true, false)
		y += 26
	end

	if harvest.weightLb ~= nil then
		statRow("WEIGHT", string.format("%.1f lb", harvest.weightLb) .. (if harvest.isRecord then "   ★ RECORD" else ""), if harvest.isRecord then Color3.fromRGB(255, 230, 120) else BONE)
	end
	if harvest.shotZone == "vital" then
		statRow("SHOT", "◇ HEADSHOT", Color3.fromRGB(150, 230, 140))
	end

	if isRare then
		if harvest.cleanKillMoment then
			lbl(card, '"' .. harvest.cleanKillMoment .. '"', UDim2.fromOffset(16, y), UDim2.fromOffset(388, 22), 15, accent, false, true)
			y += 26
		end
		lbl(card, "✶ ADDED TO COLLECTION ✶", UDim2.fromOffset(16, y), UDim2.fromOffset(388, 22), 16, accent, true, true)
		local mountBtn = Hud.button({ name = "MountBtn", text = "MOUNT IT", parent = card, anchor = Vector2.new(0, 1), position = UDim2.new(0, 16, 1, -12), size = UDim2.fromOffset(180, 44), color = Color3.fromRGB(70, 95, 60) })
		local keepBtn = Hud.button({ name = "KeepBtn", text = "Keep in Bag", parent = card, anchor = Vector2.new(1, 1), position = UDim2.new(1, -16, 1, -12), size = UDim2.fromOffset(170, 44), color = Color3.fromRGB(50, 50, 46) })
		mountBtn.Activated:Connect(function()
			local Net = require(script.Parent:WaitForChild("Net"))
			if Net.lodge ~= nil then
				Net.lodge:FireServer(harvest.mintedArtifactId)
				mountBtn.Text = "MOUNTED ✓"
				mountBtn.Active = false
			end
		end)
		keepBtn.Activated:Connect(function()
			if token == mine then
				card:Destroy()
			end
		end)
	else
		statRow("CATCH", "$ " .. tostring(harvest.cash), Color3.fromRGB(150, 230, 140))
		if harvest.boostCash and harvest.boostCash > 0 then
			statRow("BOOST", "+$ " .. tostring(harvest.boostCash), Color3.fromRGB(120, 210, 255))
		end
		if harvest.rankXP and harvest.rankXP > 0 then
			statRow(if harvest.loop == "Fishing" then "ANGLER XP" else "HUNTER XP", "+" .. tostring(harvest.rankXP))
		end
	end

	-- auto-dismiss (rare cards dwell longer); cancel if a newer card supersedes
	task.delay(if isRare then 6 else 3.5, function()
		if token == mine and card.Parent then
			card:Destroy()
		end
	end)
end

return M
