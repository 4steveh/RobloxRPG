--!strict
-- MVL pre-launch integrity checks (SYS_data_integrity build-notes) — the headless subset. The trade
-- auto-revert and two-sided rollback checks (4 of 5) move to Step 12 (they need escrow).

local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local SessionService = require("@src/server/SessionService")
local ArtifactStore = require("@src/server/artifacts/ArtifactStore")
local Ledger = require("@src/server/ledger/Ledger")
local Transaction = require("@src/server/authority/Transaction")
local Balance = require("@src/logic/Balance")

return function(t: Harness.T)
	t.section("MVL integrity #1 — duped-rare across two concurrent sessions is rejected by the lock")
	do
		local ds = Fakes.newDataStore()
		local clock = Fakes.newClock(1000)
		local svcA = SessionService.new({ store = ds, clock = clock, config = Catalog, serverId = "serverA" })
		local svcB = SessionService.new({ store = ds, clock = clock, config = Catalog, serverId = "serverB" })
		local rA = SessionService.login(svcA, 42)
		t.ok("serverA logs the player in", rA.ok)
		local rB = SessionService.login(svcB, 42) -- same player, different server, A's lock is live
		t.ok("serverB CANNOT load the same player → cannot mint a duplicate rare", rB.ok == false and rB.reason == "locked")
	end

	t.section("MVL integrity #2 — multi-mutation transaction: a failed write leaves NO orphan")
	do
		local ds, ctl = Fakes.newDataStore()
		local clock = Fakes.newClock(1000)
		local svc = SessionService.new({ store = ds, clock = clock, config = Catalog, serverId = "serverA" })
		local login = SessionService.login(svc, 7)
		local session = assert(login.session)
		local p = session.profile
		local idGen = Fakes.newIdGenerator()
		local tailBefore = #p.cash.tail

		ctl.failNextN(20) -- every save attempt fails (exhausts retries)
		-- a synthetic reward pipeline committed as ONE unit: mint + ledger entry + conquest flag, then write-through
		local txn = Transaction.run(p, function()
			ArtifactStore.mint(p, { kind = "trophy", tradeable = true, owner = "7", sourceId = "bayou_leviathan" }, idGen, 1001)
			Ledger.applyEntry(p.cash, { type = "kill", amount = 100, validatingEventId = "ev-1" }, 1001)
			p.conqueredDestinations["bayou"] = true
		end, function()
			return SessionService.saveNow(svc, 7)
		end)

		t.ok("the transaction reports failure", txn.ok == false)
		t.ok("NO orphaned artifact (in-memory reverted)", next(p.artifacts) == nil and next(p.inventory.artifactIds) == nil)
		t.eq("NO orphaned ledger entry (tail reverted)", #p.cash.tail, tailBefore)
		t.ok("NO orphaned conquest flag (reverted)", p.conqueredDestinations["bayou"] == nil)
		-- Non-vacuously prove the REVERT (not just the failed write) protects the durable store: clear the
		-- fault and save cleanly. This persists the reverted profile; if Transaction had NOT reverted, this
		-- successful save would orphan the artifact durably. So a no-artifact durable read here proves revert.
		ctl.failNextN(0)
		t.ok("a clean save after the revert succeeds", SessionService.saveNow(svc, 7))
		local stored = ctl.peek("profile:7")
		t.ok("the durable profile reflects the REVERTED state (no orphaned artifact persisted)", next(stored.data.artifacts) == nil)
	end

	t.section("MVL integrity #3 — idle cannot be double-claimed by a reconnect race")
	do
		local ds = Fakes.newDataStore()
		local clock, cc = Fakes.newClock(0)
		local svc = SessionService.new({ store = ds, clock = clock, config = Catalog, serverId = "serverA" })
		-- t=0 fresh login (no idle), clean logout at t=100
		SessionService.login(svc, 9)
		cc.set(100)
		SessionService.logout(svc, 9)
		-- return 2h later → idle credited once
		cc.set(100 + 2 * 3600)
		local r1 = SessionService.login(svc, 9)
		local bal1 = Balance.balanceOf(assert(r1.session).profile)
		t.ok("idle credited on the clean return", bal1 > 0)
		-- crash (no clean logout): the durable profile has sessionOpen=true. Re-login (same server re-acquires).
		cc.set(100 + 2 * 3600 + 31)
		local r2 = SessionService.login(svc, 9)
		local bal2 = Balance.balanceOf(assert(r2.session).profile)
		t.eq("the reconnect/crash re-login does NOT double idle (crash fallback ≈ 0)", bal2, bal1)
	end
end
