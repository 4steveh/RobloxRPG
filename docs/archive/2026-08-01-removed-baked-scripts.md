# Removed: two hand-baked place scripts (2026-08-01)

These two `Script`s lived directly in `ServerScriptService`, OUTSIDE the Rojo-managed
`ServerScriptService.WildWorld` tree, and were therefore invisible to the repository. They were
baked into `WildWorld.rbxl` by hand during the previous overhaul, and both headers state the
reason: *"MCP-baked deploy (the Rojo plugin was disconnected, so the WorldArt source did not
sync)"*.

That condition no longer holds — Rojo is connected and `src/server/world/WorldArt.server.luau`
syncs — so both were **removed from the place**. They are archived here because they were the only
copy in existence.

## Why they had to go, not just sit there

`WildWorldArtRuntime` is the OLD mesh-based creature upgrade. It races the new procedural one on
the *same* `model:SetAttribute("artUpgraded", true)` flag, so whichever listener fired first
silently suppressed the other. Worse, it only mapped **17 of 26** creature ids, and it mapped them
onto `ReplicatedStorage.WildWorldArt` Creator-Store meshes that `InsertService:LoadAsset` cannot
re-authorise — so a fresh place could never reproduce it. Leaving it in place meant the new
per-species silhouettes might simply never appear.

`WildWorldArtSuppress` duplicates `WorldArtBuilder.suppressPlaceholders` exactly. Harmless but
redundant, and a second writer to the same parts.

`ReplicatedStorage.WildWorldArt` (the imported Creator-Store mesh templates, ~6,700 descendants)
was deliberately **left alone**: nothing in the new pipeline reads it, but it cannot be
re-downloaded and destroying it would be irreversible.

---

## WildWorldArtRuntime (Script)

```lua
--!nonstrict
-- WildWorld ART RUNTIME — MCP-baked deploy (the Rojo plugin was disconnected, so the WorldArt source did not
-- sync). Upgrades spawned BOX creatures to their meshes IN PLACE + a cosmetic idle loop. Standalone (NOT in
-- the Rojo-mapped tree) to avoid a sync conflict with src/server/world/WorldArt.server.luau (same logic).
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local MAP={bayou_american_alligator="Alligator",bayou_white_alligator="Alligator",bayou_swamp_rabbit="SwampRabbit",bayou_nutria="SwampRabbit",bayou_wood_duck="WoodDuck",bayou_leucistic_wood_duck="WoodDuck",bayou_great_egret="Heron",bayou_painted_turtle="Turtle",bayou_songbird="WoodDuck",appalachia_whitetail_deer="Deer",appalachia_eastern_cottontail="SwampRabbit",alaska_bull_moose="Moose",alaska_caribou="Deer",alaska_grizzly_bear="Grizzly",alaska_glacier_grizzly="Grizzly",alaska_arctic_hare="SwampRabbit",alaska_sitka_deer="Deer"}
local PALE={bayou_white_alligator=true,bayou_leucistic_wood_duck=true,alaska_glacier_grizzly=true}
local animated={}
local function creatures() local r=RS:FindFirstChild("WildWorldArt"); return r and r:FindFirstChild("Creatures") end
local function upgrade(model)
  if typeof(model)~="Instance" or not model:IsA("Model") or model:GetAttribute("artUpgraded") then return end
  local cid=model:GetAttribute("creatureId"); local pp=model.PrimaryPart; local cf=creatures()
  if not (cid and pp and cf) then return end
  local tpl=cf:FindFirstChild(MAP[cid] or ""); if not tpl then return end
  model:SetAttribute("artUpgraded",true)
  for _,d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then d.Transparency=1 end end
  local root=Instance.new("Part"); root.Name="ArtVisualRoot"; root.Size=Vector3.new(.2,.2,.2); root.Transparency=1; root.CanCollide=false; root.CanQuery=false; root.Massless=true; root.CFrame=pp.CFrame; root.Parent=model
  local motor=Instance.new("Motor6D"); motor.Part0=pp; motor.Part1=root; motor.Parent=pp
  local v=tpl:Clone(); v.Name="ArtVisual"
  local _,bs=model:GetBoundingBox(); local _,ts=v:GetBoundingBox()
  pcall(function() v:ScaleTo(v:GetScale()*math.max(bs.X,bs.Z)/math.max(ts.X,ts.Z,.1)) end)
  v:PivotTo(root.CFrame)
  for _,d in ipairs(v:GetDescendants()) do if d:IsA("BasePart") then d.Anchored=false; d.CanCollide=false; d.CanQuery=false; d.Massless=true; local w=Instance.new("Weld"); w.Part0=root; w.Part1=d; w.C0=root.CFrame:ToObjectSpace(d.CFrame); w.Parent=d end end
  if PALE[cid] then for _,d in ipairs(v:GetDescendants()) do if d:IsA("MeshPart") then d.TextureID=""; d.Color=Color3.fromRGB(228,224,210) end end end
  v.Parent=model
  animated[model]={motor=motor,phase=math.random()*6.28}
end
task.spawn(function()
  for _,fn in ipairs({"HuntingTargets","FishingBites"}) do
    local f=workspace:WaitForChild(fn,30)
    if f then
      for _,m in ipairs(f:GetChildren()) do task.spawn(function() pcall(upgrade,m) end) end
      f.ChildAdded:Connect(function(m) task.defer(function() pcall(upgrade,m) end) end)
      f.ChildRemoved:Connect(function(m) animated[m]=nil end)
    end
  end
end)
RunService.Heartbeat:Connect(function()
  local t=os.clock()
  for model,a in pairs(animated) do
    if a.motor and a.motor.Parent then a.motor.C0=CFrame.new(0,math.sin(t*1.6+a.phase)*.12,0)*CFrame.Angles(0,math.sin(t*.9+a.phase)*.038,0) else animated[model]=nil end
  end
end)
print("[WildWorldArtRuntime] baked deploy active — creature upgrade + cosmetic loop")
```

## WildWorldArtSuppress (Script)

```lua
--!nonstrict
-- WildWorld ART SUPPRESS (MCP-baked; Rojo plugin disconnected). Hides WorldServer's RUNTIME placeholder boxes
-- (flat ground, zone pads, beacon cubes, vendor anchors, lodge fixture cubes) so the baked art shows cleanly.
-- Keeps SpawnLocations + a walkable ground floor; leaves fixtures present (transparent) for gameplay clicks.
local function hide(f)
  for _,d in ipairs(f:GetDescendants()) do
    if d:IsA("BasePart") and not d:IsA("SpawnLocation") then
      d.Transparency=1
      if d.Name~="Ground" then d.CanCollide=false end
    end
  end
end
task.spawn(function()
  for _,name in ipairs({"BayouShell_Placeholder","AppalachiaShell_Placeholder","AlaskaShell_Placeholder","Lodge_Placeholder"}) do
    local f=workspace:WaitForChild(name,30)
    if f then
      hide(f)
      f.DescendantAdded:Connect(function(d)
        if d:IsA("BasePart") and not d:IsA("SpawnLocation") then d.Transparency=1; if d.Name~="Ground" then d.CanCollide=false end end
      end)
    end
  end
end)
print("[WildWorldArtSuppress] active — WorldServer placeholder boxes hidden")
```
