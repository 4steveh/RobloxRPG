# Wild World — Build (Steps 1–2)

A Roblox/Luau hunting-and-fishing RPG. This repo holds the design corpus (the `*.md` specs) and the
implementation, built step-by-step per `03_BUILD_PLAN.md` Phase 4. Everything is strict Luau
(`--!strict`), server-side, Rojo-syncable, and **verified headlessly** (no Roblox runtime required for CI).

- **Step 1 — Project Skeleton & Data Model.** Data-driven content catalogs, the canonical player-state
  schema, and the pure derivation logic (EHT/EFT, gate, balance). Shape + pure logic only.
- **Step 2 — Data Persistence & Server-Authority Foundation.** The session-locked persistence layer, the
  server-authority validation gauntlet, the Cash-ledger store, and the anti-dupe primitives — the
  substrate every economic system (Steps 6/8/12) plugs into. **Primitives, not operations.**

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
  config/  Tuning (EQUIPMENT_MASTER §1 set + §-persistence params) · Equipment · Creatures · Fish ·
           Destinations (gate DAG) · RankPerks · Validation (build-time assertions) · Catalog (self-validates on load)
  logic/   (pure)  EffectiveTier (EHT/EFT) · Gate (evaluateGate) · Balance (checkpoint+tail fold) · Profile (freshProfile + newArtifact)
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
         ProfileStore/Ledger/ArtifactStore/Gauntlet/Idle/Integrity) · negative/ (MUST fail analysis)
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

The persistence/authority **logic** is fully unit-tested headless (218 assertions) against in-memory
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

## Deferred — who owns what

| Deferred | Owning step |
|---|---|
| Character controller, movement, world geometry | Step 3 |
| Combat resolution + offensive/armor stat curves (gauntlet step-3 hook) | Step 4 |
| Fishing resolution + rod/reel fight curves (gauntlet step-3 hook) | Step 5 |
| Faucet/sink **operations** (kill/catch payouts, gear-buy debits — call `applyEntry`/`attemptDebit`); shop UI; spawn caps; **the idle amount formula + "current tier for idle" definition**; applying boost multipliers | Step 6 |
| Disposition **flows** (held-then-choose, display, salvage — call the CAS primitive) | Step 8 |
| World Map UI, **gated teleport execution + enforcement** | Step 9 |
| Trading: negotiation, `PendingTrade` escrow, atomic two-sided swap, ownership transfer, two-sided rollback (call CAS `HELD↔ESCROWED` + Transaction + paired ledger entries) | Step 12 |
| Real-money product wiring (`ProcessReceipt`, currency packs, game passes — call `attemptRealMoneyCredit`) | Step 14 |
| `TODO(open)`: MemoryStore cross-server lock brokering · `TODO(ops)`: `auditLogDestination` choice, point-in-time rollback operation | ops/later |

## Binding-spec reconciliations (judgment calls — flagged, not silently resolved)

1. **Gate fields.** `prerequisiteDestinations ⊆ conqueredDestinations` is the re-threadable DAG edge;
   `milestoneTargets` supply the loop-aware actionable nouns. Per-target recorded events are `TODO(step-4/5)`.
2. **`monetizationRoles` = the four-value Template-B set** (`power-progression` restored as a legitimate
   descriptor; modeled as a set; retagged per EQUIPMENT_MASTER §4). *(Corrects Step 1's narrowing.)*
3. **`destinationId` on Creature/Fish** — the home Destination (catalog keying + milestone home lookup).
4. **Cash ranges on creature/fish rewards are illustrative** — economy computes the authoritative payout (Step 6).
5. **`freshProfile(config)`** derives the starter loadout + starter Destination from data (content-free logic).
6. **`artifactIdScheme` = GUID** (globally unique — artifacts trade across players). **Idle amount** is a
   pluggable Step-6 stub; the corpus leaves "current tier for an offline player" undefined (`TODO(step-6)`).
7. **`sessionOpen` + `lastSaveTimestamp`** added as the §6 idle hard-crash-fallback / reconnect-race
   idempotency mechanism (extend §1's persisted set).

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

**218 assertions pass; both negative fixtures fail analysis as required; `rojo build` produces a place.**
```
$ ./run-tests.sh   →   ALL GREEN ✓
```
