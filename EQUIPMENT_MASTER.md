# EQUIPMENT_MASTER — The Canonical Item Catalog

> **Role.** This is the convergence doc. Every prior system authored *rules*; this doc populates the
> *numbers* those rules consume — and proves a single set of stat curves satisfies SYS_combat (v1.1),
> SYS_fishing (v1.1), SYS_economy (v2.1), and SYS_progression (v2.1) **simultaneously**. It is the
> item table the build and all `LOC_*` docs read. It does **not** own the damage/catch *math*
> (SYS_combat/SYS_fishing — consumed here), the Cash *curve* (SYS_economy — consumed here), or the
> *creatures/fish* (LOC_ docs — they stat targets to the bands here).
>
> **Conventions (binding, from 02/04).** Currency = **Cash**. Weight = **kg**. Stats on **1–100**.
> Rarity: Common→Uncommon→Rare→Epic→Legendary→Mythic. Tier = integer 1–8+. Canonical vendor/term names
> per 04 (Outfitter, Tackle Shop, Boat Dealer, Kennel & Stable, Boat, Mount, Tracking Dog).
>
> **Numbers convention (matches the SYS_ docs).** Framework + illustrative defaults. The **formulas and
> relationships are the design**; every magnitude is a calibration knob marked *(default)*. **Tier 2 is
> fully worked** as the proof; all other tiers are generated from the formulas and flagged
> *illustrative-default*, with cross-system checks **asserted-by-construction** (the formula guarantees
> them) rather than hand-worked.
>
> **One unresolved conflict is surfaced, not hidden** — the 1–100 scale saturates inside the ladder
> (Open Question A). It changes no MVL gate outcome (tiers 1–4) — the only MVL stat it touches is the
> maxed T4 rod (108 → clamped 100), which alters no result; it must be ratified by combat/fishing before
> any tier ≥ 5 ships. Tiers 1–4 are build-ready.

---

## 0. What this doc inherits as binding (the four Resolved-Decision blocks, condensed)

| Source | The constraint this doc must satisfy |
|---|---|
| **progression** | `EHT=min(weapon,armor)`, `EFT=min(rod,reel)` — the two gating slots per loop must be **priced and statted in step** (neither far ahead). Armor is **not** a gating slot at Tier 1 (empty armor = Tier 1 below the armor-gating start tier). Free Tier-1 starter weapon + rod + reel exist. Floor takeable at **T−1** gear; apex needs **~T+1 solo OR T + co-op**. Intra-tier-maxed = apex-**capable with co-op**, never a milestone skip (pay-proof / carry-proof). Bait/Mounts/Dogs/Boats are **never** effective-tier inputs. |
| **combat** | Stats feed `ShotsToKill = ceil(Health / (WeaponDamage·Z·RangeFalloff))` and `DR = clamp(DR_base + DR_step·(armorTier−creatureTier), 0, DR_cap)`. **A: Alaska (T4) is the MVL top tier — no T5 gear exists at launch; the grizzly apex is co-op-only.** **D: MVL weapons are hitscan-with-settle; projectile classes (bows/shotguns/throwing) are deferred** — catalogued here as post-MVL, tagged. **F: the floor/ceiling spread-growth constant κ is shared with fishing**, owned jointly. Death never costs Cash/inventory (B). |
| **fishing** | Stats feed `FightTime ≤ LandWindow`, with **reel = weapon-analog** (Line Speed/Drag → shortens FightTime) and **rod = armor-analog** (Pressure → lengthens LandWindow; a snap is the window closing). **Decision 7: king salmon (T4) is Alaska's soloable fishing milestone; the giant halibut is co-op-only (no T5 reel).** **Decision 4: premium bait is capped at Uncommon bias — never raises Legendary/Mythic rate, never mandatory.** Boats gate **water type** (pond/river/lake = none; coastal = first Boat; deep sea = ocean Boat). |
| **economy** | `Income(T)=B·g^(T−1)`. Tier-gating slot price = `c·Income(T−1)`. Intra-tier climb per loop = `m·Income(T)`. `RarityMultiplier` ladder fixed. Boats/Mounts/Dogs = **big one-time access/convenience sinks, never pay-to-win**. Cosmetics = **balance-free evergreen inflation ballast**, continuously replenished. The not-a-timer rule: no target takeable *only* with a premium consumable. All item stats **server-authoritative**; schema **data-driven config** so Tier 9+ and new items drop in without code. |

---

## 1. The master tuning parameters (every stat-curve constant lives here)

All curves are **pure functions of tier `T` and intra-tier level `ℓ ∈ {entry, mid, maxed}`**, so Tier 9+
and new items are config rows, not code. `mid` is the band-reference level the economy/rate models assume.

### 1.1 Shared difficulty constant (combat + fishing, RD-F)
- **`κ` — spread-growth constant** *(default geometric base ρ = 1.4 for offensive curves; additive
  `P_step = 22` for the defensive/Pressure curve — see 1.4 for why offense is geometric and defense
  additive)*. This is the single knob that sets how fast `Ceiling(T) − Floor(T)` widens. **Owned jointly
  with combat/fishing; do not change here unilaterally.**

### 1.2 Offensive curves — weapon (hunting) and reel (fishing)
```
WeaponDamage(T, ℓ)   = round( D1 · ρ^(T−1) · q(ℓ) )      D1 = 18 (default), ρ = 1.4
ReelDrainMax(T, ℓ)   = round( R1 · ρ^(T−1) · q(ℓ) )      R1 = 9  (default), ρ = 1.4 (shared)
q(entry)=0.78 · q(mid)=1.0 · q(maxed)=1.28               (intra-tier floor→apex spread ≈ 1.6×)
```
`WeaponDamage` is the value combat's `ShotsToKill` consumes. `ReelDrainMax` sets `NetDrain` and so
`FightTime`. Reel mirrors weapon by construction → the two offensive loops scale identically (the
dual-loop balance is structural, not coincidental).

### 1.3 Weapon cycle/range (set TimeToKill and TimeToFind)
```
CycleTime(T)   = settle + recovery + reload   (default sec) : T1 1.5 · T2 1.4 · T3 1.3 · T4 1.25 · then −0.04/tier, floor 1.0
SettleTime(T,ℓ): faster at higher T and higher ℓ (the patience-tax; per-weapon, tunable)
Range(T)       = 36 + 12·(T−1) on 1–100 (optimal-range band midpoint); RangeFalloff = 1.0 in-band, declining to floor 0.4 beyond
```
Higher tiers settle/cycle slightly faster (better gear) **and** reach farther — which offsets warier,
farther-fleeing higher-tier game, holding `TimeToKill` near-constant *relative to gear* (combat §5).

