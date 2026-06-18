--!nonstrict
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- STUDIO-ONLY (NOT headless-analyzed). THE ONE RUNNABLE SERVER (Step 8 bootstrap consolidation). Before
-- Step 8 each per-step slice (BayouBlockout / HuntingService / FishingService) stood up its OWN
-- SessionService + gauntlet registry "self-contained for the slice" — they CANNOT coexist (multiple login
-- locks on one profile). This file is the single login owner: ONE SessionService, ONE shared gauntlet
-- registry into which hunting, fishing, the shop, the daily, and the salvage/display/decor handlers all
-- register; it builds the Bayou world + the Lodge interior + the service fixtures, runs both spawners +
-- both flows, and places the player via resolveArrival (Lodge for a returning player, Bayou for a first-
-- time player). The headless SessionService LOGIC is unchanged (Step 2 verified) — this is wiring only.
-- BAR: exactly ONE login lock per profile (Studio checklist) — verify no double-lock in a running session.
--
-- The Bayou world build, the hunting spawner/fire flow, and the fishing spawner/cast flow are the proven
-- glue from the deleted per-step slices, reassembled here on the shared substrate.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")

-- headless modules (require-by-string via .luaurc; Rojo + Roblox resolve at runtime)
local Catalog = require("@src/config/Catalog")
local Shells = require("@src/config/Shells")
local Spawning = require("@src/config/Spawning")
local Spawner = require("@src/logic/Spawner")
local Combat = require("@src/logic/Combat")
local Fishing = require("@src/logic/Fishing")
local Onboarding = require("@src/logic/Onboarding")
local Gauntlet = require("@src/server/authority/Gauntlet")
local FireHandler = require("@src/server/combat/FireHandler")
local CatchHandler = require("@src/server/fishing/CatchHandler")
local EquipHandler = require("@src/server/authority/handlers/EquipHandler")
local ShopHandler = require("@src/server/shop/ShopHandler")
local VendorHandler = require("@src/server/shop/VendorHandler")
local ClaimDailyHandler = require("@src/server/daily/ClaimDailyHandler")
local SalvageHandler = require("@src/server/lodge/SalvageHandler")
local DisplayHandler = require("@src/server/lodge/DisplayHandler")
local LodgeShopHandler = require("@src/server/lodge/LodgeShopHandler")
local WorldMapHandler = require("@src/server/progression/WorldMapHandler")
local TradeService = require("@src/server/trading/TradeService")
local Progression = require("@src/logic/Progression")
local DestinationService = require("@src/server/DestinationService")
local SessionService = require("@src/server/SessionService")
local ArrivalService = require("@src/server/ArrivalService")
local Adapters = require("@src/server/RobloxAdapters")

local BAYOU = "bayou"
local shell = Shells.byDestination[BAYOU]
local movement = Shells.movement
local huntingSpawn = Spawning.byDestination[BAYOU].hunting
local fishingSpawn = Spawning.byDestination[BAYOU].fishing

-- ── STEP-10: world spatial offsets (hub-and-spoke — all three worlds coexist in one place at offsets).
-- The Bayou offset is (0,0,0) so the existing Bayou login placement and all Bayou coord math is unaffected.
-- Used by buildWorldGeometry (geometry) AND the fast-travel pivot (3.3) so they stay in sync.
local worldOffsets = {
	bayou      = Vector3.new(0,    0, 0),
	appalachia = Vector3.new(2000, 0, 0),
	alaska     = Vector3.new(4000, 0, 0),
}

local function vec(p)
	return Vector3.new(p.x, p.y, p.z)
end

