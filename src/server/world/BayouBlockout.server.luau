--!nonstrict
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- STUDIO-ONLY (NOT headless-analyzed). Builds the navigable Bayou PLACEHOLDER shell from the Shells
-- config at server start, and wires login → arrival. References the Roblox runtime (Workspace / Lighting /
-- Instance / Vector3 / DataStore) — verified by the Studio playtest checklist (README), not by CI.
-- This is BLOCKOUT geometry; finished art (cypress models, water shader, textures, sound) is the
-- separate Phase-3 art pass. The LAYOUT is data-driven (read from the validated Shells config), so it is
-- correct-by-construction even though the look is placeholder.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")

-- headless modules (require-by-string via .luaurc; resolved at runtime by Rojo + Roblox require-by-string)
local Shells = require("@src/config/Shells")
local Catalog = require("@src/config/Catalog")
local ArrivalService = require("@src/server/ArrivalService")
local SessionService = require("@src/server/SessionService")
local Adapters = require("@src/server/RobloxAdapters")

local BAYOU = "bayou"
local shell = Shells.byDestination[BAYOU]
local movement = Shells.movement

local function vec(p)
	return Vector3.new(p.x, p.y, p.z)
end

local world = Instance.new("Folder")
world.Name = "BayouShell_Placeholder"
world.Parent = workspace

local function part(name, size, position, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = true
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or world
	return p
end

-- ground baseplate (swamp green), sized to the compact footprint
part("Ground", Vector3.new(420, 2, 520), Vector3.new(0, -1, 100), Color3.fromRGB(74, 92, 56))

-- §2.3 zones: one labeled, navigable marker pad per named region
local zonesFolder = Instance.new("Folder")
zonesFolder.Name = "Zones"
zonesFolder.Parent = world
for id, z in shell.zones do
	local isWater = z.kind == "fishing" or z.kind == "rareSite"
	local pad = part(z.name, Vector3.new(z.size.x, 0.4, z.size.z), vec(z.center) + Vector3.new(0, 0.2, 0), isWater and Color3.fromRGB(55, 85, 105) or Color3.fromRGB(96, 116, 64), zonesFolder)
	pad.Material = isWater and Enum.Material.Glass or Enum.Material.Grass -- flat water plane = cheap shader (§2.5)
	pad.Transparency = isWater and 0.3 or 0
	pad:SetAttribute("zoneId", id)
	pad:SetAttribute("zoneKind", z.kind)
end

-- §2.2 landmarks: the Old Cypress beacon (tall, visible from most of the map) + the Landing
part("OldCypress_Beacon", Vector3.new(8, 80, 8), vec(shell.landmarks.the_old_cypress.anchor) + Vector3.new(0, 40, 0), Color3.fromRGB(60, 50, 40))
part("TheLanding_Shack", Vector3.new(24, 12, 18), vec(shell.landmarks.the_landing.anchor) + Vector3.new(0, 6, 0), Color3.fromRGB(110, 90, 70))
-- vendor outpost + co-located travel signpost (non-functional anchors — transactions/map are Steps 6/9)
part("Outfitter_Anchor", Vector3.new(4, 8, 4), vec(shell.vendorOutpostAnchor) + Vector3.new(-8, 4, 0), Color3.fromRGB(150, 120, 90))
part("TackleShop_Anchor", Vector3.new(4, 8, 4), vec(shell.vendorOutpostAnchor) + Vector3.new(8, 4, 0), Color3.fromRGB(90, 120, 150))
part("TravelSignpost_Anchor", Vector3.new(2, 10, 2), vec(shell.travelSignpostAnchor) + Vector3.new(0, 5, 6), Color3.fromRGB(120, 100, 60))

-- ambiance placeholders, scattered in their home zones (instanced low-cost "alive" signal, §2.5).
-- ambianceOnly = shootable-but-zero-reward; the zero-reward ENFORCEMENT is Step 4 — here it is only look.
local ambFolder = Instance.new("Folder")
ambFolder.Name = "Ambiance"
ambFolder.Parent = world
for speciesId, zoneId in shell.ambiancePlacements do
	local z = shell.zones[zoneId]
	local species = Catalog.creatures[speciesId]
	for i = 1, 4 do
		local a = part(species.name, Vector3.new(1.5, 1.5, 1.5), vec(z.center) + Vector3.new(i * 7 - 14, 1, i * 5 - 12), Color3.fromRGB(220, 220, 200), ambFolder)
		a:SetAttribute("ambianceOnly", true)
		a:SetAttribute("speciesId", speciesId)
	end
end
-- dragonflies: pure VFX (no species), a flocked "alive" cue near the water
local dragonflies = Instance.new("ParticleEmitter")
local dfHost = part("Dragonflies_VFX", Vector3.new(2, 2, 2), vec(shell.zones.channel_banks.center) + Vector3.new(0, 3, 0), Color3.fromRGB(60, 90, 110), ambFolder)
dfHost.Transparency = 1
dragonflies.Rate = 8
dragonflies.Lifetime = NumberRange.new(3, 6)
dragonflies.Speed = NumberRange.new(2, 5)
dragonflies.Parent = dfHost

-- arrival SpawnLocation at the arrival clearing, FACING the Sunny Levee (§2.6.1)
local arrival = ArrivalService.resolveArrival(nil, Shells, Catalog)
local clearing = shell.zones[arrival.zoneId]
local levee = shell.zones.sunny_levee.center
local spawn = Instance.new("SpawnLocation")
spawn.Name = "BayouArrival"
spawn.Anchored = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Color = Color3.fromRGB(120, 130, 90)
spawn.CFrame = CFrame.lookAt(vec(clearing.center) + Vector3.new(0, 0.5, 0), Vector3.new(levee.x, 0.5, levee.z))
spawn.Parent = world

-- §2.5 swamp fog = the view-distance cull (atmospheric AND the far-LOD budget)
Lighting.FogStart = shell.render.fogStart
Lighting.FogEnd = shell.render.fogEnd
Lighting.FogColor = Color3.fromRGB(150, 160, 130)

-- arrival flow: login (lock + load via Step 2) then apply the movement tunables on spawn. The
-- SpawnLocation places the character at the arrival clearing. DataStore needs Studio API Services on.
local svc = SessionService.new({
	store = Adapters.dataStore(DataStoreService:GetDataStore("WildWorld_Profiles_v1")),
	clock = Adapters.clock(),
	config = Catalog,
	serverId = (game.JobId ~= "" and game.JobId) or "studio",
})

Players.PlayerAdded:Connect(function(plr)
	pcall(function()
		SessionService.login(svc, plr.UserId)
	end) -- best-effort; the shell is walkable even if persistence is off
	plr.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		hum.WalkSpeed = movement.walkSpeed
		hum.JumpPower = movement.jumpPower
	end)
end)
Players.PlayerRemoving:Connect(function(plr)
	pcall(function()
		SessionService.logout(svc, plr.UserId)
	end)
end)
game:BindToClose(function()
	for _, plr in Players:GetPlayers() do
		pcall(function()
			SessionService.logout(svc, plr.UserId)
		end)
	end
end)

print("[WildWorld] Bayou placeholder shell built:", arrival.destinationId, "->", arrival.zoneId)
