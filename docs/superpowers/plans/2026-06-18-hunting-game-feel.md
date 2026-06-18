# Hunting Game-Feel Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the hunting loop *play* like a game in Studio — distinct procedural animals with name/health labels, a visible rifle, aim highlight, and full shot/hit/kill feedback — wired to the existing fire events, with zero change to headless logic.

**Architecture:** Server-side procedural creature building extends `WorldServer.server.luau` inline (the established convention — it already owns the spawners). Client feel lives in new focused `client/` modules driven from the existing `FireController`. No new RemoteEvents; no change to `src/config`, `src/logic`, or the headless `src/server` substrate.

**Tech Stack:** Roblox Luau (Studio runtime), procedural `Instance` construction, `TweenService`, `Highlight`, `BillboardGui`, attribute replication, `rbxasset://` sounds. Rojo live-sync (`localhost:34872`) pushes disk edits into the open place.

## Global Constraints

- **No headless change.** Do NOT edit `src/config/**`, `src/logic/**`, or any non-`*.server.luau` file under `src/server/**`. `./run-tests.sh` must report **ALL GREEN** after every task.
- **Studio-only code location:** server feel → inline in `src/server/world/WorldServer.server.luau`; client feel → new files under `client/` (synced to `StarterPlayerScripts`). Never add a Roblox-touching un-suffixed ModuleScript under `src/` (breaks the analyzer gate).
- **No Roblox CDN.** Everything procedural. Sounds use `rbxasset://` engine ids only and MUST degrade to silent on load failure (wrap in `pcall` / load-timeout).
- **Verification is a Studio playtest** via the Roblox Studio MCP (`start_stop_play`, `execute_luau`, `screen_capture`), not a Luau unit test. After a disk edit, Rojo syncs to the **Edit** DataModel; stop+start Play to re-clone before verifying.
- **Existing seams (do not rewrite):** `spawnTarget(creatureId, zoneId)` @ `WorldServer.server.luau:508`; `despawnTarget(model, respawnAfter)` @ `:528`; fire handler hit branch @ `:654`; `zoneOfHit` @ `:584`; client `FireController.client.luau` fire path + `("hit"|"kill", targetId, extra)` handler @ `:49`.

---

### Task 1: Procedural creature models (server)

Replace the single 3×3×4 box in `spawnTarget` with distinct multi-part silhouettes carrying `hitZone` tags + health attributes. This also activates the existing headshot mechanic (the fire handler already reads `hitZone`).

**Files:**
- Modify: `src/server/world/WorldServer.server.luau` (add `CREATURE_ARCHETYPES` + `buildCreatureModel` near the other builders ~`:297`; call it from `spawnTarget` ~`:508-526`).

**Interfaces:**
- Produces: `buildCreatureModel(creatureId: string, originCFrame: CFrame) -> Model` — a `Model` parented by the caller, `PrimaryPart` = torso, with attributes `creatureId`, `targetId`, `maxHealth`, `currentHealth`, and per-part `hitZone` ("vital" on head, "body" on torso, "limb" on legs/tail/wing). Consumed by `spawnTarget`.
- Consumes: `Catalog.creatures[creatureId]` (`.health`, `.name`), already required in WorldServer.

- [ ] **Step 1: Add the archetype table + builder.** Insert near the other geometry helpers. Bayou creatures → archetype + scale + color. Representative code (tune sizes/colours live):

