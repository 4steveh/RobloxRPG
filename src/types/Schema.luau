--!strict
-- The runtime SHAPES. Pure type definitions (erased at runtime) consumed by config + logic + tests.
-- Source of truth: Templates B/C/D/E (02), SYS_data_integrity §1/§4, SYS_progression, the build prompt.

local Enums = require("./Enums")
local Ids = require("./Ids")
local Tuning = require("../config/Tuning")

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
type FunnelBeat = Enums.FunnelBeat
type RealMoneyKind = Enums.RealMoneyKind
type DecorKind = Enums.DecorKind
type EventKind = Enums.EventKind
type NewScarcityKind = Enums.NewScarcityKind
type QuestLoop = Enums.QuestLoop
type DestinationId = Ids.DestinationId
type TargetId = Ids.TargetId
type ItemId = Ids.ItemId
type ArtifactId = Ids.ArtifactId
type EventId = Ids.EventId

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
-- DecorItem (SYS_lodge_trophy §3 — the evergreen inflation ballast). A typed-owned cosmetic commodity:
-- Cash-priced, balance-free (NO stats field → balance-free by construction; identity-only monetization),
-- tradeable=false (a tradeable decor would be the rare-cosmetic ARTIFACT path — out of scope here / Step 11+).
-- A decor SKU with an artifactId is a build-time schema error (the type carries none).
-- ─────────────────────────────────────────────────────────────────────────────
export type DecorItem = {
	id: ItemId,
	name: string,
	kind: DecorKind,
	cost: Cost, -- the Cash leg (the sink); real-money decor is Step 14, rejected at load by assertDecorItem
	tradeable: boolean, -- MUST be false (typed-owned); asserted at load
	monetizationRoles: { MonetizationRole }, -- identity-only (balance-free); asserted at load
	notes: string,
}
export type DecorCatalog = { [ItemId]: DecorItem }

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
	-- ── Step-4 combat fields ──
	-- spawnZones: structured Step-3 zone ids the live spawner places this TARGET species into (the prose
	-- `spawn.location` stays a human description). nil for ambiance (placed via Shells.ambiancePlacements).
	spawnZones: { string }?,
	-- KillWindow inputs (SYS_combat §3, LOC-owned): escapeWindowSeconds = TimeToFlee for escape-bounded
	-- (passive/flees); attackIntervalSeconds = the survival-bounded DPS interval (aggressive/pack). In the
	-- non-lethal Bayou only the escape-bounded branch is load-bearing; survival-bounded is owed at Step 10.
	escapeWindowSeconds: number?,
	attackIntervalSeconds: number?,
	reward: Reward?, -- nil iff ambianceOnly
	reskinOf: TargetId?, -- art/behavior link only; this row's own `tier` is authoritative
	spawn: CreatureSpawn,
	rare: RareFields?, -- present iff rarity ≥ Rare
	isMilestoneTarget: boolean?, -- the destination's designated HUNTING conquest target
	typicalWeightKg: { min: number, max: number }?, -- cosmetic per-catch weight range (lb on the harvest card); never a payout input
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
	-- Step 13: a COMMODITY (e.g. tackle_ice_fishing_kit) the angler must OWN to attempt this catch. The
	-- generalization of `baitRequired` to durable typed-owned gear: baitRequired reads inventory.fungible,
	-- requiresItem reads inventory.commodities (the same item-ownership gate the Frozen Lake uses, NOT
	-- canAccessZone — the Kit is tackle, owned, never a vehicle and never a tier input). nil = no item gate.
	requiresItem: ItemId?,
	waterType: WaterType,
	-- Step-5 placement: the structured Step-3 water zones the live bite spawner places this fish into
	-- (the Fish equivalent of Creature.spawnZones; fish carry no prose location).
	spawnZones: { string }?,
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
	-- Step 9: entry-gate access items the player must OWN (e.g. a Boat for a water-locked Destination).
	-- OPTIONAL: MVL Destinations omit it (no entry is access-gated; Alaska's Boat gates a sub-area, Step 10/11).
	requiredAccessItems: { ItemId }?,
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
-- Step 12: the two-sided trade record (audit/rollback substrate, data-integrity §5/§7). Written to BOTH
-- parties' tradeLog inside the atomic swap so a reconcile-on-reload can reconstruct/reverse a trade across
-- the residual two-key persist crash window.
export type TradeRecord = {
	tradeId: string,
	partyA: string, -- the two owner keys
	partyB: string,
	aArtifactIds: { ArtifactId }, -- A's artifacts that moved to B
	bArtifactIds: { ArtifactId }, -- B's artifacts that moved to A
	payer: string, -- the owner key that paid the net Cash leg ("" if no Cash leg)
	cashGross: number, -- the gross Cash moved (net of the two sides' offers); tax skimmed from it
	tax: number,
	timestamp: number,
}
-- ─────────────────────────────────────────────────────────────────────────────
-- Lodge state (Step 8) — the player's count-based typed-owned slots/decor + decor layout. DISTINCT from
-- the instance-based `inventory.commodities` (gear): no instanceId, no equipped, no artifactId. Persisted
-- as part of the whole-profile atomic write (§1 — never split across desyncable keys). The Trophy Hall is
-- NOT here — it is a VIEW over `artifacts` where disposition==DISPLAYED (TrophyHall.luau), never stored.
-- ─────────────────────────────────────────────────────────────────────────────
export type DecorPlacement = { itemId: ItemId, slotKey: string } -- where an owned decor sits (cosmetic-only)
export type LodgeState = {
	boughtSlots: number, -- escalating-price slot expansions purchased; total slots = baseTrophySlots + boughtSlots
	ownedDecor: { [ItemId]: number }, -- count-based typed-owned decor/theme/framing (tradeable=false, no artifactId)
	placements: { DecorPlacement }, -- per-player decor layout (cosmetic; no economy/anti-dupe weight)
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
	tradeLog: { TradeRecord }, -- Step 12: append-only two-sided trade records (audit/rollback)
	cash: Ledger, -- §3 checkpoint+tail (replaces Step 1's flat cashLedger)
	-- ── integrity-mechanism fields (extend §1's table; each implied/required by §3/§6) ──
	nextCommodityInstanceSeq: number, -- monotonic source for commodity instanceIds (Step 6 mints on buy)
	redeemedPurchaseIds: { [string]: boolean }, -- real-money idempotency tokens (§3 PurchaseId-uniqueness)
	logoutTimestamp: number, -- written at CLEAN session-end (§6 idle input); Step 2 writes it
	lastSaveTimestamp: number, -- written at every save; the §6 hard-crash idle fallback basis
	sessionOpen: boolean, -- true while a live session holds the profile; a loaded `true` ⇒ prior session crashed (§6)
	-- ── Step-15 retention substrate (server-time; the D1/D7/D30 basis — Analytics.retentionDay). NOT derivable
	-- from the ledger/idle timestamps: firstSeenAt is the install/first-session anchor, set ONCE on the fresh
	-- profile; lastSeenAt is updated every login. Cohort rollup is the AnalyticsService (ops). ──
	firstSeenAt: number, -- server time of the FIRST session (0 = never seen; SessionService stamps it once)
	lastSeenAt: number, -- server time of the most recent login (the return-detection input)
	activeEntitlements: { Entitlement },
	-- ── Step-7 onboarding funnel + daily-quest state (server-owned, in the session-locked profile) ──
	onboarding: OnboardingState,
	daily: DailyState,
	-- ── Step-8 Lodge state (count-based slots/decor + decor layout; the Trophy Hall is a VIEW, not here) ──
	lodge: LodgeState,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Onboarding funnel (Step 7) — the server-owned tutorial state machine. Survives disconnect (it's in the
-- session-locked profile), never client-spoofed; COMPLETE is a one-time threshold. `progress` is the
-- per-beat counter (LOOP_CONFIRM needs N loop actions); `beatStartedAt` feeds per-beat dwell telemetry.
-- ─────────────────────────────────────────────────────────────────────────────
export type OnboardingState = {
	funnelBeat: FunnelBeat,
	beatStartedAt: number, -- server time the current beat began (now − this = dwell, for drop-off telemetry)
	completedAt: number?, -- set when COMPLETE; its presence is the "returning player" marker
	progress: number, -- per-beat event count (resets on each transition)
}

-- Daily-quest state (Step 7 skeleton) — the cross-loop pair + the reset basis. `resetBasis` is a NEW
-- server-time field (its own; no collision with logout/lastSave); the daily window rolls off it via the
-- server clock, never client-reported elapsed. Content/rotation is Step 13; this is the board+claim skeleton.
export type DailyState = {
	resetBasis: number, -- server time of the current daily window's start
	huntDone: boolean, -- the day's hunting objective satisfied (a validated kill since resetBasis)
	fishDone: boolean, -- the day's fishing objective satisfied (a validated catch since resetBasis)
	claimed: boolean, -- the cross-loop pair already claimed this window (idempotent per day)
}

-- ─────────────────────────────────────────────────────────────────────────────
-- LiveOps event framework (Step 13 — SYS_liveops_calendar §A/§7). A new event/season is a CONFIG RECORD
-- the live game loads — no code per event (RD4). The scheduler (logic/LiveOps) recomputes which events are
-- live from SERVER TIME every tick and drives the WorldState `event` clause the spawn predicate already reads.
-- ─────────────────────────────────────────────────────────────────────────────
-- The RD1 new-scarcity declaration: an event may (a) open a window for an EXISTING rare at its UNCHANGED
-- 1-in-N (referenceWindow), or (b) introduce a GENUINELY-NEW event-exclusive rare (mintNew). It may NEVER
-- edit an existing artifact's rarity/1-in-N (structurally absent here) nor clone one under a colliding id
-- (the scarcity guard rejects both — Validation.assertEventConfig / assertNewScarcityId).
export type NewScarcityDecl = { kind: NewScarcityKind, targetId: TargetId }
-- What the event IMPOSES on the spawner's WorldState while live. `event` is the single spawn-gating clause
-- (one event at a time, equality-matched — Spawner.WorldState). nil fields impose nothing.
export type ImposedWorld = { event: string?, season: string?, weather: string?, time: string? }
export type EventConfig = {
	id: EventId,
	name: string,
	kind: EventKind,
	startTime: number, -- server-time absolute (inclusive); the activation window's open
	endTime: number, -- server-time absolute (inclusive); reverts AFTER this on the per-tick recompute
	imposes: ImposedWorld, -- the WorldState the event drives while live (imposes.event = the spawn-gating clause)
	cashBudget: number, -- per-window thin participation Cash cap (≤ tuning.economy.eventPayoutBudgetCeiling)
	-- RD1b: the GENUINELY-NEW fish this event INTRODUCES (authored here, NOT in the base Fish catalog). The
	-- Catalog merges these into config.fish with a clone-evasion collision check (a minted id must not pre-
	-- exist in ANY catalog — that is what makes "genuinely new" structural, not a forgeable spawn-clause edit).
	-- A `mintNew` newScarcity decl MUST name a member of this list; a `referenceWindow` decl names an EXISTING
	-- rare. OPTIONAL — most events (conditionWindow / seasonal) introduce no new fish (nil = none).
	mintsFish: { Fish }?,
	newScarcity: { NewScarcityDecl }, -- the RD1 declaration (audited + guarded at load)
	notes: string,
}
export type EventCatalog = { [EventId]: EventConfig }
-- A daily-quest pool entry (Step 13 §F). MECHANICAL, not narrative ("Catch 5 trout"). Liveops authors WHICH
-- quests; economy owns the reward SCALE (Economy.dailyQuestReward, scaled by T_current — an open economy call).
export type Quest = { id: string, loop: QuestLoop, objective: string, themedFor: EventId? }
export type LiveOpsConfig = { events: EventCatalog, dailyQuestPool: { Quest } }

-- ─────────────────────────────────────────────────────────────────────────────
-- Monetization (Step 14 — SYS_economy §7 / EQUIPMENT_MASTER §4.8–4.10 / 00 §4). The real-money layer,
-- "sell WITH the player": real money compresses grind (Cash, multipliers) + removes friction, but NEVER
-- buys a milestone, a tier, a rare, or a gate.
--
-- THE PAY-PROOF KEYSTONE — `ProductGrant` is a CLOSED tagged union of SAFE variants (Cash | item | cosmetic
-- | multiplier). It has NO conquest/tier/effective-tier-input member, so a pay-to-win grant is
-- UNREPRESENTABLE — the same type-level guarantee the Reward XOR and the cosmetic no-stats field give,
-- stronger than a role-tag a mis-tagged config could sneak past. A function that tries to write the conquest
-- set off a ProductGrant cannot type-check (negative fixture `pay_to_win_grant.luau`).
-- ─────────────────────────────────────────────────────────────────────────────
export type CashGrant = { kind: "cash", amount: number } -- injects a `currencypack` Cash faucet
-- `item` grants an EXISTING catalog item (a game-pass Boat = the same ACCESS grant bought a different way; a
-- premium-bait dev-product pack = a fungible stack). `quantity` is the fungible stack size (nil → 1 / a
-- single commodity). Validation.assertProduct rejects an item grant of TIER GEAR (tierInput) — real money
-- never hands a power input.
export type ItemGrant = { kind: "item", itemId: ItemId, quantity: number? }
export type CosmeticGrant = { kind: "cosmetic", itemId: ItemId } -- a balance-free cosmetic (cosmeticOnly; no stats)
export type MultiplierGrant = { kind: "multiplier", multiplier: Enums.CashMultiplier } -- active-income multiplier (§7)
export type ProductGrant = CashGrant | ItemGrant | CosmeticGrant | MultiplierGrant

-- A real-money product (dev product or game pass). Config-driven: a new pack/pass is a config row (RD4-style).
-- `assetId` is a Roblox asset-id PLACEHOLDER — Steve binds the real ids in Studio. `role` is the Template-B
-- monetization role; Validation.assertProduct forbids `power-progression` on any product (the never-power
-- guard extended to the catalog). The grant is the closed union above.
export type Product = {
	id: string,
	name: string,
	kind: RealMoneyKind, -- gamepass | devproduct (the platform purchase mechanism)
	assetId: string, -- Roblox asset-id PLACEHOLDER (bound in Studio)
	grant: ProductGrant,
	role: MonetizationRole, -- never power-progression (asserted) — identity|convenience|access only
	notes: string,
}
export type ProductCatalog = { [string]: Product }

-- ─────────────────────────────────────────────────────────────────────────────
-- Destination SHELL (Step 3 — the navigable place). Pure DATA: positions are plain {x,y,z} tables (not
-- Roblox Vector3) so the shell is headless. The world blockout converts to Vector3 at runtime. Keyed by
-- DestinationId so a second Destination (Appalachia, Step 10) reuses the framework with new data.
-- ─────────────────────────────────────────────────────────────────────────────
export type Vec3 = { x: number, y: number, z: number }
export type ZoneKind = "arrival" | "hunting" | "fishing" | "rareSite" | "vendor"
export type Zone = {
	id: string,
	name: string,
	kind: ZoneKind,
	center: Vec3,
	size: Vec3, -- bounding box of the region (placeholder geometry + ambiance scatter)
	description: string,
}
export type Landmark = {
	id: string,
	name: string,
	anchor: Vec3,
	isBeacon: boolean, -- the Old Cypress: visible from most of the map, the wayfinding beacon
	description: string,
}
export type Shell = {
	destinationId: DestinationId,
	arrivalZoneId: string, -- the §2.6 arrival/spawn clearing
	zones: { [string]: Zone }, -- the §2.3 functional regions (named, reusable)
	landmarks: { [string]: Landmark }, -- the §2.2 navigate-by points
	vendorOutpostAnchor: Vec3, -- The Landing (Outfitter + Tackle Shop), §2.3
	travelSignpostAnchor: Vec3, -- co-located with the vendor outpost (§2.6.3)
	ambiancePlacements: { [TargetId]: string }, -- ambianceOnly species id → home zone id (target species are NOT mapped here — Steps 4/5)
	render: { fogStart: number, fogEnd: number, drawDistance: number }, -- §2.5 fog-as-cull budget
}
-- Character-controller tunables (Tier 1 is on-foot only). walkSpeed is applied server-side to the
-- Humanoid on arrival; the camera tunables are read by the client controller.
export type Movement = { walkSpeed: number, jumpPower: number, cameraMinZoom: number, cameraMaxZoom: number }

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
	decor: DecorCatalog,
	liveOps: LiveOpsConfig, -- Step 13: the event calendar + daily-quest pool (config-not-code, RD4)
	products: ProductCatalog, -- Step 14: the real-money product catalog (dev products + game passes; config-driven)
	targetIndex: { [TargetId]: TargetIndexEntry },
}

return Schema
