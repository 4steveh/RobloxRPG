--!nonstrict
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- STUDIO-ONLY (NOT headless-analyzed). The fishing INTEGRATION surface — the mirror of HuntingService. It
-- wires the headless fishing core (Fishing, Spawner, CatchHandler, the SHARED RewardPipeline — all unit-
-- tested) into the Roblox runtime. References Workspace / Players / RemoteEvents / Humanoids — verified by
-- the README playtest checklist, NOT by CI. The catchability MATH / pipeline / bite-caps are proven
-- headless; the fight FEEL (the tension gauge, the push-pull rhythm, the runs, the cast, weighty haptics)
-- is what a phone confirms — none of that is asserted here.
--
-- What this owns: (1) the server-authoritative BITE spawner (per-water MaxConcurrentBites + respawn +
-- LOCAL SPOT-DEPLETION + the condition-gated rare layer); (2) the cast → bite → fight flow (server
-- simulates the bite roll, hook-set, and the Stamina/tension fight → the LANDED fish routes through the
-- gauntlet's step-3 hook → the atomic reward pipeline); (3) NON-PUNITIVE loss (snap/throw/timeout forfeits
-- only the current fight — never banked Cash/inventory; no death, no respawn, no armor).
--
-- BOOTSTRAP NOTE: in the MVL bootstrap, ONE server script owns SessionService + the gauntlet registry and
-- BOTH loops (hunting + fishing) + the world share them. Shown self-contained here for the Step-5 slice;
-- consolidating the single login owner is TODO(step-8 bootstrap).
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")

local Catalog = require("@src/config/Catalog")
local Shells = require("@src/config/Shells")
local Spawning = require("@src/config/Spawning")
local Spawner = require("@src/logic/Spawner")
local Fishing = require("@src/logic/Fishing")
local Gauntlet = require("@src/server/authority/Gauntlet")
local CatchHandler = require("@src/server/fishing/CatchHandler")
local SessionService = require("@src/server/SessionService")
local Adapters = require("@src/server/RobloxAdapters")
local Onboarding = require("@src/logic/Onboarding")

local BAYOU = "bayou"
local shell = Shells.byDestination[BAYOU]
local fishingSpawn = Spawning.byDestination[BAYOU].fishing

local function vec(p)
	return Vector3.new(p.x, p.y, p.z)
end

-- ── runtime substrate ───────────────────────────────────────────────────────────────────────────────
local idGen = Adapters.idGenerator(HttpService)
local telemetry = Adapters.telemetry(function(metric, value)
	-- TODO(ops): forward to AnalyticsService. The fishing telemetry set — fishing Cash/hr vs hunting Cash/hr
	-- (the DUAL-LOOP DRIFT alarm, the single most important fishing chart), catch-success %, time-to-catch
	-- decomposed, catches/hr vs modeled, hook-set-miss/snap/throw rates, co-op-vs-solo, rare-vs-1-in-N.
end)
local sessionService = SessionService.new({
	store = Adapters.dataStore(DataStoreService:GetDataStore("WildWorld_Profiles_v1")),
	clock = Adapters.clock(),
	config = Catalog,
	serverId = (game.JobId ~= "" and game.JobId) or "studio",
	telemetry = telemetry,
})

local registry = Gauntlet.new()
Gauntlet.register(registry, CatchHandler.new({ idGen = idGen, telemetry = telemetry })) -- payoutFn nil → stub (Step 6)

-- ── server-authoritative BITE spawner (the bite-density cap is the anti-farming invariant) ────────────
-- The server owns bite positions, counts, respawn timers, and spot-depletion; the client cannot spawn,
-- force, or relocate bites. Ambiance has no fishing analog; rares are layered on top via the rare predicate.
local bitesFolder = Instance.new("Folder")
bitesFolder.Name = "FishingBites"
bitesFolder.Parent = workspace

local liveBites: { [Instance]: { fishId: string, zoneId: string } } = {}

local function spawnBite(fishId: string, zoneId: string)
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

-- LOCAL SPOT-DEPLETION (fishing-meta): a landed/spooked bite recovers after the water's BiteRespawnInterval,
-- re-rolling the routine population — so an over-geared player rotates spots and the ceiling holds.
local function depleteBite(marker: Instance)
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

-- condition-gated RARE layer (the MECHANISM; LiveOps cadence is Step 13) — NEVER a per-cast roll, NO bait input.
local function worldState()
	return { time = "night", weather = "storm" } -- TODO(step-13): real time/weather/season/event
