--!strict
-- Step 11 — the BOAT DEALER + KENNEL & STABLE vendors (the access sink + the convenience sinks) as a single
-- server-authoritative Gauntlet handler (intent "buyVendorItem"). The precedent is ShopHandler.buyHandler /
-- LodgeShopHandler.buyDecorHandler: the CLIENT asserts nothing; the server validates, debits the catalog's
-- AUTHORED Cash price via the Ledger, and grants the typed-owned commodity. `critical` -> the debit + the
-- grant commit atomically (a failed write reverts both -- no orphan Cash or item). Buy != equip (vehicles/
-- mounts/dogs carry no equip slot; OWNERSHIP grants access -- Spawner.canAccessZone reads all commodities).
-- What this handler does NOT do: it never sells gating gear (that is ShopHandler), never sells a real-money
-- pack (Step 14), and never Cash-sells a tradeable rare breed (dog_redbone_rare -> Trading Post P2P, Step 12).
-- The Boat is ACCESS, never power: this grants no stat, only the item.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Profile = require("@src/logic/Profile")
local Ledger = require("@src/server/ledger/Ledger")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx
type EquipmentItem = Schema.EquipmentItem

local M = {}

export type VendorDeps = { idGen: Types.IdGenerator, telemetry: Types.Telemetry? }

-- The two Lodge vendors Step 6's gear shop deferred (gear -> Outfitter/TackleShop; rare breeds -> Trading Post).
local VENDOR_VENDORS: { [string]: boolean } = { BoatDealer = true, KennelAndStable = true }

local function resolve(ctx: Ctx): EquipmentItem?
	local itemId = ctx.payload.itemId
	if type(itemId) ~= "string" then
		return nil
	end
	return ctx.config.equipment[itemId]
end

function M.buyHandler(deps: VendorDeps): Gauntlet.IntentHandler
	return {
		intent = "buyVendorItem",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			local item = resolve(ctx)
			if item == nil then
				return false, "unknown_item"
			end
			if not VENDOR_VENDORS[item.availableAt] then
				return false, "not_sold_here" -- gating gear is the Outfitter/TackleShop (ShopHandler), not here
			end
			if item.tradeable then
				return false, "rare_trade_routed" -- a tradeable rare breed (dog_redbone_rare) -> Trading Post (Step 12)
			end
			local cash = (item.cost :: any).cash
			if cash == nil then
				return false, "real_money_not_here" -- a real-money pack is Step 14; this is the Cash sink
			end
			if Ledger.balanceOf(ctx.profile.cash) < cash then
				return false, "insufficient_funds"
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local item = assert(resolve(ctx), "buyVendorItem commit: authority should have caught this")
			local cash = (item.cost :: any).cash :: number
			local debit = Ledger.attemptDebit(ctx.profile.cash, cash, {
				type = item.category, -- "vehicle" | "mount" | "dog": the access/convenience sink tag (telemetry §F)
				tier = item.tier,
				loop = "none",
				validatingEventId = deps.idGen.next("vendor"),
			}, ctx.now)
			assert(debit.ok, "buyVendorItem commit: affordability verified, no yield, debit must succeed")
			Profile.mintCommodity(ctx.profile, item.id, 0) -- typed-owned at the entry floor; NOT equipped (buy != equip)
			if deps.telemetry ~= nil then
				deps.telemetry.incr("economy.buy:" .. item.category, 1) -- mount/dog adoption + vehicle access rate
				if item.accessGrant == Enums.WaterType.coastal then
					deps.telemetry.incr("economy.buy:coastalSkiff", 1) -- the marquee Alaska save-up (time-to-Skiff)
				end
			end
		end,
	}
end

return M
