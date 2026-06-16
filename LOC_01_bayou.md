# Location: Louisiana Bayou (Tier 1)

> **STARTER Destination — the first MVL location, and the canonical Template A example for LOC_02 /
> LOC_03.** This doc owns the **PLACE**; SYS_onboarding_funnel owns the **PATH** through it. Read both
> together — the seam (§2.6) is binding, not a courtesy.
>
> **v1.2 (lock pass).** One correction, zero stat changes (the roster is build-ready as-is). The v1.1
> "starter-rod snaps at ≈ FD 38" claim was wrong by its own inequality: `LandWindow = max(30 − 0.6·FD, 0)`
> reaches zero (the actual **snap**) only at **FD 50**. At FD 38 the rod still holds positive headroom
> (LandWindow 7.2); that failure is a **reel-bound throw/timeout** (drain too slow), not a rod snap. So
> the T1 catchable ceiling (≈ FD 37) is set by the **starter reel**, not the rod, and the rod snap is
> ≈ FD 50 — corrected in §4 header, change #2, and flag #3. A wrong-number-stated-as-insight that would
> propagate if LOC_02/03 reasoned from it by analogy; locked here.
>
> **v1.1 (review pass).** No structural change; five corrections found by re-deriving the bands against
> the stat math. (1) **Fishing milestone retuned from FightDifficulty 36 → 34** so it is *comfortably*
> landable on the free starter rig (landing margin ~1.0 s → ~3.0 s) — the v1 value was tense, violating
> fishing §8's "deliberately light, protects D1." (2) **The starter-rod fish-compression insight is
> surfaced** (§4 header; snap-point corrected in v1.2): the starter **reel** (DrainMax 9), not the rod,
> caps the T1 catchable ladder at ≈ FightDifficulty 37 (a reel-bound throw — the rod does not snap until
> ≈ FD 50), so the fish ladder is *necessarily* compressed and the milestone's "big one" feel must come
> from size, not fight. (3) **The rare-rate double-count is corrected** (§5): v1 stacked large flat 1-in-N
> values on top of already-heavy condition-gating, compounding to *unreachable* — contradicting
> "accessible-but-rare." v1.1 lowers the per-window 1-in-N and introduces **effective rarity =
> per-window roll × condition frequency** as the real tuning target. (4) **A genuine upstream gap is
> flagged, not inherited silently** (§8.4 / §10): this roster's mechanical FightTimes (~2–7 s) sit well
> below fishing §5's modeled ~18 s rate input — part of the "ExpectedTargetsPerHour is the load-bearing
> unknown" reconciliation, surfaced for the joint tuning pass. (5) **Spawn-throughput ceilings are
> stated with the throttle-vs-leak trade-off** instead of an over-precise single number. Changes from v1
> are listed at the end.
>
> **Inherited as binding (consumed, not re-litigated):** SYS_progression v2.1 (Tier 1, no gear gate,
> free starter loadout, EHT 1 armorless / EFT 1 on arrival, light conquest milestone, OR-gate);
> SYS_economy v2.1 (`Income(1)` ≈ 1,000 Cash/hr band, payout *computed* `Income(T)÷ExpectedTargetsPerHour`,
> RarityMultiplier ladder, spawn-density-cap dependency); SYS_combat v1.1 (floor ≤ 2–3 shots on starter,
> **non-lethal Tier-1 clamp**, archetypes, the spawn-density cap *mechanism* this doc sets values
> within, rares as independent condition-gated spawns RD-E, ambiance grants nothing); SYS_fishing v1.1
> (floor landable on free starter rod+reel, bite-density caps, water types §7, rares condition-gated
> Decision 3, signature-catfish milestone §8); EQUIPMENT_MASTER (starter loadout §4.1/§4.3/§4.4, T1
> intra-tier climb §2, Coonhound §4.7, basic bait §4.8); SYS_data_integrity (rares mint **one** unique
> artifact, **write no Cash at kill/catch**, disposition XOR); SYS_lodge_trophy (the Travel surface).
>
> **What this doc authors vs. cites.** It authors the *place*, the *roster*, the per-target *engagement
> inputs* (creature Health/Damage/Speed and KillWindow inputs; fish FightDifficulty/weights; per-area
> spawn-density and bite-density values), the *rares* and their conditions, and the region gear in
> Template B. It **cites** every Cash value (economy owns the band; per-target Cash is computed from it),
> the combat/fishing math, and the gear *balance* (EQUIPMENT_MASTER owns it). Cash figures shown are
> *computed illustrations from economy's band*, not authored here — flagged as such.
>
> **Numbers convention** (matching the SYS_ docs): formulas/relationships are the design; every
> magnitude is an *illustrative default*, a calibration knob, validated against live data. Stats on
> 1–100, weight in kg, Cash currency, rarity Common→Mythic, spawn rates 1-in-N.

---

## 1. Identity & Story

- **Real-world basis:** the Louisiana / Atchafalaya bayou country — slow tea-colored channels, cypress
  stands hung with Spanish moss, levees and oxbow ponds. A place a 13-year-old recognizes on sight (the
  real-world-legibility lever, 00 §10 / 01): "a bayou" needs no explanation, which is exactly why it is
  the first impression.
- **One-line feel:** *huntin', fishin', and lovin' every day* — sunny, warm, gentle, unhurried. The
  Bayou's job is to make a brand-new player feel **competent and welcome in the first sixty seconds**
  (00 §3 — D1 lives here).
- **The story this place tells:** This is home turf — a humble local backwater where a kid learns to
  shoot and to fish before the world gets big and scary. Nothing here wants to kill you (combat §4 — the
  Tier-1 non-lethal clamp, extended across the whole Bayou roster, §3). The water is generous, the game
  is easy, and the only pressure is the glowing pins on the World Map promising somewhere *bigger*. The
  Bayou is the porch you leave from, and — once you have a Lodge — the easy water you come back to.
- **Sensory signature:** warm low-gold light through moss-draped cypress; a wall of cicada, frog, and
  birdsong; the lazy plop of a feeding fish and the occasional far-off gator bellow; dragonflies over
  still tea-brown water; a faint cajun-fiddle ambience near the Landing. Palette: warm greens, amber,
  honey light, muddy-gold water. The signature read is **stillness + warmth + sound** — instantly
  distinct from Appalachia's cool ridgelines or Alaska's white glare, and the cheapest possible "this
  world is alive" cue (00 §8 — engagement from atmosphere, not polygon count).

---

## 2. Map Features & Layout

### 2.1 Terrain types
Cypress swamp and flooded timber; slow bayou channels and a deeper oxbow ("the catfish hole"); raised
levees and dry hunting flats; reed beds and grassy verges (duck and rabbit cover); scattered patches of
higher dry ground. One compact, walkable footprint — this is the smallest, most legible Destination by
design (it is a tutorial space first).

### 2.2 Landmarks (recognizable, navigate-by-looking)
- **The Landing** — a weathered dock + general-store shack: the social anchor and vendor outpost
  (Outfitter + Tackle Shop access points) and the Bayou-side **travel signpost** (a posted map board /
  pirogue dock). This is the heart of the seam (§2.6).
