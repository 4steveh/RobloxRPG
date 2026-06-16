--!strict
local Harness = require("@tests/harness")
local Catalog = require("@src/config/Catalog")

-- Helper: narrow a Cost/Reward union for assertion in tests.
local function tag(v: any): string
	return v.kind
end

return function(t: Harness.T)
	t.section("Catalog — loaded + validated on require (build-time guarantee)")
	-- Reaching here means require('Catalog') succeeded, i.e. Validation.validateConfig passed.
	t.ok("destinations present", next(Catalog.destinations) ~= nil)
	t.ok("equipment present", next(Catalog.equipment) ~= nil)
	t.ok("creatures + fish present", next(Catalog.creatures) ~= nil and next(Catalog.fish) ~= nil)

	t.section("Catalog — every gate reference resolves")
	for _, dst in Catalog.destinations do
		for _, tid in dst.gate.milestoneTargets do
			t.ok(dst.id .. " milestone target resolves: " .. tid, Catalog.targetIndex[tid] ~= nil)
		end
		for _, pre in dst.gate.prerequisiteDestinations do
			t.ok(dst.id .. " prerequisite resolves: " .. pre, Catalog.destinations[pre] ~= nil)
		end
	end

	t.section("Catalog — tradeable matrix (data-integrity RD1)")
	t.ok("gear (lever rifle) tradeable=false", Catalog.equipment["weapon_lever_action_rifle"].tradeable == false)
	t.ok("rare-breed dog tradeable=true", Catalog.equipment["dog_redbone_rare"].tradeable == true)
	t.ok("rare cosmetic tradeable=true", Catalog.equipment["cosmetic_rare_boat_livery"].tradeable == true)
	t.ok("standard cosmetic tradeable=false", Catalog.equipment["cosmetic_wood_rifle_skin"].tradeable == false)

	t.section("Catalog — tierInput invariant (only weapon/armor/rod/reel)")
	t.ok("weapon tierInput=true", Catalog.equipment["weapon_lever_action_rifle"].tierInput == true)
	t.ok("armor tierInput=true", Catalog.equipment["armor_field_jacket"].tierInput == true)
	t.ok("rod tierInput=true", Catalog.equipment["rod_coastal_surf"].tierInput == true)
	t.ok("reel tierInput=true", Catalog.equipment["reel_coastal_lever_drag"].tierInput == true)
	t.ok("mount tierInput=false", Catalog.equipment["mount_horse"].tierInput == false)
	t.ok("vehicle/boat tierInput=false", Catalog.equipment["vehicle_coastal_skiff"].tierInput == false)
	t.ok("dog tierInput=false", Catalog.equipment["dog_husky"].tierInput == false)
	t.ok("bait tierInput=false", Catalog.equipment["bait_cut_bait"].tierInput == false)
	t.ok("tool tierInput=false", Catalog.equipment["tool_snowshoes"].tierInput == false)
	t.ok("cosmetic tierInput=false", Catalog.equipment["cosmetic_wood_rifle_skin"].tierInput == false)

	t.section("Catalog — accessGrant + starter loadout")
	t.ok("Coastal Skiff accessGrant=coastal (water-type unlock)", Catalog.equipment["vehicle_coastal_skiff"].accessGrant == "coastal")
	t.ok("a boat grants access, never a stat (no stat fields exist)", Catalog.equipment["vehicle_coastal_skiff"].category == "vehicle")
	local starter = Catalog.equipment["weapon_bolt_22"]
	t.ok("starter weapon availableAt=StarterLoadout", starter.availableAt == "StarterLoadout")
	t.ok("starter weapon cost = 0 Cash", (starter.cost :: any).cash == 0)
	t.ok("starter weapon is Tier 1", starter.tier == 1)

	t.section("Catalog — Reward XOR in seeded content")
	t.ok("a Common creature pays Cash", tag(Catalog.creatures["bayou_swamp_rabbit"].reward) == "cash")
	t.ok("an Uncommon milestone pays Cash", tag(Catalog.creatures["appalachia_wild_boar"].reward) == "cash")
	t.ok("a Mythic fish mints an artifact (no Cash)", tag(Catalog.fish["bayou_leviathan"].reward) == "artifact")
	t.ok("a Legendary creature mints an artifact", tag(Catalog.creatures["appalachia_ghost_buck"].reward) == "artifact")
	t.ok("ambiance grants nothing (reward nil)", Catalog.creatures["bayou_great_egret"].reward == nil)
	t.ok("Rare-and-above carry Template-E rare fields", Catalog.creatures["appalachia_ghost_buck"].rare ~= nil)
	t.ok("Common carries no rare fields", Catalog.creatures["bayou_swamp_rabbit"].rare == nil)

	t.section("Catalog — re-skins balanced at their DISPLAYED tier, not the origin's")
	local hare = Catalog.creatures["alaska_arctic_hare"]
	local source = Catalog.creatures["bayou_swamp_rabbit"]
	t.ok("Arctic Hare re-skins the Bayou Swamp Rabbit", hare.reskinOf == "bayou_swamp_rabbit")
	t.ok("…its OWN tier is authoritative (T4, not the origin's T1)", hare.tier == 4 and source.tier == 1)
	t.ok("…it pays an Alaska-tier wage, above the origin's Bayou band", (hare.reward :: any).cash.min > (source.reward :: any).cash.min)

	t.section("Catalog — milestone designations (the MVL conquest targets)")
	t.ok("Bayou hunting milestone = American Alligator", Catalog.creatures["bayou_american_alligator"].isMilestoneTarget == true)
	t.ok("Bayou fishing milestone = Blue Catfish", Catalog.fish["bayou_blue_catfish"].isMilestoneTarget == true)
	t.ok("Alaska hunting milestone = Bull Moose (not the grizzly)", Catalog.creatures["alaska_bull_moose"].isMilestoneTarget == true)
	t.ok("Alaska fishing milestone = King Salmon (not the halibut)", Catalog.fish["alaska_king_salmon"].isMilestoneTarget == true)
	t.ok("the grizzly is NOT a milestone (co-op-only apex)", Catalog.creatures["alaska_grizzly_bear"].isMilestoneTarget ~= true)
end
