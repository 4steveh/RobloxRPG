# S1 — Bayou Vertical Slice: the client layer + the shop/equip server glue (design)

**Date:** 2026-06-18
**Status:** approved design (Steve green-lit); pending spec review → implementation plan
**Scope of this spec:** the **git-verifiable code layer** of Studio Prompt S1. The *live* half (place-file
geometry polish, the Studio playtest, payout-band/persistence confirmation) is **deferred to a live-Studio
session** because the `roblox-studio` MCP is not currently connected to this CC session — per Steve's
decision "build the code layer now."

---

## 1. Goal & the corrected premises

The S1 milestone: in Play mode a tester spawns in the Bayou → aims and shoots a routine huntable → gets the
Tier-1 band payout → buys the T2 weapon at the Outfitter → **equips it** → shoots a higher target → casts and
catches a routine fish → gets the matching band → and on rejoin, Cash + gear persist.

Grounding the prompt against the actual repo corrected four premises (all verified, not assumed):

1. **The Studio MCP is not connected** to this session — no `roblox-studio` tools are exposed. The live
   operations (MCP geometry, playtest) cannot run here; they wait for Steve to connect Studio.
2. **The functional blockout geometry already exists**, built procedurally by `WorldServer.server.luau`
   (lines 287–333): ground plane, water-zone pads at the fishing coordinates, the Outfitter/TackleShop/
   TravelSignpost anchor parts, landmarks, the arrival `SpawnLocation`, fog, plus the Lodge interior +
   fixtures. The already-spawning creature Models therefore already sit on terrain. "Build coordinate-aligned
   geometry" is **functionally already satisfied**; what remains is Steve's aesthetic pass (a place-file job).
3. **`client/` is not empty** — it holds `CharacterController.client.luau` (27 lines, camera/touch tuning).
   The fire/fishing/shop/travel controllers are genuinely missing. **A client LocalScript cannot `require`
   the `@src` modules** (they live under `ServerScriptService`), so controllers talk to the server *only*
   through the ReplicatedStorage RemoteEvents and render the server's `projection` replies.
4. **The milestone's "buy the T2 weapon" path is NOT wired.** `PurchaseRequest` is the **real-money
   MarketplaceService** prompt, not the in-game Cash shop. The Cash shop (`buy`) + `equip` + `upgrade` are
   registered gauntlet intents with **no RemoteEvent routing them**. And `buy` mints the weapon *unequipped*
   while `FireHandler` reads `equipped.weapon` — so the slice requires **buy → equip → shoot**. This needs new
   server glue (a RemoteEvent), which must live inside `WorldServer.server.luau` because `registry` and
   `sessionService` are file-locals there.

---

## 2. The grounded contract (source of truth — verified against the repo)

### 2.1 Wired RemoteEvents (in `ReplicatedStorage`) — unchanged, the client renders against these

| Event | Client → Server | Server → Client replies |
|---|---|---|
| `FireRequest` | `:FireServer(aimOrigin: Vector3, aimDirection: Vector3)` | `("hit", targetId, dmg: number)` · `("kill", targetId, projection: Projection)` |
| `FishingCast` | `:FireServer(action, arg)` — `action ∈ {"cast","fight"}`, fight `arg = E ∈ [0,1]` | `("bite", fishId)` · `("fightProgress", fishId, accumulated: number)` · `("landed", fishId, projection)` |
| `TravelRequest` | `:FireServer("openMap")` / `:FireServer("travel", destinationId)` | `("map", pins, passport)` · `("traveling", destId, teleportTarget)` · `("denied", destId, reason)` |
| `PurchaseRequest` | `:FireServer(kind, assetId)` — **real money**, out of S1 scope | (server prompts MarketplaceService) |
| `RewardedAdClaim` | `:FireServer()` — out of S1 scope | (none) |

Authority notes (verified): `FireRequest.OnServerEvent` raycasts **from `char.PrimaryPart.Position`** along
the client's `aimDirection.Unit * 500`, finds the hit Model in `liveTargets`, and **recomputes damage
server-side**. It accumulates per-shot damage and only routes the **lethal** shot through the gauntlet
(`intent="fire"`); non-lethal shots reply `("hit", …, dmg)`. The client's `aimOrigin` is currently **ignored**
(see §6 decision). Fishing `cast` picks a live bite and replies `("bite", fishId)`; each `fight` tick drains
stamina and replies `("fightProgress", …)` until `staminaToLand` is reached → gauntlet `intent="catch"` →
`("landed", …, projection)`.

