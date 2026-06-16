--!strict
-- PURE FISHING MATH (SYS_fishing §2/§3 + EQUIPMENT_MASTER §1 fishing curves) — the structural MIRROR of
-- Combat.luau. The catchability inequality is `FightTime ≤ LandWindow`, with ONLY the escape/break-bounded
-- form (no survival/death variant — fishing has no death, no armor). Reel = weapon-analog (its drain
-- shortens FightTime); rod = armor-analog (its Pressure lengthens LandWindow; a snap is the window
-- closing). Min rod/reel tiers are DERIVED (asserted == authored in Validation). The spread-growth constant
-- is INHERITED from combat (Tuning.spread, RD-F) — not forked. Zero content literals. The fight FEEL
-- (tension gauge, runs, haptics, cast) is Studio, not here.

local Schema = require("@src/types/Schema")

type Config = Schema.Config
type Fish = Schema.Fish

local M = {}

export type GearLevel = "entry" | "mid" | "maxed"

local function round(x: number): number
	return math.floor(x + 0.5)
end

-- A just-bought rod/reel sits at the intra-tier floor (entry); Step 6's upgrade economy climbs it (mirror Combat).
function M.gearLevelOf(intraLevel: number): GearLevel
	if intraLevel <= 0 then
		return "entry"
	elseif intraLevel == 1 then
		return "mid"
	end
	return "maxed"
end

-- ── EQUIPMENT_MASTER §1.2 reel curve (weapon-analog): ReelDrainMax(T,ℓ) = round(R1·ρ^(T−1)·q(ℓ)) ──
function M.reelDrainMax(config: Config, tier: number, level: GearLevel?): number
	local off = config.tuning.offensive
	local mult = off.q.mid
	if level == "entry" then
		mult = off.q.entry
	elseif level == "maxed" then
		mult = off.q.maxed
	end
	return round(off.R1 * off.rho ^ (tier - 1) * mult)
end

-- ── EQUIPMENT_MASTER §1.4 rod curve (armor-analog): BreakThreshold(T,ℓ) = round((P1 + P_step·(T−1))·pq(ℓ)) ──
function M.breakThreshold(config: Config, tier: number, level: GearLevel?): number
	local d = config.tuning.defensive
	local mult = d.rodPq.mid
	if level == "entry" then
		mult = d.rodPq.entry
	elseif level == "maxed" then
		mult = d.rodPq.maxed
	end
	return round((d.rodP1 + d.rodPStep * (tier - 1)) * mult)
end

-- ── §2 the fish side of the inequality ──
-- The representative weight for StaminaToLand is the heaviest TYPICAL specimen (conservative — matches the
-- authored routine min-tiers). A rare's huge RECORD weight is cosmetic; routine bites use typical.max.
local function representativeWeight(fish: Fish): number
	return fish.typicalWeightKg.max
end

function M.staminaToLand(config: Config, fish: Fish): number
	local fc = config.tuning.fishingFight
	return fc.k_s * fish.fightDifficulty * (1 + representativeWeight(fish) / fc.W_ref)
end

function M.fishRecovery(config: Config, fish: Fish): number
	return config.tuning.fishingFight.r * fish.fightDifficulty
end

function M.peakRunForce(config: Config, fish: Fish): number
	return config.tuning.fishingFight.p * fish.fightDifficulty
end

-- NetDrain = ReelDrainMax·E − FishRecovery; E ∈ [0,1] is the tension-efficiency skill term (≙ Z_expected).
function M.netDrain(reelDrainMax: number, E: number, fishRecovery: number): number
	return reelDrainMax * E - fishRecovery
end

-- FightTime = StaminaToLand / NetDrain (∞ if NetDrain ≤ 0 — a too-weak reel can never out-drain the fish).
function M.fightTime(staminaToLand: number, netDrain: number): number
	if netDrain <= 0 then
		return math.huge
	end
	return staminaToLand / netDrain
end

-- dragSmooth(reel): the §2 reel factor on LandWindow. Flat 1.0 at MVL (reel-scaling deferred), a tuning knob.
function M.dragSmooth(config: Config, _reelTier: number): number
	return config.tuning.fishingFight.dragSmooth
end