- **The Old Cypress** — a single huge lightning-split cypress visible from most of the map: the primary
  wayfinding beacon (a child navigates by it, 00 §2 legibility).
- **Sunny Levee** — the dry hunting flat beside the arrival clearing (rabbits, duck flocks on the
  reed-edge): the first-hunt ground.
- **The Catfish Hole** — the deep oxbow off the main channel: the best fishing water and the
  rare/legendary catfish condition site.
- **Cottonmouth Slough** — a fog-prone back-channel of deep cypress shade: the White Gator (Ghost Gator)
  condition site.

### 2.3 Functional zones
- **Arrival / spawn clearing** — a sunlit levee spot beside the Landing; faces the Sunny Levee (first
  hunt) with the channel bank a few steps off (first fish). Owns the §2.6 first-spawn guarantee.
- **Hunting** — the Sunny Levee and reed-edges (floor game); Cottonmouth Slough and channel banks (the
  signature alligator / milestone).
- **Fishing** — all shore-accessible (fishing §7, water type *bank/pond*): the channel banks, the
  Catfish Hole oxbow. **No Boat required** at Tier 1 (a Jon Boat is cosmetic convenience only —
  EQUIPMENT_MASTER §4.5).
- **Vendor outpost** — the Landing (Outfitter + Tackle Shop interfaces; same vendors as the Lodge,
  surfaced Bayou-side for the funnel).
- **Travel surface** — the Landing's travel signpost (opens the World Map; §2.6).

### 2.4 Traversal notes
On foot only. No mount, no boat needed (Mounts start at Tier 3 — EQUIPMENT_MASTER §4.6; Bayou fish are
shore-accessible — fishing §7). Floor game is **shot as it flushes or breaks, within its escape window —
not run down** (the duck flock is shot on the flush; the rabbit on its break), so a player on foot is
never out-paced by fleeing game — a deliberate gentleness choice (a fleeing target a new player *can't*
resolve would read as failure and cost D1). The whole map is crossable in well under a minute so the
funnel's distance targets are physically achievable (§2.6).

### 2.5 Performance notes (mobile-first, 00 §8)
Low-poly throughout; the art budget goes to the thumbnail/icon, not the geometry. **Swamp fog doubles as
the view-distance budget** — atmospheric *and* a cheap far-LOD cull (the Bayou's signature look is also
its render strategy). Dense cypress provides natural occlusion; the water is a flat plane with a cheap
shader; duck flocks and dragonflies are instanced/flocked low-cost "alive" signals. Single compact
footprint → low draw distance, high frame rate on phones. Frame rate beats fidelity (00 §8).

### 2.6 THE ONBOARDING SEAM — how this map satisfies the funnel's three placement requirements (binding)

SYS_onboarding_funnel hands LOC_01 three placement requirements (funnel §Inputs, §build-notes). The PATH
is the funnel's; the PLACE below is this doc's, built to make the funnel's timing targets (≤ 60 s to
first reward, World Map by minute 3–4) **physically achievable**.

