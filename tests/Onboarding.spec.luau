--!strict
-- Step 7 (onboarding funnel) — the server-owned, data-driven tutorial state machine: beats advance only on
-- authoritative events, COMPLETE is one-shot/idempotent, WORLD_MAP is pass-through (Step 9 swaps it), and
-- the first-spawn ELIGIBILITY predicate encodes the no-low-tier-farming-leak guarantee. The felt FTUE
-- (arrows, pings, "+Cash" juice, pacing) and every D1 metric are Studio/telemetry, not here.

local Harness = require("@tests/harness")
local Util = require("@tests/util")
local Catalog = require("@src/config/Catalog")
local Onboarding = require("@src/logic/Onboarding")
local Enums = require("@src/types/Enums")

return function(t: Harness.T)
	local H, F = Enums.Loop.Hunting, Enums.Loop.Fishing

	t.section("Onboarding — the beat chain advances on authoritative events (WORLD_MAP pass-through)")
	do
		local p = Util.mkProfile(Catalog, {}) -- begins FIRST_HUNT
		Onboarding.advance(p, "kill", 10)
		t.eq("a kill → FIRST_CATCH", p.onboarding.funnelBeat, "FIRST_CATCH")
		Onboarding.advance(p, "catch", 20)
		t.eq("a catch → FIRST_PURCHASE", p.onboarding.funnelBeat, "FIRST_PURCHASE")
		Onboarding.advance(p, "gearUpgrade", 30)
		t.eq("a gearUpgrade → LOOP_CONFIRM (WORLD_MAP passed through — Step 9 makes it real)", p.onboarding.funnelBeat, "LOOP_CONFIRM")
		t.ok("beatStartedAt tracks the transition time (dwell telemetry)", p.onboarding.beatStartedAt == 30)
		Onboarding.advance(p, "kill", 40)
		Onboarding.advance(p, "catch", 50)
		t.eq("LOOP_CONFIRM needs 3 loop actions — still confirming after 2", p.onboarding.funnelBeat, "LOOP_CONFIRM")
		Onboarding.advance(p, "kill", 60)
		t.eq("the 3rd loop action → DAILY_INTRO", p.onboarding.funnelBeat, "DAILY_INTRO")
		t.ok("not COMPLETE yet (completedAt unset)", p.onboarding.completedAt == nil)
		Onboarding.advance(p, "dailyClaim", 70)
		t.eq("the daily claim → COMPLETE", p.onboarding.funnelBeat, "COMPLETE")
		t.ok("completedAt stamped at COMPLETE", p.onboarding.completedAt == 70)
	end

	t.section("Onboarding — a mismatched event does not advance the beat (hunt-first ordering)")
	do
		local p = Util.mkProfile(Catalog, {})
		Onboarding.advance(p, "catch", 10) -- FIRST_HUNT wants a kill, not a catch
		t.eq("a catch during FIRST_HUNT does not advance", p.onboarding.funnelBeat, "FIRST_HUNT")
	end

	t.section("Onboarding — idempotent one-shot: a returning (COMPLETE) player never re-enters")
	do
		local p = Util.mkProfile(Catalog, {})
		for _, e in { "kill", "catch", "gearUpgrade", "kill", "catch", "kill", "dailyClaim" } do
			Onboarding.advance(p, e, 100)
		end
		t.eq("reached COMPLETE", p.onboarding.funnelBeat, "COMPLETE")
		local stampedAt = p.onboarding.completedAt
		Onboarding.advance(p, "kill", 200) -- a post-completion kill
		t.eq("a post-COMPLETE event does not re-enter the funnel", p.onboarding.funnelBeat, "COMPLETE")
		t.ok("completedAt is unchanged (no re-grant)", p.onboarding.completedAt == stampedAt)
	end

	t.section("Onboarding — isOnboardingComplete gates real-money (false through the funnel, true at COMPLETE)")
	do
		local p = Util.mkProfile(Catalog, {})
		t.ok("a first-time player is NOT complete (no store / real-money UI)", Onboarding.isOnboardingComplete(p) == false)
		for _, e in { "kill", "catch", "gearUpgrade", "kill", "catch", "kill", "dailyClaim" } do
			Onboarding.advance(p, e, 1)
		end
		t.ok("after the chain, onboarding IS complete (Step 14's store may now surface)", Onboarding.isOnboardingComplete(p))
	end

	t.section("Onboarding — firstSpawnEligible is tightly scoped (the no-farming-leak guarantee)")
	do
		local fresh = Util.mkProfile(Catalog, {}) -- FIRST_HUNT
		t.ok("first-time player, arrival hunt area, FIRST_HUNT → eligible", Onboarding.firstSpawnEligible(Catalog, fresh, "bayou", "sunny_levee", H))
		t.ok("a non-arrival area → NOT eligible (no farming leak)", Onboarding.firstSpawnEligible(Catalog, fresh, "bayou", "reed_edges", H) == false)
		t.ok("fishing is not eligible until the FIRST_CATCH beat", Onboarding.firstSpawnEligible(Catalog, fresh, "bayou", "channel_banks", F) == false)

		local afterKill = Util.mkProfile(Catalog, {})
		Onboarding.advance(afterKill, "kill", 1) -- now FIRST_CATCH
		t.ok("after the first kill, the arrival fishing spot becomes eligible", Onboarding.firstSpawnEligible(Catalog, afterKill, "bayou", "channel_banks", F))
		t.ok("the first HUNT is no longer guaranteed once it's been done (post-first)", Onboarding.firstSpawnEligible(Catalog, afterKill, "bayou", "sunny_levee", H) == false)

		local done = Util.mkProfile(Catalog, {})
		for _, e in { "kill", "catch", "gearUpgrade", "kill", "catch", "kill", "dailyClaim" } do
			Onboarding.advance(done, e, 1)
		end
		t.ok("a returning (COMPLETE) player gets NO guaranteed spawn (caps hold)", Onboarding.firstSpawnEligible(Catalog, done, "bayou", "sunny_levee", H) == false)
	end
end
