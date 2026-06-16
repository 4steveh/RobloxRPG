--!strict
-- The runtime SHAPES. Pure type definitions (erased at runtime) consumed by config + logic + tests.
-- Source of truth: Templates B/C/D/E (02), SYS_data_integrity §1/§4, SYS_progression, the build prompt.

local Enums = require("@src/types/Enums")
local Ids = require("@src/types/Ids")
local Tuning = require("@src/config/Tuning")

type Rarity = Enums.Rarity
type Category = Enums.Category
type Behavior = Enums.Behavior
type Coop = Enums.Coop
type WaterType = Enums.WaterType
type Loop = Enums.Loop
type Vendor = Enums.Vendor
type MonetizationRole = Enums.MonetizationRole
type RankPerkCategory = Enums.RankPerkCategory
type Disposition = Enums.Disposition
type ArtifactKind = Enums.ArtifactKind
type RealMoneyKind = Enums.RealMoneyKind
type DestinationId = Ids.DestinationId
type TargetId = Ids.TargetId
type ItemId = Ids.ItemId
type ArtifactId = Ids.ArtifactId

local Schema = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Cost (XOR: a Cash price OR a real-money product — tagged so real money is explicit, Template B).
-- ─────────────────────────────────────────────────────────────────────────────
export type CashCost = { cash: number }
export type RealMoneyCost = { realMoney: { kind: RealMoneyKind } }
export type Cost = CashCost | RealMoneyCost

