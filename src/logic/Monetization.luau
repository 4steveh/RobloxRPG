--!strict
-- PURE MONETIZATION LOGIC (Step 14 — SYS_economy §7 / EQUIPMENT_MASTER §4.8 / 00 §4). The headless,
-- by-construction half of the real-money layer: (D) the 2x/VIP active-income multiplier math (stack +
-- ceiling), (A) the premium bait/ammo CONVENIENCE effect + the structural ≤Uncommon cap, (F) the bounded
-- rewarded-ad amount. Zero content literals — reads `config` (Tuning/Economy) + `profile` (entitlements).
-- It owns no Cash and writes nothing: it returns the numbers the GRANT points (RewardPipeline, the handlers,
-- PurchaseService) move. The pay-proof union (Schema.ProductGrant) is the type-level keystone; the conquest
-- set is never an input or an output here — sell WITH the player, never the play requirement.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Economy = require("@src/logic/Economy")

type Config = Schema.Config
type PlayerData = Schema.PlayerData
type CashMultiplier = Enums.CashMultiplier
type Rarity = Enums.Rarity

local M = {}

local function round(x: number): number
	return math.floor(x + 0.5)
end

-- ── §D the 2x/VIP active-income multiplier ────────────────────────────────────────────────────────────
-- A multiplier is held as a server-time ENTITLEMENT (Schema.Entitlement) so offline time counts and a
-- reconnect cannot resurrect an expired boost (the same idle-proof mechanism as the Step-13 event claim).
-- The entitlement kind encodes the multiplier tag: "multiplier:2xBoost" (time-limited) / "multiplier:vip"
-- (persistent). Never the conquest set — a multiplier touches the active Cash GRANT only.
local MULT_PREFIX = "multiplier:"

function M.multiplierEntitlementKind(tag: CashMultiplier): string
	return MULT_PREFIX .. tag
end

