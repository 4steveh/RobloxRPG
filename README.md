# Wild World — Build (Steps 1–10)

A Roblox/Luau hunting-and-fishing RPG. This repo holds the design corpus (the `*.md` specs) and the
implementation, built step-by-step per `03_BUILD_PLAN.md` Phase 4. The **headless-verifiable** code (data,
pure logic, server substrate) is strict Luau (`--!strict`), unit-tested with no Roblox runtime. **Client /
world / feel** code is Studio-only and verified by a manual playtest checklist — see the honest-coverage
note per step.

- **Step 1 — Project Skeleton & Data Model.** Data-driven content catalogs, the canonical player-state
  schema, and the pure derivation logic (EHT/EFT, gate, balance). Shape + pure logic only.
- **Step 2 — Data Persistence & Server-Authority Foundation.** The session-locked persistence layer, the
  server-authority validation gauntlet, the Cash-ledger store, and the anti-dupe primitives — the
  substrate every economic system (Steps 6/8/12) plugs into. **Primitives, not operations.**
- **Step 3 — Core Movement & the Bayou Shell.** A navigable, seam-correct Bayou **placeholder shell**
  (data-driven zones/landmarks/anchors), a mobile character controller, and the login→arrival flow.
  **The headless bar is the data/logic seams; the world & feel are a Studio playtest** (see below).