### 1.4 Defensive curves — armor (hunting) and rod Pressure (fishing)
```
Armor: the gating input is armorTier; DR is DERIVED by combat's model, NOT a raw stat —
       DR = clamp(0.50 + 0.12·(armorTier − creatureTier), 0, 0.85).
       Template-B "Protection 1–100" is a within-tier readout only (display); the math uses tier.
Rod:   BreakThreshold(T, ℓ) = round( (P1 + P_step·(T−1)) · pq(ℓ) )   P1 = 30, P_step = 22 (default)
       pq(entry)=0.90 · pq(mid)=1.0 · pq(maxed)=1.12
       LandWindow = w · max(BreakThreshold − PeakRunForce, 0) · dragSmooth(reel),  w = 1.0
```
**Why offense is geometric and defense additive:** combat's DR model is *additive in tier gap* and
**hard-capped at 0.85**, so defense is inherently bounded — that boundedness is what makes the apex
"behaves-as-+1-tier" trick necessary and is the reason armor must climb with the threat, not ahead of
it. Rod Pressure mirrors that additive shape so rod and armor stay analogs. *(This asymmetry is the
direct cause of Open Question A: the additive Pressure curve reaches the 1–100 cap first — maxed already
at **T4**, mid at **T5** — while the geometric offensive curves saturate later and unevenly: weapon at
**T6–T7**, reel not until **T8**.)*

### 1.5 Fishing fight constants (consumed by `FightTime ≤ LandWindow`)
```
StaminaToLand(fish) = k_s · FightDifficulty · (1 + weight/W_ref)     k_s = 0.5,  W_ref = 10 kg
NetDrain(reel,fish) = ReelDrainMax(reel) · E_expected − FishRecovery(fish)
FishRecovery(fish)  = r · FightDifficulty       r = 0.08
PeakRunForce(fish)  = p · FightDifficulty       p = 0.6
E_expected = 0.7  (tension-efficiency derivation reference; analog of Z_expected)
```

### 1.6 Skill reference for min-tier derivation
- **`Z_expected = 1.0` (= `Z_body`)** *(default)*. Min-weapon/min-armor tiers are derived assuming the
  reference player lands **body shots** — the conservative floor of capability. Vital-hit skill
  (`Z_vital = 2.5`) is *upside* that lets a good player do it with less gear; the gate must clear the
  target even for a mediocre shot. (Same logic on fishing via `E_expected`.) **If playtest shows the
  median player lands vitals routinely, raise `Z_expected` here and re-derive — it is the single knob
  that shifts every min-tier at once.**

### 1.7 Economy constants (consumed, not owned — from SYS_economy)
```
Income(T) = B·g^(T−1),  B = 1,000,  g = 1.7
GearCost_slot(T) = c·Income(T−1),  c = 3   (T ≥ 2; Tier-1 gating items are free starter loadout)
IntraTierClimb(T) per loop ≈ m·Income(T),  m = 2.5
RarityMultiplier: Common 1 · Uncommon 1.6 · Rare 2.8 · Epic 5 · Legendary 9 · Mythic 16
```

### 1.8 Generated stat tables (all tiers, from §1.2/§1.4 — illustrative-default)

| T | Weapon Dmg (entry/mid/maxed) | Reel Drain (e/m/m) | Rod Pressure (mid) | CycleTime | Range |
|---|---|---|---|---|---|
| 1 | 14 / 18 / 23 | 7 / 9 / 12 | 30 | 1.50 | 36 |
| 2 | 20 / 25 / 32 | 10 / 13 / 16 | 52 | 1.40 | 48 |
| 3 | 28 / 35 / 45 | 14 / 18 / 23 | 74 | 1.30 | 60 |
| 4 | 39 / 49 / 63 | 19 / 25 / 32 | 96 | 1.25 | 72 |
| 5 | 54 / 69 / 89 | 27 / 35 / 44 | 118 ⚠ | 1.21 | 84 |
| 6 | 76 / 97 / 124 ⚠ | 38 / 48 / 62 | 140 ⚠ | 1.17 | 96 |
| 7 | 106 ⚠ / 136 ⚠ / 173 ⚠ | 53 / 68 / 87 | 162 ⚠ | 1.13 | 100⚠ |
| 8 | 148 ⚠ / 190 ⚠ / 243 ⚠ | 74 / 95 / 121 ⚠ | 184 ⚠ | 1.10 | 100⚠ |

⚠ = exceeds the 1–100 cap → **Open Question A** territory. Saturation order by curve: **rod (additive)
first — maxed at T4 (108), mid at T5 (118); weapon (geometric) at T6 (maxed) → T7; reel (geometric,
half-magnitude) only at T8 (maxed).** **MVL gate outcomes hold; the one MVL value that reaches the cap is
the maxed T4 rod (108 → clamped 100), and clamping it changes no T4 gate result** (§4.3). Past T4 the raw
1–100 numbers must be read as the re-based form in OQ-A (within-tier quality × config `TierCoefficient`),
not as literal 1–100 stats.

---

## 2. Economy reconciliation — every gating price, from the curve

Each tier-gating slot = `c·Income(T−1)`. A loop's two slots cost the same (weapon=armor, rod=reel) — the
price symmetry is what enforces buying **in step** (the `min` rule has no cheaper corner). Intra-tier
climb per loop = `m·Income(T)`, distributed across the discrete upgrade steps (early steps cheaper for
first-five-minutes dopamine, geometric within the tier).

| T | Income(T) | Gating slot `c·Income(T−1)` | Hunter pair (wpn+armor) | Fisher pair (rod+reel) | Intra-tier climb/loop `m·Income(T)` |
|---|---|---|---|---|---|
| 1 | 1,000 | — (free starter; **no armor cost**) | 0 | 0 | 2,500 |
| 2 | 1,700 | **3,000** | 6,000 | 6,000 | **4,250** |
| 3 | 2,890 | 5,100 | 10,200 | 10,200 | 7,225 |
| 4 | 4,913 | 8,670 | 17,340 | 17,340 | 12,283 |
| 5 | 8,352 | 14,739 | 29,478 | 29,478 | 20,880 |
| 6 | 14,199 | 25,056 | 50,112 | 50,112 | 35,498 |
| 7 | 24,138 | 42,597 | 85,194 | 85,194 | 60,345 |
| 8 | 41,034 | 72,414 | 144,828 | 144,828 | 102,585 |

