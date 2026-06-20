# Wild World — Comprehensive Review & Prioritized Implementation Roadmap
### Against the Modern Roblox Bar (2024–2026) · 2026-06-20

> Produced by a 9-agent grounded review (7 dimensions + a modern-Roblox web benchmark + synthesis),
> cross-checked against a first-hand live Studio play-test. Evidence is cited as `file:line` or a live-scene fact.

## 1. Executive verdict

Wild World has a **genuinely strong, server-authoritative gameplay spine and a real cinematic art layer** — it
is not a greybox. The headless math (combat/fishing inequalities, derived tiers, co-op effective-health, economy
reconciliation) is rigorous, and the Bayou's lighting/atmosphere stack is already Future-class *on intent*. But
the **felt experience lags the modern bar by a generation in exactly the areas players judge in the first 60
seconds**: no aim/ADS, no held-item grip pose, no character or creature animation (creatures slide; the rifle is
a static weld; arms never move), the gun and rod are untextured boxes, ~18 huntables render as grey blobs even
though finished meshes sit unused in the library, and the new player gets *zero* on-screen direction despite a
fully-built onboarding state machine that never reaches the client. **The good news:** almost every top fix is
**additive client/visual work over an already-correct authority layer** — the server already raycasts from the
camera (ADS needs no server change), the mesh library already exists (mapping is a data add), and the onboarding
beats already advance (they just need to be put in the projection). This is polish-and-surface, not a rebuild.

| Dimension | Verdict | One-line why |
|---|---|---|
| Environment graphics & art direction | **Near-bar** | Real cinematic stack, but image-based lighting is OFF (EnvDiffuse/Spec=0), fog is effectively disabled, dense foliage is flat boxes |
| Creature & held-item models | **Below-bar** | Finished meshes exist but ~18 huntables stay boxes (unmapped); rifle = 3 boxes, rod = 2 boxes |
| Player actions & aiming | **Far-below-bar** | One-tap fire, no ADS, no shoulder cam, no FOV zoom, no aim phase or settling reticle |
| Animation & movement | **Far-below-bar** | Stock avatar; arms never move on shoot/cast; creatures slide via PivotTo with frozen limbs; real rigs anchored as decor |
| Gameplay clarity, HUD & direction | **Below-bar** | Onboarding funnel never reaches client; no waypoint/arrow; EHT/EFT jargon; dated flat HUD |
| World depth & content | **Far-below-bar** | Named landmarks have no identity; zero interactables outside the Lodge; Bayou vendor outpost built then hidden (Transparency=1) |
| Core loop quality & fun | **Below-bar** | No risk/failure state in starter loop; fishing is hold-button with a fake gauge; rares are silent RNG |

## 2. The biggest gaps (deduplicated, by severity)

1. **No aiming at all** — one-tap fire, no ADS/shoulder cam/FOV zoom. Largest deviation from the genre bar (Hunting Season/Gone Hunting are ADS-first). `FireController:30`, `CharacterController:20-22`. Server is already aim-ray-only → ADS needs no server change.
2. **Held items never move the arms** — rifle/rod static welds, no grip/fire/cast/reel pose. `ViewModel:40-52`, `FishingFeel:66-80`.
3. **Creatures slide instead of walk; real animatable rigs sit anchored as decor.** `WorldServer.moveCreatures:747-756`; Bear/Grizzly are full R6 rigs w/ 32 Motor6D + a bundled Animation, never driven.
4. **~18 Appalachia/Alaska huntables render as grey boxes** though their meshes exist. `WorldArt.CREATURE_MAP:517-527` lists only `bayou_*`.
5. **Held weapon/rod are untextured boxes.** `ViewModel:34-36`, `FishingFeel:66-67`.
6. **First-session objective never reaches the client** — `Replication.buildProjection` omits `onboarding`; no waypoint/arrow anywhere in `client/`.
7. **Image-based lighting is OFF and fog is disabled** — `EnvironmentDiffuseScale=0`, `EnvironmentSpecularScale=0`, `FogEnd=100000` (code sets 320) → all 659 PBR meshes render flat.
8. **The Bayou vendor outpost is built then suppressed to invisibility.** `WorldServer:343-346` builds it; `WorldArt.suppressPlaceholders:474-497` sets `Transparency=1`.
9. **No risk/failure state in the starter loop** — non-lethal Bayou; fishing gauge is cosmetic (`FishingController:70,97`).
10. **Named landmarks have no in-world identity; zero ProximityPrompt/ClickDetector outside the Lodge.**

## 3. Prioritized roadmap

Effort: **S** ≤ half-day · **M** ~1–2d · **L** ~3–5d · **XL** > 1wk. All Wave 1/2 items are additive client/visual/data changes that preserve server authority and respect the LoadAsset constraint (procedural / generated / owner-owned meshes only).

