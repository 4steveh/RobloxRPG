# Bayou + Lodge Visual Overhaul — Design Spec

**Date:** 2026-06-18
**Status:** Approved design → implementation planning
**Scope:** Take the Bayou (starter world) + the Lodge (home hub) from greybox to a flagship, grounded-naturalistic visual bar — "on par or better than the most popular Roblox games" — then templatize the proven pipeline to Appalachia & Alaska.

---

## 0. Context & constraints

### Starting point (verified in Studio + code)
- The Edit-time place is empty (`Workspace` = empty `Terrain` + `Camera`; `Lighting` has **zero** children). **Everything visual is generated at runtime** by `src/server/world/WorldServer.server.luau`:
  - Worlds: flat colored ground `Part`s, thin "zone pad" parts, landmark **boxes** (the Old Cypress = an 8×80×8 brown box), vendor-anchor cubes.
  - Lighting: fog only (`FogStart`/`FogEnd`/`FogColor`).
  - Animals (~26): procedural box-silhouettes (torso + head + limb cubes), flat-colored, no locomotion beyond a tip-over death.
  - Fish: translucent blue **balls** (the `FishingFeel` module renders a landed-fish reveal).
  - Vehicles (boats/mounts/dogs): not modeled; Boat Dealer is a labeled cube.
  - Lodge: a floor slab + 7 colored service cubes.

### Hard environment facts
- **Headless test gate** (`run-tests.sh`) analyzes every `.luau` under `src/` + `tests/` **except** `*.server.luau` / `*.client.luau`; it never scans `client/`. Any module with Roblox globals must therefore be a `*.server.luau`/`*.client.luau` script or live in `client/`. Pure-data modules (no Roblox globals) under `src/` are fine.
- **Rojo mapping**: `src/` → `ServerScriptService.WildWorld`; `client/` → `StarterPlayer.StarterPlayerScripts`. **Rojo owns only those two folders.** It does **not** touch `Lighting`, `Workspace`/`Terrain`, or `ReplicatedStorage` — so baked art content and live-synced gameplay code cannot clobber each other, and a Rojo live-sync will not delete baked art.
- **Concurrency reality**: one shared working directory; a gameplay terminal is on branch `s2-creature-movement` building **creature movement/AI**. ⇒ This effort touches **none** of their files, builds **no** creature locomotion, and does not switch branches / commit on the shared tree.

### Locked decisions (from brainstorming)
- **Sequence**: Bayou + Lodge depth-first to a flagship bar, then templatize.
- **Pipeline**: HYBRID — terrain/water/atmosphere/lighting in code; animals/fish/vehicles/landmarks as bespoke AI-generated meshes; filler props via Creator Store + AI materials.
- **Art direction**: grounded-naturalistic with cinematic light (humid dawn, golden raking sun, fog-in-the-fire haze; the Ghost-Gator-in-the-murk mood).
- **Integration**: a **decoupled, additive art layer** — zero edits to gameplay files; the creature visual upgrade happens **in place** on spawned models.

### Numeric authority
Roblox documents property *names/types* and a few *hard ranges* exactly, but **not** most Atmosphere/post-FX min/max. Values below are marked **(ENGINE)** = confirmed fact, or **(TUNE)** = author-recommended working value to eyeball in Studio at the target `ClockTime`. Do not treat TUNE numbers as spec; they are starting points.

---

## 1. Architecture — the decoupled art layer

Three artifacts, all additive:

### 1.1 `src/config/ArtAssets.luau` — the asset manifest (headless-safe data)
A pure-data module (no Roblox globals → passes `--!strict`) recording, per species/prop/material, the generated Roblox **asset IDs** plus tuning: scale, palette `Color3` components (as `{r,g,b}` numbers), poly tier, hitZone layout for creatures, and prop scatter parameters. This is the **single durable record** of every AI-generated asset, so the look is reproducible from repo + asset IDs. Mesh generation is non-deterministic and asset IDs are permanent once created; this module pins them.

