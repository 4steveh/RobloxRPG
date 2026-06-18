--!strict
-- THE SALVAGE FLOW (Step 8) — the data-integrity-critical Lodge piece. Salvaging a trophy is ONE atomic
-- operation: ArtifactStore.transition(id, HELD|DISPLAYED → SALVAGED) AND a Ledger credit of
-- Economy.salvageFloor(...), wrapped in the gauntlet's `critical` Transaction so BOTH commit or BOTH revert
-- (a forced save failure leaves the artifact un-salvaged and no Cash — the Step-6 no-orphan shape). The CAS
-- precondition is the race/double-spend defense and makes salvage IDEMPOTENT: salvaging an already-SALVAGED
-- (tombstoned) or concurrently-ESCROWED artifact fails the precondition → no double-credit, no double-
-- transition. SALVAGED is terminal. Server-authoritative: the client only names the artifact; the server
-- derives the floor from the artifact's own provenance (never a client-asserted amount).
--
-- This handler CALLS the §4 CAS + the salvage-floor formula — it reimplements neither (SYS_lodge_trophy).

local Schema = require("../../types/Schema")
local Economy = require("../../logic/Economy")
local Ledger = require("../ledger/Ledger")
local ArtifactStore = require("../artifacts/ArtifactStore")
local Gauntlet = require("../authority/Gauntlet")
local Enums = require("../../types/Enums")
local Types = require("../persistence/Types")

type Ctx = Gauntlet.Ctx
type Artifact = Schema.Artifact

local M = {}

local D = Enums.Disposition

export type SalvageDeps = { idGen: Types.IdGenerator, telemetry: Types.Telemetry? }

-- the two salvageable dispositions (a HELD or a DISPLAYED trophy; ESCROWED is locked in a live trade — §4).
local function salvageableFrom(a: Artifact): Enums.Disposition?
	if a.disposition == D.HELD or a.disposition == D.DISPLAYED then
		return a.disposition
	end
	return nil
end

function M.new(deps: SalvageDeps): Gauntlet.IntentHandler
	return {
		intent = "salvage",
		critical = true, -- the transition + the credit commit atomically (no orphan on a failed write)
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
				return false, "already_salvaged" -- idempotency: terminal SALVAGED has no exit
			end
			if a.kind ~= Enums.ArtifactKind.trophy then
				return false, "not_a_trophy" -- §4: SALVAGED is Trophy-only (dogs/mounts/boats live in their homes)
			end
			if salvageableFrom(a) == nil then
				return false, "not_salvageable" -- ESCROWED (a live trade) can't be salvaged
			end
			local sid = a.provenance.sourceId
			if sid == nil or ctx.config.targetIndex[sid] == nil then
				return false, "unresolvable_provenance" -- the floor is derived from the source; it must resolve
			end
			return true, nil
		end,
		commit = function(ctx: Ctx)
			local a = ctx.profile.artifacts[ctx.payload.artifactId]
			local from = assert(salvageableFrom(a), "salvage commit: authority verified salvageable + no yield")
			-- the §4 CAS — this is the un-display-then-salvage (DISPLAYED→SALVAGED) or HELD→SALVAGED, one edge.
			local tr = ArtifactStore.transition(ctx.profile, a.artifactId, from, D.SALVAGED)
			assert(tr.ok, "salvage commit: CAS must succeed (authority verified the precondition; nothing yields)")
			local idx = assert(ctx.config.targetIndex[a.provenance.sourceId :: string], "salvage commit: provenance verified in authority")
			local amount = Economy.salvageFloor(ctx.config, idx.tier, idx.rarity, idx.loop)
			Ledger.applyEntry(ctx.profile.cash, {
				type = "salvage", -- the §3 faucet/sink tag (a faucet: rare value realized at the low floor)
				amount = amount,
				tier = idx.tier,
				loop = idx.loop,
				validatingEventId = deps.idGen.next("salvage"),
			}, ctx.now)
			if deps.telemetry ~= nil then
				deps.telemetry.incr("lodge.salvage:" .. idx.rarity, 1)
			end
		end,
	}
end

return M