### 2.2 Gauntlet intents the new glue routes to (verified)

| Intent | Handler | Payload | Notes |
|---|---|---|---|
| `buy` | `ShopHandler.buyHandler` | `{ itemId }` | authority: item exists, `tierInput`, `availableAt ∈ {Outfitter,TackleShop}`, `tier ≥ 2`, affordable. commit: debit `gearCostSlot(tier)`, `mintCommodity(itemId, 0)` → **unequipped**. `critical` (atomic). |
| `equip` | `EquipHandler` | `{ commodityInstanceId }` | authority: owned + equippable category (weapon/armor/rod/reel). commit: set `equipped[slot]`, re-`commitUnlocks`. **non-critical** (dirty-flag autosave). |
| `upgrade` | `ShopHandler.upgradeHandler` | `{ commodityInstanceId }` | intra-tier climb; debit `intraTierUpgradeCost`; never changes EHT/EFT. `critical`. |

`Gauntlet.handle(reg, {intent, playerId, payload}, session, deps)` returns
`{ ok: boolean, reason: string?, projection: Replication.Projection? }`. On `ok` the projection is a fresh
read-only snapshot.

### 2.3 `Replication.Projection` shape (what the client renders — verified)

```
{ balance, eht, eft, unlockedDestinations, conqueredDestinations, hunterRankXP, anglerRankXP,
  gates, trophyHall:{displayed,slotsUsed,slotsTotal}, worldMap:{[destId]=Pin}, passport }
```

Notably **no `inventory` and no `equipped`** — so the shop's owned/equip list cannot be derived client-side;
the `ShopRequest` "open" reply must carry it (§3).

### 2.4 Helper signatures the glue depends on (verified by the grounding sweep)

- `Economy.gearCostSlot(config, tier) → number` — `tier ≤ 1 ⇒ 0`; else `round(c · income(tier−1))`. **This is
  exactly the amount the buy handler debits** → the shop must **display this**, not `item.cost`.
- `Economy.intraTierUpgradeCost(config, tier, fromLevel) → number`, `fromLevel ∈ {"entry","mid"}`.
- `Profile.mintCommodity(profile, catalogId, intraLevel) → Commodity` — assigns stable `"ci<n>"` instanceId
  from `profile.nextCommodityInstanceSeq` (persisted; survives reload); sets
  `{instanceId, catalogId, intraLevel, equipped=false}`.
- `Schema.Commodity = { instanceId: string, catalogId: ItemId, intraLevel: number, equipped: boolean }`.
- `Schema.EquipmentItem` fields used: `id, name, category, tier, availableAt, tierInput`. (It has more fields —
  `cost (tagged union), tradeable, cosmeticOnly, monetizationRoles, accessGrant, notes` — the builder
  **selects** specific fields, never spreads the item.)

### 2.5 The T2 milestone item (verified)

`weapon_lever_action_rifle` — "Lever-Action Rifle", `category=weapon`, `tier=2`, `availableAt=Outfitter`.
Price = `Economy.gearCostSlot(config, 2)`. Buy → mint unequipped → equip its `instanceId` → it drives
`FireHandler` damage.

### 2.6 World instance names the controllers must find (built by `WorldServer` at startup)

- `workspace.BayouShell_Placeholder/` → `Outfitter_Anchor`, `TackleShop_Anchor`, `TravelSignpost_Anchor`,
  `BayouArrival` (SpawnLocation), `Zones/`, `Ambiance/`, `Ground`.
- `workspace.Lodge_Placeholder/` → fixtures (Parts) `Outfitter`, `TackleShop`, `TravelDesk_WorldMap`,
  `TrophyHall`, `TradingPost`, `BoatDealer`, `KennelAndStable` (each has `service`/`status` attributes).
- `workspace.HuntingTargets/` → creature Models (attrs `creatureId`/`targetId`, PrimaryPart
  `HumanoidRootPart`). `workspace.FishingBites/` → ball Parts (attrs `fishId`/`targetId`).