```lua
-- ── STUDIO FEEL: procedural creature silhouettes (replaces the single-box target) ──────────────────
-- Each creature reads as a distinct animal: a body + a VITAL head + archetype limbs. hitZone tags make
-- the existing headshot multiplier (Combat.zoneMultiplier, via zoneOfHit) live. All parts anchored,
-- non-colliding; PrimaryPart = torso. maxHealth/currentHealth attrs drive the client health bar.
local CREATURE_ARCHETYPES = {
	bayou_american_alligator = { kind = "reptile", scale = 1.6, color = Color3.fromRGB(70, 92, 64) },
	bayou_swamp_rabbit       = { kind = "small_mammal", scale = 0.6, color = Color3.fromRGB(140, 120, 96) },
	bayou_nutria             = { kind = "small_mammal", scale = 0.9, color = Color3.fromRGB(110, 86, 64) },
	bayou_wood_duck          = { kind = "bird", scale = 0.7, color = Color3.fromRGB(96, 120, 150) },
}
local DEFAULT_ARCHETYPE = { kind = "small_mammal", scale = 1.0, color = Color3.fromRGB(120, 110, 100) }

local function fxPart(name, size, color, hitZone, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = true -- the fire raycast must hit it
	p.Material = Enum.Material.SmoothPlastic
	if hitZone then p:SetAttribute("hitZone", hitZone) end
	p.Parent = parent
	return p
end

-- archetype body plans: return torso, and weld the rest at offsets (CFrame relative to torso center)
local function buildBody(model, arch)
	local s, c = arch.scale, arch.color
	local headC = c:Lerp(Color3.new(1,1,1), 0.12)
	if arch.kind == "reptile" then
		local torso = fxPart("Torso", Vector3.new(2.2*s, 1.1*s, 5.0*s), c, "body", model)
		fxPart("Head", Vector3.new(1.2*s, 1.0*s, 1.8*s), headC, "vital", model).CFrame = torso.CFrame * CFrame.new(0, 0.1*s, -3.0*s)
		fxPart("Tail", Vector3.new(1.0*s, 0.7*s, 3.0*s), c, "limb", model).CFrame = torso.CFrame * CFrame.new(0, 0, 3.4*s)
		for _, dx in ipairs({ -1.2*s, 1.2*s }) do for _, dz in ipairs({ -1.6*s, 1.6*s }) do
			fxPart("Leg", Vector3.new(0.5*s, 1.0*s, 0.5*s), c, "limb", model).CFrame = torso.CFrame * CFrame.new(dx, -0.9*s, dz)
		end end
		return torso
	elseif arch.kind == "bird" then
		local torso = fxPart("Torso", Vector3.new(1.4*s, 1.4*s, 2.2*s), c, "body", model)
		fxPart("Head", Vector3.new(0.9*s, 0.9*s, 0.9*s), headC, "vital", model).CFrame = torso.CFrame * CFrame.new(0, 0.9*s, -1.2*s)
		for _, dx in ipairs({ -1.0*s, 1.0*s }) do
			fxPart("Wing", Vector3.new(0.3*s, 0.9*s, 1.6*s), c, "limb", model).CFrame = torso.CFrame * CFrame.new(dx, 0.2*s, 0)
		end
		return torso
	else -- small_mammal
		local torso = fxPart("Torso", Vector3.new(1.6*s, 1.5*s, 2.6*s), c, "body", model)
		fxPart("Head", Vector3.new(1.1*s, 1.1*s, 1.1*s), headC, "vital", model).CFrame = torso.CFrame * CFrame.new(0, 0.7*s, -1.5*s)
		fxPart("Ear", Vector3.new(0.3*s, 1.1*s, 0.3*s), headC, "limb", model).CFrame = torso.CFrame * CFrame.new(0, 1.6*s, -1.5*s)
		return torso
	end
end

local function buildCreatureModel(creatureId, originCFrame)
	local creature = Catalog.creatures[creatureId]
	local arch = CREATURE_ARCHETYPES[creatureId] or DEFAULT_ARCHETYPE
	local model = Instance.new("Model")
	model.Name = creature.name
	local torso = buildBody(model, arch)
	model.PrimaryPart = torso
	model:PivotTo(originCFrame + Vector3.new(0, 1.5 * arch.scale, 0))
	model:SetAttribute("creatureId", creatureId)
	model:SetAttribute("targetId", creatureId)
	model:SetAttribute("maxHealth", creature.health)
	model:SetAttribute("currentHealth", creature.health)
	return model
end
```

- [ ] **Step 2: Call it from `spawnTarget`.** In `spawnTarget` (`:508`), replace the inline single-`Part`/`Model` construction with `buildCreatureModel`, preserving the existing position logic and the `liveTargets[model] = {...}` registration + `model.Parent = targetsFolder`. Keep `liveTargets` state fields exactly as they are (`creatureId, health, accumulated, zoneId`).

