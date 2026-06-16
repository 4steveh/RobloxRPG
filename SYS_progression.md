# System: Progression

> First system deep-dive. This doc owns the gear-tier ladder, Destination gating, Passport
> progression, Hunter/Angler Rank, and the floor/ceiling difficulty principle. It constrains
> SYS_economy, SYS_combat, SYS_fishing, EQUIPMENT_MASTER, and every LOC_* doc downstream.
> It owns *structure and rules*; it does not own Cash values, damage math, or item stats —
> those are named as tuning parameters and handed to the dependent docs.
>
> **v2 (deeper pass).** Unifies "conquer" and "milestone" into one event; makes the gate
> dual-loop-completable (you can advance the Passport on hunting OR fishing alone); states the
> pay-proof / carry-proof property that is the structural answer to "is gear-gating
> pay-to-win"; defines starter / empty-slot tier semantics; separates entry-gates from
> within-Destination access sub-gates. Changes from v1 are summarized at the end.

---

## Purpose & player-facing goal

Progression is the felt sense of "I am getting somewhere." In Wild World that sense comes from two
visible, concrete things — **better gear** and **more of the world unlocked** — never from an
abstract level number. A player should be able to answer, at any moment and in one glance, two
questions: *what can I take down / catch now that I couldn't before*, and *where can I go that I
couldn't go before*. The system's job is to make both answers always legible, always tied to a
specific next purchase or a specific next conquest, and never gated by a random one-shot wall.

The player-facing experience: you buy a rifle and can finally hunt boar; you down the apex of your
current tier and the next Destination's pin lights up on the World Map; you buy an expedition parka
and a Boat and Alaska becomes reachable. Money → gear → access → bigger prey → more money. The
progression *is* that loop made visible — and it advances whether you play the hunting loop, the
fishing loop, or both.

---

## How it ties to the formula

Progression is the primary engine for the **30-second-legible / deep-to-master** balance (00 §2)
and for **D1/D7/D30 retention** (00 §0), the hub everything serves.

**The legible / shallow half (hooks the new player):**

- **Visible progress in the first session** (00 §3): a concrete next goal within minutes — a
  starter rifle to buy, a second Destination glowing locked on the World Map. The aspiration hook
  ("I want to go to Alaska") is a progression artifact, surfaced from minute one.
