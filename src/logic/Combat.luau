--!strict
-- PURE COMBAT MATH (SYS_combat §1–§6 + EQUIPMENT_MASTER §1). The deferred Step-1 curves, implemented:
-- the offensive weapon curve, cycle/range, the armor DR model, the shot/kill math, co-op Health scaling,
-- the Bayou-wide non-lethal clamp, the kill-window inequality, the min-tier DERIVATION, and the
-- server-side anti-exploit validators. ZERO content literals — every magnitude comes from `config`
-- (Tuning) and every creature/state value from the caller. The game FEEL these numbers drive
-- (recoil/hit-stop/impact/audio/haptics/aim) is Studio and is NOT here (README playtest checklist).

local Schema = require("@src/types/Schema")

type Config = Schema.Config
type Creature = Schema.Creature

local M = {}

export type GearLevel = "entry" | "mid" | "maxed"

local function round(x: number): number
	return math.floor(x + 0.5)
end

-- Map a commodity's intra-tier upgrade level (a number; 0 = just-bought) to the q-curve gear level. A
-- freshly-granted gating weapon sits at the intra-tier floor (entry); Step 6's upgrade economy climbs it.
function M.gearLevelOf(intraLevel: number): GearLevel
	if intraLevel <= 0 then
		return "entry"
	elseif intraLevel == 1 then
		return "mid"
	end
	return "maxed"
end

