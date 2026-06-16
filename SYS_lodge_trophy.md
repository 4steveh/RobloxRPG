# System: Lodge & Trophy Hall

> System deep-dive #7 in the build order (03 §90). This doc owns the **Lodge** as the player's
> home hub and social/identity space, and the **Trophy Hall** as the room where rares become
> displayable status. It owns the *hub navigation, the display UX, the slot model, and the
> identity/decor monetization that is the economy's primary inflation ballast*. It does **not**
> own disposition mechanics (SYS_data_integrity §4), trade flow (SYS_trading), World Map gating
> logic (SYS_progression — this doc only *presents* it), or vendor inventories
> (EQUIPMENT_MASTER). The Trophy Hall is built as a **view over DISPLAYED-disposition
> artifacts** — it stores no separate authoritative copy of a trophy.
>
> Reads as binding: 00 (§5 scarcity moat, §6 content moments, §8 identity/low-poly, §9 co-op
> hub), 01 (the Lodge), 02 (Template F, fixed units), 04 (canonical terms), 05 (the trade-moat
> wedge), SYS_progression v2.1 (Passport / World Map), SYS_economy v2.1 (§9 evergreen sinks),
> SYS_data_integrity §4 (disposition rule), EQUIPMENT_MASTER §4.9 / §6.1 (cosmetic ballast +
> `tradeable` discriminator).

---

## Resolved Decisions (binding — confirms two upstream open flags)

These confirm flags that SYS_data_integrity and SYS_economy explicitly handed to this doc.

1. **Default disposition on mint is HELD; the UX is "held-then-choose" with an auto-prompt — NOT
   auto-display.** (Confirms SYS_data_integrity open flag, line 665.) A freshly minted rare enters
   tradeable inventory as `HELD`. The clean-kill / clean-catch flourish fires the content moment
   *at the point of mint* (combat §173, fishing §562); immediately after, a one-tap **"Mount it in
   the Trophy Hall"** prompt surfaces. The prompt is a **UI beat on top of the unchanged
   primitive** — the artifact stays `HELD` until the player taps, at which point a normal
   `HELD → DISPLAYED` CAS runs. Rationale: auto-display would silently move a just-minted rare out
   of tradeable inventory, which (a) pre-empts the player's salvage/trade/display choice that
   SYS_data_integrity §4 makes the single value-realization point, and (b) risks confusing a new
   player about where their trophy "went." Held-then-choose keeps the choice explicit and keeps the
   default state tradeable, which the economy and trade moat both want. **The prompt is a
   convenience, never a coercion: dismissing it leaves the artifact HELD and fully tradeable.**

2. **Trophy Hall expansion slots are a Cash-priced typed-owned commodity, not a tradeable
   artifact.** (Confirms EQUIPMENT_MASTER §6.1 routing.) A display *slot* is capacity the player
   owns, not a unique object that can be duped or traded; it follows the `tradeable = false`
   typed-owned path (catalog id + owned count). Only the *trophies that occupy slots* are unique
   artifacts. This keeps slot-buying on the clean fixed-Cash sink path with no anti-dupe surface.

---

## Purpose & player-facing goal

The Lodge is the answer to "where do I go when I'm not out hunting or fishing." It is **the hub**:
the single place every player returns to between expeditions, where the services live, where the
World Map is opened, where other players are, and where your accumulated success is on the wall for
the server to see. It is **yours and you upgrade it** (01) — the home of self-expression spending,
the Brookhaven/Bloxburg lesson applied (00 §8).

The Trophy Hall is the emotional core of that hub. It is where a rare kill or record catch stops
being a line in an inventory and becomes **a mounted, visible, permanent status object** that other
players walk past and recognize. This is the mechanic that makes a rare **worth more than its sale
price**: a trophy you can show off carries status + emotional attachment on top of trade value (01,
05 §3). That doubling is *half the reason the trade economy has a long tail* — the other half is
trading itself (SYS_trading). A rare you can only sell is a commodity; a rare you can display is an
identity.

