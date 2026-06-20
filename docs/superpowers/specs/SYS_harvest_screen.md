# Wild World — Harvest / Catch Result Moment (the screenshot beat)

**Spec owner:** gameplay + UI
**Status:** v1 scope LOCKED 2026-06-19 — implementation-ready (see §8 Resolved Decisions: Seam A, Bestiary Tier A, weight in lb for fish+creatures, hybrid card/toast)
**Validated against the codebase maps** (`clientCatch`, `spawnEcon`, `liveops`) and the live files: `RewardPipeline.luau`, `Gauntlet.luau`, `CatchHandler.luau`, `WorldServer.server.luau`, `Hud.luau`, `FireController.client.luau`, `FishingController.client.luau`, `TrophyHall.luau`.

---

## 0. The pitch, in one paragraph

Right now a kill or catch produces a single transient center toast — `"Down!"` / `"Landed!"` — plus an inferred `+$<delta>` derived by diffing `projection.balance` in `Hud.applyProjection`. That is the entire value-feedback surface, and it is invisible the first time (`lastBalance` starts nil; see `Hud.luau` L123–128). The genre's proven retention beat — Hunting Season's diegetic post-kill readout, Gone Hunting's named-and-weighed item (`"Sika Deer [201.7 lb]"`) — is a *result card*: a momentary, screenshot-worthy panel that names the animal/fish, shows its weight and rarity, grades the shot, states the cash earned, and flags a Bestiary "NEW!" — then offers, for a rare mint, the "Mount it in the Trophy Hall" prompt that today is only a TODO comment (`WorldServer.server.luau` L864–866, L987–988). This spec defines that card end to end while keeping the server authoritative: the client renders, the client never mints, and every displayed number is computed server-side and shipped on the existing kill/landed RemoteEvents.

---

## 1. The exact trigger — real remote + handler + payload

### 1.1 The two real fire points (no new RemoteEvents)

The result card is driven by the **two existing server→client fires** in the Studio-only world script `src/server/world/WorldServer.server.luau`:

| Loop | RemoteEvent | Instance / map symbol | Fire site | Today's signature |
|---|---|---|---|---|
| Hunting | `FireRequest` (`fireRequest`) | created L792–794, `Net.fire` on client | **L863** | `:FireClient(plr, "kill", rayHitTargetId, r.projection)` |
| Fishing | `FishingCast` (`castRequest`) | created L944–946, `Net.cast` on client | **L986** | `:FireClient(plr, "landed", fishId, r.projection)` |

We do **not** add a remote. We **widen the 4th argument** (`extra`) from "projection only" to a `{ projection, harvest }` envelope (§4.3). This is the lowest-friction seam the `clientCatch` map calls the "PRIMARY server seam": it edits one Studio-only file, leaves the headless gauntlet contract untouched, and both fire sites already have `r.projection` and the catalog (`Catalog.creatures[id]` / `Catalog.fish[id]`) in scope.

> The fire happens **only on `r.ok`** (`WorldServer.server.luau` L861, L984) — i.e. after `Gauntlet.handle` has run the full 6-step gauntlet and `RewardPipeline.resolve` has committed inside the `Transaction` (`Gauntlet.luau` L85–92). The card is therefore a *render of a committed authoritative outcome*, never a prediction.

### 1.2 The authoritative source of the result data

The richest per-event data already exists exactly once: `RewardPipeline.Result` (`RewardPipeline.luau` L48–56):

```
{ ambiance: boolean, cash: number, boostCash: number,
  mintedArtifactId: string?, rankXP: number,
  conquestNewlySet: boolean, cleanKillMoment: string? }
```

Today this is **computed then discarded** — `CatchHandler.commit` (L133–163) and the parallel `FireHandler` assign it to a local `result` and use it only for funnel/telemetry side-effects; the gauntlet's `commit: (ctx) -> ()` returns nothing and `HandleResult` (`Gauntlet.luau` L36) has no slot for it. **This is the single richest source of result data and it never reaches the client** (`clientCatch` gap). Surfacing it is the heart of this spec — see the two seam options in §4.

---

## 2. The info breakdown — what to surface, adapting HS's score model

The card adapts Hunting Season's "animal-factors × shot-quality-factors" readout and Gone Hunting's named-with-weight item. Each field below is tagged **EXISTS** (server already has it on the catch path), **DERIVABLE** (server has the inputs, needs a small new computation), or **NEW** (net-new field/concept; cites the map gap).

