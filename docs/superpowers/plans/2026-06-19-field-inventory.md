# Field Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the player open a standalone inventory anywhere (a key + an on-screen button) to switch which gear is equipped in the four slots (weapon/armor/rod/reel), reusing the existing equip intent end-to-end.

**Architecture:** A thin headless pure module (`logic/Loadout`) computes "owned equippable gear grouped by slot" (equipped derived from `profile.equipped`). A vendor-free `InventoryRequest` RemoteEvent in `WorldServer` answers `"open"` (→ loadout + projection) and `"equip"` (→ routes the existing `equip` intent through the Gauntlet/`EquipHandler` unchanged, always returning the projection). A new client controller renders the panel and sends only an `instanceId`.

**Tech Stack:** Luau, Rojo, the headless test harness (`luau tests/run.luau` / `./run-tests.sh`), Roblox Studio (client + world script).

## Global Constraints

Copy these verbatim into every task's mental checklist:

- Run all commands from the git root `RobloxRPG/RobloxRPG`.
- `./run-tests.sh` is the Definition-of-Done gate (luau-analyze `--!strict` on every headless module · all unit tests · negative fixtures must still fail · `rojo build` succeeds). It must stay green.
- Headless modules (`src/logic/*`, `src/types/*`) are `--!strict`, reference **no** Roblox globals, and require by **relative** string (`require("../types/Schema")`). Tests require by `@src/...` / `@tests/...` alias.
- Studio-only files are `*.client.luau` and `WorldServer.server.luau`; they are excluded from luau-analyze + unit tests and verified by the Studio playtest (Task 4). Keep Roblox-API code out of `src/logic`.
- Closed enums live once: the four equippable slots come from `Enums.TIER_INPUT_CATEGORIES` (`{weapon, armor, rod, reel}`), never a string-literal list.
- Derive, don't store: `equipped` in the loadout is derived from `profile.equipped[slot] == instanceId`, never the denormalized `commodity.equipped` flag.
- Server-authority: the client sends only an `instanceId`; the Gauntlet/`EquipHandler` validates ownership + equippability. No client-side tier math or optimistic equip.
- Reuse `EquipHandler` / the Gauntlet verbatim — no new equip logic, no change to the `ShopRequest` path or `buildShopListing`. Scope: the four slots, swap-only, static held model.

---

### Task 1: `logic/Loadout` — owned equippable gear grouped by slot (headless, TDD)

**Files:**
- Create: `src/logic/Loadout.luau`
- Create: `tests/Loadout.spec.luau`
- Modify: `tests/run.luau` (register the new spec)

**Interfaces:**
- Consumes: `Schema.PlayerData`, `Schema.Config`, `Enums.Category`, `Enums.TIER_INPUT_CATEGORIES`.
- Produces:
  - `type GearRow = { instanceId: string, catalogId: string, name: string, tier: number, intraLevel: number, equipped: boolean }`
  - `type Loadout = { weapon: {GearRow}, armor: {GearRow}, rod: {GearRow}, reel: {GearRow} }`
  - `Loadout.ownedEquippableBySlot(profile: PlayerData, config: Config) -> Loadout` — used by the `InventoryRequest` server handler (Task 2).

- [ ] **Step 1: Write the failing test**

Create `tests/Loadout.spec.luau`:

