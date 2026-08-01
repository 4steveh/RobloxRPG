--!nonstrict
-- ════════════════════════════════════════════════════════════════════════════════════════════════════
-- STUDIO-ONLY boot script for the art layer. All the work lives in src/server/studio/WorldArtBuilder.luau
-- (a ModuleScript, so the world can also be BAKED from edit mode — Roblox discards everything Play mode
-- builds when you stop, and edit mode never runs Scripts, so a Script alone can never persist a sculpt).
--
-- This file's only job is the gate: apply the look, publish it to clients, hide WorldServer's placeholder
-- blockout, start the creature-visual listener, and build the world if it is not already built.
--
-- ACTIVE BY DEFAULT. The previous version gated everything behind workspace:GetAttribute("WildWorldArt"),
-- an attribute nothing in the repository ever set — which is why none of the art had ever rendered for a
-- player. It now builds once per place, keyed on ArtKit.version, so bumping the kit and pressing Play is
-- the whole iteration loop.
-- ════════════════════════════════════════════════════════════════════════════════════════════════════

local ArtKit = require("../../config/ArtKit")
local Builder = require("../studio/WorldArtBuilder")

local BUILT_ATTR = "WildWorldArt_Built"
local REBUILD_ATTR = "WildWorldArt_Rebuild"
local VERSION_ATTR = "WildWorldArt_Version"

Builder.applyTerrainColors()
-- The server's default look is the Bayou's (the free starter destination and the hero look); each client
-- then overrides it per biome via client/BiomeLook.client.luau.
Builder.applyLook(ArtKit.looks.bayou)
Builder.publishLooks()
Builder.publishWeapons()
Builder.suppressPlaceholders()
Builder.startCreatureUpgrades()
Builder.startGaitLoop()

local built = workspace:GetAttribute(BUILT_ATTR) == true
local sameVersion = workspace:GetAttribute(VERSION_ATTR) == ArtKit.version
local forced = workspace:GetAttribute(REBUILD_ATTR) == true

if (not built) or (not sameVersion) or forced then
	task.spawn(function()
		local why = if forced then "forced" elseif not built then "first build" else "ArtKit version changed"
		print(("[WildWorldArt] building world (%s), ArtKit v%d"):format(why, ArtKit.version))
		local ok, err = pcall(Builder.buildAll)
		if ok then
			workspace:SetAttribute(BUILT_ATTR, true)
			workspace:SetAttribute(VERSION_ATTR, ArtKit.version)
			workspace:SetAttribute(REBUILD_ATTR, false)
		else
			-- Surfaced loudly. The previous version wrapped every stage in a silent pcall, so a failed build
			-- was indistinguishable from a world that simply had no art in it.
			warn("[WildWorldArt] BUILD FAILED: " .. tostring(err))
		end
	end)
else
	print(
		("[WildWorldArt] world already built at ArtKit v%d (set workspace attribute %s = true to rebuild)"):format(
			ArtKit.version,
			REBUILD_ATTR
		)
	)
end
