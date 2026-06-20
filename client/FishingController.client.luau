--!nonstrict
-- STUDIO-ONLY. Cast-and-reel fishing terminal. "Cast" asks the server for a bite; on a bite, holding "Reel"
-- sends fight ticks (effort E∈[0,1]) until the server says "landed". The server owns stamina/landing; this
-- script sends effort + renders the gauge + the catch. The gauge is COSMETIC for S1 (the client isn't told
-- the target stamina), so it animates on the server's fightProgress; the authoritative resolve is "landed".
local Net = require(script.Parent:WaitForChild("Net"))
local Hud = require(script.Parent:WaitForChild("Hud"))
local Feel = require(script.Parent:WaitForChild("FishingFeel")) -- S2 game-feel: rod, cast line, bobber, reel, landed FX
local HarvestCard = require(script.Parent:WaitForChild("HarvestCard"))

local STATE = { idle = "idle", waiting = "waiting", fighting = "fighting" }
local state = STATE.idle
local reeling = false
local progressTicks = 0
local castToken = 0

local castBtn = Hud.button({
	name = "CastButton", text = "CAST",
	position = UDim2.new(1, -150, 1, -150), size = UDim2.fromOffset(120, 56),
	color = Color3.fromRGB(55, 90, 120),
})
local reelBtn = Hud.button({
	name = "ReelButton", text = "REEL (hold)",
	position = UDim2.new(1, -150, 1, -150), size = UDim2.fromOffset(120, 56),
	color = Color3.fromRGB(60, 110, 90), textSize = 15,
})
reelBtn.Visible = false

castBtn.Activated:Connect(function()
	if state ~= STATE.idle then
		return
	end
	state = STATE.waiting
	castToken += 1
	local mine = castToken
	Net.cast:FireServer("cast")
	Feel.onCast()
	Hud.toast("Casting…", Color3.fromRGB(150, 200, 230))
	task.delay(4, function()
		if state == STATE.waiting and castToken == mine then
			state = STATE.idle
			Hud.toast("No bite — cast again", Color3.fromRGB(220, 200, 140))
			Feel.onIdle()
		end
	end)
end)

-- hold-to-reel: MouseButton1Down/Up fire for both mouse and touch on a GUI button
reelBtn.MouseButton1Down:Connect(function()
	reeling = true
end)
reelBtn.MouseButton1Up:Connect(function()
	reeling = false
end)

local lastFightReply = 0

local function resetToIdle()
	state = STATE.idle
	reeling = false
	reelBtn.Visible = false
	castBtn.Visible = true
	Hud.setGauge(false)
end

local function fightLoop()
	progressTicks = 0
	lastFightReply = os.clock()
	while state == STATE.fighting do
		Net.cast:FireServer("fight", reeling and 1 or 0)
		task.wait(0.15)
		-- watchdog: the server acks every fight tick with "fightProgress" (or "landed"). If it goes SILENT —
		-- the catch was rejected by the gauntlet, or the bite despawned (both clear the server-side fight
		-- without a reply) — the fight is dead; recover to idle instead of spinning forever.
		if state == STATE.fighting and (os.clock() - lastFightReply) > 1.5 then
			resetToIdle()
			Hud.toast("Fish got away — cast again", Color3.fromRGB(220, 200, 140))
			Feel.onIdle()
			return
		end
	end
end

Net.cast.OnClientEvent:Connect(function(kind, fishId, extra)
	if kind == "bite" then
		state = STATE.fighting
		reeling = false
		castBtn.Visible = false
		reelBtn.Visible = true
		Hud.setGauge(true, 0)
		Hud.toast("Bite! Hold REEL", Color3.fromRGB(150, 200, 230))
		Feel.onBite()
		task.spawn(fightLoop)
	elseif kind == "fightProgress" then
		lastFightReply = os.clock()
		progressTicks += 1
		Hud.setGauge(true, math.clamp(progressTicks / 8, 0, 0.95)) -- cosmetic; true max is server-side
		Feel.onReel(math.clamp(progressTicks / 8, 0, 1))
	elseif kind == "landed" then
		lastFightReply = os.clock()
		resetToIdle()
		local h = extra.harvest
		Hud.applyProjection(extra.projection)
		if h.mintedArtifactId or h.isRecord or h.isNew then
			HarvestCard.show(h)
		else
			Hud.toast("+$" .. tostring(h.cash) .. "  " .. tostring(h.name), Color3.fromRGB(150, 230, 140))
		end
		Feel.onLanded(fishId, h.name)
	end
end)
