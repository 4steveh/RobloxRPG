--!strict
-- THE GEAR SINKS — Outfitter (weapon/armor) & Tackle Shop (rod/reel) — as server-authoritative Gauntlet
-- intent handlers (the precedent is EquipHandler; the atomic/critical shape is FireHandler's). The CLIENT
-- asserts nothing — not a price, not a balance, not ownership; the server validates, debits via the Ledger,
-- and grants gear via the commodity-mint. Both handlers are `critical` → the Cash debit + the gear change
-- commit atomically in a Transaction (a failed write reverts both — no orphan Cash or gear).
--
--   buy     (intent "buy",     payload { itemId })            → debit GearCostSlot(T) + mint an `entry` commodity
--   upgrade (intent "upgrade", payload { commodityInstanceId }) → debit the IntraTierClimb step + intraLevel += 1
--
-- Buying a slot does NOT equip it (equip is EquipHandler) and does NOT satisfy a Gate; an intra-tier
-- upgrade NEVER changes EHT/EFT (RD1 — it gets you apex-capable with co-op; the milestone is still played).
-- The shop UI and the felt "earned upgrade" pacing are Studio. Real-money packs/boosts are Step 14.

local Schema = require("@src/types/Schema")
local Economy = require("@src/logic/Economy")
local Profile = require("@src/logic/Profile")
local Ledger = require("@src/server/ledger/Ledger")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx
type Commodity = Schema.Commodity
type EquipmentItem = Schema.EquipmentItem

local M = {}

export type ShopDeps = {
	idGen: Types.IdGenerator,
	telemetry: Types.Telemetry?,
}

-- The two shop vendors (gating gear is sold here; StarterLoadout is the free grant; BoatDealer/Kennel = Step 11).
local SHOP_VENDORS: { [string]: boolean } = { Outfitter = true, TackleShop = true }

-- the level name for the current intra-tier level (0 → "entry" upgrading to mid; 1 → "mid" upgrading to maxed).
local function fromLevelOf(intraLevel: number): string
	return if intraLevel == 0 then "entry" else "mid"
end
local MAXED_LEVEL = 2 -- entry 0 → mid 1 → maxed 2

local function resolveCommodity(ctx: Ctx): (Commodity?, EquipmentItem?)
	local instanceId = ctx.payload.commodityInstanceId
	if type(instanceId) ~= "string" then
		return nil, nil
	end
	for _, c in ctx.profile.inventory.commodities do
		if c.instanceId == instanceId then
			return c, ctx.config.equipment[c.catalogId]
		end
	end
	return nil, nil
end

-- ── buy a tier-gating slot ───────────────────────────────────────────────────────────────────────────
function M.buyHandler(deps: ShopDeps): Gauntlet.IntentHandler
	return {
		intent = "buy",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			local item = ctx.config.equipment[ctx.payload.itemId]
			if item == nil then
				return false, "unknown_item"
			end
			if not item.tierInput then
				return false, "not_a_gating_slot" -- bait/cosmetic/vehicle/mount/dog are not sold here (Steps 11/14)
			end
			if not SHOP_VENDORS[item.availableAt] then
				return false, "not_sold_here" -- StarterLoadout is the free grant, not a purchase
			end
			if item.tier < 2 then
				return false, "free_starter" -- Tier-1 gating gear is the free starter loadout
			end
			if Ledger.balanceOf(ctx.profile.cash) < Economy.gearCostSlot(ctx.config, item.tier) then
				return false, "insufficient_funds"
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local item = assert(ctx.config.equipment[ctx.payload.itemId], "buy commit: authority should have caught this")
			local cost = Economy.gearCostSlot(ctx.config, item.tier)
			local debit = Ledger.attemptDebit(ctx.profile.cash, cost, {
				type = "gear",
				tier = item.tier,
				loop = "none",
				validatingEventId = deps.idGen.next("buy"),
			}, ctx.now)
			assert(debit.ok, "buy commit: authority verified affordability and nothing yields, so the debit must succeed")
			Profile.mintCommodity(ctx.profile, item.id, 0) -- granted at the intra-tier floor (entry); NOT equipped
			if deps.telemetry ~= nil then
				deps.telemetry.incr("economy.buy:tier" .. tostring(item.tier), 1)
			end
		end,
	}
end

-- ── upgrade an owned gating slot intra-tier ───────────────────────────────────────────────────────────
function M.upgradeHandler(deps: ShopDeps): Gauntlet.IntentHandler
	return {
		intent = "upgrade",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			local commodity, item = resolveCommodity(ctx)
			if commodity == nil then
				return false, "not_owned"
			end
			if item == nil or not item.tierInput then
				return false, "not_upgradeable" -- only gating slots have an intra-tier curve
			end
			if commodity.intraLevel >= MAXED_LEVEL then
				return false, "already_maxed"
			end
			if Ledger.balanceOf(ctx.profile.cash) < Economy.intraTierUpgradeCost(ctx.config, item.tier, fromLevelOf(commodity.intraLevel)) then
				return false, "insufficient_funds"
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local commodity, item = resolveCommodity(ctx)
			assert(commodity ~= nil and item ~= nil, "upgrade commit: authority should have caught this")
			local cost = Economy.intraTierUpgradeCost(ctx.config, item.tier, fromLevelOf(commodity.intraLevel))
			local debit = Ledger.attemptDebit(ctx.profile.cash, cost, {
				type = "gearUpgrade",
				tier = item.tier,
				loop = "none",
				validatingEventId = deps.idGen.next("upgrade"),
			}, ctx.now)
			assert(debit.ok, "upgrade commit: affordability verified, no yield, debit must succeed")
			commodity.intraLevel += 1 -- intra-tier only — never changes EHT/EFT, never satisfies a Gate
			if deps.telemetry ~= nil then
				deps.telemetry.incr("economy.upgrade:tier" .. tostring(item.tier), 1)
			end
		end,
	}
end

return M
