--!strict
-- BUILD-TIME SCHEMA ASSERTIONS (data-integrity / progression / EQUIPMENT_MASTER §6 build notes).
-- These make the corpus's structural guarantees TRUE at load time, not review-time hopes:
--   • tierInput true only for weapon/armor/rod/reel (bait/mount/dog/boat/cosmetic can never gate)
--   • a cosmetic is balance-free (no accessGrant; tierInput false)
--   • the Reward XOR: Common/Uncommon → Cash, Rare-and-above → exactly one artifact, NO Cash at mint
--   • disposition is legal for the artifact's kind (DISPLAYED/SALVAGED are Trophy-only)
--   • rank-perk category is identity|convenience — `power` is rejected
--   • gate milestone targets resolve, are loop-aligned, and live in a prerequisite Destination
-- Catalog.luau calls validateConfig() on load, so a malformed catalog fails the require.

local Enums = require("@src/types/Enums")
local Schema = require("@src/types/Schema")
local Combat = require("@src/logic/Combat")
local Fishing = require("@src/logic/Fishing")

type EquipmentItem = Schema.EquipmentItem
type Creature = Schema.Creature
type Fish = Schema.Fish
type Artifact = Schema.Artifact
type Config = Schema.Config
type Disposition = Enums.Disposition
type ArtifactKind = Enums.ArtifactKind

local V = {}

local function inRange(x: number, lo: number, hi: number): boolean
	return x >= lo and x <= hi
end

function V.isTierInputCategory(category: Enums.Category): boolean
	return Enums.TIER_INPUT_CATEGORIES[category] == true
end

function V.isRareOrAbove(rarity: Enums.Rarity): boolean
	return Enums.RarityRank[rarity] >= Enums.RARE_AND_ABOVE_RANK
end

-- Disposition legality by kind (data-integrity §4): trophy → full enum; non-trophy → {HELD, ESCROWED}.
function V.isDispositionLegal(kind: ArtifactKind, disposition: Disposition): boolean
	if kind == Enums.ArtifactKind.trophy then
		return true -- any of HELD/DISPLAYED/ESCROWED/SALVAGED
	end
	return Enums.NON_TROPHY_DISPOSITIONS[disposition] == true
end

function V.assertDispositionLegal(kind: ArtifactKind, disposition: Disposition)
	if not V.isDispositionLegal(kind, disposition) then
		error(string.format("illegal disposition '%s' for non-trophy artifact kind '%s' (DISPLAYED/SALVAGED are Trophy-only)", tostring(disposition), tostring(kind)))
	end
end

-- Accepts a raw string so a negative test can pass "power" and observe the rejection at runtime
-- (the type system rejects it at build time; this guards data-driven/LiveOps-added perks too).
function V.assertRankPerkCategory(category: string)
	if category ~= Enums.RankPerkCategory.identity and category ~= Enums.RankPerkCategory.convenience then
		error(string.format("illegal rank-perk category '%s' — only identity|convenience are legal (power is not pay-to-win-safe)", category))
	end
end

function V.assertArtifact(a: Artifact)
	V.assertDispositionLegal(a.kind, a.disposition)
end

function V.assertEquipmentItem(it: EquipmentItem)
	assert(it.tierInput == V.isTierInputCategory(it.category),
		it.id .. ": tierInput must be derived from category (true only for weapon/armor/rod/reel)")
	assert(it.tier >= 0, it.id .. ": tier must be ≥ 0")
	if it.category == Enums.Category.cosmetic then
		assert(it.cosmeticOnly, it.id .. ": cosmetics must be cosmeticOnly")
		assert(it.accessGrant == nil, it.id .. ": a cosmetic must be balance-free (no accessGrant)")
		assert(it.tierInput == false, it.id .. ": a cosmetic can never be a tier input")
	else
		assert(it.cosmeticOnly == false, it.id .. ": only cosmetics may be cosmeticOnly")
	end
	if it.accessGrant ~= nil then
		assert(it.category == Enums.Category.vehicle, it.id .. ": only vehicles may carry an accessGrant")
	end
	-- monetizationRoles must be a set of legal Template-B values; cosmetics are identity-only (balance-free).
	for _, role in it.monetizationRoles do
		assert(Enums.MonetizationRoleSet[role] == true, it.id .. ": illegal monetization role '" .. tostring(role) .. "'")
		if it.category == Enums.Category.cosmetic then
			assert(role == Enums.MonetizationRole.identity, it.id .. ": a cosmetic's monetization is identity-only")
		end
	end