-- ─────────────────────────────────────────────────────────────────────────────
-- EquipmentItem (Template B → config). STRUCTURAL FIELDS ONLY — no stat numbers (those are generated
-- from the §1 curves at consumption time, Steps 4–5). Armor carries no stat; only its `tier`.
-- ─────────────────────────────────────────────────────────────────────────────
export type EquipmentItem = {
	id: ItemId,
	name: string,
	category: Category,
	tier: number, -- integer; 0/empty-slot semantics live in the derivation, not here
	availableAt: Vendor,
	cost: Cost,
	tradeable: boolean, -- routes the persistence path (data-integrity RD1): false=commodity, true=artifact
	tierInput: boolean, -- derived from category; TRUE only for weapon/armor/rod/reel (asserted)
	cosmeticOnly: boolean, -- cosmetics are balance-free (no stats, no accessGrant, no tier slot)
	monetizationRoles: { MonetizationRole }, -- the Template-B set ({} for free starter / friction-free items)
	accessGrant: WaterType?, -- vehicles that gate a water type (e.g. Coastal Skiff → coastal). Access, never a stat.
	notes: string,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Reward (XOR — binding). Common/Uncommon pay Cash at resolution; Rare-and-above mint EXACTLY ONE
-- artifact and write NO Cash at mint. The union has NO member carrying both → "cash + artifact on one
-- target" is UNREPRESENTABLE. No `salvageCash` field — the salvage floor is derived (economy/data-integrity).
-- ─────────────────────────────────────────────────────────────────────────────
export type CashReward = { kind: "cash", cash: { min: number, max: number } }
export type ArtifactReward = { kind: "artifact", artifact: { tradeable: boolean, displayableInLodge: boolean } }
export type Reward = CashReward | ArtifactReward

-- ─────────────────────────────────────────────────────────────────────────────
-- Rare fields (Template E) — folded onto a Creature/Fish row when rarity ≥ Rare.
-- ─────────────────────────────────────────────────────────────────────────────
export type RareFields = {
	spawnRate: number, -- 1-in-N (the per-window roll)
	tradeable: boolean,
	displayableInLodge: boolean,
	reReleasePolicy: string, -- default "NEVER"
	intendedContentMoment: string,
}

export type SpawnConditions = { time: string?, weather: string?, season: string?, event: string? }
export type CreatureSpawn = { location: string, conditions: SpawnConditions? }
export type FishSpawn = { conditions: SpawnConditions? }

-- ─────────────────────────────────────────────────────────────────────────────
-- Creature (Template C → config). `destinationId` (home Destination) is added to key the catalog by
-- Destination and to resolve a milestone target's home for the gate's milestone check.
-- reward is nil iff ambianceOnly (ambiance grants nothing).
-- ─────────────────────────────────────────────────────────────────────────────
export type Creature = {
	id: TargetId,
	destinationId: DestinationId,
	name: string,
	tier: number,
	rarity: Rarity,
	ambianceOnly: boolean,
	behavior: Behavior,
	packSize: number?,
	health: number, -- 1–100 (0 for ambiance)
	damageToPlayer: number, -- 1–100 (0 for non-threats)
	speed: number, -- 1–100
	minWeaponTierToKill: number,
	minArmorTierToSurvive: number,
	coop: Coop,
	reward: Reward?, -- nil iff ambianceOnly
	reskinOf: TargetId?, -- art/behavior link only; this row's own `tier` is authoritative
	spawn: CreatureSpawn,
	rare: RareFields?, -- present iff rarity ≥ Rare
	isMilestoneTarget: boolean?, -- the destination's designated HUNTING conquest target
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Fish (Template D → config). All fish grant a reward (no ambiance fish).
-- ─────────────────────────────────────────────────────────────────────────────
export type Fish = {
	id: TargetId,
	destinationId: DestinationId,
	name: string,
	tier: number,
	rarity: Rarity,
	typicalWeightKg: { min: number, max: number },
	recordWeightKg: number,
	fightDifficulty: number, -- 1–100
	minRodTier: number,
	minReelTier: number,
	baitRequired: string?,
	waterType: WaterType,
	reward: Reward,
	spawn: FishSpawn,
	rare: RareFields?, -- present iff rarity ≥ Rare
	isMilestoneTarget: boolean?, -- the destination's designated FISHING conquest target
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Destination + Gate (teleport framework + gating DAG). offeredLoops is authoritative gate input.
-- ─────────────────────────────────────────────────────────────────────────────
export type Gate = {
	requiredTier: number,
	milestoneTargets: { TargetId }, -- the prerequisite's conquest targets; loop-aware via the catalog
	prerequisiteDestinations: { DestinationId }, -- the DAG edges (⊆ conqueredDestinations)
}
export type Destination = {
	id: DestinationId,
	name: string,
	tier: number,
	offeredLoops: { Loop }, -- subset of {Hunting, Fishing}
	gate: Gate,
	teleportTarget: string, -- place/spawn ref — the framework hook (resolved in Step 9)
	notes: string?,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Rank perk registry (progression §4). `category` is identity|convenience — `power` is unrepresentable.
-- ─────────────────────────────────────────────────────────────────────────────
export type RankPerk = {
	id: string,
	name: string,
	category: RankPerkCategory,
	track: Loop, -- Hunting → Hunter Rank, Fishing → Angler Rank
	description: string,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- PlayerData (in-memory authoritative profile — the irreducible set, data-integrity §1).
-- Derived-never-stored: Cash balance, EHT/EFT, gate satisfaction (functions, not fields).
-- ─────────────────────────────────────────────────────────────────────────────
-- `instanceId` is a stable per-commodity identity (server-minted, monotonic per player). It survives
-- inventory mutation + a load/save round-trip — UNLIKE a list index (Step 1's broken model). It is what
-- equipped refs point at, so removing/reordering a commodity never re-points an equipped slot.
export type Commodity = { instanceId: string, catalogId: ItemId, intraLevel: number, equipped: boolean }
export type EquippedRefs = {
	-- the equipped commodity's stable instanceId (nil = empty slot). The input to derived EHT/EFT.
	weapon: string?,
	armor: string?,
	rod: string?,
	reel: string?,
}
export type Inventory = {
	fungible: { [ItemId]: number }, -- ammo/bait counts
	commodities: { Commodity }, -- typed-owned: gear, basic vehicles/dogs/cosmetics (identical instances)
	artifactIds: { [ArtifactId]: boolean }, -- set of owned unique artifact ids
}
export type Provenance = {
	sourceId: TargetId?, -- the creature/fish it was minted from
	mintedAt: number?, -- server time (Step 2 writes)
	validatingEventId: string?,
}
export type Artifact = {
	artifactId: ArtifactId,
	owner: string,
	kind: ArtifactKind, -- gates which dispositions are legal (data-integrity §4)
	disposition: Disposition, -- the single source of truth; mutually exclusive
	tradeable: boolean,
	tombstoned: boolean, -- SALVAGED or traded-away artifacts are MARKED, never erased (audit/rollback)
	provenance: Provenance,
}
export type LedgerLoop = "Hunting" | "Fishing" | "none"
export type LedgerEntry = {
	entryId: number, -- server-minted unique, monotonic per player (data-integrity §3)
	type: string, -- faucet/sink subtype (kill, catch, gear, idle, salvage, currencypack, …)
	amount: number, -- signed Cash (faucets +, sinks −)
	tier: number?,
	loop: LedgerLoop?,
	timestamp: number,
	validatingEventId: string, -- the kill/catch/trade/purchase event that authorized it (= PurchaseId for real money)
	realMoneyTag: string?, -- set for currency-pack / boost / VIP-attributable faucets
}
-- Cash storage layout (§3): a balance CHECKPOINT (sum of compacted/offloaded history) + a bounded recent
-- TAIL. balanceOf = checkpoint.balance + Σ(tail). lastEntryId is the monotonic id source (survives compaction).
export type LedgerCheckpoint = { balance: number, compactedCount: number, lastEntryId: number }
export type Ledger = { checkpoint: LedgerCheckpoint, tail: { LedgerEntry } }
export type Entitlement = { kind: string, expiryTimestamp: number } -- expiry is a server-time absolute (wall-clock)
export type PlayerData = {
	unlockedDestinations: { [DestinationId]: boolean }, -- one-time threshold, permanent
	conqueredDestinations: { [DestinationId]: boolean }, -- idempotent set membership (the Passport spine)
	hunterRankXP: number,
	anglerRankXP: number,
	inventory: Inventory,
	equipped: EquippedRefs,
	artifacts: { [ArtifactId]: Artifact },
	cash: Ledger, -- §3 checkpoint+tail (replaces Step 1's flat cashLedger)
	-- ── integrity-mechanism fields (extend §1's table; each implied/required by §3/§6) ──
	nextCommodityInstanceSeq: number, -- monotonic source for commodity instanceIds (Step 6 mints on buy)
	redeemedPurchaseIds: { [string]: boolean }, -- real-money idempotency tokens (§3 PurchaseId-uniqueness)
	logoutTimestamp: number, -- written at CLEAN session-end (§6 idle input); Step 2 writes it
	lastSaveTimestamp: number, -- written at every save; the §6 hard-crash idle fallback basis
	sessionOpen: boolean, -- true while a live session holds the profile; a loaded `true` ⇒ prior session crashed (§6)
	activeEntitlements: { Entitlement },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Aggregated config the pure functions consume. Logic takes this as `config`; it holds the catalogs,
-- the tuning constants, and the derived target→(loop, home, tier, milestone) index.
-- ─────────────────────────────────────────────────────────────────────────────
export type EquipmentCatalog = { [ItemId]: EquipmentItem }
export type CreatureCatalog = { [TargetId]: Creature }
export type FishCatalog = { [TargetId]: Fish }
export type DestinationCatalog = { [DestinationId]: Destination }
export type TargetIndexEntry = {
	loop: Loop,
	destinationId: DestinationId,
	tier: number,
	rarity: Rarity,
	isMilestone: boolean,
}
export type Config = {
	tuning: typeof(Tuning),
	equipment: EquipmentCatalog,
	creatures: CreatureCatalog,
	fish: FishCatalog,
	destinations: DestinationCatalog,
	rankPerks: { RankPerk },
	targetIndex: { [TargetId]: TargetIndexEntry },
}

return Schema
