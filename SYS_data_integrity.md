# System: Data Integrity

> The foundation under the foundation. Five locked docs (SYS_progression v2.1, SYS_economy v2.1,
> SYS_combat v1.1, SYS_fishing v1.1, EQUIPMENT_MASTER) each declare integrity *requirements* and
> defer the *guarantees* here. This doc owns the persistence model, the server-authority substrate,
> the Cash ledger structure, the trophy-disposition rule, the anti-dupe layer, idle/AFK integrity,
> and rollback/recovery. It also specifies the integrity *primitives* SYS_trading will build its
> flow on top of (escrow, atomic two-sided swap), without owning the trade flow itself.
>
> **Why it is EXISTENTIAL.** The trade economy is the multi-year moat (00 §5), and the moat is built
> on **real scarcity**. If an item can be duped, or player data can roll back to a state where a
> minted rare exists twice, the scarcity collapses on day one and the moat with it. Equally, a player
> who loses Cash, gear, or a Mythic to a bad save does not return — and retention is the hub
> everything serves (00 §0). Data integrity is therefore not a hygiene layer; it is load-bearing for
> both differentiators (the aspiration spine's progression artifacts and the trade moat's scarcity).
>
> **Scope discipline.** This is a *design* spec, not an implementation. It names where Roblox
> DataStore / MemoryStore semantics materially constrain the design, and specifies the rules and
> invariants Claude Code must satisfy; it does not write the Luau. Template F. Canonical terms (04),
> fixed units.
>
> **v1.1 (review pass).** Closes three integrity seams the first pass left open and tightens several
> definitions. (1) **Rare kills/catches mint an artifact but write NO Cash faucet entry** — Cash is
> realized only on the SALVAGED transition, conforming to SYS_economy RD5 and, more fundamentally,
> protecting the disposition XOR from *value* duplication (a rare that paid Cash at kill *and* stayed a
> tradeable artifact would realize its value twice). (2) **Real-money credits are idempotent on the
> Roblox `PurchaseId`**, keyed into the ledger, closing the receipt-redelivery free-Cash dupe.
> (3) **The artifact taxonomy is discriminated by *tradeability/scarcity*, not object category** —
> gear is a fixed-price commodity (typed-owned), not a unique artifact, per economy's dual-pricing;
> only tradeable/scarce things get unique IDs. Also: ESCROWED is now a full disposition value; the
> reward pipeline commits as one atomic unit; lock-steal is heartbeat-gated; rollback beyond the
> ledger tail reads the audit log. Changes summarized at the end.

---

## Resolved Decisions (binding — do not re-litigate downstream)

These are choices this doc owns. SYS_trading, SYS_lodge_trophy, and the LOC_ docs inherit them as
settled; if a future need forces a change, change it here first and propagate.

1. **Persisted value splits into three classes, discriminated by *tradeability/scarcity* — and only
   one class is the anti-dupe surface.** The discriminator is **not the kind of object** (a "dog" is
   not automatically anything); it is whether the specific item is **tradeable or individually
   scarce**.
   - **Fungible balances** — quantity, not identity. Cash (the ledger, RD2) and stackable consumables
     (basic ammo, bait counts). Tracked as amounts; two units are interchangeable.
   - **Typed-owned commodities** — bought at a fixed Cash price, non-scarce, **non-tradeable**:
     gear (weapon/armor/rod/reel — formula-priced and identical for everyone, economy dual-pricing),
     basic vehicles/dogs/cosmetics. Stored as a **typed entry** (which item you own + its intra-tier
     level + whether equipped), **not** a unique ID. Duping an Iron Rifle gains nothing — you can buy
     one for fixed Cash — so the unique-ID machinery is unnecessary overhead here. Anti-dupe for this
     class is trivial: ownership is a boolean-or-count against a fixed catalog.
   - **Unique artifacts** — every **tradeable or individually-scarce** object: Rare/Legendary/Mythic
     Trophies and record catches, **rare-breed** Tracking Dogs / Mounts / Boats and **tradeable**
     cosmetics (01: "rare breeds can be tradeable"). Each carries a **server-minted globally unique
     `artifactId`**, a single authoritative **owner**, a **disposition** (Trophies), and a
     **provenance** record. **This class — and only this class — is the anti-dupe surface.**
   - **Derived state** — never stored; recomputed from the above (see the storage table in §1).

   Rationale: you cannot dupe what is identity-checked at the schema level, but you also should not pay
   that cost for things that aren't scarce. The economy's "no last-write-wins on a bare int" rule
   generalizes to: *no fungible-count representation for anything scarce* — scarce/tradeable things are
   unique artifacts with IDs; everything else is a commodity count, which is cheaper and equally safe
   because it has no scarcity to protect. **The item/artifact schema therefore needs a `tradeable`
   (equivalently `scarce`) discriminator** that routes an item into the commodity path or the
   unique-artifact path; this doc introduces that requirement (reconcile with EQUIPMENT_MASTER's item
   record and SYS_trading — §open).

2. **Cash is an append-only transaction ledger with a compacted checkpoint, never a mutable int.**
   Balance is *derived* (a fold over entries), never stored as an authoritative number. This is
   inherited verbatim from SYS_economy and is non-negotiable: it is the anti-dupe, audit, and
   rollback-safe spine of the currency. The one implementation concession Roblox forces — a single
   DataStore key cannot hold an unbounded ledger (§7, the 4 MB limit) — is met by a **balance
   checkpoint + bounded recent tail in the live profile, with older entries offloaded to an audit
   log**. The *invariant* (balance = Σ entries, no bare mutable int) holds; only the *storage layout*
   checkpoints. (See §3, §7.)

3. **Every state mutation is server-authoritative, atomic-in-memory, and persisted whole-profile.**
   The client asserts **nothing** — not a balance, a kill, a catch, an item stat, a milestone, an
   elapsed idle time, a disposition, or a trade outcome. It sends *inputs*; the server simulates,
   validates, commits, and replicates. "Atomic" means the check-and-mutate completes in one
   server-side synchronous section **with no intervening yield** before the durable write is enqueued;
   the durable write is **all-or-nothing across the player's integrity-critical state** (one profile,
   not desyncable shards). This is the shared substrate combat/fishing/economy/progression validation
   all sits on. (See §2.)

