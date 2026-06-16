--!strict
local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Fakes = require("@src/server/persistence/Fakes")
local ProfileStore = require("@src/server/persistence/ProfileStore")

local KEY = "profile:1"
local TIMEOUT = 30
local OPTS: ProfileStore.SaveOpts = { maxAttempts = 3 }

return function(t: Harness.T)
	t.section("ProfileStore — session lock acquire / reject / heartbeat-gated steal")

	do -- acquire on a fresh key
		local ds = Fakes.newDataStore()
		local a = ProfileStore.acquireLock(ds, KEY, "serverA", 100, TIMEOUT)
		t.ok("serverA acquires the lock", a.ok)
		t.ok("fresh key → no durable data (caller uses freshProfile)", a.data == nil)
	end

	do -- second server rejected while A's lock is live
		local ds = Fakes.newDataStore()
		ProfileStore.acquireLock(ds, KEY, "serverA", 100, TIMEOUT)
		local b = ProfileStore.acquireLock(ds, KEY, "serverB", 110, TIMEOUT) -- 10s later, A still fresh
		t.ok("serverB rejected while A's lock is live (the concurrent-session defense)", b.ok == false and b.reason == "locked")
	end

	do -- steal a STALE lock (no heartbeat past timeout)
		local ds = Fakes.newDataStore()
		ProfileStore.acquireLock(ds, KEY, "serverA", 100, TIMEOUT)
		local b = ProfileStore.acquireLock(ds, KEY, "serverB", 131, TIMEOUT) -- A went dark; 31s > timeout
		t.ok("serverB steals a stale (dead-server) lock", b.ok)
	end

	do -- a LIVE, heartbeating lock is NEVER stolen (the load-bearing guarantee)
		local ds = Fakes.newDataStore()
		ProfileStore.acquireLock(ds, KEY, "serverA", 100, TIMEOUT)
		t.ok("serverA refreshes its heartbeat", ProfileStore.heartbeat(ds, KEY, "serverA", 125))
		local b = ProfileStore.acquireLock(ds, KEY, "serverB", 150, TIMEOUT) -- 25s since last heartbeat (< 30)
		t.ok("serverB CANNOT steal a live lock (heartbeat-gated, never pure-timeout)", b.ok == false and b.reason == "locked")
	end

	t.section("ProfileStore — save guarded by lock ownership + retry/revert (§7)")

	do -- a save by a server that LOST the lock is rejected (must not overwrite the new owner)
		local ds = Fakes.newDataStore()
		ProfileStore.acquireLock(ds, KEY, "serverA", 100, TIMEOUT)
		ProfileStore.acquireLock(ds, KEY, "serverB", 131, TIMEOUT) -- B steals the stale lock
		local p = Util.mkProfile(Catalog, {})
		local r = ProfileStore.save(ds, KEY, "serverA", p, 132, OPTS)
		t.ok("serverA's save is rejected after losing the lock", r.ok == false and r.reason == "lock_lost")
	end

	do -- retry exhaustion leaves the durable value intact (no corruption)
		local ds, ctl = Fakes.newDataStore()
		ProfileStore.acquireLock(ds, KEY, "serverA", 100, TIMEOUT)
		local v0 = Util.mkProfile(Catalog, {})
		v0.hunterRankXP = 7
		t.ok("save V0 succeeds", ProfileStore.save(ds, KEY, "serverA", v0, 101, OPTS).ok)
		local v1 = Util.mkProfile(Catalog, {})
		v1.hunterRankXP = 999
		ctl.failNextN(5) -- every retry of the next save fails
		local r = ProfileStore.save(ds, KEY, "serverA", v1, 102, OPTS)
		t.ok("save fails after exhausting retries", r.ok == false and r.reason == "retry_exhausted")
		t.eq("attempts == maxAttempts", r.attempts, OPTS.maxAttempts)
		local stored = ctl.peek(KEY)
		t.eq("durable value is still V0 (reverted to last good; no partial write)", stored.data.hunterRankXP, 7)
	end

	do -- a clean release lets a second session load immediately
		local ds = Fakes.newDataStore()
		ProfileStore.acquireLock(ds, KEY, "serverA", 100, TIMEOUT)
		t.ok("serverA releases cleanly", ProfileStore.releaseLock(ds, KEY, "serverA"))
		local b = ProfileStore.acquireLock(ds, KEY, "serverB", 101, TIMEOUT) -- immediately, no timeout wait
		t.ok("serverB acquires immediately after a clean release", b.ok)
	end
end