-- ── EQUIPMENT_MASTER §1.2 offensive curve: WeaponDamage(T,ℓ) = round(D1 · ρ^(T−1) · q(ℓ)) ──
-- Defaults to mid gear (the §3 floor/ceiling derivation reference). q(entry) is the intra-tier floor a
-- just-bought weapon sits at; q(maxed) the apex after the intra-tier climb (Step 6's upgrade economy).
function M.weaponDamage(config: Config, tier: number, level: GearLevel?): number
	local off = config.tuning.offensive
	local mult = off.q.mid
	if level == "entry" then
		mult = off.q.entry
	elseif level == "maxed" then
		mult = off.q.maxed
	end
	return round(off.D1 * off.rho ^ (tier - 1) * mult)
end

-- ── EQUIPMENT_MASTER §1.3 cycle/range ──
function M.cycleTime(config: Config, tier: number): number
	local w = config.tuning.weapon
	if tier >= 1 and tier <= w.cycleTimeAnchorTier then
		return w.cycleTime[tier]
	end
	local anchored = w.cycleTime[w.cycleTimeAnchorTier] - w.cycleTimePerTierDecrement * (tier - w.cycleTimeAnchorTier)
	return math.max(anchored, w.cycleTimeFloor)
end

function M.weaponRange(config: Config, tier: number): number
	local w = config.tuning.weapon
	return w.rangeBase + w.rangePerTier * (tier - 1)
end

function M.maxEffectiveRange(config: Config, tier: number): number
	return M.weaponRange(config, tier) * config.tuning.combat.range.falloffExtension
end

-- RangeFalloff: 1.0 in-band (≤ optimal); linear down to the floor at maxEffectiveRange; 0 beyond (the
-- shot is out of range and deals no damage — rangeOk rejects it server-side).
function M.rangeFalloff(config: Config, tier: number, distance: number): number
	local w = config.tuning.weapon
	local optimal = M.weaponRange(config, tier)
	local maxEff = M.maxEffectiveRange(config, tier)
	if distance <= optimal then
		return w.rangeFalloffInBand
	end
	if distance > maxEff then
		return 0
	end
	local fraction = (distance - optimal) / (maxEff - optimal)
	return w.rangeFalloffInBand - fraction * (w.rangeFalloffInBand - w.rangeFalloffFloor)
end

-- ── §2 shot/kill math ──
function M.shotDamage(weaponDamage: number, zoneMult: number, rangeFalloff: number): number
	return weaponDamage * zoneMult * rangeFalloff
end

-- ShotsToKill = ceil(Health / (WeaponDamage·Z·Falloff)). A non-damaging shot can never kill (∞ shots).
function M.shotsToKill(health: number, weaponDamage: number, zoneMult: number, rangeFalloff: number): number
	local perShot = weaponDamage * zoneMult * rangeFalloff
	if perShot <= 0 then
		return math.huge
	end
	return math.ceil(health / perShot)
end

function M.timeToKill(shotsToKill: number, cycleTime: number): number
	return shotsToKill * cycleTime
end

-- ── §4 armor: DR = clamp(DR_base + DR_step·(armorTier − creatureTier), DR_min, DR_cap) ──
function M.dr(config: Config, armorTier: number, creatureTier: number): number
	local d = config.tuning.defensive
	return math.clamp(d.drBase + d.drStep * (armorTier - creatureTier), d.drMin, d.drCap)
end

function M.damageTaken(creatureDamage: number, dr: number): number
	return creatureDamage * (1 - dr)
end

-- ── §6 co-op: EffectiveHealth(N) = Health·(1 + h_coop·(N−1)), capped at partyCap (sublinear vs linear DPS) ──
function M.coopEffectiveHealth(config: Config, baseHealth: number, partySize: number): number
	local coop = config.tuning.combat.coop
	local n = math.min(math.max(partySize, 1), coop.partyCap)
	return baseHealth * (1 + coop.hCoop * (n - 1))
end

-- ── §4 Tier-1 non-lethal floor (the Bayou-wide clamp) ──
-- A creature is non-lethal if its home Destination is in the non-lethal set (the whole Bayou roster, LOC §3).
function M.isNonLethal(config: Config, creature: Creature): boolean
	return config.tuning.combat.nonLethalDestinations[creature.destinationId] == true
end

-- Apply incoming damage to the player's HP. Non-lethal → floored at nonLethalMinHP (can never be downed);
-- lethal → floored at 0 (downed). The hard server clamp that makes "armorless EHT=1 in the Bayou" true.
function M.resolvePlayerHP(config: Config, currentHP: number, rawDamage: number, nonLethal: boolean): number
	local minHP = if nonLethal then config.tuning.combat.nonLethalMinHP else 0
	return math.max(currentHP - rawDamage, minHP)
end

-- ── §3 the single kill inequality: killable iff you can land enough shots before the window closes ──
function M.isKillable(shotsToKill: number, killWindowSeconds: number, cycleTime: number): boolean
	return shotsToKill <= killWindowSeconds / cycleTime
end

-- ─────────────────────────────────────────────────────────────────────────────
-- §build-notes — server-side anti-exploit validators (pure; the server is authoritative). The LOS
-- raycast itself is Studio; losOk is only the through-wall DECISION over a (stubbed) ray result.
-- ─────────────────────────────────────────────────────────────────────────────
function M.zoneLegal(_config: Config, zone: string): boolean
	return zone == "vital" or zone == "body" or zone == "limb"
end

-- The zone's multiplier (callers gate on zoneLegal first; an unknown zone falls back to body 1.0).
function M.zoneMultiplier(config: Config, zone: string): number
	local z = config.tuning.combat.zone
	if zone == "vital" then
		return z.vital
	elseif zone == "limb" then
		return z.limb
	end
	return z.body
end

-- Fire-rate: shots arriving faster than CycleTime are rejected (a small tolerance absorbs latency/rounding).
function M.fireRateOk(config: Config, lastShotAt: number, now: number, cycleTime: number): boolean
	return (now - lastShotAt) >= (cycleTime - config.tuning.combat.fireRateToleranceSeconds)
end

-- Range: a shot beyond the weapon's max-effective range (where RangeFalloff hits 0) is rejected.
function M.rangeOk(config: Config, tier: number, distance: number): boolean
	return distance >= 0 and distance <= M.maxEffectiveRange(config, tier)
end

-- Damage-spoof: the claimed damage must equal ShotDamage recomputed from the equipped weapon's
-- authoritative stats × a LEGAL zone × the range falloff, within a rounding tolerance. A 999 claim drops.
function M.damageDerivable(config: Config, tier: number, level: GearLevel, zone: string, distance: number, claimed: number): boolean
	if not M.zoneLegal(config, zone) then
		return false
	end
	if not M.rangeOk(config, tier, distance) then
		return false
	end
	local expected = M.shotDamage(M.weaponDamage(config, tier, level), M.zoneMultiplier(config, zone), M.rangeFalloff(config, tier, distance))
	return math.abs(claimed - expected) <= config.tuning.combat.damageToleranceAbs
end

-- LOS / geometry: the server's raycast (Studio) must have hit the claimed target — no through-wall /
-- wrong-target kill. This is the pure decision over the ray result; the raycast belongs to HuntingService.
function M.losOk(rayHitTargetId: string?, claimedTargetId: string): boolean
	return rayHitTargetId ~= nil and rayHitTargetId == claimedTargetId
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SYS_progression §4 — Rank XP per kill/catch, difficulty/rarity WEIGHTED (the weighting is the design;
-- magnitudes are tuning). Rank grants identity/convenience only — never power, never a gate.
-- ─────────────────────────────────────────────────────────────────────────────
function M.rankXP(config: Config, creature: Creature): number
	local r = config.tuning.combat.rankXP
	local tierFactor = 1 + r.tierStep * (creature.tier - 1)
	local rarityWeight = r.rarityWeight[creature.rarity]
	local archetypeWeight = r.archetypeWeight[creature.behavior]
	return round(r.base * tierFactor * rarityWeight * archetypeWeight)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- §3 min-tier DERIVATION — the Template-C min-weapon/min-armor-tier fields are DERIVED from the kill
-- inequality, not authored truth; Validation asserts the catalog matches (catching a mis-statted creature).
-- The derivation assumes the §3 mid-gear reference (q.mid, Z_expected). BAYOU scope: every creature is
-- non-lethal → the survival window is unbounded → only the escape-bounded branch does real work, and
-- min-armor-tier is n/a (0) everywhere. The full survival-bounded branch first does real work at Step 10.
-- ─────────────────────────────────────────────────────────────────────────────
local MAX_DERIVE_TIER = 10 -- iteration bound (MVL is T1–4; headroom for re-statting/later tiers)

-- An apex is tuned to hit AS IF one tier higher (§4). The design marker is the co-op recommendation:
-- a `party` creature is the tier's apex (cougar/catamount/grizzly/glacier). NOT a hardcoded id list.
function M.isApex(creature: Creature): boolean
	return creature.coop == "party"
end

local function isEscapeBounded(behavior: string): boolean
	return behavior == "passive" or behavior == "flees"
end

-- The survival-bounded KillWindow at a given armor tier (lethal, aggressive/pack). Non-lethal / no-damage
-- creatures have no survival clock → unbounded. DR uses the creature's EFFECTIVE tier (apex = +1).
-- The window is (hitsToDown − 1) · interval: the player absorbs (hits−1) intervals before the last hit
-- downs them.
local function survivalWindow(config: Config, creature: Creature, armorTier: number): number
	local interval = creature.attackIntervalSeconds
	if interval == nil or interval <= 0 then
		return math.huge
	end
	local effTier = creature.tier + (if M.isApex(creature) then 1 else 0)
	local taken = M.damageTaken(creature.damageToPlayer, M.dr(config, armorTier, effTier))
	if taken <= 0 then
		return math.huge
	end
	local hitsToDown = math.ceil(config.tuning.combat.playerBaseHP / taken)
	return math.max(hitsToDown - 1, 0) * interval
end

-- Soloability at a specific (weaponTier, armorTier) — the §3 inequality with the chosen gear. Escape-
-- bounded creatures use their TimeToFlee; survival-bounded use the (hits−1) window above.
function M.soloableAt(config: Config, creature: Creature, weaponTier: number, armorTier: number): boolean
	local escape = creature.behavior == "passive" or creature.behavior == "flees"
	local window: number
	if escape then
		window = creature.escapeWindowSeconds or math.huge
	elseif M.isNonLethal(config, creature) then
		window = math.huge
	else
		window = survivalWindow(config, creature, armorTier)
	end
	local stk = M.shotsToKill(creature.health, M.weaponDamage(config, weaponTier, "mid"), config.tuning.skill.Z_expected, config.tuning.weapon.rangeFalloffInBand)
	return M.isKillable(stk, window, M.cycleTime(config, weaponTier))
end

-- Co-op solubility (§6): a party clears the co-op-scaled Health with combined DPS; the worst-case tank
-- (holds aggro the whole fight) must survive the fight's duration. Soluble iff the tank's accumulated
-- post-armor hits over the kill time stay under playerBaseHP. Uses coopEffectiveHealth + the (apex) DR.
function M.coopSoloableAt(config: Config, creature: Creature, gearTier: number, partySize: number): boolean
	local n = math.min(math.max(partySize, 1), config.tuning.combat.coop.partyCap)
	if n <= 1 then
		return M.soloableAt(config, creature, gearTier, gearTier) -- solo == the wall
	end
	local effHealth = M.coopEffectiveHealth(config, creature.health, n)
	local perPlayerDamage = M.weaponDamage(config, gearTier, "mid") * config.tuning.skill.Z_expected * config.tuning.weapon.rangeFalloffInBand
	if perPlayerDamage <= 0 then
		return false
	end
	local killTime = (effHealth / (n * perPlayerDamage)) * M.cycleTime(config, gearTier)
	local interval = creature.attackIntervalSeconds
	if interval == nil or interval <= 0 then
		return true -- no survival threat (e.g. a non-lethal/escape target) → trivially co-op-soluble
	end
	local effTier = creature.tier + (if M.isApex(creature) then 1 else 0)
	local taken = M.damageTaken(creature.damageToPlayer, M.dr(config, gearTier, effTier))
	local tankHits = math.floor(killTime / interval) -- hits the aggro-holder eats over the fight
	return tankHits * taken < config.tuning.combat.playerBaseHP
end

export type MinTiers = { minWeaponTier: number, minArmorTier: number }
function M.deriveMinTiers(config: Config, creature: Creature): MinTiers
	local zExpected = config.tuning.skill.Z_expected
	local inBand = config.tuning.weapon.rangeFalloffInBand
	local escape = isEscapeBounded(creature.behavior)
	local nonLethal = M.isNonLethal(config, creature)

	-- the KillWindow used for the min-WEAPON derivation (armor referenced at parity, per §3).
	local function windowAtParity(): number
		if escape then
			return creature.escapeWindowSeconds or math.huge
		end
		if nonLethal then
			return math.huge
		end
		return survivalWindow(config, creature, creature.tier)
	end

	-- min weapon tier = lowest T whose mid-gear weapon satisfies ShotsToKill ≤ KillWindow / CycleTime.
	local minWeaponTier = MAX_DERIVE_TIER
	local window = windowAtParity()
	for tier = 1, MAX_DERIVE_TIER do
		local stk = M.shotsToKill(creature.health, M.weaponDamage(config, tier, "mid"), zExpected, inBand)
		if M.isKillable(stk, window, M.cycleTime(config, tier)) then
			minWeaponTier = tier
			break
		end
	end

	-- min armor tier = n/a (0) when there is no survival threat; else the lowest armor tier whose DR keeps
	-- the survival window long enough to land the kill at the min-weapon weapon.
	local minArmorTier = 0
	if not escape and not nonLethal and creature.damageToPlayer > 0 then
		minArmorTier = MAX_DERIVE_TIER
		local stk = M.shotsToKill(creature.health, M.weaponDamage(config, minWeaponTier, "mid"), zExpected, inBand)
		local ct = M.cycleTime(config, minWeaponTier)
		for armorTier = 0, MAX_DERIVE_TIER do
			if M.isKillable(stk, survivalWindow(config, creature, armorTier), ct) then
				minArmorTier = armorTier
				break
			end
		end
	end

	return { minWeaponTier = minWeaponTier, minArmorTier = minArmorTier }
end

return M