The fire/cast targeting is **server-side**, so the controllers do **not** read these target folders; they only
attach ProximityPrompts to the vendor/travel anchors+fixtures.

### 2.7 Bayou spawn areas (verified — confirms live targets exist for the milestone)

Hunting: `sunny_levee`, `reed_edges`, `channel_banks` (each `maxConcurrentTargets=3`). Fishing:
`channel_banks` (3), `catfish_hole` (2). First-spawn guarantees seed `sunny_levee` (hunt) + `channel_banks`
(fish) for a first-time player.

---

## 3. The server glue — additive `ShopRequest` block in `WorldServer.server.luau`

A single clearly-commented additive block placed beside the other RemoteEvent blocks. **Reuses** the
file-locals `registry`, `sessionService`, `gauntletDeps`. **Adds two requires:** `Economy` (`@src/logic/Economy`,
for prices) and `Replication` (`@src/server/authority/Replication`, to attach a fresh projection to read-only
"open" replies so the HUD stays in sync). **Hard constraint:** the spawn loops, the fire/raycast handler, and
the existing gauntlet routing are **not touched**.

### 3.1 Protocol

`ShopRequest:FireServer(action, arg1, arg2)`:

- `("open", vendor)` — `vendor ∈ {"Outfitter","TackleShop"}`. Read-only; no gauntlet.
- `("buy", itemId, vendor)`
- `("equip", commodityInstanceId, vendor)`
- `("upgrade", commodityInstanceId, vendor)`

Server → client `ShopRequest:FireClient(plr, kind, …)`:

- `("listing", vendor, listing, projection)` — sent on `open` and after every successful mutation (rebuilt
  from the now-current profile). `projection` is `Replication.buildProjection(profile, Catalog)`.
- `("result", op, ok: boolean, reason: string?)` — `op ∈ {"buy","equip","upgrade"}`. On `ok=false` carries the
  gauntlet `reason` (e.g. `insufficient_funds`, `not_owned`). On `ok=true` the rebuilt `listing` follows.

`listing = { vendor, forSale, owned }`:

- `forSale[]` = for each `Catalog.equipment` item where `tierInput and availableAt == vendor and tier >= 2`:
  `{ itemId, name, tier, price = Economy.gearCostSlot(Catalog, tier), owned: boolean }`.
  (`owned` = the profile already has a commodity with `catalogId == itemId`.)
- `owned[]` = for each `profile.inventory.commodities` whose item is `tierInput` and in the vendor's
  categories (`Outfitter → {weapon,armor}`, `TackleShop → {rod,reel}`):
  `{ instanceId, catalogId, name, tier, intraLevel, equipped }`. (Category-filtered, not vendor-filtered, so
  the free starter gear also shows and can be re-equipped.)

### 3.2 Routing

`open` → guard `session ≠ nil` → build listing → `FireClient("listing", …, projection)`.
`buy`/`equip`/`upgrade` → guard session → `Gauntlet.handle(registry, {intent=op, playerId=plr.UserId,
payload=<{itemId}|{commodityInstanceId}>}, session, gauntletDeps(plr))` →
on `r.ok`: `FireClient("result", op, true, nil)` then `FireClient("listing", vendor, rebuilt, r.projection)`;
else `FireClient("result", op, false, r.reason)`.

---

## 4. The client layer (under `client/` → `StarterPlayerScripts`)

Rojo mapping: `*.luau` → ModuleScript, `*.client.luau` → LocalScript. ModuleScripts run once and their return
value is **cached + shared** across all LocalScripts in the same client context — so `Hud` is a safe singleton.

