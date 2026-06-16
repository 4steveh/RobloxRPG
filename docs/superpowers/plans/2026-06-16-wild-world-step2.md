# Wild World — Step 2: Data Persistence & Server-Authority Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or
> superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) tracking.

**Goal:** Build the session-locked persistence layer, the server-authority validation gauntlet, the
Cash-ledger store, and the anti-dupe primitives — the substrate every economic system (Steps 6/8/12)
plugs into — **before any Cash or items exist to exploit**.

**Architecture:** Interface-vs-adapter everywhere: every Roblox service (`DataStoreService`,
`MemoryStoreService`, `MarketplaceService`, `Players`, `BindToClose`, the clock, GUID generation) sits
behind a thin interface with an **in-memory fake** (headless-testable) and a **thin Roblox adapter**
(Studio-verified). All persistence/authority *logic* is unit-tested headless against the fakes. Build
the **primitives, not the operations** — Steps 6/8/12 register their domain handlers/flows into what we
build. Substrate vs operations is the dividing line throughout.

**Tech Stack:** strict Luau, the Step 1 toolchain (`luau`/`luau-analyze`/`rojo`, `./run-tests.sh`).

---

## Binding-spec map (every primitive → its SYS_data_integrity section)

| Primitive | Spec | Module |
|---|---|---|
| Session-locked single-writer store, heartbeat-gated steal | RD5, §1, §5, build-notes | `server/persistence/ProfileStore.luau` |
| Dirty-flag autosave + write-through critical + session-end flush + retry/revert | §1, §7 | `ProfileStore` + `SessionService` |
| Cash ledger: checkpoint+tail, no-yield atomic debit, entryId mint, compaction, PurchaseId idempotency | §3 | `server/ledger/Ledger.luau` + `AuditLog.luau` |
| 6-step validation gauntlet (1,2,4,5,6 here; 3 pluggable), request router, read-only projection | §2 | `server/authority/Gauntlet.luau` + `Replication.luau` |
| Artifact mint (unique id + provenance + HELD), CAS disposition transition (kind-gated), tombstone | §4, §5 | `server/artifacts/ArtifactStore.luau` |
| Idle integrity mechanism (clamp, single entry, idempotent, hard-crash fallback, idle-proof); amount stub | §6 | `server/idle/Idle.luau` |
| Atomic multi-mutation transaction (commit-as-unit, revert-on-failed-write) | §2.4, §7 | `server/authority/Transaction.luau` |
| Integrity telemetry | build-notes | `server/Telemetry.luau` (fake) |

### Resolved open questions (flagged, not silently settled)
- **`artifactIdScheme` = GUID** (globally unique — artifacts trade across players, so a monotonic-per-player
  id would collide). Injected `IdGenerator`: deterministic `"art-N"` in tests, `HttpService:GenerateGUID`
  at runtime. `TODO` notes the choice.
- **`auditLogDestination` = separate DataStore** (in-memory fake for tests). `TODO(ops): external sink vs DataStore`.
- **Cross-server lock brokering (MemoryStore)** — DEFERRED. MVL lock is DataStore-based (lock lives in the
  profile key). `TODO(open): MemoryStore cross-server handoff`.
- **Point-in-time rollback OPERATION** — `TODO(ops)`. Step 2 guarantees the *data* it needs (complete
  append-only audit log, artifact provenance, tombstones); the operation is ops tooling.
- **Idle "current tier" + amount formula** — `TODO(step-6 / economy open question)`. The corpus leaves
  "current tier for an offline player" undefined (EHT? EFT? highest reached?); it's an economy decision.
  Step 2 takes the amount from a pluggable `idleAmount(profile, config, hours)` **stub**.

---

## Task 0 — Step 1 carry-over fixes (DO FIRST; #2 is load-bearing for everything below)

**Files:** `src/types/Enums.luau`, `src/types/Schema.luau`, `src/config/Equipment.luau`,
`src/config/Validation.luau`, `src/logic/EffectiveTier.luau`, `src/logic/Balance.luau`,
`src/logic/Profile.luau`, `tests/util.luau`, and the specs referencing changed fields.

1. **`monetizationRole` → four-value Template B set, modeled as a SET of roles.**
   `MonetizationRole = "identity" | "convenience" | "access" | "power-progression"`. EquipmentItem field
   `monetizationRole: MonetizationRole?` → `monetizationRoles: { MonetizationRole }`. Retag per
   EQUIPMENT_MASTER §4: gating weapon = `{power-progression, convenience}`; armor T2 `{power-progression}`,
   T3/T4 `{power-progression, convenience}`; rod/reel `{power-progression}`; boats `{access}`; mounts
   `{convenience}`; dogs `{convenience, identity}`; premium bait/ammo `{convenience}`; basic bait/ammo/tackle
   `{}`; tools/ice-kit `{convenience}` (ice-kit `{convenience, identity}`); cosmetics `{identity}`; free
   starter `{}`. (No-real-money-power is enforced elsewhere: gear is Cash-cost; RankPerkCategory excludes
   `power`; real money never touches milestones — so the descriptor only adds fidelity.)

