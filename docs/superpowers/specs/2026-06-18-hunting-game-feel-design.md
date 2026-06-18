# Hunting Game-Feel Pass — Design

**Date:** 2026-06-18
**Status:** Approved (brainstorming) → ready for implementation plan
**Scope:** Hunting loop only (fishing feel is a follow-up). Approach **B — Procedural animals**.

## Why

The MVL is logic-complete and the loops are verified to *resolve* (server-authoritative kill/catch/buy/equip/progress all work). But **playing** it in Studio feels "very basic, not really playable": every creature is the identical 3×3×4 box, the player holds no visible weapon, and firing produces only a raycast + a tiny toast — no gun, no shot, no reaction, no reward feedback. The entire **feel/presentation layer** was deferred ("Studio feel" / "Phase-3 art"). This pass builds the hunting half of it so the core loop *plays* like a game, not just computes like one.

## Constraints (binding)

- **Studio-only.** No change to `src/config`, `src/logic`, or the headless `src/server` substrate/handlers. The gauntlet/economy/EHT logic already works and is untouched. `./run-tests.sh` must stay green.
- **Headless/Studio split:** Studio-only code lives in `*.server.luau` / `*.client.luau` / `client/`. Server-side procedural building therefore extends **`WorldServer.server.luau` inline** (the established convention — it already owns `buildWorldGeometry` + the spawners); client feel lives in **new `client/` modules**. (No Roblox-touching ModuleScript may live under `src/` un-suffixed — it would break the analyzer gate.)
- **No Roblox CDN.** This Studio cannot fetch assets (`could not fetch` / HTTP 403 flood). Everything is **procedural** — parts, shapes, `Highlight`/`BillboardGui`, tween animation, camera kick. Sound uses engine-bundled `rbxasset://` ids only, and **degrades to silent** if even those don't resolve.

## Existing seams this builds on (no rewrites)

- `spawnTarget(creatureId, zoneId)` — `WorldServer.server.luau:508`. Currently creates a single-box `Model` with `creatureId`/`targetId` attributes into `HuntingTargets`. **Replaced** by a call to a new `buildCreatureModel`.
- `despawnTarget(model, respawnAfter)` — `:528`. **Extended** with a death animation before `Destroy`.
- Fire handler — `:588`. On a non-lethal hit (`:654` `state.accumulated += shotDmg`) we additionally write `currentHealth`. On the lethal blow (`:642`) it already calls `despawnTarget` + `FireClient(plr,"kill",targetId,projection)`. On a hit it already `FireClient(plr,"hit",targetId,shotDmg)`.
- `zoneOfHit(part)` — `:584`. Already reads a part's `hitZone` attribute (`vital`/`limb`/`body`) and feeds the existing `Combat.zoneMultiplier`. **Tagging parts is all that's needed to make headshots live** — no logic change.
- Client `FireController.client.luau` — already aims (`Net.fire:FireServer(origin, dir.Unit)`) and receives `("kill"|"hit", targetId, extra)`. **Extended** to drive FX; the input/fire path is unchanged.

## Components

### Server (inline in WorldServer.server.luau)

1. **`CREATURE_ARCHETYPES` table + `buildCreatureModel(creatureId) -> Model`.**
   A small data table maps each Bayou creature to an **archetype** (`reptile` | `small_mammal` | `bird`) plus a size scale and base color. `buildCreatureModel` assembles a procedural multi-part `Model`:
   - **reptile (alligator):** long low body + tail taper + 4 stubby legs + a snout head.
   - **small_mammal (rabbit/nutria):** rounded body + head + ears (rabbit) / + tail (nutria), small.
   - **bird (wood duck):** body + head + folded wings, smallest.
   - The **head part is tagged `hitZone="vital"`**, the torso `hitZone="body"`, legs `hitZone="limb"`. Parts are anchored, `CanCollide=false`, grouped under the Model with `PrimaryPart` = the torso.
   - Sets `maxHealth` and `currentHealth` attributes (= `creature.health`) on the Model for the client health bar.
   - Carries the existing `creatureId`/`targetId` attributes so the fire raycast + `liveTargets` lookup are unchanged.

2. **Health replication.** In the non-lethal hit branch, after `state.accumulated += shotDmg`, write `model:SetAttribute("currentHealth", math.max(0, Catalog.creatures[state.creatureId].health - state.accumulated))`. Attributes replicate to all clients → the billboard health bar updates for free.

