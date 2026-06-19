# Field Inventory — Design

- **Date:** 2026-06-19
- **Branch:** `feat-field-inventory`
- **Status:** approved (brainstorming → spec); pending implementation plan
- **Layer:** Studio-feel feature (client UI) + a thin headless logic module + server wiring

## Summary

Let the player open a **field inventory** anywhere — not only inside a vendor shop panel — to
**switch which gear is equipped** in each of the four equippable slots (weapon, armor, rod, reel).
Today, equipping is reachable only from the shop panel's "Your gear" section. This feature adds a
standalone, key-toggled inventory panel that reuses the **existing** equip intent end-to-end.

The key realization from the codebase study: **equip is already a vendor-agnostic server intent.**
The shop's `EQUIP` button just fires `ShopRequest("equip", commodityInstanceId)` → `Gauntlet` →
`EquipHandler`, which writes `PlayerData.equipped`. The server does not care that the click came
from a vendor. So this feature is **mostly a new client panel plus a thin read-only listing path**;
it adds **no new equip logic**.

## Goals

- A field inventory panel, opened by a key (`I`) and an on-screen `GEAR` HUD button, that lists the
  player's owned **equippable** gear grouped by slot and lets them equip any owned item.
- Reuse `EquipHandler` / the `Gauntlet` verbatim for the mutation (server-authoritative).
- Make the HUD's EHT/EFT + `[equipped]` state refresh after a **field** equip (today that refresh is
  vendor-gated).
- A headless, unit-tested pure function for the "owned equippable gear, grouped by slot" view.

## Non-goals (explicitly deferred)

- **Unequip / clearing a slot.** Swap-only, matching today's behavior (a slot always holds an item
  once one is equipped). No new intent; no EHT/EFT→0 / gate-relock edge case.
- **Held-item visual refresh.** The on-character `HeldRifle`/`HeldRod` model stays static across
  tiers (its current behavior). Swapping gear updates the HUD numbers + tags but not the held mesh.
  Tier-based held visuals remain a separate, already-deferred item.
- **New equippable categories.** Only the four existing slots (`weapon`/`armor`/`rod`/`reel`, i.e.
  `Enums.TIER_INPUT_CATEGORIES`). The other seven categories (bait/tackle/vehicle/mount/dog/tool/
  cosmetic) have no equip slot and are out of scope.
- No refactor of the existing shop path (`buildShopListing`, `ShopController`); it is left untouched.

## Background — how equip works today (grounded)

- `EquipHandler` (`src/server/authority/handlers/EquipHandler.luau`): `intent="equip"`,
  `critical=false`, `simulate=nil`. `resolve` finds the `Commodity` by stable `instanceId` in
  `profile.inventory.commodities` and its catalog row via `config.equipment[catalogId]`. `authority`
  rejects `not_owned` / `unknown_item` / `not_equippable` (category not in the `SLOT` map). `SLOT`
  (`:18`) is `{ weapon, armor, rod, reel }`. `commit` clears the previously-equipped commodity's
  flag, writes `equipped[slot] = instanceId`, sets `commodity.equipped = true`, then calls
  `Progression.commitUnlocks(profile, config)` (a tier change may newly satisfy a gate).
- `Gauntlet.handle` (`src/server/authority/Gauntlet.luau`) runs its 6 steps and **always returns a
  projection** (`Replication.buildProjection`). EHT/EFT derive from `equipped` via
  `EffectiveTier.luau` (never stored).
- Profile state: `PlayerData.equipped : EquippedRefs = { weapon?, armor?, rod?, reel? }` (stable
  `instanceId`s) — `src/types/Schema.luau:207-213`. Owned gear lives in
  `PlayerData.inventory.commodities : { Commodity }` where `Commodity = { instanceId, catalogId,
  intraLevel, equipped }`.
- Client wire today: `ShopController.client.luau` opens via a ProximityPrompt (E) on vendor anchors,
  `render(vendor, listing, projection)` draws a "Your gear" section, an un-equipped owned commodity
  gets an `EQUIP` button firing `Net.shop:FireServer("equip", c.instanceId, vendor)`.
