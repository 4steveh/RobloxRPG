# System: Combat (Hunting)

> Third system deep-dive. Owns the hunting mechanic end to end: the shot/aim model and the skill it
> exercises, the damage model (weapon stats → damage → creature Health/Damage/Speed), the concrete
> **min-weapon-tier-to-kill / min-armor-tier-to-survive** numbers that implement SYS_progression's
> floor/ceiling rule, armor/survival and death cost, co-op Health scaling, the creature behavior
> archetypes, and ambiance-creature enforcement. It owns **ExpectedTargetsPerHour(T, hunting)** — the
> hunting side of the economy reconciliation seam — and the **spawn-density cap mechanism** the economy
> depends on. It owns *mechanics and numbers*; it does **not** own item stats/prices (EQUIPMENT_MASTER),
> specific creatures per Destination (LOC_ docs), or Cash values (SYS_economy).
>
> **Inherited as binding** (do not re-litigate):
> - From **SYS_progression v2.1**: EHT = `min(weaponTier, armorTier)`; armor is not a gating slot at
>   Tier 1 (empty armor = Tier 1 below the armor-gating start tier); a tier's **floor** is takeable with
>   T−1 gear and its **apex** needs ~T+1 gear **solo** OR T gear **+ co-op**; the milestone (conquest)
>   half of a gate is non-purchasable and must be earned in play; ambiance creatures grant nothing;
>   server validates every kill against authoritative event history.
> - From **SYS_economy v2.1**: **Resolved Decision 4** — payout is *computed* `Income(T) ÷
>   ExpectedTargetsPerHour`; this doc authors the rate, never the Cash. **Resolved Decision 5** — the
>   income band is normalized over the **routine Common/Uncommon mix only**; rares are bonus on top, so
>   routine spawns must be **stable** and rares must stay **infrequent (1-in-N)**. **§5 hard
>   dependency** — spawn-density caps must bound the rate independent of gear, or the economy breaks.
>   The **not-a-timer rule** — no creature may be takeable *only* with a premium consumable.
>
> **Illustrative numbers convention** (as in SYS_economy): every concrete magnitude is an *illustrative
> default*, flagged in Tuning Parameters. The *formulas and relationships* are the design; magnitudes
> are calibration knobs. Numbers in prose are marked *(default)*.

---

## Purpose & player-facing goal

Combat is the hunting half of the dual loop, and its job is to make pulling the trigger *feel* good
enough that a player wants to do it a few hundred more times. The player-facing fantasy is the clean
shot: you spot an animal, steady your aim, place the round where it counts, and it drops. Underneath
that 30-second-legible action sits the depth that holds the committed player — vital-zone placement,
reading a fleeing target's line, deciding whether to take an aggressive animal solo or wait for a
partner, and the constant gear-vs-skill question of whether your current rifle can finish a target
before it finishes you, or before it bolts.

The single most important quality bar for this system is **game feel** (01 risk #4 — this is where the
game is won or lost, and no amount of systems rigor substitutes for it). A shot must land with weight:
recoil, impact, a readable reaction from the animal, and a satisfying kill. The mechanic must also be
**mobile-first** — fully playable with two thumbs on a phone — because that is where the audience is
(00 §8), and a precision-shooting model that only works with a mouse would lock out most players.

The system's second, structural job is to make SYS_progression's floor/ceiling rule *true in numbers*:
a player who just unlocked a Destination can immediately start earning at its floor on the gear that
got them in, while that Destination's apex stays a real wall that demands either the next tier's gear
or a hunting party. That tension — "I can hunt here, but I can't take *that* yet" — is the forced-
progression engine and the co-op on-ramp, expressed as combat math.

---

## How it ties to the formula

**Retention via game feel (00 §0, §2).** A loop a seven-year-old grasps in 30 seconds is *aim and
shoot*; the depth that earns D7/D30 is shot placement, threat management, and the gear/skill climb. The
punchy-kill requirement is a direct retention lever — the first kill in the Bayou is the dopamine hit
the first-five-minutes funnel depends on (00 §3).