| # | Field | Hunting | Fishing | Status | Source / where to get it |
|---|---|---|---|---|---|
| 1 | **Species name** (authoritative) | ✅ | ✅ | **DERIVABLE → ship it** | `Catalog.creatures[id].name` / `Catalog.fish[id].name`, both in scope at the fire sites. **Today the client *derives* the name client-side** from the raw id via `gsub` in `FishingFeel` (`clientCatch` gap) and shows raw `model.Name` for creatures — a stopgap the card replaces with the server-sent name. |
| 2 | **Weight** — GH's `[201.7 lb]` | ⚠️ | ✅ (fish) | **DERIVABLE (fish) / NEW (creatures)** | Fish carry `typicalWeightKg{min,max}` + `recordWeightKg` (`Schema.Fish`, L146–147) but **no code rolls or sends a per-catch weight** (`clientCatch` + `spawnEcon` gaps). **Creatures carry NO weight field at all** (`Schema.Creature`, `spawnEcon` gap). See §2.1 — weight must be **server-rolled at resolve time**, never stored on the artifact (`Provenance` carries no weight; `TrophyHall.plaque` docstring L56–59 explicitly calls the weight-kg label "a Studio concern"). |
| 3 | **Rarity** | ✅ | ✅ | **EXISTS** | `RewardPipeline.describe` already reads `rarity` per-event (`RewardPipeline.luau` L82/L100); `Catalog.creatures[id].rarity` / `.fish[id].rarity` at the fire site. Closed enum `Enums.Rarity` (`Common..Mythic`). |
| 4 | **Trait / mutation** (GH "trait farming") | ❌ | ❌ | **NEW — out of scope for v1; see §8** | **No trait concept anywhere** and **no mutation concept anywhere** (`liveops` + `spawnEcon` gaps: grep returns zero). The card **reserves a slot** but renders nothing until a trait system exists. Do not invent one here. |
| 5 | **Shot quality / headshot** | ✅ | n/a | **DERIVABLE (hunting) → ship the hit zone** | `zoneOfHit(part)` → `'vital'\|'limb'\|'body'` exists at `WorldServer.server.luau` L797–800 and is computed per shot (L821), but the **kill reply does not include it** (`clientCatch` gap). The *killing* shot's `zone` is in scope in the `OnServerEvent` closure. Fishing has no shot quality; substitute **fight grade** from `fightDifficulty` (`Schema.Fish`) as the parallel "skill" axis (DERIVABLE; optional v1). |
| 6 | **Cash value** | ✅ | ✅ | **EXISTS (once surfaced)** | `RewardPipeline.Result.cash` (base routine payout + boost) and `.boostCash` (the 2x/VIP portion). **This is the authoritative number** — far better than the `Hud` balance-diff, which shows nothing on the first payout. For a **rare mint**, `cash == 0` (Reward XOR; see §2.2). |
| 7 | **Bestiary "NEW!"** | ✅ | ✅ | **NEW — needs a seen-set; see §2.3** | **No bestiary/seen-set exists** on the profile in any map. Two implementation tiers in §2.3 (cheap derive-from-artifacts for rares; new `profile.seen` set for full coverage). |
| 8 | **Rare clean-kill moment** | ✅ | ✅ | **EXISTS** | `RewardPipeline.Result.cleanKillMoment` = `rare.intendedContentMoment` (`RewardPipeline.luau` L139). The marquee "moment" string; the card's headline for a rare. |
| 9 | **Rank XP gained** | ✅ | ✅ | **EXISTS (once surfaced)** | `RewardPipeline.Result.rankXP` (Hunter/Angler). A small "+XP" chip. |
| 10 | **Conquest / milestone** | ✅ | ✅ | **EXISTS (once surfaced)** | `RewardPipeline.Result.conquestNewlySet`. When true, the card gets a "Destination Conquered!" banner. |

### 2.1 Weight — the server-rolled value (NEW computation; DERIVABLE inputs)

GH's `[201.7 lb]` is the single most screenshot-driving field. It must be **server-authoritative and rolled at resolve time**, because (a) the client cannot require the catalog (`default.project.json` maps `src/` to `ServerScriptService`), and (b) it must not be stored on the artifact (`Provenance` has no weight; storing it would be a derive-don't-store violation per `CLAUDE.md`).

- **Fish — DERIVABLE.** Roll `weightKg ∈ [typicalWeightKg.min, typicalWeightKg.max]` (uniform, or triangular biased to the low end for naturalism). Flag `isRecord = weightKg > 0.95 * recordWeightKg` for a "RECORD!" badge. Display in lb (`lb = round(kg * 2.2046, 1)`) to match GH's idiom, or kg — see Open Decision OD-2.
- **Creatures — NEW field.** `Schema.Creature` has no weight. Add an **optional** `typicalWeightKg: {min:number, max:number}?` to `Schema.Creature` (NEW, `src/types/Schema.luau`) and author values in `src/config/Creatures.luau`. Until authored, the card omits the weight row for that species (graceful). **Keep it cosmetic:** weight must NOT enter payout — `Economy.payout` is keyed by `tier+rarity+destinationId+loop` only (`spawnEcon` constraint), and a "bigger fish pays more" rule does not exist and must not be introduced here (that would break the routine-band reconciliation; see §6 invariants).

