# S1 — Bayou Client Layer + Shop/Equip Glue — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the verified Bayou loop to a live runtime by building the missing client controllers + the missing in-game shop/equip RemoteEvent, so a player can shoot → get paid → buy+equip the T2 weapon → shoot harder → catch a fish → get paid, all through the existing server-authoritative handlers.

**Architecture:** The client is a pure aim-and-render terminal that talks to the server only through ReplicatedStorage RemoteEvents and renders the server's read-only `projection`. One additive `ShopRequest` block in `WorldServer.server.luau` routes the already-registered `buy`/`equip`/`upgrade` gauntlet intents (they had no wire). No existing server logic is edited.

**Tech Stack:** Roblox Luau; Rojo (`default.project.json` maps `client/` → `StarterPlayerScripts`, `*.luau`→ModuleScript, `*.client.luau`→LocalScript); the headless `@src` modules (server-side only).

**Companion spec:** `docs/superpowers/specs/2026-06-18-s1-bayou-client-layer-design.md` (the verified contract is §2 there).

## Global Constraints

- **Run all commands from the git root `RobloxRPG/RobloxRPG/`** (the nested dir).
- **Verification model (overrides TDD — per CLAUDE.md's headless/Studio split):** `client/**` and `*.server.luau` are Studio-only and **excluded from headless analysis**. There is no headless unit test for them. Per-task gate: (1) `./run-tests.sh` stays **ALL GREEN** (headless layer intact + `rojo build` syncs), (2) a syntax-sanity grep, (3) the file reads correctly against the §2 contract. Suite gate: the adversarial-review workflow (Task 8) + the **deferred Studio playtest** (Steve).
- **Do NOT edit** the spawn loops, the fire/raycast handler, or the existing gauntlet routing in `WorldServer.server.luau`. The only server change is the additive `ShopRequest` block + its two new `require`s.
- **The client asserts nothing** — no price, balance, ownership, or hit is computed client-side; it sends intents (itemId / instanceId / aim) and renders server replies.
- Client files are `--!nonstrict` (matching the existing `CharacterController.client.luau`); they reference Roblox globals, which is why they're outside the analyzer.
- ModuleScripts under `client/` are shared singletons (Roblox caches a module's return value per client context) — `Hud` relies on this.

---

### Task 0: Branch + commit the design artifacts

**Files:** none created; commits the already-written spec + this plan.

- [ ] **Step 1: Branch off main**

Run (from `RobloxRPG/RobloxRPG/`):
```bash
git checkout -b s1-bayou-client
```
Expected: `Switched to a new branch 's1-bayou-client'`

- [ ] **Step 2: Commit the spec + plan**

```bash
git add docs/superpowers/specs/2026-06-18-s1-bayou-client-layer-design.md docs/superpowers/plans/2026-06-18-s1-bayou-client-layer.md
git commit -m "docs(s1): Bayou client-layer spec + implementation plan"
```

---

### Task 1: The `ShopRequest` server glue (Outfitter / Tackle Shop buy + equip + upgrade)

**Files:**
- Modify: `src/server/world/WorldServer.server.luau` — add two requires (after the existing require block, ~line 53) and one additive block (before the `LOGIN → ARRIVAL` section, ~line 809).

**Interfaces:**
- Consumes (existing file-locals): `sessionService`, `registry`, `gauntletDeps(plr)`, `Catalog`, `ReplicatedStorage`, `Gauntlet`.
- Consumes (existing modules): `Economy.gearCostSlot(config, tier) → number`; `Replication.buildProjection(profile, config) → Projection`; gauntlet intents `buy {itemId}`, `equip {commodityInstanceId}`, `upgrade {commodityInstanceId}`.
- Produces (the client renders these): RemoteEvent `ShopRequest` in `ReplicatedStorage`. Server→client: `("listing", vendor, listing, projection)` and `("result", op, ok, reason)`. `listing = { vendor, forSale=[{itemId,name,tier,price,owned}], owned=[{instanceId,catalogId,name,tier,intraLevel,equipped}] }`.

- [ ] **Step 1: Add the two requires**

In `src/server/world/WorldServer.server.luau`, immediately after `local Adapters = require("@src/server/RobloxAdapters")` add:
```lua
local Economy = require("@src/logic/Economy") -- S1: in-game shop pricing (the amount the buy handler debits)
local Replication = require("@src/server/authority/Replication") -- S1: read-only projection for shop "open"
```

- [ ] **Step 2: Add the additive `ShopRequest` block**

Insert immediately before the `LOGIN → ARRIVAL PLACEMENT` banner comment (the `local FIRST_HUNT_AREA = "sunny_levee"` area):
```lua
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- THE IN-GAME CASH SHOP — Outfitter / Tackle Shop buy + equip + upgrade (S1 client-layer glue).
-- ADDITIVE WIRE ONLY: the gauntlet already owns buy/upgrade (ShopHandler) + equip (EquipHandler), registered
-- on the shared registry above but with NO RemoteEvent. This block is that wire. It does NOT touch the spawn
-- loops, the fire/raycast handler, or the existing gauntlet routing. The client asserts nothing: it sends an
-- itemId / instanceId + the vendor; the server PRICES via Economy, validates + debits inside the gauntlet,
-- and replies with a fresh read-only projection + a rebuilt listing. (PurchaseRequest above is REAL MONEY —
-- a different path; this is the Cash shop.)
local VENDOR_CATEGORIES: { [string]: { [string]: boolean } } = {
	Outfitter = { weapon = true, armor = true },
	TackleShop = { rod = true, reel = true },
}

local function buildShopListing(profile, vendor)
	local cats = VENDOR_CATEGORIES[vendor]
	local forSale = {}
	if cats ~= nil then
		for id, item in Catalog.equipment do
			if item.tierInput and item.availableAt == vendor and item.tier >= 2 then
				local alreadyOwned = false
				for _, c in profile.inventory.commodities do
					if c.catalogId == id then
						alreadyOwned = true
						break
					end
				end
				table.insert(forSale, {
					itemId = id, name = item.name, tier = item.tier,
					price = Economy.gearCostSlot(Catalog, item.tier), owned = alreadyOwned,
				})
			end
		end
	end
	local owned = {}
	for _, c in profile.inventory.commodities do
		local item = Catalog.equipment[c.catalogId]
		if item ~= nil and item.tierInput and cats ~= nil and cats[item.category] then
			table.insert(owned, {
				instanceId = c.instanceId, catalogId = c.catalogId, name = item.name,
				tier = item.tier, intraLevel = c.intraLevel, equipped = c.equipped,
			})
		end
	end
	return { vendor = vendor, forSale = forSale, owned = owned }
end

local shopRequest = Instance.new("RemoteEvent")
shopRequest.Name = "ShopRequest"
shopRequest.Parent = ReplicatedStorage

local SHOP_INTENT = { buy = "buy", equip = "equip", upgrade = "upgrade" }

shopRequest.OnServerEvent:Connect(function(plr, action, arg1, arg2)
	local session = sessionService.sessions[plr.UserId]
	if session == nil then
		return
	end
	if action == "open" then
		if VENDOR_CATEGORIES[arg1] == nil then
			return
		end
		shopRequest:FireClient(plr, "listing", arg1, buildShopListing(session.profile, arg1), Replication.buildProjection(session.profile, Catalog))
		return
	end
	local intent = SHOP_INTENT[action]
	if intent == nil then
		return
	end
	local vendor = arg2
	local payload = if intent == "buy" then { itemId = arg1 } else { commodityInstanceId = arg1 }
	local r = Gauntlet.handle(registry, { intent = intent, playerId = plr.UserId, payload = payload }, session, gauntletDeps(plr))
	if r.ok then
		shopRequest:FireClient(plr, "result", action, true, nil)
		if VENDOR_CATEGORIES[vendor] ~= nil then
			shopRequest:FireClient(plr, "listing", vendor, buildShopListing(session.profile, vendor), r.projection)
		end
	else
		shopRequest:FireClient(plr, "result", action, false, r.reason)
	end
end)
```

- [ ] **Step 3: Verify the headless gate is still green + rojo syncs**

Run: `./run-tests.sh`
Expected: ends with `ALL GREEN ✓`. (`WorldServer.server.luau` is excluded from analysis; gate 4 `rojo build` must still succeed with the new requires resolvable via `.luaurc`.)

- [ ] **Step 4: Commit**

```bash
git add src/server/world/WorldServer.server.luau
git commit -m "feat(s1): wire in-game ShopRequest (buy/equip/upgrade) — additive glue"
```

---

### Task 2: `client/Net.luau` — the RemoteEvent accessor

**Files:** Create `client/Net.luau`

**Interfaces:**
- Produces: a table `{ fire, cast, shop, travel }` of the four `RemoteEvent`s, resolved via `WaitForChild`.

- [ ] **Step 1: Create the module**

```lua
--!nonstrict
-- STUDIO-ONLY (NOT headless-analyzed). The client's single point of access to the server RemoteEvents. A
-- LocalScript cannot require the @src modules (they live under ServerScriptService), so every controller
-- talks to the server ONLY through these events (created server-side in WorldServer, in ReplicatedStorage).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ev(name)
	return ReplicatedStorage:WaitForChild(name)
end

return {
	fire = ev("FireRequest"),
	cast = ev("FishingCast"),
	shop = ev("ShopRequest"),
	travel = ev("TravelRequest"),
}
```

- [ ] **Step 2: Syntax sanity + green gate**

Run: `luau-analyze client/Net.luau 2>&1 | grep -i "syntaxerror" || echo "no syntax errors"`
Expected: `no syntax errors` (type/unknown-global warnings are expected and ignored — the file is Studio-only).
Run: `./run-tests.sh`
Expected: `ALL GREEN ✓`.

- [ ] **Step 3: Commit**

```bash
git add client/Net.luau
git commit -m "feat(s1): client Net module (RemoteEvent accessor)"
```

---

### Task 3: `client/Hud.luau` — the shared HUD singleton

**Files:** Create `client/Hud.luau`

**Interfaces:**
- Produces: `M.gui` (the ScreenGui), `M.applyProjection(proj)`, `M.toast(text, color?)`, `M.setGauge(visible, fraction?)`, `M.button(opts) → TextButton`, `M.balance() → number?`.
- `applyProjection` reads `proj.balance`, `proj.eht`, `proj.eft` (the verified `Replication.Projection` fields) and toasts a `+$delta` only on a balance INCREASE.

- [ ] **Step 1: Create the module**

```lua
--!nonstrict
-- STUDIO-ONLY. The shared client HUD (singleton ModuleScript — Roblox caches the module result, so every
-- controller that requires it shares ONE ScreenGui). Owns: the Cash/EHT/EFT header (driven by the server's
-- read-only projection), payout-delta toasts, the center crosshair, a transient toast line, the fishing
-- tension gauge, and a styled-button factory the controllers use for their on-screen inputs. Renders ONLY
-- what the server sends; asserts nothing.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local M = {}

local gui = Instance.new("ScreenGui")
gui.Name = "WildWorldHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
M.gui = gui

local function label(parent, name, pos, size, textSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = Color3.fromRGB(235, 235, 220)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextSize = textSize
	l.Text = ""
	l.Parent = parent
	return l
end

-- header (Cash / tiers)
local header = Instance.new("Frame")
header.Name = "Header"
header.Position = UDim2.fromOffset(12, 12)
header.Size = UDim2.fromOffset(230, 64)
header.BackgroundColor3 = Color3.fromRGB(20, 24, 20)
header.BackgroundTransparency = 0.35
header.BorderSizePixel = 0
header.Parent = gui
local cashLabel = label(header, "Cash", UDim2.fromOffset(10, 6), UDim2.fromOffset(210, 26), 22)
local tierLabel = label(header, "Tiers", UDim2.fromOffset(10, 36), UDim2.fromOffset(210, 20), 14)
cashLabel.Text = "$ —"
tierLabel.Text = "EHT — · EFT —"

-- crosshair
local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.Size = UDim2.fromOffset(6, 6)
crosshair.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
crosshair.BackgroundTransparency = 0.2
crosshair.BorderSizePixel = 0
crosshair.Parent = gui

-- toast
local toast = label(gui, "Toast", UDim2.new(0.5, -200, 0.16, 0), UDim2.fromOffset(400, 28), 20)
toast.TextXAlignment = Enum.TextXAlignment.Center
toast.TextStrokeTransparency = 0.4
local toastToken = 0
function M.toast(text, color)
	toastToken += 1
	local mine = toastToken
	toast.Text = text
	toast.TextColor3 = color or Color3.fromRGB(235, 235, 220)
	task.delay(2.5, function()
		if toastToken == mine then
			toast.Text = ""
		end
	end)
end

-- tension gauge (fishing)
local gaugeBack = Instance.new("Frame")
gaugeBack.Name = "Gauge"
gaugeBack.AnchorPoint = Vector2.new(0.5, 1)
gaugeBack.Position = UDim2.new(0.5, 0, 0.86, 0)
gaugeBack.Size = UDim2.fromOffset(260, 18)
gaugeBack.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
gaugeBack.BackgroundTransparency = 0.25
gaugeBack.BorderSizePixel = 0
gaugeBack.Visible = false
gaugeBack.Parent = gui
local gaugeFill = Instance.new("Frame")
gaugeFill.Name = "Fill"
gaugeFill.Size = UDim2.fromScale(0, 1)
gaugeFill.BackgroundColor3 = Color3.fromRGB(90, 180, 220)
gaugeFill.BorderSizePixel = 0
gaugeFill.Parent = gaugeBack
function M.setGauge(visible, fraction)
	gaugeBack.Visible = visible
	if fraction ~= nil then
		gaugeFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	end
end

-- projection → header (tracks last balance for payout deltas)
local lastBalance = nil
function M.applyProjection(proj)
	if proj == nil then
		return
	end
	if proj.balance ~= nil then
		if lastBalance ~= nil and proj.balance > lastBalance then
			M.toast("+$" .. tostring(proj.balance - lastBalance), Color3.fromRGB(150, 230, 140))
		end
		cashLabel.Text = "$ " .. tostring(proj.balance)
		lastBalance = proj.balance
	end
	tierLabel.Text = string.format("EHT %s · EFT %s", tostring(proj.eht), tostring(proj.eft))
end
function M.balance()
	return lastBalance
end

-- styled-button factory (controllers own their input logic)
function M.button(opts)
	local b = Instance.new("TextButton")
	b.Name = opts.name or "Button"
	b.AnchorPoint = opts.anchor or Vector2.new(1, 1)
	b.Position = opts.position
	b.Size = opts.size or UDim2.fromOffset(120, 48)
	b.BackgroundColor3 = opts.color or Color3.fromRGB(40, 60, 50)
	b.BackgroundTransparency = 0.1
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = opts.textSize or 18
	b.TextColor3 = Color3.fromRGB(240, 240, 230)
	b.Text = opts.text or ""
	b.Parent = opts.parent or gui
	return b
end

return M
```

- [ ] **Step 2: Syntax sanity + green gate**

Run: `luau-analyze client/Hud.luau 2>&1 | grep -i "syntaxerror" || echo "no syntax errors"`
Expected: `no syntax errors`.
Run: `./run-tests.sh` → `ALL GREEN ✓`.

- [ ] **Step 3: Commit**

```bash
git add client/Hud.luau
git commit -m "feat(s1): client Hud singleton (header/crosshair/toast/gauge/buttons)"
```

---

### Task 4: `client/FireController.client.luau`

**Files:** Create `client/FireController.client.luau`

**Interfaces:**
- Consumes: `Net.fire` (`:FireServer(origin, direction)`, replies `("hit", targetId, dmg)` / `("kill", targetId, projection)`), `Hud.applyProjection`, `Hud.toast`, `Hud.button`.

- [ ] **Step 1: Create the LocalScript**

```lua
--!nonstrict
-- STUDIO-ONLY. Aim-and-render fire terminal. Sends AIM ONLY — the server raycasts from the character, finds
-- the target, and recomputes damage; this script never does hit detection or claims a payout. Aim = the
-- camera's screen-center (crosshair) ray; we ALSO send the real camera-ray origin (the server currently
-- ignores it, but sending it keeps the future "raycast-from-camera, bound the origin near the character" fix
-- forward-compatible). Renders the server's ("hit"|"kill", …) reply.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Net = require(script.Parent:WaitForChild("Net"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local FIRE_COOLDOWN = 0.15 -- client-side anti-spam only; the server enforces the authoritative fire rate
local lastFire = 0

local function aimAndFire()
	local cam = workspace.CurrentCamera
	local char = player.Character
	if cam == nil or char == nil or char.PrimaryPart == nil then
		return
	end
	local now = os.clock()
	if now - lastFire < FIRE_COOLDOWN then
		return
	end
	lastFire = now
	local vp = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	Net.fire:FireServer(ray.Origin, ray.Direction.Unit)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return -- a tap/click consumed by the HUD (e.g. a shop button) is not a shot
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		aimAndFire()
	end
end)

-- a dedicated on-screen FIRE button for touch (right edge, above the thumbstick area)
local fireBtn = Hud.button({
	name = "FireButton", text = "FIRE",
	position = UDim2.new(1, -20, 1, -150), size = UDim2.fromOffset(120, 56),
	color = Color3.fromRGB(120, 60, 55),
})
fireBtn.Activated:Connect(aimAndFire)

Net.fire.OnClientEvent:Connect(function(kind, targetId, extra)
	if kind == "kill" then
		Hud.applyProjection(extra) -- extra = projection (carries the new balance → payout-delta toast)
		Hud.toast("Down!", Color3.fromRGB(150, 230, 140))
	elseif kind == "hit" then
		Hud.toast("hit " .. tostring(extra), Color3.fromRGB(230, 220, 140)) -- extra = per-shot damage
	end
end)
```

- [ ] **Step 2: Syntax sanity + green gate**

Run: `luau-analyze client/FireController.client.luau 2>&1 | grep -i "syntaxerror" || echo "no syntax errors"` → `no syntax errors`.
Run: `./run-tests.sh` → `ALL GREEN ✓`.

- [ ] **Step 3: Commit**

```bash
git add client/FireController.client.luau
git commit -m "feat(s1): FireController (crosshair aim, render hit/kill)"
```

---

### Task 5: `client/FishingController.client.luau`

**Files:** Create `client/FishingController.client.luau`

**Interfaces:**
- Consumes: `Net.cast` (`:FireServer("cast")` → `("bite", fishId)`; `:FireServer("fight", E)` → `("fightProgress", fishId, accumulated)` / `("landed", fishId, projection)`), `Hud.button`, `Hud.setGauge`, `Hud.applyProjection`, `Hud.toast`.

- [ ] **Step 1: Create the LocalScript**

```lua
--!nonstrict
-- STUDIO-ONLY. Cast-and-reel fishing terminal. "Cast" asks the server for a bite; on a bite, holding "Reel"
-- sends fight ticks (effort E∈[0,1]) until the server says "landed". The server owns stamina/landing; this
-- script sends effort + renders the gauge + the catch. The gauge is COSMETIC for S1 (the client isn't told
-- the target stamina), so it animates on the server's fightProgress; the authoritative resolve is "landed".
local Net = require(script.Parent:WaitForChild("Net"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local STATE = { idle = "idle", waiting = "waiting", fighting = "fighting" }
local state = STATE.idle
local reeling = false
local progressTicks = 0
local castToken = 0

local castBtn = Hud.button({
	name = "CastButton", text = "CAST",
	position = UDim2.new(1, -150, 1, -150), size = UDim2.fromOffset(120, 56),
	color = Color3.fromRGB(55, 90, 120),
})
local reelBtn = Hud.button({
	name = "ReelButton", text = "REEL (hold)",
	position = UDim2.new(1, -150, 1, -150), size = UDim2.fromOffset(120, 56),
	color = Color3.fromRGB(60, 110, 90), textSize = 15,
})
reelBtn.Visible = false

castBtn.Activated:Connect(function()
	if state ~= STATE.idle then
		return
	end
	state = STATE.waiting
	castToken += 1
	local mine = castToken
	Net.cast:FireServer("cast")
	Hud.toast("Casting…", Color3.fromRGB(150, 200, 230))
	task.delay(4, function()
		if state == STATE.waiting and castToken == mine then
			state = STATE.idle
			Hud.toast("No bite — cast again", Color3.fromRGB(220, 200, 140))
		end
	end)
end)

-- hold-to-reel: MouseButton1Down/Up fire for both mouse and touch on a GUI button
reelBtn.MouseButton1Down:Connect(function()
	reeling = true
end)
reelBtn.MouseButton1Up:Connect(function()
	reeling = false
end)

local function fightLoop()
	progressTicks = 0
	while state == STATE.fighting do
		Net.cast:FireServer("fight", reeling and 1 or 0)
		task.wait(0.15)
	end
end

Net.cast.OnClientEvent:Connect(function(kind, fishId, extra)
	if kind == "bite" then
		state = STATE.fighting
		reeling = false
		castBtn.Visible = false
		reelBtn.Visible = true
		Hud.setGauge(true, 0)
		Hud.toast("Bite! Hold REEL", Color3.fromRGB(150, 200, 230))
		task.spawn(fightLoop)
	elseif kind == "fightProgress" then
		progressTicks += 1
		Hud.setGauge(true, math.clamp(progressTicks / 8, 0, 0.95)) -- cosmetic; true max is server-side
	elseif kind == "landed" then
		state = STATE.idle
		reeling = false
		reelBtn.Visible = false
		castBtn.Visible = true
		Hud.setGauge(false)
		Hud.applyProjection(extra) -- extra = projection (payout delta)
		Hud.toast("Landed!", Color3.fromRGB(150, 230, 140))
	end
end)
```

- [ ] **Step 2: Syntax sanity + green gate**

Run: `luau-analyze client/FishingController.client.luau 2>&1 | grep -i "syntaxerror" || echo "no syntax errors"` → `no syntax errors`.
Run: `./run-tests.sh` → `ALL GREEN ✓`.

- [ ] **Step 3: Commit**

```bash
git add client/FishingController.client.luau
git commit -m "feat(s1): FishingController (cast/hold-reel fight, render landed)"
```

---

### Task 6: `client/ShopController.client.luau`

**Files:** Create `client/ShopController.client.luau`

**Interfaces:**
- Consumes: `Net.shop` (`:FireServer("open", vendor)` / `("buy", itemId, vendor)` / `("equip", instanceId, vendor)` / `("upgrade", instanceId, vendor)`; replies `("listing", vendor, listing, projection)` / `("result", op, ok, reason)`), `Hud.gui`, `Hud.applyProjection`, `Hud.toast`. Attaches `ProximityPrompt`s to `workspace.BayouShell_Placeholder` `Outfitter_Anchor`/`TackleShop_Anchor` + `workspace.Lodge_Placeholder` `Outfitter`/`TackleShop`.

- [ ] **Step 1: Create the LocalScript**

```lua
--!nonstrict
-- STUDIO-ONLY. The Outfitter / Tackle Shop terminal. Attaches ProximityPrompts to the vendor parts the server
-- builds (Bayou shell anchors + Lodge fixtures), opens a minimal buy/equip/upgrade panel from the server's
-- listing, and routes the player's choice through ShopRequest. The client asserts NOTHING — it shows the
-- server's prices/ownership and sends an itemId/instanceId; the server validates + debits.
local Net = require(script.Parent:WaitForChild("Net"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local VENDORS = { Outfitter = true, TackleShop = true }
local currentBalance = nil

-- the panel
local panel = Instance.new("Frame")
panel.Name = "ShopPanel"
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

local function rowLabel(parent, text, width, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(0, width, 1, 0)
	l.Position = UDim2.fromOffset(8, 0)
	l.Font = Enum.Font.GothamMedium
	l.TextSize = size or 15
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = Color3.fromRGB(235, 235, 220)
	l.Text = text
	l.Parent = parent
	return l
end

local function rowButton(parent, text, enabled, cb)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -6, 0.5, 0)
	b.Size = UDim2.fromOffset(104, 30)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.BackgroundColor3 = enabled and Color3.fromRGB(50, 90, 70) or Color3.fromRGB(60, 60, 60)
	b.TextColor3 = Color3.fromRGB(240, 240, 230)
	b.AutoButtonColor = enabled
	b.Text = text
	b.Parent = parent
	if enabled then
		b.Activated:Connect(cb)
	end
	return b
end

local function render(vendor, listing, projection)
	if projection ~= nil and projection.balance ~= nil then
		currentBalance = projection.balance
	end
	clearRows()
	local title = rowLabel(row(34), vendor .. "   $ " .. tostring(currentBalance or "—"), 400, 20)
	title.Font = Enum.Font.GothamBold

	rowLabel(row(20), "For sale", 400).TextColor3 = Color3.fromRGB(170, 200, 160)
	for _, it in listing.forSale do
		local r = row(36)
		rowLabel(r, string.format("%s (T%d) — $%d", it.name, it.tier, it.price), 270)
		if it.owned then
			rowButton(r, "owned", false, nil)
		else
			local canAfford = currentBalance ~= nil and currentBalance >= it.price
			rowButton(r, canAfford and "BUY" or "need $", canAfford, function()
				Net.shop:FireServer("buy", it.itemId, vendor)
			end)
		end
	end

	rowLabel(row(20), "Your gear", 400).TextColor3 = Color3.fromRGB(170, 200, 160)
	for _, c in listing.owned do
		local r = row(36)
		local tag = c.equipped and "  [equipped]" or ""
		rowLabel(r, string.format("%s (T%d) Lv%d%s", c.name, c.tier, c.intraLevel, tag), 250)
		if not c.equipped then
			rowButton(r, "EQUIP", true, function()
				Net.shop:FireServer("equip", c.instanceId, vendor)
			end)
		elseif c.intraLevel < 2 then
			rowButton(r, "UPGRADE", true, function()
				Net.shop:FireServer("upgrade", c.instanceId, vendor)
			end)
		end
	end

	rowButton(row(40), "CLOSE", true, function()
		panel.Visible = false
	end)
	panel.Visible = true
end

Net.shop.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "listing" then
		Hud.applyProjection(c) -- c = projection
		render(a, b, c) -- a = vendor, b = listing, c = projection
	elseif kind == "result" then
		-- a = op, b = ok, c = reason
		if b then
			Hud.toast(tostring(a) .. " ok", Color3.fromRGB(150, 230, 140)) -- a fresh "listing" follows + re-renders
		else
			Hud.toast(tostring(a) .. " failed: " .. tostring(c), Color3.fromRGB(230, 150, 140))
		end
	end
end)

-- attach proximity prompts to the server-built vendor anchors + Lodge fixtures
local function attachPrompt(part, vendor)
	if part:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "Open " .. vendor
	p.ObjectText = vendor
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 12
	p.Parent = part
	p.Triggered:Connect(function()
		Net.shop:FireServer("open", vendor)
	end)
end

local function vendorFromName(name)
	local base = (string.gsub(name, "_Anchor$", "")) -- "Outfitter_Anchor"→"Outfitter"; "TackleShop"→"TackleShop"
	if VENDORS[base] then
		return base
	end
	return nil
end

local function scan(container)
	if container == nil then
		return
	end
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then
			local v = vendorFromName(d.Name)
			if v ~= nil then
				attachPrompt(d, v)
			end
		end
	end
end

task.spawn(function()
	scan(workspace:WaitForChild("BayouShell_Placeholder", 30))
	scan(workspace:WaitForChild("Lodge_Placeholder", 30))
end)
```

- [ ] **Step 2: Syntax sanity + green gate**

Run: `luau-analyze client/ShopController.client.luau 2>&1 | grep -i "syntaxerror" || echo "no syntax errors"` → `no syntax errors`.
Run: `./run-tests.sh` → `ALL GREEN ✓`.

- [ ] **Step 3: Commit**

```bash
git add client/ShopController.client.luau
git commit -m "feat(s1): ShopController (vendor prompts + buy/equip/upgrade panel)"
```

---

### Task 7: `client/TravelController.client.luau` (minimal)

**Files:** Create `client/TravelController.client.luau`

**Interfaces:**
- Consumes: `Net.travel` (`:FireServer("openMap")` → `("map", pins, passport)`; `:FireServer("travel", destId)` → `("traveling", destId, …)` / `("denied", destId, reason)`), `Hud.gui`, `Hud.toast`. All destinations are clickable; the **server gate** (`DestinationService.travelTo`) decides — the client doesn't need to know unlock state.

- [ ] **Step 1: Create the LocalScript**

```lua
--!nonstrict
-- STUDIO-ONLY. Minimal fast-travel terminal (off the S1 milestone critical path — included for completeness).
-- Prompts on the travel signpost / Lodge travel desk open the world map; the server enforces the gate
-- (DestinationService.travelTo) and executes the within-place pivot. This script lists destinations and sends
-- the travel intent; it does NOT re-derive unlock state — a locked target is rejected server-side ("denied").
local Net = require(script.Parent:WaitForChild("Net"))
local Hud = require(script.Parent:WaitForChild("Hud"))

local panel = Instance.new("Frame")
panel.Name = "TravelPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(320, 320)
panel.BackgroundColor3 = Color3.fromRGB(22, 26, 30)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = Hud.gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = panel

local function clear()
	for _, ch in panel:GetChildren() do
		if not ch:IsA("UIListLayout") then
			ch:Destroy()
		end
	end
end

local function button(text, color, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -12, 0, 40)
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 16
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.fromRGB(240, 240, 230)
	b.Text = text
	b.Parent = panel
	b.Activated:Connect(cb)
	return b
end

local function renderMap(pins)
	clear()
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -12, 0, 32)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(235, 235, 220)
	title.Text = "World Map"
	title.Parent = panel
	for destId in pins do
		button(destId, Color3.fromRGB(50, 80, 70), function()
			Net.travel:FireServer("travel", destId)
		end)
	end
	button("CLOSE", Color3.fromRGB(70, 50, 50), function()
		panel.Visible = false
	end)
	panel.Visible = true
end

Net.travel.OnClientEvent:Connect(function(kind, a, b)
	if kind == "map" then
		renderMap(a) -- a = pins ({ [destId] = Pin })
	elseif kind == "traveling" then
		panel.Visible = false
		Hud.toast("Traveling to " .. tostring(a), Color3.fromRGB(150, 200, 230))
	elseif kind == "denied" then
		Hud.toast("Travel denied: " .. tostring(b), Color3.fromRGB(230, 150, 140))
	end
end)

local function attachPrompt(part)
	if part == nil or part:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local p = Instance.new("ProximityPrompt")
	p.ActionText = "World Map"
	p.ObjectText = "Travel"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = 12
	p.Parent = part
	p.Triggered:Connect(function()
		Net.travel:FireServer("openMap")
	end)
end

task.spawn(function()
	local bayou = workspace:WaitForChild("BayouShell_Placeholder", 30)
	if bayou then
		attachPrompt(bayou:FindFirstChild("TravelSignpost_Anchor"))
	end
	local lodge = workspace:WaitForChild("Lodge_Placeholder", 30)
	if lodge then
		attachPrompt(lodge:FindFirstChild("TravelDesk_WorldMap"))
	end
end)
```

- [ ] **Step 2: Syntax sanity + green gate**

Run: `luau-analyze client/TravelController.client.luau 2>&1 | grep -i "syntaxerror" || echo "no syntax errors"` → `no syntax errors`.
Run: `./run-tests.sh` → `ALL GREEN ✓`.

- [ ] **Step 3: Commit**

```bash
git add client/TravelController.client.luau
git commit -m "feat(s1): TravelController (minimal world-map terminal)"
```

---

### Task 8: Suite verification + adversarial review + README note

**Files:**
- Verify only (no new source); optionally Modify `README.md` (add an S1 client-layer note to the Studio playtest section).

- [ ] **Step 1: Full green gate + build artifact check**

Run: `./run-tests.sh`
Expected: `ALL GREEN ✓`.
Run: `rojo build default.project.json --output /tmp/wildworld.rbxlx && echo OK`
Expected: `OK` (the place packages with `StarterPlayerScripts` holding `Net`, `Hud`, the four controllers + `CharacterController`).

- [ ] **Step 2: Confirm `StarterPlayerScripts` mapping in the built place**

Run: `rojo build default.project.json --output /tmp/wildworld.rbxlx 2>&1; ls -la client/`
Expected: all six client files present; rojo build clean. (A deeper check of the instance tree is the playtest.)

- [ ] **Step 3: Adversarial review (workflow)**

Run the adversarial-review Workflow (see the session's verification task): each new file + the `ShopRequest` block read against the §2 contract; hunt the buy→equip→fire chain, projection-delta rendering, ProximityPrompt attach-timing, the Hud module-cache singleton, the fishing fight-tick lifecycle, nil guards, and "client asserts nothing." Fix any findings and re-run Step 1.

- [ ] **Step 4: README playtest note (optional, recommended)**

Add a short S1 entry to README's Studio playtest section documenting: the new `ShopRequest` wire (buy→equip→upgrade), the six client files, and the deferred playtest items (loop run-through, payout bands, persistence-on-rejoin, aim-parallax feel, geometry aesthetics).

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "chore(s1): suite verification + README playtest note for the client layer"
```

---

## Self-Review

**1. Spec coverage:** §3 server glue → Task 1. §4 Net/Hud/Fire/Fishing/Shop/Travel → Tasks 2–7. §5 milestone flow → exercised by Tasks 1+4+6 (shoot/buy/equip/shoot) and 5 (catch). §6 decisions: D1 aim+camera-origin → Task 4 (`ray.Origin` sent, server ignores); D2 untyped surface → Global Constraints note; D3 Hud singleton → Task 3 + Global Constraints; D4 cosmetic gauge → Task 5; D5 projection on open+mutation → Task 1. §7 verification → per-task green gate + Task 8. No spec section is unimplemented.

**2. Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to Task N". Every code step contains the full file or the exact insertion. ✓

**3. Type/name consistency:** `ShopRequest` replies `("listing", vendor, listing, projection)` + `("result", op, ok, reason)` — produced in Task 1, consumed identically in Task 6. `listing.forSale[]`/`owned[]` field names match Task 1's builder. `Net.{fire,cast,shop,travel}` (Task 2) used consistently in Tasks 4–7. `Hud.{applyProjection,toast,setGauge,button,gui,balance}` (Task 3) used consistently. `buy {itemId}` / `equip|upgrade {commodityInstanceId}` payloads match §2.2. ✓
