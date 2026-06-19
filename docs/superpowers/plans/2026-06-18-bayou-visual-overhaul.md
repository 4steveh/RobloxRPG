# Bayou + Lodge Visual Overhaul — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Take the Bayou starter world + the Lodge hub from greybox to a flagship grounded-naturalistic visual bar, as a decoupled, additive art layer that touches no gameplay files.

**Architecture:** Three additive artifacts — a pure-data asset manifest (`src/config/ArtAssets.luau`), a server art builder (`src/server/world/WorldArt.server.luau`), and client-only FX (`client/WorldArtClient.client.luau`). Environment (terrain/water/lighting/atmosphere/props/lodge) is built at runtime by the server script; AI-generated meshes are baked Roblox assets pinned by ID in the manifest; spawned creatures are upgraded **in place** so no gameplay contract changes.

**Tech Stack:** Roblox Luau, the Studio MCP (`execute_luau`, `generate_mesh`, `generate_material`, `search_asset`/`insert_asset`, `screen_capture`, `inspect_instance`), `Terrain` Fill API, Unified Lighting, `Motor6D`+`Animator`, `RunService.Heartbeat`.

## Global Constraints

- **Touch no gameplay files.** Do not edit `WorldServer.server.luau` or any existing `client/` controller. Only create the three new files below + add place content (Lighting/Workspace/Terrain/ReplicatedStorage).
- **No creature locomotion.** Movement/pathing/flee-AI belong to the gameplay terminal's `s2-creature-movement`. This plan delivers visual mesh + **cosmetic** secondary animation that reads `PrimaryPart` and never sets world position.
- **Git is hands-off on the shared tree.** Do not switch branches or commit. New source files are written to disk (they Rojo-sync into the place). All other art is baked into the live place via the MCP (Rojo-safe — Rojo owns only `ServerScriptService.WildWorld` + `StarterPlayerScripts`). Git/branch handling is the user's call.
- **Verification = visual, not unit-test.** Each task ends with a `screen_capture` and/or `inspect_instance` check with an expected observation. The headless `run-tests.sh` gate must stay green: `ArtAssets.luau` is pure data (no Roblox globals) so it passes `--!strict`; the two scripts are `*.server.luau`/`*.client.luau` and are excluded from analysis.
- **Numeric values are starting points.** Property values marked TUNE in the spec are eyeballed at the target `ClockTime 6.7` in Studio and adjusted; ENGINE values are fixed facts. Re-tune after each capture.
- **Single shared `Lighting`.** Bayou + Lodge + (later) other worlds share one global `Lighting`. The Bayou dawn look is global; the Lodge reads warm from an enclosed shell + a local light rig (no per-space global override this pass).
- **Asset durability.** Every generated mesh's asset ID is recorded in `ArtAssets.luau` immediately after generation. Rig assembly is code; meshes are the only baked external dependency.

Spec: `docs/superpowers/specs/2026-06-18-bayou-visual-overhaul-design.md`.

---

## File Structure

- `src/config/ArtAssets.luau` (CREATE) — pure-data manifest: per species/prop/material asset IDs + tuning (scale, palette as `{r,g,b}`, poly tier, hitZone layout, scatter params). No Roblox globals.
- `src/server/world/WorldArt.server.luau` (CREATE) — server art builder: global look, terrain+water, prop scatter, placeholder suppression, lodge, in-place creature/fish upgrade, central cosmetic-anim loop, back-slough transition.
- `client/WorldArtClient.client.luau` (CREATE) — client FX: quality toggle, ADS depth-of-field, ambient sprites, camera/photo polish.
- Place content (baked via MCP, not git): `Lighting` (Atmosphere/Sky/post-FX + `Workspace.Terrain.Clouds`), `Workspace.Terrain` (sculpt+water), `ReplicatedStorage.WildWorldArt` (generated mesh assets / shared meshes), `Workspace` props.

---

## Phase A — Foundations & the instant-impact look

### Task A1: Verify lighting technology + lay the scaffold files

**Files:**
- Create: `src/config/ArtAssets.luau`
- Create: `src/server/world/WorldArt.server.luau`
- Create: `client/WorldArtClient.client.luau`