The player-facing experience: you land a record king salmon during the migration event; the
clean-catch flourish fires; a prompt asks if you want to mount it; you tap, walk into your Lodge,
and it is on the wall with its weight and date under it. A friend teleports to your Lodge to plan an
Alaska trip, sees the salmon, and asks how you got it. Six weeks in, your wall is filling, you have
bought a second display room and a set of regional decor, and the empty slots are themselves a
goal — a reason to go back out and hunt the thing that fills them.

---

## How it ties to the formula

The Lodge & Trophy Hall is load-bearing on **four** of the Research Foundation's spokes
simultaneously, which is why it is a core system and not a cosmetic bolt-on (05 §4 test #2: it
serves both load-bearing differentiators, the aspiration spine *and* the trade moat).

- **The scarcity trade moat (00 §5, 05 §3).** The Trophy Hall is what makes scarcity *felt*. Real
  scarcity (rares minted carefully, never re-released) only becomes a moat if rarity is **socially
  legible** — if owning the rare thing signals status to other players. The Hall is the signaling
  surface. Without it, a rare is a private number; with it, a rare is a public flex, which is
  exactly the "scarcity + social signaling → identity markers" mechanism 00 §5 names. This is the
  single biggest separator between a 3-month hit and a multi-year franchise, and Gone Hunting's
  fatal lack of it (05 §2: "solo sell-to-NPC economy, no long tail") is precisely the hole this
  attacks.

- **Identity monetization, the safest money (00 §4, §8).** The Lodge is the home of identity
  spending — decor, room themes, Trophy Hall expansion, wall-mount framing. Cosmetics are the
  highest-margin, zero-balance-impact category, and self-expression spaces (Brookhaven/Bloxburg)
  make millions on exactly this. Per SYS_economy §9 this is not just *a* revenue line; **Lodge
  decor + Trophy Hall expansion are the economy's primary inflation ballast** — the evergreen sink
  that absorbs endgame Cash once gear-buying plateaus.

- **The content-moment endpoint (00 §6).** A 1-in-N Mythic is designed to produce a screenshot
  (Template E content-moment field; combat/fishing clean-kill/clean-catch flourish). The flourish
  is the *capture*; the Trophy Hall is the *display* — the place the captured moment lives and gets
  re-shown. Trade showcases and "look what's on my wall" tours are creator content that feeds the
  discovery flywheel. The flourish and the Hall are two ends of one content pipeline.

- **The social / co-op hub (00 §9, 01 co-op model).** Co-op is incentivized, never forced, and
  "the social hub is where players find partners" (00 §9). The Lodge is that hub: concentrating
  players in one shared space makes the world feel alive (01: "concentrates players in the lodge so
  the world feels alive, not empty"), and a wall full of trophies is both a conversation-starter and
  a credibility signal when forming an expedition party. Public activity cues (visible progress that
  pulls others in, 00 §8) are literally the trophies on the wall.

Retention tie (00 §0, the hub everything serves): empty display slots are a **return hook** — a
concrete, visible, personal goal ("fill the wall") that pulls D7/D30, and the Lodge as a social
space lengthens sessions (you stay to show off, to find a partner, to browse the new decor drop).

---

## Mechanics (detailed)

### 1. The Lodge as hub — what's in it and how you navigate it

The Lodge is a single instanced, low-poly interior space (performance-first, 00 §8 — frame rate
beats fidelity; the art budget goes to the thumbnail, not polygon count). It is **not a town**; it
is a hunting/fishing lodge that belongs to the player. It contains the service access points (01)
plus the Trophy Hall and the player's decor.

**The services hub (this doc places them; it does not own their inventories).** Each service is an
interaction point inside the Lodge that opens that system's own interface:

| Service point | Opens | Owned by |
|---|---|---|
| **Outfitter** | weapons + armor vendor | EQUIPMENT_MASTER (inventory), SYS_economy (pricing) |
| **Tackle Shop** | rods, reels, bait, tackle vendor | EQUIPMENT_MASTER, SYS_economy |
| **Travel Desk** | the **World Map** (Passport progression surface) | SYS_progression (gating logic); this doc presents it |
| **Trading Post** | the player-to-player trade interface | SYS_trading |
| **Kennel & Stable** | Tracking Dogs + Mounts management | EQUIPMENT_MASTER (the artifacts), SYS_data_integrity (their HELD↔ESCROWED disposition) |
| **Boat Dealer** | Boats (access gating) | EQUIPMENT_MASTER, SYS_progression (the access gate) |
| **Trophy Hall** | the display room(s) — **this doc owns it** | this doc (as a view); SYS_data_integrity §4 (the disposition under it) |

**Navigation.** The Lodge interior is walkable on foot; service points are physical, recognizable
fixtures (a gun rack for the Outfitter, a map table for the Travel Desk, etc.) so a seven-year-old
navigates by *looking*, not by reading a menu (00 §2 legibility). A lightweight radial or bottom-bar
shortcut menu is acceptable on mobile for fast service access, but the **physical fixtures are the
primary navigation** — they double as the Lodge's décor identity and the thing players customize.
Spawning into the game and returning from a Destination both land the player in the Lodge.

**Why the hub is the social flex space.** Other players' Lodges are visitable (the partner-finding
and flex mechanic). The default arrival space — and the place co-op parties assemble before booking
a guided expedition (01) — is the Lodge. A player's trophy wall is the first thing a visitor sees:
it is the credential ("this person has conquered Alaska, look at the grizzly") that makes them a
desirable expedition partner. *Specifying the multiplayer/instancing model of Lodge-visiting (your
own instance vs. a shared social lobby vs. visitable-on-invite) is an open question below — it has
performance and moderation implications and should be set with SYS_data_integrity's server model.*