| File | Kind | Responsibility |
|---|---|---|
| `Net.luau` | ModuleScript | `WaitForChild`s and exposes the RemoteEvents (`FireRequest`, `FishingCast`, `ShopRequest`, `TravelRequest`). One lookup point; controllers `require(script.Parent:WaitForChild("Net"))`. |
| `Hud.luau` | ModuleScript (singleton) | Owns one `ScreenGui`: Cash / EHT / EFT header driven by `applyProjection(proj)` (tracks last balance → renders **payout deltas** "+$N"); a center **crosshair**; `toast(text, color)`; a cosmetic **tension gauge** for fishing. |
| `FireController.client.luau` | LocalScript | On shot input (mouse click / touch tap), aim = **camera screen-center ray direction** (crosshair); `FireRequest:FireServer(camRayOrigin, dir)`. Renders `("hit",…,dmg)` → hitmarker+dmg; `("kill",…,projection)` → `Hud.applyProjection` + payout toast. Small client-side cooldown to avoid spam (server enforces fire rate authoritatively). |
| `FishingController.client.luau` | LocalScript | "Cast" input → `FishingCast:FireServer("cast")`. On `("bite",…)` → start a fight: while a "Reel" button/key is held, send `("fight", E)` at ~10 Hz with `E` ramping in `[0,1]`; render `("fightProgress",…)` on the cosmetic gauge; `("landed",…,projection)` → `Hud.applyProjection` + payout toast. Idle/timeout guards. |
| `ShopController.client.luau` | LocalScript | Attaches `ProximityPrompt`s to the Bayou `Outfitter_Anchor`/`TackleShop_Anchor` **and** the Lodge `Outfitter`/`TackleShop` fixtures (waits for the world folders, derives vendor from part name). On trigger → `ShopRequest:FireServer("open", vendor)`. On `("listing",…)` → build a minimal buy/equip/upgrade panel (price + "owned"/"can't afford" states from `forSale`/projection.balance; equip/upgrade buttons per `owned`). On `("result",…)` → toast + (ok) `Hud.applyProjection`. |
| `TravelController.client.luau` | LocalScript | **Minimal** (off the milestone critical path). Prompt on Bayou `TravelSignpost_Anchor` + Lodge `TravelDesk_WorldMap` → `("openMap")`; on `("map", pins, …)` render a simple destination list; select → `("travel", destId)`; render `traveling`/`denied`. |
| `CharacterController.client.luau` | LocalScript (exists) | **Unchanged** — camera/touch tuning is already correct. |

---

## 5. Data flow — the milestone, step by step

1. **Spawn.** Login → `placeCharacter` pivots to the Bayou arrival; `guaranteeFirstSpawns` seeds a huntable in
   `sunny_levee` + a bite in `channel_banks`. `CharacterController` sets the camera. (No projection yet — HUD
   Cash shows "—" until the first server reply or shop open.)
2. **Shoot a routine huntable.** Click → `FireRequest:FireServer(camOrigin, dir)`. Server raycasts from the
   character, accumulates damage; non-lethal → `("hit",…,dmg)`; lethal → gauntlet `fire` → `("kill",…,proj)`.
   `Hud.applyProjection(proj)` → Cash jumps by the **Tier-1 routine band** (verified live by reading the delta /
   server analytics).
3. **Buy the T2 weapon.** Walk to Outfitter prompt → `("open","Outfitter")` → listing shows
   "Lever-Action Rifle — $`gearCostSlot(2)`". Click buy → `("buy","weapon_lever_action_rifle","Outfitter")` →
   gauntlet debits + mints unequipped → `("result","buy",true)` + rebuilt listing (now `owned` includes the
   rifle with its `ci<n>` instanceId, `equipped=false`).
4. **Equip it.** Click equip on the rifle → `("equip", ci<n>, "Outfitter")` → gauntlet sets `equipped.weapon` +
   `commitUnlocks` → `("result","equip",true)` + listing + projection (EHT may rise).
5. **Shoot a higher target.** Now `FireHandler` reads the T2 weapon → higher damage band.
6. **Catch a routine fish.** Cast at `channel_banks`/`catfish_hole` water → `("bite",…)` → hold-Reel fight →
   `("landed",…,proj)` → Cash jumps by the matching fishing band.
7. **Rejoin persists.** `buy`/`upgrade` are `critical` (write-through Transaction); `equip` rides the
   dirty-flag autosave; SessionService persists on logout. On rejoin the projection shows the retained Cash +
   the owned/equipped T2 weapon. (Persistence-on-rejoin is a playtest-verified item.)

---

## 6. Decisions & flags

