--!strict
-- PURE ECONOMY FORMULAS (SYS_economy §2/§3/§4/§5/§6). Implements the functions that consume the EXISTING
-- `Tuning.economy` constants (B/g/c/m, the rarity ladder, idle/salvage fractions) — Step 1 authored the
-- constants as "consumed, not owned"; Step 6 owns the math. Cash is server-authoritative and append-only
-- (the Ledger, Step 2); these are the pure amounts the faucets/sinks move. The felt pacing + the LIVE
-- (measured) reconciliation are Studio/telemetry; this is the headless, by-construction half.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Spawner = require("@src/logic/Spawner")

type Config = Schema.Config
type Loop = Enums.Loop
type Rarity = Enums.Rarity

local M = {}

local function round(x: number): number
	return math.floor(x + 0.5)
end

-- §2 income band: Income(T) = B·g^(T−1) (T1 1000 · T2 1700 · T3 2890 · T4 4913). Never stored.
function M.income(config: Config, tier: number): number
	local e = config.tuning.economy
	return e.B * e.g ^ (tier - 1)
end

-- §3 tier axis (gates Destinations): GearCostSlot(T) = c·Income(T−1), T≥2; Tier 1 gating gear is the free starter.
function M.gearCostSlot(config: Config, tier: number): number
	if tier <= 1 then
		return 0
	end
	return round(config.tuning.economy.c * M.income(config, tier - 1)) -- integer Cash debit (no float drift)
end

-- §3 intra-tier axis (drives the floor→apex climb; never gates): total climb = m·Income(T).
function M.intraTierClimb(config: Config, tier: number): number
	return config.tuning.economy.m * M.income(config, tier)
end

-- The cost of one intra-tier step, split across entry→mid→maxed by the q-curve stat gain (sums to IntraTierClimb).
function M.intraTierUpgradeCost(config: Config, tier: number, fromLevel: string): number
	local q = config.tuning.offensive.q
	local span = q.maxed - q.entry
	local delta = if fromLevel == "entry" then (q.mid - q.entry) else (q.maxed - q.mid)
	return round(M.intraTierClimb(config, tier) * (delta / span))
end

-- §5 rarity ladder (Common 1 · Uncommon 1.6 · Rare 2.8 · Epic 5 · Legendary 9 · Mythic 16).
function M.rarityMultiplier(config: Config, rarity: string): number
	return (config.tuning.economy.rarityMultiplier :: { [string]: number })[rarity]
end

-- The reward-bearing ROUTINE population of a (destination, loop): Common/Uncommon non-ambiance targets
-- (RD5 — rares are bonus on top, excluded). The set the band is normalized over (uniform spawn over species).
type RoutineTarget = { tier: number, rarity: Rarity }
local function routinePopulation(config: Config, destinationId: string, loop: Loop): { RoutineTarget }
	local pop: { RoutineTarget } = {}
	if loop == Enums.Loop.Fishing then
		for _, f in config.fish do
			if f.destinationId == destinationId and Enums.RarityRank[f.rarity] < Enums.RARE_AND_ABOVE_RANK then
				table.insert(pop, { tier = f.tier, rarity = f.rarity })
			end
		end
	else
		for _, c in config.creatures do
			if c.destinationId == destinationId and not c.ambianceOnly and Enums.RarityRank[c.rarity] < Enums.RARE_AND_ABOVE_RANK then
				table.insert(pop, { tier = c.tier, rarity = c.rarity })
			end
		end
	end
	return pop
end

-- The spawn-weighted (uniform-over-species) mean RarityMultiplier over the routine population — the divisor
-- that makes each loop's routine hour sum to exactly Income(T), independent of that loop's Common/Uncommon mix.
function M.avgRoutineMultiplier(config: Config, destinationId: string, loop: Loop): number
	local pop = routinePopulation(config, destinationId, loop)
	assert(#pop > 0, "Economy.avgRoutineMultiplier: no routine population for " .. destinationId)
	local sum = 0
	for _, target in pop do
		sum += M.rarityMultiplier(config, target.rarity)
	end
	return sum / #pop
end

-- §5 routine payout (the band), NORMALIZED per loop. Denominator = the MODELED engagement rate (not the
-- ceiling-clamped rate). Income(T) uses the TARGET's displayed tier (a re-skin pays its displayed-tier wage).
function M.payoutExact(config: Config, tier: number, rarity: string, destinationId: string, loop: Loop): number
	local baseline = M.income(config, tier) / Spawner.modeledRatePerHour(config, tier, loop)
	return baseline * (M.rarityMultiplier(config, rarity) / M.avgRoutineMultiplier(config, destinationId, loop))
end

function M.payout(config: Config, tier: number, rarity: string, destinationId: string, loop: Loop): number
	return round(M.payoutExact(config, tier, rarity, destinationId, loop))
end

-- §5 salvage floor: a rare's NPC-vendor Cash, a deliberately LOW fraction of its conceptual faucet value
-- (so rare value flows to P2P trade / the Trophy Hall, not the Cash supply). Step 8 credits this on →SALVAGED.
function M.salvageFloor(config: Config, tier: number, rarity: string, loop: Loop?): number
	local l = loop or Enums.Loop.Hunting
	local baseline = M.income(config, tier) / Spawner.modeledRatePerHour(config, tier, l)
	return round(config.tuning.economy.salvageFloorFraction * baseline * M.rarityMultiplier(config, rarity))
end

-- §9 evergreen sink (Step 8): the Cash cost of the (boughtSlots+1)-th Trophy-Hall display slot. ESCALATING
-- and UNCAPPED (the unbounded inflation-ballast property) — base · growth^boughtSlots. Integer Cash (no
-- float drift). The absolute numbers are economy's to ratify; the escalating-uncapped shape is fixed.
function M.slotExpansionPrice(config: Config, boughtSlots: number): number
	local l = config.tuning.lodge
	return round(l.slotExpansionBase * l.slotExpansionGrowth ^ boughtSlots)
end

-- §1/§6 daily-quest amounts (Step 7). Both scale off the player's current tier (the caller passes
-- T_current = max(EHT, EFT), the idle resolution): the daily faucet is a fraction of Income(T); the
-- cross-loop bonus is ≈ half an hour of current-tier income (the breadth kicker for one hunt + one catch).
function M.dailyQuestReward(config: Config, tier: number): number
	return round(config.tuning.economy.dailyQuestFraction * M.income(config, tier))
end
function M.crossLoopBonus(config: Config, tier: number): number
	return round(config.tuning.economy.crossLoopBonusHours * M.income(config, tier))
end

-- §6 reconciliation: the normalized routine hour for a (destination, loop) — equals Income(dest tier) BY
-- CONSTRUCTION (mean of mult/avgMult = 1). The test asserts this per MVL tier on each loop → parity is
-- automatic despite different absolute rates and different per-loop Common/Uncommon mixes.
function M.routineHourSum(config: Config, destinationId: string, loop: Loop): number
	local dst = assert(config.destinations[destinationId], "Economy.routineHourSum: unknown destination " .. destinationId)
	local pop = routinePopulation(config, destinationId, loop)
	assert(#pop > 0, "Economy.routineHourSum: no routine population for " .. destinationId)
	local sum = 0
	for _, target in pop do
		sum += M.payoutExact(config, target.tier, target.rarity, destinationId, loop)
	end
	return Spawner.modeledRatePerHour(config, dst.tier, loop) * (sum / #pop)
end

return M