-- ── THE ONE SHARED SUBSTRATE: one telemetry sink, one idGen, one SessionService, one gauntlet registry ──
local idGen = Adapters.idGenerator(HttpService)
local telemetry = Adapters.telemetry(function(metric, value)
	-- TODO(ops): forward to AnalyticsService. Step-8 metrics to surface here + in the handlers: the §9 canary
	-- `evergreen-sink share of endgame Cash` (economy.evergreenSink:slot/decor vs total endgame Cash), first-
	-- trophy-display rate / time-to-first-mount (lodge.mount), slot-expansion purchase curve, take-down-to-
	-- trade rate (lodge.takeDown), Lodge-visit / in-Lodge session time (the co-op-hub signal — Studio).
	--
	-- STEP-10 (3.4) telemetry — WIRED (these incr() calls fire at their event points below):
	--   travel.fast_travel:<destinationId>  — fired in the "travel" action branch on result.ok (3.3)
	--
	-- STEP-10 (3.4) telemetry — TODO (need conquest/co-op events; deeper Studio work):
	--   destination.time_to_conquer:<destinationId>  — per-Destination time from first-arrival to Tier apex
	--                                                   kill; needs conquest event + timestamp store.
	--   coop.apex_attempt:<destinationId>  — co-op grizzly/halibut attempt start; needs party-formation event.
	--   coop.apex_success:<destinationId>  — co-op apex kill confirmed; needs Gauntlet party payload.
	--   gate.t2_to_t4_dropoff:<destinationId>  — players who unlock T2 but do not reach T4; needs periodic
	--                                             profile scan (idle player check) or session-end hook.
	--   economy.destination_routine_income:<destinationId>  — per-session Cash earned in a Destination vs the
	--                                                          EHT/EFT band; needs session-end flush with totals.
end)
local sessionService = SessionService.new({
	store = Adapters.dataStore(DataStoreService:GetDataStore("WildWorld_Profiles_v1")),
	clock = Adapters.clock(),
	config = Catalog,
	serverId = (game.JobId ~= "" and game.JobId) or "studio",
	telemetry = telemetry,
})

