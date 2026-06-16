# Location: Appalachia / Midwest (Tier 2)

> Second Destination, early-progression MVL tier, and the **first real difficulty step** — the first
> commitment point where a new player decides to gear up. This is the tier where **armor first enters
> the bill** (the player's first survival purchase) and where the **co-op tutorial** is taught by
> mechanics, not text.
>
> **v1.2 (LOCKED).** One stat correction over v1.1: the **Tiger Muskie is FD 58 @ 8 kg** (was FD ~70,
> which actually *failed* at T2 — a wall, contradicting its "find" label), now worked to land at T2 with
> +5.5 s margin, fulfilling the find-not-wall design and Ghost Buck dual-loop parity. Coyote solo
> narration set to ~2 of 4 (realistic convergence). No other changes; roster and band-conformance final.
>
> **v1.1 (second/review pass).** No change to the roster's structure or the locked-band targets it
> populates. Corrections after reading LOC_01 in full: (1) **rares write NO Cash at kill/catch** — Cash
> is realized only on the SALVAGED transition, floored low (was implied as salvage-at-kill; SYS_data_
> integrity / LOC_01 §5). (2) **Effective rarity is two knobs** (per-window roll × condition frequency ×
> presence) — per-window N's recalibrated so the §5 rares are *accessible-but-rare*, not unreachable, and
> Mythic scarcity escalates above the Bayou (LOC_01 §5). (3) **Rares are finds, not walls** — Piebald /
> Ghost Buck / Tiger Muskie share base stats; the Black Catamount is the one deliberate "rare that is
> also a wall," flagged. (4) The **modeled-vs-mechanical FightTime reconciliation gap** is surfaced, not
> papered over (§10). (5) Economy normalization and the rarity-label-vs-spawn-density decoupling are
> stated explicitly (§3, §8). Changes are listed at the end.
>
> **What this doc authors vs. cites.** It authors the *place*, the *roster*, the per-target *engagement
> inputs* (creature Health/Damage/Speed + KillWindow inputs; fish FightDifficulty/weights; per-area
> spawn-density and bite-density values), the *rares* and their conditions, the milestone designation,
> and the region companion in Template B. It **cites** every Cash value (economy owns the band; per-
> target Cash is *computed* from it, never authored here), the combat/fishing math (LOCKED at T2 —
> populated, not re-derived), and all gear *balance/stats* (EQUIPMENT_MASTER). Cash figures shown are
> **computed illustrations from economy's band**, flagged as such.
>
> **Inherited as binding (consumed, not re-litigated):** SYS_progression v2.1 (Tier 2 — first armor-
> gating tier; EHT/EFT = min-rule; floor takeable at T−1, apex ~T+1 solo OR T + co-op; milestone earned-
> in-play, carry-proof on gear; OR-gate; ambiance grants nothing). SYS_economy v2.1 (`Income(2) ≈
> 1,700/hr` band; payout *computed* `Income(T)÷ExpectedTargetsPerHour × RarityMultiplier`; band
> normalized over the **routine Common/Uncommon mix only**, rares bonus on top — RD5; spawn-density-cap
> dependency; armor first on the bill at T2). SYS_combat v1.1 (LOCKED T2 floor/mid/apex bands §3; the
> **pack co-op tutorial** §7; armor DR model; rares as independent condition-gated spawns RD-E; ambiance
> enforced server-side). SYS_fishing v1.1 (LOCKED T2 catch bands §3; trophy-bass/trout milestone §8;
> river/lake **no-Boat** water §7; bite-density caps; rares condition-gated). EQUIPMENT_MASTER (worked
> T2 line §3/§4 — Lever-Action Rifle, Field Jacket, Appalachia Bait Rod, Baitcaster; Pointer §4.7; Mount
> §4.6; basic/premium bait §4.8). SYS_data_integrity (rares mint **one** unique artifact, **write no
> Cash at kill/catch**, disposition XOR). SYS_lodge_trophy (mint→HELD→"Mount it" prompt; display ≠
> tradeable).
>
> **Numbers convention.** Formulas/relationships are the design; every magnitude is an *illustrative
> default* and calibration knob, validated against live data. Stats 1–100, weight kg, Cash currency,
> rarity Common→Mythic, spawn rates 1-in-N.

---

## 1. Identity & Story

- **Real-world basis:** the Appalachian foothills and Upper-Midwest hardwood country — recognizable as
  *Appalachia* (ridgelines, hollows, cold trout streams) with Midwestern farm-edge woodlots and lakes
  at its lower elevations. A real, named place a 13-year-old intuitively reads as "north and up from the
  warm Louisiana bayou." The real-world scale does the motivational work an abstract tier number can't
  (00 §0; 05 §3 — the aspiration spine that beats Gone Hunting's interchangeable fantasy zones).
- **One-line feel:** *You climbed out of the swamp. The air is thinner, the woods are bigger, and
  something up the ridge is watching you back.*
- **The story this place tells:** The Bayou was warm, flat, safe, and forgiving — you could not die
  there. Appalachia is the first place the world pushes back. The deer won't stand still, the boar will
  charge, and a coyote pack will put you on the ground if you try to take it alone. This is where the
  player stops *sampling* the game and decides to *commit* — buys their first armor, learns to read a
  threat, and (for the first time) wishes they had a partner. The felt sentence is **"I have to gear up
  for this."**
- **Sensory signature (distinct from the Bayou):** Where the Bayou was hot, green-gold, wet, and droning
  with insects, Appalachia is **cool and crisp** — dawn fog burning off hardwood ridges, a palette of
  rust, amber, slate, and deep evergreen instead of the Bayou's swamp-green. Sound signature: wind in
  bare-to-turning hardwoods, a distant crow, running stream-water, and — the threat tell — a **coyote
  yip-howl chorus at dusk** and the cough-scream of a cougar on the high ridges. Light is **lower,
  longer, and gold at the edges of the day** (the dawn/dusk framing the rares hang on). The player should
  *feel* they gained altitude and a tier in the first ten seconds.

---

## 2. Map Features & Layout

- **Terrain types:** mixed hardwood forest; **ridgelines and hollows** (verticality — the felt
  "altitude" the Bayou lacked); cold **trout streams** and a warmer **lowland lake**; **farm-edge
  woodlots / old fields** (deer and turkey feeding edges); rocky bluffs and a **high ridge** (the
  cougar's range).
- **Landmarks (navigated-by):** **Lookout Ridge** (the high apex-predator range and the panoramic
  arrival vista — also the thumbnail-worthy hero shot of the Destination); **Hollow Creek** (the cold
  trout stream); **Mill Pond / the Lowland Lake** (warmwater bass + the muskie water); **the Old Field**
  (a dawn meadow — the Ghost Buck's spawn); **the Outpost Cabin** (the vendor outpost and arrival point).
- **Functional zones:**
  - *Hunting:* the Old Field / woodlot edges (deer, turkey — floor); the brushy mid-slopes and oak
    ridges (boar — mid); the draws and creek-bottoms (coyote packs — co-op tutorial); **Lookout Ridge**
    (mountain lion — apex/wall).
  - *Fishing:* **Hollow Creek** (brook/brown trout — fly water); **Mill Pond / Lowland Lake**
    (panfish, bass, pike, muskie). **Shore-accessible — no Boat** (SYS_fishing §7: the MVL's first two
    Destinations are Boat-free on the fishing side).
  - *Vendor outpost:* the **Outpost Cabin** — a forward post of the Outfitter / Tackle Shop services and
    the Kennel & Stable's first **Tracking Dog** (the Pointer). It is **not** a second Lodge; the Lodge
    remains the single hub (04). The arrival/respawn point sits here.
- **Traversal notes:** **On foot.** This is the Destination that makes a **Mount's** value *legible* but
  does not yet hand one over: fleeing whitetail and turkey outrun a player on foot (combat `flees`
  archetype), so the chase-loss teaches the want. The Mount is **T3-priced (~10,200, Kennel & Stable —
  EQUIPMENT_MASTER §4.6)**, i.e. *aspirational here, purchasable as the player gears past this tier* — a
  savings goal surfaced in Appalachia, bought later. The **Pointer Tracking Dog** (convenience, T2–T3) is
  the equipment that *is* available here (finds rares / tracks wounded fleeing game). Neither is ever a
  Gate (progression — convenience never gates shared content).
- **Performance notes (mobile-first, 00 §8):** ridgeline verticality wants careful LOD — distant ridges
  as low-poly silhouette/billboard layers, not full geometry; dawn **fog** is the cheap atmosphere lever
  that doubles as a draw-distance mask (use it to bound view distance on the high ridge). Keep the
  turning-foliage palette in a small shared texture set. One Destination loaded at a time (hub-and-spoke),
  so density budget is local. Coyote packs are the only multi-agent crowd — cap concurrent pack count
  (see §8 density) so the AI/animation load stays phone-safe.

---

## 3. Wildlife Roster (Hunting)

> Template C for each. Listed in ascending difficulty. **Stats populated to the LOCKED T2 bands**
> (SYS_combat §3 / EQUIPMENT_MASTER §3.1): floor `≤2–3` shots at **T1** gear; mid `~3–5` at **T2**;
> apex **not soloable at T2** even intra-tier-maxed, soloable at **T3** / trivial **co-op at T2**.
> Cash is **derived** from `Income(2)/ExpectedTargetsPerHour(2) × RarityMultiplier`
> (= `1,700/45 ≈ 38` Cash baseline per routine target; Uncommon ×1.6 ≈ 60). It is *not* authored by
> hand — size/weight is flavor and does **not** change Cash (rarity drives Cash, per economy §5).
>
> **Two notes that prevent misreading (second-pass clarifications):**
> - **Rarity-label and spawn-frequency are decoupled** for the routine band. The `Rarity` field is the
>   *value tier* — it drives `RarityMultiplier` and the Rare-and-above artifact-mint threshold
>   (SYS_data_integrity). **Encounter frequency is set separately by §8 spawn density.** So a creature
>   can be a low-density spawn with an `Uncommon` *value* label (e.g. the mountain lion) — deliberately
>   kept ≤Uncommon so it stays off the artifact-mint path. Common/Uncommon are the *routine, stable-rate*
>   band; the scarce **1-in-N condition-gated** layer is Rare-and-above (§5).
> - **The nominal Cash below is `baseline × RarityMultiplier`, pre-normalization.** Economy normalizes
>   the actual Common/Uncommon *mix* so a routine hour sums to `Income(2)` (economy §5 / RD5); the
>   realized commons therefore land slightly below ~38 and uncommons slightly below ~60. These figures
>   are the *shape*, not the final tuned values — the economy chat owns the normalization.

### Ambiance-only (grant nothing — enforced server-side, combat §8)
- **Gray Squirrel, Chipmunk, Songbirds, Crow, Eastern Cottontail (re-skin of the Bayou rabbit, warier).**
  Atmosphere only; killing them pays no Cash, no Rank XP, no drops, no milestone credit, and they do not
  occupy the reward-bearing spawn ceiling. The "identify worthwhile targets" signal (01) as indifference,
  not a fine.

### Whitetail Deer  [Tier 2]  — FLOOR (the worked H50 example)
- **Rarity:** Common
- **Ambiance-only?:** no
- **Behavior:** flees
- **Pack size:** n/a (small loose groups; not shared-aggro)
- **Health:** 50
- **Damage to player:** 0 (non-threat; the floor is an *escape*-bounded target, not a survival one)
- **Speed:** 78 (outruns a player on foot — the legible Mount-want)
- **Min weapon tier to kill:** 1  **Min armor tier to survive:** 1 (no threat)
- **Co-op recommended?:** solo-with-top-gear (trivially solo)
- **Drops / reward:** ~38 Cash (Common); venison + hide (quest/butcher items — money-sink fuel, 01)
- **Re-skin of:** n/a (the new tier floor)
- **Spawn:** the Old Field and woodlot edges; **most active at dawn/dusk**. `KillWindow = TimeToFlee`
  (escape-bounded): detects at range and bolts, so it rewards range, stealth, and — once available — a
  Mount to close the chase. *(Worked: `ceil(50/18)=3` shots at T1, `=3` at T2 entry → ≤2–3 at T−1. ✓)*

### Wild Turkey  [Tier 2]  — FLOOR (lighter reward, wariest flee)
- **Rarity:** Common
- **Ambiance-only?:** no
- **Behavior:** flees
- **Health:** 35
- **Damage to player:** 0
- **Speed:** 70 (runs; short flight bursts)
- **Min weapon tier to kill:** 1  **Min armor tier to survive:** 1
- **Co-op recommended?:** solo
- **Drops / reward:** ~38 Cash (Common); a seasonal cosmetic-feather collectible hook for LiveOps (§9)
- **Re-skin of:** n/a
- **Spawn:** Old Field edges at first light; extreme `detectionRadius` (the "they always see you first"
  skill teach). A clean floor target that rewards patience over the deer.

### Wild Boar  [Tier 2]  — MID (the worked H88 example; the **hunting conquest milestone**)
- **Rarity:** Uncommon
- **Ambiance-only?:** no
- **Behavior:** aggressive
- **Health:** 88
- **Damage to player:** 40  **Attack interval:** 3.0 s
- **Speed:** 55 (charges; can be out-positioned, not out-run on foot)
- **Min weapon tier to kill:** 2  **Min armor tier to survive:** 2
- **Co-op recommended?:** solo-with-top-gear (T2-soloable — this is the point)
- **Drops / reward:** ~60 Cash (Uncommon); boar meat (butcher quest sink)
- **Re-skin of:** n/a (Midwest razorback flavor available as a cosmetic variant)
- **Spawn:** brushy mid-slopes and oak ridges. Survival-bounded `KillWindow`. *(Worked: T2 `ceil(88/25)=4`
  shots → 3–5 at T; T2 armor `DR 0.50`, 20/hit → ~5 hits to down → ~12 s window ≫ 5.6 s kill = **tense but
  safe in T armor**. ✓)* **This is the designated hunting milestone target** (§7) — the first "stand and
  fight" check, soloable at tier, parity with the fishing milestone (trophy bass).

### Coyote Pack  [Tier 2]  — THE CO-OP TUTORIAL (pack archetype; binding from combat §7)
> A *lone* coyote is a trivial floor kill. The **pack** is the lesson. Combined shared-aggro DPS exceeds a
> solo player's at-tier survive-while-killing budget; a **duo splitting aggro** handles it cleanly. This
> is "get a partner or over-gear," taught by mechanics, placed **before** the Rockies/Alaska hard walls.
> Pack size and shared-aggro are tuning parameters (combat §7) — values below are LOC calibration,
> illustrative-default, to confirm in playtest.
- **Rarity:** Common (per coyote)
- **Ambiance-only?:** no
- **Behavior:** pack (shared aggro, converge)
- **Pack size:** 4 (range 4–5; **cap concurrent packs** per §8 for mobile load)
- **Health:** 30 per coyote (≈ `ceil(30/25)=2` shots each at T2 → ~2.8 s/coyote)
- **Damage to player:** 22 per coyote  **Attack interval:** 2.0 s (fast, harrying)
- **Speed:** 72 (fast; flanks)
- **Min weapon tier to kill:** 2 (per coyote) — but **not solo-survivable as a pack at T2**
- **Min armor tier to survive (solo, as a pack):** 3 (over-gear) — **or T2 + a duo**
- **Co-op recommended?:** **duo** (the entire point)
- **Drops / reward:** ~38 Cash per coyote (~152 for a 4-pack) — the aggregate pays *more* than a single
  mid kill, the carrot that makes clearing it (with a partner) worthwhile
- **Re-skin of:** the wolf-pack template reserved for the Rockies (LOC_03) — see §10 reconciliation
- **Spawn:** draws and creek-bottoms; **most active at dusk/night** (the "Coyote Moon" LiveOps hook, §9).
  *Pack math (illustrative, to the spec — multi-attacker, so modeled as continuous DPS rather than the
  single-attacker (hits−1)-interval window used for the boar/apex). Solo, 4 coyotes hold shared aggro →
  incoming `4 × 22 × 0.50 / 2.0 ≈ 22` post-armor DPS. Killing them one-at-a-time costs ~2 shots ×1.40 ≈
  2.8 s each: the player drops the 1st coyote at ~2.8 s having taken ~62, then faces 3 (~16.5 DPS). Under
  realistic pack convergence (the coyotes close from spawn over ~1–1.5 s rather than all biting from
  t=0), full DPS lands late enough that the player is **downed at ~6 s having cleared only ~2 of 4 → solo
  fails at T2** (worst-case instant-convergence gives ~1 of 4 — either way solo loses). Duo: aggro splits ~2-and-2 → ~11 DPS
  each → each player clears their 2 in ~5.6 s while taking ~46 → **both survive with margin → handled.**
  ✓ Matches combat §7's "combined DPS exceeds the solo budget; a duo splitting aggro handles it."*

### Mountain Lion (Cougar / "Catamount")  [Tier 2]  — APEX / WALL (the worked H100 example)
> The T2 **conquest-class predator**, *behaves-as-T3* (combat §3/§4 armor offset). It is the **routine
> apex wall**, not the conquest milestone (§7) and not a scarce trophy: it is repeatable, it does **not**
> mint a tradeable artifact (only Rare-and-above mint — SYS_data_integrity RD1 / SYS_lodge_trophy), and
> it is the mechanical "you need T3 gear or a party" teacher. Its **scarce, single-mint trophy version is
> the Black Catamount (Mythic, §5)** — same behavioral/stat template, re-skinned. A dangerous predator
> that **hunts the player** → squarely the intended combat-threat category (01 appropriateness guardrail),
> framed as self-defense on the ridge, not slaughter of charismatic megafauna.
- **Rarity:** Uncommon (routine apex; Cash ~60 salvage — the reward is the *fight and the flex*, not the
  faucet, consistent with apex-as-progression-not-income)
- **Ambiance-only?:** no
- **Behavior:** aggressive (its **ambush** flavor is deferred past MVL — combat RD-C — so it is statted
  *aggressive/charge* at MVL, with a telegraphed pounce wind-up; ambush re-entry flagged for a later pass)
- **Health:** 100
- **Damage to player:** 76  **Attack interval:** 2.7 s
- **Speed:** 88 (very fast; closes hard — the threat that makes the ridge feel dangerous)
- **Min weapon tier to kill (solo):** 3   **Min armor tier to survive (solo):** 3
- **Co-op recommended?:** **solo only at T3** (tense) / **co-op at T2** (trivial) — **not soloable at T2**
- **Drops / reward:** ~60 Cash (Uncommon, a normal kill payout — NOT an artifact-salvage; only Rare+ mint artifacts); cosmetic pelt variant unlocks (identity, not power)
- **Re-skin of:** n/a (its Mythic melanistic variant, the Black Catamount, re-skins *from* it)
- **Spawn:** **Lookout Ridge**, low routine frequency (1 concurrent per Destination, §8). *(Worked: solo
  T2 `ceil(100/25)=4` shots, even maxed `ceil(100/32)=4`; survival `DR 0.38`, 47/hit → 3 hits → ~5.4 s
  window → `5.4/1.40 = 3.86` → **4 > 3.86 = NOT soloable at T2**. Solo T3: `ceil(100/35)=3`, `DR 0.50`,
  window 5.4 s → `5.4/1.30 = 4.15` → **3 ≤ 4.15 = soloable, tense**. Co-op T2: `EffectiveHealth(4)=250`
  vs 4× DPS, aggro split → drops fast. ✓ All three rows match the locked apex band.)*

---

## 4. Fish Roster (Fishing)

> Template D for each. **Stats populated to the LOCKED T2 catch bands** (SYS_fishing §3 /
> EQUIPMENT_MASTER §3.3): floor landable at **T1** rod+reel; mid landable at **T2**; trophy/apex snaps or
> throws at T2 (even maxed) and lands at **T3** / **T2 + co-op assist**. Cash derived from
> `Income(2)/ExpectedTargetsPerHour(2, fishing) × RarityMultiplier` (= `1,700/38 ≈ 45` baseline per
> routine catch; Uncommon ×1.6 ≈ 72). Water is **river/lake/pond — no Boat** (SYS_fishing §7).

### Bluegill / Panfish  [Tier 2]  — COMMON FLOOR (the worked FD30 example)
- **Rarity:** Common
- **Typical weight range:** 0.2–0.6 kg   **Record/trophy weight:** ~1 kg
- **Fight difficulty:** 30
- **Min rod tier / reel tier to catch:** 1 / 1
- **Bait/lure required:** worm/grub (basic, auto-restocked — never a tier input)
- **Water type:** pond / lake (Mill Pond, lake margins)
- **Drops / reward:** ~45 Cash (Common)
- **Spawn / bite condition:** all day, shallows; the protect-the-new-arrival floor catch. *(Worked:
  `FightTime 4.2 ≤ LandWindow 12` at T1 → landable at T−1. ✓)*

### Brook Trout  [Tier 2]  — COMMON (the fly-water teach)
- **Rarity:** Common
- **Typical weight range:** 0.3–0.9 kg   **Record/trophy weight:** ~1.5 kg
- **Fight difficulty:** 38
- **Min rod tier / reel tier to catch:** 1 / 1
- **Bait/lure required:** **fly** (basic *required-item* gate — legible "do you hold the right tackle?",
  SYS_fishing §4 / EQUIPMENT_MASTER §4.8; trivially priced, never a timer)
- **Water type:** river (cold Hollow Creek)
- **Drops / reward:** ~45 Cash (Common)
- **Spawn / bite condition:** cold flowing water, better at dawn/overcast — teaches the required-basic-bait
  check without gating play (every fish is catchable with its basic).

### Smallmouth Bass  [Tier 2]  — COMMON/MID
- **Rarity:** Common
- **Typical weight range:** 0.5–1.8 kg   **Record/trophy weight:** ~3 kg
- **Fight difficulty:** 50
- **Min rod tier / reel tier to catch:** 2 / 2
- **Bait/lure required:** crankbait/soft-plastic (basic)
- **Water type:** river / lake
- **Drops / reward:** ~45 Cash (Common)
- **Spawn / bite condition:** rocky river runs and lake structure; the warm-up before the milestone bass.

### Trophy Largemouth Bass  [Tier 2]  — MID (the worked FD60 example; the **fishing conquest milestone**)
- **Rarity:** Uncommon
- **Typical weight range:** 2–4 kg   **Record/trophy weight:** ~6 kg
- **Fight difficulty:** 60
- **Min rod tier / reel tier to catch:** 2 / 2
- **Bait/lure required:** spinnerbait/jig (basic)
- **Water type:** lake (Mill Pond / Lowland Lake)
- **Drops / reward:** ~72 Cash (Uncommon)
- **Spawn / bite condition:** lake structure, low light. *(Worked: T2 `FightTime 9.8 ≤ LandWindow 16` →
  landable at T; T1 `LandWindow 0` → **snap** → needs T2 via the `min` rule. ✓)* **This is the designated
  fishing milestone target** (§7), T2-soloable, parity with the hunting milestone (boar) — per
  SYS_fishing §8.

### Northern Pike  [Tier 2]  — HIGH-MID / SUB-APEX
- **Rarity:** Uncommon
- **Typical weight range:** 2–5 kg   **Record/trophy weight:** ~8 kg
- **Fight difficulty:** 78
- **Min rod tier / reel tier to catch:** 2 (tense, near-ceiling) → comfortably 3
- **Bait/lure required:** spoon (basic)
- **Water type:** lake / slow river
- **Drops / reward:** ~72 Cash (Uncommon)
- **Spawn / bite condition:** weed edges, cooler water. The "the muskie is coming" difficulty rung.

### Record Muskie (Muskellunge)  [Tier 2]  — APEX / CONTENT MOMENT (the worked FD90 example)
> The fishing apex, **rod-leaning** (high `PeakRunForce`, needs rod headroom). Like the mountain lion, it
> is the **routine apex wall**, not the milestone (§7); its **scarce single-mint version is the Tiger
> Muskie (Legendary, §5)**. Repeatable; pays Uncommon Cash directly (no artifact mint); the flex is the fight.
- **Rarity:** Uncommon (~72 Cash salvage)
- **Typical weight range:** 5–9 kg   **Record/trophy weight:** ~12 kg
- **Fight difficulty:** 90
- **Min rod tier / reel tier to catch (solo):** 3 / 3 — **snaps at T2 even maxed**; **T2 + co-op assist**
  lands it (the fishing co-op route, SYS_fishing §9)
- **Bait/lure required:** large bucktail/sucker (basic)
- **Water type:** lake (the deep Lowland Lake basin)
- **Drops / reward:** ~72 Cash (Uncommon, normal kill payout)
- **Spawn / bite condition:** low-frequency, dusk/overcast, deep basin. *(Worked: T2 `LandWindow 0`
  (snap), T2-maxed `LandWindow 4 < FightTime 21.4` → **fails**; T3 `FightTime 15.8 ≤ LandWindow 20` →
  **landable, tense**, or T2 + co-op. ✓)*

---

## 5. Rare & Mythical Spawns

> Template E for each. The **trade-economy + content layer**: **condition-gated, independent spawns**
> layered on the routine population — **never** per-kill upgrade rolls (SYS_combat RD-E / SYS_economy
> RD5). Each **mints exactly one unique artifact** (server-minted `artifactId`, owner, disposition,
> provenance — SYS_data_integrity RD1) and **writes NO Cash at the kill/catch**: Cash is realized **only
> on the SALVAGED transition** and is **floored low** — the real value is **P2P trade + the Trophy Hall**
> (economy §5; this keeps rares out of the Cash faucet and protects the moat). Default disposition on
> mint is **HELD** with a one-tap "Mount it in your Trophy Hall?" prompt — never auto-display
> (SYS_lodge_trophy RD1); a **displayed** trophy is not tradeable (mutual exclusivity). **Re-release
> policy: NEVER** (00 §5). The **Pointer** widens detection radius — it helps you *find*, never *win*.
>
> **Effective rarity is two knobs (inherited from LOC_01 §5).** For a condition-gated spawn, **effective
> rarity = per-window 1-in-N roll × condition frequency × player-presence-with-prereqs.** Because the
> conditions below (dawn / storm / night-fog + specific location + sometimes a basic bait) *already*
> carry most of the scarcity, the per-window N is kept **modest** so the rares stay **accessible-but-
> rare** — dreamable, not unreachable. Mythic scarcity still **escalates above the Bayou** (LOC_01's
> "later-tier Mythics are far rarer"): the Catamount's *effective* rate sits below the Bayou Leviathan's.
>
> **Rares are finds, not walls — with one deliberate exception.** Following LOC_01, the deer rares and
> the deer rares **share their base creature's floor profile**, and the Tiger Muskie is **statted
> independently at a T2-landable level** (FD 58 @ 8 kg, not the apex muskie's FD 90) — in all three a
> rare is a *find* (the content moment is the discovery + the clean kill/catch, not a difficulty wall, so
> a player can take it on the gear that found it). The **single exception is the Black Catamount**, the
> tier's Mythic capstone, which **is** an apex-band fight — the first "rare that is also a wall" in the
> game, justified and flagged (§10).

### Piebald Whitetail  [Rare]  — Appalachia
- **Type:** hunting trophy  ·  **Base creature/fish:** Whitetail Deer (floor re-skin — **shares the
  H50 floor profile; a find, not a fight**)
- **Spawn condition:** dawn/dusk in the Old Field, clear weather (the *accessible* rare — the player's
  likely first minted artifact, teaching the mint→HELD→display/trade choice)
- **Spawn rate:** **1-in-250** qualifying deer encounters in-window (modest per-window N; the dawn/dusk +
  location condition does the rest — effective rate is a genuine but reachable Rare)
- **Reward:** **no Cash at kill** — mints one **Piebald Mount** artifact; **if salvaged**, floored low
  (~nominal Rare ×2.8, set well below P2P value)
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER
- **Intended content moment:** the first "wait — that one's *different*" double-take; the entry-level
  trade chip that onboards a player into the Trading Post and Trophy Hall.

### Ghost Buck (Albino Whitetail)  [Legendary]  — Appalachia  *(the archetypal Template-E dawn legendary)*
- **Type:** hunting trophy  ·  **Base creature/fish:** Whitetail Deer (floor re-skin, trophy-class rack —
  **shares the H50 floor profile; a find, not a fight**)
- **Spawn condition:** **dawn only**, clear weather, **the Old Field**, low ground-fog — the canonical
  "legendary buck at dawn" (01; the gold-light content frame the sensory signature is built around)
- **Spawn rate:** **1-in-1,500** qualifying dawn windows (per-window N kept modest; dawn-only + location +
  clear-weather + presence compound to the region's marquee Legendary effective rate — a real return-hook
  and YouTube/TikTok thumbnail)
- **Reward:** **no Cash at kill** — mints the unique **Ghost Buck** artifact; **if salvaged**, floored low
  (~nominal Legendary ×9)
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER
- **Intended content moment:** white stag in gold dawn fog, the clean-kill flourish (combat §1, reserved
  for Legendary+) firing in slow-mo — the designed screenshot. Anchors the **dawn-buck LiveOps beat** and
  the autumn **Rut** competition (§9).

### Tiger Muskie  [Legendary]  — Appalachia
- **Type:** record fish  ·  **Base creature/fish:** Muskie/Pike natural hybrid (a *real* rarity, so it
  reads as authentic). **A find, not a wall: FD 58 at 8 kg — genuinely landable at T2** on the gear that
  found it, so a pure angler's Legendary chase mirrors the hunter's Ghost Buck (dual-loop parity at the
  rare layer). *(Worked to the locked §3.3 model: `Stamina = 0.5·58·(1+8/10) = 52.2`; T2 `NetDrain =
  13·0.7 − 0.08·58 = 4.46` → `FightTime ≈ 11.7 s`; `LandWindow = max(52 − 0.6·58, 0) = 17.2` →
  `11.7 ≤ 17.2` → **lands at T2, margin +5.5 s** — a big, dogged, reel-leaning fight, tenser than the
  milestone bass (9.8 s) but not a wall.)* The challenge is *reaching the condition*,
  not snapping the line.
- **Spawn condition:** **during storms**, dusk, the deep Lowland Lake basin + a large bucktail (basic
  required-item as part of the condition — gates the *attempt*, never bought past; 01: "storms make rare
  fish bite")
- **Spawn rate:** **1-in-1,500** qualifying storm-dusk bite checks (modest per-window N; storms are
  infrequent + location + bait + presence carry the scarcity → the fishing-side equal of the Ghost Buck)
- **Reward:** **no Cash at catch** — mints the unique **Tiger Muskie** artifact; **if salvaged**, floored
  low (~nominal Legendary ×9)
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER
- **Intended content moment:** the storm-light hero catch — the fishing-side mirror of the Ghost Buck, so
  a pure angler has an equal-weight Legendary to chase (dual-loop parity at the rare layer).

### The Black Catamount (Melanistic Mountain Lion)  [Mythic]  — Appalachia  *(the region's "white whale")*
- **Type:** special creature / hunting trophy  ·  **Base creature/fish:** Mountain Lion (apex re-skin —
  melanistic "black panther of Appalachia" folklore; appropriate-for-13+ as a *predator threat*, framed
  as a legendary stalker on the ridge)
- **The deliberate exception — a rare that is ALSO a wall.** Unlike the finds above, the Catamount
  **carries the full mountain-lion apex profile** (H100, behaves-as-T3 → **not soloable at T2**, soloable
  at **T3**, trivial **co-op**). This is the tier's capstone challenge. *Mitigation against the "fumble a
  once-in-weeks spawn" problem:* by the time a player is repeatedly hunting Lookout Ridge at night they
  are doing late-Appalachia / co-op content (likely T3-geared or grouped), and the spawn **persists for
  its encounter window** rather than vanishing instantly. **Flagged for review (§10).**
- **Spawn condition:** **night + heavy fog**, **Lookout Ridge** — a co-op-class encounter (the white-whale
  capstone)
- **Spawn rate:** **1-in-6,000** qualifying night-fog windows (the single Mythic for the Destination — 01/
  02: ~one per region early; per-window N modest, the compound condition carries scarcity; **effective
  rate sits below the Bayou Leviathan's** — tier-escalating Mythic scarcity, LOC_01 §5)
- **Reward:** **no Cash at kill** — mints the unique **Black Catamount** artifact (the server-flex
  trophy); **if salvaged**, floored low (~nominal Mythic ×16)
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER
- **Intended content moment:** green eyeshine in the fog, then the cat in the beam — the rarest, most
  clip-worthy moment in the early game; the trophy that says "I conquered Appalachia harder than you."

---

## 6. Region-Specific Equipment

> The **Tier-2 gear is already authored in EQUIPMENT_MASTER §3/§4** — Lever-Action Rifle (weapon), Field
> Jacket (armor), Appalachia Bait Rod (rod), Baitcaster (reel). **Referenced, not re-authored here.** The
> one region-introduced companion this Destination surfaces is the **Pointer**, which is **already
> authored in EQUIPMENT_MASTER §4.7**; reproduced below in reference form only (the canonical block is the
> master's — do not fork its stats).

### Pointer (Appalachia Tracking Dog)  — *reference; canonical block: EQUIPMENT_MASTER §4.7*
- **Category:** dog
- **Tier:** available **T2–T3**
- **Available at:** Kennel & Stable (Outpost Cabin surfaces it here first)
- **Cost:** basic breed ~8,000 Cash; **rare breeds are P2P trade items** (value flows to the Trading Post)
- **Primary stat(s):** widens rare-spawn **detection radius** (helps find the §5 rares); tracks
  wounded/fleeing game (a `flees`-archetype aid for the deer/turkey chase). **No** damage, survivability,
  or catch power.
- **Weight:** n/a
- **Strengths:** faster rare discovery; recovers wounded fleeing game; regional-breed identity
- **Weaknesses / limits:** **never in a Gate**; cannot make an un-takeable target takeable (rares stay
  condition-gated)
- **Gates unlocked:** none — ever
- **Monetization role:** convenience + identity (rare breeds = collectible/tradeable)
- **Notes:** the first Tracking Dog the player meets; its job is to make the §5 rare hunt feel *active*
  rather than purely RNG.

*(The Mount is **not** a region-specific Appalachia item — it is surfaced as aspirational here but is
T3-available at the Kennel & Stable, authored in EQUIPMENT_MASTER §4.6. No new Appalachia-only weapon,
armor, rod, or reel is introduced; the T2 line is the master's.)*

---

## 7. Gating (entry & exit)

> Inherited from SYS_progression §gate-table (required_tier = **EHT ≥ N OR EFT ≥ N**; milestone =
> conquer-in-place; carry-proof on gear, carry-friendly-but-non-skippable on the milestone).

- **To UNLOCK Appalachia:** **Tier-2 gear on at least one loop (EHT ≥ 2 OR EFT ≥ 2) + conquer the Bayou.**
  This is the **first time armor enters the bill** — a hunter's unlock cost is weapon + armor =
  `2 · c · Income(1) = 6,000` (EQUIPMENT_MASTER §3.4; economy §3); a fisher's is rod + reel = 6,000. The
  conquest prerequisite (conquer Bayou) is the light milestone LOC_01 sets (protects D1). This purchase
  *is* the "first commitment point."
- **Appalachia's conquest milestone (designated here — OR-gate, either loop conquers):**
  - **Hunting target:** down the **Wild Boar** (mid, H88, T2-soloable).
  - **Fishing target:** land the **Trophy Largemouth Bass** (mid, FD60, T2-soloable).
  - Both are **soloable at tier** and **parity-matched** (SYS_fishing §8 target-parity; flagged as a
    tuning item). The **apex (Mountain Lion) and the Record Muskie are deliberately NOT the milestone** —
    they are the co-op/aspirational content moments, so a pure-solo player on either loop can always
    conquer without being walled. (At T2, unlike Alaska, T+1 gear *does* exist; we still keep the
    milestone at the soloable mid so conquest is never gated on an extra gear purchase or a partner.)
- **To progress PAST Appalachia:** **conquer Appalachia (the milestone above) + the next Destination's
  required_tier.**
  - **Post-launch (Rockies inserted, T3):** Rockies needs **EHT/EFT ≥ 3 + conquer Appalachia**.
  - **MVL (Rockies skipped):** **Alaska needs EHT/EFT ≥ 4 (expedition-grade T4 gear) + conquer
    Appalachia** — the verified two-tier jump (SYS_economy §4: ~10.2 hrs single-loop ≈ 1.7× a normal step,
    *passes*; SYS_combat MVL difficulty check: *passes* because the player enters Alaska already holding
    T4 gear, so Alaska's floor is comfortable — the jump is a *purchase* step, not a difficulty cliff).
    The **first Boat** also enters here as the gate to Alaska's *coastal fishing sub-area* (not Alaska
    entry) — surfaced as a savings goal but bought at the Alaska step.
- **What this tier pushes the player to buy/achieve next:** their **first armor** (to enter at all), the
  **intra-tier T2 climb** (`m · Income(2) ≈ 4,250`/loop) toward boar/bass-capable, the **Pointer** (to
  hunt the §5 rares), and the **aspirational Mount + the T4 expedition gear** they'll save toward for the
  Alaska jump. The legible wants — fleeing deer (Mount), the un-soloable cougar (T3 gear / a party), the
  pack (a partner) — are all *forced-progression pressure expressed as mechanics*, not text.

---

## 8. Economy Hooks (hand-off to economy chat)

> **Per-hour income band: `Income(2) ≈ 1,700/hr`** (economy §2; B=1,000, g=1.7), **identical for hunting
> and fishing** (dual-loop balance, economy §6 — a bored hunter fishes and still earns the same). All Cash
> below is **derived** from the band, not authored; LOC fills these into the band, the economy chat tunes
> magnitudes.

- **Cash faucets here:**
  - *Kill payouts:* deer ~38 · turkey ~38 · boar ~60 · coyote ~38 ea (pack ~152) · mountain lion ~60
    (all `Income(2)/45 × RarityMultiplier`, **nominal/pre-normalization** — see the §3 note; economy
    normalizes the Common/Uncommon mix to sum to `Income(2)`).
  - *Catch payouts:* panfish ~45 · brook trout ~45 · smallmouth ~45 · trophy bass ~72 · pike ~72 ·
    muskie ~72 (all `Income(2)/38 × RarityMultiplier`, nominal/pre-normalization).
  - *Rare salvage (NOT a kill payout):* the §5 rares **write no Cash at the kill/catch** — they mint an
    artifact; Cash appears **only if the player chooses to SALVAGE** it, floored low (SYS_data_integrity /
    economy §5). Real value is P2P trade + the Trophy Hall; rares are bonus **on top of** the band, never
    averaged in (RD5). This faucet is deliberately tiny.
  - *Quest / daily-quest rewards:* scaled as a fraction of `Income(2)` (economy §1) — "down a boar"
    (pushes the milestone), "land 5 trout" (teaches fly-water), "bring the butcher 3 venison" (sink+faucet).
  - *Idle/AFK accrual:* the capped offline trickle (a fraction of active `Income(2)`; never advances
    rank/conquest — economy §6).
- **Cash sinks here:**
  - *Tier-2 gating gear:* weapon + armor (or rod + reel) = **6,000** — the first-commitment sink, armor's
    first appearance (economy §3 / EQUIPMENT_MASTER §3.4).
  - *Intra-tier T2 climb:* `m · Income(2) ≈ 4,250`/loop across discrete upgrade steps (the floor→apex
    stat climb, the high-frequency early spend).
  - *Pointer Tracking Dog:* ~8,000 (convenience; EQUIPMENT_MASTER §4.7).
  - *Mount (aspirational, T3-priced ~10,200):* surfaced here, bought past this tier — a cross-loop savings
    goal (economy §6).
  - *Premium ammo / premium bait* (optional convenience, capped — never required), *cosmetics* (evergreen
    identity ballast), *revive/restock* (light, with free/ad alternative).
- **Spawn-density values (set *within* the combat/fishing cap mechanism — the economy's hard dependency,
  economy §5 / combat §5 / fishing §6; illustrative-default, confirm against realized
  `ExpectedTargetsPerHour(2)` in playtest):**
  - *Hunting (`MaxConcurrentTargets` / `RespawnInterval` per spawn area):* deer 6 / 45 s · turkey 4 / 60 s
    · boar 3 / 90 s · coyote **packs: 1–2 concurrent, 180 s** (also the mobile crowd cap) · mountain lion
    **1 per Destination / 300 s**. → `SpawnThroughputCeiling` tuned so a solo T2 player realizes
    **~45 targets/hr**, and an **over-geared low-tier farmer caps at ≈ Income(1)** (the anti-farming
    guarantee — combat §5).
  - *Fishing (`MaxConcurrentBites` / `BiteRespawnInterval` per water cell, with spot-depletion):* ~4–6 /
    30–45 s → realized **~38 catches/hr** at T2; over-geared low-tier farming caps at ≈ Income(1)
    (fishing §6).

---

## 9. LiveOps / Event Ideas

> Appalachia-appropriate, tied to **real seasons** (a year-round calendar for free — 01 §timed-spawns;
> SYS_liveops owns cadence, economy owns each event's budget ceiling so a faucet can't flood supply).

- **The Dawn Buck (recurring daily beat):** the **Ghost Buck** dawn window as the canonical return hook —
  a reason to log in *at dawn*. The everyday version of the LiveOps rare-spawn calendar.
- **The Rut (autumn seasonal):** elevated trophy-buck spawns + a **trophy-rack leaderboard competition**;
  a Fall Foliage cosmetic season (turning-hardwood palette, blaze-orange outfits) as the evergreen
  identity faucet's seasonal drop. The Ghost Buck's marquee window.
- **Coyote Moon (night event):** increased **pack** activity and size — a deliberate **co-op push** that
  amplifies the tutorial into a group event ("clear the packs with friends"); aggregate Cash carrot
  scaled within the event budget.
- **Stocked-Trout Opener (spring fishing season):** a trout-bite surge in Hollow Creek (the fishing-side
  daily hook), pairing with the fly-water teach; an angler's mirror of the Rut.
- **Storm Fronts (weather-gated):** rolling storms trigger the **Tiger Muskie** bite window — "storms make
  rare fish bite" as a live, watchable weather event that drives the fishing trade-rare chase.
- **Cougar Sighting (rare alert / Mythic teaser):** a server-wide "tracks on Lookout Ridge" alert seeding
  the **Black Catamount** night-fog window — the white-whale hype beat that manufactures creator content.

---

## 10. Open Questions / Flags

1. **Wolves-vs-coyote pack — RESOLVED here.** SYS_progression / 01 used a **"wolf pack"** as the example
   for the **Rockies** unlock, *not* Appalachia; neither locked roster (combat §3, EQUIPMENT_MASTER §3)
   contains wolves. Resolution: the **Appalachia co-op tutorial is an Eastern Coyote pack** (regionally
   accurate — the Appalachian "coywolf" — and the cleaner choice the brief calls for), and **wolves are
   reserved for the Rockies (LOC_03)** as that tier's gear-or-die wall. No conflict with progression's
   text (its wolf reference is the Rockies, which this honors). **Flag for LOC_03:** the wolf-pack template
   is yours; inherit the coyote-pack shared-aggro mechanics here and scale to T3.
2. **Milestone designation & parity.** Hunting milestone = **Wild Boar**; fishing milestone = **Trophy
   Largemouth Bass** — both T2-soloable, both the *mid*, never the apex (so solo players on either loop are
   never walled, and conquest is never gated on extra gear or a partner). Matches SYS_fishing §8's proposal
   verbatim. **Target-parity (equal effort across the two loops' milestones) is flagged as a tuning item**
   (progression / fishing §8) — confirm boar-difficulty ≈ trophy-bass-difficulty in playtest.
3. **Apex-as-wall vs apex-as-trophy split (design decision — confirm acceptable).** The **Mountain Lion**
   is the *routine apex wall* (Uncommon, repeatable, **no artifact mint**, no clean-kill flourish — only
   Rare+ mint/flourish per SYS_data_integrity RD1 / SYS_lodge_trophy and combat §1). Its **scarce,
   single-mint, flourish-bearing trophy version is the Black Catamount (Mythic re-skin)**. This conforms to
   the locked rules (only Rare+ are scarce artifacts; the re-skin pattern is sanctioned, combat §re-skin)
   and protects the moat (a farmable apex would flood trophies). **Flag for combat/data_integrity to
   confirm** the routine-apex/scarce-variant split reads as intended rather than as one "apex = content
   moment" object.
4. **Mountain Lion appropriateness & archetype.** Framed as a **predator that hunts the player**
   (self-defense on the ridge) → the *intended* combat-threat category (01 guardrail), not charismatic
   megafauna being slaughtered. Its **ambush** flavor is **deferred past MVL** (combat RD-C), so it is
   statted **aggressive/charge** with a telegraphed pounce wind-up at MVL; **flag ambush re-entry** for the
   Amazon pass (LOC_06).
5. **Per-archetype KillWindow / pack values are LOC calibration (combat open flag #5), illustrative-default
   here.** The coyote pack math, attack intervals, flee timings, and §8 density values are populated to the
   spec but are **provisional pending playtest** — instrument the Appalachia pack death-rate and the
   solo-vs-duo clear-rate as the co-op-tutorial canary; instrument the boar/bass milestone time-to-conquer
   for parity.
6. **Mount purchase point in the MVL (Rockies skipped).** The Mount is surfaced here as aspirational but is
   **T3-priced (~10,200)**; with Rockies absent, the exact in-MVL affordability point falls inside the
   `Income(2)`→T4-gear climb. **Defer the precise timing to SYS_economy** (it is a savings-goal flavor item,
   not a gate). Heavy-gear→Mount convenience tie is asserted, not yet mechanized (EQUIPMENT_MASTER open flag
   E) — not a LOC_02 dependency.
7. **The Black Catamount is the first "rare that is also a wall" — flagged.** Following LOC_01, every other
   rare here is a *find* (base-creature stats; the moment is the discovery). The Catamount alone carries the
   apex profile (not soloable at T2). The risk LOC_01 deliberately avoided is a player rolling a once-in-
   weeks spawn they then can't take. Mitigations stated in §5 (it's late-tier/co-op content by the time a
   player farms the night ridge; the spawn persists for its window). **Confirm in playtest** that the
   "find-it-but-can't-take-it-solo" case is rare and reads as aspirational, not punitive; if it reads badly,
   the fallback is to drop the Catamount to base mountain-lion-as-a-find (lose the capstone-fight flavor).
8. **Inherited reconciliation gap — mechanical FightTime vs. the rate-model input (NOT introduced here;
   surfaced honestly per LOC_01's precedent).** The worked T2 catch FightTimes are short (panfish 4.2 s,
   trophy bass 9.8 s, muskie 15.8 s at T3), while SYS_fishing §5's *rate model* uses a T2 `FightTime ≈ 38 s`
   inside `TimePerCatch ≈ 95 s`. These are different layers (one mechanical-per-fish at `E_expected`, one a
   modeled per-catch average), but the ~4× gap is the same modeled-vs-mechanical seam LOC_01 flagged and the
   load-bearing `ExpectedTargetsPerHour` unknown (combat/fishing open flags, economy §6). **Flag for the
   joint economy/fishing tuning pass**, not resolvable in a LOC doc; LOC_02's per-fish FightDifficulty and
   §8 bite-density values are the inputs that pass will tune against.
9. **Corpus hygiene — `LOC_01_bayou.md` not on the mounted disk, but RETRIEVED from project knowledge
   (second pass).** It was missing from `/mnt/project/` but is present in the project knowledge base; this
   pass read it and reconciled LOC_02's conventions to it (header structure, the no-Cash-at-kill rare rule,
   the two-knobs rarity framing, finds-vs-walls). Residual stylistic differences (LOC_01 numbers its §2
   sub-headings 2.1/2.2; LOC_02 keeps the flat Template-A field style) are cosmetic and compose fine. Flag
   the disk/knowledge-base mismatch as a **build-pipeline hygiene item** so Claude Code reads from the
   authoritative source.

---

## Out of Scope (named and deferred)

- **Combat & fishing math** — **LOCKED** at T2 (SYS_combat §3 / SYS_fishing §3 / EQUIPMENT_MASTER §3);
  this doc **populated** to it and did not re-derive it.
- **The Cash curve / income-band magnitudes, inflation, sink macro-balance** — **SYS_economy** (this doc
  uses `Income(2)` and the derivation rule; it does not set B, g, c, m, or tune sinks).
- **T2 gear stats and the Mount/Pointer pricing formulas** — **EQUIPMENT_MASTER §3/§4** (referenced, not
  authored).
- **Trade mechanics (escrow, anti-dupe, tradeable discriminator)** — **SYS_trading / SYS_data_integrity**
  (this doc only states each rare *is* a single-mint tradeable artifact).
- **The first-five-minutes funnel** — **LOC_01 / SYS_onboarding_funnel** (Appalachia is the
  *post*-onboarding commitment tier).

---

## Changes from v1 (the second-pass diff)

1. **Rares no longer imply Cash at the kill.** Every §5 reward line now reads "**no Cash at kill/catch** —
   mints one artifact; if SALVAGED, floored low," matching SYS_data_integrity / LOC_01. (v1 wrote "floored
   salvage (~N nominal)," which implied a kill-time faucet.) §8's rare line corrected to match.
2. **Rare spawn rates recalibrated for the "two-knobs" model.** Per-window N's lowered (Piebald 400→250,
   Ghost Buck 3,000→1,500, Tiger Muskie 3,000→1,500, Catamount 12,000→6,000) and reframed as *per-window
   rolls* whose compound condition carries most of the scarcity — so the rares are accessible-but-rare, not
   unreachable. Catamount's *effective* rate noted as below the Bayou Leviathan's (tier-escalating Mythic
   scarcity).
3. **Finds-vs-walls split added.** Piebald / Ghost Buck / Tiger Muskie are now explicitly *finds* (share
   base stats; the Tiger Muskie is statted independently at a T2-landable level — **FD 58 @ 8 kg**,
   worked to land at T2 with +5.5 s margin); the Black Catamount is the one deliberate
   *rare-that-is-also-a-wall*, with mitigation and a playtest flag (§10 #7).
4. **Two clarifications added to prevent misreading:** rarity-label vs spawn-density are decoupled (§3); the
   nominal Cash figures are pre-normalization, with economy normalizing the Common/Uncommon mix to
   `Income(2)` (§3, §8).
5. **Coyote solo-downed math** set to "downed at ~6 s having cleared ~2 of 4" under realistic pack
   convergence (worst-case instant-convergence ~1 of 4; solo fails either way), with the continuous-DPS
   modeling assumption stated.
6. **New honest flags:** the inherited mechanical-vs-modeled FightTime reconciliation gap (§10 #8) and the
   Catamount-wall risk (§10 #7).
7. **Header aligned to LOC_01** (inherited-as-binding, authors-vs-cites, numbers convention) and the
   `LOC_01_bayou.md` flag updated — the file was retrieved from project knowledge and its conventions
   reconciled (§10 #9).
8. **No change** to: identity/story, map, the locked-band stat populations for deer/turkey/boar/coyote/
   mountain-lion and panfish/trout/bass/pike/muskie, the milestone designation (boar / trophy bass), the
   gating, or the LiveOps set. The roster and its band-conformance are unchanged; the second pass was
   correctness and consistency, not re-design.
