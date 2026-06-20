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
local Economy = require("@src/logic/Economy")
local Enums = require("@src/types/Enums")
local Monetization = require("@src/logic/Monetization")

return function(t: Harness.T)
	local function newDeps(): RewardPipeline.PipelineDeps
		return { idGen = Fakes.newIdGenerator(), now = 1000, telemetry = Fakes.newTelemetry() }
	end
	local function huntEvent(targetId: string): RewardPipeline.KillEvent
		return { targetId = targetId, owner = "u1", validatingEventId = "kill:" .. targetId, loop = Enums.Loop.Hunting }
	end
	local function fishEvent(targetId: string): RewardPipeline.KillEvent
		return { targetId = targetId, owner = "u1", validatingEventId = "catch:" .. targetId, loop = Enums.Loop.Fishing }
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
		t.ok("entry amount = the REAL economy Payout (NOT the catalog cash range)", r.cash == Economy.payout(Catalog, 1, "Common", "bayou", Enums.Loop.Hunting) and r.cash > 0)
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

	-- ── Step 5: the SAME pipeline, extended with the Fishing describe branch (not forked) ──
	t.section("RewardPipeline (fishing) — routine catch: ONE 'catch' ledger entry + Angler XP, no mint")
	do
		local p = Util.mkProfile(Catalog, {})
		local r = RewardPipeline.resolve(p, Catalog, fishEvent("bayou_bluegill"), newDeps())
		t.eq("exactly one ledger entry", #p.cash.tail, 1)
		t.ok("entry amount = the REAL economy Payout, tagged a fishing 'catch' faucet", r.cash == Economy.payout(Catalog, 1, "Common", "bayou", Enums.Loop.Fishing) and p.cash.tail[1].type == "catch" and p.cash.tail[1].loop == "Fishing")
		t.ok("ANGLER Rank XP awarded (not Hunter)", p.anglerRankXP > 0 and r.rankXP == p.anglerRankXP and p.hunterRankXP == 0)
		t.ok("no mint for a routine catch", r.mintedArtifactId == nil)
	end

	t.section("RewardPipeline (fishing) — RARE catch: ONE mint + NO Cash (the shared Reward XOR)")
	do
		local p = Util.mkProfile(Catalog, {})
		local r = RewardPipeline.resolve(p, Catalog, fishEvent("bayou_leviathan"), newDeps())
		t.ok("exactly one artifact minted (the Mythic Leviathan)", r.mintedArtifactId ~= nil and p.artifacts[r.mintedArtifactId :: string] ~= nil)
		t.ok("NO Cash at mint, Angler XP awarded, clean-catch moment fires", r.cash == 0 and #p.cash.tail == 0 and r.rankXP > 0 and r.cleanKillMoment ~= nil)
	end

	t.section("RewardPipeline — the OR-gate: hunting AND fishing share ONE idempotent Bayou conquest flag")
	do
		-- conquer via the gator, then catch the Blue Catfish — the SAME flag, not re-triggered
		local p = Util.mkProfile(Catalog, {})
		local g = RewardPipeline.resolve(p, Catalog, huntEvent("bayou_american_alligator"), newDeps())
		t.ok("the gator kill conquers the Bayou (newly set)", g.conquestNewlySet and p.conqueredDestinations.bayou == true)
		local b = RewardPipeline.resolve(p, Catalog, fishEvent("bayou_blue_catfish"), newDeps())
		t.ok("then catching the Blue Catfish does NOT re-trigger conquest (one shared flag, idempotent)", b.conquestNewlySet == false and p.conqueredDestinations.bayou == true)
		-- reverse order: catch first, then hunt — still once-only
		local p2 = Util.mkProfile(Catalog, {})
		local b2 = RewardPipeline.resolve(p2, Catalog, fishEvent("bayou_blue_catfish"), newDeps())
		t.ok("catching the Blue Catfish FIRST conquers the Bayou (the OR-gate's fishing route)", b2.conquestNewlySet and p2.conqueredDestinations.bayou == true)
		local g2 = RewardPipeline.resolve(p2, Catalog, huntEvent("bayou_american_alligator"), newDeps())
		t.ok("then the gator kill does NOT re-trigger (conquering via EITHER loop is enough)", g2.conquestNewlySet == false and p2.conqueredDestinations.bayou == true)
	end

	t.section("RewardPipeline (fishing) — a rare catch is atomic (forced save failure → no orphan)")
	do
		local p = Util.mkProfile(Catalog, {})
		local txn = Transaction.run(p, function()
			RewardPipeline.resolve(p, Catalog, fishEvent("bayou_leviathan"), newDeps())
		end, function()
			return false
		end)
		t.ok("transaction reports failure", txn.ok == false)
		t.ok("no orphan mint / Angler XP", next(p.artifacts) == nil and p.anglerRankXP == 0)
	end

	t.section("RewardPipeline — weather TRAIT bonus (Cash branch, separable, reconciliation-safe)")
	do
		local p = Util.mkProfile(Catalog, {})
		local base = Economy.payout(Catalog, 1, "Common", "bayou", Enums.Loop.Hunting)
		local expectedBonus = Monetization.boostBonus(base, Economy.traitStackMultiplier(Catalog, { Enums.Trait.stormTouched }))
		local ev = huntEvent("bayou_wood_duck")
		ev.traits = { Enums.Trait.stormTouched }
		local r = RewardPipeline.resolve(p, Catalog, ev, newDeps())
		t.eq("two ledger entries: base + trait", #p.cash.tail, 2)
		t.ok("base entry is the UNMULTIPLIED kill faucet", p.cash.tail[1].type == "kill" and p.cash.tail[1].amount == base and p.cash.tail[1].loop == "Hunting")
		t.ok("trait entry is loop=none, type=traitBonus", p.cash.tail[2].type == "traitBonus" and p.cash.tail[2].loop == "none" and p.cash.tail[2].amount == expectedBonus)
		t.eq("result.cash = base + traitBonus", r.cash, base + expectedBonus)
		t.eq("result.traitCash = the bonus", r.traitCash, expectedBonus)
	end

	t.section("RewardPipeline — trait stacking; rare immunity; no-trait parity")
	do
		local pr = Util.mkProfile(Catalog, {})
		local re = huntEvent("bayou_white_alligator")
		re.traits = { Enums.Trait.stormTouched, Enums.Trait.moonlit }
		local rr = RewardPipeline.resolve(pr, Catalog, re, newDeps())
		t.ok("rare+traits: mints, cash=0, traitCash=0, NO ledger entry (XOR holds)", rr.mintedArtifactId ~= nil and rr.cash == 0 and rr.traitCash == 0 and #pr.cash.tail == 0)
		local pn = Util.mkProfile(Catalog, {})
		local rn = RewardPipeline.resolve(pn, Catalog, huntEvent("bayou_wood_duck"), newDeps())
		t.ok("no traits -> single entry, traitCash 0 (regression)", #pn.cash.tail == 1 and rn.traitCash == 0)
	end

end