**Where the roll lives:** it is a Studio-runtime roll (uses `math.random`), so it belongs in `WorldServer.server.luau` at the fire site (Studio-only), *or* threaded through as part of the harvest envelope assembled there. It is **purely cosmetic** and never re-read, so it does not need to enter the headless pipeline. (If we later want it gauntlet-blessed, it would ride on `KillEvent` — but `KillEvent` carries no quality field today, `spawnEcon` gap, and v1 does not need that rigor for a display-only number.)

### 2.2 The Reward XOR branch (integrity-critical render rule)

The card **must branch on the XOR** (`RewardPipeline.luau` L126, `clientCatch` constraint):

- **Routine catch (cash branch):** show **cash** (field 6) as the headline value; `mintedArtifactId == nil`; no "Mount it" prompt. Weight/rarity/shot still show.
- **Rare catch (artifact mint):** `cash == 0`, `mintedArtifactId` set, `cleanKillMoment` set. The card becomes the **trophy card**: gold treatment, the moment string as headline, and the **"Mount it in the Trophy Hall"** prompt (§3.3, finally implementing the `autoPromptOnMint` TODO). Never show "$0" as if it were a payout — show "ADDED TO COLLECTION" instead.

### 2.3 Bestiary "NEW!" (NEW — two tiers)

There is no seen-set anywhere (`clientCatch` gap). Two implementation tiers; pick per OD-3:

- **Tier A (cheap, rares-only, no schema change):** "NEW!" iff this is the first artifact with `provenance.sourceId == targetId`. Derivable server-side at the fire site by scanning `profile.artifacts` *before* the mint, or by checking `Replication.Projection.trophyHall` deltas. Covers only rare mints (routine cash catches never get "NEW!").
- **Tier B (full coverage, NEW field):** add `profile.seen: { [string]: boolean }` (`src/types/Schema.luau` PlayerData, NEW) recording every species id the player has ever caught/killed. Set it in `RewardPipeline.resolve` (or the handler commit) and ship `isNew = (not already seen)` on the harvest envelope, then mark seen. This makes "NEW!" fire for routine species too (the GH/HS bestiary feel). Requires a profile-version bump and a migration default `{}`.

---

## 3. Visual treatment — diegetic, screenshot-worthy, grounded-naturalistic

Tie to the established art bar (the parallel "Wild World visual overhaul": flagship grounded-naturalistic, decoupled additive art layer) and to the **Lodge/Trophy Hall**, which `TrophyHall.luau` already models as a pure view (`displayed`, `slotUsage`, `plaque`) but whose physical box is **currently an unfinished placeholder**.

### 3.1 Form: a "field journal plaque", not a game-y popup

The card reads as a **carved wooden trophy plaque / field-journal page** — leather/aged-paper texture, brass corner brackets, a hairline rule under the species name — so it feels like a record you'd hang in the Lodge, not a casino toast. This is the same provenance shape `TrophyHall.plaque` produces (`what/where/when/loop/tier/rarity`), so a routine card and a mounted trophy plaque are visually the **same object** at two lifecycle stages: the card *is* the plaque-to-be. That continuity is the screenshot hook and the Lodge tie-in.

### 3.2 Placement & motion (diegetic)

- **Spawn:** lower-center, slightly above the action bar, rising ~40px with a 0.25s ease-out + subtle 2° settle (a plaque being set down). Soft drop-shadow. No screen-flash.
- **Rarity-keyed accent:** the brass rule + species-name color keys to `rarity` using the **closed `Enums.Rarity`** palette (Common neutral bone → Uncommon sage → Rare steel-blue → Epic violet → Legendary amber → Mythic iridescent). Use the closed enum values, never new string synonyms (`clientCatch` constraint).
- **Rare mint:** the plaque arrives with a slow gold sweep + a single low "weighty resolve" sound (the `FishingFeel`/`HuntingFeel` "weighty haptic resolve" TODOs, `WorldServer` L987/L864). This is the trophy moment.
- **Dwell & dismiss:** auto-dismiss after ~3.5s (longer than the 2.5s `Hud.toast`), or on tap. Mirror the `toastToken` auto-dismiss pattern in `Hud.luau` L86–96 so a rapid second catch cancels the prior card cleanly.
- **3D companion (optional, reuses existing feel):** keep the existing diegetic floats — `HuntingFeel.onKill` "Down!" billboard and `FishingFeel.onLanded` lifted-fish — but have the lifted fish/creature *present toward camera* under the plaque for the screenshot. The plaque supplies the authoritative name; the 3D supplies the subject.

### 3.3 The "Mount it in the Trophy Hall" beat (rare only) — implements the TODO

On a rare mint (`mintedArtifactId ~= nil`), the plaque grows a single primary button **"MOUNT IT"** (and a secondary "Keep in Bag"). This finally implements the `autoPromptOnMint` beat that is only a TODO in `WorldServer.server.luau` L864–866 / L987–988. The artifact stays **HELD** until the player taps; dismissing/"Keep in Bag" is a no-op (the artifact is already minted and replicated — the card does not mint), and the Lodge UI can mount it later. "MOUNT IT" fires the **existing `mountTrophy` intent** (`DisplayHandler.mountHandler`, `src/server/lodge/DisplayHandler.luau` L29–31, registered in `WorldServer.server.luau` L166) back through the gauntlet, so mounting is itself server-authoritative. The card never changes disposition itself. The card may show current capacity as "Lodge n/12" from `TrophyHall.slotUsage` and warn when full.