### 1.2 `src/server/world/WorldArt.server.luau` — the server art builder (Studio-only Script, excluded from the test gate)
A **new** server `Script` that runs alongside `WorldServer` and:
- Sets the scriptable global look (Atmosphere, Clouds, Sky, post-FX, `Lighting` color/time values).
- Builds Bayou terrain + water + standable hummocks via the `Terrain` Fill API.
- Scatters props (cypress, knees, moss, palmetto, logs, lily/duckweed) by asset ID from the manifest, instanced for batching.
- **Suppresses** `WorldServer`'s placeholder visual boxes (flat ground, zone pads, landmark beacons, vendor anchors) — sets `Transparency = 1` / `CanQuery = false` / removes purely-visual placeholders — while leaving all functional anchors (`SpawnLocation`s, the `HuntingTargets`/`FishingBites` folders, zone attribute carriers) intact.
- Builds the Lodge interior shell, materials, light rig, and the trophy-hall framing (reading the existing Step-8 display projection — view-not-store).
- Runs the **in-place creature/fish visual upgrade** (§4) and the **one central cosmetic-animation `Heartbeat` loop** (§4.3).
- Drives the **Ghost-Gator back-slough local atmosphere transition** (§3.4).

> Non-scriptable properties (`LightingStyle = Realistic`, `PrioritizeLightingQuality = Enabled`) cannot be set from a script. They are set once in the place (verify in Studio; the place already carries the unified-migration flag). Everything else above is scriptable.

### 1.3 `client/WorldArtClient.client.luau` (+ small `.luau` helpers) — client-only FX
- The **graphics-quality toggle** (low-end fallback: cull distant creatures, drop shadow-casters/effects; the non-scriptable lighting style cannot be changed at runtime, so the toggle works through cull/effect levers).
- **DepthOfField** on ADS/scope-aim, photo mode, and the trophy-placement beat only — never constant.
- Ambient client sprites that benefit from client-side motion (dragonflies, fireflies), camera/photo-mode polish.

### 1.4 The creature seam (no `WorldServer` edit)
`WorldArt` connects to `workspace.HuntingTargets.ChildAdded` (and `FishingBites.ChildAdded`) and **upgrades each spawned model in place**:
1. Keep the `Model`, its `PrimaryPart`, and the `maxHealth`/`currentHealth`/`targetId`/`creatureId` attributes.
2. Destroy the placeholder visual child parts (everything except `PrimaryPart`); set `PrimaryPart` invisible + `CanQuery=false` (it remains the anchor the rig welds to).
3. Weld in the AI mesh parts (head / body / limbs), tagging them with the matching `hitZone` attribute and `CanQuery=true`.
4. Register the instance in the cosmetic-animation loop; deregister + clean up on removal.

This preserves every existing contract: the server fire-raycast (`FindFirstAncestorOfClass("Model")` + `hitZone`), the client aim-highlight, the `CreatureLabels` health billboards, and the `playDeath` animation all keep working unmodified.

**Alternative considered (deferred):** a one-line clone-from-library hook in `WorldServer.buildCreatureModel`. Cleaner, but edits a gameplay-owned file mid-concurrent-work. Graduate to it later once coordinated.

---

## 2. The global look (grounded-naturalistic + cinematic; fact-checked)

### 2.1 Lighting technology
- `Lighting.LightingStyle = Realistic`, `Lighting.PrioritizeLightingQuality = Enabled` **(ENGINE; non-scriptable — set in place / verify in Studio)**.

### 2.2 Bayou dawn key (scriptable, on `Lighting`)
- `ClockTime = 6.7` (dawn hero); ship a `17.8` dusk variant. **(TUNE)**
- `GeographicLatitude = 29` (low raking Louisiana sun). **(TUNE)**
- `Brightness = 2`, `ExposureCompensation = 0.15`. **(TUNE)**
- `Ambient = (54,60,48)` (cool-green shade fill), `OutdoorAmbient = (96,104,86)`. **(TUNE)**
- `ColorShift_Top = (255,214,150)` (warm sun), `ColorShift_Bottom` neutral. **(TUNE)**
- Leave legacy `Fog*` at defaults (Atmosphere is the depth tool) or set `FogEnd ≈ 520` only as a hard cull backstop.

