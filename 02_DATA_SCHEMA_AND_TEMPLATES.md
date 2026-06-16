# Data Schema & Deep-Dive Templates

> **Purpose — read this carefully.** This is the most important operational document in the
> project. Ten different chats will produce research. If they don't write to a *shared schema*,
> the outputs won't compose and Claude Code can't assemble them. **Every deep-dive chat MUST
> produce output in the exact templates below.** When you start a location or systems chat, paste
> the relevant template and instruct the chat to fill it out completely.
>
> **Units convention (global, non-negotiable):**
> - **Currency:** in-game "Cash" (define final name later). All prices in Cash.
> - **Weight:** kilograms (kg) for everything — animals, fish, gear weight capacity. Pick ONE unit
>   and never mix. kg chosen.
> - **Tier:** integer 1–8+ matching the destination ladder in doc 01.
> - **Rarity scale (fixed, use these exact labels):** Common → Uncommon → Rare → Epic → Legendary
>   → Mythic. Spawn rates expressed as 1-in-N.
> - **Stat scale:** all combat/quality stats on a 1–100 scale for cross-comparability.

---

## TEMPLATE A — Location Deep-Dive

> One per destination. Output filename: `LOC_<tier>_<name>.md` (e.g. `LOC_01_bayou.md`).

```markdown
# Location: <Name> (Tier <N>)

## 1. Identity & Story
- **Real-world basis:** <place>
- **One-line feel:** <the emotion the player should have here>
- **The story this place tells:** <2–4 sentences. What makes the player feel they are HERE.
  This is the "each map tells its own story" requirement.>
- **Sensory signature:** <signature sounds, light, weather, color palette — what makes it
  instantly recognizable and distinct from other tiers>

## 2. Map Features & Layout
- **Terrain types:** <list — e.g. swamp, bayou channels, cypress stands>
- **Landmarks (recognizable, compelling):** <named, memorable locations a player navigates by>
- **Functional zones:** <where hunting happens, where fishing happens, vendor outpost location,
  spawn/arrival point>
- **Traversal notes:** <on foot? needs a mount? a boat? what region-specific transport applies>
- **Performance notes:** <anything that affects mobile rendering — view distance, density>

## 3. Wildlife Roster (Hunting)
> Use the Creature Stat Block (Template C) for EACH entry. List in ascending difficulty.
- Ambiance-only (grants nothing): <list>
- Tier floor creatures (incl. re-skinned lower-tier "bigger & meaner"): <list>
- Mid creatures: <list>
- Apex / ceiling creatures: <list>

## 4. Fish Roster (Fishing)
> Use the Fish Stat Block (Template D) for EACH entry. List in ascending difficulty.
- Common catches: <list>
- Mid catches: <list>
- Trophy catches: <list>

## 5. Rare & Mythical Spawns
> Use the Rare/Legendary Block (Template E) for EACH. This is the trade-economy + content layer.
- **Rare variants:** <e.g. albino buck, golden catfish>
- **Legendary creatures:** <named, iconic to this region>
- **Mythical creature:** <1 per region max early on — the region's "white whale">
- For each: spawn condition (time/weather/season/event), spawn rate (1-in-N), what it drops,
  whether it's tradeable, and the intended content/screenshot moment.

## 6. Region-Specific Equipment
> Gear sold ONLY here or first available here. Use Equipment Stat Block (Template B).
- <e.g. snowshoes, dog sled, ice-fishing kit — with stats and Cash price>

## 7. Gating (entry & exit)
- **To UNLOCK this destination:** <gear tier required + milestone kill/catch>
- **To progress PAST this destination:** <what this tier pushes the player to buy/achieve next>

## 8. Economy Hooks (hand-off to economy chat)
- **Cash faucets here:** <what pays out, rough ranges — to be tuned in economy doc>
- **Cash sinks here:** <what costs money here>
- **Per-hour income band (rough):** <so the economy chat can balance against other tiers>

## 9. LiveOps / Event Ideas
- <seasonal events, migrations, limited-time spawns tied to this region>

## 10. Open Questions / Flags
- <anything unresolved for a future pass>
```

---

## TEMPLATE B — Equipment Stat Block

> For weapons, armor, rods, fishing gear, vehicles, mounts, dogs, tools. Output accumulates into
> the master equipment list (`EQUIPMENT_MASTER.md`). Use this block so every item is comparable.

```markdown
### <Item Name>
- **Category:** weapon | armor | rod | reel | bait | tackle | vehicle | mount | dog | tool | cosmetic
- **Tier:** <1–8>  (the destination tier where it becomes relevant/available)
- **Available at:** <Outfitter / Tackle Shop / region-specific vendor / boat dealer>
- **Cost:** <Cash>  (or: game pass / dev product — note if real-money)
- **Primary stat(s):** <e.g. Damage 45/100, Range 60/100 | Armor 30/100 | Catch-Power 50/100>
- **Weight:** <kg>  (and for armor/vehicles: weight capacity granted, if any)
- **Strengths:** <what it's good for / what prey or fish it unlocks the ability to take>
- **Weaknesses / limits:** <what it CAN'T do — important for forcing progression>
- **Gates unlocked:** <does owning this open a destination or a prey tier?>
- **Monetization role:** identity | convenience | access | power-progression
- **Notes:** <flavor, regional ties, cosmetic variants>
```

