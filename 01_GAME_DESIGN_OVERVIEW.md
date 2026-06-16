# Game Design Overview — "Wild World" (working title)

> **Purpose.** This is the canonical description of *what we are building*. The Research
> Foundation (00) explains the winning patterns; this document applies them to our specific
> game. Every deep-dive chat should read both this and 00 before starting. Working title
> "Wild World" — replace once we settle on a final name.

---

## One-line pitch

A hunting-and-fishing RPG where you start in a humble local bayou and work your way across
the real world — Montana, Alaska, Africa, the Amazon, the open ocean — unlocking each
destination by earning gear, chasing rare and legendary creatures, and building a trophy lodge
that's the envy of the server.

The spirit: "huntin', fishin', and lovin' every day" — but as a globe-spanning progression RPG.

---

## Why this concept fits the formula

- **Dual cross-feeding loops.** Hunting and fishing are two loops sharing ONE currency and ONE
  upgrade tree. A bored hunter can fish and still progress toward the same goals. This roughly
  doubles session-length potential without doubling content cost. *This is the structural
  backbone — protect it.*
- **Legible progression via the real world.** A child intuitively knows Alaska is bigger and
  scarier than a local pond. That real-world intuition does the motivational work an abstract XP
  bar can't. Passport progression (destinations unlocked) IS the felt sense of advancement.
- **Underserved genre.** RPG is exactly the gap Roblox is actively courting and amplifying (see 00,
  §10).
- **Built-in trade economy.** Region-specific rare trophies and record catches become tradeable
  status items displayed in the lodge — the multi-year moat.
- **Modular LiveOps.** Each new destination is a self-contained, droppable update unit — the
  perfect weekly/monthly content cadence vehicle.

---

## Core architecture: Home Lodge hub + World Map of destinations

### The Home Lodge (the hub)
Not a town — a hunting/fishing **lodge that is yours and that you upgrade**. This is the durable
identity-monetization play (Brookhaven/Bloxburg make millions on self-expression). The lodge is:

- **The trophy hall** — players mount rare kills and record catches on the wall. The emotional
  anchor that makes rare items matter (displayable, not just sellable).
- **The social flex space** — where players show off, meet, and find expedition partners.
- **The services hub** — contains the Outfitter (weapons/armor), Tackle Shop (rods/fishing gear),
  Travel Desk (world map / fast-travel), Trading Post, Kennel & Stable (dogs/mounts), Boat Dealer.

### The World Map (the progression spine)
A stylized globe/map opened at the Travel Desk. Each destination is a pin:
- **Locked pins** show their unlock requirement ("Requires: Expedition gear + 50 trophies").
- **Tapping an unlocked pin** flies you there — single-button teleport, themed as booking a trip.
- This **replaces an abstract level number** as the primary progression. How many destinations
  you've unlocked and conquered is the progression.

**Why hub-and-spoke beats open world:** runs smooth on phones (one destination loaded at a time);
concentrates players in the lodge so the world feels alive, not empty; makes every new destination
a modular, shippable content drop.

---

## Progression model: gear + unlocks, not an abstract XP bar

The primary felt progression is the **gear-and-zones ladder**, tied directly to purchases (where
monetization lives):

**money → gear tier → destination access → bigger prey → more money → repeat**

A Roblox kid feels "I just bought the iron rifle and can finally hunt boar" far more than
"Level 14." Optionally layer light **Hunter Rank** and **Angler Rank** systems on top for perk
unlocks and a dopamine bar — but they are secondary, not the gate.

