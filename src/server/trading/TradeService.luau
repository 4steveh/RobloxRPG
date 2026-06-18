--!strict
-- Step 12 — the trade FLOW: the server-owned PendingTrade state machine (REQUESTED → BUILDING →
-- A/B_CONFIRMED → COMMITTING → COMPLETE | CANCELLED). The server owns the state; clients send INTENTS
-- (validated against authoritative state) and see a read-only projection. This module owns negotiation,
-- the version-bound double-confirm + re-arm, the escrow lifecycle (HELD↔ESCROWED via the existing CAS), the
-- offer validation, the tax assembly, and the commit which INVOKES TradeSwap (it never moves items itself).
-- Two profiles are reached via injected getProfile/saveProfile (in Studio: SessionService; in tests: a table).
-- The atomic two-profile swap + the anti-dupe are TradeSwap's; this is the flow that drives it.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Economy = require("@src/logic/Economy")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local Transaction = require("@src/server/authority/Transaction")
local TradeSwap = require("@src/server/trading/TradeSwap")
local Types = require("@src/server/persistence/Types")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
type TradeState = Enums.TradeState
local TS = Enums.TradeState
local D = Enums.Disposition

local M = {}

export type Offer = { items: { string }, cash: number, confirmed: boolean }
export type PendingTrade = {
	tradeId: string,
	a: string,
	b: string,
	state: TradeState,
	version: number,
	offers: { [string]: Offer },
	settleStartedAt: number?,
	createdAt: number,
}
export type TradeDeps = {
	config: Config,
	idGen: Types.IdGenerator,
	telemetry: Types.Telemetry?,
	getProfile: (key: string) -> PlayerData?,
	saveProfile: (key: string) -> boolean,
}
export type TradeService = {
	deps: TradeDeps,
	trades: { [string]: PendingTrade },
	activeByPlayer: { [string]: string }, -- player key → tradeId (the one-active-trade index)
}
export type Result = { ok: boolean, reason: string?, tradeId: string? }

function M.new(deps: TradeDeps): TradeService
	return { deps = deps, trades = {}, activeByPlayer = {} }
end

local function incr(self: TradeService, metric: string)
	if self.deps.telemetry ~= nil then
		self.deps.telemetry.incr(metric, 1)
	end
end

local function other(trade: PendingTrade, who: string): string
	return if who == trade.a then trade.b else trade.a
end

-- the freed-up release of the one-active-trade reservation for both parties.
local function release(self: TradeService, trade: PendingTrade)
	self.activeByPlayer[trade.a] = nil
	self.activeByPlayer[trade.b] = nil
end

-- revert a side's escrow: every ESCROWED artifact in `who`'s offer goes ESCROWED → HELD (the no-dangling-
-- escrow guarantee). Persisted via the single-profile Transaction (a failed save leaves it escrowed for the
-- timeout/reconcile to sweep — the fail-safe direction). Used by re-arm, cancel, timeout, disconnect.
local function revertEscrow(self: TradeService, trade: PendingTrade, who: string)
	local p = self.deps.getProfile(who)
	if p == nil then
		return
	end
	local offer = trade.offers[who]
	Transaction.run(p, function()
		for _, id in offer.items do
			local art = p.artifacts[id]
			if art ~= nil and art.disposition == D.ESCROWED then
				ArtifactStore.transition(p, id, D.ESCROWED, D.HELD)
			end
		end
	end, function()
		return self.deps.saveProfile(who)
	end)
end

-- re-arm: any offer change clears BOTH confirms, reverts any escrow, bumps the version, returns to BUILDING.
local function reArm(self: TradeService, trade: PendingTrade)
	for key, offer in trade.offers do
		if offer.confirmed then
			offer.confirmed = false
			revertEscrow(self, trade, key)
		end
	end
	trade.version += 1
	trade.settleStartedAt = nil
	trade.state = TS.BUILDING
end

