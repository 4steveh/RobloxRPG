--!strict
-- Step 12 — THE atomic two-sided swap primitive (data-integrity §5; the rigor-critical core). All-or-nothing
-- over BOTH profiles: pre-validate EVERY CAS precondition before any mutation, then in ONE no-yield section
-- (PairTransaction) move each artifact (ArtifactStore.transferOwnership: live to new, tombstone old), apply
-- the Cash triple (tradepay-out / tradepay-in / tradetax), and write the two-sided trade record to both
-- tradeLogs. If ANY precondition fails → nothing mutates. If a save fails → both profiles revert. No artifact
-- is ever LIVE in two profiles; no item leaves one inventory until it enters the other. Trading INVOKES this;
-- it never inlines the atomic logic.

local Schema = require("../../types/Schema")
local Enums = require("../../types/Enums")
local Economy = require("../../logic/Economy")
local Ledger = require("../ledger/Ledger")
local ArtifactStore = require("../artifacts/ArtifactStore")
local PairTransaction = require("../authority/PairTransaction")
local Types = require("../persistence/Types")

type PlayerData = Schema.PlayerData
type Config = Schema.Config
local D = Enums.Disposition

local M = {}

export type SwapArgs = {
	aProfile: PlayerData,
	bProfile: PlayerData,
	aOwner: string,
	bOwner: string,
	aArtifactIds: { string },
	bArtifactIds: { string },
	payer: string, -- "a" | "b" | "none"
	cashGross: number,
	config: Config,
	idGen: Types.IdGenerator,
	now: number,
	saveA: () -> boolean,
	saveB: () -> boolean,
	telemetry: Types.Telemetry?,
}
export type SwapResult = { ok: boolean, reason: string?, tax: number? }

-- A read-only pre-check: every id is ESCROWED + owned + tradeable on `profile` (the CAS preconditions).
local function allEscrowed(profile: PlayerData, ids: { string }): boolean
	for _, id in ids do
		local a = profile.artifacts[id]
		if a == nil or a.tombstoned or a.disposition ~= D.ESCROWED or not a.tradeable or profile.inventory.artifactIds[id] ~= true then
			return false
		end
	end
	return true
end

function M.commit(args: SwapArgs): SwapResult
	-- ── PRE-VALIDATE everything BEFORE any mutation (so a failure transfers nothing). ──
	if (#args.aArtifactIds + #args.bArtifactIds) < 1 then
		return { ok = false, reason = "no_items" } -- |A.items| + |B.items| ≥ 1 (no raw-Cash channel)
	end
	if not allEscrowed(args.aProfile, args.aArtifactIds) then
		return { ok = false, reason = "precondition_failed" } -- A's side not all ESCROWED as expected (CAS)
	end
	if not allEscrowed(args.bProfile, args.bArtifactIds) then
		return { ok = false, reason = "precondition_failed" } -- B's side not all ESCROWED as expected (CAS)
	end
	local tax = Economy.tradeTax(args.config, args.cashGross)
	if args.cashGross > 0 then
		local payerProfile = if args.payer == "a" then args.aProfile elseif args.payer == "b" then args.bProfile else nil
		if payerProfile == nil then
			return { ok = false, reason = "bad_payer" }
		end
		if Ledger.balanceOf(payerProfile.cash) < args.cashGross then
			return { ok = false, reason = "insufficient_funds" }
		end
	end

	-- ── APPLY in ONE no-yield section over BOTH profiles; restore both on any save failure. ──
	local tradeId = args.idGen.next("trade")
	local run = PairTransaction.run(args.aProfile, args.bProfile, function(pa, pb)
		-- artifact legs: A's → B, B's → A (live to new, tombstone old). Pre-validated, no yield → assert ok.
		for _, id in args.aArtifactIds do
			assert(ArtifactStore.transferOwnership(pa, pb, id, D.ESCROWED, args.bOwner).ok, "swap: A→B transfer must succeed (pre-validated)")
		end
		for _, id in args.bArtifactIds do
			assert(ArtifactStore.transferOwnership(pb, pa, id, D.ESCROWED, args.aOwner).ok, "swap: B→A transfer must succeed (pre-validated)")
		end
		-- Cash leg: payer −gross (tradepay-out); payee +gross (tradepay-in) then −tax (tradetax sink). Once.
		if args.cashGross > 0 then
			local payerProfile = if args.payer == "a" then pa else pb
			local payeeProfile = if args.payer == "a" then pb else pa
			local debit = Ledger.attemptDebit(payerProfile.cash, args.cashGross, { type = "tradepay-out", loop = "none", validatingEventId = tradeId }, args.now)
			assert(debit.ok, "swap: payer affordability pre-validated, no yield → debit must succeed")
			Ledger.applyEntry(payeeProfile.cash, { type = "tradepay-in", amount = args.cashGross, loop = "none", validatingEventId = tradeId }, args.now)
			if tax > 0 then
				Ledger.applyEntry(payeeProfile.cash, { type = "tradetax", amount = -tax, loop = "none", validatingEventId = tradeId }, args.now)
			end
		end
		-- the two-sided trade record → both tradeLogs (audit/rollback; the reconcile-on-reload substrate).
		local payerKey = if args.payer == "a" then args.aOwner elseif args.payer == "b" then args.bOwner else ""
		local record: Schema.TradeRecord = {
			tradeId = tradeId,
			partyA = args.aOwner,
			partyB = args.bOwner,
			aArtifactIds = table.clone(args.aArtifactIds),
			bArtifactIds = table.clone(args.bArtifactIds),
			payer = payerKey,
			cashGross = args.cashGross,
			tax = tax,
			timestamp = args.now,
		}
		table.insert(pa.tradeLog, record)
		table.insert(pb.tradeLog, (table.clone(record :: any) :: any))
	end, args.saveA, args.saveB)

	if not run.ok then
		return { ok = false, reason = run.reason }
	end
	if args.telemetry ~= nil then
		args.telemetry.incr("trade.completed", 1)
		args.telemetry.incr("trade.tax", tax)
	end
	return { ok = true, tax = tax }
end

return M
