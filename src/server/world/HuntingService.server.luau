--!nonstrict
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- STUDIO-ONLY (NOT headless-analyzed). The hunting INTEGRATION surface: it wires the headless combat core
-- (Combat, Spawner, FireHandler, RewardPipeline — all unit-tested) into the Roblox runtime. References
-- Workspace / Players / RemoteEvents / Raycasts / Humanoids — verified by the README playtest checklist,
-- NOT by CI. The rigor-critical MATH/PIPELINE/CAPS are proven headless; the game FEEL and the live shot
-- are what a phone confirms (recoil, hit-stop, impact, kill reaction, audio, haptics, the clean-kill
-- flourish, aim-assist) — none of that is asserted here.
--
-- What this owns: (1) the server-authoritative TARGET SPAWNER (per-area MaxConcurrentTargets + respawn
-- timers + the condition-gated rare layer); (2) the FIRE flow (raycast LOS + position/weapon authority →
-- the gauntlet's step-3 shot resolution → the atomic reward pipeline); (3) the Bayou-wide non-lethal
-- clamp on the player Humanoid; (4) free respawn-and-walk on downed.
--
-- BOOTSTRAP NOTE: in the MVL bootstrap, ONE server script owns SessionService + the gauntlet registry and
-- BOTH the world (Step 3 BayouBlockout) and this combat wiring share them. Shown self-contained here for
-- the Step-4 slice; consolidating the single login owner is TODO(step-8 bootstrap).
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- headless modules (require-by-string via .luaurc; Rojo + Roblox resolve at runtime)
local Catalog = require("@src/config/Catalog")
local Shells = require("@src/config/Shells")
local Spawning = require("@src/config/Spawning")
local Spawner = require("@src/logic/Spawner")
local Combat = require("@src/logic/Combat")
local Gauntlet = require("@src/server/authority/Gauntlet")
local FireHandler = require("@src/server/combat/FireHandler")
local EquipHandler = require("@src/server/authority/handlers/EquipHandler")
local Onboarding = require("@src/logic/Onboarding")
local SessionService = require("@src/server/SessionService")
local ArrivalService = require("@src/server/ArrivalService")
local Adapters = require("@src/server/RobloxAdapters")

local BAYOU = "bayou"
local shell = Shells.byDestination[BAYOU]
local huntingSpawn = Spawning.byDestination[BAYOU].hunting

local function vec(p)
	return Vector3.new(p.x, p.y, p.z)
end

-- ── runtime substrate adapters (GUID ids, telemetry, persistence) ──────────────────────────────────
local idGen = Adapters.idGenerator(HttpService)
local telemetry = Adapters.telemetry(function(metric, value)
	-- TODO(ops): forward to AnalyticsService. The build-notes telemetry set (per-tier kill success, death
	-- rate per archetype, TTK-vs-modeled, targets/hr-vs-modeled, co-op-vs-solo, aim-assist by platform) is
	-- emitted from here + the reward pipeline; aim-assist-by-platform is added in the client controller.
end)
local sessionService = SessionService.new({
	store = Adapters.dataStore(DataStoreService:GetDataStore("WildWorld_Profiles_v1")),
	clock = Adapters.clock(),
	config = Catalog,
	serverId = (game.JobId ~= "" and game.JobId) or "studio",
	telemetry = telemetry,
})

-- ── the gauntlet registry (combat + the Step-2 reference equip handler) ─────────────────────────────
local registry = Gauntlet.new()
Gauntlet.register(registry, FireHandler.new({ idGen = idGen, telemetry = telemetry })) -- payoutFn nil → stub (Step 6 supplies real Payout)
Gauntlet.register(registry, EquipHandler)

-- ── server-authoritative TARGET SPAWNER ─────────────────────────────────────────────────────────────
-- The server OWNS spawn positions, counts, and respawn timers (the client cannot spawn/force/relocate).
-- The cap is the economy invariant (Spawner.expectedTargetsPerHour bounds the realized rate near
-- Income(1)); ambiance is placed by BayouBlockout and never counts toward this reward-bearing population.
local targetsFolder = Instance.new("Folder")
targetsFolder.Name = "HuntingTargets"
targetsFolder.Parent = workspace

-- live per-creature combat state, keyed by the spawned Model
local liveTargets: { [Instance]: { creatureId: string, health: number, accumulated: number, zoneId: string } } = {}

local function spawnTarget(creatureId: string, zoneId: string)
	local creature = Catalog.creatures[creatureId]
	local zone = shell.zones[zoneId]
	local model = Instance.new("Model")
	model.Name = creature.name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 3, 4)
	root.Anchored = true
	root.Color = creature.behavior == "aggressive" and Color3.fromRGB(120, 70, 60) or Color3.fromRGB(150, 130, 90)
	-- a server-owned position scattered within the zone bounds
	local jitterX = (math.random() - 0.5) * zone.size.x
	local jitterZ = (math.random() - 0.5) * zone.size.z
	root.Position = vec(zone.center) + Vector3.new(jitterX, 1.5, jitterZ)
	root.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("creatureId", creatureId)
	model:SetAttribute("targetId", creatureId)
	model.Parent = targetsFolder
	liveTargets[model] = { creatureId = creatureId, health = creature.health, accumulated = 0, zoneId = zoneId }
	return model
