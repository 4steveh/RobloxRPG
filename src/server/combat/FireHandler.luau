--!strict
-- THE HUNTING VERB as a Gauntlet intent handler — it fills the pluggable STEP-3 (simulation) hook with
-- server-authoritative SHOT RESOLUTION, and runs the shared RewardPipeline in its commit. Because a kill
-- is a faucet + conquest critical trigger, the handler is `critical = true`, so the gauntlet wraps the
-- reward pipeline in a Transaction — the kill's ledger + Rank XP + mint + conquest land atomically or not
-- at all. The CLIENT asserts nothing: there is no "I killed X" route; the kill is the server's conclusion
-- from validated shot data. The actual aim/fire/raycast/recoil/feel is Studio (HuntingService + README).
--
-- Payload contract (HuntingService enriches the client request with AUTHORITATIVE fields server-side):
--   client-claimed : targetId, zone ("vital"|"body"|"limb")
--   server-set     : distance, claimedDamage(client-predicted, re-derived here), lastShotAt, rayHitTargetId
--                    (raycast result), targetAlive (spawn state), accumulatedDamageBefore (server HP track),
--                    owner (player key)
-- The Studio server resolves NON-lethal shots locally (impact prediction) and routes only the LETHAL blow
-- through this critical handler; a valid-but-non-lethal shot here returns (false, "not_lethal").

local Schema = require("../../types/Schema")
local Enums = require("../../types/Enums")
local Combat = require("../../logic/Combat")
local EffectiveTier = require("../../logic/EffectiveTier")
local Onboarding = require("../../logic/Onboarding")
local Daily = require("../../logic/Daily")
local Progression = require("../../logic/Progression")
local Gauntlet = require("../authority/Gauntlet")
local RewardPipeline = require("./RewardPipeline")
local Types = require("../persistence/Types")

type Ctx = Gauntlet.Ctx
type PlayerData = Schema.PlayerData
type Config = Schema.Config

local M = {}

export type FireDeps = {
	idGen: Types.IdGenerator,
	payoutFn: RewardPipeline.PayoutFn?,
	telemetry: Types.Telemetry?,
}

-- Resolve the equipped weapon to its authoritative (tier, intra-tier gear level). Empty slot → (0, entry).
local function equippedWeapon(profile: PlayerData, config: Config): (number, Combat.GearLevel)
	local instanceId = profile.equipped.weapon
	if instanceId ~= nil then
		for _, c in profile.inventory.commodities do
			if c.instanceId == instanceId then
				local item = config.equipment[c.catalogId]
				if item ~= nil then
					return item.tier, Combat.gearLevelOf(c.intraLevel)
				end
			end
		end
	end
	return 0, "entry"
end

function M.new(deps: FireDeps): Gauntlet.IntentHandler
	return {
		intent = "fire",
		critical = true, -- a kill is a faucet + conquest critical trigger → write-through Transaction

		-- Step 2: authoritative state must permit a shot at this target.
		authority = function(ctx: Ctx): (boolean, string?)
			if EffectiveTier.weaponTier(ctx.profile, ctx.config) < 1 then
				return false, "no_weapon" -- you cannot hunt with no weapon equipped
			end
			local creature = ctx.config.creatures[ctx.payload.targetId]
			if creature == nil then
				return false, "unknown_target"
			end
			if ctx.payload.targetAlive ~= true then
				return false, "target_not_alive" -- server spawn state owns life/death; not a client claim
			end
			return true, nil
		end,

		-- Step 3 (the hook this step fills): shot resolution + anti-exploit validation + lethality gate.
		simulate = function(ctx: Ctx): (boolean, string?)
			local payload = ctx.payload
			local tier, level = equippedWeapon(ctx.profile, ctx.config)
			if not Combat.zoneLegal(ctx.config, payload.zone) then
				return false, "illegal_zone"
			end
			if not Combat.rangeOk(ctx.config, tier, payload.distance) then
				return false, "out_of_range"
			end
			if not Combat.fireRateOk(ctx.config, payload.lastShotAt, ctx.now, Combat.cycleTime(ctx.config, tier)) then
				return false, "fire_rate"
			end
			if not Combat.losOk(payload.rayHitTargetId, payload.targetId) then
				return false, "los" -- through-wall / wrong-target (the raycast result, computed in Studio)
			end
			if not Combat.damageDerivable(ctx.config, tier, level, payload.zone, payload.distance, payload.claimedDamage) then
				return false, "damage_spoof"
			end
			-- lethality from the SERVER-authoritative shot damage + accumulated damage (the only kill route).
			local creature = ctx.config.creatures[payload.targetId]
			local serverShot = Combat.shotDamage(
				Combat.weaponDamage(ctx.config, tier, level),
				Combat.zoneMultiplier(ctx.config, payload.zone),
				Combat.rangeFalloff(ctx.config, tier, payload.distance)
			)
			if (payload.accumulatedDamageBefore + serverShot) < creature.health then
				return false, "not_lethal" -- a valid hit, but not the killing blow → no reward event
			end
			return true, nil
		end,

		-- Step 4: the reward pipeline (the gauntlet wraps this in a Transaction since critical = true).
		commit = function(ctx: Ctx)
			local event: RewardPipeline.KillEvent = {
				targetId = ctx.payload.targetId,
				owner = ctx.payload.owner,
				validatingEventId = deps.idGen.next("kill"), -- server-minted authoritative kill id
				loop = Enums.Loop.Hunting,
				partySize = ctx.payload.partySize,
			}
			local result = RewardPipeline.resolve(ctx.profile, ctx.config, event, {
				idGen = deps.idGen,
				now = ctx.now,
				payoutFn = deps.payoutFn,
				telemetry = deps.telemetry,
			})
			-- Step 7: advance the funnel + record the daily objective INSIDE this commit (atomic with the
			-- reward, idempotent). An ambiance kill pays nothing → it is not a comprehension beat, so skip it.
			if not result.ambiance then
				Onboarding.advance(ctx.profile, "kill", ctx.now)
				Daily.recordAction(ctx.profile.daily, Enums.Loop.Hunting, ctx.now)
			end
			-- Step 9: a NEW conquest may newly satisfy a downstream gate's milestone half → re-evaluate
			-- unlocks atomically with the kill (the gauntlet's Transaction reverts both on a failed save).
			-- Surface the committed result so the caller can render the harvest card (HandleResult.result).
			if ctx.resultSink then
				ctx.resultSink.value = result
			end
			if result.conquestNewlySet then
				Progression.commitUnlocks(ctx.profile, ctx.config)
			end
		end,
	}
end

return M