---

## 4. The exact client implementation seam (server authority preserved)

### 4.1 Client host module: a new `client/HarvestCard.luau` (NEW), hosted by `Hud.luau`

Add the card as a **sibling client module** loaded by the shared HUD singleton, mirroring how `Hud.button` / `Hud.toast` are factories on the one cached ScreenGui (`Hud.luau` L17–23 creates the single `WildWorldHUD` gui shared by all controllers).

- **NEW file:** `client/HarvestCard.luau` (Studio-only, `--!nonstrict`, excluded from `run-tests.sh`). Exposes `M.show(harvest)` building the plaque under `Hud.gui`, using the existing `label` helper pattern and `M.button` factory, and the `toastToken`-style auto-dismiss.
- **Expose host:** add `function M.showHarvest(harvest) HarvestCard.show(harvest) end` to `Hud.luau`, or require `HarvestCard` directly from the controllers. (Hosting in `Hud` keeps one entry point; see `clientCatch` "CLIENT host seam".)

### 4.2 Client controller hooks (the two render call sites)

- **Hunting — `client/FireController.client.luau` L51–55**, the `kind == "kill"` branch. Today: `Hud.applyProjection(extra)` + `Hud.toast("Down!")` + `Feel.onKill(extra)`. Change to read the envelope: `Hud.applyProjection(extra.projection)`, `Hud.showHarvest(extra.harvest)`, `Feel.onKill(extra.projection)`. Drop the generic toast (the card replaces it).
- **Fishing — `client/FishingController.client.luau` L98–104**, the `kind == "landed"` branch. Today: `Hud.applyProjection(extra)` + `Hud.toast("Landed!")` + `Feel.onLanded(fishId, extra)`. Change to `Hud.applyProjection(extra.projection)`, `Hud.showHarvest(extra.harvest)`, `Feel.onLanded(fishId, extra.harvest.name)` — passing the **authoritative** name so `FishingFeel` stops deriving it via `gsub` (`clientCatch` gap).

> **Back-compat note:** both controllers currently treat `extra` as the projection directly (and `Hud.applyProjection` no-ops on nil). Since we change the server to send `{ projection, harvest }`, update **both** read sites in the same change; the `fightProgress`/`hit`/`bite` branches keep their scalar `extra` unchanged.

### 4.3 The harvest envelope (the new payload shape)

The 4th arg of the kill/landed fire becomes:

```
extra = {
  projection = r.projection,         -- unchanged Replication.Projection (header/goal/balance-delta)
  harvest = {                        -- NEW: the result-card payload
    loop      = "Hunting" | "Fishing",
    targetId  = string,
    name      = string,              -- authoritative Catalog name (field 1)
    rarity    = Enums.Rarity,        -- (field 3)
    tier      = number,
    weightKg  = number?,             -- server-rolled; nil if species has no weight data (field 2)
    isRecord  = boolean?,            -- weightKg near recordWeightKg (fish)
    shotZone  = "vital"|"limb"|"body"?, -- hunting only, from zoneOfHit (field 5)
    cash      = number,              -- Result.cash (0 for a rare mint) (field 6)
    boostCash = number,              -- Result.boostCash (the 2x/VIP portion, shown separately) (field 6)
    rankXP    = number,              -- Result.rankXP (field 9)
    isNew     = boolean,             -- Bestiary NEW! (field 7) — Tier A or B
    mintedArtifactId = string?,      -- present → rare trophy card + "MOUNT IT" (XOR branch)
    cleanKillMoment  = string?,      -- Result.cleanKillMoment (field 8)
    conquest  = boolean,             -- Result.conquestNewlySet (field 10)
    trait     = nil,                 -- RESERVED (field 4); always nil until a trait system exists
  }
}
```

This is a **plain table assembled in the Studio-only server file**; it never crosses into headless code as a typed contract, so it adds no `--!strict` burden and no schema risk.

### 4.4 Getting `RewardPipeline.Result` to the fire site — two seams (pick per OD-1)

The fields `cash`, `boostCash`, `rankXP`, `mintedArtifactId`, `cleanKillMoment`, `conquest` all live in `RewardPipeline.Result`, which **dies in `commit`** today. Two ways to surface it:

- **Seam A — DEEPER, integrity-correct (recommended).** Thread `Result` through the gauntlet:
  1. Widen `Gauntlet.HandleResult` (`Gauntlet.luau` L36) to `{ ok, reason, projection?, result? }` where `result` is typed **`RewardPipeline.Result?`** (preferred over opaque `any?` so the strict checker proves only the two reward handlers produce it and consumers can't read garbage).
  2. Change `IntentHandler.commit` (`Gauntlet.luau` L24) from `(ctx) -> ()` to `(ctx) -> RewardPipeline.Result?` (the commit returns its `result` local). This is a **shared contract** implemented by EVERY registered handler — `CatchHandler`, `FireHandler`, the Step 6 buy/sell, Step 8 `mountTrophy`/`takeDownTrophy`/salvage, Step 9 travel, Step 12 trade, `EventRewardHandler` — all of which compile unchanged (they simply omit a return → `nil`); only the two reward handlers return their `result`. Keep it `--!strict`-clean and **re-run `./run-tests.sh` gates 1–4** (`clientCatch` constraint).
  3. `Gauntlet.handle` captures the commit return (L87 inside the `Transaction` closure and L94 non-critical) and puts it on `HandleResult.result`.
  4. `WorldServer` reads `r.result` (the `RewardPipeline.Result`) at the fire sites, merges with the server-rolled weight + shot zone + name, and ships the harvest envelope.
  - **Pro:** every displayed value is the authoritative committed number — no client derivation. **Con:** edits a headless contract shared by all handlers (must stay green).

- **Seam B — SHALLOW, Studio-only.** Don't touch the gauntlet. At the fire site, re-derive what's cheaply available from `Catalog` + `r.projection`: name/rarity/tier from `Catalog.*[targetId]`; cash from the `projection.balance` delta (already what `Hud` does); rare-vs-routine from `reward.kind`; `cleanKillMoment` from `Catalog.*[id].rare.intendedContentMoment`; weight + shot zone rolled/read locally.
  - **Pro:** zero headless change. **Con:** loses the authoritative `cash`/`boostCash` split (you only get a balance delta — and the boost portion is invisible) and `rankXP`; reintroduces a client/derived value the maps explicitly flag as a stopgap.

**Recommendation:** **Seam A.** The whole point of the card is to *display the authoritative cash and rare-moment*, and `Result` is the only place they exist correctly. Seam B re-creates the very `+$<delta>`-diff fragility (`Hud.luau` L123–128) this card is meant to retire. The gauntlet widening is small and mechanical.

### 4.5 Server-authority guarantees (the non-negotiables)

- The card **renders only** — it computes nothing of value. Cash, rarity, mint status, conquest, rankXP all arrive from the committed `RewardPipeline.Result`. Weight is server-rolled. ("The CLIENT asserts nothing" — `CatchHandler.luau` L6.)
- "MOUNT IT" does not mint or display — it fires the existing display intent **back through the gauntlet** (Step 8 CAS). The artifact is already minted server-side before the card ever shows.
- "MOUNT IT" does not mint or display — it fires the existing `mountTrophy` intent (`DisplayHandler.mountHandler`) **back through the gauntlet** (Step 8 CAS). The artifact is already minted server-side before the card ever shows.
- No client→emit analytics path (Wild World invariant): any card-impression metric is emitted **server-side** at the fire site via the existing `telemetry.incr` already used in `WorldServer`/handlers, not from the client.
- Headless/Studio split honored: all new render code is in `client/HarvestCard.luau` + the two `*.client.luau` controllers + `WorldServer.server.luau` (all excluded from `run-tests.sh`). The only headless touch is the optional Seam-A contract widening (`Gauntlet.luau`) + optional schema fields (`Schema.Creature.typicalWeightKg`, `PlayerData.seen`), each of which must keep `--!strict` + `luau-analyze` green and pass `./run-tests.sh`.

---

## 5. HUD-legibility (addressing the known open cluster)

The known HUD-legibility cluster shows in the current HUD: `Hud.luau` uses `BackgroundTransparency = 0.35` panels (L46/L61/L107) and `TextStrokeTransparency = 0.4` only on the toast (L84) — thin contrast over a naturalistic outdoor scene, no safe-area inset (`IgnoreGuiInset = true`, L20), and fixed pixel offsets that don't scale across phone→desktop. The card must not inherit those problems. Requirements:

- **Contrast:** the plaque is an **opaque** textured panel (not `0.35` transparent) with a dark scrim behind text (≥ 0.6 opacity) so bone-white text clears WCAG-ish contrast over bright sky/snow/water. Add a `UIStroke`/`TextStrokeTransparency ≤ 0.2` on the species name and the cash value specifically.
- **Scale & DPI:** size the card with a `UIScale` driven by viewport (clamp ~0.8–1.3) plus a `UIAspectRatioConstraint`, instead of the fixed `UDim2.fromOffset` the current header uses (L43–50). Min touch target 44px for "MOUNT IT" (the current `M.button` defaults to 48px — reuse it).
- **Safe area:** because `Hud.gui.IgnoreGuiInset = true`, manually inset the card from `GuiService:GetGuiInset()` and keep it clear of the bottom action bar (CAST/REEL/FIRE buttons sit at `(1,-150)`, see the controllers) and the tension gauge (`Gauge` at `0.5,0.86`, `Hud.luau` L103). Lower-center placement (§3.2) must not overlap the gauge during a back-to-back catch — offset the card above the gauge band.
- **Type hierarchy:** species name `GothamBold` ~24–28, weight/rarity ~16, cash ~22 (match header `cashLabel` 22, L49), chips ~13. One accent color per card (rarity-keyed), everything else bone/`(235,235,220)` on dark — consistent with the existing palette so the card reads as part of the same HUD.
- **Color-blind safety:** rarity is conveyed by **the word + tier number**, not color alone.
- **Motion restraint:** no full-screen flash; the rare gold sweep is on the plaque only — legibility of the cash number is never sacrificed to FX.

---

## 6. Invariants this design must (and does) respect

- **Server-authoritative, no client mint:** card renders committed `RewardPipeline.Result` + server-rolled weight; "MOUNT IT" routes the display intent through the gauntlet. ✅
- **Reward XOR intact:** the card branches routine(cash)/rare(mint); a rare shows `cash==0` as "ADDED TO COLLECTION", never a payout. The card adds no value. ✅
- **No new value path / reconciliation untouched:** weight is **cosmetic only** — it does NOT feed `Economy.payout` (keyed `tier+rarity+destinationId+loop`) and is never added to a ledger entry. No "bigger pays more." The boost portion is *displayed* split out but is still the existing separate `boostBonus` `loop="none"` entry (`RewardPipeline.luau` L161–175) — we read it, we don't change it. ✅
- **Closed enums:** rarity/loop rendered from `Enums`, no synonyms. ✅
- **No client→emit analytics:** impression metrics server-side. ✅
- **Monetization never-power:** the card surfaces the existing 2x/VIP `boostCash` as a Cash bonus line; it introduces no new grant and no power. ✅
- **derive-don't-store:** weight is rolled at resolve and shipped, never stored on the artifact/`Provenance` (consistent with `TrophyHall.plaque` L56–59). ✅

---

## 7. ASCII mockup

**Routine catch (fishing, cash branch):**

```
                       ╔══════════════════════════════════════════╗
                       ║ ▓                                      ▓ ║   ← brass corner brackets
                       ║          L A R G E M O U T H   B A S S    ║   GothamBold 26, bone, stroke
                       ║   ────────────────────────────────────   ║   ← rarity rule (Uncommon = sage)
                       ║                                           ║
                       ║     ⬤ UNCOMMON · Tier 2 · Bayou      NEW! ║   rarity word + tier (not color-only)
                       ║                                           ║
                       ║     WEIGHT          8.4 lb                ║   server-rolled; lb (or kg, OD-2)
                       ║     CATCH          $  124                 ║   Result.cash  (authoritative)
                       ║     BOOST  (2x)    +$  124                ║   Result.boostCash (only if >0)
                       ║     ANGLER XP      +18                    ║   Result.rankXP
                       ║                                           ║
                       ╚══════════════════════════════════════════╝
                                 (auto-dismiss 3.5s / tap)
```

**Rare mint (hunting, artifact branch — the trophy card):**

```
                  ╔══════════════════════════════════════════════════╗
                  ║ ✦   ★  A   L   B   I   N   O    B   U   C   K  ★  ✦ ║  gold sweep, Legendary amber
                  ║   ══════════════════════════════════════════════   ║
                  ║        "A ghost of the deep timber"               ║  cleanKillMoment (headline)
                  ║                                                    ║
                  ║   ⬤ LEGENDARY · Tier 3 · Appalachia        NEW!   ║
                  ║   WEIGHT      241.6 lb        ◇ HEADSHOT          ║  weight + shotZone=='vital'
                  ║                                                    ║
                  ║              ✶ ADDED TO COLLECTION ✶              ║  (NOT "$0" — XOR rare branch)
                  ║   ┌────────────────────┐   ┌──────────────────┐   ║
                  ║   │     MOUNT  IT       │   │   Keep in Bag    │   ║  fires display intent (gauntlet)
                  ║   └────────────────────┘   └──────────────────┘   ║
                  ╚══════════════════════════════════════════════════╝
```

**Conquest overlay (when `conquestNewlySet`):** a thin banner clipped to the card's top edge — `▰ APPALACHIA CONQUERED ▰` — in the rarity accent, above the species name.

---

## 8. RESOLVED DECISIONS (v1 — locked 2026-06-19, owner-confirmed)

- **OD-1 → Seam A — IMPLEMENTED via a Ctx result-sink (refinement found during build).** Strict Luau requires *all codepaths* to return, so widening `commit` to `(ctx) -> any?` forces `return nil` into all ~11 other handlers (gate-1 proved this). Implemented instead as a per-request **`ctx.resultSink` output channel**: `commit` stays `(ctx) -> ()` (no other handler touched), the two reward handlers publish `ctx.resultSink.value = result`, and `Gauntlet.handle` surfaces it on `HandleResult.result`. Same goal, minimal blast radius (3 files).
- **OD-2 → lb, fish + creatures.** Roll fish weight from `typicalWeightKg`; **ADD** optional `Schema.Creature.typicalWeightKg` + author values in `Creatures.luau` (v1; cosmetic, no migration). Display lb. Use a triangular roll biased low so big weights/records feel rare. Weight never feeds `Economy.payout`.
- **OD-3 → Tier A** (rares-only "NEW!", derived from `profile.artifacts`; no schema/migration). Tier B (`profile.seen`) deferred.
- **OD-4 → reserve, don't build.** The `trait` row is reserved (renders nothing); the weather/trait system is the separate `SYS_liveops_weather_traits.md` spec.
- **OD-5 → `shotZone` + distance chip** (hunting). Caliber-appropriateness / shot-count deferred.
- **OD-6 → weight + rarity only** for fishing v1; `fightDifficulty` grade deferred.
- **OD-7 → keep HELD on "Keep in Bag"** (Lodge UI mounts later); card shows "Lodge n/12" from `TrophyHall.slotUsage` and warns when full. No auto-mount.
- **OD-8 → Hybrid.** Full plaque on **rare mint / record weight / first-time (NEW)**; lightweight `"+$x Species"` toast for routine repeats (anti-spam for high-throughput Bayou).
- **OD-9 → deferred.** A dedicated screenshot pose is a later nice-to-have; the plaque itself is the shareable artifact for v1.

_Original options & rationale (kept for the record):_

- **OD-1 — Result-surfacing seam.** Seam A (widen `Gauntlet.HandleResult` + `IntentHandler.commit` return type — authoritative cash/boost/XP, touches a shared headless contract) vs Seam B (Studio-only re-derive — no headless change, loses authoritative cash split). **Recommend A.** Owner decides whether the contract change is acceptable now or deferred (B as a stopgap, A later).
- **OD-2 — Weight unit & roll shape.** lb (GH idiom, screenshot familiarity) vs kg (schema-native, `typicalWeightKg`)? Uniform roll vs triangular (bias to smaller, makes records feel rare)? And: do creatures get a weight at all in v1 (requires NEW `Schema.Creature.typicalWeightKg` + authoring in `Creatures.luau`), or do only fish show weight initially?
- **OD-3 — Bestiary "NEW!" depth.** Tier A (rares-only, zero schema change, derive from `profile.artifacts`) vs Tier B (NEW `profile.seen` set + version bump → "NEW!" for routine species too). Tier B is the fuller GH/HS bestiary feel but needs a migration.
- **OD-4 — Trait/mutation slot.** The card reserves a trait row but **no trait system exists** (`liveops`/`spawnEcon` gaps). Is a GH-style weather-gated stackable mutation trait on the roadmap (it would touch `spawn.conditions`/`rareSpawnEligible` and the RewardPipeline bonus seam), or do we permanently drop the row? This is a much larger feature — flag, don't build here.
- **OD-5 — Shot-quality readout depth.** Ship just `shotZone` (vital/limb/body → "HEADSHOT"/"clean"/"body"), or adapt more of Hunting Season's model (distance, caliber-appropriateness, shot count)? Distance is in scope at the fire site (`distance`, `WorldServer` L820) but caliber-appropriateness has no existing factor. Recommend `shotZone` + optional distance chip for v1.
- **OD-6 — Fishing "skill" parallel.** Should fishing show a fight grade derived from `fightDifficulty` (`Schema.Fish`) as the shot-quality analog, or leave fishing to weight+rarity only? (Hunting Season grades shots; GH does not grade fish.)
- **OD-7 — "MOUNT IT" default & Lodge state.** Does declining ("Keep in Bag") leave the artifact HELD (current model) and rely on the Lodge UI to mount later, or do we auto-mount if a slot is free? `TrophyHall.slotUsage` is already computed — should the card show "Lodge 4/12" and warn when full?
- **OD-8 — Card vs toast coexistence.** Replace the `"Down!"/"Landed!"` toasts entirely with the card, or keep a tiny toast for rapid-fire catches and only show the full card on rares + records + NEW? (Anti-spam consideration for high-throughput Bayou hunting at 85 ceiling/hr.)
- **OD-9 — Screenshot affordance.** Add an explicit "📷 frame this" idle pose / camera nudge for rares (lifts the 3D subject, hides HUD chrome for 1.5s) to make the moment deliberately shareable, or keep it incidental?

---

**Net delta summary:** NEW `client/HarvestCard.luau`; edits to `client/FireController.client.luau` (L51–55), `client/FishingController.client.luau` (L98–104), `client/Hud.luau` (add `showHarvest` host + legibility scaffolding), and `WorldServer.server.luau` (fire-site envelope assembly + weight roll + shot-zone capture at L863/L986). Optional headless touches gated by OD-1/OD-2/OD-3: widen `Gauntlet.HandleResult`/`IntentHandler.commit` (`src/server/authority/Gauntlet.luau`), add `Schema.Creature.typicalWeightKg?` and/or `PlayerData.seen` (`src/types/Schema.luau`). Everything authoritative flows from the already-computed-but-discarded `RewardPipeline.Result`.

---

## Faithfulness review (automated adversarial pass · 2026-06-19)
**Verdict: faithful = True** — every referenced symbol/file was confirmed against the codebase maps; no invented APIs. The following are refinements to fold in during implementation (none are blockers):

- **[medium]** This understates the blast radius and the --!strict cost. Gauntlet.IntentHandler.commit is currently typed (ctx: Ctx) -> () (Gauntlet.luau L24) and is implemented by EVERY registered handler in the registry — not just FireHandler/CatchHandler, but buy/sell (Step 6), salvage/display (Step 8), travel (Step 9), trade (Step 12), and EventRewardHandler (claimEventReward). Widening the field type to (ctx) -> any? forces a re-typecheck of the whole handler registry under --!strict; handlers whose commit currently ends without a return are fine, but Gauntlet.handle's two call sites (L87 inside the Transaction closure, L94 non-critical) must both capture and thread the return, and HandleResult (L36) gains a result field. The negative fixtures and run-tests.sh gate-1 (luau-analyze --!strict on every headless module) must stay green across all of those.
  - _Re:_ Seam A step 2: 'Change IntentHandler.commit from (ctx) -> () to (ctx) -> any? ... a shared contract touched by CatchHandler, FireHandler, and every other handler — most return nil unchanged.'
  - _Fix:_ Keep the recommendation (Seam A) but enumerate the full handler set that the contract change touches and call out that ./run-tests.sh gates 1-4 must be re-run; prefer typing the new slot as RewardPipeline.Result? rather than opaque any? so the strict checker still proves the only producers are the two reward handlers and consumers can't read garbage. Note that EventRewardHandler.commit and all Step 6/8/9/12 handlers must compile unchanged (they simply omit a return).
- **[low]** These line numbers are accurate as verified, but two are off-by-a-hair vs. the actual ranges and could confuse an implementer: zoneOfHit is L797-800 (correct), the killing-shot zone is captured at L821 (spec says 'L821' in field 5 — correct) but §4.4 Seam A bullet 4 says weight/shot-zone are 'in scope in the OnServerEvent closure' which is true only for hunting (the fish fight closure at L961-995 has no zone). The boost computation actually spans L155-175 (the multiplier read is L161); citing 'L161-175' omits the explanatory comment block but points at the right code.
  - _Re:_ Section 1.1 table and §4.2: the fishing landed fire is at WorldServer L986 and the FishingController landed branch is at L98-104; §2.1/OD-5 cite zoneOfHit at L797-800, distance at L820, and the boost block at L161-175.
  - _Fix:_ Clarify that shotZone/distance are hunting-only (the fish landed path at L961-995 has no hit-zone concept, consistent with field 5 marking fishing 'n/a' and OD-6 proposing fightDifficulty as the parallel). No code change to the design; just tighten the prose so an implementer doesn't look for a zone in the fishing closure.
- **[low]** Both are correctly flagged NEW and confirmed absent (Creature L106-135 has no weight; PlayerData L276+ has firstSeenAt/lastSeenAt but no seen set). The spec is faithful. The only gap: it does not mention that any new PlayerData field must also pass the negative-fixture / config-self-validation discipline and that a profile-shape change touches the persistence migration path (ProfileStore), which is a real headless surface — not just 'a migration default {}'. Schema.Creature.typicalWeightKg? being optional is safe (no migration needed, builders/Validation just ignore nil).
  - _Re:_ §2.1: 'Add an optional typicalWeightKg: {min:number, max:number}? to Schema.Creature' and §2.3 Tier B: 'add profile.seen: { [string]: boolean } to PlayerData ... Requires a profile-version bump and a migration default {}.'
  - _Fix:_ For Tier B / OD-3, add a note that profile.seen is a persisted-shape change requiring the ProfileStore migration/version path and a tests pass, raising its cost above the cosmetic Schema.Creature.typicalWeightKg? addition. This strengthens the OD-3 cost framing; it does not change the recommendation.
- **[low]** The spec asserts a 'display' intent exists as a registered Gauntlet handler. The maps reference Step 8 'call-the-CAS salvage/display/sink' and ArtifactStore, and the memory index confirms Step 8 Lodge/Trophy Hall shipped with display transitions, but the provided codebase maps do not name the exact intent string ('display' vs 'mount' vs 'setDisposition') or the handler file. This is plausibly real but unverified in the supplied maps.
  - _Re:_ §3.3 / §4.5: '"MOUNT IT" fires the existing display intent through the gauntlet (the display/salvage CAS transitions owned by Step 8 / ArtifactStore)'.
  - _Fix:_ Before wiring 'MOUNT IT', confirm the exact registered intent name and handler module for the DISPLAYED disposition transition (Step 8) and cite it, so the client fires the correct intent string. If the intent is named differently, update §3.3/§4.5 accordingly. The design principle (card routes through the gauntlet, never mints/displays itself) is correct regardless.
