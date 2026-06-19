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
local MarketplaceService = game:GetService("MarketplaceService") -- Step 14: the real-money platform boundary

-- headless modules (require-by-string via .luaurc; Rojo + Roblox resolve at runtime)
local Catalog = require("../../config/Catalog")
local Shells = require("../../config/Shells")
local Spawning = require("../../config/Spawning")
local Spawner = require("../../logic/Spawner")
local Combat = require("../../logic/Combat")
local Fishing = require("../../logic/Fishing")
local LiveOps = require("../../logic/LiveOps")
local Onboarding = require("../../logic/Onboarding")
local Loadout = require("../../logic/Loadout")
local Gauntlet = require("../authority/Gauntlet")
local FireHandler = require("../combat/FireHandler")
local CatchHandler = require("../fishing/CatchHandler")
local EquipHandler = require("../authority/handlers/EquipHandler")
local ShopHandler = require("../shop/ShopHandler")
local VendorHandler = require("../shop/VendorHandler")
local ClaimDailyHandler = require("../daily/ClaimDailyHandler")
local SalvageHandler = require("../lodge/SalvageHandler")
local DisplayHandler = require("../lodge/DisplayHandler")
local LodgeShopHandler = require("../lodge/LodgeShopHandler")
local WorldMapHandler = require("../progression/WorldMapHandler")
local EventRewardHandler = require("../liveops/EventRewardHandler")
local PurchaseService = require("../monetization/PurchaseService") -- Step 14: the headless grant logic
local RewardedAdHandler = require("../monetization/RewardedAdHandler")
local TradeService = require("../trading/TradeService")
local Progression = require("../../logic/Progression")
local Analytics = require("../../logic/Analytics") -- Step 15: the session/funnel/retention emits + the metric defs
local DestinationService = require("../DestinationService")
local SessionService = require("../SessionService")
local ArrivalService = require("../ArrivalService")
local Adapters = require("../RobloxAdapters")
local Fakes = require("../persistence/Fakes") -- S1 Studio: in-memory store fallback when DataStore is unavailable (unpublished place / API access off)
local Economy = require("../../logic/Economy") -- S1: in-game shop pricing (the amount the buy handler debits)
local Replication = require("../authority/Replication") -- S1: read-only projection for shop "open"

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
	--
	-- STEP-13 (LiveOps) telemetry — WIRED (these incr() calls fire from the handlers/flows):
	--   liveops.eventFaucet:<eventId>   — event-faucet Cash share (did Cash stay in budget) — EventRewardHandler
	--   liveops.eventParticipation      — event participation rate (did the event land) — EventRewardHandler
	--   combat/fishing.rare_spawned:<id>— a windowed rare went live (the event/seasonal spawn fired)
	-- STEP-13 telemetry — TODO (ops dashboards / session-end aggregates, not headless):
	--   liveops.evergreenSinkShare      — the §9 canary: endgame Cash routed to decor/slots ÷ endgame Cash earned
	--                                     (built from economy.evergreenSink:* vs income); FEEDS the alarm below.
	--   trading.rarePriceTrend          — the corroborating inflation canary (Trading Post rare prices)
	--   daily.claim by day / session-2  — the D1→D7 bridge; reactivation on a marquee beat; cadence-adherence
	--
	-- STEP-15 (Analytics) telemetry — WIRED (these fire from the handlers/session boundaries):
	--   session.start / session.end / session.retention:dN  — the retention substrate (Analytics.recordSession*)
	--   funnel.beat_dwell:<beat> / funnel.beat_abandoned:<beat>  — the funnel drop-off (Analytics.recordSessionEnd)
	-- STEP-15 telemetry — TODO (the AnalyticsService aggregation / metric SECOND-operands, not headless):
	--   analytics.activeSeconds:Hunting|Fishing  — the per-loop ACTIVE-TIME attribution (NEW instrumentation):
	--     accumulate wall-clock seconds the player is actively in each loop (hunting vs fishing), and emit per
	--     session. This is the second operand of the MEASURED per-loop balance ratio: realized loop Cash (read
	--     from the ledger's kill/catch faucets — Analytics.realizedLoopCash) ÷ realized active seconds. The pure
	--     ratio (Analytics.perLoopBalanceRatio) is headless + has teeth; THIS wall-clock accumulator is Studio.
	--   the D1/D7/D30 cohort rollups, the funnel-viz, ARPU/ARPPU, the canary dashboards + alarm paging
	--     (Analytics.healthReport defines the verdicts; populating its inputs + paging is the AnalyticsService).
end)