- **Legibility as downvote-avoidance** (00 §4, 01 risk #2): a player who understands *why* they
  can't advance buys or earns the fix; a player one-shot by an unexplained wall rage-quits and
  downvotes. Every gate states its requirement in concrete, actionable nouns — an item to buy, a
  creature to conquer — never an abstract number. This is the **legibility contract** (defined in
  Mechanics §2).

**The deep / mastery half (holds the committed player):** progression's mastery surface is the set
of optimization decisions a returning player makes —

- *Gear-buy ordering:* which slot to upgrade next given the weakest-slot rule and the next gate.
- *Dual-loop arbitrage:* earning Cash on whichever loop is paying better right now (per-loop income
  is balanced by SYS_economy, but moment-to-moment opportunity differs) and funding the other.
- *Apex / co-op runs:* deciding whether to over-gear and solo a tier's apex or assemble a party.
- *Conquest order across a content drop:* which new Destinations to chase first.
- *Rank optimization:* pushing Hunter/Angler Rank for convenience perks and identity titles.

**Where monetization sits, and why it stays clean** (00 §4, 01 monetization map): gear is the gate,
so the thing players pay to accelerate is the thing that advances them — but the gate has two halves
(see §2), and only one of them is purchasable. Payment compresses the **economy grind**; it can
never compress the **play requirement**. That is the structural reason the whole ladder is
convenience-and-access monetization, not pay-to-win.

**Content-engine fit** (00 §7, 01 LiveOps): the gate chain is a data-driven DAG and re-skins reuse
behavior templates, so new tiers slot in as droppable content. This is how the MVL ships three
Destinations and grows from there without rewiring progression.

---

## Mechanics (detailed)

### 1. The gear-tier ladder

**Tier** is the integer 1–8+ rank of a Destination (04, and the ladder in 01). Every equipment item
carries a **Tier** field (Template B) equal to the Destination tier at which it becomes relevant.
Places and gear ride the same integer axis — which is what makes "of course you need an expedition
parka for Alaska" feel earned rather than arbitrary.

**Gear tier** (04) means a player's *effective* tier, computed from equipped items — not the tier of
any single item owned. Because Wild World runs two cross-feeding loops, it is computed **per
discipline**:

- **Effective Hunting Tier (EHT)** = `min(weaponTier, armorTier)`.
- **Effective Fishing Tier (EFT)** = `min(rodTier, reelTier)`.

These are two readouts on one shared spine: one Cash pool funds both (fishing money buys hunting
gear and vice versa) and one Passport tracks both (advancing either loop unlocks the same
Destinations). This is the intended reading of 01's "one currency and one upgrade tree" — unified
*funding* and unified *Destination unlocks*, with gear specializing into a hunting branch and a
fishing branch. (Deliberate interpretation — see Open Questions.)

**The weakest-required-slot rule.** Effective tier is the **minimum** of the gating slots' tiers,
not the max and not the average. Rationale:

- *Max* is gameable and anti-legible: buy one high-tier weapon, keep Tier-1 armor, "qualify," then
  die instantly to the apex. It breaks the promise that meeting a gate means you can function there.
- *Average* produces fractional, mushy tiers a child cannot feel — it fails the 30-second test.
- *Min* is legible ("your armor is Tier 1, so you hunt at Tier 1 — upgrade your armor"),
  exploit-resistant, and creates two honest purchase pressures per loop without any single buy
  trivializing progression.

**Starter and empty-slot semantics.** Tier counts from 1; the absence of a required item is **Tier
0**, and Tier 0 in a gating slot forces the discipline's effective tier to 0 (you cannot hunt with
no weapon; you cannot fish with no rod). To protect the first-five-minutes funnel:

- The player spawns with a **free Tier-1 starter rod + reel** and a **free Tier-1 starter weapon**
  so EHT and EFT are both 1 on arrival and the 60-second first catch/kill is possible without a
  purchase. (The onboarding doc owns the beat sequence; this doc fixes that the starter loadout
  exists and is Tier 1.)
- **Armor is not a gating slot at Tier 1.** Tier-1 floor creatures deal no lethal damage (combat
  owns the number), so a player with no armor still computes EHT = 1 in the Bayou. Armor becomes a
  gating slot from **Tier 2 onward**; below that, an empty armor slot is treated as Tier 1, not Tier
  0. This prevents a "you spawned but can't hunt anything" dead state. The tier at which armor
  begins gating is a tuning parameter.

**Surfacing.** The integer is internal. The player is **never** shown "you are Effective Hunting
Tier 3." Gates render as concrete requirements and a concrete diagnosis:
`✓ Heavy Rifle  ✗ Expedition Parka — your armor is too light for Alaska`. The min-rule is what lets
the UI point at the exact weakest slot. Keep the integer out of the player's face; keep the *item*
and the *one task* in it.

**Non-tier items.** Bait/lure and consumables are **not** tier inputs — a required bait is a
required-item check, not a number that moves EFT. Mounts, Boats, and Tracking Dogs are
**access/convenience**, not effective-tier inputs (see §2 access rules).

### 2. Destination gating, conquest, and the legibility contract

A **Gate** (04) is a structured object on each Destination:

```
Gate {
  offered_loops:           [hunting? fishing?]    # which loops this Destination supports
  required_tier:           <N>                    # the effective-tier threshold
  required_access_items:   [ <item> ]             # e.g. a Boat of tier X; usually empty for entry
  milestone_prerequisite:  <DestinationId | none> # the Destination that must be CONQUERED first
  prerequisite_destinations: [ <id> ]             # which must be UNLOCKED (reachable) first
}
```

