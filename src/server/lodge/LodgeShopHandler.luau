--!strict
-- THE LODGE CASH SINK (Step 8) — SYS_economy §9's PRIMARY evergreen inflation ballast. Buying a slot
-- (slotExpansionPrice, escalating/uncapped) or a decor SKU is a normal atomic ledger sink (the Step-6 buy
-- pattern): debit Cash via the Ledger, grant the COUNT-BASED owned slot/decor, server-authoritative (the
-- client never asserts ownership), tagged for the `evergreen-sink share` telemetry. `critical` → the debit +
-- the grant commit atomically (a failed write reverts both — no orphan). Decor is balance-free (asserted at
-- catalog load — assertDecorItem); here we only transact a Cash-priced SKU. placeDecor is cosmetic layout
-- (no economy/anti-dupe weight) → non-critical (dirty-flag autosave). Real-money decor is Step 14.

local Schema = require("../../types/Schema")
local Economy = require("../../logic/Economy")
local Ledger = require("../ledger/Ledger")
local Gauntlet = require("../authority/Gauntlet")
local Types = require("../persistence/Types")

type Ctx = Gauntlet.Ctx
type DecorItem = Schema.DecorItem

local M = {}

export type LodgeShopDeps = { idGen: Types.IdGenerator, telemetry: Types.Telemetry? }

-- ── buy an additional Trophy-Hall display slot (escalating, uncapped — the unbounded sink) ──────────────
function M.buySlotHandler(deps: LodgeShopDeps): Gauntlet.IntentHandler
	return {
		intent = "buySlot",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			-- uncapped: no maxTrophySlots check (the sink must keep absorbing endgame Cash — §9)
			local price = Economy.slotExpansionPrice(ctx.config, ctx.profile.lodge.boughtSlots)
			if Ledger.balanceOf(ctx.profile.cash) < price then
				return false, "insufficient_funds"
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local price = Economy.slotExpansionPrice(ctx.config, ctx.profile.lodge.boughtSlots)
			local debit = Ledger.attemptDebit(ctx.profile.cash, price, {
				type = "slotExpansion", -- the evergreen-sink ledger tag (§9)
				loop = "none",
				validatingEventId = deps.idGen.next("slot"),
			}, ctx.now)
			assert(debit.ok, "buySlot commit: authority verified affordability and nothing yields, so the debit must succeed")
			ctx.profile.lodge.boughtSlots += 1 -- the count-based grant (no instanceId, no artifactId)
			if deps.telemetry ~= nil then
				deps.telemetry.incr("economy.evergreenSink:slot", 1)
			end
		end,
	}
end

-- ── buy a decor / theme / framing SKU (count-based owned decor) ─────────────────────────────────────────
function M.buyDecorHandler(deps: LodgeShopDeps): Gauntlet.IntentHandler
	local function resolve(ctx: Ctx): DecorItem?
		local itemId = ctx.payload.itemId
		if type(itemId) ~= "string" then
			return nil
		end
		return ctx.config.decor[itemId]
	end
	return {
		intent = "buyDecor",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			local item = resolve(ctx)
			if item == nil then
				return false, "unknown_decor"
			end
			local cash = (item.cost :: any).cash
			if cash == nil then
				return false, "real_money_not_here" -- real-money decor is Step 14; this is the Cash sink
			end
			if Ledger.balanceOf(ctx.profile.cash) < cash then
				return false, "insufficient_funds"
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local item = assert(resolve(ctx), "buyDecor commit: authority should have caught this")
			local cash = (item.cost :: any).cash :: number
			local debit = Ledger.attemptDebit(ctx.profile.cash, cash, {
				type = "decor", -- the evergreen-sink ledger tag (§9)
				loop = "none",
				validatingEventId = deps.idGen.next("decor"),
			}, ctx.now)
			assert(debit.ok, "buyDecor commit: affordability verified, no yield, debit must succeed")
			ctx.profile.lodge.ownedDecor[item.id] = (ctx.profile.lodge.ownedDecor[item.id] or 0) + 1
			if deps.telemetry ~= nil then
				deps.telemetry.incr("economy.evergreenSink:decor", 1)
			end
		end,
	}
end

-- ── place owned decor in the Lodge layout (cosmetic-only; no economy/anti-dupe weight) ──────────────────
function M.placeDecorHandler(deps: LodgeShopDeps): Gauntlet.IntentHandler
	return {
		intent = "placeDecor",
		critical = false, -- cosmetic layout → the periodic dirty-flag autosave (part of the whole-profile write)
		authority = function(ctx: Ctx): (boolean, string?)
			local itemId = ctx.payload.itemId
			local slotKey = ctx.payload.slotKey
			if type(itemId) ~= "string" or type(slotKey) ~= "string" then
				return false, "bad_payload"
			end
			if (ctx.profile.lodge.ownedDecor[itemId] or 0) < 1 then
				return false, "not_owned" -- the server validates ownership (the client never asserts it)
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local itemId = ctx.payload.itemId :: string
			local slotKey = ctx.payload.slotKey :: string
			-- one placement per layout slotKey (placing replaces what sits there) → no placement dupe surface.
			for _, pl in ctx.profile.lodge.placements do
				if pl.slotKey == slotKey then
					pl.itemId = itemId
					return
				end
			end
			table.insert(ctx.profile.lodge.placements, { itemId = itemId, slotKey = slotKey })
			if deps.telemetry ~= nil then
				deps.telemetry.incr("lodge.placeDecor", 1)
			end
		end,
	}
end

return M
