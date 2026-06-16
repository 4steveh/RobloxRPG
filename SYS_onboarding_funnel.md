# System: Onboarding Funnel (First Five Minutes)

> Ninth system deep-dive (Phase 1, step 9). Owns the **first session, beat by beat** — the path a
> brand-new player walks from spawn to the point where the habit is either formed or lost. This is
> the operational translation of the whole project's top-line target: **D1 > 25%** (00 §0, §3). If
> the funnel fails, the algorithm buries the game regardless of how good every other system is.
>
> It owns the **first-session PATH through the Bayou**: the opening beat, the order the loops are
> introduced, the first-quest chain that paces comprehension, the first-reward timing target, the
> first-purchase beat, the World-Map aspiration reveal, the daily-quest handoff, and the **D1
> instrumentation** (funnel drop-off per beat, time-to-first-reward, first-purchase conversion). It
> is the place where D1 measurement is *defined* (03 build step 9: "Instrument D1 from here").
>
> It does **not** own: the combat or fishing **mechanics** (it *uses* the ~60-sec first-kill and
> ~60-sec first-catch beats those docs define); **Cash values** (SYS_economy owns every number; this
> doc cites economy's illustrative defaults and never authors a new one); the Bayou's **full content**
> — roster, map geometry, vendor-outpost placement (LOC_01 owns the PLACE; this doc owns the funnel
> *through* the place). The seam with LOC_01 is coordinated explicitly in §Inputs.
>
> **Inherited as binding** (do not re-litigate):
> - **SYS_combat v1.1** — the Bayou is **mechanically non-lethal**: a hard server clamp prevents an
>   armorless player from being downed by any Tier-1 floor creature (combat §4), so death never stalls
>   onboarding; the **first kill lands in ~60 s**; the **punchy clean-kill** (hit-stop, impact VFX,
>   kill reaction, haptics) is the reward beat (combat §1); every lethal threat is telegraphed — and at
>   Tier 1 there are no lethal threats at all. Aim-assist is default ON (combat §1) so the first shot
>   is landable two-thumbed on a phone.
> - **SYS_fishing v1.1** — the **first catch lands in ~60 s** on the free starter rod + reel; the
>   signature verb is sustained tension management (cast → bite → hook-set tap → push/pull reel); there
>   is **no death threat**; losing a fish costs nothing banked (fishing §1).
> - **SYS_economy v2.1** — the **free starter loadout** means no Cash gate at Tier 1 (economy §3;
>   `GearCost_slot` applies only at T ≥ 2); the **first payout lands in ~60 s** (the first kill/catch
>   pays Cash immediately); the **first intra-tier upgrade is the minute-one soft-monetization beat**,
>   priced within the **T1 intra-tier climb = `m·Income(1)` ≈ 2,500 Cash total** (economy §3,
>   EQUIPMENT_MASTER §2); the **not-a-timer rule** is absolute (no energy timers, no rod-recharge
>   waits, no pressure — 00 §4); **daily quests** are a scaled faucet that feed Premium Payouts
>   (economy §1, §6); the **cross-loop daily bonus** rewards breadth (economy §6).
> - **SYS_progression v2.1** — the Bayou is **Tier 1 with no gear gate**; the player spawns with a
>   free Tier-1 loadout and computes **EHT 1 armorless / EFT 1** on arrival (progression §1, Resolved
>   starter semantics); the **World Map is the aspiration surface** and the locked-Destination pull is
>   a progression artifact surfaced from minute one (progression §"How it ties"); the **milestone half
>   of any gate is non-purchasable** — onboarding teaches the spend loop but never sells a conquest.
> - **SYS_data_integrity v1.1** — the **starter loadout grant and the first payout are
>   server-authoritative from session one**: the loadout is granted inside the session-locked profile
>   load (idempotent — re-spawning never re-grants or dupes), and the first Cash is written as an
>   atomic ledger entry by the server reward pipeline, never asserted by the client.
>
> **Illustrative numbers convention** (as in SYS_economy / SYS_combat / SYS_fishing). Concrete
> magnitudes here — reward-timing targets, quest-chain length, the beat at which the World Map
> unlocks — are **illustrative defaults**, flagged in Tuning Parameters. The *funnel structure and
> the three jobs it must accomplish* are the design; the timings are calibration knobs measured
> against live D1 drop-off. Numbers in prose are marked *(default)*. Every Cash figure is **owned by
> SYS_economy** and reproduced here only as a cited default, never re-derived.

---

## Purpose & player-facing goal

The first five minutes are a designed funnel, not an intro cutscene. Their entire job is to convert a
curious tap-from-the-thumbnail into a player who comes back tomorrow. A new player lands in the sunny
Louisiana Bayou and, within the first minute, performs the core action, gets a visible reward, and
understands — without reading anything — what the game is asking of them: **earn Cash → buy gear →
reach bigger places → take bigger prey → earn more**. By the end of the five minutes they have done
the loop a few times on both halves (hunting *and* fishing), made their first small purchase, seen
the World Map with Alaska glowing locked in the distance, and picked up a daily quest that gives them
a concrete reason to return.

The felt experience is *competence and pull*: the player feels good at the thing immediately (the
clean shot, the landed fish) and simultaneously sees a world far bigger than the pond they're
standing in. Competence without pull is a toy they put down; pull without competence is a wall they
bounce off. The funnel must deliver both, in that first session, because the algorithm is measuring.

The player-facing promise the funnel makes — and the rest of the game keeps — is that **fun never
hits a premature, artificial end** (00 §4). Nothing in onboarding (or after) makes the player wait,
recharge, or pay to keep playing. The first purchase is offered as an *upgrade they want*, never a
*gate they're stuck behind*.

---

## How it ties to the formula

This system *is* 00 §3 ("the first five minutes are a designed funnel") made concrete, in direct
service of 00 §0 (D1/D7/D30 is the hub everything serves). The three jobs map one-to-one onto the
three retention levers the Research Foundation names, and the whole doc exists to beat one specific
competitor failure.

- **Comprehension → retention (00 §3, §2).** The loop a seven-year-old grasps in 30 seconds is the
  D1 protector. Onboarding's first job is making **money → gear → access → bigger prey** legible
  through *doing*, not telling. A player who can't answer "what am I trying to do here?" by minute
  two does not come back.
- **Visible progress → the dopamine hit (00 §3).** The ~60-second first reward (combat/fishing/
  economy all converge on this number) is the fast win that says "this game pays off." Then the
  first intra-tier upgrade is a *second*, larger, player-driven win inside five minutes.
- **Soft monetization setup → sell WITH the player (00 §4).** The first purchase is the first
  intra-tier gear upgrade — a thing the player chooses to buy with *earned* Cash, teaching the spend
  loop with zero real-money pressure. It is the seed that *can later* become a real-money
  convenience purchase, never a hard sell. The not-a-timer rule is binding from the first second.
- **The aspiration spine → D7/D30 (01, 05 §3).** The World Map reveal is the "I want to go there"
  pull — our load-bearing differentiator against the flat treadmill. Onboarding's job is to plant it
  early, while the player is still deciding whether this game is worth a tomorrow.
- **Beating Gone Hunting (05 §2).** Gone Hunting pulls 11M visits and **~8.6-minute sessions** —
  people try it and leave. Its diagnosed disease is a flat horizontal treadmill with no aspiration
  spine and no reason the next thing matters. The funnel is the antidote applied at the exact moment
  the bounce happens: comprehension (you understand the objective) + visible progress (you feel the
  payoff) + aspiration (you can see Alaska). **Every beat in this doc is checked against one question:
  does this make the player come back tomorrow?** A beat that doesn't move that needle is cut.
- **The dual loop introduced at birth (01, 05 §3).** The dual cross-feeding loop is the structural
  backbone. Onboarding introduces *both* hunting and fishing in the first session so the player knows
  both exist and both feed one Cash pool — the cross-loop pull starts here, not at Tier 4.

---

## Mechanics (detailed)

### 0. The spawn — server-authoritative from the first frame

The player loads into the Bayou arrival point (LOC_01 owns its location and look). During the
session-locked profile load (SYS_data_integrity), the server confirms the player's
**conqueredDestinations / unlockedDestinations** sets and, for a first-time player, grants the **free
Tier-1 starter loadout** — Starter Rifle (Bolt .22), Starter Cane Rod, Starter Spincast Reel
(EQUIPMENT_MASTER §4; all 0 Cash) — as an **idempotent** grant keyed so a re-spawn or reconnect never
re-grants or dupes. The player is equipped and able to act the instant the world is interactive.
EHT 1 (armorless allowance) and EFT 1 are computed, not stored. There is no name-entry gate, no
class select, no cutscene the player can't skip — the first *action* is the first thing that happens.

**Onboarding state is server-owned too.** A small `OnboardingState` (the tutorial state machine, §
build notes) is part of the session-locked profile so the funnel survives a disconnect: a player who
drops at beat 3 resumes at beat 3, never restarts. This matters for D1 — a forced restart after a
mobile disconnect is a silent churn cause.

### 1. The opening 60 seconds — the first action, the first reward

**The opening beat is a guided first *hunt*, with fishing introduced immediately after.** This is a
design decision, recorded here as this doc's to make (and flagged for playtest in Open Questions):

- **Why hunt first.** The clean kill is the punchier, more legible ~60-second reward (combat §1: the
  hit-stop / impact / kill-reaction flourish is built for exactly this moment). A duck flushing from
  the reeds or a rabbit breaking across open ground is a self-evident target; "point, settle, fire,
  it drops, Cash pops" is comprehension and visible-progress delivered in one beat with no
  explanation required. Fishing's first catch is equally fast (~60 s) but its satisfaction is a
  *sustained* 10-15-second fight — a slightly slower read for second-zero. Lead with the faster
  dopamine, follow with the meatier one.
- **The first quest arrow.** On spawn, a single objective appears — *"Bag your first catch of the
  day"* themed as the day's hunt — with a **world-space arrow / ping** pointing at the nearest
  guaranteed Tier-1 floor spawn (LOC_01 places the spawn; this doc owns that the *first* spawn is
  guaranteed-present and close, not subject to the normal density/respawn wait — a new player must
  never stand in an empty field). One arrow, one target, one verb.
- **The shot.** Aim-assist (default ON, combat §1) makes the two-thumbed shot landable on a phone.
  The Bayou is mechanically non-lethal (combat §4) so even total fumbling — missing, getting close
  to an animal — carries zero death risk; the worst case is the target flees and another guaranteed
  spawn is offered. **Onboarding cannot fail.**
- **The first reward (~60 s, the convergence point).** The animal drops with the full clean-kill
  feedback, and **Cash pops immediately** — the first payout, written server-side as an atomic ledger
  entry (data_integrity), is the visible-progress hit. The amount is SYS_economy's (a Tier-1 routine
  payout); this doc owns only that it is *immediate and visible*, with a clear "+Cash" feedback the
  player cannot miss.