### 2. The Trophy Hall — the display model

**The Trophy Hall is a VIEW, not a store.** This is the single most important build property and it
is dictated by SYS_data_integrity §4. The Hall does **not** hold its own list of trophies. It is a
**render of the player's artifacts whose `disposition == DISPLAYED`**. The authoritative state of
every trophy — its existence, owner, provenance, and disposition — lives in the artifact record
owned by SYS_data_integrity. The Hall reads that state and draws a mount for each DISPLAYED
artifact. There is exactly one authoritative copy of a trophy (the artifact), and the Hall is a
window onto the subset of it that is currently displayed. **There is no separate "trophy wall data
structure" to keep in sync, and therefore no desync/dupe surface between inventory and wall** —
which is the whole point of building it as a view.

**Displaying and un-displaying are disposition transitions, not Hall operations.** "Mount this
trophy" issues a `HELD → DISPLAYED` CAS (SYS_data_integrity §4 transition table). "Take it down"
issues `DISPLAYED → HELD`. This doc **does not reimplement** either; it calls the transition and
re-renders the view on success. Consequences inherited directly from §4, surfaced to the player by
this doc's UX:

- A **DISPLAYED** trophy is **not in tradeable inventory** and **not directly tradeable**. To trade
  a displayed trophy the player must first take it down (`DISPLAYED → HELD`), then it can be escrowed
  (`HELD → ESCROWED`). The UX must make this legible: a displayed trophy's detail panel shows a
  **"Take down to trade"** action, never a direct "trade" action, so the player understands the
  display/trade exclusivity rather than hitting a confusing block.
- The mutual-exclusivity invariant (a displayed item is not tradeable and vice versa, never both,
  never neither-but-still-counted) is enforced *under* the Hall by the CAS, not by the Hall.
- **`DISPLAYED → SALVAGED`** exists (§4: un-display then salvage as one atomic op, terminal). The
  Hall surfaces salvage from a displayed trophy's panel **behind an explicit confirm** ("Salvage
  this trophy for [low Cash]? This is permanent and cannot be undone"), because salvage is terminal
  and the salvage floor is deliberately low — the moat depends on players almost never doing this to
  a real rare. **Auto-sell never touches a displayed (or any) trophy** (§4 — auto-sell is
  fungible-yield-only; this is a moat footgun guard).

**Slot model.** A trophy occupies one **display slot**. Slots are the capacity constraint and the
monetization lever:

