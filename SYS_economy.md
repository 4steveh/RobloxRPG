# System: Economy

> Second system deep-dive. Owns the Cash economy end to end: every **faucet** and **sink**, the
> per-tier **income bands** (formula, extensible past Tier 8), the **gear pricing curve** on its
> **two axes** (tier-gating + intra-tier), the **idle/AFK** rule, the **dual-loop income balance**,
> the **cross-loop pull** progression handed off, and the **inflation discipline** that protects the
> trade moat. It owns *Cash values, rates, curves, and the rules that keep them balanced*. It does
> **not** own damage/catch math (SYS_combat / SYS_fishing), item stats (EQUIPMENT_MASTER), specific
> creature/fish Cash numbers (LOC_ docs fill these into the bands here), spawn density (LOC_/combat —
> though the economy has a hard dependency on it, §5), or trade/anti-dupe mechanics (SYS_trading /
> SYS_data_integrity).
>
> **Inherited as binding** from SYS_progression v2.1: (1) unified funding + unified Passport, gear
> split into hunting/fishing branches, no single shared gear stat; (2) OR-gate on `required_tier` —
> a player can ride one loop to endgame, so each loop must independently sustain progression while
> both stay income-comparable, and the cross-loop pull is an *incentive*, never a gate.
>
> **v2 (deeper pass).** Adds the **two-axis gear model** (tier-gating gear gates Destinations;
> intra-tier gear drives the floor→apex climb and carries first-five-minutes dopamine) — the v1 gap
> that left onboarding nothing to sell early. Derives the **actual inflation condition** and its
> consequence (inflation control is a continuous LiveOps obligation). Names the **low-tier-farming
> exploit** and the **spawn-density dependency** that closes it. Resolves the **trade-tax tension**,
> the **reconciliation-seam ownership**, and recommends **Cash not be a tradeable leg** (RMT/inflation
> closure). Adds **idle-proof progression**, **dual-pricing insulation**, **multiplier-stacking** and
> **quest-scaling** rules. Changes from v1 summarized at the end.
>
> **v2.1 (review pass).** Two clarifications, no structural change: (1) resolves the rarity-multiplier /
> income-band double-count by fixing the band to the **routine (Common/Uncommon) mix only**, with
> rares as deliberate bonus on top (new Resolved Decision 5); (2) reconciles the MVL-jump arithmetic so
> "normal step = `2c`" and "MVL jump = `2c·g`" read as one claim (§4). Everything else unchanged.
>
> **Illustrative numbers convention.** Every concrete magnitude (B, g, c, m, idle fraction, caps,
> tax) is an **illustrative default**, flagged in Tuning Parameters. The *formulas and relationships*
> are the design; magnitudes are calibration knobs. Numbers in prose are marked *(default)*.

---

## Resolved Decisions (binding — do not re-litigate downstream)

1. **Gear has two pricing axes, and only the tier axis gates Destinations.**
   - **Tier-gating gear** (the integer `Tier` on weapon/armor/rod/reel that computes EHT/EFT) gates
     Destinations and is priced `GearCost_slot(T) = c·Income(T−1)` (§3).
   - **Intra-tier gear** (stat upgrades *within* an integer tier) does **not** change EHT/EFT or
     satisfy any Gate. It drives the floor→apex climb inside a Destination, carries the moment-to-
     moment and first-five-minutes spend, and is priced on a within-tier curve (§3). Its *stats* are
     EQUIPMENT_MASTER/combat's; its *cost shape* is this doc's.
   - Rationale: v1 priced only the tier axis, leaving the onboarding funnel with no minute-one
     purchase and each Destination with no internal economic arc. Two axes fix both and map cleanly
     onto progression's floor/ceiling rule (entry gear takes the floor; intra-tier-maxed + co-op takes
     the apex; next-tier gear solos the apex). Conquest still cannot be bought — intra-tier gear gets
     you apex-*capable*, the kill is still played.

