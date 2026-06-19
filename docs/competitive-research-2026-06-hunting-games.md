# Competitive Landscape Briefing — Roblox Hunting Games
_Prepared for Wild World · 2026-06-19 · multi-agent web research (20 agents) + first-hand screenshot review_

> **Framing:** The three games originally requested resolved to **two real games plus one phantom**.
> **"Major Hunt" does not exist** as a Roblox experience — Roblox's omni-search API returns zero
> games with "Major" in the title across six spelling variants. The "~7 players / 33% rating"
> detail was a search-summarizer hallucination (closest red herring: *The Hunt: First Edition*,
> Roblox's dormant 2024 event hub, ~7 players but 88% likes). The intended referent is almost
> certainly **Gone Hunting**, our direct concept-twin. This briefing therefore covers **Gone
> Hunting** and **Hunting Season** in depth, with **Foresto** as a sentiment benchmark.

---

## 1. Snapshot

| Game | Visits | CCU now / peak | Likes | Graphics (first-hand) | Identity |
|---|---|---|---|---|---|
| **Gone Hunting** (Wallaby Wiggins) | ~11.5M | ~100 / ~5,145* | **82%** | **Mid (cozy-stylized)** | Relaxing hunt + fish + **offline-trap** collection RPG w/ dynamic weather |
| **Hunting Season** (Josima Studios) | ~105.5M | ~900 / ~16,440* | **71%** | **Mid-high** | Realism sim: track → stalk → clean shot → trophy lodge |
| **Foresto** (reference) | ~12.2M | ~620 | **90%** | Mid (moody) | Grittier, almost-horror survival-hunt — genre's sentiment ceiling |
| ~~Major Hunt~~ | — | — | — | — | **Does not exist** — treat as Gone Hunting |

\*Peak CCU is Rolimons-only and unverifiable. All other numbers cross-confirmed (Roblox API + Rolimons).
Both leaders have collapsed from peak — **retention decay, not launch sentiment, is the genre's real failure mode.**

Date corrections: Gone Hunting created 2025-08-22 (Studio) ≠ launched ~2025-09-20 (public).
Hunting Season is now **v0.15.1** (2026-05-26), not the stale v0.6.x in older guides.

---

## 2. Per-game deep dive

### Gone Hunting — the concept-twin
- **Loop:** three activities with distinct jobs — **hunting** = skill rifle minigame ("aim for the
  middle"), the most efficient grind; **fishing** = tap-to-reel; **trapping** = the passive/offline
  earner (6-trap cost/cooldown ladder, $200/1min → $4,000/12hr). Single currency, sell-to-upgrade.
  Gear tiered by DMG multiplier **+ a % chance to roll a mutation**.
- **Signature system — global dynamic weather:** 8 types (~5 min each), each unlocking one exclusive
  animal + fish + **mutation trait**. "Trait farming" (timing sessions to weather windows, stacking
  traits) is a real player meta — there is literally a `TRAITFARMING` code. End-goal = a **Bestiary** index.
- **Missing:** single biome, **no boats/mounts/dogs, no trading, no true co-op** (16-player shared room).
- **Monetization — lean, convenience-only:** exactly 4 passes, all <500 R$ — Sell-Anywhere (299),
  Auto-Collect traps (349), VIP (499), offsale Starterpack. **No dev products, no 2x pass, no luck pass.**
  Power/luck given free via codes; XP boost bought with in-game cash, not Robux.
- **Reception:** praised as relaxing + fresh (weather/mutations); criticized for **grind** and
  **faucet imbalance** (hunting out-earns fishing/trapping → two loops feel vestigial). ~97% retention
  decay from peak; ~12-min sessions.

### Hunting Season — the realism incumbent
- **Loop:** scout (binoculars) → read age-graded tracks → stalk downwind (modeled vision + hearing) →
  one precise shot at a vital organ → harvest → **score-based payout**. The **kill score** weighs
  animal factors (type/gender/age/weight/fur/difficulty) × shot quality (vital hit, shot count,
  caliber match, distance, velocity). ~9 real-named guns, ballistic ammo economy (FMJ/hollow/slug/
  buck/birdshot), callers, upgradeable trophy **Lodge**, **200-player co-op**. **No fishing, no trapping.**
- **Monetization:** 4 passes, no dev products — ATV (399), Thermal Scope (379), **Enhanced Hunter /
  pay-for-info (239)**, Hunting Towers (149). Gear earned, never sold for Robux.
- **Reception:** the "serious sim" of the niche; 71% ratio is normal at 105M scale. Criticized for a
  **punishing newcomer curve** ("empty shots," a hidden E + right-click scanning trick) and beta bugs.

---

## 3. First-hand visual review (screenshots actually viewed)

> Competitor store screenshots were downloaded and viewed directly; Wild World was captured live in
> Studio (edit mode, ClockTime ≈ 6.7 / dawn, Atmosphere + 6 post-FX active). This section is **primary,
> not second-hand.**

**The genre bar:** none of these games win on geometry. They win on **lighting + atmosphere +
art direction**: golden-hour/dawn-dusk light, autumn or moody palettes, atmospheric haze/fog,
a polished **first-person weapon layer**, **detailed animal meshes** — all on **stock blocky avatars**,
plus strong poster/mascot marketing art.

- **Gone Hunting (live in-game shot reviewed, 2026-06-19):** the store **thumbnails undersell it** — they
  are meme clickbait (a Skibidi-style face popping from a trap; flat-green scope backgrounds) plus a blocky
  mascot (plaid jacket + crown, screaming) in golden-hour *poster* renders. The **actual game is markedly
  more polished**: the hub **"Hunters Hollow"** is a competent **cozy-stylized village** — custom wooden
  shop buildings with shingled roofs (Wallaby Co. Animal Exports, Johnston Outdoors), hand-painted signage,
  cobblestone paths, manicured grass, mushroom props, rounded low-poly trees, warm light + hill haze.
  Avatars are fully stock/player-customized (Spider-Man skins, lightsabers). The distinctive *mechanic*
  visual is the scope **thermal/X-ray vital overlay** (animal glows cyan w/ red organ hotspots = "aim for
  the middle"). **Verdict: mid, cozy-stylized — a different art philosophy than Wild World's grounded-
  naturalism, but cohesive and competent. Concept + systems + marketing still carry it more than fidelity.**
  _Live HUD intel:_ a persistent **"Next global dimensional spawn in: HH:MM:SS"** countdown surfaces the
  live-ops/weather layer directly; catches are carried as named items with a **weight stat** ("Sika Deer
  [201.7 lb]"); an onboarding quest ("The Beginner's Guide → sell your catch") steers the first loop;
  commerce is **split into a SELL vendor vs BUY shops** with large floating labels.
- **Hunting Season (viewed):** best in-engine environment of the three — naturalistic **autumn forest,
  warm low sun, god-rays, atmospheric haze, depth-of-field**, a polished **first-person ADS rifle**, and
  detailed **bear/deer meshes** — but the **player avatar is left stock blocky**. (Its lion-pounce hero
  image is a painterly marketing render that oversells the baseline.) **Verdict: mid-high.**
- **Foresto (viewed):** lowest geometry but **highest mood** — dark pine forests, glowing-eyed deer,
  bunker scenes with narrative captions ("Lost… Alone", "Oh… Deer"). Atmosphere + framing, not fidelity,
  drive its 90% rating.

**Wild World (captured live):**
- **Bayou — genuinely strong.** Atmospheric flooded **cypress swamp**: buttressed/flared trunks rising
  from standing water with reflections, naturalistic canopies, pastel **dawn sky**, horizon haze. Clearly
  **beats Gone Hunting** and sits in **the same atmospheric league as Hunting Season** (HS still has
  denser foliage + DoF + first-person weapon polish). The cypress-swamp setting is a **distinctive biome**
  most competitors don't have.
- **Appalachia — solid mid-tier.** Rolling green hills, conifers with real silhouettes, a ridge structure,
  same dawn light + haze. Good mood.
- **Alaska — solid mid-tier.** Snowfields, dark conifers, a snow-capped peak, heavy atmospheric fog that
  flatters it. Reads as cold wilderness.
- **Lodge — the weak point.** Currently a **plain untextured box** (walls + a chimney block, no roof
  detail) on flat ground. Given the genre proves the **trophy lodge is both a production-value showcase
  and a retention pillar** (Hunting Season), this is the single highest-value visual fix.
- **Rough edges seen:** dark **floating quads** in the bayou water (duckweed/lily-pad parts reading as
  black rectangles), flat **decal-card** moss/foliage at close range, visible hard **terrain edges** /
  map boundary, and **flat translucent water** (no shader polish).
- **Not yet measured here:** creatures/weapons/HUD/first-person and the catch/harvest moment — i.e.
  exactly the axes Hunting Season polishes (first-person weapon layer, detailed animals, score readout).
  Creature mesh upgrade is a known in-progress workstream.

**Net graphics verdict:** Wild World's **environments already meet or beat the genre's effective bar**
on atmosphere and biome distinctiveness. The deltas to "flagship" are: (1) finish the **Lodge**,
(2) clean the **rough edges** (floating quads, water, map edges), (3) match Hunting Season's
**first-person weapon polish + animal-mesh detail + a screenshot-worthy harvest moment**.

---

## 4. Takeaways for Wild World (prioritized)

- **P0 — Retention is existential, not the loop.** Both leaders cratered from peak; the core hunt+fish
  loop is commoditized (Gone Hunting hit 11M visits on one biome, no co-op). Wild World's differentiators
  — biome breadth, boats/mounts/dogs, lodge/trophy hall, trading, live-ops calendar — are the **retention
  insurance** against that decay curve. Lead with breadth + depth.
- **P1 — Convenience-only monetization is what this audience rewards.** Our closed never-power
  ProductGrant model (Step 14) matches the genre. Keep idle-convenience passes (monetize T_idle) + an
  info-edge pass (Hunting Season's Enhanced Hunter is the template). Stay <500 R$ for the core lineup.
- **P2 — Steal the weather→rarity layer.** Gone Hunting's dynamic weather → exclusive spawns + stackable
  traits is the genre's best engagement multiplier and we lack it. **Vehicle: the live-ops calendar
  (Step 13)** — time-limited rarity/trait windows. Highest-leverage *new* system to add. _(See spec.)_
- **P3 — Balance the three faucets.** Their fatal flaw: hunting out-earns fishing/trapping. Keep
  idle/trapping a supplement, never the optimal earner (per-loop EHT/EFT, Step 15, is the tool — verify
  the daily pair stays competitive with idle).
- **P4 — Win onboarding** — the genre's unsolved problem (HS "empty shots" + hidden trick; GH early grind).
  Our data-driven funnel (Step 7) is a real edge if first catch lands in the first 60 seconds.
- **P5 — Graphics: finish the Lodge + match HS's split.** Invest in lighting/atmosphere (already strong) +
  first-person weapon polish + animal meshes; leave the avatar stock. Make the **Lodge/Trophy Hall** and a
  **screenshot-worthy harvest screen** the showcases. _(See storyboard.)_
- **P6 — Add a daily-reward loop** (Step 7 daily skeleton) — neither leader confirmedly has one. But don't
  let promo codes become the engagement crutch.
- **P7 — Protect the moat:** trading + anti-dupe, vehicles/companions, cross-biome map, real live-ops —
  all absent from both competitors.

---

## 5. Confidence & caveats
- **"Major Hunt" is a phantom** — all analysis of that slot is Gone Hunting by proxy.
- **Cross-verified (high):** visits, favorites, like ratios, server caps, creation dates, gamepass
  prices/IDs for both real games (Roblox API + Rolimons).
- **Unverifiable (single-source):** all-time peak CCU for both games (~5,145 / ~16,440).
- **Graphics are now first-hand** for all three competitors + Wild World (this revision). Earlier drafts
  rated Gone Hunting second-hand; direct viewing **lowered** it to low-mid.
- **Not assessed:** in-game HUD/UI legibility for competitors (not visible in store shots); Wild World
  creatures/weapons/first-person/harvest UI (not yet captured).
- Don't conflate "Hunting Season [BETA]" with the deleted "Hunting Season REBIRTH" (separate failed title).

**Primary sources:**
[Gone Hunting](https://www.roblox.com/games/132128062320193/Gone-Hunting) ·
[Gone Hunting Wiki](https://gonehunting.fandom.com/wiki/Gone_Hunting) ·
[Hunting Season](https://www.roblox.com/games/5286116071/Hunting-Season) ·
[Hunting Season Wiki](https://roblox-hunting-season.fandom.com/wiki/Hunting_Season_Wiki) ·
[Hunting Season v0.6.1 devforum](https://devforum.roblox.com/t/hunting-season-update-v061/3181230) ·
[Foresto](https://www.roblox.com/games/12575645876/Foresto-Hunting-Game)

_Screenshots were fetched via Roblox's thumbnails API (`thumbnails.roblox.com/v1/games/multiget/thumbnails`)
and viewed directly; Wild World captures via the Studio MCP `screen_capture` at dawn lighting. Both are
reproducible._
