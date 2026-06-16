--!strict
-- THE SERVER-AUTHORITY VALIDATION GAUNTLET (§2). A reusable request-handler substrate: every
-- state-changing client REQUEST runs the 6 ordered steps. The client asserts NOTHING — there is no
-- "set balance" / "I killed X" handler, so a client assertion has no route and is rejected at step 2.
-- This module builds the machinery (steps 1, 2, 4, 5, 6) + the router; the per-intent HANDLERS register
-- in their owning steps (buy/sell → Step 6, salvage/display → Step 8, travel → Step 9, trade → Step 12).
-- Step 3 (domain simulation) is a pluggable hook combat/fishing fill in Steps 4/5.

local Schema = require("@src/types/Schema")
local Types = require("@src/server/persistence/Types")
local Replication = require("@src/server/authority/Replication")
local Transaction = require("@src/server/authority/Transaction")

type PlayerData = Schema.PlayerData
type Config = Schema.Config

local M = {}

export type Ctx = { profile: PlayerData, config: Config, payload: any, now: number }
export type IntentHandler = {
	intent: string,
	authority: (ctx: Ctx) -> (boolean, string?), -- step 2: does authoritative state permit it?
	simulate: ((ctx: Ctx) -> (boolean, string?))?, -- step 3: pluggable domain check (nil → skip)
	commit: (ctx: Ctx) -> (), -- step 4: apply the mutation(s) in one no-yield section
	critical: boolean, -- step 5: write-through (true) vs dirty-flag (false)
}
export type Session = { playerId: number, profile: PlayerData, live: boolean }
export type Request = { intent: string, playerId: number, payload: any }
export type Deps = {
	config: Config,
	now: number,
	saveFn: () -> boolean, -- write-through persist (returns ok); critical handlers run inside a Transaction
	markDirty: () -> (), -- mark the profile dirty for the periodic autosave
	telemetry: Types.Telemetry?,
}
export type HandleResult = { ok: boolean, reason: string?, projection: Replication.Projection? }
export type Registry = { handlers: { [string]: IntentHandler } }

local function incr(deps: Deps, metric: string)
	if deps.telemetry ~= nil then
		deps.telemetry.incr(metric, 1)
	end
end

function M.new(): Registry
	return { handlers = {} }
end

function M.register(reg: Registry, handler: IntentHandler)
	assert(reg.handlers[handler.intent] == nil, "Gauntlet: intent already registered: " .. handler.intent)
	reg.handlers[handler.intent] = handler
end

function M.handle(reg: Registry, request: Request, session: Session, deps: Deps): HandleResult
	-- 1. Authenticity — a legal request for this player's live, session-locked session.
	if not session.live then
		return { ok = false, reason = "session_not_live" }
	end
	if session.playerId ~= request.playerId then
		return { ok = false, reason = "not_authenticated" }
	end
	-- route — rejects client ASSERTIONS (no handler for "setBalance" / "iKilledX").
	local handler = reg.handlers[request.intent]
	if handler == nil then
		incr(deps, "gauntlet.rejected_unknown_intent")
		return { ok = false, reason = "unknown_intent" }
	end
	local ctx: Ctx = { profile = session.profile, config = deps.config, payload = request.payload, now = deps.now }
	-- 2. Authority — does authoritative state permit it?
	local authOk, authReason = handler.authority(ctx)
	if not authOk then
		incr(deps, "gauntlet.rejected_authority")
		return { ok = false, reason = authReason or "unauthorized" }
	end
	-- 3. Simulation — pluggable domain check (combat/fishing, Steps 4/5).
	if handler.simulate ~= nil then
		local simOk, simReason = handler.simulate(ctx)
		if not simOk then
			incr(deps, "gauntlet.rejected_simulation")
			return { ok = false, reason = simReason or "sim_failed" }
		end
	end
	-- 4 + 5. Atomic commit + persist. Critical mutations commit-as-a-unit inside a Transaction so a
	-- failed write reverts cleanly; non-critical mutations commit and ride the dirty-flag autosave.
	if handler.critical then
		local txn = Transaction.run(session.profile, function()
			handler.commit(ctx)
		end, deps.saveFn)
		if not txn.ok then
			incr(deps, "gauntlet.persist_failed")
			return { ok = false, reason = "persist_failed" }
		end
	else
		handler.commit(ctx)
		deps.markDirty()
	end
	-- 6. Replicate — a fresh read-only projection.
	incr(deps, "gauntlet.handled:" .. request.intent)
	return { ok = true, projection = Replication.buildProjection(session.profile, deps.config) }
end

return M
