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

-- thousands-separated cash (modern read: "$ 12,480" not "$ 12480")
local function commafmt(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- the MVL unlock path (after the free Bayou) — used to surface the "next goal" from proj.gates.
local DEST_ORDER = { "appalachia", "rockies", "alaska", "deep_sea" }
local DEST_NAMES = { appalachia = "Appalachia", rockies = "The Rockies", alaska = "Alaska", deep_sea = "The Deep Sea" }

local gui = Instance.new("ScreenGui")
gui.Name = "WildWorldHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
M.gui = gui


local TweenService = game:GetService("TweenService")
local UISound = require(script.Parent:WaitForChild("UISound"))
M.sound = UISound

-- ── UI MOTION ──────────────────────────────────────────────────────────────────────────────────────
-- Every panel in this game appeared and disappeared as a hard cut: Visible = true. Nothing moved, so
-- nothing had weight, and a UI where nothing moves reads as a debug overlay no matter how it is styled.
-- These are the two primitives every surface now goes through.
local EASE_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local EASE_IN = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- Show a frame with a small scale-and-fade pop. `baseSize` is remembered per instance, so repeated calls
-- do not compound the scale-down and shrink the panel away to nothing.
local baseSizes = {}
function M.popIn(frame, sound)
	if frame == nil then
		return
	end
	local base = baseSizes[frame]
	if base == nil then
		base = frame.Size
		baseSizes[frame] = base
	end
	frame.Visible = true
	frame.Size = UDim2.new(base.X.Scale * 0.94, base.X.Offset * 0.94, base.Y.Scale * 0.94, base.Y.Offset * 0.94)
	TweenService:Create(frame, EASE_OUT, { Size = base }):Play()
	if sound ~= false then
		UISound.play(sound or "open")
	end
end

function M.popOut(frame, sound)
	if frame == nil or not frame.Visible then
		return
	end
	local base = baseSizes[frame] or frame.Size
    local t = TweenService:Create(frame, EASE_IN, {
		Size = UDim2.new(base.X.Scale * 0.94, base.X.Offset * 0.94, base.Y.Scale * 0.94, base.Y.Offset * 0.94),
	})
	t:Play()
	t.Completed:Once(function()
		frame.Visible = false
		frame.Size = base
	end)
	if sound ~= false then
		UISound.play(sound or "close")
	end
end

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
local headerCorner = Instance.new("UICorner"); headerCorner.CornerRadius = UDim.new(0, 8); headerCorner.Parent = header
local headerStroke = Instance.new("UIStroke"); headerStroke.Color = Color3.fromRGB(120, 140, 110); headerStroke.Thickness = 1; headerStroke.Transparency = 0.55; headerStroke.Parent = header
local cashLabel = label(header, "Cash", UDim2.fromOffset(10, 6), UDim2.fromOffset(210, 26), 22)
local tierLabel = label(header, "Tiers", UDim2.fromOffset(10, 36), UDim2.fromOffset(210, 20), 14)
cashLabel.Text = "$ —"
tierLabel.Text = "EHT — · EFT —"

-- next-goal panel: renders the next locked destination's gate reasons, so e.g. "Reach Tier-2 — buy weapon
-- AND armor" is on screen instead of EHT silently dropping. The server already ships proj.gates[*].unmetReasons.
local goalFrame = Instance.new("Frame")
goalFrame.Name = "NextGoal"
goalFrame.Position = UDim2.fromOffset(12, 84)
goalFrame.Size = UDim2.fromOffset(344, 58)
goalFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 20)
goalFrame.BackgroundTransparency = 0.35
goalFrame.BorderSizePixel = 0
goalFrame.Visible = false
goalFrame.Parent = gui
local goalTitle = label(goalFrame, "GoalTitle", UDim2.fromOffset(10, 4), UDim2.fromOffset(322, 16), 12)
goalTitle.TextColor3 = Color3.fromRGB(170, 200, 160)
local goalBody = label(goalFrame, "GoalBody", UDim2.fromOffset(10, 20), UDim2.fromOffset(324, 34), 12)
goalBody.TextWrapped = true
goalBody.TextYAlignment = Enum.TextYAlignment.Top