-- LandWindow = w·max(BreakThreshold(rod) − PeakRunForce(fish), 0)·dragSmooth(reel). Collapses to 0 when
-- the rod can't clear the fish's runs (you snap on the first big run) — the armor-analog "window closing".
function M.landWindow(config: Config, rodTier: number, reelTier: number, fish: Fish, rodLevel: GearLevel?): number
	local w = config.tuning.defensive.landWindowW
	local headroom = math.max(M.breakThreshold(config, rodTier, rodLevel) - M.peakRunForce(config, fish), 0)
	return w * headroom * M.dragSmooth(config, reelTier)
end

-- The single inequality: landable iff you can drain the fish before a tension error breaks the line.
function M.landable(fightTime: number, landWindow: number): boolean
	return fightTime <= landWindow
end

-- ── §build-notes anti-exploit (pure; mirrors combat's validators) ──
function M.tensionLegal(E: number): boolean
	return E >= 0 and E <= 1
end

-- Drain-spoof: the claimed Stamina-drain must equal ReelDrainMax × a LEGAL tension E, within tolerance.
function M.drainDerivable(config: Config, reelTier: number, level: GearLevel, E: number, claimed: number): boolean
	if not M.tensionLegal(E) then
		return false
	end
	local expected = M.reelDrainMax(config, reelTier, level) * E
	return math.abs(claimed - expected) <= config.tuning.combat.damageToleranceAbs
end

-- ── §3 min-tier DERIVATION (mirror Combat.deriveMinTiers) ──
-- Reel drives FightTime; rod drives LandWindow. Evaluated at the §3 mid-gear reference and E_expected.
local MAX_DERIVE_TIER = 10

export type MinTiers = { minRodTier: number, minReelTier: number }
function M.deriveMinTiers(config: Config, fish: Fish): MinTiers
	local E = config.tuning.fishingFight.E_expected
	local stamina = M.staminaToLand(config, fish)
	local recovery = M.fishRecovery(config, fish)

	-- min reel tier: lowest reel whose drain lands the fish in the window at a PARITY rod (rod = fish.tier).
	local minReelTier = MAX_DERIVE_TIER
	for reelTier = 1, MAX_DERIVE_TIER do
		local ft = M.fightTime(stamina, M.netDrain(M.reelDrainMax(config, reelTier, "mid"), E, recovery))
		if M.landable(ft, M.landWindow(config, fish.tier, reelTier, fish, "mid")) then
			minReelTier = reelTier
			break
		end
	end

	-- min rod tier: lowest rod whose window (using the min-reel reel) lands the fish.
	local minRodTier = MAX_DERIVE_TIER
	local ftAtMinReel = M.fightTime(stamina, M.netDrain(M.reelDrainMax(config, minReelTier, "mid"), E, recovery))
	for rodTier = 1, MAX_DERIVE_TIER do
		if M.landable(ftAtMinReel, M.landWindow(config, rodTier, minReelTier, fish, "mid")) then
			minRodTier = rodTier
			break
		end
	end

	return { minRodTier = minRodTier, minReelTier = minReelTier }
end

-- ── SYS_progression §4 Angler Rank XP — tier × rarity × fight-difficulty weighted (fish have no archetype,
-- so this replaces Combat.rankXP's archetype factor with a fight-difficulty factor). Identity only. ──
function M.anglerRankXP(config: Config, fish: Fish): number
	local r = config.tuning.fishing.rankXP
	local tierFactor = 1 + r.tierStep * (fish.tier - 1)
	local rarityWeight = r.rarityWeight[fish.rarity]
	local difficultyFactor = 1 + fish.fightDifficulty / r.fightDifficultyDivisor
	return round(r.base * tierFactor * rarityWeight * difficultyFactor)
end

-- ── §9 co-op assist (generic; the Bayou has no apex → first does real work at Step 10). A second angler
-- adds NetDrain sublinearly, capped — the fishing analog of combat's co-op EffectiveHealth, using the
-- SHARED co-op constants (Tuning.combat.coop), not a fork. ──
function M.coopNetDrain(config: Config, baseNetDrain: number, partySize: number): number
	local coop = config.tuning.combat.coop
	local n = math.min(math.max(partySize, 1), coop.partyCap)
	return baseNetDrain * (1 + coop.hCoop * (n - 1))
end

return M
