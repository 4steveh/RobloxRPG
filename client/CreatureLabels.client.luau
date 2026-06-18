--!nonstrict
-- STUDIO-ONLY. Floating name + health bar over each huntable creature. Reads the server's maxHealth/
-- currentHealth attributes (set in WorldServer's buildCreatureModel + the on-hit update) and updates live
-- on every hit. Self-contained; attaches as creatures spawn into workspace.HuntingTargets, tears down with them.
local function attach(model)
	if not model:IsA("Model") or model:GetAttribute("maxHealth") == nil then
		return
	end
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if anchor == nil then
		return
	end

	local bg = Instance.new("BillboardGui")
	bg.Name = "CreatureLabel"
	bg.Size = UDim2.fromOffset(150, 36)
	bg.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	bg.AlwaysOnTop = true
	bg.MaxDistance = 220
	bg.Adornee = anchor
	bg.Parent = anchor

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 18)
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 14
	name.TextColor3 = Color3.fromRGB(235, 235, 220)
	name.TextStrokeTransparency = 0.4
	name.Text = model.Name
	name.Parent = bg

	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.new(0, 0, 0, 22)
	barBg.Size = UDim2.new(1, 0, 0, 8)
	barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	barBg.BorderSizePixel = 0
	barBg.Parent = bg

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(200, 80, 70)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = barBg

	local function refresh()
		local maxH = model:GetAttribute("maxHealth") or 1
		local cur = model:GetAttribute("currentHealth") or maxH
		local frac = math.clamp(cur / maxH, 0, 1)
		fill.Size = UDim2.fromScale(frac, 1)
		-- shade green→amber→red as it drains
		fill.BackgroundColor3 = Color3.fromRGB(200, 80, 70):Lerp(Color3.fromRGB(110, 200, 100), frac)
	end
	refresh()
	model:GetAttributeChangedSignal("currentHealth"):Connect(refresh)
end

local function start()
	local ht = workspace:WaitForChild("HuntingTargets", 30)
	if ht == nil then
		return
	end
	for _, m in ipairs(ht:GetChildren()) do
		attach(m)
	end
	ht.ChildAdded:Connect(attach)
end

task.spawn(start)