- **Then, immediately, the rod.** The moment the first kill resolves, the next quest beat points the
  player a few steps to the water's edge: *"Now wet a line"* — the first cast. The hook-set tap and
  the first push/pull fight land the **~60-second first catch** on the free starter gear, paying its
  own Cash. Within roughly the first two minutes the player has earned Cash on **both** loops and
  has felt, in their hands, that hunting and fishing are two different verbs feeding one pocket.

**First-reward timing target: ≤ 60 s to first Cash (default), ≤ 120 s to first cross-loop Cash
(default).** These are the headline funnel metrics; they are instrumented per-beat (§build notes).

### 2. The three funnel jobs, delivered

The three jobs (00 §3) are not three separate phases — they are braided through the same beats. This
table is the contract; the prose below it is how each is delivered.

| Job (00 §3) | Delivered by | The metric it protects |
|---|---|---|
| **Comprehension** | the first hunt + first catch (you *do* the loop), then the first vendor visit (you *spend* the loop) — money→gear→access→prey learned by doing | "does the player understand the objective?" → beat-2 drop-off |
| **Visible progress** | ~60-s first Cash, then the first intra-tier upgrade (a second, player-chosen win inside 5 min), then a visibly fuller pocket and a better stat | time-to-first-reward; first-purchase conversion |
| **Soft monetization setup** | the first intra-tier upgrade taught as a *wanted* Cash purchase at the Outfitter / Tackle Shop — the seed of a later real-money convenience buy, never a hard sell | first-purchase conversion; (downstream) D7 spend onset |

