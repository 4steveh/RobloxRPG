--!strict
-- THE DISPLAY / UN-DISPLAY FLOWS (Step 8). Mount = HELD→DISPLAYED CAS; take-down = DISPLAYED→HELD CAS. No
-- Cash moves; just the §4 transition, then the view re-renders (TrophyHall). `critical` because a disposition
-- change is a write-through trigger (Tuning.criticalSaveTriggers.dispositionTransition). Server-authoritative:
-- the client issues "display W" / "take down W"; the server validates against authoritative state.
--
-- SLOT CAPACITY is a precondition on the mount (TrophyHall: countDisplayed < totalSlots) — a player cannot
-- display more trophies than owned slots; a full wall rejects the mount (take one down or buy a slot → the
-- sink pull). Only trophies display (§4 kind-gating is enforced by the CAS; authority pre-checks for a clean
-- reason). A DISPLAYED trophy is NOT directly tradeable: to trade it the player takes it down (→ HELD) and
-- THEN trading escrows it (HELD→ESCROWED, Step 12) — this handler routes "take down to trade" into take-down;
-- it does NOT build escrow/the swap. These CALL the §4 CAS; they reimplement neither it nor the wall.

local ArtifactStore = require("../artifacts/ArtifactStore")
local TrophyHall = require("../../logic/TrophyHall")
local Gauntlet = require("../authority/Gauntlet")
local Enums = require("../../types/Enums")
local Types = require("../persistence/Types")

type Ctx = Gauntlet.Ctx

local M = {}

local D = Enums.Disposition

export type DisplayDeps = { telemetry: Types.Telemetry? }

-- ── mount: HELD → DISPLAYED, gated on slot capacity ───────────────────────────────────────────────────
function M.mountHandler(deps: DisplayDeps): Gauntlet.IntentHandler
	return {
		intent = "mountTrophy",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			local id = ctx.payload.artifactId
			if type(id) ~= "string" then
				return false, "bad_payload"
			end
			local a = ctx.profile.artifacts[id]
			if a == nil then
				return false, "no_such_artifact"
			end
			if a.tombstoned then
				return false, "tombstoned"
			end
			if a.kind ~= Enums.ArtifactKind.trophy then
				return false, "not_a_trophy" -- §4: only Trophy artifacts display (dogs/mounts/boats have their own homes)
			end
			if a.disposition ~= D.HELD then
				return false, "not_held" -- already displayed, or escrowed in a live trade
			end
			if TrophyHall.countDisplayed(ctx.profile) >= TrophyHall.totalSlots(ctx.profile, ctx.config) then
				return false, "slots_full" -- the capacity constraint = the monetization lever (buy a slot / take one down)
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local tr = ArtifactStore.transition(ctx.profile, ctx.payload.artifactId, D.HELD, D.DISPLAYED)
			assert(tr.ok, "mount commit: authority verified HELD + trophy + capacity; CAS must succeed")
			if deps.telemetry ~= nil then
				deps.telemetry.incr("lodge.mount", 1)
			end
		end,
	}
end

-- ── take down: DISPLAYED → HELD (the take-down-to-trade handoff; trading owns escrow, Step 12) ───────────
function M.takeDownHandler(deps: DisplayDeps): Gauntlet.IntentHandler
	return {
		intent = "takeDownTrophy",
		critical = true,
		authority = function(ctx: Ctx): (boolean, string?)
			local id = ctx.payload.artifactId
			if type(id) ~= "string" then
				return false, "bad_payload"
			end
			local a = ctx.profile.artifacts[id]
			if a == nil then
				return false, "no_such_artifact"
			end
			if a.disposition ~= D.DISPLAYED then
				return false, "not_displayed"
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local tr = ArtifactStore.transition(ctx.profile, ctx.payload.artifactId, D.DISPLAYED, D.HELD)
			assert(tr.ok, "take-down commit: authority verified DISPLAYED; CAS must succeed")
			if deps.telemetry ~= nil then
				deps.telemetry.incr("lodge.takeDown", 1)
			end
		end,
	}
end

return M