```lua
--!strict
local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Loadout = require("@src/logic/Loadout")

-- find a real catalog item id by category (+ optional tier) — data-driven, like the game does
local function itemId(category: string, tier: number?): string
	for _, it in Catalog.equipment do
		if it.category == category and (tier == nil or it.tier == tier) then
			return it.id
		end
	end
	error("test: no " .. category .. " item" .. (if tier ~= nil then " T" .. tier else ""))
end

return function(t: Harness.T)
	t.section("Loadout — owned equippable gear grouped by the four slots")
	local p = Util.mkProfile(Catalog, { weapon = 2, armor = 2, rod = 1, reel = 1 })
	local lo = Loadout.ownedEquippableBySlot(p, Catalog)
	t.eq("weapon slot has 1 owned", #lo.weapon, 1)
	t.eq("armor slot has 1 owned", #lo.armor, 1)
	t.eq("rod slot has 1 owned", #lo.rod, 1)
	t.eq("reel slot has 1 owned", #lo.reel, 1)
	t.ok("equipped weapon is marked equipped", lo.weapon[1].equipped)
	t.eq("weapon row carries the catalog tier", lo.weapon[1].tier, 2)
	t.ok("weapon row carries a name", lo.weapon[1].name ~= "")

	t.section("Loadout — multiple owned items in one slot; exactly one marked equipped")
	table.insert(p.inventory.commodities, { instanceId = "ci-w-extra", catalogId = itemId("weapon", nil), intraLevel = 0, equipped = false })
	lo = Loadout.ownedEquippableBySlot(p, Catalog)
	t.eq("weapon slot now lists 2 owned", #lo.weapon, 2)
	local nEquipped = 0
	for _, r in lo.weapon do if r.equipped then nEquipped += 1 end end
	t.eq("exactly one weapon equipped", nEquipped, 1)

	t.section("Loadout — equipped is DERIVED from profile.equipped, not the commodity flag")
	local p2 = Util.mkProfile(Catalog, { weapon = 2 }) -- equipped.weapon = "ci1"
	table.insert(p2.inventory.commodities, { instanceId = "ci-stale", catalogId = itemId("weapon", nil), intraLevel = 0, equipped = true }) -- stale flag, NOT the equipped ref
	local lo2 = Loadout.ownedEquippableBySlot(p2, Catalog)
	for _, r in lo2.weapon do
		if r.instanceId == "ci-stale" then
			t.ok("stale equipped=true flag overridden by derived ref → false", not r.equipped)
		elseif r.instanceId == "ci1" then
			t.ok("the profile.equipped ref is the one marked equipped", r.equipped)
		end
	end

	t.section("Loadout — non-equippable categories excluded")
	local p3 = Util.mkProfile(Catalog, { weapon = 1 })
	table.insert(p3.inventory.commodities, { instanceId = "ci-bait", catalogId = itemId("bait", nil), intraLevel = 0, equipped = false })
	local lo3 = Loadout.ownedEquippableBySlot(p3, Catalog)
	t.eq("bait is not in any equip slot (only the weapon counts)", #lo3.weapon + #lo3.armor + #lo3.rod + #lo3.reel, 1)

	t.section("Loadout — empty slots return empty lists")
	local p4 = Util.mkProfile(Catalog, { weapon = 1 })
	local lo4 = Loadout.ownedEquippableBySlot(p4, Catalog)
	t.eq("armor empty", #lo4.armor, 0)
	t.eq("rod empty", #lo4.rod, 0)
	t.eq("reel empty", #lo4.reel, 0)
end
```

Register it in `tests/run.luau` — add, immediately before the closing `}` of the `specs` table (after the Analytics line):

```lua
	-- Field inventory (Loadout — owned equippable gear grouped by slot)
	require("@tests/Loadout.spec"),
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `luau tests/run.luau`
Expected: FAIL — the run errors / the spec cannot load because `@src/logic/Loadout` does not exist yet.

- [ ] **Step 3: Write the minimal implementation**

Create `src/logic/Loadout.luau`:

```lua
--!strict
-- PURE READ-ONLY VIEW — the player's OWNED equippable gear, grouped by the four equip slots, each row
-- marked `equipped` DERIVED from `profile.equipped` (never the denormalized `commodity.equipped` flag).
-- Zero content literals; the slot set comes from Enums.TIER_INPUT_CATEGORIES. Feeds the field-inventory
-- client panel via the InventoryRequest server handler. Same row shape as the shop's owned listing.
local Schema = require("../types/Schema")
local Enums = require("../types/Enums")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type Category = Enums.Category

export type GearRow = {
	instanceId: string,
	catalogId: string,
	name: string,
	tier: number,
	intraLevel: number,
	equipped: boolean,
}
export type Loadout = {
	weapon: { GearRow },
	armor: { GearRow },
	rod: { GearRow },
	reel: { GearRow },
}

local M = {}

-- The equipped commodity instanceId for a category. Explicit per-slot (strict-safe — EquippedRefs is a
-- named struct, not a string-indexed map). nil = empty slot.
local function equippedInstanceId(profile: PlayerData, category: Category): string?
	local e = profile.equipped
	if category == Enums.Category.weapon then
		return e.weapon
	elseif category == Enums.Category.armor then
		return e.armor
	elseif category == Enums.Category.rod then
		return e.rod
	elseif category == Enums.Category.reel then
		return e.reel
	end
	return nil
end

