--!strict
-- THE MASTER TUNING CONSTANTS — the entire EQUIPMENT_MASTER §1 set, plus the economy/progression
-- knobs the corpus enumerates. DATA ONLY in Step 1: the curves/resolution math that consume these
-- (WeaponDamage, ReelDrainMax, BreakThreshold, DR, Income, GearCost, Payout, FightTime…) are owned by
-- combat/fishing/economy and implemented in Steps 4–6. Captured here so Tier 9+ and retunes are config,
-- not code. Every magnitude is an illustrative default (a calibration knob), per the SYS_ docs.

local Tuning = {}

-- §1.1 Shared difficulty constant κ (combat + fishing, RD-F). Sets how fast Ceiling(T)−Floor(T) widens.
-- Realized as a geometric base (offensive curves) and an additive step (defensive/Pressure curve).
-- Owned JOINTLY with combat/fishing — do not change here unilaterally.
Tuning.spread = table.freeze({
	rho = 1.4, -- ρ — geometric base for offensive curves (the offensive face of κ)
	pStep = 22, -- P_step — additive step for the defensive/Pressure curve (the defensive face of κ)
})

-- §1.2 Offensive curves — weapon (hunting) and reel (fishing). Reel mirrors weapon by construction,
-- which is WHY hunting and fishing income scale identically (dual-loop balance is structural).
--   WeaponDamage(T,ℓ) = round(D1 · ρ^(T−1) · q(ℓ));  ReelDrainMax(T,ℓ) = round(R1 · ρ^(T−1) · q(ℓ))
Tuning.offensive = table.freeze({
	D1 = 18, -- weapon damage base (Tier-1 mid)
	R1 = 9, -- reel drain base (Tier-1 mid)
	rho = 1.4, -- shared geometric base (= spread.rho)
	q = table.freeze({ entry = 0.78, mid = 1.0, maxed = 1.28 }), -- intra-tier floor→apex spread ≈ 1.6×
})

-- §1.3 Weapon cycle/range — set TimeToKill and TimeToFind.
--   CycleTime: T1 1.50 · T2 1.40 · T3 1.30 · T4 1.25 · then −0.04/tier, floor 1.0
--   Range(T) = rangeBase + rangePerTier·(T−1);  RangeFalloff = inBand within band, → floor beyond.
Tuning.weapon = table.freeze({
	cycleTime = table.freeze({ [1] = 1.5, [2] = 1.4, [3] = 1.3, [4] = 1.25 }), -- explicit MVL tiers
	cycleTimeAnchorTier = 4, -- beyond this, CycleTime = cycleTime[4] − perTierDecrement·(T−4)
	cycleTimePerTierDecrement = 0.04,
	cycleTimeFloor = 1.0,
	rangeBase = 36,
	rangePerTier = 12,
	rangeFalloffInBand = 1.0,
	rangeFalloffFloor = 0.4,
	-- SettleTime is per-weapon/tunable (no §1 default) — owned by combat (Step 4). TODO(step-4).
})

-- §1.4 Defensive curves — armor (hunting) and rod Pressure (fishing).
-- ARMOR HAS NO ITEM-STAT CURVE: its only gating attribute is `tier`; DR is DERIVED by combat from the
-- tier gap and the CREATURE's tier — not a stored item stat. Template-B "Protection 1–100" is display only.
--   DR = clamp(drBase + drStep·(armorTier − creatureTier), drMin, drCap)
--   BreakThreshold(T,ℓ) = round((P1 + P_step·(T−1)) · pq(ℓ));  LandWindow = w·max(BreakThreshold−PeakRunForce,0)·dragSmooth
Tuning.defensive = table.freeze({
	drBase = 0.50, -- DR at tier parity (armorTier == creatureTier)
	drStep = 0.12, -- DR change per tier of gap
	drMin = 0.0,
	drCap = 0.85, -- hard cap — why defense is bounded and apex "behaves-as-+1-tier"
	rodP1 = 30, -- rod BreakThreshold base
	rodPStep = 22, -- additive step (= spread.pStep)
	rodPq = table.freeze({ entry = 0.90, mid = 1.0, maxed = 1.12 }),
	landWindowW = 1.0, -- w in the LandWindow formula
})

-- §1.5 Fishing fight constants (consumed by FightTime ≤ LandWindow).
--   StaminaToLand = k_s · FightDifficulty · (1 + weight/W_ref)
--   NetDrain = ReelDrainMax · E_expected − FishRecovery;  FishRecovery = r · FightDifficulty
--   PeakRunForce = p · FightDifficulty
Tuning.fishingFight = table.freeze({
	k_s = 0.5,
	W_ref = 10, -- kg
	r = 0.08, -- FishRecovery coefficient
	p = 0.6, -- PeakRunForce coefficient
	E_expected = 0.7, -- tension-efficiency reference (fishing analog of Z_expected)
})

