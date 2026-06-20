--!strict
-- Canonical value vocabulary. Every closed string-set the schema uses is defined here ONCE,
-- as both a Luau string-literal union (compile-time) and a frozen value table (runtime).
-- Names are the glossary's (04) and the SYS_ docs' — no synonyms.

local Enums = {}

-- Rarity scale (02 — fixed order Common→Mythic). Spawn rates are 1-in-N (a separate field).
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"
Enums.Rarity = table.freeze({
	Common = "Common" :: Rarity,
	Uncommon = "Uncommon" :: Rarity,
	Rare = "Rare" :: Rarity,
	Epic = "Epic" :: Rarity,
	Legendary = "Legendary" :: Rarity,
	Mythic = "Mythic" :: Rarity,
})
-- Ordinal rank — drives the Reward XOR boundary (Rare-and-above mint artifacts; economy RD5 / data-integrity §4).
local rarityRank: { [Rarity]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
}
Enums.RarityRank = table.freeze(rarityRank)
-- The single binding boundary: rarity at/above this rank pays an artifact, never Cash at mint.
Enums.RARE_AND_ABOVE_RANK = 3

-- Equipment category (Template B — exact set; there is NO `boat` category, Boats are `vehicle`).
export type Category =
	"weapon" | "armor" | "rod" | "reel" | "bait" | "tackle" | "vehicle" | "mount" | "dog" | "tool" | "cosmetic"
Enums.Category = table.freeze({
	weapon = "weapon" :: Category,
	armor = "armor" :: Category,
	rod = "rod" :: Category,
	reel = "reel" :: Category,
	bait = "bait" :: Category,
	tackle = "tackle" :: Category,
	vehicle = "vehicle" :: Category,
	mount = "mount" :: Category,
	dog = "dog" :: Category,
	tool = "tool" :: Category,
	cosmetic = "cosmetic" :: Category,
})
-- The ONLY categories that feed an effective tier (progression §1). Encoded structurally so
-- bait/tackle/vehicle/mount/dog/tool/cosmetic can never enter the EHT/EFT derivation.
local tierInputCategories: { [Category]: boolean } = {
	weapon = true,
	armor = true,
	rod = true,
	reel = true,
}
Enums.TIER_INPUT_CATEGORIES = table.freeze(tierInputCategories)

-- Creature behaviour archetypes (Template C).
export type Behavior = "passive" | "flees" | "aggressive" | "pack" | "ambush"
Enums.Behavior = table.freeze({
	passive = "passive" :: Behavior,
	flees = "flees" :: Behavior,
	aggressive = "aggressive" :: Behavior,
	pack = "pack" :: Behavior,
	ambush = "ambush" :: Behavior,
})

-- Co-op recommendation (Template C).
export type Coop = "soloTopGear" | "duo" | "party"
Enums.Coop = table.freeze({
	soloTopGear = "soloTopGear" :: Coop,
	duo = "duo" :: Coop,
	party = "party" :: Coop,
})

-- Water type (Template D / fishing §7). Boats grant access to a water type (never a stat).
export type WaterType = "pond" | "river" | "lake" | "coastal" | "deepSea"
Enums.WaterType = table.freeze({
	pond = "pond" :: WaterType,
	river = "river" :: WaterType,
	lake = "lake" :: WaterType,
	coastal = "coastal" :: WaterType,
	deepSea = "deepSea" :: WaterType,
})

-- The two cross-feeding loops (01 / progression). `offeredLoops` is authoritative gate input.
export type Loop = "Hunting" | "Fishing"
Enums.Loop = table.freeze({
	Hunting = "Hunting" :: Loop,
	Fishing = "Fishing" :: Loop,
})

-- Vendors (04). `StarterLoadout` is the free spawn grant, not a shop.
export type Vendor = "Outfitter" | "TackleShop" | "BoatDealer" | "KennelAndStable" | "StarterLoadout"
Enums.Vendor = table.freeze({
	Outfitter = "Outfitter" :: Vendor,
	TackleShop = "TackleShop" :: Vendor,
	BoatDealer = "BoatDealer" :: Vendor,
	KennelAndStable = "KennelAndStable" :: Vendor,
	StarterLoadout = "StarterLoadout" :: Vendor,
})

-- Monetization role (02 Template B — the full four-value set). An item carries a SET of roles
-- (EquipmentItem.monetizationRoles), e.g. a gating weapon is {power-progression, convenience}.
-- `power-progression` is a legitimate DESCRIPTOR (gear IS the progression gate); no-real-money-power is
-- enforced elsewhere (gear is Cash-cost; RankPerkCategory excludes `power`; real money never touches a
-- milestone), so the descriptor only adds fidelity to EQUIPMENT_MASTER §4.
export type MonetizationRole = "identity" | "convenience" | "access" | "power-progression"
local monetizationRoleSet: { [MonetizationRole]: boolean } = {
	identity = true,
	convenience = true,
	access = true,
	["power-progression"] = true,
}
Enums.MonetizationRoleSet = table.freeze(monetizationRoleSet)
Enums.MonetizationRole = table.freeze({
	identity = "identity" :: MonetizationRole,
	convenience = "convenience" :: MonetizationRole,
	access = "access" :: MonetizationRole,
	powerProgression = "power-progression" :: MonetizationRole,
})

