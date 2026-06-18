--!strict
-- PROGRESSION OPERATIONS (SYS_progression §2/§3). The unlock-COMMIT + the Passport/World-Map surface.
-- commitUnlocks is the one-time threshold crossing: it re-evaluates every Destination's gate (via the
-- single source of truth, Gate.evaluateGate) and ADDS each newly-unlocked Destination to the PERSISTED
-- unlockedDestinations set. The set is authoritative truth — once added, a Destination stays unlocked even
-- if the player later sells/unequips the qualifying gear (§2: "you upgraded and lost Alaska" is the bug we
-- forbid). evaluateGate is the trigger to ADD, never re-checked to KEEP membership; the set is NEVER derived
-- live. Idempotent + one pass (the gate checks prerequisiteDestinations ⊆ CONQUERED — a stable player
-- action — so unlocking A never mechanically unlocks B; no cascade, no fixpoint). Pure: reads profile +
-- config, mutates only profile.unlockedDestinations (the Onboarding.advance / Daily.recordAction pattern).

local Schema = require("../types/Schema")
local Gate = require("./Gate")
local Ids = require("../types/Ids")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type DestinationId = Ids.DestinationId

local M = {}

export type CommitResult = { newlyUnlocked: { DestinationId } }

-- commitUnlocks(profile, config): re-evaluate ALL gates; add each now-unlocked, not-already-in-set
-- Destination to the persisted set. Returns the list newly added (for telemetry). ONLY adds, never removes.
function M.commitUnlocks(profile: PlayerData, config: Config): CommitResult
	local newlyUnlocked: { DestinationId } = {}
	for id, destination in config.destinations do
		if profile.unlockedDestinations[id] ~= true and Gate.evaluateGate(profile, destination, config).unlocked then
			profile.unlockedDestinations[id] = true
			table.insert(newlyUnlocked, id)
		end
	end
	return { newlyUnlocked = newlyUnlocked }
end

-- The World-Map pin per Destination: unlocked + conquered from the PERSISTED sets (NOT a live gate eval —
-- a sold-gear Destination must read unlocked); unmetReasons from evaluateGate ONLY for a still-locked pin
-- (the legibility-contract strings). One source of truth: the UI renders this, never re-deriving gate logic.
export type Pin = { unlocked: boolean, conquered: boolean, unmetReasons: { string } }
function M.worldMapPins(profile: PlayerData, config: Config): { [DestinationId]: Pin }
	local pins: { [DestinationId]: Pin } = {}
	for id, destination in config.destinations do
		local unlocked = profile.unlockedDestinations[id] == true
		pins[id] = {
			unlocked = unlocked,
			conquered = profile.conqueredDestinations[id] == true,
			unmetReasons = if unlocked then {} else Gate.evaluateGate(profile, destination, config).unmetReasons,
		}
	end
	return pins
end

-- The Passport readout: counts derived from the persisted sets (the Lodge "N of M unlocked / K conquered").
export type PassportCounts = { unlocked: number, conquered: number, total: number }
function M.passportCounts(profile: PlayerData, config: Config): PassportCounts
	local unlocked, conquered, total = 0, 0, 0
	for id in config.destinations do
		total += 1
		if profile.unlockedDestinations[id] == true then
			unlocked += 1
		end
		if profile.conqueredDestinations[id] == true then
			conquered += 1
		end
	end
	return { unlocked = unlocked, conquered = conquered, total = total }
end

return M