4. **Disposition transitions and ownership changes are compare-and-swap on expected state.** Every
   transition (mint → held, held ↔ displayed, → salvaged, → escrowed, → new owner) succeeds **only if
   the artifact's current state matches the transition's precondition**, evaluated and applied without
   a yield between. This single primitive makes transitions idempotent and defeats the
   double-spend race (two concurrent requests to dispose/trade the same artifact: the first wins the
   CAS, the second fails its precondition and is rejected). It is the mechanical heart of the
   trophy-disposition rule (§4) and of anti-dupe (§5).

5. **Session-locking is mandatory; one live authoritative session per player.** A player's profile is
   session-locked while loaded. A second concurrent session does not load until the first is confirmed
   released (clean) or dead (lock stolen after timeout). This is THE defense against the
   concurrent-session dupe (two servers each granting/writing the same item). Without it, no other
   anti-dupe rule holds. (See §5, §7.)

---

## Purpose & player-facing goal

Data integrity has almost no *visible* surface — and that is the goal. The player experience it
creates is the **absence** of three catastrophes: your stuff is never silently lost, never silently
duplicated, and never rolled back to a worse state. A player who lands a 1-in-50,000 Mythic must be
able to trust, without ever thinking about it, that the catch is permanent, that it is *theirs alone*,
that nobody can manufacture a second one, and that when they mount it in the Trophy Hall it leaves
their tradeable inventory cleanly and comes back cleanly if they un-mount it. The felt experience is
**trust** — in the permanence of progression artifacts and the scarcity of rares.

That trust is the precondition for the two load-bearing differentiators. The aspiration spine
(Passport progression, conquered Destinations) is only motivating if conquests are durable. The trade
moat (00 §5) is only a moat if scarcity is real, which is only true if items cannot be duped. So while
this system sells nothing and shows nothing, it is the substrate that lets the systems that *do* sell
and show work at all.

---

## How it ties to the formula

- **The trade moat (00 §5).** Scarcity discipline at the design layer (mint rares carefully, never
  re-release) is worthless if the *implementation* layer leaks dupes. This doc is where design-time
  scarcity becomes runtime scarcity. The trophy-disposition rule (§4) and the anti-dupe layer (§5)
  are the moat's structural floor.
- **Retention is the hub (00 §0).** Data loss and rollbacks are top-tier retention killers — a player
  who loses a session's gains, or a hard-won rare, churns and downvotes. Durable saves and rollback
  safety directly protect D1/D7/D30.
- **Sell WITH the player, never against (00 §4).** Server-authority is the enforcement layer for
  every no-pay-to-win promise the other docs make: real-money Cash is just a ledger faucet that hits
  the same milestone wall as earned Cash (§6), entitlements are server-validated (§6), and no client
  claim can convert a purchase into power. The structural guarantees the other docs assert *become
  true* here.
- **Content engine (00 §7).** Because artifacts, ledger entries, and dispositions are data-driven and
  schema-uniform, a new Destination's rares, a new cosmetic line, or a Tier 9+ tier drop inherits the
  integrity layer with no new code — the same droppable-unit discipline the rest of the corpus follows.

---

## Mechanics (detailed)

### 1. The persistence model — what is saved, when, and how

**What is authoritatively stored vs derived-not-stored.** The single most important integrity habit:
derive everything that *can* be derived, because every stored copy of a derivable value is a
stale-state dupe surface (a saved EHT that disagrees with equipped gear; a saved balance that
disagrees with the ledger). Store only what is irreducible.

| State | Stored or derived | Source / note |
|-------|-------------------|---------------|
| **Cash balance** | **Derived** | Fold over the ledger (checkpoint + tail), §3. Never a stored int (economy). |
| **Effective Hunting / Fishing Tier (EHT / EFT)** | **Derived** | `min(weaponTier, armorTierOrFloor)` / `min(rodTier, reelTier)` from *equipped* item tiers (progression). Never stored. |
| **Gate satisfaction ("can I go to X")** | **Derived** | Pure function `evaluateGate(player, destination)` over stored sets + derived tiers (progression). Never stored. |
| **`unlockedDestinations` set** | **Stored** | One-time threshold crossing; permanent once added (progression). |
| **`conqueredDestinations` set** | **Stored** | Idempotent set membership; the milestone/Passport spine (progression). |
| **Hunter / Angler Rank XP** | **Stored** | Two ints; active-play accrual only (progression). |
| **Owned-item inventory** | **Stored** | Fungible counts (ammo/bait) + **typed-owned commodities** (gear, basic vehicles/dogs/cosmetics: catalog id + intra-level + equipped flag) + the **set of owned unique `artifactId`s** (rares, tradeable breeds, tradeable cosmetics, trophies). |
| **Per-item intra-tier level** | **Stored** | Per owned gear item; drives stats, never the gate (equipment). |
| **Equipped-item references** | **Stored** | Which owned items are in weapon/armor/rod/reel slots — the input to derived EHT/EFT. |
| **Trophy artifacts + disposition** | **Stored** | Each unique artifact: `artifactId`, owner, `disposition` enum, provenance (§4). |
| **Logout timestamp** | **Stored** | Server-written at session end; the sole legitimate input to idle accrual (§6). |
| **Active timed entitlements** | **Stored** | e.g. a 2x boost's server-side expiry timestamp; ownership of game passes is read from Roblox MarketplaceService and cached, never trusted from client (§6). |

The persisted profile is therefore small and irreducible: two sets, two ints, an inventory of IDs +
counts, equipped refs, dispositions, a timestamp, entitlement expiries, and the Cash checkpoint+tail.
Everything a player *feels* as progression (their tier, their balance, where they can go) is computed
from it.

**When state is saved — two cadences, one rule.** The rule: **integrity-critical mutations are
write-through (persisted immediately, before the operation is acknowledged as done); everything else
rides a periodic dirty-flag save.**

- **Periodic autosave** (`saveCadenceSeconds`, default 60) — fires only if the profile is dirty.
  Resilience against ordinary crashes; bounds worst-case loss of *non-critical* progress to one
  interval.
- **Write-through critical saves** — on any mutation whose loss or duplication is unacceptable:
  a committed **trade**, any **disposition transition** (mint / display / un-display / salvage), any
  **real-money credit**, any **Destination unlock or conquest**, any **gear purchase**. These cannot
  wait for the next tick — a duped or lost rare, a lost purchase, or a lost conquest is exactly the
  catastrophe this system exists to prevent.
- **On session end** — `PlayerRemoving` and the game-close hook (`BindToClose`) flush a final save and
  release the session lock cleanly, writing the logout timestamp as part of the same whole-profile
  write.