1. **Guaranteed-present, CLOSE first hunt spawn AND first fish spot at the arrival point.** The arrival
   clearing faces the Sunny Levee (a guaranteed Swamp Rabbit / Wood-Duck flock within a few steps) and
   sits a few steps from a channel bank (a guaranteed first bite). **The *first* of each is a funnel-owned
   guaranteed spawn that bypasses this Destination's normal `MaxConcurrentTargets` / `RespawnInterval`
   and `MaxConcurrentBites` / `BiteRespawnInterval` caps (§8) — scoped to the arrival area and the
   first-time player only.** Every target after the first obeys the caps, so the override does **not**
   leak into a low-tier-farming hole (combat §5 / fishing §6, funnel §build-notes "first-spawn
   guarantee"). A new player never stands in an empty field; a returning or over-geared player gets no
   special spawns here.
2. **First-purchase vendor within a SHORT WALK of the opening loops.** The Landing (Outfitter + Tackle
   Shop) is ~15–20 s on foot from the arrival clearing, in line of sight of both the levee and the bank.
   The first-purchase beat (funnel beat 3 — the first T1 intra-tier upgrade, economy §3) is therefore
   contiguous with the loop the player just acted on.
3. **World-Map / Travel surface reachable by funnel beat 4 (~minute 3–4).** The Landing's **travel
   signpost** (a posted map board / pirogue dock) opens the **same World Map** the Lodge Travel Desk
   opens (SYS_lodge_trophy presents it; SYS_progression owns its gating). It is co-located with the
   vendor outpost, so beat 4 (World Map reveal) follows beat 3 (first purchase) **with no Lodge
   round-trip and no loading screen** — the sequencing the funnel needs (funnel §4).

**First-session spawn exception (seam reconciliation, flagged §10).** SYS_lodge_trophy specifies that
spawning lands a player in the Lodge. SYS_onboarding_funnel §0 specifies that a *first-time* player loads
into the Bayou arrival point. These reconcile cleanly: the **direct-to-Bayou spawn is the onboarding-owned
first-session exception**; LOC_01 places that arrival point (here). Once the funnel reaches `COMPLETE`,
the **Lodge is the standing hub** and the player travels to the Bayou via the Travel Desk like any other
Destination. The Bayou-side signpost is the in-field Travel surface for the funnel; the Lodge Travel Desk
is the durable one. (Coordinate with SYS_lodge_trophy — §10.)

---

## 3. Wildlife Roster (Hunting)

> Template C per entry, ascending difficulty. All stats on 1–100. **The roster is deliberately lean** —
> the starter tier is the smallest content footprint in the game (it is a tutorial space first); breadth
> arrives in higher tiers. **Bayou-wide non-lethal rule:** the Tier-1 non-lethal clamp (combat §4) is
> applied to the **entire** huntable roster here, not just the floor — so **nothing in the Bayou can
> down an armorless player** (honoring onboarding's "at Tier 1 there are no lethal threats at all," funnel
> §1). Armor becomes a survival factor only from Tier 2 (combat §4). Flagged for combat confirmation
> (§10) — it scopes the existing clamp, it does not change the mechanism. **Cash in "Drops/reward" is
> computed from economy's band** (`BaselinePerTarget(1) = Income(1)/ExpectedTargetsPerHour(1,hunting) ≈
> 1,000/80 ≈ 12.5 Cash`, × RarityMultiplier) — not authored here; cite SYS_economy §5.

### Ambiance-only (grant nothing — combat enforces the zero reward)

#### Great Egret  [Tier 1]
- **Rarity:** Common
- **Ambiance-only?:** yes (grants no reward — for atmosphere; teaches "not every animal is a target,"
  01 tier-floor principle, an anti-mindless-slaughter signal)
- **Behavior:** passive (wades, flushes if approached)
- **Pack size:** n/a (singles / loose pairs)
- **Health / Damage to player / Speed:** n/a (ambiance) / 0 / 45
- **Min weapon tier to kill / Min armor tier to survive:** n/a — yields nothing if shot
- **Co-op recommended?:** n/a
- **Drops / reward:** none (ambiance; the reward pipeline early-returns zero — combat §build-notes)
- **Re-skin of:** n/a
- **Spawn:** channel edges and shallows, daylight

#### Painted Turtle & Songbirds  [Tier 1]
> Grouped intentionally — ambiance entries need no individual stat block (they yield nothing).
- **Rarity:** Common · **Ambiance-only?:** yes · **Behavior:** passive
- **Health / Damage / Speed:** n/a / 0 / 20 (turtle), 50 (songbirds)
- **Drops / reward:** none · **Spawn:** logs and reed beds, daylight — pure atmosphere

### Tier floor creatures (the ~60 s first-kill targets)

#### Wood Duck (flock)  [Tier 1]
- **Rarity:** Common
- **Ambiance-only?:** no
- **Behavior:** flees (flushes; not the aggressive-"pack" archetype — ducks are a fleeing flock, not a
  shared-aggro hunting pack; the flock is a *spawn* property, below)
- **Pack size:** 4–8 (flock; flushes together → a satisfying multi-target first hunt)
- **Health:** 15  (→ `ceil(15/18) = 1` shot on the starter Bolt .22, Damage 18 — combat §3, `Z_expected`
  1.0)
- **Damage to player:** 0 (non-lethal; ducks do not attack)
- **Speed:** 50 (flushing/flying — shot on the flush, not chased; no mount needed)
- **Min weapon tier to kill:** 1 (starter)  ·  **Min armor tier to survive:** n/a (non-lethal)
- **Co-op recommended?:** solo
- **Drops / reward:** ≈ 12.5 Cash (Common; *computed from economy band*, SYS_economy §5); flavor: meat
- **Re-skin of:** n/a (this is the base "flees + flock" template Appalachia turkey etc. re-skin from)
- **Spawn:** reed-edge of the Sunny Levee. **First-hunt candidate** (funnel-guaranteed first spawn, §2.6)
- **KillWindow input (LOC-owned, combat open Q5):** escape-bounded; `TimeToFlee` ≈ 4 s after flush

#### Swamp Rabbit  [Tier 1]
- **Rarity:** Common · **Ambiance-only?:** no · **Behavior:** flees
- **Pack size:** n/a (singles)
- **Health:** 22  (→ `ceil(22/18) = 2` shots on starter — floor band ✓)
- **Damage to player:** 0 (non-lethal) · **Speed:** 55 (shot on the break, not chased)
- **Min weapon tier:** 1 (starter) · **Min armor tier:** n/a (non-lethal)
- **Co-op recommended?:** solo
- **Drops / reward:** ≈ 12.5 Cash (Common; *computed*, SYS_economy §5); flavor: meat/pelt
- **Re-skin of:** n/a (base "flees" template; Appalachia/Alaska "bigger & meaner" rabbits re-skin this —
  01 tier floors/ceilings)
- **Spawn:** Sunny Levee dry ground; **alternate first-hunt candidate**
- **KillWindow input:** escape-bounded; `TimeToFlee` ≈ 5 s, `detectionRadius` modest (forgiving)

#### Nutria  [Tier 1]
- **Rarity:** Common · **Ambiance-only?:** no · **Behavior:** flees / passive (iconic Louisiana swamp
  rodent)
- **Health:** 30 (→ `ceil(30/18) = 2` shots on starter ✓) · **Damage to player:** 0 · **Speed:** 35
- **Min weapon tier:** 1 (starter) · **Min armor tier:** n/a (non-lethal)
- **Co-op recommended?:** solo
- **Drops / reward:** ≈ 12.5 Cash (Common; *computed*, SYS_economy §5)
- **Re-skin of:** n/a · **Spawn:** water's-edge reeds, daylight
- **KillWindow input:** escape-bounded; `TimeToFlee` ≈ 6 s (slow, the easiest floor target)

### Mid / signature creature (the conquest milestone — deliberately light, protects D1)

#### American Alligator  [Tier 1]
- **Rarity:** Uncommon
- **Ambiance-only?:** no
- **Behavior:** **aggressive** (basks, then lunges/hisses if approached — *telegraphed*, combat §1) **but
  non-lethal** (the Bayou-wide clamp, §3 header). It teaches the "aggressive animal" read in a totally
  safe sandbox before Appalachia makes aggression lethal.
- **Pack size:** n/a (solitary)
- **Health:** 48  (→ `ceil(48/18) = 3` shots on the starter Bolt .22 — top of the floor band; soloable on
  the gear you spawned with, combat §3)
- **Damage to player:** raw 15, **clamped non-lethal** (cannot reduce an armorless player below 1 HP —
  combat §4 clamp + chip-damage floor). It lunges and staggers the player; it never downs them.
- **Speed:** 40 (slow cruise, fast short lunge — does not chase; no mount needed)
- **Min weapon tier to kill:** 1 (starter, possibly + a cheap T1 intra-tier upgrade for comfort)  ·
  **Min armor tier to survive:** n/a (non-lethal)
- **Co-op recommended?:** solo (the milestone is single-player by design — progression: milestones are
  reachable, and the Bayou's is intentionally the lightest in the game)
- **Drops / reward:** ≈ 20 Cash (Uncommon = 12.5 × 1.6; *computed from economy band*, SYS_economy §5);
  flavor: gator hide. **This is the hunting-side conquest milestone** (§7).
- **Re-skin of:** n/a (the Bayou's signature; its body/lunge template is reused for later aggressive
  reptiles/predators)
- **Spawn:** channel banks and Cottonmouth Slough, daylight. Present but uncommon — "the big one" a new
  player works up to within their first session or two.
- **KillWindow input:** survival-bounded in form but **non-lethal**, so the window is effectively
  unbounded — the encounter is purely a 3-shot placement check under a lunge-telegraph. (Attack interval
  ≈ 3 s for the stagger animation; no down state.)

### Apex / ceiling

**By design, the Bayou has no gear-wall apex creature.** The tier-floor/ceiling principle (01) is that
*the ceiling rises faster than the floor as tiers climb* — so at Tier 1 the floor→ceiling spread is the
**narrowest in the game**, and there is no "buy the next tier or die" wall. A punishing apex here would
fight the onboarding-gentleness requirement head-on (it would stall D1 on a death or a wall, exactly what
the funnel forbids — funnel §7). **The Bayou's aspirational "top" is carried by the rares (§5), not by a
wall creature.** This is a deliberate LOC-level reading of the floor/ceiling rule for the starter tier,
flagged for combat confirmation (§10).

---

## 4. Fish Roster (Fishing)

> Template D per entry, ascending difficulty. All water here is **bank/pond — shore-accessible, no Boat**
> (fishing §7). Floor fish are landable on the **free starter Cane Rod (Pressure 30) + Spincast Reel
> (DrainMax 9)** (EQUIPMENT_MASTER §4.3/§4.4). Landability is checked against `FightTime ≤ LandWindow`
> (fishing §2; `E_expected` 0.7, dragSmooth ≈ 1.0 as in EQUIPMENT_MASTER §3.3).
>
> **Starter-rig compression (the constraint that shapes this whole ladder — v1.1, snap-point corrected
> v1.2).** Two distinct failure modes set the ceiling (fishing §2): a **reel-bound throw/timeout**
> (`FightTime > LandWindow` while the window is still positive — the reel can't drain the fish's stamina
> in time) and a **rod snap** (`LandWindow = max(BreakThreshold − PeakRunForce, 0) → 0`). On the free
> starter rig these sit far apart: the **starter reel (DrainMax 9) is the binding slot** — beyond ≈
> **FightDifficulty 37** the fish throws/times out — while the **rod (BreakThreshold 30) does not snap
> until ≈ FD 50** (`PeakRunForce = 0.6·FD` reaches 30 only there), so the rod holds comfortable headroom
> over *every* Bayou fish. The catchable range on the starter rig is therefore ≈ **FD 20–37, capped by
> the reel's drain, not the rod**, so the Bayou's fish ladder is *necessarily* compressed into a narrow
> band and the milestone catfish *cannot* be much harder-fighting than the routine catfish. The
> milestone's "big one" feel comes from **size/weight and the conquest**, not from a punishing fight —
> which is exactly right for the gentlest tier (the narrowest floor→ceiling spread, §3). *(This also
> tells LOC_02/03 the useful generalization: at low tiers the **reel/drain**, not the rod/break, is
> usually the binding fish-difficulty slot — the rod's headroom is large until high FD.)* **Cash is
> computed from economy's band** (`BaselinePerCatch(1) = Income(1)/ExpectedTargetsPerHour(1,fishing) ≈
> 1,000/60 ≈ 16.7 Cash`, × RarityMultiplier) — cite SYS_economy §5 / fishing §5.

### Common catches (the ~60 s first-catch targets)

#### Bluegill (panfish)  [Tier 1]
- **Rarity:** Common
- **Typical weight range:** 0.2–0.5 kg  ·  **Record/trophy weight:** 0.8 kg
- **Fight difficulty:** 20
- **Min rod tier / reel tier to catch:** 1 / 1 (free starter). *Check (0.4 kg):* `FightTime ≈ 2.2 s`,
  `LandWindow ≈ 18` → `2.2 ≤ 18` ✓ trivially landable (the gentlest fight in the game).
- **Bait/lure required:** worms / crickets (basic, required-item yes/no — fishing §4; trivial,
  auto-restocked)
- **Water type:** bank
- **Drops / reward:** ≈ 16.7 Cash (Common; *computed*, SYS_economy §5)
- **Spawn / bite condition:** all day, channel banks and shallows. **First-catch candidate**
  (funnel-guaranteed first bite, §2.6)

#### Bullhead Catfish  [Tier 1]
- **Rarity:** Common · **Typical weight:** 0.5–2 kg · **Record:** 3 kg
- **Fight difficulty:** 28  ·  **Min rod / reel tier:** 1 / 1 (starter). *Check (1.5 kg):* `FightTime ≈
  4.0 s`, `LandWindow ≈ 13.2` → ✓ comfortable.
- **Bait/lure required:** cut bait (basic) · **Water type:** bank / channel
- **Drops / reward:** ≈ 16.7 Cash (Common; *computed*) · **Spawn / bite:** all day, slow channels

### Mid catches

#### Channel Catfish  [Tier 1]
- **Rarity:** Uncommon · **Typical weight:** 2–6 kg · **Record:** 12 kg
- **Fight difficulty:** 32  ·  **Min rod / reel tier:** 1 / 1 (starter). *Check (4 kg):* `FightTime ≈ 6.0
  s`, `LandWindow ≈ 10.8` → ✓ comfortable, doggier/reel-leaning than the bullhead.
- **Bait/lure required:** cut bait (basic) · **Water type:** channel / the Catfish Hole oxbow
- **Drops / reward:** ≈ 26.7 Cash (Uncommon = 16.7 × 1.6; *computed*) · **Spawn / bite:** all day, better
  at dusk in the deeper channels

### Trophy catch (the fishing-side conquest milestone — deliberately light, protects D1)

#### Blue Catfish — "the Bayou's signature catch"  [Tier 1]
- **Rarity:** Uncommon
- **Typical weight range:** 4–9 kg  ·  **Record/trophy weight:** 25 kg (the heaviest routine species —
  the "big one" feel is its *size*, not its fight)
- **Fight difficulty:** 34 (the firmest routine fight at T1, sitting comfortably below the starter-rig
  catchable ceiling of ≈ FD 37 — which is **reel-bound**, the rod's snap point being far higher at ≈ FD
  50). *Check (4 kg):* `FightTime ≈ 6.65 s`, `LandWindow ≈ 9.6` → `6.65 ≤ 9.6` →
  **margin ~3.0 s — comfortably landable on the free starter rig** (deliberately light, fishing §8;
  skill / `E_expected` above 0.7 widens the margin further). *(v1 used FD 36, a ~1.0 s margin — tense,
  not light; corrected.)*
- **Min rod / reel tier:** 1 / 1 (starter — no gear gate to conquer the Bayou via fishing)
- **Bait/lure required:** cut bait (basic) · **Water type:** the Catfish Hole oxbow / deep channel
- **Drops / reward:** ≈ 26.7 Cash (Uncommon; *computed*). **This is the fishing-side conquest milestone**
  (§7), parity-targeted against the alligator hunting milestone (fishing §8 — comparable *light* effort
  so conquest-via-either-loop is roughly equal; flagged as a tuning item, §10).
- **Spawn / bite condition:** the Catfish Hole, dawn and dusk best
- **Apex note:** as with hunting (§3), the Bayou intentionally has **no co-op-only fishing apex** — the
  signature Blue Catfish is the top routine fight, and the aspirational top is the rares (§5). (The
  starter-rig compression above also *mechanically* prevents a T1 apex fish: anything tough enough to be
  an apex would throw/time-out on the starter reel — a reel-bound dead end well before the rod ever snaps
  — which is not a "tense" experience, so it is correct to avoid at T1.)

---

## 5. Rare & Mythical Spawns

> Template E per entry. **All are independent, condition-gated spawns — never per-kill / per-cast rolls**
> (combat RD-E / fishing Decision 3 / economy RD5). Each is a separately-spawned entity present under its
> condition, layered on the routine population. **Each mints exactly one unique artifact and writes NO
> Cash at kill/catch** (SYS_data_integrity v1.1 — Cash is realized only on the SALVAGED transition, and
> salvage is floored low; the real value is **P2P trade + the Trophy Hall**, economy §5). Default
> disposition on mint is HELD with a one-tap "Mount it" prompt (SYS_lodge_trophy RD1). **Re-release
> policy is NEVER** — minted permanently, never re-released to juice numbers (00 §5, the scarcity moat).
> **At Tier 1, rares share their base creature's combat/catch stats** (no added difficulty wall — a rare
> here is a *find*, not a fight; the content moment is the discovery + the clean kill/catch, consistent
> with the no-apex decision §3/§4). The Bayou's rares are deliberately **accessible-but-rare** (it is the
> starter zone — a new player must be able to *dream* of the catch; 00 §6 "design for the thumbnail").
>
> **Rarity is two knobs, not one (v1.1 correction).** For a condition-gated spawn, **effective rarity =
> per-window 1-in-N roll × condition frequency × player presence-with-prereqs.** v1 stacked a large flat
> 1-in-N on top of already-heavy condition-gating, compounding to *effectively unreachable* — which
> contradicts "accessible-but-rare." v1.1 sets the **per-window 1-in-N low** (the *condition-gating*
> carries most of the scarcity) and tunes it so the *effective* rate lands at accessible-Legendary /
> accessible-Mythic for the starter zone. **LiveOps owns condition frequency on the calendar (§9); this
> doc owns the per-window roll.** All values below are illustrative defaults; the effective rate is the
> real tuning target (§10).

#### Leucistic Wood Duck — "the Pale Drake"  [Rare] — Bayou
- **Type:** hunting trophy  ·  **Base creature/fish:** Wood Duck (shares its stats)
- **Spawn condition:** dawn flocks on the Sunny Levee reed-edge (time-of-day: first light — a *frequent*
  condition)
- **Spawn rate:** 1-in-900 per qualifying dawn-flock check → with daily dawns and common flocks, an
  *accessible* rare; the first rarity moment most new players hit, teaching them rares exist and matter
- **Reward:** no Cash at kill (mints one artifact); low salvage floor; a unique **Pale Drake** trophy
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER
- **Intended content moment:** one ghost-white duck in a flock of brown — a clean, early "look what I got"
  screenshot that hooks a new player on the rarity chase

#### White Alligator — "the Ghost Gator"  [Legendary] — Bayou
- **Type:** hunting trophy  ·  **Base creature/fish:** American Alligator (shares its 3-shot, non-lethal
  stats — a find, not a wall)
- **Spawn condition:** dawn **or** dusk **+ fog/mist** in Cottonmouth Slough (time-of-day + weather — an
  *occasional* condition)
- **Spawn rate:** 1-in-2,500 per qualifying fog-window check → with fog infrequent and the Slough
  location-gated, the *effective* rate is genuine-Legendary
- **Reward:** no Cash at kill (mints one artifact); low salvage floor; a unique **White Gator Hide**
  trophy — a high-status Bayou flex
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER
- **Intended content moment:** the pale gator surfacing silently out of the fog at first light — the
  Bayou's signature thumbnail/clip (00 §6)

#### Albino Blue Catfish — "the Pale Monster"  [Legendary] — Bayou
- **Type:** record fish  ·  **Base creature/fish:** Blue Catfish (shares its FD 34 fight — landable on
  starter; the challenge is *finding* it)
- **Spawn condition:** **night + the deepest Catfish Hole channel + cut bait** (time-of-day + location +
  a basic required-item as part of the condition — fishing §4; gates the *attempt*, never bought past)
- **Spawn rate:** 1-in-3,500 per qualifying night-bite check → location- and bait-gated to a
  genuine-Legendary effective rate
- **Reward:** no Cash at catch (mints one artifact); low salvage floor; a unique **Pale Monster** record
  catch
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER
- **Intended content moment:** a huge ghost-pale catfish breaching at night — the fishing-loop legendary
  reveal

#### The Bayou Leviathan — "the Old Cat of the Channel"  [Mythic] — Bayou
- **Type:** record fish (the Bayou's "white whale" — **one Mythic per Destination**, 01 / 04)
- **Base creature/fish:** an ancient, colossal Blue Catfish (T1 stats — landable on starter once hooked;
  the whole difficulty is *reaching the condition and winning the roll*, not the fight)
- **Spawn condition:** **storm + night + the deepest Catfish Hole + a live sucker** (weather + time +
  location + basic required-item — the storm-makes-rare-fish-bite return hook, 01; the live sucker is a
  *basic* bait, never premium — fishing §4. A *rare* compound condition)
- **Spawn rate:** 1-in-7,500 per qualifying storm-night check. The per-window roll is deliberately modest
  because the **compound condition (storm-nights are infrequent, plus location + live sucker + presence)
  already carries most of the scarcity** — the *effective* rate is the rarest in the Bayou, yet still
  **the most accessible Mythic in the game** (later-tier Mythics are far rarer): a dedicated player who
  shows up every storm-night with live sucker has a real, weeks-long dream, which is exactly the
  starter-zone target
- **Reward:** no Cash at catch (mints one artifact); low salvage floor; a unique **Bayou Leviathan**
  trophy — the centerpiece of an early Trophy Hall
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER (permanent
  scarcity — the moat)
- **Intended content moment:** the screen-filling leviathan rising in a thunderstorm — the clip every new
  player wants, and the reason they return on stormy nights (the timed-spawn retention hook, 01)

---

## 6. Region-Specific Equipment

> Template B per item. These **merge into EQUIPMENT_MASTER**, which owns balance — stats/curves here are
> *cited from* EQUIPMENT_MASTER, not re-authored. The Tier-1 starter loadout (Bolt .22, Cane Rod,
> Spincast Reel) is **inherited, not re-specced here** (EQUIPMENT_MASTER §4.1/§4.3/§4.4; all 0 Cash,
> granted on spawn). The region items first available in the Bayou are the **Coonhound** and the **basic
> Bayou bait**; cosmetics are categories, not statted items (§9 / EQUIPMENT_MASTER §4.9).

### Coonhound (Tracking Dog)
- **Category:** dog
- **Tier:** first available T2–T3 (a Bayou-flavored breed, but a **mid-game convenience**, not a starter
  item — players pay to save time *once they like the loop*, 01)
- **Available at:** Kennel & Stable
- **Cost:** ~8,000 Cash basic (≈ `1.6·GearCost_slot(T)`, EQUIPMENT_MASTER §4.7); **rare coonhound breeds
  are P2P trade items** (value flows to the Trading Post, like rares — tradeable unique artifact,
  EQUIPMENT_MASTER §6.1)
- **Primary stat(s):** widens rare-spawn detection radius; tracks wounded/fleeing game (a `flees`-archetype
  aid). **No Damage, no survivability, no catch power** — "does not break combat balance" (01)
- **Weight:** n/a
- **Strengths:** finds the Bayou's condition-gated rares (§5) faster; recovers a wounded rabbit/duck;
  regional-breed identity flex
- **Weaknesses / limits:** **never in a Gate** (progression — convenience must not gate shared content);
  cannot make an un-takeable target takeable (a dog helps you *find* a rare, not *win* it — rares are
  still condition-gated spawns)
- **Gates unlocked:** none — ever
- **Monetization role:** convenience + identity (rare breeds = collectible / tradeable)
- **Notes:** the rare-breed line is a clean trade-economy + identity sink with zero balance impact. Does
  **not** interfere with onboarding (priced well above first-session earnings; not surfaced in the
  funnel).

### Basic Bayou Bait & Tackle (cut bait · worms/crickets · live sucker)
- **Category:** bait / tackle
- **Tier:** all (Bayou-relevant set)
- **Available at:** Tackle Shop (the Landing) / Outfitter
- **Cost:** trivial (5–20 Cash), **auto-restocked — effectively free** (EQUIPMENT_MASTER §4.8; the
  not-a-timer rule, economy §1)
- **Primary stat(s):** **required-item yes/no gate only** — cut bait (catfish), worms/crickets
  (panfish), live sucker (a *condition* component of the Bayou Leviathan, §5). **Never a tier input.**
- **Weight:** n/a
- **Strengths:** the legible "do you hold the right basic tackle" check; every Bayou target is engageable
  with its appropriate basic
- **Weaknesses / limits:** a player can **never** be blocked from the core loop by running out (binding —
  the not-a-timer rule). A condition-gated rare may *name* a specific basic bait (live sucker) as part of
  its condition — that gates the *attempt*, not the *win*, and cannot be bought past.
- **Gates unlocked:** none
- **Monetization role:** — (friction-free; not a real-money sink). *(Premium bait/ammo exist as
  EQUIPMENT_MASTER §4.8 convenience items — capped, never mandatory, never reach the §5 moat-rares — but
  are not introduced in the funnel.)*

*(Jon Boat — cosmetic convenience only in the Bayou; **not required** since all Bayou fish are
shore-accessible. Already specced in EQUIPMENT_MASTER §4.5; noted, not re-statted. Cosmetic identity sinks
relevant here: a "rustic bayou cabin" Lodge theme and Bayou camo skins — categories per EQUIPMENT_MASTER
§4.9, the evergreen inflation ballast, economy §9.)*

---

## 7. Gating (entry & exit)

- **To UNLOCK this Destination:** **none — the Bayou is the free STARTER** (progression gating table:
  Bayou = no `required_tier`, no access item, no `milestone_prerequisite`). The player spawns with the
  free Tier-1 loadout (EHT 1 armorless / EFT 1 on arrival) and acts immediately — no Cash gate, no
  purchase, no cutscene (funnel §0).
- **To progress PAST this Destination (unlock Appalachia, Tier 2):** the two-part gate (progression §2),
  **OR-gated across loops** —
  1. **Milestone (non-purchasable):** **conquer the Bayou** — designated targets, satisfiable via
     *either* loop: hunting = **American Alligator** (§3), fishing = **Blue Catfish** (§4). Both are
     **deliberately light** (soloable on the free starter loadout, possibly + a cheap T1 intra-tier
     upgrade) to **protect D1** (economy / onboarding — the Bayou conquest must not wall a new player).
  2. **Gear (purchasable):** **Tier-2 gating gear** on at least one offered loop — `EHT ≥ 2` (Lever-Action
     Rifle + Field Jacket, 3,000 Cash/slot) **OR** `EFT ≥ 2` (Appalachia Bait Rod + Baitcaster, 3,000
     Cash/slot) — EQUIPMENT_MASTER §2. **This is the first time armor enters the bill** (Tier 1 has no
     armor cost — progression / EQUIPMENT_MASTER §2).
- **The legibility contract** (progression §2): Appalachia's locked pin reads in concrete nouns —
  *"Requires: Tier-2 rifle + jacket (or rod + reel) · Conquer the Bayou."* No abstract score; the player
  always knows the exact next item and the exact next conquest.
- **MVL note:** Appalachia's `milestone_prerequisite` is "conquer Bayou"; Alaska's is "conquer
  Appalachia," re-pointing to Rockies when Rockies ships (progression §2 DAG). The Bayou is the chain's
  root.

---

## 8. Economy Hooks (hand-off to economy chat)

> **All Cash is SYS_economy's** (band-owned, computed). This section provides the **engagement inputs**
> (the spawn-density and bite-density values, set *within* combat's / fishing's cap mechanism, plus the
> per-target time components) that bound `ExpectedTargetsPerHour` and are economy-critical (the
> anti-low-tier-farming invariant, economy §5 / combat §5 / fishing §6). It does **not** author Cash.

### 8.1 Per-hour income band
`Income(1) ≈ 1,000 Cash/hr` (economy default `B`). Per-target Cash is **computed**:
`Payout = (Income(1)/ExpectedTargetsPerHour) · RarityMultiplier` (economy §5). With combat's modeled
hunting rate ~80/hr and fishing's ~60/hr, the routine baselines are **~12.5 Cash/kill** and **~16.7
Cash/catch** (Common); Uncommon ×1.6 (the gator ≈ 20, the signature catfish ≈ 26.7). These are computed
illustrations, not authored values.

### 8.2 Cash faucets here (cite economy; do not author)
Kill payouts (floor game + the Uncommon gator), catch payouts (panfish/catfish + the Uncommon Blue
Catfish), daily-quest rewards (scaled as a fraction of `Income(1)` — economy §1; the funnel hands the
player the first daily set, funnel §6), and **rare salvage floored low** (the §5 rares write no Cash at
kill/catch; value flows to trade + Trophy Hall — economy §5 / data_integrity v1.1).

### 8.3 Cash sinks here
The **T1 intra-tier climb ≈ `m·Income(1)` = 2,500 Cash total** per loop (economy §3; the *first, cheap*
step is the funnel's minute-one soft-monetization beat, funnel §3); the **Tier-2 gating gear** (6,000
Cash/loop — the exit purchase toward Appalachia, economy §2); basic bait (trivial); the Coonhound
(~8,000, mid-game convenience); cosmetics (rustic-bayou Lodge theme, camo — the evergreen ballast,
economy §9). Basic ammo/bait is effectively free (the not-a-timer rule).

### 8.4 Spawn-density values — the anti-low-tier-farming invariant (engagement inputs, illustrative)

> Set **within** combat's `MaxConcurrentTargets + RespawnInterval → SpawnThroughputCeiling` mechanism
> (combat §5) and fishing's `MaxConcurrentBites + BiteRespawnInterval → BiteThroughputCeiling` mechanism
> (fishing §6). LOC_ owns the *values*; the docs own the *mechanism*. **Purpose:** bound
> `ExpectedTargetsPerHour` so it is capped by **availability, not player kill/catch speed** — an
> over-geared Tier-4 player who one-shots Bayou game exhausts the local spawns and earns ≈ `Income(1)`,
> strictly **worse** than playing their own tier (`Income(4) ≈ 4,913`), so low-tier farming is
> irrational (the binding invariant, economy §5). All values illustrative; validate against the modeled
> rates and the over-geared-farming test (§10).

**Hunting (target ~80/hr modeled for a normal T1 player — combat §5):**
- 3 spawn areas (Sunny Levee, reed-edges, channel banks), each `MaxConcurrentTargets` ≈ 3–4,
  `RespawnInterval` ≈ 30–40 s.
- `SpawnThroughputCeiling(Bayou, hunting)` — set in the **~80–90/hr** band. The trade-off is explicit and
  is a tuning knob, **not** a single asserted number: set it *at* ~80 and an efficient normal player is
  throttled to the modeled rate (clean anti-farming, but caps over-performers); set it *toward* ~90 and
  an efficient normal player keeps their edge while a tiny farming margin opens (≈ 90 × 12.5 ≈ 1,125 vs
  `Income(1)` 1,000). Tune against the over-geared-farming test and normal-play telemetry (§10); the
  *invariant* (capped near `Income(1)`) is binding, the exact ceiling is the knob.
- Per-target time components (LOC inputs to combat's `TimePerTarget`): `TimeToFind` ~25 s, `TimeToKill`
  ~10 s (1–3 shots × CycleTime 1.5 s + settle/acquisition/missed shots), `Overhead` ~10 s →
  `TimePerTarget` ~45 s → ~80/hr, matching combat's table. (Hunting's mechanical and modeled times are
  roughly consistent — unlike fishing, below.)
- **First-hunt override (funnel-scoped):** the *first* hunt spawn bypasses these caps for the first-time
  player in the arrival area only (§2.6); caps hold for everything after.

**Fishing (target ~60/hr modeled for a normal T1 player — fishing §5):**
- 2–3 fishing waters (channel banks, the Catfish Hole oxbow), each `MaxConcurrentBites` ≈ 2–3,
  `BiteRespawnInterval` ≈ 25–35 s, with **local spot-depletion** on each landed/spooked fish (rotate
  spots — the fishing-meta depth and an anti-AFK/anti-bot signal, fishing §6).
- `BiteThroughputCeiling(Bayou, bank)` — set in the **~60–70/hr** band (same throttle-vs-leak trade-off
  as hunting; tune against the farming test).
- Per-catch time components (LOC inputs to fishing's `TimePerCatch`): fishing §5 models `TimeToBite` ~20
  s, `FightTime` ~18 s, `Overhead` ~22 s → `TimePerCatch` ~60 s → ~60/hr. **LOC_01 uses fishing's modeled
  ~60/hr for the economy hand-off** and the per-fish mechanical fight times (§4) for the catchability
  checks.
- **Flagged rate gap (v1.1 — upstream, surfaced not papered over).** The mechanical FightTimes this
  roster computes via `FightTime = Stamina/NetDrain` (~2–7 s: Bluegill 2.2 s … Blue Catfish 6.65 s — and
  consistent with fishing §3.3's own worked examples of 4–10 s) sit **well below** fishing §5's modeled
  ~18 s FightTime that feeds the rate. The gap is the difference between *idealized drain time* and the
  *experienced fight* (runs, eases, re-grabs, the bite-reaction beat) the rate model folds in. This is
  **not a LOC fix** — it is part of the upstream "ExpectedTargetsPerHour is the load-bearing unknown"
  reconciliation (fishing/economy/combat joint tuning); LOC_01 raises it so the joint pass reconciles the
  mechanical and modeled fight times rather than discovering the gap in playtest (§10).
- **First-fish override (funnel-scoped):** the *first* bite bypasses caps for the first-time player at the
  arrival bank only (§2.6).

---

## 9. LiveOps / Event Ideas

> Suggestions only — SYS_liveops_calendar owns cadence and budgets. All are Bayou-appropriate timed
> content that doubles as a **return hook** (the timed-spawn retention lever, 01).
>
> **Scarcity-discipline rule (00 §5, binding — tightened in v1.1).** Events may raise the *frequency of a
> standing rare's qualifying CONDITION* (more storm-nights, more fog-dawns on the calendar) so more
> players get a fair shot — the intended "storms make rare fish bite" hook (01). They **never** lower a
> rare's fixed per-window 1-in-N, never re-release a retired exclusive, and never dilute already-minted
> artifacts. But note the tension: because effective rarity = per-window roll × condition frequency (§5),
> a condition-frequency boost **does** modestly raise total mints over the event — so boosts must be
> **bounded** (a short, scheduled window, not a permanent condition shift) to keep total mint scarce and
> trade value intact. A truly limited-time *exclusive* mythic, if ever run, is retired forever.

- **Catfish Run (seasonal):** a window where catfish bite faster (more routine bites/hour) — a pure
  routine-income + engagement bump, no rare dilution.
- **Duck Migration weekend:** larger / more frequent Wood-Duck flocks on the Levee (flavor + a *bounded*
  Pale Drake condition-window bump).
- **Blood-Moon Bayou (night event):** more fog-dawn and storm-night windows → more *chances* at the Ghost
  Gator and the Bayou Leviathan (the condition is more frequent for a bounded window; the 1-in-N is
  unchanged). The headline return hook — kept short so total mints stay scarce.
- **Crawfish Boil (community festival at the Landing):** a social/cosmetic event — a Mardi Gras / cajun
  cosmetic drop (identity sink, the evergreen ballast economy §9 requires be continuously replenished),
  plus a light cross-loop daily pair themed to the festival.
- **Cross-loop daily pair (standing, introduced in the funnel):** one small hunt + one small catch
  objective; completing both pays the cross-loop breadth kicker (economy §6). Breadth-as-reward, never
  focus-as-penalty.

---

## 10. Open Questions / Flags

1. **Bayou-wide non-lethal extension (combat confirm).** This doc extends the Tier-1 non-lethal clamp
   (combat §4) across the *entire* huntable roster — including the aggressive-but-clamped Alligator — to
   honor onboarding's "no lethal threats at all at Tier 1" (funnel §1). Combat §4 already implies this
   ("armor becomes a survival factor from Tier 2 onward"); flagged for explicit confirmation that scoping
   the clamp to the whole T1 roster is intended (it scopes, it does not change, the mechanism).

2. **No gear-wall apex at Tier 1 (combat/fishing confirm).** Both rosters deliberately populate floor +
   signature/milestone but **no co-op-only / T+1-gated apex** (§3, §4). This is a LOC reading of the
   floor/ceiling rule for the starter tier (narrowest spread, aspirational top carried by the rares). On
   the fishing side it is also *mechanically forced*: beyond ≈ FD 37 a fish throws/times out on the
   starter reel (a reel-bound dead end; the rod itself does not snap until ≈ FD 50 — §4, corrected v1.2),
   so a T1 apex fish would be a dead end, not a tense fight. Confirm combat/fishing accept a tier with no
   apex creature.

3. **Starter-rig fish-ladder compression (new in v1.1; snap-point corrected v1.2; fishing confirm).** The
   starter **reel** (DrainMax 9), not the rod, caps the catchable range at ≈ FD 20–37 (the rod's snap
   point is far higher, ≈ FD 50 — `PeakRunForce = 0.6·FD` reaches BreakThreshold 30 only there), which
   forces the milestone catfish (FD 34) to fight only marginally harder than the routine channel catfish
   (FD 32). This is *correct* for the gentlest tier, but confirm fishing is comfortable that the T1 fish
   *texture* differentiates by size/weight and bite-condition rather than by fight difficulty (the
   rod-bound/reel-bound axis fishing §3 wants is mostly unavailable at T1 because the band is so
   compressed — and at T1 it is specifically the *reel* that binds).

4. **Milestone parity (tuning).** The hunting milestone (Alligator, 3 shots on starter, non-lethal) and
   the fishing milestone (Blue Catfish, FD 34, landing margin ~3.0 s on starter) are both targeted to
   *light* effort so conquest-via-either-loop is roughly equal (fishing §8). Validate in playtest that
   neither over- nor under-shoots the other; if first-conquest drop-off diverges by loop, nudge the
   catfish FD or the gator Health (do **not** touch starter-gear stats — EQUIPMENT_MASTER owns those).

5. **The mechanical-vs-modeled FightTime gap (new in v1.1; fishing/economy/combat joint).** This roster's
   per-fish FightTimes (~2–7 s) are well below fishing §5's modeled ~18 s rate input (and below combat's
   implied parity). It is an upstream reconciliation item ("ExpectedTargetsPerHour is the load-bearing
   unknown"), not a LOC fix — but it must be resolved in the joint tuning pass, because if the *real*
   fight is ~6 s rather than ~18 s, fishing's catches/hour (and therefore per-catch Cash) are mis-modeled
   and the dual-loop balance drifts. Highest-priority cross-doc item alongside #6.

6. **Spawn-density / bite-density values are illustrative (§8.4).** They must be validated against
   combat's ~80/hr and fishing's ~60/hr modeled rates **and** the over-geared low-tier-farming test
   (economy §5 / combat §5 / fishing §6). The throttle-vs-leak ceiling trade-off (§8.4) is a real knob,
   not a single number; the *invariant* (capped near `Income(1)`) is binding.

7. **First-spawn override scoping (onboarding/combat coordinate).** The funnel-owned first-hunt and
   first-fish overrides (§2.6) must be scoped to the arrival area **and** the first-time player **only**,
   and must not leak into a low-tier-farming hole afterward (funnel §build-notes). Build-together
   constraint, not a sequential hand-off (funnel §10).

8. **First-session direct-to-Bayou spawn (SYS_lodge_trophy coordinate).** SYS_lodge_trophy says spawning
   lands a player in the Lodge; the funnel (and §2.6) routes the *first-time* player directly to the
   Bayou arrival point. Confirmed as the onboarding-owned first-session exception, with the Lodge as the
   standing hub post-`COMPLETE`. Flagged so the two docs agree on the spawn router.

9. **Rare effective-rate tuning (revised in v1.1; §5).** The per-window 1-in-N values (Pale Drake 1-in-900,
   Ghost Gator 1-in-2,500, Pale Monster 1-in-3,500, Bayou Leviathan 1-in-7,500) are set *with the
   condition-gating doing most of the scarcity work*. The tuning target is the **effective** rate
   (per-window roll × condition frequency × presence), co-owned with SYS_liveops (which owns condition
   frequency on the calendar). Validate that the Legendaries are weeks-reachable and the Mythic is a
   genuine-but-attainable starter-zone dream; once minted, scarcity is permanent (00 §5).

10. **Coonhound availability (T2–T3) vs. Bayou flavor.** The coonhound is the Bayou's signature breed but
    is priced/gated as a mid-game convenience (EQUIPMENT_MASTER §4.7), so a brand-new player can't buy it
    in their first session. Confirm "Bayou-flavored but not a starter item" is the intended read (it keeps
    the funnel clean and the dog a *wanted goal*, not a starter handout).

---

## Changes from v1 (for the diff)

1. **Fishing milestone retuned FD 36 → 34.** v1's Blue Catfish had a ~1.0 s landing margin on the starter
   rig — tense, contradicting fishing §8's "deliberately light, protects D1." FD 34 gives a ~3.0 s margin
   (comfortably landable). Re-derived and verified against the catchability inequality.
2. **Surfaced the starter-rig compression insight (§4 header).** The starter **reel** (DrainMax 9) caps
   the T1 catchable range at ≈ FD 20–37 (reel-bound throw); the fish ladder is *necessarily* narrow and
   the milestone's "big one" feel is reassigned to size/weight, not fight. Added as a design constraint, a
   fishing flag (#3), and an apex justification (#2). *(v1.1 mis-stated this as a rod snap at ≈ FD 38 —
   corrected in v1.2 below.)*
3. **Corrected the rare-rate double-count (§5).** v1 stacked large flat 1-in-N values (up to 60,000) on
   top of heavy condition-gating, compounding to effectively unreachable — contradicting "accessible-but-
   rare." v1.1 introduces **effective rarity = per-window roll × condition frequency**, lowers the
   per-window rolls (Pale Drake 900, Ghost Gator 2,500, Pale Monster 3,500, Leviathan 7,500), and makes
   the *effective* rate the tuning target. Added that T1 rares share base stats (a find, not a wall).
4. **Flagged the mechanical-vs-modeled FightTime gap (§8.4 / §10 #5).** v1's §8.4 copied fishing §5's ~18 s
   FightTime while the roster computed ~2–7 s — an internal inconsistency inherited from an upstream gap.
   v1.1 surfaces it as a cross-doc reconciliation item rather than papering over it.
5. **Stated spawn-throughput ceilings as a throttle-vs-leak trade-off (§8.4)** instead of a single
   over-precise number; the invariant (capped near `Income(1)`) is binding, the exact ceiling is a knob.
6. **Tightened the LiveOps scarcity note (§9)** to acknowledge that condition-frequency boosts modestly
   raise total mints, so boosts must be *bounded* — not implying they are free.
7. **Precision fixes:** Wood Duck reclassified `flees` + flock-spawn (not the aggressive-"pack"
   archetype); "catchable on foot" reworded to "shot on the flush/break, not run down."

## Changes from v1.1 (v1.2 lock pass)

1. **Corrected the starter-rig snap point ≈ FD 38 → ≈ FD 50, and re-attributed the catchable cap from
   rod to reel (§4 header, change #2, flag #3, the Blue Catfish FD note, the apex note).** The v1.1
   "snaps at ≈ FD 38" was contradicted by its own inequality: `LandWindow = max(30 − 0.6·FD, 0)` reaches
   zero (the actual snap) only at FD 50. At FD 38 the rod still holds LandWindow 7.2; the failure there is
   a **reel-bound throw/timeout** (drain too slow), so the ≈ FD 37 catchable ceiling is set by the
   **starter reel**, not the rod. **Zero stats change** — the roster max is the Blue Catfish at FD 34,
   which lands with a ~3.0 s margin either way; the doc was build-ready as-is. The fix corrects a
   wrong-number-stated-as-insight (the *binding slot* and the *snap value* were both wrong) so LOC_02/03
   inherit the right generalization: at low tiers the reel/drain, not the rod/break, is the binding
   fish-difficulty slot.

---

> **Template A pattern note (for LOC_02 / LOC_03):** every section above is filled; creatures use
> Template C, fish Template D, rares Template E, region gear Template B; units are Cash / kg / 1–100 /
> 1-in-N throughout; Cash is *computed and cited* from the economy band, never authored; combat/fishing
> math and gear stats are *cited*, never re-derived; the onboarding seam is stated explicitly where a
> location is an onboarding host. Higher tiers raise the floor→ceiling spread, re-skin these templates
> "bigger & meaner," and *do* populate a real apex with a real gear wall — the Bayou's emptied apex band
> and compressed fish ladder are the starter-tier exception, not the pattern. **Re-derive every stat
> against the inequalities (don't inherit a band by assertion).** This corpus found four wrong numbers
> across two passes — and the fourth (the FD-50 snap point) had *survived* the v1.1 review and was stated
> as a confident insight before a re-derivation caught it. A number can pass a prose read and still be
> wrong; only the inequality settles it.