function M.ownedEquippableBySlot(profile: PlayerData, config: Config): Loadout
	local out: Loadout = { weapon = {}, armor = {}, rod = {}, reel = {} }
	for _, c in profile.inventory.commodities do
		local item = config.equipment[c.catalogId]
		if item ~= nil and Enums.TIER_INPUT_CATEGORIES[item.category] then
			local rowData: GearRow = {
				instanceId = c.instanceId,
				catalogId = c.catalogId,
				name = item.name,
				tier = item.tier,
				intraLevel = c.intraLevel,
				equipped = equippedInstanceId(profile, item.category) == c.instanceId,
			}
			-- item.category is guaranteed one of the four by TIER_INPUT_CATEGORIES above
			if item.category == Enums.Category.weapon then
				table.insert(out.weapon, rowData)
			elseif item.category == Enums.Category.armor then
				table.insert(out.armor, rowData)
			elseif item.category == Enums.Category.rod then
				table.insert(out.rod, rowData)
			elseif item.category == Enums.Category.reel then
				table.insert(out.reel, rowData)
			end
		end
	end
	return out
end

return M
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `luau tests/run.luau`
Expected: PASS — all Loadout assertions green; no other spec affected.

- [ ] **Step 5: Run the full DoD gate**

Run: `./run-tests.sh`
Expected: ALL GREEN (luau-analyze `--!strict` accepts `Loadout.luau`; all unit tests pass; negative fixtures still fail; `rojo build` succeeds).

- [ ] **Step 6: Commit**

```bash
git add src/logic/Loadout.luau tests/Loadout.spec.luau tests/run.luau
git commit -m "feat(field-inventory): Loadout.ownedEquippableBySlot — owned equippable gear grouped by slot

Pure headless view: groups owned commodities under the four equip slots
(from Enums.TIER_INPUT_CATEGORIES), equipped derived from profile.equipped.
Feeds the field-inventory panel. Unit-tested.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `InventoryRequest` server channel in `WorldServer` (Studio-only)

**Files:**
- Modify: `src/server/world/WorldServer.server.luau` — add a `Loadout` require near the other top-of-file requires (where `Catalog = require("../../config/Catalog")` is); add the `InventoryRequest` RemoteEvent + handler immediately after the `shopRequest.OnServerEvent:Connect(...)` block (~L1147 onward).

**Interfaces:**
- Consumes: `Loadout.ownedEquippableBySlot` (Task 1); existing `sessionService`, `registry`, `gauntletDeps`, `Gauntlet.handle`, `Replication.buildProjection`, `Catalog`, `ReplicatedStorage`.
- Produces: a `ReplicatedStorage.InventoryRequest` RemoteEvent with replies `("loadout", loadout, projection)` and `("equipped", ok, reason, loadout, projection)` — consumed by the client (Task 3).

> **Note:** `WorldServer.server.luau` is Studio-only (excluded from luau-analyze + unit tests). This task has no headless test; it is verified by `rojo build` (syntax/sync) here and by the Studio playtest in Task 4. There is no new equip logic — the handler routes the existing `"equip"` intent.

- [ ] **Step 1: Add the `Loadout` require**

Near the other top-of-file requires (alongside `local Catalog = require("../../config/Catalog")`), add:

```lua
local Loadout = require("../../logic/Loadout")
```

- [ ] **Step 2: Add the `InventoryRequest` remote + handler**

Immediately after the entire `shopRequest.OnServerEvent:Connect(function(...) ... end)` block, add:

```lua
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- FIELD INVENTORY (additive, vendor-FREE): view owned gear by slot + equip anywhere. "equip" routes the
-- SAME gauntlet intent as the shop (EquipHandler unchanged); the ONLY new behavior is that the projection
-- is ALWAYS returned on a field equip (the shop path gates its refresh on a known vendor). Read-only "open"
-- needs no gauntlet (no mutation). The shop path + buildShopListing are untouched.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local inventoryRequest = Instance.new("RemoteEvent")
inventoryRequest.Name = "InventoryRequest"
inventoryRequest.Parent = ReplicatedStorage

inventoryRequest.OnServerEvent:Connect(function(plr, action, arg1)
	local session = sessionService.sessions[plr.UserId]
	if session == nil then
		return
	end
	if action == "open" then
		inventoryRequest:FireClient(
			plr, "loadout",
			Loadout.ownedEquippableBySlot(session.profile, Catalog),
			Replication.buildProjection(session.profile, Catalog)
		)
		return
	end
	if action == "equip" then
		local r = Gauntlet.handle(
			registry,
			{ intent = "equip", playerId = plr.UserId, payload = { commodityInstanceId = arg1 } },
			session,
			gauntletDeps(plr)
		)
		inventoryRequest:FireClient(
			plr, "equipped", r.ok, r.reason,
			Loadout.ownedEquippableBySlot(session.profile, Catalog),
			r.projection
		)
		return
	end
end)
```

- [ ] **Step 3: Verify the project still builds**

Run: `rojo build default.project.json --output /tmp/wildworld.rbxlx`
Expected: `Built project to ...` with exit 0 (no syntax error).

- [ ] **Step 4: Run the DoD gate (confirm nothing headless regressed)**

Run: `./run-tests.sh`
Expected: ALL GREEN (the `.server.luau` change is excluded from analyze/tests; this confirms the project still syncs and no headless module broke).

- [ ] **Step 5: Commit**

```bash
git add src/server/world/WorldServer.server.luau
git commit -m "feat(field-inventory): InventoryRequest server channel (vendor-free equip)