end
task.spawn(function()
	while true do
		task.wait(60)
		local world = worldState()
		for id, f in Catalog.fish do
			if f.destinationId == BAYOU and f.rare ~= nil and f.spawnZones ~= nil then
				if Spawner.rareSpawnEligible(f, world) and math.random(1, f.rare.spawnRate) == 1 then
					spawnBite(id, f.spawnZones[1]) -- a distinct rare bite, layered on the routine population
					telemetry.incr("fishing.rare_spawned:" .. id, 1)
				end
			end
		end
	end
end)

-- ── the cast → bite → fight flow ──────────────────────────────────────────────────────────────────────
-- The client sends INPUTS only (cast vector/power, the hook-set tap, reel-hold tension); the server
-- simulates the bite, the hook-set, and the Stamina/tension fight, and routes only the LANDED fish here.
local castRequest = Instance.new("RemoteEvent")
castRequest.Name = "FishingCast"
castRequest.Parent = ReplicatedStorage

-- per-player active fight state (server-authoritative Stamina drain + the bite being fought).
local activeFight: { [number]: { marker: Instance, accumulated: number } } = {}

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

-- a fight "tick": the client reports held tension E; the server clamps it legal, drains Stamina, and on the
-- LANDING tick routes the catch through the critical gauntlet. (The tension gauge + runs are Studio feel.)
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
		local E = math.clamp(tonumber(arg) or 0, 0, 1) -- server-clamped tension (never a client-asserted drain)
		local drain = Fishing.reelDrainMax(Catalog, reelTier, reelLevel) * E
		fight.accumulated += drain
		if fight.accumulated >= Fishing.staminaToLand(Catalog, fish) then
			-- the LANDING blow → route through the critical gauntlet (atomic reward pipeline)
			local payload = {
				targetId = fishId,
				biteActive = true,
				E = E,
				claimedDrain = drain,
				accumulatedStaminaBefore = fight.accumulated - drain,
				owner = tostring(plr.UserId),
				partySize = 1, -- TODO(co-op): party size
			}
			local result = Gauntlet.handle(registry, { intent = "catch", playerId = plr.UserId, payload = payload }, session, {
				config = Catalog,
				now = os.time(),
				saveFn = function()
					return SessionService.saveNow(sessionService, plr.UserId)
				end,
				markDirty = function()
					SessionService.markDirty(sessionService, plr.UserId)
				end,
				telemetry = telemetry,
			})
			if result.ok then
				depleteBite(fight.marker) -- spot-depletion on a landed fish
				castRequest:FireClient(plr, "landed", fishId, result.projection)
				-- TODO(Studio feel): the land animation, weighty haptic resolve, and — on a rare mint — the
				-- clean-catch flourish (the 1-in-N screenshot beat).
			end
			activeFight[plr.UserId] = nil
		else
			castRequest:FireClient(plr, "fightProgress", fishId, fight.accumulated)
		end
		return
	end

	-- a cast: pick the nearest active bite cell (water-reading, not millimetric aim) and begin the fight.
	if action == "cast" then
		local nearest, _bestDist = nil, math.huge
		for marker in liveBites do
			activeFight[plr.UserId] = { marker = marker, accumulated = 0 }
			nearest = marker
			break -- (Studio: choose by cast landing cell; here, any active bite)
		end
		if nearest ~= nil then
			castRequest:FireClient(plr, "bite", liveBites[nearest].fishId)
		end
	end
end)

-- Step 7 first-fish guarantee — the fishing mirror of the hunt guarantee. Eligible ONLY once the player has
-- made their first kill (the funnel introduces fishing AFTER the first hunt → firstSpawnEligible is true at
-- the FIRST_CATCH beat), in the arrival fishing water, for a first-time player; the cap holds otherwise.
local FIRST_FISH_AREA = "channel_banks"
Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		local session = sessionService.sessions[plr.UserId]
		if session ~= nil and Onboarding.firstSpawnEligible(Catalog, session.profile, BAYOU, FIRST_FISH_AREA, "Fishing") then
			local pool = Spawner.routineTargetsInZone(Catalog, BAYOU, FIRST_FISH_AREA, "Fishing")
			if #pool > 0 then
				spawnBite(pool[1], FIRST_FISH_AREA) -- guaranteed first bite (bypasses the bite cap, first only)
			end
		end
	end)
end)

-- NON-PUNITIVE loss (§1 / Decision 1): a snap/throw/timeout forfeits ONLY the current fight — never banked
-- Cash or inventory, and there is NO death/respawn/armor (fishing's whole distinctness from hunting).
Players.PlayerRemoving:Connect(function(plr)
	activeFight[plr.UserId] = nil
end)

print("[WildWorld] FishingService online — bites:", #bitesFolder:GetChildren(), "waters:", (function()
	local n = 0
	for _ in fishingSpawn.areas do
		n += 1
	end
	return n
end)())