-- ONE shared registry — every system's handler registers here (no second SessionService, no second registry).
local registry = Gauntlet.new()
Gauntlet.register(registry, FireHandler.new({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, CatchHandler.new({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, EquipHandler)
Gauntlet.register(registry, ShopHandler.buyHandler({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, ShopHandler.upgradeHandler({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, VendorHandler.buyHandler({ idGen = idGen, telemetry = telemetry })) -- Step 11: BoatDealer + Kennel & Stable
Gauntlet.register(registry, ClaimDailyHandler.new({ telemetry = telemetry }))
Gauntlet.register(registry, SalvageHandler.new({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, DisplayHandler.mountHandler({ telemetry = telemetry }))
Gauntlet.register(registry, DisplayHandler.takeDownHandler({ telemetry = telemetry }))
Gauntlet.register(registry, LodgeShopHandler.buySlotHandler({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, LodgeShopHandler.buyDecorHandler({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, LodgeShopHandler.placeDecorHandler({ idGen = idGen, telemetry = telemetry }))
Gauntlet.register(registry, WorldMapHandler.new({ telemetry = telemetry }))

-- Step 12: the Trading Post — a SPECIAL two-session path (NOT a gauntlet handler; the gauntlet is single-
-- profile). It reaches both traders' profiles via the one SessionService and runs the atomic swap (TradeSwap)
-- over PairTransaction. Client trade intents (request/accept/setOffer/confirm/cancel) route to tradeService;
-- a tick drives timeoutTick + the post-settle tryCommit; PlayerRemoving fires onDisconnect. Owner keys are
-- the player's UserId as a string; tonumber recovers the SessionService playerId.
local tradeService = TradeService.new({
	config = Catalog,
	idGen = idGen,
	telemetry = telemetry,
	getProfile = function(key: string)
		local s = sessionService.sessions[tonumber(key) :: number]
		return if s ~= nil then s.profile else nil
	end,
	saveProfile = function(key: string)
		return SessionService.saveNow(sessionService, tonumber(key) :: number)
	end,
})
local _ = tradeService -- the RemoteEvent routing + the settle/timeout tick are the Studio surface (playtest-pending)

-- shared gauntlet deps for a given player (the write-through + dirty-flag wiring used by every handler)
local function gauntletDeps(plr)
	return {
		config = Catalog,
		now = os.time(),
		saveFn = function()
			return SessionService.saveNow(sessionService, plr.UserId)
		end,
		markDirty = function()
			SessionService.markDirty(sessionService, plr.UserId)
		end,
		telemetry = telemetry,
	}
end

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- THE BAYOU WORLD (the proven BayouBlockout glue — placeholder shell from the validated Shells config)
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
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

part("Ground", Vector3.new(420, 2, 520), Vector3.new(0, -1, 100), Color3.fromRGB(74, 92, 56))

local zonesFolder = Instance.new("Folder")
zonesFolder.Name = "Zones"
zonesFolder.Parent = world
for id, z in shell.zones do
	local isWater = z.kind == "fishing" or z.kind == "rareSite"
	local pad = part(z.name, Vector3.new(z.size.x, 0.4, z.size.z), vec(z.center) + Vector3.new(0, 0.2, 0), isWater and Color3.fromRGB(55, 85, 105) or Color3.fromRGB(96, 116, 64), zonesFolder)
	pad.Material = isWater and Enum.Material.Glass or Enum.Material.Grass
	pad.Transparency = isWater and 0.3 or 0
	pad:SetAttribute("zoneId", id)
	pad:SetAttribute("zoneKind", z.kind)
end

part("OldCypress_Beacon", Vector3.new(8, 80, 8), vec(shell.landmarks.the_old_cypress.anchor) + Vector3.new(0, 40, 0), Color3.fromRGB(60, 50, 40))
part("TheLanding_Shack", Vector3.new(24, 12, 18), vec(shell.landmarks.the_landing.anchor) + Vector3.new(0, 6, 0), Color3.fromRGB(110, 90, 70))
part("Outfitter_Anchor", Vector3.new(4, 8, 4), vec(shell.vendorOutpostAnchor) + Vector3.new(-8, 4, 0), Color3.fromRGB(150, 120, 90))
part("TackleShop_Anchor", Vector3.new(4, 8, 4), vec(shell.vendorOutpostAnchor) + Vector3.new(8, 4, 0), Color3.fromRGB(90, 120, 150))
part("TravelSignpost_Anchor", Vector3.new(2, 10, 2), vec(shell.travelSignpostAnchor) + Vector3.new(0, 5, 6), Color3.fromRGB(120, 100, 60))

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

local arrivalClearing = shell.zones[shell.arrivalZoneId]
local levee = shell.zones.sunny_levee.center
local bayouSpawn = Instance.new("SpawnLocation")
bayouSpawn.Name = "BayouArrival"
bayouSpawn.Anchored = true
bayouSpawn.Enabled = false -- placement is driven by resolveArrival below, not by auto-spawn
bayouSpawn.Size = Vector3.new(12, 1, 12)
bayouSpawn.Color = Color3.fromRGB(120, 130, 90)
bayouSpawn.CFrame = CFrame.lookAt(vec(arrivalClearing.center) + Vector3.new(0, 0.5, 0), Vector3.new(levee.x, 0.5, levee.z))
bayouSpawn.Parent = world

Lighting.FogStart = shell.render.fogStart
Lighting.FogEnd = shell.render.fogEnd
Lighting.FogColor = Color3.fromRGB(150, 160, 130)

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- STEP-10 (3.1): buildWorldGeometry — reusable low-poly placeholder builder for non-Bayou worlds.
-- The Bayou world build above is LEFT INLINE (the proven playtest baseline — additive only; we do NOT
-- refactor it to go through this helper so equivalence is guaranteed). This helper is called ONLY for
-- Appalachia and Alaska. Each world is placed at a spatial originOffset so they don't overlap.
--
-- Fog is global (Lighting), so per-world fog is NOT set here (the Bayou's fog already wires Lighting
-- above). A later step can swap fog on world-transition. Alaska's coastal_inlet/open_gulf zones render
-- as geometry but are visually present only; Boat-gating is enforced at the data layer (Step 11).
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local function buildWorldGeometry(destinationId, originOffset)
	local targetShell = Shells.byDestination[destinationId]
	if targetShell == nil then return end

	local folder = Instance.new("Folder")
	folder.Name = destinationId:sub(1,1):upper() .. destinationId:sub(2) .. "Shell_Placeholder"
	folder.Parent = workspace

	local function wpart(name, size, position, color, parent)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = originOffset + position
		p.Anchored = true
		p.Color = color
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = parent or folder
		return p
	end

	-- Ground pad: 500×500 centered on the world origin (low-poly placeholder per LOC §2.5).
	local groundColor = (destinationId == "appalachia") and Color3.fromRGB(62, 80, 48) or Color3.fromRGB(70, 70, 65)
	wpart("Ground", Vector3.new(500, 2, 500), Vector3.new(0, -1, 0), groundColor)

	-- Zones
	local zonesF = Instance.new("Folder")
	zonesF.Name = "Zones"
	zonesF.Parent = folder
	for zid, z in targetShell.zones do
		local isWater = z.kind == "fishing" or z.kind == "rareSite"
		-- Alaska coastal zones: rendered but walled-off visually (no enforcement here — Step 11 Boat gate).
		local zColor = isWater and Color3.fromRGB(55, 85, 105) or Color3.fromRGB(96, 116, 64)
		local zpad = wpart(z.name, Vector3.new(z.size.x, 0.4, z.size.z), Vector3.new(z.center.x, 0.2, z.center.z), zColor, zonesF)
		zpad.Material = isWater and Enum.Material.Glass or Enum.Material.Grass
		zpad.Transparency = isWater and 0.3 or 0
		zpad:SetAttribute("zoneId", zid)
		zpad:SetAttribute("zoneKind", z.kind)
		if isWater and destinationId == "alaska" and (zid == "coastal_inlet" or zid == "open_gulf") then
			-- NOTE: coastal Boat-gated sub-area. Geometry present; navigation is non-traversable until Step 11.
			zpad:SetAttribute("boatGated", true)
		end
	end

	-- Landmark beacons (isBeacon=true → tall pillar like the Bayou Old Cypress; others → small shack)
	for _, lm in targetShell.landmarks do
		local lsize = lm.isBeacon and Vector3.new(8, 80, 8) or Vector3.new(24, 12, 18)
		local lcolor = lm.isBeacon and Color3.fromRGB(60, 50, 40) or Color3.fromRGB(110, 90, 70)
		local loffset = lm.isBeacon and Vector3.new(0, 40, 0) or Vector3.new(0, 6, 0)
		wpart(lm.name .. "_Beacon", lsize, Vector3.new(lm.anchor.x, 0, lm.anchor.z) + loffset, lcolor)
	end

	-- Vendor outpost anchors
	local vo = targetShell.vendorOutpostAnchor
	wpart("Outfitter_Anchor",    Vector3.new(4, 8, 4), Vector3.new(vo.x - 8, 4, vo.z), Color3.fromRGB(150, 120, 90))
	wpart("TackleShop_Anchor",   Vector3.new(4, 8, 4), Vector3.new(vo.x + 8, 4, vo.z), Color3.fromRGB(90, 120, 150))

	-- Travel signpost
	local ts = targetShell.travelSignpostAnchor
	wpart("TravelSignpost_Anchor", Vector3.new(2, 10, 2), Vector3.new(ts.x, 5, ts.z + 6), Color3.fromRGB(120, 100, 60))

	-- Ambiance pieces (same 4-per-zone pattern as the Bayou)
	local ambF = Instance.new("Folder")
	ambF.Name = "Ambiance"
	ambF.Parent = folder
	for speciesId, zoneId in targetShell.ambiancePlacements do
		local z = targetShell.zones[zoneId]
		local species = Catalog.creatures[speciesId]
		if z ~= nil and species ~= nil then
			for i = 1, 4 do
				local a = wpart(species.name, Vector3.new(1.5, 1.5, 1.5), Vector3.new(z.center.x + i * 7 - 14, 1, z.center.z + i * 5 - 12), Color3.fromRGB(220, 220, 200), ambF)
				a:SetAttribute("ambianceOnly", true)
				a:SetAttribute("speciesId", speciesId)
			end
		end
	end

	-- Arrival spawn location
	local arrZ = targetShell.zones[targetShell.arrivalZoneId]
	if arrZ ~= nil then
		local sp = Instance.new("SpawnLocation")
		sp.Name = destinationId:sub(1,1):upper() .. destinationId:sub(2) .. "Arrival"
		sp.Anchored = true
		sp.Enabled = false -- placement driven by ArrivalService/PivotTo, not auto-spawn
		sp.Size = Vector3.new(12, 1, 12)
		sp.Color = Color3.fromRGB(120, 130, 90)
		sp.Position = originOffset + Vector3.new(arrZ.center.x, 0.5, arrZ.center.z)
		sp.Parent = folder
	end
end

-- Build Appalachia and Alaska placeholder geometry (additive — Bayou inline block above is untouched).
buildWorldGeometry("appalachia", worldOffsets.appalachia)
buildWorldGeometry("alaska",     worldOffsets.alaska)

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- THE LODGE (Step 8 — the hub interior placeholder + service fixtures). Low-poly placeholder; finished art
-- is the Phase-3 pass. PLACED service points (this doc owns the Trophy Hall; it only PLACES the others):
--   • Outfitter + Tackle Shop  → BUILT (Step 6 handlers) — look-navigable gun rack / tackle bench
--   • Trophy Hall              → BUILT (this step) — the display room (a VIEW over DISPLAYED artifacts)
--   • World Map (Travel Desk)  → Step 9 BUILT · Boat Dealer/Kennel → Step 11 BUILT · Trading Post → Step 12 BUILT (UI playtest-pending)
-- The Trophy Hall renders the player's DISPLAYED artifacts (Replication.projection.trophyHall) — rendering
-- the rarity-distinct mounts + provenance plaques is the Studio checklist. Visit/social topology is FLAGGED
-- (own-Lodge only at MVL; Tuning.lodge.visitInstancingMode).
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local lodge = Instance.new("Folder")
lodge.Name = "Lodge_Placeholder"
lodge.Parent = workspace
local lodgeAnchor = vec(Shells.lodge.anchor)
part("Lodge_Floor", Vector3.new(80, 1, 80), lodgeAnchor + Vector3.new(0, -0.5, 0), Color3.fromRGB(96, 78, 60), lodge)
local lodgeSpawn = Instance.new("SpawnLocation")
lodgeSpawn.Name = "LodgeArrival"
lodgeSpawn.Anchored = true
lodgeSpawn.Enabled = false
lodgeSpawn.Size = Vector3.new(10, 1, 10)
lodgeSpawn.Color = Color3.fromRGB(120, 100, 80)
lodgeSpawn.Position = lodgeAnchor + Vector3.new(0, 0.5, 0)
lodgeSpawn.Parent = lodge

-- the placed service fixtures (look-navigable per 00 §2 legibility; built vs stubbed labelled honestly)
local function fixture(name, offset, color, status)
	local f = part(name, Vector3.new(6, 8, 6), lodgeAnchor + offset, color, lodge)
	f:SetAttribute("service", name)
	f:SetAttribute("status", status) -- "built" | "stub" → the UI reads it as ready vs "coming soon"
	return f
end
fixture("Outfitter", Vector3.new(-30, 4, -20), Color3.fromRGB(150, 120, 90), "built")
fixture("TackleShop", Vector3.new(-30, 4, 0), Color3.fromRGB(90, 120, 150), "built")
fixture("TrophyHall", Vector3.new(0, 4, -30), Color3.fromRGB(180, 150, 70), "built")
fixture("TravelDesk_WorldMap", Vector3.new(30, 4, -20), Color3.fromRGB(120, 110, 80), "built") -- Step 9
fixture("TradingPost", Vector3.new(30, 4, 0), Color3.fromRGB(110, 130, 110), "built") -- Step 12: same-server P2P escrow swap
fixture("BoatDealer", Vector3.new(30, 4, 20), Color3.fromRGB(90, 110, 140), "built") -- Step 11: Coastal Skiff + boats (Cash sink)
fixture("KennelAndStable", Vector3.new(-30, 4, 20), Color3.fromRGB(130, 110, 90), "built") -- Step 11: mounts + dogs (Cash sinks)

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- THE HUNTING SPAWNER + FIRE FLOW (the proven HuntingService glue, on the SHARED registry)
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local targetsFolder = Instance.new("Folder")
targetsFolder.Name = "HuntingTargets"
targetsFolder.Parent = workspace
local liveTargets = {}

local function spawnTarget(creatureId, zoneId)
	local creature = Catalog.creatures[creatureId]
	local zone = shell.zones[zoneId]
	local model = Instance.new("Model")
	model.Name = creature.name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 3, 4)
	root.Anchored = true
	root.Color = creature.behavior == "aggressive" and Color3.fromRGB(120, 70, 60) or Color3.fromRGB(150, 130, 90)
	root.Position = vec(zone.center) + Vector3.new((math.random() - 0.5) * zone.size.x, 1.5, (math.random() - 0.5) * zone.size.z)
	root.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("creatureId", creatureId)
	model:SetAttribute("targetId", creatureId)
	model.Parent = targetsFolder
	liveTargets[model] = { creatureId = creatureId, health = creature.health, accumulated = 0, zoneId = zoneId }
	return model
end

local function despawnTarget(model, respawnAfter)
	local state = liveTargets[model]
	liveTargets[model] = nil
	model:Destroy()
	if state ~= nil and respawnAfter ~= nil then
		task.delay(respawnAfter, function()
			local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, state.zoneId)
			if #pool > 0 then
				spawnTarget(pool[math.random(1, #pool)], state.zoneId)
			end
		end)
	end
end

for zoneId, area in huntingSpawn.areas do
	local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, zoneId)
	if #pool > 0 then
		for _ = 1, area.maxConcurrentTargets do
			spawnTarget(pool[math.random(1, #pool)], zoneId)
		end
	end
end

local function huntWorldState()
	return { time = "dawn or dusk", weather = "fog" } -- TODO(step-13): real time/weather/season/event
end
task.spawn(function()
	while true do
		task.wait(60)
		local w = huntWorldState()
		for id, c in Catalog.creatures do
			if c.destinationId == BAYOU and c.rare ~= nil and c.spawnZones ~= nil then
				if Spawner.rareSpawnEligible(c, w) and math.random(1, c.rare.spawnRate) == 1 then
					spawnTarget(id, c.spawnZones[1])
					telemetry.incr("combat.rare_spawned:" .. id, 1)
				end
			end
		end
	end
end)

local fireRequest = Instance.new("RemoteEvent")
fireRequest.Name = "FireRequest"
fireRequest.Parent = ReplicatedStorage
local lastShotAt = {}

local function zoneOfHit(part_)
	local z = part_:GetAttribute("hitZone")
	return (z == "vital" or z == "limb") and z or "body"
end

fireRequest.OnServerEvent:Connect(function(plr, aimOrigin, aimDirection)
	local session = sessionService.sessions[plr.UserId]
	local char = plr.Character
	if session == nil or char == nil or char.PrimaryPart == nil then
		return
	end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local origin = char.PrimaryPart.Position
	local result = workspace:Raycast(origin, aimDirection.Unit * 500, params)
	local now = os.time()
	local rayHitTargetId, distance, zone, model = nil, math.huge, "body", nil
	if result ~= nil then
		model = result.Instance:FindFirstAncestorOfClass("Model")
		if model ~= nil and liveTargets[model] ~= nil then
			rayHitTargetId = model:GetAttribute("targetId")
			distance = (result.Position - origin).Magnitude
			zone = zoneOfHit(result.Instance)
		end
	end
	if rayHitTargetId == nil or model == nil then
		return
	end
	local state = liveTargets[model]
	local payload = {
		targetId = rayHitTargetId, zone = zone, distance = distance, claimedDamage = nil,
		lastShotAt = lastShotAt[plr.UserId] or 0, rayHitTargetId = rayHitTargetId, targetAlive = true,
		accumulatedDamageBefore = state.accumulated, owner = tostring(plr.UserId), partySize = 1,
	}
	local function equippedTierLevel()
		local refs = session.profile.equipped
		for _, c in session.profile.inventory.commodities do
			if c.instanceId == refs.weapon then
				local item = Catalog.equipment[c.catalogId]
				if item then
					return item.tier, Combat.gearLevelOf(c.intraLevel)
				end
			end
		end
		return 0, "entry"
	end
	local tlvl, lvl = equippedTierLevel()
	local shotDmg = Combat.shotDamage(Combat.weaponDamage(Catalog, tlvl, lvl), Combat.zoneMultiplier(Catalog, zone), Combat.rangeFalloff(Catalog, tlvl, distance))
	payload.claimedDamage = shotDmg
	if Combat.fireRateOk(Catalog, payload.lastShotAt, now, Combat.cycleTime(Catalog, tlvl)) then
		lastShotAt[plr.UserId] = now
	end
	if (state.accumulated + shotDmg) >= Catalog.creatures[state.creatureId].health then
		local deps = gauntletDeps(plr)
		deps.now = now
		local r = Gauntlet.handle(registry, { intent = "fire", playerId = plr.UserId, payload = payload }, session, deps)
		if r.ok then
			despawnTarget(model, huntingSpawn.areas[state.zoneId] and huntingSpawn.areas[state.zoneId].respawnIntervalSeconds or nil)
			fireRequest:FireClient(plr, "kill", rayHitTargetId, r.projection)
			-- TODO(Studio feel): hit-stop/impact/audio/haptics; the rare clean-kill flourish fires here when
			-- the kill minted an artifact → then the "Mount it in the Trophy Hall" auto-prompt (autoPromptOnMint
			-- on; a UI beat — the artifact stays HELD until the player taps; dismissing is a no-op).
		end
	else
		state.accumulated += shotDmg
		fireRequest:FireClient(plr, "hit", rayHitTargetId, shotDmg)
	end
end)

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- THE FISHING SPAWNER + CAST FLOW (the proven FishingService glue, on the SHARED registry)
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local bitesFolder = Instance.new("Folder")
bitesFolder.Name = "FishingBites"
bitesFolder.Parent = workspace
local liveBites = {}

local function spawnBite(fishId, zoneId)
	local fishDef = Catalog.fish[fishId]
	local zone = shell.zones[zoneId]
	local marker = Instance.new("Part")
	marker.Name = "Bite_" .. fishDef.name
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(2, 2, 2)
	marker.Anchored = true
	marker.Transparency = 0.4
	marker.Color = Color3.fromRGB(120, 180, 220)
	marker.Position = vec(zone.center) + Vector3.new((math.random() - 0.5) * zone.size.x, 0.5, (math.random() - 0.5) * zone.size.z)
	marker:SetAttribute("fishId", fishId)
	marker:SetAttribute("targetId", fishId)
	marker.Parent = bitesFolder
	liveBites[marker] = { fishId = fishId, zoneId = zoneId }
	return marker
end

local function depleteBite(marker)
	local state = liveBites[marker]
	liveBites[marker] = nil
	marker:Destroy()
	if state ~= nil then
		local area = fishingSpawn.areas[state.zoneId]
		task.delay(area and area.respawnIntervalSeconds or 30, function()
			local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, state.zoneId, "Fishing")
			if #pool > 0 then
				spawnBite(pool[math.random(1, #pool)], state.zoneId)
			end
		end)
	end
end

for zoneId, area in fishingSpawn.areas do
	local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, zoneId, "Fishing")
	if #pool > 0 then
		for _ = 1, area.maxConcurrentTargets do
			spawnBite(pool[math.random(1, #pool)], zoneId)
		end
	end
end

local function fishWorldState()
	return { time = "night", weather = "storm" } -- TODO(step-13): real time/weather/season/event
end
task.spawn(function()
	while true do
		task.wait(60)
		local w = fishWorldState()
		for id, f in Catalog.fish do
			if f.destinationId == BAYOU and f.rare ~= nil and f.spawnZones ~= nil then
				if Spawner.rareSpawnEligible(f, w) and math.random(1, f.rare.spawnRate) == 1 then
					spawnBite(id, f.spawnZones[1])
					telemetry.incr("fishing.rare_spawned:" .. id, 1)
				end
			end
		end
	end
end)

local castRequest = Instance.new("RemoteEvent")
castRequest.Name = "FishingCast"
castRequest.Parent = ReplicatedStorage
local activeFight = {}

local function equippedReel(profile)
	for _, c in profile.inventory.commodities do
		if c.instanceId == profile.equipped.reel then
			local item = Catalog.equipment[c.catalogId]
			if item then
				return item.tier, Fishing.gearLevelOf(c.intraLevel)
			end
		end
	end
	return 0, "entry"
end

castRequest.OnServerEvent:Connect(function(plr, action, arg)
	local session = sessionService.sessions[plr.UserId]
	if session == nil then
		return
	end
	if action == "fight" then
		local fight = activeFight[plr.UserId]
		if fight == nil or liveBites[fight.marker] == nil then
			return
		end
		local fishId = liveBites[fight.marker].fishId
		local fish = Catalog.fish[fishId]
		local reelTier, reelLevel = equippedReel(session.profile)
		local E = math.clamp(tonumber(arg) or 0, 0, 1)
		local drain = Fishing.reelDrainMax(Catalog, reelTier, reelLevel) * E
		fight.accumulated += drain
		if fight.accumulated >= Fishing.staminaToLand(Catalog, fish) then
			local payload = {
				targetId = fishId, biteActive = true, E = E, claimedDrain = drain,
				accumulatedStaminaBefore = fight.accumulated - drain, owner = tostring(plr.UserId), partySize = 1,
			}
			local deps = gauntletDeps(plr)
			local r = Gauntlet.handle(registry, { intent = "catch", playerId = plr.UserId, payload = payload }, session, deps)
			if r.ok then
				depleteBite(fight.marker)
				castRequest:FireClient(plr, "landed", fishId, r.projection)
				-- TODO(Studio feel): land animation, weighty haptic resolve; on a rare mint, the clean-catch
				-- flourish → the "Mount it" auto-prompt (the artifact stays HELD until tapped).
			end
			activeFight[plr.UserId] = nil
		else
			castRequest:FireClient(plr, "fightProgress", fishId, fight.accumulated)
		end
		return
	end
	if action == "cast" then
		local nearest = nil
		for marker in liveBites do
			activeFight[plr.UserId] = { marker = marker, accumulated = 0 }
			nearest = marker
			break
		end
		if nearest ~= nil then
			castRequest:FireClient(plr, "bite", liveBites[nearest].fishId)
		end
	end
end)

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- THE TRAVEL DESK → WORLD MAP + FAST-TRAVEL (Step 9 wiring)
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- Step 9: the Travel Desk → World Map + fast-travel. Opening the map fires the openWorldMap intent (completes
-- the funnel reveal beat + the unlock catch-all); a travel request is enforced by DestinationService.travelTo
-- (the gate-bypass guard — target must be in the persisted unlocked set) and, on ok, executes the teleport.
local travelRequest = Instance.new("RemoteEvent")
travelRequest.Name = "TravelRequest"
travelRequest.Parent = ReplicatedStorage

travelRequest.OnServerEvent:Connect(function(plr, action, destinationId)
	local session = sessionService.sessions[plr.UserId]
	if session == nil then
		return
	end
	if action == "openMap" then
		Gauntlet.handle(registry, { intent = "openWorldMap", playerId = plr.UserId, payload = {} }, session, gauntletDeps(plr))
		travelRequest:FireClient(plr, "map", Progression.worldMapPins(session.profile, Catalog), Progression.passportCounts(session.profile, Catalog))
		return
	end
	if action == "travel" then
		local result = DestinationService.travelTo(session.profile, destinationId)
		-- STEP-10 (3.3): the gate is already enforced by DestinationService.travelTo (Step 9 — the persisted
		-- unlocked set; travelTo can't bypass the gate). This block is the EXECUTION: resolve the destination
		-- arrival anchor via ArrivalService.resolveDestinationArrival and PivotTo the character there.
		-- All three worlds coexist in one place at their worldOffsets (hub-and-spoke MVL approach); the offset
		-- is added to the shell-local anchor so the player lands in the correct world's geometry.
		-- (Full cross-place TeleportService:Teleport is a later optimization — not needed while all worlds are
		-- in one Studio place. result.teleportTarget is passed through for future use.)
		if result.ok then
			local char = plr.Character
			local arrival = ArrivalService.resolveDestinationArrival(destinationId, Shells, Catalog)
			local offset = worldOffsets[destinationId] or Vector3.new(0, 0, 0)
			if char ~= nil and char.PrimaryPart ~= nil then
				char:PivotTo(CFrame.new(vec(arrival.anchor) + offset + Vector3.new(0, 3, 0)))
			end
			telemetry.incr("travel.fast_travel:" .. destinationId, 1)
			travelRequest:FireClient(plr, "traveling", destinationId, result.teleportTarget)
		else
			travelRequest:FireClient(plr, "denied", destinationId, result.reason)
		end
	end
end)

-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- LOGIN → ARRIVAL PLACEMENT (kind-aware) + the non-lethal clamp + the funnel first-spawn guarantees
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local FIRST_HUNT_AREA = "sunny_levee"
local FIRST_FISH_AREA = "channel_banks"

local function guardHumanoid(hum)
	hum.HealthChanged:Connect(function(h)
		if Catalog.tuning.combat.nonLethalDestinations[BAYOU] and h < Catalog.tuning.combat.nonLethalMinHP then
			hum.Health = Catalog.tuning.combat.nonLethalMinHP
		end
	end)
end

local function placeCharacter(plr, char)
	local session = sessionService.sessions[plr.UserId]
	if session == nil then
		return
	end
	-- the Step-8 routing branch: a returning (funnel-COMPLETE) player lands in the Lodge, a first-time player
	-- in the Bayou root. ONE login owner resolves this — no second SessionService anywhere.
	local arrival = ArrivalService.resolveArrival(session.profile, Shells, Catalog)
	if char.PrimaryPart ~= nil then
		char:PivotTo(CFrame.new(vec(arrival.anchor) + Vector3.new(0, 3, 0)))
	end
end

local function guaranteeFirstSpawns(plr)
	local session = sessionService.sessions[plr.UserId]
	if session == nil then
		return
	end
	if Onboarding.firstSpawnEligible(Catalog, session.profile, BAYOU, FIRST_HUNT_AREA, "Hunting") then
		local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, FIRST_HUNT_AREA, "Hunting")
		if #pool > 0 then
			spawnTarget(pool[1], FIRST_HUNT_AREA)
		end
	end
	if Onboarding.firstSpawnEligible(Catalog, session.profile, BAYOU, FIRST_FISH_AREA, "Fishing") then
		local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, FIRST_FISH_AREA, "Fishing")
		if #pool > 0 then
			spawnBite(pool[1], FIRST_FISH_AREA)
		end
	end
end

Players.PlayerAdded:Connect(function(plr)
	pcall(function()
		SessionService.login(sessionService, plr.UserId) -- THE single login lock (lock + load via Step 2)
	end)
	-- Step 9: re-evaluate gate unlocks at login (the catch-all — cheap, idempotent, eventually consistent).
	local session = sessionService.sessions[plr.UserId]
	if session ~= nil then
		Progression.commitUnlocks(session.profile, Catalog)
		SessionService.markDirty(sessionService, plr.UserId)
	end
	plr.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		hum.WalkSpeed = movement.walkSpeed
		hum.JumpPower = movement.jumpPower
		guardHumanoid(hum)
		placeCharacter(plr, char)
		guaranteeFirstSpawns(plr)
	end)
end)
Players.PlayerRemoving:Connect(function(plr)
	activeFight[plr.UserId] = nil
	pcall(function()
		SessionService.logout(sessionService, plr.UserId)
	end)
end)
game:BindToClose(function()
	for _, plr in Players:GetPlayers() do
		pcall(function()
			SessionService.logout(sessionService, plr.UserId)
		end)
	end
end)

print("[WildWorld] WorldServer online — ONE login owner; handlers:", (function()
	local n = 0
	for _ in registry.handlers do
		n += 1
	end
	return n
end)(), "· Bayou (inline) + Appalachia + Alaska (Step-10 geometry) + Lodge built · fast-travel execution live")
