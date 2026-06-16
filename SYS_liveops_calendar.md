# System: LiveOps Calendar & Event Framework

> Tenth system deep-dive (Phase 1, step 10) — the **last** Phase-1 system doc, and the one that
> turns nine static system specs into an *operating rhythm*. It owns the **update cadence as an
> operating model**, the **event taxonomy**, the **inflation-control SLA** (the cosmetic/decor
> replenishment cadence that is the economy's single most important inheritance), the **daily-quest
> content/cadence** going forward, and the **scheduling of events within the economy's Cash budget
> ceiling**. It is the system that keeps the game alive after launch (00 §7).
>
> It owns **the schedule and the framework, never the content's mechanics**. It does **not** own: the
> rare-spawn *mechanism* (SYS_combat RD-E / SYS_fishing Decision 3 own it — liveops schedules *when*
> conditions fire); the cosmetic *SKU catalog* (EQUIPMENT_MASTER §4.9, SYS_lodge_trophy — liveops owns
> *cadence*, not art); *Cash values* or the budget-ceiling *number* (SYS_economy); specific
> new-Destination *content* (future LOC_ docs — liveops owns the *slot* in the calendar, not the
> region's rosters).
>
> **Inherited as binding** (do not re-litigate — read for what each doc HANDED here):
> - **SYS_economy v2.1** — the **extensible formulas** (`Income(T)=B·g^(T−1)`; Tier 9+ inherits the
>   curve free, so a new-Destination drop needs *no* economy retune); the **event-payout budget
>   ceiling** (liveops schedules within it; economy owns the number); the **inflation-as-LiveOps-duty**
>   result (§9: shipping new cosmetics/decor on the calendar is an *economic* obligation, not a content
>   nicety, tracked by the `endgame-sink-replenishment cadence` knob and alarmed by
>   `evergreen-sink share of endgame Cash`); **daily quests as a scaled faucet** (a fraction of
>   `Income(T_current)`, feeding Premium Payouts); the **standing** cross-loop daily bonus is economy's,
>   the **scheduled** cross-loop pull is handed *here* (economy §6).
> - **SYS_combat v1.1 / SYS_fishing v1.1** — rares are **independent, condition-gated spawns, never
>   per-kill/per-cast rolls** (combat RD-E, fishing Decision 3): liveops schedules **when conditions
>   fire**, and **never changes the spawn mechanism**; the **archetype / re-skin reuse** and
>   **telegraphed-wall** patterns that make new combat/fishing content a **droppable unit**; **premium
>   bait/consumables can never reach the moat-rares** (fishing Decision 4) — so no event may sell a path
>   to a scarce item.
> - **SYS_lodge_trophy** — the **Lodge is the HOME of the evergreen-sink pipeline**; liveops owns the
>   `decorReplenishCadence` that keeps it from saturating; the deferred **Kennel/Stable "show off rare
>   companions" showcase** is a candidate liveops identity feature; the **decor catalog launch-size vs.
>   ongoing-cadence** call is joint with this doc.
> - **SYS_data_integrity v1.1** — event spawns and seasonal rares inherit **single-mint, one-disposition
>   CAS integrity** with no new code; **event payouts are budget-capped, validated, atomic ledger
>   entries**; a new content drop inherits the integrity layer as a **config drop, not code** (the
>   droppable-unit discipline); **timed entitlements are server-time-authoritative** (no client-asserted
>   event state); a **rare mint writes no Cash** (value realized only on salvage / trade).
> - **SYS_onboarding_funnel** — the **daily-quest board handoff** at the end of the funnel is where
>   liveops takes over the daily content; **idle/AFK accrual is introduced at session 2** (a
>   liveops/economy coordination the funnel deliberately flagged and withheld from session 1);
>   **daily-quest claim rate at session 2** is the D1→D7 bridge metric.
> - **SYS_progression v2.1** — **scarcity discipline**: rares are minted carefully and **NEVER
>   re-released to juice numbers** (00 §5, 01) — the hardest liveops temptation, elevated below to a
>   binding constraint on event design; **Rank cap / prestige is deferred here** (a liveops retention
>   knob, decided with live rank-participation data); the **cross-loop pull is an opportunity to
>   incentivize, never a gate** (so scheduled cross-loop event goals are incentives, never AND-gates).
> - **SYS_trading** — the **auction-house / marketplace is the named post-launch LiveOps system** (never
>   a launch feature); a **light Passport gate on trading** is a flagged anti-wash decision co-owned
>   here; trade is the moat surface scarcity discipline protects.
>
> **Illustrative numbers convention** (as in SYS_economy / SYS_combat / SYS_fishing). Every concrete
> *cadence interval* and *policy threshold* here is an **illustrative default**, flagged in Tuning
> Parameters. The *cadence framework, the event taxonomy, and the scarcity/inflation disciplines* are
> the design; the intervals are calibration knobs measured against live retention and inflation
> telemetry. **This doc authors no Cash value** — every Cash magnitude is SYS_economy's and is cited,
> never re-derived. Numbers in prose are marked *(default)*.
>
> **v1.1 (review pass).** No structural change to the framework. Fixes six seams the first pass left
> loose: (1) the daily-quest and idle reward basis is reconciled with the **OR-gate two-tier (EHT/EFT)
> ambiguity** data_integrity flagged for idle — `T_current` is *not* a settled single value and is no
> longer presented as one (§5, Open Questions); (2) the **inflation SLA is restricted to the
> Cash-priced evergreen subset** — real-money/game-pass cosmetics are revenue but not inflation ballast,
> so they do not count toward the replenishment quota (§4); (3) the **alarm-threshold ownership** is
> corrected — economy owns the *metric*, liveops owns the *trigger threshold* because liveops owns the
> drop response (Tuning); (4) the **cadence axis (§1) and the event-content-kind axis (§2) are made
> explicitly orthogonal** so "seasonal" and "Destination drop" appearing on both is no longer a smear;
> (5) an **illustrative first-quarter calendar** is added (§1.1) — the brief's "illustrate the first few
> cycles" the first pass under-delivered; (6) the **session-2 idle framing is downgraded from claimed
> ownership to a co-owned coordination item**, matching the funnel's "not owned here." Plus a broken
> cross-ref fix (RD2 → §6) and an event-leaderboard server-authority build note. Changes summarized at
> the end.

---

## Resolved Decisions (binding — do not re-litigate downstream)

These are the choices this doc owns. LOC_ docs and the Claude Code event build inherit them as settled;
if a future need forces a change, change it here first and propagate.

1. **New scarcity, never diluted scarcity — the scarcity-discipline rule for events (THE liveops-specific
   moat constraint).** A limited-time event may do exactly two things with scarce content, and never a
   third:
   - **(a) Open a NEW spawn window for an existing rare at its existing, unchanged 1-in-N.** The
     legendary buck that normally appears at dawn can be scheduled to appear during a weekend event — but
     it spawns at the *same* per-encounter rarity it always has. This is *more chances to encounter the
     same scarce thing*, not more of the thing minted cheaply. The per-encounter scarcity, and therefore
     the value held by existing owners, is untouched. (This is just the condition-gated mechanism
     combat/fishing already own — liveops schedules the predicate's window; it does not change the rate.)
   - **(b) Mint a GENUINELY NEW scarce item** (an event-exclusive trophy, cosmetic, or rare breed) that
     becomes **permanently scarce** after the window closes — a new artifact with its *own* permanent
     scarcity, not a re-issue of an existing one.
   - **FORBIDDEN (a structural rejection, not a willpower test):** altering an *existing* rare's 1-in-N
     (making it commoner), increasing the live supply of an *already-minted, already-traded* rare, or
     re-running a "limited" event in a way that re-mints a previously-limited item and dilutes its
     existing holders. *Re-releasing a hyped legendary for an event spike destroys its trade value and
     the moat.* This is the single discipline test the whole trade economy depends on (00 §5, Adopt Me's
     discipline), and liveops is precisely where the pressure to break it arrives.

   **Made structural, not hoped for** (mirrors the schema-error pattern the rest of the corpus uses): a
   liveops event config may *reference an existing rare's spawn predicate* (schedule a window) and may
   *introduce a new artifact catalog entry* (new scarce item), but it **MUST NOT edit an existing
   artifact's `rarity` / `1-in-N` / mint accounting**. An event config that raises the live mint cap or
   lowers the 1-in-N of an already-minted artifact id is a **build-time schema error**, the same class
   of guard EQUIPMENT_MASTER and SYS_data_integrity use elsewhere. The discipline is enforced by the
   config schema, not by remembering to be disciplined.

2. **Events deliver value primarily as scarce/identity items, not Cash — this is the structural way
   event Cash stays under the economy's budget ceiling.** The reward an event is *for* is a content
   moment, a new scarce trophy, a cosmetic, prestige, or a leaderboard placing — not a Cash dump. Cash
   is at most a thin participation reward. This is not a nicety: it is the mechanism that keeps event
   payouts bounded (§6), because most event value never touches the Cash faucet at all (a minted rare
   writes no Cash — data_integrity v1.1; its value flows to trade and the Trophy Hall). An event whose
   primary reward is Cash is the wrong shape and pressures the ceiling.

3. **The cosmetic/decor replenishment is the highest-priority recurring beat — an economic obligation
   outranks a content nicety.** When the calendar is resource-constrained (a small team, a slipped
   sprint), the order of what-ships-first is: **decor/cosmetic replenishment cycle → seasonal
   condition-gated windows → daily-quest rotation → the spectacle/limited-time event → the Destination
   drop**. Rationale: a missed event costs a retention *bump* (recoverable); a missed decor cycle lets
   the endgame evergreen sink saturate and **endgame inflation resumes, which corrodes the trade moat**
   (economy §9) — a structural, compounding loss, not a recoverable one. The inflation SLA is the one
   calendar commitment that is non-negotiable.

4. **Everything is data-driven config: a new event, season, or Destination is a CONFIG DROP, not code.**
   This is the droppable-unit discipline (00 §7) that makes the weekly cadence *achievable* rather than
   aspirational. An event is a scheduling/predicate/reward-budget config that the live game loads; it
   ships without a code deploy. **Corollary and standing risk:** any upstream system that requires *code
   per event* silently downgrades the achievable cadence from weekly toward monthly toward stale. The
   config-not-code property is a cross-doc invariant this doc depends on and asserts back onto every
   system it schedules (see §7 and Open Questions).

---

## Purpose & player-facing goal

The LiveOps calendar is the game's heartbeat — the reason there is *always something happening* and a
reason to come back this week that wasn't here last week. Its player-facing job is to make the world
feel **operated, not abandoned**: a salmon run is on this month, a blood-moon predator event is live
this weekend, a fresh set of daily quests is up, the new Alaska lodge-theme decor just dropped, and the
Rockies are opening next month with a launch event. To a player, the calendar is invisible as a system
and total as an atmosphere — the game is *alive*.

Internally, this is the system that converts a **launch spike into a multi-year franchise** (00 §7). It
is operational, not creative: a release *calendar*, not a patch *schedule* (the Big Games / Pet Sim 99
discipline 00 §7 names). It schedules across nearly every other system — it does not build their
mechanics; it decides *when* their content goes live, *how often* new content ships, and *which*
beat carries each week. Its second, load-bearing job is **economic**: it carries the inflation-control
SLA that keeps Cash feeling earned forever, which is what keeps rares rare and the trade moat alive
(economy §9).

The felt experience the calendar protects: a lapsed player gets a notification that the Rockies just
opened, returns, finds their lodge wall and gear exactly where they left them, and has a fresh
continent and a launch event waiting — the return hook that is the D7/D30 retention signal made into a
scheduled marketing beat.

---

## How it ties to the formula

- **Cadence is the launch-spike-to-franchise line (00 §7).** Roblox punishes staleness because
  shipping is cheap; weekly is ideal, monthly is the floor, and elite teams run a calendar. This doc
  *is* that calendar. It is "where most indie devs lose," and the config-not-code discipline (Resolved
  Decision 4) is what makes the elite cadence survivable for a small team.
- **Events are the content-moment / creator-content engine (00 §6).** A limited-time spectacle event
  manufactures urgency *and* gives creators something to film simultaneously — a competitive event,
  a blood-moon predator night, a 1-in-N event-exclusive reveal are YouTube/TikTok content by design.
  The calendar is the schedule of manufactured moments that feed the discovery flywheel.
- **Scarcity discipline is the moat (00 §5).** This is the doc where the temptation to dilute scarcity
  for a number spike actually arrives, so it is the doc that has to hold the line. Resolved Decision 1
  is that line, made structural.
- **Retention is the hub (00 §0).** Events, seasonal content, the daily-quest rotation, and Destination
  drops are the **D7/D30 return-hook engine** — the standing reasons to come back this week and the
  lapsed-player reactivation beats. The daily-quest handoff inherited from onboarding is the D1→D7
  bridge; the calendar is what makes D7 convert to D30.
- **Sell WITH the player (00 §4).** The calendar's monetization surface is the cosmetic/decor drop
  (identity, the safest money) — and that same drop *is* the inflation ballast. Events sell nothing
  predatory: no energy timers, no "pay to enter the event," no pay-to-rare (premium bait can't reach
  moat-rares — fishing Decision 4). The event-exclusive scarce item is earned by *playing the window*,
  not bought.
- **Anti-treadmill (05 §2–§4).** Gone Hunting is a static solo treadmill that leaked to ~160 CCU;
  Fisch thrives on relentless cadence. The calendar is the structural answer to "static" — it is the
  cadence half of the contrast that *is* the lesson (05 §2). Every scheduled beat is checked against
  05 §4: does it produce a content moment or a trade interaction, or is it horizontal reskin?

---

## Mechanics (detailed)

### 1. The cadence framework — what ships weekly vs. monthly vs. seasonally

The calendar runs four nested cadences. Each has a different cost, frequency, and job. The point of the
nesting is that the **cheap, high-frequency layers defeat staleness every week** while the **expensive,
low-frequency layers carry the marquee moments** — so the game never feels static even between the big
drops.

| Cadence | Default interval | What ships | Cost / nature | Primary job |
|---|---|---|---|---|
| **Weekly heartbeat** | every 1 week *(default)* | a fresh **daily-quest rotation** (§5); the active **condition-gated spawn windows** for the week (§3.1); a **small cosmetic/decor replenishment** (a few SKUs); roughly every 1–2 weeks a **limited-time event** (§3.3) | mostly pure config: schedule entries, predicate activations, a few catalog rows flipped live | defeat weekly staleness (00 §7); keep the daily hook fresh |
| **Monthly marquee** | every ~1 month *(default; 00's floor)* | a larger **limited-time / competitive event** (the spectacle, §3.3) **or** a **Destination drop** (§3.4); a **themed cosmetic collection** (a room theme — the high-value identity unit, lodge_trophy §3) | a real content beat; config + assets, no engine code (Resolved Decision 4) | the monthly content moment + the inflation-SLA anchor drop |
| **Seasonal tie-in** | real-world season windows | real hunting/fishing **season content** — salmon runs, migrations, real-season openers (§3.2), tied to *real* calendar dates | condition-gated spawns scheduled at calendar scale; "a year-round content schedule for free" (01) | the year-round return-hook spine, themed to the real world |
| **Destination drop** | every ~1 quarter *(default; content-readiness-gated)* | a **new region** (Rockies first — §3.4): a scheduled launch event, a marketing beat, a lapsed-player return hook | the largest droppable unit; inherits economy/progression/integrity layers with no retune | the modular content engine (00 §7, 01); the franchise's growth |

The intervals are **illustrative defaults** (Tuning Parameters). 00 §7 sets the targets: **weekly is the
aim, monthly is the floor.** A week with no marquee beat is fine — the heartbeat layer carries it. A
*month* with no marquee beat is the floor being missed, and is an alarm.

**How a Destination drop slots in** (the modular-content-engine claim, made concrete): a new region is a
config bundle — its LOC_ config (rosters, map, gates), its EQUIPMENT_MASTER region-gear rows, its
condition-gated rare predicates — loaded into the live game on a scheduled date. Because income/pricing
are formulas keyed to the tier axis (economy §2), **Tier 9+ inherits the curve untouched**; because the
gate chain is a data-driven DAG (progression build notes), the drop **re-threads the chain** (e.g.
Rockies inserts between Appalachia and Alaska by editing Alaska's `milestone_prerequisite`); because
event spawns inherit the integrity layer (data_integrity), the drop's rares are single-mint with **no
new anti-dupe code**. The drop is a *launch event* (a marquee beat) wrapped around a *content config
bundle* — that wrapping is the marketing/return-hook value, and the bundle is the droppable unit.

**Two orthogonal axes — read §1 and §2 together, not as one list.** §1 (above) is the **time
structure**: the buckets a beat ships *into*. §2 (below) is the **content-type taxonomy**: the *kinds*
of beat. The two axes are orthogonal, and the mapping between them is: condition-gated windows (§3.1)
and limited-time events (§3.3) are *scheduled into* the weekly/monthly buckets; seasonal content (§3.2)
and Destination drops (§3.4) are large enough that they constitute *their own* cadence tier. That is
why "seasonal" and "Destination drop" appear as labels on both axes — not a duplication, but a content
kind whose size makes it also a cadence. Daily-quest rotation (§5) and the decor replenishment (§4) are
**standing systems the calendar feeds on the weekly/monthly cadence — they are not "events"** and sit
outside the §2 taxonomy by design.

### 1.1 Illustrative first quarter (NOT a commitment — the engine made concrete)

Per scope discipline, this doc specifies the *engine*; the calendar below illustrates *how the
cadences interleave* for roughly the first post-launch quarter, so the framework is concrete rather
than abstract. **It is illustrative, not a content plan** — actual beats depend on content readiness
(Open Questions: launch-vs-ongoing volume) and live telemetry. Intervals are the §Tuning defaults.

| Week | Weekly heartbeat (always) | Marquee / seasonal beat | Notes |
|---|---|---|---|
| **1 (launch)** | daily rotation; small decor batch; first condition-gated windows live (dawn buck, storm muskie) | — (launch *is* the beat) | seed the decor catalog adequately so the sink functions from day one (lodge_trophy launch-size flag) |
| **2** | daily rotation; decor batch | first **limited-time event** (a weekend competitive trophy-weight event) | rehearses the event-config path end to end at low stakes |
| **3** | daily rotation; decor batch | **seasonal window opens** if real-calendar aligned (e.g. a salmon-run tie-in) | seasonal is months-long; it opens here and persists |
| **4** | daily rotation; decor batch | **monthly marquee: a room-theme drop** (the high-value identity unit) — the inflation-SLA anchor | RD3: this beat ships even if the team is stretched |
| **5–7** | daily rotation; decor batches; a blood-moon predator weekend ~week 6 | seasonal continues | heartbeat carries weeks with no marquee |
| **8** | daily rotation; decor batch | **monthly marquee: a themed cosmetic collection** | watch `evergreen-sink share`; if it has fallen, the marquee is pulled-forward decor (§4 alarm) |
| **9–11** | daily rotation; decor batches | seasonal closes; a second limited-time event | begin lapsed-player pre-drop teasing |
| **~12** | daily rotation; decor batch | **Destination drop: the Rockies** — a launch event wrapping the LOC_03 config bundle | the pipeline acceptance test (§3.4); re-threads the gate DAG; lapsed-player return hook |

The pattern the table encodes: the **heartbeat never skips** (defeats weekly staleness); a **marquee
beat lands roughly monthly** (00's floor); **seasonal content runs underneath at calendar scale**; and
the **first Destination drop lands at the quarter boundary**, rehearsing the update pipeline (03). The
decor beat is present every cycle because it is the non-negotiable economic obligation (RD3, §4), not
because the calendar happens to have room for it.

### 2. The event taxonomy — the four kinds of scheduled event content

The calendar schedules exactly four kinds of scheduled **event** content (daily-quest rotation and
decor replenishment are standing systems it feeds, not events — see the orthogonality note above).
Liveops owns **the schedule of each**; it owns **the mechanism of none** (those belong upstream). This
separation is the spine of the whole doc.

| Kind | What it is | The mechanism (owned upstream) | What liveops owns |
|---|---|---|---|
| **Condition-gated rare-spawn window** (§3.1) | a scheduled period in which a rare's spawn condition is active (dawn legendary buck, storm muskie, blood-moon predator) | combat RD-E / fishing Decision 3 — independent condition-gated spawns, the 1-in-N, the predicate | **when** the condition fires (the window's open/close on the calendar); **never** the rate or the mechanism |
| **Seasonal content** (§3.2) | real hunting/fishing-season tie-ins (salmon run, migration) scheduled to real-world dates | same condition-gated spawn mechanism, at calendar scale | the real-season → in-game-window mapping and its calendar placement |
| **Limited-time event** (§3.3) | a manufactured moment — a competitive/spectacle event with urgency, an event-exclusive scarce item, a leaderboard | combat/fishing spawns; lodge/trading surfaces; economy payout rules | the event's existence, window, theme, reward *budget* (within the ceiling), and its **new scarcity** (Resolved Decision 1) |
| **Destination drop** (§3.4) | a new region as a scheduled launch event | LOC_/economy/progression/integrity layers (config bundle) | the drop's **slot** in the calendar and its launch-event wrapper; **not** the region's rosters |

### 3. Each kind, specified

**3.1 Condition-gated rare-spawn windows — liveops schedules the SCHEDULE, never the mechanism.**
Combat RD-E and fishing Decision 3 are emphatic and binding: rares are *independent, condition-gated
spawns layered on the routine population* — never a per-kill or per-cast upgrade roll, because that
would couple rare frequency to play *rate* and break the economy's band normalization (economy RD5).
The mechanism *is already the schedule hook*: a rare's spawn predicate is `time/weather/season/event`.
**Combat/fishing own the predicate's definition and the 1-in-N it gates; liveops owns the
*activation schedule* that drives it** — the `event` clause's on/off and the calendar placement of the
`time/weather/season` windows: when the dawn buck's dawn is "live this weekend," when the storm that
makes the muskie bite is scheduled, when the blood-moon predator night opens. Liveops **never** edits
the 1-in-N, the spawn entry, or the layering. The window is a config entry that flips a predicate
active; the rate the predicate gates is untouchable (Resolved Decision 1).

**3.2 Seasonal content — the year-round schedule, for free.** 01 promises that tying spawns to *real*
hunting/fishing seasons yields "a year-round content schedule for free." This is that schedule: the
salmon run scheduled to the real fall run, a migration event to its real season, a real-season opener.
Mechanically these are 3.1 windows placed at *real-calendar* scale — a months-long seasonal window
rather than a weekend. The value is double: the content is themed to something players recognize from
the real world (the same real-world-legibility that does the motivational work elsewhere — 01), and the
schedule writes itself from the real calendar, so it is the cheapest possible year-round return-hook
spine. The daily-quest board (§5) themes to the active season, tying the standing hook to the calendar.

**3.3 Limited-time events — the spectacle / content-moment / creator-content engine (00 §6).** A
manufactured moment that drives urgency *and* creator content simultaneously: a weekend competitive
event (most trophy weight landed, a leaderboard), a blood-moon aggressive-predator night, an
event-exclusive 1-in-N reveal designed for the thumbnail. Its reward is value *as a content moment and
a scarce/identity item*, not Cash (Resolved Decision 2). The event's **new scarcity** obeys Resolved
Decision 1 absolutely: it either opens a new window for an existing rare at unchanged rarity, or mints a
genuinely new, permanently-scarce event-exclusive — **never** a dilutive re-release. A competitive
event is also a candidate surface for spotlighting otherwise-thin content (the co-op-only grizzly apex
that combat flag #3 worries may be "dead content" at low CCU can be the centerpiece of a co-op event —
**without** NPC-assist or matchmaking, which combat rules out for MVL).

**3.4 Destination drops — the modular LiveOps content engine.** Specified in §1 (how it slots in). Each
drop is the largest marquee unit: a marketing beat (a new continent), a lapsed-player return hook (the
reason a churned player reopens the app), and a rehearsal-then-routine of the update pipeline. **Rockies
is the first drop** (03: deliberately skipped for the MVL so that shipping it *rehearses the update
pipeline early*, on real content, while the team is small and the stakes are low). The drop proves the
config-not-code claim end to end: if Rockies needs engine changes to ship, the droppable-unit discipline
has a hole and the whole cadence model is at risk — so the first drop is also the first real test of
Resolved Decision 4.

### 4. The inflation-control SLA — the single most important thing liveops inherits

Economy §9 and lodge_trophy §3 both established, independently, that **shipping new cosmetics/decor on
the calendar is an economic DUTY, not a content nicety.** The derivation (economy §9): at endgame, gear
buying plateaus, so the gear sink → 0, and the only sinks left are the **evergreen** cosmetic/decor
sinks. Those are evergreen *only if continuously replenished* — a fixed catalog saturates (players buy
everything they want, then accumulate Cash with nothing to absorb it), and **endgame inflation resumes,
which corrodes the rare prices that are the trade moat.** Therefore the catalog must keep growing, and
keeping it growing is liveops's job. **Liveops owns the cadence; it does not own the art** (the SKUs are
EQUIPMENT_MASTER §4.9 / lodge_trophy §3; liveops schedules *when batches ship*).

**The SLA counts the Cash-priced evergreen subset only.** EQUIPMENT_MASTER §4.9 includes both
Cash-priced decor and **game-pass flagship cosmetics** (e.g. a premium rifle skin). Only the
**Cash-priced** items are inflation ballast — they are the sink that *removes Cash*; a real-money
game-pass cosmetic is welcome **revenue** but removes no Cash and does **nothing** for the inflation
condition. So the replenishment quota (`decorReplenishCadence`) is satisfied only by **Cash-priced**
new SKUs. A cycle that ships five game-pass skins and no Cash decor has met a revenue goal and
**missed the economic SLA** — and the `evergreen-sink share` alarm will eventually fire. Do not let
real-money cosmetic output disguise a stalled Cash-sink pipeline.

**How the calendar guarantees the catalog keeps growing — a baseline quota plus an alarm override:**

1. **Baseline guarantee (the quota).** A standing **per-cycle SKU quota** is baked into the weekly and
   monthly cadences: at least a small evergreen-decor batch every weekly heartbeat and at least one
   **room theme** (the high-value identity unit) every monthly marquee *(default cadence — the
   `decorReplenishCadence` knob, which is economy's `endgame-sink-replenishment cadence` surfaced here)*.
   This is the steady drip that keeps the sink ahead of accumulation by default. It is the **highest-
   priority recurring beat** (Resolved Decision 3): when resources are tight, the decor cycle ships
   before the spectacle event.
2. **Alarm override (the canary triggers a drop).** The baseline quota is calibrated, not omniscient —
   player taste and accumulation rates drift. So the quota is backed by an alarm: **`evergreen-sink
   share of endgame Cash`** (economy §9 canary; lodge_trophy §3 surfaces it as that system's primary
   health metric). When top-tier players *stop* routing Cash into decor/slots — the share falls below
   threshold — the catalog has saturated *faster than the baseline quota anticipated*, and that **fires
   an out-of-band decor/theme drop, pulled forward ahead of the normal cadence.** The alarm is the
   safety net under the baseline; together they make "the catalog always keeps growing" a guarantee with
   a feedback loop, not a hope. (Rising rare-price trend on the Trading Post is the corroborating
   second canary — economy §9 — and a leading indicator that endgame Cash is reaching the trade economy.)

This is the load-bearing reason this doc exists past "scheduling fun events": **the calendar is the
mechanism by which the economy stays non-inflationary forever.**

### 5. Daily-quest content & cadence — the standing hook liveops inherits from onboarding

Onboarding owns the **first introduction** of the daily-quest board (its final funnel beat,
`DAILY_INTRO`); **liveops owns the content and cadence from there forward** (the standing retention hook
+ scaled Cash faucet + Premium-Payout feeder + the cross-loop daily pair — economy §1/§6). The daily
board is the connective tissue between the standing hook and the live calendar.

- **The daily set** *(default ~3 quests/day)*: at least **one hunting objective and one fishing
  objective** so the **cross-loop daily pair** (economy §6) is always present — completing both pays the
  cross-loop breadth kicker (economy's standing bonus; *breadth-as-reward, never focus-as-penalty*). A
  third flexible/either-loop quest rounds the set.
- **Scaling and faucet discipline (economy's, applied here):** each daily reward is **a fraction of
  current-tier income** (economy §1) — so dailies stay relevant at every tier and **never become a
  low-tier-farming vector**. Liveops sets the *quest content and rotation*; economy owns the *reward
  scale*. **Caveat (a real open seam, not a settled value):** under the OR-gate a player has *two*
  effective tiers (EHT, EFT) that can differ widely (EHT 4 / EFT 1), so "current tier" is **not a
  single number** — it is the same `T_current` basis data_integrity flagged as underspecified for idle
  (its Open Questions: `max(EHT,EFT)` vs. highest *conquered* tier vs. a blend). The daily-quest scale
  inherits that same unresolved basis; it is **economy's formula call**, flagged here (Open Questions)
  so liveops does not paper over it with a crisp-looking `Income(T_current)` that hides the ambiguity.
  Dailies feed **Premium Payouts** (economy §6) by rewarding the exact return-and-engage behavior
  Premium pays for.
- **Rotation and calendar-theming:** the set refreshes daily; during an active seasonal/limited-time
  beat, the daily board **themes to it** (salmon-run dailies during the run, event dailies during an
  event), which is what makes the standing hook feel part of the live calendar rather than a static
  chore. *Keep quests mechanical, not literary* (01: "Catch 5 trout," not narrative).
- **The session-2 idle introduction (a coordination point, not sole ownership):** onboarding
  *deliberately withholds* idle/AFK accrual from session 1 (surfacing "your stuff earns while you're
  away" in the first five minutes risks teaching a new player to log *off* — funnel Open Questions). The
  funnel recommends introducing it at **session 2's return** (the first idle payout the player collects).
  The funnel explicitly left this **"not owned here … flagged for coordination with economy/liveops,"**
  so this doc does **not** claim settled ownership: the **proposed** division is that liveops carries the
  *return-moment framing* (the idle payout as a scheduled "welcome back" beat alongside the daily claim)
  and economy owns the *Cash* (`idleFraction` / `idleCapHours` faucet). Named here as the co-owned
  coordination item the funnel flagged (Open Questions), not re-authored and not unilaterally claimed.

### 6. Event payout budgets — how event Cash stays bounded

Economy set a **per-event budget ceiling** so an event can't flood the Cash supply (economy §1 faucet
table: "economy owns the per-event budget ceiling"). **Liveops schedules events within that ceiling;
economy owns the ceiling number.** The mechanism is three-layered:

1. **Structural (the primary defense).** Events deliver value as scarce/identity items, not Cash
   (Resolved Decision 2). Because a rare mint writes **no Cash** (data_integrity v1.1 — value is
   realized only on salvage/trade, and the salvage floor is deliberately low so value flows to the
   moat, not the faucet), the bulk of an event's value **never touches the Cash faucet at all.** Most
   event Cash exposure is eliminated by the reward *shape*, before any budgeting.
2. **Per-event budget.** Each scheduled event config carries a **declared Cash budget** for its thin
   participation rewards; the event's payouts are **budget-capped, validated, atomic ledger entries**
   (data_integrity) tagged as event faucet, so event Cash is separable in telemetry and bounded per
   event by construction.
3. **Aggregate-overlap check.** The scheduler validates that the **sum of concurrently-active event Cash
   faucets stays within the ceiling** before activating overlapping events — two events running at once
   cannot stack their faucets past the bound. Overlapping windows are allowed (they're good for the
   calendar feeling alive); overlapping *Cash* is what's bounded.

### 7. The scheduling / activation mechanism

All four event kinds activate through one mechanism: **time-gated and/or condition-gated, server-
authoritative, no client-asserted event state.** An event is a config record with an activation window
(start/end against **server time**), an optional condition predicate (the `event` clause combat/fishing
read on their spawns), a declared reward budget, and its new-scarcity declaration (Resolved Decision 1).
The server owns whether an event is live; the client **displays** event state but never asserts it (a
client claiming "the blood-moon event is active for me" is ignored — the same server-authority discipline
every other system uses). Timed entitlements (event multipliers, window-bounded boosts) are **server-time
entitlements** (data_integrity — offline time counts; logging off banks nothing), so no client-reported
time can extend an event for a player.

---

## Inputs / dependencies

- **00 (§7 cadence-as-calendar, §6 events-as-content-moments, §5 scarcity-as-moat), 01 (modular-
  Destination LiveOps, seasonal/real-season spawns, scarcity discipline), 02 (Template F, Template E for
  any event rare, fixed units), 04 (LiveOps, Content moment, Scarcity discipline, Destination — canonical
  terms), 05 (§2 the static-treadmill failure this doc's cadence beats; §4 the content-moment/trade-
  interaction guardrail).**
- **SYS_economy v2.1** — the **extensible formulas** (Tier 9+ free, no retune for a drop); the
  **event-payout budget ceiling** (the number); the **inflation-as-LiveOps-duty** result and the
  `endgame-sink-replenishment cadence` knob; the **`evergreen-sink share of endgame Cash`** alarm; the
  **daily-quest reward scale** (fraction of `Income(T_current)`); the **standing** cross-loop bonus (the
  **scheduled** pull is handed here); the `idleFraction`/`idleCapHours` faucet for the session-2 beat.
- **SYS_combat v1.1 / SYS_fishing v1.1** — the **condition-gated spawn mechanism** (RD-E / Decision 3)
  whose *windows* this doc schedules and whose *rates/entries* it never touches; the **archetype/re-skin
  reuse** and **telegraphed-wall** patterns (droppable combat/fishing content); **premium consumables
  never reach moat-rares** (no event pay-to-rare); the co-op-apex content (combat flag #3) as an event
  spotlight candidate; the single-loop-endgame-reach flag (fishing Open Questions) as a scheduled
  cross-loop-incentive candidate.
- **SYS_data_integrity v1.1** — **single-mint / one-disposition CAS integrity** inherited by every event
  spawn and seasonal rare with **no new code**; **event payouts as budget-capped atomic ledger entries**;
  **server-time-authoritative timed entitlements**; the **config-drop-not-code** integrity-layer
  inheritance (a new drop adds no anti-dupe surface).
- **SYS_lodge_trophy** — the **Lodge as the home of the evergreen-sink pipeline**; the
  `decorReplenishCadence` knob and the decor-catalog **launch-size-vs-ongoing-cadence** joint call; the
  **Kennel/Stable showcase** as a candidate liveops identity feature.
- **EQUIPMENT_MASTER §4.9 / §6.1** — the **cosmetic category/intent table** this doc schedules batches
  *from* (it owns cadence, not the SKUs); the **`tradeable` discriminator** that routes a new
  event-exclusive item into the unique-artifact path (a tradeable event rare is `tradeable=true`); flag
  **G** (cosmetic replenishment is an economic SLA — the items live in EQUIPMENT_MASTER, the cadence
  lives here).
- **SYS_onboarding_funnel** — the **daily-quest board handoff** (`DAILY_INTRO` → liveops takes the
  content); the **session-2 idle introduction** coordination; the **daily-quest claim rate at session 2**
  D1→D7 bridge metric.
- **SYS_progression v2.1** — **scarcity discipline** (the binding constraint Resolved Decision 1
  enforces); **Rank cap/prestige deferred here**; the **DAG re-thread** mechanism a Destination drop
  uses; the **cross-loop pull as incentive-never-gate** (scheduled cross-loop goals are incentives).
- **SYS_trading** — the **marketplace/auction-house as a named post-launch LiveOps system**; the **light
  Passport-gate-on-trading** anti-wash decision co-owned here; trade as the moat surface scarcity
  discipline protects.
- **03_BUILD_PLAN** — Phase 4 step 13 (first LiveOps event + timed spawns), Phase 5 (weekly cadence from
  day one; **Rockies is the first scheduled drop**).

**Out of scope (named, not designed):** the rare-spawn *mechanism* (combat/fishing); the cosmetic *SKU
art/catalog* (EQUIPMENT_MASTER/lodge_trophy); *Cash values* and the budget-ceiling *number* (economy);
specific new-Destination *content* (future LOC_ docs); the *trade marketplace flow* (a deferred
SYS_trading post-launch extension).

---

## Outputs / what depends on this

- **The live game's content rhythm** — the calendar is the schedule the running game reads to activate
  windows, rotate dailies, ship decor batches, run events, and drop Destinations. Nothing "depends on"
  it as an upstream spec the way systems depend on the economy; instead, *the operating game depends on
  it continuously* for not going stale and not inflating.
- **SYS_economy (the inflation loop closes here).** Economy hands liveops the inflation duty and the
  alarm; liveops hands back the **realized cadence** that keeps the evergreen sink ahead of endgame
  accumulation. The economy's §9 inflation condition is *satisfied by this doc's execution* — the
  decor cadence is the operational half of the economy's macro balance.
- **The LOC_ docs (future).** Each future Destination's rares declare Template E spawn conditions; this
  doc's calendar is **where those conditions are scheduled to fire** as windows/seasons/events. A LOC_
  doc authors the rare and its 1-in-N; liveops schedules its windows — and the LOC_ doc inherits
  Resolved Decision 1 (its rares may be *windowed* by events but never *diluted* by them).
- **The Claude Code event build** (03 Phase 4 step 13) consumes this doc as its spec: the event-config
  schema, the activation mechanism, the budget/aggregate checks, and the scarcity-discipline schema
  guard.
- **The marketing/return-hook beats.** Destination drops and marquee events are the scheduled marketing
  moments; the calendar is what makes them *scheduled* rather than improvised.

---

## Tuning parameters

Explicit knobs for instrumentation (00 §0, 01 risk #3 — wire telemetry alongside, not after). Cadence
intervals and policy thresholds are **illustrative defaults**; every **Cash value is SYS_economy's** and
is echoed, never authored here.

- **`weeklyHeartbeatInterval`** *(default 1 week)* — the staleness-defeating base cadence (00 §7 ideal).
- **`monthlyMarqueeInterval`** *(default ~1 month)* — the marquee-beat floor (00 §7 minimum); a month
  with no marquee beat is an alarm.
- **`destinationDropInterval`** *(default ~1 quarter, content-readiness-gated)* — the modular-content-
  engine cadence; Rockies is the first.
- **`limitedTimeEventInterval`** *(default every 1–2 weeks)* — the manufactured-moment frequency.
- **`seasonalWindowDefinitions`** — the real-season → in-game-window mappings (salmon run, migration,
  openers) and their real-calendar placement.
- **`decorReplenishCadence`** — **the economy SLA knob** (= economy's `endgame-sink-replenishment
  cadence`, surfaced here): how many **Cash-priced** evergreen decor/theme/framing SKUs ship per cycle
  (game-pass cosmetics do not count — §4). Owned jointly with SYS_lodge_trophy/SYS_economy. **The one
  non-negotiable recurring beat (Resolved Decision 3).**
- **`evergreenSinkShareAlarmThreshold`** — the **metric** (`evergreen-sink share of endgame Cash`) is
  economy's §9 / lodge_trophy's canary; the **trigger threshold on it is this doc's** (co-set with
  economy), because liveops owns the *response* — the level below which the catalog has saturated and an
  **out-of-band decor drop is triggered** (the §4 alarm override). Corroborated by `rare-price-trend`
  (economy moat canary).
- **`eventPayoutBudgetCeiling`** — **echoed from economy** (co-set with this doc): the per-event Cash
  bound; `aggregateEventFaucetCeiling` is the concurrent-overlap bound (§6).
- **`dailyQuestSetSize`** *(default ~3/day)* and **`dailyQuestRotationRule`** — the daily-board content
  and refresh; always includes the cross-loop pair. Reward *scale* is economy's (a fraction of
  current-tier income), echoed not authored — and its **`T_current` basis under the OR-gate is an open
  economy call**, not a settled value (§5, Open Questions).
- **`scheduledCrossLoopGoalCadence`** — how often a calendar beat sets a cross-loop event goal (an
  *incentive*, never a gate — progression RD2); the escalation lever if the single-loop population is
  large (economy/fishing flagged it here).
- **`scarcityApprovalPolicy`** — the operational process gate for any event that mints a new scarce item
  or opens a rare window (Resolved Decision 1; the *who-approves* is an Open Question). Not a number — a
  configured policy + the schema guard.
- **`session2IdleIntroFraming`** — the **proposed** "welcome back" return-moment beat that surfaces the
  first idle payout at session 2 (framing *proposed* for liveops, the Cash for economy — co-owned, not
  claimed; §5, Open Questions). The `idleFraction`/`idleCapHours` Cash is economy's.
- **`rankPrestigeCadence`** — **deferred** (progression handed Rank cap/prestige here; not designed until
  live rank-participation data exists — Open Questions).

---

## Claude Code build notes

- **Events are data-driven config, not code (Resolved Decision 4 — the load-bearing build property).**
  A new event, season, or Destination is a **config record the live game loads**, shipped without a code
  deploy. The event-config schema carries: an id; an activation window (start/end against **server
  time**); an optional condition predicate (the `event` clause combat/fishing spawns already read); a
  declared **Cash reward budget** (≤ `eventPayoutBudgetCeiling`); a reward manifest (predominantly
  scarce/identity items, per Resolved Decision 2); and a **new-scarcity declaration** (Resolved Decision
  1). Build this schema first; everything else is records in it.
- **The scarcity-discipline schema guard (make the moat structural).** The event-config loader/validator
  **must reject at build/load time** any config that edits an existing artifact's `rarity` / `1-in-N` /
  live-mint accounting (Resolved Decision 1) — the same build-time-schema-error class EQUIPMENT_MASTER
  and SYS_data_integrity use. A liveops config may **reference** an existing rare's spawn predicate
  (schedule a window) and may **introduce a new artifact catalog entry** (new permanent scarcity); it
  may **not** mutate an existing entry's scarcity. This is the one guard that makes "never re-release a
  rare to juice numbers" a property of the system, not a discipline someone has to remember under
  pressure.
- **Event spawns inherit data_integrity's single-mint integrity with no new code.** An event/seasonal
  rare is a normal condition-gated spawn entry (combat RD-E / fishing Decision 3) layered on the routine
  population; its mint is the same server-minted unique `artifactId` with one disposition and CAS
  transitions (data_integrity §4). **A new content drop adds no anti-dupe surface** — it reuses the
  integrity layer wholesale. Do not build an event-specific mint/dupe path.
- **Event payouts are budget-capped, validated, atomic ledger entries** (data_integrity), tagged as the
  event faucet so event Cash is separable in telemetry. The scheduler enforces the per-event budget and
  the **aggregate concurrent-faucet ceiling** (§6) before activating overlapping events. A rare minted
  by an event writes **no Cash** (data_integrity v1.1) — its value is trade/Trophy-Hall, which is why
  most event value never pressures the ceiling.
- **Server-authoritative activation, no client-asserted event state.** The server owns whether an event
  is live (time- and/or condition-gated against server time); the client displays event state but never
  asserts it. Timed event entitlements (multipliers, window-bounded boosts) are **server-time
  entitlements** (offline time counts; logging off banks nothing — data_integrity). A client-reported
  time can never extend an event for a player.
- **Event leaderboards are server-authoritative (no client-asserted scores).** A competitive event's
  ranking (e.g. most trophy weight in kg) is computed from server-validated kills/catches only — the
  same discipline as every other score in the game (combat/fishing validate the event; the leaderboard
  reads validated events, never a client-submitted total). A client claiming a score is ignored. This
  is the one place an event adds a *new* server-state surface, and it must inherit the existing
  server-authority substrate, not invent a parallel one.
- **The Destination-drop pipeline is the config-bundle-load path** (§1, §3.4). Build it so a region drops
  as: LOC_ config + EQUIPMENT_MASTER region rows + condition-gated rare predicates, loaded live, with the
  gate DAG re-threaded by editing the adjacent Destination's `milestone_prerequisite` (progression build
  notes) and the income/pricing formulas inheriting the curve untouched (economy). **Rockies is the first
  drop and the first real test of this path** (03) — if it needs engine code, the droppable-unit
  discipline has a hole. Treat the Rockies drop as the pipeline's acceptance test.
- **The daily-quest board is liveops-owned config after the onboarding handoff.** Onboarding's
  `DAILY_INTRO` beat introduces the board; from there the daily set is a liveops rotation config (set
  size, the cross-loop pair, seasonal/event theming). Reward *scale* calls into economy's
  current-tier-income faucet (whose `T_current` basis under the OR-gate is an open economy call — §5);
  liveops authors *which quests*, not *how much Cash*.
- **The evergreen-sink alarm is a telemetry-driven scheduler trigger.** Wire `evergreen-sink share of
  endgame Cash` (economy §9) as an input to the scheduler: below `evergreenSinkShareAlarmThreshold`,
  fire an out-of-band decor/theme drop ahead of the baseline cadence (§4). This closes the inflation
  feedback loop in software, not in a spreadsheet someone has to check.
- **Telemetry — wire alongside, not after (00 §0, 01 risk #3):**
  - **`evergreen-sink share of endgame Cash`** (economy §9 canary) — *the* liveops health metric; the
    decor-cadence-is-working signal and the alarm trigger.
  - **Rare-price trend on the Trading Post** (economy moat canary) — the corroborating inflation leading
    indicator; rising rare prices precede Cash inflation reaching the trade economy.
  - **Event participation rate and event-faucet Cash share** — did the event land, and did its Cash stay
    within budget (the aggregate-ceiling check, observed).
  - **Daily-quest claim rate, by day, and specifically at session 2** (the D1→D7 bridge, inherited from
    onboarding) — did the "come back tomorrow" hook convert.
  - **Lapsed-player reactivation on a Destination drop / marquee event** — the return-hook payoff; D7/D30
    lift attributable to a calendar beat.
  - **Cadence-adherence** (did the weekly heartbeat and the monthly-marquee floor actually ship) — the
    operational discipline metric; a slipping cadence is the franchise-vs-spike line being lost (00 §7).
  - **Scheduled-cross-loop-goal effect on single-loop population** — whether scheduled cross-loop
    incentives actually pull single-loop players toward breadth (the escalation lever economy/fishing
    handed here).

---

## Open questions / flags

- **The scarcity-discipline OPERATIONAL policy — who approves a new scarce item, and how re-release
  pressure is resisted in practice (the highest-value open item).** Resolved Decision 1 makes *dilution*
  a structural impossibility (the schema guard). What it cannot make structural is the *judgment* on
  whether a proposed **new** scarce item is worth minting (every new scarce item is a permanent supply
  commitment that can never be cleanly undone) and the *organizational discipline* to keep saying no to
  "just re-release the legendary buck for the anniversary, the numbers need it." That pressure is real
  and it arrives *here*. Recommendation to set before launch: a lightweight **scarcity-mint approval
  gate** — every event that mints a new scarce item or opens a rare window files a one-page declaration
  (what it mints, its permanent supply consequence, an explicit "does this dilute any existing holder's
  scarcity? — must be NO"), reviewed by whoever owns the economy/moat. The schema guard is the floor;
  the approval gate is the ceiling. **Flagged as a decision for whoever owns live-ops/economy, not
  taken here.** This is the discipline test the whole trade moat depends on.
- **Launch-vs-ongoing content-volume balance (a scope/resourcing call).** This doc specifies the
  *engine* and illustrates the first few cycles (§1.1, marked illustrative) per scope discipline — the
  MVL ships 3 Destinations, world-expansion is the ongoing engine, not the launch (01 risk #1). The open
  question is the *volume* split: how much content the launch calendar needs to feel alive on day one
  vs. how much is held for the ongoing cadence. Tied to the lodge_trophy flag on **decor-catalog launch size vs. ongoing
  cadence** (seed the launch catalog adequately so the sink *functions* at launch, then grow it) and to
  the realistic team-capacity question below. Co-decide with SYS_lodge_trophy / SYS_economy.
- **The weekly cadence is only as achievable as the config-not-code discipline holds (a future-debt
  flag, stated honestly).** 00 §7's weekly ideal is a heavy operational commitment for a small team. It
  is survivable *only* because Resolved Decision 4 makes events config drops. **Any upstream system that
  ends up requiring code per event silently downgrades the achievable cadence** from weekly toward
  monthly toward the staleness that buries the game. The first real test is the **Rockies drop** (the
  pipeline acceptance test above). If Rockies needs engine work to ship, that is a signal the
  droppable-unit discipline has a hole that must be fixed before the cadence model can be trusted —
  flag it loudly if it happens; do not paper over it by shipping monthly and calling it the floor.
- **Rank cap / prestige is deferred to this doc and not yet designed (inherited from progression).**
  Whether Hunter/Angler Rank caps, prestiges, or loops for repeat rewards is a LiveOps retention knob
  best decided with live rank-participation data (progression Open Questions). Not designed at MVL;
  named here as this doc's to decide post-launch. (`rankPrestigeCadence` is the placeholder knob.)
- **Dead co-op-apex content (inherited from combat flag #3).** At soft-launch low CCU, the co-op-only
  grizzly/halibut apex may go effectively unkilled. Combat rules out NPC-assist/matchmaking for MVL
  (scope). A **co-op spotlight event** is the liveops lever to make that apex live content rather than
  dead content — but only if the telemetry shows it is actually dead, and only without violating
  combat's no-matchmaking-at-MVL rule. Flagged as a post-launch-data-driven event candidate, not a
  launch commitment.
- **Single-loop endgame reach (inherited from progression/fishing).** The OR-gate lets a pure hunter
  reach a fishing-only endgame (Deep Sea, T7) with no reason to pick up the rod. Economy's standing
  cross-loop pull may not suffice; the escalation path both docs name is a **scheduled cross-loop event
  goal** (an incentive, never a gate — progression RD2). Owned here as a lever; its efficacy is the
  `scheduledCrossLoopGoalCadence` telemetry question. Not a launch concern (Deep Sea is post-MVL).
- **Daily-quest (and idle) reward basis under the OR-gate — an unresolved economy call this doc
  inherits.** Economy scales dailies and idle as a fraction of "current-tier income," but the OR-gate
  gives a player two effective tiers (EHT, EFT) that can differ widely, so `T_current` is not a single
  value — it is the same basis data_integrity flagged as underspecified for idle (`max(EHT,EFT)` vs.
  highest *conquered* tier vs. a blend). The daily-quest scale inherits the same ambiguity. **It is
  economy's formula call, not liveops's** — flagged here because liveops *uses* the value and must not
  present it as crisp. Resolve in economy; liveops echoes whatever basis economy sets. (All candidate
  bases are derivable from stored state, so integrity is unaffected; only the *amount* is in question.)
- **Session-2 idle introduction — a co-owned coordination item, ownership deliberately not claimed
  here.** The funnel withholds idle from session 1 and flags its session-2 introduction "for
  coordination with economy/liveops … not owned here." This doc *proposes* the division (liveops carries
  the return-moment framing; economy owns the Cash — §5) but does not unilaterally claim it, to avoid
  exactly the doc-boundary drift the project discipline guards against. Co-decide with economy/onboarding
  who owns the session-2 "welcome back" beat before building it. Default if undecided: economy owns the
  faucet, liveops owns the calendar beat that surfaces it.
- **The Kennel/Stable "show off rare companions" showcase (deferred from lodge_trophy).** Rare-breed
  Dogs/Mounts/Boats are unique artifacts but are not Trophy-Hall-displayable; a separate showcase view
  over their HELD state is a candidate liveops identity feature (lodge_trophy Open Questions). Out of
  scope at MVL; named here as a future liveops identity beat, not designed.
- **The marketplace/auction-house as a post-launch LiveOps system (deferred from trading).** A listings
  market would deepen the economy but is explicitly out of MVL scope (trading Open Questions; it needs
  the proven same-server trade flow and the cross-server substrate first). Named here as the tempting
  post-launch LiveOps system it will become the moment direct trading works — flagged so it is scheduled
  as a deliberate post-launch beat, never rushed in as a launch feature.
- **The light Passport-gate-on-trading anti-wash decision (co-owned with trading/economy/onboarding).**
  A "must have conquered ≥1 Destination to trade" gate would deter throwaway-alt wash-trading and
  bot-trade-farms at a small new-player-friction cost (trading Open Questions; MVL default: no gate). It
  intersects liveops because wash-trading is partly an event/economy-health concern. Co-decide; not
  taken here.

---

## Changes from v1 (review pass, for the diff)

No structural change to the cadence framework, the event taxonomy, or the four Resolved Decisions. The
pass closed seams and corrected over-claims; two were genuine correctness fixes, the rest are precision.

- **Daily-quest / idle reward basis reconciled with the OR-gate (correctness).** v1 wrote the daily
  reward as a crisp fraction of `Income(T_current)`. But under the OR-gate a player has two effective
  tiers (EHT/EFT), and data_integrity already flagged `T_current` as underspecified for idle. v1
  inherited that ambiguity while presenting it as settled. v1.1 states it as the same open economy call
  (§5, Tuning, new Open Question), echoed not authored.
- **Inflation SLA restricted to the Cash-priced evergreen subset (correctness).** v1 treated "new
  cosmetics/decor" as the inflation ballast without distinguishing Cash-priced (a Cash *sink*) from
  game-pass/real-money cosmetics (revenue, but *no* Cash removed). A cycle of real-money skins could
  appear to satisfy the SLA while doing nothing for inflation. v1.1 counts only Cash-priced SKUs toward
  `decorReplenishCadence` (§4, Tuning).
- **Alarm-threshold ownership corrected.** v1 said `evergreenSinkShareAlarmThreshold` was "echoed from
  economy." The *metric* is economy's canary, but the *trigger threshold* is a liveops call (liveops
  owns the drop response). v1.1 assigns the metric to economy and the threshold to this doc, co-set
  (Tuning).
- **Cadence axis (§1) and event-content-kind axis (§2) made explicitly orthogonal.** v1 left "seasonal"
  and "Destination drop" appearing on both lists as an unexplained smear. v1.1 adds the orthogonality
  note (§1) and clarifies dailies/decor are standing systems, not events (§2 header).
- **Illustrative first-quarter calendar added (§1.1).** The brief asked to "illustrate the first few
  cycles"; v1 only scattered examples. v1.1 adds a concrete, explicitly-illustrative first-quarter table
  showing how the heartbeat, marquee, seasonal, and the Rockies drop interleave.
- **Session-2 idle framing downgraded from claimed ownership to a co-owned coordination item.** v1 wrote
  "Liveops owns the session-2 return-moment framing"; the funnel had left it "not owned here." v1.1
  proposes the division without claiming it and adds an Open Question (§5).
- **§3.1 ownership boundary tightened.** v1 said liveops "owns the `event` clause of the predicate";
  v1.1 makes clear combat/fishing own the predicate definition and rate, and liveops owns the
  *activation schedule* that drives it.
- **Event leaderboards build note added** — competitive-event scores are server-authoritative, the one
  new server-state surface an event adds, inheriting the existing substrate (build notes).
- **Broken cross-reference fixed** — RD2's "(Resolved Decision below + §3.4)" now correctly points to
  §6 (how event Cash stays bounded).
