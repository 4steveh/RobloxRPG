--!strict
local Harness = require("@tests/harness")
local Harvest = require("@src/logic/Harvest")

return function(t: Harness.T)
	t.section("Harvest.kgToLb — pounds rounded to 0.1")
	do
		t.eq("10 kg → 22.0 lb", Harvest.kgToLb(10), 22.0)
		t.eq("rounds to one decimal", Harvest.kgToLb(1), 2.2)
	end

	t.section("Harvest.rollWeightKg — in range, biased low")
	do
		t.eq("u=0 → min", Harvest.rollWeightKg(10, 20, 0), 10)
		t.eq("u=1 → max", Harvest.rollWeightKg(10, 20, 1), 20)
		t.ok("u=0.5 is below the midpoint (biased to min)", Harvest.rollWeightKg(10, 20, 0.5) < 15)
		local w = Harvest.rollWeightKg(10, 20, 0.5)
		t.ok("stays within [min,max]", w >= 10 and w <= 20)
		t.ok("clamps u below 0", Harvest.rollWeightKg(10, 20, -3) == 10)
		t.ok("clamps u above 1", Harvest.rollWeightKg(10, 20, 9) == 20)
	end

	t.section("Harvest.isRecord — near the record")
	do
		t.ok("0.95*record is a record at threshold 0.95", Harvest.isRecord(95, 100, 0.95))
		t.ok("below threshold is not a record", not Harvest.isRecord(94, 100, 0.95))
		t.ok("a zero record is never a record (no data)", not Harvest.isRecord(5, 0, 0.95))
	end

	t.section("Harvest.timesSourced — counts artifacts by source species")
	do
		local profile: any = { artifacts = {
			a1 = { provenance = { sourceId = "bayou_x" } },
			a2 = { provenance = { sourceId = "bayou_x" } },
			a3 = { provenance = { sourceId = "bayou_y" } },
			a4 = { provenance = {} },
		} }
		t.eq("two of bayou_x", Harvest.timesSourced(profile, "bayou_x"), 2)
		t.eq("one of bayou_y", Harvest.timesSourced(profile, "bayou_y"), 1)
		t.eq("none of bayou_z", Harvest.timesSourced(profile, "bayou_z"), 0)
	end
end
