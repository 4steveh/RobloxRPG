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

local Enums = require("../types/Enums")
local Schema = require("../types/Schema")
local Combat = require("../logic/Combat")
local Fishing = require("../logic/Fishing")
local LiveOps = require("../logic/LiveOps")

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
	-- Step 11 never-gate guardrail (SYS_progression §2 — "Mounts and Tracking Dogs never appear in a Gate,
	-- ever, for entry or sub-area"): a mount/dog can never gate (no accessGrant) and is never a tier input.
	-- accessGrant-on-non-vehicle is already rejected above and tierInput is derived; this states the mount/dog
	-- invariant explicitly with the spec citation and guards LiveOps-added convenience SKUs.
	if it.category == Enums.Category.mount or it.category == Enums.Category.dog then
		assert(it.accessGrant == nil, it.id .. ": a mount/dog can never gate (no accessGrant — convenience never gates shared content)")
		assert(it.tierInput == false, it.id .. ": a mount/dog is never a tier input (convenience, never power)")
	end
	-- monetizationRoles must be a set of legal Template-B values; cosmetics are identity-only (balance-free).
	for _, role in it.monetizationRoles do
		assert(Enums.MonetizationRoleSet[role] == true, it.id .. ": illegal monetization role '" .. tostring(role) .. "'")
		if it.category == Enums.Category.cosmetic then
			assert(role == Enums.MonetizationRole.identity, it.id .. ": a cosmetic's monetization is identity-only")
		end
		-- Step 11 never-power guardrail (EQUIPMENT_MASTER §4.5–4.7): only tier gear (weapon/armor/rod/reel) may
		-- carry the power-progression role; a vehicle/mount/dog/bait/tackle that claims it is a build-time error
		-- (access/convenience monetization can never be a combat/catch power input).
		if role == Enums.MonetizationRole.powerProgression then
			assert(it.tierInput, it.id .. ": only tier gear may carry the power-progression role (access/convenience items are never a power input)")
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
	if c.typicalWeightKg ~= nil then
		assert(c.typicalWeightKg.min > 0 and c.typicalWeightKg.max >= c.typicalWeightKg.min,
			c.id .. ": typicalWeightKg must have 0 < min <= max")
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

-- Step 13: a fish's requiresItem (the Frozen-Lake item-ownership gate) must resolve to a real equipment
-- item — else a typo silently makes the fish permanently uncatchable (no player can own a non-existent
-- item, so the gate denies forever). Cross-reference check (needs the catalog), mirrors the gate-access-item
-- resolution. (baitRequired stays free-form: bait ids have no backing fungible-item catalog.)
function V.assertFishItemRefs(f: Fish, config: Config)
	if f.requiresItem ~= nil then
		assert(config.equipment[f.requiresItem] ~= nil, f.id .. ": requiresItem '" .. f.requiresItem .. "' must resolve to an equipment item")
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

-- ── Step 13: the LiveOps scarcity-discipline guard (SYS_liveops_calendar RD1 — THE moat-structural piece).
-- A build-time schema error, the same class as assertDecorItem/assertFish. Events are precisely where the
-- pressure to dilute a rare's scarcity arrives; a single dilutive re-release collapses the trade moat, so the
-- discipline is a PROPERTY OF THE SCHEMA, not a thing someone remembers under pressure. ──────────────────

-- A new-scarcity id MUST be genuinely new — not present in ANY existing catalog (the clone evasion: a config
-- "introducing a new entry" whose id collides with an existing rare overwrites/clones it). RD1.
function V.assertNewScarcityId(proposedId: string, config: Config)
	local collides = config.equipment[proposedId] ~= nil
		or config.creatures[proposedId] ~= nil
		or config.fish[proposedId] ~= nil
		or config.decor[proposedId] ~= nil
		or config.destinations[proposedId] ~= nil
	assert(not collides, "new-scarcity id '" .. proposedId .. "' collides with an existing catalog id — a new entry must be genuinely new (RD1 clone-evasion guard)")
end

-- An event config obeys RD1/RD2: budget within the (economy-owned) ceiling; a well-formed window; and each
-- new-scarcity declaration is legal —
--   • referenceWindow (RD1a): names an EXISTING rare (its 1-in-N untouched; the event carries no rate, so
--     dilution is structurally absent). May NOT also be minted by this event.
--   • mintNew (RD1b): names a fish this event INTRODUCES (∈ event.mintsFish). The Catalog merge already
--     proved every minted id is genuinely new (∉ ANY base catalog — assertNewScarcityId), so a re-release of
--     an existing rare is structurally impossible: a standing rare's id is NOT in mintsFish, and putting it
--     there collides at merge. This is the fix for the forgeable-spawn-clause re-release the review found.
-- Plus: every fish the event MINTS must be gated by THIS event (event-exclusive), and every minted RARE must
-- be declared as a mintNew (no undeclared MINTED scarcity — the RD1 audit on introduced content). NOTE: this
-- guard is the STRUCTURAL floor (no rate edit, no clone, no re-release, no undeclared mint). It does NOT also
-- require an event to file a referenceWindow for every EXISTING rare its imposed clause happens to window —
-- opening a window at an UNCHANGED 1-in-N is the explicitly-permitted RD1(a) behavior, and the completeness
-- of windowing declarations is the OPERATIONAL scarcity-mint approval gate the spec leaves to live-ops
-- (SYS_liveops_calendar Open Questions), not the schema guard.
function V.assertEventConfig(event: Schema.EventConfig, config: Config)
	assert(event.startTime < event.endTime, event.id .. ": event window start must be < end")
	assert(event.cashBudget >= 0, event.id .. ": cashBudget must be ≥ 0")
	assert(event.cashBudget <= config.tuning.economy.eventPayoutBudgetCeiling,
		event.id .. ": cashBudget exceeds eventPayoutBudgetCeiling (economy owns the per-event Cash bound — SYS_liveops §6)")

	local mintsFish = event.mintsFish or {}
	local mintedIds: { [string]: boolean } = {}
	for _, mf in mintsFish do
		mintedIds[mf.id] = true
	end

	local declaredMintNew: { [string]: boolean } = {}
	for _, decl in event.newScarcity do
		if decl.kind == Enums.NewScarcityKind.mintNew then
			declaredMintNew[decl.targetId] = true
			-- RD1b: a mintNew names a genuinely-new fish this event INTRODUCES (∈ mintsFish). A standing rare's
			-- id is not in mintsFish (and can't be added — the Catalog merge rejects an id colliding with base).
			assert(mintedIds[decl.targetId],
				event.id .. ": mintNew '" .. decl.targetId .. "' must be a fish this event INTRODUCES (in mintsFish) — re-releasing an existing rare is forbidden (RD1)")
			local idx = config.targetIndex[decl.targetId]
			assert(idx ~= nil and V.isRareOrAbove(idx.rarity),
				event.id .. ": mintNew '" .. decl.targetId .. "' must be rare-and-above (RD1 governs scarcity)")
		else
			-- RD1a: referenceWindow names an EXISTING rare (not one this event introduces).
			local idx = config.targetIndex[decl.targetId]
			assert(idx ~= nil, event.id .. ": referenceWindow target '" .. decl.targetId .. "' must resolve to a catalog target")
			assert(V.isRareOrAbove(idx.rarity),
				event.id .. ": referenceWindow target '" .. decl.targetId .. "' must be a rare — RD1 governs SCARCITY (rare-and-above) only")
			assert(not mintedIds[decl.targetId],
				event.id .. ": referenceWindow target '" .. decl.targetId .. "' cannot also be minted by this event")
		end
	end

	for _, mf in mintsFish do
		local cond = mf.spawn.conditions
		local gating = cond ~= nil and cond.event or nil
		assert(event.imposes.event ~= nil and gating == event.imposes.event,
			event.id .. ": minted fish '" .. mf.id .. "' must be gated by this event's spawn clause (event-exclusive)")
		if V.isRareOrAbove(mf.rarity) then
			assert(declaredMintNew[mf.id],
				event.id .. ": minted RARE '" .. mf.id .. "' must be declared as a mintNew newScarcity entry (the RD1 audit)")
		end
	end
	if event.traitsGranted ~= nil then
		assert(event.kind == "weatherWindow",
			event.id .. ": traitsGranted is only legal on a weatherWindow event")
		for _, tr in event.traitsGranted do
			assert((config.tuning.economy.traitMultiplier :: any)[tr] ~= nil,
				event.id .. ": trait '" .. tostring(tr) .. "' has no traitMultiplier (every granted trait must be priced)")
		end
	end
end

-- A daily-quest pool entry is mechanical (not narrative), carries a legal loop, and any theming resolves.
function V.assertQuest(q: Schema.Quest, config: Config)
	assert(q.objective ~= "", q.id .. ": quest objective must be set (mechanical content)")
	assert(q.loop == Enums.QuestLoop.Hunting or q.loop == Enums.QuestLoop.Fishing or q.loop == Enums.QuestLoop.either,
		q.id .. ": illegal quest loop '" .. tostring(q.loop) .. "'")
	if q.themedFor ~= nil then
		assert(config.liveOps.events[q.themedFor] ~= nil, q.id .. ": themedFor '" .. q.themedFor .. "' must resolve to an event")
	end
end

-- Whole-LiveOps validation: per-event guard; the daily pool can form the cross-loop pair; the aggregate
-- concurrent Cash faucet stays within the (economy-owned) PEAK ceiling; and at most ONE spawn-gating event
-- is ever live at a time (world.event is a single string, equality-matched).
function V.validateLiveOps(config: Config)
	local lo = config.liveOps
	for id, e in lo.events do
		assert(e.id == id, "liveOps event key '" .. id .. "' must match its id '" .. e.id .. "'")
		V.assertEventConfig(e, config)
	end

	-- The cross-loop pair must be formable on ANY day — including days with no active event, when themed
	-- quests are excluded. So count only the ALWAYS-ELIGIBLE (non-themed) quests toward the pair guarantee.
	local hasHunt, hasFish = false, false
	for _, q in lo.dailyQuestPool do
		V.assertQuest(q, config)
		if q.themedFor == nil then
			if q.loop == Enums.QuestLoop.Hunting then
				hasHunt = true
			elseif q.loop == Enums.QuestLoop.Fishing then
				hasFish = true
			end
		end
	end
	if #lo.dailyQuestPool > 0 then
		assert(hasHunt, "daily-quest pool must contain ≥1 NON-THEMED Hunting quest (the cross-loop pair must be formable every day)")
		assert(hasFish, "daily-quest pool must contain ≥1 NON-THEMED Fishing quest (the cross-loop pair must be formable every day)")
	end

	assert(LiveOps.peakConcurrentCashBudget(config) <= config.tuning.economy.aggregateEventFaucetCeiling,
		"concurrent event Cash faucets exceed aggregateEventFaucetCeiling (the PEAK instantaneous sum — SYS_liveops §6)")

	local gating: { Schema.EventConfig } = {}
	for _, e in lo.events do
		if e.imposes.event ~= nil then
			table.insert(gating, e)
		end
	end
	for i = 1, #gating do
		for j = i + 1, #gating do
			local a, b = gating[i], gating[j]
			assert(not (a.startTime <= b.endTime and b.startTime <= a.endTime),
				"spawn-gating events '" .. a.id .. "' and '" .. b.id .. "' overlap — only one spawn-gating event at a time (world.event is a single string)")
		end
	end

	-- NEW: at most ONE weatherWindow live at any instant (activeWeather is a single string; activeTraits
	-- first-match relies on it). Mirrors the spawn-gating non-overlap check.
	local weather: { Schema.EventConfig } = {}
	for _, e in lo.events do
		if e.kind == "weatherWindow" then
			table.insert(weather, e)
		end
	end
	for i = 1, #weather do
		for j = i + 1, #weather do
			local a, b = weather[i], weather[j]
			assert(not (a.startTime <= b.endTime and b.startTime <= a.endTime),
				"weatherWindow events '" .. a.id .. "' and '" .. b.id .. "' overlap — one weather at a time")
		end
	end
end

-- ── Step 14: the pay-proof monetization guard (SYS_economy §7 / 00 §4 — the integrity spine of the
-- real-money layer). A build-time schema error, the same class as assertDecorItem (balance-free) and the
-- Step-11 power-role guard. The STRUCTURAL keystone is the type: ProductGrant is a closed union with NO
-- conquest/tier variant, so a pay-to-win grant is UNREPRESENTABLE (the negative fixture proves it). This
-- runtime guard is the BELT-AND-SUSPENDERS half: it (i) extends the Step-11 never-power role guard to the
-- product catalog (no product carries power-progression), and (ii) closes the two ways a SAFE-kinded grant
-- could still smuggle power — an `item` grant of TIER GEAR, or a `cosmetic` grant of a non-balance-free item.
-- It also guards data-driven / future LiveOps-added products. ──────────────────────────────────────────
function V.assertProduct(p: Schema.Product, config: Config)
	assert(p.assetId ~= "", p.id .. ": a product must carry an assetId (a placeholder bound in Studio)")
	assert(Enums.MonetizationRoleSet[p.role] == true, p.id .. ": illegal monetization role '" .. tostring(p.role) .. "'")
	-- The never-power guard (Step 11 → Step 14): no real-money product may carry power-progression. Sell WITH
	-- the player — real money compresses grind / removes friction, it never buys a power input or a milestone.
	assert(p.role ~= Enums.MonetizationRole.powerProgression,
		p.id .. ": a real-money product may NOT carry the power-progression role (no pay-to-win — SYS_economy §7)")

	local g = p.grant
	assert(Enums.GrantKindSet[g.kind] == true, p.id .. ": illegal grant kind '" .. tostring(g.kind) .. "'")
	if g.kind == "cash" then
		assert(g.amount > 0, p.id .. ": a cash grant must inject a positive amount")
	elseif g.kind == "item" then
		local item = assert(config.equipment[g.itemId], p.id .. ": item grant '" .. g.itemId .. "' must resolve to an equipment item")
		-- THE pay-proof line for an item grant: real money never hands a POWER input. An item grant can never
		-- be tier gear (weapon/armor/rod/reel) — only access (a Boat), convenience (premium bait/ammo/tools),
		-- or identity. tierInput is derived from category (assertEquipmentItem), so this cannot drift.
		assert(not item.tierInput, p.id .. ": a real-money item grant may NOT be tier gear (tierInput) — that is pay-to-win")
		if g.quantity ~= nil then
			assert(g.quantity > 0, p.id .. ": an item-grant quantity must be > 0")
		end
	elseif g.kind == "cosmetic" then
		local item = assert(config.equipment[g.itemId], p.id .. ": cosmetic grant '" .. g.itemId .. "' must resolve to an equipment item")
		assert(item.cosmeticOnly, p.id .. ": a cosmetic grant must reference a cosmeticOnly item (balance-free, no stats)")
	else
		-- multiplier: must be a known ACTIVE-income multiplier tag (the closed CashMultiplier set). It touches
		-- the active kill/catch grant only (RewardPipeline), never idle/daily/salvage/the conquest set.
		assert(Enums.CashMultiplierSet[g.multiplier] == true,
			p.id .. ": illegal cash multiplier '" .. tostring(g.multiplier) .. "'")
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
			-- The re-skin's OWN tier is authoritative and it is balanced/rewarded at its DISPLAYED tier
			-- ("rabbits in Alaska, but bigger"): tier ≥ origin, behavior reuses the template (progression §6).
			V.assertCreatureReskin(c, config)
		end
		-- Step-4/10 (SYS_combat §3): the min-weapon/min-armor-tier fields are DERIVED, not authored truth.
		-- Bayou: assert derived==authored (T1 physical-min == design floor; holds for the non-lethal zone).
		-- Appalachia/Alaska: cross-tier equality is unachievable (deriveMinTiers computes the physical-minimum;
		--   the catalog authors the design role-anchor floor=T-1/mid=T/apex=T+1) — assert the spec's
		--   floor/ceiling SEMANTICS instead: sufficiency (soloableAt authored tier, or wall+co-op proof for
		--   co-op-only apex with minWeaponTierToKill > 4) + role band [T-1,T+1].
		-- deep_sea/rockies: stub fixtures with no spawnZones — excluded from this gate.
		if not c.ambianceOnly then
			if c.destinationId == "bayou" or c.destinationId == "appalachia" or c.destinationId == "alaska" then
				assert(c.spawnZones ~= nil and #(c.spawnZones :: { string }) > 0, c.id .. ": a hunting target must carry structured spawnZones")
			end
			if c.destinationId == "bayou" then
				-- Bayou keeps strict derived==authored (T1 physical-min == design floor; holds).
				local derived = Combat.deriveMinTiers(config, c)
				assert(derived.minWeaponTier == c.minWeaponTierToKill, string.format("%s: authored minWeaponTierToKill %d ≠ derived %d (§3 kill inequality)", c.id, c.minWeaponTierToKill, derived.minWeaponTier))
				assert(derived.minArmorTier == c.minArmorTierToSurvive, string.format("%s: authored minArmorTierToSurvive %d ≠ derived %d (Bayou non-lethal → n/a=0)", c.id, c.minArmorTierToSurvive, derived.minArmorTier))
			elseif c.destinationId == "appalachia" or c.destinationId == "alaska" then
				-- Cross-tier (appalachia + alaska): strict equality unachievable; assert the spec's semantics.
				-- Co-op-only apex (minWeaponTierToKill > 4): skip the soloableAt sufficiency check — the design
				-- intent is that the creature is a WALL solo at T4 and co-op-soluble at T4 with a full party.
				if c.minWeaponTierToKill <= 4 then
					assert(Combat.soloableAt(config, c, c.minWeaponTierToKill, math.max(c.minArmorTierToSurvive, c.minWeaponTierToKill)), c.id .. ": must be soloable at its authored min-tier (floor/ceiling sufficiency, §3)")
				end
				assert(c.minWeaponTierToKill >= c.tier - 1 and c.minWeaponTierToKill <= c.tier + 1, c.id .. ": authored minWeaponTier must sit in the role band [T-1, T+1]")
			end
		end
	end
	for _, f in config.fish do
		V.assertFish(f)
		V.assertFishItemRefs(f, config) -- Step 13: requiresItem (the Frozen-Lake kit) must resolve
		-- Step-5/10 (SYS_fishing §3): min rod/reel tiers are DERIVED. Bayou: assert derived==authored for
		-- the ROUTINE band (rares excluded per RD5 — the Leviathan's colossal weight intentionally exceeds
		-- the T1 fight model). Appalachia/Alaska: cross-tier equality is unachievable — assert sufficiency
		-- (landableAt authored rod+reel, or wall proof for co-op-only when max(rod,reel) > 4) + role band.
		-- deep_sea/rockies: stub fixtures with no spawnZones — excluded from this gate.
		if f.destinationId == "bayou" or f.destinationId == "appalachia" or f.destinationId == "alaska" then
			assert(f.spawnZones ~= nil and #(f.spawnZones :: { string }) > 0, f.id .. ": a fish must carry structured spawnZones")
			if not V.isRareOrAbove(f.rarity) then
				if f.destinationId == "bayou" then
					local derived = Fishing.deriveMinTiers(config, f)
					assert(derived.minRodTier == f.minRodTier, string.format("%s: authored minRodTier %d ≠ derived %d (§2 catchability inequality)", f.id, f.minRodTier, derived.minRodTier))
					assert(derived.minReelTier == f.minReelTier, string.format("%s: authored minReelTier %d ≠ derived %d (§2 catchability inequality)", f.id, f.minReelTier, derived.minReelTier))
				else
					-- appalachia + alaska: co-op-only fish (max(rod,reel) > 4) skip the solo sufficiency check;
					-- the band [T-1,T+1] is still enforced so the role anchor is correct.
					if math.max(f.minRodTier, f.minReelTier) <= 4 then
						assert(Fishing.landableAt(config, f, f.minRodTier, f.minReelTier), f.id .. ": must be landable at its authored rod+reel (sufficiency, §3)")
					end
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

	-- Step 14: the real-money product catalog self-validates on load (the pay-proof guard — no power-progression
	-- product, no item grant of tier gear, no non-balance-free cosmetic grant; the closed union forbids the rest).
	for id, product in config.products do
		assert(product.id == id, "products key '" .. id .. "' must match its id '" .. product.id .. "'")
		V.assertProduct(product, config)
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
		-- Step 11 never-gate guardrail (SYS_progression §2): an ENTRY-gate access item must be a VEHICLE — a
		-- mount/dog can never gate. MVL Destinations carry none (requiredAccessItems nil); this is the forward
		-- guard for any future water-locked entry gate, and proves evaluateGate's access half can only ever read
		-- a Boat (never a convenience item).
		local accessItems: { string } = dst.gate.requiredAccessItems or {}
		for _, itemId in accessItems do
			local accessItem = assert(config.equipment[itemId], dst.id .. ": gate access item '" .. itemId .. "' must resolve")
			assert(accessItem.category == Enums.Category.vehicle, dst.id .. ": a gate access item must be a vehicle — convenience (mount/dog) can never gate (SYS_progression §2)")
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

	-- Step 13: the LiveOps event calendar + daily-quest pool self-validate on load (the scarcity guard).
	V.validateLiveOps(config)
end

return V