A Destination's pin on the **World Map** is **Locked** until its Gate is satisfied, at which point
it is reachable from the **Travel Desk**.

**Conquest = the milestone (unified).** A Destination is **Conquered** when the player completes its
**designated milestone target** — a kill or catch performed *inside* that Destination. The target
defaults to the Destination's apex; a LOC_ doc may instead designate a specific signature creature
or fish. Conquering Destination N *is* the milestone half of the Gate for any Destination that lists
N as its `milestone_prerequisite`. There is one event, not two: the apex kill that is the content
moment is the same act that turns the key for the next Destination. This removes v1's chicken-and-egg
("must kill something you can't yet reach") entirely — you conquer the place you're standing in, and
that unlocks the next.

**The two-part gate — and why it is not pay-to-win.** Every Gate (after the free starter) has two
independent halves:

1. **The gear half** (`required_tier` + access items) — *purchasable*. A player may earn the Cash by
   playing or buy Cash directly (a sanctioned developer product, 00 §4) and reach the gear faster.
2. **The milestone half** (`milestone_prerequisite`) — *not purchasable*. The only way to conquer a
   Destination is to actually take its milestone target in play.

Therefore payment can compress the *economy grind* (how long it takes to afford the gear) but can
**never** skip the *play requirement* (the conquest must be earned). A whale and a free player both
have to down the boar to reach Alaska; the whale just buys the rifle sooner. The gear half is also
**carry-proof on the buyer's side and the milestone half is carry-friendly but non-skippable**: a
high-tier friend can help you conquer a tier's apex (co-op is incentivized, 00 §9), but co-op gets
you the *milestone*, not the *gear* — you still must own the required gear to enter the next
Destination. This two-sided property (can't buy the conquest, can't be carried past the gear) is the
structural guarantee that gear-gating sells convenience and access, not power or skips.

**Dual-loop completability — the Passport advances on one loop.** For a Destination that offers both
loops, the gate is satisfiable end-to-end via **either** discipline:

- `required_tier` is met if **EHT ≥ N OR EFT ≥ N** (you need to be geared on at least one offered
  loop, not both).
- The `milestone` has a designated **hunting target and a designated fishing target**; conquering
  via **either** counts.

A pure fisher can thus unlock and conquer their way up the ladder without ever buying a weapon, and
a pure hunter without ever buying a rod — honoring 01's promise that "a bored hunter can fish and
still progress toward the same goals." A handful of endgame Destinations may be **single-loop**
(e.g. Deep Sea, the fishing culmination); those are completable only on the loop they offer, which
is acceptable because by the endgame a player has engaged both loops. `offered_loops` makes this
explicit per Destination.

**Access items gate entry OR a sub-area within a Destination.** A Boat is *access* monetization (00:
identity > convenience > access). It may gate:

- **Entry** to a Destination, only when the place is physically water-locked, or
- **A sub-area / loop within** a Destination — the common case. A Boat gates Alaska's coastal/deep
  fishing, **not** Alaska itself: a hunter can walk Alaska's interior for moose without owning a
  Boat. The LOC_ doc specifies whether an access item gates entry or a sub-area.

**Mounts and Tracking Dogs never appear in a Gate** — ever, for entry or sub-area. They are pure
convenience (faster traversal, finding rares, tracking wounded game). Letting a convenience item
gate content would edge toward selling advantage in shared content. The line: **access-gating is
acceptable (it opens new content for everyone who buys in); power/convenience-gating is not (it
would let a payer outperform a non-payer in the same content).** Boats sit on the acceptable side
because they unlock *access*, not *advantage*.

**Unlock is a one-time threshold crossing, not a maintained state.** The Gate is checked at the
moment of crossing; once a Destination is in the player's `unlockedDestinations` set it **stays
unlocked** even if the player later sells or unequips the gear that qualified them. Surviving and
profiting *inside* a Destination is governed by the floor/ceiling rule and SYS_combat/SYS_fishing
(your armor still has to keep you alive there), not by re-checking the Gate. This avoids a punishing
"you upgraded and lost Alaska" state and keeps the unlock a durable progression artifact.