-- crosshair — a 4-tick reticle + centre dot that TIGHTENS on ADS (review 2.2). The ticks live in a
-- container at screen centre; setAimState() tweens their spread + colour (wide/dim at hip → tight/crisp on aim).
local TweenSvc = game:GetService("TweenService")
local reticle = Instance.new("Frame")
reticle.Name = "Crosshair"
reticle.AnchorPoint = Vector2.new(0.5, 0.5)
reticle.Position = UDim2.fromScale(0.5, 0.5)
reticle.Size = UDim2.fromOffset(2, 2)
reticle.BackgroundTransparency = 1
reticle.Parent = gui
local function tick(name)
	local t = Instance.new("Frame")
	t.Name = name
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.BackgroundColor3 = Color3.fromRGB(240, 240, 230)
	t.BackgroundTransparency = 0.15
	t.BorderSizePixel = 0
	t.Parent = reticle
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 2)
	c.Parent = t
	return t
end
local dot = tick("Dot")
dot.Size = UDim2.fromOffset(3, 3)
dot.Position = UDim2.fromScale(0.5, 0.5)
local tickN, tickS, tickE, tickW = tick("N"), tick("S"), tick("E"), tick("W")
local HIP_SPREAD, ADS_SPREAD = 14, 7
local function layoutReticle(spread, thin, alpha, color)
	local len = 7
	for _, t in ipairs({ tickN, tickS }) do t.Size = UDim2.fromOffset(thin, len) end
	for _, t in ipairs({ tickE, tickW }) do t.Size = UDim2.fromOffset(len, thin) end
	tickN.Position = UDim2.new(0.5, 0, 0.5, -spread)
	tickS.Position = UDim2.new(0.5, 0, 0.5, spread)
	tickE.Position = UDim2.new(0.5, spread, 0.5, 0)
	tickW.Position = UDim2.new(0.5, -spread, 0.5, 0)
	for _, t in ipairs({ tickN, tickS, tickE, tickW, dot }) do
		t.BackgroundTransparency = alpha
		t.BackgroundColor3 = color
	end
end
layoutReticle(HIP_SPREAD, 2, 0.3, Color3.fromRGB(240, 240, 230))
-- public: tighten/brighten the reticle on ADS (called by AimController)
local aimTweens = {}
function M.setAimState(on)
	for _, tw in ipairs(aimTweens) do tw:Cancel() end
	aimTweens = {}
	local spread = on and ADS_SPREAD or HIP_SPREAD
	local alpha = on and 0.05 or 0.3
	local color = on and Color3.fromRGB(150, 230, 150) or Color3.fromRGB(240, 240, 230)
	local info = TweenInfo.new(0.16, Enum.EasingStyle.Quad)
	tickN.Position = tickN.Position -- (no-op; keep refs)
	for _, spec in ipairs({
		{ tickN, UDim2.new(0.5, 0, 0.5, -spread) }, { tickS, UDim2.new(0.5, 0, 0.5, spread) },
		{ tickE, UDim2.new(0.5, spread, 0.5, 0) }, { tickW, UDim2.new(0.5, -spread, 0.5, 0) },
	}) do
		local tw = TweenSvc:Create(spec[1], info, { Position = spec[2], BackgroundTransparency = alpha, BackgroundColor3 = color })
		tw:Play(); table.insert(aimTweens, tw)
	end
	local td = TweenSvc:Create(dot, info, { BackgroundTransparency = alpha, BackgroundColor3 = color })
	td:Play(); table.insert(aimTweens, td)
end

