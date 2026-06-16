--!strict
local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Idle = require("@src/server/idle/Idle")

local HOUR = 3600

return function(t: Harness.T)
	t.section("Idle — single clamped entry; Cash-only (idle-proof progression)")
	do
		local p = Util.mkProfile(Catalog, {})
		p.logoutTimestamp = 1000 -- clean prior logout
		local r = Idle.creditOnLogin(p, Catalog, 1000 + 2 * HOUR, Idle.stubAmount) -- 2h offline
		t.ok("basis is the clean logout", r.basis == "clean_logout")
		t.eq("credited the stub amount for 2 hours", r.credited, 200) -- stub = floor(hours*100)
		t.eq("exactly one ledger entry", #p.cash.tail, 1)
		t.ok("the entry is idle-tagged", p.cash.tail[1].type == "idle")
		t.ok("session claimed (sessionOpen=true)", p.sessionOpen == true)
		t.eq("idle wrote NO Rank XP", p.hunterRankXP + p.anglerRankXP, 0)
		t.ok("idle set NO conquest flag", next(p.conqueredDestinations) == nil)
	end

	t.section("Idle — elapsed clamped to idleCapHours")
	do
		local p = Util.mkProfile(Catalog, {})
		p.logoutTimestamp = 1000
		local r = Idle.creditOnLogin(p, Catalog, 1000 + 100 * HOUR, Idle.stubAmount) -- 100h, over the 8h cap
		t.eq("hours clamped to idleCapHours (8)", r.hours, 8)
		t.eq("credited the capped amount", r.credited, 800)
	end

	t.section("Idle — reconnect race cannot double-credit")
	do
		local p = Util.mkProfile(Catalog, {})
		p.logoutTimestamp = 1000
		local now = 1000 + 2 * HOUR
		local r1 = Idle.creditOnLogin(p, Catalog, now, Idle.stubAmount)
		t.eq("first login credits", r1.credited, 200)
		p.lastSaveTimestamp = now -- the login write-through (SessionService does this) persists sessionOpen + idle
		local r2 = Idle.creditOnLogin(p, Catalog, now + 1, Idle.stubAmount) -- replay
		t.ok("the replay takes the crash path (sessionOpen already true)", r2.basis == "crash_fallback")
		t.eq("≈0 second credit (1s elapsed)", r2.credited, 0)
		t.eq("ledger still has exactly one idle entry (no double)", #p.cash.tail, 1)
	end

	t.section("Idle — hard-crash fallback under-credits vs the stale logout timestamp")
	do
		local p = Util.mkProfile(Catalog, {})
		p.sessionOpen = true -- a crashed prior session (never cleanly logged out)
		p.logoutTimestamp = 1000 -- STALE — using it would over-credit
		p.lastSaveTimestamp = 5000 -- the last autosave before the crash
		local r = Idle.creditOnLogin(p, Catalog, 5000 + 1 * HOUR, Idle.stubAmount)
		t.ok("uses the last-save basis (crash fallback)", r.basis == "crash_fallback")
		t.eq("credits only since last save (1h) — not since the stale logout (the safe under-credit)", r.credited, 100)
	end

	t.section("Idle — a brand-new profile gets no idle")
	do
		local p = Util.mkProfile(Catalog, {}) -- logoutTimestamp 0, sessionOpen false
		local r = Idle.creditOnLogin(p, Catalog, 9999, Idle.stubAmount)
		t.eq("fresh → 0 credited", r.credited, 0)
		t.ok("basis is fresh", r.basis == "fresh")
		t.eq("no ledger entry", #p.cash.tail, 0)
	end
end