**The legibility contract (binding on all downstream UI and LOC_ docs).** Every Locked pin must
state its unmet requirements as **concrete, actionable nouns** — an item to acquire, a Destination
to conquer, an access item to buy — and never as an abstract score. Examples:
`Requires: Iron-tier rifle (or rod) + conquer Appalachia` /
`Requires: a Boat to reach the coast`. If a requirement cannot be phrased as a thing the player can
go do, it does not belong in a Gate.

**The MVL chain and the DAG.** Gates are *data*, and the unlock chain is a **configurable DAG keyed
by `milestone_prerequisite` + `prerequisite_destinations`**, not a hardcoded linear sequence. This
is required by the build plan: the MVL ships **Bayou → Appalachia → Alaska** and inserts **Rockies**
between Appalachia and Alaska post-launch. With gates as data, inserting Rockies = re-pointing
Alaska's `milestone_prerequisite` from Appalachia to Rockies, no code change.

| Destination | Tier | required_tier (EHT or EFT) | Access item | milestone_prerequisite |
|-------------|------|----------------------------|-------------|------------------------|
| Bayou | 1 | none (free starter) | none | none |
| Appalachia | 2 | low entry gear | none | conquer Bayou (light — protects D1) |
| Alaska (MVL) | 4 | expedition-grade | Boat → gates Alaska's *coastal fishing*, not entry | conquer Appalachia *(re-points to Rockies when Rockies ships)* |
| Rockies (post-launch) | 3 | mid gear | none | conquer Appalachia |

Note the MVL makes Alaska a two-tier jump (T2 → T4). That widens the Appalachia→Alaska gear and
difficulty step for MVL only; SYS_economy and SYS_combat must sanity-check that the jump stays
legible and co-op-soluble rather than a wall (flagged below).

### 3. Passport progression

**Passport progression** (04) is the felt sense of advancement, replacing an abstract level number
as the primary readout.

- **Tracked as** two server-owned sets: `unlockedDestinations` and `conqueredDestinations`. Both are
  validated server-side; the client never asserts them.
- **Two states per Destination:** *Unlocked* (Gate met, can travel) and *Conquered* (milestone
  target taken). Conquered is the deeper completion metric and is exactly what feeds the next
  Destination's gate — so the Passport's "conquered" count is also the player's position in the
  unlock chain.
- **Surfaced** in two places: (1) the **World Map** at the Travel Desk — lit pins for unlocked,
  glowing-locked pins (requirements shown per the legibility contract) for the rest; the map is the
  progression spine made visual, with higher-tier pins visible from session one as the aspiration
  pull. (2) A **Passport** readout in **The Lodge** — e.g. "4 of 8 Destinations unlocked / 3
  conquered." This is the number a player quotes to a friend instead of a character level.
- **For a single-loop Destination**, "conquered" is satisfied via the one available loop. For a
  dual-loop Destination, conquering via *either* loop sets the flag (you don't have to conquer it
  twice).

### 4. Hunter Rank and Angler Rank (secondary tracks)

The **optional** light leveling tracks (04). They exist for dopamine, a small perk drip, and
identity — **never as a gate**, **never as balance-affecting power.**