**Legibility as downvote-avoidance (00 §4, 01 risk #2).** Combat must never one-shot a player out of
nowhere. Every lethal threat is **telegraphed** — a wind-up, an audio cue, a visible charge — so death
is readable and feels like the player's mistake, not the game's. An unexplained instakill is exactly
the rage-quit-and-downvote pattern the whole gating system exists to avoid (SYS_progression's
legibility contract, expressed here as a *combat-feel* contract).

**Co-op, incentivized not forced (00 §9).** The apex-Health and pack mechanics make big game soloable-
but-tense with top gear and trivial with a party, and put an early pack in the player's path as a
natural "get a friend" lesson — the hub is where they find one.

**Depth, not Gone Hunting's treadmill (05 §2).** Gone Hunting's ~8.6-minute sessions come from a flat
shoot→sell→repeat loop with no mastery surface. Combat's answer is a skill floor *and* ceiling in the
mechanic itself: the same animal is a 3-shot fumble for a new player and a 1-shot clean kill for a
practiced one, and the threat/positioning layer gives the act tactical depth a static sell-loop can't.

**Content engine (00 §7).** Archetypes plus re-skins (SYS_progression §6) mean new Destinations reuse
behavior templates with scaled stats, so combat content is a droppable unit — no new mechanic per drop.

---

## Mechanics (detailed)

### 1. The shot model (the core skill, mobile-first)

Hunting is a **precision-shot mechanic under a closing window**, not a sustained-DPS or bullet-hose
model. One shot is a deliberate act with a skill check, not a held trigger.

**The act, beat by beat:**

1. **Aim (ADS).** The player holds/taps an aim control. The weapon raises and the view zooms to the
   weapon's optical range. A **sway reticle** appears wide and **settles** inward to a tight point over
   the weapon's *settle time* (a weapon stat, EQUIPMENT_MASTER) — better weapons settle faster and to a
   tighter point. Settling is the patience tax: snap-firing wide is inaccurate; waiting for the settle
   costs time against the target's escape/charge window.
2. **Place the shot.** A **vital zone** (heart/lung) is shown on the animal when the reticle is near
   it. Hitting the vital is the skill payoff. The zone is smaller and the settle slower at higher
   tiers and on tougher animals.
3. **Fire.** Tap-to-fire. Resolution is **hitscan** for rifles (instant ray) with range falloff — the
   forgiving choice for mobile latency. (Projectile classes such as bows/shotguns are deferred; see
   Open Questions.) Recoil kicks the reticle and it must re-settle for the next shot.
4. **Reaction & feedback.** The animal reacts immediately — stagger, flinch, flee, or charge — and the
   shot lands with weight (below).

**Mobile touch scheme (the default, must be first-class):**
- Left thumb: virtual movement stick. Right thumb: drag-to-aim (swings the reticle).
- A dedicated **fire** button under the right thumb; **aim** is hold-to-ADS (or a toggle, a setting).
- **Aim-assist** (default ON, strength tunable): a soft magnetism that slows reticle travel near a
  valid target's vital and lightly biases toward it within a cone. It makes the mechanic *possible* on
  a phone without making it *trivial* — it helps you settle on the target, it does not place the lethal
  shot for you, and its strength is capped so rares and apexes still demand real timing. Aim-assist
  strength/cone is a tuning parameter and is **platform-split in telemetry** for fairness (Open
  Questions).
- Desktop/gamepad use the same model with mouse/stick aim and reduced or no assist.

**Game-feel requirements (the §4-risk bar — treat as spec, iterate hard in build):** per-weapon-class
recoil kick; a brief **hit-stop / freeze-frame** on a vital hit; impact VFX and a directional blood/
dust tell; a distinct **kill reaction** (stagger-into-drop or ragdoll); class-distinct audio (a bolt
rifle and a shotgun must *sound* different); **haptic** feedback on mobile for fire and kill; and a
**clean-kill flourish** (short slow-mo / emphasized audio) reserved for rare/legendary/mythic kills —
this *is* the designed content moment (00 §6, Template E's content-moment field), built into the
mechanic rather than bolted on.

**Why this is mechanically distinct from fishing (so the loops feel different).** Hunting's signature
is the **discrete precision shot resolved against a survival/escape clock** — you can *die*, and the
threat is positional and bursty. Fishing (SYS_fishing) is sustained tension on the line with no death
threat and a patience/endurance feel. Keeping hunting's death-risk and burst-precision unique to it is
what stops the two loops from collapsing into the same minigame. Both still reconcile to the same
`Income(T)` band (§5) — same economy, different hands.

### 2. The damage model

All combat stats are on the shared **1–100 scale** (02). Per shot:

```
ShotDamage = WeaponDamage · ZoneMultiplier · RangeFalloff
```

- **WeaponDamage** — the weapon's Damage stat (EQUIPMENT_MASTER, 1–100), at the player's current
  intra-tier upgrade level.
- **ZoneMultiplier** — `Z_vital` *(default 2.5)* for a vital hit, `Z_body` *(default 1.0)* for a body
  hit, `Z_limb` *(default 0.5)* for a graze; a miss deals 0 and spooks the target.
- **RangeFalloff** — `1.0` within the weapon's optimal range band (from its Range stat), declining
  beyond it to a floor; inside-band shots are full damage, long shots are penalized. Below-band (too
  close) is full for rifles.

A target dies when cumulative `ShotDamage` ≥ its **Health** (Template C, 1–100). So:

```
ShotsToKill = ceil( CreatureHealth / (WeaponDamage · Z_expected · RangeFalloff) )
```

`Z_expected` is the zone multiplier the player actually achieves — the skill term. A practiced player
lands vitals (`Z_vital`) and kills in fewer shots; a flustered one lands body shots and needs more.
That spread *is* the mechanical skill ceiling, and it is what lets the same animal be easy or hard
without changing its stats.

**Cycle time.** Between shots there is `CycleTime = settleTime + fireRecovery + reloadIfNeeded` (driven
by weapon stats, EQUIPMENT_MASTER). `CycleTime` converts `ShotsToKill` into **time**-to-kill, which is
what the floor/ceiling and reconciliation math actually use:

```
TimeToKill = ShotsToKill · CycleTime
```

### 3. The floor/ceiling threshold — concrete computation

This is where combat *implements* SYS_progression's rule. The rule is: a tier's **floor** is takeable
with T−1 gear; its **apex** needs ~T+1 gear **solo** OR T gear **+ co-op**. Combat makes that true by
setting creature Health and Damage so two windows decide every encounter.

**The two windows.** Every huntable target has a **KillWindow** — the time the player has to land the
kill before the encounter fails — and failure has two flavors by archetype:

- **Escape-bounded** (passive/flees): `KillWindow = TimeToFlee` — the target detects you, breaks, and
  is gone. Miss too much or cycle too slowly and it escapes. Gear and skill both shorten `ShotsToKill`
  and so beat the window.
- **Survival-bounded** (aggressive/pack/apex): `KillWindow = PlayerEffectiveHP / CreatureDPS_postArmor`
  — the time before the animal downs *you*. Here armor and weapon both matter: a better weapon finishes
  sooner; better armor lengthens the window.

**A target is killable iff `ShotsToKill ≤ KillWindow / CycleTime`** (you can land enough shots before
the window closes). This single inequality, evaluated with T−1, T, and T+1 gear, produces the
floor/ceiling relationships:

| Target role in tier T | Design target (skilled, vital hits) | Effect |
|---|---|---|
| **Floor** | killable in `≤ 2–3` shots with **T−1** weapon, inside its escape window; survivable in **T−1/entry** armor | new arrival earns immediately on the gear that got them in |
| **Mid** | killable in `~3–5` shots with **T** weapon; tense but safe in **T** armor | the routine band target (§5) |
| **Apex** | with **T** weapon solo, `ShotsToKill > KillWindow/CycleTime` (you die or it escapes); with **T+1** weapon (and T+1 armor lengthening the window) it just fits — *tense solo*; with **T** gear + party its effective Health splits and it dies fast — *trivial with a party* | the wall, the conquest target, the content moment |

**Worked illustration at an apex (all defaults, 1–100 scale).** Player base HP `100`. Apex raw Damage
`70`; with T-parity armor `DR ≈ 0.38` (apex behaves like a T+1 threat, §4 armor model) → `~43`/hit; at
a `~3 s` attack interval the survival window is `~7 s`. With a T weapon (`CycleTime ~1.2 s`) the player
gets `~5–6` shots; if the apex needs `~10` shots at T-weapon damage, it **can't be finished solo** —
correct. A **T+1 weapon** cuts `ShotsToKill` to `~6` *and* T+1 armor stretches the window to `~10 s` →
it just fits, *tense solo*. A **4-player party** at T gear lands `~20` shot-equivalents in the window
against the co-op-scaled Health (§6) → it drops fast, *trivial with a party*. The relationships hold;
the magnitudes are LOC_/EQUIPMENT calibration.

**Who owns what.** Combat owns this **formula and the band targets** (floor ≈ 2–3 shots at T−1, apex
not-soloable at T / soloable at T+1 / co-op at T). LOC_ docs set each creature's Health, Damage, Speed,
and KillWindow inputs to hit these bands; EQUIPMENT_MASTER sets weapon Damage/CycleTime/Range so a
tier's weapon produces the intended `ShotsToKill`. The **min weapon tier to kill** and **min armor tier
to survive** fields in Template C are then *derived* from this inequality, not authored by hand — a
creature's min-weapon-tier is the lowest tier whose mid-gear weapon satisfies `ShotsToKill ≤
KillWindow/CycleTime`, and its min-armor-tier is the lowest armor tier whose `DR` keeps the survival
window long enough for that kill.

### 4. Armor, survival, and death cost

**Effective HP / mitigation.** Player base HP is a fixed, server-owned `100`. Armor reduces incoming
damage:

```
DamageTaken = CreatureDamage · (1 − DR)
DR = clamp( DR_base + DR_step · (armorTier − creatureTier), 0, DR_cap )
```

*(defaults: `DR_base = 0.50` at tier parity, `DR_step = 0.12` per tier of gap, `DR_cap = 0.85`)*. So at
armor = creature tier, `DR 0.50`; one tier of armor advantage, `0.62`; one tier behind, `0.38`; two
behind, `0.26` (you get deleted — the intended punishment for under-armoring). Apexes are tuned to hit
*as if* one tier higher, which is why surviving a tier's apex comfortably wants that tier's-plus-one
armor (or co-op to cut your exposure).

**Tier-1 non-lethal floor (this doc owns the number).** Tier-1 floor creatures resolve their
Damage-to-player as **non-lethal**: a hard server clamp prevents an armorless player from being downed
by any Tier-1 floor creature (their cumulative damage cannot reduce the player below `1` HP). This is
the number that makes SYS_progression's "armorless new player computes EHT = 1 in the Bayou" true — the
Bayou is mechanically safe so onboarding never stalls on a death. Armor becomes a *survival* factor
from Tier 2 onward, matching armor becoming a *gating* slot at Tier 2.

**Death cost (light by design; ties to the revive sink, SYS_economy §1).** Death must sting enough to
make threat real but never enough to read as punitive (which the audience punishes — 00 §4). On being
downed:
- **Never** lose banked Cash or inventory items. (Punitive item loss would also poison the trade
  economy and is forbidden.) The only thing lost is the *current hunt* — a wounded animal escapes and
  any unbanked-kill-in-progress is forfeit.
- A short **downed/respawn**: respawn at the Destination's arrival point (or Lodge) after a brief timer
  — short enough to never feel like an energy-timer lockout.
- Optional **revive-in-place** to skip the walk back: a small **Cash revive** (sink; Cash amount is
  SYS_economy's) **or** an opt-in **rewarded-ad revive** (00 §4) — both are convenience, never required
  to keep playing. The free path (respawn-and-walk) always exists.

### 5. Engagement rate, spawn-density caps, and the rarity rule (the economy seam)

**ExpectedTargetsPerHour(T, hunting) — combat authors this.** Per Resolved Decision 4, combat owns the
*rate* a player engages routine huntable targets; economy divides `Income(T)` by it to compute per-
target Cash. The rate is built from the encounter clock:

```
TimePerTarget(T) = TimeToFind(T) + TimeToKill(T) + Overhead
ExpectedTargetsPerHour(T) = min( 3600 / TimePerTarget(T) , SpawnThroughputCeiling(Destination) )
```

`TimeToFind` rises with tier (targets get sparser and warier); `TimeToKill` rises with tier (tankier
targets) but is held near-constant *relative to gear* because the player gears up in step; `Overhead`
is repositioning/looting.

**Modeled rates, MVL tiers (illustrative, provisional — co-owned with SYS_economy, validate in
playtest):**

| Tier (Destination) | TimeToFind | TimeToKill (mid gear) | Overhead | TimePerTarget | **ExpectedTargetsPerHour** |
|---|---|---|---|---|---|
| 1 (Bayou) | ~25 s | ~10 s | ~10 s | ~45 s | **~80/hr** |
| 2 (Appalachia) | ~45 s | ~20 s | ~15 s | ~80 s | **~45/hr** |
| 4 (Alaska) | ~75 s | ~35 s | ~20 s | ~130 s | **~28/hr** |

The rate **declines** as tier rises; per-target Cash therefore rises faster than the rate falls, which
is consistent with `Income(T)` growing. These are the numbers SYS_economy reconciles against; this
table is the handoff.

**Spawn-density caps (binding invariant combat enforces — SYS_economy §5 hard dependency).** Each
Destination's huntable population is **finite and server-owned**: a `MaxConcurrentTargets` per spawn
area and a `RespawnInterval`, so target *availability* is bounded **independent of how fast the player
can kill**. The cap term `SpawnThroughputCeiling(Destination)` in the formula above is set by these.
The consequence is the economy's anti-farming guarantee: an over-geared Tier-4 player who one-shots
Tier-1 Bayou animals exhausts the local spawns and then waits on respawns, so their realized rate
collapses to `≈ Income(1)/hr` — strictly worse than hunting their own tier. **Without these caps the
band model breaks and low-tier farming prints money** (§5 of economy). This is a precondition, not a
tuning nicety: combat enforces caps server-side; LOC_ docs set the per-Destination density/respawn
values within this mechanism.

**Conformance to the rarity/band rule (Resolved Decision 5 — checked, conforms).** The income band is
normalized over the routine Common/Uncommon mix only; rares are bonus on top. The hunting encounter
model satisfies the two constraints this imposes:
- **(a) Routine spawns are stable.** Common/Uncommon targets come from the fixed-population +
  fixed-respawn model above — a *deterministic, stable* rate, not a per-kill RNG roll. Normalizing the
  band across them is therefore safe (it does not couple payouts to a lottery).
- **(b) Rares stay infrequent and *separate from the routine stream*.** Rare/Legendary/Mythic huntable
  spawns are **condition-gated, low-probability, independent spawns** (time-of-day / weather / season /
  event per Template E), layered *on top of* the routine population — **not** implemented as "every Nth
  kill upgrades to a rare." That distinction is load-bearing: a per-kill rare roll would couple rare
  frequency to kill *rate* and effectively fold rares into the routine stream, contradicting Resolved
  Decision 5. Keeping rares as separate condition-gated spawns lets them spike an hour *above*
  `Income(T)` as genuine upside while routine cadence — and the band — stays clean. **Combat will not
  ship a per-kill rare-upgrade mechanic;** rare encounters are always independent spawns. (No conflict
  to flag — the models agree.)

### 6. Co-op scaling

Big game is **soloable-but-tense with top gear, trivial with a party** (00 §9). The rule:

```
EffectiveHealth(N) = Health_base · (1 + h_coop · (N − 1))     capped at N = partyCap
```

*(defaults: `h_coop = 0.5`, `partyCap = 4`)*. Health scales **sublinearly** with party size while DPS
scales **linearly**, so a party is faster but never a free multiplier:
- Solo (`N=1`): full base Health — the tense, T+1-gear fight.
- Party of 4: Health `× 2.5` against `4×` DPS → roughly `1.6×` faster effective clear — clearly
  easier, but the animal still feels big and a party can't trivialize it to nothing or infinitely-zerg
  trivial content for linear speedup. Sublinear scaling is also what stops one high-tier player from
  turning an apex into a faceroll for a leeching group.

**Threat distribution.** The animal holds aggro on one player at a time and switches on threat events
(damage dealt, proximity), so a party shares survival risk and the fight has tactics (the tank takes
hits while others DPS, then swap) rather than everyone standing still. Apex attacks that would
otherwise one-shot are telegraphed AoE/charges the party can read and dodge — preserving the
legibility-of-death contract even in a group.

**Co-op gets the milestone, never the gear (inherited).** Carrying a friend to a conquest kill is the
intended incentive, but it yields the *milestone*, not the *gear tier* — the carried player still needs
their own gear to unlock the next Destination (SYS_progression's carry-proof property). Combat just
validates the kill; the gate stays gear-gated.

### 7. Behavior archetypes (Template C: passive | flees | aggressive | pack | ambush)

Each archetype is a behavior template (re-skinnable across tiers per SYS_progression §6) and taxes a
different skill:

- **Passive.** Ignores the player until shot; then flees or, rarely, retaliates. The easiest reward
  target; populates floors. Skill: clean first shot.
- **Flees.** Detects the player at a `detectionRadius` and breaks at `fleeSpeed`; rewards stealth,
  range, and leading a moving target. Drives `TimeToFind` up and teaches the value of range weapons and
  Mounts (to chase). Escape-bounded KillWindow.
- **Aggressive.** Charges and attacks; the survival threat where armor matters. Telegraphed wind-up
  before any heavy hit (legibility-of-death). Survival-bounded KillWindow.
- **Pack.** Several aggressive units with **shared aggro** that converge on the player. A pack's
  *combined* DPS exceeds a solo player's survive-while-killing budget *at-tier*, but a duo splitting
  aggro handles it — so an **early pack (Appalachia) is the game's natural co-op tutorial** (01): a
  legible "get a partner or over-gear" lesson placed *before* the Rockies/Alaska hard walls, taught by
  mechanics rather than text. Pack size and shared-aggro behavior are tuning parameters.
- **Ambush.** Concealed until the player is close, then a sudden high-damage strike from low
  visibility; rewards awareness, punishes autopilot. This is the Amazon "different feel" (01) and is
  **likely deferred past the MVL** (Bayou/Appalachia/Alaska don't need it; see Open Questions). When it
  ships, the reveal is still telegraphed in the final instant (a rustle/audio tell) so it reads as
  "I walked into that," not a random instakill.

### 8. Ambiance creatures — "grants nothing," enforced

Ambiance creatures (01, SYS_progression) exist for atmosphere and give **no reward**. The rule lives
upstream; combat owns *enforcement*, and it is enforced **server-side at the reward pipeline**, not by
hoping LOC_ docs leave fields blank:

- Every creature carries an authoritative `ambiance` flag. On a validated kill the server checks it
  first; if set, the reward path **early-returns**: **no Cash ledger entry, no Hunter Rank XP, no drop
  roll, no conquest/milestone credit.** An ambiance creature can therefore never be a milestone target,
  a faucet, or a rank-XP exploit.
- The kill still plays normal feedback (so killing one isn't *confusing*), but it is mechanically
  inert. There is **no penalty** either — we don't punish the player (which would read as arbitrary),
  we simply pay nothing. This is the subtle "identify worthwhile targets / don't mindlessly slaughter"
  signal (01) implemented as indifference, not as a fine.
- Ambiance spawns occupy world density for atmosphere but do **not** count against the reward-bearing
  `SpawnThroughputCeiling` — they can't be used to pad or starve the farmable population.

---

## Inputs / dependencies

- **00 / 01 / 02 / 04 / 05** — the retention-via-feel and 30-sec-legible bars (00 §0,§2,§3), the
  sell-with-the-player / no-punitive-death rule (00 §4), incentivized-not-forced co-op (00 §9), the
  1–100 stat scale and Template C creature fields, canonical terms (04), and the Gone-Hunting
  flat-treadmill / 8.6-min guardrail (05 §2) this system is built to beat.
- **SYS_progression v2.1** — the floor/ceiling rule combat implements; EHT = `min(weapon, armor)`;
  armor gates from Tier 2 and the Tier-1 armorless allowance (combat owns the no-lethal-floor number);
  apex = T+1 solo / T + co-op; ambiance grants nothing; milestone is earned-in-play and server-
  validated; carry-proof co-op.
- **SYS_economy v2.1** — `Income(T)` (combat produces the rate it's divided by); Resolved Decision 4
  (reconciliation seam — combat authors `ExpectedTargetsPerHour`, never Cash); Resolved Decision 5
  (rarity/band — combat's encounter model conforms, §5); the **spawn-density hard dependency** (combat
  enforces the cap); the revive sink (death cost ties to it); the not-a-timer rule (no target takeable
  only with a premium consumable).
- **EQUIPMENT_MASTER** — weapon Damage / Range / settle-time / CycleTime and armor DR-by-tier; combat
  **consumes** these stats and does not author them. (Combat hands EQUIPMENT_MASTER the *damage-model
  formula and the shots-to-kill targets* its stats must produce.)
- **LOC_ docs** — per-creature Health / Damage / Speed / behavior / spawn condition, per-Destination
  spawn density + respawn values (set within combat's cap mechanism), and the milestone-target
  designation; all stat to combat's bands.
- **SYS_data_integrity** — the server-authority and anti-dupe/anti-exploit substrate kill validation is
  built on.
- **SYS_fishing** — parallel loop; mechanically distinct (no death threat, sustained reel vs. discrete
  shot) but reconciled to the *same* `Income(T)` band, and **sharing the floor/ceiling spread-growth
  constant** so the two loops stay parallel as tiers climb.

---

## Outputs / what depends on this

- **LOC_ docs** — consume the archetypes, the floor/mid/apex shot-count bands, the kill/survival
  threshold inequality (to derive each creature's min-weapon/min-armor-tier), the Tier-1 non-lethal
  rule, and the spawn-cap mechanism (to set densities). They populate; they do not redefine the math.
- **SYS_economy** — consumes `ExpectedTargetsPerHour(T, hunting)` (§5 table) to compute hunting
  payouts, and the confirmation that the encounter model satisfies Resolved Decision 5.
- **EQUIPMENT_MASTER** — consumes the damage model and shots-to-kill targets so weapon Damage/CycleTime
  per tier produce the intended floor/ceiling outcomes; provides the settle/recoil stats combat reads
  back.
- **SYS_progression** — receives the realized floor/ceiling (telemetry confirming apex = T+1 solo / T
  co-op) as the feedback that validates its rule in practice.
- **SYS_onboarding_funnel** — consumes the punchy Tier-1 first-kill feel, the non-lethal Bayou, and the
  ~60-second first kill as the funnel's reward beat.
- **SYS_data_integrity** — consumes the kill-validation and anti-exploit requirements (§build notes) as
  build spec for the validation layer.
- **SYS_liveops_calendar** — consumes archetype/re-skin reuse and the telegraphed-wall pattern for
  cheap new combat content, and the condition-gated rare-spawn model for event spawns.

**Out of scope (named, not designed):** item stats/prices (EQUIPMENT_MASTER); specific creatures per
Destination (LOC_); Cash values (SYS_economy); fishing mechanics (SYS_fishing); persistence/anti-dupe
implementation (SYS_data_integrity — combat states the requirement, that doc builds it).

---

## Tuning parameters

- **Hit zones:** `Z_vital` *(2.5)*, `Z_body` *(1.0)*, `Z_limb` *(0.5)*; vital-zone size per
  tier/creature.
- **Aim/cycle:** reticle settle-curve shape (per-weapon settle stat is EQUIPMENT's); recoil magnitude
  per class; `CycleTime` composition (settle + recovery + reload).
- **Range:** optimal-range band width and falloff slope/floor.
- **Threshold reference:** `Z_expected` used to *derive* min-weapon-tier (the assumed skill level for
  the floor/ceiling computation).
- **Survival:** player base HP *(100)*; armor `DR_base` *(0.50)*, `DR_step` *(0.12)*, `DR_cap` *(0.85)*;
  the apex "behaves-as-+1-tier" threat offset.
- **Tier-1 non-lethal-floor clamp** (the rule + any chip-damage value).
- **Co-op:** `h_coop` *(0.5)*, `partyCap` *(4)*; aggro-switch thresholds; apex telegraph timings.
- **Archetypes:** flee `detectionRadius` / `fleeSpeed`; pack size + shared-aggro radius; ambush conceal
  range + reveal-burst multiplier; per-archetype KillWindow definitions.
- **Engagement rate:** `ExpectedTargetsPerHour(T, hunting)` and its `TimeToFind` / `TimeToKill` /
  `Overhead` components per tier *(§5 table)* — co-owned with SYS_economy, the drift-prone input.
- **Spawn caps:** `MaxConcurrentTargets` and `RespawnInterval` per spawn area → `SpawnThroughputCeiling`
  per Destination (mechanism here; values in LOC_).
- **Mobile:** aim-assist strength and cone, with a cap; platform-split fairness target.
- **Death/revive:** downed-timer length; Cash revive price *(amount is SYS_economy's)*; ad-revive
  availability.
- **Rare encounter:** per-rare spawn probability and spawn condition *(Template E; combat owns that
  they're independent condition-gated spawns, not per-kill rolls)*.

---

## Claude Code build notes

**Server-authority over every kill is absolute** (ties to SYS_data_integrity and SYS_progression's
milestone validation). The server owns creature Health and resolves every shot: it validates the shot
ray against the **authoritative** player position/orientation and weapon at fire time, applies damage
from the **equipped weapon's authoritative stats**, and is the only party that declares a creature
dead. The client predicts hits for responsiveness (show the impact immediately) but **never asserts a
kill** — a client message "I killed creature X" is ignored; the kill is a server-emitted event carrying
creature id, tier, rarity, hit data, and the validating context.

**Anti-exploit, server-side:**
- **Damage spoofing:** reject any damage not derivable from the equipped weapon's stats × a legal zone
  × range — a client claiming 999 damage is dropped.
- **Fire-rate hacks:** enforce `CycleTime` server-side; shots arriving faster than the weapon allows
  are rejected.
- **Geometry/LOS:** validate the target was in valid line-of-fire and range from the authoritative
  position; reject through-wall / out-of-range kills.
- **Spawn authority:** the server owns the spawn population, positions, and respawn timers; the client
  cannot spawn, force, or relocate targets. This is also where the **spawn-density cap is enforced** —
  it is an economy-critical invariant, not cosmetic.

**Reward pipeline (server-side, ordered):** on a validated kill → check `ambiance` (if set,
early-return, zero reward) → compute Cash via SYS_economy's `Payout` formula and write an atomic
ledger entry → award Hunter Rank XP (active-play only) → roll drops → if the target is a legal
milestone for the current Destination, set the conquest flag (idempotent — re-killing never
re-triggers). Rare kills additionally fire the clean-kill content-moment feedback.

**Rare spawns are independent, condition-gated server spawns** — never a per-kill upgrade roll (Resolved
Decision 5 conformance, §5). Implement them as their own spawn entries with time/weather/season/event
predicates, layered on the routine population.

**Telemetry — wire alongside, not after (00 §0, 01 risk #3, and the MVL difficulty risk below):**
- **Per-tier kill success rate** (hits-on-target, kills-per-encounter) and **accuracy distribution** —
  the skill-floor health check.
- **Death rate per tier and per archetype** — the primary difficulty-cliff alarm; a spike at a specific
  tier/creature means a wall, not a challenge.
- **Time-to-kill per target per tier vs. modeled** — feeds the economy reconciliation; divergence on
  hunting is the dual-loop-drift signal (must be compared against SYS_fishing at the same tier).
- **Actual targets/hour per tier vs. modeled `ExpectedTargetsPerHour`** — a high reading at a *low*
  tier flags a missing/mis-set spawn cap (a low-tier-farming hole).
- **Co-op vs. solo apex-completion rate** — validates the soloable-tense / trivial-with-party tuning; if
  solo apex completion is ~0 at MVL, that is *expected* for Alaska (see flag) but a problem elsewhere.
- **Aim-assist accuracy split by platform** — mobile-vs-desktop fairness; assist must not let mobile
  trivialize rares.

**MVL difficulty check — Appalachia (T2) → Alaska (T4), the two-tier jump (this doc's owed check).**
SYS_economy verified the *Cash* gap (~1.7×, passes); combat owes the *difficulty* gap. The result:
**it passes, because the player enters Alaska already holding T4 gear** — the gate requires `EHT ≥ 4`
to unlock, so the player gears to T4 *before* arrival, and Alaska's floor (takeable with T−1 = T3) is
comfortable on T4 gear. The jump is a *purchase* step, not a difficulty cliff. Two conditions make this
hold and are **binding on LOC_04 and EQUIPMENT_MASTER:** (1) Alaska's floor/mid creatures must be
statted so T4 gear clears them at the normal shot-count bands — i.e. the difficulty *within* Alaska is
normal-for-its-tier, not inflated to "punish" the skip; and (2) every Alaska lethal threat is
telegraphed (no random one-shots), so the higher absolute damage reads as legible. **The one real
caveat is the apex** — see the flag below. Instrument the Appalachia→Alaska transition specifically:
death-rate and time-to-conquer at the jump are the canaries.

---

## Open questions / flags

1. **MVL Alaska's conquest milestone must NOT be the grizzly apex (highest-priority downstream flag).**
   SYS_progression's rule is apex = T+1 gear solo OR T + co-op. **At the MVL, Alaska is the top tier —
   T5 gear does not exist yet.** So the grizzly apex has **no solo route** until post-launch gear ships.
   If the conquest milestone *were* the apex, a pure-solo player could never conquer Alaska and so could
   never advance the Passport — which breaks progression's "milestone is non-skippable *but reachable*"
   guarantee, and is worse at soft-launch when co-op partners are scarce (low CCU). **Resolution to hand
   LOC_04:** designate a **T4-soloable signature creature** (a caribou or moose) as Alaska's conquest
   milestone, and make the **grizzly a co-op apex / content moment with no solo route until T5 gear
   ships**. This keeps the gate solo-completable *and* preserves a co-op-incentivized trophy kill. Both
   SYS_progression and SYS_economy assumed the milestone is reachable; this is the combat-side condition
   that makes that true at MVL.

2. **`ExpectedTargetsPerHour(T, hunting)` (§5 table) is modeled, not measured** — provisional until
   playtest, co-owned with SYS_economy, and load-bearing for dual-loop balance: it **must** land at the
   same realized `Income(T)` as SYS_fishing's rate at each tier, or one loop out-earns the other and
   half the content dies (01 risk #3). First joint-tuning target post-soft-launch.

3. **Aim-assist is a fairness *and* economy knob.** Too strong on mobile trivializes rares and inflates
   effective targets-per-hour (touching the economy via the rate); too weak makes the game unplayable on
   a phone. Needs platform-split telemetry and a cap. Flag for playtest.

4. **Co-op population at soft launch.** A co-op-gated apex is thin at low CCU. Flag #1 (solo-completable
   *milestone*) protects progression; the grizzly itself may simply go unkilled by many early solo
   players, which is acceptable (it's an aspirational trophy). **Do not** add NPC-assist or matchmaking
   at MVL (scope); revisit with SYS_liveops if data shows the apex is effectively dead content.

5. **Death/revive exact magnitudes** — confirm with SYS_economy that the downed timer is short and the
   revive Cash price is light, and lock the rule that death **never** costs banked Cash or items. My
   recommendation stands: respawn-and-walk free path always available; optional Cash-or-ad revive-in-
   place; no item/Cash loss ever.

6. **Ambush archetype in MVL?** Bayou/Appalachia/Alaska don't need it; it's the Amazon "low-visibility
   ambush" feel. Recommend **deferring ambush to post-MVL** and shipping the MVL on passive/flees/
   aggressive/pack. Confirm at LOC_04/LOC_06.

7. **Projectile vs. hitscan per weapon class.** MVL rifles are **hitscan-with-settle** (mobile-friendly).
   Bows/shotguns/throwing weapons may want projectile-with-lead for feel — deferred to EQUIPMENT_MASTER
   + a later pass; flag so it isn't assumed hitscan-only forever.

8. **Floor/ceiling spread-growth constant is shared with SYS_fishing.** The rate at which
   `Ceiling(T) − Floor(T)` widens per tier (SYS_progression §5) must use the **same constant** in combat
   and fishing, or the two loops diverge in felt difficulty as tiers climb. Coordinate the value with
   SYS_fishing; don't set it unilaterally here.