### WAVE 1 — Hands, eyes, and direction (first-impression fixes)
- **1.1 AimController: hold-to-ADS** (shoulder camera offset + FOV 70→50 + DoF; separate touch AIM button) · *aiming* · high · **L**
- **1.2 ArmPose: procedural grip/aim/fire poses via Shoulder Motor6D** (two-handed grip, recoil spring) · *held-items + animations* · high · **M**
- **1.3 CREATURE_MAP data add: map every huntable to its existing mesh** · *models* · high · **S**
- **1.4 Generated/upgraded rifle + rod models (replace the boxes)** · *models + held-items* · high · **M**
- **1.5 Ship the onboarding beat to the client + objective tracker** · *clarity* · high · **M**
- **1.6 World-space waypoint Beam + screen-edge arrow to the objective** · *clarity* · high · **M**
- **1.7 Image-based lighting ON + restore fog** (one-line-class wins) · *graphics* · high · **S**

### WAVE 2 — Make it move and make it readable
- **2.1 Procedural creature gait** (legs/wings sync to speed) · *animations* · high · **L**
- **2.2 Settling sway reticle + vital-zone pip** · *aiming* · high · **M**
- **2.3 Drive the real Bear/Grizzly rigs with their bundled Animation** · *animations + models* · high · **M**
- **2.4 Modern HUD restyle + decode EHT/EFT** · *clarity* · medium · **M**
- **2.5 Always-visible station affordances + un-hide the Bayou outpost** · *clarity + world-depth* · high · **M**
- **2.6 Wire the daily-quest board to the client** · *clarity* · high · **M**

### WAVE 3 — Make the loop have teeth
- **3.1 Real fishing tension minigame** (analog band) · *gameplay* · high · **M**
- **3.2 Weapon feel: magazine + reload + ADS-tightened window** (session ammo, not persisted) · *gameplay + aiming* · high · **M**
- **3.3 Let the apex threaten: scope non-lethal + downed/revive beat** · *gameplay* · high · **M**
- **3.4 Rare tracking layer** (sign + proximity tell, not silent RNG) · *gameplay + clarity* · high · **M**
- **3.5 Flocks/herds + ambiance spawner** · *gameplay + world-depth* · medium · **S**

### WAVE 4 — Graphics polish & world depth
- **4.1 Batched alpha-card reeds/duckweed** (replace ~1330 boxes) · graphics · high · **M**
- **4.2 Landmark beacons + floating labels** · world-depth · high · **S**
- **4.3 StreamingEnabled + WorldArtClient quality toggle** · perf · high · **M**
- **4.4 Interactables + boat embark + lore caches** · world-depth · high · **M**
- **4.5 Ambient motion + per-world sensory set pieces** · world-depth + graphics · medium · **M**
- **4.6 Per-world look variants + bespoke dawn skybox** · graphics · medium · **M**
- **4.7 Sculpted elevation & water features** · world-depth · medium · **L/XL** (defer)

### WAVE 5 — Progression payoff & co-op
- **5.1 Tier the held-item model off equipped Loadout** · held-items + models · medium · **M**
- **5.2 Real per-species Lodge trophy mounts** · models + world-depth · low · **S**
- **5.3 Dynamic co-op party detection + one early co-op spectacle** · gameplay · medium · **M**
- **5.4 Stealth/approach verb + session objective drip** · gameplay · medium · **M**

## 4. Quick wins (<1hr each, high visibility)
- **Image-based lighting on** (`EnvironmentDiffuseScale/SpecularScale=1`) — 659 meshes stop looking flat instantly.
- **CREATURE_MAP data add** — biggest model upgrade for the least code.
- **Restore fog** (`FogEnd≈520` + warm FogColor); investigate the runtime override leaving it at 100000.
- **Un-hide the Bayou outpost** — name-whitelist Shack/Outfitter/Tackle/Signpost out of `suppressPlaceholders()`.
- **Comma-format cash + UICorner on the header**; **enlarge the crosshair** to a scalable ring.
- **Fix the first-payout delta** (seed `lastBalance` from the login StateSync projection).
- **Warn on CREATURE_MAP miss**; **fill the empty Lodge trophy frame**.
- **Fix the `DevTouchMovementMode` crash** (`CharacterController:26` errors every spawn — "lacking capability RobloxScript"). ✅ done.
- **Fix the oversized-gator scale** (the runtime fit-to-box-silhouette math balloons single-mesh creatures).

## 5. Risks & sequencing notes
- **Preserve authority/invariants:** ADS/ammo/tension changes must not move authority client-side. Server already raycasts from the camera ray. Ammo/reload = a **session counter, not persisted profile**. Fishing input must still validate against `Fishing.drainDerivable` — only the *mapping* changes.
- **Run `./run-tests.sh`** after any change touching `src/logic` or `src/server/authority` (esp. 1.5, 2.6, 3.x).
- **Headless/Studio split trap:** the creature upgrade path is Studio-only and `HuntingTargets` only exists at runtime — Play-test 1.3/2.3. Two prior boots surfaced env crashes invisible to tests.
- **Live atmosphere drift:** something overrode `applyGlobalLook()` post-bake (Brightness 3.13 vs 2, FogEnd 100000 vs 320) — reconcile before tuning or graphics fixes silently revert.
- **Script divergence:** the place has **baked standalone scripts** (`ServerScriptService.WildWorldArtRuntime`, `WildWorldArtSuppress`) duplicating the repo's `WorldArt` — consolidate onto one source.
- **StreamingEnabled (4.3)** is the highest-regression-risk change — guard part references with `WaitForChild`.
