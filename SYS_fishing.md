# System: Fishing

> Fourth system deep-dive (Phase 1, step 4). Sibling to SYS_combat: the second of the two
> cross-feeding loops. This doc owns the **fishing mechanic** (cast → bite → fight/reel), the
> **rod/reel ↔ fish-stat interaction** that decides catch success, the **min-rod/min-reel-tier
> derivation** that implements progression's floor/ceiling rule for fishing, **bait/lure** rules,
> **water types + Boat sub-area gating**, the **fishing milestone target** per dual-loop
> Destination, and — load-bearing — fishing's **`ExpectedTargetsPerHour(T, fishing)`**, the input
> the economy turns into per-fish Cash and the figure telemetry watches for dual-loop drift.
>
> It does **not** own: Cash values/curves (SYS_economy), rod/reel/bait/boat stats and prices
> (EQUIPMENT_MASTER), the specific fish per Destination (LOC_ docs fill rosters into this doc's
> mechanic + math), or hunting (SYS_combat).
>
> **v1.1 (second pass).** Built and reconciled against the now-present **SYS_combat v1.1**. Three
> changes from v1: (1) the catchability model is recast to mirror combat's single inequality exactly
> — `FightTime ≤ LandWindow`, with **reel as the weapon-analog** (shortens FightTime) and **rod as
> the armor-analog** (lengthens LandWindow; a snap is the window closing, not a separate gate); (2)
> **Alaska's fishing milestone is corrected to a T4-soloable signature catch (king salmon), NOT the
> coastal apex** — mirroring combat Resolved Decision A, because at MVL the apex has no solo route
> (T5 gear does not exist); (3) a fabricated drift-threshold number is removed (no such constant
> exists in economy or combat). Plus alignment to combat's rate-formula `min(...)` cap fold, its
> ordered reward pipeline, and a named skill term. See *Changes from v1* at the end.
>
> **Inherited as binding** (do not re-litigate):
> - **SYS_progression v2.1** — `EFT = min(rodTier, reelTier)`; weakest-required-slot rule; bait is
>   **not** a tier input (required-item yes/no only); OR-gate on `required_tier` (`EHT ≥ N OR
>   EFT ≥ N`); Boats gate a **sub-area**, not Destination entry, except where genuinely water-locked;
>   floor/ceiling rule (floor catchable at T−1, apex at T+1 solo / T with co-op); unlock is a
>   one-time threshold; milestone validation is server-side and idempotent; Angler Rank XP is earned
>   through **active play only**, never idle.
> - **SYS_economy v2.1** — Resolved Decision 4 (per-target Cash is **computed** from
>   `Income(T) ÷ ExpectedTargetsPerHour`, authored by neither loop alone); Resolved Decision 5 (the
>   income band is the **routine Common/Uncommon mix only**; rares are bonus on top, so routine bites
>   must be **stable** and rares **infrequent, 1-in-N**); the **not-a-timer rule** (no fish takeable
>   *only* with a premium consumable); the **§5 spawn/bite-density-cap** hard dependency; Cash is
>   server-authoritative; rare NPC-salvage floored low so rare value flows to **trade**, not the
>   Cash faucet.
> - **SYS_combat v1.1** — the mechanical-distinctness commitment (§1: hunting is the *discrete
>   precision shot under a survival/escape clock*; fishing is *sustained line tension with no death
>   threat*); the catchability-inequality **form** (`ShotsToKill ≤ KillWindow/CycleTime`, evaluated
>   at T−1/T/T+1, deriving min-tier) that this doc mirrors; the rate formula's `min(rate,
>   throughput-ceiling)` cap fold; **Resolved Decision A** (top-tier MVL milestone must be soloable,
>   not the apex — mirrored here for Alaska); **Resolved Decision B** (failure is never punitive —
>   no Cash/inventory loss — mirrored here as losing a fish costs nothing banked); **Resolved
>   Decision E** (rares are independent condition-gated spawns, never per-resolution rolls);
>   **Resolved Decision F** (the floor/ceiling **spread-growth constant is shared and jointly owned**
>   — fishing inherits combat's value, does not set its own).
>
> **Illustrative numbers convention** (as in SYS_economy / SYS_combat). Every concrete magnitude here
> (time components, rates, `k_s`, `E_expected`, band cutoffs) is an **illustrative default**, flagged
> in Tuning Parameters. The *formulas, inequalities, and reconciliation relationships are the
> design*; magnitudes are calibration knobs. Numbers in prose are marked *(default)*.

---

## Resolved Decisions (binding — do not re-litigate downstream)

1. **Fishing's signature verb is sustained tension management, not aim.** The fight is a push/pull
   rhythm — apply reel pressure to drain the fish when it lets you, ease off the instant it runs to
   keep line tension out of the break zone. There is **no death threat** to the player and **no armor
   interaction**: fishing's failure mode is **losing the fish** (line snaps from over-tension, or the
   hook throws from slack/timeout), which is the escape/break-bounded analog of combat's kill window.
   This distinctness is deliberate and mutual with combat (combat §1 makes the same commitment from
   its side) — it is what stops the two loops from collapsing into the same minigame.

2. **Reel is the weapon-analog; rod is the armor-analog; `EFT = min(rod, reel)` is mechanically
   justified.** Mirroring combat's `min(weaponTier, armorTier)`: **reel Line Speed/Drag** sets
   stamina-drain rate and so **shortens FightTime** (the offense side — a too-low reel can't out-drain
   the fish: `FightTime > LandWindow` → throw/timeout); **rod Pressure** sets the tension ceiling and
   so **lengthens LandWindow** (the defense side — a too-low rod gives no headroom over the fish's
   runs, the window collapses, and you snap, exactly as too-little armor collapses combat's survival
   window). A great reel with a weak rod lands routine fish but snaps on the apex; a great rod with a
   weak reel holds tension but never lands. Both must clear → the **min** of the two binds, exactly
   progression's weakest-slot rule. (Stats live in EQUIPMENT_MASTER; the roles are this doc's.)

3. **Rare/Legendary/Mythic catches are independent, condition-gated spawns — fishing ships NO
   per-cast rare-upgrade roll.** A legendary fish is a separately-spawned entity present in the water
   under its Template E condition (time/weather/season/event), with its own 1-in-N, layered *on top
   of* the routine population. It is never "every Nth routine catch upgrades to a rare." Mirrors
   combat Resolved Decision E and conforms to economy Resolved Decision 5: a per-cast roll would
   couple rare frequency to catch *rate* and fold rares into the routine stream, breaking the band
   normalization. Routine (Common/Uncommon) fish bite at **stable, predictable** rates; rares are
   **separate and infrequent**. This also protects the 1-in-N catch as a genuine content moment (01).

4. **Premium bait accelerates the routine stream only; it can never reach the moat-rares and can
   never be mandatory.** Premium bait shortens `TimeToBite` and slightly eases routine fights; it
   does **not** raise Legendary/Mythic encounter rate (those are bait-independent condition-gated
   spawns per Decision 3). No fish is catchable *only* with premium bait (economy not-a-timer rule).
   *Basic* required bait/tackle (a fly for trout, cut bait for catfish) is a **required-item yes/no
   gate** — trivially priced, auto-restocked, never a tier input. This keeps premium bait pure
   convenience (grind-compression on routine income) and keeps scarcity discipline (00 §5) intact:
   you cannot buy your way to more rares.

5. **Fishing reconciles to `Income(T)` through the shared band, not through equal rates.** Per-fish
   Cash is derived from fishing's **own** `ExpectedTargetsPerHour(T, fishing)` against the same
   `Income(T)` the band defines (economy RD4). Fishing's absolute catch rate is *lower* than combat's
   kill rate at every tier by design (fishing is the slower, fewer-but-bigger loop) — so each fish
   pays *more* per target, and an hour of tier-T fishing still sums to `Income(T)`, the same as an
   hour of tier-T hunting. Equal Cash/hr is structural; equal rates are not required and not sought.

6. **Bite availability, not gear, caps earning in low-tier water.** Each fishable area has
   `MaxConcurrentBites` and a `BiteRespawnInterval`, with local spot-depletion on each landed/spooked
   fish — together a `BiteThroughputCeiling` folded into the rate as
   `ExpectedTargetsPerHour = min(3600/TimePerCatch, BiteThroughputCeiling)`, mirroring combat's
   `SpawnThroughputCeiling`. An over-geared player in low-tier water hits the ceiling and earns ≈
   `Income(low)`, strictly worse than fishing their own tier. This is the fishing instance of economy
   §5's binding spawn-density dependency; LOC_ docs set the per-Destination values inside this
   mechanism.

7. **Alaska's MVL fishing conquest milestone is a T4-soloable signature catch (king salmon), NOT the
   coastal apex. (Mirrors combat Resolved Decision A; binding on LOC_04.)** At MVL, Alaska is the top
   tier, so T5 gear does not yet exist, so progression's apex rule (apex = T+1 solo OR T + co-op)
   leaves the apex with **no solo route**. If the fishing milestone were the apex, a pure-solo fisher
   could never conquer Alaska and never advance the Passport — breaking progression's "milestone
   non-skippable *but reachable*" guarantee, worst at soft-launch when co-op partners are scarce.
   Resolution, parallel to combat's caribou/moose-vs-grizzly: LOC_04 designates a **T4-soloable
   signature fish (king salmon) as Alaska's fishing milestone**, and makes the **giant halibut (or an
   open-ocean marlin-class "white whale") a co-op apex / content moment with no solo route until T5
   gear ships**. Gate stays solo-completable; the apex stays an aspirational co-op trophy.

---

## Purpose & player-facing goal

Fishing is the second of the two cross-feeding loops — a complete, satisfying way to earn the same
Cash, advance the same Passport, and conquer the same Destinations as hunting, exercising a
*different muscle*. Where hunting is twitch precision under a clock, fishing is patience and
endurance: read the water, place a cast, wait for the tell, set the hook on a beat, then *fight* — a
sustained tug-of-war where the skill is reading the fish's runs and managing line tension so you
neither snap the line nor let it go slack. The player-facing promise is that the fight is the payoff:
each catch is a small earned battle, and the big ones are battles you remember (and clip).

It exists so a bored hunter can switch loops and still progress (01's dual-loop promise, made real by
the shared Cash pool and the OR-gate), so the game has a second content surface that travels with
every Destination at roughly half the content cost, and so the rarest catches — the storm muskie at
midnight, the white whale of the open ocean — are the screenshot moments that feed the creator
flywheel (00 §6). A player should always know, in one glance, what they can catch now that they
couldn't before, and feel the difference between landing a panfish and surviving a king-salmon run.

---

## How it ties to the formula

- **Retention hub / 30-second-legible, deep-to-master (00 §0, §2).** The shallow loop — cast, wait,
  tug, reel — is legible in seconds. The depth is the tension-management skill ceiling (perfect
  pressure timing lands fish at gear you "shouldn't" be able to — the `E_expected` skill term, §2),
  the water-reading and spot-rotation meta the bite-density cap creates, and the dual-loop arbitrage
  of fishing when fishing pays better this moment. Fishing's slower, meatier cadence is a deliberate
  counter-tempo to hunting, lengthening combined session time without doubling content.
- **The dual-loop balance — 01 risk #3, the single most fragile thing in the game.** Fishing exists
  only as one half of a balanced pair. The whole reconciliation apparatus below (§5) is in service of
  one constraint: an hour of tier-T fishing earns the same `Income(T)` as an hour of tier-T hunting,
  so neither loop dies.
- **The trade moat (00 §5).** Region-specific rare and record catches are tradeable, displayable
  Trophy Hall status items. Decision 3 (rares as scarce condition-gated spawns, never a per-cast
  faucet) is what keeps a record catch *rare*, which is what keeps it *valuable*, which is what keeps
  the Trading Post the reason people log in.
- **Sell WITH the player (00 §4).** Fishing's monetization is premium bait (convenience on routine
  income), Boats (access to deeper water — the acceptable side of progression's access line), and
  cosmetic rod/lure skins (identity). The not-a-timer rule is binding: basic bait never blocks the
  loop. No fishing feature compresses the milestone — the conquest catch is always played.
- **Not Gone Hunting, not Fisch (05).** Gone Hunting's flat solo treadmill produced ~8.6-min
  sessions; fishing's depth lives in the contended Cash spend (economy §8) and the tension-skill
  ceiling, not in a longer sell→upgrade loop. And per 05's hard constraint, fishing is **half a
  dual-loop RPG**, never positioned as "a fishing game" — that is Fisch's category at Fisch's scale.
- **Content engine (00 §7).** Fishing rosters are data filled per Destination via Template D, and the
  fight mechanic is content-agnostic, so a new Destination's water is a droppable unit. Rares are
  condition-gated spawns on the LiveOps calendar.

---

## Mechanics (detailed)

### 1. The three-phase loop: cast → bite → fight/reel

Fishing is one continuous gesture chain on a touchscreen, deliberately lower-twitch than aiming a
rifle and higher-endurance than firing one. The contract with combat (combat §1): hunting owns the
**discrete precision shot under a survival/escape clock**; fishing owns **sustained line tension with
no death threat and a patience/endurance feel**. Same economy, different hands.

**Phase 1 — Cast (coarse placement, low stakes).** A flick gesture sets cast direction and power (a
brief power arc on press-and-drag, released to cast). The lure lands in a water cell. Skill here is
*water-reading* — casting near structure, into a bite-active cell, or onto a condition-gated rare —
not millimetric aim. Casting is intentionally forgiving; the precision verb belongs to hunting.

**Phase 2 — Bite (anticipation → reaction).** After a variable wait (`TimeToBite`, governed by the
water's bite density, the fish population, and bait quality), a clear audiovisual tell fires — the
lure dips, the line tugs. The player must **set the hook** with a timed tap inside a short window.
Miss it → the fish is off the hook (no catch, no gear loss, just lost time — which feeds back into
the rate economy and rewards attention). This is a single reaction beat, distinct from sustained aim.

**Phase 3 — Fight/reel (the signature verb — sustained tension management).** The hooked fish has a
**Stamina** pool; the fight is won when Stamina reaches zero and the fish is landed. The player
controls **reel pressure** (press-and-hold a reel control, or a continuous drag, on mobile). A
**line-tension gauge** has a productive band (reeling here drains Stamina), a **break zone** at the
top (snap → fish lost), and a **slack zone** at the bottom (hook throws → fish lost). The fish
**runs** intermittently — surges that spike tension; bigger/harder fish run harder and more often.
The skill loop: **reel hard when the fish isn't running to make progress; ease off the instant it
runs to stay out of the break zone.** That push-pull rhythm is the fishing verb. Making it satisfying
(01 risk #4) is a feel mandate for the build: weighty haptics on runs, the gauge tactile and readable
one-handed, audio that swells with tension and resolves on the land.

Failure is *losing the fish*, never dying, and (mirroring combat Resolved Decision B's no-punitive-
loss rule) it **never costs banked Cash or inventory** — only the current fight is forfeit. This is
the escape/break-bounded analog of combat's death/escape window, and it is why fishing has no armor
interaction.

### 2. How rod/reel stats and fish stats decide a catch (the catchability inequality)

This mirrors combat's `ShotsToKill ≤ KillWindow / CycleTime` exactly — one inequality, evaluated at
T−1/T/T+1, that *derives* min-tier rather than hand-authoring it. Fish carry, per Template D:
**Typical/Record weight (kg)** and **Fight difficulty (1–100)**. Rod and reel carry (stats in
EQUIPMENT_MASTER, 1–100): rod **Pressure**, reel **Line Speed/Drag**.

**Stamina to land** (analog of combat's `ShotsToKill` — what you must drain):
```
StaminaToLand(fish) = k_s · FightDifficulty · (1 + weight / W_ref)        (k_s, W_ref default)
```

**Net drain and the skill term** (analog of damage-per-cycle, carrying combat's `Z_expected`-style
skill term). `E ∈ [0,1]` is **tension efficiency** — how well the player holds productive tension
without spiking into the break zone or sagging into slack. A skilled angler (high `E`) drains faster
and lands at lower gear; a fumbling one (low `E`) stalls or snaps. This spread *is* the mechanical
skill ceiling — the fishing analog of combat's vital-hit spread — and it lets the same fish be easy
or hard without changing its stats:
```
NetDrain(reel, fish | E) = ReelDrainMax(reel) · E − FishRecovery(fish)
```
`ReelDrainMax` rises with reel Line Speed; `FishRecovery` (stamina the fish recoups during/after
runs) rises with Fight difficulty.

**FightTime** (analog of combat's `TimeToKill`):
```
FightTime(fish | reel, E) = StaminaToLand(fish) / NetDrain(reel, fish | E)      (∞ if NetDrain ≤ 0)
```

**LandWindow** (analog of combat's `KillWindow`; fishing has **only** the escape/break-bounded
variant — no survival-bounded form, because there is no death). Rod Pressure sets the tension ceiling
over the fish's run force; the more headroom, the longer you can fight before a tension error
compounds into a snap. When the rod barely clears the runs the window is short (one mistimed run ends
it); when `BreakThreshold ≤ PeakRunForce` the window collapses to ~0 (you snap on the first big run):
```
PeakRunForce(fish) ∝ FightDifficulty                                    (peak run intensity)
LandWindow(rod, fish) = w · max( BreakThreshold(rod) − PeakRunForce(fish), 0 ) · dragSmooth(reel)
```

**The catch is landable iff `FightTime ≤ LandWindow`** — you can drain the fish before a tension
error breaks the line. The two failure modes map to the two min-tiers, exactly as combat's weapon and
armor do:
- **Reel too low → `FightTime > LandWindow` (throw/timeout).** Derives the fish's **min reel tier**
  (the weapon-analog: not enough drain to finish in the window).
- **Rod too low → `LandWindow → 0` (snap).** Derives the fish's **min rod tier** (the armor-analog:
  no headroom over the runs).

Because `EFT = min(rodTier, reelTier)`, both must clear — progression's weakest-slot rule, now
mechanically grounded rather than asserted, on the same inequality shape as combat.

### 3. Deriving min-tier from the inequality (implements progression's floor/ceiling)

LOC_ docs author each fish's `FightDifficulty` and weights; the **min rod/reel tiers are derived, not
hand-set**, by evaluating `FightTime ≤ LandWindow` at the **T−1 / T / T+1** rod-and-reel stat values
(EQUIPMENT_MASTER supplies the tier→stat mapping) at the assumed skill reference `E_expected` — the
direct procedural parallel to combat deriving min-weapon-tier at `Z_expected`:

| Fish role in tier T | Design target (at `E_expected`, skilled tension play) | Effect |
|---|---|---|
| **Floor** | landable with **T−1** rod+reel inside its LandWindow | new arrival earns immediately on the gear that got them in (protects new arrivals — progression §5) |
| **Mid** | landable with **T** rod+reel | the routine band target (§5) |
| **Trophy / apex** | with **T** gear `FightTime > LandWindow` (you snap or it throws); with **T+1** rod+reel it just fits — *tense solo*; with **T** gear + a co-op assist it lands — *manageable with a partner* | the wall, the conquest target, the content moment |

This is combat's floor/mid/apex table, fishing-side. **Top-tier caveat, mirrored from combat Resolved
Decision A:** at the MVL top tier (Alaska, T4) there is no T+1 gear, so a tier's apex has **no solo
route** — it is co-op-only until T5 ships. That is why Alaska's *milestone* is a T4-soloable fish, not
the apex (Decision 7); the apex remains a co-op content moment.

Within a tier, the **Fight-difficulty band spans `[Floor_F(T), Ceiling_F(T)]`**, and
`Ceiling_F(T) − Floor_F(T)` **widens with T using the shared spread-growth constant inherited from
SYS_combat** (progression §5 / combat Resolved Decision F). Fishing does **not** set its own widening
rate — a divergent constant would make the two loops drift apart in felt difficulty as tiers climb.
Inherited, not authored; the constant is jointly owned and any change coordinates across both docs.

Rod and reel demands need not be equal for a given fish — roster texture for LOC_ docs: a hard-
running, light fish (a tarpon analog) is **rod-bound** (high `PeakRunForce`, modest Stamina → needs
rod headroom, modest reel); a heavy, dogged fish (a halibut/sturgeon analog) is **reel-bound**
(modest runs, huge Stamina → needs reel drain, modest rod). Both resolve to one `EFT` gate via `min`,
but they *feel* different and reward different gear-buy orders — a legible second axis of within-tier
choice, exactly parallel to combat's weapon-vs-armor pull.

### 4. Bait and lure

Per progression, bait is **never a tier input**. Two categories:

- **Basic bait / tackle (required-item yes/no gate).** Some fish require a specific basic bait/tackle
  to strike (fly for trout, cut bait for catfish, spoon for pike). This is a legible required-item
  check — *do you hold the right basic tackle?* — trivially priced and auto-restocked at the Tackle
  Shop. Every fish is catchable with its appropriate basic bait. This satisfies the not-a-timer rule:
  a player can **never** be blocked from the loop by running out of basics.
- **Premium bait / lure (convenience, optional, capped).** Shortens `TimeToBite` (more bites/hour →
  more routine income) and slightly eases routine fights (a modest LandWindow bonus or a small
  reduction in routine `PeakRunForce`). It is **never mandatory** and **no fish is catchable only
  with it.** Critically (Decision 4): premium bait does **not** raise Legendary/Mythic encounter rate
  — those are bait-independent condition-gated spawns (§5). Premium bait's effect on the routine
  rarity roll is capped at Uncommon bias *(tuning)*; Rare-and-above are unaffected. This keeps premium
  bait pure routine-grind compression and keeps the moat unbuyable.

A condition-gated rare **may** name a specific *basic* bait as part of its condition (e.g., "the
legendary muskie only strikes a live sucker, during a storm"). That is still a required-item
condition, not premium and not pay — it gates *the attempt*, not the *win*, and cannot be bought past.

### 5. The reconciliation seam — `ExpectedTargetsPerHour(T, fishing)` and dual-loop balance

Economy owns `Income(T)`; this doc owns the **rate**, and per-fish Cash is **computed** from
`Income(T) ÷ rate` (economy RD4). Fishing's rate is built from a `TimePerCatch` decomposition, the
direct analog of combat's `TimePerTarget`, with the bite-cap folded in via `min(...)` exactly as
combat folds `SpawnThroughputCeiling`:

```
TimePerCatch(T) = TimeToBite(T) + FightTime(T) + Overhead(T)
ExpectedTargetsPerHour(T, fishing) = min( 3600 / TimePerCatch(T) , BiteThroughputCeiling(water) )
```

Modeled at **mid intra-tier gear**, over the **routine Common/Uncommon mix only** (RD5 — rares are
excluded from the band and paid as bonus on top), per MVL tier, shown beside combat's published rates
*(all values default, provisional, co-owned with SYS_economy)*:

| Tier (Destination) | `Income(T)` (econ default) | TimeToBite | FightTime | Overhead | TimePerCatch | **ExpTargets/hr (fishing)** | Combat kills/hr (combat §5) | Baseline Cash / routine catch = `Income(T)/rate` |
|--------------------|----------------------------|------------|-----------|----------|--------------|------------------------------|------------------------------|--------------------------------------------------|
| 1 — Bayou (bank)   | 1,000  | 20s | 18s | 22s | 60s  | **~60** | ~80 | ~16.7 |
| 2 — Appalachia (river/lake) | 1,700 | 32s | 38s | 25s | 95s | **~38** | ~45 | ~44.7 |
| 4 — Alaska (coastal, boat-gated) | 4,913 | 55s | 80s | 30s | 165s | **~22** | ~28 | ~223 |

**Reconciliation check (the whole point):** `rate × baseline = Income(T)` on every row —
60 × 16.7 ≈ 1,000; 38 × 44.7 ≈ 1,700; 22 × 223 ≈ 4,913. So an hour of tier-T fishing earns
`Income(T)` — **the same** an hour of tier-T hunting earns, *despite different absolute rates*
(combat 80/45/28 vs fishing 60/38/22). Fishing lands fewer targets and each pays more; the per-target
Cash absorbs the rate difference exactly. Balance is a **derivation, not a coincidence of two payout
tables** (economy §6).

Fishing's rate is set *below* combat's at each tier on purpose — fishing is the slower, meatier,
fewer-but-bigger-catch loop, which serves the savor-the-fight feel and the content-moment framing.
This is a design choice and a tuning knob, not a balance requirement; the band reconciles at any rate.

**Per-fish Cash from the band (economy §5 form, restated for fishing):**
```
Payout(fish) = ( Income(T) / ExpectedTargetsPerHour(T, fishing) ) · RarityMultiplier(rarity)
```
`Income(T)` uses the **fish's displayed tier** (a re-skinned Alaska "bigger, meaner" panfish pays an
Alaska-floor wage — progression §6). The band is anchored on routine targets; a Rare/Epic/Legendary/
Mythic that appears pays baseline × its multiplier as genuine upside *on top of* the hour, spiking it
above `Income(T)` — never averaged in (RD5). Legendary/Mythic salvage stays floored low (economy §5):
the real value of a record catch is the **P2P trade and the Trophy Hall**, not the Cash faucet, so a
Mythic catch does not flood the economy.

**Drift.** The single failure door (economy §6) is the *modeled* rate diverging from the *measured*
one — fish biting slower or fights running longer than modeled on live data. That is what the
dual-loop drift alarm watches: **realized fishing Cash/hr vs realized hunting Cash/hr at comparable
intra-tier progress.** The alarm tolerance (how far the loop-ratio may stray from 1.0 before it fires)
is a telemetry tuning parameter, jointly owned with SYS_economy — not a fixed constant set here. The
fix when it fires is a knob turn — re-derive the lagging loop's payouts against the measured
`ExpectedTargetsPerHour` — because the structure already names where to turn it.

### 6. Bite-density caps (the low-tier-farming closure for fishing)

The band model is valid **only** if `ExpectedTargetsPerHour` is bounded by bite availability, not gear
(economy §5, binding). The fishing instance, mirroring combat's `MaxConcurrentTargets +
RespawnInterval → SpawnThroughputCeiling`, and folded into the rate formula (§5):

- **`MaxConcurrentBites(water)`** — how many active bite-opportunities a fishable area offers at once.
- **`BiteRespawnInterval(water)`** — how fast a fished-down area recovers.
- **Local spot-depletion** — each landed/spooked fish reduces nearby bite availability, recovering
  over the interval. → players rotate spots / read fresh water (this *is* fishing-meta depth, and an
  anti-AFK/anti-bot signal).

Together these set **`BiteThroughputCeiling(water, T)`**, which caps `ExpectedTargetsPerHour`
independent of rod/reel. An over-geared Tier-4 player fishing Tier-1 water hits the Tier-1 ceiling and
earns ≈ `Income(1)` — strictly worse than fishing their own tier. **This is a binding precondition,
not a nicety;** without it, low-tier farming breaks the bands. LOC_ docs set the per-Destination
`MaxConcurrentBites` and `BiteRespawnInterval` *within this mechanism*.

### 7. Water types and Boat sub-area gating

Template D water types and their access rules (Boat stats/tiers/prices → EQUIPMENT_MASTER; this doc
specifies the **gating relationship**, not the boat stats):

- **pond / river / lake / bank** — shore-accessible, **no Boat**. Early-tier fishing lives here (Bayou
  panfish/catfish; Appalachia trout/bass). The MVL's first two Destinations are Boat-free on the
  fishing side.
- **coastal** — requires the **first Boat tier**. Alaska's coastal/deep fishing (halibut, king salmon)
  is the MVL Boat gate. Per progression, the Boat gates **Alaska's coastal fishing sub-area, not
  Alaska entry** — a hunter walks the interior for caribou/moose Boat-free; a fisher needs the Boat to
  reach the coastal fish (including Alaska's fishing milestone king salmon, §8). Both routes stay
  legible.
- **deep sea** — requires a **top-tier ocean Boat**. Tier-7 Deep Sea is the single-loop fishing
  culmination (`offered_loops = [fishing]`).

A Boat is **access** monetization (progression's acceptable side of the line): it opens *new water*
for everyone who buys in. It must **not** grant fishing *power* in water already reachable from shore
— that would be convenience-gating shared content. The Boat opens the cell; it does not out-fish a
shore angler in a shared shore cell. (Genuinely water-locked Destinations, if any arise later, may use
a Boat as an *entry* gate per progression; the MVL has none — Alaska is sub-area gated.)

### 8. Fishing milestone targets per dual-loop Destination

Progression hands fishing the job of designating each dual-loop Destination's **fishing-side conquest
target** — the catch that, performed inside the Destination, conquers it via the fishing loop (the
OR-gate: conquering via *either* loop satisfies the milestone). Each should be the fishing-loop
signature of that Destination, **comparable in challenge to the hunting milestone** so conquest-via-
either-loop is roughly equal effort (progression flags target-parity as a tuning item; this doc
targets parity and flags it), and — binding from Decision 7 — **soloable at its tier**, never an apex
with no solo route. Proposed for MVL — **LOC_ docs finalize the exact species**:

| Destination | Tier | Proposed fishing milestone (T-soloable) | The apex / content moment (separate) |
|-------------|------|------------------------------------------|--------------------------------------|
| Bayou | 1 | A signature catfish (floor/mid fight) — deliberately light, protects D1 | — (Bayou conquest is intentionally light) |
| Appalachia | 2 | A trophy bass or trout, T2-soloable, comparable to the hunting milestone | a record muskie/pike as a co-op/aspirational catch (optional) |
| Alaska (MVL) | 4 | **King salmon (T4-soloable)** — the conquest milestone | **Giant halibut / open-ocean "white whale" — co-op apex, NO solo route until T5** (Decision 7) |

The Alaska row mirrors combat's caribou/moose (soloable milestone) vs grizzly (co-op apex) exactly. A
pure fisher can ride the fishing loop up the entire MVL ladder (buying the first Boat to reach
Alaska's coastal king salmon) without ever firing a weapon — honoring 01's promise — and the standing
cross-loop pull (economy §6) is what *invites* breadth without *requiring* it.

### 9. Co-op fishing (the apex co-op route)

To honor progression's ceiling rule (apex = T+1 solo **or** T + co-op) on the fishing side, apex fish
support a **light co-op assist**: a second angler can join the fight, adding `NetDrain` and/or
extending `LandWindow` (e.g., a tag-team reel, or a net/gaff assist at the landing phase), letting a
party land a tier's apex on **T** gear that would need **T+1** solo. At the MVL top tier (Alaska),
where T+1 does not exist, the apex (giant halibut) is **co-op-only** — there is no solo route until T5
(Decision 7), exactly as combat's grizzly is co-op-only at MVL. Kept deliberately light; the exact
co-op-fishing UX (shared fight vs. assist-at-landing) is an open question for LOC_/feel iteration.
Co-op gets the *milestone*, never the *gear* (progression's carry-proof property): a carried fisher
still needs the required rod/reel (and Boat) to enter the next Destination.

---

## Inputs / dependencies

- **00 / 01 / 02 / 04 / 05** — retention hub and 30-sec/deep-to-master balance; the dual-loop promise
  and risk #3; the reeling-feel mandate (01 risk #4); Template D fields (weights kg, Fight difficulty
  1–100) and the rarity scale; the canonical terms (Tackle Shop, Boat, Rare/Legendary/Mythic, Angler
  Rank, etc.); the "not a fishing game" positioning and the anti-treadmill guardrail.
- **SYS_progression v2.1** — `EFT = min(rod, reel)`; weakest-slot rule; floor/ceiling rule and the
  shared spread-growth constant; bait-not-a-tier-input; OR-gate; Boat sub-area gating; milestone-
  validation pattern; unlock as a one-time threshold; Angler Rank XP from **catches** (active play
  only, never idle), weighted by difficulty/rarity (curve is progression's, fed by this doc's catch
  events).
- **SYS_economy v2.1** — `Income(T)` band and the **computed-payout** rule (RD4); **RD5** (band =
  routine mix, rares bonus on top); the **not-a-timer rule**; the **bite-density-cap dependency**
  (§5/§6); rare salvage floored low; Cash server-authoritative; premium bait as a convenience sink,
  Boats as access sinks, rod/lure skins as identity sinks.
- **SYS_combat v1.1** — verified against, not assumed: the **hunting rate table** reconciled in §5
  (T1 ~80, T2 ~45, T4 ~28); the catchability-inequality **form** (`ShotsToKill ≤ KillWindow/CycleTime`
  → fishing's `FightTime ≤ LandWindow`) and the `Z_expected`→`E_expected` skill-term parallel; the
  rate-formula `min(...)` cap fold; **Resolved Decision A** (top-tier milestone soloable, not apex —
  mirrored as Decision 7); **Resolved Decision B** (no punitive loss — mirrored in §1); **Resolved
  Decision E** (rares as condition-gated spawns); **Resolved Decision F** (the **shared spread-growth
  constant**, inherited not re-set).
- **EQUIPMENT_MASTER** — rod **Pressure** and reel **Line Speed/Drag** stat values per tier (the
  tier→stat mapping the inequality reads); basic and premium bait items; Boat tiers and the
  water-type each opens; the starter Tier-1 rod+reel (progression's free starter loadout).
- **LOC_ docs** — per-Destination fish rosters (Template D), the actual `FightDifficulty`/weights the
  min-tier derivation consumes, the per-water `MaxConcurrentBites`/`BiteRespawnInterval`, the
  condition-gated rare definitions (Template E), and the finalized fishing milestone species (with
  Alaska's milestone bound to a T4-soloable catch per Decision 7).
- **Hard external dependency — bite-density caps** (LOC_/this doc's mechanism): the band model is
  invalid without them (§6).

---

## Outputs / what depends on this

- **SYS_economy** — consumes `ExpectedTargetsPerHour(T, fishing)` as the rate it divides `Income(T)`
  by to compute per-fish Cash, and as the **dual-loop drift** input it monitors against combat's rate.
- **LOC_ docs** — consume the fight mechanic, the min-tier **derivation** (they author Fight
  difficulty/weight; this doc's inequality yields min rod/reel tier), the water-type/Boat gating
  rules, the bite-density-cap mechanism (they set the values), the rare-spawn rules (Decision 3), and
  the milestone-designation rule (§8, with the Alaska soloable-milestone constraint binding on LOC_04).
- **EQUIPMENT_MASTER** — consumes the rod-Pressure / reel-Line-Speed **roles** and the requirement
  that a tier's rod+reel land that tier's floor but not its apex (the cross-tier balance rule, fishing
  side); the bait categories; the Boat→water-type gating spec (boat *stats* are EQUIPMENT_MASTER's).
- **SYS_progression** — consumes fishing's catch events for Angler Rank XP and the fishing
  milestone-target designations that fill each dual-loop Destination's Gate.
- **SYS_data_integrity** — consumes: every catch is a server-validated event; one bite → one fish
  artifact → one disposition (salvage XOR display XOR trade — economy's trophy-disposition rule);
  anti-dupe on landed-fish artifacts.
- **SYS_trading / SYS_lodge_trophy** — consume record/rare catches as tradeable, displayable status
  items (the moat and the Trophy Hall).
- **SYS_onboarding_funnel** — consumes the ~60-second first catch in the Bayou on the free starter
  rod+reel (the comprehension + first-reward beat), and the first premium-bait offer as a candidate
  minute-five soft-monetization setup.
- **SYS_liveops_calendar** — consumes the condition-gated rare spawns (storms make rare fish bite;
  salmon runs; seasonal migrations) as calendar content, and the standing cross-loop pull as the base
  the calendar escalates.

**Out of scope (named, not designed here):** Cash values/curves (SYS_economy — this doc produces the
rate, not the prices); rod/reel/bait/boat stats and prices (EQUIPMENT_MASTER); specific fish per
Destination (LOC_); hunting (SYS_combat); trade/anti-dupe *mechanics* (SYS_trading /
SYS_data_integrity — depended on, not built here).

---

## Tuning parameters

- **`TimeToBite(T)`, `FightTime(T)`, `Overhead(T)`** — the `TimePerCatch` components that set
  `ExpectedTargetsPerHour(T, fishing)`. *(this doc; the drift-prone reconciliation input, co-watched
  with SYS_economy — combat's analogous `TimeToFind/TimeToKill/Overhead`.)*
- **`ExpectedTargetsPerHour(T, fishing)`** — the derived rate; the dual-loop drift alarm reads it
  against combat's. **Bounded above by `BiteThroughputCeiling` via the `min(...)` in §5.**
- **`k_s`, `W_ref`** — the `StaminaToLand` constants (Fight-difficulty and weight scaling).
- **`E_expected`** — the assumed tension-efficiency used to *derive* min rod/reel tier (the fishing
  analog of combat's `Z_expected`); the skill reference the floor/ceiling computation assumes.
- **`ReelDrainMax(reel)` / `FishRecovery(fish)` mapping** — reel Line Speed → drain, and the fish's
  stamina-recovery term (sets min reel tier).
- **`BreakThreshold(rod)` / `PeakRunForce(fish)` / `w` / `dragSmooth(reel)`** — the LandWindow model
  (sets min rod tier).
- **Tension-gauge band geometry** — productive-band width, break-zone and slack-zone sizes; the core
  feel knob. *(coordinate with feel iteration / 01 risk #4.)*
- **Hook-set window length** — Phase-2 reaction window.
- **Spread-growth constant** — **inherited from SYS_combat (Resolved Decision F), not set here** (the
  per-tier `Ceiling_F − Floor_F` widening); the per-tier Fight-difficulty band cutoffs are the shared,
  jointly-owned values.
- **`MaxConcurrentBites(water)`, `BiteRespawnInterval(water)`, spot-depletion rate** — the
  bite-density cap (LOC_ docs set per-Destination values within this mechanism).
- **Premium-bait effect sizes** — `TimeToBite` reduction, routine LandWindow/run-force easing, the
  Uncommon-bias cap; *bound to never touch Legendary/Mythic encounter (Decision 4).*
- **Basic required-bait assignments** — which fish/water need which basic tackle (LOC_; legibility).
- **Co-op assist magnitude** — added `NetDrain` / extended `LandWindow` from a second angler; the apex
  T-with-co-op vs T+1-solo delta (and at MVL top tier, co-op-only — Decision 7).
- **Drift-alarm tolerance** — how far the fishing-vs-hunting Cash/hr ratio may stray from 1.0 before
  the alarm fires; *telemetry tuning param, jointly owned with SYS_economy (not a fixed constant).*
- **Fishing milestone target per Destination + target-parity** — whether the fishing and hunting
  milestones of a dual-loop Destination are equal difficulty (this doc designates; LOC_ specifies),
  subject to the Decision-7 soloable-at-tier constraint.
- **Rare-fish condition + 1-in-N** — per Template E (LOC_ docs; bait-independent per Decision 3).

---

## Claude Code build notes

- **Server-authority over every catch is absolute** (SYS_data_integrity; mirrors combat's anti-exploit
  pattern). The client sends *inputs* — cast vector/power, the hook-set tap, reel-hold state — and the
  **server simulates and validates** the bite roll, the hook-set, the fight resolution (Stamina,
  tension, runs), and the landed fish. A client asserting "I caught it," asserting a fish identity/
  rarity, or asserting a milestone is **ignored**; the server recomputes from authoritative event
  history. Couple with progression's server-side milestone validation (the conquest catch must have
  actually happened, inside the Destination, on a legal target) — idempotent set membership, so
  farming a milestone re-grants nothing.

- **Anti-exploit, server-side (mirrors combat's list):** reject any Stamina-drain not derivable from
  the equipped reel's stats × legal tension efficiency (a client claiming instant drain is dropped);
  enforce reel/run timing server-side; the server owns the bite population, positions, and respawn
  timers — the client cannot spawn, force, or relocate bites. This is also where the **bite-density
  cap is enforced** — an economy-critical invariant, not cosmetic.

- **Reward pipeline (server-side, ordered — mirrors combat's):** on a validated land → check an
  `ambiance`/no-reward flag (decorative or uncatchable-by-design fish grant nothing; early-return) →
  compute Cash via SYS_economy's `Payout` formula and write an **atomic ledger entry** → award Angler
  Rank XP (active-play only) → roll drops → if the catch is a legal milestone for the current
  Destination, set the conquest flag (idempotent — re-catching never re-triggers). Rare lands
  additionally fire the clean-catch content-moment flourish (the 1-in-N screenshot beat).

- **Rare catches are independent, condition-gated server-side spawns — never a per-cast roll**
  (Decision 3, mirrors combat Resolved Decision E). The server spawns a rare fish entity when its
  Template E condition is met, at its 1-in-N, into the water as a distinct target; routine bites
  resolve their rarity from the **stable Common/Uncommon** distribution only. Do **not** implement
  "roll on each cast for a rare upgrade" — that would couple rare frequency to catch rate and
  contradict economy RD5. Build-time assertion: rare-spawn code takes **no bait input** (Decision 4).

- **Cash per catch is computed, never authored** (economy RD4): `Payout = (Income(T) /
  ExpectedTargetsPerHour(T, fishing)) · RarityMultiplier`, as a server-validated atomic ledger
  transaction. Legendary/Mythic salvage floored low; their value routes to trade/display via the
  trophy-disposition rule (one artifact, one mutually-exclusive disposition).

- **Premium bait is a server-validated, time/quantity-bounded entitlement** affecting only
  `TimeToBite`, routine fight ease, and the capped Uncommon bias — wired so it **cannot** touch
  Legendary/Mythic spawn logic. Basic required bait is a server-checked inventory yes/no, never a
  timer.

- **Telemetry — wire alongside, not after** (00 §0, 01 risk #3):
  - **Fishing Cash/hr vs hunting Cash/hr, per tier, at comparable intra-tier progress** — the
    **dual-loop drift alarm**, compared directly against combat's §5 rate table; fires when the
    loop-ratio strays past the drift-alarm tolerance (a tuning param, §tuning). *The single most
    important fishing chart.*
  - **Per-tier catch success rate** (hooked → landed %) — detects a mis-tuned tension model or a fish
    whose derived min-tier is wrong (success collapsing at a tier = gate too tight). Combat's
    analog is per-tier kill success.
  - **Time-to-catch** (cast → land), decomposed into `TimeToBite` / `FightTime` / `Overhead` —
    verifies the modeled `ExpectedTargetsPerHour`; a divergence here is the drift's root cause (the
    fishing-side of combat's time-to-kill-vs-modeled check).
  - **Actual catches/hour per tier vs modeled** — verifies the bite-density cap; a high reading in
    low-tier water flags a low-tier-farming hole (combat's analog finding).
  - **Hook-set miss rate, snap rate, and throw/timeout rate** — feel-tuning signals for the gauge
    geometry, hook-set window, and the `E_expected` assumption (01 risk #4).
  - **Co-op vs. solo apex-completion rate** — validates the tense-solo / co-op-only tuning; at MVL,
    Alaska's apex (halibut) solo-completion is *expected* to be ~0 (co-op-only, Decision 7), as
    combat expects for the grizzly.
  - **Rare-catch frequency vs intended 1-in-N** — confirms rares stay scarce (moat) and that no path
    (premium bait, catch rate) is inflating them.

- **MVL pre-launch fishing checks:** (1) both loops hit the same `Income(T)` band at MVL tiers under
  realistic, bite-capped rates (the §5 reconciliation table holds on live data, against combat's
  table); (2) Alaska's fishing milestone (king salmon) is **T4-soloable** and reachable with the first
  Boat — *not* the co-op-only halibut apex (Decision 7) — verified alongside combat's parallel Alaska-
  milestone check; (3) the bite-density cap holds under an over-geared low-tier-farming test; (4) rare
  spawns fire as condition-gated server entities, never per-cast.

---

## Open questions / flags

- **SYS_combat is now reconciled** (it was absent at v1; present and verified at v1.1). Residual joint
  item: combat's rate table (80/45/28) and the shared spread-growth constant are both *illustrative/
  provisional* on combat's side too — the numeric cross-check is only as firm as combat's own
  pre-playtest defaults. Re-verify both tables together at the first post-soft-launch tuning pass
  (combat's open Q1 names the same joint target).

- **`ExpectedTargetsPerHour(T, fishing)` is the load-bearing unknown** (shared with economy and the
  twin of combat's open Q1). The modeled `TimePerCatch` components are estimates; dual-loop balance
  holds *only if* they match measured reality. Cannot be finalized until live data; payouts (§5) are
  provisional. Highest-priority joint-tuning item with SYS_combat/SYS_economy.

- **Tension-gauge feel is unproven and central** (01 risk #4, the same build-time risk combat names in
  its open Q4). Whether the push/pull rhythm is *satisfying* — not just functional — is an iteration
  question the spec can't settle. Prototype the fight in isolation early; the gauge geometry, run
  cadence, haptics, and the `E_expected` calibration are where fishing is won or lost. If the fight
  isn't fun, no amount of balance saves the loop.

- **Co-op fishing UX undecided.** Shared-fight (two anglers on one fish simultaneously) vs. assist-at-
  landing (a net/gaff beat) vs. tag-team (alternate reeling). Each has different netcode and feel
  implications. Deferred to feel iteration / LOC_ design; the *rule* (apex = T+1 solo or T + co-op; at
  MVL top tier, co-op-only) is fixed, the *mechanic* is open. Note combat's open Q3 caveat applies:
  at soft-launch low CCU the Alaska apex (halibut) may simply go uncaught by many solo players — that
  is acceptable (aspirational trophy), and **no NPC-assist or matchmaking at MVL** (scope).

- **Single-loop endgame reach for pure hunters** (inherited from progression). Deep Sea (Tier 7) is
  fishing-only; a pure hunter arriving at the endgame needs a reason to pick up the rod. Confirm at
  LOC_07 design that the standing cross-loop pull (economy §6) plus the content-moment draw of the
  open-ocean apex (the "white whale") is enough, or escalate to a LiveOps incentive.

- **Rod-bound vs reel-bound fish split is roster guidance, not yet validated.** Whether players *feel*
  the difference between a rod-bound (hard-running) and reel-bound (heavy-dogged) fish, and whether it
  meaningfully diversifies gear-buy order, needs playtesting. If it reads as noise, collapse to a
  single Fight-difficulty axis. (Parallel to combat's weapon-vs-armor pull, which combat treats as
  load-bearing — so the bar is to make this *as* legible.)

- **Premium-bait Uncommon-bias cap is a scarcity boundary to watch.** Decision 4 holds the line at
  Legendary/Mythic; the Rare/Uncommon boundary for bait bias is a knob. Watch rare-catch frequency vs
  premium-bait adoption in telemetry; if premium bait is measurably inflating tradeable rares, tighten
  the cap toward Common/Uncommon only.

- **Spot-depletion aggressiveness.** Too aggressive → fishing feels like constant relocation
  (annoying); too soft → the bite-density cap leaks and low-tier farming reopens. The
  `MaxConcurrentBites` / `BiteRespawnInterval` / depletion-rate triplet needs joint tuning with LOC_
  density values against the over-geared-farming test.

---

## Changes from v1 (for the diff)

1. **Catchability model recast to mirror combat's single inequality.** v1 used a three-part construct
   (`Landable ⇔ BreakThreshold ≥ PeakRunForce AND NetDrain > 0 AND StaminaToLand ≤ NetDrain·LineBudget`)
   with a separate binary snap-gate and a rod≈offense / reel≈sustain mapping. v1.1 adopts combat's
   exact shape: **`FightTime ≤ LandWindow`**, with **reel = weapon-analog** (shortens FightTime) and
   **rod = armor-analog** (lengthens LandWindow; the snap *is* the window closing, parallel to death
   folding into combat's survival window). Renames `LineBudget → LandWindow`; adds the skill term
   **`E_expected`** (tension efficiency), the procedural analog of combat's `Z_expected`. The §3
   floor/mid/apex table now mirrors combat's line-for-line.

2. **Alaska's fishing milestone corrected (the substantive fix).** v1 named it "king salmon **or**
   halibut (coastal apex)." Combat Resolved Decision A establishes that at the MVL top tier the apex
   has **no solo route** (no T5 gear), so an apex milestone would strand solo players. v1.1 designates
   **king salmon (T4-soloable) as the milestone** and the **giant halibut as a co-op-only apex /
   content moment** — mirroring combat's caribou-moose-vs-grizzly. New **Resolved Decision 7**; §3, §8,
   §9, build-note checks, and the open-questions co-op flag updated to match.

3. **Removed a fabricated drift threshold.** v1 cited a numeric drift band ("≈0.85–1.18") as if from
   economy; no such constant exists in economy or combat. v1.1 states the drift-alarm tolerance is a
   telemetry tuning parameter (jointly owned), not a fixed number.

4. **Alignment to combat's exact patterns:** the bite-cap is folded into the rate formula as
   `min(3600/TimePerCatch, BiteThroughputCeiling)` (combat's `min(...)` shape) rather than described as
   a separate cap; the build-notes reward pipeline is reordered to mirror combat's ordered server
   pipeline (validate → ambiance check → Cash/ledger → XP → drops → idempotent conquest flag → rare
   flourish); the no-punitive-loss rule is stated as the fishing mirror of combat Resolved Decision B.

5. **Combat-dependency flag resolved.** v1 was built against the brief's transcription of combat and
   flagged the file as absent; v1.1 is reconciled against the present **SYS_combat v1.1**, with the
   residual cross-check (both rate tables still pre-playtest) carried as a joint-tuning open item.