- [ ] **Step 3: Sync + verify in Studio.** Stop Play if running; let Rojo sync; Start Play. Run via MCP `execute_luau` (Server):

```lua
local ht = workspace.HuntingTargets
local out = {}
for _, m in ipairs(ht:GetChildren()) do
	local parts, zones = 0, {}
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then parts += 1; local z=d:GetAttribute("hitZone"); if z then zones[z]=(zones[z] or 0)+1 end end end
	table.insert(out, m.Name.." parts="..parts.." vital="..tostring(zones.vital).." maxHP="..tostring(m:GetAttribute("maxHealth")))
end
return table.concat(out, "\n")
```
Expected: each creature has **>1 part**, exactly **1 vital** part, and a `maxHealth` attribute. Then `screen_capture` — creatures should read as **distinct shapes** (gator long, rabbit tiny, duck small).

- [ ] **Step 4: Confirm headless gate untouched.** Run `./run-tests.sh`. Expected: **ALL GREEN** (no `src/` headless file changed).

- [ ] **Step 5: Commit.**
```bash
git add src/server/world/WorldServer.server.luau
git commit -m "feat(s2-feel): procedural creature silhouettes with hitZones + health attrs"
```

---

### Task 2: Creature name + health labels (client)

A `BillboardGui` over each creature: name + health bar bound to the `currentHealth`/`maxHealth` attributes from Task 1.

**Files:**
- Create: `client/CreatureLabels.client.luau`

**Interfaces:**
- Consumes: `workspace.HuntingTargets` creatures with `maxHealth`/`currentHealth` attributes (Task 1).
- Produces: nothing other modules consume (self-contained visual).

- [ ] **Step 1: Write the label controller.**

```lua
--!nonstrict
-- STUDIO-ONLY. Floating name + health bar over each huntable creature (reads the server's maxHealth/
-- currentHealth attributes; updates live on hit). Self-contained; attaches/detaches with HuntingTargets.
local Players = game:GetService("Players")
local cam = workspace.CurrentCamera

local function attach(model)
	if not model:IsA("Model") or model:GetAttribute("maxHealth") == nil then return end
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not anchor then return end
	local bg = Instance.new("BillboardGui")
	bg.Name = "CreatureLabel"
	bg.Size = UDim2.fromOffset(140, 34)
	bg.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	bg.AlwaysOnTop = true
	bg.MaxDistance = 220
	bg.Adornee = anchor
	bg.Parent = anchor
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1; name.Size = UDim2.new(1,0,0,18); name.Font = Enum.Font.GothamMedium
	name.TextSize = 14; name.TextColor3 = Color3.fromRGB(235,235,220); name.TextStrokeTransparency = 0.4
	name.Text = model.Name; name.Parent = bg
	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.new(0,0,0,20); barBg.Size = UDim2.new(1,0,0,8)
	barBg.BackgroundColor3 = Color3.fromRGB(30,30,30); barBg.BorderSizePixel = 0; barBg.Parent = bg
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(200,80,70); fill.BorderSizePixel = 0; fill.Size = UDim2.fromScale(1,1); fill.Parent = barBg
	local function refresh()
		local maxH = model:GetAttribute("maxHealth") or 1
		local cur = model:GetAttribute("currentHealth") or maxH
		fill.Size = UDim2.fromScale(math.clamp(cur / maxH, 0, 1), 1)
	end
	refresh()
	model:GetAttributeChangedSignal("currentHealth"):Connect(refresh)
end

local function scan()
	local ht = workspace:WaitForChild("HuntingTargets", 30)
	if not ht then return end
	for _, m in ipairs(ht:GetChildren()) do attach(m) end
	ht.ChildAdded:Connect(attach)
end
task.spawn(scan)
```

- [ ] **Step 2: Sync + verify.** Stop/Start Play. `screen_capture` — a **name + red health bar** floats over each creature. Confirm no client errors via `execute_luau` (Client) scanning `LogService:GetLogHistory()` for non-asset errors (expect 0).