2. **Inflation control is carried by cosmetics/decor, not the trade tax; the tax stays low.** Making
   the trade tax do inflation work forces it high, which suppresses the trading that *is* the moat.
   Resolution: the **evergreen identity sinks** (cosmetics, Lodge/Trophy decor) are the primary
   inflation ballast; the trade tax is a **light** secondary sink whose main job is anti-wash-trading
   friction *(default rate low, §9)*. (Resolves v1's trade-tax tension flag.)

3. **Cash is not a directly tradeable item; it moves only as the escrowed payment leg of an item
   trade.** A player cannot send raw Cash to another player. Rationale: directly tradeable Cash is an
   RMT magnet and a collusion/laundering vector; restricting Cash to the payment side of an item swap
   (SYS_trading's escrow) closes most of it and keeps the "rare purchase = P2P transfer, not a mint"
   inflation argument (§7/§9) clean. The economy *requires* this property; SYS_trading owns the
   mechanic. (Resolves v1's open RMT question.)

4. **The income/payout reconciliation seam has explicit ownership: economy owns the income target,
   SYS_combat/SYS_fishing own the engagement rate, and the per-target payout is *computed*, never
   authored independently by either side.** Neither doc may hardcode a Cash-per-target value; both
   must derive it from `Income(T)` ÷ rate (§5). (Resolves v1's reconciliation-owner flag.)

5. **The income band is the routine (Common/Uncommon) target mix only; rares are bonus ON TOP, not in
   the band.** This resolves the rarity-multiplier double-count: if the band already included rares and
   each rare were then multiplied by up to 16×, an average hour with any rare would exceed `Income(T)`
   and the economy would mint faster than the band claims. The fix:
   - `Income(T)` and `ExpectedTargetsPerHour` are **calibrated over the routinely-encountered targets
     (Common/Uncommon)** at mid intra-tier gear, normalized so a routine hour sums to `Income(T)`.
     (Common/Uncommon spawn at *stable* rates, so normalizing across them is safe — it does not couple
     payouts to a lottery.)
   - **Rare and above are excluded from the band.** When one appears, `Payout = BaselinePerTarget(T) ·
     RarityMultiplier` pays a multiple of the routine value as genuine upside, spiking that hour
     *above* `Income(T)`. The band is therefore a reliable **baseline/floor**, and realized income =
     `Income(T) + a small rare premium`.
   - **The premium is deliberately small**, by two existing rules: rares are infrequent (1-in-N), and
     Legendary/Mythic NPC salvage is floored low with their real value flowing to P2P trade and the
     Trophy Hall (§5) — so the 9×/16× ladder entries are realized as *trade/display value*, not as Cash
     dumped into the faucet. The rare contribution to the Cash supply stays minimal.
   - **Rejected alternative (folding rares into the band, scaling commons down so the mix sums to
     `Income(T)`):** it would couple common payouts to rare *spawn rates*, so every LOC_ rare-rate
     change would force a re-tune of that tier's common payouts (breaking the formula-not-table
     discipline and making LOC_ docs interdependent), and it would make commons feel underpaid. Not
     adopted.
   - **Consequence for the inflation model (§9):** the endgame faucet rate is `Income(T_max)` **plus
     the small rare premium**, not the bare band — the evergreen-sink check (§9) consumes the realized
     faucet including that premium, not `Income(T_max)` alone. EQUIPMENT_MASTER and LOC_ docs bake in
     *this* interpretation: commons/uncommons sum to the band; everything rarer is accretive.

---

## Purpose & player-facing goal

The economy is the connective tissue: the single Cash pool both loops pour into and draw from, the
pacing mechanism that makes a gear upgrade *felt*, and the macro system that keeps rares rare. Its
player-facing job is to make the core sentence true and satisfying — **money → gear → access → bigger
prey → more money** — at two cadences at once: frequent small wins (intra-tier upgrades, the session-
dopamine and first-five-minutes layer) and slower aspirational ones (a new continent unlocked). A
player should always have a *meaningful* choice about where the next Cash goes and should never feel
the economy is a free slot machine or a real-money paywall.

Its second, invisible goal is guarding the trade moat. Rares are valuable only while Cash is scarce
relative to them. If Cash inflates, rares lose their price, the Trading Post stops mattering, and the
single biggest separator between a 3-month hit and a multi-year franchise (00 §5) dies quietly. So the
economy must keep Cash feeling *earned* for the whole population, forever, across unlimited LiveOps
content — and as §9 shows, that "forever" is an ongoing operational commitment, not a one-time tune.

---

## How it ties to the formula

- **Retention hub (00 §0).** Two spend cadences serve two retention windows: intra-tier upgrades give
  the per-session dopamine that protects D1; tier-gating purchases and the locked-Destination
  aspiration protect D7/D30. Idle/AFK accrual (00 §2) is a capped retention faucet whose cap *is* the
  "come back daily" hook.
- **Sell WITH the player (00 §4).** Real money touches Cash only through grind-compression (currency
  packs, 2x boosts) and friction-removal (auto-sell), never the play requirement — the pay-proof
  property makes currency packs non-pay-to-win, and idle Cash hits the same milestone wall (§6, §7).
  Forbidden patterns (energy timers, rod-recharge waits, play-blocking ammo/bait) are named and
  excluded.
- **The trade moat (00 §5).** Inflation discipline *is* scarcity discipline in Cash terms; Resolved
  Decisions 2 and 3 are its structural spine.
- **Depth, not a treadmill (00 §2; 05 §2).** Gone Hunting is a flat sell→upgrade→repeat loop with
  ~8.6-min sessions. The antidote is **contended Cash** across several legible uses (next tier-gating
  slot, intra-tier climb to the apex, a Boat, a Trading-Post rare, a cosmetic flex, premium bait for a
  spawn window) plus the **within-Destination floor→apex arc** the intra-tier axis creates. The depth
  is in the spend decisions, not the payout.
- **Content engine (00 §7).** Income and pricing are formulas keyed to the tier axis, so Tier 9+
  content inherits the curve untouched — and §9 makes the cosmetic pipeline itself part of the engine.

---

## Mechanics (detailed)

### 1. Faucets and sinks (the complete two-column inventory)

The macro balance rule (§9): total sink capacity must absorb total faucet output across the whole
lifecycle — especially at endgame, where the gear sink plateaus.

| FAUCETS (Cash in) | Design intent |
|-------------------|---------------|
| **Kill payouts (hunting)** | Primary hunting faucet; per-target value derived from the tier band (§5). |
| **Catch payouts (fishing)** | Mirror of kills; must hit the *same* band at the same tier (§6). |
| **Quest / daily-quest rewards** | Loop-teaching and pacing Cash; **scaled as a fraction of `Income(T_current)`** so they neither trivialize endgame nor become a low-tier-farming vector (§5). Dailies feed Premium Payouts; the cross-loop daily bonus lives here (§6). |
| **Idle / AFK accrual** | Capped offline trickle (§6), a *fraction* of active income — never replaces play, never advances rank/conquest. |
| **Rare/Legendary NPC salvage** | A deliberately *low* floor for vendoring a rare — always far below P2P value, to push rares into the trade economy, not the Cash supply (§5). |
| **Event payouts (LiveOps)** | Bounded, scheduled Cash; SYS_liveops owns cadence, economy owns the per-event **budget ceiling** so an event can't flood supply. |
| **Currency packs (real money)** | Developer product; injects Cash. Non-pay-to-win (pay-proof); inflation-managed via sinks + Cash-not-tradeable + P2P-transfer rare buying (§7, §9). |
| **2x Cash boost / VIP (real money)** | Time-limited / persistent multipliers on *active* income. Compress grind, never milestones; metered separately (§7). |

| SINKS (Cash out) | Design intent |
|------------------|---------------|
| **Tier-gating gear (weapon/armor/rod/reel)** | Primary *progression* sink; scales with tier (§3). **Plateaus** at top tier — which is why the evergreen sinks must carry endgame (§9). |
| **Intra-tier gear upgrades** | The within-Destination sink: the floor→apex stat climb (§3). High-frequency early spend; the first-five-minutes purchase lives here. |
| **Boats / Mounts / Tracking Dogs** | Big one-time access/convenience sinks; also shared cross-loop savings goals (§6). |
| **Cosmetics (skins, outfits, camo, boat paint, dog breeds)** | **Evergreen, balance-free, highest-margin — the primary inflation ballast (§9).** No ceiling; absorbs endgame Cash gear no longer can. |
| **Lodge decor / Trophy Hall expansion** | Second evergreen identity sink; unbounded appetite. |
| **Premium consumables (premium ammo/bait/lure)** | Recurring optional sink. Basic ammo/bait is effectively free — premium only *improves* outcomes, never gates play (the not-a-timer rule below). |
| **Trade tax** | **Low** secondary sink; anti-wash friction, minor inflation drain (Resolved Decision 2). Rate owned here; trade flow is SYS_trading's. |
| **Repair / restock / revive** | Minor friction sinks; light by design, with a free/ad alternative for revive. |
| **Fast-travel fee (default OFF)** | Dormant knob; risks reading punitive, enabled only if data demands an extra sink. |

**The not-a-timer rule (binding).** Basic ammo and bait are auto-replenished or trivially priced; a
player can **never** be blocked from the core loop by running out. Only *premium* consumables cost
meaningful Cash, and no creature/fish may be takeable *only* with a premium consumable (that would
convert a sink into a soft timer — flagged to combat/fishing, §open).

### 2. The income curve (per-tier, formula, extensible past Tier 8)

Income is a band — target Cash/hour for an average player **at mid intra-tier gear** at a given tier —
defined as a geometric formula keyed to the tier axis:

```
Income(T) = B · g^(T − 1)
```

`B` = Tier-1 base *(default 1,000 Cash/hr)*; `g` = per-tier growth *(default 1.7)*.

Worked illustration (computed from the formula, never stored): T1 1,000 · T2 1,700 · T3 2,890 ·
T4 4,913 · T5 8,352 · T6 14,199 · T7 24,138 · T8 41,034 · T9 (LiveOps) 69,758. Tier 9+ is just
`B·g^(T−1)` — no retune.

**`g` and `c` are orthogonal knobs.** Because gear is priced off *prior-tier* income (§3),
time-to-afford a tier step is `2c` hours **independent of `g`**. So `c` sets *pacing* (how many hours
per tier) and `g` sets *number-feel* (how fast absolute Cash grows) — plus two side effects `g`
carries: the MVL-jump severity equals `g` (§4), and the strength of the low-tier-farming disincentive
rises with `g` (§5). Tune `c` for pace; tune `g` for the curve's shape and those two couplings.

**Reference point.** The band is measured at *mid* intra-tier gear. A floor-geared player at tier T
earns somewhat *below* `Income(T)` (slow kills); an intra-tier-maxed player earns somewhat *above* it.
That spread is intentional — it is the within-tier reinforcement loop (better gear → faster kills →
more Cash → next upgrade) and the economic motor of the floor→apex climb.

### 3. The two-axis gear pricing curve

**Tier axis (gates Destinations).** Reaching `EHT = T` needs Tier-T weapon **and** armor; `EFT = T`
needs Tier-T rod **and** reel (min rule). Each gating slot:

```
GearCost_slot(T) = c · Income(T − 1)        for T ≥ 2     (c default 3)
```

A full tier-up buys two gating slots: `2·c·Income(T−1)`. Normal step `T→T+1` while earning
`Income(T)`: time-to-afford `= 2c` hours *(default 6 hrs; 3/slot)*. (Tier 1 has **no armor cost** —
armor gates from Tier 2 — so Bayou→Appalachia is the first time armor enters the bill.)

**Intra-tier axis (drives the floor→apex climb, does not gate).** Within a tier, gear has stat-upgrade
levels at the same integer `Tier`. Total cost to climb a loop's gating slots from tier-T *floor* stats
to tier-T *ceiling* stats:

```
IntraTierClimb(T) ≈ m · Income(T)                          (m default 2.5 hours of current-tier income)
```

distributed across the discrete steps EQUIPMENT_MASTER/combat define (early steps cheaper for dopamine
cadence; geometric within the tier). Intra-tier-maxed ≈ apex-capable **with co-op**; solo apex still
wants Tier-(T+1) gear — consistent with progression's floor/ceiling. Intra-tier upgrades never change
EHT/EFT and never satisfy a Gate.

**The per-Destination economic arc** is therefore `(m + 2c)·Income(T)` ≈ *(default 8.5)* hours of
single-loop play: arrive at the floor on entry gear → spend `~m·Income(T)` climbing intra-tier to
apex-capable → conquer (milestone) → spend toward the next tier's gating gear → unlock the next
Destination. Dual-loop play splits the wall-clock against the shared pool. Each continent is a solid
evening or two — the right D7/D30 cadence.

### 4. The MVL two-tier jump check (Appalachia T2 → Alaska T4, Rockies skipped)

SYS_progression's highest-risk MVL spot, handed here to verify the *Cash* gap is affordable and
legible, not a paywall (the *difficulty* gap is SYS_combat's, not solved here).

- Appalachia player earns `Income(2) = 1,700/hr` *(default)*.
- Alaska Tier-4 gear: `GearCost_slot(4) = c·Income(3) = 3·2,890 = 8,670`/slot; two slots = `17,340`.
- Time-to-afford on T2 income: `17,340 / 1,700 ≈ 10.2 hrs` single-loop.
- Normal step is `2c = 6 hrs`. The MVL jump is **≈ 1.7× a normal step** — exactly `g`, because the
  player buys T4 gear priced off T3 income while still earning T2 income. In affordability terms this
  is one claim, not two: a normal step costs `2c` hours; the MVL jump costs `2c·g = 6·1.7 = 10.2` hrs
  (the same 10.2 above, and the same figure the telemetry build-note targets).

**Verdict: passes, with one mitigation and one self-heal.** A ~1.7× step reads as the expedition-sized
purchase Alaska *should* feel like — not a wall. (1) The **shared Cash pool roughly halves wall-clock**
for a player working both loops in Appalachia — the MVL jump *is* the cross-loop pull in action. (2)
When **Rockies ships**, the player passes through `Income(3)` and the T4 gear time normalizes to the
standard 6 hrs automatically (formula + DAG re-thread, no number changes). Note the intra-tier arc in
Alaska is unaffected — it's priced off `Income(4)`, which the player earns *once there*, so the
within-Destination climb is normal even in the MVL.

### 5. From income bands to per-target payouts — and the low-tier-farming closure

LOC_ docs fill specific Cash values; this doc owns the band and the **derivation rule** (Resolved
Decision 4 — payout is computed, never authored):

```
Payout(target) = ( Income(T) / ExpectedTargetsPerHour(T, loop) ) · RarityMultiplier(rarity)
```

`RarityMultiplier` *(defaults)*: Common 1 · Uncommon 1.6 · Rare 2.8 · Epic 5 · Legendary 9 · Mythic
16 — geometric, mirroring the income feel. `Income(T)` uses the **target's** tier (a re-skinned Alaska
rabbit pays an Alaska-floor wage, per progression), and the band is calibrated over the **routine
(Common/Uncommon) mix only** at mid intra-tier gear — Rare-and-above are bonus on top, not in the band
(Resolved Decision 5). So `BaselinePerTarget(T) = Income(T)/ExpectedTargetsPerHour` is anchored on the
routine targets; a Rare/Epic/Legendary/Mythic that appears pays that baseline × its multiplier as
genuine upside, spiking the hour above `Income(T)` rather than being averaged into it.

**Rares are a trade item first, a faucet a distant second.** Legendary/Mythic targets pay their
scaled Cash *only as NPC salvage*, set deliberately low; real value is the P2P trade and the Trophy
Hall. This protects the moat (rares flow to players, not vaporized into supply) and caps rare-driven
minting (a Mythic doesn't flood the economy). The salvage-vs-P2P gap is a tuning parameter and a
deliberate nudge.

**Low-tier farming — the exploit and its closure.** Geometric income *alone does not* stop an
over-geared player from farming trivial low-tier content: if a maxed Tier-4 player one-shots Tier-1
targets at, say, 10× the normal Tier-1 rate, naive `Payout = Income(1)/rate` math lets them earn
`10·Income(1) = 10,000/hr`, *exceeding* legitimate `Income(4) = 4,913`. The curve is self-protecting
**only in conjunction with spawn-density caps**: each Destination has finite spawn density and respawn
timers, so `ExpectedTargetsPerHour` has a **ceiling set by spawn availability, not player speed**. An
over-geared player at Tier 1 hits the spawn-density ceiling and earns ≈ `Income(1)`, strictly worse
than playing their own tier. **The economy has a hard dependency on spawn-density caps existing**
(owned by LOC_/combat); without them, the band model breaks. Stated here as a binding dependency, not
an assumption (§inputs, §open).

### 6. Dual-loop income balance (load-bearing) and the cross-loop pull

**Constraint.** Hunting Cash/hr ≈ fishing Cash/hr at **every** tier. If one loop out-earns the other,
players abandon the weaker loop, half the content dies, and the OR-gate turns a strength into a trap.
This is 01 risk #3, the single most fragile thing in the game.

**Guaranteed structurally, not hoped for.** Both loops are tuned to the *same* `Income(T)` band by
derivation (§5): each loop's payouts are back-solved so an hour of tier-T play on that loop ≈ the same
`Income(T)`. Balance is a derivation rule, not a coincidence of two payout tables. **Drift has exactly
one door:** the modeled `ExpectedTargetsPerHour` diverging from reality on one loop (e.g. fish bite
slower than modeled). That single failure mode is what telemetry watches, and the fix is to re-derive
the lagging loop's payouts against its *measured* rate — a knob turn, because the structure already
names where to turn it. (Telemetry must compare loops at *comparable intra-tier progress*, or on
population averages, since intra-tier gear shifts per-loop earn rate within a tier — §build notes.)

**The cross-loop pull (handed from progression; built here without hard-gating).**
- The **shared Cash pool is the baseline pull** — fishing money buys hunting gear; dabbling is never
  wasted (and it's what halves the MVL Alaska grind, §4).
- A **cross-loop daily bonus** — a small kicker *(default ≈ 0.5 hrs of current-tier income, scaled
  with tier)* for landing at least one kill *and* one catch in a day. A reward for breadth, never a
  penalty for focus; within-loop diminishing returns are excluded (they read as fun-interruption).
- **Shared big-ticket goals** — Boats/mounts/dogs are wanted across both loops, funded from one pool.
- **Scheduled cross-loop goals are deferred to SYS_liveops** — economy owns the *standing* pull,
  LiveOps owns the *calendar* pull.

The pull is opportunity, never obligation; a committed single-loop player still progresses and merely
leaves the standing bonus on the table.

### 7. Where real money touches Cash (non-pay-to-win rules)

This doc specifies only the Cash-touch points, not the store.

- **Currency packs (dev product)** inject Cash directly. Clean via the pay-proof property: bought Cash
  compresses the grind, never the milestone (a whale still downs the boar to reach Alaska).
  Inflation/scarcity reasoning: injected Cash re-exits via sinks; and because **Cash is not a
  tradeable leg** (Resolved Decision 3), a whale buying a *rare* sends Cash to another *player* on the
  Trading Post — a **transfer, not a mint** — net-neutral to supply, net-deflationary after the tax.
  Real-money Cash funds the F2P economy (the moat working as intended). Still a faucet on the ledger,
  instrumented as such.
- **2x Cash boost (dev product)** — time-limited multiplier on *active* income; urgency, grind
  compression, no milestone skip. An inflation accelerant (more Cash/hr while active), so boost-active
  income is metered separately.
- **Auto-sell (game pass)** — convenience, not a multiplier: pays the **same Cash** as manual selling,
  only removes friction. The equivalence is a hard rule (else it's pay-to-win).
- **VIP pass** — small persistent active-income multiplier; same rules and metering as the boost.

**Multiplier stacking rule.** VIP, 2x boost, and any event multiplier stack **multiplicatively** on
the active-income faucet, applied at credit time, with a **design max-stack ceiling** *(default ~2.5×;
a tuning cap)* instrumented so worst-case minting is bounded. No multiplier ever applies to idle beyond
its stated scope, and none applies to milestone/conquest (not Cash, out of reach entirely).

**Idle-proof progression.** Idle Cash hits the same wall real-money Cash does: it can fund the
*purchasable* (gear) half of a gate but can never produce the *milestone* (active kill/catch). A pure-
idle player accumulates Cash and gear but cannot conquer a Destination, so cannot advance the
Passport. The pay-proof property is also idle-proof by the same mechanism.

**Forbidden (restated — the audience punishes these, 00 §4):** energy timers; rod-recharge / "wait to
play again"; basic ammo/bait that blocks the core loop; any Cash-side feature letting a payer take a
target or cross a gate a non-payer's *play* could not.

### 8. Depth — the anti-treadmill spend decisions

Gone Hunting's economy is a flat sell→upgrade→repeat funnel; ~8.6-min sessions are the symptom
(05 §2). Wild World makes **Cash contended** — several legible, desirable uses compete for one wallet,
so spending is a decision with trade-offs:

- *Slot ordering* — which gating slot to upgrade next (weakest-slot rule + next gate).
- *Tier vs. intra-tier* — push the intra-tier climb to conquer the current apex now, or save the Cash
  toward the next tier's gating gear and out-level it? A genuine pace-vs-power choice each Destination.
- *Dual-loop arbitrage* — earn on whichever loop pays better now, fund the other.
- *Save-vs-spend* — gear now, or save for a Boat/mount, or buy a Trading-Post rare, or bank toward a
  cosmetic flex.
- *Rare acquisition cost* — buying a rare costs progression speed (Cash that didn't go to gear). That
  real opportunity cost is the depth Gone Hunting's solo sell-to-NPC loop structurally cannot have.
- *Consumable timing* — premium bait/ammo to improve odds in a rare spawn window, or pocket the Cash.

None is a number shown to the player; all are choices the price structure creates. The depth is in the
contention.

---

## Inputs / dependencies

- **00 / 01 / 02 / 04 / 05** — as v1: retention hub, monetization rules, trade-moat scarcity, the
  money→gear→prey loop and risk #3, Cash/kg/1–100/rarity units (rarity drives the multiplier ladder),
  Template B `Cost` and Template C/D reward fields, the Gone Hunting flat-treadmill guardrail.
- **SYS_progression v2.1** — the tier axis; `EHT=min(weapon,armor)`/`EFT=min(rod,reel)`; armor gates
  from Tier 2; OR-gate + pay-proof; idle feeds Cash only; the MVL jump to verify; the floor/ceiling
  rule the intra-tier axis prices; the cross-loop pull handed here.
- **Hard dependency — spawn density (LOC_ / SYS_combat / SYS_fishing).** The per-target band model
  (§5) is valid **only** if spawn-density caps bound `ExpectedTargetsPerHour` independent of player
  gear. Without them, low-tier farming breaks the economy. This is a precondition, not a nicety.
- **Reconciliation seam (Resolved Decision 4).** `ExpectedTargetsPerHour` is set by combat/fishing
  difficulty; economy owns the income it must produce; payout is computed jointly, authored by
  neither alone. Per-tier reconciliation is the origin of dual-loop drift.

---

## Outputs / what depends on this

- **EQUIPMENT_MASTER** — consumes the tier-gating curve (§3) for every gating item's `Cost`, the
  **intra-tier cost curve** for within-tier upgrade pricing, and evergreen-sink intent for cosmetics.
- **All LOC_ docs** — consume the income band + payout derivation (§5) for creature/fish Cash and rare
  salvage floors; consume the **spawn-density requirement** (they own the actual densities the economy
  depends on); consume the regional sink list (premium consumables, regional cosmetics, Boats).
- **SYS_combat / SYS_fishing** — consume `ExpectedTargetsPerHour` as the income-per-hour target their
  difficulty is reconciled against; own the spawn-density caps and the intra-tier *stat* values;
  SYS_combat additionally owns the MVL *difficulty* check this doc does not.
- **SYS_trading** — consumes the **low** trade-tax rate (Resolved Decision 2), the **Cash-not-
  tradeable** rule (Resolved Decision 3 — Cash only as escrowed payment leg), and the rare salvage-vs-
  P2P split; depends on scarcity holding (anti-dupe is SYS_trading/SYS_data_integrity's to *build*).
- **SYS_data_integrity** — consumes: all Cash server-authoritative; every faucet/sink an atomic,
  validated, non-dupe-able ledger transaction; and the **trophy-disposition rule** (§build notes — one
  rare artifact has exactly one disposition: salvage XOR display XOR trade, never duplicated across).
- **SYS_lodge_trophy** — consumes the cosmetic/decor sink as the **primary inflation ballast** and the
  identity-monetization spec for Cash-priced decor; depends on a **continuous cosmetic pipeline** (§9).
- **SYS_onboarding_funnel** — consumes the free starter loadout (no Cash gate at Tier 1), the ~60-sec
  first payout, and the **intra-tier first purchase** as the minute-one soft-monetization setup.
- **SYS_liveops_calendar** — consumes the extensible formulas (Tier 9+ free), the event-payout budget
  ceiling, the handoff of *scheduled* cross-loop incentives, and the **inflation-as-LiveOps-obligation**
  result (§9): shipping new cosmetic/decor content is an economic duty, not just a content one.

**Out of scope (named, not designed):** damage/catch math; item stats; specific Cash numbers (LOC_,
into these bands); spawn density (LOC_/combat — depended on, not set); trade/anti-dupe mechanics; full
store design (only Cash-touch points here).

---

## Tuning parameters

- **`B` — Tier-1 base income** *(default 1,000 Cash/hr)*. Anchors the curve.
- **`g` — per-tier income growth** *(default 1.7)*. Number-feel; also = MVL-jump factor and
  low-tier-farming disincentive strength.
- **`c` — tier-gating gear cost, hours-of-prior-tier-income per slot** *(default 3)*. Pacing only
  (`2c` hrs/tier-step), orthogonal to `g`.
- **`m` — intra-tier climb cost, hours-of-current-tier-income (floor→apex, both slots)** *(default
  2.5)*. The within-Destination spend; sets per-Destination arc `(m+2c)`.
- **`RarityMultiplier` ladder** *(Common 1 · Uncommon 1.6 · Rare 2.8 · Epic 5 · Legendary 9 · Mythic
  16)*.
- **`ExpectedTargetsPerHour(T, loop)`** — *co-owned with combat/fishing*; the drift-prone input;
  **bounded above by spawn-density caps** (LOC_/combat).
- **Rare salvage-vs-P2P value split** — how low the NPC floor sits vs. true trade value.
- **`idleFraction`** *(default 0.15 of current-tier active income)*; **`idleCapHours`** *(default 8)* —
  the daily-return hook strength.
- **Cross-loop daily bonus size** *(default ≈ 0.5 hrs current-tier income, tier-scaled)*.
- **Quest/daily reward scale** — fraction of `Income(T_current)` per reward (keeps dailies relevant,
  non-exploitable).
- **Trade-tax rate** *(default low — anti-wash, not inflation primary; Resolved Decision 2)*.
- **Premium-consumable prices and effect sizes**; **minor-sink magnitudes** (repair/restock/revive;
  fast-travel fee default OFF).
- **Real-money multipliers** — 2x boost size/duration, VIP size, and the **max-stack ceiling**
  *(default ~2.5×)*.
- **Event-payout budget ceiling** — *co-set with SYS_liveops*.
- **Drift alert threshold** — per-loop Cash/hr ratio bounds *(default outside 0.85–1.18, ≈15%)*.
- **Inflation alert threshold** — tolerated per-capita Cash-supply growth rate.
- **Endgame-sink replenishment cadence** — how often new cosmetic/decor must ship to hold the evergreen
  sink (the §9 obligation made a tracked knob).

---

## Claude Code build notes

**Server-authority over all Cash is absolute** (SYS_data_integrity). The client never asserts a
balance, a sale, a faucet credit, a sink debit, an idle duration, or a milestone. Every Cash movement
is a server-validated atomic transaction against a server-owned balance; a client claiming "+5,000
Cash" or "balance = X" is ignored and the server recomputes from authoritative event history. This is
the precondition for both anti-dupe and the trade moat.

**Cash as an append-only transaction ledger, not a mutable integer.** Each entry: source/sink type,
amount, tier, loop, timestamp, validating event id, and (for real-money faucets) a `realmoney_*` tag.
Balance is derived. This gives anti-dupe robustness (no last-write-wins on a bare int), exact
faucet/sink telemetry for free, and a rollback-safe audit trail.

**Income / gear price / payout / intra-tier cost are pure functions of tier**, evaluated from the
formulas, not tables: `Income(T)=B·g^(T−1)`, `GearCost_slot(T)=c·Income(T−1)`,
`IntraTierClimb(T)=m·Income(T)`, `Payout=(Income(T)/ExpectedTargetsPerHour)·RarityMultiplier`. Keep
`B,g,c,m`, the multiplier ladder, and the rate model as live config so they retune without code and
Tier 9+ inherits the curve.

**Spawn-density caps are an economy-critical invariant, enforced server-side.** `ExpectedTargetsPerHour`
must be bounded by spawn availability, not player speed, or low-tier farming breaks the bands (§5).
Build and test the cap before any Cash is live; instrument actual targets/hour per tier against the
modeled rate to catch a missing or mis-set cap.

**Real-money multipliers are server-validated, time-bounded entitlements**, applied at credit time,
stacked multiplicatively up to the max-stack ceiling, metered with a flag so boost-active income is
separable in telemetry. No multiplier touches milestone state.

**Trophy disposition atomicity** (coordinate with SYS_trading / SYS_data_integrity): one rare
spawn yields exactly **one** artifact, whose disposition is mutually exclusive — **salvage for Cash
XOR display in the Trophy Hall XOR hold-as-tradeable** — and transitions are atomic server moves
(displayed items leave tradeable inventory and vice versa; never both). This is a scarcity-integrity
dependency the economy relies on.

**Idle accrual** computed server-side from the stored logout timestamp, clamped to `idleCapHours`,
credited as a single `idle`-tagged ledger entry at next authenticated login — never from client-
reported elapsed time.

**Telemetry — wire alongside, not after (00 §0, 01 risk #3):**
- **Per-loop Cash/hr, per tier, population-distributed** — the core balance metric; compare loops
  against each other and the band, at comparable intra-tier progress; fire the drift alert past
  threshold. The single most important chart in the game.
- **Faucet/sink flow ledger** — Cash minted per faucet and removed per sink per day; per-capita net is
  the headline **inflation indicator**.
- **Cash supply per active player over time** — should be roughly flat; triggers the inflation alert.
- **Gear-affordability time-to-purchase per tier** — measured hours to afford the next tier's gating
  gear; should match `2c` (and `2c·g` for the MVL Appalachia→Alaska jump). Catches a mispriced tier.
- **Actual targets/hour per tier vs. modeled** — verifies spawn caps and the rate model; a high
  reading at a low tier flags a low-tier-farming hole.
- **Median vs. mean Cash per tier** — hoarding (inflation) vs. starvation (sinks too harsh); the gap
  detects whale skew.
- **Idle %, boost-active % of total faucet** — guard against either quietly driving supply.
- **Evergreen-sink share of endgame Cash** — if top-tier players aren't routing Cash into
  cosmetics/decor/tax, endgame inflation is imminent (the §9 canary alongside rare-price trend).
- **Trading Post Cash velocity + rare price trend** — the moat canary; rising rare prices lead Cash
  inflation reaching the trade economy.
- **Gate drop-off, gear-half only** — stalls on affording *gear* (vs. milestone) mean a tier is
  overpriced; retune `c` or that tier.

**MVL pre-launch economy checks:** (1) the Appalachia→Alaska gear-Cash gap matches the ~1.7× model and
is co-op/dual-loop soluble; (2) both loops hit the same `Income(T)` band per MVL tier under realistic,
spawn-capped rates; (3) the faucet/sink ledger shows flat per-capita supply in a simulated population
*before* real money is wired; (4) the spawn-density cap holds under an over-geared low-tier-farming
test.

---

## The inflation condition, derived (why §9 is load-bearing)

Per-capita Cash supply changes at rate `Σfaucets − Σsinks`. Early game `faucets > sinks` is **correct**
— the player is saving toward gear, and that accumulation *is* the progression feel; this is not
inflation. Inflation is unbounded accumulation, which happens only when earned Cash has nothing left to
buy. So the real condition is two-part:

1. **Over a full progression arc, integrated `(faucet − sink)` stays bounded** — players spend roughly
   what they earn across the tier ladder (tier-gating gear + intra-tier climbs + access items soak the
   journey). The pricing curves (§3) enforce this for the *progression* phase.
2. **At endgame (top tier, gear maxed, gear sink → 0), evergreen-sink spend-rate must be ≥ faucet-
   rate.** Faucet rate ≈ `Income(T_max) + idle + boosts`. The only sinks left are cosmetics, decor,
   premium consumables, and the (low) trade tax. For the per-capita supply to stay flat, these must be
   able to *continuously* absorb endgame income.

**The non-obvious consequence: inflation control is a continuous LiveOps obligation, not a one-time
tune.** Evergreen sinks are evergreen *only if continuously replenished* — a fixed cosmetic catalog
saturates (players buy everything they want, then accumulate), and inflation resumes. Therefore
**shipping new desirable cosmetics/decor on the LiveOps calendar is an economic duty**, tracked by the
endgame-sink-replenishment cadence parameter and the evergreen-sink-share telemetry. This is also why
the dual-pricing structure matters (below): it lets the trade market run hot without the heat leaking
into progression.

**Dual-pricing insulation.** Gear and consumables are **formula-priced in Cash** (fixed, identical for
everyone, immune to veteran wealth); rares are **market-priced P2P** (dynamic, veteran-set). A late
joiner buys gear at the same Cash price the first player did — the progression economy is insulated
from veteran wealth — while the *optional* rare market is free to be a dynamic, aspirational,
veteran-priced layer. The two pricing regimes don't leak into each other precisely because Cash is not
a tradeable leg (Resolved Decision 3) and rare NPC-salvage is floored low (§5): the trade market's
inflation can't reach the gear a new player needs.

---

## Open questions / flags

- **`ExpectedTargetsPerHour` remains the load-bearing unknown.** Dual-loop balance is structurally
  guaranteed *only if* the modeled rate matches reality on both loops, and the whole band model
  depends on spawn-density caps bounding it. Cannot be finalized until SYS_combat/SYS_fishing set
  difficulty, engagement, and spawn density. Highest-priority joint-tuning item; payouts (§5) are
  provisional until then.
- **Spawn-density caps are a hard external dependency, owned elsewhere.** The economy *requires* them
  (§5) but does not set them. If LOC_/combat ship without effective caps, low-tier farming breaks the
  economy regardless of anything in this doc. Track as a cross-doc gating dependency, not a flag to
  resolve here.
- **Currency-pack inflation — monitored, not closeable in design.** The §7/§9 reasoning (re-exit via
  sinks; Cash-not-tradeable; rare buying is a transfer not a mint) is sound, but magnitude depends on
  real whale behavior. Telemetry-watch (currency-pack faucet share, rare-price trend); levers if it
  drifts: raise trade tax, ship more evergreen sinks, cap pack size.
- **Boost adoption vs. supply.** 2x/VIP mint extra Cash/hr. Held acceptable (metered, absorbed by
  sinks, stack-capped), but high adoption could drift supply; mitigation is sink elasticity, not
  removing the boost.
- **`m` and the per-Destination arc length** *(default 8.5 hrs single-loop)* is a retention-sensitive
  guess. Too long walls D7; too short exhausts content. Validate against live time-to-conquer and
  session-length data; first real tuning target post-soft-launch.
- **Cross-loop daily bonus efficacy unproven.** Whether a modest standing bonus actually pulls
  single-loop players toward breadth is an empirical question; if the OR-gate produces a large
  single-loop population anyway, escalate cross-loop incentives to SYS_liveops (event goals) rather
  than hard-gating.
- **Endgame-sink-replenishment cadence is now a hard LiveOps commitment**, not just creative content.
  Flag for SYS_liveops/SYS_lodge_trophy: the cosmetic/decor pipeline carries an economic SLA, and the
  evergreen-sink-share metric is its alarm.
- **Trade-tax rate is a shared, low knob with SYS_trading.** Resolved Decision 2 sets it low and lets
  cosmetics carry inflation; the exact rate is co-set with live trade-velocity data.
- **Premium-consumable boundary.** Must stay optional-improvement. Flag for combat/fishing: no
  creature/fish may be takeable *only* with a premium consumable, which would convert a sink into a
  soft timer/pay-to-win.