Tier 9+ inherits the same formulas untouched **on the Cash axis** (the stat axis does not — OQ-A).

---

## 3. THE FULLY WORKED TIER — Tier 2 (Appalachia), end to end

Everything below uses the §1 constants. This proves one stat set satisfies all four systems at once.
Illustrative creature/fish stats are LOC_02's to finalize; they are asserted here to the bands so the
reconciliation is demonstrable. `Z_expected = 1.0`, `RangeFalloff = 1.0` (in-band).

### 3.1 Combat check — `ShotsToKill = ceil(Health / (WeaponDamage·Z·RangeFalloff))`

T2 weapon (Lever-Action Rifle): Damage **25** (mid), **32** (maxed); T1 starter rifle Damage **18**;
T3 weapon Damage **35**. CycleTime: T2 1.40 s, T3 1.30 s.

- **Floor — Whitetail Deer** (passive/flees, Health **50**). With **T1** gear: `ceil(50/(18·1·1)) = 3`
  shots; with T2 entry (20): `3`. → **≤ 2–3 at T−1.** ✓ A new arrival earns immediately on the gear
  that got them in.
- **Mid — Boar** (aggressive, Health **88**, Damage-to-player 40, attack interval 3.0 s). With **T2**
  gear: `ceil(88/(25·1)) = 4` shots → **3–5 at T.** ✓ Survival in T2 armor: `DR = 0.50` (parity),
  `taken = 40·0.50 = 20`/hit → 5 hits to down → ~12 s window ≫ 4·1.40 = 5.6 s kill time. **Tense but
  safe in T armor.** ✓
- **Apex — T2 conquest-class predator** (aggressive, Health **100**, Damage-to-player **76**, interval
  2.7 s, *behaves-as-T3* per the armor model).
  - **Solo at T2:** `ShotsToKill = ceil(100/25) = 4` (and **even maxed**, `ceil(100/32) = 4`). Survival:
    `DR = clamp(0.50 + 0.12·(2−3)) = 0.38`, `taken = 76·0.62 = 47.1` → 3 hits to down → window ≈ 2
    intervals = 5.4 s → `window/CycleTime = 5.4/1.40 = 3.86`. **`4 > 3.86` → NOT soloable at T2, even
    intra-tier-maxed.** ✓ (Maxing gets you apex-*capable*, not a solo kill — pay-proof.)
  - **Solo at T3:** `ceil(100/35) = 3` shots; `DR = 0.50` (parity) → `taken = 38` → 3 hits → window 5.4
    s → `5.4/1.30 = 4.15`. **`3 ≤ 4.15` → soloable, tense.** ✓ (apex needs ~T+1 solo)
  - **Co-op at T2:** aggro switches between party members (your exposure drops) and `EffectiveHealth(4)
    = 100·(1+0.5·3) = 250` against 4× DPS → drops fast. **Trivial with a party.** ✓

### 3.2 Armor check — the DR model holds the survival window

T2 armor keeps the survival window long past the kill time for the **mid** (boar: 12 s window vs 5.6 s
kill), and the apex's *behaves-as-T3* offset (`DR 0.38`, 62% damage taken) is exactly what makes T2
armor insufficient for the apex while T3 armor (`DR 0.50`) makes it survivable — the forced-progression
pressure, expressed in the binding `DR_base 0.50 / DR_step 0.12 / DR_cap 0.85` model. No new armor math;
this is the model consuming the tier stat.

### 3.3 Fishing check — `FightTime ≤ LandWindow`

T2 rod Pressure (BreakThreshold) **52**; T2 reel DrainMax **13**; T1 rod 30 / reel 9; T3 rod 74 / reel
18. `E_expected = 0.7`.

- **Floor — Panfish** (FightDifficulty 30, 1 kg). `Stamina = 0.5·30·1.1 = 16.5`; `NetDrain = 9·0.7 −
  2.4 = 3.9` → `FightTime = 4.2`; `LandWindow = max(30 − 18, 0) = 12`. With **T1** gear `4.2 ≤ 12` →
  **landable at T−1.** ✓
- **Mid — Trophy Bass** (FightDifficulty 60, 4 kg). `Stamina = 42`; **T2** `NetDrain = 13·0.7 − 4.8 =
  4.3` → `FightTime = 9.8`; `LandWindow = max(52 − 36, 0) = 16`. `9.8 ≤ 16` → **landable at T.** ✓ With
  **T1** gear: `LandWindow = max(30 − 36, 0) = 0` → **snap** (and `NetDrain` only 1.5 → `FightTime 28`).
  **Both slots must clear → needs T2** (the `min` rule, mechanically grounded). ✓
- **Apex — Record Muskie** (FightDifficulty 90, 9 kg; rod-leaning). `Stamina = 85.5`. **T2:** `NetDrain
  = 13·0.7 − 7.2 = 1.9` → `FightTime = 45`; `LandWindow = max(52 − 54, 0) = 0` → **snap.** Even **T2
  maxed** (rod 58, reel 16): `LandWindow = max(58 − 54, 0) = 4`, `FightTime = 21.4` → `21.4 > 4` →
  **still fails.** ✓ **T3:** `NetDrain = 18·0.7 − 7.2 = 5.4` → `FightTime = 15.8`; `LandWindow = max(74
  − 54, 0) = 20` → `15.8 ≤ 20` → **landable, tense** (or T2 + co-op assist adding NetDrain). ✓

### 3.4 Economy check — prices match the curve

Every T2 gating item costs `c·Income(1) = 3·1,000 = **3,000**`/slot. A hunter buys weapon + armor =
**6,000** (EHT 2); a fisher buys rod + reel = **6,000** (EFT 2). On `Income(1) = 1,000/hr`,
time-to-afford = `6,000/1,000 = 6 hrs = 2c`. ✓ The intra-tier climb from T2-floor to T2-ceiling stats
totals `m·Income(2) = 2.5·1,700 = **4,250**` per loop, distributed across the discrete upgrade steps. ✓
Both match the SYS_economy targets to the digit.

### 3.5 The `min`-rule, priced and statted in step

Weapon and armor at T2 cost the same (3,000) and advance on paired curves, so a player can't profitably
buy one far ahead of the other — `EHT = min(weapon, armor)` has no cheap corner to exploit. Identical
for rod/reel. This is the equipment-side enforcement of progression's weakest-slot rule.

---

## 4. THE MVL EQUIPMENT LINE — full Template B blocks (Tiers 1–4, what ships)