- [ ] **Step 3: Confirm gate.** `./run-tests.sh` → ALL GREEN (no `src/` change).

- [ ] **Step 4: Commit.**
```bash
git add client/CreatureLabels.client.luau
git commit -m "feat(s2-feel): creature name + health-bar billboards"
```

---

### Task 3: Health-on-hit + server death animation (server)

Make hits visibly drain the Task-2 health bar, and replace the instant despawn with a death animation everyone sees.

**Files:**
- Modify: `src/server/world/WorldServer.server.luau` (hit branch `:654`; `despawnTarget` `:528`).

**Interfaces:**
- Consumes: `liveTargets[model]` (`.accumulated`, `.creatureId`), `Catalog.creatures[id].health`.
- Produces: live updates to the `currentHealth` attribute (Task 2 reads it).

- [ ] **Step 1: Write `currentHealth` on each hit.** In the non-lethal hit branch (after `state.accumulated += shotDmg`, `:654`):
```lua
		state.accumulated += shotDmg
		model:SetAttribute("currentHealth", math.max(0, Catalog.creatures[state.creatureId].health - state.accumulated))
		fireRequest:FireClient(plr, "hit", rayHitTargetId, shotDmg)
```

- [ ] **Step 2: Add a death animation to `despawnTarget`.** Before the existing destroy/respawn, tip + sink + fade the model, then destroy. Representative:
```lua
local TweenService = game:GetService("TweenService")
-- inside despawnTarget, replacing the immediate model:Destroy():
local function playDeath(model)
	model:SetAttribute("currentHealth", 0)
	local cf = model:GetPivot()
	local goalCF = cf * CFrame.Angles(math.rad(80), 0, 0) + Vector3.new(0, -2, 0)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end
	end
	-- pivot tween via a CFrameValue driver (anchored parts): step the model pivot
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.6 do
			local a = (os.clock() - t0) / 0.6
			model:PivotTo(cf:Lerp(goalCF, a))
			task.wait()
		end
		model:Destroy()
	end)
end
```
Call `playDeath(model)` where `despawnTarget` currently destroys the model (keep the respawn scheduling intact — schedule respawn immediately, animate+destroy the corpse in parallel).

- [ ] **Step 3: Verify live.** Stop/Start Play. Via `execute_luau` (Server), fire the loop on a creature programmatically OR drive a real shot, then read `currentHealth`:
```lua
-- pick a creature, simulate accumulation by reading after a client fire; or directly:
local m = workspace.HuntingTargets:GetChildren()[1]
return "before="..tostring(m:GetAttribute("currentHealth")).."/"..tostring(m:GetAttribute("maxHealth"))
```
Then from the Client datamodel, fire at it (`ReplicatedStorage.FireRequest:FireServer(origin, dir)`) aimed at the creature and confirm `currentHealth` drops and, on the killing blow, the model **tips + fades + disappears** (screen_capture mid-death).

- [ ] **Step 4: Gate.** `./run-tests.sh` → ALL GREEN.

- [ ] **Step 5: Commit.**
```bash
git add src/server/world/WorldServer.server.luau
git commit -m "feat(s2-feel): health-bar drain on hit + server-driven death animation"
```

---

### Task 4: Visible held rifle (client)

A procedural rifle welded to the player's hand.

**Files:**
- Create: `client/ViewModel.client.luau`

**Interfaces:**
- Produces: a `Model` named `HeldRifle` under the character, with a `BarrelTip` `Attachment` at the muzzle (consumed by Task 5 for muzzle/tracer origin).