- **What they level off.** Hunter Rank gains XP from kills; Angler Rank from catches. XP per
  kill/catch is weighted by the target's difficulty and rarity (a Mythic >> a Common; an apex > a
  floor creature). XP is earned through **active play only** — idle/AFK accrual feeds Cash
  (economy's domain), never rank or conquest. The XP weight table and level curve are tuning
  parameters; this doc fixes that the input is kills/catches, not Cash and not real money.
- **What perks they grant — identity and convenience only.** This restriction is the hard rule that
  keeps the tracks fun *and* non-pay-to-win:
  - *Identity:* rank titles, badges, Lodge/player flair. Pure status.
  - *Convenience / time-saving:* faster processing, wider tracking radius, a small sell-value bonus,
    reduced spook radius. All save time; none grant combat power.
  - **Forbidden for ranks:** anything raising damage or survivability, anything that satisfies a
    Gate, anything that lets a player take a target their *gear* could not. A rank perk must never
    substitute for a gear tier.
- **Why strictly secondary to gear.** Gear is the gate and the gate is where monetization lives. If
  a rank could substitute for gear, three things break at once: legibility (you'd qualify without
  the gear, muddying "why can't I go yet"), the monetization spine (the thing you pay to accelerate
  would no longer be the thing that gates), and the no-pay-to-win rule (selling XP boosts would sell
  power). Confined to identity + convenience, rank-XP boosts are sellable as a **convenience**
  developer product (reach the title faster, don't win), and rank progression feeds **Premium
  Payouts** (a long-term engagement bar) without touching balance.

The design test for any rank perk proposed downstream: *a high rank with low gear still cannot enter
Alaska and still cannot solo a grizzly.* If a proposed perk would make either sentence false, it is
power, not a rank perk.

### 5. The floor/ceiling difficulty principle

Within each tier there is a **Floor** (the lowest-difficulty reward-granting target) and a
**Ceiling** (the apex). Both rise as tiers climb; the ceiling rises faster than the floor. The
1–100 difficulty numbers are owned by SYS_combat / SYS_fishing; this doc fixes the *relationships*:

- **Floor accessibility (protects new arrivals).** A tier's Floor target is takeable with the
  *previous* tier's gear, or that tier's entry-grade gear. A player who just unlocked a Destination
  must be able to start earning there immediately — no "you unlocked it but everything one-shots
  you," which would re-introduce the wall the gating system exists to prevent.
- **Ceiling pressure (drives the next purchase, drives co-op).** A tier's Ceiling (apex / conquest
  target) requires roughly the *next* tier's gear to take **solo**, OR the current tier's gear
  **with co-op**. This is also why conquest is not a wall for the co-op-willing: a player at tier N
  with N gear and a partner can conquer N's apex and open the path to N+1. A solo player must
  over-gear (push toward N+1 gear) — both routes are legible, and the co-op route is the incentive
  pull (00 §9).
- **Widening spread (the forced-progression engine).** `Ceiling(T) − Floor(T)` **increases with T**.
  Each tier you climb, the distance between its easiest and hardest target grows, so each tier
  demands a real gear step rather than a coast. The widening rate is a tuning parameter.

SYS_combat implements this via "min weapon tier to kill / min armor tier to survive"; SYS_fishing
via "min rod/reel tier to catch." Progression owns the *rule* (apex ≈ T+1 solo, floor ≈ T−1);
the mechanics docs own the *numbers*.

### 6. Re-skinned "bigger & meaner" creatures

Re-skins reuse a lower-tier behavioral template, re-tagged to a higher tier with scaled stats (01:
"there can still be rabbits in Alaska — but bigger, tougher, more aggressive").

- A re-skin's **Tier** equals the Destination it appears in, and it is **balanced and rewarded at
  that displayed tier**, not its origin tier — the Alaska rabbit sits in Alaska's floor band and
  pays an Alaska-floor wage (the Cash number is economy's; the rule that reward tracks displayed
  tier is this doc's). Template C's `Re-skin of:` field links it to the origin only for art/behavior
  reuse, not for balance.
- Re-skins populate a tier's **Floor / low-mid band**, never its apex. The apex must be
  region-iconic (the grizzly, the bear) — it is a content moment and a conquest target, and it
  should feel like the place, not like a scaled-up rabbit.
- Because re-skins are template reuse, they are a primary lever for cheap LiveOps content and for
  giving a new Destination a populated, immediately-approachable floor without bespoke art/behavior
  for every entry.

---

## Inputs / dependencies

First system deep-dive; depends on no other SYS_ doc. It consumes:

- **01_GAME_DESIGN_OVERVIEW** — the Destination tier ladder, the money→gear→access→prey loop, the
  gear-not-XP-bar decision, the boat/mount/dog model, the co-op model, the dual-loop promise.
- **02_DATA_SCHEMA_AND_TEMPLATES** — Template B's per-item `Tier` field (the ladder's atoms), the
  rarity scale (drives rank XP weighting), the 1–100 stat scale and kg units, Template C/D's
  min-tier-to-kill/catch fields (which implement the floor/ceiling rule).
- **04_GLOSSARY** — canonical terms throughout (Gear tier, Passport progression, Gate, Milestone
  kill/catch, Floor/ceiling, etc.).

---

## Outputs / what depends on this

- **SYS_economy** — keys per-tier income bands and the gear pricing curve to this tier axis; prices
  each slot so reaching `EHT = T` / `EFT = T` is a deliberate, affordable-but-felt step; defines the
  pricing curve as a *formula extensible past tier 8* (not a hardcoded table); owns idle/AFK Cash
  accrual (which must not advance rank or conquest).
- **SYS_combat** — implements the floor/ceiling relationships as concrete min-weapon/min-armor tiers
  and damage; sets the Tier-1 "no lethal floor damage" baseline that lets armorless new players
  compute EHT = 1.
- **SYS_fishing** — implements rod/reel tier gates and the fight model against the floor/ceiling
  rule; defines the fishing milestone targets per Destination.
- **EQUIPMENT_MASTER** — every item's `Tier`; the rule that a tier's weapon kills that tier's floor
  but not its apex; the starter Tier-1 loadout items.
- **All LOC_ docs** — fill each Destination's Gate (offered loops, required tier, access items and
  whether they gate entry or a sub-area, the hunting and fishing milestone targets), its
  floor/mid/apex rosters, and its re-skins, all conforming to the rules here and the legibility
  contract.