-- ── request: A asks B; both become party to a live trade (one-active-trade reserves BOTH). ──
function M.request(self: TradeService, from: string, to: string, now: number): Result
	if from == to then
		return { ok = false, reason = "self_trade" }
	end
	if self.activeByPlayer[from] ~= nil or self.activeByPlayer[to] ~= nil then
		return { ok = false, reason = "already_trading" } -- one active trade per player (check 8)
	end
	local tradeId = self.deps.idGen.next("pendingtrade")
	self.trades[tradeId] = {
		tradeId = tradeId, a = from, b = to, state = TS.REQUESTED, version = 1,
		offers = { [from] = { items = {}, cash = 0, confirmed = false }, [to] = { items = {}, cash = 0, confirmed = false } },
		settleStartedAt = nil, createdAt = now,
	}
	self.activeByPlayer[from] = tradeId
	self.activeByPlayer[to] = tradeId
	incr(self, "trade.requested")
	return { ok = true, tradeId = tradeId }
end

-- ── accept: the requestee moves the trade to BUILDING. ──
function M.accept(self: TradeService, by: string, tradeId: string, now: number): Result
	local trade = self.trades[tradeId]
	if trade == nil then
		return { ok = false, reason = "no_such_trade" }
	end
	if trade.state ~= TS.REQUESTED or by ~= trade.b then
		return { ok = false, reason = "not_acceptable" }
	end
	trade.state = TS.BUILDING
	return { ok = true, tradeId = tradeId }
end

-- validate one offered artifact: exists, owned by `by`, tradeable, HELD. Returns nil on ok or a reason.
local function badOfferItem(self: TradeService, by: string, id: string): string?
	local p = self.deps.getProfile(by)
	if p == nil then
		return "no_profile"
	end
	local art = p.artifacts[id]
	if art == nil or art.tombstoned or p.inventory.artifactIds[id] ~= true or art.owner ~= by then
		return "not_owned"
	end
	if not art.tradeable then
		return "not_tradeable" -- a commodity is structurally un-offerable (check 5)
	end
	if art.disposition ~= D.HELD then
		return "not_held" -- DISPLAYED (un-display first, check 4) / ESCROWED / SALVAGED
	end
	return nil
end

-- ── setOffer: replace a side's offer (covers add/remove item + set Cash). Validates every item; any change
-- re-arms (clears both confirms, reverts escrow, bumps version). ──
function M.setOffer(self: TradeService, by: string, tradeId: string, items: { string }, cash: number, now: number): Result
	local trade = self.trades[tradeId]
	if trade == nil then
		return { ok = false, reason = "no_such_trade" }
	end
	if by ~= trade.a and by ~= trade.b then
		return { ok = false, reason = "not_a_party" }
	end
	if trade.state == TS.COMPLETE or trade.state == TS.CANCELLED or trade.state == TS.COMMITTING then
		return { ok = false, reason = "not_editable" }
	end
	if cash < 0 then
		return { ok = false, reason = "bad_cash" }
	end
	local seen: { [string]: boolean } = {}
	for _, id in items do
		if seen[id] then
			return { ok = false, reason = "duplicate_item" }
		end
		seen[id] = true
		local bad = badOfferItem(self, by, id)
		if bad ~= nil then
			return { ok = false, reason = bad }
		end
	end
	trade.offers[by] = { items = table.clone(items), cash = cash, confirmed = false }
	reArm(self, trade)
	return { ok = true, tradeId = tradeId }
end

