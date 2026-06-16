# Wild World — Step 3: Core Movement & the Bayou Shell — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline). Checkbox tracking.

**Goal:** A navigable, seam-correct Bayou **placeholder shell** with a mobile character controller and a
login→arrival flow — built data-driven so a second Destination reuses the framework.

**Architecture:** Split by verifiability. The **data/logic seams** (named zones, landmark anchors,
ambiance placement, the §2.6 layout distances, arrival routing) are pure config + logic → `--!strict` +
headless-tested. The **world geometry + character controller + the live arrival placement** are
Studio-only Roblox scripts (reference Humanoid/Workspace/Lighting) → built data-driven from the config,
verified by a manual Studio playtest checklist, NOT headless. This split is the honest success bar.

**Tech Stack:** strict Luau (headless modules) + Studio-only Roblox scripts (`*.server.luau`/`*.client.luau`),
the Step 1–2 codebase (`SessionService`, `DestinationService`, `Destinations`/`Creatures` config),
`luau`/`luau-analyze`/`rojo`.

---

## The verifiability split (the whole point of this step)

| Surface | Files | How verified |
|---|---|---|
| Shell DATA (zones/landmarks/anchors/ambiance/render/movement) | `src/config/Shells.luau`, `Schema.luau` types | strict + load-validated |
| Shell LOGIC (distances, walk/crossing time, validators) | `src/logic/Shell.luau` | strict + unit tests |
| Arrival routing | `src/server/ArrivalService.luau` | strict + unit tests |
| Ambiance species rows (Painted Turtle, songbird) | `src/config/Creatures.luau` | strict + existing Validation |
| World geometry blockout (placeholder) | `src/server/world/BayouBlockout.server.luau` | **Studio-only** (reads validated config) |
| Mobile character controller | `client/CharacterController.client.luau` | **Studio-only** |

`run-tests.sh` analyzes the headless set and **excludes** `*.server.luau` / `*.client.luau` / `client/**`
(Roblox-runtime scripts), printing them as a Studio-only list. The README carries the honest coverage
statement + the unchecked Studio playtest checklist.

## Binding reconciliations / decisions (flagged)

1. **`spawn.location` prose is NOT resolved here** (Step-1 catalog stores it as free-form prose). Step 3
   owns the **zone ids**; the species→zone mapping for TARGET species + the live spawner are Steps 4/5.
   Only **ambiance** species get a zone here (`Shells.ambiancePlacements`). `TODO(step-4/5): structured
   spawnZones`.
2. **Positions are plain `{x,y,z}` tables** in config (no Roblox `Vector3`) so the shell is pure data /
   headless. The blockout converts to `Vector3.new` at runtime.
3. **`walkSpeed` is NOT tuned vs fleeing-game speed** (no fleeing game exists; that's Step 4's escape
   window). Set a sensible value (16) and hit the crossing-time target.
4. **Arrival is unconditional → the free-starter (requiredTier 0) Destination's arrival anchor** (derived
   from data, like `freshProfile`), i.e. always the Bayou. The returning-player→Lodge branch is `TODO(step-8)`.
5. **Add Painted Turtle + songbird as `ambianceOnly` Creature rows** (LOC_01 §3 lists them; Step 1 was
   "representative, not exhaustive"). Dragonflies stay pure-VFX (a blockout decoration, not a species).

---

## Tasks

### Task 1 — Schema: shell types
**Files:** Modify `src/types/Schema.luau`.
Add: `Vec3 = {x,y,z}`; `ZoneKind`; `Zone = {id,name,kind,center:Vec3,size:Vec3,description}`;
`Landmark = {id,name,anchor:Vec3,isBeacon,description}`; `Shell = {destinationId, arrivalZoneId,
zones:{[string]:Zone}, landmarks:{[string]:Landmark}, vendorOutpostAnchor:Vec3, travelSignpostAnchor:Vec3,
ambiancePlacements:{[TargetId]:string}, render:{fogStart,fogEnd,drawDistance}}`; `Movement =
{walkSpeed,jumpPower,cameraMinZoom,cameraMaxZoom}`. Strict-clean.