-- Rank-perk category (progression §4 / build-time guarantee): `power` is NOT a legal value.
-- A perk in a power category is a build-time schema error (Validation.luau).
export type RankPerkCategory = "identity" | "convenience"
Enums.RankPerkCategory = table.freeze({
	identity = "identity" :: RankPerkCategory,
	convenience = "convenience" :: RankPerkCategory,
})

-- Artifact disposition (data-integrity §4 — the scarcity keystone). The single source of truth;
-- ESCROWED is a full value, not a side-flag. Mutually exclusive at any instant.
export type Disposition = "HELD" | "DISPLAYED" | "ESCROWED" | "SALVAGED"
Enums.Disposition = table.freeze({
	HELD = "HELD" :: Disposition,
	DISPLAYED = "DISPLAYED" :: Disposition,
	ESCROWED = "ESCROWED" :: Disposition,
	SALVAGED = "SALVAGED" :: Disposition,
})

-- Step 12: the PendingTrade negotiation states (server-owned; the read-only projection carries this).
export type TradeState = "REQUESTED" | "BUILDING" | "A_CONFIRMED" | "B_CONFIRMED" | "COMMITTING" | "COMPLETE" | "CANCELLED"
Enums.TradeState = table.freeze({
	REQUESTED = "REQUESTED" :: TradeState,
	BUILDING = "BUILDING" :: TradeState,
	A_CONFIRMED = "A_CONFIRMED" :: TradeState,
	B_CONFIRMED = "B_CONFIRMED" :: TradeState,
	COMMITTING = "COMMITTING" :: TradeState, -- both confirmed; in the settle window, then the swap
	COMPLETE = "COMPLETE" :: TradeState,
	CANCELLED = "CANCELLED" :: TradeState,
})

-- Artifact kind gates which dispositions are legal (data-integrity §4):
--   trophy        → full enum {HELD, DISPLAYED, ESCROWED, SALVAGED}
--   non-trophy    → reduced set {HELD, ESCROWED} (+ ownership transfer); DISPLAYED/SALVAGED are Trophy-only.
export type ArtifactKind = "trophy" | "trackingDog" | "mount" | "boat" | "cosmetic"
Enums.ArtifactKind = table.freeze({
	trophy = "trophy" :: ArtifactKind,
	trackingDog = "trackingDog" :: ArtifactKind,
	mount = "mount" :: ArtifactKind,
	boat = "boat" :: ArtifactKind,
	cosmetic = "cosmetic" :: ArtifactKind,
})
-- Dispositions legal for a non-trophy unique artifact. Trophy may use any Disposition value.
local nonTrophyDispositions: { [Disposition]: boolean } = {
	HELD = true,
	ESCROWED = true,
}
Enums.NON_TROPHY_DISPOSITIONS = table.freeze(nonTrophyDispositions)

-- Onboarding funnel beats (SYS_onboarding_funnel build-notes) — the server-owned tutorial state machine.
-- WORLD_MAP is declared but PASS-THROUGH at MVL (its reveal surface is Step 9). COMPLETE is a one-time
-- threshold (a returning player never re-enters). Beats are advanced ONLY by authoritative server events.
export type FunnelBeat = "FIRST_HUNT" | "FIRST_CATCH" | "FIRST_PURCHASE" | "WORLD_MAP" | "LOOP_CONFIRM" | "DAILY_INTRO" | "COMPLETE"
Enums.FunnelBeat = table.freeze({
	FIRST_HUNT = "FIRST_HUNT" :: FunnelBeat,
	FIRST_CATCH = "FIRST_CATCH" :: FunnelBeat,
	FIRST_PURCHASE = "FIRST_PURCHASE" :: FunnelBeat,
	WORLD_MAP = "WORLD_MAP" :: FunnelBeat,
	LOOP_CONFIRM = "LOOP_CONFIRM" :: FunnelBeat,
	DAILY_INTRO = "DAILY_INTRO" :: FunnelBeat,
	COMPLETE = "COMPLETE" :: FunnelBeat,
})

-- Real-money product kinds (Roblox terms, 04). Cash-cost items use the cash leg instead.
export type RealMoneyKind = "gamepass" | "devproduct"
Enums.RealMoneyKind = table.freeze({
	gamepass = "gamepass" :: RealMoneyKind,
	devproduct = "devproduct" :: RealMoneyKind,
})

