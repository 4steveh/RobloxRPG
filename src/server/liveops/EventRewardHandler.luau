--!strict
-- THE EVENT PARTICIPATION REWARD (Step 13 §D) as a server-authoritative Gauntlet handler. The thin Cash
-- reward an event pays is budget-capped, validated, atomic, and EVENT-FAUCET-tagged (separable in telemetry,
-- bounded per event by construction — SYS_liveops §6). It REUSES the Ledger/Economy substrate wholesale: no
-- event-specific Cash path, no new anti-dupe surface. Idempotency is a SERVER-TIME entitlement (offline time
-- counts; logging off banks nothing — SYS_data_integrity §6), so a reconnect cannot double-claim.
--
-- This is NOT how event RARES are delivered: a rare mint is a normal condition-gated catch/kill through the
-- existing RewardPipeline + ArtifactStore and writes NO Cash (RD2). This handler is ONLY the thin
-- participation faucet — the bulk of an event's value never touches the Cash supply.

local Schema = require("@src/types/Schema")
local Economy = require("@src/logic/Economy")
local LiveOps = require("@src/logic/LiveOps")
local Ledger = require("@src/server/ledger/Ledger")
local Gauntlet = require("@src/server/authority/Gauntlet")
local Types = require("@src/server/persistence/Types")

type Ctx = Gauntlet.Ctx

local M = {}

export type EventRewardDeps = { telemetry: Types.Telemetry? }

-- The per-window claim marker (a server-time entitlement keyed by event id). One claim per window.
local function claimKind(eventId: string): string
	return "eventReward:" .. eventId
end

function M.new(deps: EventRewardDeps): Gauntlet.IntentHandler
	return {
		intent = "claimEventReward",
		critical = true, -- the faucet credit + the claim entitlement commit atomically (write-through)

		authority = function(ctx: Ctx): (boolean, string?)
			local eventId = ctx.payload.eventId
			local event = ctx.config.liveOps.events[eventId]
			if event == nil then
				return false, "unknown_event"
			end
			-- server owns whether the event is live (server time ∈ [start, end]); the client never asserts it.
			if not LiveOps.isEventActive(ctx.config, eventId, ctx.now) then
				return false, "event_inactive"
			end
			-- idempotency: an active claim entitlement for THIS event blocks a re-claim (server-time-validated).
			local kind = claimKind(eventId)
			for _, ent in ctx.profile.activeEntitlements do
				if ent.kind == kind and LiveOps.entitlementActive(ent, ctx.now) then
					return false, "already_claimed"
				end
			end
			return true, nil
		end,

		commit = function(ctx: Ctx)
			local eventId = ctx.payload.eventId
			local event = ctx.config.liveOps.events[eventId]
			local tier = Economy.currentTier(ctx.profile, ctx.config) -- Step 15: loop-agnostic (max EHT/EFT), the one T_current fn
			local amount = LiveOps.eventPayout(ctx.config, event, tier) -- already capped at the event budget
			if amount > 0 then
				Ledger.applyEntry(ctx.profile.cash, {
					type = "eventReward", -- the event faucet tag (telemetry-separable; loop=none keeps reconciliation clean)
					amount = amount,
					tier = tier,
					loop = "none",
					validatingEventId = "eventReward:" .. eventId .. "@" .. tostring(event.startTime),
				}, ctx.now)
			end
			-- prune expired entitlements, then grant the window-bounded claim entitlement (server-time absolute).
			local kept: { Schema.Entitlement } = {}
			for _, ent in ctx.profile.activeEntitlements do
				if LiveOps.entitlementActive(ent, ctx.now) then
					table.insert(kept, ent)
				end
			end
			-- expiry = endTime + 1: the claim marker must outlast the INCLUSIVE window. isEventActive is inclusive
			-- (now ≤ endTime) but entitlementActive is exclusive (now < expiry), so an expiry of endTime would read
			-- EXPIRED at now == endTime while the event is still live → an unbounded re-claim drain at the boundary.
			-- +1 makes `now < endTime+1` block through the whole [start,end] (no boundary hole), without shifting the
			-- timed-boost/offline-entitlement semantics (entitlementActive stays `now < expiry`).
			table.insert(kept, { kind = claimKind(eventId), expiryTimestamp = event.endTime + 1 })
			ctx.profile.activeEntitlements = kept
			if deps.telemetry ~= nil then
				deps.telemetry.incr("liveops.eventFaucet:" .. eventId, amount) -- event-faucet Cash share (did Cash stay in budget)
				deps.telemetry.incr("liveops.eventParticipation", 1) -- event participation rate (did it land)
			end
		end,
	}
end

return M