- [ ] **Step 1: Build + weld the rifle on character spawn.**
```lua
--!nonstrict
-- STUDIO-ONLY. A procedural rifle welded to the player's right hand. Exposes a BarrelTip attachment at
-- the muzzle for muzzle-flash/tracer origin (Task 5). Rebuilds on respawn.
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function build(char)
	local hand = char:WaitForChild("RightHand", 10) or char:WaitForChild("Right Arm", 5)
	if not hand then return end
	local model = Instance.new("Model"); model.Name = "HeldRifle"
	local function p(name, size, color, cf)
		local x = Instance.new("Part"); x.Name=name; x.Size=size; x.Color=color; x.Anchored=false
		x.CanCollide=false; x.Massless=true; x.Material=Enum.Material.SmoothPlastic; x.Parent=model; return x
	end
	local stock = p("Stock", Vector3.new(0.25,0.5,1.2), Color3.fromRGB(70,50,35))
	local barrel = p("Barrel", Vector3.new(0.18,0.18,2.4), Color3.fromRGB(40,40,45))
	model.PrimaryPart = barrel
	-- weld parts to the hand at a held offset (tune the CFrame live)
	local base = hand.CFrame * CFrame.new(0, -0.2, -1.2) * CFrame.Angles(math.rad(-90),0,0)
	barrel.CFrame = base
	stock.CFrame = base * CFrame.new(0, 0, 0.9)
	for _, part in ipairs(model:GetChildren()) do
		local w = Instance.new("Weld"); w.Part0 = hand; w.Part1 = part
		w.C0 = hand.CFrame:ToObjectSpace(part.CFrame); w.Parent = part
	end
	local tip = Instance.new("Attachment"); tip.Name = "BarrelTip"; tip.Position = Vector3.new(0,0,-1.3); tip.Parent = barrel
	model.Parent = char
end

local function onChar(char) task.defer(build, char) end
if player.Character then onChar(player.Character) end
player.CharacterAdded:Connect(onChar)
```

- [ ] **Step 2: Verify.** Stop/Start Play. `screen_capture` — a **rifle is visible** in the player's hands. `execute_luau` (Client): confirm `player.Character.HeldRifle.Barrel.BarrelTip` exists.

- [ ] **Step 3: Gate.** `./run-tests.sh` → ALL GREEN.

- [ ] **Step 4: Commit.**
```bash
git add client/ViewModel.client.luau
git commit -m "feat(s2-feel): procedural held rifle welded to the hand"
```

---

### Task 5: Aim highlight + shot FX + FireController wiring (client)

Highlight the creature under the crosshair; on fire show muzzle flash / tracer / recoil; on hit show a hit-marker; on kill show a floating `+$`.

**Files:**
- Create: `client/HuntingFeel.luau` (a ModuleScript — NOT `.client` — so `FireController` can `require` it; a `.client` LocalScript cannot be required).
- Modify: `client/FireController.client.luau` (call into HuntingFeel on fire + on `"hit"`/`"kill"`).

**Interfaces:**
- Consumes: `player.Character.HeldRifle.Barrel.BarrelTip` (Task 4); `workspace.HuntingTargets` (Task 1); the fire payload reply `("hit"|"kill", targetId, extra)`.
- Produces: a module-level table required by FireController: `local Feel = require(...HuntingFeel)` exposing `Feel.onFire(aimRay)`, `Feel.onHit()`, `Feel.onKill(projection)`. **Note:** since these are `*.client.luau` scripts (not ModuleScripts), expose the API via a shared `ModuleScript` `client/HuntingFeelApi.luau` that both require, OR move the feel logic into a ModuleScript `client/HuntingFeel.luau` (no `.client`) required by `FireController` — pick the ModuleScript form so FireController can call it directly.