**Comprehension.** The objective is taught as a *sentence the player performs*, not a tooltip wall.
Beats 1-2 teach "I act → I get Cash" (both loops). Beat 3 (the first purchase) teaches "Cash → better
gear → I'm more effective" — the player feels the upgraded stat on the very next animal/fish. Beat 4
(the World Map) teaches "gear → access → bigger places → bigger prey." By the end the full loop
sentence has been *experienced*, never lectured. Quest text stays mechanical and short (01: "Catch 5
trout," not narrative) — Roblox kids don't read paragraphs.

**Visible progress.** Two escalating wins inside five minutes: the ~60-second first Cash (given), then
the first intra-tier upgrade (earned and chosen). The second win matters more for D1 than the first
because it is the player's *own decision* producing a *felt* improvement — the first taste of the
agency that holds a committed player. A pocket that visibly grew and a rifle/rod that visibly hits
harder is the dopamine that says "there is a ladder here, and I'm on it."

**Soft monetization setup.** See §3. The key property: it is a setup, not a sale. The player spends
*earned* Cash on a *wanted* upgrade. No real-money prompt appears in the first session. The funnel's
job is to make the spend loop *feel good* so that, later, a convenience purchase (a 2x boost, a
currency pack — economy §7) reads as "more of a good thing," not a wall to pay past.

### 3. The first purchase beat — teaching the spend loop without pressure

Once the player has a few hundred Cash from the opening loops, the quest chain routes them to the
**Outfitter** (weapons/armor) or **Tackle Shop** (rods/reels) — whichever loop they just acted on,
so the lesson is contiguous with the action. (LOC_01 places the vendor outpost; this doc owns that
the first purchase beat *happens here* and *when*.)

- **What they buy.** The **first intra-tier upgrade** to their starter weapon (a better barrel/optic)
  or starter rod/reel — economy's minute-one soft-monetization beat (economy §3; EQUIPMENT_MASTER
  §2). This does **not** change EHT/EFT and **does not** satisfy any gate (it can't — the Bayou has no
  gate, and Tier-1 intra-tier gear never gates anything). It makes the next kill/catch faster: a
  clean, immediate "I bought it, I feel it" reinforcement.