### Task 2 — logic/Shell: pure geometry + validators
**Files:** Create `src/logic/Shell.luau`. **Test:** `tests/Shell.spec.luau`.
`horizontalDistance(a,b)`, `walkSeconds(a,b,walkSpeed)`, `crossingSeconds(shell, walkSpeed)` (max pairwise
horizontal distance among all zone centers + landmark anchors ÷ walkSpeed), `arrivalAnchor(shell)`,
`ambianceZoneOf(shell, speciesId)`, and `validateShell(shell, catalog)` asserting: arrivalZoneId resolves;
every `ambianceOnly` creature of this Destination is in `ambiancePlacements` → a valid zone; NO target
(non-ambiance) species in `ambiancePlacements`; `travelSignpostAnchor == vendorOutpostAnchor` (co-located).
Tests: distances, crossing time, validate rejects a bad shell (missing ambiance home; a target species).

### Task 3 — Ambiance Creature rows
**Files:** Modify `src/config/Creatures.luau`. Add `bayou_painted_turtle`, `bayou_songbird`
(`ambianceOnly=true`, reward nil). Existing Validation covers them.

### Task 4 — config/Shells: the Bayou shell + movement tunables
**Files:** Create `src/config/Shells.luau`. **Test:** `tests/Shell.spec.luau` (extend).
The §2.3 zones (arrival_clearing, sunny_levee, reed_edges, channel_banks, catfish_hole, cottonmouth_slough)
with coordinates satisfying §2.6: arrival(0,0,0); levee(0,0,-50) [faces, <70]; channel_banks(24,0,12)
[few steps, <40]; the_landing(0,0,255) [~16 s walk ∈ 15–20]; old_cypress(55,0,110) [beacon]; catfish_hole
(120,0,70); cottonmouth_slough(-110,0,80). Landmarks the_landing+the_old_cypress (isBeacon). vendorOutpost
= signpost = the_landing anchor (co-located). ambiancePlacements: egret→channel_banks, turtle→catfish_hole,
songbird→reed_edges. render fog budget. movement {walkSpeed=16,…}. `validateShell(bayou, Catalog)` on load.
Tests: all §2.3 zones present w/ stable ids; §2.6 distance constraints (walk 15–20 s, few-steps, faces,
co-located, crossing <60 s); ambiance coverage; no target species; framework keyed by DestinationId.

### Task 5 — server/ArrivalService: login→Bayou arrival resolver
**Files:** Create `src/server/ArrivalService.luau`. **Test:** `tests/Arrival.spec.luau`.
`resolveArrival(profile, shells, config) → {destinationId, zoneId, anchor}` = the free-starter
(requiredTier 0) Destination's shell arrival anchor (always Bayou). `TODO(step-8)` returning→Lodge.
Tests: fresh profile → Bayou + arrival_clearing + the arrival anchor; unconditional regardless of profile state.

### Task 6 — Studio: world blockout (placeholder geometry)
**Files:** Create `src/server/world/BayouBlockout.server.luau` (Studio-only, NOT analyzed).
On server start: read `Shells.byDestination[Bayou]`; build a flat ground baseplate, a flat water plane at
the channel/oxbow zones, named zone marker parts at centers, landmark placeholders (Old Cypress = tall
beacon part; The Landing = dock/shack + a signpost part + Outfitter/TackleShop anchor parts), a SpawnLocation
at the arrival clearing facing the levee, instanced ambiance placeholder parts in their zones + dragonfly
particles, and atmospheric fog (FogStart/End from render budget) as the cull. Wire PlayerAdded →
SessionService.login (RobloxAdapters) → ArrivalService.resolveArrival → place character at the anchor +
set Humanoid.WalkSpeed from movement config. Data-driven; clearly placeholder.

### Task 7 — Studio: mobile character controller
**Files:** Create `client/CharacterController.client.luau` (Studio-only). Update `default.project.json`
to map `client/` → StarterPlayer.StarterPlayerScripts. A thin LocalScript: lean on Roblox's built-in touch
controls; tune the third-person camera (zoom min/max from inline constants), ensure mobile controls on.

### Task 8 — run-tests.sh exclusion + README + final run
Exclude `*.server.luau`/`*.client.luau`/`client/**` from the analyze loop; print them as Studio-only.
README: Step 3 module map, the **honest coverage** (headless-proven seams vs the unchecked Studio playtest
checklist), and the placeholder-art-awaiting-Phase-3 note. Run `./run-tests.sh` → headless green.

## Self-review checklist
- §2.1–§2.6 each → a zone/landmark/anchor + (where measurable) a headless distance assert OR a Studio
  checklist item. Nothing claims a headless green that only Studio can confirm.
- No deferred verb built (no shooting/casting/buying/travel/spawner/caps/Lodge/returning-branch).
- Shell is data-driven + keyed by DestinationId (reusable). Logic content-free.
- Honest report: headless seams vs Studio checklist, explicitly.