**Interfaces:**
- Produces: `ArtAssets` table with keys `lighting`, `atmosphere`, `clouds`, `post`, `sky`, `terrain`, `palette`, `props`, `creatures`, `fish`, `lodge` (later tasks populate sub-tables); the two scripts as empty-but-running shells.

- [ ] **Step 1: Confirm the place is on Unified Lighting (non-scriptable props).** Use `inspect_instance` on `Lighting`; confirm it carries `RBX_LightingTechnologyUnifiedMigration` (already seen). In Studio's Properties panel verify `Lighting.LightingStyle = Realistic` and `PrioritizeLightingQuality = Enabled`; if not, set them manually (they cannot be scripted). Record the confirmed state.

- [ ] **Step 2: Create the data manifest shell.** Write `src/config/ArtAssets.luau`:

```lua
--!strict
-- Pure-data art manifest (no Roblox globals → passes the headless --!strict gate).
-- The single durable record of every AI-generated asset ID + per-asset visual tuning.
-- Studio-only scripts (WorldArt.server / WorldArtClient.client) read this; nothing in
-- src/logic or src/server substrate depends on it. Colors are {r,g,b} 0-255 (the Studio
-- scripts wrap them in Color3.fromRGB). Asset IDs are "rbxassetid://N" filled as meshes are generated.
local ArtAssets = {
	version = 1,
	lighting = {
		bayouDawn = {
			clockTime = 6.7, geographicLatitude = 29, brightness = 2, exposureCompensation = 0.15,
			ambient = {54,60,48}, outdoorAmbient = {96,104,86}, colorShiftTop = {255,214,150},
		},
		bayouDusk = { clockTime = 17.8 }, -- overrides only; inherits bayouDawn otherwise
	},
	atmosphere = { density = 0.42, offset = 0.25, color = {208,196,158}, decay = {140,120,90}, glare = 0.35, haze = 2.2 },
	clouds = { cover = 0.55, density = 0.18, color = {245,240,228} },
	post = {
		bloom = { intensity = 0.5, size = 24, threshold = 0.9 },
		colorCorrection = { contrast = 0.1, saturation = 0.08, brightness = 0, tint = {255,246,230} },
		sunRays = { intensity = 0.18, spread = 0.9 },
		depthOfField = { focusDistance = 50, inFocusRadius = 50, farIntensity = 0.2, nearIntensity = 0 },
	},
	sky = { assetIds = {} }, -- six skybox face image ids, filled later
	terrain = {
		water = { color = {44,56,36}, transparency = 0.22, reflectance = 0.55, waveSize = 0.04, waveSpeed = 4 },
		grassLength = 0.4,
		materialColors = { LeafyGrass = {78,92,52}, Grass = {88,100,58}, Mud = {74,59,40}, Ground = {86,72,52} },
	},
	palette = {
		waterOpen = {38,48,30}, waterMid = {44,56,36}, duckweed = {111,138,60},
		foliageShadow = {27,51,17}, foliageMid = {45,91,16}, foliageHi = {166,185,111},
		barkMid = {90,77,59}, barkShadow = {58,50,37}, moss = {154,162,136},
		mud = {74,59,40}, wetLog = {107,90,69},
	},
	props = {}, -- [propId] = { meshId=..., scale=..., color={...}, count=..., zones={...} }
	creatures = {}, -- [creatureId] = { parts = { {name=,meshId=,size=,hitZone=,offset=} }, scale=, color= }
	fish = {}, -- [fishId] = { meshId=, scale=, color= }
	lodge = {}, -- fixture/material/light tuning filled in Phase C
}
return ArtAssets
```

- [ ] **Step 3: Create the server builder shell.** Write `src/server/world/WorldArt.server.luau`:

```lua
--!nonstrict
-- STUDIO-ONLY (excluded from run-tests.sh). The decoupled art layer. Builds the global look,
-- the Bayou environment, the Lodge, and the in-place creature/fish visual upgrade + cosmetic
-- animation. Touches NO gameplay file. Runs alongside WorldServer; additive only.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ArtAssets = require(ReplicatedStorage:WaitForChild("WildWorld") and game:GetService("ServerScriptService").WildWorld.config.ArtAssets)
local function c3(t) return Color3.fromRGB(t[1], t[2], t[3]) end

-- module-level handles populated by the build functions below
local M = { animated = {} } -- M.animated = { [model] = { creatureId, joints, phase } }

-- (build functions added per task)

print("[WildWorldArt] online")
```

