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
type DecorItem = Schema.DecorItem

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

-- Decor balance-free guarantee (SYS_lodge_trophy §3 / EQUIPMENT_MASTER §6 — extends the cosmetic check).
-- A DecorItem has NO stats/accessGrant/tierInput field, so balance-free is by construction; this enforces
-- the rest: identity-ONLY monetization, Cash-priced (real-money decor is Step 14), tradeable=false (a
-- tradeable cosmetic routes to the rare-cosmetic ARTIFACT path, not the typed-owned sink). The runtime
-- assertion also guards data-driven / LiveOps-added decor SKUs.
function V.assertDecorItem(d: DecorItem)
	assert((d.cost :: any).cash ~= nil, d.id .. ": decor must be Cash-priced (real-money decor is Step 14)")
	assert(d.tradeable == false, d.id .. ": Step-8 decor is the typed-owned path (tradeable=false; a tradeable cosmetic is the artifact path)")
	-- identity-only is enforced in the loop below; an EMPTY role set would skip it and silently bypass the
	-- balance-free guarantee — so a decor SKU MUST carry the identity role (guards LiveOps-added SKUs).
	assert(#d.monetizationRoles > 0, d.id .. ": decor must carry the identity monetization role (balance-free)")
	for _, role in d.monetizationRoles do
		assert(Enums.MonetizationRoleSet[role] == true, d.id .. ": illegal monetization role '" .. tostring(role) .. "'")
		assert(role == Enums.MonetizationRole.identity, d.id .. ": decor is identity-only / balance-free (the zero-stat guarantee)")
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

-- Re-skin integrity: tier ≥ origin's AND behavior reuses the origin's template (progression §6).
-- A re-skin may always be a calmer flee/passive 'find' variant of an aggressive/pack origin (LOC §5 —
-- e.g. alaska_spirit_moose is `flees` while its origin alaska_bull_moose is `aggressive`).
function V.assertCreatureReskin(c: Creature, config: Config)
	local originId = assert(c.reskinOf, c.id .. ": assertCreatureReskin called on a non-reskin (reskinOf is nil)")
	local source = assert(config.creatures[originId], c.id .. ": reskinOf '" .. originId .. "' must resolve to a creature")
	assert(c.tier >= source.tier, c.id .. ": a re-skin's displayed tier (" .. c.tier .. ") must be ≥ its origin's (" .. source.tier .. ")")
	-- Re-skins reuse a behavior TEMPLATE (progression §6). It must reuse the origin's archetype, OR be a
	-- calmer flee/passive 'find' variant of an aggressive/pack origin (LOC §5 — e.g. the Spirit Moose).
	local reusesTemplate = c.behavior == source.behavior or c.behavior == "flees" or c.behavior == "passive"
	assert(reusesTemplate, c.id .. ": a re-skin must reuse its origin's behavior template (progression §6)")
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
			-- The re-skin's OWN tier is authoritative and it is balanced/rewarded at its DISPLAYED tier
			-- ("rabbits in Alaska, but bigger"): tier ≥ origin, behavior reuses the template (progression §6).
			V.assertCreatureReskin(c, config)
		end
		-- Step-4/10 (SYS_combat §3): the min-weapon/min-armor-tier fields are DERIVED, not authored truth.
		-- Bayou: assert derived==authored (T1 physical-min == design floor; holds for the non-lethal zone).
		-- Appalachia: cross-tier equality is unachievable (deriveMinTiers computes the physical-minimum;
		--   the catalog authors the design role-anchor floor=T-1/mid=T/apex=T+1) — assert the spec's
		--   floor/ceiling SEMANTICS instead: sufficiency (soloableAt authored tier) + role band [T-1,T+1].
		-- Alaska: NO spawnZones yet (Phase 2 / Task 2.6) — gate kept to bayou|appalachia only.
		if not c.ambianceOnly then
			if c.destinationId == "bayou" or c.destinationId == "appalachia" then
				assert(c.spawnZones ~= nil and #(c.spawnZones :: { string }) > 0, c.id .. ": a hunting target must carry structured spawnZones")
			end
			if c.destinationId == "bayou" then
				-- Bayou keeps strict derived==authored (T1 physical-min == design floor; holds).
				local derived = Combat.deriveMinTiers(config, c)
				assert(derived.minWeaponTier == c.minWeaponTierToKill, string.format("%s: authored minWeaponTierToKill %d ≠ derived %d (§3 kill inequality)", c.id, c.minWeaponTierToKill, derived.minWeaponTier))
				assert(derived.minArmorTier == c.minArmorTierToSurvive, string.format("%s: authored minArmorTierToSurvive %d ≠ derived %d (Bayou non-lethal → n/a=0)", c.id, c.minArmorTierToSurvive, derived.minArmorTier))
			elseif c.destinationId == "appalachia" then
				-- Cross-tier: strict equality unachievable; assert the spec's floor/ceiling semantics.
				if c.minWeaponTierToKill <= 4 then
					assert(Combat.soloableAt(config, c, c.minWeaponTierToKill, math.max(c.minArmorTierToSurvive, c.minWeaponTierToKill)), c.id .. ": must be soloable at its authored min-tier (floor/ceiling sufficiency, §3)")
				end
				assert(c.minWeaponTierToKill >= c.tier - 1 and c.minWeaponTierToKill <= c.tier + 1, c.id .. ": authored minWeaponTier must sit in the role band [T-1, T+1]")
			end
		end
	end
	for _, f in config.fish do
		V.assertFish(f)
		-- Step-5/10 (SYS_fishing §3): min rod/reel tiers are DERIVED. Bayou: assert derived==authored for
		-- the ROUTINE band (rares excluded per RD5 — the Leviathan's colossal weight intentionally exceeds
		-- the T1 fight model). Appalachia: cross-tier equality is unachievable — assert sufficiency
		-- (landableAt authored rod+reel) + role band [T-1,T+1] instead.
		-- Alaska: NO spawnZones yet (Phase 2 / Task 2.6) — gate kept to bayou|appalachia only.
		if f.destinationId == "bayou" or f.destinationId == "appalachia" then
			assert(f.spawnZones ~= nil and #(f.spawnZones :: { string }) > 0, f.id .. ": a fish must carry structured spawnZones")
			if not V.isRareOrAbove(f.rarity) then
				if f.destinationId == "bayou" then
					local derived = Fishing.deriveMinTiers(config, f)
					assert(derived.minRodTier == f.minRodTier, string.format("%s: authored minRodTier %d ≠ derived %d (§2 catchability inequality)", f.id, f.minRodTier, derived.minRodTier))
					assert(derived.minReelTier == f.minReelTier, string.format("%s: authored minReelTier %d ≠ derived %d (§2 catchability inequality)", f.id, f.minReelTier, derived.minReelTier))
				else
					assert(Fishing.landableAt(config, f, f.minRodTier, f.minReelTier), f.id .. ": must be landable at its authored rod+reel (sufficiency, §3)")
					assert(f.minRodTier >= f.tier - 1 and f.minRodTier <= f.tier + 1, f.id .. ": authored minRodTier must sit in the role band [T-1, T+1]")
				end
			end
		end
	end
	-- Boat sub-area data integrity (LOC_04 §4/§7): the King Salmon MILESTONE is coastal/Boat-gated (per
	-- spec — the pure-fisher conquest waits for the Boat, Step 11); the interior run species are not.
	assert(Fishing.requiresBoat(config.fish.alaska_king_salmon), "king salmon must be coastal/Boat-gated (LOC_04 §4/§7)")
	assert(not Fishing.requiresBoat(config.fish.alaska_sockeye_salmon), "interior sockeye must be shore-accessible (no Boat)")

	for _, perk in config.rankPerks do
		V.assertRankPerkCategory(perk.category)
	end
	for _, d in config.decor do
		V.assertDecorItem(d)
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