-- toast
local toast = label(gui, "Toast", UDim2.new(0.5, -200, 0.16, 0), UDim2.fromOffset(400, 28), 20)
toast.TextXAlignment = Enum.TextXAlignment.Center
toast.TextStrokeTransparency = 0.4
local toastToken = 0
local TOAST_HOME = toast.Position
function M.toast(text, color)
	toastToken += 1
	local mine = toastToken
	toast.Text = text
	toast.TextColor3 = color or Color3.fromRGB(235, 235, 220)
	-- rise into place and fade out on the way up: a line that simply blinks on and off is easy to miss
	-- entirely, which is exactly what happened to the old payout toast.
	toast.Position = TOAST_HOME + UDim2.fromOffset(0, 14)
	toast.TextTransparency = 1
	toast.TextStrokeTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = TOAST_HOME,
		TextTransparency = 0,
		TextStrokeTransparency = 0.4,
	}):Play()
	task.delay(2.2, function()
		if toastToken ~= mine then
			return
		end
		local out = TweenService:Create(toast, TweenInfo.new(0.45), {
			Position = TOAST_HOME - UDim2.fromOffset(0, 16),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		out:Play()
		out.Completed:Once(function()
			if toastToken == mine then
				toast.Text = ""
			end
		end)
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
local gaugeShown = false
function M.setGauge(visible, fraction)
	if visible and not gaugeShown then
		gaugeShown = true
		M.popIn(gaugeBack, false)
	elseif not visible and gaugeShown then
		gaugeShown = false
		M.popOut(gaugeBack, false)
	end
	if fraction ~= nil then
		-- tension is a continuous quantity; snapping the bar to each sampled value throws away the fact
		-- that it is RISING, which is the only thing the player is reading off it.
		TweenService:Create(gaugeFill, TweenInfo.new(0.09, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
		}):Play()
	end
end

-- projection → header (tracks last balance for payout deltas). The FIRST projection sets the baseline
-- SILENTLY (lastBalance starts nil): there is no login-time projection push, so the first projection IS the
-- first payout and we have no prior balance to diff against. The Cash header still updates, and the
-- kill/catch controllers fire their own "Down!"/"Landed!" toast, so the first payout is still visible.
-- (A login-time projection push would let the first payout show its +$ delta too — deferred, see spec §9.)
local lastBalance = nil
local cashToken = 0
-- A brief scale-and-colour pulse on the cash header, so a payout registers even if the player's eyes are
-- on the animal rather than the corner of the screen.
local function cashPulse()
	cashLabel.TextColor3 = Color3.fromRGB(168, 240, 150)
	local base = cashLabel.TextSize
	cashLabel.TextSize = base + 4
	TweenService:Create(cashLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		TextSize = base,
		TextColor3 = Color3.fromRGB(235, 235, 220),
	}):Play()
end
-- Weather countdown chip (top-center): "Storm · next 02:14" — a server-time target, client display only.
local RunService = game:GetService("RunService")
local weatherChip = label(gui, "WeatherChip", UDim2.new(0.5, -110, 0, 10), UDim2.fromOffset(220, 22), 15)
weatherChip.TextXAlignment = Enum.TextXAlignment.Center
weatherChip.TextStrokeTransparency = 0.4
weatherChip.Visible = false
local countdownTarget = nil
local countdownWeather = nil
local function fmtMMSS(secs)
	secs = math.max(0, math.floor(secs))
	return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end
function M.setCountdown(nextWindowChangeAt, activeWeather, _activeTraits)
	countdownTarget = nextWindowChangeAt
	countdownWeather = activeWeather
	weatherChip.Visible = nextWindowChangeAt ~= nil
end
RunService.Heartbeat:Connect(function()
	if countdownTarget == nil then
		return
	end
	local remaining = countdownTarget - workspace:GetServerTimeNow()
	local w = countdownWeather and (tostring(countdownWeather):gsub("^%l", string.upper)) or "Clear"
	weatherChip.Text = w .. " · next " .. fmtMMSS(remaining)
end)

-- ── OBJECTIVE CARD — the first-session DIRECTION the game was missing (review §6). The server now ships the
-- onboarding beat in proj.onboarding (beat + targetKind + progress); the CLIENT owns the wording. Top-center,
-- can't-miss; hides once the funnel is COMPLETE (then the next-goal panel carries destination unlocks).
local OBJECTIVE_COPY: { [string]: string } = {
	FIRST_HUNT = "Take aim and bag your first animal",
	FIRST_CATCH = "Head to the water and catch your first fish",
	FIRST_PURCHASE = "Visit a shop and upgrade your gear",
	WORLD_MAP = "Open the World Map at the Travel Desk",
	LOOP_CONFIRM = "Keep hunting or fishing to build your stake",
	DAILY_INTRO = "Claim your daily reward",
}
local objCard = Instance.new("Frame")
objCard.Name = "ObjectiveCard"
objCard.AnchorPoint = Vector2.new(0.5, 0)
objCard.Position = UDim2.new(0.5, 0, 0, 40)
objCard.Size = UDim2.fromOffset(348, 48)
objCard.BackgroundColor3 = Color3.fromRGB(22, 27, 22)
objCard.BackgroundTransparency = 0.15
objCard.BorderSizePixel = 0
objCard.Visible = false
objCard.Parent = gui
local objCorner = Instance.new("UICorner"); objCorner.CornerRadius = UDim.new(0, 8); objCorner.Parent = objCard
local objStroke = Instance.new("UIStroke"); objStroke.Color = Color3.fromRGB(150, 200, 140); objStroke.Thickness = 1.5; objStroke.Transparency = 0.35; objStroke.Parent = objCard
local objAccent = Instance.new("Frame"); objAccent.Size = UDim2.new(0, 4, 1, -10); objAccent.Position = UDim2.fromOffset(6, 5); objAccent.BackgroundColor3 = Color3.fromRGB(150, 220, 130); objAccent.BorderSizePixel = 0; objAccent.Parent = objCard
local objAccentC = Instance.new("UICorner"); objAccentC.CornerRadius = UDim.new(0, 2); objAccentC.Parent = objAccent
local objTitle = Instance.new("TextLabel")
objTitle.BackgroundTransparency = 1; objTitle.Position = UDim2.fromOffset(18, 5); objTitle.Size = UDim2.new(1, -90, 0, 13)
objTitle.Font = Enum.Font.GothamBold; objTitle.TextSize = 10; objTitle.TextXAlignment = Enum.TextXAlignment.Left
objTitle.TextColor3 = Color3.fromRGB(150, 210, 140); objTitle.Text = "NEXT OBJECTIVE"; objTitle.Parent = objCard
local objLabel = Instance.new("TextLabel")
objLabel.BackgroundTransparency = 1; objLabel.Position = UDim2.fromOffset(18, 19); objLabel.Size = UDim2.new(1, -96, 0, 24)
objLabel.Font = Enum.Font.GothamSemibold; objLabel.TextSize = 16; objLabel.TextXAlignment = Enum.TextXAlignment.Left
objLabel.TextColor3 = Color3.fromRGB(240, 240, 230); objLabel.TextStrokeTransparency = 0.6; objLabel.Text = ""; objLabel.Parent = objCard
local objProgress = Instance.new("TextLabel")
objProgress.BackgroundTransparency = 1; objProgress.AnchorPoint = Vector2.new(1, 0.5); objProgress.Position = UDim2.new(1, -12, 0.5, 0); objProgress.Size = UDim2.fromOffset(58, 30)
objProgress.Font = Enum.Font.GothamBold; objProgress.TextSize = 17; objProgress.TextXAlignment = Enum.TextXAlignment.Right
objProgress.TextColor3 = Color3.fromRGB(150, 230, 140); objProgress.Text = ""; objProgress.Parent = objCard
local lastObjective = nil
-- the waypoint controller reads this (the HUD always holds the latest projection, from StateSync + kill/catch replies)
function M.currentObjective()
	return lastObjective
end
function M.setObjective(ob)
	lastObjective = ob
	if ob == nil or ob.complete or ob.beat == "COMPLETE" then
		objCard.Visible = false
		return
	end
	local text = OBJECTIVE_COPY[ob.beat]
	if text == nil then
		objCard.Visible = false
		return
	end
	objLabel.Text = text
	objProgress.Text = ((ob.requiredCount or 1) > 1) and string.format("%d/%d", ob.progress or 0, ob.requiredCount) or ""
	objCard.Visible = true
end

function M.applyProjection(proj)
	if proj == nil then
		return
	end
	if proj.balance ~= nil then
		local gained = lastBalance ~= nil and proj.balance > lastBalance
		if gained then
			M.toast("+$" .. tostring(proj.balance - lastBalance), Color3.fromRGB(150, 230, 140))
			-- a payout is the game's core reward beat and it happened in silence
			UISound.rewardFlourish(3)
		end
		-- Count the number UP rather than swapping it. The balance is the single number this whole economy
		-- exists to move, and an instant replacement makes earning it feel like a variable assignment.
		if gained and lastBalance ~= nil then
			cashToken += 1
			local mine = cashToken
			local from, to = lastBalance, proj.balance
			local t0 = os.clock()
			local DURATION = 0.45
			task.spawn(function()
				while cashToken == mine do
					local a = math.min(1, (os.clock() - t0) / DURATION)
					-- ease out so it decelerates onto the final value instead of stopping dead
					local eased = 1 - (1 - a) * (1 - a)
					cashLabel.Text = "$ " .. commafmt(from + (to - from) * eased)
					if a >= 1 then
						break
					end
					task.wait()
				end
			end)
			cashPulse()
		else
			cashLabel.Text = "$ " .. commafmt(proj.balance)
		end
		lastBalance = proj.balance
	end
	tierLabel.Text = string.format("EHT %s · EFT %s", tostring(proj.eht), tostring(proj.eft))
	if proj.gates ~= nil then
		local nextId = nil
		for _, id in ipairs(DEST_ORDER) do
			local g = proj.gates[id]
			if g ~= nil and not g.unlocked then
				nextId = id
				break
			end
		end
		if nextId ~= nil then
			local g = proj.gates[nextId]
			goalTitle.Text = "Next: " .. (DEST_NAMES[nextId] or nextId)
			goalBody.Text = table.concat(g.unmetReasons or {}, "   •   ")
			goalFrame.Visible = true
		else
			goalFrame.Visible = false
		end
	end
	M.setCountdown(proj.nextWindowChangeAt, proj.activeWeather, proj.activeTraits)
	M.setObjective(proj.onboarding)
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
	b.AutoButtonColor = false -- we drive the press state ourselves, below
	b.Parent = opts.parent or gui

	-- Rounded corners and a stroke, on the factory rather than per controller. Square hard-edged buttons are
	-- one of the most recognisable "unfinished Roblox UI" tells, and every on-screen input in the game is
	-- built here.
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, opts.radius or 10)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(220, 232, 210)
	stroke.Thickness = 1
	stroke.Transparency = 0.72
	stroke.Parent = b

	-- Every controller builds its on-screen inputs through this factory, so wiring feedback here gives the
	-- whole UI audio and press response in one place, rather than six controllers each remembering to.
	b.Activated:Connect(function()
		UISound.play("click")
	end)
	-- A press must visibly depress. On mobile there is no hover state to fall back on, so a button that does
	-- not move on touch reads as unresponsive even when it fired correctly.
	local function press()
		TweenService:Create(b, TweenInfo.new(0.06), { BackgroundTransparency = 0.32 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.06), { Transparency = 0.35 }):Play()
	end
	local function release()
		TweenService:Create(b, TweenInfo.new(0.14), { BackgroundTransparency = 0.1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.14), { Transparency = 0.72 }):Play()
	end
	b.MouseButton1Down:Connect(press)
	b.MouseButton1Up:Connect(release)
	b.MouseLeave:Connect(release)
	b.TouchLongPress:Connect(release)

	return b
end

-- login-time state pull/push: ask the server for the projection when the HUD loads + apply any pushes, so the
-- header + next-goal show real values immediately on spawn (there was no login projection before).
task.spawn(function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local stateSync = ReplicatedStorage:WaitForChild("StateSync", 30)
	if stateSync ~= nil then
		stateSync.OnClientEvent:Connect(function(proj)
			M.applyProjection(proj)
		end)
		stateSync:FireServer() -- pull current state now
	end
end)

return M

-- rojo-live-test-marker-42
