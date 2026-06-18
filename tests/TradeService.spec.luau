--!strict
-- Step 12 — the trade flow state machine. Negotiation: request/accept (one-active-trade), setOffer validation
-- (owned + tradeable + HELD; no raw Cash), the terms-version re-arm; and confirm→commit: escrow on confirm,
-- the settle freeze, the atomic swap (TradeSwap), and escrow revert on every exit. The 8 MVL pre-launch checks.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local Ledger = require("@src/server/ledger/Ledger")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local TradeService = require("@src/server/trading/TradeService")

return function(t: Harness.T)
	-- ONE shared mint generator → globally-distinct artifact ids (a fresh generator per mint would collide).
	local mintGen = Fakes.newIdGenerator()
	-- a world of two players keyed "u1"/"u2", each a profile; getProfile/saveProfile injected.
	local function world(saveOk: boolean)
		local profiles: { [string]: any } = { u1 = Util.mkProfile(Catalog, { ledger = { 5000 } }), u2 = Util.mkProfile(Catalog, { ledger = { 5000 } }) }
		local svc = TradeService.new({
			config = Catalog, idGen = Fakes.newIdGenerator(), telemetry = Fakes.newTelemetry(),
			getProfile = function(k) return profiles[k] end,
			saveProfile = function(_) return saveOk end,
		})
		return svc, profiles
	end
	local function mintHeld(p: any, key: string, sourceId: string): string
		return ArtifactStore.mint(p, { kind = "trophy", tradeable = true, owner = key, sourceId = sourceId, validatingEventId = "ev" }, mintGen, 1).artifactId
	end
	-- get-trade as `any` (the public get returns PendingTrade?; tests know it exists and index it directly).
	local function get(svc: any, tid: string): any
		return TradeService.get(svc, tid)
	end

	t.section("TradeService — request + accept + one-active-trade (check 8)")
	do
		local svc, profiles = world(true)
		local r = TradeService.request(svc, "u1", "u2", 100)
		t.ok("request opens a REQUESTED trade", r.ok and r.tradeId ~= nil)
		t.eq("state REQUESTED", get(svc, r.tradeId :: string).state, "REQUESTED")
		t.ok("u1 can't open a second trade", TradeService.request(svc, "u1", "u2", 100).ok == false)
		t.ok("u2 (the requestee) can't open a second either", TradeService.request(svc, "u2", "u1", 100).ok == false)
		local acc = TradeService.accept(svc, "u2", r.tradeId :: string, 100)
		t.ok("accept → BUILDING", acc.ok and get(svc, r.tradeId :: string).state == "BUILDING")
	end

	t.section("TradeService — setOffer validates ownership + tradeable + HELD; DISPLAYED/unknown rejected (checks 4,5)")
	do
		local svc, profiles = world(true)
		local a1 = mintHeld(profiles.u1, "u1", "bayou_white_alligator")
		local r = TradeService.request(svc, "u1", "u2", 100)
		local tid = r.tradeId :: string
		TradeService.accept(svc, "u2", tid, 100)
		t.ok("u1 can offer its own HELD tradeable artifact", TradeService.setOffer(svc, "u1", tid, { a1 }, 0, 100).ok)
		t.ok("u2 can't offer u1's artifact (not owned)", TradeService.setOffer(svc, "u2", tid, { a1 }, 0, 100).ok == false)
		local a2 = mintHeld(profiles.u1, "u1", "bayou_leviathan")
		assert(ArtifactStore.transition(profiles.u1, a2, "HELD", "DISPLAYED").ok)
		t.ok("a DISPLAYED trophy can't be offered until un-displayed (check 4)", TradeService.setOffer(svc, "u1", tid, { a1, a2 }, 0, 100).ok == false)
		t.ok("an unknown artifact id is rejected", TradeService.setOffer(svc, "u1", tid, { "nope" }, 0, 100).ok == false)
	end

	t.section("TradeService — the terms-version increments on every offer change (re-arm substrate)")
	do
		local svc, profiles = world(true)
		local a1 = mintHeld(profiles.u1, "u1", "bayou_white_alligator")
		local r = TradeService.request(svc, "u1", "u2", 100)
		local tid = r.tradeId :: string
		TradeService.accept(svc, "u2", tid, 100)
		local v0 = get(svc, tid).version
		TradeService.setOffer(svc, "u1", tid, { a1 }, 0, 100)
		t.ok("version increments on an offer change", get(svc, tid).version > v0)
		local v1 = get(svc, tid).version
		TradeService.setOffer(svc, "u1", tid, { a1 }, 250, 100) -- set Cash → another change
		t.ok("version increments again on a Cash change", get(svc, tid).version > v1)
	end

	-- drive a full trade to built (both offers set, BUILDING); returns svc/profiles/tid/a1/b1.
	local function builtTrade(saveOk: boolean)
		local svc, profiles = world(saveOk)
		local a1 = mintHeld(profiles.u1, "u1", "bayou_white_alligator")
		local b1 = mintHeld(profiles.u2, "u2", "bayou_leviathan")
		local r = TradeService.request(svc, "u1", "u2", 100)
		local tid = r.tradeId :: string
		TradeService.accept(svc, "u2", tid, 100)
		TradeService.setOffer(svc, "u1", tid, { a1 }, 1000, 100) -- u1: item + 1000 Cash
		TradeService.setOffer(svc, "u2", tid, { b1 }, 0, 100) -- u2: item
		return svc, profiles, tid, a1, b1
	end
	local function freed(svc: any): boolean
		return TradeService.request(svc, "u1", "u2", 999).ok -- both must be free to open a new one
	end

	t.section("TradeService — confirm escrows the side; both-confirm → settle; commit runs the swap (happy path)")
	do
		local svc, profiles, tid, a1, b1 = builtTrade(true)
		local v = get(svc, tid).version
		t.ok("u1 confirm escrows a1 (HELD→ESCROWED)", TradeService.confirm(svc, "u1", tid, v, 100).ok and profiles.u1.artifacts[a1].disposition == "ESCROWED")
		t.eq("state A_CONFIRMED", get(svc, tid).state, "A_CONFIRMED")
		t.ok("u2 confirm escrows b1 + opens the settle window", TradeService.confirm(svc, "u2", tid, v, 100).ok and profiles.u2.artifacts[b1].disposition == "ESCROWED")
		t.eq("state COMMITTING (both confirmed, settling)", get(svc, tid).state, "COMMITTING")
		t.ok("commit blocked during the settle freeze", TradeService.tryCommit(svc, tid, 101).ok == false)
		local r = TradeService.tryCommit(svc, tid, 100 + Catalog.tuning.persistence.commitSettleSeconds)
		t.ok("commit succeeds → COMPLETE", r.ok and get(svc, tid).state == "COMPLETE")
		t.ok("a1 LIVE in u2, tombstone in u1", profiles.u2.artifacts[a1].owner == "u2" and profiles.u2.inventory.artifactIds[a1] == true and profiles.u1.artifacts[a1].tombstoned == true)
		t.ok("b1 LIVE in u1, tombstone in u2", profiles.u1.artifacts[b1].owner == "u1" and profiles.u1.inventory.artifactIds[b1] == true and profiles.u2.artifacts[b1].tombstoned == true)
		t.eq("u1 paid 1000 (5000→4000)", Ledger.balanceOf(profiles.u1.cash), 4000)
		t.eq("u2 got 950 (1000 − 50 tax) (5000→5950)", Ledger.balanceOf(profiles.u2.cash), 5950)
		t.ok("both players freed after completion", freed(svc))
	end

	t.section("TradeService — check 1: re-arm while confirmed clears BOTH confirms + reverts escrow; stale-version confirm rejected")
	do
		local svc, profiles, tid, a1, b1 = builtTrade(true)
		local v = get(svc, tid).version
		TradeService.confirm(svc, "u1", tid, v, 100) -- u1 confirmed → a1 ESCROWED
		t.ok("a1 escrowed by the confirm", profiles.u1.artifacts[a1].disposition == "ESCROWED")
		TradeService.setOffer(svc, "u2", tid, { b1 }, 50, 100) -- u2 changes → re-arm
		t.eq("back to BUILDING", get(svc, tid).state, "BUILDING")
		t.ok("u1's confirm cleared", get(svc, tid).offers.u1.confirmed == false)
		t.ok("a1's escrow reverted ESCROWED→HELD", profiles.u1.artifacts[a1].disposition == "HELD")
		t.ok("the version bumped", get(svc, tid).version > v)
		t.ok("stale-version confirm rejected", TradeService.confirm(svc, "u1", tid, v, 100).ok == false)
	end

	t.section("TradeService — check 2: disconnect auto-cancels with full escrow revert")
	do
		local svc, profiles, tid, a1, b1 = builtTrade(true)
		local v = get(svc, tid).version
		TradeService.confirm(svc, "u1", tid, v, 100) -- a1 escrowed
		TradeService.onDisconnect(svc, "u2", 100)
		t.eq("trade CANCELLED", get(svc, tid).state, "CANCELLED")
		t.ok("a1 escrow reverted", profiles.u1.artifacts[a1].disposition == "HELD")
		t.ok("both freed", freed(svc))
	end

	t.section("TradeService — check 6: a pure-Cash trade cannot be committed")
	do
		local svc, profiles = world(true)
		local r = TradeService.request(svc, "u1", "u2", 100)
		local tid = r.tradeId :: string
		TradeService.accept(svc, "u2", tid, 100)
		TradeService.setOffer(svc, "u1", tid, {}, 1000, 100) -- Cash only, no items
		TradeService.setOffer(svc, "u2", tid, {}, 0, 100)
		local v = get(svc, tid).version
		TradeService.confirm(svc, "u1", tid, v, 100)
		TradeService.confirm(svc, "u2", tid, v, 100)
		local cr = TradeService.tryCommit(svc, tid, 100 + Catalog.tuning.persistence.commitSettleSeconds)
		t.ok("pure-Cash commit rejected (|items| ≥ 1)", cr.ok == false)
		t.eq("no Cash moved", Ledger.balanceOf(profiles.u1.cash), 5000)
	end

	t.section("TradeService — check 7: tax taken exactly once on commit, never on cancel/re-arm")
	do
		local svc, profiles, tid, a1, b1 = builtTrade(true)
		local v = get(svc, tid).version
		TradeService.confirm(svc, "u1", tid, v, 100)
		TradeService.cancel(svc, "u1", tid, 100) -- cancel before commit
		t.eq("no tax on a cancelled trade — u2 balance unchanged", Ledger.balanceOf(profiles.u2.cash), 5000)
		t.eq("no tradetax entry anywhere on u2", (function()
			local n = 0
			for _, e in profiles.u2.cash.tail do
				if e.type == "tradetax" then
					n += 1
				end
			end
			return n
		end)(), 0)
	end

	t.section("TradeService — check 3: a forced CAS mismatch at commit transfers nothing, reverts to CANCELLED")
	do
		local svc, profiles, tid, a1, b1 = builtTrade(true)
		local v = get(svc, tid).version
		TradeService.confirm(svc, "u1", tid, v, 100)
		TradeService.confirm(svc, "u2", tid, v, 100)
		-- force a CAS mismatch: yank a1 out of ESCROWED behind the swap's back
		assert(ArtifactStore.transition(profiles.u1, a1, "ESCROWED", "HELD").ok)
		local cr = TradeService.tryCommit(svc, tid, 100 + Catalog.tuning.persistence.commitSettleSeconds)
		t.ok("commit fails on the CAS mismatch", cr.ok == false)
		t.eq("trade → CANCELLED", get(svc, tid).state, "CANCELLED")
		t.ok("nothing transferred: b1 still u2's, a1 not in u2", profiles.u2.artifacts[b1] ~= nil and profiles.u2.inventory.artifactIds[b1] == true and profiles.u2.artifacts[a1] == nil)
	end

	t.section("TradeService — final-terms projection is server-sourced (canonical name/rarity, gross/tax/net)")
	do
		local svc, profiles, tid, a1, b1 = builtTrade(true)
		local proj: any = TradeService.projection(svc, tid)
		t.ok("projection exists with state + version", proj ~= nil and proj.state == "BUILDING" and proj.version ~= nil)
		t.eq("gross Cash from u1's side", proj.gross, 1000)
		t.eq("tax = 50 (server-computed, not client)", proj.tax, 50)
		t.eq("net = 950", proj.net, 950)
		t.ok("a1's offered identity is the canonical Catalog name (server-sourced)", (function()
			for _, it in proj.offers.u1.items do
				if it.artifactId == a1 then
					return it.name == Catalog.creatures.bayou_white_alligator.name and it.rarity == Catalog.creatures.bayou_white_alligator.rarity
				end
			end
			return false
		end)())
	end
end
