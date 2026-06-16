--!strict
-- Step 4 (hunting) — the SHARED, loop-agnostic, atomic reward pipeline (the Step-2 substrate's first real
-- caller). Ambiance → zero · the Reward XOR (stub Payout → Ledger | ArtifactStore.mint) · weighted Rank XP
-- · idempotent conquest · the whole thing committing as ONE Transaction (a forced save failure leaves no
-- orphan). Step 5 (fishing) reuses this exact pipeline — only the per-loop descriptor branch is added.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local RewardPipeline = require("@src/server/combat/RewardPipeline")
local Transaction = require("@src/server/authority/Transaction")
local Balance = require("@src/logic/Balance")
local Enums = require("@src/types/Enums")

return function(t: Harness.T)
	local function newDeps(): RewardPipeline.PipelineDeps
		return { idGen = Fakes.newIdGenerator(), now = 1000, telemetry = Fakes.newTelemetry() }
	end
	local function huntEvent(targetId: string): RewardPipeline.KillEvent
		return { targetId = targetId, owner = "u1", validatingEventId = "kill:" .. targetId, loop = Enums.Loop.Hunting }
	end

	t.section("RewardPipeline — ambiance early-returns ZERO (no entry, XP, mint, or conquest)")
	do
		local p = Util.mkProfile(Catalog, {})
		local r = RewardPipeline.resolve(p, Catalog, huntEvent("bayou_great_egret"), newDeps())
		t.ok("ambiance flagged, zero cash, no mint/XP/conquest", r.ambiance and r.cash == 0 and r.mintedArtifactId == nil and r.rankXP == 0 and r.conquestNewlySet == false)
		t.eq("no ledger entry written", #p.cash.tail, 0)
		t.eq("hunter rank unchanged", p.hunterRankXP, 0)
		t.ok("no artifact minted", next(p.artifacts) == nil)
		t.ok("no conquest set", next(p.conqueredDestinations) == nil)
	end

	t.section("RewardPipeline — routine kill: ONE ledger entry (stub Payout) + Rank XP, no mint")
	do
		local p = Util.mkProfile(Catalog, {})
		local r = RewardPipeline.resolve(p, Catalog, huntEvent("bayou_wood_duck"), newDeps())
		t.eq("exactly one ledger entry", #p.cash.tail, 1)
		t.ok("entry amount = stub Payout (NOT the catalog cash range)", r.cash == RewardPipeline.stubPayout(Catalog, 1, "Common", "Hunting") and r.cash > 0)
		t.eq("balance reflects the payout", Balance.balanceOf(p), r.cash)
		t.ok("the ledger entry is a hunting 'kill' faucet", p.cash.tail[1].type == "kill" and p.cash.tail[1].loop == "Hunting")
		t.ok("Hunter Rank XP awarded (active-play)", p.hunterRankXP > 0 and r.rankXP == p.hunterRankXP)
		t.ok("no artifact minted for a routine kill", r.mintedArtifactId == nil and next(p.artifacts) == nil)
	end

	t.section("RewardPipeline — RARE kill: ONE artifact mint + NO Cash (the Reward XOR)")
	do
		local p = Util.mkProfile(Catalog, {})
		local r = RewardPipeline.resolve(p, Catalog, huntEvent("bayou_white_alligator"), newDeps())
		local id = r.mintedArtifactId :: string
		t.ok("exactly one artifact minted", id ~= nil and p.artifacts[id] ~= nil and next(p.inventory.artifactIds) ~= nil)
		t.ok("artifact HELD, owner u1, provenance = source creature", p.artifacts[id].disposition == "HELD" and p.artifacts[id].owner == "u1" and p.artifacts[id].provenance.sourceId == "bayou_white_alligator")
		t.ok("NO Cash at mint (XOR holds — never both)", r.cash == 0 and #p.cash.tail == 0)
		t.ok("Rank XP still awarded for the rare", r.rankXP > 0)
		t.ok("the clean-kill content moment fires for a rare", r.cleanKillMoment ~= nil)
	end

	t.section("RewardPipeline — conquest on the alligator milestone is idempotent")
	do
		local p = Util.mkProfile(Catalog, {})
		local r1 = RewardPipeline.resolve(p, Catalog, huntEvent("bayou_american_alligator"), newDeps())
		t.ok("first gator kill sets the Bayou conquest (newly set)", r1.conquestNewlySet and p.conqueredDestinations.bayou == true)
		local r2 = RewardPipeline.resolve(p, Catalog, huntEvent("bayou_american_alligator"), newDeps())
		t.ok("re-killing does NOT re-trigger conquest (idempotent set membership)", r2.conquestNewlySet == false and p.conqueredDestinations.bayou == true)
		t.eq("re-kill still pays a second faucet entry; conquest is once-only", #p.cash.tail, 2)
	end

	t.section("RewardPipeline — the whole pipeline is ONE atomic Transaction (no orphan on save failure)")
	do
		-- routine + milestone: ledger + Rank XP + conquest must revert together
		local p = Util.mkProfile(Catalog, {})
		local txn = Transaction.run(p, function()
			RewardPipeline.resolve(p, Catalog, huntEvent("bayou_american_alligator"), newDeps())
		end, function()
			return false
		end)
		t.ok("transaction reports failure", txn.ok == false)
		t.eq("no orphan ledger entry", #p.cash.tail, 0)
		t.eq("no orphan Rank XP", p.hunterRankXP, 0)
		t.ok("no orphan conquest", next(p.conqueredDestinations) == nil)
	end
	do
		-- rare: the artifact mint must revert too
		local p = Util.mkProfile(Catalog, {})
		local txn = Transaction.run(p, function()
			RewardPipeline.resolve(p, Catalog, huntEvent("bayou_white_alligator"), newDeps())
		end, function()
			return false
		end)
		t.ok("transaction reports failure", txn.ok == false)
		t.ok("no orphan artifact (mint reverted)", next(p.artifacts) == nil and next(p.inventory.artifactIds) == nil)
		t.eq("no orphan Rank XP", p.hunterRankXP, 0)
	end
end