-- §1.6 Skill reference for min-tier derivation. Gates clear for a body-shot (conservative) player;
-- vital hits are upside. Raising Z_expected re-derives every min-tier at once.
Tuning.skill = table.freeze({
	Z_expected = 1.0, -- = Z_body
	Z_vital = 2.5,
})

-- §1.7 Economy constants (consumed, not owned — from SYS_economy; balanceOf does not need them in Step 1).
--   Income(T) = B·g^(T−1);  GearCost_slot(T) = c·Income(T−1) (T≥2);  IntraTierClimb(T) ≈ m·Income(T)
Tuning.economy = table.freeze({
	B = 1000, -- Tier-1 base income (Cash/hr)
	g = 1.7, -- per-tier income growth (also the MVL-jump factor)
	c = 3, -- tier-gating gear cost: hours-of-prior-tier-income per slot
	m = 2.5, -- intra-tier climb cost: hours-of-current-tier-income (floor→apex, both slots)
	rarityMultiplier = table.freeze({
		Common = 1,
		Uncommon = 1.6,
		Rare = 2.8,
		Epic = 5,
		Legendary = 9,
		Mythic = 16,
	}),
	idleFraction = 0.15, -- fraction of current-tier active income accrued idle (Step 2 consumes)
	idleCapHours = 8, -- daily-return-hook clamp (Step 2 consumes)
})

-- Big one-time access/convenience sink multipliers (EQUIPMENT_MASTER §4.5–§4.7; coarse defaults, OQ-D).
--   BoatCost = b·Income(T_water);  MountCost ≈ mountMultiplier·GearCost_slot(T);  DogCost ≈ dogMultiplier·GearCost_slot(T)
Tuning.vehicles = table.freeze({
	boatB = 3.7,
	mountMultiplier = 2.0,
	dogMultiplier = 1.6,
})

-- Progression knob (progression §1 / tuning): the tier at which an empty armor slot becomes Tier 0
-- instead of Tier 1. Below it, armorless = Tier 1 (Bayou); at/above it, armorless = Tier 0.
Tuning.progression = table.freeze({
	armorGatingStartTier = 2,
})

-- §1.8 / §6 forward-compat hook for Open Question A. MVL reads raw 1–100, so TierCoefficient = 1.0
-- through T4; T5+ re-basing uses TierCoefficient(T) = κ^(T−1) (κ = spread.rho). Storing it now keeps
-- the T5+ change a config edit, not a schema migration.
Tuning.tierCoefficient = table.freeze({ [1] = 1.0, [2] = 1.0, [3] = 1.0, [4] = 1.0 })
Tuning.TIER_COEFFICIENT_KAPPA = 1.4 -- κ for TierCoefficient(T)=κ^(T−1) past T4 (combat/fishing ratify, OQ-A)

-- Data-integrity / persistence tuning (SYS_data_integrity §tuning). Consumed by Step 2's substrate.
Tuning.persistence = table.freeze({
	saveCadenceSeconds = 60, -- periodic dirty-flag autosave interval
	sessionLockTimeoutSeconds = 30, -- a stale lock (no heartbeat past this) may be stolen; a LIVE lock never is
	lockHeartbeatIntervalSeconds = 6, -- the holding server refreshes the lock this often (< timeout)
	saveRetryMaxAttempts = 5, -- failed-save retry budget (§7); on exhaustion revert to last good
	saveRetryBackoffSeconds = 2, -- base backoff between retries
	ledgerTailLength = 50, -- entries kept in the live profile before compaction folds the oldest away (§3)
	ledgerTailDays = 7, -- the audit-log-vs-in-profile rollback boundary (§7); Step 2 uses length for MVL
	escrowTimeoutSeconds = 120, -- pending-trade auto-cancel window (Step 12 consumes)
	-- artifactIdScheme = GUID (globally unique; injected IdGenerator). auditLogDestination = separate DataStore.
})

-- The mutations that force a write-through save (§1). Extensible config set, not a number.
Tuning.criticalSaveTriggers = table.freeze({
	tradeCommit = true,
	dispositionTransition = true,
	realMoneyCredit = true,
	destinationUnlock = true,
	conquest = true,
	gearPurchase = true,
})

return table.freeze(Tuning)