These are the items the build instantiates for the Minimum Viable Loop (Bayou → Appalachia → Alaska).
Stats from §1; all flagged *illustrative-default* except the fully-worked T2 line.

### 4.1 Hunting weapons (hitscan-with-settle — the only MVL weapon class, combat RD-D)

#### Starter Rifle (Bolt .22)
- **Category:** weapon
- **Tier:** 1
- **Available at:** free starter loadout (spawned with it; never purchased)
- **Cost:** 0 Cash
- **Primary stat(s):** Damage 18/100 (mid) · Range 36/100 · CycleTime 1.5 s
- **Weight:** 3 kg
- **Strengths:** clears all Bayou floor game (rabbits, ducks); the ~60-second first-kill weapon
- **Weaknesses / limits:** too slow-cycling and low-damage for Appalachia's aggressive game (boar = 5
  shots at this damage, loses the survival window)
- **Gates unlocked:** none (EHT 1 on arrival, with armorless allowance)
- **Monetization role:** — (free; onboarding)
- **Notes:** intra-tier upgrades (better barrel/optic) exist even at T1 — the *first* purchasable
  upgrade is the minute-one soft-monetization beat (§2 intra-tier climb T1 = 2,500 Cash total)

#### Lever-Action Rifle  *(fully worked, §3)*
- **Category:** weapon
- **Tier:** 2
- **Available at:** Outfitter
- **Cost:** 3,000 Cash (gating; `c·Income(1)`); intra-tier climb +4,250 to ceiling
- **Primary stat(s):** Damage 20→25→32/100 (entry/mid/maxed) · Range 48/100 · CycleTime 1.4 s
- **Weight:** 4 kg
- **Strengths:** kills Appalachia floor (deer, 3 shots at T1 already) and mid (boar, 4 shots, safe in
  T2 armor); the first real-commitment weapon
- **Weaknesses / limits:** cannot solo the T2 apex even maxed (4 shots vs 3.86-shot window); no use
  against T3+ tankier/faster game
- **Gates unlocked:** contributes to EHT 2 → Appalachia (with T2 armor)
- **Monetization role:** power-progression (the gate) + convenience (the intra-tier climb)
- **Notes:** the worked proof item; cosmetic wood/blued variants sold separately (identity, zero stats)

#### Scoped Hunting Rifle
- **Category:** weapon
- **Tier:** 3
- **Available at:** Outfitter
- **Cost:** 5,100 Cash (`c·Income(2)`); intra-tier climb +7,225
- **Primary stat(s):** Damage 28→35→45/100 · Range 60/100 · CycleTime 1.3 s
- **Weight:** 4.5 kg
- **Strengths:** solos the T2 apex (3 shots, tense) and clears Rockies floor/mid; the longer range
  starts to matter for warier game
- **Weaknesses / limits:** insufficient for Alaska apex (grizzly); designed to clear Alaska floor only
  as the T−1 weapon
- **Gates unlocked:** EHT 3 → Rockies (post-launch); is the T−1 weapon that makes Alaska's floor
  comfortable
- **Monetization role:** power-progression + convenience
- **Notes:** *post-launch in the strict MVL chain (Rockies is inserted later); shipped in the catalog so
  the Bayou→Appalachia→Alaska two-tier jump has the correct T−1 reference for Alaska's floor*

#### Heavy Expedition Rifle
- **Category:** weapon
- **Tier:** 4
- **Available at:** Outfitter (Alaska-region variant: cold-rated furniture, cosmetic)
- **Cost:** 8,670 Cash (`c·Income(3)`); intra-tier climb +12,283
- **Primary stat(s):** Damage 39→49→63/100 · Range 72/100 · CycleTime 1.25 s
- **Weight:** 6 kg (heavy — pairs naturally with a Mount for traversal; convenience tie, not a gate)
- **Strengths:** clears Alaska floor (2 shots at T3-floor creatures) and the **caribou/moose milestone**
  (3 shots, safe in T4 armor — the soloable conquest target, RD-A)
- **Weaknesses / limits:** **does NOT solo the grizzly apex** — 3 shots but the apex (behaves-as-T5)
  downs you in ~2 hits through T4 armor, and **no T5 weapon exists at MVL** to fix it → grizzly is
  co-op-only (RD-A). Stat accordingly: this weapon clears floor/mid/milestone, not the apex.
- **Gates unlocked:** EHT 4 → Alaska (with T4 armor; Boat gates only the coastal *fishing* sub-area)
- **Monetization role:** power-progression + convenience
- **Notes:** the MVL top hunting weapon; T5 ships post-launch and is what finally solos the grizzly

### 4.2 Hunting armor (gates from Tier 2; DR derived, not a raw stat)

#### Field Jacket
- **Category:** armor
- **Tier:** 2 · **Available at:** Outfitter · **Cost:** 3,000 Cash (`c·Income(1)`); intra-tier +included in the 4,250 loop climb
- **Primary stat(s):** Protection 30/100 *(within-tier readout)*; **functional DR vs T2 = 0.50** (parity, derived)
- **Weight:** 3 kg
- **Strengths:** survives the T2 mid (boar: 12 s window) — makes Appalachia's first aggressive game safe
- **Weaknesses / limits:** vs the T2 apex (behaves-as-T3) DR drops to 0.38 → you take 62% → downed
  before the kill. Under-armoring is punished exactly here.
- **Gates unlocked:** contributes to EHT 2 (the first tier where armor gates)
- **Monetization role:** power-progression
- **Notes:** **this is the first time armor enters the bill** (Tier 1 has no armor cost). Regional camo
  variants are cosmetic.

#### Brush Guard Vest (T3) / Expedition Parka (T4)
- **Category:** armor · **Tiers:** 3, 4 · **Available at:** Outfitter (Parka = Alaska cold-weather line)
- **Cost:** 5,100 / 8,670 Cash (`c·Income(T−1)`)
- **Primary stat(s):** Protection 44 / 58 /100 *(readout)*; functional DR vs own tier 0.50, vs +1 threat 0.38
- **Weight:** 5 / 8 kg (Parka heavy → Mount convenience tie)
- **Strengths:** T3 makes the T2 apex safe (DR 0.50) and clears Rockies; **T4 keeps the caribou/moose
  milestone survivable** (DR 0.50, 22.5 dmg/hit, 5 hits to down)
- **Weaknesses / limits:** **T4 vs grizzly (behaves-as-T5): DR 0.38, downed in ~2 hits → co-op-only.**
  No T5 armor at MVL.