- **SYS_onboarding_funnel** — relies on the free Tier-1 starter loadout, the armorless-Tier-1
  allowance, light early gates, and the locked-pin aspiration hook.
- **SYS_liveops_calendar** — relies on the gate chain being a data-driven DAG so new Destinations
  drop in without rewiring, and on re-skins for cheap floor population.
- **SYS_lodge_trophy / SYS_trading** — reference Passport state and the tier of rares.
- **World Map / Travel Desk UI** — renders Passport state and enforces the legibility contract.

---

## Tuning parameters

Knobs to instrument and adjust with data; owning doc noted where the *number* lives elsewhere.

- **Gating slots per discipline** — weapon+armor (hunting), rod+reel (fishing). Whether a third slot
  should count. *(this doc)*
- **Armor-gating start tier** — the tier at which an empty armor slot becomes Tier 0 instead of Tier
  1 (currently: gating begins at Tier 2). *(this doc; combat sets the Tier-1 no-lethal-damage number)*
- **required_tier semantics** — OR across offered loops (current) vs. AND. OR honors the dual-loop
  promise; AND would force both loops. Revisit only if playtesting shows OR trivializes a tier.
  *(this doc)*
- **Apex gear delta** — "next tier solo / current tier + co-op," fixed or varying by tier. *(this
  doc; combat implements)*
- **Floor/ceiling spread growth rate** — how fast `Ceiling(T) − Floor(T)` widens per tier.
  *(SYS_combat / SYS_fishing)*
- **Milestone target selection** — apex by default vs. a LOC-designated signature creature/fish; and
  whether the hunting and fishing targets of a dual-loop Destination are equal difficulty.
  *(this doc structurally; LOC_ docs specify)*
- **Unlock trigger** — auto-unlock the instant the Gate is met vs. a one-tap "book the expedition"
  claim at the Travel Desk. *(this doc)*
- **Hunter/Angler XP curve + per-kill/catch XP weights** by difficulty and rarity. *(this doc
  structurally; magnitudes coordinate with SYS_economy)*
- **Rank perk magnitudes** — size of any sell-value bonus, tracking radius, etc. *(SYS_economy owns
  Cash-affecting numbers; combat owns none by rule)*