- [ ] **Step 1: Create `client/HuntingFeel.luau` (ModuleScript).** Owns aim-highlight loop + FX functions. Representative:
```lua
--!nonstrict
-- STUDIO-ONLY ModuleScript. Hunting game-feel: aim highlight + shot/hit/kill FX. Required by FireController.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local M = {}

local highlight = Instance.new("Highlight")
highlight.FillTransparency = 0.7; highlight.OutlineColor = Color3.fromRGB(255,220,120); highlight.Enabled = false
highlight.Parent = workspace

-- aim-highlight: each frame raycast from screen center; highlight a HuntingTargets creature if hit
RunService.RenderStepped:Connect(function()
	local vp = cam.ViewportSize
	local ray = cam:ViewportPointToRay(vp.X/2, vp.Y/2)
	local params = RaycastParams.new(); params.FilterDescendantsInstances = { player.Character }; params.FilterType = Enum.RaycastFilterType.Exclude
	local r = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local model = r and r.Instance:FindFirstAncestor("HuntingTargets") and r.Instance:FindFirstAncestorOfClass("Model")
	if model and model.Parent and model.Parent.Name == "HuntingTargets" then
		highlight.Adornee = model; highlight.Enabled = true
	else
		highlight.Enabled = false
	end
end)

local function barrelTip()
	local c = player.Character
	local b = c and c:FindFirstChild("HeldRifle") and c.HeldRifle:FindFirstChild("Barrel")
	return b and b:FindFirstChild("BarrelTip")
end

function M.onFire(aimRay)
	local tip = barrelTip()
	if tip then
		local flash = Instance.new("PointLight"); flash.Brightness = 6; flash.Range = 10; flash.Color = Color3.fromRGB(255,200,120); flash.Parent = tip.Parent
		TweenService:Create(flash, TweenInfo.new(0.12), { Brightness = 0 }):Play()
		game:GetService("Debris"):AddItem(flash, 0.2)
		-- tracer
		local beam = Instance.new("Part"); beam.Anchored=true; beam.CanCollide=false; beam.Material=Enum.Material.Neon
		beam.Color=Color3.fromRGB(255,230,160); beam.Size=Vector3.new(0.1,0.1,(aimRay.Origin - tip.WorldPosition).Magnitude)
		beam.CFrame = CFrame.lookAt(tip.WorldPosition, aimRay.Origin) * CFrame.new(0,0,-beam.Size.Z/2)
		beam.Parent = workspace; TweenService:Create(beam, TweenInfo.new(0.15), { Transparency = 1 }):Play()
		game:GetService("Debris"):AddItem(beam, 0.2)
	end
	-- recoil: brief camera kick
	local k = CFrame.Angles(math.rad(1.2), 0, 0)
	cam.CFrame = cam.CFrame * k
end

function M.onHit()
	-- crosshair / hit marker flash handled by Hud if available; minimal: a quick highlight pulse
	highlight.OutlineColor = Color3.fromRGB(255,90,80)
	task.delay(0.1, function() highlight.OutlineColor = Color3.fromRGB(255,220,120) end)
end

function M.onKill(projection)
	-- floating +$ at the highlighted creature (or screen center)
	local adornee = highlight.Adornee
	local pos = adornee and adornee:GetPivot().Position or (cam.CFrame * CFrame.new(0,0,-12)).Position
	local part = Instance.new("Part"); part.Anchored=true; part.Transparency=1; part.CanCollide=false; part.Size=Vector3.one
	part.CFrame = CFrame.new(pos + Vector3.new(0,3,0)); part.Parent = workspace
	local bg = Instance.new("BillboardGui"); bg.Size = UDim2.fromOffset(120,40); bg.AlwaysOnTop=true; bg.Adornee=part; bg.Parent=part
	local lbl = Instance.new("TextLabel"); lbl.BackgroundTransparency=1; lbl.Size=UDim2.fromScale(1,1); lbl.Font=Enum.Font.GothamBold
	lbl.TextSize=22; lbl.TextColor3=Color3.fromRGB(150,230,140); lbl.Text="Down!"; lbl.Parent=bg
	TweenService:Create(part, TweenInfo.new(1.0), { CFrame = part.CFrame + Vector3.new(0,3,0) }):Play()
	TweenService:Create(lbl, TweenInfo.new(1.0), { TextTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(part, 1.1)
end

return M
```

- [ ] **Step 2: Wire FireController.** In `client/FireController.client.luau`: `local Feel = require(script.Parent:WaitForChild("HuntingFeel"))`. In `aimAndFire`, after building `ray`, call `Feel.onFire(ray)`. In the `Net.fire.OnClientEvent` handler: on `"kill"` call `Feel.onKill(extra)`; on `"hit"` call `Feel.onHit()`. Keep the existing toasts.