- **Gates unlocked:** EHT 3 (Rockies) / EHT 4 (Alaska)
- **Monetization role:** power-progression + convenience (heavy-gear → Mount)
- **Notes:** the Parka is the legible "of course you need this for Alaska" gate item (01).

### 4.3 Rods (armor-analog — Pressure → LandWindow)

#### Starter Cane Rod
- **Category:** rod · **Tier:** 1 · **Available at:** free starter loadout · **Cost:** 0 Cash
- **Primary stat(s):** Pressure (BreakThreshold) 30/100
- **Weight:** 1 kg
- **Strengths:** lands all Bayou panfish/catfish and Appalachia floor (panfish: 12-s LandWindow)
- **Weaknesses / limits:** zero headroom over T2 mid runs (bass: LandWindow 0 → snap) — needs T2 rod
- **Gates unlocked:** none (EFT 1 on arrival)
- **Monetization role:** — (free; onboarding)
- **Notes:** paired with the Starter Spincast Reel as the free fishing loadout

#### Appalachia Bait Rod (T2) / Mountain Rod (T3) / Coastal Surf Rod (T4)
- **Category:** rod · **Tiers:** 2, 3, 4 · **Available at:** Tackle Shop
- **Cost:** 3,000 / 5,100 / 8,670 Cash (`c·Income(T−1)`); T2 intra-tier within the 4,250 loop climb
- **Primary stat(s):** Pressure (mid) 52 / 74 / 96 /100 *(T4 mid sits at the cap edge; **maxed T4 = 108 → clamped 100** — OQ-A boundary)*
- **Weight:** 1.5 / 2 / 2.5 kg
- **Strengths:** T2 gives 16-s LandWindow on the trophy bass (lands it); T4 gives huge headroom on the
  **king salmon milestone** (LandWindow 48)
- **Weaknesses / limits:** the **rod is the analog that snaps**: T2 has 0 headroom over the muskie apex;
  **T4 rod headroom is fine on the king salmon but the halibut apex is reel-bound** — the rod isn't the
  binding slot there (see 4.4)
- **Gates unlocked:** EFT 2 / 3 / 4 (with the matching reel)
- **Monetization role:** power-progression
- **Notes:** the rod is the first curve to saturate: **maxed T4 already computes to 108** (clamped to
  100 — which does not change the T4 gate: a clamped-100 rod still throws the halibut, see 4.4), and the
  **T5 mid (118)** cannot be represented on 1–100 at all without OQ-A's re-basing. Surfaced, not silently
  clamped.

### 4.4 Reels (weapon-analog — Line Speed/Drag → FightTime)

#### Starter Spincast Reel (T1, free) / Baitcaster (T2) / Spinning Reel (T3) / Coastal Lever-Drag (T4)
- **Category:** reel · **Tiers:** 1–4 · **Available at:** free (T1) / Tackle Shop
- **Cost:** 0 / 3,000 / 5,100 / 8,670 Cash (`c·Income(T−1)`)
- **Primary stat(s):** DrainMax (Line Speed/Drag) 9 / 13 / 18 / 25 /100 (mid)
- **Weight:** 0.5 / 0.8 / 1 / 1.5 kg
- **Strengths:** T2 out-drains the trophy bass (FightTime 9.8 ≤ 16); **T4 lands the king salmon
  milestone** (FightTime 9.0)
- **Weaknesses / limits:** **the reel is the binding slot on heavy "reel-bound" fish.** The **halibut
  apex** (huge stamina 441) needs `FightTime ≤ LandWindow`: at T4 `FightTime 45.6 > 37.2` → throw. **No
  T5 reel at MVL → halibut is co-op-only** (Decision 7) — the fishing mirror of the grizzly being
  damage-window-gated.
- **Gates unlocked:** EFT 2 / 3 / 4 (with the matching rod)
- **Monetization role:** power-progression
- **Notes:** reel mirrors weapon by construction (`R1·ρ^(T−1)`), which is *why* hunting and fishing
  income scale identically — the dual-loop balance is built into the stat curves, not patched on.

### 4.5 Boats (access sink — gate water type, never power in shared water)