3. **Server-driven death.** `despawnTarget` plays a brief death before `Destroy`: unanchor-free CFrame **tip-over + sink** (Tween/`TweenService` on the anchored parts' CFrame) + **fade** (Transparency tween), ~0.6s, then `Destroy`. Server-driven so every client sees the same death. Respawn timing is unchanged.

### Client (new modules under `client/`)

4. **`ViewModel.client.luau` — held rifle.** On character spawn, build a procedural rifle (stock + barrel + grip, a few parts) and weld it to the right hand (`Motor6D`/`Weld` to the hand, or an arm offset), pointing forward. v1 is **one generic rifle** (no tier variation). Exposes the barrel-tip attachment for the muzzle FX.

5. **`HuntingFeel.client.luau` — aim highlight + shot FX.** A render-stepped loop raycasts from the crosshair; when over a `HuntingTargets` creature, apply a `Highlight` (fill/outline) and tint the crosshair "locked". On fire (driven from `FireController`, predicted immediately): **muzzle flash** (brief `PointLight` + flash part at the barrel tip), **tracer** (a thin neon beam barrel→aim point, fades), **recoil** (short camera-CFrame kick). On the server `"hit"` reply: **hit-marker** (crosshair flash) + small impact spark at the creature. On `"kill"`: a floating **`+$X`** + damage number rising and fading at the creature.

6. **`CreatureLabels.client.luau` — name + health labels.** Watches `HuntingTargets` (ChildAdded/Removed); attaches a `BillboardGui` over each creature showing the **creature name** + a **health bar** bound to the `currentHealth`/`maxHealth` attributes (updates on `GetAttributeChangedSignal`). Faces the camera, scales with distance, hides past a max range.

7. **Sound.** `SoundFx.client.luau` (or folded into HuntingFeel): play engine-bundled `rbxasset://` sounds for gunshot (fire), impact (hit), a death thud (kill), and a cash chime (`+$`). Wrapped in `pcall`/load-timeout; if a sound fails to load, **skip silently** — visuals carry the feel.

### Wiring
`FireController` gains a tiny seam: on its existing fire path it calls into `HuntingFeel.onFire(...)` (predicted FX) and on its existing `"hit"`/`"kill"` handlers calls `HuntingFeel.onHit(...)` / `HuntingFeel.onKill(...)`. FireController stays responsible only for input + the RemoteEvent; the feel modules own all visuals. No new RemoteEvents.

## Data flow

```
SPAWN:  server buildCreatureModel → HuntingTargets (tagged parts + health attrs)
        client CreatureLabels attaches name+health billboards
        client ViewModel builds the held rifle
FIRE:   client predicts muzzle flash + tracer + recoil → Net.fire:FireServer(ray)
        server raycasts (existing) → hitZone read (existing, now meaningful)
HIT:    server: accumulated += dmg, SetAttribute currentHealth ; FireClient "hit"
        client: hit-marker + impact spark ; health bar drops (attribute)
KILL:   server: despawnTarget death anim (tip/sink/fade) ; FireClient "kill", projection
        client: floating +$X + damage number ; HUD balance updates (existing applyProjection)
```

## Out of scope (YAGNI — explicit follow-ups)

- Creature **movement/AI** (wander/flee) — the natural next pass (Approach C).
- **Fishing** feel — separate follow-up using the same pattern.
- Real art/textures/meshes; weapon-tier visual variation; ragdoll/gore.
- The HUD-legibility cluster (login projection push, gate-reason rendering) — tracked separately from the earlier shop audit.

## Testing

Studio-only feel → **playtest checklist** (not headless; `run-tests.sh` unaffected):
- [ ] Spawn shows **distinct** procedural animals (gator ≠ rabbit ≠ duck ≠ nutria), each with a **name + health label**.
- [ ] A **rifle is visible** in the player's hands.
- [ ] Aiming the crosshair at a creature **highlights** it; off a creature, no highlight.
- [ ] Firing shows **muzzle flash + tracer + recoil**; a gunshot sound plays (or silently degrades).
- [ ] A non-lethal hit shows a **hit-marker** and the **health bar drops**.
- [ ] A **headshot** (crosshair on the head) does **more damage** than a body shot (health bar drops further).
- [ ] The killing blow plays the **death animation** (tip/sink/fade) and a floating **`+$X`** appears; the HUD balance increases.
- [ ] `./run-tests.sh` still **ALL GREEN** (no headless change).

## Risks / decisions

- **Sound under no-CDN:** `rbxasset://` engine sounds *may* still fail; mitigated by silent degradation. Accepted.
- **WorldServer growth:** the creature builder is added inline to an already-large script (forced by the headless split). Accepted for this pass; a future refactor could extract a Studio-only server module via a dedicated rojo mapping.
- **Held rifle v1 is generic** (not tier-varied) — accepted to keep scope tight.