end

local function despawnTarget(model: Instance, respawnAfter: number?)
	local state = liveTargets[model]
	liveTargets[model] = nil
	model:Destroy()
	if state ~= nil and respawnAfter ~= nil then
		task.delay(respawnAfter, function()
			-- respawn a fresh routine target into the same area (the server-owned respawn timer = the cap)
			local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, state.zoneId)
			if #pool > 0 then
				spawnTarget(pool[math.random(1, #pool)], state.zoneId)
			end
		end)
	end
end

-- initial fill: each area up to MaxConcurrentTargets, drawn from that zone's routine population.
for zoneId, area in huntingSpawn.areas do
	local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, zoneId)
	if #pool > 0 then
		for _ = 1, area.maxConcurrentTargets do
			spawnTarget(pool[math.random(1, #pool)], zoneId)
		end
	end
end

-- ── condition-gated RARE layer (the MECHANISM; LiveOps condition scheduling is Step 13) ──────────────
-- A separate, independent spawn — NEVER a per-kill upgrade roll. worldState is a stub here; Step 13's
-- calendar drives time/weather/season/event. The per-window 1-in-N roll lives on the creature's rare field.
local function worldState()
	return { time = "dawn or dusk", weather = "fog" } -- TODO(step-13): real time-of-day/weather/season/event
end
task.spawn(function()
	while true do
		task.wait(60) -- one rare "window" per minute (illustrative; Step 13 owns cadence)
		local world = worldState()
		for id, c in Catalog.creatures do
			if c.destinationId == BAYOU and c.rare ~= nil and c.spawnZones ~= nil then
				if Spawner.rareSpawnEligible(c, world) and math.random(1, c.rare.spawnRate) == 1 then
					spawnTarget(id, c.spawnZones[1]) -- layered ON TOP of the routine population
					telemetry.incr("combat.rare_spawned:" .. id, 1)
				end
			end
		end
	end
end)

-- ── the FIRE flow ───────────────────────────────────────────────────────────────────────────────────
local fireRequest = Instance.new("RemoteEvent")
fireRequest.Name = "FireRequest"
fireRequest.Parent = ReplicatedStorage

local lastShotAt: { [number]: number } = {} -- server-authoritative per-player fire-rate clock

-- map a hit part to a vital/body/limb zone (Studio art tags the vital part). Default body.
local function zoneOfHit(part: Instance): string
	local z = part:GetAttribute("hitZone")
	return (z == "vital" or z == "limb") and z or "body"
end

fireRequest.OnServerEvent:Connect(function(plr, aimOrigin, aimDirection)
	local session = sessionService.sessions[plr.UserId]
	local char = plr.Character
	if session == nil or char == nil or char.PrimaryPart == nil then
		return
	end
	-- SERVER-AUTHORITATIVE raycast (the LOS truth — the client's aim is advisory, the server casts).
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { char }
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- cast from the authoritative character position toward the (sanitized) aim direction
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
		return -- missed / hit world geometry (a miss spooks the target; handled by client feedback)
	end

	local state = liveTargets[model]
	-- build the server-enriched payload (client claimed only the target/aim; everything else is server truth)
	local payload = {
		targetId = rayHitTargetId,
		zone = zone,
		distance = distance,
		claimedDamage = nil, -- filled below from the equipped weapon (server canonical)
		lastShotAt = lastShotAt[plr.UserId] or 0,
		rayHitTargetId = rayHitTargetId,
		targetAlive = true,
		accumulatedDamageBefore = state.accumulated,
		owner = tostring(plr.UserId),
		partySize = 1, -- TODO(co-op): party size from the player's group
	}
	-- derive the authoritative shot damage for THIS player's equipped weapon (also re-validated in the handler)
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
	local t, lvl = equippedTierLevel()
	local shotDmg = Combat.shotDamage(Combat.weaponDamage(Catalog, t, lvl), Combat.zoneMultiplier(Catalog, zone), Combat.rangeFalloff(Catalog, t, distance))
	payload.claimedDamage = shotDmg

	-- fire-rate is validated in the handler; record the shot time for the NEXT shot
	if Combat.fireRateOk(Catalog, payload.lastShotAt, now, Combat.cycleTime(Catalog, t)) then
		lastShotAt[plr.UserId] = now
	end

	if (state.accumulated + shotDmg) >= Catalog.creatures[state.creatureId].health then
		-- the LETHAL blow → route through the critical gauntlet (atomic reward pipeline)
		local result = Gauntlet.handle(registry, { intent = "fire", playerId = plr.UserId, payload = payload }, session, {
			config = Catalog,
			now = now,
			saveFn = function()
				return SessionService.saveNow(sessionService, plr.UserId)
			end,
			markDirty = function()
				SessionService.markDirty(sessionService, plr.UserId)
			end,
			telemetry = telemetry,
		})
		if result.ok then
			despawnTarget(model, huntingSpawn.areas[state.zoneId] and huntingSpawn.areas[state.zoneId].respawnIntervalSeconds or nil)
			fireRequest:FireClient(plr, "kill", rayHitTargetId, result.projection)
			-- TODO(Studio feel): hit-stop, kill reaction, impact VFX, class audio, haptics; the rare
			-- clean-kill flourish (slow-mo) fires here when the kill minted an artifact.
		end
	else
		-- a valid non-lethal shot: apply damage to the SERVER HP, replicate impact for feedback prediction
		state.accumulated += shotDmg
		fireRequest:FireClient(plr, "hit", rayHitTargetId, shotDmg)
	end
end)

-- ── Bayou-wide non-lethal clamp + free respawn ──────────────────────────────────────────────────────
-- A creature damaging the player (the aggressive gator's lunge) can never down an armorless player in the
-- Bayou: clamp the Humanoid to ≥ nonLethalMinHP. (From Tier 2 armor becomes a real survival factor.)
local function guardHumanoid(hum)
	hum.HealthChanged:Connect(function(h)
		if Catalog.tuning.combat.nonLethalDestinations[BAYOU] and h < Catalog.tuning.combat.nonLethalMinHP then
			hum.Health = Catalog.tuning.combat.nonLethalMinHP
		end
	end)
	hum.Died:Connect(function()
		-- Non-punitive death (§4): forfeit only the current hunt; never banked Cash/inventory. The
		-- SpawnLocation (BayouBlockout) free-respawns at the Bayou arrival point. TODO(step-8): Lodge
		-- respawn; TODO(step-6): Cash revive-in-place price; TODO(step-14): rewarded-ad revive.
	end)
end

-- Step 7 first-spawn guarantee (the no-empty-field D1 killer): for a first-time player whose first hunt is
-- still ungranted, guarantee a close target in the arrival hunting area, BYPASSING the density cap — but
-- ONLY when the headless eligibility predicate says so (it returns false for a post-first / non-arrival /
-- returning player, so the caps hold for everything else — no farming leak). The predicate is the tested
-- guarantee; this is the Studio spawn. (Session ownership consolidation with BayouBlockout: TODO(step-8).)
local FIRST_HUNT_AREA = "sunny_levee"
local function guaranteeFirstHunt(plr)
	local session = sessionService.sessions[plr.UserId]
	if session == nil then
		return
	end
	if Onboarding.firstSpawnEligible(Catalog, session.profile, BAYOU, FIRST_HUNT_AREA, "Hunting") then
		local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, FIRST_HUNT_AREA, "Hunting")
		if #pool > 0 then
			spawnTarget(pool[1], FIRST_HUNT_AREA) -- bypasses MaxConcurrentTargets for the FIRST hunt only
		end
	end
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		guardHumanoid(hum)
		guaranteeFirstHunt(plr)
	end)
end)

print("[WildWorld] HuntingService online — targets:", #targetsFolder:GetChildren(), "areas:", (function()
	local n = 0
	for _ in huntingSpawn.areas do
		n += 1
	end
	return n
end)())