end

function V.assertCreature(c: Creature)
	assert(c.tier >= 1, c.id .. ": tier must be ≥ 1")
	assert(inRange(c.health, 0, 100) and inRange(c.damageToPlayer, 0, 100) and inRange(c.speed, 0, 100),
		c.id .. ": stats must be on the 0–100 scale")
	local rareFlag = V.isRareOrAbove(c.rarity)
	assert((c.rare ~= nil) == rareFlag, c.id .. ": rare fields present iff rarity ≥ Rare")
	if c.ambianceOnly then
		assert(c.reward == nil, c.id .. ": ambiance grants nothing (reward must be nil)")
	else
		local reward = assert(c.reward, c.id .. ": non-ambiance must carry a reward")
		if rareFlag then
			assert(reward.kind == "artifact", c.id .. ": Rare-and-above must mint an artifact (no Cash at mint)")
			local rf = assert(c.rare)
			assert(reward.artifact.tradeable == rf.tradeable and reward.artifact.displayableInLodge == rf.displayableInLodge,
				c.id .. ": reward artifact must match the rare fields")
		else
			assert(reward.kind == "cash", c.id .. ": Common/Uncommon must pay Cash")
		end
	end
end

function V.assertFish(f: Fish)
	assert(f.tier >= 1, f.id .. ": tier must be ≥ 1")
	assert(inRange(f.fightDifficulty, 1, 100), f.id .. ": fightDifficulty must be 1–100")
	assert(f.typicalWeightKg.min > 0 and f.typicalWeightKg.max >= f.typicalWeightKg.min and f.recordWeightKg > 0,
		f.id .. ": weights must be positive and ordered")
	local rareFlag = V.isRareOrAbove(f.rarity)
	assert((f.rare ~= nil) == rareFlag, f.id .. ": rare fields present iff rarity ≥ Rare")
	if rareFlag then
		assert(f.reward.kind == "artifact", f.id .. ": Rare-and-above must mint an artifact (no Cash at mint)")
		local rf = assert(f.rare)
		assert(f.reward.artifact.tradeable == rf.tradeable and f.reward.artifact.displayableInLodge == rf.displayableInLodge,
			f.id .. ": reward artifact must match the rare fields")
	else
		assert(f.reward.kind == "cash", f.id .. ": Common/Uncommon must pay Cash")
	end
end