**Destinations are gated by gear tier + a milestone kill/catch**, not just one trophy. E.g. unlock
the Rockies by (a) owning iron-tier gear and (b) downing your first wolf pack. This makes gates
*legible* (the player understands why they can't go yet) instead of random one-shot deaths that
cause rage-quits and downvotes.

---

## The destination tier ladder (the roadmap)

Each location is simultaneously a difficulty tier, a flavor identity, and a gear gate — all
reinforcing each other. Most destinations offer BOTH hunting and fishing so the dual loops travel
together. **This list is the build roadmap.** (Detailed deep-dives happen in per-location chats.)

| Tier | Destination | Hunting (examples) | Fishing (examples) | Gates / Notes |
|------|-------------|--------------------|--------------------|---------------|
| 1 | **Local Bayou (Louisiana)** — STARTER, free | rabbits, ducks (flocks) | catfish, panfish | First-five-minutes zone. Kill/catch + reward in ~60s. No gear gate. |
| 2 | **Appalachia / Midwest** — early | whitetail deer, boar, turkey | trout, bass | First real difficulty step. Basic gear gate. First commitment point. |
| 3 | **Rocky Mountains / Canada** — mid | elk, mountain goat, black bear | salmon, pike | First "gear-or-die" wall (bear), telegraphed. Co-op becomes valuable. Mounts/dogs matter. |
| 4 | **Alaska** — first expedition tier | moose, grizzly, caribou | halibut, king salmon | **Requires first BOAT** for coastal/deep water. Hunting party assumed. |
| 5 | **Africa (savanna)** — high-end big game | dangerous predators (that hunt YOU); photo/conservation framing for charismatic megafauna | tigerfish, Nile perch | Hard gear + passport gate. See appropriateness note below. |
| 6 | **Amazon** — exotic / specialist | jungle predators, ambush gameplay, low visibility | peacock bass, arapaima | Different *feel* (ambush vs open) to keep gameplay fresh, not just bigger numbers. |
| 7 | **Deep Sea / Open Ocean** — fishing endgame | (n/a or sea mammals TBD) | marlin, tuna, sharks, "the white whale" | Requires top-tier boat. Fishing-track culmination. |
| 8+ | **Legendary / Mythic destinations** — endgame & ongoing LiveOps | Arctic, Himalayas, "lost island", rotating/seasonal | TBD per location | The permanent content engine — new mythic destinations drop as updates. |

**The real-world logic makes gear gates feel earned, not arbitrary.** Of course you need an
expedition parka and heavy rifle for Alaska; of course you need an ocean boat for marlin. The
fantasy justifies the progression wall.

---

## Tier floors and ceilings (the design principle for scaling difficulty)

As the player climbs tiers, the **floor and ceiling of difficulty both rise**:

- **Re-skinned low-tier creatures return, bigger and meaner.** There can still be rabbits in
  Alaska — but they're bigger, tougher, and more aggressive. This reinforces the sense of a
  harsher world and lets us reuse behavioral templates with new art/stats.
- **Ambiance creatures grant nothing.** Harmless animals may wander a zone purely for atmosphere;
  killing them gives no reward. This makes the world feel alive and teaches players to identify
  worthwhile targets. (Also a subtle anti-griefing / anti-mindless-slaughter signal.)
- **The ceiling rises faster than the floor** so each tier demands a real gear step — the forced-
  progression pressure that pushes players to level up (WoW-style), but legibly telegraphed.

---

## Region-specific equipment (surfaced by location deep-dives)

Each destination sells **special gear common to its real-world area**, which deepens immersion and
adds region-specific money sinks and goals. Examples to be fleshed out per location:
- **Alaska:** snowshoes, skis, dog sled, cold-weather expedition gear, ice-fishing kit.
- **Africa:** safari jeep, lightweight breathable gear, long-range optics.
- **Amazon:** machete, insect protection, riverboat, camo for dense cover.
- **Deep Sea:** ocean-going vessels, heavy trolling rigs, sonar/fish-finder.

These are surfaced and specified by each location's deep-dive chat, then folded into the master
equipment list.

---

## The trade economy (the long-term moat)

- Each region produces **region-specific rare trophies and record catches** — an albino Alaskan
  moose, a record Amazon arapaima, a legendary Montana elk — that become tradeable status items.
- Rares are **displayable in the lodge trophy hall**, doubling their value (status + emotional
  attachment).
- **Scarcity discipline (the hard part):** do NOT re-release hyped legendaries to juice numbers.
  Mint them carefully and permanently (see 00, §5).
- Every legendary catch/kill is a **content moment** — design the reveal for the screenshot/clip.

---

## Timed & seasonal spawns (return hooks + LiveOps calendar)

Rare creatures spawn under specific conditions, driving the return visits that ARE the retention
signal — and doubling as the LiveOps calendar:
- **Time-of-day:** the legendary buck at dawn.
- **Weather events:** storms make rare fish bite; blizzards spawn rare Arctic predators.
- **Seasonal/migration:** salmon runs, wildebeest migration, tied to *real* hunting/fishing
  seasons → a year-round content schedule for free.
- **Special events:** blood-moon aggressive predators, limited-time legendary spawns.

---

## Mounts, dogs, boats (progression goals AND clean monetization)

All map onto "sell convenience and identity, never pay-to-win":
- **Boats** — gate fishing destinations (access) and flex status. Tiered: jon boat → bass boat →
  ocean trawler. The Alaska/deep-sea gates make them legible goals.
- **Mounts (horse / ATV / safari jeep)** — regional convenience: faster traversal, chase fleeing
  game. Mid-game purchases (players pay to save time once they like the loop), never starter.
- **Tracking dogs** — find rare spawns, track wounded game. Desirable, time-saving, does NOT break
  combat balance. Breeds = collectible identity with regional flavor (coonhound in the bayou,
  husky in Alaska). Rare breeds can be tradeable.

---

## Co-op model

Big game has high health: soloable with top gear as a tense fight, trivial with a party. Pack
enemies in early zones teach grouping naturally. The lodge is where partners meet. Consider
**guided group expeditions** to the hardest destinations (a party books a trip together).
Incentivized, never forced (see 00, §9).

---

## Monetization map (sell with the player)

- **Game passes:** VIP (XP/cash boost + cosmetic flair), boat tiers, hunting dogs, auto-sell
  convenience, cosmetic gun/rod/lodge skins. Multiple price tiers.
- **Developer products (recurring engine):** bait, ammo, time-limited 2x cash/luck boosts,
  passport "fast-track" packs, currency packs.
- **Premium Payouts:** fed by daily quests and timed spawns (session time + return visits).
- **Rewarded ads (opt-in):** free bait, a luck boost, a revive after a grizzly mauls you.
- **Cosmetics = safest, highest-margin money:** gun/rod skins, lodge decor, dog breeds, boat paint,
  regional outfits/camo. Zero balance impact.

**Forbidden:** energy timers, rod-recharge waits, pay-to-win. Roblox players downvote these and the
algorithm penalizes them.

---

## Side quests (light, loop-reinforcing — NOT deep narrative)

Quests are **directed objectives that teach and pace the loop**, not a narrative system Roblox kids
won't read:
- "Catch 5 trout" (teaches fishing), "Down a boar" (pushes to next zone), "Bring the butcher 3
  venison" (money sink + gold faucet).
- **Daily quests are retention gold** — a reason to return every day, and they feed Premium Payouts.
- Keep them mechanical, not literary.

---

## The full player journey (the target experience)

New player lands in the sunny Louisiana bayou. Within 60 seconds: catches a catfish, earns first
cash, a quest arrow points to the Outfitter for a starter rifle. Shoots ducks and rabbits, earns
more. At the Travel Desk, sees a *world map* with Alaska, Africa, the Amazon glowing locked in the
distance — *the hook: I want to go there.* Grinds bayou + Appalachia, buys mid-tier gear, unlocks
the Rockies, hits the first bear wall, teams up with someone from the lodge. Hours in, saving for a
bass boat because Alaskan halibut requires one; buys a husky to track caribou. Lands a record king
salmon during the migration event, mounts it in the trophy hall, trades a spare albino catfish for
an ATV. The Africa expedition drops as this month's update — a new continent, new rares, a live
launch event. Six weeks in, lodge wall filling up, shopping for the ocean trawler to chase marlin.
The Himalayas are teased "coming soon."

**The flywheel:** fast first reward → a visible world of aspiration → legible gear-and-passport
progression → cross-feeding dual loops → optional co-op → timed/seasonal return hooks → a global
trade-and-trophy economy → convenience & identity monetization → an endless pipeline of new
destinations as LiveOps.

---

## Known risks (carry these into every chat)

1. **Scope is the enemy.** "The whole world" is infinitely expandable — the trap. **Launch with the
   minimum that proves the loop: 3 destinations (Bayou, Mountains, Alaska)** — gives the dual loop,
   the first boat gate, and the first real difficulty wall. Let world-expansion BE the update
   engine. Do not front-load eight regions.
2. **Real-world theming needs care on optics.** Hunting charismatic megafauna (elephants, etc.) can
   read badly for a young audience and draw moderation/parent scrutiny. Lean toward
   conservation/photo-safari framing for the most iconic animals; make *dangerous predators that
   hunt the player* the combat threat in those zones.
3. **Balance is the silent killer.** The dual-loop economy is the greatest strength AND most fragile
   point. If hunting/fishing income drift out of balance, or a gear tier is mispriced, the
   progression curve breaks and players quit. Requires real data instrumentation from day one.
4. **Art and game-feel are where it's won or lost.** Engineering rigor covers the systems; it does
   not cover whether shooting feels punchy or reeling feels satisfying, or whether 8 biomes look
   appealing. Budget for an artist; iterate hard on feel.