-- STEP-13: the evergreen-sink alarm — a telemetry-driven scheduler trigger (SYS_liveops §4/§G). When the
-- §9 canary (evergreen-sink share of endgame Cash) falls below the threshold, the catalog has saturated faster
-- than the baseline decor cadence and an out-of-band decor/theme drop is pulled forward. The decision FUNCTION
-- is headless + tested (LiveOps.evergreenSinkAlarm); feeding it the LIVE share is an ops/analytics aggregate
-- (the telemetry sink above forwards to AnalyticsService — playtest/ops-pending), so the trigger is a seam:
--   if LiveOps.evergreenSinkAlarm(currentEvergreenSinkShare, Catalog) then  -- fire the out-of-band decor drop
--     <schedule/flag a pulled-forward Cash-priced decor batch ahead of the baseline cadence>
--   end
-- S1 Studio resilience: GetDataStore THROWS in an unpublished place / with Studio API access off
-- ("You must publish this place to the web to access DataStore"). A thrown error here would kill the whole
-- world bootstrap (no remotes, no geometry). Degrade gracefully to an EPHEMERAL in-memory store so the place
-- still boots and is fully playable — profiles just do not persist across sessions. Publish the place AND
-- enable Studio → Game Settings → Security → "Enable Studio Access to API Services" for real persistence.
local profileStore
do
	local ok, robloxDataStore = pcall(function()
		return DataStoreService:GetDataStore("WildWorld_Profiles_v1")
	end)
	if ok then
		profileStore = Adapters.dataStore(robloxDataStore)
	else
		warn("[WildWorld] DataStore unavailable (" .. tostring(robloxDataStore) .. ") — using an EPHEMERAL in-memory store. "
			.. "Profiles will NOT persist. Publish the place + enable Studio API access for real persistence.")
		profileStore = (Fakes.newDataStore())
	end
end