Adds open (-> loadout + projection) and equip (-> routes the existing equip
intent through the gauntlet, always returns the projection). Reuses
EquipHandler verbatim; shop path + buildShopListing untouched.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: `InventoryController` client panel + `Net` wiring (Studio-only)

**Files:**
- Modify: `client/Net.luau` — add the `InventoryRequest` remote to the returned table.
- Create: `client/InventoryController.client.luau` — the panel, the `I` key + `GEAR` button, the open/equip flow.

**Interfaces:**
- Consumes: `Net.inventory` (this task's `Net.luau` entry); `Hud.gui`, `Hud.button`, `Hud.applyProjection`, `Hud.toast`; the `InventoryRequest` replies from Task 2 (`"loadout"`, `"equipped"`).
- Produces: none (terminal client feature).

> **Note:** Both files are Studio-only (excluded from luau-analyze + unit tests); verified by `rojo build` here and the Studio playtest in Task 4.

- [ ] **Step 1: Add the remote to `Net.luau`**

In `client/Net.luau`, add the `inventory` entry to the returned table (alongside `shop = ev("ShopRequest")`):

```lua
	inventory = ev("InventoryRequest"),
```

- [ ] **Step 2: Create the client controller**

Create `client/InventoryController.client.luau`:

```lua
--!nonstrict
-- STUDIO-ONLY. The field inventory: a key (I) and an on-screen GEAR button toggle a panel listing the
-- player's OWNED equippable gear grouped by the four slots, with EQUIP buttons. Reuses the server's equip
-- intent via the vendor-free InventoryRequest channel. The client asserts NOTHING — it renders the server's
-- loadout and sends an instanceId; the server validates + equips. Swap-only; the held model is intentionally
-- static (tier-based held visuals are deferred). Mirrors ShopController's panel/render pattern.
local UserInputService = game:GetService("UserInputService")
local Net = require(script.Parent:WaitForChild("Net"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local SLOTS = { "weapon", "armor", "rod", "reel" }
local SLOT_TITLE = { weapon = "WEAPON", armor = "ARMOR", rod = "ROD", reel = "REEL" }

-- the panel
local panel = Instance.new("Frame")
panel.Name = "InventoryPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(430, 470)
panel.BackgroundColor3 = Color3.fromRGB(24, 28, 26)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = Hud.gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local function clearRows()
	for _, ch in panel:GetChildren() do
		if not ch:IsA("UIListLayout") then
			ch:Destroy()
		end
	end
end

local function row(height)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -16, 0, height)
	f.BackgroundTransparency = 1
	f.Parent = panel
	return f
end

local function rowLabel(parent, text, width, size, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(0, width, 1, 0)
	l.Position = UDim2.fromOffset(8, 0)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size or 15
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = color or Color3.fromRGB(235, 235, 220)
	l.Text = text
	l.Parent = parent
	return l
end

local function rowButton(parent, text, cb)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -6, 0.5, 0)
	b.Size = UDim2.fromOffset(104, 30)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.BackgroundColor3 = Color3.fromRGB(50, 90, 70)
	b.TextColor3 = Color3.fromRGB(240, 240, 230)
	b.Text = text
	b.Parent = parent
	b.Activated:Connect(cb)
	return b
end

local function render(loadout)
	clearRows()
	local titleRow = row(34)
	rowLabel(titleRow, "GEAR", 360, 20).Font = Enum.Font.GothamBold
	rowButton(titleRow, "X", function()
		panel.Visible = false
	end)
	for _, slot in SLOTS do
		rowLabel(row(20), SLOT_TITLE[slot], 400, 14, Color3.fromRGB(170, 200, 160))
		local items = loadout[slot]
		if items == nil or #items == 0 then
			rowLabel(row(26), "(none owned)", 300, 14, Color3.fromRGB(150, 150, 140))
		else
			for _, c in items do
				local r = row(36)
				local tag = c.equipped and "  [equipped]" or ""
				rowLabel(r, string.format("%s (T%d) Lv%d%s", c.name, c.tier, c.intraLevel, tag), 250)
				if not c.equipped then
					rowButton(r, "EQUIP", function()
						Net.inventory:FireServer("equip", c.instanceId)
					end)
				end
			end
		end
	end
	panel.Visible = true
end

local function toggle()
	if panel.Visible then
		panel.Visible = false
	else
		Net.inventory:FireServer("open") -- server replies "loadout" → render(...) shows the panel
	end
end

Net.inventory.OnClientEvent:Connect(function(kind, a, b, c, d)
	if kind == "loadout" then
		-- a = loadout, b = projection
		Hud.applyProjection(b)
		render(a)
	elseif kind == "equipped" then
		-- a = ok, b = reason, c = loadout, d = projection
		if a then
			Hud.applyProjection(d)
			render(c) -- keep the panel open + refresh the [equipped] tags
		else
			Hud.toast("equip failed: " .. tostring(b), Color3.fromRGB(230, 150, 140))
		end
	end
end)

-- input: I key (desktop) + an on-screen GEAR button (touch/console), placed above the FIRE button
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.I then
		toggle()
	end
end)

local gearBtn = Hud.button({
	name = "GearButton",
	text = "GEAR",
	position = UDim2.new(1, -20, 1, -215),
	size = UDim2.fromOffset(120, 48),
	color = Color3.fromRGB(60, 70, 90),
})
gearBtn.Activated:Connect(toggle)
```

- [ ] **Step 3: Verify the project still builds**

Run: `rojo build default.project.json --output /tmp/wildworld.rbxlx`
Expected: `Built project to ...` with exit 0.

- [ ] **Step 4: Run the DoD gate**

Run: `./run-tests.sh`
Expected: ALL GREEN (client files excluded from analyze/tests; confirms the project still syncs).

- [ ] **Step 5: Commit**

```bash
git add client/Net.luau client/InventoryController.client.luau
git commit -m "feat(field-inventory): InventoryController client panel + Net wiring

Key (I) and on-screen GEAR button toggle a panel of owned gear grouped by
slot; EQUIP fires the vendor-free InventoryRequest equip; the reply applies
the projection (HUD EHT/EFT + tags refresh) and re-renders. Mirrors
ShopController. Static held model (no ViewModel/FishingFeel change).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Studio playtest verification (manual)

**Files:** none (verification only).

This feature's interactive behavior is Studio-only. After Tasks 1–3 are committed and the branch is synced into the place (connect the Rojo plugin to the running `rojo serve`, then Play), confirm each item:

- [ ] **Step 1: Open the panel.** Press `I` (desktop) and tap the on-screen `GEAR` button — both toggle the panel open/closed.
- [ ] **Step 2: Listing is correct.** The panel lists owned gear grouped under WEAPON / ARMOR / ROD / REEL; the currently-equipped item in each slot shows `[equipped]`; an empty slot shows `(none owned)`; non-gear (bait/etc.) does not appear.
- [ ] **Step 3: Equip from the field.** Buy a second weapon at the Outfitter, open the field inventory away from the vendor, and `EQUIP` the other weapon. Confirm: the `[equipped]` tag moves, the HUD `EHT`/`EFT` header updates, and the next-goal panel updates if a gate flips. Repeat for a rod/reel (EFT updates).
- [ ] **Step 4: Shop equip still works.** Open the Outfitter shop panel and equip from there — unchanged behavior; both paths write the same `equipped` state.
- [ ] **Step 5: Held model unchanged (expected).** The on-character rifle/rod model does not visually change on swap — this is the intended v1 scope (tier-based held visuals deferred).
- [ ] **Step 6: Report** which checks passed; note any layout nudge needed for the `GEAR` button position (it is placed above `FIRE`; adjust the `position` offset if it overlaps on a given resolution).

---

## Spec coverage check

- "Field inventory panel opened by `I` + GEAR button, grouped by slot, equip any owned item" → Task 3 + Task 4.
- "Reuse `EquipHandler`/Gauntlet verbatim, server-authoritative" → Task 2 (routes the `equip` intent; no new logic).
- "HUD EHT/EFT refresh after a field equip" → Task 2 always returns the projection; Task 3 calls `Hud.applyProjection`.
- "Headless, unit-tested owned-equippable-by-slot builder" → Task 1.
- Non-goals (unequip, held-visual refresh, new categories, shop-path refactor) → none of the tasks add these; explicitly excluded.