-- Step 14: the CLOSED set of what a real-money product may grant (SYS_economy §7 — sell WITH the player).
-- This is the pay-proof keystone: a product's grant is a union of these SAFE variants ONLY (Cash | item |
-- cosmetic | multiplier). There is deliberately NO `conquest`/`tier`/`effective-tier-input` kind, so a
-- pay-to-win grant is UNREPRESENTABLE (the type-level guarantee, like the cosmetic "no stats field") — not a
-- role-tag a mis-tagged config could evade. `Schema.ProductGrant` is the tagged union over these kinds.
export type GrantKind = "cash" | "item" | "cosmetic" | "multiplier"
local grantKindSet: { [GrantKind]: boolean } = { cash = true, item = true, cosmetic = true, multiplier = true }
Enums.GrantKindSet = table.freeze(grantKindSet)
Enums.GrantKind = table.freeze({
	cash = "cash" :: GrantKind, -- a `currencypack` Cash faucet (hits the same milestone wall idle Cash does)
	item = "item" :: GrantKind, -- grant an EXISTING catalog item (never tier gear — Validation.assertProduct)
	cosmetic = "cosmetic" :: GrantKind, -- a balance-free cosmetic (the cosmeticOnly guarantee)
	multiplier = "multiplier" :: GrantKind, -- a time-limited / persistent ACTIVE-income multiplier (never idle/milestone)
})

-- Step 14: the real-money active-income multipliers (SYS_economy §7). A CLOSED set — the 2x Cash boost
-- (time-limited dev product) and VIP (persistent game pass). Applied at the active kill/catch GRANT only,
-- stacked multiplicatively up to the §7 max-stack ceiling; never on idle/daily/salvage/milestone.
export type CashMultiplier = "2xBoost" | "vip"
local cashMultiplierSet: { [CashMultiplier]: boolean } = { ["2xBoost"] = true, vip = true }
Enums.CashMultiplierSet = table.freeze(cashMultiplierSet)
Enums.CashMultiplier = table.freeze({
	boost2x = "2xBoost" :: CashMultiplier,
	vip = "vip" :: CashMultiplier,
})

-- Lodge decor SKU kind (SYS_lodge_trophy §3). A closed set; decor is identity-only, balance-free.
export type DecorKind = "decor" | "theme" | "framing"
Enums.DecorKind = table.freeze({
	decor = "decor" :: DecorKind, -- furniture/wall/lighting/rugs/fixture skins
	theme = "theme" :: DecorKind, -- cohesive room re-skin set (the high-value identity unit)
	framing = "framing" :: DecorKind, -- per-trophy plaque/frame/mount-quality upgrade
})

-- Step 13: LiveOps event taxonomy (SYS_liveops_calendar §2 — the four KINDS of scheduled event content).
-- LiveOps owns the SCHEDULE of each; it owns the MECHANISM of none. A closed set.
export type EventKind = "conditionWindow" | "seasonal" | "limitedTime" | "destinationDrop" | "weatherWindow"
Enums.EventKind = table.freeze({
	conditionWindow = "conditionWindow" :: EventKind, -- §3.1 a scheduled period a rare's spawn condition is active
	seasonal = "seasonal" :: EventKind, -- §3.2 real-season tie-ins (salmon run) at calendar scale
	limitedTime = "limitedTime" :: EventKind, -- §3.3 a manufactured moment (the spectacle / Winter Freeze)
	destinationDrop = "destinationDrop" :: EventKind, -- §3.4 a new region as a scheduled launch event (post-launch)
	weatherWindow = "weatherWindow" :: EventKind, -- recurring short-cycle weather beat (exclusive spawns + trait grants)
})

-- Step 13: the RD1 scarcity-discipline declaration kinds. An event may (a) schedule a window for an EXISTING
-- rare at its unchanged 1-in-N, or (b) introduce a GENUINELY-NEW permanently-scarce artifact. Never dilute.
export type NewScarcityKind = "referenceWindow" | "mintNew"
Enums.NewScarcityKind = table.freeze({
	referenceWindow = "referenceWindow" :: NewScarcityKind, -- RD1a: open a window for an existing rare (rate untouched)
	mintNew = "mintNew" :: NewScarcityKind, -- RD1b: a genuinely-new event-exclusive rare (its own permanent scarcity)
})

-- Step 13: daily-quest loop assignment (SYS_liveops §5). The cross-loop pair needs ≥1 Hunting + ≥1 Fishing;
-- `either` is the flexible third. (Distinct from the closed two-loop `Loop` because a quest may be loop-agnostic.)
export type QuestLoop = "Hunting" | "Fishing" | "either"
Enums.QuestLoop = table.freeze({
	Hunting = "Hunting" :: QuestLoop,
	Fishing = "Fishing" :: QuestLoop,
	either = "either" :: QuestLoop,
})

-- Weather-window catch traits (the GH "stackable mutation" analogue). A per-catch Cash-branch overlay ROLLED
-- at kill/catch time when its enabling weather window is live. Closed set — a trait is identity, never power;
-- it scales Cash only (RewardPipeline boost-branch), never tier/rarity/gate/artifact.
export type Trait = "stormTouched" | "frostbitten" | "goldenHour" | "fogShrouded" | "moonlit"
Enums.Trait = table.freeze({
	stormTouched = "stormTouched" :: Trait,
	frostbitten = "frostbitten" :: Trait,
	goldenHour = "goldenHour" :: Trait,
	fogShrouded = "fogShrouded" :: Trait,
	moonlit = "moonlit" :: Trait,
})

return table.freeze(Enums)