- **The price shape.** The full T1 intra-tier climb is **`m·Income(1)` ≈ 2,500 Cash total** (economy
  §3, default), distributed across discrete steps with **the early steps deliberately cheap** so the
  *first* upgrade is affordable within the first few minutes of earning (economy §3: "early steps
  cheaper for dopamine cadence"). The funnel needs only the *first* step affordable inside five
  minutes; the rest of the climb is the Bayou's ongoing arc (LOC_01 / economy own it). This doc owns
  only the *placement* of the first step inside the funnel — not the 2,500 figure, which is economy's.
- **How it's guided, without pressure.** The vendor visit is a quest beat with the same single-arrow
  treatment, and the first affordable upgrade is highlighted. The player taps to buy with **earned
  Cash**. There is **no real-money offer, no countdown, no "limited time," no obscured price** — the
  not-a-timer rule and the sell-with-the-player rule are absolute here (00 §4). The teaching goal is
  the *mechanic* of spending, so that the player's own brain closes the loop: "earning buys upgrades,
  upgrades make me better, I want to earn more." That internalized loop is what a later, optional
  convenience purchase plugs into.

**Guardrail check (05 §4):** this beat deepens the loop (it teaches the spend decision that is the
economy's depth surface) rather than being a horizontal reskin, and it sets up the trade/identity
monetization that is our moat — it passes. A first beat that *sold* something for real money would be
the predatory pattern the audience downvotes; we explicitly do not do it.

### 4. The aspiration hook — the World Map reveal

The World Map (opened at the Travel Desk) showing **locked Destinations with Alaska / Africa glowing
in the distance** is the "I want to go there" pull (01) and our primary structural answer to Gone
Hunting's missing aspiration spine (05 §3). The World Map *is* the Passport-progression surface
(progression) — how many Destinations you've unlocked and conquered is the felt advancement, and
onboarding's job is to make a new player *want* the second pin. The question is *when* in the first
session it's revealed.

**Default: reveal the World Map at the end of the first purchase beat — roughly minute 3-4, after the
player has felt one full loop-turn (act → earn → upgrade), not before.** The sequencing reasoning:

- Revealing it *too early* (at spawn) is noise — a player who hasn't yet felt the core loop has no
  frame for why a locked Alaska matters, and a big map screen at second zero competes with the
  first-action priority.
- Revealing it *too late* (after five minutes) risks the player bouncing before they ever see the
  pull. The aspiration spine is the D7/D30 hook; it must land *inside the D1 session*.
- The sweet spot is **right after the first purchase closes the comprehension loop**: the player now
  understands money → gear → *better* and is primed to ask "better *for what?*" The World Map answers
  exactly that question at the moment it forms — bigger places, bigger prey, the next pin. The reveal
  is themed as the player's first visit to the Travel Desk in the Lodge (or a Bayou-side travel
  signpost; LOC_01 / SYS_lodge_trophy own the surface), with the second Destination (Appalachia)
  shown *unlockable-soon* and Alaska/Africa shown *locked-and-glowing* far out.

The reveal is **legible** (progression's legibility contract): each locked pin states its requirement
in concrete nouns ("Requires: Tier-2 gear + conquer the Bayou"), so the pull is "I can see the path,"
not "I'm blocked by a mystery." Aspiration plus legibility is the antidote to the flat-treadmill
bounce; mystery walls are the rage-quit pattern we avoid.

### 5. The pull toward both loops — dual loop from the first session

**Recommendation, adopted: onboarding introduces both hunting and fishing in the first session
(§1).** The dual cross-feeding loop is the structural backbone (01), and the cross-loop pull (economy
§6) should *start in onboarding*, not be discovered hours later. Delivery:

- **Both verbs in the first ~2 minutes** (§1): first kill, then first catch, so the player knows both
  exist and both pay into one pocket. The shared-Cash-pool lesson is taught implicitly — the Cash
  from the fish lands in the *same* pocket as the Cash from the kill, and either can buy the first
  upgrade.
- **The cross-loop daily bonus introduced as a daily quest** (§6, economy §6): the day-one daily
  set includes one small hunting objective *and* one small fishing objective, and completing both
  pays the cross-loop breadth kicker (economy's default ≈ 0.5 hrs of current-tier income, scaled).
  This is breadth-as-reward, never focus-as-penalty — a committed single-loop player still progresses
  and merely leaves the bonus on the table.
- **No forced alternation.** After the guided opening, the player is free to play either loop. The
  funnel *introduces* both; it never *requires* both (consistent with progression's OR-gate — a
  single-loop player can ride one loop to endgame). The pull is opportunity, not obligation.

### 6. The early quest chain and the daily-quest handoff

**Structure: a short, linear, mechanical opening chain (the funnel), handing off to the standing
daily-quest system (the retention engine).**

- **The opening chain (the funnel itself), default ~5-7 beats:**
  1. *Bag your first catch of the day* (first hunt → first Cash, ~60 s).
  2. *Wet a line* (first cast → first catch → cross-loop Cash, ~120 s cumulative).
  3. *Gear up* (visit Outfitter/Tackle Shop → buy first intra-tier upgrade → feel the stat).
  4. *See the world* (World Map reveal at the Travel Desk → Appalachia shown unlockable-soon, Alaska
     glowing locked).
  5. *Loop it* (a light "earn a small target" beat — e.g. *bag 3 more / catch 3 more* — that has the
     player run the loop unguided a few times, confirming comprehension stuck).
  6. *Tomorrow's hunt* (introduce the daily-quest board → claim the first daily set, including the
     cross-loop pair → the chain hands off and ends).

  The chain is **mechanical, not narrative** (01): short objective text, single arrows, loop-teaching
  verbs. It is **skippable-by-doing** — a player who already gets it races ahead and the beats
  auto-complete; it never blocks a competent player behind a tutorial they don't need.

- **The daily-quest handoff (the retention hook + economy faucet).** The final funnel beat introduces
  the **daily-quest board** and has the player claim their first daily set. Daily quests are
  *retention gold* (01): a concrete reason to return tomorrow, a scaled Cash faucet (economy §1,
  scaled as a fraction of `Income(T_current)` so they never become a low-tier-farming vector), and a
  Premium-Payout feeder (economy §6). **This handoff is where the funnel's "come back tomorrow" pull
  is made explicit** — the player leaves session one with a stated reason to open session two. The
  daily-quest *content/cadence* is SYS_liveops_calendar's; this doc owns only the *first
  introduction* of the board inside onboarding.

**Length discipline.** The whole opening chain targets **completable in ≤ 5-7 minutes (default)** by
an average new player. Longer and the funnel itself becomes the treadmill it's meant to escape;
shorter and comprehension may not stick. The length is a tuning parameter measured against per-beat
drop-off.

### 7. What onboarding must never do (the D1 killers, stated as rules)

- **Never stall on a death.** Guaranteed by the non-lethal Bayou (combat §4). No respawn walk, no
  downed timer, in the first session.
- **Never stall on an empty field.** The first targets (hunt and fish) are guaranteed-present and
  close; the normal density/respawn cap (combat §5 / fishing §6) does not gate the *first* of each.
- **Never show a real-money prompt in the first session.** The first purchase is earned Cash only.
- **Never present a mystery wall.** Every locked pin and every gate states its requirement in
  concrete nouns (legibility contract). The funnel reveals locks as *legible goals*, never as
  *blocks*.
- **Never force a restart.** Onboarding state is server-side and resumes after a disconnect.
- **Never gate the loop behind a consumable.** Basic ammo/bait is auto-restocked and effectively free
  (not-a-timer rule); a new player can never run dry.
- **Never lecture.** Comprehension is delivered by doing, with short mechanical prompts — not by walls
  of text a 13-year-old skips.

---

## Inputs / dependencies

- **SYS_combat (v1.1)** — the non-lethal Bayou clamp, the ~60-sec first-kill timing and the clean-kill
  reward feedback, telegraphing (moot at T1, no lethal threats), aim-assist default-ON for phone
  playability. The funnel *uses* these beats; it does not set combat numbers.
- **SYS_fishing (v1.1)** — the ~60-sec first-catch timing on free starter gear, the cast → bite →
  hook-set → push/pull fight, no-death / no-punitive-loss. Used, not authored.
- **SYS_economy (v2.1)** — the free starter loadout (no T1 Cash gate), the immediate first payout, the
  T1 intra-tier climb (`m·Income(1)` ≈ 2,500 Cash) whose *first step* is the soft-monetization beat,
  the daily-quest faucet and cross-loop daily bonus, the not-a-timer rule. **Every Cash value is
  economy's**; this doc cites and never re-authors them.
- **SYS_progression (v2.1)** — the Bayou as Tier 1 with no gear gate, the free Tier-1 starter loadout
  + EHT 1 armorless / EFT 1 starter semantics, the World Map as the aspiration surface, the legibility
  contract on locked pins, the non-purchasable milestone half (onboarding never sells a conquest).
- **SYS_data_integrity (v1.1)** — server-authoritative, session-locked, idempotent starter-loadout
  grant and first payout from session one; the `OnboardingState` carried in the session-locked profile
  so the funnel survives disconnects.
- **LOC_01_bayou.md (Phase 2 — coordinate the seam).** LOC_01 owns the **PLACE**: the arrival/spawn
  point, the map geometry, the vendor-outpost location, the Travel-Desk/signpost surface, the specific
  Tier-1 roster, and the per-Destination spawn-density values. This doc owns the **PATH** through it:
  the first-spawn guarantee, the beat order, the reveal timing, the quest-chain shape. **Concrete
  hand-offs to LOC_01:** (1) place a guaranteed-present, close first hunt spawn and first fish spot at
  the arrival point; (2) place the first-purchase vendor within a short walk of the opening loops;
  (3) provide the World-Map/Travel surface reachable by beat 4. These are coordinated, not assumed —
  build LOC_01 and this doc together (03 Phase 2 note).
- **SYS_liveops_calendar.md (later) and SYS_lodge_trophy.md** — own daily-quest *content/cadence* and
  the Lodge/Travel-Desk surface respectively; the funnel introduces the daily board and the World Map
  but does not own their ongoing content.
- **EQUIPMENT_MASTER.md** — the starter loadout stat blocks (Bolt .22, Cane Rod, Spincast Reel) and
  the T1 intra-tier upgrade steps the first-purchase beat draws on.

---

## Outputs / what depends on this

- **The D1 metric and the funnel-drop-off instrumentation are defined here** (03 build step 9:
  "Instrument D1 from here"). Every downstream tuning decision about the opening experience reads this
  doc's per-beat telemetry. This is the origin point for D1 measurement in the whole project.
- **LOC_01_bayou.md** consumes the path requirements (first-spawn guarantee, vendor proximity, reveal
  surface) and must place its content to satisfy them.
- **SYS_liveops_calendar.md** consumes the daily-quest handoff point — the funnel hands the player to
  the daily system, which LiveOps then keeps fed (the daily content is a retention + faucet
  obligation, economy §"inflation as a LiveOps duty").
- **The analytics instrumentation build step (03 step 15)** consumes this doc's metric definitions
  (time-to-first-reward, per-beat drop-off, first-purchase conversion) as the D1 half of the
  D1/D7/D30 dashboard.
- **The MVL launch gate** (03: "Target D1 > 25%; if below ~15%, the loop or onboarding is broken")
  reads directly against this doc's instrumentation. This funnel is the system the launch decision is
  measured on.

---

## Tuning parameters

The knobs, listed explicitly for instrumentation. All defaults are illustrative and calibrated
against live D1 drop-off; Cash figures are SYS_economy's and tuned there, listed here only where the
funnel's *placement* of them is the knob.

- **`TimeToFirstReward`** — target ≤ **60 s** (default) from spawn to first Cash. The headline funnel
  metric.
- **`TimeToFirstCrossLoopReward`** — target ≤ **120 s** (default) to first Cash on the *second* loop
  (first catch after first kill). Confirms the dual loop landed.
- **`OpeningChainLength`** — **5-7 beats** (default); the funnel chain from spawn to daily-quest
  handoff. Too long → the funnel becomes a treadmill; too short → comprehension doesn't stick.
- **`OpeningChainCompletionTarget`** — **≤ 5-7 minutes** (default) for an average new player to
  complete the chain.
- **`FirstSpawnGuaranteeWindow`** — the first hunt and first fish spawn are guaranteed-present and
  proximate (override the normal density/respawn cap for the *first* of each). Distance/latency to
  first target is a knob.
- **`WorldMapRevealBeat`** — **beat 4 / ~minute 3-4** (default), after the first purchase closes the
  comprehension loop. The single most sequencing-sensitive knob; A/B-test against D1.
- **`FirstPurchaseBeat`** — **beat 3** (default); the first intra-tier upgrade visit. Its affordability
  depends on economy's early-step pricing of the T1 climb (the first step must be affordable in the
  first few minutes of earning).
- **`FirstUpgradeAffordabilityTarget`** — the first intra-tier step is affordable within the first
  **few minutes** of opening-loop earning (economy owns the Cash; the funnel owns that the *first
  step* lands inside the session). 
- **`DailyQuestIntroBeat`** — the final funnel beat; the handoff to the standing daily system and the
  explicit "come back tomorrow" pull.
- **`AimAssistOnboardingStrength`** — whether first-session aim-assist is boosted above the standard
  cap to guarantee the first shot lands (a fairness/feel knob; coordinate the cap with combat §1 and
  its platform-split telemetry). Flagged: must not become a permanent crutch — taper to the standard
  cap after onboarding.
- **`OnboardingResumePoint`** — granularity at which a disconnected first-session player resumes (per
  beat, default).

---

## Claude Code build notes

**The tutorial state machine.** Implement `OnboardingState` as a small, server-owned, **data-driven**
state machine carried inside the session-locked profile (SYS_data_integrity), so it survives
disconnects and cannot be client-spoofed.

```
OnboardingState {
  funnelBeat: enum   # FIRST_HUNT, FIRST_CATCH, FIRST_PURCHASE, WORLD_MAP,
                     # LOOP_CONFIRM, DAILY_INTRO, COMPLETE
  beatStartedAt: timestamp   # per-beat dwell, for drop-off telemetry
  completedAt: timestamp?    # set when COMPLETE; never re-runs for a returning player
}
```

- **Beats are config, not code** (mirrors progression's data-driven gate DAG): each beat declares its
  objective, its arrow target, its completion predicate, and its next beat. Adding/reordering a beat
  is a config edit, so the funnel can be A/B-tested without a code change — essential, because the
  reveal-beat and chain-length knobs *will* be tuned against live D1.
- **Server-authoritative completion.** Each beat's completion predicate is checked against
  authoritative server events (a validated kill, a validated catch, a validated purchase ledger
  entry), never a client "I'm done" flag — same discipline as progression's milestone validation. A
  client cannot skip the funnel to claim its rewards, and the funnel's own small rewards (if any) flow
  through the economy's idempotent ledger.
- **Idempotent and one-shot.** `COMPLETE` is a one-time threshold (like an unlocked Destination): a
  returning player never re-enters the funnel, and re-triggering a beat never re-grants. The
  starter-loadout grant is keyed idempotently so reconnect/respawn never dupes (data_integrity).
- **First-spawn guarantee.** Implement the opening hunt/fish targets as funnel-owned guaranteed spawns
  that bypass the normal `MaxConcurrentTargets` / `RespawnInterval` cap for the *first* of each only —
  coordinate with LOC_01's spawn config so this override is scoped to the arrival area and the
  first-time player, and does **not** leak into a low-tier-farming hole (the caps must hold for
  everything after the first guaranteed target).
- **No real-money surface in-funnel.** Gate any store/real-money UI behind `funnelBeat == COMPLETE`
  (or behind the first daily reset) so the first session is provably real-money-prompt-free — a
  structural guarantee of the sell-with-the-player rule, not a review-time hope.

**D1 instrumentation (this is where D1 measurement starts — 03 step 9, 00 §0).** Wire alongside, not
after. The funnel is the most heavily instrumented five minutes in the game.

- **Per-beat funnel drop-off** — for each `funnelBeat`, the fraction of players who enter it but never
  complete it (and dwell time `now − beatStartedAt` before they quit). This is the **primary D1
  diagnostic**: a spike at a specific beat is a specific, fixable confusion point. The beats most
  likely to leak (the D1 killers): first-shot failure-to-land (aim-assist too weak), first-purchase
  confusion (price/UI unclear), World-Map-reveal bounce (revealed too early/late or illegible pins).
- **Time-to-first-reward** — distribution of seconds from spawn to first Cash; alarm if the median
  drifts above the 60-s target. The single most important onboarding chart.
- **Time-to-first-cross-loop-reward** — confirms the dual loop is landing in-session.
- **First-purchase conversion** — fraction of first-session players who complete the first intra-tier
  purchase, and time-to-purchase. Low conversion means the spend loop isn't being taught (or the first
  step is mispriced — escalate to economy).
- **Opening-chain completion rate and time** — fraction reaching `DAILY_INTRO` / `COMPLETE`, and how
  long it took. The headline "did the funnel work" number.
- **D1 return, segmented by where the player ended the first session** — the payoff metric: D1 for
  players who completed the chain vs. dropped at each beat. This is what tells us *which* beat's
  drop-off actually costs tomorrows, so tuning effort goes where it moves D1, not where drop-off is
  merely cosmetically high.
- **Daily-quest claim rate at session 2** — did the "come back tomorrow" handoff actually convert? The
  bridge metric from D1 into D7.

All funnel telemetry must be **separable from steady-state telemetry** (tag events with
`isOnboarding`) so a new-player confusion spike doesn't pollute the economy/combat dashboards and
vice versa.

---

## Open questions / flags

- **Hunt-first vs. fish-first vs. let-the-player-choose is a playtest question, not a settled
  answer.** §1 recommends **hunt first** (punchier ~60-s reward, more self-evident target) with fishing
  immediately after. The alternatives — fish-first (gentler, no-death, but slower-resolving), or a
  *choose-your-first-action* fork — each have a case. A fork respects player agency but doubles the
  first-beat tutoring surface and risks a new player choosing badly and bouncing. **Resolve with an A/B
  test on D1**; this is the highest-value single onboarding experiment. Flagged, not assumed.
- **World-Map reveal timing is the most sequencing-sensitive knob and is provisional.** Beat 4 /
  minute 3-4 is the reasoned default (after comprehension closes, before the session ends), but
  whether the pull lands harder slightly earlier or later is empirical. A/B against D1 and D7 (the
  aspiration spine is a D7/D30 lever surfaced in the D1 window, so watch both).
- **Aim-assist onboarding boost risks becoming a crutch.** Boosting first-session aim-assist guarantees
  the first shot lands (protects the ~60-s reward), but if it's too strong or never tapers, the player
  learns the game is trivial and the skill ceiling (combat's depth surface) never reveals itself —
  a slow-bleed D7 risk. Coordinate the taper with combat §1's cap and platform-split telemetry. Flag.
- **The opening-chain length is a treadmill risk in miniature.** Too many beats and the funnel
  *is* the flat treadmill we're trying to beat (the player is doing tutorial chores, not playing).
  Watch per-beat drop-off and total completion time; if a beat consistently leaks, cut it rather than
  explain it harder.
- **First-purchase affordability depends on economy's early-step pricing of the T1 climb, which is a
  provisional default.** The funnel needs the *first* intra-tier step affordable within the first few
  minutes of earning; economy owns the 2,500-Cash total and its step distribution. If playtest shows
  the first step is unaffordable in-session (first-purchase conversion craters), escalate to economy to
  front-load the T1 climb's cheap steps — do not solve it by inflating the first payout (that would
  ripple into the band). Cross-doc flag with SYS_economy.
- **The LOC_01 seam must be built jointly, not sequentially.** The first-spawn guarantee, vendor
  proximity, and Travel surface are path requirements this doc owns but LOC_01 must physically place.
  If LOC_01 is designed without them, the funnel's timing targets are unachievable. 03 already pairs
  them in Phase 2; this flag is to make the dependency a build-order hard constraint, not a courtesy.
- **Idle/AFK accrual is deliberately *not* introduced in the funnel.** Idle income (economy §6, 00 §2)
  is a return hook, but surfacing "your stuff earns while you're away" in the first five minutes risks
  teaching a new player to *log off* rather than play — exactly wrong for D1. The recommendation is to
  introduce idle accrual at *session 2's* return (the first idle payout the player collects), not in
  session 1. Flagged for coordination with economy/liveops; not owned here, but the funnel's choice to
  withhold it is intentional.
- **Co-op is not introduced in the funnel** (correctly — the Bayou is solo, pack enemies that teach
  grouping live in later tiers per combat §1 / 00 §9). Noted only to record that the omission is
  deliberate, not an oversight.