- The Lodge ships with a **baseline free slot count** (`baseTrophySlots`, tuning param) — enough to
  make the Hall feel real and rewarding from the first rare, but not so many that expansion has no
  pull. Default proposal: a small baseline (e.g. ~6–10) that fills within the early-mid game.
- Players buy **additional slots** for Cash (`slotExpansionPrice`, an escalating curve — each
  expansion costs more than the last, an unbounded sink with no ceiling, per economy §9). Slots are
  a typed-owned commodity (Resolved Decision 2): the player owns a count, not unique objects.
- Slots are organized into **display rooms / themes** (see §3) so expansion is *also* an identity
  purchase, not just raw capacity — you are buying "the Alaska trophy room," which has both more
  slots and a cohesive look.

**What can be displayed.** Only **Trophy artifacts** — the unique artifacts minted by combat/fishing
for Rare-and-above kills and record catches (SYS_data_integrity §4: "DISPLAYED and SALVAGED are
Trophy-only"). **Non-trophy unique artifacts are NOT displayable in the Trophy Hall** — a
rare-breed Tracking Dog lives in the Kennel, a rare Mount in the Stable, a rare Boat in its slip
(§4). Implementers must not build a "display a dog in the Trophy Hall" path. (A *separate* future
"show off your rare dog" surface in the Kennel is a possible LiveOps identity feature, flagged
below — but it is not the Trophy Hall and would be its own view over those artifacts' own state.)

**Trophy presentation (the status layer).** Each mounted trophy renders with:

- The **trophy object** itself — a low-poly mount of the creature/fish, ideally visually distinct
  for the rare variant (an albino buck reads as white) so the *rarity is visible at a glance* across
  the room. This is the status signal; it must be readable in a screenshot (00 §6).
- A **plaque** with the trophy's **provenance**, drawn from the artifact's provenance record (§4):
  what it was, its **weight in kg** (fixed unit), where it was taken (Destination), and when. The
  weight and date are what make a record catch a *record* — they are the brag.
- **Rarity framing** — a visual frame keyed to the rarity tier (Common→Mythic; though in practice
  only Rare-and-above mint trophies, so the Hall shows Rare→Mythic). Mythic gets the most
  distinctive framing. **Decor purchases can upgrade framing** (an identity sink — see §3).

### 3. Identity monetization — decor, themes, and expansion (the inflation ballast)

This is the economic heart of the doc. **Per SYS_economy §9, Lodge decor + Trophy Hall expansion
are the PRIMARY inflation ballast** — the evergreen, balance-free, no-ceiling sink that must absorb
endgame Cash after gear-buying plateaus. This doc specifies the *model and economic role*, not every
SKU (the SKU catalog is EQUIPMENT_MASTER §4.9's "category + intent" table, continuously extended by
LiveOps).

**The decor / expansion model:**

- **Lodge decor** — furniture, wall treatments, lighting, rugs, mounted-fixture skins (the gun rack,
  the map table), room themes. Pure identity, zero stats (a decor item with non-null stats is a
  build-time schema error, inheriting EQUIPMENT_MASTER §6's cosmetic-with-stats check). Cash-priced.
- **Room themes** — cohesive cosmetic sets that re-skin a Lodge room or a Trophy Hall display room
  (a "rustic bayou cabin" theme, an "Alaska expedition lodge" theme). Themes are the high-value
  identity purchase and the natural unit for regional/seasonal drops.
- **Trophy Hall expansion** — additional display slots (Resolved Decision 2), sold bundled into
  display rooms so each expansion is *capacity + a look*. The escalating slot price (§2) is the
  unbounded part of the sink.
- **Trophy framing / mount-quality cosmetics** — upgraded plaques, premium frames, lighting on a
  mount. Lets a player spend *on a trophy they already own* to make it flex harder — an identity
  sink that scales with how much the player cares about a specific rare.

**The economic SLA (binding, from SYS_economy §9).** The decor/expansion catalog **must grow on the
LiveOps calendar**. A fixed cosmetic catalog saturates — players buy everything they want, then
accumulate Cash with nothing to spend on, and **endgame inflation resumes**. Therefore shipping new
desirable decor/themes/framing is an **economic duty, not just a content one** (economy §9: "an
economic obligation … tracked by the endgame-sink-replenishment-cadence parameter and the
evergreen-sink-share telemetry"). This doc commits the Lodge as the *home* of that pipeline; the
*cadence and calendar* are owned by SYS_liveops_calendar, which inherits the SLA. **The alarm metric
is `evergreen-sink share of endgame Cash`** (economy telemetry, §9 canary): if top-tier players stop
routing Cash into decor/slots, the catalog has saturated and a drop is overdue.

**Tradeability of decor (build routing, EQUIPMENT_MASTER §6.1):**

- **Basic / standard decor and slots are `tradeable = false`** — typed-owned commodities (catalog id
  + owned count). This is the overwhelming majority of the catalog and the inflation-ballast
  workhorse: fixed-Cash, no anti-dupe machinery needed (duping a fixed-Cash purchasable is
  pointless), clean on the dual-pricing insulation (economy §9 — Cash-priced commodities are immune
  to veteran wealth).
- **Any *tradeable* decor is `tradeable = true`** — a unique artifact with `artifactId`, owner,
  provenance, CAS transitions, full anti-dupe (the rare-cosmetic path, EQUIPMENT_MASTER §6.1). This
  is reserved for genuinely scarce decor (e.g. a limited-event mounted-fixture skin meant to hold
  trade value). Use it sparingly — every tradeable cosmetic is a scarcity object whose re-release
  discipline must be honored (00 §5). **Default new decor to `tradeable = false`** unless it is
  deliberately designed as a scarce trade item.

**Monetization-cleanliness note.** Everything in this section is **identity** monetization (00 §4
priority order: identity > convenience > access). Zero balance impact, no pay-to-win surface, no
energy timers, no rod-recharge waits (01 forbidden list). A player who buys nothing here is at zero
competitive disadvantage; they simply have a plainer Lodge. That is the safe, downvote-proof shape.

### 4. The content-moment connection (flourish → wall → clip)

The clean-kill flourish (combat §173) and clean-catch flourish (fishing §562) are the *birth* of a
content moment — the slow-mo / emphasized-audio beat reserved for Rare-and-above. This doc owns the
*afterlife* of that moment:

1. **At mint** (HELD), the flourish fires. The auto-prompt (Resolved Decision 1) offers "Mount it."
2. **On display**, the trophy enters the Hall (the view re-renders) with full provenance framing —
   the *persistent, re-viewable* form of the moment. The screenshot beat is no longer a one-time
   slow-mo; it is a permanent wall object a creator can tour, compare, and show off (00 §6: trade
   showcases and rare-drop reveals as creator content).
3. **In the social hub**, visitors see it — the flex completes the loop (00 §8 public activity cues).

The design intent: the flourish makes the *catch* shareable; the Hall makes the *collection*
shareable. A wall of Mythics is a thumbnail in a way a single catch is not.

---

## Inputs / dependencies

- **SYS_data_integrity §4 (the disposition rule) — the foundation this is built ON.** The Trophy
  Hall is a view over `disposition == DISPLAYED`; display/un-display/salvage are §4 CAS transitions
  this doc calls, never reimplements. The artifact record (id, owner, provenance, disposition) is
  the authoritative state; the Hall renders it. This doc inherits §4's mutual-exclusivity invariant,
  the auto-sell-never-salvages-a-trophy rule, and the DISPLAYED/SALVAGED-are-Trophy-only rule
  wholesale.
- **SYS_economy §9 (evergreen sinks).** Decor + slot expansion are the primary inflation ballast;
  the catalog-growth cadence is an economic SLA; `evergreen-sink share` is the alarm. Slot
  expansion pricing echoes the economy's escalating-sink intent (exact curve co-set with economy).
- **SYS_progression (Passport / World Map).** The Travel Desk in the Lodge opens the World Map; this
  doc *presents* the Passport state (lit/locked pins, the legibility-contract requirement strings)
  and the in-Lodge Passport readout. Progression owns all gating logic, conquest validation, and the
  legibility contract; this doc renders its output and must not re-derive gate logic (progression
  build notes: the UI never re-derives gate logic).
- **EQUIPMENT_MASTER §4.9 (cosmetic categories) + §6.1 (`tradeable` discriminator).** The decor/skin
  catalog and the persistence-path routing for every decor item and slot.
- **SYS_combat §173 / SYS_fishing §562 (the flourishes).** The content-moment birth this doc's
  display layer continues. Combat/fishing mint the trophy artifact; this doc displays it.
- **SYS_trading.** Consumes HELD trophies that the player takes down to trade; this doc routes the
  "take down to trade" action into trading's flow. Trading owns the negotiation/escrow/swap.
- **04 (canonical terms), 02 (fixed units).** "Trophy Hall," "Trophy," "Travel Desk," "Cash," kg,
  the rarity scale — used exactly.

## Outputs / what depends on this

- **SYS_trading** depends on the display/un-display surface: a trophy must be HELD to be offered, and
  the "take down to trade" action is this doc's hand-off into trading. The Lodge's Trading Post is
  the physical access point trading renders into.
- **SYS_liveops_calendar** inherits the **decor/expansion catalog-growth SLA** (economy §9): the
  Lodge is the home of the evergreen-sink pipeline; LiveOps owns the cadence that keeps it from
  saturating. This is the single most important downstream dependency — the economy's inflation
  control runs through it.
- **SYS_economy** consumes the realized decor/slot **sink** (the Cash actually removed) as part of
  the faucet/sink ledger and the `evergreen-sink share` telemetry; this doc's catalog is the sink
  the §9 inflation condition relies on.
- **SYS_onboarding_funnel** depends on the first-trophy beat: the auto-prompt and the first mount are
  a designed early dopamine + identity-spend setup (00 §3 soft monetization setup) — onboarding owns
  the beat sequence; this doc owns the prompt and the Hall it points to.
- **The thumbnail / icon** (00 §8 — where art budget goes): a flex-worthy Trophy Hall is prime
  thumbnail material. Not a code dependency, but a design intent this doc serves.

## Tuning parameters

Explicit knobs for instrumentation (00 §0, 01 risk #3 — wire telemetry alongside, not after):

- **`baseTrophySlots`** — free baseline display slot count at Lodge start. Default proposal ~6–10.
  Too high and expansion has no pull; too low and the Hall feels punitive before the player can
  afford slots. Tune against first-expansion-purchase timing.
- **`slotExpansionPrice(n)`** — Cash cost of the *n*-th expansion slot/room. **Escalating, no
  ceiling** (the unbounded-sink property economy §9 requires). Exact curve **echoed from / co-set
  with SYS_economy** (the escalating evergreen-sink intent); this doc does not set the absolute Cash
  numbers, it sets that the curve is escalating and uncapped.
- **`maxTrophySlots`** — hard cap on total slots, if any. **Default: none** (uncapped, to preserve
  the sink). A cap would only be added for performance (render budget) reasons, in which case it
  becomes a per-room streaming concern, not an economy lever.
- **Decor catalog size + `decorReplenishCadence`** — how many new decor/theme/framing SKUs ship per
  LiveOps cycle. **This is the economy SLA knob** (economy's `endgame-sink-replenishment cadence`,
  surfaced here). Owned jointly with SYS_liveops_calendar; alarmed by `evergreen-sink share`.
- **`autoPromptOnMint`** — whether the "Mount it" prompt fires after a rare's flourish. Default
  **on** (Resolved Decision 1). A knob in case telemetry shows it annoys players mid-action; the
  fallback is a passive notification rather than a modal.
- **`displayRoomThemeCount`** — number of distinct Trophy Hall room themes available (an identity
  variety knob, grows on the LiveOps calendar).
- **Lodge-visit instancing mode** — own-instance / shared-lobby / visitable-on-invite (see open
  questions). Has performance + moderation weight; not a pure number but a configured mode.

Telemetry to wire alongside:

- **`evergreen-sink share of endgame Cash`** (the §9 canary — inherited from economy, surfaced here
  as *this system's* primary health metric): are top-tier players routing Cash into decor/slots? A
  falling share = catalog saturation = decor drop overdue.
- **First-trophy-display rate / time-to-first-mount** — what fraction of players who mint a rare
  display it, and how fast. Low display rate = the Hall isn't compelling or the prompt isn't
  landing; a D7/identity-engagement signal.
- **Slot-expansion purchase curve** — slots owned vs. player progress; validates `baseTrophySlots`
  and the escalating price.
- **Trophy take-down-to-trade rate** — how often displayed trophies are pulled back for trade;
  informs the display/trade tension UX and the trade economy's liquidity.
- **Lodge-visit / social-session metrics** — visits to other Lodges, session time spent in-Lodge;
  the co-op-hub-is-working signal (00 §9).

## Claude Code build notes

- **The Trophy Hall is a pure view — build it that way, no separate authoritative copy.** Render the
  Hall by querying the player's artifacts for `disposition == DISPLAYED` (state owned by
  SYS_data_integrity §4). Do **not** persist a parallel "trophyWall" list; that would be a second
  source of truth and a desync/dupe surface — exactly what building it as a view eliminates. The one
  authoritative record per trophy is the artifact; the wall is `filter(artifacts, DISPLAYED)`.
- **Display / un-display / salvage call §4 transitions; do not reimplement disposition.** "Mount" =
  `HELD → DISPLAYED` CAS. "Take down" = `DISPLAYED → HELD` CAS. "Salvage displayed" =
  `DISPLAYED → SALVAGED` (§4's atomic un-display-then-salvage, terminal, behind a confirm). On CAS
  success, re-render the view; on CAS failure (precondition mismatch — e.g. the artifact was
  escrowed by a concurrent trade), show the current true state, never a stale wall. The CAS
  precondition is the race defense (§4) — this doc relies on it, doesn't duplicate it.
- **Slots and decor are typed-owned commodities (`tradeable = false`, EQUIPMENT_MASTER §6.1):**
  stored as (catalog id + owned count / owned flag), server-authoritative, no `artifactId`, no
  anti-dupe machinery. A decor item or slot with an `artifactId` is a build-time schema error
  (extends EQUIPMENT_MASTER §6.1's assertion: `tradeable=false` MUST NOT carry an `artifactId`).
- **Tradeable decor (`tradeable = true`) routes to the unique-artifact path** (id, owner, provenance,
  CAS, anti-dupe) — the same machinery as Trophies but with the **HELD ↔ ESCROWED ↔ transfer** subset
  (no DISPLAYED-in-Trophy-Hall, no SALVAGED — §4: those are Trophy-only). A tradeable mounted-fixture
  skin lives in the Lodge as decor but is not a "trophy"; it does not occupy a Trophy Hall display
  slot. Keep the two concepts distinct in the schema.
- **Decor as Cash sink writes a normal ledger sink entry** (SYS_economy §3 — every sink is one atomic
  validated ledger append). Slot expansion and decor purchase are sink entries tagged for the
  `evergreen-sink share` telemetry. Server-authoritative purchase (the client never asserts
  ownership of decor or a slot).
- **Decor placement persistence.** Where a player has *placed* decor in their Lodge is per-player
  layout state (which owned decor sits where). Persist it as part of the whole-profile atomic write
  (SYS_data_integrity §1 — never split across desyncable keys). Placement is cosmetic-only; it has no
  economy or anti-dupe weight (you can't dupe a placement of a typed-owned commodity).
- **Provenance comes from the artifact, not re-entered.** The plaque (what/weight-kg/where/when)
  reads the artifact's provenance record (§4). The Hall never stores trophy metadata separately —
  same view principle: one source of truth.
- **Auto-prompt on mint is a UI beat, not a state change.** The "Mount it" prompt fires after the
  flourish but the artifact stays HELD until the player acts (Resolved Decision 1). Dismissing the
  prompt is a no-op on disposition. Do not implement an auto-display path.
- **Auto-sell exclusion (inherited, §4).** The auto-sell game pass must never auto-salvage a trophy
  (displayed or held). Auto-sell is fungible-routine-yield-only. This is a moat footgun guard —
  assert it where auto-sell is implemented.
- **Server-authority throughout** (SYS_data_integrity §2). The client renders the Hall and issues
  *intents* ("display artifact W", "buy slot", "place decor"); the server validates and mutates. A
  client claiming a trophy is displayed, or that it owns a slot/decor, is ignored — the server
  recomputes from authoritative state.
- **Low-poly / mobile-first (00 §8).** Trophy mounts and decor are low-poly; a Hall full of mounts
  must stream/render within mobile budget. If `maxTrophySlots` is ever set, it is for this reason.
  The rare-variant trophy must be **visually distinct at a glance** (albino reads white) so rarity is
  legible in a screenshot without a UI label — the status signal is the model, not a tooltip.
- **Lodge instancing model is an open architectural decision** (below) — coordinate with
  SYS_data_integrity's session/server model before building the visit/social path.

## Open questions / flags

- **Lodge-visit instancing model — UNRESOLVED, needs the server model.** Is a player's Lodge their
  own instance (visitors load into it), a shared social lobby (many players in one space), or
  visitable-on-invite only? This drives the "social flex space / partner-finding hub" promise (00 §9,
  01) but has real **performance** (concurrent-player render budget on mobile) and **moderation**
  (visiting strangers' spaces, chat, 13+ audience) weight. Decide with SYS_data_integrity's
  server/session model and a moderation pass. The Trophy Hall *content* is unaffected (it's a view
  either way); only *who can see it and how* is in question. **Recommendation to evaluate:** a shared
  Lodge social-lobby for the partner-finding hub + visitable individual Lodges on invite for the
  flex — but confirm the render budget first.
- **A "show off rare companions" surface beyond the Trophy Hall — deferred.** Rare-breed Dogs /
  Mounts / Boats are unique artifacts but are NOT Trophy-Hall-displayable (§4). A player may still
  want to flex a rare husky. A future Kennel/Stable/slip "showcase" view (its own view over those
  artifacts' HELD state, no new disposition) is a candidate LiveOps identity feature. **Out of scope
  here; flagged for SYS_liveops_calendar / a future Kennel deep-dive.** Do not overload the Trophy
  Hall to cover it.
- **`baseTrophySlots` and `slotExpansionPrice` curve are provisional** until SYS_economy sets the
  absolute Cash numbers and the escalating curve, and until live data shows first-expansion timing.
  The *model* (escalating, uncapped, room-bundled) is fixed here; the *numbers* are economy's and are
  a post-soft-launch tuning target (the §9 sink must actually absorb endgame income).
- **Decor catalog launch size vs. ongoing cadence.** The MVL needs *enough* decor at launch that the
  sink functions, but the SLA is about *ongoing* growth. How big is the launch catalog vs. the
  per-cycle drop? Joint call with SYS_liveops_calendar and SYS_economy; the alarm
  (`evergreen-sink share`) tells you if launch size was too small, but better to seed adequately.
- **Trophy framing as identity sink vs. clutter.** Per-trophy framing/mount-quality upgrades are a
  nice scaling identity sink, but risk UI clutter and a "pay to make your trophy look real" feel if
  the *base* framing looks cheap. Constraint: base framing must look good unpurchased (the
  no-disadvantage-for-non-payers rule); premium framing is *additive flair*, never a fix for an ugly
  default. Flag for art/feel iteration (01 risk #4).
- **Mythic re-display / multiple of the same rare.** If a player owns two of the same rare (possible
  via trade), can both be displayed? Yes under the slot model (each is a distinct artifact occupying
  a distinct slot) — but confirm the *presentation* doesn't look like a dupe/bug to a viewer. Minor
  UX flag.
- **Does displaying a trophy ever grant a non-cosmetic benefit?** **Recommendation: NO, hold the
  line.** A displayed trophy is pure status/identity. Granting it a stat/perk/income benefit would
  (a) make display a power decision and pull it toward pay-to-win-adjacent territory, and (b) create
  a perverse incentive against trading (you'd never sell a trophy that buffs you). Keep display
  purely social. Flagged because it's a tempting "make the Hall matter mechanically" idea that should
  be resisted — the Hall matters *socially and economically*, which is enough and is the point.