local sessionService = SessionService.new({
	store = profileStore,
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
Gauntlet.register(registry, EventRewardHandler.new({ telemetry = telemetry })) -- Step 13: the thin event participation faucet
Gauntlet.register(registry, RewardedAdHandler.new({ idGen = idGen, telemetry = telemetry })) -- Step 14: the opt-in rewarded-ad faucet

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
-- STEP-14 MONETIZATION — the MarketplaceService boundary (PLATFORM/Studio). The grant + idempotency logic is
-- HEADLESS + tested (PurchaseService / RewardedAdHandler / RewardPipeline's multiplier hook, run-tests.sh);
-- THIS block is the thin platform wiring: PromptProductPurchase / PromptGamePassPurchase, the ProcessReceipt
-- callback, UserOwnsGamePassAsync, and the rewarded-ad SDK trigger. NOTHING here mints Cash on its own — it
-- routes the platform events into the headless grant functions, which carry the pay-proof + idempotency.
--
-- ASSET-ID BINDING (Out of scope — Steve binds the real numeric ids in Studio): the catalog ships PLACEHOLDER
-- assetIds (config/Monetization), so these maps are EMPTY until the real Roblox ProductId / GamePassId numbers
-- are filled in below. Until then the prompts are inert and ProcessReceipt defers (NotProcessedYet) — no Cash
-- can be granted before an id is bound, which is the safe direction.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
local devProductIdToProduct = {} -- TODO(studio): [Roblox ProductId (number)] = Catalog.products["pack_cash_small" | "boost_2x_cash" | "devproduct_premium_*"]
local gamePassIdToProduct = {} -- TODO(studio): [Roblox GamePassId (number)] = Catalog.products["vip_pass" | "gamepass_coastal_skiff" | "gamepass_founders_skin"]

-- The dev-product receipt callback. Idempotent on the Roblox PurchaseId via PurchaseService.processReceipt
-- (a re-delivered receipt is a no-op). Persist BEFORE acknowledging: PurchaseGranted only on a successful
-- save, else NotProcessedYet so Roblox re-delivers (and the redeemed-set makes the re-delivery a no-op).
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local product = devProductIdToProduct[receiptInfo.ProductId]
	if product == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- id not yet bound / unknown → let Roblox retry
	end
	local session = sessionService.sessions[receiptInfo.PlayerId]
	if session == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- player not on this server; retry where they are
	end
	local r = PurchaseService.processReceipt(session.profile, Catalog, product, receiptInfo.PurchaseId, os.time(), telemetry)
	if r.alreadyGranted then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- granted in a prior delivery (idempotent)
	end
	if SessionService.saveNow(sessionService, receiptInfo.PlayerId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- The store UI asks the server to PROMPT a real-money purchase (the platform call; the grant lands in
-- ProcessReceipt above / the game-pass login check below). Cash is never granted here.
local purchaseRequest = Instance.new("RemoteEvent")
purchaseRequest.Name = "PurchaseRequest"
purchaseRequest.Parent = ReplicatedStorage
purchaseRequest.OnServerEvent:Connect(function(plr, kind, assetId)
	if kind == "gamepass" then
		MarketplaceService:PromptGamePassPurchase(plr, assetId)
	else
		MarketplaceService:PromptProductPurchase(plr, assetId)
	end
end)

-- The rewarded-ad trigger. The client watches an ad via the SDK and, on a VERIFIED completion, fires this;
-- the server runs the claimAdReward gauntlet intent (which enforces the bounded amount + the cooldown cap).
-- TODO(studio): gate this on the real rewarded-ad SDK completion attestation (the handler is the backstop).
local adRequest = Instance.new("RemoteEvent")
adRequest.Name = "RewardedAdClaim"
adRequest.Parent = ReplicatedStorage
adRequest.OnServerEvent:Connect(function(plr)
	local session = sessionService.sessions[plr.UserId]
	if session ~= nil then
		Gauntlet.handle(registry, { intent = "claimAdReward", playerId = plr.UserId, payload = {} }, session, gauntletDeps(plr))
	end
end)

-- Grant the game-pass entitlements a player OWNS (idempotent — safe to call every login; PurchaseService
-- skips an already-owned item / active VIP). Called from PlayerAdded after the session loads.
local function grantOwnedGamePasses(plr)
	local session = sessionService.sessions[plr.UserId]
	if session == nil then
		return
	end
	for passId, product in gamePassIdToProduct do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(plr.UserId, passId)
		end)
		if ok and owns then
			PurchaseService.grantGamePass(session.profile, Catalog, product, os.time(), telemetry)
		end
	end
	SessionService.markDirty(sessionService, plr.UserId)
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

-- ── STUDIO FEEL: procedural creature silhouettes (replaces the single-box target). Each creature reads as a
-- distinct animal: a body + a VITAL head + archetype limbs. The hitZone tags make the existing headshot
-- multiplier (Combat.zoneMultiplier, via zoneOfHit) live. All parts anchored + non-colliding; PrimaryPart =
-- torso. maxHealth/currentHealth attrs drive the client health bar (CreatureLabels) + the death anim.
local CREATURE_ARCHETYPES = {
	bayou_american_alligator = { kind = "reptile", scale = 1.6, color = Color3.fromRGB(70, 92, 64) },
	bayou_swamp_rabbit       = { kind = "small_mammal", scale = 0.6, color = Color3.fromRGB(150, 140, 120) },
	bayou_nutria             = { kind = "small_mammal", scale = 0.95, color = Color3.fromRGB(110, 86, 64) },
	bayou_wood_duck          = { kind = "bird", scale = 0.8, color = Color3.fromRGB(96, 120, 150) },
}
local DEFAULT_ARCHETYPE = { kind = "small_mammal", scale = 1.0, color = Color3.fromRGB(120, 110, 100) }

local function fxPart(fxName, size, color, hitZone, parent)
	local pt = Instance.new("Part")
	pt.Name = fxName
	pt.Size = size
	pt.Color = color
	pt.Anchored = true
	pt.CanCollide = false
	pt.CanQuery = true -- the fire raycast must hit it
	pt.Material = Enum.Material.SmoothPlastic
	if hitZone ~= nil then
		pt:SetAttribute("hitZone", hitZone)
	end
	pt.Parent = parent
	return pt
end

local function buildBody(model, arch)
	local s, c = arch.scale, arch.color
	local headC = c:Lerp(Color3.new(1, 1, 1), 0.12)
	if arch.kind == "reptile" then
		local torso = fxPart("Torso", Vector3.new(2.2 * s, 1.1 * s, 5.0 * s), c, "body", model)
		fxPart("Head", Vector3.new(1.2 * s, 1.0 * s, 1.8 * s), headC, "vital", model).CFrame = torso.CFrame * CFrame.new(0, 0.1 * s, -3.0 * s)
		fxPart("Tail", Vector3.new(1.0 * s, 0.7 * s, 3.0 * s), c, "limb", model).CFrame = torso.CFrame * CFrame.new(0, 0, 3.4 * s)
		for _, dx in ipairs({ -1.2 * s, 1.2 * s }) do
			for _, dz in ipairs({ -1.6 * s, 1.6 * s }) do
				fxPart("Leg", Vector3.new(0.5 * s, 1.0 * s, 0.5 * s), c, "limb", model).CFrame = torso.CFrame * CFrame.new(dx, -0.9 * s, dz)
			end
		end
		return torso
	elseif arch.kind == "bird" then
		local torso = fxPart("Torso", Vector3.new(1.4 * s, 1.4 * s, 2.2 * s), c, "body", model)
		fxPart("Head", Vector3.new(0.9 * s, 0.9 * s, 0.9 * s), headC, "vital", model).CFrame = torso.CFrame * CFrame.new(0, 0.9 * s, -1.2 * s)
		for _, dx in ipairs({ -1.0 * s, 1.0 * s }) do
			fxPart("Wing", Vector3.new(0.3 * s, 0.9 * s, 1.6 * s), c, "limb", model).CFrame = torso.CFrame * CFrame.new(dx, 0.2 * s, 0)
		end
		return torso
	else
		local torso = fxPart("Torso", Vector3.new(1.6 * s, 1.5 * s, 2.6 * s), c, "body", model)
		fxPart("Head", Vector3.new(1.1 * s, 1.1 * s, 1.1 * s), headC, "vital", model).CFrame = torso.CFrame * CFrame.new(0, 0.7 * s, -1.5 * s)
		fxPart("Ear", Vector3.new(0.3 * s, 1.1 * s, 0.3 * s), headC, "limb", model).CFrame = torso.CFrame * CFrame.new(0, 1.6 * s, -1.5 * s)
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
	-- S3 GROUND CONTRACT: originCFrame already carries the resolved torso-center Y (groundY + footOffset from
	-- spawnTarget). The old fixed +1.2*scale lift is GONE — placement Y now lives in one place: the ground raycast.
	model:PivotTo(originCFrame)
	model:SetAttribute("creatureId", creatureId)
	model:SetAttribute("targetId", creatureId)
	model:SetAttribute("maxHealth", creature.health)
	model:SetAttribute("currentHealth", creature.health)
	return model
end

-- STUDIO FEEL: per-archetype wander speed (studs/sec). Gators slow, rabbits quick.
local MOVE_SPEED = { reptile = 3, small_mammal = 7, bird = 6 }
local function creatureSpeed(creatureId)
	local arch = CREATURE_ARCHETYPES[creatureId] or DEFAULT_ARCHETYPE
	return MOVE_SPEED[arch.kind] or 5
end

-- STUDIO FEEL (S3 GROUND CONTRACT): per-archetype FOOT OFFSET = distance from the PrimaryPart (torso center)
-- DOWN to the body's resting contact. It equals the torso half-height from buildBody, so the torso BOTTOM
-- sits on the ground: a reptile rests LOW (belly near the ground; its short legs splay/clip — a gator
-- belly-crawls), a small mammal / bird (no separate legs in the silhouette) stands on its body. One formula
-- keyed on the archetype's kind+scale — never hand-tuned per creature. Mirrors buildBody's torso Size.Y.
local TORSO_HEIGHT = { reptile = 1.1, bird = 1.4, small_mammal = 1.5 }
local function footOffset(arch)
	return (TORSO_HEIGHT[arch.kind] or 1.5) * 0.5 * arch.scale
end

-- STUDIO FEEL (S3 GROUND CONTRACT): resolve the Y of the surface the PLAYER SEES & WALKS ON at (x, z), so a
-- creature is placed/kept on the rendered ground regardless of what the baked art looks like (we can't see
-- the art from the repo — the ray adapts to whatever is there). RespectCanCollide skips non-collidable décor
-- (reeds/props/overlay meshes); excluding HuntingTargets + the live characters means we hit the SAME top
-- collidable surface the character's feet rest on — baked Terrain grass when the art layer is enabled, the
-- placeholder pads/floor when it isn't. That reconciles the art-ground ↔ collision-floor seam by construction.
-- IgnoreWater → we want the land surface, not the water plane.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true
groundParams.IgnoreWater = true
local function refreshGroundFilter()
	local filter = { targetsFolder }
	for _, plr in Players:GetPlayers() do
		if plr.Character ~= nil then
			table.insert(filter, plr.Character)
		end
	end
	groundParams.FilterDescendantsInstances = filter
end
-- One downward ray per call from well above (x, z). Cheap; callers refreshGroundFilter() once per batch.
local function groundYAt(x, z, fromY)
	local origin = Vector3.new(x, (fromY or 0) + 64, z)
	local hit = workspace:Raycast(origin, Vector3.new(0, -512, 0), groundParams)
	return if hit ~= nil then hit.Position.Y else nil
end

local function spawnTarget(creatureId, zoneId)
	local zone = shell.zones[zoneId]
	local arch = CREATURE_ARCHETYPES[creatureId] or DEFAULT_ARCHETYPE
	local foot = footOffset(arch)
	local x = zone.center.x + (math.random() - 0.5) * zone.size.x
	local z = zone.center.z + (math.random() - 0.5) * zone.size.z
	-- Rest the creature ON the surface the player sees, not at a fixed height above an old flat placeholder.
	refreshGroundFilter()
	local groundY = groundYAt(x, z, zone.center.y) or zone.center.y
	local model = buildCreatureModel(creatureId, CFrame.new(x, groundY + foot, z))
	model.Parent = targetsFolder
	liveTargets[model] = {
		creatureId = creatureId, health = Catalog.creatures[creatureId].health, accumulated = 0, zoneId = zoneId,
		mode = "wander", target = nil, fleeUntil = 0, fleeFrom = nil, speed = creatureSpeed(creatureId), footOffset = foot,
	}
	return model
end

-- STUDIO FEEL: a brief server-driven death (tip over + sink + fade) so every client sees the creature go
-- down, instead of an instant despawn. Animates in parallel with the respawn schedule, then destroys.
local function playDeath(model)
	local cf = model:GetPivot()
	local goalCF = cf * CFrame.Angles(math.rad(80), 0, 0)
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	model:SetAttribute("currentHealth", 0)
	task.spawn(function()
		local t0 = os.clock()
		while true do
			local a = (os.clock() - t0) / 0.6
			if a >= 1 then
				break
			end
			model:PivotTo(cf:Lerp(goalCF, a) + Vector3.new(0, -2 * a, 0))
			for _, d in ipairs(parts) do
				d.Transparency = a
			end
			task.wait()
		end
		model:Destroy()
	end)
end

local function despawnTarget(model, respawnAfter)
	local state = liveTargets[model]
	liveTargets[model] = nil
	playDeath(model)
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

-- ── STUDIO FEEL: creature movement (wander + face direction; flee when shot at) ──────────────────────
-- SERVER-AUTHORITATIVE so the fire raycast always hits the live position (moving targets). A throttled
-- Heartbeat walks each creature toward a wander point in its zone, or away from a recent shot. Anchored-
-- part PivotTo replicates to all clients. The loop never yields, so it can't interleave with despawn.
local function zoneRandomPoint(zoneId)
	local z = shell.zones[zoneId]
	return vec(z.center) + Vector3.new((math.random() - 0.5) * z.size.x * 0.8, 0, (math.random() - 0.5) * z.size.z * 0.8)
end

local function moveCreatures(dt)
	local now = os.clock()
	refreshGroundFilter() -- S3: refresh the live-character exclude list once per move-tick, not per creature
	for model, state in liveTargets do
		if model.PrimaryPart ~= nil then
			local pos = model:GetPivot().Position
			local z = shell.zones[state.zoneId]
			local center = vec(z.center)
			local speed = state.speed or 5
			local dir
			if state.mode == "flee" and now < state.fleeUntil then
				local from = state.fleeFrom or pos
				dir = Vector3.new(pos.X - from.X, 0, pos.Z - from.Z)
				speed = speed * 2.4
			else
				if state.mode == "flee" then
					state.mode = "wander"
					state.target = nil
				end
				if state.target == nil or (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(state.target.X, 0, state.target.Z)).Magnitude < 2 then
					state.target = zoneRandomPoint(state.zoneId)
				end
				dir = Vector3.new(state.target.X - pos.X, 0, state.target.Z - pos.Z)
			end
			if dir.Magnitude > 0.15 then
				dir = dir.Unit
				local step = pos + dir * speed * dt
				local nx = math.clamp(step.X, center.X - z.size.x / 2, center.X + z.size.x / 2)
				local nz = math.clamp(step.Z, center.Z - z.size.z / 2, center.Z + z.size.z / 2)
				-- S3 GROUND CONTRACT: follow terrain elevation at the new (x, z) instead of sliding at a fixed Y.
				local groundY = groundYAt(nx, nz, center.Y)
				local ny = if groundY ~= nil then groundY + (state.footOffset or 0) else pos.Y
				local newPos = Vector3.new(nx, ny, nz)
				model:PivotTo(CFrame.lookAt(newPos, newPos + dir))
			end
		end
	end
end

-- spook creatures within `radius` of a shot impact (called from the fire handler on every shot)
local function spookNear(impactPos, radius, fromPos)
	for model, state in liveTargets do
		if (model:GetPivot().Position - impactPos).Magnitude <= radius then
			state.mode = "flee"
			state.fleeUntil = os.clock() + 3
			state.fleeFrom = fromPos or impactPos
			state.target = nil
		end
	end
end

local moveAccum = 0
game:GetService("RunService").Heartbeat:Connect(function(dt)
	moveAccum += dt
	if moveAccum < 0.1 then
		return
	end
	moveCreatures(moveAccum)
	moveAccum = 0
end)

-- Step 13: the per-tick server-time recompute of the calendar's WorldState. LiveOps.worldStateAt reads the
-- ACTIVE event (server time ∈ [start,end]) and returns the clauses it imposes (event/season/…); because this
-- is recomputed every tick (the spawn loops below call it each cycle), world.event goes active at the event's
-- start and REVERTS after its end — purely from server time, never latched. Ambient time/weather are the
-- day-night + weather systems (Studio placeholders here); the calendar's clauses overlay them.
local function liveOpsWorld()
	return LiveOps.worldStateAt(Catalog, os.time())
end
local function huntWorldState()
	local w = liveOpsWorld()
	return { time = w.time or "dawn or dusk", weather = w.weather or "fog", season = w.season, event = w.event }
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
	spookNear(if result ~= nil then result.Position else origin + aimDirection.Unit * 60, 22, origin) -- STUDIO FEEL: shots scatter nearby game
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
	-- S1 review fix: enforce fire-rate on the WHOLE shot, not just the lastShotAt bookkeeping. Previously the
	-- non-lethal accumulation (the else branch below) ran REGARDLESS of fireRateOk, so rapid fire accumulated
	-- damage OUTSIDE the gauntlet's per-shot validators (only the killing blow is gauntlet-checked). A shot that
	-- violates the weapon's cycle time is now rejected entirely — no accumulation, no "hit", consistent with the
	-- gauntlet's own fire-rate check on the lethal blow (which reads the same payload.lastShotAt).
	if not Combat.fireRateOk(Catalog, payload.lastShotAt, now, Combat.cycleTime(Catalog, tlvl)) then
		return
	end
	lastShotAt[plr.UserId] = now
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
		model:SetAttribute("currentHealth", math.max(0, Catalog.creatures[state.creatureId].health - state.accumulated))
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
	local w = liveOpsWorld() -- Step 13: per-tick server-time recompute (drives the Frozen-Lake / Salmon-Run event clause)
	return { time = w.time or "night", weather = w.weather or "storm", season = w.season, event = w.event }
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
		-- Pick the NEAREST live bite to the caster (not an arbitrary hash-order one), so a player hooks a
		-- fish in the water they are standing by — never a far-zone, gear-inappropriate fish. Falls back to
		-- the first bite if the character is not yet present (no position to measure from).
		local origin = plr.Character and plr.Character.PrimaryPart
		local nearest, bestDist = nil, math.huge
		for marker in liveBites do
			local d = if origin ~= nil then (marker.Position - origin.Position).Magnitude else 0
			if d < bestDist then
				bestDist = d
				nearest = marker
			end
		end
		if nearest ~= nil then
			activeFight[plr.UserId] = { marker = nearest, accumulated = 0 }
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

-- STUDIO FEEL: login-time state push + pull. The HUD had no projection until the first kill/cast/shop
-- event (showing dashes). StateSync pushes the read-only projection on spawn AND answers a client request
-- (the HUD asks on load), so the header + the next-goal gate reasons populate immediately.
local stateSync = Instance.new("RemoteEvent")
stateSync.Name = "StateSync"
stateSync.Parent = ReplicatedStorage
local function pushState(plr)
	local session = sessionService.sessions[plr.UserId]
	if session ~= nil then
		stateSync:FireClient(plr, Replication.buildProjection(session.profile, Catalog))
	end
end
stateSync.OnServerEvent:Connect(function(plr)
	pushState(plr)
end)

Players.PlayerAdded:Connect(function(plr)
	pcall(function()
		SessionService.login(sessionService, plr.UserId) -- THE single login lock (lock + load via Step 2)
	end)
	-- Step 9: re-evaluate gate unlocks at login (the catch-all — cheap, idempotent, eventually consistent).
	local session = sessionService.sessions[plr.UserId]
	if session ~= nil then
		Progression.commitUnlocks(session.profile, Catalog)
		grantOwnedGamePasses(plr) -- Step 14: grant owned game-pass entitlements (idempotent; marks dirty)
		-- Step 15: the session-start boundary + the retention-day classification (server-time; firstSeenAt was
		-- stamped inside SessionService.login). The cohort rollup over players is the AnalyticsService (ops).
		Analytics.recordSessionStart(telemetry, Catalog, session.profile, os.time())
	end
	plr.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		hum.WalkSpeed = movement.walkSpeed
		hum.JumpPower = movement.jumpPower
		guardHumanoid(hum)
		placeCharacter(plr, char)
		guaranteeFirstSpawns(plr)
		pushState(plr) -- STUDIO FEEL: populate the HUD header + next-goal immediately on spawn
	end)
end)
Players.PlayerRemoving:Connect(function(plr)
	activeFight[plr.UserId] = nil
	-- Step 15: the session-end boundary + the funnel ABANDON signal (a session ending below COMPLETE → the
	-- beat it stalled on + the dwell), emitted BEFORE logout while the profile is still live. Server-derived.
	local session = sessionService.sessions[plr.UserId]
	if session ~= nil then
		Analytics.recordSessionEnd(telemetry, session.profile, os.time())
	end
	pcall(function()
		SessionService.logout(sessionService, plr.UserId)
	end)
end)
game:BindToClose(function()
	for _, plr in Players:GetPlayers() do
		local session = sessionService.sessions[plr.UserId]
		if session ~= nil then
			Analytics.recordSessionEnd(telemetry, session.profile, os.time())
		end
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
end)(), "· Bayou (inline) + Appalachia + Alaska (Step-10 geometry) + Lodge built · fast-travel execution live · LiveOps event clock driving world.event (Step 13) · monetization wired: ProcessReceipt + game-pass + rewarded-ad seams (Step 14) · analytics: session/funnel/retention emits + the T_current resolution (Step 15 — MVL feature-complete)")