- `WorldServer.server.luau:1112-1139` handles `ShopRequest`: `"open"` → fires `"listing"`; an action
  in `SHOP_INTENT` → `Gauntlet.handle` → on ok fires `"result"` **and**, *only when the vendor is
  known* (`VENDOR_CATEGORIES[vendor] ~= nil`, `:1133`), a trailing `"listing"` carrying the fresh
  projection. **This vendor gate is why a field equip would not refresh the HUD** without new wiring.
- `buildShopListing` (`WorldServer.server.luau:1073`) is inline + vendor-scoped; owned rows are
  `{ instanceId, catalogId, name, tier, intraLevel, equipped }`. The field listing mirrors this row
  shape but groups by all four slots and is not vendor-scoped.

## Architecture (Approach B — dedicated channel + headless builder)

Three pieces, respecting the headless/Studio split:

### 1. `src/logic/Loadout.luau` — headless, `--!strict`, unit-tested

Pure function over `profile` + `config`, zero Roblox globals:

```
Loadout.ownedEquippableBySlot(profile, config) -> {
  weapon : { Row }, armor : { Row }, rod : { Row }, reel : { Row }
}
-- Row = { instanceId, catalogId, name, tier, intraLevel, equipped : boolean }
```

- Iterates `profile.inventory.commodities`; includes a commodity only if its catalog row's
  `category` is one of the four equippable categories. **Source the set from `Enums`**
  (`TIER_INPUT_CATEGORIES`, the frozen `{weapon, armor, rod, reel}`) — never a string literal list,
  and never by requiring the server `EquipHandler` (a `logic/` module depends on `types`/`config`
  only, not on a server handler — correct layering direction). For these four, the **slot name
  equals the category name**, so grouping is by category.
