--!strict
local Harness = require("@tests/harness")
local Ledger = require("@src/server/ledger/Ledger")
local Fakes = require("@src/server/persistence/Fakes")
local Schema = require("@src/types/Schema")

local KEY = "p:1"

local function newCash(): Schema.Ledger
	return { checkpoint = { balance = 0, compactedCount = 0, lastEntryId = 0 }, tail = {} }
end
local function draft(ty: string, amount: number): Ledger.EntryDraft
	return { type = ty, amount = amount, validatingEventId = "ev" }
end

return function(t: Harness.T)
	t.section("Ledger — balance = checkpoint + Σ tail; entryId monotonic")
	do
		local cash = newCash()
		cash.checkpoint.balance = 500 -- compacted history
		local e1 = Ledger.applyEntry(cash, draft("kill", 100), 1)
		local e2 = Ledger.applyEntry(cash, draft("gear", -30), 2)
		t.eq("balance folds checkpoint + tail", Ledger.balanceOf(cash), 570)
		t.eq("entryId 1", e1.entryId, 1)
		t.eq("entryId 2", e2.entryId, 2)
	end

	t.section("Ledger — atomic debit cannot drive the balance negative (no-yield check+append)")
	do
		local cash = newCash()
		Ledger.applyEntry(cash, draft("faucet", 50), 1)
		local ok1 = Ledger.attemptDebit(cash, 30, { type = "gear", validatingEventId = "buy" }, 2)
		t.ok("a debit within balance succeeds", ok1.ok and Ledger.balanceOf(cash) == 20)
		local ok2 = Ledger.attemptDebit(cash, 100, { type = "gear", validatingEventId = "buy2" }, 3)
		t.ok("a debit beyond balance is rejected (insufficient_funds)", ok2.ok == false and ok2.reason == "insufficient_funds")
		t.eq("balance unchanged by the rejected debit", Ledger.balanceOf(cash), 20)
	end

	t.section("Ledger — PurchaseId idempotency (real-money exactly-once across redelivery)")
	do
		local cash = newCash()
		local redeemed: { [string]: boolean } = {}
		local c1 = Ledger.attemptRealMoneyCredit(redeemed, cash, "PID-1", 5000, "currencypack", 1)
		t.ok("first credit applies", c1.ok and c1.alreadyGranted == false and Ledger.balanceOf(cash) == 5000)
		local c2 = Ledger.attemptRealMoneyCredit(redeemed, cash, "PID-1", 5000, "currencypack", 2) -- redelivery
		t.ok("redelivered PurchaseId is a no-op, success returned (Roblox stops re-delivering)", c2.ok and c2.alreadyGranted == true)
		t.eq("balance NOT doubled (exactly-once)", Ledger.balanceOf(cash), 5000)
	end

	t.section("Ledger — compaction offloads to the audit log + preserves balance")
	do
		local cash = newCash()
		for i = 1, 10 do
			Ledger.applyEntry(cash, draft("kill", 10), i)
		end -- balance 100, 10 entries
		local audit = Fakes.newAuditLog()
		local before = Ledger.balanceOf(cash)
		local r = Ledger.compact(cash, 4, audit, KEY)
		t.eq("moved 6 entries (n − keepTail)", r.moved, 6)
		t.eq("tail trimmed to keepTail", #cash.tail, 4)
		t.eq("balance preserved across the fold", Ledger.balanceOf(cash), before)
		t.eq("checkpoint absorbed the folded amounts", cash.checkpoint.balance, 60)
		t.eq("compactedCount advanced", cash.checkpoint.compactedCount, 6)
		t.eq("the audit log holds the offloaded entries", #audit.read(KEY), 6)
	end

	t.section("Ledger — PurchaseId idempotency SURVIVES compaction (persistent set, not entry-scan)")
	do
		local cash = newCash()
		local redeemed: { [string]: boolean } = {}
		Ledger.attemptRealMoneyCredit(redeemed, cash, "PID-X", 5000, "currencypack", 1)
		for i = 1, 20 do
			Ledger.applyEntry(cash, draft("kill", 1), i) -- bury the currency-pack entry
		end
		Ledger.compact(cash, 4, Fakes.newAuditLog(), KEY) -- folds the PID entry OUT of the tail
		local balAfter = Ledger.balanceOf(cash)
		local c = Ledger.attemptRealMoneyCredit(redeemed, cash, "PID-X", 5000, "currencypack", 99) -- redelivery
		t.ok("the redelivered PID is still a no-op after its entry was offloaded", c.alreadyGranted == true)
		t.eq("balance NOT re-credited post-compaction (exactly-once survives offload)", Ledger.balanceOf(cash), balAfter)
	end

	t.section("Ledger — lastEntryId survives compaction (no id reuse)")
	do
		local cash = newCash()
		for i = 1, 6 do
			Ledger.applyEntry(cash, draft("x", 1), i)
		end
		Ledger.compact(cash, 2, Fakes.newAuditLog(), KEY)
		local e = Ledger.applyEntry(cash, draft("y", 1), 99)
		t.eq("next entryId continues past compacted ids", e.entryId, 7)
	end
end
