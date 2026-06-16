# Glossary — Canonical Terms

> **Purpose.** Ten chats will write about the same concepts. Without a fixed vocabulary they drift
> ("Cash" becomes "coins," "destination" becomes "zone" becomes "region"), and drift breaks the
> ability to assemble the corpus and confuses Claude Code at build time. **Use these exact terms.**
> The schema (02) fixes units; this file fixes words. If a new concept appears in a chat, add it
> here rather than inventing a synonym.

---

## Core nouns (use these, not synonyms)

| Canonical term | Means | Do NOT use |
|----------------|-------|------------|
| **Cash** | the single in-game currency | coins, gold, money, bucks, Sheckles |
| **Destination** | a tier-numbered, fast-travel-able place (Bayou, Alaska...) | zone, region, area, map, level, world |
| **Tier** | the integer 1–8+ difficulty/progression rank of a destination | level, stage, rank (rank is reserved, see below) |
| **The Lodge** | the player's home hub / trophy space | base, home, house, camp |
| **Trophy Hall** | the room in the Lodge where rares are displayed | trophy room, wall, showcase |
| **Trophy** | a displayable item from a notable kill/catch | mount (mount = rideable, see below), display |
| **Travel Desk** | the Lodge interface that opens the World Map | travel menu, map table |
| **World Map** | the globe/map of destinations; the progression spine | level select, map screen |
| **Outfitter** | vendor for weapons + armor | gun shop, armory (armorer is the NPC, ok informally) |
| **Tackle Shop** | vendor for rods, reels, bait, fishing gear | bait shop, fishing store |
| **Trading Post** | the player-to-player trade interface/location | market, auction house, exchange |
| **Rare** | umbrella for above-Common items/creatures/fish | special, exotic (reserve "exotic" for flavor only) |
| **Legendary** | a specific rarity tier (see rarity scale) | epic (epic is its own tier), ultra |
| **Mythic** | the top rarity tier; ~one per destination early on | mythical (adjective ok), god-tier |
| **Mount** | a rideable transport (horse, ATV, jeep, sled) | vehicle (vehicle = boats + mounts collectively, ok) |
| **Boat** | a watercraft that gates fishing destinations | ship, vessel (ok in flavor text) |
| **Tracking Dog** | a companion that finds rare spawns / tracks game | hunting dog (ok informally), pet, hound |
| **Ambiance creature** | a harmless animal that grants no reward | filler, decoration, NPC animal |

---

## Progression terms

| Canonical term | Means |
|----------------|-------|
| **Gear tier** | the tier level of a player's equipment; the primary gate |
| **Passport progression** | how many Destinations a player has unlocked/conquered; the felt sense of advancement |
| **Hunter Rank** | the optional light leveling track for hunting (secondary to gear) |
| **Angler Rank** | the optional light leveling track for fishing (secondary to gear) |
| **Gate / gating** | the requirement (gear tier + milestone kill/catch) to unlock a Destination |
| **Milestone kill / catch** | the specific creature/fish required (with gear) to unlock the next Destination |
| **Floor / ceiling** | the lowest and highest difficulty within a tier; both rise as tiers climb |

---

## Economy & monetization terms

| Canonical term | Means |
|----------------|-------|
| **Faucet** | any source that pays Cash into the economy |
| **Sink** | anything that removes Cash from the economy |
| **Per-loop income** | Cash earned per hour from hunting vs. fishing; must stay roughly balanced |
| **Game pass** | a permanent, one-time real-money purchase (Roblox term — keep as-is) |
| **Developer product** | a repeatable, consumable real-money purchase (Roblox term — keep as-is) |
| **Premium Payout** | Roblox revenue from Premium subscribers' engagement time (Roblox term) |
| **Rewarded ad** | opt-in video ad exchanged for an in-game reward (Roblox term) |
| **Identity monetization** | selling self-expression (cosmetics, decor) — the safest category |
| **Convenience monetization** | selling time-savings (boosts, auto-sell, mounts) |
| **Scarcity discipline** | the rule that minted rares are NEVER re-released to juice numbers |

---

## Systems & build terms

| Canonical term | Means |
|----------------|-------|
| **Dual loop** | the two cross-feeding gameplay loops (hunting + fishing) sharing one Cash + one upgrade tree |
| **MVL** | Minimum Viable Loop — the 3-Destination launch (Bayou, Appalachia, Alaska) |
| **Server-authority** | the rule that the server owns all economy/inventory state; the client never asserts it |
| **Anti-dupe** | safeguards preventing item duplication (existential for the trade economy) |
| **D1 / D7 / D30** | next-day / 7-day / 30-day player return rates; the core retention metrics |
| **First-five-minutes funnel** | the onboarding sequence: comprehension + visible progress + soft purchase setup |
| **Content moment** | a designed screenshot/clip-worthy event (e.g. a Mythic catch) for creator content |
| **LiveOps** | scheduled live operations: events, seasonal spawns, limited-time content, run as a calendar |

---

## Project meta terms

| Canonical term | Means |
|----------------|-------|
| **The corpus** | the full set of design/research `.md` files that compile into build prompts |
| **Deep-dive** | a single-purpose chat producing one `LOC_*` or `SYS_*` document |
| **Template A–F** | the fixed output formats in doc 02 (A=location, B=equipment, C=creature, D=fish, E=rare, F=system) |
| **Anchor docs** | 00, 01, 02 — read at the start of every chat |