> Note: the `require` path for a `*.server.luau` under `ServerScriptService.WildWorld.server.world` to reach `...WildWorld.config.ArtAssets` is `require(game:GetService("ServerScriptService").WildWorld.config.ArtAssets)`. Simplify Step 3's require to exactly that; the `c3` helper converts manifest `{r,g,b}` to `Color3`.

- [ ] **Step 4: Create the client FX shell.** Write `client/WorldArtClient.client.luau`:

```lua
--!nonstrict
-- STUDIO-ONLY client FX: graphics-quality toggle, ADS depth-of-field, ambient sprites.
-- Additive; no gameplay coupling.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
print("[WildWorldArtClient] online")
```

- [ ] **Step 5: Verify the headless gate stays green + scripts load.** Run `./run-tests.sh`; expect ALL GREEN (ArtAssets passes `--!strict`; the two scripts are excluded but listed under "Studio-only"). Then in Studio, `start_stop_play(true)`, `get_console_output`, expect `[WildWorldArt] online` and `[WildWorldArtClient] online` with no errors. `start_stop_play(false)`.

### Task A2: The global look pass (lighting / atmosphere / clouds / post-FX)

**Files:** Modify `src/server/world/WorldArt.server.luau`

**Interfaces:**
- Consumes: `ArtAssets.lighting/atmosphere/clouds/post`, `c3`.
- Produces: `M.applyGlobalLook()` (idempotent; creates-or-updates the singletons).

- [ ] **Step 1: Implement `M.applyGlobalLook()`.** Add to `WorldArt.server.luau` — set the `Lighting` scalar/color props from `ArtAssets.lighting.bayouDawn`; create-or-find a single `Atmosphere` under `Lighting` and set Density/Offset/Color/Decay/Glare/Haze; create-or-find `Clouds` under `Workspace.Terrain` (Cover/Density/Color/Enabled); create-or-find `BloomEffect`/`ColorCorrectionEffect`/`SunRaysEffect` under `Lighting` and set per the manifest; create a disabled `DepthOfFieldEffect` (client enables it on ADS). Use a `findOrNew(parent, class, name)` helper so re-runs update rather than duplicate. Call `M.applyGlobalLook()` near the bottom of the script.