- [ ] **Step 3: Verify.** Stop/Start Play. `screen_capture` while aiming at a creature → it's **highlighted**. Drive a fire (`execute_luau` Client `ReplicatedStorage.FireRequest:FireServer(ray.Origin, ray.Direction)`) and screen_capture → **muzzle flash + tracer** visible; on a kill, a **"Down!" float** rises. Confirm 0 non-asset client errors.

- [ ] **Step 4: Gate.** `./run-tests.sh` → ALL GREEN.

- [ ] **Step 5: Commit.**
```bash
git add client/HuntingFeel.luau client/FireController.client.luau
git commit -m "feat(s2-feel): aim highlight + muzzle/tracer/recoil + hit/kill FX, wired to FireController"
```

---

### Task 6: Sound (client, best-effort)

Gunshot / impact / kill / cash via engine-bundled `rbxasset://` ids; silent on failure.

**Files:**
- Modify: `client/HuntingFeel.luau` (add a `playSound` helper + calls in `onFire`/`onHit`/`onKill`).

**Interfaces:** none external.

- [ ] **Step 1: Add a guarded sound helper.**
```lua
local SoundService = game:GetService("SoundService")
local SOUNDS = { -- rbxasset:// engine-bundled ids (no CDN); adjust if any fail to load
	fire = "rbxasset://sounds/impact_water.mp3", hit = "rbxasset://sounds/impact_generic.mp3",
	kill = "rbxasset://sounds/impact_generic_large_water.mp3", cash = "rbxasset://sounds/electronicpingshort.wav",
}
local function playSound(key)
	local id = SOUNDS[key]; if not id then return end
	local ok, s = pcall(function() local snd = Instance.new("Sound"); snd.SoundId = id; snd.Volume = 0.5; return snd end)
	if not ok or not s then return end
	s.Parent = SoundService
	s.Ended:Connect(function() s:Destroy() end)
	pcall(function() s:Play() end)
	game:GetService("Debris"):AddItem(s, 4)
end
```
Call `playSound("fire")` in `onFire`, `playSound("hit")` in `onHit`, `playSound("kill")` + `playSound("cash")` in `onKill`.

- [ ] **Step 2: Verify (best-effort).** Stop/Start Play, fire, and check `execute_luau` (Client) `LogService` for any **non**-`could not fetch` sound errors (expect none — failures degrade silently). Confirm firing still works regardless of whether sound is audible.

- [ ] **Step 3: Gate.** `./run-tests.sh` → ALL GREEN.

- [ ] **Step 4: Commit.**
```bash
git add client/HuntingFeel.luau
git commit -m "feat(s2-feel): best-effort rbxasset gunshot/impact/kill/cash sounds (silent on CDN failure)"
```

---

## Final playtest (the spec's checklist)

Run all in one Play session and screen_capture each:
- [ ] Distinct animals visible, each with a name + health label.
- [ ] Rifle visible in hand.
- [ ] Crosshair on a creature highlights it.
- [ ] Fire → muzzle flash + tracer + recoil (+ sound or silent).
- [ ] Non-lethal hit → health bar drops + hit-marker.
- [ ] Headshot (crosshair on head) drops the bar more than a body shot.
- [ ] Kill → death animation (tip/sink/fade) + "Down!"/`+$` float + HUD balance up.
- [ ] `./run-tests.sh` ALL GREEN.

## Self-review notes

- **Spec coverage:** every spec component maps to a task (1→creatures, 2→labels, 3→health/death, 4→rifle, 5→highlight/FX/wiring, 6→sound). ✓
- **Type consistency:** `buildCreatureModel(creatureId, originCFrame)`, attributes `maxHealth`/`currentHealth`/`hitZone`, `HeldRifle.Barrel.BarrelTip`, `HuntingFeel.onFire/onHit/onKill` — used consistently across tasks. ✓
- **Decision locked:** Task 5 uses a **ModuleScript `client/HuntingFeel.luau`** (not `.client`) so `FireController` can `require` it (a `.client` LocalScript cannot be required). CreatureLabels/ViewModel stay `.client.luau` (self-running).
