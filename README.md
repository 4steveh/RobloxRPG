# Wild World — Build (Steps 1–6)

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
           Creatures (+ Step-4 spawnZones/KillWindow inputs) · Fish · Destinations (gate DAG) · RankPerks ·
           Validation (build-time assertions, incl. Step-4 authored==derived min-tiers) · Catalog (self-validates)
           · Shells (Step 3 — the Bayou shell; self-validates + Step-4 placement check)
           · Spawning (Step 4 — per-(destination,loop) caps + throughput ceiling; loop-agnostic; +Step-5 .fishing)
  logic/   (pure)  EffectiveTier (EHT/EFT) · Gate (evaluateGate) · Balance (checkpoint+tail fold) · Profile
           · Shell (Step 3 — distances/walk-time/crossing-time + shell validators)
           · Combat (Step 4 — weapon/armor curves, shot/kill math, co-op, non-lethal clamp, min-tier derivation, validators)
           · Fishing (Step 5 — reel/rod curves, FightTime ≤ LandWindow, min rod/reel derivation, Angler XP, drain validators, co-op)
           · Economy (Step 6 — Income/GearCost/IntraTierClimb/Payout/salvageFloor + the per-loop routine-band normalization + reconciliation)
           · Spawner (Step 4 — caps/engagement rate, exclusions, rare predicate, placement; GENERALIZED Step 5; +modeledRatePerHour Step 6)
           · Profile (+ Step-6 mintCommodity: the gear-grant primitive the shops + the starter loadout use)
  server/
    ArrivalService.luau   (Step 3) login→Bayou arrival resolver (the gate-less root; returning→Lodge is Step 8)
    combat/
      RewardPipeline.luau   (Step 4) the SHARED ordered atomic reward (loop-agnostic): ambiance→0 · Reward XOR · Rank XP · conquest. Step 5 adds ONE describe branch.
      FireHandler.luau      (Step 4) the "fire" intent handler — the gauntlet's step-3 shot resolution + the reward commit (critical)
    fishing/
      CatchHandler.luau     (Step 5) the "catch" intent handler — the gauntlet's step-3 fight resolution + the (shared) reward commit (critical)
    shop/
      ShopHandler.luau      (Step 6) the Outfitter/Tackle-Shop gear sinks — buy + intra-tier upgrade gauntlet handlers (critical, atomic Cash debit + commodity mint)
    idle/Idle.luau          (+ Step-6 economyAmount: the real idle amount at T_idle = max(EHT, EFT))
    world/BayouBlockout.server.luau    ⌂ STUDIO-ONLY — builds the placeholder shell from Shells config + the arrival flow
    world/HuntingService.server.luau   ⌂ STUDIO-ONLY (Step 4) — physical spawner + fire RemoteEvent + raycast LOS + non-lethal clamp + respawn
    world/FishingService.server.luau   ⌂ STUDIO-ONLY (Step 5) — physical bite spawner + spot-depletion + cast/bite/fight + non-punitive loss
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
    DestinationService.luau  teleport registry + canTravel preview; travelTo is a Step-9 stub
    RobloxAdapters.luau   thin injection-based Roblox adapters (Studio-only binding; strict-clean headless)
tests/   harness + specs (Step 1: Catalog/EffectiveTier/Gate/Balance/Profile/Validation; Step 2:
         ProfileStore/Ledger/ArtifactStore/Gauntlet/Idle/Integrity; Step 3: Shell/Arrival; Step 4:
         Combat/Spawner/RewardPipeline/FireHandler; Step 5: Fishing/CatchHandler; Step 6: Economy/ShopHandler) · negative/ (MUST fail analysis)
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

**Owed, NOT faked — the MVL T2→T4 difficulty check** (SYS_combat build notes: Alaska clears on T4 gear;
caribou/moose milestone soloable, grizzly apex co-op, RD-A) needs Appalachia + Alaska creatures'
survival-bounded inputs and is therefore **owed at Step 10**, not here. The Bayou is the only Destination
that exists; only the **T1 floor bands** are validated (no premature cross-tier checks).

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

**Owed, NOT faked → Step 10:** Alaska's king-salmon milestone + the coastal Boat gate + the halibut apex,
and the dual-loop **reconciliation/drift** check (fishing Cash/hr vs hunting Cash/hr) — they need the
higher-tier rosters and live data. Step 5 provides fishing's *rate*; it does **not** prove balance.

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

## Deferred — who owns what

| Deferred | Owning step |
|---|---|
| Finished art (cypress models, water shader, textures, sound) — the shell is placeholder blockout | Phase-3 art pass |
| **Boats** + water-type→Boat-access enforcement (Bayou is shore-accessible — none built); the coastal sub-area gate | Step 11 |
| **Premium bait** (paid `TimeToBite` accelerator — stub here, asserts rare-spawn takes no bait); the **bait shop + starter-bait grant** (so "buy bait → catch" is end-to-end) | Steps 14 / 6-7 |
| The funnel first-spawn / first-bite guarantee (bypasses caps for a first-time player) + funnel state machine; returning-player→Lodge respawn | Steps 7/8 |
| ~~The real **`Payout`** formula + the idle amount + gear sinks~~ — **DONE (Step 6)**; remaining: the **shop UI** (Studio) + the **Cash revive-in-place price** (a minor sink, not yet wired) | Studio / later |
| The **rewarded-ad revive** | Step 14 |
| **Ambush** archetype (RD-C) + **projectile** weapon classes (bows/shotguns, RD-D); the MVL **T2→T4 difficulty check** + the **dual-loop reconciliation/drift** check (needs Appalachia/Alaska rosters + king-salmon/halibut) | post-MVL / Step 10 |
| Rare-spawn **LiveOps event scheduling** (condition frequency on the calendar; the spawn *mechanism* is built in Step 4) | Step 13 |
| Real-money **currency packs / 2×-VIP multipliers (multiplicative stacking + max-stack ceiling) / auto-sell**; cosmetics & Lodge decor (the evergreen inflation ballast) | Steps 14 / 8 |
| Disposition **flows** (held-then-choose, display, salvage — call the CAS primitive) | Step 8 |
| World Map UI, **gated teleport execution + enforcement** | Step 9 |
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

**493 assertions pass headless; both negative fixtures fail analysis as required; `rojo build` produces a
place.** The Studio playtest checklists above are the honest bar for UI/feel/live-data — not headless-green.
```
$ ./run-tests.sh   →   ALL GREEN ✓
```