#### Jon Boat (T1–2 convenience) / Bass Boat (T3 convenience) / Coastal Skiff (T4 — the MVL Boat gate)
- **Category:** vehicle (Boat) · **Available at:** Boat Dealer
- **Tier / water opened:** Jon = lake/slow river (cosmetic convenience; Bayou/Appalachia fish are
  shore-accessible so **no Boat is required for MVL tiers 1–3**) · Bass = T3 lakes · **Coastal Skiff =
  T4 coastal** (opens Alaska's king salmon + halibut sub-area)
- **Cost (one-time, big lump):** the **gating** boat is priced by `BoatCost = b·Income(T_water)`, b ≈ 3.7
  — **Coastal Skiff ~18,000** (3.7·Income(4); the marquee Alaska save-up, ≈ a full T4 gear tier-up). The
  non-gating convenience boats sit deliberately **below** that formula (they open nothing required): Jon
  ~1,500, Bass ~6,000. These lump sums are feel-set placeholders, not formula outputs — see OQ-D.
- **Primary stat(s):** none combat/catch — Boats grant **access only** (a water-type unlock flag).
  Optional cosmetic: hull paint, livery.
- **Weight:** n/a (capacity: carries the angler + gear into the opened water)
- **Strengths:** opens otherwise-unreachable water for **everyone who buys in** (the acceptable side of
  the access line)
- **Weaknesses / limits:** **must NOT out-fish a shore angler in a shared shore cell** — opens the cell,
  grants no in-cell power (SYS_fishing §7). Never a tier input; never required to *enter* Alaska (a
  hunter walks the interior).
- **Gates unlocked:** **sub-area** (Alaska coastal fishing), not Destination entry
- **Monetization role:** access
- **Notes:** the legible "you need a boat for the coast" gate (01). Game-pass tiers exist as a faster
  path to ownership (still access, never power); the **Ocean Trawler (T7)** is post-MVL (§5).

### 4.6 Mounts (convenience — traversal/chase; mid-game, never starter)

#### Horse / ATV / (regional) Snowmobile
- **Category:** mount · **Tier:** available from **T3** (never starter — players pay to save time *once
  they like the loop*, 01) · **Available at:** Kennel & Stable
- **Cost (one-time, `MountCost ≈ 2·GearCost_slot(T)`):** first Mount ~10,200 (T3) · regional reskins priced to tier
- **Primary stat(s):** Traversal speed +X% (convenience); chase-speed to catch *fleeing* game (combat
  archetype `flees`). **No** combat/catch power, **no** damage, **no** survivability.
- **Weight:** n/a (carries player + heavy gear → the explicit pairing with heavy T4+ armor/rifles)
- **Strengths:** cuts `TimeToFind`/repositioning overhead; catches fleeing game a player on foot loses
- **Weaknesses / limits:** **never appears in a Gate** (progression — convenience must not gate shared
  content); cannot take a target your *gear* could not
- **Gates unlocked:** none — ever
- **Monetization role:** convenience
- **Notes:** breeds/models are collectible identity (regional flavor); rare models are **tradeable
  cosmetics**, not power.

### 4.7 Tracking Dogs (convenience + collectible identity)

#### Coonhound (Bayou) / Pointer (Appalachia) / Husky (Alaska)
- **Category:** dog · **Tier:** available from **T2–T3** · **Available at:** Kennel & Stable
- **Cost (one-time):** basic breeds ~8,000 (≈ `1.6·GearCost_slot(T)`); **rare breeds are P2P trade
  items**, not shop-Cash priced (their value flows to the Trading Post, like rares)
- **Primary stat(s):** widens rare-spawn detection radius; tracks wounded/fleeing game (convenience).
  **Does NOT raise damage, survivability, or catch power** — explicitly "does not break combat balance"
  (01).
- **Weight:** n/a
- **Strengths:** finds condition-gated rare spawns faster; recovers wounded game (a `flees`-archetype
  aid); regional-breed identity
- **Weaknesses / limits:** **never in a Gate**; cannot make an un-takeable target takeable (rares are
  still condition-gated spawns — a dog helps you *find*, not *win*)
- **Gates unlocked:** none — ever
- **Monetization role:** convenience + identity (rare breeds = collectible/tradeable)
- **Notes:** the rare-breed line is a clean trade-economy + identity sink with zero balance impact.

### 4.8 Bait & tackle

#### Basic bait/tackle (cut bait, fly, spoon, basic ammo)
- **Category:** bait / tackle · **Tier:** all · **Available at:** Tackle Shop / Outfitter
- **Cost:** trivial (5–20 Cash) and **auto-restocked** — effectively free
- **Primary stat(s):** **required-item yes/no gate only** (does a given fish/target need this basic
  item to strike/engage). **Never a tier input.**
- **Strengths:** legible "do you hold the right basic tackle" check; every target is engageable with its
  appropriate basic
- **Weaknesses / limits:** by rule, a player can **never** be blocked from the core loop by running out
  (the not-a-timer rule). A condition-gated rare *may* name a specific basic bait as part of its spawn
  condition — that gates *the attempt*, not the *win*, and cannot be bought past.
- **Monetization role:** — (friction-free; not a real money sink)

#### Ice-Fishing Kit (auger + tip-up)  *(region-specific — Alaska; authored in LOC_04 §6, canonical here)*
- **Category:** tackle
- **Tier:** first available T4 (Alaska); relevant during the **Winter Freeze** event (LOC_04 §9)
- **Available at:** Tackle Shop (Harbor Camp)
- **Cost:** ~800 Cash (trivial; a seasonal-activity enabler, not a tier input)
- **Primary stat(s):** **required-item yes/no gate** to fish the **Frozen Lake** during the freeze (cut a
  hole + set a tip-up) — the same required-basic-tackle pattern as cut bait / fly (SYS_fishing §4).
  **Never a tier input; never premium-gated.**
- **Weight:** 2 kg
- **Strengths:** opens a self-contained winter sub-activity (a calmer, seated counter-tempo to the
  coastal fight) and a LiveOps surface (LOC_04 §9); a flavor/identity beat
- **Weaknesses / limits:** a player can **never** be blocked from the *core* loop by lacking it — it
  gates only the seasonal Frozen-Lake micro-activity, not Alaska's standing rivers/coast (the not-a-timer
  rule, SYS_economy §1). It does **not** reach the moat-rares (LOC_04 §5).
- **Gates unlocked:** the Frozen-Lake winter water only (a seasonal sub-area, not a Destination or a tier)
- **Monetization role:** convenience + identity (the kit and winter-themed cosmetics)
- **Notes:** ties the Winter Freeze event to a real verb rather than a passive boost; keep the
  frozen-lake catches inside the bite-density cap (LOC_04 §8) so it is not an over-geared-farming hole.

#### Premium bait/lure (convenience, capped — fishing Decision 4)
- **Category:** bait · **Tier:** all · **Available at:** Tackle Shop (Cash) / developer product
- **Cost:** modest recurring (a fraction of `Income(T)` per stack); also a dev-product pack
- **Primary stat(s):** shortens `TimeToBite` (more routine bites/hour) + small `LandWindow` bonus on
  routine fish. **Rarity-bias capped at Uncommon** — **never** raises Legendary/Mythic encounter rate.
- **Weaknesses / limits:** **never mandatory; no fish catchable *only* with it** (not-a-timer). Cannot
  touch the moat-rares — those are bait-independent condition-gated spawns.
- **Monetization role:** convenience (routine-grind compression only)
- **Notes:** **watch-knob** — if telemetry shows premium bait inflating tradeable rares, tighten the
  bias toward Common/Uncommon (SYS_fishing open flag).

#### Premium ammo (the hunting analog — convenience, capped)
- **Category:** tackle · **Tier:** all · **Available at:** Outfitter (Cash) / developer product
- **Cost:** modest recurring
- **Primary stat(s):** tighter settle / faster re-settle (a small effective-`CycleTime` edge) **within
  the not-a-timer cap**: it improves odds, it does **not** make any creature takeable *only* with it.
  Capped so it never substitutes for a weapon tier.
- **Monetization role:** convenience
- **Notes:** the cap is the design guarantee — premium ammo can shave a fumbled shot, never clear a gate
  the player's *gear* couldn't.

### 4.9 Cosmetics (category + intent — the evergreen inflation ballast, economy §9)

Not a skin list — categories and the economic role. **Balance-free, no stats, no ceiling, highest
margin; the primary endgame inflation sink that must be continuously replenished (a LiveOps SLA).**

| Category | Examples (intent) | Price model | Role |
|---|---|---|---|
| Weapon / rod skins | wood/blued rifle, custom rod wraps | Cash + game-pass flagship | identity |
| Outfits / camo | regional hunting outfits, Alaska parka colorways | Cash | identity |
| Boat paint / livery | hull colors, decals | Cash | identity |
| Dog breeds (cosmetic variants) | coat colors, rare-breed skins | Cash + P2P (rare) | identity |
| Lodge decor / Trophy Hall expansion | wall mounts framing, room themes, extra display slots | Cash | identity + the trophy-status layer |