**How state is saved — session-locked, whole-profile, single-writer.** Each player has one
session-locked profile (the established Roblox profile-store idiom; ProfileService / ProfileStore-style
session locking). While loaded on a server, that server is the **single writer**; no other session
can load the profile until the lock is released or stolen after timeout (RD5, §5). Writes are
**whole-profile and atomic** — integrity-critical state is never split across keys that could desync
(a balance in one key and the inventory it paid for in another, persisted independently, is a dupe/loss
seam). The Cash audit-log offload (§3) is the one *deliberately* separate append-only store, and it is
append-only precisely so it cannot desync destructively.

### 2. Server-authority architecture (the client/server boundary)

**The binding rule, stated once for the whole corpus:** the server owns all economy, inventory, and
progression state; **the client asserts nothing.** The client sends *inputs*; the server simulates,
validates, commits, persists, and replicates authoritative state back. This consolidates the
anti-exploit requirements combat (§build notes), fishing (§build notes), economy, and progression each
stated into one coherent layer.

**Inputs the client may send** (the complete category list; the specific contents are the owning docs'):
movement / aim / fire-tap (combat); cast vector+power / hook-set tap / reel-hold state (fishing); and
*UI intents* — "buy item X", "equip Y", "offer trade", "salvage artifact Z", "display artifact W",
"travel to Destination D". Every one is a **request**, not a declaration of outcome.

**What the client may never assert** (rejected on sight, server recomputes from authoritative state):
a Cash balance or delta; a kill or catch ("I killed creature X" is ignored — the kill is a
server-emitted event); a fish identity or rarity; an item stat (damage / drain / DR / Pressure); a
milestone or conquest; an elapsed idle duration; a disposition; a trade result; or ownership of an
entitlement.

**Authoritative state vs replicated state (a Roblox reality worth stating plainly).** The server
replicates a **read-only projection** of relevant state to the client for display (balance, inventory,
gate readouts) via remotes / attributes / a replicated store. That projection is a *shadow*, not the
truth. A client that edits its shadow changes nothing server-side; the next replication overwrites it.
The source of truth is **server memory, backed by the DataStore**. The client may *predict* outcomes
for responsiveness (show the bullet impact, show a provisional balance) but predictions are always
reconciled to server truth and never persisted from the client side.

**The unified validation pipeline.** Every state-changing client request passes through one ordered
gauntlet. Combat and fishing own step 3 for their respective verbs; this doc owns 1, 2, 4, 5, 6 as the
shared substrate every system reuses:

1. **Authenticity** — is this a legal request for this player's live, session-locked session?
2. **Authority** — does authoritative state permit it? (Owns the item? Has the Cash? Meets the gate?
   Artifact in the required precondition state for the requested transition?)
3. **Simulation / validation** — the domain check: combat resolves the shot ray against authoritative
   position/weapon and rejects damage-spoof / fire-rate / geometry-LOS violations; fishing simulates
   bite/hook-set/fight and rejects any Stamina-drain not derivable from the equipped reel. (Owned by
   SYS_combat / SYS_fishing; invoked here.)
4. **Atomic commit** — apply the mutation in memory in one no-yield section: ledger append (with the
   pre-append balance check), and/or artifact CAS transition (§4). When a single validated event drives
   **several** mutations — combat's/fishing's ordered reward pipeline writes a ledger entry, awards Rank
   XP, may mint an artifact, and may set a conquest flag — **the whole pipeline executes as one atomic
   in-memory commit**, then one write-through. A crash cannot split it (Cash without the conquest, or a
   minted artifact without its provenance); either the event resolved wholly or it did not resolve. The
   owning docs define the *order* of the pipeline steps; this doc requires they commit as a *unit*.
5. **Persist** — write-through if the mutation is integrity-critical (§1); else mark dirty.
6. **Replicate** — push the new authoritative projection to the client.

### 3. The Cash ledger

**Structure (inherited from SYS_economy, made precise here).** Cash is an **append-only sequence of
transaction entries**. Each entry:

```
LedgerEntry {
  entryId:           <server-minted unique, monotonic per player>
  type:              <faucet/sink subtype: kill | catch | quest | idle | salvage |
                      event | currencypack | boost-adjusted-credit | gear | intratier |
                      access | cosmetic | decor | premium-consumable | tradepay-in |
                      tradepay-out | tradetax | repair | revive | ...>
  amount:            <signed integer Cash; faucets +, sinks ->
  tier:              <the tier the entry was earned/spent at>
  loop:              <hunting | fishing | none>
  timestamp:         <server time>
  validatingEventId: <the kill/catch/trade/purchase event that authorized it>
  realmoneyTag?:     <set for currency-pack / boost / VIP-attributable faucets>
}
```

**Balance is derived**, never stored as an authoritative int: `balance = Σ entry.amount`. This is the
whole point — there is no mutable number to overwrite, so the classic dupe ("two writes race, the
larger wins") has no target.

**Atomicity guarantee.** A sink (a debit) is committed by: in one server-side synchronous section with
no intervening yield, (a) compute the current derived balance, (b) verify `balance ≥ cost`, (c) append
the negative entry. Because nothing yields between the check and the append, the balance can never go
negative and no concurrent debit can double-spend the same Cash — the per-player session is the
serialization point (one live writer, RD5). The durable write is then enqueued (write-through for
critical sinks like gear/trade, dirty-flag for trivial ones).

**Balance derivation with a checkpoint (the Roblox concession).** A literally-unbounded ledger cannot
live in one DataStore key (§7, the 4 MB limit). So the live profile stores a **balance checkpoint** (a
single signed number representing all *compacted* history) plus a **bounded recent tail** (the last
`ledgerTailLength` entries / `ledgerTailDays` of history). `balance = checkpoint + Σ(tail)`.
Periodically, the oldest tail entries are folded into the checkpoint and **offloaded to an append-only
audit log** (a separate, date-or-player-keyed DataStore, or an external telemetry sink). The
*invariant* the economy mandated is preserved exactly — balance is a fold over entries, there is no
bare mutable int, and the audit trail is append-only and complete — while respecting the key-size
limit. The checkpoint fold is itself a logged, validated operation so it cannot silently alter balance.

**Every faucet and sink is one atomic validated entry.** No Cash moves except as a ledger append
authorized by a `validatingEventId` (a server-validated kill/catch/trade/purchase). This gives, for
free, the exact per-faucet/per-sink flow telemetry the economy's inflation dashboard depends on
(economy §build notes).

**Real-money credits are idempotent on the Roblox `PurchaseId` (closes the receipt-redelivery dupe).**
Roblox's dev-product receipt callback (`ProcessReceipt`) can fire **more than once** for the same
purchase — if the grant is not persisted and acknowledged, Roblox re-delivers it. A naive credit would
mint the currency pack's Cash twice: a **free-money dupe, worse than an item dupe**. The rule: for any
`realmoney_*` faucet, the entry's `validatingEventId` **is** the Roblox `PurchaseId`, and the atomic
append first checks that **no existing entry carries that `PurchaseId`**; if one does, the credit is a
no-op (already granted) and the callback still returns success so Roblox stops re-delivering. The
PurchaseId-uniqueness check is part of the same no-yield critical section as the append. This makes
currency-pack and boost credits exactly-once regardless of redelivery. (The same idempotency-token
pattern as idle, §6, and conquest flags — apply it to every faucet that an external system can replay.)

### 4. The trophy-disposition rule (the scarcity-integrity keystone)

This is where a Mythic *becomes* actually scarce. Economy, fishing, and combat all depend on it.

**One rare spawn yields exactly one artifact.** When combat's or fishing's reward pipeline resolves a
Rare-and-above target (an independent, condition-gated server spawn — never a per-kill/per-cast roll,
per combat RD-E / fishing Decision 3 / economy RD5), the server **mints exactly one artifact** with a
fresh globally-unique `artifactId`, an owner, a `provenance` record (what it was, where, when, the
validating event), and an initial disposition. One spawn → one mint → one ID. There is no path that
produces two artifacts from one spawn.

**A rare mint writes NO Cash faucet entry — Cash is realized only on SALVAGE.** This corrects a seam
between combat's/fishing's reward pipeline ("compute Cash via the Payout formula and write a ledger
entry" on *every* validated kill/catch) and economy RD5 ("Legendary/Mythic pay their scaled Cash
*only as NPC salvage*"). Taken literally, the pipeline would, for a rare, write faucet Cash *and* mint
a tradeable artifact — realizing the rare's value **twice** (once as banked Cash, once as a sellable
object). That is not just faucet pollution (economy §9 keeps rares out of the Cash supply); it is a
**value dupe that breaks the disposition XOR at its root**. The rule, binding on both reward pipelines:
for a Rare-and-above target the pipeline's Cash step is **skipped at kill/catch time**; the only Cash a
rare ever produces is the (deliberately low) salvage floor credited on the `→ SALVAGED` transition.
Routine (Common/Uncommon) targets pay Cash normally at resolution; rares pay Cash only if and when the
player chooses salvage over display or trade. The disposition is thus the **single point at which a
rare's value is realized**, in exactly one of three mutually-exclusive ways — which is the whole point
of the rule.

**Disposition is a single enum, and it is mutually exclusive.** Every unique Trophy artifact is, at any
instant, in exactly one disposition value (ESCROWED is a full value, not a side-flag, so the enum is
the one source of truth and the mutual-exclusivity invariant covers it):

```
disposition ∈ { HELD, DISPLAYED, ESCROWED, SALVAGED }
```

- **HELD** — in the player's tradeable inventory. The default at mint.
- **DISPLAYED** — mounted in the Trophy Hall. **Not in tradeable inventory**, and **not directly
  tradeable** — a displayed artifact must transition DISPLAYED → HELD before it can be escrowed into a
  trade. The status layer (00 §5, 01).
- **ESCROWED** — locked in a pending trade's escrow (§5). Neither freely tradeable elsewhere, nor
  displayable, nor salvageable until the trade commits or cancels.
- **SALVAGED** — vendored to an NPC for the (deliberately low) salvage Cash floor; the **only** time a
  rare credits the Cash faucet. **Terminal**: the artifact is consumed (tombstoned).

**Transitions are atomic compare-and-swap on expected state (RD4).** Each transition succeeds only if
the artifact's current disposition matches the precondition, applied with no intervening yield:

| Transition | Precondition | Effect | Reversible? |
|------------|--------------|--------|-------------|
| mint → HELD | (none) | artifact created, owner set, enters tradeable inventory | n/a |
| HELD → DISPLAYED | HELD | leaves tradeable inventory, occupies a Trophy Hall slot | yes |
| DISPLAYED → HELD | DISPLAYED | leaves Trophy Hall, re-enters tradeable inventory | yes |
| HELD → ESCROWED | HELD | locked into a pending trade; cannot display/salvage/re-offer | yes (cancel) |
| ESCROWED → HELD | ESCROWED | trade cancelled/expired; returns to free inventory | — |
| ESCROWED → (new owner, HELD) | ESCROWED | trade committed; ownership transfers (§5) | no (it's a trade) |
| HELD → SALVAGED | HELD | artifact tombstoned, salvage Cash credited as a ledger entry | **no — terminal** |
| DISPLAYED → SALVAGED | DISPLAYED | (un-display then salvage as one atomic op) | **no — terminal** |

**The invariant, stated plainly:** *a displayed item is not in tradeable inventory, and a tradeable
item is not displayed — never both, never neither-but-still-counted.* A salvaged item is gone. The CAS
precondition is what enforces this against races: two concurrent requests to (say) salvage-and-trade
the same artifact cannot both succeed, because each transition requires the artifact to be in a
specific prior state and the first commit leaves it in a state that fails the second's precondition.

**Non-trophy unique artifacts use the same machinery with a reduced disposition set.** A tradeable
rare-breed Tracking Dog / Mount / Boat or tradeable cosmetic is a unique artifact (ID + owner +
provenance + CAS transitions) but is **not** displayed in the Trophy Hall and **not** NPC-salvaged — it
lives in its own home (Kennel / Stable / Boat slot / wardrobe) and its only dispositions are
**HELD ↔ ESCROWED ↔ ownership-transfer**. DISPLAYED and SALVAGED are Trophy-only. Implementers should
not build "display a dog in the Trophy Hall" or "salvage a boat" paths; the disposition enum's full
range applies to Trophies, the HELD/ESCROWED/transfer subset to everything else tradeable.

**Auto-sell never touches a unique artifact.** The auto-sell game pass (economy §7) pays the same Cash
as manual selling for *fungible routine yield only*; it must **never** auto-salvage a Trophy. A rare's
disposition is always an explicit player action. (If auto-sell could silently salvage a Mythic, it
would convert a convenience purchase into a moat-destroying footgun — flagged to economy/onboarding,
§open.)

**Tombstones, not deletes.** SALVAGED artifacts and traded-away artifacts are **tombstoned** (marked,
not erased) with their provenance, so the audit log and any rollback (§7) can reconstruct exactly what
a player legitimately held at any past time.

### 5. Anti-dupe (across every path)

Generalizing the economy's "no last-write-wins on a bare int" to all artifacts: **scarce things are
unique IDs under a single authoritative owner+state, and every change is a CAS-or-atomic-swap that has
no intermediate observable state in which the item exists twice or zero times.**

- **Unique identity.** Every artifact has a server-minted unique `artifactId` (RD1). Two artifacts
  with the same ID is definitionally impossible. You cannot duplicate what is identity-checked.
- **Single authoritative owner + location.** `(owner, disposition)` is single-valued authoritative
  state; all changes are CAS (§4). There is no representation in which an artifact is owned by two
  players or in two dispositions.
- **Trade.** Resolved by the **atomic two-sided swap** primitive (below): the item leaves A's
  inventory *as* it enters B's, in one committed transaction; there is no instant at which it is in
  both or neither.
- **Disposition transitions.** CAS preconditions (§4) defeat the display/salvage/trade race.
- **Disconnect / reconnect.** The session lock plus all-or-nothing whole-profile persistence means a
  disconnect mid-mutation cannot leave a half-applied dupe: the in-memory mutation is atomic, and the
  durable write either landed wholly (write-through critical events) or did not. On reconnect the
  player loads the last durably-persisted profile, which reflects only committed transactions.
- **Concurrent sessions.** **Session-locking (RD5)** is the defense. One live authoritative session
  per player; a second login does not load the profile until the first is confirmed released (clean)
  or its lock is stolen after `sessionLockTimeoutSeconds` (dead-server case). Without this, two servers
  could each hold the player, each grant the same item, and each write — the canonical Roblox dupe.
  This is the single most important anti-dupe primitive after unique IDs.
- **Rollback.** See §7. The hard case is **trades inside the rollback window**: a naive per-player
  rollback that returns A's traded-away item without also reversing B creates a dupe. Because every
  trade is logged as a two-sided atomic record carrying both party IDs and both artifact IDs (below),
  a rollback can reverse both sides transactionally — and the policy (§7) requires it to.

**The trading primitives this doc owns (foundations SYS_trading inherits).** SYS_trading builds the
negotiation/UX flow; it sits on these primitives, which are specified *here*:

- **Escrow.** A server-held `PendingTrade` record locking each side's offered artifacts (each
  transitioned HELD → ESCROWED) and the Cash payment leg. Escrowed artifacts cannot be displayed,
  salvaged, or offered in a second trade. Escrow is **time-bounded** (`escrowTimeoutSeconds`) and
  **auto-reverts** on timeout or disconnect (each artifact ESCROWED → HELD, Cash unlocked) — no item
  lost, none duped.
- **Atomic two-sided swap.** Commit is **all-or-nothing**: A's offered artifacts → B (ownership CAS),
  B's offered artifacts → A, and the Cash leg moves as **paired ledger entries** (debit payer, credit
  payee) net of trade tax (a `tradetax` sink entry), all in one atomic server operation. Either every
  transfer commits or none does. **The no-item-leaves-one-inventory-until-it-enters-the-other rule**:
  there is no observable intermediate state; the swap is a single committed transition.
- **Cash only as the escrowed payment leg (economy RD3).** Raw Cash cannot be sent player-to-player;
  it moves *solely* as the priced leg of an item swap, as the paired ledger entries inside the atomic
  commit. This is the integrity primitive that makes "a rare purchase is a P2P *transfer*, not a mint"
  true (economy §7/§9) and closes the RMT/laundering vector.
- **Two-sided rollback record.** The committed trade is logged with both party IDs and both artifact
  IDs so a rollback (§7) can reverse both sides.

### 6. Idle / AFK integrity

Inherited from SYS_economy and made mechanically precise: **idle Cash is computed server-side from the
stored logout timestamp, clamped to `idleCapHours`, and credited as a single tagged ledger entry at
next authenticated login — never from client-reported elapsed time.**

- **The only legitimate input** is the **server-written logout timestamp** (§1), recorded at session
  end as part of the final whole-profile write. The client never reports how long it was away.
- **At next authenticated login**, the server computes `elapsed = now − logoutTimestamp`, clamps to
  `idleCapHours`, and credits **one `idle`-tagged ledger entry** (the amount per economy's formula —
  `idleFraction` of current-tier active income × clamped hours; the economy owns the formula, this doc
  owns the integrity of its inputs and the single-entry crediting).
- **Idempotency.** The credit is keyed to the logout timestamp it was computed against; crediting
  **consumes/advances** that timestamp (the new login writes a fresh one). A reconnect race or a
  replayed login therefore cannot credit idle twice — the second attempt finds no un-credited interval.
- **Idle-proof progression (economy §7, progression).** An idle entry can fund the *purchasable* (gear)
  half of a gate but can **never** produce a milestone — idle credits Cash only, never Rank XP, never a
  conquest flag. A pure-idle player accumulates Cash and gear but cannot advance the Passport. The
  reward pipelines (combat/fishing) are the *only* writers of Rank XP and conquest flags, and they fire
  only on validated active kills/catches.
- **Hard-crash fallback (safe direction).** If a session died without writing a logout timestamp, fall
  back to the **last-save timestamp**. This *under-credits* (the player loses idle for the unsaved
  tail) rather than over-credits — the safe direction, since over-crediting mints free Cash. (Flagged
  to economy, §open, as an acceptable small loss.)

### 7. Rollback and recovery

The append-only ledger, unique-ID artifacts with provenance, and tombstones are what make recovery
possible. The governing principle: **never overwrite good data with a partial or failed write; prefer
reverting to the last consistent state over persisting corruption.**

- **Failed save.** Retry with backoff (`saveRetryMaxAttempts`, `saveRetryBackoff`). The session lock is
  **not** released as "clean" while a save is unconfirmed. On exhausted retries, the profile-store
  pattern's rule applies: do not commit a partial profile — the player reverts to the last *good* save
  on reload. Losing the last few seconds is acceptable; writing corruption is not.
- **Server crash mid-transaction.** Because an in-memory mutation is atomic (no-yield section) and the
  durable write is whole-profile all-or-nothing, a crash leaves either the fully-applied-and-persisted
  state (write-through critical events) or the prior consistent state — never a half-applied dupe. On
  restart, the player loads the last durable profile.
- **Disconnect mid-trade.** Escrow auto-reverts (§5): each artifact ESCROWED → HELD, Cash unlocked,
  atomically. No item lost, none duped.
- **Disconnect mid-fight.** Clean by construction: the kill/catch never resolved server-side, so no
  reward, no artifact mint, no ledger entry, no conquest flag — there is nothing to roll back (combat
  "lose only the current hunt"; fishing "no catch, just lost time").
- **Point-in-time rollback (the hard case).** When an exploit or a corruption forces rolling a player
  back to time T, the ledger and the artifact provenance/tombstones reconstruct the legitimate state at
  T. **The depth of T matters:** if T falls within the live profile's recent tail (`ledgerTailDays`),
  the reconstruction is in-profile and cheap; if T predates the last checkpoint fold, the entries were
  offloaded, so the rollback must **read the append-only audit log** (§3) to rebuild — which is exactly
  why the audit log is complete and append-only. `ledgerTailDays` therefore sets the boundary between
  cheap in-profile rollback and audit-log-dependent rollback; size it against the realistic
  exploit-detection-to-response window. **And a per-player rollback that ignores trade counterparties
  dupes items** (A's traded-away rare is restored while B keeps the received copy). Binding policy: **any
  committed trade inside the rollback window must be reversed on both sides transactionally**, using the
  two-sided trade record (§5). This is why trades are logged with both party IDs — rollback safety
  requires it. Where reversing both sides is operationally impossible (B already traded it onward), the
  conservative fallback is to roll the affected player back only to **pre-trade**, never to a state that
  creates a second copy. (Operational policy detail flagged, §open.)

---

## Inputs / dependencies

- **00 / 01 / 02 / 04 / 05** — the trade moat's scarcity requirement (00 §5) this doc enforces at
  runtime; retention-as-hub (00 §0) that data loss/rollback threatens; the no-pay-to-win rules (00 §4)
  server-authority enforces; Cash/kg/1–100/rarity units (rarity drives which catches/kills mint
  artifacts); the Gone Hunting solo-economy contrast (05) — our trade moat is the differentiator this
  layer protects.
- **SYS_progression v2.1** — `unlockedDestinations` / `conqueredDestinations` as the only persisted
  progression state; EHT/EFT and gate satisfaction **derived, not stored**; milestone validation
  **server-side and idempotent** (re-killing/re-catching a milestone re-grants nothing — set
  membership); the **pay-proof / carry-proof** property (payment and co-op yield Cash/milestone but the
  gate stays gear+milestone-gated) that this doc's server-authority makes structurally true.
- **SYS_economy v2.1** — Cash **server-authoritative**; the **append-only ledger** (RD2); **atomic
  validated faucet/sink** entries; **idle computed server-side**, clamped, single-entry; **real-money
  multipliers as server-validated, time-bounded entitlements**; the **trophy-disposition rule** the
  economy relies on (§4); **Cash-not-a-tradeable-leg** (economy RD3) realized as the escrowed payment
  primitive (§5).
- **SYS_combat v1.1** — the server **validates every kill** (ray vs authoritative position/weapon;
  reject damage-spoof / fire-rate / geometry-LOS); the server **owns the spawn population** and the
  **spawn-density cap** (an economy-critical invariant this doc treats as authoritative-state the
  client cannot touch); the **ordered reward pipeline** whose Cash-ledger-write and idempotent
  conquest-flag steps are this doc's atomic-commit primitive; rares are **independent condition-gated
  server spawns** that this doc mints as single artifacts.
- **SYS_fishing v1.1** — the server **validates every catch** (simulate bite/hook-set/fight; reject
  Stamina-drain not derivable from the equipped reel); **one bite → one fish → one artifact → one
  disposition**; the **bite-density cap** as server-enforced authoritative state; rares as
  server-spawned condition-gated entities, never per-cast rolls.
- **EQUIPMENT_MASTER** — every item stat **server-authoritative** and **data-driven config** keyed by
  `(itemId, tier, intraLevel)`; the `tierInput: bool` schema field (`false` for bait/mount/dog/boat/
  cosmetic) as the **schema-level guarantee** those items can never enter a Gate; **a cosmetic with
  non-null stats is a build-time schema error** — this doc treats both as build-time assertions in the
  artifact/item schema, not runtime checks.

---

## Outputs / what depends on this

- **SYS_trading** — sits directly on top of this doc's primitives. It inherits **escrow**, the
  **atomic two-sided swap**, the **no-item-leaves-until-it-enters rule**, **Cash-as-payment-leg-only**,
  and the **two-sided trade record** for rollback. It builds the negotiation flow and UX; it must not
  reimplement or weaken any of these primitives. The anti-dupe guarantee is this doc's; the trade
  experience is SYS_trading's.
- **SYS_lodge_trophy** — inherits the **trophy-disposition rule** (§4): displaying a Trophy is a
  HELD → DISPLAYED CAS that removes it from tradeable inventory; un-displaying reverses it. The Trophy
  Hall is a view over DISPLAYED-disposition artifacts owned by the player; it stores no separate
  authoritative copy.
- **SYS_combat / SYS_fishing** — consume the **unified validation pipeline** (§2) and the
  **atomic-commit / artifact-mint** primitives their reward pipelines write through. They define the
  domain validation (step 3); they rely on this doc for steps 1, 2, 4, 5, 6.
- **SYS_economy** — relies on every faucet/sink being an atomic validated ledger entry (for both
  anti-dupe and its inflation telemetry), and on idle/entitlement integrity (§6).
- **All LOC_ docs** — their rares are minted as single artifacts; their spawn-density values populate
  the server-owned, client-untouchable spawn-cap state.
- **SYS_onboarding_funnel** — relies on the free starter loadout and first-payout being
  server-authoritative from session one (no client-asserted starting state).
- **SYS_liveops_calendar** — event spawns and seasonal rares inherit the same single-mint,
  one-disposition integrity; event payouts are budget-capped ledger entries.

**Out of scope (named, deferred):**
- **The trade flow / negotiation UX** → SYS_trading (this doc provides the escrow/atomicity primitives;
  it builds the negotiation).
- **The actual game mechanics** (what a kill/catch *is*) → SYS_combat / SYS_fishing (this doc validates
  them; they define them).
- **Specific Cash values** → SYS_economy (this doc moves Cash atomically; it sets no amounts).
- **Roblox DataStore API implementation details** → noted where semantics constrain the design (§7
  flags), but this is a design spec, not the Luau.

---

## Tuning parameters

- **`saveCadenceSeconds`** *(default 60)* — periodic dirty-flag autosave interval; bounds worst-case
  loss of non-critical progress.
- **`criticalSaveTriggers`** *(config set, not a number)* — the mutations that force a write-through
  save: trade commit, disposition transition, real-money credit, Destination unlock, conquest, gear
  purchase. Extensible as config.
- **`idleCapHours`** *(echo from economy, default 8)* and **`idleFraction`** *(echo, default 0.15)* —
  owned by SYS_economy; listed here because this doc consumes them in the idle-credit mechanism (§6).
- **`ledgerTailLength`** / **`ledgerTailDays`** — how much recent ledger history stays in the live
  profile before folding into the checkpoint and offloading to the audit log (§3); bounds profile size
  against the DataStore key limit.
- **`sessionLockTimeoutSeconds`** + **lock-heartbeat interval** — how long without a heartbeat refresh
  before a stale lock (dead server) may be stolen by a new session (§5, build notes). Too short risks
  stealing a live-but-laggy lock; too long delays legitimate re-login. The steal is gated on heartbeat
  staleness, never elapsed wall-clock alone.
- **`saveRetryMaxAttempts`** / **`saveRetryBackoff`** — failed-save retry policy (§7).
- **`escrowTimeoutSeconds`** — pending-trade auto-cancel window (§5).
- **`artifactIdScheme`** — GUID vs server-monotonic-per-player ID generation for minted artifacts.
- **`auditLogDestination`** — where offloaded ledger history lands (separate DataStore vs external
  telemetry sink); §open.

---

## Claude Code build notes

Concrete about Roblox realities. These are constraints and idioms, not the implementation.

- **Session-locking is the keystone; use the profile-store pattern.** Adopt a ProfileService /
  ProfileStore-style session lock per player (single-writer, lock-on-load, release-on-leave,
  steal-after-timeout). This is the canonical Roblox concurrent-session-dupe defense (§5, RD5) and the
  precondition for every other anti-dupe rule. Do not roll a bespoke locking scheme without a very good
  reason. **The steal must be heartbeat-gated, not pure-timeout:** the holding server periodically
  refreshes the lock's timestamp; a new session may steal only if the lock has gone *stale* (no
  heartbeat past `sessionLockTimeoutSeconds`), never on elapsed wall-clock alone. A pure-timeout steal
  would yank the lock from a live-but-laggy server and produce the very two-writer dupe the lock exists
  to prevent.
- **DataStore limits and throttling shape the cadence.** A DataStore value is capped (~4 MB/key) and
  requests are budgeted/throttled (a per-minute quota that scales with player count). Consequences,
  already baked into the design: (a) keep the profile small and irreducible (§1) — derive, don't store;
  (b) save on a dirty-flag cadence + write-through-only-for-critical, never per-frame; (c) checkpoint
  the ledger and offload old entries (§3) rather than appending forever into one key.
- **Use `UpdateAsync`, not `SetAsync`, for the profile write** — it gives read-modify-write with the
  DataStore's own reconciliation. But understand that **our real concurrency defense is the session
  lock**, not `UpdateAsync`; `UpdateAsync` guards against datastore-level races, the session lock guards
  against two servers holding one player.
- **Authoritative vs replicated, in code.** Server memory (backed by the DataStore) is truth. Replicate
  a **read-only** projection to the client (remotes / attributes / a replicated value store) for
  display only. Never accept a client write to authoritative state; every client message is a *request*
  routed through the validation pipeline (§2).
- **Atomic-in-memory means no yield mid-mutation.** The check-then-mutate for a ledger debit or an
  artifact CAS must not `wait()` / yield on a DataStore call between the check and the apply — do the
  in-memory mutation synchronously, *then* enqueue the durable write. The per-player session is the
  serialization point.
- **Whole-profile, all-or-nothing writes.** Do not split integrity-critical state (balance, inventory,
  dispositions, sets) across independently-persisted keys that can desync. The Cash audit-log offload
  is the one deliberate exception and is append-only precisely so it cannot desync destructively.
- **MemoryStore for cross-server coordination.** Pending-trade brokering across server instances and
  global lock-handoff are MemoryStore's job (fast, ephemeral, cross-server) — not the DataStore.
  Relevant only if trades or features must span servers (§open).
- **Tombstone, never hard-delete** salvaged or traded-away artifacts (§4) — audit and rollback depend
  on reconstructable history.
- **Entitlements come from Roblox, validated server-side.** Game-pass ownership via MarketplaceService;
  dev-product purchases via the `ProcessReceipt` callback, which **must be idempotent on the
  `PurchaseId`** — Roblox re-delivers receipts, so the Cash credit checks the ledger for that PurchaseId
  before appending and returns success either way (§3). Timed boosts (2x) store a **server-time** expiry
  in the profile; never trust a client clock for entitlement duration. Boost expiry is **wall-clock**:
  a 30-minute boost elapses in 30 real minutes whether the player is online or not (logging off does not
  bank boost time), since expiry is an absolute server timestamp, not an accumulated play counter.
- **Build-time schema assertions** (from EQUIPMENT_MASTER): `tierInput=false` for
  bait/mount/dog/boat/cosmetic, and "a cosmetic with non-null stats is a build-time error." Enforce
  these in the item-config loader/validator at build time, not as runtime checks.
- **MVL pre-launch integrity checks:** (1) a duped-rare attempt across two simulated concurrent
  sessions is rejected by the session lock; (2) a kill/catch reward pipeline that crashes mid-commit
  leaves no orphaned artifact and no orphaned ledger entry (atomicity); (3) a trade interrupted by a
  disconnect auto-reverts escrow with both items intact and unduplicated; (4) a forced point-in-time
  rollback that includes a trade reverses both sides without creating a copy; (5) idle credit cannot be
  double-claimed by a reconnect race.

---

## Open questions / flags

- **Full append-only-forever ledger is not literally achievable in one DataStore key (HARD ROBLOX
  FLAG).** The 4 MB key limit forces the checkpoint + bounded-tail + offloaded-audit-log design (§3).
  The invariant (balance derived from entries, no bare int, complete append-only audit) is preserved,
  but confirm the **`auditLogDestination`**: a separate date/player-keyed DataStore is simplest and
  keeps everything in-platform; an external telemetry sink scales better for analytics but adds an
  egress dependency. Decide before wiring the offload.
- **Cross-server trade atomicity is the hardest integrity guarantee on Roblox (HARD ROBLOX FLAG, for
  SYS_trading).** Two players may be on different server instances; an atomic two-sided swap across
  servers requires a shared broker (MemoryStore-backed pending-trade queue) or a dedicated trade-broker
  place. **If MVL trading is same-server-only**, the escrow + atomic-swap primitive is straightforward
  (one writer sees both profiles). SYS_trading must decide trade scope; the primitives in §5 hold
  either way, but the *mechanism* that realizes them differs sharply. Flag this as the first decision
  SYS_trading must make.
- **Rollback-of-traded-items policy is an operational decision, not just a design one.** §7 specifies
  the conservative rule (reverse both sides, or roll back only to pre-trade), but the real-world case
  where an item has been traded onward N times needs an explicit ops policy (how far to cascade, when
  to accept a localized loss vs. a dupe). Set this with whoever owns live-ops/support before launch;
  the two-sided trade record makes it *possible*, but the policy is a judgment call.
- **Auto-sell vs. unique artifacts — confirmed exclusion here; flag to economy/onboarding.** This doc
  rules that auto-sell never auto-salvages a Trophy (§4). Economy's auto-sell game-pass spec and the
  onboarding funnel must reflect that auto-sell applies only to fungible routine yield. Confirm there
  is no design intent for "auto-salvage rares," which would be a moat footgun.
- **Default disposition = HELD on mint — confirm the player UX with SYS_lodge_trophy / SYS_trading.**
  A freshly minted rare enters tradeable inventory and the player then chooses to display or salvage.
  If the intended UX is "auto-prompt to display the content moment immediately," that is a UI beat on
  top of the same primitive (still HELD until the player acts) — confirm the corpus expects
  "held-then-choose," not "auto-display."
- **Routine (non-rare) kill/catch yield: fungible or trackable? (assumed fungible for MVL.)** This doc
  treats routine meat/hide as fungible auto-vendored Cash (no per-unit identity), reserving the
  unique-artifact machinery for **tradeable/scarce** items only (rares, tradeable breeds, tradeable
  cosmetics — RD1). If a LOC_ doc later wants a *tradeable common resource* (e.g. craftable hides as a
  market commodity), that resource must be promoted from fungible count to the unique-artifact path with
  full anti-dupe treatment. Flag for LOC_ docs.
- **The `tradeable`/`scarce` schema discriminator is a new requirement this doc introduces (RD1).**
  EQUIPMENT_MASTER's item record carries no tradeability field today; routing an item into the
  commodity path (typed-owned, no ID) vs. the unique-artifact path (ID, disposition, anti-dupe) needs
  that discriminator. Reconcile with EQUIPMENT_MASTER (add the field to the item schema) and SYS_trading
  (which consumes it to decide what may be offered). Until set, the safe default for anything *possibly*
  tradeable is the unique-artifact path. Confirm specifically which vehicles/dogs/cosmetics are
  tradeable (rare breeds yes, per 01; basic catalog items presumably no).
- **Idle's "current tier" basis is underspecified across the two loops (flag to economy, §6).** Economy
  prices idle as a fraction of "current-tier active income," but with the OR-gate a player has two
  effective tiers (EHT, EFT) that can differ widely (e.g. EHT 4 / EFT 1). The idle credit needs a
  defined basis — `max(EHT, EFT)`, the highest *conquered* Destination tier, or a blend. This is
  economy's formula call; flagged here because this doc computes the credit from stored state at login
  and needs the basis pinned. (All candidate bases are derivable from stored state, so integrity is
  unaffected; only the amount is in question.)
- **Idle hard-crash fallback under-credits — confirm acceptable with economy (§6).** When no logout
  timestamp was written, falling back to last-save timestamp loses the unsaved tail's idle (safe
  direction). Confirm economy accepts the small player-facing loss in exchange for never over-minting.
