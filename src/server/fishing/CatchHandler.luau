--!strict
-- THE FISHING VERB as a Gauntlet intent handler — the mirror of combat's FireHandler. It fills the
-- pluggable STEP-3 (simulation) hook with server-authoritative FIGHT RESOLUTION, and runs the SHARED
-- RewardPipeline in its commit. Because a landed fish is a faucet + conquest critical trigger, the handler
-- is `critical = true`, so the gauntlet wraps the reward pipeline in a Transaction (ledger + Angler XP +
-- mint + conquest land atomically or not at all). The CLIENT asserts nothing: there is no "I caught it"
-- route; the catch is the server's conclusion from validated inputs. The cast/bite/fight FEEL is Studio.
--
-- Payload contract (FishingService enriches the client request with AUTHORITATIVE fields server-side):
--   client-claimed : targetId, E (tension efficiency the player held)
--   server-set     : biteActive (spawn state), claimedDrain (re-derived here), accumulatedStaminaBefore
--                    (server fight track), owner (player key)
-- The Studio server resolves NON-landing ticks locally and routes only the LANDING blow through this
-- critical handler; a valid-but-unlanded fight here returns (false, "not_landed"). No death, no armor —
-- the failure modes are gear that can't clear the fight (gear_insufficient) and losing the fish (Studio).

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Fishing = require("@src/logic/Fishing")
local EffectiveTier = require("@src/logic/EffectiveTier")
local Gauntlet = require("@src/server/authority/Gauntlet")
local RewardPipeline = require("@src/server/combat/RewardPipeline")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx
type PlayerData = Schema.PlayerData
type Config = Schema.Config

local M = {}

export type CatchDeps = {
	idGen: Types.IdGenerator,
	payoutFn: RewardPipeline.PayoutFn?,
	telemetry: Types.Telemetry?,
}

-- Resolve an equipped tackle slot (rod/reel) to its authoritative (tier, intra-tier gear level).
local function equipped(profile: PlayerData, config: Config, instanceId: string?): (number, Fishing.GearLevel)
	if instanceId ~= nil then
		for _, c in profile.inventory.commodities do
			if c.instanceId == instanceId then
				local item = config.equipment[c.catalogId]
				if item ~= nil then
					return item.tier, Fishing.gearLevelOf(c.intraLevel)
				end
			end
		end
	end
	return 0, "entry"
end

function M.new(deps: CatchDeps): Gauntlet.IntentHandler
	return {
		intent = "catch",
		critical = true, -- a landed fish is a faucet + conquest critical trigger → write-through Transaction

		-- Step 2: authoritative state must permit a catch — tackle equipped, an active bite, and (the §4
		-- yes/no gate) the basic required bait in inventory. Bait ACQUISITION is Step 6/7; here it is the check.
		authority = function(ctx: Ctx): (boolean, string?)
			if EffectiveTier.effectiveFishingTier(ctx.profile, ctx.config) < 1 then
				return false, "no_tackle" -- you cannot fish without a rod AND reel (EFT = min(rod, reel))
			end
			local fish = ctx.config.fish[ctx.payload.targetId]
			if fish == nil then
				return false, "unknown_target"
			end
			if ctx.payload.biteActive ~= true then
				return false, "no_bite" -- server spawn state owns the bite; not a client claim
			end
			if fish.baitRequired ~= nil and (ctx.profile.inventory.fungible[fish.baitRequired] or 0) <= 0 then
				return false, "missing_bait" -- basic required-item yes/no gate (never a timer; auto-restocked, Step 6)
			end
			return true, nil
		end,

		-- Step 3 (the hook): fight resolution — tension legality + drain-spoof, the runtime gear-adequacy
		-- (min-tier) gate, and the landed check. The only kill-route to the reward pipeline.
		simulate = function(ctx: Ctx): (boolean, string?)
			local payload = ctx.payload
			local fish = ctx.config.fish[payload.targetId]
			local reelTier, reelLevel = equipped(ctx.profile, ctx.config, ctx.profile.equipped.reel)
			local rodTier, rodLevel = equipped(ctx.profile, ctx.config, ctx.profile.equipped.rod)
			if not Fishing.tensionLegal(payload.E) then
				return false, "illegal_tension"
			end
			if not Fishing.drainDerivable(ctx.config, reelTier, reelLevel, payload.E, payload.claimedDrain) then
				return false, "drain_spoof"
			end
			-- gear-adequacy: at the §3 skill reference, can the equipped rod+reel land this fish at all?
			-- (else the line snaps / the hook throws before the fish is drained — the runtime min-tier gate.)
			local stamina = Fishing.staminaToLand(ctx.config, fish)
			local ft = Fishing.fightTime(stamina, Fishing.netDrain(Fishing.reelDrainMax(ctx.config, reelTier, reelLevel), ctx.config.tuning.fishingFight.E_expected, Fishing.fishRecovery(ctx.config, fish)))
			if not Fishing.landable(ft, Fishing.landWindow(ctx.config, rodTier, reelTier, fish, rodLevel)) then
				return false, "gear_insufficient"
			end
			-- landed: the server-authoritative cumulative drain has emptied the Stamina pool.
			local serverDrain = Fishing.reelDrainMax(ctx.config, reelTier, reelLevel) * payload.E
			if (payload.accumulatedStaminaBefore + serverDrain) < stamina then
				return false, "not_landed" -- a valid fight tick, but not the landing blow → no reward event
			end
			return true, nil
		end,

		-- Step 4: the SHARED reward pipeline (the gauntlet wraps this in a Transaction since critical = true).
		commit = function(ctx: Ctx)
			local event: RewardPipeline.KillEvent = {
				targetId = ctx.payload.targetId,
				owner = ctx.payload.owner,
				validatingEventId = deps.idGen.next("catch"),
				loop = Enums.Loop.Fishing,
				partySize = ctx.payload.partySize,
			}
			RewardPipeline.resolve(ctx.profile, ctx.config, event, {
				idGen = deps.idGen,
				now = ctx.now,
				payoutFn = deps.payoutFn,
				telemetry = deps.telemetry,
			})
		end,
	}
end

return M