-- Parse the multiplier tag out of an entitlement kind (nil if the entitlement is not a multiplier — e.g. an
-- event-claim or ad-cooldown marker, which this must ignore).
function M.multiplierTagOf(entitlementKind: string): string?
	if string.sub(entitlementKind, 1, #MULT_PREFIX) ~= MULT_PREFIX then
		return nil
	end
	return string.sub(entitlementKind, #MULT_PREFIX + 1)
end

-- The absolute server-time expiry for a granted multiplier: a 2x boost is TIME-LIMITED (now + duration); VIP
-- is PERSISTENT (a game pass — re-granted idempotently on login), modeled as a non-expiring entitlement
-- (entitlementActive = now < expiry → always true; the prune loop never drops it).
function M.multiplierExpiry(config: Config, tag: CashMultiplier, now: number): number
	if tag == Enums.CashMultiplier.vip then
		return math.huge
	end
	return now + config.tuning.monetization.boostDurationSeconds
end

-- activeCashMultiplier — the COMBINED active-income multiplier from the player's live multiplier entitlements.
-- Stacks MULTIPLICATIVELY (VIP × boost × …), capped at the §7 max-stack ceiling so worst-case minting is
-- bounded. Returns ≥ 1.0 (1.0 = no active multiplier). An expired boost contributes nothing (offline counts).
function M.activeCashMultiplier(config: Config, profile: PlayerData, now: number): number
	local product = 1.0
	for _, ent in profile.activeEntitlements do
		if now < ent.expiryTimestamp then
			local tag = M.multiplierTagOf(ent.kind)
			if tag ~= nil then
				local factor = config.tuning.monetization.multipliers[tag]
				if factor ~= nil then
					product *= factor
				end
			end
		end
	end
	local ceiling = config.tuning.monetization.maxStackCeiling
	if product > ceiling then
		product = ceiling
	end
	return product
end

-- The boost BONUS Cash on a routine payout: round(base × multiplier) − base. Zero when no multiplier is
-- active (the no-op fast path). Written as a SEPARATE, real-money-tagged, loop="none" ledger entry by the
-- grant point (RewardPipeline) so the routine kill/catch faucet stays the BASE payout — the dual-loop
-- reconciliation reads the formula (untouched) and the boost is separable + bounded in telemetry (§7).
function M.boostBonus(base: number, multiplier: number): number
	if multiplier <= 1 then
		return 0
	end
	return round(base * multiplier) - base
end

-- ── §A premium bait/ammo — the CONVENIENCE effect (routine-grind compression) + the STRUCTURAL cap ──────
-- The cap is the design guarantee, and it holds at THREE structural levels — NONE a soft clamp:
--   (1) Spawner.rareSpawnEligible takes NO bait/profile input — premium bait is mechanically unable to touch
--       the moat-rare roll (you cannot buy your way to a rare). Asserted behaviorally in the spec.
--   (2) the routine bias operates ONLY on the Common/Uncommon routine pool (routineTargetsInZone /
--       Economy.routinePopulation filter rarity < RARE_AND_ABOVE_RANK), so a Rare-via-bait is
--       UNREPRESENTABLE — Rare is not in the pool to bias toward (premiumRoutineWeight rejects it).
--   (3) no target is takeable ONLY with premium bait (the land/kill min-tier math takes no premium-bait arg).
-- These functions are the EFFECT; the cap is the construction above + the watch-knob (uncommonBias).

-- premiumBaitTimeToBite — shorter routine TimeToBite (more bites/hour). Grind COMPRESSION: more bites/hr at
-- the SAME per-catch payout (the band is untouched — Economy.payout takes no bait arg). Always < base, > 0.
function M.premiumBaitTimeToBite(config: Config, baseTimeToBite: number): number
	return baseTimeToBite * (1 - config.tuning.monetization.premiumBait.timeToBiteSpeedup)
end

-- premiumBaitLandWindow — a small routine LandWindow bonus (bait). Improves odds on the routine fight; it
-- never makes an UN-landable fish landable (the min-tier gate is computed WITHOUT premium bait — not mandatory).
function M.premiumBaitLandWindow(config: Config, baseLandWindow: number): number
	return baseLandWindow * (1 + config.tuning.monetization.premiumBait.landWindowBonus)
end

-- premiumAmmoCycleTime — premium ammo's tighter settle (a small effective-CycleTime edge). Shaves a fumbled
-- shot; never clears a gate the player's WEAPON could not (the fire-rate / damage / range gates are unchanged).
function M.premiumAmmoCycleTime(config: Config, baseCycleTime: number): number
	return baseCycleTime * (1 - config.tuning.monetization.premiumBait.cycleTimeEdge)
end

-- premiumRoutineWeight — the biased SPAWN WEIGHT of a routine target under premium bait. Common keeps weight
-- 1.0; Uncommon is biased up by the WATCH-KNOB (uncommonBias). RARE-AND-ABOVE IS REJECTED: it can never be a
-- routine target (the pool excludes it), so biasing one is a category error — the structural ceiling surfaced
-- as a hard assert, NOT a silent clamp. The Uncommon ceiling is the pool's construction, not a tunable number.
function M.premiumRoutineWeight(config: Config, rarity: Rarity): number
	assert(Enums.RarityRank[rarity] < Enums.RARE_AND_ABOVE_RANK,
		"premiumRoutineWeight: premium bait biases only the Common/Uncommon routine pool — Rare-and-above is bait-independent (the ≤Uncommon cap is structural)")
	if rarity == Enums.Rarity.Uncommon then
		return 1 + config.tuning.monetization.premiumBait.uncommonBias
	end
	return 1.0 -- Common (the only other routine rarity)
end

-- The structural rarity ceiling premium bait can bias toward — EQUALS the routine pool's top rarity by
-- construction. A constant to reason the watch-knob against, NOT a clamp the bias is compared to.
M.PREMIUM_BAIT_RARITY_CEILING = Enums.Rarity.Uncommon :: Rarity

-- ── §F the rewarded-ad opt-in faucet amount (bounded) ───────────────────────────────────────────────────
-- A small Cash reward for watching an ad: a fraction of current-tier hourly income, HARD-CAPPED at an
-- absolute ceiling (bounded — low-tier-farming-proof + inflation-bounded). Opt-in + never-a-gate is the
-- handler's job; this is just the bounded amount, off the same Income(T) band the daily faucet uses.
function M.adReward(config: Config, tier: number): number
	local mon = config.tuning.monetization.adReward
	return math.min(round(mon.incomeFraction * Economy.income(config, tier)), mon.absoluteCap)
end

return M