- **MVL Appalachia→Alaska jump check** — confirm the two-tier MVL gap is legible and co-op-soluble.
  *(SYS_economy + SYS_combat)*

---

## Claude Code build notes

- **Server-authority is mandatory** (ties to SYS_data_integrity). Effective tiers, gate
  satisfaction, Passport sets, and rank XP are computed and stored server-side from equipped items
  and validated event history. The client may *display* a predicted gate state for responsiveness
  but never asserts unlock/conquer/tier. A client claiming "EHT 4" is ignored; the server recomputes
  from equipped item tiers.

- **Suggested state:**
  ```
  PlayerProgression {
    unlockedDestinations: Set<DestinationId>   # permanent once added (one-time threshold)
    conqueredDestinations: Set<DestinationId>  # idempotent; re-killing an apex never re-triggers
    hunterRankXP: int
    anglerRankXP: int
  }
  ```
  Effective tiers are **derived, not stored**: `EHT = min(weapon.tier, armorTierOrFloor)`,
  `EFT = min(rod.tier, reel.tier)`, where `armorTierOrFloor` treats an empty armor slot as Tier 1
  below the armor-gating start tier and Tier 0 at/above it. Deriving avoids a stale-state dupe
  surface; the sets above are the only persisted progression state.

- **Gate evaluation as a pure function:** `evaluateGate(player, destination) -> { unlocked: bool,
  unmetReasons: [string] }`. `unmetReasons` are the legibility-contract strings that power the UI
  directly — the UI never re-derives gate logic, so client and server can't diverge. One source of
  truth for "why can't I go yet." Each unmet reason must be an actionable noun (an item, a conquest,
  an access item), enforced at the schema level.

- **Gates and the chain are config/data, not code.** Each Destination's Gate lives in its LOC_
  config, loaded at runtime; the chain is a DAG keyed by `milestone_prerequisite` +
  `prerequisite_destinations`. Inserting Rockies post-launch = editing Alaska's data, no
  progression-code change. **Build and test both the MVL chain (Bayou→Appalachia→Alaska) and the
  Rockies re-thread before launch** so the insertion path is proven, not assumed.

- **Dual-loop gate logic:** `required_tier` satisfied if `max(EHT, EFT) >= N` for a dual-loop
  Destination (i.e. either loop qualifies), or the single offered loop's effective tier for a
  single-loop Destination. The milestone is satisfied by *either* designated target on a dual-loop
  Destination. Keep `offered_loops` in the data so the logic reads it rather than hardcoding.

- **Rank perk registry is data-driven** and each perk declares a **category** (identity | convenience
  | — power is not a legal value). A perk in a power category is a build-time schema error. This
  makes the no-pay-to-win rule a structural guarantee, not a review-time hope, and lets LiveOps add
  perks without code.

- **Milestone validation** checks the kill/catch against an authoritative server-recorded event (it
  actually happened, inside the Destination, on a legal target), never a client flag; couple with
  the anti-dupe rules in SYS_data_integrity. Conquest is idempotent — Set membership — so farming a
  milestone cannot re-grant anything.

