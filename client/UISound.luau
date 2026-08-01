--!nonstrict
-- STUDIO-ONLY ModuleScript. THE INTERACTION AUDIO LAYER.
--
-- Wild World had exactly two sound-producing files, both combat FX. Every button press, panel open, purchase,
-- equip, travel and reward happened in total silence — which is most of why the UI reads as a prototype even
-- when it looks fine. Silence on interaction is one of the loudest amateur tells there is.
--
-- Engine-bundled `rbxasset://` ids ONLY. They resolve from the local install with no CDN fetch and no asset
-- permission, so they cannot fail on a cold client or in an unpublished place the way an uploaded id can —
-- which matters here, because this place is unpublished and its DataStore already degrades for that reason.
--
-- Pitch is varied per call. A UI sound played at exactly the same pitch every time stops registering after
-- about thirty presses; a few percent of drift keeps it alive without ever being noticeable as variation.

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local M = {}

-- name -> { id, volume, pitch, spread }
local BANK = {
	-- light, high, short: a press that has not committed to anything yet
	click = { id = "rbxasset://sounds/button.wav", volume = 0.28, pitch = 1.18, spread = 0.05 },
	-- a real state change: buy, equip, claim
	confirm = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, pitch = 1.0, spread = 0.04 },
	-- money arriving, distinct from a generic confirm so a payout is audible without looking
	reward = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, pitch = 1.45, spread = 0.03 },
	-- refusal: same family, pitched down, so it reads as the negative of confirm
	deny = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.32, pitch = 0.62, spread = 0.03 },
	-- panel transitions
	open = { id = "rbxasset://sounds/button.wav", volume = 0.3, pitch = 0.92, spread = 0.04 },
	close = { id = "rbxasset://sounds/button.wav", volume = 0.26, pitch = 0.74, spread = 0.04 },
	-- the marquee moment: a rare or a record
	fanfare = { id = "rbxasset://sounds/bass.wav", volume = 0.55, pitch = 1.1, spread = 0.02 },
}

local muted = false

function M.setMuted(on)
	muted = on == true
end

function M.play(name, volumeScale)
	if muted then
		return
	end
	local spec = BANK[name]
	if spec == nil then
		return
	end
	-- pcall: a missing engine sound must never break the interaction it was decorating
	pcall(function()
		local snd = Instance.new("Sound")
		snd.SoundId = spec.id
		snd.Volume = spec.volume * (volumeScale or 1)
		snd.PlaybackSpeed = spec.pitch + (math.random() * 2 - 1) * spec.spread
		snd.Parent = SoundService
		snd:Play()
		Debris:AddItem(snd, 4)
	end)
end

-- A short ascending run, for a payout worth noticing. Three notes rather than one is what separates
-- "something happened" from "something GOOD happened".
function M.rewardFlourish(steps)
	if muted then
		return
	end
	local n = math.clamp(steps or 3, 1, 5)
	for i = 1, n do
		task.delay((i - 1) * 0.07, function()
			local spec = BANK.reward
            pcall(function()
				local snd = Instance.new("Sound")
				snd.SoundId = spec.id
				snd.Volume = spec.volume * (0.7 + i * 0.1)
				snd.PlaybackSpeed = spec.pitch * (1 + (i - 1) * 0.16)
				snd.Parent = SoundService
				snd:Play()
				Debris:AddItem(snd, 3)
			end)
		end)
	end
end

return M