- [ ] **Step 2: Verify in edit mode.** `execute_luau` (datamodel `Edit`) to run the same look-application inline (so it's visible without Play), then `screen_capture` a wide shot of the existing greybox. **Expected:** warm dawn cast, visible haze/atmosphere on the horizon, soft bloom on bright surfaces, god-ray spread — a dramatic tonal shift from the flat fog-only baseline. `inspect_instance` on `Lighting` to confirm the `Atmosphere`/`BloomEffect`/`ColorCorrectionEffect`/`SunRaysEffect` children exist with the set values, and `Workspace.Terrain` has a `Clouds` child.

- [ ] **Step 3: Re-tune.** Adjust TUNE values in `ArtAssets.luau` (Atmosphere Density/Haze, Bloom Intensity, ColorCorrection) and re-capture until the dawn look is rich but readable (haze not milky, bloom not blown). Record final values in the manifest.

- [ ] **Step 4: Persist & verify.** Confirm `WorldArt.server.luau` + the updated `ArtAssets.luau` are saved to disk (Rojo-synced). Re-run `./run-tests.sh` → ALL GREEN. Capture one "before/after" pair for the user.

---

## Phase B — The Bayou environment

### Task B1: Terrain landforms + blackwater

**Files:** Modify `src/server/world/WorldArt.server.luau`, `src/config/ArtAssets.luau`

**Interfaces:**
- Consumes: `ArtAssets.terrain`, the Bayou zone centers/sizes (from `Shells.byDestination.bayou`, read via `require(...WildWorld.config.Shells)` — read-only).
- Produces: `M.buildTerrain()` (clears prior art terrain region, sculpts, paints, sets water).

- [ ] **Step 1: Implement `M.buildTerrain()`.** Add a function that: (a) sets `workspace.Terrain` water props from `ArtAssets.terrain.water`; (b) calls `Terrain:SetMaterialColor` for each entry in `ArtAssets.terrain.materialColors`; (c) lays a broad water basin with `FillBlock`/`FillRegion(region, 4, Enum.Material.Water)` across the playable footprint (~ -210..210 X, -260..260 Z) at a shallow depth; (d) raises standable land/hummocks with `FillBlock(cframe, size, Enum.Material.LeafyGrass)` keyed to the non-water zone centers (`sunny_levee`, `reed_edges`, `the_landing`, `arrival_clearing`) and `Mud` aprons at the waterline via `FillBall`; (e) carves the channels (`channel_banks`, `catfish_hole`, `cottonmouth_slough`) as water. Use a fixed region constant so re-runs `FillRegion(region,4,Enum.Material.Air)` to clear before rebuilding (idempotent). Enable `Terrain.Decoration = true`, `Terrain.GrassLength = ArtAssets.terrain.grassLength`.

- [ ] **Step 2: Suppress the placeholder ground.** Add `M.suppressPlaceholders()` — find `workspace.BayouShell_Placeholder.Ground` and its `Zones` pads; set `Transparency = 1`, `CanCollide = false`, `CanQuery = false` (keep them so any gameplay attribute reads still resolve; just make them invisible/non-blocking). Do **not** touch `SpawnLocation`s or the `HuntingTargets`/`FishingBites` folders. Call after `buildTerrain`.

- [ ] **Step 3: Verify.** Play (or `execute_luau` Server) to run `buildTerrain` + `suppressPlaceholders`; `screen_capture` from a few camera positions over the playable area. **Expected:** dark olive-tea water with slow ripples + reflections, mud banks blending to olive grass hummocks, animated Decoration grass, the flat green placeholder ground gone. `inspect_instance` `workspace.Terrain` to confirm `WaterColor (44,56,36)` etc.

- [ ] **Step 4: Re-tune water + materials** at `ClockTime 6.7` (time auto-tints water); adjust `ArtAssets.terrain` values; re-capture. Confirm files saved; `./run-tests.sh` GREEN.

### Task B2: Generate + scatter the cypress grove (trees, knees, moss)

**Files:** Modify `WorldArt.server.luau`, `ArtAssets.luau`

**Interfaces:**
- Consumes: `ArtAssets.props`, palette.
- Produces: `M.scatterProps()` + `ArtAssets.props.{cypress, cypressKnee, mossDrape, tupelo, palmetto, cattail, lilyPad, log}` entries with `meshId`, scale, count, and zone affinity.

- [ ] **Step 1: Generate the hero meshes.** Use `generate_mesh` for each, recording the returned asset ID into `ArtAssets.props`:
  - Bald cypress: *"A grounded-realistic bald cypress swamp tree, tall straight trunk with a wide flared fluted buttress base, sparse feathery needle canopy, a few bare branches; weathered grey-brown bark. Single watertight low-poly game mesh, ~4,000 triangles, vertical, no ground plane."* size ~`{40,90,40}`.
  - Cypress knee: *"A small knobby cypress root knee, rounded woody cone rising from the ground, weathered bark. Single watertight low-poly mesh, ~200 triangles, no base."* size ~`{3,5,3}` (this ONE mesh is reused 400–800×).
  - Spanish moss drape: *"A hanging clump of Spanish moss, wispy grey-green draping strands. Single low-poly alpha-card mesh, ~150 triangles."* (set `AlphaMode = Transparency` on its SurfaceAppearance).
  - Water tupelo, dwarf palmetto cluster, cattail/reed clump, lily-pad raft, fallen mossy log — one prompt each, recorded.

- [ ] **Step 2: Build the shared-mesh prop helper.** In `WorldArt.server.luau` add `spawnProp(propId, cframe)` that clones a single cached `MeshPart` template per `propId` (one `MeshId` + one shared `MaterialVariant`/`SurfaceAppearance` → draw-call batching), sets `Anchored=true`, `CanQuery` false for foliage / true for walkable logs, `RenderFidelity=Automatic`, `CollisionFidelity=Box`/None, applies per-instance `Color` jitter from the palette.

- [ ] **Step 3: Implement `M.scatterProps()`.** Scatter per spec counts using deterministic but irregular placement (grove clustering for cypress 4–9 per clump; ring 6–14 knees around each mature trunk; moss on ~65% of cypress; cattails along water margins; lily rafts on still water; logs near banks). Keep all foliage out of the `SpawnLocation` footprints and walking lanes between vendor/zones.

- [ ] **Step 4: Verify.** Run it; `screen_capture` wide + ground-level. **Expected:** the scene reads unmistakably as a cypress bayou — groved trees with buttressed bases, knee rings in the shallows, moss curtains, reed margins, lily rafts. Confirm via MicroProfiler note / `inspect_instance` that knees share one `MeshId` (batching). Re-tune density; save; `./run-tests.sh` GREEN.

### Task B3: The Old Cypress beacon + duckweed/lily film

**Files:** Modify `WorldArt.server.luau`, `ArtAssets.luau`

- [ ] **Step 1: Place the hero beacon.** Add `M.buildOldCypress()` — at `shell.landmarks.the_old_cypress.anchor`, place an oversized cypress (~2× grove scale, generated or the cypress mesh scaled up) on a raised hummock, with a dense knee ring, heavy moss, clearer ringing water (locally raise `WaterReflectance`/lower nearby duckweed), and a dedicated `SunRaysEffect`-catching gap + a perched egret static. Suppress the placeholder `OldCypress_Beacon` box.

- [ ] **Step 2: Lay the duckweed/lily film.** Add `M.layDuckweed()` — flat textured planes (`#6F8A3C`) just above the water plane covering ~30–50% of still-water zones (not open channels); reuse the lily-pad raft prop interleaved.

- [ ] **Step 3: Verify.** `screen_capture` framed on the Old Cypress with its reflection + a god-ray shaft. **Expected:** a postcard "hero" shot that reads as the map's nav landmark; duckweed greens the still margins while channels stay dark tea. Re-tune; save.

### Task B4: Ambient life + SFX bed

**Files:** Modify `WorldArt.server.luau`, `client/WorldArtClient.client.luau`, `ArtAssets.luau`

- [ ] **Step 1: Wading egrets/herons (server).** Add 2–4 static egret models (generated or Creator-Store) at channel edges that play a one-shot flap-and-rise (procedural `CFrame:Lerp`) when a player enters a radius, then resettle.

- [ ] **Step 2: Dragonflies + fireflies (client).** In `WorldArtClient.client.luau` add 6–12 sprite zones over duckweed (`ParticleEmitter`/billboard sprites drifting), fireflies as emissive sprites enabled only near the dusk `ClockTime`.

- [ ] **Step 3: SFX bed.** Add looping ambient `Sound`s (cicada/cricket drone, frog chorus that swells toward dusk, water lap, distant calls) via best-effort `rbxasset://`/Creator-Store audio, parented to `SoundService`/zone parts; silent on failure (match `HuntingFeel`'s pattern).

- [ ] **Step 4: Verify.** Play; `screen_capture` + `get_console_output`. **Expected:** dragonflies over the duckweed, an egret flushing on approach, audible swamp ambience; no errors. Save; `./run-tests.sh` GREEN.

---

## Phase C — Creatures & fish (visual + cosmetic animation only)

### Task C1: The mesh pipeline + the in-place upgrade (validate on exemplars FIRST)

**Files:** Modify `WorldArt.server.luau`, `ArtAssets.luau`

**Interfaces:**
- Consumes: `workspace.HuntingTargets` / `FishingBites`, the existing model contract (`PrimaryPart`, `maxHealth`/`currentHealth`/`targetId`/`creatureId` attrs, `hitZone`).
- Produces: `M.upgradeCreature(model)`, `ArtAssets.creatures[creatureId]` (parts: name/meshId/size/hitZone/offset).

- [ ] **Step 1: Generate + validate 3 exemplars.** `generate_mesh` for `bayou_swamp_rabbit`, `bayou_wood_duck`, and `bayou_american_alligator` using the spec prompt templates. Insert each into `ReplicatedStorage.WildWorldArt`; `screen_capture` each. **Gate:** confirm watertight, recognizable, neutral pose, within tri budget. If an asset fails the bar, regenerate (vary the prompt) or pivot to a Creator-Store mesh (`search_asset`). Record asset IDs + a hitZone part layout (which mesh part = vital/body/limb) in `ArtAssets.creatures`.

- [ ] **Step 2: Implement `M.upgradeCreature(model)`.** Given a spawned box model: read `creatureId`; look up `ArtAssets.creatures[creatureId]` (if none, leave the box as-is — graceful fallback); keep `PrimaryPart` + attributes; destroy the placeholder visual children (all BaseParts except `PrimaryPart`); set `PrimaryPart` `Transparency=1`,`CanQuery=false`; weld in the mesh parts (`Motor6D` to `PrimaryPart`), each tagged with its `hitZone` attribute + `CanQuery=true`, sized/offset per the manifest; add an `AnimationController`+`Animator`; register `M.animated[model] = { creatureId, joints, phase }`.

- [ ] **Step 3: Wire the listener.** Connect `workspace.HuntingTargets.ChildAdded:Connect(M.upgradeCreature)` and iterate existing children; on `ChildRemoved`, deregister from `M.animated`.

- [ ] **Step 4: Verify the contract holds.** Play; walk up to a rabbit/duck/gator. **Expected:** the box is replaced by the mesh; the aim-highlight still highlights it; the name+health billboard still shows; a body shot vs head shot still registers (the `hitZone` raycast works — test by firing); on kill the tip-over death animation still plays. `get_console_output` clean. This is the make-or-break decoupling test.

### Task C2: The central cosmetic-animation loop

**Files:** Modify `WorldArt.server.luau`

**Interfaces:**
- Consumes: `M.animated`.
- Produces: a single `RunService.Heartbeat` connection driving all registered creatures.

- [ ] **Step 1: Implement the loop.** One `Heartbeat:Connect` that iterates `M.animated`: per instance, drive (relative to `PrimaryPart`, via `CFrame:Lerp` on `Motor6D.C0`) idle breathing/sway (sine, per-instance `phase` offset), head-track toward nearest player (clamped neck lerp), limb/wing/tail flutter, ear/gill twitch. Read `PrimaryPart` position only; never set it. Skip instances beyond ~250 studs from any player (cull).

- [ ] **Step 2: Verify.** Play; observe a herd. **Expected:** creatures breathe and look around with de-synced phase (not robotic lockstep), atop whatever movement the gameplay system applies; no fighting the movement (positions unchanged by this loop). Capture a short observation. Save; `./run-tests.sh` GREEN.

### Task C3: Fish in the water + landed reveal

**Files:** Modify `WorldArt.server.luau`, `ArtAssets.luau` (coordinate read-only with `FishingFeel`)

- [ ] **Step 1: Generate fish meshes** for the Bayou roster (bluegill, bullhead/channel/blue catfish, + the rare albino + the Mythic Leviathan as a scaled hero) per the catfish prompt template; record IDs.

- [ ] **Step 2: Populate swimming fish.** Add low-poly schooling fish models in the fishing zones (shared waypoint + per-fish offset, swim-bob via the C2 loop), `CanQuery=false` (decorative; the bite markers stay the gameplay target). Upgrade the `FishingBites` ball markers' visual subtly (a subsurface shadow/ripple) without changing their gameplay role.

- [ ] **Step 3: Landed-fish reveal.** Ensure a landed catch shows the real fish mesh (the existing `FishingFeel` renders the reveal — supply the mesh by `fishId` from the manifest if `FishingFeel` exposes a hook; otherwise add a parallel reveal that reads the `landed` event without editing `FishingFeel`). A breach arc + foam `ParticleEmitter` + expanding ring on landing.

- [ ] **Step 4: Verify.** Play; cast + land a fish; `screen_capture`. **Expected:** fish visibly swim in the water; a landed catch reveals a recognizable species mesh with a foam splash. Save; `./run-tests.sh` GREEN.

### Task C4: Apex alligator + the Ghost-Gator back-slough set-piece

**Files:** Modify `WorldArt.server.luau`, `ArtAssets.luau`

- [ ] **Step 1: Apex gator polish.** Ensure the `bayou_american_alligator` mesh (high tier, ~9k tris, `SurfaceAppearance` scutes + cream belly) reads as a menacing apex; tune scale/material.

- [ ] **Step 2: Build the back-slough.** Add `M.buildGhostSlough()` at `cottonmouth_slough` — skeletal leafless cypress snags, thickest moss, deepest-tea water, dim local read, a half-submerged non-interactive gator silhouette (eyes/snout only). 

- [ ] **Step 3: Local atmosphere transition.** Add a region trigger (server senses player proximity, or client-side for smoothness) that ramps `Atmosphere.Density` toward ~0.6 and shortens cull distance while inside the slough, restoring on exit. (If global Atmosphere ramping is too coarse for multiplayer, approximate with dense local fog parts / a `ParticleEmitter` mist bed.)

- [ ] **Step 4: Verify.** Walk into the slough at dawn. **Expected:** visibility tightens, fog burns at the waterline, the gator silhouette looms out of the murk — a genuine menace beat. Capture. Save; `./run-tests.sh` GREEN.

---

## Phase D — The Lodge & Trophy Hall

### Task D1: Lodge shell + interior lighting + materials

**Files:** Modify `WorldArt.server.luau`, `ArtAssets.luau`

**Interfaces:** Produces `M.buildLodge()`; `ArtAssets.lodge.{materials, lights, fixtures}`.

- [ ] **Step 1: Build the enclosed shell.** At `Shells.lodge.anchor` (`0,0,600`) build log walls + beams + a solid roof (no skylight — so the global dawn doesn't leak in), `WoodPlanks` floor, a `Slate` hearth/chimney. Suppress the placeholder `Lodge_Floor` slab + fixture cubes' visuals (keep their `service`/`status` attributes intact for the gameplay UI). Apply PBR `MaterialVariant`/`SurfaceAppearance` per spec (wood Roughness ~0.7, planks ~0.5, slate ~0.85, leather ~0.4, brass focal, iron subordinate).

- [ ] **Step 2: The light rig.** Build the ~11-light rig from `ArtAssets.lodge.lights` (hearth `PointLight` 3–5 with Heartbeat flicker + additive `Fire` particles, great-room wash, lanterns, trophy spots); cap `Shadows=true` to 3–5 fixtures; ranges per the 120-cap table.

- [ ] **Step 3: Verify.** Play; spawn into / teleport to the Lodge. **Expected:** a warm, cozy timber interior with a flickering hearth, readable but moody; brass catches the firelight. Confirm the service-fixture attributes still present (`inspect_instance`). Save; `./run-tests.sh` GREEN.

### Task D2: Service stations + signage

**Files:** Modify `WorldArt.server.luau`, `ArtAssets.luau`

- [ ] **Step 1: Dress the 7 stations.** For each placed fixture (`Outfitter`, `TackleShop`, `TrophyHall`, `TravelDesk_WorldMap`, `TradingPost`, `BoatDealer`, `KennelAndStable`) build a themed station prop (gun rack, tackle bench, map desk, etc.) with a brass-trimmed signboard reading the fixture name, and a small per-cluster light. Keep the existing fixture part as the invisible interaction anchor.

- [ ] **Step 2: Verify.** Walk the perimeter. **Expected:** each station is visually distinct + labeled; the hub reads as a lived-in lodge. Capture. Save; `./run-tests.sh` GREEN.

### Task D3: Trophy hall — rarity framing + fills-as-you-succeed

**Files:** Modify `WorldArt.server.luau`, `ArtAssets.luau`

**Interfaces:** Consumes the Step-8 display projection (`Replication.buildProjection(...).trophyHall` or the equivalent read-only projection — read-only; no new store).

- [ ] **Step 1: Build the trophy wall + slots.** On the hearth-flanking wall, build a fixed set of mount slots (wall plaques, 2–3 pedestals, one glass vitrine center-stage). Each slot ships as a low-lit silhouette/`?` plate by default.

- [ ] **Step 2: Read display state + render mounts.** Read the player's displayed-artifact projection; for each displayed trophy render the creature/fish mesh (from the manifest) on its slot with rarity-distinct framing across the four channels (frame material, backing/size, accent light, FX) per the spec palette. Reserve the center vitrine for the highest rarity.

- [ ] **Step 3: The placement beat.** When a trophy is newly displayed (watch the projection / a display event), play the SpotLight fade-up + a chime + a one-time mote burst; the room visibly brightens as slots fill.

- [ ] **Step 4: Verify.** Play with a profile that has a displayed trophy (or stub one). **Expected:** earned trophies show as framed mounts with rarity reading correctly (a Legendary is the brightest/center/most-shadowed; a Common is flat); empty slots are silhouettes, not blank wall. Capture. Save; `./run-tests.sh` GREEN.

---

## Phase E — Polish & performance

### Task E1: Dusk variant + boardwalk polish

- [ ] **Step 1:** Add a `bayouDusk` look application (swap to `ClockTime 17.8` + warmer/darker grade + fireflies on) behind a simple toggle/seam (not wired to LiveOps time this pass). Optionally build the half-rotted sunken boardwalk artery. Verify with a dusk capture. Save.

### Task E2: Graphics-quality toggle + ADS depth-of-field (client)

- [ ] **Step 1:** In `WorldArtClient.client.luau` add a quality toggle (low: cull distant creatures/foliage, disable decorative shadows + SunRays/Bloom) and enable `DepthOfFieldEffect` only while aiming-down-sights (read the existing aim state / `HuntingFeel` highlight) and in photo mode. Verify both states by capture. Save.

### Task E3: Performance + mobile pass

- [ ] **Step 1: Batching audit.** Confirm (MicroProfiler / `inspect_instance`) that per-species and per-prop instances share `MeshId` + material (no per-instance `SurfaceAppearance` divergence).
- [ ] **Step 2: Shadow/LOD/collision audit.** Confirm ≤3–5 shadow-casters in the lodge + a handful outdoors; all props/creatures `RenderFidelity=Automatic`, `CollisionFidelity=Box`/None, decorative `CastShadow=false`.
- [ ] **Step 3: `StreamingEnabled` (COORDINATE).** Flag to the user + gameplay terminal before enabling; if approved, enable + tune `StreamingTargetRadius`, then verify the lodge/trophy state, the back-slough transition, and terrain water + duckweed survive stream-in/out.
- [ ] **Step 4: Profile.** Validate ≤~40–60 concurrent animated creatures + ≤~30 fish hold frame budget; capture the MicroProfiler on a mid-quality setting. Record findings; save.

---

## Self-Review (against the spec)

- **Spec coverage:** §1 architecture → Tasks A1–A2 + the file structure; §2 global look → A2; §3 environment → B1–B4 + C4 (slough); §4 creatures/fish → C1–C4; §5 lodge/trophy → D1–D3; §6 performance → E3 (+ batching folded into B2/C1); §7 build order → the A–E phase order; §8 risks → exemplar-first gate (C1.1), TUNE re-tuning steps, the shared-Lighting handling (D1.1), `StreamingEnabled` coordination (E3.3); §9 integration contract → the Global Constraints + C1's in-place upgrade verification. No uncovered section.
- **Placeholders:** the `ArtAssets` sub-tables (`props`/`creatures`/`fish`/`lodge`) are intentionally populated *by* the tasks that generate the assets (the manifest is the deliverable being filled), not plan gaps; every task states exact files, actions, and a concrete visual verification. Mesh prompts are given verbatim.
- **Type/name consistency:** `M.applyGlobalLook` / `M.buildTerrain` / `M.suppressPlaceholders` / `M.scatterProps` / `M.buildOldCypress` / `M.layDuckweed` / `M.upgradeCreature` / `M.buildGhostSlough` / `M.buildLodge` and `M.animated` are referenced consistently across tasks; `c3` is the single `{r,g,b}→Color3` helper; the manifest keys match between A1 and their consumers.

## Notes on adaptation

This plan substitutes the standard TDD test/commit cadence with the domain-correct cadence: **build via the MCP → `screen_capture`/`inspect_instance` verify → re-tune → persist** (CLAUDE.md: Studio-only work is verified by the playtest checklist, not headless tests). The headless `run-tests.sh` gate is still run after every task to prove the data manifest stays `--!strict`-clean and the project keeps Rojo-building. Git commits are deferred to the user given the shared working tree on the gameplay terminal's branch.
