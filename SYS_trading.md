# System: Trading

> The player-to-player trade **flow and UX**. This doc owns negotiation, the double-confirm state
> machine, what may be offered, the trade tax application point, anti-scam UX, and trade discovery.
> It **sits on** SYS_data_integrity's trading primitives (escrow, atomic two-sided swap, Cash-as-
> payment-leg-only, the two-sided trade record, CAS disposition transitions, session-locking,
> server-authority) and **never reimplements or weakens them**. Anti-dupe is data_integrity's;
> scam-resistance is this doc's. Cash values and the tax *rate* are economy's; this doc applies them.
> Template F. Canonical terms (04), fixed units.
>
> **Binding scope decision (made, not re-litigated here): MVL trading is SAME-SERVER-ONLY.** Both
> parties occupy one server instance and trade through the Trading Post in the Lodge. One server is
> the single writer, so escrow and the atomic swap are straightforward (one process sees both
> profiles). **Cross-server trading is explicitly post-launch** — noted as a future extension at the
> end, not designed. This resolves the "first decision SYS_trading must make" that data_integrity
> flagged (its §open, cross-server atomicity).

---

## Purpose & player-facing goal

Trading is the system where **people log in to negotiate** (00 §5). Its player-facing job is to make
moving a rare from one player to another feel **safe, deliberate, and satisfying** — a small piece of
theater with real stakes. A player carrying a 1-in-50,000 Mythic must be able to put it on the table,
watch the other side's offer assemble, agree to exact terms, and walk away certain the swap happened
cleanly and exactly as shown — or that nothing happened at all. The felt experience is **confident
negotiation**: you can drive a hard bargain without fear that a mistimed tap or a switched item costs
you the catch.

The system is deliberately **MVL-simple**: a direct, two-person, face-to-face trade brokered in the
Lodge. It is not a marketplace, not an order book, not an auction house — those are scope creep (see
§Open questions and §Out of scope). The depth that matters at launch is the *negotiation and its
safety*, not market automation.

---

## How it ties to the formula

- **The trade moat (00 §5, 05 §3).** Trading is the single biggest separator between a 3-month hit
  and a multi-year franchise. This doc is the surface where the moat is *experienced*. Adopt Me's
  longevity is that the P2P economy IS the product; the negotiation flow here is what makes that true
  for Wild World. Region-specific rare Trophies and record catches as tradeable status items are the
  point — this doc is how they change hands.
- **Scarcity protected, not created.** Scarcity discipline (never re-release rares) is upstream
  (00 §5, 01); runtime scarcity (no dupes) is data_integrity's. This doc protects the moat one way:
  by ensuring **only legitimately-minted unique artifacts can be offered** — every tradeable thing is
  already an `artifactId` with provenance and a single authoritative owner (data_integrity RD1), and
  the offer step can only escrow such an artifact. There is no path here that mints, copies, or
  re-values an item; a trade is a *transfer*.