### 2.3 Atmosphere (under `Lighting`)
Property names + dependency rules are **(ENGINE)**: `Decay` acts only when `Haze>0 AND Glare>0`; `Glare` acts only when `Haze>0`. Values **(TUNE)**:
- `Density 0.42`, `Offset 0.25`, `Color (208,196,158)`, `Decay (140,120,90)`, `Glare 0.35`, `Haze 2.2`.

### 2.4 Clouds (MUST be parented to `Workspace.Terrain` — **(ENGINE)** or they don't render)
- `Cover 0.55` (ENGINE range 0–1), `Density 0.18` (TUNE), `Color (245,240,228)` (TUNE), `Enabled = true`.

### 2.5 Post-processing stack (under `Lighting`; names ENGINE, values TUNE — always set Bloom explicitly, defaults changed in v0.726)
- `BloomEffect`: `Intensity 0.5`, `Size 24`, `Threshold 0.9` (keep ≤ ~1.0).
- `ColorCorrectionEffect`: `Contrast 0.1`, `Saturation 0.08`, `Brightness 0`, `TintColor (255,246,230)` — cheapest, highest-impact lever.
- `SunRaysEffect`: `Intensity 0.18`, `Spread 0.9` (god-rays through canopy; keep low).
- `DepthOfFieldEffect`: OFF in normal gameplay; ADS/photo/trophy only — `FocusDistance 50`, `InFocusRadius 50`, `FarIntensity 0.2`, `NearIntensity 0`.
- Optional `ColorGradingEffect`, `TonemapperPreset = Default`.

### 2.6 Sky
Custom dawn skybox `Sky` under `Lighting`: six seamless 1024² faces (**ENGINE** texture cap), `CelestialBodiesShown = true`, slightly enlarged `SunAngularSize` (hazy low sun), modest `StarCount` for the dusk variant; warm horizon ~`#E6D2A0 → #F0DCB4`.

---

## 3. The Bayou environment (~420×520 studs)

### 3.1 Terrain (code-built; **(ENGINE)** API)
- `Terrain:FillBlock/FillWedge/FillBall/FillCylinder` for the channel bed, banks, and standable hummocks; `Terrain:FillRegion(region, 4, material)` for the broad basin + mud flats.
- `Terrain:ReplaceMaterial(region, 4, src, target)` (**resolution must be exactly 4**) for waterline blending. No `PaintRegion` runtime method exists.
- `Terrain:SetMaterialColor(material, color)` to push materials toward olive (`MaterialColors` editor is not scriptable).
- Materials: `Mud` (banks/shallows), `LeafyGrass`/`Grass` recolored olive (hummocks), `Ground` (trails); curve/blend all edges.
- `Terrain.Decoration = true`, `Terrain.GrassLength = 0.4` (ENGINE valid range 0.1–1.0).

### 3.2 Blackwater (TUNE; author at the dawn `ClockTime`, which auto-tints `WaterColor`)
- `WaterColor (44,56,36)` (dark olive tea), `WaterTransparency 0.22`, `WaterReflectance 0.55`, `WaterWaveSize 0.04`, `WaterWaveSpeed 4`.
- **Duckweed/algae film**: flat textured/decal planes (`#6F8A3C`, RGB 111,138,60) just above the water plane over ~30–50% of still water; open channels stay dark tea.

### 3.3 Palette (hex)
| Role | Hex | Role | Hex |
|---|---|---|---|
| Tannin open water | `#26301E` | Cypress bark | `#5A4D3B` |
| Water mid/olive | `#2C3824` | Bark shadow | `#3A3225` |
| Duckweed film | `#6F8A3C` | Spanish moss | `#9AA288`/`#7C846B` |
| Lily pad | `#3E5524`→`#5B7A2E` | Mud/bank | `#4A3B28` |
| Foliage shadow | `#1B3311` | Wet log | `#6B5A45` |
| Foliage mid | `#2D5B10` | Warm haze | `#C4BC98` |
| Foliage highlight | `#A6B96F` | Sky dawn | `#E6D2A0`→`#F0DCB4` |