- **D1 — Aim: crosshair direction + forward-compatible camera origin.** The client sends `aimDirection` =
  camera screen-center ray direction (predictable on desktop + touch). It **also sends the real camera-ray
  origin** as `aimOrigin` even though the server currently ignores it — so the future parallax fix (server
  raycasts from the camera while bounding the claimed origin near the character) has the data already on the
  wire, with **no server change today** and authority unchanged. **Playtest watch:** the server raycasts from
  `char.PrimaryPart.Position`, not the camera, so close-range third-person aim can feel offset (parallel rays).
  Keep the choice; confirm feel live; if off, apply the camera-origin fix server-side then.
- **D2 — Untyped client surface (durable, non-blocking for S1).** `client/` is outside the analyzer's roots
  (`run-tests.sh` searches only `src tests`) — *independent* of the (correct) choice to use plain `.luau`
  ModuleScripts. Bringing `client/` under `--!strict` would require Roblox API type definitions
  (luau-lsp/roblox types), a real toolchain addition. For S1's thin aim-and-render layer this is acceptable.
  **Recommendation:** decide whether to type the client surface (esp. a shared `Projection` type) **before the
  full UI grows** (Trophy Hall, world map, trading panels) — that larger surface accumulating untyped is real
  debt. Not an S1 blocker.
- **D3 — Hud is a singleton ModuleScript.** Relies on Roblox's per-context module cache; all controllers share
  one `ScreenGui`. Verified-by-construction in the adversarial review (§7).
- **D4 — Tension gauge is cosmetic for S1.** The client doesn't know `staminaToLand` (server-side) and the
  `("bite",…)` reply carries no target, so the gauge animates on `fightProgress` deltas without a true max. An
  accurate gauge would need the server to send the stamina target on `bite` — a tiny future additive change,
  deliberately **not** made now (don't touch the fishing flow). The authoritative land is the `("landed")`
  event.
- **D5 — ShopRequest carries a full projection** on `open` and successful mutations (consistent with how
  kill/catch/equip already return projections), so the HUD stays in sync without a separate balance fetch.

---

## 7. Verification

**This session (git layer):**
- `./run-tests.sh` stays **ALL GREEN** — `client/**` is outside the analyzer roots and the one server edit is a
  `.server.luau` (also excluded); only `rojo build` (gate 4) sees the new files, and it just packages.
- `rojo build default.project.json` succeeds with the new client files mapped into `StarterPlayerScripts`.
- **Adversarial review workflow** (post-implementation): read each controller + the `ShopRequest` block against
  the exact §2 signatures; hunt integration bugs — the buy→equip→fire chain, projection-delta rendering, the
  ProximityPrompt attach-timing race (world folders built at server start vs client start), the Hud
  module-cache singleton assumption, the fishing fight-tick loop lifecycle (start on bite / stop on land /
  timeout), nil character/camera guards, and "client asserts nothing" (no price/balance/hit claimed client
  side). Fix findings; commit on a branch.

**Deferred to a live-Studio session (Steve runs):** the actual playtest of the loop; payout-band confirmation
(`combat.payout`/`economy.buy:tier` via the analytics events / Cash delta); persistence-on-rejoin; the
aesthetic geometry pass; the aim-parallax feel check (D1). Optional small aid added *then* (not now): a `print`
in `WorldServer`'s currently-empty telemetry sink so the bands are console-visible.

---

## 8. Out of scope (unchanged from the prompt)

The rest of Bayou + Appalachia/Alaska geometry; the full UI (Trophy Hall, world map, trading panels, daily
board, event banners); the real-money platform calls (`ProcessReceipt` asset-id binding); aesthetic/visual
polish; the Frozen-Lake / rare-spawn windows. Keep the slice minimal so the loop is provable.

---

## 9. Risks / open questions

- **ProximityPrompt attach timing.** The client must find server-built world parts; mitigated by
  `WaitForChild` on the folders + a bounded retry. (Reviewed in §7.)
- **Vendor part naming across worlds.** Appalachia/Alaska also have `Outfitter_Anchor` etc. at world offsets;
  S1 attaches only to the Bayou folder + Lodge fixtures to avoid cross-world prompts. Documented so it's a
  deliberate scope line, not an omission.
- **HUD before first projection.** Cash shows "—" until the first kill/catch or shop open; acceptable for S1
  (first shop `open` carries a projection). If undesirable, a login-time projection push is a trivial future
  addition (out of S1).
