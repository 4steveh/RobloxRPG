--!strict
-- Step 14 — PURE monetization logic + the active-payout multiplier invariant.
--   §D the 2x/VIP active-income multiplier (multiplicative stack, §7 ceiling, server-time expiry) applied
--      ONLY at the active kill/catch grant — idle/daily/salvage/the milestone flag are NEVER multiplied.
--   §A premium bait/ammo: the convenience EFFECT (grind compression, the band untouched) + the STRUCTURAL
--      ≤Uncommon cap (the rare roll is bait-free; the routine pool is Common/Uncommon; never mandatory).
--   §F the bounded rewarded-ad amount.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Enums = require("@src/types/Enums")
local Monetization = require("@src/logic/Monetization")
local Economy = require("@src/logic/Economy")
local Spawner = require("@src/logic/Spawner")
local Fishing = require("@src/logic/Fishing")
local Idle = require("@src/server/idle/Idle")
local RewardPipeline = require("@src/server/combat/RewardPipeline")
local Fakes = require("@src/server/persistence/Fakes")

return function(t: Harness.T)
	local MON = Catalog.tuning.monetization
	local function approx(a: number, b: number): boolean
		return math.abs(a - b) < 1e-9
	end
	local function grantMultiplier(p: any, tag: Enums.CashMultiplier, now: number)
		table.insert(p.activeEntitlements, { kind = Monetization.multiplierEntitlementKind(tag), expiryTimestamp = Monetization.multiplierExpiry(Catalog, tag, now) })
	end
	local function deps(now: number): RewardPipeline.PipelineDeps
		return { idGen = Fakes.newIdGenerator(), now = now, telemetry = Fakes.newTelemetry() }
	end
	local function huntEvent(targetId: string): RewardPipeline.KillEvent
		return { targetId = targetId, owner = "u1", validatingEventId = "k:" .. targetId, loop = Enums.Loop.Hunting }
	end

	t.section("§D multiplier — multiplicative stack, §7 ceiling, server-time expiry")
	do
		local p = Util.mkProfile(Catalog, {})
		t.eq("no entitlement → 1.0 (no-op)", Monetization.activeCashMultiplier(Catalog, p, 0), 1.0)
		grantMultiplier(p, Enums.CashMultiplier.boost2x, 0)
		t.eq("a 2x boost → 2.0", Monetization.activeCashMultiplier(Catalog, p, 0), MON.multipliers["2xBoost"])
		grantMultiplier(p, Enums.CashMultiplier.vip, 0)
		t.ok("VIP × boost stack MULTIPLICATIVELY (2.0 × 1.1)", approx(Monetization.activeCashMultiplier(Catalog, p, 0), MON.multipliers["2xBoost"] * MON.multipliers.vip))
		t.eq("the boost EXPIRES (server time; offline counts) → only persistent VIP remains", Monetization.activeCashMultiplier(Catalog, p, MON.boostDurationSeconds + 1), MON.multipliers.vip)
		-- the §7 max-stack ceiling bounds worst-case minting (pile multipliers past the cap)
		local q = Util.mkProfile(Catalog, {})
		for _ = 1, 5 do
			table.insert(q.activeEntitlements, { kind = Monetization.multiplierEntitlementKind(Enums.CashMultiplier.boost2x), expiryTimestamp = math.huge })
		end
		t.eq("piled multipliers clamp at maxStackCeiling", Monetization.activeCashMultiplier(Catalog, q, 0), MON.maxStackCeiling)
	end

	t.section("§D the multiplier hits the ACTIVE kill grant — a separate boost-tagged loop=none entry")
	do
		local p = Util.mkProfile(Catalog, {})
		grantMultiplier(p, Enums.CashMultiplier.boost2x, 1000)
		local base = Economy.payout(Catalog, 1, "Common", "bayou", Enums.Loop.Hunting)
		local r = RewardPipeline.resolve(p, Catalog, huntEvent("bayou_wood_duck"), deps(1000))
		t.eq("two ledger entries: the base faucet + the boost bonus", #p.cash.tail, 2)
		t.ok("the kill faucet is the UNMULTIPLIED routine payout (the reconciliation reads the formula — untouched)", p.cash.tail[1].type == "kill" and p.cash.tail[1].loop == "Hunting" and p.cash.tail[1].amount == base and p.cash.tail[1].realMoneyTag == nil)
		t.ok("the boost is a SEPARATE, real-money-tagged, loop=none entry (separable in telemetry)", p.cash.tail[2].type == "boostBonus" and p.cash.tail[2].loop == "none" and p.cash.tail[2].realMoneyTag == "realmoney:boost")
		t.eq("the bonus = round(base × 2) − base", p.cash.tail[2].amount, Monetization.boostBonus(base, 2.0))
		t.eq("result.cash = total granted (base + bonus)", r.cash, base + Monetization.boostBonus(base, 2.0))
		t.eq("result.boostCash isolates the bonus portion", r.boostCash, Monetization.boostBonus(base, 2.0))
	end

	t.section("§D idle / daily / salvage / the milestone are NEVER multiplied")
	do
		local p = Util.mkProfile(Catalog, { weapon = 1, rod = 1, reel = 1 })
		grantMultiplier(p, Enums.CashMultiplier.boost2x, 0) -- an ACTIVE boost on the profile
		-- idle reads Economy.income(T_idle) — NOT the active-grant path → unmultiplied (equals the base formula)
		local expectedIdle = math.floor(Catalog.tuning.economy.idleFraction * Economy.income(Catalog, 1) * 8)
		t.eq("idle accrual is unmultiplied (reads Income(T), not the grant)", Idle.economyAmount(p, Catalog, 8), expectedIdle)
		-- daily + salvage are pure formulas (take no profile/entitlement) → structurally unmultipliable
		t.eq("daily-quest reward is the base formula (no profile/entitlement arg)", Economy.dailyQuestReward(Catalog, 1), math.floor(Catalog.tuning.economy.dailyQuestFraction * Economy.income(Catalog, 1) + 0.5))
		t.ok("salvage floor takes no entitlement → unmultipliable", Economy.salvageFloor(Catalog, 1, "Legendary", Enums.Loop.Hunting) > 0)
		-- the milestone is a BOOLEAN, not Cash: a boosted milestone kill sets conquest ONCE (the boost adds
		-- Cash to the active kill; it never scales or re-sets the milestone state).
		local g = RewardPipeline.resolve(p, Catalog, huntEvent("bayou_american_alligator"), deps(0))
		t.ok("the milestone conquest is set once (a boolean — never multiplied)", g.conquestNewlySet == true and p.conqueredDestinations.bayou == true)
		t.ok("the boost added Cash to the active kill, but the milestone STATE is orthogonal", g.boostCash > 0)
	end

	t.section("§D rares mint — never multiplied (the multiplier lives only in the Cash branch)")
	do
		local p = Util.mkProfile(Catalog, {})
		grantMultiplier(p, Enums.CashMultiplier.boost2x, 0)
		local r = RewardPipeline.resolve(p, Catalog, huntEvent("bayou_white_alligator"), deps(0))
		t.ok("a rare mints an artifact, NO Cash — so the boost cannot apply (XOR + Cash-only multiplier)", r.mintedArtifactId ~= nil and r.cash == 0 and r.boostCash == 0 and #p.cash.tail == 0)
	end

	t.section("§A premium bait/ammo — the convenience EFFECT (grind compression; the band untouched)")
	do
		local baseBite = Catalog.tuning.fishing.engagement[1].timeToBite
		local biteEff = Monetization.premiumBaitTimeToBite(Catalog, baseBite)
		t.ok("premium bait shortens routine TimeToBite (more bites/hr)", biteEff < baseBite and biteEff > 0)
		t.ok("premium bait adds a small routine LandWindow bonus", Monetization.premiumBaitLandWindow(Catalog, 100) > 100)
		local baseCycle = Catalog.tuning.weapon.cycleTime[1]
		t.ok("premium ammo tightens the effective CycleTime (a settle edge)", Monetization.premiumAmmoCycleTime(Catalog, baseCycle) < baseCycle)
		-- the per-catch BAND is untouched: Economy.payout takes no bait arg — compression is more bites/hr, NOT
		-- more Cash/catch (the routine wage is structurally bait-independent).
		t.ok("the per-catch payout has no bait input", Economy.payout(Catalog, 1, "Common", "bayou", Enums.Loop.Fishing) > 0)
	end

	t.section("§A the cap is STRUCTURAL — the rare roll is BAIT-FREE")
	do
		local rare = Catalog.creatures.bayou_white_alligator
		-- rareSpawnEligible takes (target, world) ONLY — no bait/profile parameter exists, so holding premium
		-- bait cannot change a rare roll. It is CONDITION-gated by the world, full stop.
		t.ok("rare eligible when the WORLD conditions match", Spawner.rareSpawnEligible(rare, { time = "dawn or dusk", weather = "fog" }))
		t.ok("rare NOT eligible when a world condition fails (world-driven, never bait)", not Spawner.rareSpawnEligible(rare, { time = "noon", weather = "fog" }))
		-- a rare's spawn condition can name only world clauses (time/weather/season/event) — never bait/an item.
		local cond = rare.spawn.conditions
		local allowed: { [string]: boolean } = { time = true, weather = true, season = true, event = true }
		local onlyWorldKeys = true
		if cond ~= nil then
			for k in cond :: any do
				if not allowed[k] then
					onlyWorldKeys = false
				end
			end
		end
		t.ok("a rare's spawn condition can name only world clauses (no bait/item key — structural)", onlyWorldKeys)
	end

	t.section("§A the cap is STRUCTURAL — the routine bias is Common/Uncommon ONLY (≤Uncommon ceiling)")
	do
		local pool = Spawner.routineTargetsInZone(Catalog, "bayou", "channel_banks", "Fishing")
		t.ok("the routine fishing pool is non-empty", #pool > 0)
		local maxRank = 0
		for _, id in pool do
			local f = Catalog.fish[id]
			if Enums.RarityRank[f.rarity] > maxRank then
				maxRank = Enums.RarityRank[f.rarity]
			end
		end
		t.ok("every routine target is below Rare (the pool premium bait biases WITHIN)", maxRank < Enums.RARE_AND_ABOVE_RANK)
		t.eq("the ceiling premium bait can bias toward IS Uncommon", maxRank, Enums.RarityRank[Monetization.PREMIUM_BAIT_RARITY_CEILING])
		-- the bias weight: Common neutral, Uncommon biased up by the watch-knob; Rare-and-above is REJECTED — a
		-- category error (not a routine target) → a Rare-via-bait is UNREPRESENTABLE, not merely clamped.
		t.eq("Common keeps neutral weight 1.0", Monetization.premiumRoutineWeight(Catalog, "Common"), 1.0)
		t.ok("Uncommon is biased up by the watch-knob", Monetization.premiumRoutineWeight(Catalog, "Uncommon") > 1.0)
		t.errs("biasing a RARE is a category error (the structural cap — not in the routine pool)", function()
			Monetization.premiumRoutineWeight(Catalog, "Rare")
		end)
		t.errs("…and Legendary likewise", function()
			Monetization.premiumRoutineWeight(Catalog, "Legendary")
		end)
	end

	t.section("§A premium bait/ammo is NEVER MANDATORY (no target takeable only with it)")
	do
		for _, id in { "bait_premium_lure", "tackle_premium_ammo" } do
			local item = Catalog.equipment[id]
			t.ok(id .. " is convenience, never a tier input", item.tierInput == false and Util.anyContains(item.monetizationRoles :: any, "convenience"))
		end
		-- no fish names a premium item as its required bait/item → no catch is gated on premium gear
		local premiumIsRequired = false
		for _, f in Catalog.fish do
			if f.baitRequired == "bait_premium_lure" or f.requiresItem == "bait_premium_lure" or f.requiresItem == "tackle_premium_ammo" then
				premiumIsRequired = true
			end
		end
		t.ok("no fish requires a premium item to be caught (the not-a-timer rule)", not premiumIsRequired)
		-- every routine fish is landable at its authored min rod+reel WITHOUT premium bait → premium bait only
		-- IMPROVES odds, it never enables an otherwise-impossible catch.
		local bluegill = Catalog.fish.bayou_bluegill
		t.ok("a routine fish is landable at its authored gear with NO premium bait (improves, never enables)", Fishing.landableAt(Catalog, bluegill, bluegill.minRodTier, bluegill.minReelTier))
	end

	t.section("§F rewarded-ad reward — bounded + opt-in faucet amount")
	do
		t.ok("ad reward is positive and capped at the absolute ceiling", Monetization.adReward(Catalog, 1) > 0 and Monetization.adReward(Catalog, 1) <= MON.adReward.absoluteCap)
		t.eq("a high tier is HARD-CAPPED at absoluteCap (bounded — not a farming vector)", Monetization.adReward(Catalog, 9), MON.adReward.absoluteCap)
		t.ok("the reward is a small fraction of current-tier income (≤ the daily faucet)", Monetization.adReward(Catalog, 1) <= Economy.dailyQuestReward(Catalog, 1))
	end
end