### 3.4 Props & set-pieces
**Prop counts (instanced — one shared mesh per type for draw-call batching):**
- Bald cypress hero meshes: 60–90 in irregular groves of 4–9.
- Cypress knees: 6–14 per mature trunk → ~400–800 instances of **one** shared mesh (instancing-critical).
- Spanish moss drapes (alpha-card, `AlphaMode = Transparency`): on ~60–70% of cypress.
- Water tupelo 25–40; dwarf palmetto 40–70; cattails/reeds 80–150; lily rafts 60–120; understory shrubs 30–50; fallen mossy logs 25–40; standable hummock islets 15–25; plus Creator-Store ground clutter to break the stamped look.

**Hero set-pieces:**
1. **The Old Cypress (beacon)** — an oversized ancient cypress (~2× grove height, flared buttress, dense moss, knee ring) on a hummock at a sightline node; clearer ringing water for the postcard reflection; a `SunRays` shaft + a perched egret. Reads as the nav landmark from across the map.
2. **The Ghost-Gator back-slough** — a dead-end far-corner channel where, on player entry, `Atmosphere.Density` ramps locally toward ~0.6 (and cull distance shortens): fog burning at the waterline, skeletal leafless snags, thickest moss, deepest tea-water, dim light, a half-submerged gator silhouette (eyes/snout only — non-interactive menace), frog-heavy SFX. Visibility intentionally short so the gator looms.
3. *(Optional polish)* a half-rotted sunken-boardwalk artery framing the first impression.

### 3.5 Ambient life + SFX (cheap, high-impact)
2–4 wading egrets that flush on approach, 6–12 dragonfly sprite zones over duckweed, fireflies (dusk), the distant gator silhouette, and an audio bed (cicada/cricket drone, frog chorus swelling near dusk, distant calls, water lap).

---

## 4. Animals (~26) & fish (~25) — visual + cosmetic animation only

> **Lane boundary:** locomotion / pathing / flee-AI / spawn logic belong to the gameplay terminal's `s2-creature-movement` work. This effort delivers the **mesh + material upgrade** and **cosmetic secondary animation** that layer on top, reading `PrimaryPart` and never setting world position.

### 4.1 Mesh generation (HYBRID)
Grounded prompts; outputs a single static, watertight, neutral-pose, unrigged mesh. Poly + texture tiers (**ENGINE** hard caps: 20,000 tris/mesh, 1024² texture):
| Tier | Examples | Tris | Texture | Material |
|---|---|---|---|---|
| Low (many concurrent) | fish, rabbit, wood duck, frog | 300–1,200 | 256² | shared `MaterialVariant` + per-instance `MeshPart.Color` |
| Medium | deer, dog, mount, heron | 2,000–5,000 | 512² | `MaterialVariant`, optional `SurfaceAppearance` |
| High / apex (rare concurrency) | alligator, bear, prize mount | up to 8,000–10,000 | 1024² | dedicated `SurfaceAppearance` + `NormalMap` |

Prompt template example (alligator): *"A grounded-realistic American alligator ~10 ft, neutral resting pose, legs splayed, mouth closed, tail straight; dark olive armored scutes, cream-yellow belly, blunt snout; single watertight low-poly game mesh, quad topology, ~9,000 triangles, symmetrical, neutral stance for rigging, no base plane."* Author per-species prompts in this shape so meshes rig cleanly afterward. Filler/secondary species may use Creator-Store meshes + AI `MaterialVariant`.

Set every spawned mesh `RenderFidelity = Automatic` (free LOD at 250/500 studs) and `CollisionFidelity = Box`/none.

