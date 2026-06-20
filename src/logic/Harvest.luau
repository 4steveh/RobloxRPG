--!strict
-- Pure helpers for the harvest/catch result card (SYS_harvest_screen). Zero Roblox globals, zero content
-- literals (thresholds are passed in). The RANDOM source stays in Studio (WorldServer passes math.random()
-- as `u`); the math here is deterministic + unit-tested.

local Schema = require("../types/Schema")

type PlayerData = Schema.PlayerData

local M = {}

-- kilograms → pounds, rounded to one decimal (Gone Hunting's "[201.7 lb]" idiom).
function M.kgToLb(kg: number): number
	return math.floor(kg * 2.2046 * 10 + 0.5) / 10
end

-- A weight roll biased toward `min` (u*u for u∈[0,1]) so heavy specimens / records feel rare.
function M.rollWeightKg(min: number, max: number, u: number): number
	local c = math.clamp(u, 0, 1)
	return min + (max - min) * c * c
end

-- Is this catch at/near the species record? `threshold` ∈ (0,1] (e.g. 0.95). A zero/absent record is never one.
function M.isRecord(weightKg: number, recordWeightKg: number, threshold: number): boolean
	return recordWeightKg > 0 and weightKg >= recordWeightKg * threshold
end

-- How many of the player's artifacts came from this source species (Tier-A "NEW!": after a mint, == 1 ⇒ first).
function M.timesSourced(profile: PlayerData, sourceId: string): number
	local n = 0
	for _, a in profile.artifacts do
		if a.provenance.sourceId == sourceId then
			n += 1
		end
	end
	return n
end

return M
