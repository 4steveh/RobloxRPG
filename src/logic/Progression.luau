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

local Schema = require("@src/types/Schema")
local Gate = require("@src/logic/Gate")
local Ids = require("@src/types/Ids")

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

return M