### 4.2 Rigging (assembled in code from generated meshes)
- No `Humanoid` on spawned creatures (Humanoid replication is the lag wall at ~20–30 NPCs).
- Build the body from MeshParts joined by `Motor6D`; attach `AnimationController` + child `Animator` (call `Animator:LoadAnimation`, not the deprecated controller method).
- `SurfaceAppearance` cannot be recolored at runtime ⇒ per-instance variation via `MeshPart.Color` or a swapped `MaterialVariant`, never a SurfaceAppearance tween.

### 4.3 Cosmetic animation (one central `Heartbeat` loop)
A single `RunService.Heartbeat` loop iterates all live creature instances and drives, **relative to `PrimaryPart`** (so it composes with the gameplay-driven movement, not against it):
- idle breathing/sway (sine on root joint `C0`, per-instance phase offset so herds don't sync),
- head-tracking toward the nearest player (lerp neck `C0`, clamped),
- limb/wing/tail flutter, gill/ear twitch (sine on limb joints),
- a banking/lean read derived from `PrimaryPart` velocity if the movement system exposes it (purely cosmetic).
All via `CFrame:Lerp` — never per-NPC `TweenService` tweens. Authored `Animator` animation assets reserved for hero beats only (death throe, fish breach). Fish: a swim-bob + a surface breach arc (quick upward `CFrame:Lerp`) with a `ParticleEmitter` foam ripple + expanding decal ring, integrated with the existing `FishingFeel` reveal.

### 4.4 Fish in water
Visible swimming fish models populate the fishing zones (low-poly, schooling via shared waypoint + per-fish offset); the bite/fight/landed beats build on `FishingFeel` so the catch resolves with a real fish, not a ball.

---

## 5. The Lodge & Trophy Hall (80×80 studs, ~20–22 stud interior height)

### 5.1 Interior lighting (local-light `Range` cap is now **120** (ENGINE) — budget 8–14 fixtures, not 30+)
**Shared-`Lighting` constraint:** the Bayou, the Lodge, and (later) Appalachia/Alaska all coexist in one place at spatial offsets and share **one global `Lighting` service** — so the Lodge **cannot** set its own global `ClockTime`/`Atmosphere` without overriding the Bayou's dawn look (and multiple players can span worlds simultaneously). Therefore the interior mood is delivered **locally**, not globally: (a) an **enclosed shell** (solid roof/walls, no skylight) so the global sun/sky/atmosphere don't penetrate; (b) the local warm light rig below as the real driver; (c) the global `Ambient (54,60,48)` set for the Bayou serves as the neutral minimum fill (the warm rig dominates). The Roblox indoor-sample globals (`ClockTime 15.6`, lifted `ExposureCompensation`, interior `Ambient (83,70,57)`, `EnvironmentDiffuseScale/SpecularScale 1`, gentler `SunRays`/`ColorCorrection`) are the **target** for a future **per-space lighting swap** (drive global `Lighting` by the local player's current world — requires the single-occupant / per-player-lighting assumption); noted seam, out of scope for this pass.

~11-light rig (each `Fire` emits **zero** light → pair every flame with a `PointLight`); cap shadow-casters at 3–5:
| Fixture | Type | Brightness | Range | Color | Shadows |
|---|---|---|---|---|---|
| Hearth core (+Fire) | PointLight | 3–5, flicker ±15–25% | 22 | (255,170,90) | ON |
| Hearth bounce | PointLight | 1.5 | 14 | (255,150,80) | off |
| Great-room wash ×2 | PointLight | 2 | 120 | (255,238,202) | off |
| Hanging lanterns ×3 | PointLight | 1.5 | 40 | (255,238,202) | off |
| Rare-trophy spot | SpotLight | 3 | 16 | (255,238,202) | off |
| Legendary spot | SpotLight ~35° | 5 | 18 | (255,210,140) | ON |
| Apex vitrine | SpotLight (top-down) | 4 | 12 | (255,238,202) | ON |
| Candle accents | PointLight | 0.7 | 8 | (255,202,156) | 1 hero ON |

Hearth flame particles: `LightEmission 1`, `LightInfluence 0`, size-over-lifetime tapering to 0.

### 5.2 Materials (metallic-roughness PBR via `SurfaceAppearance`/`MaterialVariant`; `StudsPerTile` so walls read architectural)
Log walls/beams `Wood` (Roughness ~0.6–0.8, NormalMap grain, high StudsPerTile); floor `WoodPlanks` (~0.5); hearth `Slate`/`Rock` (~0.85, the cool counterpoint); leather seating (~0.4); **brass** lamps/hinges/high-tier frames (`Metal`, Metalness 1, ~(196,160,82), Roughness ~0.3 — focal/wayfinding); **iron** rack/tools/low-tier plaques (`Metal`, dark ~(60,60,65), Roughness ~0.5 — subordinate). Rule: gloss/metalness encodes hierarchy.

### 5.3 Mount presentation + rarity framing (view-not-store; reads Step-8 display state)
Mixed vocabulary: wall mounts on wood backing plaques (default), pedestals (showpieces), `SurfaceGui` plaques (species + the player's caught weight/score + date — the top "this is MY lodge" detail), one glass vitrine (the apex item). 7 service stations ring the perimeter; the hearth-flanking wall is the trophy hall.

Rarity reads across **four stacking channels** (so it works desaturated/colorblind): frame material (iron/dark-wood → brass → ornate gold), backing & size (flush small → wood backboard medium → pedestal/vitrine large center-stage), accent light (none → dim neutral SpotLight → dedicated tinted SpotLight, Shadows ON), FX (none → faint shimmer → slow `ParticleEmitter` motes + SpotLight pulse). Palette: Common `#D1D5D8`, Uncommon `#41A85F`, Rare `#2C82C9`, Epic `#9365B8`, Legendary `#FAC51C`.

**Fills-as-you-succeed:** ship the room already framed — empty slots are visible low-lit silhouette/`?` plates, not blank wall; trophy SpotLights fade up as items are earned (the room literally brightens with progress); the dead-center hearth-adjacent slot is reserved for the Legendary; placement plays a short beat (SpotLight fade-up + chime + one-time mote burst) tied to the persisted display event.

---

## 6. Performance & mobile

- **Draw-call batching is the #1 lever**: one shared `MeshId` + identical texture/`MaterialVariant`/`SurfaceAppearance` per species/prop ⇒ concurrent instances collapse to ~one draw call (the ~400–800 knees especially). Any per-instance `SurfaceAppearance` difference breaks batching.
- **No `Humanoid`** on spawned creatures; one central `Heartbeat` loop, never per-NPC tweens. Validate ceilings: ≤ ~40–60 concurrent animated creatures, ≤ ~30 fish, with distance culling (deregister/hide beyond ~250 studs).
- **Lighting cost**: `LightingStyle = Realistic` is real GPU; cap shadow-casters (3–5 lodge / a handful outdoors); disable `CastShadow` on decorative props.
- **`RenderFidelity = Automatic`**, `CollisionFidelity = Box`/none on props/creatures. Texture memory: 256² small / 512² medium / 1024² hero only (1024² is 4× the memory of 512²).
- **`StreamingEnabled`**: recommended for the 420×520 map, but it is a **shared place setting** that can interact with the runtime spawner/placement and the back-slough atmosphere transition ⇒ **coordinate with the gameplay terminal; tune in the perf pass, do not flip unilaterally.**
- **Mobile**: watch total local lights/shadow-casters first, concurrent animated-creature count second, texture memory third; ship the client graphics-quality toggle; profile on mid-tier mobile.

---

## 7. Build order (each step independently visible/testable)

1. **Global look pass** — set the §2 lighting/atmosphere/clouds/post/sky on the existing geometry. Instant, cheapest, highest-impact. Validate via screen capture.
2. **Bayou terrain + blackwater** — sculpt landforms, lay the basin, swamp water values, olive material recolor, Decoration grass. Walkable swamp.
3. **Cypress grove + knees + moss** — generate hero cypress/tupelo + the shared knee mesh + moss alpha-cards; scatter per §3.4 (instanced). Scene reads "bayou."
4. **Old Cypress beacon + duckweed/lily film** — first postcard shot.
5. **Ambient life + SFX bed** — egrets, dragonflies, fireflies, audio, distant gator silhouette.
6. **Creature/fish visual pipeline** — `ArtAssets` manifest + the in-place upgrade + the central cosmetic-animation loop; generate + validate the **low-tier exemplars first** (rabbit, wood duck, catfish) before committing the full roster. Animals breathe/track/flutter atop gameplay movement; fish swim/breach.
7. **Apex alligator + Ghost-Gator back-slough** — the high-tier mesh + the local atmosphere transition + skeletal snags. Menace beat lands.
8. **Lodge shell + interior lighting + materials** — log walls/beams/floor/hearth + the §5 PBR + the 11-light rig with hearth flicker. Cozy walkable hub.
9. **Service stations + signage** — the 7 stations with brass-trim signboards + per-cluster lighting.
10. **Trophy hall** — plaque/pedestal/vitrine framing, the four rarity channels, silhouette placeholders, the SpotLight-fade placement beat wired to the persisted display state.
11. **Dusk variant + boardwalk polish** — the `ClockTime 17.8` set, fireflies, optional sunken boardwalk.
12. **Performance + mobile pass** — `StreamingEnabled` tuning (coordinated), shadow-caster + LOD + collision audit, the quality toggle, mid-tier mobile profiling.

Then **templatize** the proven pipeline → Appalachia & Alaska (where boats/mounts/dogs/snowmobile get their hero meshes).

---

## 8. Risks & unknowns (verify live in Studio)

- **AI-mesh quality is unverified until generated.** Cube 3D outputs static, unrigged, single meshes — watertightness, neutral pose, tri-count adherence, and clean rigging-to-Motor6D must be checked **per asset**. Build step 6 validates exemplars first; budget a manual cleanup/retopo fallback and a Creator-Store pivot for any asset that disappoints.
- **Atmosphere/Clouds/post-FX numbers are author-inferred**, not documented — eyeball + re-tune at the actual dawn `ClockTime`. `Haze` has no documented upper bound; Bloom defaults changed in v0.726 (always set explicitly).
- **`LightingStyle`/`PrioritizeLightingQuality` are non-scriptable** — confirm the place is on Realistic (it carries the unified-migration flag) and that the runtime quality toggle works through cull/effect levers, not the lighting style.
- **Time-of-day auto-tints `WaterColor`** — lock the target `ClockTime` before finalizing water values.
- **Draw-call batching** — verify in the MicroProfiler that shared-mesh foliage actually instances.
- **Concurrent-creature ceiling** is an estimate — profile the central loop at real spawn density on mid-tier hardware.
- **`StreamingEnabled` interactions** — confirm persisted lodge/trophy state, the back-slough transition, and Terrain water + duckweed planes behave across stream-in/out; coordinate the setting with the gameplay terminal.
- **Coordination with `s2-creature-movement`** — the cosmetic-animation loop must read, never set, world position; re-verify after their movement system lands (the `PrimaryPart`/attribute/`hitZone` contract is the integration boundary).

---

## 9. Integration contract (the boundary the gameplay terminal can rely on)

The art layer **only**:
- adds `Lighting`/`Workspace`/`Terrain`/`ReplicatedStorage` content (Rojo-safe, git-untracked),
- adds the new files in §1 (no edits to existing gameplay files),
- upgrades spawned `HuntingTargets`/`FishingBites` models **in place**, preserving `Model` + `PrimaryPart` + the `maxHealth`/`currentHealth`/`targetId`/`creatureId` attributes + `hitZone`-tagged `CanQuery` parts,
- reads creature/fish position from `PrimaryPart` and never sets it.

It does **not**: edit `WorldServer.server.luau` or any client controller, build creature locomotion/AI, switch git branches, or commit on the shared working tree.
