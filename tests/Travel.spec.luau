--!strict
-- Step 9 — gated fast-travel ENFORCEMENT. travelTo validates the target against the PERSISTED
-- unlockedDestinations set (NOT a live evaluateGate) — the gate-bypass guard. A locked target is rejected
-- server-side; an unlocked target resolves its teleportTarget for the Studio TeleportService to execute.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local DestinationService = require("@src/server/DestinationService")
local Ids = require("@src/types/Ids")

local D = Ids.Destination

return function(t: Harness.T)
	t.section("Travel — an UNLOCKED target succeeds and resolves its teleportTarget")
	do
		local p = Util.mkProfile(Catalog, {}) -- freshProfile-like: Bayou seeded as the requiredTier-0 root
		p.unlockedDestinations[D.Bayou] = true
		local r = DestinationService.travelTo(p, D.Bayou)
		t.ok("travel to the unlocked Bayou is allowed", r.ok)
		t.eq("the teleportTarget resolves", r.teleportTarget, Catalog.destinations[D.Bayou].teleportTarget)
	end

	t.section("Travel — a LOCKED target is rejected server-side (the gate-bypass guard)")
	do
		local p = Util.mkProfile(Catalog, {}) -- Appalachia NOT in the unlocked set
		local r = DestinationService.travelTo(p, D.Appalachia)
		t.ok("travel to a locked Destination is rejected", r.ok == false and r.reason == "locked")
		t.eq("no teleportTarget is handed back", r.teleportTarget, nil)
	end

	t.section("Travel — the guard reads the SET, not a live gate eval (can't bypass by being 'qualified')")
	do
		-- a player who WOULD pass evaluateGate for Appalachia (T2 + conquered Bayou) but whose unlock was
		-- never committed to the set cannot travel — the persisted set is the only travel authority.
		local qualified = Util.mkProfile(Catalog, { weapon = 2, armor = 2, conquered = { D.Bayou } })
		-- deliberately do NOT call commitUnlocks; the set stays empty for Appalachia.
		t.ok("being gate-qualified but not in the unlocked set still cannot travel", DestinationService.travelTo(qualified, D.Appalachia).ok == false)
		-- and conversely: in the set but now under-geared (gear sold) STILL travels (persisted truth).
		local unlockedThenSold = Util.mkProfile(Catalog, {})
		unlockedThenSold.unlockedDestinations[D.Appalachia] = true -- committed earlier
		t.ok("in the set but no longer gate-qualified STILL travels (persisted truth)", DestinationService.travelTo(unlockedThenSold, D.Appalachia).ok)
	end

	t.section("Travel — an unknown DestinationId is rejected")
	do
		local p = Util.mkProfile(Catalog, {})
		t.ok("an unknown id is rejected", DestinationService.travelTo(p, "no_such_place").ok == false)
	end
end