- `equipped` is **derived**: `profile.equipped[category] == commodity.instanceId` (honors
  derive-don't-store; does not trust the denormalized `commodity.equipped` flag).
- Slot order is fixed (`weapon`, `armor`, `rod`, `reel`) for stable rendering.
- This is the only new headless surface and the only thing that gets dedicated unit tests.

### 2. `InventoryRequest` wiring in `src/server/world/WorldServer.server.luau` (Studio-only)

A new `RemoteEvent` `InventoryRequest` (sibling of `ShopRequest`), with one handler:

- `"open"` → reply `("loadout", Loadout.ownedEquippableBySlot(session.profile, Catalog),
  Replication.buildProjection(session.profile, Catalog))`.
- `"equip"`, `arg1 = instanceId` → build `{ intent = "equip", playerId, payload =
  { commodityInstanceId = arg1 } }`, call `Gauntlet.handle(registry, …, session, gauntletDeps(plr))`
  (the **existing** handler + deps — no new equip logic). On result, reply `("equipped", r.ok,
  r.reason, Loadout.ownedEquippableBySlot(session.profile, Catalog), r.projection)`.
  The projection is **always** returned here (no vendor gate), fixing the field-refresh gap.

The shop path (`ShopRequest`, `buildShopListing`, `VENDOR_CATEGORIES`) is untouched.

### 3. `client/InventoryController.client.luau` (Studio-only LocalScript)

Mirrors `ShopController.client.luau` and uses the existing `Hud` factory primitives:

- **Open input:** `I` key (desktop, via `UserInputService` / `ContextActionService`) and an
  on-screen `GEAR` button on the HUD (mobile/console parity with the existing `CAST`/`FIRE`
  buttons). Pressing again (or `[X]`) toggles closed.
- **On open:** fire `InventoryRequest:FireServer("open")`. On the `"loadout"` reply, render a panel
  grouping the four slots; the equipped item is tagged `[equipped]`, the rest get an `EQUIP` button.
- **On `EQUIP` click:** fire `InventoryRequest:FireServer("equip", instanceId)`. On the `"equipped"`
  reply, call `Hud.applyProjection(projection)` (HUD EHT/EFT + tags update) and re-render the loadout
  from the returned fresh listing. On failure, `Hud.toast(reason)`.
- Client asserts nothing — it sends only an `instanceId`; the server resolves + validates.

### UI layout

```
┌─ GEAR ───────────────────────────[X]┐
│ WEAPON   ▸ Lever Rifle T2  [equipped]│
│            Bolt Rifle  T3     [EQUIP]│
│ ARMOR    ▸ Camo Vest   T2  [equipped]│
│ ROD      ▸ Cane Pole   T1  [equipped]│
│            Spincast    T2     [EQUIP]│
│ REEL     ▸ (none owned)              │
└──────────────────────────────────────┘
```

## Data flow

**Open:** `I` / `GEAR` → `InventoryRequest("open")` → server reads profile →
`("loadout", loadout, projection)` → client renders.

**Equip:** click `EQUIP` → `InventoryRequest("equip", instanceId)` → `Gauntlet`/`EquipHandler`
(commit + `commitUnlocks`) → `("equipped", ok, reason, freshLoadout, projection)` →
`Hud.applyProjection` + re-render.

## Error handling

- Server rejects (`not_owned` / `unknown_item` / `not_equippable`) flow back as `("equipped", false,
  reason, …)`; client shows a toast and leaves the panel as-is.
- Unknown `InventoryRequest` actions are ignored server-side (mirrors the `ShopRequest` guard).
- No-session requests are dropped (same guard as `ShopRequest`).

## Invariants honored (CLAUDE.md)

- **Derive, don't store.** `equipped` in the listing is derived from `profile.equipped`; no cached
  loadout or computed tier is stored. The projection is the only read-only client shadow.
- **Closed enums live once.** The four slots come from `Enums` (`TIER_INPUT_CATEGORIES` / the
  `EquipHandler.SLOT` keys), not a literal list in `Loadout` or the client.
- **Server-authority / client asserts nothing.** Field UI sends only an `instanceId`; the Gauntlet
  validates. No client-side optimistic equip or tier math. Forged intents rejected at routing.
- **Headless vs Studio split.** `Loadout.luau` is headless `--!strict`, no Roblox globals,
  unit-tested in `tests/`. The new UI + remote wiring are `*.client.luau` / the Studio `WorldServer`
  script, excluded from `run-tests.sh` and verified by the playtest checklist.
- **Config vs logic.** Slot/category/tier facts stay in `config` + `Enums`; `Loadout` is pure
  resolution; the client reads the listing, never hardcoding item lists/prices/tiers.
- **Substrate vs operations / non-orphaning.** Reuses the `critical=false` equip path (dirty-flag
  autosave; inventory + equipped are one atomic write). Equip is not promoted to `critical`.

## Testing

**Headless (`tests/`, in `run-tests.sh`):** new spec for `Loadout.ownedEquippableBySlot`:
- groups owned gear under the correct four slots; excludes non-equippable categories (bait, etc.);
- `equipped` true exactly for the commodity referenced by `profile.equipped[slot]` (derived);
- empty inventory → four empty slot lists; multiple owned items in one slot all listed;
- a slot with no owned item → empty list (renders `(none owned)`).

The equip mutation itself is already covered by the `Gauntlet`/`EquipHandler` specs and is reused
verbatim, so no new equip-mutation tests are required (optionally assert the field path constructs
the identical `{intent="equip", payload={commodityInstanceId}}` request).

**Studio playtest checklist:** open the panel with `I` and the `GEAR` button; it lists owned gear by
slot with the equipped item tagged; equipping a different weapon updates the HUD EHT/EFT and moves
the `[equipped]` tag; equipping a rod likewise; the shop-panel equip still works unchanged; the held
rifle/rod model is (intentionally) unchanged.

## File manifest

**New**
- `src/logic/Loadout.luau` — headless gear-by-slot builder.
- `tests/Loadout.spec.luau` — unit tests; registered in `tests/run.luau`.
- `client/InventoryController.client.luau` — the field inventory panel.

**Touched**
- `src/server/world/WorldServer.server.luau` — add the `InventoryRequest` RemoteEvent + handler;
  require `Loadout`. (No change to the `ShopRequest` block / `buildShopListing`.)
- `tests/run.luau` — register the new spec.
- Possibly `client/Hud.luau` — add the `GEAR` button if the HUD owns the on-screen button row
  (confirm during planning; otherwise the button is created by `InventoryController`).

## Risks / open items

- **HUD button ownership.** Whether the `GEAR` button is added in `Hud.luau` or created by
  `InventoryController` depends on how the existing `CAST`/`FIRE` buttons are owned — resolve during
  planning by reading the HUD button code; default to mirroring wherever those buttons live.
- **`I` key on mobile/gamepad.** The on-screen `GEAR` button covers touch; gamepad binding (e.g. a
  face button) can be added via `ContextActionService` but is a nicety, not required for v1.