-- Whole-catalog validation: per-row checks + cross-reference integrity (the seams that only show up
-- across catalogs — reskins, milestone targets, gate prerequisites).
function V.validateConfig(config: Config)
	for _, it in config.equipment do
		V.assertEquipmentItem(it)
	end
	for _, c in config.creatures do
		V.assertCreature(c)
		if c.reskinOf ~= nil then
			local source = assert(config.creatures[c.reskinOf], c.id .. ": reskinOf '" .. c.reskinOf .. "' must resolve to a creature")
			-- The re-skin's OWN tier is authoritative and it is balanced/rewarded at its DISPLAYED tier
			-- ("rabbits in Alaska, but bigger"): a re-skin populates a HIGHER-or-equal tier than its origin,
			-- never below (progression §6 — reskins populate a tier's floor/low-mid, never carry origin balance).
			assert(c.tier >= source.tier, c.id .. ": a re-skin's displayed tier (" .. c.tier .. ") must be ≥ its origin's (" .. source.tier .. ")")
		end
		-- Step-4 (SYS_combat §3): the min-weapon/min-armor-tier fields are DERIVED, not authored truth.
		-- Assert the catalog matches the derivation for the BAYOU — the only Destination that exists; the
		-- T2→T4 (Appalachia/Alaska) survival-bounded derivation is owed at Step 10 (no premature cross-tier
		-- checks). Also require structured spawnZones on every non-ambiance Bayou target (Step 4 P1).
		if c.destinationId == "bayou" and not c.ambianceOnly then
			assert(c.spawnZones ~= nil and #(c.spawnZones :: { string }) > 0, c.id .. ": a Bayou hunting target must carry structured spawnZones (Step 4 P1)")
			local derived = Combat.deriveMinTiers(config, c)
			assert(derived.minWeaponTier == c.minWeaponTierToKill,
				string.format("%s: authored minWeaponTierToKill %d ≠ derived %d (§3 kill inequality)", c.id, c.minWeaponTierToKill, derived.minWeaponTier))
			assert(derived.minArmorTier == c.minArmorTierToSurvive,
				string.format("%s: authored minArmorTierToSurvive %d ≠ derived %d (Bayou non-lethal → n/a=0)", c.id, c.minArmorTierToSurvive, derived.minArmorTier))
		end
	end
	for _, f in config.fish do
		V.assertFish(f)
		-- Step-5 (SYS_fishing §3): min rod/reel tiers are DERIVED, asserted == authored for the BAYOU
		-- ROUTINE band only. Rares are bonus-on-top finds excluded from the band (RD5) — e.g. the
		-- Leviathan's colossal weight intentionally exceeds the T1 fight model ("the difficulty is reaching
		-- the condition, not the fight", LOC §5). Appalachia/Alaska + the cross-tier derivation are owed at
		-- Step 10. Also require structured spawnZones on every Bayou fish (Step 5 prerequisite).
		if f.destinationId == "bayou" then
			assert(f.spawnZones ~= nil and #(f.spawnZones :: { string }) > 0, f.id .. ": a Bayou fish must carry structured spawnZones (Step 5 prereq)")
			if not V.isRareOrAbove(f.rarity) then
				local derived = Fishing.deriveMinTiers(config, f)
				assert(derived.minRodTier == f.minRodTier,
					string.format("%s: authored minRodTier %d ≠ derived %d (§2 catchability inequality)", f.id, f.minRodTier, derived.minRodTier))
				assert(derived.minReelTier == f.minReelTier,
					string.format("%s: authored minReelTier %d ≠ derived %d (§2 catchability inequality)", f.id, f.minReelTier, derived.minReelTier))
			end
		end
	end
	for _, perk in config.rankPerks do
		V.assertRankPerkCategory(perk.category)
	end

	-- Destinations + gate DAG integrity.
	local function offers(dst: Schema.Destination, loop: Enums.Loop): boolean
		for _, l in dst.offeredLoops do
			if l == loop then
				return true
			end
		end
		return false
	end
	for _, dst in config.destinations do
		assert(#dst.offeredLoops >= 1, dst.id .. ": a Destination must offer at least one loop")
		assert(dst.gate.requiredTier >= 0, dst.id .. ": requiredTier must be ≥ 0")
		assert(dst.teleportTarget ~= "", dst.id .. ": teleportTarget must be set (the framework hook)")
		for _, prereq in dst.gate.prerequisiteDestinations do
			assert(config.destinations[prereq] ~= nil, dst.id .. ": prerequisite '" .. prereq .. "' must resolve")
		end
		for _, targetId in dst.gate.milestoneTargets do
			local entry = assert(config.targetIndex[targetId], dst.id .. ": milestone target '" .. targetId .. "' must resolve")
			assert(entry.isMilestone, dst.id .. ": gate milestone target '" .. targetId .. "' must be a DESIGNATED conquest target (isMilestoneTarget)")
			assert(offers(dst, entry.loop), dst.id .. ": milestone target '" .. targetId .. "' is on a loop this Destination does not offer")
			-- A conquest milestone target lives in a prerequisite Destination (the unified-conquest model).
			local homeIsPrereq = false
			for _, prereq in dst.gate.prerequisiteDestinations do
				if prereq == entry.destinationId then
					homeIsPrereq = true
					break
				end
			end
			assert(homeIsPrereq, dst.id .. ": milestone target '" .. targetId .. "' must live in a prerequisite Destination")
		end
	end

	-- Each dual-loop MVL Destination must designate a hunting AND a fishing conquest target in its roster.
	local function hasMilestone(loop: Enums.Loop, dId: string): boolean
		for _, entry in config.targetIndex do
			if entry.destinationId == dId and entry.loop == loop and entry.isMilestone then
				return true
			end
		end
		return false
	end
	for _, dId in { "bayou", "appalachia", "alaska" } do
		assert(hasMilestone(Enums.Loop.Hunting, dId), dId .. ": missing a designated hunting milestone target")
		assert(hasMilestone(Enums.Loop.Fishing, dId), dId .. ": missing a designated fishing milestone target")
	end
end

return V
