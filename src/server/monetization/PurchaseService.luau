--!strict
-- THE REAL-MONEY GRANT LOGIC (Step 14 §C/§E/§G) — the headless half of the MarketplaceService boundary. The
-- Studio platform callbacks invoke these; this module owns the grant + the idempotency, NOT the platform call:
--   • processReceipt  ← the Roblox `ProcessReceipt` dev-product callback (re-fires; granted ONCE per PurchaseId)
--   • grantGamePass   ← the `UserOwnsGamePassAsync` game-pass check (ownership-idempotent; safe to call each login)
-- The platform calls (PromptProductPurchase / ProcessReceipt wiring / UserOwnsGamePassAsync) + the save+return-
-- to-Roblox are Studio (WorldServer seams); the grant + the exactly-once idempotency are headless + tested here.
--
-- PAY-PROOF (§B): applyGrant is EXHAUSTIVE over the closed ProductGrant union (Cash | item | cosmetic |
-- multiplier) — there is NO conquest/tier branch because the union has no such variant (unrepresentable). No
-- grant here writes profile.conqueredDestinations or an effective-tier input; bought Cash hits the SAME
-- milestone wall idle Cash does (Step 9). The pay-to-win canary is therefore structurally zero.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Profile = require("@src/logic/Profile")
local Monetization = require("@src/logic/Monetization")
local Ledger = require("@src/server/ledger/Ledger")
local Types = require("@src/server/persistence/Types")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type Product = Schema.Product
type ProductGrant = Schema.ProductGrant
type Telemetry = Types.Telemetry

local M = {}

export type ReceiptResult = { granted: boolean, alreadyGranted: boolean }
export type GamePassResult = { granted: boolean, alreadyOwned: boolean }

-- Fungible categories (ammo/bait counts live in inventory.fungible; everything else is a durable commodity).
local function isFungible(category: Enums.Category): boolean
	return category == Enums.Category.bait or category == Enums.Category.tackle
end

local function ownsCommodity(profile: PlayerData, itemId: string): boolean
	for _, c in profile.inventory.commodities do
		if c.catalogId == itemId then
			return true
		end
	end
	return false
end

local function hasActiveMultiplier(profile: PlayerData, tag: Enums.CashMultiplier, now: number): boolean
	local kind = Monetization.multiplierEntitlementKind(tag)
	for _, ent in profile.activeEntitlements do
		if ent.kind == kind and now < ent.expiryTimestamp then
			return true
		end
	end
	return false
end

-- grant an item: a fungible stack (bait/tackle → inventory.fungible) or a single durable commodity.
local function grantItem(profile: PlayerData, config: Config, itemId: string, quantity: number)
	local item = assert(config.equipment[itemId], "PurchaseService: item grant '" .. itemId .. "' must resolve")
	if isFungible(item.category) then
		profile.inventory.fungible[itemId] = (profile.inventory.fungible[itemId] or 0) + quantity
	else
		Profile.mintCommodity(profile, itemId, 0) -- a durable commodity, NOT equipped (equip is EquipHandler)
	end
end

-- add/REFRESH a multiplier entitlement (server-time expiry). A re-grant of the SAME multiplier REPLACES the
-- existing one (refreshes a boost's timer / is a no-op for VIP's persistent expiry) rather than stacking with
-- itself — so buying two 2x boosts never silently becomes 4×. Distinct multipliers (VIP × boost) still stack
-- (activeCashMultiplier), capped at the §7 ceiling.
local function addMultiplierEntitlement(profile: PlayerData, config: Config, tag: Enums.CashMultiplier, now: number)
	local kind = Monetization.multiplierEntitlementKind(tag)
	local kept: { Schema.Entitlement } = {}
	for _, ent in profile.activeEntitlements do
		if ent.kind ~= kind then
			table.insert(kept, ent)
		end
	end
	table.insert(kept, { kind = kind, expiryTimestamp = Monetization.multiplierExpiry(config, tag, now) })
	profile.activeEntitlements = kept
end