**Cross-item balance rules (enforced by the equipment chat):**
- Every tier's weapons must be able to kill that tier's floor creatures but NOT its apex without
  effort/co-op. Every tier's apex requires roughly the *next* tier's weapon to take solo.
- Armor follows the same logic for survival: a tier's apex predator should be able to kill a player
  wearing that tier's armor unless they play well; the next tier's armor makes it safe.
- Rods/reels gate fish the same way weapons gate game.
- Weight matters: heavier gear may slow the player or require a mount/vehicle (a convenience sink).

---

## TEMPLATE C — Creature Stat Block (Hunting)

```markdown
### <Creature Name>  [Tier <N>]
- **Rarity:** Common | Uncommon | Rare | Epic | Legendary | Mythic
- **Ambiance-only?:** yes/no  (if yes, grants no reward; for atmosphere)
- **Behavior:** passive | flees | aggressive | pack | ambush
- **Pack size:** <if pack>
- **Health:** <1–100 scale, relative within game>
- **Damage to player:** <1–100>
- **Speed:** <1–100>  (affects whether a mount is needed to chase)
- **Min weapon tier to kill:** <tier>   **Min armor tier to survive:** <tier>
- **Co-op recommended?:** solo-with-top-gear | duo | party
- **Drops / reward:** <Cash value range, meat/hide/trophy, trade items>
- **Re-skin of:** <lower-tier creature, if this is a "bigger & meaner" variant>
- **Spawn:** location within map + any time/weather/season condition
```

---

## TEMPLATE D — Fish Stat Block (Fishing)

```markdown
### <Fish Name>  [Tier <N>]
- **Rarity:** Common | Uncommon | Rare | Epic | Legendary | Mythic
- **Typical weight range:** <kg>   **Record/trophy weight:** <kg>
- **Fight difficulty:** <1–100>  (how hard to reel — gates on reel/rod power)
- **Min rod tier / reel tier to catch:** <tier>
- **Bait/lure required:** <if any>
- **Water type:** pond | river | lake | coastal | deep sea
- **Drops / reward:** <Cash value range; tradeable if rare>
- **Spawn / bite condition:** time/weather/season/event (e.g. "bites during storms")
```

---

## TEMPLATE E — Rare / Legendary / Mythical Block

```markdown
### <Name>  [Legendary | Mythic]  — <region>
- **Type:** hunting trophy | record fish | special creature
- **Base creature/fish:** <what it's a variant of, if any>
- **Spawn condition:** <exact — time of day, weather, season, event, or combination>
- **Spawn rate:** 1-in-<N>  (be deliberate — this drives scarcity and trade value)
- **Reward:** <Cash + unique trophy item>
- **Tradeable?:** yes/no  (most legendaries: yes — the economy moat)
- **Displayable in lodge?:** yes/no  (usually yes — the status layer)
- **Re-release policy:** <default: NEVER re-release; permanent scarcity. Note exceptions explicitly>
- **Intended content moment:** <the screenshot/clip this is designed to produce>
```

---

## TEMPLATE F — System Spec (for non-location systems chats)

> For chats deep-diving the economy, combat, fishing mechanics, progression, lodge/trophy system,
> trading system, LiveOps calendar, onboarding funnel, etc. Output: `SYS_<name>.md`.

```markdown
# System: <Name>

## Purpose & player-facing goal
<what this system does and the player experience it creates>

## How it ties to the formula
<which Research Foundation principles it serves — retention? monetization? trade moat?>

## Mechanics (detailed)
<the actual rules, numbers, formulas, state>

## Inputs / dependencies
<what other systems or data this needs — reference exact doc names>

## Outputs / what depends on this
<what consumes this system>

## Tuning parameters
<the knobs we'll adjust with data — list them explicitly for instrumentation>

## Claude Code build notes
<implementation guidance: data structures, services, edge cases, anti-cheat considerations>

## Open questions / flags
```

---

## File naming convention (so Claude Code can find everything)

```
00_RESEARCH_FOUNDATION.md         (anchor — the winning patterns)
01_GAME_DESIGN_OVERVIEW.md        (anchor — our game)
02_DATA_SCHEMA_AND_TEMPLATES.md   (this file)
03_BUILD_PLAN.md                  (the systematic build sequence + Claude Code handoff)
04_GLOSSARY.md                    (canonical terms — one name per concept, prevents drift)
05_COMPETITIVE_LANDSCAPE.md       (the market gap + competitor failures — differentiation guardrail)

LOC_01_bayou.md                   (location deep-dives)
LOC_02_appalachia.md
LOC_03_rockies.md
LOC_04_alaska.md
...

SYS_progression.md                (system deep-dives)
SYS_economy.md
SYS_combat.md
SYS_fishing.md
SYS_data_integrity.md             (persistence, server-authority, anti-dupe — EXISTENTIAL)
SYS_lodge_trophy.md
SYS_trading.md
SYS_liveops_calendar.md
SYS_onboarding_funnel.md

EQUIPMENT_MASTER.md               (accumulated from all Template B blocks)
```

**Rule:** location chats produce region-specific equipment in Template B format; those blocks get
merged into `EQUIPMENT_MASTER.md` so there is ONE canonical, balanced equipment list. The equipment
chat owns the master list and resolves cross-tier balance.