- **Server-time authority for timed entitlements.** A 2x boost's expiry is tracked against server time
  in the profile. Confirm there is no path (UI, reconnect) where a client-reported time could extend a
  boost; the entitlement-validation step (§2, §6) must read server time only.

---

## Changes from v1 (review pass, for the diff)

Three were integrity-correctness fixes (a leak each); the rest are precision.

- **Rare mint writes no Cash faucet entry; Cash realized only on SALVAGE (§4).** v1 left combat's /
  fishing's "compute Cash on every kill/catch" pipeline unreconciled with economy RD5. Taken literally
  it realized a rare's value twice (faucet Cash *and* a tradeable artifact) — a value dupe that broke
  the disposition XOR at its root. Now the rare path skips the kill-time Cash step; salvage is the only
  Cash a rare produces.
- **Real-money credits are idempotent on the Roblox `PurchaseId` (§3, build notes).** v1 noted receipt
  idempotency only as a build-note aside, not wired to the ledger. Roblox re-delivers receipts, so an
  unkeyed credit dupes currency-pack Cash — a free-money dupe. Now the PurchaseId *is* the
  `validatingEventId` and the atomic append rejects a duplicate PurchaseId.
- **Taxonomy discriminated by tradeability/scarcity, not object category (RD1, §1 table, §open).** v1
  lumped gear and basic vehicles/dogs/cosmetics into "unique artifacts," over-engineering the common
  case and contradicting economy's dual-pricing (gear is a fixed-price commodity, not traded). Now:
  fungible balances / typed-owned commodities / unique artifacts, with a new `tradeable`/`scarce` schema
  discriminator flagged for reconciliation with EQUIPMENT_MASTER and SYS_trading.
- **ESCROWED is a full disposition enum value (§4),** not a side-flag, so the single-enum
  mutual-exclusivity invariant covers it cleanly.
- **The reward pipeline commits as one atomic unit (§2 step 4)** — ledger + Rank XP + artifact mint +
  conquest flag cannot be split by a crash.
- **DISPLAYED is not directly tradeable (§4)** — must transition to HELD before escrow.
- **Lock-steal is heartbeat-gated, not pure-timeout (§5 build notes, tuning)** — prevents yanking a
  lock from a live-but-laggy server (which would itself cause a two-writer dupe).
- **Rollback depth and the audit log (§7)** — rollback within `ledgerTailDays` is in-profile; deeper
  rollback reads the offloaded append-only audit log. Made the dependency explicit.
- **Boost expiry is wall-clock server-time (§6, build notes)** — offline time counts; logging off does
  not bank boost duration.
- **New flags:** the `tradeable` schema discriminator reconciliation, and idle's underspecified
  "current-tier" basis across the two loops.