**Economic duty:** the catalog must grow on the LiveOps calendar or it saturates and endgame inflation
resumes (economy §9). Tracked by the `endgame-sink replenishment cadence` knob and `evergreen-sink-share`
telemetry.

### 4.10 Tools (regional traversal/access aids — convenience, never power, never a gate)

*New subsection: `tool` is a first-class Template B category (doc 02) with no prior home in §4. Appended
as §4.10 — rather than inserted near the Mounts/Boats convenience items — specifically so §4.7–§4.9 keep
their numbers and no corpus cross-reference breaks.*

#### Snowshoes  *(region-specific — Alaska; authored in LOC_04 §6, canonical here)*
- **Category:** tool
- **Tier:** first available T4 (Alaska)
- **Available at:** Outfitter (Harbor Camp)
- **Cost:** ~600 Cash (trivial — a friction-remover, not a progression sink; well below first-session
  Alaska earnings)
- **Primary stat(s):** removes the deep-snow on-foot movement penalty (restores normal walk/run pace
  over snow/tundra). **No** combat/catch/survivability stat.
- **Weight:** 1 kg
- **Strengths:** makes the interior traversable on foot without the Snowmobile; the cheap legible counter
  to the snow-slow terrain (LOC_04 §2.4)
- **Weaknesses / limits:** does not chase fleeing game faster than a player's base pace (that is the
  Snowmobile's convenience) — it *restores* normal pace, it does not exceed it; **never a Gate**
- **Gates unlocked:** none — ever
- **Monetization role:** convenience (trivial Cash; not a real-money sink) — the friction it removes is
  flavor, never a timer (00 §4)
- **Notes:** the legible "of course you need snowshoes up here" immersion item (01) at a price that never
  reads as a wall. Distinct from the §4.6 Snowmobile Mount: Snowshoes *restore* base pace cheaply; the
  Snowmobile *exceeds* it and chases fleeing game (the convenience-mount tier).

---

## 5. THE FULL LADDER beyond MVL (T5–T8+) and deferred classes

Stats generate from §1 untouched **on the Cash axis**; on the stat axis, **everything from T5 up depends
on Open Question A's resolution** (the raw 1–100 numbers in §1.8 exceed the cap). Representative blocks,
all *illustrative-default*, cross-system checks **asserted-by-construction**:

- **T5–T8 hunting weapons / armor, rods / reels, boats:** identical Template-B shape, stats from §1.8,
  prices from §2. By construction each tier's weapon clears its floor (T−1 reference) and mid (T) and
  needs T+1 for its apex; each tier's rod+reel land its floor/mid not its apex. **The T5 line is what
  finally solos the Alaska grizzly and lands the halibut** (the MVL apexes become soloable when T5
  ships — RD-A / Decision 7). **Ocean Trawler (T7 Boat)** opens deep-sea water for the marlin/tuna/“white
  whale” fishing endgame (`offered_loops = [fishing]`).
- **Tier 9+ (LiveOps):** Cash inherits the curve with no change; **stats require OQ-A's `TierCoefficient`
  re-basing to drop in without saturating.** This asymmetry is the doc's central open question.

### Deferred weapon classes (combat RD-D — catalogued, NOT built for MVL)

Tagged **`POST-MVL · projectile-with-lead · engine must not hard-wire hitscan-only`**:

- **Bows** — projectile arc + travel time; reward leading a moving target; quieter (lower spook radius —
  a `flees`-archetype synergy). Stat on the same Damage curve but with a projectile resolution layer.
- **Shotguns** — spread/pellet model; short optimal range, high close damage; pairs with `ambush` (also
  deferred, RD-C) and dense-cover Destinations (Amazon).
- **Throwing weapons** — short-range, silent, niche.

These exist as catalog rows so the data schema and combat engine reserve the projectile path; **the MVL
weapon line is hitscan rifles only.** Do not stat creatures against projectile classes until they ship.

---

## 6. Build notes (Claude Code)

- **Every item stat is server-authoritative.** The client never asserts a weapon's damage, a reel's
  drain, a rod's Pressure, or an armor's DR. The server resolves `ShotsToKill` / `FightTime ≤ LandWindow`
  from the **equipped item's authoritative stats** (combat/fishing anti-exploit). A client claiming
  damage/drain/catch is ignored.
- **The item schema is data-driven config**, keyed by `(itemId, tier, intraLevel)`, with pure-function
  stat curves (`WeaponDamage`, `ReelDrainMax`, `BreakThreshold`, `CycleTime`, `Range`, prices) evaluated
  from the §1/§2 constants — **so Tier 9+ and new items are config rows, not code.** Keep `D1, R1, ρ,
  P1, P_step, q(), pq(), c, m, B, g`, the rarity ladder, `Z_expected`, `E_expected`, and the
  fishing-fight constants as live config.
- **Suggested item record:**
  ```
  Item { id, category, tier, intraLevel,
         statCurveRef,                 # which §1 formula set
         costCash | passId | devProductId,
         accessFlag?,                  # boats: which water type
         tierInput: bool,              # false for bait/mount/dog/boat/cosmetic — never moves EHT/EFT
         tradeable: bool,              # SYS_data_integrity RD1: routes the item's persistence path
         monetizationRole, cosmeticOnly: bool }
  ```
  `tierInput=false` is the schema-level guarantee that Bait/Mounts/Dogs/Boats/Cosmetics can never enter
  a Gate (progression). A cosmetic with non-null stats is a build-time schema error.
- **Effective tiers are derived from equipped item tiers, never stored** (progression): `EHT =
  min(weapon.tier, armorTierOrFloor)`, `EFT = min(rod.tier, reel.tier)`. Buying one slot ahead does not
  move the gate — the price symmetry (§2) makes that uneconomical, the `min` makes it ineffective.
- **Intra-tier upgrades change stats, never tier.** An intra-level field modifies `q(ℓ)/pq(ℓ)` only;
  it never satisfies a Gate (the pay-proof property — maxing = apex-*capable*, not a milestone skip).
- **`TierCoefficient` hook (forward-compatible for OQ-A):** even though MVL reads raw 1–100, store the
  per-tier coefficient as config now (`= 1.0` through T4) so the T5+ re-basing is a config change, not a
  schema migration.

### 6.1 The `tradeable` discriminator (SYS_data_integrity RD1)

SYS_data_integrity splits persisted value by **tradeability/scarcity**, not object category, and routes
each item into one of two persistence paths. EQUIPMENT_MASTER's item record therefore carries a
`tradeable: bool` field that determines the path:

- **`tradeable = false` → typed-owned commodity.** Stored as (catalog id + intra-tier level + equipped
  flag), NOT a unique ID. No anti-dupe machinery — duping is pointless because the item is fixed-Cash
  purchasable. This is the path for the entire **standard gear line** (all weapons, armor, rods, reels),
  **basic boats/mounts/dogs**, and **basic cosmetics**.
- **`tradeable = true` → unique artifact.** Server-minted unique `artifactId`, single owner, provenance,
  CAS transitions, full anti-dupe. This is the path for **rare-breed Tracking Dogs / Mounts / Boats**
  and **tradeable cosmetics** (01: "rare breeds can be tradeable"). Trophies/record catches are minted
  by combat/fishing, not sold here, but use the same path.

**MVL tradeability assignments:**

| Category | `tradeable` | Notes |
|----------|-------------|-------|
| Weapons (all tiers, hitscan + deferred projectile) | **false** | fixed-Cash commodity; economy dual-pricing |
| Armor (all tiers) | **false** | same |
| Rods / Reels (all tiers) | **false** | same |
| Bait / tackle (basic + premium) | **false** | fungible counts, not even typed-owned |
| Boats — basic (Jon, Bass, Coastal Skiff) | **false** | access commodity |
| Boats — rare/special variants (if any ship) | **true** | unique artifact |
| Mounts — basic (Horse, ATV, Snowmobile base) | **false** | convenience commodity |
| Mounts — rare models | **true** | "rare models are tradeable cosmetics" (§4.6) |
| Tracking Dogs — basic breeds (Coonhound, Pointer, Husky) | **false** | convenience commodity |
| Tracking Dogs — rare breeds | **true** | "rare breeds are P2P trade items" (§4.7) |
| Cosmetics — standard (Cash-priced skins/decor) | **false** | identity commodity |
| Cosmetics — rare/tradeable variants | **true** | unique artifact (§4.9 dog-breed P2P row) |

**Build-time assertion (extends EQUIPMENT_MASTER's existing schema checks):** an item with
`tradeable=true` MUST have a unique-artifact code path; an item with `tradeable=false` MUST NOT carry an
`artifactId`. The pairing of `tradeable` with the existing `tierInput=false` rule means a rare-breed dog
is `tradeable=true, tierInput=false` — a unique, tradeable artifact that still can never enter a Gate.
These are orthogonal: `tierInput` governs progression-gating; `tradeable` governs the persistence/
anti-dupe path. (Reconciles SYS_data_integrity RD1 §open and SYS_trading's "what may be offered" input.)

---

## 7. Open questions / flags

**A — THE CENTRAL CONFLICT (must be ratified by combat + fishing before any tier ≥ 5 ships).** A single
absolute-1–100 stat curve **cannot** "generate all 8+ tiers and let Tier 9+ inherit untouched" the way
economy's `Income(T) = B·g^(T−1)` does, because the 1–100 scale (mandated by doc 02 for
cross-comparability) is **capped** and economy's Cash curve is **not**. The saturation bites *inside the
designed ladder*: the additive **rod Pressure curve reaches the cap first — maxed already at T4 (108),
mid at T5 (118)** — and the geometric **weapon curve crosses at T6–T7, the reel only at T8** — all well
before the "Tier 9+ LiveOps" the economy formula handles for free. Consequence: past ~T4 a T8 rod is barely stronger than a T4 rod once clamped,
and the rod stops being a progression axis. **Recommended resolution:** re-base the 1–100 stat to
**within-tier quality** and carry cross-tier power in a config-only **`TierCoefficient(T) = κ^(T−1)`**
(κ = the shared spread-growth constant, RD-F) that the inequalities consume — within a tier the
coefficient cancels (combat's literal formula is the within-tier case), across tier offsets the
coefficient ratio supplies the floor/ceiling delta. This preserves every relationship, keeps 1–100
readable at every tier, and makes Tier 9+ genuinely drop-in. **This refines the damage/catch FORMULA
representation, which is combat/fishing's territory — so it is flagged for their ratification, not
asserted here.** MVL gate outcomes are unaffected and tiers 1–4 are build-ready either way — the lone
cap touch (maxed T4 rod → clamped 100) changes no result.

**B — `Z_expected = 1.0` and `E_expected = 0.7` are the load-bearing skill assumptions** behind every
min-tier in the catalog. If the median player lands vitals more often than body shots, every gate is
looser than modeled (targets die faster) and the bands shift. These are the single knobs that re-derive
all min-tiers at once; first joint-tuning target post-soft-launch (twin of combat Q1 / fishing's
rate flag). Do not finalize stat magnitudes against them until live accuracy/tension-efficiency
distributions exist.

**C — The Health/FightDifficulty cap squeezes the shot-count band at the top of each tier.** With
`Z_expected = 1.0`, a tier's mid creature near Health 100 yields only ~3 shots at the T-weapon (bottom
of the 3–5 band), because `WeaponDamage·Z` is large relative to a capped Health. It works through T4
(Alaska mid = 3 shots) but leaves no room for a "4–5 shot" mid at high tiers without OQ-A. Tied to A.

**D — Boat/Mount/Dog price formulas (`b`, the Mount/Dog multipliers) are coarse defaults.** They satisfy
"big one-time sink, never pay-to-win" but are not reconciled against a measured save-up curve. Validate
against time-to-purchase telemetry; these are access/convenience lumps, so mis-pricing is a pacing
annoyance, not a balance break.

**E — Heavy-gear → Mount convenience tie is asserted, not mechanized.** §1 gives T4+ gear high kg and
says it "pairs with a Mount," but whether weight actually imposes a traversal penalty (making the Mount
a *real* convenience purchase vs. flavor) is a feel decision. If weight does nothing, the kg field is
cosmetic; if it slows the player, confirm it never crosses into *power*-gating (a non-payer must still
function on foot). Flag for LOC_/combat.

**F — Premium-consumable effect sizes (bait `TimeToBite`/`LandWindow` bonus, premium-ammo settle edge)
are unset magnitudes** bounded only by the not-a-timer cap. They must improve odds without making any
target takeable *only* with them. Set with live data on rare-catch-vs-premium-bait adoption; tighten if
the moat leaks.

**G — Cosmetic replenishment cadence is an economic SLA, not a creative nicety** (economy §9). The
catalog in §4.9 saturates without a continuous pipeline, at which point endgame inflation resumes. This
is SYS_liveops/SYS_lodge_trophy's commitment; flagged here because the *items* live in this doc.
