--!strict
-- THE CASH LEDGER as a live store (§3). Cash is an append-only sequence; balance is DERIVED
-- (checkpoint + Σ tail), never a stored mutable int. Every primitive here is a NO-YIELD critical section
-- (compute-then-append synchronously); the per-player session is the serialization point, so the balance
-- can never go negative and no concurrent debit double-spends. Faucet/sink OPERATIONS are Step 6 — they
-- call applyEntry / attemptDebit. Real-money receipt wiring is Step 14 — it calls attemptRealMoneyCredit.

local Schema = require("../../types/Schema")
local Types = require("../persistence/Types")

type Ledger = Schema.Ledger
type LedgerEntry = Schema.LedgerEntry
type AuditSink = Types.AuditSink

local M = {}

export type EntryDraft = {
	type: string,
	amount: number,
	tier: number?,
	loop: Schema.LedgerLoop?,
	validatingEventId: string,
	realMoneyTag: string?,
}
export type SinkMeta = { type: string, tier: number?, loop: Schema.LedgerLoop?, validatingEventId: string }
export type DebitResult = { ok: boolean, entry: LedgerEntry?, reason: string? }
export type CreditResult = { ok: boolean, entry: LedgerEntry?, alreadyGranted: boolean }

-- balance = checkpoint (compacted history) + Σ(tail). The single derived truth.
function M.balanceOf(cash: Ledger): number
	local sum = cash.checkpoint.balance
	for _, e in cash.tail do
		sum += e.amount
	end
	return sum
end

-- Monotonic per-player entryId source. lastEntryId survives compaction (the high-water mark).
local function mintEntryId(cash: Ledger): number
	cash.checkpoint.lastEntryId += 1
	return cash.checkpoint.lastEntryId
end

-- Append a faucet/sink entry. NO-YIELD: mint id + push. (Use attemptDebit for sinks so the balance check
-- is part of the same critical section.)
function M.applyEntry(cash: Ledger, draft: EntryDraft, now: number): LedgerEntry
	local entry: LedgerEntry = {
		entryId = mintEntryId(cash),
		type = draft.type,
		amount = draft.amount,
		tier = draft.tier,
		loop = draft.loop,
		timestamp = now,
		validatingEventId = draft.validatingEventId,
		realMoneyTag = draft.realMoneyTag,
	}
	table.insert(cash.tail, entry)
	return entry
end

-- Atomic debit (§3 atomicity guarantee). NO-YIELD: compute balance → verify ≥ cost → append the
-- negative entry. Nothing yields between the check and the append, so the balance can never go negative.
function M.attemptDebit(cash: Ledger, cost: number, meta: SinkMeta, now: number): DebitResult
	assert(cost >= 0, "attemptDebit: cost must be ≥ 0 (use applyEntry for faucets)")
	if M.balanceOf(cash) < cost then
		return { ok = false, reason = "insufficient_funds" }
	end
	local entry = M.applyEntry(cash, {
		type = meta.type,
		amount = -cost,
		tier = meta.tier,
		loop = meta.loop,
		validatingEventId = meta.validatingEventId,
	}, now)
	return { ok = true, entry = entry }
end

-- Real-money credit, idempotent on the Roblox PurchaseId (§3 — closes the receipt-redelivery free-money
-- dupe). NO-YIELD: check the redeemed-token SET first; if present, no-op (already granted) and the caller
-- returns success so Roblox stops re-delivering. The validatingEventId IS the PurchaseId.
--   DELIBERATE DIVERGENCE FROM §3's LITERAL WORDING (safer): §3 says "check that no existing ENTRY carries
--   that PurchaseId". Scanning ledger entries would re-open the dupe after compaction offloads the
--   currency-pack entry out of the tail. We instead key off the PERSISTENT `redeemedPurchaseIds` set,
--   which compaction never touches — exactly-once survives offload. (Tested in Ledger.spec.)
function M.attemptRealMoneyCredit(
	redeemed: { [string]: boolean },
	cash: Ledger,
	purchaseId: string,
	amount: number,
	productType: string,
	now: number
): CreditResult
	if redeemed[purchaseId] then
		return { ok = true, alreadyGranted = true }
	end
	redeemed[purchaseId] = true
	local entry = M.applyEntry(cash, {
		type = productType,
		amount = amount,
		validatingEventId = purchaseId,
		realMoneyTag = "realmoney:" .. productType,
	}, now)
	return { ok = true, entry = entry, alreadyGranted = false }
end

-- Checkpoint compaction (§3 Roblox concession). Fold the oldest tail entries into checkpoint.balance and
-- OFFLOAD them to the append-only audit log. A logged, validated fold: it asserts the derived balance is
-- unchanged, so it cannot silently alter balance. Keeps the profile under the DataStore key-size limit.
export type CompactResult = { moved: number }
function M.compact(cash: Ledger, keepTail: number, audit: AuditSink, playerKey: string): CompactResult
	local n = #cash.tail
	if n <= keepTail then
		return { moved = 0 }
	end
	local moveCount = n - keepTail
	local balanceBefore = M.balanceOf(cash)
	local moved: { LedgerEntry } = {}
	for i = 1, moveCount do
		local e = cash.tail[i]
		cash.checkpoint.balance += e.amount
		cash.checkpoint.compactedCount += 1
		table.insert(moved, e)
	end
	local newTail: { LedgerEntry } = {}
	for i = moveCount + 1, n do
		table.insert(newTail, cash.tail[i])
	end
	cash.tail = newTail
	audit.append(playerKey, moved) -- the deliberate separate append-only store (cannot desync destructively)
	assert(M.balanceOf(cash) == balanceBefore, "Ledger.compact: fold must preserve balance")
	return { moved = moveCount }
end

return M