- **Step 4 — The Hunting System.** The first gameplay verb: a loop-agnostic **target spawner** + **shot
  resolution** (the gauntlet's step-3 hook) + the shared **reward pipeline** — the Step-2 substrate's
  first real caller (a kill drives `Transaction` → `Ledger`/`ArtifactStore.mint`/conquest atomically). The
  deferred EQUIPMENT_MASTER §1 combat/armor curves are implemented and the min-tier fields are now
  **derived & asserted**. **The combat math/pipeline/caps are headless-proven; game FEEL and the live shot
  are a Studio playtest** — split honestly below.
- **Step 5 — The Fishing System.** The second half of the dual loop, built by **extending** the Step-4
  substrate: the shared **reward pipeline** gains one `describe` branch (not forked), the **spawner cap** is
  *generalized* so one anti-farming line serves both loops, and `Fishing.luau` adds the catchability
  inequality (`FightTime ≤ LandWindow`) with derived min rod/reel tiers. The **OR-gate** is one shared
  idempotent conquest flag (gator *or* Blue Catfish). **The catchability math/pipeline/caps are
  headless-proven; the fight FEEL is a Studio playtest** — split honestly below.
- **Step 6 — Economy & Shops.** The convergence point: the real economy **formulas** (`Income`/`GearCost`/
  `IntraTierClimb`/`Payout`) replace the **three `Payout`/idle stubs** (idle, hunting, fishing); the
  Outfitter/Tackle-Shop **gear sinks** (buy + intra-tier upgrade) are server-authoritative gauntlet
  handlers minting commodities; and the **dual-loop reconciliation** (01 risk #3) + the MVL gear-Cash jump
  are proven headless. **The formulas/sinks/reconciliation are headless-proven; the shop UI, felt pacing,
  and the *live* (measured) reconciliation are Studio/telemetry** — split honestly below.
- **Step 7 — The Onboarding Funnel (First Five Minutes).** A **different-shaped, mostly-UX** step: the
  headless core is a thin-but-rigorous server-owned `OnboardingState` machine (data-driven beats advancing
  on *authoritative* events inside the handlers' atomic commit), a scoped first-spawn **eligibility
  predicate**, the no-real-money-until-`COMPLETE` gate, and the daily-quest **skeleton**. **The funnel
  *working* is a playtest/telemetry verdict (the D1 > 25% gate), not a green-CI one** — the felt FTUE and
  every D1 metric are Studio/telemetry, split honestly below.
- **Step 8 — The Lodge & Trophy Hall.** A **thin-but-rigorous headless core** + a **large Studio bulk**. The
  Trophy Hall is a **VIEW, not a store** — `filter(profile.artifacts, DISPLAYED)`, no parallel list, no
  desync/dupe surface. Step 8 builds the **flows that CALL the existing primitives** (it reimplements none):
  **salvage** (the §4 CAS `→ SALVAGED` + the `salvageFloor` credit, in one `Transaction` — atomic,
  idempotent via the CAS precondition, terminal), **display / take-down** (the `HELD↔DISPLAYED` CAS, gated on
  owned **slot capacity**), the **slot + decor Cash sink** (the economy's §9 evergreen inflation ballast —
  escalating/uncapped slots + a balance-free decor catalog), and the **Lodge arrival routing** (a
  funnel-`COMPLETE` player returns to the Lodge; a first-time player to the Bayou root). The **one-server
  bootstrap** consolidates the per-step `.server` slices into a single login owner. **The flows are
  headless-proven; the bootstrap, the Lodge interior, trophy rendering, the "Mount it" prompt, decor
  placement, and the visit/social path are Studio** — split honestly below.
- **Step 9 — World Map, Fast-Travel & Destination Gating.** A thin progression-integrity-adjacent core +
  a Studio map UI. The **unlocked set is persisted truth, not a live derivation** (`commitUnlocks` only ever
  *adds* the one-time threshold crossing — selling gear never re-locks), and **fast-travel cannot bypass a
  gate** (`travelTo` validates the target against the persisted set). Step 9 *calls* `Gate.evaluateGate` /
  `EffectiveTier` / the teleport scaffold / the persisted Passport sets — it rebuilds none of them. It wires
  the unlock-commit into conquest (Fire/Catch, gated on `conquestNewlySet`) + equip + the login/Travel-Desk
  catch-all; builds the World-Map pin + Passport surface; and flips the onboarding `WORLD_MAP` beat from
  pass-through to a real reveal. **The map UI, the `TeleportService` execution, and the Passport-readout feel
  are Studio** — split honestly below.
- **Step 10 — Appalachia & Alaska.** The rosters (creatures, fish, rares, milestones) were **already
  authored in Steps 4/5** — Step 10 **verified and extended** them; it did not re-author the stat blocks.
  What was added: the KillWindow inputs (`escapeWindowSeconds` / `attackIntervalSeconds`) deferred from
  Step 4 for the non-Bayou tiers; structured `spawnZones` on every non-ambiance Appalachia/Alaska target;
  Appalachia/Alaska shell zone data + spawn config (LOC §8.4 ceilings/caps); a re-skin behavior-template-
  reuse check; a `Fishing.requiresBoat` coastal/interior marker (data only — enforcement is Step 11); and
  the **cross-tier difficulty rigor** as the headline headless deliverable. The rigor discharges the Step-4
  owed T2→T4 check: strict `derived==authored` was proven unachievable cross-tier, replaced by the
  spec-faithful floor/ceiling semantics (sufficiency + role band + co-op-only wall + co-op-soluble), with
  two derivation defects fixed. Two genuine stat defects were caught and corrected. **The world geometry,
  fast-travel execution, and co-op feel are Studio** — split honestly below.

> Source-of-truth specs, in priority order: `02_DATA_SCHEMA_AND_TEMPLATES.md` (units/templates),
> `04_GLOSSARY.md` (names), `SYS_progression.md`, `SYS_economy.md`, `EQUIPMENT_MASTER.md`,
> `SYS_data_integrity.md` (the binding spec for Step 2).

## Quick start

```bash
./run-tests.sh   # strict type-check (all modules) + unit tests + negative fixtures + rojo build
```

Toolchain on `PATH`: **`luau`** (run tests), **`luau-analyze`** (`--!strict`, config in `.luaurc`),
**`rojo`** (`rojo build` → place file). Requires resolve by Luau require-by-string via `.luaurc` aliases
(`@src/...`, `@tests/...`). `default.project.json` maps `src/` → `ServerScriptService.WildWorld`.

## The rules of the codebase

- **config (data) vs logic (pure).** `src/config/` holds every content value; `src/logic/` holds pure
  functions with zero hardcoded content (they read `profile` + `config` args).
- **interface vs adapter** (Step 2). Persistence logic depends on `src/server/persistence/Types.luau`
  interfaces, never on `DataStoreService` directly. In-memory **fakes** make it headless-testable; thin
  **Roblox adapters** (`RobloxAdapters.luau`) run in Studio.
- **derive, don't store.** Cash balance, EHT/EFT, and gate satisfaction are functions over the profile,
  never stored fields (every stored derivable is a stale-state dupe surface).
- **substrate vs operations** (Step 2). This build owns the primitives (lock, ledger, CAS, gauntlet,
  transaction); later steps own the operations that call them.

## Module map

```
src/
  types/   Ids · Enums · Schema   (string-id registries; the closed enums; all record TYPES + PlayerData + Config)
  config/  Tuning (EQUIPMENT_MASTER §1 set + §-persistence params + §combat Step-4 knobs) · Equipment ·
           Creatures (+ Step-4 spawnZones/KillWindow inputs; +Step-10 Appalachia/Alaska KillWindow inputs + spawnZones) ·
           Fish (+ Step-10 Appalachia/Alaska spawnZones + requiresBoat marker) · Destinations (gate DAG) · RankPerks ·
           Validation (build-time assertions, incl. Step-4 authored==derived min-tiers for Bayou;
             +Step-10 cross-tier floor/ceiling semantics: sufficiency, role band, co-op-only wall, co-op-soluble) ·
           Catalog (self-validates) · Shells (Step 3 — the Bayou shell; +Step-10 Appalachia/Alaska shells; self-validates + placement check)
           · Spawning (Step 4 — per-(destination,loop) caps + throughput ceiling; loop-agnostic; +Step-5 .fishing; +Step-10 Appalachia/Alaska caps)
           · Decor (Step 8 — the starter MVL decor/theme/framing catalog; Cash-priced, balance-free, tradeable=false; self-validates)
  logic/   (pure)  EffectiveTier (EHT/EFT) · Gate (evaluateGate) · Balance (checkpoint+tail fold) · Profile
           · Shell (Step 3 — distances/walk-time/crossing-time + shell validators)
           · Combat (Step 4 — weapon/armor curves, shot/kill math, co-op, non-lethal clamp, min-tier derivation, validators)
           · Fishing (Step 5 — reel/rod curves, FightTime ≤ LandWindow, min rod/reel derivation, Angler XP, drain validators, co-op)
           · Economy (Step 6 — Income/GearCost/IntraTierClimb/Payout/salvageFloor + per-loop normalization + reconciliation; +Step-7 dailyQuestReward/crossLoopBonus)
           · Spawner (Step 4 — caps/engagement rate, exclusions, rare predicate, placement; GENERALIZED Step 5; +modeledRatePerHour Step 6)
           · Profile (+ Step-6 mintCommodity: the gear-grant primitive the shops + the starter loadout use)
           · Onboarding (Step 7 — the data-driven funnel state machine: advance/firstSpawnEligible/isOnboardingComplete; server-auth, idempotent, atomic)
           · Daily (Step 7 — the daily cross-loop pair objective state + the server-time reset; the board-claim skeleton)
           · TrophyHall (Step 8 — the VIEW: filter(artifacts, DISPLAYED); plaque from provenance; slot usage; NO parallel store)
           · Economy (+ Step-8 slotExpansionPrice: the escalating/uncapped evergreen-sink slot price)
           · Progression (Step 9 — commitUnlocks: the persisted-truth unlock set; worldMapPins/passportCounts: the Passport surface; CALLS evaluateGate, never re-derives)
  server/
    ArrivalService.luau   (Step 3) login→Bayou arrival resolver (the gate-less root; returning→Lodge is Step 8)
    combat/
      RewardPipeline.luau   (Step 4) the SHARED ordered atomic reward (loop-agnostic): ambiance→0 · Reward XOR · Rank XP · conquest. Step 5 adds ONE describe branch.
      FireHandler.luau      (Step 4) the "fire" intent handler — the gauntlet's step-3 shot resolution + the reward commit (critical)
    fishing/
      CatchHandler.luau     (Step 5) the "catch" intent handler — the gauntlet's step-3 fight resolution + the (shared) reward commit (critical)
    shop/
      ShopHandler.luau      (Step 6) the Outfitter/Tackle-Shop gear sinks — buy + intra-tier upgrade gauntlet handlers (critical, atomic Cash debit + commodity mint)
    daily/
      ClaimDailyHandler.luau (Step 7) the daily cross-loop-pair claim — credits the faucet + breadth bonus, completes DAILY_INTRO (critical, idempotent per day)
    lodge/
      SalvageHandler.luau     (Step 8) the "salvage" intent — §4 CAS →SALVAGED + salvageFloor credit, one Transaction (critical, atomic, idempotent, terminal)
      DisplayHandler.luau     (Step 8) "mountTrophy"/"takeDownTrophy" — HELD↔DISPLAYED CAS + slot-capacity gate (critical; no Cash)
      LodgeShopHandler.luau   (Step 8) "buySlot"/"buyDecor" (the evergreen Cash sink, evergreen-tagged) + "placeDecor" (cosmetic layout)
    progression/
      WorldMapHandler.luau    (Step 9) the "openWorldMap" intent — completes the WORLD_MAP reveal beat + the commitUnlocks catch-all (critical)
    idle/Idle.luau          (+ Step-6 economyAmount: the real idle amount at T_idle = max(EHT, EFT))
    world/WorldServer.server.luau   ⌂ STUDIO-ONLY (Step 8) — THE ONE login owner: one SessionService + one shared gauntlet registry (every handler), Bayou + Lodge build, both spawners + flows, kind-aware arrival
  client/CharacterController.client.luau   ⌂ STUDIO-ONLY — mobile camera/controls (→ StarterPlayerScripts)
  server/
    persistence/
      Types.luau          interfaces: DataStoreLike, Clock, IdGenerator, AuditSink, Telemetry, StoredProfile/LockInfo
      Fakes.luau          in-memory fakes (DataStore w/ failure injection + deep-copy serialization; clock; id gen; audit; telemetry)
      Copy.luau           deep copy / in-place restore (transaction snapshots, read-only projections)
      ProfileStore.luau   THE KEYSTONE — session lock (heartbeat-gated steal), lock-verified save, retry/revert
    ledger/
      Ledger.luau         checkpoint+tail; no-yield atomic debit; entryId mint; PurchaseId idempotency; compaction→audit
      (audit sink = persistence/Types.AuditSink; in-memory fake in Fakes)
    artifacts/
      ArtifactStore.luau  mint (unique id + provenance + HELD); CAS disposition transition (kind-gated); tombstone-on-salvage
    authority/
      Gauntlet.luau       the 6-step validation gauntlet + request router (steps 1,2,4,5,6; step 3 pluggable)
      Transaction.luau    atomic multi-mutation commit-as-a-unit + revert-on-failed-write
      Replication.luau    read-only server-computed projection (balance/EHT/EFT/gates) from the pure fns
      handlers/EquipHandler.luau   the ONE reference intent handler (equip Y)
    idle/Idle.luau        idle integrity mechanism (clamp, single entry, idempotent, hard-crash fallback, idle-proof); amount stub
    SessionService.luau   orchestration: login (lock+load/fresh+idle+write-through) / logout (flush+logoutTimestamp+release) / autosave
    DestinationService.luau  teleport registry + canTravel preview + travelTo (Step 9: gated fast-travel ENFORCEMENT — validates the persisted unlocked set, resolves teleportTarget)
    RobloxAdapters.luau   thin injection-based Roblox adapters (Studio-only binding; strict-clean headless)
tests/   harness + specs (Step 1: Catalog/EffectiveTier/Gate/Balance/Profile/Validation; Step 2:
         ProfileStore/Ledger/ArtifactStore/Gauntlet/Idle/Integrity; Step 3: Shell/Arrival; Step 4:
         Combat/Spawner/RewardPipeline/FireHandler; Step 5: Fishing/CatchHandler; Step 6: Economy/ShopHandler;
         Step 7: Onboarding/Daily/ClaimDailyHandler;
         Step 8: Lodge/TrophyHall/SalvageHandler/DisplayHandler/LodgeShopHandler;
         Step 9: Progression/Travel/WorldMapHandler;
         Step 10: CrossTier assertions — sufficiency/role-band/co-op-wall/co-op-soluble for Appalachia+Alaska) · negative/ (MUST fail analysis)
docs/superpowers/plans/   the implementation plans
```

## Step 1 carry-over fixes (done in Step 2, tested)

1. **`monetizationRoles` — the four-value Template-B SET** (`identity | convenience | access |
   power-progression`). EquipmentItem now carries a *set* of roles (a gating weapon is
   `{power-progression, convenience}`); rows are retagged per EQUIPMENT_MASTER §4 via a category-default
   builder. (No-real-money-power is enforced elsewhere: gear is Cash-cost; `RankPerkCategory` excludes
   `power`; real money never touches a milestone.)
2. **`EquippedRefs` — stable `commodityInstanceId`, not a list index.** Equipped slots point at a
   commodity's stable `instanceId`, so a reference survives inventory mutation + a load/save round-trip
   (tested: prepend a commodity, shifting all indices → EHT unchanged).
3. **`LedgerEntry.type`** (was `kind`) — matches `SYS_data_integrity` §3.

Plus the ledger restructure: `PlayerData.cash = { checkpoint, tail }`; `balanceOf = checkpoint.balance +
Σ tail`. New integrity-mechanism fields (`nextCommodityInstanceSeq`, `redeemedPurchaseIds`,
`lastSaveTimestamp`, `sessionOpen`) extend §1's table — each documented to its §.

## Step 2 — the substrate (primitives, each → its SYS_data_integrity §)

| Primitive | What it guarantees | §  |
|---|---|---|
| **ProfileStore** session lock | single live writer per player; steal a lock ONLY if stale past `sessionLockTimeoutSeconds`; a **live (heartbeating) lock is never stolen**; a save by a lock-loser is rejected; failed-save retries then reverts to last-good (no corruption) | RD5, §1, §7 |
| **Ledger** | balance = checkpoint + Σ tail (no bare int); no-yield atomic debit can't go negative; monotonic `entryId` survives compaction; compaction offloads to the append-only audit log preserving balance; **PurchaseId idempotency** (real-money exactly-once across redelivery) | §3 |
| **ArtifactStore** | one mint → one unique id + provenance + `HELD`; CAS transition rejects a wrong precondition (defeats the double-spend race); kind-gating (DISPLAYED/SALVAGED Trophy-only); SALVAGED tombstones (marked, never erased) | §4, §5 |
| **Gauntlet** | every client *request* runs 6 steps (Authenticity → Authority → Simulation[pluggable] → Atomic commit → Persist → Replicate); a client **assertion** has no route and is rejected; the projection is a read-only server-computed shadow | §2 |
| **Transaction** | a multi-mutation event (mint + ledger + conquest) commits as ONE unit; a failed durable write reverts both halves — **no orphan** | §2.4, §7 |
| **Idle** | one clamped `idle` entry at login; Cash-only (never Rank XP / conquest); idempotent (reconnect race can't double-credit); hard-crash fallback under-credits vs last-save | §6 |

## Honest coverage — headless-proven vs Studio-manual

The persistence/authority **logic** is fully unit-tested headless against in-memory
fakes that faithfully model the Roblox realities the logic depends on: `UpdateAsync`'s synchronous
read-modify-write transform, value serialization (deep copy, so a mutation can't leak into the durable
copy), and throttle/failure injection.

**Studio-only — NOT exercised headless (manual checklist before launch):**
- [ ] `RobloxAdapters.dataStore` against a real DataStore (UpdateAsync yields, throttles, 4 MB key limit).
- [ ] The bootstrap that wires `game:GetService(...)` into a `SessionService` (one screen; see below).
- [ ] `Players.PlayerRemoving` + `BindToClose` firing `SessionService.logout` (session-end flush + release).
- [ ] Real two-server concurrency: the lock under a real DataStore (the fake proves the algorithm).
- [ ] `HttpService:GenerateGUID` artifact ids; `MarketplaceService`/`ProcessReceipt` feeding
      `Ledger.attemptRealMoneyCredit` (the callback wiring itself is Step 14).
- [ ] `MemoryStore` cross-server lock brokering — **deferred/open**, not MVL (DataStore lock is MVL).

**Studio bootstrap (illustrative — the only `game:GetService` edge):**
```lua
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Adapters = require(... .RobloxAdapters)
local SessionService = require(... .SessionService)
local svc = SessionService.new({
  store = Adapters.dataStore(DataStoreService:GetDataStore("WildWorld_Profiles_v1")),
  clock = Adapters.clock(),
  config = require(... .config.Catalog),
  serverId = game.JobId,
  idleAmountFn = nil, -- Step 6 supplies the real economy formula (defaults to Idle.stubAmount)
})
game.Players.PlayerAdded:Connect(function(plr) SessionService.login(svc, plr.UserId) end)
game.Players.PlayerRemoving:Connect(function(plr) SessionService.logout(svc, plr.UserId) end)
game:BindToClose(function() for id in svc.sessions do SessionService.logout(svc, id) end end)
```

## Step 3 — the Bayou shell (the bar is split, honestly)

This step is mostly client/world/feel, which a headless harness **cannot** judge. So "ALL GREEN headless"
is **not** the success bar — the data/logic seams are headless-tested, and the world/controller/feel are a
navigable placeholder verified by the Studio playtest checklist below.

**Headless-proven (the data/logic seams):**
- The §2.3 **named zones** exist as defined regions with stable ids (config loads + self-validates; keyed
  by `DestinationId` so a 2nd Destination reuses the framework). The §2.2 landmarks (the Landing, the Old
  Cypress beacon) are anchored.
- **Ambiance placement**: every `ambianceOnly` Bayou species (Egret, Painted Turtle, Songbird) has a home
  zone; **no TARGET species is placed** (targets + the species→zone mapping + the spawner are Steps 4/5).
- The **§2.6 layout constraints that are measurable**: the Landing is a ~15–20 s walk from arrival; a
  channel bank is a few steps away; the arrival clearing is adjacent to (faces) the Sunny Levee; the
  signpost is co-located with the vendor outpost; the whole map crosses on foot in **< 60 s**. *(Distances
  are computed from config; **sightlines and feel are Studio.**)*
- **Arrival routing**: a login resolves to the Bayou arrival anchor (the unconditional gate-less root);
  unit-tested. *(The returning→Lodge branch is explicitly absent — `TODO(step-8)`.)*

**Studio playtest checklist — NOT headless; verify on a phone/Studio (all unchecked):**
- [ ] Usable frame rate on a mid phone (the §2.5 fog-as-cull / low-draw-distance budget actually holds).
- [ ] The whole map is crossable on foot in **under ~1 minute** (§2.4).
- [ ] **The Landing is in line of sight** of the levee and the bank from arrival (§2.6.2 — the distance is
      headless-proven; the *sightline* is not).
- [ ] The arrival clearing **faces the Sunny Levee** and a channel bank is a few steps off (§2.6.1 feel).
- [ ] You can **navigate by the Old Cypress** — it's visible from most of the map (§2.2 legibility).
- [ ] On-foot movement feels right (not sluggish); the third-person camera works on touch.
- [ ] `require`-by-string (`@src/...`) resolves at runtime in the target Roblox version (Rojo + Roblox
      require-by-string); login→arrival places the character at the clearing.

**Placeholder note:** `BayouShell_Placeholder` is blockout geometry (coloured parts, flat-plane water,
particle dragonflies). Finished art — cypress models, water shader, textures, sound — is the separate
**Phase-3 art pass**, not this step. The *layout* is data-driven and correct-by-construction; only the
*look* is placeholder.

## Step 4 — the hunting system (the bar is split, honestly)

Two bars, split deliberately. **The combat math, the reward pipeline, and the spawn caps are
rigor-critical and headless-proven.** But **game feel is the single most important quality bar of this
system** (SYS_combat §1 — "where the game is won or lost") and it is **Studio-only**: recoil, hit-stop,
impact, the kill reaction, audio, haptics, the clean-kill flourish, the actual aim/fire. We do **not**
report a green for feel that only a phone can confirm.

**The spawner and the reward pipeline are loop-agnostic** — built once here and reused by fishing (Step 5);
the reward pipeline is *shared* by design (duplicating the Reward XOR / atomic-commit across two steps
would invite the divergence the integrity model forbids). The only loop-specific seam is the pipeline's
per-loop descriptor (which catalog, which Rank field, the ledger type).

**Prerequisites landed (Step-1 schema gaps closed):** structured **`spawnZones`** on every Bayou target
(prose `spawn.location` kept) and the **KillWindow inputs** (`escapeWindowSeconds` = TimeToFlee;
`attackIntervalSeconds` = survival DPS) — populated for the Bayou (Appalachia/Alaska survival-bounded
inputs are left nil, owed at Step 10). Added the **Nutria** floor creature (LOC §3).

**Headless-proven (the rigor-critical core):**
- **Damage/kill math** — `WeaponDamage(T,ℓ)`, `CycleTime`, `Range`/`RangeFalloff`, `ShotDamage`,
  `ShotsToKill`, `TimeToKill`, armor `DR = clamp(0.50 + 0.12·(armorTier−creatureTier), 0, 0.85)`,
  `DamageTaken` — from EQUIPMENT_MASTER §1 + Tuning, unit-tested against the §3 Bayou floor band.
- **Min-weapon/min-armor-tier are DERIVED, not authored truth** — `Combat.deriveMinTiers` computes them
  from the kill inequality (`ShotsToKill ≤ KillWindow/CycleTime`, mid-gear reference) and **`Validation`
  asserts the catalog's authored values match** at load (a mis-statted creature fails the `require`). The
  Bayou exercises the **escape-bounded** branch (the floor creatures + the gator: `ceil(48/18)=3` shots →
  min-weapon-tier 1); **min-armor-tier is n/a (0) Bayou-wide** (non-lethal — no survival-bounded lethal
  creature). The full survival-bounded branch first does real work at Step 10.
- **Bayou-wide non-lethal clamp** — an armorless player cannot be reduced below 1 HP by **any** Bayou
  creature, including the aggressive American Alligator (tested: 100 gator lunges → still 1 HP).
- **Co-op scaling** — `EffectiveHealth(N) = Health·(1 + 0.5·(N−1))`, sublinear, capped at `partyCap` 4.
- **Spawn caps (the economy invariant)** — `ExpectedTargetsPerHour = min(3600/TimePerTarget, ceiling)`;
  an over-geared player's realized routine rate is **bounded by the ceiling (~85/hr ≈ Income(1)), not
  their kill speed** (the anti-low-tier-farming guarantee: ≪ Income(4) ≈ 4913). **Ambiance never consumes
  the reward-bearing ceiling**; rares are **condition-gated independent spawns** (a per-window predicate,
  never a per-kill upgrade roll).
- **Reward pipeline (the substrate's first real caller)** — ambiance → **zero** (no entry/XP/mint/
  conquest); routine → **one** `Ledger` entry (stub `Payout`) + Rank XP; rare → **one** `ArtifactStore`
  mint + **no Cash**; the alligator conquest is **idempotent**; the whole pipeline commits as **one
  `Transaction`** — a forced save failure mid-commit leaves **no orphan** (no entry/artifact/XP/conquest).
- **Anti-exploit validators** — damage-spoof (damage not derivable from equipped-weapon × legal zone ×
  range), fire-rate-faster-than-`CycleTime`, and out-of-range are **rejected**, headless-tested as pure
  validators. The **LOS decision** is unit-tested against a stubbed ray result; the **raycast itself is
  Studio**.

| Pipeline step | Hunting (Step 4) | Fishing (Step 5, reuses) |
|---|---|---|
| 1. Ambiance check | early-return zero | — (no ambiance fish) |
| 2. Reward XOR | routine→Cash (`kill`) / rare→trophy mint | routine→Cash (`catch`) / rare→trophy mint |
| 3. Rank XP (weighted) | `hunterRankXP` (Combat.rankXP) | `anglerRankXP` (TODO step-5) |
| 4. Conquest (idempotent) | the American Alligator | the Blue Catfish |
| commit | one atomic `Transaction` (shared) | one atomic `Transaction` (shared) |

**Studio playtest checklist — NOT headless; the game-feel bar verified on a phone (all unchecked):**
- [ ] **The kill feels good** — recoil, hit-stop on a vital, impact VFX, a readable kill reaction,
      class-distinct audio, mobile haptics (SYS_combat §1 — the win-or-lose-it quality).
- [ ] The **first Bayou kill** is the punchy ~60 s dopamine hit the funnel depends on.
- [ ] **Clean-kill flourish** fires on a rare (the designed content moment).
- [ ] Aim/settle/fire works with two thumbs; **aim-assist** helps settle without placing the shot.
- [ ] Behaviors read right: a duck flushes, a rabbit breaks, the gator telegraphs its lunge before it hits
      (legibility-of-death — no random one-shots).
- [ ] No lethal threat is an unexplained instakill.
- [ ] The physical spawner places/respawns targets server-side at the right density; the LOS raycast
      rejects through-wall shots in the live world.

**Named stubs (built as pluggable seams; the owning step swaps in the real thing):**
- **`Payout` (the per-kill Cash amount)** → **Step 6** (`RewardPipeline.stubPayout` here, modeled on
  `Idle.stubAmount`; we do **not** read the catalog's illustrative `cash:{min,max}`).
- **Cash revive-in-place price** → Step 6; **rewarded-ad revive** → Step 14. The free respawn-and-walk
  path is what Step 4 builds (downed forfeits only the current hunt — never banked Cash/inventory).
- **Rank-XP magnitudes** are illustrative (the *weighting* by difficulty/rarity is the design, SYS_progression §4).
- **First-spawn cap bypass** (the funnel's guaranteed first kill) → Step 7. **Rare event scheduling** → Step 13.

~~**Owed at Step 10**: the T2→T4 difficulty check~~ — **DISCHARGED (Step 10)**. See the Step 10 section for
the full story: strict `derived==authored` was unachievable cross-tier; the spec-faithful floor/ceiling
semantics (sufficiency + role band + co-op-wall + co-op-soluble) were asserted instead, with two derivation
defects fixed and two stat defects corrected.

## Step 5 — the fishing system (extend, don't fork; the bar is split, honestly)

Fishing is the second half of the dual loop, built by **extending** the Step-4 substrate — the integrity
model forbids duplicating the Reward XOR / atomic-commit / conquest path or the cap math, so neither was
copied:
- **The reward pipeline gained ONE `describe` branch** (`config.fish`, Angler Rank XP, `ledgerType
  "catch"`). The XOR / mint / ledger / conquest path is the **same code** both loops run.
- **The spawner cap was GENERALIZED**, not duplicated: the anti-farming `min(3600/TimePerTarget, ceiling)`
  is one line, parameterized by `loop` (engagement table + target collection + conditions-bearer). The
  Step-4 hunting callers default to Hunting and are unchanged.

Fishing is **mechanically distinct** (Resolved Decision 1): sustained tension management, **no death, no
armor, no respawn** — the only failure is *losing the fish* (snap/throw/timeout), and it's non-punitive
(never costs banked Cash/inventory). The **fight FEEL** (the tension gauge, the push-pull rhythm, the
runs, weighty haptics, the cast) is fishing's win-or-lose-it bar and is **Studio-only**.

**Prerequisite landed:** `spawnZones` added to the `Fish` schema (the only gap — the fight inputs
`fightDifficulty`/weights/`minRod/ReelTier` and the `Tuning.fishingFight` constants were already present);
the 6 Bayou fish are placed in `channel_banks`/`catfish_hole`.

**Headless-proven:**
- **Catchability math** — reel curve `ReelDrainMax` (weapon-analog) + rod curve `BreakThreshold`
  (armor-analog), `StaminaToLand`, `NetDrain`, `FightTime` (∞ if NetDrain ≤ 0), `LandWindow`, and the
  single inequality `FightTime ≤ LandWindow` — from EQUIPMENT_MASTER §1 + `Tuning`.
- **Min rod/reel tiers are DERIVED, asserted == authored** at load for the **routine Bayou band** (the
  4 Common/Uncommon fish derive to `1/1`, incl. the Blue Catfish milestone at ft 9.02 ≤ lw 9.6). **Rares
  are excluded from the band** (RD5 — bonus-on-top finds): the Leviathan's colossal weight intentionally
  exceeds the T1 fight model ("the difficulty is reaching the condition, not the fight"). Cross-tier is
  owed at Step 10.
- **The OR-gate** — catching the **Blue Catfish** sets `conqueredDestinations["bayou"]`, the **same**
  idempotent flag the American Alligator sets; conquering via either loop (in either order) leaves it set
  **once** (tested both ways).
- **The bite-density cap** — fishing's `BiteThroughputCeiling` (~65/hr) runs through the *same* generalized
  anti-farming line; an over-geared player's realized catch-rate is bounded by the ceiling near
  `Income(1)`, not catch speed. Rares (and any ambiance) are excluded from the routine population.
- **Anti-exploit** — drain-spoof (drain not derivable from the equipped reel × a legal tension `E ∈ [0,1]`)
  and illegal tension are rejected; the rare predicate **takes no bait input** (Decision 4 — you cannot
  buy your way to a rare). The runtime **gear-adequacy** gate (`gear_insufficient`) is the min-tier check
  in play: a fresh *entry* rig snaps on the milestone until a cheap intra-tier upgrade reaches mid.
- **Reuse holds:** the Step-4 hunting tests are **unchanged and green** — the shared path did not regress.

**Studio playtest checklist — NOT headless; the fight-feel bar on a phone (all unchecked):**
- [ ] **The fight feels good** — the tension gauge is tactile/readable one-handed, runs spike with weighty
      haptics, audio swells with tension and resolves on the land (Decision 1 / 01 risk #4).
- [ ] The push-pull rhythm (reel-when-calm, ease-on-runs) reads and rewards skill.
- [ ] The **first Bayou catch** is the punchy ~60 s funnel beat on the free starter rod+reel.
- [ ] The hook-set window feels fair; snap/throw failures read as the player's error, not arbitrary.
- [ ] **Clean-catch flourish** fires on a rare (the 1-in-N screenshot beat).
- [ ] The physical bite spawner + spot-depletion (rotate spots / read fresh water) behaves on a phone.

**Named stubs (owning step):** the real **`Payout`** → Step 6 (reuses `RewardPipeline.stubPayout`); the
**bait shop + starter-bait grant** (so "buy bait → catch" is end-to-end) → Step 6/7 (grant bait manually
for the Step-5 playtest); **premium bait** (paid `TimeToBite` accelerator) → Step 14 (stub; assert
rare-spawn takes no bait); **Boats** → Step 11 (Bayou is shore-accessible, no Boat gating built).

~~**Owed at Step 10**: Alaska's king-salmon milestone + the coastal Boat gate + the halibut apex, and the
dual-loop reconciliation/drift check~~ — **DISCHARGED (Step 10)**. King Salmon is confirmed coastal/Boat-
gated (`requiresBoat=true`; enforcement → Step 11). The halibut `typicalWeightKg.max` was corrected 180→80
for co-op-solubility. Economy reconciliation (`routineHourSum` = `Income(T)` both loops) holds for
Appalachia and Alaska.

## Step 6 — economy & shops (the convergence; the bar is split, honestly)

Step 6 is where the three pipelines running on a **stub `Payout`** since they were built (idle from Step 2,
hunting from Step 4, fishing from Step 5) get the **real economy formulas**, and where the dual-loop
balance (01 risk #3, the most fragile thing in the game) becomes *provable*.

**The constants already existed** (`Tuning.economy`: `B/g/c/m`, the rarity ladder, idle fraction/cap) —
Step 6 implements the **functions** that read them and adds the one missing value (the salvage floor).

**Headless-proven:**
- **Formulas** — `Income(T)=B·g^(T−1)` (1000/1700/2890/4913), `GearCostSlot(T)=c·Income(T−1)` (3000/5100/
  8670), `IntraTierClimb(T)=m·Income(T)` (2500 at T1), the rarity ladder, and the salvage floor. Every
  gating item's catalog price is asserted == the formula (drift check).
- **The three stubs are gone.** Hunting + fishing pay the **real `Payout`**, with the **routine band
  normalized per loop** by `AvgRoutineMultiplier(dest, loop)` so each loop's routine hour sums to *exactly*
  `Income(T)` — the denominator is the **modeled** engagement rate (80/60 at Bayou T1), never the
  ceiling-clamped one. Rares still **mint** (the XOR holds — Cash is realized only at the low salvage
  floor, Step 8). Idle pays the **real amount** at **`T_idle = max(EHT, EFT)`** (this is Step 6's
  resolution of the Step-2/economy open "current tier" question — **flagged to ratify**; floors to
  under-credit, idle-only, never milestone).
- **Dual-loop reconciliation (01 risk #3)** — a test asserts **each loop's normalized routine hour sums to
  `Income(T)`** for Bayou/Appalachia/Alaska (parity *by construction*, not a raw hunting≈fishing compare),
  plus **ceiling slackness** (modeled ≤ ceiling at each dest-tier — the at-tier complement to the
  over-geared anti-farming bound).
- **The MVL gear-Cash jump** — Appalachia→Alaska costs `2c·g ≈ 10.2` hrs (≈1.7×); a normal step is `2c=6`.
  (Pure formula; the combat *difficulty* T2→T4 check stays Step 10.)
- **Shops** — the **commodity-mint** primitive (`Profile.mintCommodity`); buy debits `GearCostSlot(T)` +
  mints an `entry` commodity (not equipped → **EHT unchanged until equipped**, never gates by purchase);
  upgrade increments `intraLevel` + debits the `IntraTierClimb` step (**EHT/EFT unchanged** — intra-tier
  never gates); insufficient funds rejects with **no partial state**; both commit atomically (forced save
  failure → no orphan Cash or gear); non-gating items (bait) and the free starter are rejected.
- **Finding:** the **starter-loadout grant already exists** in production (`Profile.freshProfile` →
  `SessionService.login`) — the prompt's "appears absent" was incorrect; not rebuilt (the mint is built
  regardless, for the shops).

**Studio / telemetry — NOT headless (all unchecked):**
- [ ] The **Outfitter / Tackle Shop UI** reads and transacts on a phone (the buy/upgrade screens; the
      handlers are built and headless-tested — only the UI is Studio).
- [ ] A gear upgrade **feels earned** — the first-five-minutes intra-tier purchase lands as the soft-
      monetization beat; "money → gear → access → bigger prey" reads.
- [ ] **Live reconciliation** — realized fishing Cash/hr ≈ hunting Cash/hr at comparable progress (the
      drift alarm needs real play data; the modeled per-loop-sum proof above is *not* the live proof).
- [ ] The faucet/sink ledger shows ≈ flat per-capita Cash supply in a played/simulated population.

**Named stubs (owning step):** real-money **currency packs / 2×-VIP multipliers / auto-sell** → Step 14;
the **salvage TRANSITION + choose-disposition UI** → Step 8 (Step 6 supplies the floor amount); **cosmetics
/ Lodge decor** (the evergreen inflation ballast) → Step 8/14; **Boats/Mounts/Dogs** (priced by this curve)
→ Step 11; **trade tax** → Step 12; **dailies / cross-loop daily bonus delivery** → Step 7/13.

## Step 7 — the onboarding funnel (mostly UX; the headless core is thin but rigorous)

This is a **different-shaped** step from 1–6: most of its value is the felt first-five-minutes and the **D1
telemetry**, which only real players validate. The headless core is real but deliberately **thin** — and
held to the full session-locked-profile discipline (server-auth, idempotent, resume-safe) because it lives
in that profile.

**Headless-proven:**
- **The `OnboardingState` machine is data-driven + server-authoritative.** Beats
  (`FIRST_HUNT → FIRST_CATCH → FIRST_PURCHASE → WORLD_MAP → LOOP_CONFIRM → DAILY_INTRO → COMPLETE`) are
  declared data; each advances **only on an authoritative event** (a validated kill / catch / `"gearUpgrade"`
  purchase / daily claim), never a client flag. `Onboarding.advance` runs **inside the handler's
  `Transaction`** — so a beat advances **atomically with the reward** (a forced save failure reverts the
  advance *and* the reward — tested) and is idempotent.
- **One-shot.** `COMPLETE` is a one-time threshold (like an unlocked Destination) — a returning player never
  re-enters; a post-completion event never re-grants.
- **Disconnect-resume.** `OnboardingState` is in the session-locked profile (persisted at login + on
  `markDirty`/autosave), so a dropped player reloads at the last-saved beat — **never a full restart**.
- **The first-spawn guarantee is a scoped eligibility predicate.** `firstSpawnEligible` is true **only** for
  a first-time player, in the loop's arrival-proximate area, at the beat that first needs that loop's
  target — and **false** for a post-first / non-arrival / returning case (the **no-low-tier-farming-leak**
  guarantee). *The guaranteed spawn itself is Studio (the services call the predicate); the headless
  deliverable is the predicate.*
- **The no-real-money gate.** `isOnboardingComplete` is false through the funnel, true at `COMPLETE` — the
  structural predicate Step 14's store must gate on (the first session is provably real-money-prompt-free).
- **Ambiance kills don't advance** the funnel (no Cash → not a comprehension beat) — tested.
- **The daily skeleton.** `Daily` tracks the cross-loop pair (one hunt + one catch) with a **server-time**
  reset (never client elapsed); `ClaimDailyHandler` credits `Economy.dailyQuestReward` + `Economy.crossLoopBonus`
  **once per day** (idempotent) through the ledger and completes the `DAILY_INTRO` handoff. The economy
  amounts (deferred by Step 6) scale off `T_current = max(EHT, EFT)`.
- Steps 1–6 tests stay green (the handlers now advance the funnel + record the daily objective atomically).

**Studio / telemetry — NOT headless (the real bar; all unchecked):**
- [ ] The opening chain *plays* on a phone: ≤60 s to first Cash, ≤120 s to first cross-loop Cash, ≤5–7 min
      to `DAILY_INTRO`, with single arrows / world-space pings / unmissable "+Cash" feedback.
- [ ] The first-purchase beat reads as a *wanted* earned-Cash upgrade — no real-money prompt, no countdown.
- [ ] Aim-assist boost guarantees the first shot lands **and tapers** to the standard cap after onboarding.
- [ ] The **D1 dashboard**: per-beat drop-off, time-to-first-reward, conversion, **D1 segmented by the beat
      the session ended on**, session-2 daily-claim — all `isOnboarding`-tagged, separable from steady-state.
- [ ] The funnel moves D1 toward the **> 25%** launch gate (the verdict only real players give).

**Seams / deferrals (named, not silently resolved):**
- **`WORLD_MAP` is a pass-through here** — Step 9 swaps the pass-through for the real World-Map reveal + a
  real completion predicate (a config/handler swap, no machine change).
- **Daily content / rotation / cadence** → Step 13; **the store / real-money** → Step 14 (gates on
  `isOnboardingComplete`); **idle-accrual intro** → session 2 (deliberately withheld — surfacing "earn while
  away" in the first 5 min teaches a new player to log off); **co-op** → later tiers (the Bayou is solo).
- **A/B knobs preserved as config** (not silently resolved): hunt-first vs fish-first, World-Map reveal
  timing, aim-assist taper, chain length, first-purchase affordability — beats are data-driven for exactly this.

## Step 8 — the Lodge & Trophy Hall (view-not-store; call-don't-reimplement; the bar is split, honestly)

The single most important property: **the Trophy Hall is a VIEW, not a store** — `filter(profile.artifacts,
disposition == DISPLAYED)`. There is **no parallel `trophyWall` list** to keep in sync, hence no
desync/dupe surface between inventory and wall (SYS_data_integrity §4). The plaque (what/where/when) reads
the artifact's **provenance** — one source of truth, never re-entered. The second property: Step 8 **CALLS
the existing primitives, it reimplements none** — `ArtifactStore.transition` (the §4 CAS), `Economy.salvageFloor`,
`profile.artifacts`, `Onboarding.isOnboardingComplete`, the `Ledger`, the `Gauntlet`, `Transaction`.

**Schema additions (Step 8 owns):** a count-based `PlayerData.lodge = { boughtSlots, ownedDecor, placements }`
— typed-owned slots/decor (no `instanceId`/`equipped`/`artifactId`), distinct from the instance-based gear
`commodities`; a `Config.decor` catalog (`Decor.luau`); `Tuning.lodge` (`baseTrophySlots = 8`, the
escalating/uncapped `slotExpansionPrice`, `visitInstancingMode`); and a Lodge **arrival representation**
(`Shells.lodge` + a `kind: "lodge" | "destination"` discriminator on `Arrival`) — the Lodge is the hub, NOT
a `requiredTier==0` Destination, so it does not fit the shell/gate model.

**Headless-proven (the flows + the sink — full discipline on the salvage path):**
- **Salvage** — `transition(HELD|DISPLAYED → SALVAGED)` + a `salvageFloor` credit commit in **one
  `Transaction`** (a forced save failure leaves the artifact **un-salvaged AND no Cash** — no orphan); a
  re-salvage of a SALVAGED/escrowed artifact **fails the CAS precondition → no double-credit**; `SALVAGED`
  is terminal; `DISPLAYED → SALVAGED` is **one** atomic transition. Server derives the floor from the
  artifact's own provenance (never a client amount).
- **Display / un-display** — `mountTrophy` (HELD→DISPLAYED) and `takeDownTrophy` (DISPLAYED→HELD) call the
  CAS and re-render; **mounting past owned slot capacity is rejected** (`slots_full` — the sink pull); a
  non-Trophy `→ DISPLAYED` is rejected (§4 kind-gating); a DISPLAYED trophy has **no direct trade path**
  (take it down first — escrow/swap is Step 12).
- **Trophy Hall view** — `TrophyHall.displayed(profile) = filter(artifacts, DISPLAYED)` with provenance read
  from the artifact record; **no parallel structure persisted** (a test asserts the wall is derived, not
  stored); also exposed read-only in `Replication.projection.trophyHall` (the client renders from the
  server-computed shadow; a client edit changes nothing).
- **Slot/decor sink** — `buySlot` (escalating, **uncapped** `slotExpansionPrice`) and `buyDecor` debit Cash +
  grant the count-based owned slot/decor, **server-validated + atomic + evergreen-tagged** (`slotExpansion`
  / `decor` ledger types; `economy.evergreenSink:*` telemetry — the §9 canary `evergreen-sink share of
  endgame Cash`); **insufficient funds rejects with no partial state**; a decor SKU that is not balance-free
  is **rejected at load** (`assertDecorItem`: identity-only monetization, Cash-priced, `tradeable=false`).
  `placeDecor` records the cosmetic layout (no economy/anti-dupe weight).
- **Arrival routing** — `resolveArrival` returns the **Lodge** for `isOnboardingComplete`, the **Bayou root**
  for a first-time player (a headless branch test).
- Steps 1–7 tests stay green (the artifact CAS + the ledger now carry the salvage/display/sink flows through
  their existing atomic paths).

**Studio / telemetry — NOT headless (the real bar; all unchecked):**
- [ ] **The one-server bootstrap** — a single login/`SessionService` owner with every handler (hunting,
      fishing, shop, daily, salvage/display/decor, world) on **one shared gauntlet registry**; the per-step
      `.server` slices (`BayouBlockout`/`HuntingService`/`FishingService`) consolidated into one runnable
      `WorldServer.server.luau`. **Verify exactly one login lock per profile** in a running session (the
      headless session logic is unchanged; this is the wiring). The deleted slices each stood up their own
      `SessionService` and could not coexist.
- [ ] The Lodge interior renders within mobile budget (low-poly, streamed); service fixtures are
      look-navigable (a gun rack reads as the Outfitter); built-vs-stub fixtures read as ready vs "coming"
      (Trophy Hall/Outfitter/Tackle Shop built; World Map → 9, Trading Post → 12, Boat Dealer/Kennel → 11).
- [ ] A mounted trophy renders with a **rarity-distinct model** (an albino reads white **without a UI
      label**), a provenance plaque (weight-kg/where/when — the **weight-kg label is the Studio render**,
      derived from the source species' weight data; provenance carries sourceId + mintedAt), and rarity
      framing — readable in a screenshot.
- [ ] The **"Mount it" auto-prompt** fires after the rare flourish (`autoPromptOnMint` on) as a UI beat that
      leaves the artifact **HELD until tapped** (dismissing is a no-op; no auto-display path).
- [ ] Decor placement *feels* like making the Lodge yours; the Hall fills as a visible return hook.
- [ ] The **instancing/visit path** (own-Lodge vs shared-lobby vs visit-on-invite) — **not built**; deferred
      to the server-model + moderation pass (see the flag below).
- [ ] `evergreen-sink share` + the display/expansion/visit metrics populate.

**Flagged (resolve-or-flag, not silently baked):**
- **Lodge-visit instancing model — UNRESOLVED.** MVL builds the player's **own-Lodge** Trophy Hall + all
  flows (instancing-agnostic — the content is a view either way; only *who can see it and how* is open).
  `Tuning.lodge.visitInstancingMode = "ownInstance"`. Recommend a **shared Lodge social-lobby**
  (partner-finding) **+ visitable individual Lodges on invite** (the flex) — but **confirm the mobile render
  budget first**. Decide with the server/session model + a moderation pass (13+ audience, visiting
  strangers). No visit/social path is built.
- **`baseTrophySlots` / `slotExpansionPrice` numbers are provisional** (`8` / base `5000` · growth `1.5`) —
  economy ratifies the absolute Cash post-soft-launch (same deferral as Step 7's daily amounts); the
  **model** (escalating, uncapped, no `maxTrophySlots`) is fixed.

**Deferrals (named with their owning step):** trading / `HELD→ESCROWED` / the swap → **Step 12** (Step 8
routes "take down to trade" into take-down and hands off); the World Map / Travel Desk reveal + gated
teleport → **Step 9** (the fixture is placed); Boats / Mounts / Dogs inventories → **Step 11** (fixtures
placed); real-money decor + the **auto-sell game pass** (assert auto-sell-never-salvages-a-trophy where
auto-sell is built) → **Step 14** (decor here is Cash-priced); the ongoing decor/theme/framing catalog
**cadence** → **Step 13** (Step 8 ships the starter MVL catalog + the purchase mechanism); a "show off rare
companions" surface (rare dogs/mounts beyond the Trophy Hall) → deferred (LiveOps / a future Kennel
deep-dive — do **not** overload the Trophy Hall). **Displayed trophies grant no non-cosmetic benefit, ever.**

## Step 10 — Appalachia & Alaska (the cross-tier difficulty check; the bar is split, honestly)

### What was built vs what was already there

The creature, fish, rare, and milestone **stat blocks were authored in Steps 4 and 5** (minWeaponTier /
minArmorTier / minRodTier / minReelTier, fightDifficulty, weights, spawnWeights, behaviorTemplate). Step
10's job was to **verify and extend** them, not re-author them. What Step 10 added or completed:

- **KillWindow inputs** (the Step-4 survival-bounded owed items): `escapeWindowSeconds` (flee timer for
  fleers) and `attackIntervalSeconds` (DPS cycle for aggressors), sourced from LOC §3, on every non-ambiance
  Appalachia/Alaska creature (the Bayou already had them from Step 4).
- **Structured `spawnZones`** on every non-ambiance Appalachia/Alaska target (hunting + fishing), so
  `Spawner.validatePlacement` can verify every target has a legal zone.
- **Appalachia/Alaska shell zone data + spawn config** — per-destination spawn zones + throughput ceilings
  + anti-farming caps authored from LOC §8.4; wired into the loop-agnostic Spawner.
- **Re-skin behavior-template-reuse check** — a re-skin species must reuse its origin's behavior template,
  or be a recognizably calmer find/flee variant (accommodating the Spirit Moose as a passive find).
- **`Fishing.requiresBoat` marker** — a per-species boolean distinguishing coastal (Boat-gated) from
  interior water fishing. King Salmon is coastal/`requiresBoat=true`; implementation enforcement → Step 11.

### The cross-tier difficulty rigor — discharged honestly

**The headline headless deliverable.** Step 4 owed the T2→T4 difficulty check (SYS_combat build notes:
Alaska clears on T4 gear; caribou/moose milestone soloable, grizzly apex co-op). It was owed here because
the check needs the KillWindow inputs and higher-tier rosters — both now present.

**Why strict `derived == authored` is unachievable cross-tier (and why the Bayou was fine).**
`Combat.deriveMinTiers` computes the *physical minimum* gear that satisfies the kill inequality
(`ShotsToKill ≤ KillWindow / CycleTime`). The catalog authors the *design role-anchor*: floor creature at
T−1, mid creature at T, apex at T+1 (SYS_progression §5 / SYS_combat §3). At the Bayou (all T1) these
happen to coincide — the derivation yields T1 and the authored minimum is T1 — so the Bayou's strict
equality holds. Cross-tier they diverge: a mid-tier T3 creature might derive T2 (the physical minimum is
T2 but the design says it should feel like T3-territory). For fishing there is no input analogous to
KillWindow — there is no fight-time-to-catch formula input that would let the derivation cross-tier-assert.
The strict equality is a Bayou-tier-1 coincidence, not a universal law. **User-confirmed decision** (Step
10): replace the strict assertion with the spec's floor/ceiling SEMANTICS.

**The four assertions that replaced it:**
1. **Sufficiency** — every non-ambiance, non-rare target is killable/landable by a player at its authored
   minimum gear tier (the inequality strictly holds at the authored tier).
2. **Role band** — every authored minimum tier falls in `[T−1, T+1]` where T is the destination tier
   (floor creature at most T−1, apex at most T+1 — the progression §5 promise).
3. **Co-op-only WALL** — an apex creature with `minWeaponTier > 4` (or fishing `max(rod,reel) > 4`) is
   provably not soloable at the max MVL tier (T4 at launch); it requires a party — the incentive, not a
   hard gameplay lock.
4. **Co-op-soluble** — the co-op-only apex IS conquerable by a `partyCap`-size party using the real
   `coopEffectiveHealth` / `coopNetDrain` math. (Grizzly Bear and Giant Halibut pass; neither is a
   stationary wall, just a party puzzle.)
The **Bayou keeps strict `derived == authored`** (it held at T1 and is unchanged).

**Two derivation defects fixed to make the model match SYS_combat §3 worked examples:**
1. **Survival window** — was `hitsToDown · interval`, now `(hitsToDown − 1) · interval`. SYS_combat §3
   defines the escape window as the time between the first attack and the killing blow (the creature has
   landed `hitsToDown−1` hits when the window expires on the last hit). The old formula over-counted by
   one interval, making every survival-bounded creature appear *easier* to solo than the spec intended.
2. **Apex co-op offset** — apex creatures (marker `coop == "party"`) receive a "behaves-as-T+1" DR
   offset (SYS_combat §4: an apex creature's damage reduction is computed as if it is one tier above the
   attacker's, beyond the normal DR formula). Without this offset the grizzly derives as T4-soloable
   (matching the wrong answer). With both fixes the derivation reproduces every SYS_combat §3 worked
   soloability example: boar soloable at T2; cougar not soloable at T2 but soloable at T3; grizzly not
   soloable at T4 but co-op-soluble.

**The two stat defects the rigor caught and fixed:**
1. **`appalachia_northern_pike` `minRodTier` 2→3.** At T2 rod (entry rig), `LandWindow ≈ 5.2 s` vs
   `FightTime ≈ 20.4 s` — the fish snaps. LOC_02 §3 itself says "comfortably a T3 rod target." The pike
   is rod-bound; `minReelTier` stays 2 (the reel is not the bottleneck).
2. **`alaska_giant_halibut` `typicalWeightKg.max` 180→80.** The Step-5
   `representativeWeight = typicalWeightKg.max` rule made the authored 180 a hard wall even co-op:
   `FightTime 38.55 > LandWindow 37.2` — no party could land it. 80 kg matches EQUIPMENT_MASTER §4.4's
   worked stamina example (441 j); at 80 kg a solo player throws (FightTime 45.6 > LandWindow 37.2) but
   a `partyCap` party lands it (FightTime 18.3 ≤ LandWindow 37.2) — correctly co-op-soluble.
   `recordWeightKg = 230` and `minReelTier = 5` are intact (the stat block's rare-record and reel
   requirement are unaffected).

**The co-op-only-apex / soloable-milestone split:**
- **Bull Moose** (hunting milestone, Appalachia) and **King Salmon** (fishing milestone, Alaska): T4-
  soloable. A solo player can always conquer Appalachia and Alaska — this is the intended progression.
- **Grizzly Bear** (hunting apex, Alaska) and **Giant Halibut** (fishing apex, Alaska): CO-OP-ONLY (need T5
  gear that does not exist at MVL → a party is required). These are the party-incentive creatures, never a
  gate (you can clear Alaska solo; the apex is a bonus challenge).
- The co-op marker is tier-keyed (`minWeaponTier > 4` / `max(rod,reel) > 4`) — not a hardcoded id list.

**Economy reconciliation stays green:** `routineHourSum` for Appalachia = 1700 and Alaska = 4913 (both
loops) hold in the Economy spec at 892 assertions.

**Headless-proven (the complete list):**
- All four cross-tier assertions pass for every non-ambiance, non-rare Appalachia/Alaska species.
- The two derivation defect fixes reproduce SYS_combat §3 worked examples exactly.
- The pike and halibut stat corrections make their inequalities satisfy sufficiency.
- `Spawner.validatePlacement` covers all new non-ambiance targets (structured `spawnZones` present).
- Re-skin behavior-template-reuse check passes for all Step-10 re-skins (Spirit Moose ≡ passive find).
- The Bayou strict `derived==authored` is unchanged and green.
- Economy reconciliation: `Income(2)=1700` / `Income(4)=4913` both loops, both new destinations.
- Steps 1–9 tests are entirely unchanged (892 total assertions, 0 failed).

**Studio / telemetry — NOT headless (all unchecked):**
- [ ] Both Appalachia and Alaska worlds **render within mobile budget** (the geometry is built additively
      from the LOC shells at spatial offsets; frame rate on a mid phone is the bar).
- [ ] **Fast-travel executes** to the right arrival anchor (`ArrivalService.resolveDestinationArrival`
      with the within-place `PivotTo` path) — this closes the Step-9 `TODO(step-10)` for execution beyond
      Lodge/Bayou; verify the character lands at the correct landmark, not the Bayou.
- [ ] **Alaska interior vs coastal read as distinct areas** — the coastal sub-zone (King Salmon, Giant
      Halibut) is visually walled off (Step 11 enforces the Boat gate; here only the data marker exists).
- [ ] The **co-op apex is fightable by a party and visibly infeasible solo** — the Grizzly and Halibut
      should feel appropriately intimidating without being a confusing hard block.
- [ ] **Telemetry hooks populate:** fast-travel usage is wired; per-destination time-to-conquer, co-op-apex
      attempt/success rate, the T2→T4 drop-off funnel, and per-destination income-vs-band are `TODO`'d in
      the code (they need conquest/co-op events not yet fired in Studio).

**Deferrals from Step 10 (named, not silently baked):**
- **Boat item + coastal sub-area enforcement** (Boat-gating the King Salmon + Giant Halibut zones) → **Step 11**.
- **Dogs** (Pointer for Appalachia upland, Husky for Alaska — LOC §6.2) → **Step 11** (priced by the
  economy curve; the Kennel fixture is placed in the Lodge).
- **Rockies (T3 destination)** → **post-launch** (the gate DAG already includes it; the LOC/roster are
  future content).
- **Full multi-world spawner gameplay generalization** (cross-place TeleportService, concurrent-world
  spawner lifecycle, server-list-aware pop management) → **iterative Studio work**.
- **Conquest/co-op telemetry events** (per-destination time-to-conquer, apex attempt/success) → **Studio
  iteration** (the hooks are `TODO`'d; the economy/playtime data shape the events).

## Step 9 — World Map, fast-travel & gating (the bar is split, honestly)

Two properties a wrong build violates: **the unlocked set is persisted truth (not a live derivation)** —
`commitUnlocks` only ever *adds* (the one-time threshold crossing); a Destination stays unlocked after the
qualifying gear is sold (`evaluateGate` gates *entry into the set*, never continued membership) — and
**fast-travel cannot bypass the gate** — `DestinationService.travelTo` validates the target against the
**persisted** `unlockedDestinations` set, not a live gate eval. Step 9 **calls** `Gate.evaluateGate`,
`EffectiveTier`, the teleport scaffold, and the persisted sets — it rebuilds none of them.

**Headless-proven:**
- **`commitUnlocks`** (`src/logic/Progression.luau`) re-evaluates every gate in **one pass** and adds each
  newly-unlocked Destination to the persisted set: idempotent (a second pass adds nothing); **survives a gear
  sale** (unlock, then unequip → still unlocked); requires **both halves** (conquest alone or gear alone does
  not unlock); one pass unlocks the whole conquered chain (no cascade — the gate checks `prerequisite
  Destinations ⊆ conquered`, a stable player action).
- **Wired into its real triggers, atomically**: `FireHandler`/`CatchHandler` commits gated on
  `result.conquestNewlySet` (a forced save failure reverts the conquest **and** the unlock — no orphan); the
  **equip** handler (the action that actually changes EHT/EFT — see the placement note); and the
  login/Travel-Desk `openWorldMap` catch-all.
- **Gated fast-travel enforcement**: `travelTo` returns `{ ok, reason?, teleportTarget? }` — an unlocked
  target resolves its `teleportTarget`; a locked target is rejected server-side; the guard reads the
  **set** (a gate-qualified-but-uncommitted player still can't travel; an in-set-but-now-under-geared player
  still can — persisted truth).
- **Surface data**: `worldMapPins` returns `{ unlocked, conquered, unmetReasons }` per Destination — `unlocked`
  from the **persisted set** (a sold-gear Destination reads unlocked), `unmetReasons` the actionable-noun
  strings for locked pins; `passportCounts` derives the readout from the sets. Both are exposed in the
  read-only projection (`worldMap` / `passport`).
- **The Rockies re-thread** is data-driven: `Gate.spec` proves it at the `evaluateGate` level; `Progression.spec`
  proves the **`commitUnlocks`** re-evaluates a synthetic re-pointed DAG with **no code change**.
- **The onboarding `WORLD_MAP` beat is now real** — opening the map (`openWorldMap`) completes it (was a
  pass-through); the funnel-to-COMPLETE chain gained a `worldMapOpen` step (the affected specs updated).
- `requiredAccessItems` added to the `Gate` (optional; the entry-gate half of `evaluateGate`) for the future
  water-locked Destination; the MVL omits it.
- Steps 1–8 tests stay green (the conquest/equip commits now carry the unlock-commit through their existing
  atomic/dirty-flag paths).

**Studio / telemetry — NOT headless (all unchecked):**
- [ ] The **World Map** renders at the Travel Desk: lit pins for unlocked, glowing-locked pins showing their
      `unmetReasons`, higher-tier pins visible from session one — no tier number shown.
- [ ] **Fast-travel** executes (`TeleportService` place/spawn) for the real targets (Lodge ⇄ Bayou) on mobile.
- [ ] The **Passport readout** in the Lodge reads as the felt progression number ("N of M unlocked").
- [ ] The onboarding `WORLD_MAP` reveal lands as the aspiration beat in the funnel.
- [ ] Telemetry populates: per-tier time-to-unlock, **gate drop-off split gear-vs-milestone** (the single
      most useful progression chart), EHT/EFT distribution, dual-loop split, fast-travel usage.

**Placement note (codebase-grounded, flagged):** the prompt says hook the gear-change unlock into
`ShopHandler`, but in this codebase **buy mints an *unequipped* commodity and upgrade is intra-tier** —
neither changes EHT — so the gear-half-newly-met trigger is in **`EquipHandler`** (the action that changes
EHT/EFT), plus the login/Travel-Desk catch-all. A `ShopHandler` hook would be dead code. *Atomicity
nuance:* the conquest hook (Fire/Catch) is write-through-atomic (inside the `critical` Transaction — a
failed save reverts conquest + unlock together); the **equip** hook rides equip's non-critical dirty-flag
(equip + unlock commit together in-memory and persist on the same autosave) — safe here because
`commitUnlocks` is idempotent and the login/`openWorldMap` catch-alls re-converge it. If a future EHT-gated
unlock ever became crash-window-exploitable, revisit whether `equip` should be `critical`.

**`Gate` prerequisite-model note:** the code checks `prerequisiteDestinations ⊆ conquered` (collapsing the
spec's `milestone_prerequisite` (conquered) and `prerequisite_destinations` (unlocked) into one) — fine for
the MVL + Rockies (a conquered milestone chain); the **unlocked-but-not-conquered** prerequisite is
unimplemented, flagged for a future Destination that needs it.

**Deferrals (named with their owning step):** the Appalachia/Alaska worlds behind the gates → **Step 10**;
Boats + the sub-area Boat-gate enforcement (Alaska coastal fishing) → **Step 11** (Boats) / **Step 10**
(sub-areas) — `requiredAccessItems` here is the *entry-gate* half only; **Hunter/Angler Rank perks** (the
registry + thresholds + cap/prestige) → **deferred** (rank XP already accrues; if ever surfaced, the registry
must be category-validated identity|convenience — power is a schema error); the `TeleportService` execution
beyond Lodge/Bayou → **Step 10**; the MVL T2→T4 combat-difficulty check → **Step 10**.

## Deferred — who owns what

| Deferred | Owning step |
|---|---|
| Finished art (cypress models, water shader, textures, sound) — the shell is placeholder blockout | Phase-3 art pass |
| **Boats** + water-type→Boat-access enforcement (Bayou is shore-accessible — none built); the coastal sub-area gate | Step 11 |
| **Premium bait** (paid `TimeToBite` accelerator — stub here, asserts rare-spawn takes no bait); the **bait shop + starter-bait grant** (so "buy bait → catch" is end-to-end) | Steps 14 / 6-7 |
| The funnel first-spawn / first-bite guarantee (bypasses caps for a first-time player) + funnel state machine; returning-player→Lodge respawn | Steps 7/8 |
| ~~The real **`Payout`** formula + the idle amount + gear sinks~~ — **DONE (Step 6)**; remaining: the **shop UI** (Studio) + the **Cash revive-in-place price** (a minor sink, not yet wired) | Studio / later |
| The **rewarded-ad revive** | Step 14 |
| **Ambush** archetype (RD-C) + **projectile** weapon classes (bows/shotguns, RD-D) | post-MVL |
| ~~MVL **T2→T4 difficulty check**~~ — **DONE (Step 10)**: cross-tier floor/ceiling semantics (sufficiency + role band + co-op-wall + co-op-soluble) replace strict `derived==authored` (proven unachievable cross-tier; user-confirmed). Two derivation defects fixed; two stat defects caught and corrected. | ✅ Step 10 |
| ~~**dual-loop reconciliation/drift** check (needs Appalachia/Alaska rosters)~~ — **DONE (Step 6/10)**: `routineHourSum` = `Income(T)` both loops, all destinations (Bayou/Appalachia/Alaska) | ✅ Step 6 + Step 10 |
| Rare-spawn **LiveOps event scheduling** (condition frequency on the calendar; the spawn *mechanism* is built in Step 4) | Step 13 |
| ~~Disposition **flows** (held-then-choose, display, salvage — call the CAS primitive)~~ — **DONE (Step 8)**; remaining: trading's escrow/swap | Step 12 |
| ~~cosmetics & Lodge decor (the evergreen inflation ballast)~~ — **decor catalog + slot/decor Cash sink DONE (Step 8)**; **real-money** decor + the **auto-sell** pass | Step 14 |
| ~~World Map UI, **gated teleport execution + enforcement**~~ — **enforcement + travel flow + surface data + unlock-commit DONE (Step 9)**; ~~the `TeleportService` execution beyond Lodge/Bayou~~ — the headless arrival-resolver seam (`ArrivalService.resolveDestinationArrival`) is **DONE + headless-tested**; the Studio fast-travel **EXECUTION** (within-place `PivotTo`) is written but **playtest-pending / not headless-verified** (see Step 10 Studio checklist); remaining: the map UI | Studio / later |
| **Boat item + coastal sub-area enforcement** (Boat-gating King Salmon / Giant Halibut zones — data marker `requiresBoat` done in Step 10; runtime enforcement not built) | Step 11 |
| **Dogs** (Pointer for Appalachia, Husky for Alaska — LOC §6.2; Kennel fixture placed in Lodge) | Step 11 |
| **Rockies (T3 destination)** — gate DAG already includes it; LOC/roster future content | post-launch |
| Full multi-world spawner gameplay generalization (cross-place TeleportService, concurrent-world spawner lifecycle, server-list-aware pop management) | iterative Studio work |
| Conquest/co-op telemetry events (per-destination time-to-conquer, apex attempt/success, T2→T4 drop-off, income-vs-band) — hooks `TODO`'d; need conquest/co-op events fired in Studio | Studio iteration |
| Trading: negotiation, `PendingTrade` escrow, atomic two-sided swap, ownership transfer, two-sided rollback (call CAS `HELD↔ESCROWED` + Transaction + paired ledger entries) | Step 12 |
| Real-money product wiring (`ProcessReceipt`, currency packs, game passes — call `attemptRealMoneyCredit`) | Step 14 |
| `TODO(open)`: MemoryStore cross-server lock brokering · `TODO(ops)`: `auditLogDestination` choice, point-in-time rollback operation | ops/later |

## Binding-spec reconciliations (judgment calls — flagged, not silently resolved)

1. **Gate fields.** `prerequisiteDestinations ⊆ conqueredDestinations` is the re-threadable DAG edge;
   `milestoneTargets` supply the loop-aware actionable nouns. The **hunting** conquest is now recorded on
   a server-validated kill (Step 4 reward pipeline sets `conqueredDestinations[home]` idempotently); the
   **fishing** conquest (Step 5) sets the **same** flag (the OR-gate — gator *or* Blue Catfish). The gate
   *consumes* the flag — that enforcement is Step 9.
2. **`monetizationRoles` = the four-value Template-B set** (`power-progression` restored as a legitimate
   descriptor; modeled as a set; retagged per EQUIPMENT_MASTER §4). *(Corrects Step 1's narrowing.)*
3. **`destinationId` on Creature/Fish** — the home Destination (catalog keying + milestone home lookup).
4. **Cash ranges on creature/fish rewards are illustrative** — economy computes the authoritative payout (Step 6).
5. **`freshProfile(config)`** derives the starter loadout + starter Destination from data (content-free logic).
6. **`artifactIdScheme` = GUID** (globally unique — artifacts trade across players). **Idle amount** is a
   pluggable Step-6 stub; the corpus leaves "current tier for an offline player" undefined (`TODO(step-6)`).
7. **`sessionOpen` + `lastSaveTimestamp`** added as the §6 idle hard-crash-fallback / reconnect-race
   idempotency mechanism (extend §1's persisted set).
8. **Idle "current tier" = `T_idle = max(EHT, EFT)`** (Step 6). SYS_economy left the offline tier
   undefined; Step 6 resolves it to the player's best effective (gated) tier — idle rewards gear
   investment, stays idle-proof (capped/fractional/floored, never milestone), and uses the min-rule
   effective tier so one high item can't inflate it. **Flagged to ratify** (highest-conquered and
   last-location are viable alternatives). Also (Step 6): routine `Payout` is **normalized per loop** by
   `AvgRoutineMultiplier(dest, loop)` (RD5) so each loop's routine hour sums to `Income(T)` by construction
   — the robust fix vs the flat `Income(T)/rate` baseline, which made dual-loop parity fragile.
9. **Cross-tier min-tier assertion semantics — strict equality unachievable; spec-faithful floor/ceiling
   semantics adopted (Step 10; user-confirmed).** `Combat.deriveMinTiers` computes the *physical minimum*
   gear; the catalog authors the *design role-anchor* (floor=T−1, mid=T, apex=T+1 per SYS_progression §5 /
   SYS_combat §3). These coincide at the Bayou (all T1) but diverge cross-tier. For fishing there is no
   KillWindow-analog from which to derive a tier cross-tier. The resolution: the Bayou keeps strict
   `derived==authored`; Appalachia/Alaska assert the spec's four semantic properties (sufficiency + role
   band + co-op-only wall + co-op-soluble) instead. Two derivation defects fixed (survival-window
   `(hitsToDown−1)·interval`; apex DR offset per SYS_combat §4) to reproduce the §3 worked examples.
10. **King Salmon stays coastal and Boat-gated** (Step 10). The build prompt §D suggested placing King
    Salmon as an interior (non-Boat) species. This contradicts LOC_04 §4 (King Salmon habitat is the
    coastal estuary) and LOC_04 §7 (all estuary fishing requires Boat access). The spec wins: King Salmon
    is marked `requiresBoat=true`; Boat enforcement → Step 11. The prompt §D claim is rejected.
11. **Non-threat fleer `minArmorTier` 1→0** (Step 10). Flee-only species (rabbit, squirrel, Spirit Moose)
    have `coop="none"` and pose no lethal threat. SYS_combat §3 defines `minArmorTier = 0` for non-lethal
    encounters; authoring `1` was a copy-paste error from the template. Corrected to 0 at load; no player
    impact (the non-lethal clamp already prevents damage regardless).
12. **`appalachia_northern_pike` `minRodTier` 2→3** (Step 10). At rod tier 2, `LandWindow ≈ 5.2 s` but
    `FightTime ≈ 20.4 s` — the fish snaps on any T2 rod (EQUIPMENT_MASTER §4.2 entry rig). The authored
    value of 2 violated sufficiency. LOC_02 §3 describes the pike as "comfortably a T3 rod target."
    `minReelTier` stays 2 (the reel is not the bottleneck). The fix restores sufficiency.
13. **`alaska_giant_halibut` `typicalWeightKg.max` 180→80** (Step 10). The Step-5 rule
    `representativeWeight = typicalWeightKg.max` made the authored 180 kg a hard wall even for a partyCap
    party (`FightTime 38.55 > LandWindow 37.2`). 80 kg matches EQUIPMENT_MASTER §4.4's stamina example
    (441 j); at 80 kg a solo player correctly throws (FightTime 45.6 > LandWindow 37.2) and a partyCap
    party lands it (FightTime 18.3 ≤ LandWindow 37.2). `recordWeightKg = 230` and `minReelTier = 5` are
    intact (the record weight and reel requirement are part of the authored design, not the representative
    fight weight).

## Definition of Done — status

**Step 1:** ✅ catalogs, `PlayerData` + `freshProfile` (EHT=EFT=1, Bayou unlocked, balance 0), the pure
functions + tests (MVL gate chain, Rockies DAG insertion zero-logic-change, weakest-slot + empty-armor
boundary, dual-loop OR-gate), failing-validation fixtures.

**Step 2:** ✅ carry-over fixes (monetizationRoles set, stable EquippedRefs round-trip, `LedgerEntry.type`);
✅ session lock (live lock never stolen); ✅ save model (write-through wrapper, retry-then-revert);
✅ ledger (checkpoint+tail, no-yield debit, PurchaseId idempotency, compaction→audit); ✅ gauntlet
(assertion rejected, request runs 6 steps, equip end-to-end, read-only projection); ✅ anti-dupe (mint,
CAS, kind-gating, tombstone); ✅ idle (single clamped entry, no double-claim, under-credit fallback,
idle-proof); ✅ MVL integrity tests (duped-rare lock rejection, multi-mutation no-orphan atomicity, idle
no-double-claim); ✅ honest coverage statement.

**Step 3:** ✅ (headless) named zones + landmark anchors load & self-validate; ambiance placed, targets
absent; the measurable §2.6 layout constraints (walk distance, few-steps bank, faces-levee, co-located
signpost, < 60 s crossing); arrival routing → Bayou. ⌂ (Studio playtest, unchecked above) the placeholder
world, the mobile controller, frame rate, sightlines, and on-foot feel.

**Step 4:** ✅ (headless) prerequisites (`spawnZones` + KillWindow inputs, Nutria); the damage/kill math +
armor `DR` + co-op + the Bayou-wide non-lethal clamp; **min-tier derivation asserted == authored** at load;
spawn caps (anti-low-tier-farming bound + ambiance exclusion) + the rare condition predicate; the shared
atomic reward pipeline (ambiance→0, Reward XOR, weighted Rank XP, idempotent alligator conquest, no-orphan
on save failure); the anti-exploit validators (damage-spoof / fire-rate / range / LOS-decision); the
`fire` handler driving the gauntlet's step-3 hook end-to-end. ⌂ (Studio playtest, unchecked above) **the
game feel — the most important bar of this system** — plus the live shot/raycast and the physical spawner.
Owed at Step 10: the T2→T4 difficulty check (flagged, not faked).

**Step 5:** ✅ (headless) the `spawnZones` prerequisite (Bayou fish → water zones); the catchability math
(`FightTime ≤ LandWindow`, reel/rod curves); **min rod/reel-tier derivation asserted == authored** for the
routine Bayou band (rares excluded, RD5); the shared pipeline **extended** (one Fishing `describe` branch —
routine catch → `catch` ledger + Angler XP; rare → mint + no Cash; atomic, no orphan); the **OR-gate** (one
shared idempotent Bayou conquest flag, both loops, both orders); the bite cap via the **generalized**
single anti-farming line (over-geared bounded near `Income(1)`); drain-spoof / illegal-tension / no-bait /
gear-insufficient rejections; the `catch` handler end-to-end; **the Step-4 hunting tests unchanged**. ⌂
(Studio playtest, unchecked above) **the fight feel — the most important bar** — the tension gauge, the
push-pull rhythm, the physical bite spawner. Owed at Step 10: Alaska milestone + reconciliation/drift.

**Step 6:** ✅ (headless) the economy formulas reading the existing `Tuning.economy` (+ the new salvage
floor); the **three `Payout`/idle stubs replaced** (real `Payout` normalized per loop; idle at
`T_idle=max(EHT,EFT)`); the **dual-loop reconciliation** (each loop's routine hour = `Income(T)`,
Bayou/Appalachia/Alaska) + ceiling slackness + the MVL `2c·g` gear-Cash jump; the **commodity-mint** + the
Outfitter/Tackle-Shop **buy/upgrade** sinks (atomic Cash debit + grant; insufficient-funds reject; intra-
tier never changes EHT/EFT); the gating-price drift check; the starter grant confirmed (already existed).
⌂ (Studio/telemetry, unchecked above) **the shop UI, the felt pacing, and the *live* (measured)
reconciliation** — the modeled per-loop proof is not the live proof.

**Step 7:** ✅ (headless) the data-driven `OnboardingState` machine (server-auth completion on validated
kill/catch/`gearUpgrade`/claim events, **atomic with the reward** inside the handler `Transaction`,
idempotent one-shot, disconnect-resume via the session-locked profile); the scoped `firstSpawnEligible`
predicate (the no-farming-leak guarantee); `isOnboardingComplete` (the real-money gate); ambiance kills
don't advance; the daily skeleton (`Daily` server-time reset + `ClaimDailyHandler` paying
`dailyQuestReward`+`crossLoopBonus` once/day); the deferred economy amounts. ⌂ (Studio/telemetry, unchecked
above) **the felt FTUE, the pacing, the aim-assist taper, and EVERY D1 metric** — and, by its nature,
**this step's success is a telemetry verdict (D1 > 25%), not a green-CI one.** `WORLD_MAP` is a declared
pass-through (Step 9 makes it real).

**Step 8:** ✅ (headless) the count-based `lodge` schema + `Decor` catalog (balance-free, self-validating) +
`Tuning.lodge` + `Economy.slotExpansionPrice` (escalating/uncapped); the **Trophy Hall VIEW**
(`filter(artifacts, DISPLAYED)`, plaque from provenance, slot usage, **no parallel store**, exposed in the
projection); the **salvage** flow (CAS `→ SALVAGED` + `salvageFloor` credit in one `Transaction` — atomic,
idempotent via the precondition, terminal; no orphan on a failed write; `DISPLAYED→SALVAGED` one transition);
**display/take-down** (HELD↔DISPLAYED CAS + slot-capacity gate; non-trophy rejected; no direct trade path);
the **slot/decor Cash sink** (escalating slot + balance-free decor buy/place — atomic, evergreen-tagged,
insufficient-funds no partial); the **Lodge arrival branch** (`isOnboardingComplete` → Lodge, else Bayou).
⌂ (Studio, unchecked above) **the one-server bootstrap (verify exactly one login lock)**, the Lodge interior,
trophy rendering, the "Mount it" prompt, decor placement, and the **flagged** visit/social topology
(own-Lodge MVL only). Step 8 **calls** the §4 CAS / `salvageFloor` / `artifacts` — it rebuilds none of them.

**Step 9:** ✅ (headless) `commitUnlocks` (persisted-truth unlock set — adds-only, idempotent, survives gear
sale, both-halves, one pass) wired into conquest (Fire/Catch on `conquestNewlySet`, atomic no-orphan) + equip
+ the `openWorldMap` catch-all; gated `travelTo` enforcement (validates the persisted set — the gate-bypass
guard, both directions); `worldMapPins`/`passportCounts` surface (persisted-truth pin `unlocked`,
actionable-noun `unmetReasons`) exposed in the projection; the optional `requiredAccessItems` entry-gate half;
the `WORLD_MAP` beat made real (`openWorldMap` completes it; funnel specs updated); the `commitUnlocks`-level
Rockies re-thread (data-only DAG re-point, no code change). ⌂ (Studio, unchecked above) the World-Map UI, the
`TeleportService` execution, the Passport readout, the onboarding reveal feel, and the progression telemetry.
Step 9 **calls** `evaluateGate`/`EffectiveTier`/the teleport scaffold — it rebuilds none of them.

**Step 10:** ✅ (headless) KillWindow inputs (`escapeWindowSeconds`/`attackIntervalSeconds`) added for all
non-ambiance Appalachia/Alaska creatures; structured `spawnZones` on every non-ambiance Appalachia/Alaska
target; Appalachia/Alaska shell zone data + spawn config (LOC §8.4 ceilings/caps); re-skin behavior-template-
reuse check; `Fishing.requiresBoat` coastal/interior marker; **cross-tier difficulty rigor**: the four
floor/ceiling assertions (sufficiency + role band + co-op-only wall + co-op-soluble) replace the Bayou's
strict `derived==authored` (unachievable cross-tier; user-confirmed) — two derivation defects fixed
(`(hitsToDown−1)·interval` survival window; apex DR offset per SYS_combat §4); two stat defects caught and
corrected (pike `minRodTier` 2→3; halibut `typicalWeightKg.max` 180→80); economy reconciliation stays green
for both new destinations (`routineHourSum` = `Income(T)` both loops). ⌂ (Studio, unchecked above) both
worlds render within mobile budget; fast-travel executes to the right anchor (closes `TODO(step-10)`);
Alaska coastal vs interior read distinct; co-op apex fightable-by-party/infeasible-solo; telemetry hooks
populate. Step 10 **calls** the existing KillWindow/Spawner/Shell/Economy machinery — it rebuilds none.

**892 assertions pass headless; both negative fixtures fail analysis as required; `rojo build` produces a
place.** The Studio playtest checklists above are the honest bar for UI/feel/live-data — not headless-green.
```
$ ./run-tests.sh   →   ALL GREEN ✓
```