-- applyGrant — the EXHAUSTIVE application of a non-cash grant (item / cosmetic / multiplier). Cash has its own
-- idempotent ledger path (Ledger.attemptRealMoneyCredit) so it is NOT routed here — calling applyGrant with a
-- cash grant is a defensive error. No-yield (mint / table writes); the caller owns persistence + idempotency.
-- THE PAY-PROOF SURFACE: the closed union has no conquest/tier variant, so this function structurally CANNOT
-- write a milestone or a tier input — a pay-to-win grant is unrepresentable, not merely unhandled.
function M.applyGrant(profile: PlayerData, config: Config, grant: ProductGrant, now: number)
	if grant.kind == "item" then
		grantItem(profile, config, grant.itemId, grant.quantity or 1)
	elseif grant.kind == "cosmetic" then
		Profile.mintCommodity(profile, grant.itemId, 0) -- a balance-free cosmetic commodity (no stats; not equipped)
	elseif grant.kind == "multiplier" then
		addMultiplierEntitlement(profile, config, grant.multiplier, now)
	else
		error("PurchaseService.applyGrant: a cash grant uses the idempotent ledger credit path, not applyGrant")
	end
end

-- processReceipt — the Roblox ProcessReceipt dev-product handler (§C). Idempotent on the Roblox PurchaseId via
-- the persistent redeemedPurchaseIds set (survives compaction — the Step-2 guarantee), so a RE-DELIVERED
-- receipt grants nothing twice. CASH reuses Ledger.attemptRealMoneyCredit wholesale (it owns the redeemed set
-- for cash, tags the entry `currencypack`); non-cash dev products MIRROR the same PurchaseId idempotency on the
-- SAME set, then apply the grant exactly once. The Studio callback persists, then returns PurchaseGranted only
-- on a successful save (a failed save → Roblox re-delivers → this is a no-op via the redeemed set).
function M.processReceipt(profile: PlayerData, config: Config, product: Product, purchaseId: string, now: number, telemetry: Telemetry?): ReceiptResult
	local g = product.grant
	if g.kind == "cash" then
		local credit = Ledger.attemptRealMoneyCredit(profile.redeemedPurchaseIds, profile.cash, purchaseId, g.amount, "currencypack", now)
		if telemetry ~= nil and not credit.alreadyGranted then
			telemetry.incr("monetization.purchase:" .. product.id, 1)
		end
		return { granted = not credit.alreadyGranted, alreadyGranted = credit.alreadyGranted }
	end
	-- non-cash dev product (a 2x boost / a premium-bait or premium-ammo pack): mirror the cash path's PurchaseId
	-- idempotency on the SAME persistent set so a re-delivered receipt is a no-op.
	if profile.redeemedPurchaseIds[purchaseId] then
		return { granted = false, alreadyGranted = true }
	end
	profile.redeemedPurchaseIds[purchaseId] = true
	M.applyGrant(profile, config, g, now)
	if telemetry ~= nil then
		telemetry.incr("monetization.purchase:" .. product.id, 1)
	end
	return { granted = true, alreadyGranted = false }
end

-- grantGamePass — the UserOwnsGamePassAsync game-pass grant (§E). Idempotent on OWNERSHIP (not a PurchaseId):
-- safe to call every login. An item/cosmetic pass grants the existing item once (skip if already owned); VIP
-- grants/refreshes the persistent multiplier entitlement (skip if already active). A game pass never injects
-- a one-time cash faucet (that is a dev-product currency pack) — rejected defensively.
function M.grantGamePass(profile: PlayerData, config: Config, product: Product, now: number, telemetry: Telemetry?): GamePassResult
	local g = product.grant
	local alreadyOwned: boolean
	if g.kind == "item" then
		alreadyOwned = ownsCommodity(profile, g.itemId)
	elseif g.kind == "cosmetic" then
		alreadyOwned = ownsCommodity(profile, g.itemId)
	elseif g.kind == "multiplier" then
		alreadyOwned = hasActiveMultiplier(profile, g.multiplier, now)
	else
		error("PurchaseService.grantGamePass: a game pass cannot grant a one-time cash faucet (use a currency pack)")
	end
	if alreadyOwned then
		return { granted = false, alreadyOwned = true }
	end
	M.applyGrant(profile, config, g, now)
	if telemetry ~= nil then
		telemetry.incr("monetization.purchase:" .. product.id, 1)
	end
	return { granted = true, alreadyOwned = false }
end

return M
