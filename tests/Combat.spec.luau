--!strict
-- Step 4 (hunting) — combat math, anti-exploit validators, the Bayou-wide non-lethal clamp, co-op
-- scaling, and the min-weapon/min-armor-tier DERIVATION (asserted against the catalog's authored values).
-- All headless-pure: the game FEEL (recoil/hit-stop/audio/haptics/aim) is Studio (README checklist).

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Combat = require("@src/logic/Combat")

local function approx(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

return function(t: Harness.T)
	-- ── Prerequisites (P1 spawnZones, P2 KillWindow inputs) landed on the Bayou roster ──
	t.section("Step-1 schema gaps closed — spawnZones + KillWindow inputs on the Bayou roster")
	do
		local duck = Catalog.creatures.bayou_wood_duck
		local rabbit = Catalog.creatures.bayou_swamp_rabbit
		local nutria = Catalog.creatures.bayou_nutria
		local gator = Catalog.creatures.bayou_american_alligator
		t.ok("wood duck carries a structured spawnZone (sunny_levee)", duck.spawnZones ~= nil and Util.anyContains(duck.spawnZones :: any, "sunny_levee"))
		t.ok("wood duck keeps the prose spawn.location", duck.spawn.location ~= "")
		t.ok("wood duck escape window = 4 s (TimeToFlee, LOC §3)", duck.escapeWindowSeconds == 4)
		t.ok("swamp rabbit escape window = 5 s", rabbit.escapeWindowSeconds == 5)
		t.ok("Nutria floor creature exists (LOC §3), health 30, escape 6 s", nutria ~= nil and nutria.health == 30 and nutria.escapeWindowSeconds == 6)
		t.ok("alligator carries attackInterval = 3 s (survival-bounded form input)", gator.attackIntervalSeconds == 3)
		t.ok("alligator carries spawnZones resolving to real zones", gator.spawnZones ~= nil and Util.anyContains(gator.spawnZones :: any, "channel_banks"))
	end

	-- ── Tuning.combat present ──
	t.section("Tuning.combat — the combat-owned knobs are present")
	do
		local c = Catalog.tuning.combat
		t.ok("zone multipliers vital/body/limb = 2.5/1.0/0.5", c.zone.vital == 2.5 and c.zone.body == 1.0 and c.zone.limb == 0.5)
		t.ok("player base HP = 100", c.playerBaseHP == 100)
		t.ok("non-lethal floor = 1 HP, Bayou is non-lethal", c.nonLethalMinHP == 1 and c.nonLethalDestinations.bayou == true)
		t.ok("co-op h_coop 0.5, partyCap 4", c.coop.hCoop == 0.5 and c.coop.partyCap == 4)
	end

	-- ── Task 3: the deferred EQUIPMENT_MASTER §1 offensive curve + damage/kill math ──
	t.section("Combat — weapon/cycle/range curves (EQUIPMENT_MASTER §1)")
	do
		t.ok("WeaponDamage(1,mid) = round(18·1.4^0·1.0) = 18 (the §3 floor reference)", Combat.weaponDamage(Catalog, 1) == 18)
		t.ok("WeaponDamage defaults to mid gear", Combat.weaponDamage(Catalog, 1, "mid") == 18)
		t.ok("WeaponDamage(2,mid) = round(18·1.4) = 25", Combat.weaponDamage(Catalog, 2) == 25)
		t.ok("WeaponDamage(1,entry) = round(18·0.78) = 14", Combat.weaponDamage(Catalog, 1, "entry") == 14)
		t.ok("WeaponDamage(1,maxed) = round(18·1.28) = 23", Combat.weaponDamage(Catalog, 1, "maxed") == 23)
		t.ok("CycleTime(1) = 1.5", approx(Combat.cycleTime(Catalog, 1), 1.5))
		t.ok("CycleTime(4) = 1.25", approx(Combat.cycleTime(Catalog, 4), 1.25))
		t.ok("CycleTime(5) = 1.25 − 0.04 = 1.21 (anchor + per-tier decrement)", approx(Combat.cycleTime(Catalog, 5), 1.21))
		t.ok("CycleTime floors at 1.0 (never below)", approx(Combat.cycleTime(Catalog, 99), 1.0))
		t.ok("Range(1) = 36; Range(2) = 48", Combat.weaponRange(Catalog, 1) == 36 and Combat.weaponRange(Catalog, 2) == 48)
		t.ok("maxEffectiveRange(1) = 36·1.5 = 54", approx(Combat.maxEffectiveRange(Catalog, 1), 54))
		t.ok("RangeFalloff in-band = 1.0", approx(Combat.rangeFalloff(Catalog, 1, 30), 1.0))
		t.ok("RangeFalloff at max extension = floor 0.4", approx(Combat.rangeFalloff(Catalog, 1, 54), 0.4))
		t.ok("RangeFalloff mid-extension lerps (45 studs → 0.7)", approx(Combat.rangeFalloff(Catalog, 1, 45), 0.7))
		t.ok("RangeFalloff beyond max = 0 (out of range)", approx(Combat.rangeFalloff(Catalog, 1, 60), 0))
	end

	t.section("Combat — ShotDamage / ShotsToKill / TimeToKill / armor DR")
	do
		t.ok("ShotDamage = WeaponDamage·Zone·Falloff (18·2.5·1.0 = 45 vital)", approx(Combat.shotDamage(18, 2.5, 1.0), 45))
		t.ok("ShotsToKill(gator 48, dmg 18, body, in-band) = ceil(48/18) = 3", Combat.shotsToKill(48, 18, 1.0, 1.0) == 3)
		t.ok("ShotsToKill(duck 15) = 1", Combat.shotsToKill(15, 18, 1.0, 1.0) == 1)
		t.ok("ShotsToKill(rabbit 22) = 2", Combat.shotsToKill(22, 18, 1.0, 1.0) == 2)
		t.ok("TimeToKill(3 shots, CycleTime 1.5) = 4.5 s", approx(Combat.timeToKill(3, 1.5), 4.5))
		t.ok("DR at tier parity (armor2 vs creature2) = 0.50", approx(Combat.dr(Catalog, 2, 2), 0.50))
		t.ok("DR one tier ahead = 0.62", approx(Combat.dr(Catalog, 3, 2), 0.62))
		t.ok("DR one tier behind = 0.38 (under-armoring punished)", approx(Combat.dr(Catalog, 1, 2), 0.38))
		t.ok("DR caps at 0.85 (defense is bounded → apex behaves as +1 tier)", approx(Combat.dr(Catalog, 9, 2), 0.85))
		t.ok("DamageTaken = CreatureDamage·(1−DR) (70 @ DR0.38 → 43.4)", approx(Combat.damageTaken(70, 0.38), 43.4))
	end

	-- ── Task 4: co-op scaling + the Bayou-wide non-lethal clamp + the kill-window inequality ──
	t.section("Combat — co-op EffectiveHealth (sublinear, capped at partyCap)")
	do
		t.ok("solo (N=1) = base Health", approx(Combat.coopEffectiveHealth(Catalog, 100, 1), 100))
		t.ok("party of 4 = 100·(1+0.5·3) = 250 (sublinear vs 4× DPS)", approx(Combat.coopEffectiveHealth(Catalog, 100, 4), 250))
		t.ok("scaling is capped at partyCap (N=9 clamps to N=4 → 250)", approx(Combat.coopEffectiveHealth(Catalog, 100, 9), 250))
	end

	t.section("Combat — Bayou-wide non-lethal clamp (armorless player can never be downed in the Bayou)")
	do
		t.ok("every Bayou creature is non-lethal, incl. the aggressive gator", Combat.isNonLethal(Catalog, Catalog.creatures.bayou_american_alligator))
		t.ok("a lethal-tier creature is NOT clamped (Appalachia boar)", Combat.isNonLethal(Catalog, Catalog.creatures.appalachia_wild_boar) == false)
		-- the gator's raw 15 dmg, applied forever, never downs an armorless player (HP floored at 1)
		local hp = 100
		for _ = 1, 100 do
			hp = Combat.resolvePlayerHP(Catalog, hp, 15, true)
		end
		t.ok("armorless player survives 100 gator lunges (floored at 1 HP, never downed)", hp == 1)
		t.ok("a single huge non-lethal hit still floors at 1, never below", Combat.resolvePlayerHP(Catalog, 100, 999, true) == 1)
		t.ok("a LETHAL hit (nonLethal=false) can down to 0", Combat.resolvePlayerHP(Catalog, 100, 100, false) == 0)
	end

	t.section("Combat — the kill-window inequality (ShotsToKill ≤ KillWindow / CycleTime)")
	do
		t.ok("3 shots fit an unbounded (non-lethal) window", Combat.isKillable(3, math.huge, 1.5))
		t.ok("escape-bounded: 2 shots fit a 5 s window at CycleTime 1.5 (2 ≤ 3.33)", Combat.isKillable(2, 5, 1.5))
		t.ok("escape-bounded: 4 shots do NOT fit a 5 s window (4 > 3.33) → not killable at this tier", Combat.isKillable(4, 5, 1.5) == false)
	end

	-- ── Task 5: server-side anti-exploit validators (the build-notes set; pure, headless) ──
	t.section("Combat — anti-exploit: zone legality + fire-rate + range")
	do
		t.ok("legal zones are vital/body/limb", Combat.zoneLegal(Catalog, "vital") and Combat.zoneLegal(Catalog, "body") and Combat.zoneLegal(Catalog, "limb"))
		t.ok("a spoofed zone ('head') is illegal", Combat.zoneLegal(Catalog, "head") == false)
		t.ok("zoneMultiplier resolves vital 2.5 / body 1.0 / limb 0.5", Combat.zoneMultiplier(Catalog, "vital") == 2.5 and Combat.zoneMultiplier(Catalog, "limb") == 0.5)
		t.ok("fire-rate: a shot at exactly CycleTime is allowed", Combat.fireRateOk(Catalog, 0, 1.5, 1.5))
		t.ok("fire-rate: a shot FASTER than CycleTime is rejected (fire-rate hack)", Combat.fireRateOk(Catalog, 0, 1.0, 1.5) == false)
		t.ok("range: a shot inside max-effective range is allowed", Combat.rangeOk(Catalog, 1, 30))
		t.ok("range: an out-of-range shot is rejected (54-stud cap at T1)", Combat.rangeOk(Catalog, 1, 60) == false)
	end

	t.section("Combat — anti-exploit: damage must be derivable from equipped weapon × legal zone × range")
	do
		-- T1 mid weapon, body zone, in-band → 18·1.0·1.0 = 18
		t.ok("a correctly-derived body-shot damage is accepted", Combat.damageDerivable(Catalog, 1, "mid", "body", 10, 18))
		t.ok("a vital shot derives 45 and is accepted", Combat.damageDerivable(Catalog, 1, "mid", "vital", 10, 45))
		t.ok("rounding slack within damageToleranceAbs is accepted", Combat.damageDerivable(Catalog, 1, "mid", "body", 10, 19))
		t.ok("a 999-damage SPOOF is rejected", Combat.damageDerivable(Catalog, 1, "mid", "body", 10, 999) == false)
		t.ok("an illegal zone makes the damage non-derivable", Combat.damageDerivable(Catalog, 1, "mid", "head", 10, 18) == false)
		t.ok("an out-of-range claim is non-derivable", Combat.damageDerivable(Catalog, 1, "mid", "body", 60, 18) == false)
	end

	t.section("Combat — LOS decision (the through-wall check; raycast itself is Studio)")
	do
		t.ok("no ray hit → no kill", Combat.losOk(nil, "bayou_wood_duck") == false)
		t.ok("ray hit a wall (not the claimed target) → rejected (through-wall)", Combat.losOk("wall", "bayou_wood_duck") == false)
		t.ok("ray hit the claimed target → LOS ok", Combat.losOk("bayou_wood_duck", "bayou_wood_duck"))
	end

	-- ── Task 6: Rank XP weighting + the min-tier DERIVATION (asserted against the catalog) ──
	t.section("Combat — Rank XP is difficulty/rarity-weighted (SYS_progression §4)")
	do
		local duckXP = Combat.rankXP(Catalog, Catalog.creatures.bayou_wood_duck)
		local gatorXP = Combat.rankXP(Catalog, Catalog.creatures.bayou_american_alligator)
		local ghostGatorXP = Combat.rankXP(Catalog, Catalog.creatures.bayou_white_alligator)
		t.ok("a kill awards positive Rank XP", duckXP > 0)
		t.ok("the aggressive Uncommon gator outweighs the Common duck (apex > floor + rarity)", gatorXP > duckXP)
		t.ok("a Legendary ≫ a Common (the Ghost Gator dwarfs the duck)", ghostGatorXP > duckXP * 5)
	end

	t.section("Combat — min-weapon/min-armor-tier are DERIVED; catalog's authored values match (Bayou)")
	do
		local function dm(id: string)
			return Combat.deriveMinTiers(Catalog, Catalog.creatures[id])
		end
		t.eq("wood duck → {1,0} (1 shot, escape-bounded, non-lethal)", dm("bayou_wood_duck"), { minWeaponTier = 1, minArmorTier = 0 })
		t.eq("swamp rabbit → {1,0}", dm("bayou_swamp_rabbit"), { minWeaponTier = 1, minArmorTier = 0 })
		t.eq("nutria → {1,0}", dm("bayou_nutria"), { minWeaponTier = 1, minArmorTier = 0 })
		t.eq("alligator → {1,0} (ceil(48/18)=3 shots in an unbounded non-lethal window)", dm("bayou_american_alligator"), { minWeaponTier = 1, minArmorTier = 0 })
		t.eq("white gator (reskin) → {1,0}", dm("bayou_white_alligator"), { minWeaponTier = 1, minArmorTier = 0 })
		t.ok("min-armor-tier is n/a (0) across the whole non-lethal Bayou", (function()
			for _, c in Catalog.creatures do
				if c.destinationId == "bayou" and not c.ambianceOnly then
					if Combat.deriveMinTiers(Catalog, c).minArmorTier ~= 0 then
						return false
					end
				end
			end
			return true
		end)())
	end

	t.section("Combat — the derivation has teeth (would catch a mis-statted creature)")
	do
		local mis = table.clone(Catalog.creatures.bayou_swamp_rabbit)
		mis.health = 9999 -- absurd HP: no MVL weapon kills it inside the 5 s escape window
		t.ok("a 9999-HP 'rabbit' no longer derives min-weapon-tier 1 (so a mis-stat fails the load assertion)", Combat.deriveMinTiers(Catalog, mis).minWeaponTier ~= 1)
	end

	t.section("Combat — survival window uses (hitsToDown−1)·interval + the apex behaves-as-T+1 offset")
	do
		-- Boar (mid, NOT apex): H88 dmg40 interval3.0. At T2 armor (parity, DR 0.50): taken 20,
		-- hitsToDown ceil(100/20)=5, window (5−1)·3 = 12 s. Killable at T2 (4 shots·1.4 = 5.6 ≤ 12).
		local boar = table.clone(Catalog.creatures.appalachia_wild_boar)
		boar.tier = 2
		boar.health = 88
		boar.damageToPlayer = 40
		boar.attackIntervalSeconds = 3.0
		boar.behavior = "aggressive"
		boar.coop = "soloTopGear"
		t.ok("boar is NOT flagged apex (coop != party)", Combat.isApex(boar) == false)
		t.ok("boar soloable at authored T2 weapon+armor (tense, safe)", Combat.soloableAt(Catalog, boar, 2, 2))
		-- Cougar (apex, behaves-as-T3): H100 dmg76 interval2.7. NOT soloable at T2, soloable at T3.
		local cougar = table.clone(Catalog.creatures.appalachia_mountain_lion)
		cougar.tier = 2
		cougar.health = 100
		cougar.damageToPlayer = 76
		cougar.attackIntervalSeconds = 2.7
		cougar.behavior = "aggressive"
		cougar.coop = "party"
		t.ok("cougar IS flagged apex (coop == party)", Combat.isApex(cougar))
		t.ok("cougar NOT soloable at T2 (window 5.4 s, 4 shots·1.4 = 5.6 > window)", Combat.soloableAt(Catalog, cougar, 2, 2) == false)
		t.ok("cougar soloable at T3 (the apex needs T+1 solo)", Combat.soloableAt(Catalog, cougar, 3, 3))
		-- Grizzly (apex, top tier): T4 H100 dmg85 interval2.5. NOT soloable at T4, soloable at T5.
		local grizzly = table.clone(Catalog.creatures.appalachia_wild_boar)
		grizzly.tier = 4
		grizzly.health = 100
		grizzly.damageToPlayer = 85
		grizzly.attackIntervalSeconds = 2.5
		grizzly.behavior = "aggressive"
		grizzly.coop = "party"
		t.ok("grizzly NOT soloable at T4 (apex effTier=5, window 2.5 s, 3 shots·1.25 = 3.75 > 2.5)", Combat.soloableAt(Catalog, grizzly, 4, 4) == false)
		t.ok("grizzly soloable at T5 (window 5.0 s, 2 shots·1.21 = 2.42 ≤ 5.0)", Combat.soloableAt(Catalog, grizzly, 5, 5))
	end

	-- ── Task 1.1 (Step 10): Appalachia KillWindow inputs + spawnZones ──
	t.section("Combat — Appalachia KillWindow inputs + spawnZones (LOC_02 §3)")
	do
		local boar = Catalog.creatures.appalachia_wild_boar
		local coyote = Catalog.creatures.appalachia_coyote
		local cougar = Catalog.creatures.appalachia_mountain_lion
		local deer = Catalog.creatures.appalachia_whitetail_deer
		t.ok("boar attackInterval = 3.0 s (LOC_02 §3)", boar.attackIntervalSeconds == 3.0)
		t.ok("coyote attackInterval = 2.0 s", coyote.attackIntervalSeconds == 2.0)
		t.ok("cougar attackInterval = 2.7 s", cougar.attackIntervalSeconds == 2.7)
		t.ok("whitetail carries an escape window + spawnZones", deer.escapeWindowSeconds ~= nil and deer.spawnZones ~= nil)
		t.ok("non-threat fleer minArmor is n/a (0), matching the derivation", deer.minArmorTierToSurvive == 0)
		t.ok("every non-ambiance Appalachia creature carries spawnZones", (function()
			for _, c in Catalog.creatures do
				if c.destinationId == "appalachia" and not c.ambianceOnly and (c.spawnZones == nil or #(c.spawnZones :: any) == 0) then return false end
			end
			return true
		end)())
	end

	-- ── Task 0.2 (Step 10): co-op-soloable helper (§6 party clears co-op-scaled Health; tank survives) ──
	t.section("Combat — co-op-soloable: party clears the apex that is a solo wall at T4")
	do
		-- Synthetic grizzly (the Step-10 Alaska apex archetype): tier=4, apex (coop="party"),
		-- health=100, damageToPlayer=85, attackIntervalSeconds=2.5.
		-- Solo at T4: effTier=5, DR(4,5)=0.38, taken=52.7, hitsToDown=2, window=2.5 s; 3 shots*1.25=3.75 > 2.5 → WALL.
		-- Co-op at T4 (partyCap=4): effHealth=250, perDmg=49, killTime≈1.594 s, tankHits=floor(1.594/2.5)=0 → 0<100 → TRUE.
		local grizzly = table.clone(Catalog.creatures.appalachia_wild_boar)
		grizzly.tier = 4
		grizzly.health = 100
		grizzly.damageToPlayer = 85
		grizzly.attackIntervalSeconds = 2.5
		grizzly.behavior = "aggressive"
		grizzly.coop = "party"
		t.ok("grizzly NOT soloable at T4/T4 (the solo wall)", Combat.soloableAt(Catalog, grizzly, 4, 4) == false)
		t.ok("grizzly co-op-soloable at T4 with full party (partyCap=4)", Combat.coopSoloableAt(Catalog, grizzly, 4, Catalog.tuning.combat.coop.partyCap))
		t.ok("grizzly NOT co-op-soloable solo (party of 1 == solo wall)", Combat.coopSoloableAt(Catalog, grizzly, 4, 1) == false)
	end
end
