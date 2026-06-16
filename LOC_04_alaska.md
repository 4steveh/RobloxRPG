# Location: Alaska (Tier 4)

> **TOP-TIER MVL Destination — the climax of the Minimum Viable Loop, the first BOAT gate, and the
> first real "gear-or-die" wall.** Third and final MVL location (Bayou → Appalachia → Alaska, Rockies
> skipped). Follows the Template A pattern established by LOC_01 / LOC_02. This doc carries the
> single most important downstream constraint in the project (the milestone constraint, below); it is
> the one LOC doc combat and fishing pre-emptively wrote a Resolved Decision *for*.
>
> **Canonical filename: `LOC_04_alaska.md`** (number = tier per 02; `LOC_03_rockies.md` is the Tier-3
> post-launch content drop per `03_BUILD_PLAN` Phase 2). Flagged in §10 because the chat brief
> requested `LOC_03`.
>
> **THE MILESTONE CONSTRAINT (BINDING — combat Resolved Decision A + fishing Decision 7).** At the MVL,
> Alaska is the top tier, so **T5 gear does not exist at launch**. Progression's apex rule (apex = T+1
> gear solo OR T gear + co-op) therefore leaves any apex with **NO solo route** until T5 ships
> post-launch. So, stated explicitly up front and enforced throughout this doc:
> - **Hunting conquest milestone = the BULL MOOSE (canonical; caribou is the reachability fallback, not
>   a co-equal path — §3/§7/§10 #1), a T4-soloable signature creature — NOT the grizzly.**
> - **Fishing conquest milestone = the KING (CHINOOK) SALMON, a T4-soloable signature catch — NOT the
>   halibut.**
> - **The GRIZZLY (hunting) and the GIANT HALIBUT / open-ocean "white whale" (fishing) are
>   CO-OP-ONLY APEXES / content moments with NO solo route until T5 gear ships.**
>   Designating the grizzly or halibut as the conquest milestone would strand a pure-solo player —
>   they could never conquer Alaska and never advance the Passport — breaking progression's "milestone
>   non-skippable *but reachable*" guarantee, worst at soft-launch when co-op partners are scarce. This
>   is the exact bug combat caught; it is not reintroduced here.
>
> **THE BOAT GATE (binding — fishing §7 / progression §2).** The first Boat (Coastal Skiff,
> EQUIPMENT_MASTER §4.5) gates Alaska's **coastal fishing sub-area** (king salmon, halibut) — **NOT
> Alaska entry**. A hunter walks the interior for caribou/moose Boat-free; a fisher fishes the interior
> rivers Boat-free on arrival, but needs the Boat to reach the coastal king salmon (the fishing
> milestone). How that reads (§7): the Boat is the legible "you need a boat for the coast" expedition
> purchase (01), and a *pure fisher* must own it to conquer Alaska via fishing — an asymmetry flagged
> in §10 #6.
>
> **THE TWO-TIER JUMP (verified upstream; carried here).** The MVL skips Rockies (T3), so
> Appalachia (T2) → Alaska (T4) is a two-tier jump. Economy verified the **Cash** gap is affordable
> (≈10.2 hrs single-loop ≈ 1.7× a normal step = `g`; passes — SYS_economy §4); combat verified the
> **difficulty** gap passes **because the player enters Alaska already holding T4 gear** (the gate
> requires EHT/EFT ≥ 4, so gearing to T4 happens *before* arrival, and Alaska's floor — takeable at
> T−1 = T3 — is comfortable on T4 gear; SYS_combat MVL difficulty check). **Two conditions are BINDING
> ON THIS DOC and are honored in §3/§4:** (1) Alaska's floor/mid creatures are statted so **T4 gear
> clears them at the NORMAL shot-count bands** — difficulty *within* Alaska is normal-for-its-tier, not
> inflated to "punish" the skip; (2) **every Alaska lethal threat is TELEGRAPHED** (no random
> one-shots), so the higher *absolute* damage reads as legible. The danger is **felt but legible** —
> the central design tension of this doc, surfaced in §10 #1.
>
> **What this doc authors vs. cites.** It authors the *place*, the *roster*, the per-target
> *engagement inputs* (creature Health/Damage/Speed and KillWindow inputs; fish FightDifficulty/
> weights; per-area spawn-density and bite-density values), the *rares* and their conditions, the
> *milestone designation*, and the genuinely region-specific gear in Template B (snowshoes,
> ice-fishing kit). It **cites** every Cash value (economy owns the band; per-target Cash is *computed*
> from it, never authored here), the combat/fishing math (LOCKED at T4 — populated, not re-derived),
> and all gear *balance/stats* — the T4 line, the Coastal Skiff, the Snowmobile Mount, and the Husky
> are authored in EQUIPMENT_MASTER and referenced, not re-statted. Cash figures shown are **computed
> illustrations from economy's band**, flagged as such.
>
> **Inherited as binding (consumed, not re-litigated):** SYS_progression v2.1 (Tier 4; EHT/EFT =
> min-rule; floor takeable at T−1, apex ~T+1 solo OR T + co-op; milestone earned-in-play, carry-proof
> on gear; OR-gate across loops; re-skins populate floor/low-mid never apex §6; Boat gates a sub-area
> not entry; passport DAG re-points Appalachia→Rockies when Rockies ships). SYS_economy v2.1
> (`Income(4) ≈ 4,913/hr`; payout *computed* `Income(T)/ExpectedTargetsPerHour × RarityMultiplier`;
> band normalized over the routine Common/Uncommon mix only, rares bonus on top — RD5; the verified
> two-tier-jump affordability §4; spawn-density-cap dependency §5). SYS_combat v1.1 (LOCKED T4
> floor/mid/apex bands §3; **Resolved Decision A**; the two-tier-jump difficulty check + its two
> binding conditions; telegraphed-lethal-threat contract; armor DR model; co-op Health scaling; rares
> as independent condition-gated spawns RD-E; ambiance enforced server-side; wolf-pack template
> reserved to Rockies/LOC_03 per LOC_02). SYS_fishing v1.1 (LOCKED T4 catch bands §3; **Decision 7**;
> the first Boat gates coastal §7; the rod-bound/reel-bound texture axis; bite-density caps; rares
> condition-gated). EQUIPMENT_MASTER (worked T4 line §4.1–§4.4 — Heavy Expedition Rifle, Expedition
> Parka, Coastal Surf Rod, Coastal Lever-Drag; the **worked king salmon and worked halibut apex**
> §4.3/§4.4; Coastal Skiff §4.5; Snowmobile §4.6; Husky §4.7; basic/premium bait §4.8). SYS_data_
> integrity (rares mint **one** unique artifact, **write no Cash at kill/catch**, disposition XOR).
> SYS_lodge_trophy (mint → HELD → one-tap "Mount it" prompt; displayed ≠ tradeable).
>
> **Numbers convention** (matching the SYS_ docs): formulas/relationships are the design; every
> magnitude is an *illustrative default* and calibration knob, validated against live data. Stats
> 1–100, weight kg, Cash currency, rarity Common→Mythic, spawn rates 1-in-N.

---

## 1. Identity & Story

- **Real-world basis:** coastal and interior Alaska — Kenai/Cook-Inlet country compressed into one
  legible footprint: open tundra and braided rivers running down to a cold saltwater inlet, with a
  glacier and snow-capped peaks behind. A place a 13-year-old reads instantly as "the far north, the
  edge of the map" (the real-world-aspiration spine, 00 §0 / 05 §3 — the thing Gone Hunting's
  interchangeable fantasy zones can't buy). This is the pin the World Map dangled from minute one.
- **One-line feel:** *You made it to the frontier. It is vast, it is cold, it is beautiful — and for
  the first time, this place can kill you.* The expedition fantasy: the place the whole climb was
  pointed at.
- **The story this place tells:** The Bayou was home; Appalachia was where the world first pushed back.
  Alaska is where the world gets *big*. You arrive geared for it — that is the whole point of the
  expedition purchase — and the land rewards a well-equipped hunter with the best income in the game
  and the most spectacular trophies. But the scale is real: the interior is empty and silent in a way
  the lower tiers never were, the cold is a presence, and somewhere up at the salmon falls there is a
  grizzly you **cannot take alone** — the first animal in the game that genuinely needs a partner. The
  felt sentence is **"I'm prepared for this, and it's still the most dangerous place I've been."**
  Crucially, "dangerous" here means *legible* danger (telegraphed, gear-checked), never *cheap* danger
  (random one-shots) — see §10 #1.
- **Sensory signature (distinct from every lower tier):** where the Bayou was warm green-gold stillness
  and Appalachia was cool rust-and-slate ridgelines, Alaska is **white glare, cold blue light, and
  scale** — low hard sun off snow and ice, a palette of white, glacier-blue, pale gold tundra, and
  dark spruce. Sound signature: **wind across open tundra** (the loneliness tell), the distant boom and
  crack of the glacier calving, a raven's call, the rush of a salmon river, gulls and surf at the
  inlet, and — the threat tells — the bugle of a rutting bull moose and the low cough/huff of a
  grizzly at the falls. The light is *flat and bright*; the air reads *thin and silent*. The player
  should feel they reached the top of the ladder in the first ten seconds — the snow glare and the
  open emptiness do the work the way the Bayou's fog and Appalachia's altitude did for theirs.

---

## 2. Map Features & Layout

### 2.1 Terrain types
Open **tundra flats** and low rolling hills (the caribou/moose interior — the hunting ground); **boreal
spruce** edges and brushy river-bottoms (moose cover, the grizzly's approach to the falls); a braided
**salmon river** and its mouth (shore-accessible interior fishing); a cold **saltwater inlet / coast**
opening to the **open Gulf** (the Boat-gated coastal fishing sub-area); a **glacier and snow peaks**
backdrop (the Dall-sheep crags and the hero vista); and a **frozen interior lake** (the seasonal
ice-fishing micro-activity, §6/§9). One compact, legible footprint — interior to one side, coast to the
other, the vendor inlet between them.

### 2.2 Landmarks (recognizable, navigate-by-looking)
- **The Inlet (Harbor Camp)** — a weathered dock, fuel shack, and the **vendor outpost**: Outfitter +
  Tackle Shop + **Boat Dealer** (the Coastal Skiff is bought here) + Kennel & Stable (the Husky). The
  **arrival/respawn point** and the **coastal launch**. The social anchor of the Destination.
- **The Glacier** — a calving ice face visible from most of the map: the primary wayfinding beacon and
  the **thumbnail/hero shot** of the Destination (00 §6 — the storefront image budget). A player
  navigates by it the way the Bayou's player navigated by the Old Cypress.
- **The Tundra Flats** — the open interior: caribou herds and the bull moose (the hunting milestone
  ground). Boat-free.
- **Salmon Falls** — a step in the river where salmon stack on the run and **grizzlies come to fish**:
  the grizzly's range and the co-op apex content site. Telegraphed, approached on foot.
- **The Crags** — the lower glacier slopes: Dall sheep (a positioning/range hunting challenge).
- **The Open Gulf** — the far coastal water, reachable only by Coastal Skiff: deep halibut ground and
  the Mythic "white whale" site.
- **Frozen Lake** — an interior lake that freezes for the Winter Freeze event: ice-fishing (§9).

### 2.3 Functional zones
- **Hunting (Boat-free, interior):** Tundra Flats (caribou, bull moose); spruce/river-bottom edges
  (moose cover, grizzly approach); the Crags (Dall sheep); Salmon Falls (the grizzly co-op apex).
- **Fishing — interior rivers (shore-accessible, NO Boat):** the salmon river and its mouth — grayling,
  char/Dolly Varden, rainbow, and the seasonal **sockeye** run into the river mouths. This is the
  **pre-Boat fisher's T4 income** on arrival (and keeps the river-vs-coast split legible).
- **Fishing — coastal sub-area (Boat-gated — Coastal Skiff, EQUIPMENT_MASTER §4.5):** the inlet and
  open Gulf — rockfish/cod, lingcod, **the King Salmon milestone**, and the **Giant Halibut co-op
  apex**. Per fishing §7 the Boat opens the *cell*; it grants **no in-cell power** over a shore angler
  in any shared shore cell.
- **Vendor outpost:** the Inlet (Harbor Camp). It is **not** a second Lodge; the Lodge remains the
  single hub (04). The player travels here from the Lodge Travel Desk like any other Destination.

### 2.4 Traversal notes
**On foot, with a snow-movement penalty** as the legible flavor mechanic: deep snow/tundra slows the
player, which makes two convenience purchases *legible wants* (never gates):
- **Snowshoes** (region-specific, this doc's Template B, §6) — a cheap purchase that restores normal
  on-foot pace over snow. Convenience, never a gate.
- **The Snowmobile Mount** (regional reskin of the Mount — EQUIPMENT_MASTER §4.6; referenced, not
  re-statted) — cuts `TimeToFind`/repositioning across the open interior and chases fleeing caribou a
  player on foot loses. Mid-game convenience (~10,200), **never** a Gate input, **no** combat/catch
  power. The heavy T4 rifle/parka (6 kg / 8 kg, EQUIPMENT_MASTER) pair naturally with a Mount — the
  asserted heavy-gear→Mount convenience tie (EQUIPMENT_MASTER open flag E; not mechanized at MVL).
- **The Coastal Skiff Boat** (EQUIPMENT_MASTER §4.5) — required to reach the coastal fishing sub-area
  (§2.3). Not required to *enter* Alaska.

The snow penalty must read as *flavor friction with an obvious fix*, **not** an energy-timer-style
gate (00 §4) — flagged §10 #9. **It is movement-only: the snow/cold deal NO damage.** There is no
environmental / cold / survival-damage system at the MVL, by binding decision (§10 #12) — a
cold/hunger/stamina meter is out of scope and must not be added here as "immersion."

### 2.5 Performance notes (mobile-first, 00 §8)
Low-poly throughout; art budget to the thumbnail (the glacier hero shot), not geometry. **Snow glare /
low cloud doubles as the view-distance budget** — atmospheric *and* a cheap far-LOD cull, exactly as
the Bayou's fog and Appalachia's dawn fog do for theirs (the signature look is also the render
strategy). Snow and ice are flat planes with a cheap shader; the open Gulf is a flat water plane with
distance fog. **Caribou herds are instanced/flocked** low-cost agents (cap concurrent herd count per
§8 so AI/animation load stays phone-safe — the Alaska analog of Appalachia's coyote-pack crowd cap).
The grizzly is a single high-value agent (1 concurrent per Destination, §8). One Destination loaded at
a time (hub-and-spoke), so density budget is local. Frame rate beats fidelity (00 §8).

---

## 3. Wildlife Roster (Hunting)

> Template C per entry, ascending difficulty. **Stats populated to the LOCKED T4 bands**
> (SYS_combat §3 / EQUIPMENT_MASTER §4.1–§4.2): floor `≤2–3` shots at **T−1 = T3** gear; mid `~3–5`
> shots at **T4**, tense-but-safe in T4 armor; the **apex is NOT soloable at T4** (no T5 gear exists)
> and is **co-op-only** (Resolved Decision A). **ShotsToKill ≈ ceil(Health / WeaponDamage_mid)** at the
> modeled body-reference (`Z·RangeFalloff ≈ 1.0`), with skilled vital hits as upside (combat §3, the
> same convention LOC_01/LOC_02 used). T4 weapon (Heavy Expedition Rifle) mid Damage **49**; T−1 (T3
> Scoped Rifle) mid Damage **35**. Armor (Expedition Parka) DR vs own tier **0.50**, vs a +1 ("behaves-
> as-T5") threat **0.38** (EQUIPMENT_MASTER §4.2). Player base HP **100**. Cash is **computed** from
> `Income(4)/ExpectedTargetsPerHour(4,hunting) × RarityMultiplier = 4,913/28 ≈ 175 baseline (Common);
> Uncommon ×1.6 ≈ 281` — *not* authored here (SYS_economy §5).
>
> **The two-tier-jump conditions are honored in the numbers below (binding, SYS_combat MVL check):**
> floor/mid clear at *normal* T4 shot-counts (no inflated bands), and **every lethal threat
> (moose, grizzly) is telegraphed** — the only two creatures that can damage the player both have a
> visible/audible wind-up before a heavy hit. Floor/mid flee-creatures deal ~0 damage, so the only
> survival threats are the two telegraphed aggressors. **No random one-shots anywhere.**
>
> **No wolf pack here.** The pack co-op-tutorial was delivered in Appalachia (coyotes); the **wolf-pack
> template is reserved to the Rockies (LOC_03)** per LOC_02 §10. Alaska's co-op lesson is the
> single-apex grizzly, not a pack (§10 #8).

### Ambiance-only (grant nothing — enforced server-side, combat §8)
- **Willow Ptarmigan, Arctic Fox, Bald Eagle, Sea Otter (at the inlet), Magpie/Raven.** Atmosphere
  only; killing them pays no Cash, no Rank XP, no drops, no milestone credit, and they do not occupy
  the reward-bearing spawn ceiling. The "identify worthwhile targets" signal (01) as indifference, not
  a fine. (The Sea Otter and Bald Eagle also carry a soft conservation read — charismatic animals you
  watch, not shoot; 01 appropriateness guardrail.)

### Arctic Hare  [Tier 4]  — FLOOR (re-skin: "bigger & meaner", progression §6)
- **Rarity:** Common
- **Ambiance-only?:** no
- **Behavior:** flees
- **Pack size:** n/a (singles / loose groups)
- **Health:** 45
- **Damage to player:** 0 (non-threat; escape-bounded)
- **Speed:** 80 (fast, jinking — a Mount/snowshoes help close, never required)
- **Min weapon tier to kill:** 3 (T−1)  ·  **Min armor tier to survive:** n/a (non-lethal)
- **Co-op recommended?:** solo (trivially)
- **Drops / reward:** ≈175 Cash (Common; *computed*, SYS_economy §5); white winter pelt (flavor/quest)
- **Re-skin of:** the Bayou Swamp Rabbit (the literal "rabbits in Alaska, but bigger" example, 01) —
  shares the `flees` template, re-tagged to T4, **rewarded at the Alaska floor wage** (progression §6)
- **Spawn:** tundra and snowfields. *(Worked: `ceil(45/35)=2` shots at T3 (T−1) → floor takeable at
  T−1 ✓; `ceil(45/49)=1` at T4 — a clean one-shot, the satisfying floor re-skin.)*

### Sitka Black-tailed Deer  [Tier 4]  — FLOOR (the worked floor reference)
- **Rarity:** Common
- **Ambiance-only?:** no
- **Behavior:** flees
- **Pack size:** n/a (small groups)
- **Health:** 70
- **Damage to player:** 0 (escape-bounded)
- **Speed:** 76 (outruns a player on foot in deep snow — the legible Snowmobile want)
- **Min weapon tier to kill:** 3 (T−1)  ·  **Min armor tier to survive:** n/a
- **Co-op recommended?:** solo
- **Drops / reward:** ≈175 Cash (Common); venison/hide (butcher-quest sink fuel, 01)
- **Re-skin of:** behaviorally the Appalachia whitetail (`flees`), re-tagged T4
- **Spawn:** spruce edges and lower slopes. *(Worked: `ceil(70/35)=2` at T3, `ceil(70/49)=2` at T4 —
  matches EQUIPMENT_MASTER's "clears Alaska floor, 2 shots at T3-floor creatures" note §4.1. ✓)*

### Caribou  [Tier 4]  — MID / herd (milestone reachability FALLBACK, RD-A — not co-equal to the moose)
- **Rarity:** Uncommon
- **Ambiance-only?:** no
- **Behavior:** flees (herd; spooks and runs as a group — a chase/positioning challenge, not a survival
  one)
- **Pack size:** herd 6–12 (instanced; **cap concurrent herds** per §8 for mobile load)
- **Health:** 100
- **Damage to player:** 0 (non-aggressive; the difficulty is the *chase*, not the fight)
- **Speed:** 82 (a true Mount-want — a herd outpaces a player on foot; the Snowmobile earns its price
  here)
- **Min weapon tier to kill:** 4  ·  **Min armor tier to survive:** n/a (non-lethal)
- **Co-op recommended?:** solo
- **Drops / reward:** ≈281 Cash (Uncommon; *computed*); caribou meat/hide
- **Re-skin of:** n/a (region-iconic)
- **Spawn:** the Tundra Flats, herding. *(Worked: `ceil(100/49)=3` shots at T4 → mid band ✓.
  Escape-bounded — the `KillWindow = TimeToFlee` is set by the herd's spook distance; range + a Mount
  beat it.)* **Milestone reachability FALLBACK**, not the design-default: a solo player who cannot get a
  bull moose to commit can still conquer Alaska's hunting milestone via the caribou (a pure chase, zero
  damage). The gate accepts it (RD-A names "caribou or moose," so conquest is never blocked), but the
  **canonical hunting conquest is the Bull Moose** — which carries the tier's one required solo
  damage-exposure beat — and this danger-free route is the **safety-valve, not a co-equal path** (§10 #1).

### Dall Sheep  [Tier 4]  — MID (positioning / range challenge)
- **Rarity:** Uncommon
- **Ambiance-only?:** no
- **Behavior:** flees (high crags; bolts uphill — rewards the climb and the long shot)
- **Pack size:** small bands (3–6)
- **Health:** 85
- **Damage to player:** 0 (escape-bounded)
- **Speed:** 70 on the flat, but the *terrain* (the Crags) is the real obstacle — a stalking/range test
- **Min weapon tier to kill:** 4  ·  **Min armor tier to survive:** n/a
- **Co-op recommended?:** solo
- **Drops / reward:** ≈281 Cash (Uncommon); the trophy ram (a clean horn-curl flex, identity)
- **Re-skin of:** n/a
- **Spawn:** the Crags (lower glacier slopes). *(Worked: `ceil(85/49)=2` at T4 with vitals → the
  difficulty is the *approach* — the Heavy Rifle's Range 72 matters here, the first place range is the
  binding skill rather than damage.)*

### Bull Moose  [Tier 4]  — THE HUNTING CONQUEST MILESTONE (T4-soloable, RD-A)
> The designated hunting milestone (§7): a **T4-soloable signature creature**, the first "stand and
> fight a big dangerous animal and *win solo*" in Alaska. Telegraphed charge (the rut bugle + a visible
> head-down wind-up before it commits) — legibility-of-death honored. **Not** the apex; the apex is the
> grizzly, which has no solo route (RD-A). The moose is the proof that a pure-solo hunter can always
> conquer Alaska.
- **Rarity:** Uncommon (the milestone is a routine-class fight, not a scarce trophy — the *conquest* is
  the reward, not a rare drop; consistent with the Appalachia boar milestone)
- **Ambiance-only?:** no
- **Behavior:** aggressive (charges when approached/provoked, especially in rut; otherwise can be
  stalked — telegraphed head-down charge wind-up before any heavy hit)
- **Pack size:** n/a (singles; bulls are solitary)
- **Health:** 100
- **Damage to player:** 45  ·  **Attack interval:** 3.0 s
- **Speed:** 58 (charges hard but can be out-positioned, not out-run — the boar's escalated cousin)
- **Min weapon tier to kill:** 4  ·  **Min armor tier to survive:** 4
- **Co-op recommended?:** **solo-with-T4-gear (this is the point)** — co-op trivializes it but is never
  required
- **Drops / reward:** ≈281 Cash (Uncommon); moose meat (butcher sink); the bull's rack (trophy/identity)
- **Re-skin of:** behaviorally the Appalachia boar (`aggressive`/charge), escalated to T4
- **Spawn:** spruce edges and river-bottoms of the Tundra Flats; low frequency, most active dawn/dusk
  and in the autumn rut. *(Worked: `ceil(100/49)=3` shots at T4 → mid band; survival: Parka DR 0.50 →
  `45×0.50 = 22.5`/hit → `100/22.5 ≈ 4.4` → ~5 hits to down → survival window ≈ `(5−1)×3.0 = 12 s` ≫
  kill time `3 shots × 1.25 s CycleTime = 3.75 s` (worst case the moose lands hits at t=0 and t=3.0 s →
  2 hits × 22.5 = 45 dmg < 100; if its first hit lands after one interval, only 1 hit ≈ 22.5 — safe
  either way) → **tense but SAFE in T4 armor, soloable.** ✓ Matches EQUIPMENT_MASTER's "caribou/moose
  milestone, 3 shots, safe in T4 armor, DR 0.50, 22.5 dmg/hit, 5 hits to down" §4.1/§4.2.)* **This is
  the designated hunting milestone** (§7), parity-targeted against the king-salmon fishing milestone
  (§10 #7).

### Grizzly Bear  [Tier 4]  — APEX / CO-OP-ONLY (NO solo route at MVL — RD-A)
> The region-iconic apex, **behaves-as-T5** (combat §3/§4 — the apex "+1-tier threat" offset). It is the
> first animal in the game with **no solo route**: a player can deal enough damage (3 shots) but
> **dies first** through T4 armor, and **no T5 weapon/armor exists at MVL** to fix it. It is therefore
> a **co-op apex / content moment**, never the conquest milestone (RD-A). A dangerous predator that
> **hunts the player** at the falls → squarely the intended combat-threat category (01 appropriateness
> guardrail), framed as self-defense, not slaughter of charismatic megafauna. **Telegraphed:** the
> charge and the swipe both have a clear rear-up/audio wind-up the player (or party) can read and dodge
> — the higher absolute damage is legible, not a random instakill (the two-tier-jump condition).
- **Rarity:** Uncommon (a **routine apex**, repeatable; **no tradeable-artifact mint** — only Rare+
  mint, SYS_data_integrity RD1 / SYS_lodge_trophy; its scarce single-mint variant is the **Glacier
  Grizzly**, Legendary, §5). The reward is the *fight and the flex*, not the faucet — consistent with
  apex-as-progression-not-income (the Appalachia mountain-lion pattern).
- **Ambiance-only?:** no
- **Behavior:** aggressive (charges, swipes; telegraphed wind-up on every heavy attack; holds aggro on
  one player and switches on threat events in co-op, combat §6)
- **Pack size:** n/a (singles; **1 concurrent per Destination**, §8)
- **Health:** 100
- **Damage to player:** 85  ·  **Attack interval:** 2.5 s
- **Speed:** 80 (closes hard — the threat that makes the falls feel dangerous)
- **Min weapon tier to kill (solo):** **5 (does not exist at MVL)**  ·  **Min armor tier to survive
  (solo):** **5 (does not exist at MVL)** → **co-op-only at MVL**
- **Co-op recommended?:** **party (the entire point — no solo route until T5)**
- **Drops / reward:** ≈281 Cash salvage (Uncommon, a normal kill payout — NOT an artifact mint);
  cosmetic pelt-variant unlocks (identity, not power)
- **Re-skin of:** n/a (its Legendary blonde/glacier variant, the Glacier Grizzly §5, re-skins *from*
  it)
- **Spawn:** **Salmon Falls** (and drawn there in greater numbers during the Salmon Run, §9), low
  routine frequency. *(Worked, solo: `ceil(100/49)=3` shots at T4 mid; survival vs behaves-as-T5
  threat → Parka DR `0.50 + 0.12·(4−5) = 0.38` → `85×0.62 = 52.7`/hit → `2 hits = 105 > 100` → **downed
  in ~2 hits**; survival window ≈ `(2−1)×2.5 = 2.5 s` < kill time 3.75 s → **NOT soloable at T4**, and
  no T+1 gear exists to close it → **co-op-only.** Co-op (party of 4): `EffectiveHealth(4) = 100×2.5 =
  250`, but total DPS is ~4× and the bear holds aggro on one player at a time, switching on threat
  events (combat §6) → time-to-kill drops to ~`250/(4×perPlayerDPS)` ≈ 0.63× the solo-length fight, and
  each player eats only the share of hits landed while *they* hold aggro (~1/4) → per-player damage
  exposure falls to roughly a *sixth* of the solo case, well under the lethal threshold →
  **trivial with a party** (combat §6). ✓ Matches EQUIPMENT_MASTER §4.1's "does NOT solo the grizzly;
  behaves-as-T5; downs you in ~2 hits through T4 armor; co-op-only.")* The fishing mirror is the giant
  halibut (§4). **At soft-launch low CCU the grizzly may simply go unkilled by many solo players — that
  is acceptable; it is an aspirational co-op trophy, and progression is never blocked because the
  *milestone* is the soloable moose** (combat open Q3; §10 #8).

---

## 4. Fish Roster (Fishing)

> Template D per entry, ascending difficulty. **Stats populated to the LOCKED T4 catch bands**
> (SYS_fishing §3 / EQUIPMENT_MASTER §4.3–§4.4): floor landable at **T−1 = T3** rod+reel; mid landable
> at **T4**; the **milestone (king salmon) is T4-soloable**; the **apex (giant halibut) throws at T4
> and is CO-OP-ONLY** (no T5 reel exists — Decision 7). The catch is landable iff **`FightTime ≤
> LandWindow`**, with **reel = weapon-analog** (DrainMax → shortens FightTime) and **rod = armor-analog**
> (Pressure → lengthens LandWindow; a snap is the window closing). T4 rod (Coastal Surf Rod) Pressure
> mid **96**; T4 reel (Coastal Lever-Drag) DrainMax mid **25** (EQUIPMENT_MASTER §4.3/§4.4). **This doc
> authors each fish's `FightDifficulty` and weights; it CITES the worked `FightTime`/`LandWindow` from
> EQUIPMENT_MASTER** (it does not re-derive the `k_s`/`W_ref`/`E_expected`/`w` constants — same
> discipline as LOC_02). Cash **computed** from `Income(4)/ExpectedTargetsPerHour(4,fishing) ×
> RarityMultiplier = 4,913/22 ≈ 223 baseline (Common); Uncommon ×1.6 ≈ 357` (SYS_economy §5 / fishing
> §5).
>
> **Water split (the Boat gate, §7):** **interior river = shore-accessible, NO Boat** (grayling, char,
> rainbow, the seasonal sockeye — the pre-Boat fisher's T4 income on arrival); **coastal = Boat-gated**
> (Coastal Skiff — rockfish/cod, lingcod, **the King Salmon milestone**, the **Giant Halibut apex**).
> The rod-bound/reel-bound texture axis (fishing §3) is used deliberately: **the king salmon is
> rod-bound** (hard runs, modest stamina → wants rod headroom) and **the halibut is reel-bound** (modest
> runs, enormous stamina → wants reel drain) — exactly the salmon-vs-halibut/sturgeon example fishing
> §3 names.

### Arctic Grayling  [Tier 4]  — FLOOR (interior river, NO Boat)
- **Rarity:** Common
- **Typical weight range:** 0.3–1.0 kg  ·  **Record/trophy weight:** ~2 kg
- **Fight difficulty:** 42
- **Min rod / reel tier to catch:** 3 (T−1) / 3 (T−1) — the floor catch, landable on the gear that got
  you in
- **Bait/lure required:** dry fly / small spinner (basic, auto-restocked — never a tier input,
  fishing §4)
- **Water type:** river (interior — **shore-accessible, no Boat**)
- **Drops / reward:** ≈223 Cash (Common; *computed*)
- **Spawn / bite condition:** clear flowing water, all day. The pre-Boat fisher's first Alaska income.

### Dolly Varden / Rainbow Trout  [Tier 4]  — FLOOR/MID (interior river, NO Boat)
- **Rarity:** Common
- **Typical weight range:** 0.8–3 kg  ·  **Record/trophy weight:** ~6 kg
- **Fight difficulty:** 52
- **Min rod / reel tier to catch:** 3 → comfortably 4
- **Bait/lure required:** egg pattern / spoon (basic)
- **Water type:** river (interior — shore-accessible)
- **Drops / reward:** ≈223 Cash (Common; *computed*)
- **Spawn / bite condition:** river runs and pools, better at low light. The river's "warm-up" before
  the sockeye run and the saved-for-Boat coastal step.

### Sockeye Salmon  [Tier 4]  — MID (interior river mouths; the RUN species)
- **Rarity:** Uncommon
- **Typical weight range:** 2–4 kg  ·  **Record/trophy weight:** ~6 kg
- **Fight difficulty:** 58 (rod-leaning — salmon run hard)
- **Min rod / reel tier to catch:** 4
- **Bait/lure required:** flash fly / spoon (basic)
- **Water type:** river mouth (interior — **shore-accessible**, so even a pre-Boat fisher gets a taste
  of the run; the *king* salmon milestone stays coastal/Boat-gated, §7)
- **Drops / reward:** ≈357 Cash (Uncommon; *computed*)
- **Spawn / bite condition:** the **Salmon Run** window concentrates them in the river mouths (the
  canonical seasonal event, §9). The shore-accessible face of the run.

### Pacific Rockfish / Cod  [Tier 4]  — COASTAL FLOOR (Boat-gated)
- **Rarity:** Common
- **Typical weight range:** 1–5 kg  ·  **Record/trophy weight:** ~12 kg
- **Fight difficulty:** 48
- **Min rod / reel tier to catch:** 4 (the coastal floor; needs the Coastal Skiff to *reach*, not to
  *fight* — Boat is access, not power, fishing §7)
- **Bait/lure required:** jig (basic)
- **Water type:** **coastal (Boat-gated — Coastal Skiff)**
- **Drops / reward:** ≈223 Cash (Common; *computed*)
- **Spawn / bite condition:** inlet structure, all day. The first thing the Boat opens.

### Lingcod  [Tier 4]  — COASTAL MID (Boat-gated)
- **Rarity:** Uncommon
- **Typical weight range:** 4–12 kg  ·  **Record/trophy weight:** ~20 kg
- **Fight difficulty:** 64 (a dogged bottom fight — reel-leaning, the halibut's "little cousin")
- **Min rod / reel tier to catch:** 4
- **Bait/lure required:** heavy jig (basic)
- **Water type:** **coastal (Boat-gated)**
- **Drops / reward:** ≈357 Cash (Uncommon; *computed*)
- **Spawn / bite condition:** rocky coastal bottom. The difficulty rung that says "the big reel-bound
  fish are coming."

### King (Chinook) Salmon — "the Tyee"  [Tier 4]  — THE FISHING CONQUEST MILESTONE (T4-soloable, Decision 7)
> The designated fishing milestone (§7): a **T4-soloable signature catch**, the fishing mirror of the
> bull moose. **Rod-bound** — long, hard runs (high `PeakRunForce`) but modest stamina, so the **T4 rod's
> headroom is what lands it** (and the T4 reel out-drains it comfortably). It lives in the **coastal
> sub-area, so a pure fisher needs the Coastal Skiff to conquer Alaska via fishing** (the legible "you
> need a boat for the coast" expedition purchase, 01; §7, §10 #6). **Not** the apex; the apex is the
> co-op-only giant halibut (Decision 7).
- **Rarity:** Uncommon (the milestone is a routine-class fight; the *conquest* is the reward)
- **Typical weight range:** 8–18 kg  ·  **Record/trophy weight:** ~30 kg (the "big one" feel is its
  size + the run, fitting a milestone)
- **Fight difficulty:** 68 (the firmest *soloable* fight at T4 — sits below the halibut apex)
- **Min rod / reel tier to catch:** 4 / 4 (T4-soloable — no co-op or T+1 needed)
- **Bait/lure required:** herring / large spoon (basic; never premium-gated — fishing §4)
- **Water type:** **coastal / estuary (Boat-gated — Coastal Skiff)**
- **Drops / reward:** ≈357 Cash (Uncommon; *computed*). **This is the designated fishing milestone**
  (§7), parity-targeted against the bull-moose hunting milestone (§10 #7).
- **Spawn / bite condition:** coastal staging water and estuary, intensified during the **Salmon Run**
  (§9). *(Worked, CITED from EQUIPMENT_MASTER §4.3/§4.4: on T4 rod+reel `FightTime 9.0 ≤ LandWindow 48`
  → margin ~39 s → **comfortably landable solo on T4 gear.** The huge LandWindow is the rod-bound
  fish meeting the T4 rod's headroom; the FightTime 9.0 is the T4 reel out-draining its modest stamina.
  ✓ T4-soloable.)*

### Giant Halibut — "the Barn Door"  [Tier 4]  — APEX / CO-OP-ONLY (NO solo route at MVL — Decision 7)
> The coastal apex and the fishing mirror of the grizzly: **reel-bound** — modest runs (so the rod is
> *not* the binding slot; the LandWindow stays positive) but **enormous stamina** from sheer weight, so
> the **T4 reel cannot out-drain it inside the window → it throws**, and **no T5 reel exists at MVL** to
> fix it → **co-op-only** (a second angler adds `NetDrain`/extends `LandWindow`, fishing §9). Never the
> milestone (Decision 7). The repeatable apex; its scarce single-mint version is the Mythic **"Ghost of
> the Gulf"** (§5). Pays Uncommon salvage directly (no artifact mint); the flex is the fight.
- **Rarity:** Uncommon (~357 Cash salvage; the reward is the battle, not the faucet)
- **Typical weight range:** 70–180 kg  ·  **Record/trophy weight:** ~230 kg (the "barn door" — the
  size *is* the legend)
- **Fight difficulty:** 98 (reel-bound: modest `PeakRunForce` → positive LandWindow; enormous stamina)
- **Min rod / reel tier to catch (solo):** **5 reel (does not exist at MVL)** → **co-op-only at T4**
- **Bait/lure required:** large cut bait (basic)
- **Water type:** **coastal / open Gulf (Boat-gated — Coastal Skiff)**
- **Drops / reward:** ≈357 Cash (Uncommon, normal salvage payout)
- **Spawn / bite condition:** deep Gulf bottom, low frequency. *(Worked, CITED from EQUIPMENT_MASTER
  §4.4: stamina **441**; on T4 reel `FightTime 45.6 > LandWindow 37.2` → **throw/timeout** → NOT
  landable solo at T4; no T5 reel → **co-op-only** until T5 ships, exactly as the grizzly is
  survival-window-gated on the hunting side. ✓)* **At soft-launch low CCU it may go uncaught by many
  solo fishers — acceptable (aspirational co-op trophy); progression is never blocked because the
  *milestone* is the soloable king salmon** (fishing co-op flag; §10 #8).

---

## 5. Rare & Mythical Spawns

> Template E per entry. **All are independent, condition-gated spawns — never per-kill / per-cast rolls**
> (combat RD-E / fishing Decision 3 / economy RD5): separately-spawned entities present under their
> condition, layered on the routine population. **Each mints exactly one unique artifact and writes NO
> Cash at kill/catch** (SYS_data_integrity — Cash is realized only on the SALVAGED transition, floored
> low; the real value is **P2P trade + the Trophy Hall**, economy §5). Default disposition on mint is
> **HELD** with a one-tap "Mount it in your Trophy Hall?" prompt; a **displayed** trophy is not tradeable
> (SYS_lodge_trophy RD1). **Re-release policy: NEVER** (00 §5, the scarcity moat). The **Husky** widens
> rare-spawn detection radius — it helps you *find*, never *win* (EQUIPMENT_MASTER §4.7).
>
> **Effective rarity is two knobs (inherited LOC_01/LOC_02 §5):** *effective rarity = per-window 1-in-N
> roll × condition frequency × player-presence-with-prereqs.* The per-window N is kept **modest**; the
> condition (season/weather/location + sometimes the Boat) carries most of the scarcity.
> **Per-window N is set by the rare's ROLE, not its tier; cross-tier escalation is enforced on the
> EFFECTIVE rate, on every band (binding decision — flagged §10 #5).** Read literally, the per-window
> rolls here are *lower* (more common) than the Bayou's at the Rare/Legendary bands — Cross Fox 1-in-300
> vs the Bayou's accessible Pale Drake 1-in-900; Spirit Moose/Tyee King 1-in-1,500 and Glacier Grizzly
> 1-in-2,500 vs the Bayou's upper rares at 1-in-2,500/3,500. **That is intentional, not a tier-escalation
> bug a build should "fix" by inflating N.** Each tier needs its own accessible onboarding mint (the
> Cross Fox is *this* tier's "first trade chip," a role that wants a low N), and what must rise across
> tiers is the **effective** rate (per-window N × condition frequency × presence-with-prereqs), which
> Alaska carries through *tighter conditions* (Boat-gating, seasonal-run and storm-Gulf windows, co-op
> walls) rather than a bigger N. **Only the Mythic escalates on N as well** (Ghost of the Gulf 1-in-9,000
> > Bayou Leviathan 1-in-7,500) *and* on condition — unambiguously the rarest thing in the game so far on
> both knobs (LOC_01: "later-tier Mythics are far rarer"). The binding invariant for the tuning pass is
> therefore **monotone effective-rate escalation per band across tiers**, NOT monotone per-window N —
> validate the *effective* rates, not the raw Ns. **LiveOps owns condition frequency on the calendar
> (§9); this doc owns the per-window roll.** All values illustrative; the *effective* rate is the tuning
> target (§10 #5).
>
> **Finds vs. walls (the binding nuance for a co-op-apex tier).** Most rares here are *finds* (share
> their base creature's profile — the moment is the discovery + the clean kill/catch). **But because
> Alaska's apexes are already co-op-only, any rare re-skinned from the grizzly or halibut inherits the
> "no solo route" property** — it is a deliberate "rare that is also a wall," the Alaska parallel of
> Appalachia's Black Catamount. Two such are designated below (the Glacier Grizzly and the Mythic Ghost
> of the Gulf) and **flagged** (§10 #4); the soloable rares (Cross Fox, Spirit Moose, Tyee King) are
> finds a solo player can actually take.

### Cross Fox (color-phase Red Fox)  [Rare] — Alaska  *(the accessible first-mint)*
- **Type:** hunting trophy  ·  **Base creature/fish:** an Arctic/Red Fox (a *find* — low-threat, takeable
  on the gear that found it; the entry-level mint that onboards the player into the Trading Post /
  Trophy Hall, the Piebald-Whitetail role at this tier)
- **Spawn condition:** tundra edges, winter coat / clear cold days (a *frequent* condition → the
  accessible rare)
- **Spawn rate:** **1-in-300** per qualifying encounter in-window (modest per-window N; condition does
  the rest)
- **Reward:** **no Cash at kill** — mints one **Cross Fox** pelt artifact; **if salvaged**, floored low
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER
- **Intended content moment:** the silver-black fox against the snow — a clean early "that one's
  *different*" screenshot; the entry-level trade chip and fur-identity flex.

### Spirit Moose (Piebald/Albino Bull Moose)  [Legendary] — Alaska
- **Type:** hunting trophy  ·  **Base creature/fish:** Bull Moose (**shares the milestone profile — a
  find a solo player CAN take**, because the base moose is T4-soloable; the challenge is *finding* it,
  not a wall)
- **Spawn condition:** dawn/dusk in the Tundra Flats spruce edges, clear weather, **autumn rut window**
  (time + season — an *occasional* condition; the "legendary buck at dawn" hook, 01)
- **Spawn rate:** **1-in-1,500** per qualifying rut-window encounter → with the rut seasonal and the
  location-gating, a genuine-but-reachable Legendary (effective rate below the Bayou's, above the
  co-op-walled rares)
- **Reward:** **no Cash at kill** — mints one **Spirit Moose** trophy (a high-status Alaska flex); low
  salvage floor
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER
- **Intended content moment:** the ghost-white bull stepping out of dark spruce at first light — the
  archetypal Alaska legendary reveal, and the iconic "albino Alaskan moose" 01 names by name.

### Glacier Grizzly (blonde/"blue" color-phase)  [Legendary] — Alaska  *(a rare that is ALSO a wall — flagged)*
- **Type:** hunting trophy  ·  **Base creature/fish:** Grizzly (**shares the co-op-only apex profile** —
  the deliberate Alaska "rare that is also a wall," parallel to the Black Catamount; a solo player can
  *find* it but **cannot take it solo at MVL**, exactly as the routine grizzly can't be — §10 #4)
- **Spawn condition:** Salmon Falls during the **Salmon Run**, low light (location + seasonal-event — an
  *occasional* condition concentrated in the run window, §9)
- **Spawn rate:** **1-in-2,500** per qualifying run-window check → effective rate is genuine-Legendary,
  and because it is co-op-content by the time a player is farming the falls in a party, the
  "find-it-but-need-a-partner" case reads as aspirational, not punitive (the Catamount mitigation)
- **Reward:** **no Cash at kill** — mints one **Glacier Grizzly** hide artifact; low salvage floor
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER
- **Intended content moment:** the pale-gold giant rearing at the falls in the run — the marquee co-op
  trophy-kill clip (00 §6); the screenshot that *sells* the co-op apex as live content (the spotlight
  event, §9).

### Tyee King (record King Salmon)  [Legendary] — Alaska
- **Type:** record fish  ·  **Base creature/fish:** King Salmon (**shares the T4-soloable milestone
  profile — a find a solo fisher CAN land**, given the Boat; the challenge is the run + the roll)
- **Spawn condition:** coastal/estuary during the **Salmon Run** (Boat-gated water + seasonal event +
  the basic herring bait named as a condition component — gates the *attempt*, not the *win*, fishing
  §4)
- **Spawn rate:** **1-in-1,500** per qualifying run-window bite → location/Boat + season gate it to a
  reachable Legendary
- **Reward:** **no Cash at catch** — mints one **Tyee King** record artifact; low salvage floor
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER
- **Intended content moment:** the chrome-bright giant king breaching in the run — the fishing-loop
  legendary reveal and a top-of-server record-board entry.

### Ghost of the Gulf (colossal Halibut)  [Mythic] — Alaska  *(the region's "white whale" — one Mythic per Destination)*
> Alaska's single Mythic and its aspirational fishing content moment — the **open-ocean "white whale"**
> the brief names. **Co-op-only** (it shares and exceeds the giant-halibut reel-bound apex profile; no
> T5 reel → no solo route at MVL — a Mythic that is also a wall, §10 #4). Distinct from the *Tier-7
> Deep-Sea* "white whale" (marlin/open-ocean endgame, 01) — naming overlap flagged §10 #5.
- **Type:** record fish (the region's white whale)
- **Base creature/fish:** an ancient, screen-filling Halibut (reel-bound apex stats, beyond the routine
  giant — the whole difficulty is reaching the condition, winning the roll, and **landing it with a
  party**)
- **Spawn condition:** **deep open Gulf (Boat-gated) + a storm/heavy-sea window + the deepest bottom +
  large cut bait** (weather + location + a basic required-item — the "storms make rare fish bite" return
  hook, 01; a *rare* compound condition that already carries most of the scarcity)
- **Spawn rate:** **1-in-9,000** per qualifying storm-Gulf check — the per-window roll is modest because
  the compound condition (storm-seas are infrequent, Gulf is Boat-gated, party needed) does the work;
  the **effective rate is the rarest in Alaska and rarer than the Bayou Leviathan** (tier-escalating
  Mythic scarcity), yet a real weeks-long dream for a dedicated co-op crew
- **Reward:** **no Cash at catch** — mints one **Ghost of the Gulf** artifact (the centerpiece of an
  Alaska Trophy Hall); low salvage floor — value is **P2P trade + display** (the moat)
- **Tradeable?:** yes  ·  **Displayable in lodge?:** yes  ·  **Re-release policy:** NEVER (permanent
  scarcity)
- **Intended content moment:** the colossal halibut surfacing in a storm-tossed Gulf as a party hauls
  together — the clip every Alaska crew wants, and the reason they return on storm-seas with a party
  (the timed-spawn + co-op return hook, 01; the co-op-apex spotlight, §9).

---

## 6. Region-Specific Equipment

> Template B per item. **The T4 line, the Coastal Skiff, the Snowmobile Mount, and the Husky are
> authored in EQUIPMENT_MASTER and REFERENCED here, not re-statted** (EQUIPMENT_MASTER owns balance —
> §4.1–§4.7). The genuinely *new* region items this doc authors are the **Snowshoes** and the
> **Ice-Fishing Kit** (Template B blocks below). Cosmetics are categories, not statted items
> (EQUIPMENT_MASTER §4.9 — Alaska camo, cold-weather outfits, a "log cabin / trophy lodge" theme).

### Snowshoes  *(region-specific, authored here)*
- **Category:** tool
- **Tier:** first available T4 (Alaska)
- **Available at:** Outfitter (Harbor Camp)
- **Cost:** ~600 Cash (trivial — a friction-remover, not a progression sink; well below first-session
  Alaska earnings)
- **Primary stat(s):** removes the deep-snow on-foot movement penalty (restores normal walk/run pace
  over snow/tundra). **No** combat/catch/survivability stat.
- **Weight:** 1 kg
- **Strengths:** makes the interior traversable on foot without the Snowmobile; the cheap legible
  counter to the snow-slow terrain (§2.4)
- **Weaknesses / limits:** does not chase fleeing game faster than a player's base pace (that is the
  Snowmobile's convenience) — it *restores* normal pace, it does not exceed it; **never a Gate**
- **Gates unlocked:** none — ever
- **Monetization role:** convenience (trivial Cash; not a real-money sink) — the friction it removes is
  flavor, never a timer (00 §4)
- **Notes:** the legible "of course you need snowshoes up here" immersion item (01) at a price that
  never reads as a wall.

### Ice-Fishing Kit (auger + tip-up)  *(region-specific, authored here)*
- **Category:** tackle
- **Tier:** first available T4 (Alaska); relevant during the **Winter Freeze** event (§9)
- **Available at:** Tackle Shop (Harbor Camp)
- **Cost:** ~800 Cash (trivial; a seasonal-activity enabler, not a tier input)
- **Primary stat(s):** **required-item yes/no gate** to fish the **Frozen Lake** during the freeze (cut
  a hole + set a tip-up) — the same required-basic-tackle pattern as cut bait / fly (fishing §4).
  **Never a tier input; never premium-gated.**
- **Weight:** 2 kg
- **Strengths:** opens a self-contained winter sub-activity (a calmer, seated counter-tempo to the
  coastal fight) and a LiveOps surface (§9); a flavor/identity beat
- **Weaknesses / limits:** a player can **never** be blocked from the *core* loop by lacking it — it
  gates only the seasonal Frozen-Lake micro-activity, not Alaska's standing rivers/coast (the
  not-a-timer rule, economy §1). It does **not** reach the §5 moat-rares.
- **Gates unlocked:** the Frozen-Lake winter water only (a seasonal sub-area, not a Destination or a
  tier)
- **Monetization role:** convenience + identity (the kit and winter-themed cosmetics)
- **Notes:** ties the Winter Freeze event to a real verb rather than a passive boost; keep the
  frozen-lake catches inside the bite-density cap (§8) so it is not an over-geared-farming hole.

### Husky (Alaska Tracking Dog)  — *reference; canonical block: EQUIPMENT_MASTER §4.7*
- **Category:** dog  ·  **Tier:** available T2–T3 (a player likely owns one before Alaska)
- **Available at:** Kennel & Stable (Harbor Camp surfaces the Alaska breed here)
- **Cost:** basic breed ~8,000 Cash; **rare breeds are P2P trade items** (value flows to the Trading
  Post)
- **Primary stat(s):** widens rare-spawn **detection radius** (helps find the §5 rares — the run
  grizzly, the Spirit Moose); tracks wounded/fleeing game (a `flees`-archetype aid for the
  caribou/sheep chase). **No** damage, survivability, or catch power (01 — "does not break combat
  balance").
- **Weaknesses / limits:** **never in a Gate**; cannot make an un-takeable target takeable (a Husky
  helps you *find* the Glacier Grizzly, never *win* it — the co-op wall stands)
- **Gates unlocked:** none — ever
- **Monetization role:** convenience + identity (the husky is the Alaska-flavor breed; rare
  husky/malamute coats are tradeable)
- **Notes:** referenced, not re-authored — EQUIPMENT_MASTER §4.7 owns the stats/curve.

*(The T4 gear — **Heavy Expedition Rifle**, **Expedition Parka**, **Coastal Surf Rod**, **Coastal
Lever-Drag** — the **Coastal Skiff** Boat (§4.5, ~18,000), and the **Snowmobile** Mount (§4.6, regional
reskin, ~10,200) are all authored in EQUIPMENT_MASTER and referenced throughout this doc; they are
**not** re-statted here. No new Alaska-only weapon, armor, rod, or reel is introduced — the T4 line is
the master's.)*

---

## 7. Gating (entry & exit)

> Inherited from SYS_progression §gate-table (`required_tier = EHT ≥ N OR EFT ≥ N`; milestone =
> conquer-in-place, OR-gated across loops; carry-proof on gear; carry-friendly-but-non-skippable on the
> milestone). Alaska's gate-table row: `required_tier = expedition-grade (EHT/EFT ≥ 4)`, `access item =
> Boat → gates Alaska's coastal fishing, NOT entry`, `milestone_prerequisite = conquer Appalachia
> (re-points to Rockies when Rockies ships)`.

- **To UNLOCK Alaska:** **Tier-4 gear on at least one loop (EHT ≥ 4 OR EFT ≥ 4) + conquer Appalachia**
  — the **two-tier jump** (T2 → T4, Rockies skipped). A hunter's unlock cost is T4 weapon + armor =
  `2·c·Income(3) = 17,340` (EQUIPMENT_MASTER §4 / economy §3/§4); a fisher's is T4 rod + reel = 17,340.
  Time-to-afford on T2 income ≈ **10.2 hrs single-loop ≈ 1.7× a normal step** (`= g`) — verified
  affordable, the expedition-sized purchase Alaska *should* feel like, not a paywall (economy §4); the
  shared Cash pool roughly halves the wall-clock for a dual-loop player. **Entering Alaska requires T4
  gear, which is exactly why the floor is comfortable** (the two-tier-jump difficulty check passes —
  combat MVL check; §3).
- **The Boat is NOT an entry gate.** A hunter walks the interior for caribou/moose Boat-free. A fisher
  fishes the interior rivers (grayling/char/sockeye) Boat-free on arrival, but needs the **Coastal
  Skiff (~18,000, EQUIPMENT_MASTER §4.5)** to reach the coastal king salmon — see the milestone below.
- **Alaska's conquest milestone (designated here — OR-gate, either loop conquers):**
  - **Hunting target (canonical):** down the **Bull Moose** (mid, H100, T4-soloable) — the headline
    conquest, carrying the tier's one required solo damage-exposure beat. **Caribou is the reachability
    FALLBACK, not a co-equal path** (RD-A names "caribou or moose"; the gate accepts the caribou — a
    zero-damage chase — so a solo player who cannot get a bull to commit is never blocked, but the
    intended conquest is the moose; §3 / §10 #1).
  - **Fishing target:** land the **King (Chinook) Salmon** (FD 68, T4-soloable, **coastal — needs the
    Coastal Skiff**).
  - Both are **T4-soloable** and parity-targeted (§10 #7). **The grizzly (hunting apex) and the giant
    halibut (fishing apex) are deliberately NOT the milestone** — they are co-op-only content moments
    with **no solo route until T5 ships** (RD-A / Decision 7). This is the binding constraint of the
    whole doc: a pure-solo player on *either* loop can always conquer Alaska (moose on foot; king salmon
    with the Boat) without a partner.
  - **How the fishing route reads (the Boat asymmetry — §10 #6):** a *pure fisher* must own the Coastal
    Skiff to conquer (the king salmon is coastal), so the fishing conquest carries an extra ~18,000
    prerequisite the hunting conquest does not. This is the legible "you need a boat for the coast"
    expedition purchase (01) — and the Boat is itself an income-enabler (it opens the higher coastal
    catches) — but the cross-loop *conquest-cost asymmetry* is flagged for economy/parity (§10 #6). A
    hunter conquers Boat-free; the OR-gate means no fisher is *forced* down a costlier path than a
    hunter overall, but the fishing-only route does front-load the Boat.
- **The legibility contract** (progression §2): Alaska's locked pin reads in concrete nouns —
  *"Requires: Tier-4 expedition rifle + parka (or rod + reel) · Conquer Appalachia."* The Boat shows as
  the coastal-sub-area unlock, not an entry requirement.
- **To progress PAST Alaska:** **none at the MVL.** Alaska is the **top tier at launch**; Africa/Amazon
  are post-MVL Destinations (future LOC_ docs). The aspirational endgame here is the **co-op apexes and
  the Mythic** — the grizzly, the giant halibut, and the Ghost of the Gulf — which have no solo route
  **until T5 gear ships post-launch** (RD-A / Decision 7), at which point they become the soloable
  capstones (EQUIPMENT_MASTER §5 notes the T5 line is what finally solos the grizzly and lands the
  halibut). **When Rockies ships**, Alaska's `milestone_prerequisite` re-points Appalachia → Rockies
  via the data-driven DAG (progression §2 / build plan), no code change.

---

## 8. Economy Hooks (hand-off to economy chat)

> **All Cash is SYS_economy's** (band-owned, computed). This section provides the **engagement inputs**
> (spawn-density and bite-density values set *within* combat's/fishing's cap mechanism, plus per-target
> time components) that bound `ExpectedTargetsPerHour` and are economy-critical (the anti-low-tier-
> farming invariant, economy §5 / combat §5 / fishing §6). It does **not** author Cash.

### 8.1 Per-hour income band
`Income(4) ≈ 4,913 Cash/hr` (economy default `B·g³`), **identical for hunting and fishing** (dual-loop
balance, economy §6). Per-target Cash is **computed**: `Payout = (Income(4)/ExpectedTargetsPerHour) ·
RarityMultiplier`. With combat's modeled hunting rate **~28/hr** and fishing's **~22/hr** (the rate
*falls* with tier so per-target Cash *rises* faster), the routine baselines are **~175 Cash/kill** and
**~223 Cash/catch** (Common); Uncommon ×1.6 (~281 / ~357). These are computed illustrations, not
authored values, and are **nominal/pre-normalization** — economy normalizes the routine Common/Uncommon
*mix* to sum to `Income(4)` (RD5).

### 8.2 Cash faucets here (cite economy; do not author)
Kill payouts (floor hare/deer, mid caribou/sheep, the Uncommon moose milestone, the Uncommon grizzly
salvage); catch payouts (river floor + the coastal mid/king-salmon, the Uncommon halibut salvage);
daily-quest rewards (a fraction of `Income(4)` — economy §1); and **rare salvage floored low** (the §5
rares write **no Cash at kill/catch**; value flows to **trade + Trophy Hall** — economy §5 /
data_integrity). Rares are bonus **on top of** the band, never averaged in (RD5) — this faucet is
deliberately tiny.

### 8.3 Cash sinks here
> The two T4 gear lines below are **sequential steps of one tier, not alternatives**: 17,340 buys the
> *entry* T4 gear that clears the gate (you arrive on it), then ~12,283/loop is the rest of the T4
> ladder bought *while playing Alaska* — total T4 gear investment ≈ **29,623/loop** over the
> destination's lifespan, normal because the climb is priced off `Income(4)`, which the player is now
> earning.
- **T4 gating gear (entry step):** weapon + armor (or rod + reel) = **17,340** (the unlock purchase the
  player arrives holding; `2·c·Income(3)`).
- **Intra-tier T4 climb (the rest of the ladder, bought in-Alaska):** `m·Income(4) ≈ 2.5·4,913 ≈
  12,283`/loop across discrete steps (priced off `Income(4)`, which the player earns *once there*, so
  the within-Alaska climb is normal even in the MVL — economy §4).
- **The Coastal Skiff (~18,000, the marquee Alaska save-up):** `3.7·Income(4)` ≈ a full gear tier-up —
  the legible expedition purchase and the fisher's conquest prerequisite (EQUIPMENT_MASTER §4.5).
- **The Snowmobile Mount (~10,200):** mid-game convenience (EQUIPMENT_MASTER §4.6).
- **The Husky (~8,000):** convenience (EQUIPMENT_MASTER §4.7).
- **Snowshoes (~600) / Ice-Fishing Kit (~800):** trivial region friction-removers (§6).
- **Cosmetics** (Alaska camo, cabin/lodge theme — the evergreen identity ballast, economy §9);
  **revive/restock** (light, with free/ad alternative — combat RD-B). Basic bait/ammo is effectively
  free (the not-a-timer rule).

### 8.4 Spawn-density values — the anti-low-tier-farming invariant (engagement inputs, illustrative)

> Set **within** combat's `MaxConcurrentTargets + RespawnInterval → SpawnThroughputCeiling` (combat §5)
> and fishing's `MaxConcurrentBites + BiteRespawnInterval → BiteThroughputCeiling` (fishing §6). LOC_
> owns the *values*; the docs own the *mechanism*. **Purpose:** bound `ExpectedTargetsPerHour` by
> *availability, not kill/catch speed*, so an over-geared player farming low-tier water earns ≈
> `Income(1)` — strictly worse than playing their own tier (the binding invariant, economy §5). All
> values illustrative; validate against the modeled rates and the over-geared-farming test (§10 #5).

**Hunting (target ~28/hr modeled for a normal T4 player — combat §5):**
- Spawn areas: Tundra Flats (hare singles + caribou herds), spruce/river-bottom (moose), Crags (Dall
  sheep), Salmon Falls (grizzly).
- `MaxConcurrentTargets` / `RespawnInterval`: hare 4 / 40 s · Sitka deer 3 / 60 s · **caribou herds 1–2
  concurrent / 180 s** (also the mobile herd-crowd cap, §2.5) · Dall sheep 2 / 120 s · **bull moose 1–2
  / 240 s** · **grizzly 1 per Destination / 300 s**.
- Per-target time components (LOC inputs to combat's `TimePerTarget`): `TimeToFind` ~75 s (sparser,
  warier, snow-slowed unless mounted), `TimeToKill` ~35 s, `Overhead` ~20 s → `TimePerTarget` ~130 s →
  ~28/hr (matching combat's table). `SpawnThroughputCeiling(Alaska, hunting)` set so a normal T4 player
  realizes ~28/hr and an over-geared low-tier farmer caps at ≈ `Income(1)` (the throttle-vs-leak
  trade-off is the tuning knob; the *invariant* — capped near `Income(1)` for low-tier farming — is
  binding).

**Fishing (target ~22/hr modeled for a normal T4 player — fishing §5):**
- Waters: interior river (grayling/char/rainbow/sockeye — **shore**, no Boat), coastal inlet + open
  Gulf (rockfish/cod, lingcod, king salmon, halibut — **Boat-gated**), Frozen Lake (seasonal).
- `MaxConcurrentBites` / `BiteRespawnInterval` per water cell, with **local spot-depletion** (rotate
  spots — the fishing-meta + anti-AFK/bot signal): river ~3–4 / 35–50 s · coastal ~3–5 / 45–60 s ·
  Frozen Lake (event) capped low. `BiteThroughputCeiling` set so a normal T4 fisher realizes ~22/hr and
  over-geared low-tier farming caps at ≈ `Income(1)`.
- Per-catch time components (LOC inputs to fishing's `TimePerCatch`): fishing §5 models `TimeToBite`
  ~55 s, `FightTime` ~80 s, `Overhead` ~30 s → `TimePerCatch` ~165 s → ~22/hr. **LOC_04 uses fishing's
  modeled ~22/hr for the economy hand-off** and the per-fish mechanical fight times (§4, cited from
  EQUIPMENT_MASTER) for the catchability checks. *(The modeled-vs-mechanical FightTime reconciliation
  gap LOC_01/LOC_02 flagged is inherited, not re-introduced — §10 #10.)*

---

## 9. LiveOps / Event Ideas

> Suggestions only — SYS_liveops_calendar owns cadence and budgets. All are Alaska-appropriate timed
> content doubling as a **return hook** (the timed-spawn retention lever, 01).
>
> **Scarcity-discipline rule (00 §5, binding).** Events may raise the *frequency of a standing rare's
> qualifying CONDITION* (more run windows, more storm-seas) so more players get a fair shot — they
> **never** lower a rare's fixed per-window 1-in-N, never re-release a retired exclusive, and never
> dilute already-minted artifacts. Because effective rarity = per-window roll × condition frequency
> (§5), condition-frequency boosts **must be bounded** (a short scheduled window) so total mints stay
> scarce and trade value intact.

- **The Salmon Run (seasonal — canonical, the centerpiece):** the migration window. Concentrates **king
  salmon** in the coastal staging water (boosts the milestone's availability — the "salmon run" 01
  names), brings **sockeye** into the shore-accessible river mouths (a taste for pre-Boat fishers), and
  **draws grizzlies to Salmon Falls** in greater numbers (the co-op apex becomes *live*, see below). A
  bounded condition-frequency bump for the **Tyee King** and **Glacier Grizzly** rare windows — never a
  1-in-N change. The tentpole return hook tied to a *real* fishing/hunting season (the year-round-
  schedule-for-free lever, 01).
- **Co-op Apex Spotlight ("Expedition Weekend"):** the lever that turns the co-op apexes from *dead*
  content at low CCU into *live* content (the liveops-flagged risk; combat open Q3 / fishing co-op
  flag). A scheduled window that (a) concentrates players in the Lodge/Harbor Camp to find partners,
  (b) bounded-boosts the **grizzly** and **giant halibut** spawn windows so a party that forms gets a
  shot, and (c) themes the Trophy Hall / leaderboard around the week's apex kills/catches. **No
  matchmaking or NPC-assist at MVL** (scope — combat open Q3); the spotlight is a *social + condition-
  frequency* push that makes parties form organically, not an automatch. This is how the grizzly,
  halibut, and Ghost of the Gulf stay alive at soft-launch (§10 #8).
- **Winter Freeze (seasonal sub-activity):** the Frozen Lake freezes; the **Ice-Fishing Kit** (§6)
  opens a calmer seated micro-activity (a counter-tempo to the coastal fight) plus winter-themed
  cosmetics (identity ballast, economy §9). A bounded event with its own light daily pair; catches stay
  inside the bite-density cap (§8) so it is not a farming hole.
- **Storm-Seas (the Mythic window):** bounded weather windows that make the **Ghost of the Gulf**'s
  storm-Gulf condition more frequent (more *chances*, unchanged 1-in-N) — the "storms make rare fish
  bite" hook (01), kept short so total mints stay scarce. The aspirational co-op clip generator.
- **Cross-loop daily pair (standing):** one small Alaska hunt + one small catch objective; completing
  both pays the cross-loop breadth kicker (economy §6). Breadth-as-reward, never focus-as-penalty —
  and the gentle standing pull that invites a pure hunter to try the rod and vice-versa.

---

## 10. Open Questions / Flags

1. **The "harsh dangerous Alaska" feel vs. the binding "normal-for-tier, telegraphed, no inflated
   punishment" constraint (the central tension; combat confirm).** The danger must be **FELT but
   LEGIBLE**. This doc resolves it by sourcing the danger from *legible* channels, not a difficulty
   cliff: (a) higher **absolute** damage numbers (moose 45, grizzly 85) on the *same* shot-count bands
   — floor 2 shots, mid 3 shots, never inflated; (b) **every lethal threat telegraphed** (moose
   head-down charge, grizzly rear-up swipe — the only two creatures that can damage the player both
   wind up visibly/audibly); (c) the genuinely **co-op-only apex** (the grizzly is the *real* wall, and
   it is gear/partner-checked, not a random one-shot); and (d) **sensory/atmospheric** dread (the
   open-tundra silence, the cold light, the glacier, the isolation). Confirm combat is satisfied that
   "felt danger via absolute numbers + telegraphs + a co-op wall + atmosphere" delivers the expedition
   threat **without** an inflated shot-count band or any random instakill (the two-tier-jump
   conditions). The risk to watch in playtest: if the higher absolute damage *reads* as a cliff despite
   being telegraphed, the fix is telegraph timing/feedback, **not** stat deflation.
   **RESOLVED (second-pass sub-issue — the solo danger budget).** The moose stays **exactly as statted**
   (3 shots, ~8 s survival margin, ~22–45 dmg taken to land it). Tightening it toward a tense margin was
   **rejected**: it would violate the milestone-reachability guarantee that is the basis of RD-A *and*
   the two-tier-jump's normal-for-tier condition (no inflated bands), and it would break the corpus-wide
   pattern that a conquest milestone is a **confidence-beat** (the Appalachia boar milestone is likewise
   safe-in-armor). The frontier tier's danger is delivered correctly through three channels that do
   **not** require inflating the milestone: (a) the genuinely **co-op-only grizzly**, which two-shots a
   solo player at the falls — optional, but real felt danger the instant a solo player approaches it;
   (b) the **storm-Gulf Mythic**; and (c) **atmosphere/isolation**. The one refinement: the **canonical**
   hunting milestone is the **Bull Moose**, which carries the tier's single *required* solo
   damage-exposure beat; the **Caribou is retained as the sanctioned reachability FALLBACK, not a
   co-equal path** (a pure chase, zero damage). A solo player who cannot get a bull to commit can still
   conquer via the caribou, so conquest is never blocked — but the intended headline conquest is the
   moose, and the danger-free caribou route is the **safety-valve, not the design-default**. This keeps
   RD-A's reachability while ensuring the canonical frontier conquest is not threat-free.
   **Playtest watch (unchanged):** if the moose's higher absolute damage ever reads as a cliff despite
   the telegraph, the fix is telegraph timing/feedback, **never** stat deflation. (Interacts with
   milestone parity #7 and the §1 copy note #12.)

2. **Filename: `LOC_04_alaska.md` (used here) vs. the brief's request for `LOC_03`.** Per 02's
   convention (number = tier) and `03_BUILD_PLAN` Phase 2, Alaska is `LOC_04` and `LOC_03` is reserved
   for the Tier-3 Rockies post-launch drop. Using `LOC_03` would collide with the Rockies doc. Produced
   as `LOC_04`; flagging so the corpus owner can confirm (trivial rename if the literal `LOC_03` is
   wanted, at the cost of the known collision).

3. **No wolf pack in Alaska (combat/LOC_03 coordinate).** The pack co-op-tutorial was delivered in
   Appalachia (coyotes); LOC_02 §10 reserved the **wolf-pack template to the Rockies (LOC_03)**. Alaska
   honors that — its co-op lesson is the single-apex grizzly, not a pack. Confirm this is the intended
   division (it keeps the wolf as the Rockies' signature when Rockies ships, and avoids two pack
   tutorials).

4. **Two "rares that are also walls" (combat/fishing/data_integrity confirm).** Because Alaska's apexes
   are co-op-only, the **Glacier Grizzly** (Legendary) and the **Ghost of the Gulf** (Mythic) inherit
   the no-solo-route property — a solo player can *find* but not *take* them at MVL. This is the
   deliberate Black-Catamount pattern (LOC_02 §10 #7). Mitigation: both are run/storm content a player
   farms *in a party* by the time they're chasing them, so "find-it-but-need-a-partner" reads as
   aspirational, not punitive — **and unlike the Catamount, here it is consistent with the entire tier's
   apex being co-op-only**, so it is less surprising. Confirm in playtest that the solo "found-but-
   walled" case reads as aspirational; the **soloable** rares (Cross Fox, Spirit Moose, Tyee King) are
   the finds a solo player can actually take, so no solo player is left with *zero* reachable rares.

5. **The Mythic "Ghost of the Gulf" as Alaska's "white whale" vs. 01 reserving the white whale for
   Deep Sea (T7).** The brief explicitly wants Alaska's open-ocean white whale as the aspirational
   fishing content moment; 01's roadmap also names a Tier-7 Deep-Sea "white whale" (marlin/open-ocean
   endgame). These can coexist (Alaska's is a colossal *halibut* in the Gulf; T7's is the *blue-water*
   marlin/ocean leviathan), but the shared "white whale" label is a naming overlap to resolve before
   T7's LOC doc (pick distinct epithets). Also: the per-window 1-in-N (9,000) and the storm/Gulf/party
   condition set the *effective* rate — validate it lands rarer than the Bayou Leviathan (tier-
   escalating Mythic scarcity) and is still a real co-op dream (co-owned with SYS_liveops, §9).

6. **The Boat conquest-asymmetry (economy/progression/parity confirm).** A pure *fisher* must own the
   Coastal Skiff (~18,000) to conquer Alaska (the king salmon is coastal), while a pure *hunter*
   conquers Boat-free (the moose is interior). The OR-gate means no player is *forced* down the costlier
   route (a fisher could in principle conquer via the hunting loop, and vice-versa), and the Boat is an
   income-enabler (it opens the higher coastal catches), so the asymmetry is bounded — but the
   fishing-*only* conquest does front-load ~18,000 that the hunting-only conquest does not. Confirm this
   is acceptable (it is the legible "you need a boat for the coast" purchase, 01) or whether the
   milestone-parity tuning (#7) should account for the Boat cost on the fishing side.

7. **Milestone parity (tuning, inherited).** Hunting milestone = **Bull Moose** (H100, 3 shots,
   tense-but-safe in T4 armor); fishing milestone = **King Salmon** (FD 68, FightTime 9.0 ≤ LandWindow
   48). Both T4-soloable; target equal effort so conquest-via-either-loop is roughly equal
   (progression / fishing §8). Validate first-conquest time-to-complete doesn't diverge by loop in
   playtest; if it does, nudge moose Health or king-salmon FD (do **not** touch T4 gear stats —
   EQUIPMENT_MASTER owns those). Note the Boat-cost asymmetry (#6) interacts with felt parity even if
   the *fight* parity holds.

8. **Co-op population at soft launch (combat open Q3 / fishing co-op flag — inherited, acceptable).**
   The grizzly, giant halibut, and Ghost of the Gulf may go untaken by many solo players at low CCU.
   This is **expected and acceptable** — they are aspirational co-op trophies and **progression is
   never blocked** (the soloable moose / king salmon are the milestones). **No matchmaking or NPC-assist
   at MVL** (scope). The mitigation is the **Co-op Apex Spotlight** event (§9), which makes parties form
   organically; escalate via SYS_liveops only if telemetry shows the apexes are effectively dead
   content (combat open Q3 names the same canary). Instrument solo-vs-co-op apex-completion rate at
   Alaska specifically — a ~0 solo rate here is *correct*, not a bug.

9. **Snow-movement penalty (combat/feel confirm).** The deep-snow on-foot slow (§2.4) makes the
   Snowshoes and Snowmobile legible wants. Confirm the slow reads as *flavor friction with an obvious
   cheap fix* (snowshoes ~600), **not** an energy-timer-style gate (00 §4). If it reads as annoying
   rather than atmospheric, soften the penalty or bundle snowshoes cheaper/earlier; the slow must never
   block the loop, only flavor it.

10. **Inherited modeled-vs-mechanical FightTime reconciliation gap (NOT introduced here; surfaced per
    LOC_01/LOC_02 precedent).** The cited per-fish mechanical FightTimes (king salmon 9.0, halibut 45.6)
    are the catchability-check values; fishing §5's *rate model* uses a T4 `FightTime ≈ 80 s` inside
    `TimePerCatch ≈ 165 s`. These are different layers (mechanical-per-fish at `E_expected` vs. a modeled
    per-catch average folding in bite-reaction, runs, re-grabs), but the gap is the same load-bearing
    `ExpectedTargetsPerHour` unknown the prior LOCs flagged. **Flag for the joint economy/fishing/combat
    tuning pass**, not resolvable in a LOC doc; LOC_04's per-fish FightDifficulty and §8 density values
    are the inputs that pass tunes against.

11. **Spawn/bite-density values are illustrative (§8.4).** Validate against combat's ~28/hr and
    fishing's ~22/hr modeled rates **and** the over-geared low-tier-farming test (economy §5 / combat §5
    / fishing §6). The throttle-vs-leak ceiling is a knob; the *invariant* (over-geared low-tier farming
    capped near `Income(1)`) is binding. Caribou-herd and grizzly concurrency caps are also the mobile
    crowd-load caps (§2.5) — co-tune.

12. **RESOLVED — BINDING BUILD-DECISION: NO environmental / cold / survival-damage system at the MVL.**
    The snow penalty (§2.4) is **movement-only and never a gate**; only **two animals** (moose, grizzly)
    can deal damage, one of them optional. A survival / cold / hunger / stamina-drain meter is
    **explicitly out of scope and must not be introduced** — it is the energy-timer pattern 00 §4
    forbids, and the specific failure mode this decision exists to prevent is it being **silently
    re-added later as a monetizable timer** ("buy a warmer parka or take cold damage"). **Any future
    proposal for a cold/hunger/stamina mechanic must be evaluated against 00 §4 as a suspected
    pay-to-win timer, not slipped in as immersion.** Copy is made honest to match (resolution (a) + copy
    nudge): the §1 one-line feel now reads "…for the first time, this place can kill you," pointing at
    the telegraphed predators + the isolation/cold light rather than implying an environmental-damage
    mechanic that by design does not and should not exist. The atmosphere keeps doing its work; the copy
    no longer writes a check the systems shouldn't cash. Pairs with the solo-danger-budget resolution
    (#1).

---

> **Template A pattern note (consistency with LOC_01 / LOC_02):** every section above is filled;
> creatures use Template C, fish Template D, rares Template E, region gear Template B; units are Cash /
> kg / 1–100 / 1-in-N throughout; Cash is *computed and cited* from the economy band, never authored;
> combat/fishing math and gear stats are *cited* (the T4 line, Coastal Skiff, Snowmobile, Husky, and the
> worked king-salmon/halibut numbers come from EQUIPMENT_MASTER), never re-derived; the milestone
> constraint (RD-A / Decision 7), the Boat-gate, and the two-tier-jump conditions are honored in the
> numbers, not just asserted. As the MVL top tier, Alaska *does* populate a real apex with a real wall —
> but that wall is **co-op-only with no solo route until T5**, which is exactly why the *milestone* is
> the soloable moose/king-salmon and the apex is the grizzly/halibut. **Re-derive every stat against the
> inequalities before build** (the corpus rule — a number can pass a prose read and still be wrong); the
> bands here are populated to combat §3 / fishing §3 and the EQUIPMENT_MASTER §4 worked values, but the
> joint economy/combat/fishing tuning pass (§10 #10/#11) is where the rates are finalized.