2. **`EquippedRefs` index → stable `commodityInstanceId`.** `Commodity` gains `instanceId: string`.
   `EquippedRefs` slots become `string?` (the equipped commodity's instanceId). `EffectiveTier.tierOfSlot`
   resolves by instanceId (find commodity, then catalog tier). `freshProfile` mints `ci1`/`ci2`/`ci3` and
   sets `nextCommodityInstanceSeq = 4`. **Test: a load/save round-trip + an inventory mutation (remove a
   different commodity) leaves the equipped weapon still resolving to the same item.**

3. **`LedgerEntry.kind` → `type`.** Rename to match §3.

**Plus the ledger restructure (§3) folded in here since it touches the same types:**
`PlayerData.cashLedger: {LedgerEntry}` → `cash: { checkpoint: {balance, compactedCount, lastEntryId}, tail: {LedgerEntry} }`.
`Balance.balanceOf = cash.checkpoint.balance + Σ cash.tail.amount`.

**New PlayerData integrity-mechanism fields** (documented as §3/§6 mechanism, extending §1's table):
`nextCommodityInstanceSeq` (commodity id source), `lastSaveTimestamp` (idle hard-crash fallback),
`sessionOpen: boolean` (crash detection for idle idempotency), `redeemedPurchaseIds: {[string]: boolean}`
(real-money idempotency tokens). `Artifact` gains `tombstoned: boolean`.

---

## Task 1 — Persistence interfaces + fakes
`server/persistence/Types.luau` (DataStoreLike with `UpdateAsync(key, transform)`, Clock, IdGenerator,
AuditSink, Telemetry interfaces). `server/persistence/Fakes.luau` (InMemoryDataStore with synchronous
no-yield UpdateAsync + injectable failure/throttle; FakeClock with settable `now`; SeqIdGenerator
(`art-N`/`ci-N`); InMemoryAuditLog; InMemoryTelemetry). These make every later task headless-testable.

## Task 2 — ProfileStore (the keystone; test hardest)
`server/persistence/ProfileStore.luau`. Stored value = `{ data: PlayerData?, lock: {serverId, heartbeat}? }`.
- `acquireLock(key, serverId, now)`: UpdateAsync transform — reject if a **fresh** lock held by another
  server (`now - heartbeat < sessionLockTimeoutSeconds`); else acquire/steal (stale or none). Returns
  `{ok, data}`.
- `heartbeat(key, serverId, now)`: refresh `lock.heartbeat` iff we hold it.
- `save(key, serverId, profile, now)`: write `data` iff we still hold the lock (a server that LOST the
  lock must NOT overwrite); refresh heartbeat; injectable failure → retry with backoff
  (`saveRetryMaxAttempts`/`saveRetryBackoff`); on exhaustion return failure (caller reverts; durable value
  unchanged — never persist corruption).
- `releaseLock(key, serverId)`: clear lock iff held.
**Tests:** acquire; second-server rejected while live; **steal only after a missed heartbeat past timeout**;
**a heartbeating (live) lock is NEVER stolen**; a save by a lock-loser is rejected; retry exhaustion leaves
durable value intact.

## Task 3 — Ledger (§3)
`server/ledger/Ledger.luau` + `server/ledger/AuditLog.luau`.
- `balanceOf(cash)` = checkpoint.balance + Σ tail.
- `mintEntryId(cash)` = ++checkpoint.lastEntryId.
- `applyEntry(cash, {type, amount, ...}, now)`: **no-yield** mint id + push to tail (faucet).
- `attemptDebit(cash, cost, meta, now)`: **no-yield** — `balanceOf ≥ cost`? append `-cost` : reject. Never negative.
- `attemptRealMoneyCredit(cash, redeemed, purchaseId, amount, meta, now)`: **no-yield** — if
  `redeemed[purchaseId]` → no-op (already granted); else append (validatingEventId=purchaseId, realMoneyTag)
  and set `redeemed[purchaseId]`. Exactly-once across redelivery.
- `compact(cash, ledgerTailLength, auditSink)`: fold oldest entries into checkpoint.balance, offload to
  audit log, assert `balanceOf` unchanged (logged/validated fold).
**Tests:** balance = checkpoint+tail; debit can't go negative; entryId monotonic; PurchaseId idempotent;
compaction offloads + preserves balance + advances checkpoint; nothing yields between check and append.

## Task 4 — ArtifactStore (§4/§5)
`server/artifacts/ArtifactStore.luau`.
- `mint(profile, {kind, tradeable, provenance, owner}, idGen, now)`: unique id + provenance + disposition
  `HELD` + add to `artifacts` map and `inventory.artifactIds`. One mint → one id.
- `transition(profile, artifactId, expected, to)`: **CAS** — reject if `disposition ≠ expected`; honor
  kind-gating (`Validation.isDispositionLegal`); on `→SALVAGED` tombstone (mark + drop from artifactIds).
- (HELD↔ESCROWED CAS exists as the primitive Step 12's swap will call; the swap FLOW is Step 12.)
**Tests:** mint unique + HELD + provenance; CAS rejects wrong precondition; kind-gating rejects non-trophy
DISPLAYED/SALVAGED; salvage tombstones (artifact marked, leaves artifactIds, stays in artifacts map).

## Task 5 — Gauntlet + Replication + Transaction + the one reference handler (§2)
`server/authority/Transaction.luau`: `run(snapshotFn, mutateFn, saveFn)` — snapshot, apply no-yield
mutation(s) as ONE unit, write-through; on save-failure revert to snapshot (crash cannot split).
`server/authority/Replication.luau`: `buildProjection(profile, config)` → a fresh read-only table
(balance, EHT/EFT, sets, ranks) from Step 1 pure fns; the client gets a shadow it cannot write back.
`server/authority/Gauntlet.luau`: `register(handler)` + `handle(request, session)` running
1 Authenticity → route → 2 Authority → 3 Simulation (pluggable; nil-skip) → 4 Atomic commit → 5 Persist
(write-through if `handler.critical` else dirty) → 6 Replicate. A client **assertion** (no registered
intent, e.g. "setBalance"/"iKilledX") is rejected at routing.
`server/authority/handlers/EquipHandler.luau`: the ONE reference handler — `equip` (payload
`{commodityInstanceId}`): authority = owns the commodity AND its category is a gating slot; commit = set
`equipped[slot]` (slot from category) + maintain commodity.equipped flags; `critical=false` (dirty-flag).
**Tests:** assertion rejected; a request runs all 6 steps; equip works end-to-end and survives a
mutate+round-trip (the stable-key fix); projection is read-only (mutating it leaves the profile untouched).

## Task 6 — Idle mechanism (§6)
`server/idle/Idle.luau`: `creditOnLogin(profile, config, now, idleAmountFn)` — basis = (sessionOpen →
crash → lastSaveTimestamp) | (clean → logoutTimestamp) | (fresh → none); clamp to `idleCapHours`; credit
**one** `idle` entry of `idleAmountFn(...)` (STUB; `TODO(step-6)`); set `sessionOpen=true`; never touch
Rank XP / conquest. `idleAmount` default stub = a fixed test value.
**Tests:** single clamped entry; reconnect-race second call credits ~0 (no double); hard-crash (sessionOpen
true) under-credits vs lastSaveTimestamp; idle writes no XP/conquest; cap honored.

## Task 7 — SessionService (orchestration)
`server/SessionService.luau`: `login(playerId)` = acquireLock → load|freshProfile → idle credit →
sessionOpen=true + lastSaveTimestamp → write-through; reject if locked. `logout(playerId)` = write
logoutTimestamp + sessionOpen=false + lastSaveTimestamp → final whole-profile save → release lock.
`heartbeat`, `markDirty`, `autosaveIfDirty`. Replaces `PersistenceStub.luau`.

## Task 8 — Telemetry + Roblox adapters (thin, Studio-only) + README
`server/Telemetry.luau` (counters: saves ok/fail, lock steals/contention, retry exhaustion, idle credits,
dupe rejections, per-faucet/sink flow). `server/RobloxAdapters.luau` — thin real adapters
(DataStoreService/MemoryStore/MarketplaceService/Players/BindToClose/HttpService GUID), **documented
Studio-only stubs**, not headless-tested. README: module map + **honest coverage** (headless-proven vs
Studio-manual checklist) + the deferred-stub ownership table updated.

## Task 9 — MVL pre-launch integrity tests (the headless subset)
`tests/Integrity.spec.luau`: (1) duped-rare attempt across two SessionService instances rejected by the
lock; (2) a synthetic multi-mutation transaction (mint + ledger entry + conquest) that fails at the
durable write leaves **no orphan** (revert-to-last-good); (3) idle double-claim by reconnect race fails to
double-credit. (Trade auto-revert + two-sided rollback → Step 12.)

---

## Self-review checklist
- Substrate vs operations line sharp: no kill-payout / salvage-effect / trade-flow logic here.
- Interface vs adapter: logic depends on `persistence/Types`, never on `DataStoreService` directly.
- Derive-don't-store still holds (balance/EHT/EFT/gate are functions); new stored fields are integrity
  mechanism only, each documented to its §.
- Every DoD bullet → a passing headless test, OR a listed Studio-manual item (honest coverage — no fake green).
- Heartbeat-gated steal (never pure-timeout); idempotency on idle + PurchaseId; tombstone never delete;
  no-yield commit; whole-profile all-or-nothing.
- Adversarial review (Workflow) against SYS_data_integrity after build.
