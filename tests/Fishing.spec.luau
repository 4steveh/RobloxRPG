--!strict
-- Step 5 (fishing) — the catchability math (FightTime ≤ LandWindow), the min rod/reel-tier DERIVATION
-- (asserted == the catalog), Angler Rank XP weighting, the drain/tension anti-exploit validators, and the
-- generic co-op assist. All headless-pure. The fight FEEL (tension gauge, runs, haptics, cast) is Studio.

local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Util = require("@tests/util")
local Fishing = require("@src/logic/Fishing")

local function approx(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

local function contains(list: { string }, needle: string): boolean
	for _, s in list do
		if s == needle then
			return true
		end
	end
	return false
end

return function(t: Harness.T)
	-- ── Prerequisite (spawnZones on the Fish schema) + Tuning.fishing ──
	t.section("Step-5 prerequisite — spawnZones on the Bayou fish + Tuning.fishing present")
	do
		local blue = Catalog.fish.bayou_blue_catfish
		t.ok("blue catfish carries a structured spawnZone (catfish_hole)", blue.spawnZones ~= nil and contains(blue.spawnZones :: any, "catfish_hole"))
		t.ok("bluegill is placed in the shore-accessible channel banks", (function()
			local z = Catalog.fish.bayou_bluegill.spawnZones
			return z ~= nil and contains(z :: any, "channel_banks")
		end)())
		t.ok("fishing engagement T1 = bite 20 / fight 18 / overhead 22 (→ 60/hr, SYS_fishing §5)", (function()
			local e = Catalog.tuning.fishing.engagement[1]
			return e.timeToBite == 20 and e.fightTime == 18 and e.overhead == 22
		end)())
		t.ok("fishingFight.dragSmooth present (LandWindow reel factor)", approx(Catalog.tuning.fishingFight.dragSmooth, 1.0))
		t.ok("Angler rankXP weighting table present (tier × rarity × fight-difficulty)", Catalog.tuning.fishing.rankXP.base == 10 and Catalog.tuning.fishing.rankXP.fightDifficultyDivisor == 100)
	end

	-- ── Task 2: the deferred EQUIPMENT_MASTER §1 fishing curves + the §2 catchability inequality ──
	t.section("Fishing — reel/rod curves (EQUIPMENT_MASTER §1; reel = weapon-analog, rod = armor-analog)")
	do
		t.ok("ReelDrainMax(1,mid) = round(9·1.4^0) = 9", Fishing.reelDrainMax(Catalog, 1) == 9)
		t.ok("ReelDrainMax(2,mid) = round(9·1.4) = 13", Fishing.reelDrainMax(Catalog, 2) == 13)
		t.ok("ReelDrainMax(1,entry) = round(9·0.78) = 7 (the starter reel sits at the intra-tier floor)", Fishing.reelDrainMax(Catalog, 1, "entry") == 7)
		t.ok("BreakThreshold(1,mid) = round(30) = 30", Fishing.breakThreshold(Catalog, 1) == 30)
		t.ok("BreakThreshold(2,mid) = round(30+22) = 52", Fishing.breakThreshold(Catalog, 2) == 52)
	end

	t.section("Fishing — catchability: FightTime ≤ LandWindow (mirror of combat's kill inequality)")
	do
		local blue = Catalog.fish.bayou_blue_catfish -- FD 34, typical max 9 kg
		t.ok("StaminaToLand = k_s·FD·(1+w/W_ref) = 0.5·34·1.9 = 32.3", approx(Fishing.staminaToLand(Catalog, blue), 32.3))
		t.ok("FishRecovery = r·FD = 2.72", approx(Fishing.fishRecovery(Catalog, blue), 2.72))
		t.ok("PeakRunForce = p·FD = 20.4", approx(Fishing.peakRunForce(Catalog, blue), 20.4))
		local nd = Fishing.netDrain(Fishing.reelDrainMax(Catalog, 1), 0.7, Fishing.fishRecovery(Catalog, blue))
		t.ok("NetDrain = ReelDrainMax·E − FishRecovery = 9·0.7 − 2.72 = 3.58", approx(nd, 3.58))
		t.ok("FightTime = StaminaToLand / NetDrain ≈ 9.02 s", approx(Fishing.fightTime(Fishing.staminaToLand(Catalog, blue), nd), 32.3 / 3.58))
		t.ok("NetDrain ≤ 0 → FightTime is ∞ (a too-weak reel never lands)", Fishing.fightTime(32.3, -1) == math.huge)
		local lw = Fishing.landWindow(Catalog, 1, 1, blue, "mid")
		t.ok("LandWindow = w·max(BreakThreshold − PeakRunForce, 0)·dragSmooth = max(30−20.4,0) = 9.6", approx(lw, 9.6))
		t.ok("the milestone blue catfish IS landable at rod1/reel1 (mid gear): 9.02 ≤ 9.6", Fishing.landable(Fishing.fightTime(Fishing.staminaToLand(Catalog, blue), nd), lw))
	end

	t.section("Fishing — anti-exploit: tension legality + drain must be derivable from the equipped reel")
	do
		t.ok("legal tension E ∈ [0,1]", Fishing.tensionLegal(0.7) and Fishing.tensionLegal(0) and Fishing.tensionLegal(1))
		t.ok("E > 1 is illegal", Fishing.tensionLegal(1.5) == false)
		t.ok("a correctly-derived drain (9·0.7 = 6.3) is accepted", Fishing.drainDerivable(Catalog, 1, "mid", 0.7, 6.3))
		t.ok("an instant-drain SPOOF is rejected", Fishing.drainDerivable(Catalog, 1, "mid", 0.7, 999) == false)
		t.ok("an illegal tension makes the drain non-derivable", Fishing.drainDerivable(Catalog, 1, "mid", 2, 6.3) == false)
	end

	t.section("Fishing — co-op assist (generic; not Bayou-load-bearing — shared co-op constant, RD-F)")
	do
		t.ok("solo NetDrain unchanged", approx(Fishing.coopNetDrain(Catalog, 10, 1), 10))
		t.ok("a party of 4 adds drain sublinearly = 10·(1+0.5·3) = 25", approx(Fishing.coopNetDrain(Catalog, 10, 4), 25))
		t.ok("capped at partyCap (N=9 → N=4 → 25)", approx(Fishing.coopNetDrain(Catalog, 10, 9), 25))
	end

	-- ── Task 3: min rod/reel-tier DERIVATION (asserted == the catalog for the routine Bayou band) ──
	t.section("Fishing — min rod/reel tiers are DERIVED; catalog's authored values match (routine Bayou)")
	do
		local function dm(id: string)
			return Fishing.deriveMinTiers(Catalog, Catalog.fish[id])
		end
		t.eq("bluegill → {1,1}", dm("bayou_bluegill"), { minRodTier = 1, minReelTier = 1 })
		t.eq("bullhead → {1,1}", dm("bayou_bullhead_catfish"), { minRodTier = 1, minReelTier = 1 })
		t.eq("channel catfish → {1,1}", dm("bayou_channel_catfish"), { minRodTier = 1, minReelTier = 1 })
		t.eq("blue catfish (milestone) → {1,1}", dm("bayou_blue_catfish"), { minRodTier = 1, minReelTier = 1 })
	end

	t.section("Fishing — Angler Rank XP is tier/rarity/difficulty-weighted (SYS_progression §4)")
	do
		local bluegillXP = Fishing.anglerRankXP(Catalog, Catalog.fish.bayou_bluegill)
		local leviathanXP = Fishing.anglerRankXP(Catalog, Catalog.fish.bayou_leviathan)
		t.ok("a catch awards positive Angler XP", bluegillXP > 0)
		t.ok("a Mythic record (the Leviathan) dwarfs a Common panfish", leviathanXP > bluegillXP * 5)
	end

	t.section("Fishing — the derivation has teeth (a mis-statted fish would diverge)")
	do
		local mis = table.clone(Catalog.fish.bayou_bluegill)
		mis.fightDifficulty = 99 -- run force far exceeds a T1 rod's BreakThreshold → window collapses
		t.ok("a 99-FD 'bluegill' no longer derives min-rod-tier 1", Fishing.deriveMinTiers(Catalog, mis).minRodTier ~= 1)
	end

	-- ── Task 1.2 (Step 10): Appalachia fish carry spawnZones ──
	t.section("Fishing — every Appalachia fish carries spawnZones")
	t.ok("Appalachia fish all carry spawnZones resolving later to the shell", (function()
		for _, f in Catalog.fish do
			if f.destinationId == "appalachia" and (f.spawnZones == nil or #(f.spawnZones :: any) == 0) then return false end
		end
		return true
	end)())

	-- ── Task 2.2 (Step 10): Alaska fish carry spawnZones ──
	t.section("Fishing — every Alaska fish carries spawnZones")
	t.ok("Alaska fish all carry spawnZones resolving later to the shell", (function()
		for _, f in Catalog.fish do
			if f.destinationId == "alaska" and (f.spawnZones == nil or #(f.spawnZones :: any) == 0) then return false end
		end
		return true
	end)())

	-- ── Task 2.3 (Step 10): Boat sub-area marker ──
	t.section("Fishing — Boat sub-area marker (coastal = Boat-gated; interior = no Boat). Data only (Step 11 enforces)")
	do
		t.ok("the King Salmon MILESTONE is coastal/Boat-gated (LOC_04 §4/§7 — spec, not the build prompt)", Fishing.requiresBoat(Catalog.fish.alaska_king_salmon))
		t.ok("the Giant Halibut apex is Boat-gated", Fishing.requiresBoat(Catalog.fish.alaska_giant_halibut))
		t.ok("interior grayling/dolly/sockeye are NOT Boat-gated (shore-accessible)", (function()
			return not Fishing.requiresBoat(Catalog.fish.alaska_arctic_grayling)
				and not Fishing.requiresBoat(Catalog.fish.alaska_dolly_varden)
				and not Fishing.requiresBoat(Catalog.fish.alaska_sockeye_salmon)
		end)())
		t.ok("Bayou/Appalachia fish are shore-accessible (no Boat at the MVL's first two)", Fishing.requiresBoat(Catalog.fish.bayou_blue_catfish) == false and Fishing.requiresBoat(Catalog.fish.appalachia_trophy_largemouth_bass) == false)
	end

	-- ── Task 0.2 (Step 10): landableAt + coopLandableAt helpers ──
	t.section("Fishing — landableAt + co-op-landable helper")
	do
		-- landableAt: bayou_blue_catfish at (rod1, reel1) — already proven in the §2 inequality section.
		local blue = Catalog.fish.bayou_blue_catfish
		t.ok("blue catfish landable at (rod1, reel1) via landableAt helper", Fishing.landableAt(Catalog, blue, 1, 1))
		-- A clone with fightDifficulty=99 throws at (rod1,reel1): NetDrain goes negative (reel can't drain), LandWindow=0.
		local hard = table.clone(blue)
		hard.fightDifficulty = 99
		t.ok("FD=99 clone NOT landable at (rod1, reel1) (NetDrain<0, LandWindow=0)", Fishing.landableAt(Catalog, hard, 1, 1) == false)

		-- coopLandableAt: a T4 fish that solo-throws at (rod4,reel4) but co-op-lands with partyCap=4.
		-- Synthetic: clone bayou_blue_catfish, set tier=4, fightDifficulty=86, typicalWeightKg.max=100.
		-- Solo (T4): nd_solo=17.5*0.7-86*0.08=12.25-6.88=~10.62, stam=0.5*86*(1+100/10)=0.5*86*11=473,
		--   ft_solo=473/10.62≈44.54, lw=max(BreakThreshold(4)-p*86,0)=(96-51.6)=44.4 → 44.54>44.4 → THROWS.
		-- Co-op (T4, party=4): nd_coop=nd_solo*(1+0.5*3)=10.62*2.5=26.55, ft_coop=473/26.55≈17.82 ≤ 44.4 → LANDS.
		local reelBound = table.clone(blue)
		reelBound.tier = 4
		reelBound.fightDifficulty = 86
		reelBound.typicalWeightKg = { min = 80, max = 100 }
		t.ok("synthetic T4 reel-bound fish NOT landable solo (ft≈44.54 > lw=44.4)", Fishing.landableAt(Catalog, reelBound, 4, 4) == false)
		t.ok("synthetic T4 reel-bound fish co-op-landable at full party (ft≈17.82 ≤ lw=44.4)", Fishing.coopLandableAt(Catalog, reelBound, 4, Catalog.tuning.combat.coop.partyCap))
	end

	t.section("Fishing — ownsBoatForWater: a Coastal Skiff opens 'coastal'; a Boat-less / wrong-water angler does not (Step 11)")
	do
		local none = Util.mkProfile(Catalog, { rod = 1, reel = 1 })
		t.ok("a Boat-less angler does NOT own coastal access", Fishing.ownsBoatForWater(none, Catalog, "coastal") == false)
		local skiff = Util.mkProfile(Catalog, { rod = 1, reel = 1 })
		table.insert(skiff.inventory.commodities, { instanceId = "ci_skiff", catalogId = "vehicle_coastal_skiff", intraLevel = 0, equipped = false })
		t.ok("a Coastal-Skiff owner DOES own coastal access", Fishing.ownsBoatForWater(skiff, Catalog, "coastal"))
		local lake = Util.mkProfile(Catalog, { rod = 1, reel = 1 })
		table.insert(lake.inventory.commodities, { instanceId = "ci_jon", catalogId = "vehicle_jon_boat", intraLevel = 0, equipped = false })
		t.ok("a lake Jon Boat does NOT open coastal water (wrong accessGrant)", Fishing.ownsBoatForWater(lake, Catalog, "coastal") == false)
	end
end