-- ── confirm: version-bound. Escrows the confirming side's items (HELD→ESCROWED, atomic). On a failed escrow
-- CAS (an item raced out of HELD), the confirm fails and the trade re-arms. Second confirm opens the settle. ──
function M.confirm(self: TradeService, by: string, tradeId: string, version: number, now: number): Result
	local trade = self.trades[tradeId]
	if trade == nil then
		return { ok = false, reason = "no_such_trade" }
	end
	if by ~= trade.a and by ~= trade.b then
		return { ok = false, reason = "not_a_party" }
	end
	if trade.state ~= TS.BUILDING and trade.state ~= TS.A_CONFIRMED and trade.state ~= TS.B_CONFIRMED then
		return { ok = false, reason = "not_confirmable" }
	end
	if version ~= trade.version then
		return { ok = false, reason = "stale_version" } -- the confirm names terms that have since changed (re-arm)
	end
	local offer = trade.offers[by]
	if offer.confirmed then
		return { ok = false, reason = "already_confirmed" }
	end
	local p = self.deps.getProfile(by)
	if p == nil then
		return { ok = false, reason = "no_profile" }
	end
	-- pre-check every item is HELD (so the escrow CAS will succeed in the no-yield Transaction).
	for _, id in offer.items do
		local art = p.artifacts[id]
		if art == nil or art.tombstoned or art.disposition ~= D.HELD or p.inventory.artifactIds[id] ~= true then
			reArm(self, trade) -- it raced — re-arm ("that item is no longer available")
			return { ok = false, reason = "item_unavailable" }
		end
	end
	-- escrow the confirming side's items atomically (HELD→ESCROWED) and lock the Cash leg.
	local pp = p
	local txn = Transaction.run(pp, function()
		for _, id in offer.items do
			assert(ArtifactStore.transition(pp, id, D.HELD, D.ESCROWED).ok, "confirm: escrow CAS pre-validated, no yield")
		end
	end, function()
		return self.deps.saveProfile(by)
	end)
	if not txn.ok then
		return { ok = false, reason = "persist_failed" }
	end
	offer.confirmed = true
	local otherOffer = trade.offers[other(trade, by)]
	if otherOffer.confirmed then
		trade.state = TS.COMMITTING -- both confirmed; the settle window opens (cancel still allowed)
		trade.settleStartedAt = now
	else
		trade.state = if by == trade.a then TS.A_CONFIRMED else TS.B_CONFIRMED
	end
	incr(self, "trade.confirmed")
	return { ok = true, tradeId = tradeId }
end

-- compute the net Cash leg: payer is the side that offered more Cash; gross = the net moved.
local function cashLeg(trade: PendingTrade): (string, number) -- returns (payer "a"|"b"|"none", gross)
	local aCash = trade.offers[trade.a].cash
	local bCash = trade.offers[trade.b].cash
	if aCash > bCash then
		return "a", aCash - bCash
	elseif bCash > aCash then
		return "b", bCash - aCash
	end
	return "none", 0
end

-- ── tryCommit: after the settle freeze elapses, invoke the atomic swap. Success → COMPLETE; precondition/
-- save failure → escrow released, CANCELLED, nothing transferred. ──
function M.tryCommit(self: TradeService, tradeId: string, now: number): Result
	local trade = self.trades[tradeId]
	if trade == nil then
		return { ok = false, reason = "no_such_trade" }
	end
	if trade.state ~= TS.COMMITTING or trade.settleStartedAt == nil then
		return { ok = false, reason = "not_committing" }
	end
	if (now - (trade.settleStartedAt :: number)) < self.deps.config.tuning.persistence.commitSettleSeconds then
		return { ok = false, reason = "settle_pending" } -- the fat-finger window is still open
	end
	local pa = self.deps.getProfile(trade.a)
	local pb = self.deps.getProfile(trade.b)
	if pa == nil or pb == nil then
		return { ok = false, reason = "no_profile" }
	end
	local payer, gross = cashLeg(trade)
	local swap = TradeSwap.commit({
		aProfile = pa, bProfile = pb, aOwner = trade.a, bOwner = trade.b,
		aArtifactIds = trade.offers[trade.a].items, bArtifactIds = trade.offers[trade.b].items,
		payer = payer, cashGross = gross, config = self.deps.config, idGen = self.deps.idGen, now = now,
		saveA = function()
			return self.deps.saveProfile(trade.a)
		end,
		saveB = function()
			return self.deps.saveProfile(trade.b)
		end,
		telemetry = self.deps.telemetry,
	})
	if not swap.ok then
		-- the swap moved nothing (pre-validate) or reverted both (save); release escrow + cancel cleanly.
		M.cancel(self, trade.a, tradeId, now)
		incr(self, "trade.cancelled:precondition")
		return { ok = false, reason = swap.reason }
	end
	trade.state = TS.COMPLETE
	release(self, trade)
	incr(self, "trade.completed:flow")
	return { ok = true, tradeId = tradeId }