- **Retention is the hub (00 §0).** A satisfying negotiation loop is itself a return reason
  (log in to check offers, complete a deal, chase the rare you've been hunting on the market). A
  *scam* — or even the fear of one — is a top-tier churn-and-downvote event, so the anti-scam UX
  below is a direct retention investment.
- **Content engine (00 §6).** Trade showcases and rare-drop reveals are creator content. The
  final-terms display and the completed-trade summary are designed to be screenshot-worthy (the deal
  you just landed), feeding the discovery flywheel.
- **Sell WITH the player (00 §4).** Trading sells nothing directly and is never pay-to-win: it moves
  player-minted scarcity between players. The only Cash that moves is earned Cash as the priced leg
  (economy RD3). There is no "pay real money to trade," no trade-slot paywall, no energy gate on
  trading.

---

## Mechanics (detailed)

### 1. Scope and where trading happens

- **Same-server, Lodge-brokered.** Both players are in the same server instance. The trade is opened,
  negotiated, confirmed, and committed through the **Trading Post** interface in the Lodge (04). A
  player out in a Destination cannot trade; trading is a hub activity (this also keeps the Lodge the
  populated social space the design wants — 01, 00 §8).
- **Server-authoritative throughout (data_integrity RD3, §2).** Every step below is a client *intent*
  (`request trade`, `add offer item`, `set offer Cash`, `confirm`, `cancel`); the server owns the
  `PendingTrade` state, validates each intent, and replicates a **read-only** projection of the trade
  to both clients for display. No client asserts the trade's contents or outcome.
- **One active trade per player at a time.** A player who is party to a live `PendingTrade` cannot
  open or accept a second. This is a UX-simplicity rule and a safety rule (it bounds how many of a
  player's artifacts can be ESCROWED at once, and removes a class of cross-trade confusion). Enforced
  server-side as a precondition on `request trade` / `accept request`.

### 2. What may be offered (the offer contents rule)

An offer has two legs: an **item leg** (zero or more unique artifacts) and a **Cash leg** (a
non-negative Cash amount). Each side builds its own offer.

**Item leg — offerable iff the artifact is `tradeable=true` AND currently in HELD disposition.**

- **Offerable:** unique artifacts — Rare/Legendary/Mythic Trophies and record catches, rare-breed
  Tracking Dogs / Mounts / Boats, and tradeable cosmetics — i.e. exactly the items
  EQUIPMENT_MASTER §6.1 marks `tradeable=true` and the artifacts combat/fishing mint. These are the
  only things with an `artifactId`, a single owner, and a disposition (data_integrity RD1, §4).
- **Not offerable (rejected at the `add offer item` intent):**
  - **Commodities / `tradeable=false`** — all standard gear (weapons, armor, rods, reels), basic
    boats/mounts/dogs, basic cosmetics, bait/tackle. These are typed-owned or fungible, have no
    `artifactId`, and are fixed-Cash purchasable; there is nothing to trade and no anti-dupe surface
    (EQUIPMENT_MASTER §6.1, economy dual-pricing). The server has no representation by which they
    *could* be escrowed, so the rejection is structural, not a rule bolted on.
  - **DISPLAYED Trophies** — a Trophy mounted in the Trophy Hall is not in tradeable inventory and is
    **not directly tradeable** (data_integrity §4). To offer it, the player must first **un-display it
    (DISPLAYED → HELD)** via the Lodge/Trophy interface; only then does it become an offerable HELD
    artifact. The Trading Post surfaces this as a clear affordance ("This trophy is on display.
    Un-display to offer it?") rather than silently hiding the item — see §6.
  - **ESCROWED or SALVAGED artifacts** — already locked in another trade, or gone. (One-active-trade
    rule mostly precludes the ESCROWED case; SALVAGED is terminal.)

**Cash leg — Cash only as the escrowed payment leg (economy RD3, data_integrity §5).** A player may
attach a Cash amount to their side of the offer. There is **no raw Cash send**: Cash moves *solely*
as the priced leg of an item swap, locked in escrow and settled inside the atomic commit. A trade
whose item legs are both empty and where only Cash moves one direction is, in effect, a gift-of-Cash
and is **disallowed** — every committed trade must move **at least one unique artifact** (otherwise
the system becomes a raw-Cash-transfer channel by the back door, re-opening the RMT/laundering vector
economy RD3 exists to close). Concretely: the commit precondition requires `|A.items| + |B.items| ≥ 1`.
(A pure cosmetic-artifact-for-Cash purchase is fine; a pure Cash-for-nothing is not.)

### 3. The negotiation flow (state machine)

The trade is a small state machine owned by the server. The **double-confirm** is its safety core:
**both sides must explicitly accept the exact final terms, and any change to either offer re-arms
(clears) both confirmations.** You can never have your confirmation "carried over" onto terms you did
not see.

States of a `PendingTrade`:

| State | Meaning | Both clients see |
|-------|---------|------------------|
| `REQUESTED` | A sent B a trade request; B has not yet accepted. | "Trade request sent / received" |
| `BUILDING` | Both accepted into the trade; either side may add/remove items, set Cash, or clear. **Neither has confirmed, or a change just re-armed.** | Live editable offer panels, both sides |
| `A_CONFIRMED` / `B_CONFIRMED` | Exactly one side has confirmed the current terms; the other has not. | "Waiting on \<other player\>" / "\<player\> confirmed — review and confirm" |
| `BOTH_CONFIRMED → COMMITTING` | Both confirmed the *same* terms snapshot; server invokes the atomic swap. | "Completing trade…" (brief) |
| `COMPLETE` | Atomic swap committed; items and Cash transferred. | Completed-trade summary (§6) |
| `CANCELLED` | Either party cancelled, a timeout fired, or a disconnect occurred; all escrow reverted. | "Trade cancelled" + reason |

**The flow, step by step:**

1. **Initiate** (`REQUESTED`). Player A selects player B at the Trading Post and sends a request.
   B accepts (→ `BUILDING`) or declines (→ `CANCELLED`). A pending request has its own short timeout
   so unaccepted requests don't linger.
2. **Build offers** (`BUILDING`). Each side independently adds offerable artifacts (§2) and sets a
   Cash amount on their own leg. Every add/remove/Cash-change is a validated server intent that
   updates the authoritative offer and re-replicates to both clients. **No artifact is escrowed yet**
   in `BUILDING` — the offer is a *proposed* set; escrow happens at confirm (§4). Both panels show the
   live proposed terms for both sides.
3. **Confirm** (`*_CONFIRMED`). When a player is satisfied, they tap **Confirm**. This is an explicit
   intent against the **current terms snapshot** (a server-computed hash/version of both offers). On
   the first confirm the trade moves to `A_CONFIRMED` or `B_CONFIRMED`; the confirming side's offered
   artifacts transition **HELD → ESCROWED** (data_integrity §4/§5) and their Cash leg is locked, so a
   confirmed offer cannot be quietly drained out from under the other party.
4. **Re-arm on change (the anti-bait-and-switch rule).** If, while one side is confirmed, **either**
   side changes their offer (adds/removes an item or edits Cash) — or the still-unconfirmed side wants
   to renegotiate — the trade returns to `BUILDING`, **both confirmations are cleared**, and any
   artifacts that had been escrowed by a confirm revert **ESCROWED → HELD**. The terms-snapshot
   version increments, so a stale confirm intent (one that names the old version) is rejected. **A
   confirmation only ever applies to the exact terms version it was cast against.**
5. **Both-confirmed → commit** (`COMMITTING`). When the second side confirms the *same* current terms
   version, the server holds the trade at the agreed snapshot and invokes data_integrity's **atomic
   two-sided swap** (§4 below). There is a brief, fixed **settle delay** (`commitSettleSeconds`,
   small) between the second confirm and the swap during which the terms are frozen and shown one last
   time and either party may still hit **Cancel** (which reverts escrow and returns to `CANCELLED`).
   The settle delay closes the "second-confirm was a fat-finger" case without re-arming on every
   keystroke.
6. **Complete** (`COMPLETE`). The swap commits all-or-nothing; both clients show the completed-trade
   summary (§6). The two-sided trade record is written for rollback (§4).

### 4. How the commit invokes data_integrity's atomic swap (the inherited primitive)

This doc does **not** implement the swap; it **invokes** it. At `BOTH_CONFIRMED`, with both sides'
artifacts in ESCROWED and both Cash legs locked, the server calls data_integrity's atomic two-sided
swap (its §5), which performs, in one atomic server operation with no observable intermediate state:

- **A's offered artifacts → B** (ownership CAS, ESCROWED → new owner HELD, per the disposition table,
  data_integrity §4).
- **B's offered artifacts → A** (same).
- **The Cash leg as paired ledger entries:** `tradepay-out` (debit the payer) and `tradepay-in`
  (credit the payee), **net of the trade tax** (§5), all as atomic validated ledger appends
  (data_integrity §3, economy ledger).
- **The two-sided trade record** (both party IDs, both artifact-ID sets, the Cash leg, the tax,
  timestamp) is logged so a rollback can reverse both sides transactionally (data_integrity §5/§7).

**The inherited guarantee, restated so this doc does not weaken it:** *no item leaves one inventory
until it enters the other; either every transfer commits or none does.* If the swap fails its
preconditions for any reason (a CAS mismatch — e.g. one artifact's disposition is no longer ESCROWED
as expected), **the entire commit fails, nothing transfers, and the trade reverts to `CANCELLED`**
with all escrow released. This doc's job is to call the primitive on a correctly-escrowed, agreed
snapshot — never to move items or Cash itself.

### 5. The trade tax (applying the sink — rate owned by economy)

- **The rate is economy's, and it is LOW** (economy Resolved Decision 2). Its job is **anti-wash-
  trading friction**, not inflation ballast (cosmetics/decor carry inflation). This doc does not set
  the rate; it **applies** it as the `tradetax` sink on the Cash leg.
- **Where it is taken:** inside the atomic commit (§4), on the Cash leg only, skimmed from the
  transfer so that **the payer is debited the full agreed Cash (`tradepay-out`), the payee is credited
  the agreed Cash minus tax (`tradepay-in`), and the difference is recorded as a `tradetax` sink
  entry.** Tax therefore scales with Cash moved, which is exactly the friction that discourages
  round-trip wash trading (moving the same Cash back and forth to launder or fake volume costs a
  little each hop). It is taken **once, on commit** — never on building or confirming, so a cancelled
  or re-armed trade costs nothing.
- **It is shown before commit.** The final-terms display (§6) shows the gross Cash, the tax, and the
  **net the payee receives**, so neither party is surprised. Anti-scam (clear terms) and the tax
  application share the same display.
- **Zero-Cash trades pay zero tax** (item-for-item swaps): the sink is a fraction of the Cash leg, so
  an all-items trade has no Cash leg to tax. (Whether that is acceptable, or whether a flat per-trade
  fee should also apply to item-for-item swaps as additional wash-friction, is an economy rate call —
  flagged in §Open questions, not decided here.)

### 6. Anti-scam UX (scam-resistance is this doc's property)

Dupe-resistance is data_integrity's; **scam-resistance is a UX property and lives here.** The
double-confirm flow is the spine; these are the supporting rules:

- **Canonical final-terms display.** Before either side can confirm, and again during the settle
  delay, both players see a **server-rendered** final-terms panel listing each offered artifact by its
  **canonical name + rarity + a provenance/identity cue** (what it is, where/when it was minted — from
  the artifact's provenance record, data_integrity §4), and the **gross Cash, tax, and net**. Item
  labels are **never player-editable free text** — a scammer cannot rename a Common-tier look-alike to
  impersonate a Mythic, because the display comes from the artifact's authoritative record, not from
  anything the counterparty typed. (Look-alike-impersonation is the classic trade scam the
  final-terms display closes.)
- **Re-arm on any change** (§3 step 4) — the structural anti-bait-and-switch. Your confirm can only
  ever apply to the terms you saw; the instant the other side changes anything, your confirm is gone
  and you must look again.
- **Explicit, separate confirms + settle delay.** Confirm is a deliberate tap, not a default or an
  auto-advance; the two confirms are independent; and the short `commitSettleSeconds` freeze with a
  visible "Completing in N…" and a live **Cancel** button gives a last beat to catch a fat-finger
  before commit.
- **Escrow timeout visibility.** The pending trade is time-bounded (`escrowTimeoutSeconds`, echoed
  from data_integrity). A **visible countdown** is shown once items are escrowed. This closes the
  **stall-grief** vector: a party who confirms and then deliberately stalls to lock the other's
  artifact in escrow gains nothing — the timeout auto-reverts both sides (ESCROWED → HELD, Cash
  unlocked, data_integrity §5) and the stalled player's item was never at risk of loss, only briefly
  unavailable, with a clock showing exactly how briefly.
- **Disconnect safety, surfaced.** If either party disconnects at any point, the trade auto-cancels
  and escrow reverts (data_integrity §5, §7 "disconnect mid-trade"). The surviving client is shown a
  clear "Trade cancelled — \<player\> disconnected; your items are returned" message, not an
  ambiguous hang.
- **Un-display friction is a feature, surfaced not hidden.** A DISPLAYED trophy can't be offered until
  un-displayed (§2). The Trading Post shows the trophy with an explicit "on display — un-display to
  offer" affordance. This is a deliberate small speed bump on trading away a wall-mounted trophy
  (a slightly higher-friction, more-considered action than trading a held item), and it keeps the
  Trophy Hall's DISPLAYED set honest.

### 7. Trade discovery (MVL — Trading Post, no marketplace)

- **In-Lodge, same-server, direct.** The Trading Post lists **players currently in this server
  instance** who are available to trade (a player can toggle "open to trade" availability). A player
  selects another and sends a trade request (§3 step 1). MVL discovery is **direct person-to-person**,
  not a listings market.
- **Browse-before-request (read-only).** A player may view another player's **offerable inventory**
  (their HELD `tradeable=true` artifacts) and their **DISPLAYED** Trophy Hall as a read-only showcase,
  so you can see what someone has before opening a trade. This doubles as the social-flex surface
  (00 §8, the Trophy Hall as status) and the content-moment surface (showing off a rare).
- **No auction house / no order book / no automated matching.** Explicitly out of scope for MVL —
  see §Open questions (flagged as the tempting scope creep) and §Out of scope. The MVL bet is that a
  *direct, safe, satisfying* face-to-face trade in a populated hub is enough to seed the moat; market
  automation is a post-launch system that should only be built on top of a proven trade flow and a
  proven anti-dupe substrate.

---

## Inputs / dependencies

- **SYS_data_integrity (the doc this sits on)** — inherited as **binding**, never rebuilt:
  **escrow** (HELD → ESCROWED, time-bounded, auto-revert on timeout/disconnect, §5); the **atomic
  two-sided swap** (§5) and the no-item-leaves-until-it-enters rule; **Cash only as the escrowed
  payment leg** (§5, economy RD3); the **two-sided trade record** for rollback (§5, §7); **CAS
  disposition transitions** and the disposition enum `HELD/DISPLAYED/ESCROWED/SALVAGED` (§4);
  **session-locking** and **server-authority** (RD3, RD5, §2). This doc invokes these; it does not
  reimplement or weaken them.
- **SYS_economy v2.1** — the **low** trade-tax rate (Resolved Decision 2), applied here as the
  `tradetax` sink on the Cash leg; **Cash-not-a-tradeable-leg** (Resolved Decision 3); the
  `tradepay-in` / `tradepay-out` / `tradetax` ledger entry types; the dual-pricing insulation that
  lets the rare market run hot without leaking into gear prices (this doc moves the rares; economy
  keeps gear fixed-Cash).
- **EQUIPMENT_MASTER (§6.1 tradeable patch)** — the `tradeable: bool` discriminator that tells this
  doc **exactly what may be offered**: `tradeable=true` items (rare-breed dogs/mounts/boats, tradeable
  cosmetics) are offerable; `tradeable=false` commodities are not. This doc consumes that field as the
  offer-eligibility check (§2).
- **SYS_lodge_trophy** — owns the Trophy Hall and the DISPLAYED ↔ HELD un-display action that a player
  must take before offering a displayed Trophy (§2); owns the read-only Trophy Hall showcase that the
  Trading Post browse surface reuses (§7). The Trading Post is a Lodge interface (04).
- **SYS_progression v2.1** — referenced for the **tier/rarity of artifacts** shown in final-terms and
  browse displays (progression §"SYS_trading references Passport state and the tier of rares"). Trading
  is not gated by Passport progression in MVL (anyone in the Lodge can trade); flagged in §Open if a
  light gate is wanted to deter throwaway-alt scams.
- **00 / 01 / 02 / 04 / 05** — the trade moat as the multi-year differentiator (00 §5, 05 §3) this flow
  realizes; Cash/kg/1–100/rarity units; canonical terms (Trading Post, Lodge, Trophy, Trophy Hall,
  Cash); the Gone-Hunting "no trade layer = no long tail" failure (05 §2) this system exists to avoid.

---

## Outputs / what depends on this

- **SYS_data_integrity** — consumes this doc's **commit call** (a correctly-escrowed, agreed snapshot
  handed to its atomic swap) and the **two-sided trade record** content this flow assembles; the
  rollback policy (its §7) operates on the records this flow writes.
- **SYS_lodge_trophy** — the Trading Post is a Lodge service; the browse/showcase surface consumes the
  Trophy Hall view. A trade that moves a Trophy updates whose Trophy Hall it can appear in.
- **SYS_economy** — consumes the `tradetax` sink flow and `tradepay-in/out` volumes as the **Trading
  Post Cash velocity + rare price trend** telemetry (economy §telemetry, "the moat canary"); the trade
  tax is one of economy's inflation levers (raise it if rare prices inflate).
- **SYS_liveops_calendar** — trade-volume and rare-price telemetry inform when to ship more evergreen
  sinks or adjust the tax; trade showcases are content moments feeding the LiveOps content flywheel.
- **SYS_onboarding_funnel** — does **not** introduce trading in the first five minutes (a new player
  has no tradeable artifact yet and trading is not a minute-one beat); onboarding should *tease* the
  Trading Post and Trophy Hall as aspiration, not gate the funnel on it. Flagged for that doc.

**Out of scope (named, deferred):**
- **The anti-dupe / escrow / swap MECHANICS** → SYS_data_integrity. This doc **invokes** them; it does
  not build or alter them. If a trade flow requirement here seemed to need a change to a primitive,
  that change is made in data_integrity first and propagated, never patched in locally.
- **Cash values and the trade-tax RATE** → SYS_economy. This doc applies the rate economy sets at the
  `tradetax` sink; it sets no Cash amounts and no rate.
- **Cross-server trading** → post-launch (see §Future extension). Not designed here.
- **Auction house / marketplace / order book / automated matching** → scope creep; explicitly not
  built for MVL (§7, §Open questions). A post-launch consideration only, and only atop a proven flow.

---

## Tuning parameters

- **`escrowTimeoutSeconds`** *(echo from SYS_data_integrity)* — pending-trade auto-cancel / escrow
  auto-revert window. Owned by data_integrity; listed here because the trade UX shows it as the
  visible countdown (§6). Too short interrupts real negotiation; too long lets a staller hold the
  other's item unavailable longer.
- **Trade-tax rate** *(echo from SYS_economy, Resolved Decision 2 — default LOW)* — owned by economy;
  applied here as the `tradetax` sink on the Cash leg (§5). Co-set with live trade-velocity and
  rare-price data.
- **`commitSettleSeconds`** *(default small, e.g. 2–3 s)* — the freeze between the second confirm and
  the atomic swap, during which terms are frozen, shown once more, and either party may still cancel
  (§3 step 5, §6). The fat-finger-on-final-confirm guard. Too long is annoying; zero removes the last
  catch-it beat.
- **`tradeRequestTimeoutSeconds`** *(default short)* — how long an unaccepted `REQUESTED` trade
  request lingers before auto-declining (§3 step 1), so requests don't pile up.
- **`tradeCooldownSeconds`** *(default low or 0 for MVL)* — optional minimum gap between a player's
  consecutive completed trades, an extra anti-wash-trading knob co-owned with economy. Default
  effectively off for MVL (the trade tax is the primary wash-friction); a knob to turn up if telemetry
  shows wash trading.
- **`maxItemsPerOfferSide`** *(default small, e.g. 4–6)* — cap on artifacts per side per trade, a UX
  and escrow-bound simplicity limit (also bounds how many of a player's artifacts are ESCROWED at
  once, reinforcing the one-active-trade rule).
- **`tradeAvailabilityDefault`** *(default: opt-in "open to trade")* — whether players are
  discoverable at the Trading Post by default or must toggle availability (§7).

---

## Claude Code build notes

Concrete about the flow layer; the integrity primitives are data_integrity's to implement.

- **The `PendingTrade` is server-owned authoritative state; clients get a read-only projection.** Hold
  the trade (state, both offers, both confirm flags, the terms-snapshot version) in server memory keyed
  to both party IDs. Replicate a read-only view to both clients (remotes / attributes). Every client
  message — request, accept, add/remove item, set Cash, confirm, cancel — is an **intent** validated
  against the authoritative `PendingTrade`, never a declaration of the trade's contents (data_integrity
  §2). This is the same server-authority substrate; do not let the client author the trade.
- **The double-confirm is a versioned snapshot, not two booleans.** Each confirm intent must carry the
  **terms-snapshot version** it is confirming. The server accepts a confirm only if its version matches
  the current authoritative version; **any offer change increments the version and clears both confirm
  flags** (the re-arm rule, §3 step 4). This makes a stale confirm (cast against terms that have since
  changed) structurally impossible to apply — the version mismatch rejects it. Do **not** implement
  re-arm as "clear a boolean and hope the client re-reads"; bind the confirm to the version.
- **Escrow at confirm, not at offer-build.** Artifacts transition HELD → ESCROWED when their owner
  **confirms** (via data_integrity's CAS), and revert ESCROWED → HELD on re-arm, cancel, timeout, or
  disconnect. Building an offer is a *proposal* over still-HELD artifacts; this keeps a long
  negotiation from needlessly locking items and means a re-arm cheaply releases them. (If a confirmed
  artifact's HELD → ESCROWED CAS fails — e.g. it was un-displayed-then-something-else raced — the
  confirm fails and the trade re-arms; surface it as "that item is no longer available.")
- **Commit = invoke the primitive, don't reimplement it.** At BOTH_CONFIRMED + settle-delay-elapsed,
  call data_integrity's atomic two-sided swap with the agreed snapshot (both ESCROWED artifact sets,
  the Cash leg, the computed tax). The swap is the all-or-nothing transaction; this code path's only
  jobs are (a) assemble the correct snapshot, (b) compute the tax split (`tradepay-out` full,
  `tradepay-in` net, `tradetax` difference), (c) call the primitive, (d) on success show the summary
  and the trade record is written, (e) on failure revert to CANCELLED with all escrow released. Never
  move an item or a Cash entry outside the primitive.
- **Same-server single-writer simplicity (the binding scope decision pays off here).** Because both
  profiles are session-locked on **one** server (data_integrity RD5), the swap has one writer that
  sees both profiles — no MemoryStore broker, no cross-server pending-trade queue. Do **not** build
  cross-server brokering for MVL; it is the explicitly-deferred post-launch path (data_integrity §open
  cross-server flag, resolved here as same-server-only).
- **Offer-eligibility check reads `tradeable` and `disposition`.** The `add offer item` intent
  validates: the artifact is owned by the requester, `tradeable=true` (EQUIPMENT_MASTER §6.1), and
  `disposition == HELD`. Reject otherwise with the specific reason (commodity / on-display /
  unavailable) so the UI can show the right affordance (§6). The `tradeable=false`/no-`artifactId`
  case is structurally un-offerable (no artifact to reference), but validate explicitly for a clean
  error.
- **The "at least one artifact moves" commit precondition** (§2) — enforce `|A.items| + |B.items| ≥ 1`
  at commit so the system can never become a raw-Cash-transfer channel (economy RD3). A pure-Cash
  "offer" is a UI state that can exist during BUILDING but can never be committed.
- **Tax is computed at commit, shown before commit.** Compute `tax = round(taxRate · grossCash)` (or
  per economy's exact formula) at the settle step; render gross/tax/net in the final-terms panel
  (§6); apply it as the three paired ledger entries inside the swap. Taken once, on commit only —
  cancelled/re-armed trades cost nothing.
- **Final-terms rendering is server-sourced, never client-labelled.** Build the final-terms payload
  from each artifact's authoritative record (canonical name, rarity, provenance) — the anti-
  impersonation guarantee (§6) depends on the client being unable to supply or alter the displayed
  identity of an offered item.
- **MVL pre-launch trade-flow checks** (complementing data_integrity's integrity checks): (1) a
  re-arm during one side's confirmed state clears **both** confirms and reverts that side's escrow,
  and a stale-version confirm is rejected; (2) a disconnect at every state (`REQUESTED`, `BUILDING`,
  one-confirmed, settle-delay) auto-cancels with full escrow revert and a clear message; (3) a trade
  that fails its swap precondition (forced CAS mismatch) transfers nothing and reverts cleanly;
  (4) a DISPLAYED trophy cannot be offered until un-displayed; (5) a commodity (`tradeable=false`)
  cannot be added to an offer; (6) a pure-Cash trade cannot be committed; (7) the tax is taken exactly
  once on commit and not on cancelled/re-armed trades; (8) the one-active-trade-per-player rule blocks
  a second concurrent trade.

---

## Open questions / flags

- **Scam vectors the double-confirm UX does NOT fully close (the requested flag).** The flow closes
  bait-and-switch (re-arm), look-alike impersonation (server-sourced canonical display), fat-finger
  (settle delay + net-Cash display), and stall-grief (visible escrow timeout + auto-revert). It does
  **not** close, because they are **social, not mechanical**:
  - **Off-platform / "trust me, I'll send the rest after" deals.** A player agrees in chat to a
    multi-part deal ("I'll give you item X now, you trade me item Y in the next trade") and then
    doesn't reciprocate. The trade UI can only guarantee *the trade in front of it*; it cannot bind a
    promised future trade. **Partial mitigation already in place:** the no-raw-Cash-send rule
    (economy RD3) and the everything-in-one-atomic-swap design mean a *single* trade is always
    all-or-nothing and fair; the residual risk is purely in deals a user chooses to split across
    trades against advice. **Recommended UX mitigation (low cost):** an in-trade reminder line — "Only
    what you see here is guaranteed. Never agree to send something in a separate trade." Cannot be
    fully closed; flagged as accepted residual social risk.
  - **Coercion / social-engineering ("trade me your Mythic or I'll get you banned/kicked").** Out of
    the trade system's scope; a moderation/reporting concern, not a flow fix. Flag to whoever owns
    player safety/moderation.
  - **Throwaway-alt manipulation / wash trading at scale.** The trade tax (anti-wash) and optional
    `tradeCooldownSeconds`/`maxItemsPerOfferSide` are the levers; whether they suffice depends on live
    behavior. A **light Passport gate on trading** (e.g. must have conquered ≥1 Destination to trade)
    would deter throwaway-alt scams and bot trade-farms at the cost of a tiny bit of new-player
    friction — **flagged as a decision, not taken** (MVL default: no gate). Co-decide with economy and
    onboarding.
- **Item-for-item (zero-Cash) trades pay zero trade tax (§5).** Because the tax is a fraction of the
  Cash leg, pure swaps have no wash-friction from the tax. If wash trading via item round-trips becomes
  a problem, economy may want a **small flat per-trade fee** (paid in Cash) on *every* committed trade,
  including item-for-item, as additional friction. This is an **economy rate call** (it adds a Cash
  sink); flagged there, not decided here. The flow can apply a flat per-trade Cash fee the same way it
  applies the percentage tax (one more `tradetax` entry) if economy chooses to define one.
- **Cross-server trading is the named post-launch extension (see §Future extension).** Same-server-only
  is binding for MVL. The §5 escrow/swap primitives hold either way (data_integrity), but the
  *mechanism* differs sharply: cross-server needs a MemoryStore-backed pending-trade broker or a
  dedicated trade-broker place, and cross-server atomicity is the hardest integrity guarantee on Roblox
  (data_integrity §open). Do not design it now; flagged so the same-server flow above is built without
  assumptions that would block a later cross-server layer (e.g. keep the `PendingTrade` shape
  broker-friendly — both party IDs, both offer sets, a version, a tax — which it already is).
- **Auction house / marketplace is the tempting scope creep — flagged, not built.** A listings market
  ("post your Mythic for 500k, anyone can buy") would deepen the economy but is **explicitly out of MVL
  scope** (00 scope discipline; 01 risk #1; 05 guardrail). It multiplies the surface for price
  manipulation, requires the cross-server substrate to be worthwhile, and should only be built atop a
  *proven* same-server trade flow and a *proven* anti-dupe substrate. Recommend: ship the direct trade,
  watch trade-velocity and rare-price telemetry, and treat a marketplace as a **post-launch LiveOps
  system**, never a launch feature. Flagging because it will be tempting the moment trading works.
- **Trade history / receipt UX.** A player-visible log of their completed trades (what, with whom,
  when, for how much) is a nice-to-have for trust and content (screenshot your trade history) and is
  cheap given the two-sided trade record already exists (data_integrity §5). MVL: out of scope as a
  built feature, but the data exists; flag to lodge/onboarding as a low-cost add if trust feedback
  wants it.
- **Browse-inventory privacy.** §7 lets a player view another's offerable inventory and Trophy Hall as
  a showcase (the flex surface). Confirm with lodge/onboarding that a player can **opt out** of having
  their offerable inventory browsed (the DISPLAYED Trophy Hall is intentionally public as the flex
  space; the HELD offerable inventory being public is a softer call). Default: Trophy Hall public,
  offerable inventory visible only on an opened trade or with availability toggled on. Flagged.

---

## Future extension (named, NOT designed): cross-server trading

Post-launch only. When trading expands beyond one server instance, the negotiation flow, double-confirm
state machine, offer-eligibility rules, tax application, and anti-scam UX in this doc are intended to
carry over largely unchanged — what changes is the **brokering substrate** beneath the commit: instead
of one server holding both session-locked profiles, a cross-server broker (MemoryStore-backed
pending-trade queue or a dedicated trade-broker place) coordinates the escrow and the atomic swap across
two instances. That substrate, and cross-server atomic-swap correctness, is **SYS_data_integrity's** to
design when the time comes (its §open flags it as the hardest Roblox integrity guarantee). This doc
deliberately keeps the `PendingTrade` shape broker-friendly (both party IDs, both offer sets, a terms
version, the Cash leg and tax) so the same-server flow does not have to be torn up to add cross-server
later. **Nothing in this section is a commitment to build cross-server in any particular window — it is
a note to not paint the MVL flow into a corner.**