- **Instrument from day one** (00 §0, 01 risk #3): per-tier time-to-unlock; **gate drop-off**
  (players who reach a gate but don't cross it — split by which half, gear vs. milestone, since that
  tells you whether to retune *price* or *difficulty*); EHT/EFT distribution across the population;
  rank-track participation; and dual-loop split (what fraction progress on one loop only). Wire
  telemetry alongside this system, not after.

---

## Open questions / flags

- **"One upgrade tree" interpretation (deliberate, flagged).** I read 01's "one currency and one
  upgrade tree" as unified *funding* + unified *Passport*, gear split into hunting and fishing
  branches. A single literal shared gear stat conflicts with weapons-gate-game / rods-gate-fish and
  with Alaska needing both a rifle and a Boat. If a single shared stat is intended, the gating model
  in §1–2 changes materially. Confirm.

- **OR-gate vs AND-gate on required_tier (deliberate, flagged).** I made a dual-loop Destination's
  tier requirement satisfiable on *either* loop, to honor "a bored hunter can fish and still
  progress." The cost: a pure-single-loop player can reach high tiers having engaged only half the
  content, which thins the cross-loop pull at the high end. If the design intent is that players
  *must* touch both loops to advance, switch to AND — but that contradicts the stated dual-loop
  promise, so I've gone with OR. Confirm the priority.

- **01's Rockies milestone example is inconsistent.** 01 says "unlock the Rockies by owning iron-tier
  gear and downing your first wolf pack," but wolves are in neither the Appalachia roster
  (deer/boar/turkey) nor the Rockies roster (elk/goat/bear) as listed. Under the unified model,
  Rockies' milestone is "conquer Appalachia," whose designated target the LOC_ docs choose — the
  boar is the natural candidate. LOC_02/LOC_03 must reconcile (place wolves in Appalachia, or pick
  the boar). Content issue, not structural.

- **MVL two-tier jump (Appalachia T2 → Alaska T4).** Because the MVL skips Rockies, Alaska's MVL
  milestone is "conquer Appalachia," re-pointing to "conquer Rockies" when Rockies ships. LOC_04
  must specify both, and SYS_economy/SYS_combat must verify the MVL gear/difficulty gap is legible
  and co-op-soluble, not a wall. Highest-risk spot in the MVL ladder.

- **Should effective tier ever be shown?** Decided: internal only, surfaced as concrete gate
  requirements. If playtesting shows players want an at-a-glance rank, reconsider — but resist; a
  visible integer competes with the Passport as the felt progression and pulls the game back toward
  an abstract level bar.

- **Access item: entry-gate vs sub-area, per Destination.** The schema supports both; each LOC_ doc
  must state which for its access items. Specifically confirm whether Alaska's Boat gates only its
  coastal fishing (my assumption, letting a hunter walk the interior Boat-free) or Alaska entry
  outright. 01's wording ("requires first Boat for coastal/deep water") supports sub-area gating.

- **Rank cap / prestige.** Not designed here. Do Hunter/Angler Rank cap, or prestige/loop for repeat
  rewards? Deferred — it's a LiveOps retention knob, best decided with SYS_liveops_calendar once
  live rank-participation data exists.

- **Single-loop endgame Destinations.** The Gate schema supports `offered_loops` with one loop (e.g.
  Deep Sea fishing endgame). Confirm at LOC_07 design time that gating a fishing-only endgame behind
  fishing-only progression is acceptable, and that a pure hunter reaching that point has a reason to
  pick up the rod.

---

## Changes from v1 (for the diff)

- **Unified conquest and milestone into one event.** v1 said the milestone must be "a creature
  reachable in the prior tier"; v2 says conquering Destination N (its designated target, default
  apex) *is* the milestone for the next Destination. Cleaner, removes the chicken-and-egg, ties the
  content moment to the gate key.
- **Made the gate dual-loop-completable (OR, not AND).** v1's schema implied separate hunting and
  fishing tier requirements (read as AND); v2 satisfies `required_tier` on either offered loop and
  the milestone on either designated target — honoring the "fish and still progress" promise.
- **Stated the pay-proof / carry-proof property explicitly** as the structural answer to "is
  gear-gating pay-to-win": gear half is purchasable, milestone half is not; payment compresses the
  grind, never the play; co-op gets the milestone, never the gear.
- **Defined starter and empty-slot tier semantics:** free Tier-1 starter loadout, armor not a gating
  slot at Tier 1, empty-slot = Tier 0. Closes a "spawned but can't play" gap v1 left open.
- **Separated entry-gates from within-Destination access sub-gates;** ruled Mounts/Dogs out of all
  gates and drew the access-OK / power-not-OK line.
- **Made unlock a one-time threshold crossing** that survives later gear changes (v1 left this
  ambiguous).
- **Added the legibility contract** (actionable-noun requirement) as a binding rule on UI and LOC_
  docs, and added a mastery-surface description to the formula section to firm up the deep-to-master
  half.