end

-- ── cancel / timeout / disconnect: every exit reverts BOTH sides' escrow and frees both players. ──
function M.cancel(self: TradeService, by: string, tradeId: string, now: number): Result
	local trade = self.trades[tradeId]
	if trade == nil then
		return { ok = false, reason = "no_such_trade" }
	end
	if trade.state == TS.COMPLETE or trade.state == TS.CANCELLED then
		return { ok = false, reason = "not_cancellable" }
	end
	revertEscrow(self, trade, trade.a)
	revertEscrow(self, trade, trade.b)
	trade.state = TS.CANCELLED
	trade.settleStartedAt = nil
	release(self, trade)
	incr(self, "trade.cancelled")
	return { ok = true, tradeId = tradeId }
end

function M.timeoutTick(self: TradeService, tradeId: string, now: number): Result
	local trade = self.trades[tradeId]
	if trade == nil then
		return { ok = false, reason = "no_such_trade" }
	end
	if trade.state == TS.COMPLETE or trade.state == TS.CANCELLED then
		return { ok = false, reason = "not_active" }
	end
	if (now - trade.createdAt) < self.deps.config.tuning.persistence.escrowTimeoutSeconds then
		return { ok = false, reason = "not_expired" }
	end
	return M.cancel(self, trade.a, tradeId, now)
end

function M.onDisconnect(self: TradeService, player: string, now: number): Result
	local tradeId = self.activeByPlayer[player]
	if tradeId == nil then
		return { ok = false, reason = "no_active_trade" }
	end
	return M.cancel(self, player, tradeId, now)
end

-- ── projection: the read-only, server-sourced view (the panel is Studio; the data is headless). Each offered
-- item's identity is rendered from the artifact's authoritative record (provenance → Catalog name/rarity),
-- NEVER from client text (the anti-impersonation guarantee). gross/tax/net are server-computed. ──
export type ProjItem = { artifactId: string, name: string, rarity: string }
export type ProjOffer = { items: { ProjItem }, cash: number, confirmed: boolean }
export type Projection = {
	tradeId: string,
	state: TradeState,
	version: number,
	offers: { [string]: ProjOffer },
	gross: number,
	tax: number,
	net: number,
}
local function identify(self: TradeService, holder: string, id: string): ProjItem
	local p = self.deps.getProfile(holder)
	local art = if p ~= nil then p.artifacts[id] else nil
	local name, rarity = id, "Unknown"
	if art ~= nil and art.provenance.sourceId ~= nil then
		local sourceId = art.provenance.sourceId :: string
		local entry = self.deps.config.targetIndex[sourceId]
		if entry ~= nil then
			rarity = entry.rarity
			-- the canonical name is on the creature/fish record (targetIndex carries no name); pick by loop.
			local src = if entry.loop == Enums.Loop.Hunting then self.deps.config.creatures[sourceId] else self.deps.config.fish[sourceId]
			if src ~= nil then
				name = src.name
			end
		end
	end
	return { artifactId = id, name = name, rarity = rarity }
end
function M.projection(self: TradeService, tradeId: string): Projection?
	local trade = self.trades[tradeId]
	if trade == nil then
		return nil
	end
	local _payer, gross = cashLeg(trade)
	local tax = Economy.tradeTax(self.deps.config, gross)
	local offers: { [string]: ProjOffer } = {}
	for key, offer in trade.offers do
		local items: { ProjItem } = {}
		for _, id in offer.items do
			table.insert(items, identify(self, key, id))
		end
		offers[key] = { items = items, cash = offer.cash, confirmed = offer.confirmed }
	end
	return { tradeId = tradeId, state = trade.state, version = trade.version, offers = offers, gross = gross, tax = tax, net = gross - tax }
end

function M.get(self: TradeService, tradeId: string): PendingTrade?
	return self.trades[tradeId]
end

return M
