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

-- Lodge decor SKU kind (SYS_lodge_trophy §3). A closed set; decor is identity-only, balance-free.
export type DecorKind = "decor" | "theme" | "framing"
Enums.DecorKind = table.freeze({
	decor = "decor" :: DecorKind, -- furniture/wall/lighting/rugs/fixture skins
	theme = "theme" :: DecorKind, -- cohesive room re-skin set (the high-value identity unit)
	framing = "framing" :: DecorKind, -- per-trophy plaque/frame/mount-quality upgrade
})

return table.freeze(Enums)
