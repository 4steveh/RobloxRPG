--!strict
-- The procedural art layer under headless assertion — the first time this project's VISUALS have a
-- regression gate. What is provable without Studio: determinism, part budgets, silhouette dimensions,
-- ground contact, palette discipline, collision/query flags, scatter spacing, and that a cabin's walls are
-- genuinely perforated by its openings. What is NOT provable here (and belongs to the Studio checklist):
-- whether it LOOKS good.

local Harness = require("@tests/harness")
local Art = require("@src/types/Art")
local ArtKit = require("@src/config/ArtKit")
local ArtGen = require("@src/logic/ArtGen")
local Rand = require("@src/logic/Rand")
local Vec = require("@src/logic/Vec")

type ModelDesc = Art.ModelDesc

-- Indexer-typed views of the ArtKit tables. ArtKit authors them as named-field structs (which is what makes
-- ArtKit.trees.baldCypress type-check at the call sites), but a spec wants to sweep EVERY entry so a newly
-- added recipe is covered automatically instead of silently skipped.
local TREES = ArtKit.trees :: { [string]: Art.TreeRecipe }
local ROCKS = ArtKit.rocks :: { [string]: Art.RockRecipe }
local CLUSTERS = ArtKit.clusters :: { [string]: Art.ClusterRecipe }
local CABINS = ArtKit.cabins :: { [string]: Art.CabinRecipe }
local LOOKS = ArtKit.looks :: { [string]: ArtKit.Look }
local PLANS = ArtKit.scatterPlans :: { [string]: { ArtKit.ScatterPatch } }

local function approx(a: number, b: number, tol: number): boolean
	return math.abs(a - b) <= tol
end

-- Every generated part must be finite and non-degenerate: a NaN size or position is an invisible part in
-- Studio and a silently corrupt CFrame, which is exactly the failure a headless gate should catch.
local function allFinite(m: ModelDesc): boolean
	for _, p in m.parts do
		for _, v in { p.size.x, p.size.y, p.size.z, p.pos.x, p.pos.y, p.pos.z } do
			if v ~= v or v == math.huge or v == -math.huge then
				return false
			end
		end
		if p.size.x <= 0 or p.size.y <= 0 or p.size.z <= 0 then
			return false
		end
		if p.up ~= nil then
			local mag = Vec.magnitude(p.up)
			if mag ~= mag or not approx(mag, 1, 1e-6) then
				return false
			end
		end
	end
	return true
end

local function colorsValid(m: ModelDesc): boolean
	for _, p in m.parts do
		if #p.color ~= 3 then
			return false
		end
		for _, c in p.color do
			if c ~= c or c < 0 or c > 255 or math.floor(c) ~= c then
				return false
			end
		end
	end
	return true
end

local function identical(a: ModelDesc, b: ModelDesc): boolean
	if #a.parts ~= #b.parts then
		return false
	end
	for i = 1, #a.parts do
		local p, q = a.parts[i], b.parts[i]
		if p.name ~= q.name or p.shape ~= q.shape or p.material ~= q.material then
			return false
		end
		for _, pair in
			{
				{ p.size.x, q.size.x },
				{ p.size.y, q.size.y },
				{ p.size.z, q.size.z },
				{ p.pos.x, q.pos.x },
				{ p.pos.y, q.pos.y },
				{ p.pos.z, q.pos.z },
				{ p.color[1], q.color[1] },
				{ p.color[2], q.color[2] },
				{ p.color[3], q.color[3] },
			}
		do
			if pair[1] ~= pair[2] then
				return false
			end
		end
	end
	return true
end

return function(t: Harness.T)
	t.section("Rand — deterministic PRNG + coherent noise")

	t.test("stream is deterministic and reproducible from a seed", function()
		local a, b = Rand.stream(12345), Rand.stream(12345)
		local same = true
		for _ = 1, 200 do
			if Rand.nextUInt(a) ~= Rand.nextUInt(b) then
				same = false
				break
			end
		end
		t.ok("same seed yields the same sequence", same)
	end)

	t.test("distinct seeds diverge", function()
		local a, b = Rand.stream(1), Rand.stream(2)
		local differs = false
		for _ = 1, 50 do
			if Rand.nextUInt(a) ~= Rand.nextUInt(b) then
				differs = true
				break
			end
		end
		t.ok("different seeds yield different sequences", differs)
	end)

	t.test("unit() stays in [0,1) and covers the range", function()
		local st = Rand.stream(99)
		local lo: number, hi: number = math.huge, -math.huge
		local inRange = true
		for _ = 1, 4000 do
			local v = Rand.unit(st)
			if v < 0 or v >= 1 then
				inRange = false
			end
			if v < lo then lo = v end
			if v > hi then hi = v end
		end
		t.ok("all samples in [0,1)", inRange)
		t.ok("spans most of the range (lo < 0.02, hi > 0.98)", lo < 0.02 and hi > 0.98)
	end)

	t.test("mul32 is an exact 32-bit multiply", function()
		t.eq("small operands", Rand.mul32(3, 5), 15)
		t.eq("identity", Rand.mul32(1, 0xFFFFFFFF), 0xFFFFFFFF)
		-- 2^16 * 2^16 = 2^32, which wraps to 0
		t.eq("wraps at 2^32", Rand.mul32(65536, 65536), 0)
		t.ok("stays inside uint32", Rand.mul32(0xFFFFFFFF, 0xFFFFFFFF) <= 0xFFFFFFFF)
	end)

	t.test("hash2 is a pure function of its lattice cell", function()
		t.eq("same cell, same value", Rand.hash2(7, -3, 42), Rand.hash2(7, -3, 42))
		t.ok("neighbouring cells differ", Rand.hash2(7, -3, 42) ~= Rand.hash2(8, -3, 42))
		t.ok("the seed matters", Rand.hash2(7, -3, 42) ~= Rand.hash2(7, -3, 43))
		local inRange = true
		for x = -20, 20 do
			for z = -20, 20 do
				local v = Rand.hash2(x, z, 5)
				if v < 0 or v >= 1 then
					inRange = false
				end
			end
		end
		t.ok("hash2 stays in [0,1)", inRange)
	end)

	t.test("fbm2 and ridge2 stay normalised and vary smoothly", function()
		local p = ArtKit.noise.appalachia.base
		local lo: number, hi: number = math.huge, -math.huge
		local maxStep: number = 0
		local prev = Rand.fbm2(0, 0, 7, p)
		for i = 1, 3000 do
			local x = i * 0.5
			local v = Rand.fbm2(x, x * 0.37, 7, p)
			if v < lo then lo = v end
			if v > hi then hi = v end
			local step = math.abs(v - prev)
			if step > maxStep then maxStep = step end
			prev = v
		end
		t.ok("fbm2 in [0,1]", lo >= 0 and hi <= 1)
		t.ok("fbm2 actually varies", hi - lo > 0.2)
		-- 0.5 studs at frequency 0.0042 is a tiny lattice step, so consecutive samples must be close:
		-- a large jump would mean the interpolation is broken and the terrain would have cliffs everywhere.
		t.ok("fbm2 is continuous (no lattice creases)", maxStep < 0.05)

		local rlo: number, rhi: number = math.huge, -math.huge
		for i = 1, 2000 do
			local v = Rand.ridge2(i * 0.7, i * 0.31, 11, p)
			if v < rlo then rlo = v end
			if v > rhi then rhi = v end
		end
		t.ok("ridge2 in [0,1]", rlo >= 0 and rhi <= 1)
		t.ok("ridge2 varies", rhi - rlo > 0.2)
	end)

	t.test("remap and smoothstep clamp at both ends", function()
		t.eq("remap below range clamps low", Rand.remap(-5, 0, 10, 100, 200), 100)
		t.eq("remap above range clamps high", Rand.remap(50, 0, 10, 100, 200), 200)
		t.eq("remap midpoint", Rand.remap(5, 0, 10, 100, 200), 150)
		t.eq("smoothstep below edge0", Rand.smoothstep(2, 4, 1), 0)
		t.eq("smoothstep above edge1", Rand.smoothstep(2, 4, 9), 1)
		t.eq("smoothstep midpoint", Rand.smoothstep(0, 1, 0.5), 0.5)
	end)

	t.section("Vec — the orientation contract")

	t.test("frame(+Y) is the identity basis", function()
		-- LOAD-BEARING: if this is not the identity, every unrotated part's authored size.x and size.z are
		-- transposed at instantiation. That bug shipped once and made a 76-stud cabin measure 154 studs.
		local r, u, f = Vec.frame({ x = 0, y = 1, z = 0 })
		t.ok("right = +X", approx(r.x, 1, 1e-9) and approx(r.y, 0, 1e-9) and approx(r.z, 0, 1e-9))
		t.ok("up = +Y", approx(u.x, 0, 1e-9) and approx(u.y, 1, 1e-9) and approx(u.z, 0, 1e-9))
		t.ok("forward = +Z", approx(f.x, 0, 1e-9) and approx(f.y, 0, 1e-9) and approx(f.z, 1, 1e-9))
	end)

	t.test("frame is orthonormal for arbitrary ups, including the degenerate axes", function()
		local ok = true
		local cases = {
			{ x = 0, y = 1, z = 0 },
			{ x = 0, y = -1, z = 0 },
			{ x = 0, y = 0, z = 1 },
			{ x = 0, y = 0, z = -1 },
			{ x = 1, y = 0, z = 0 },
			{ x = 0.3, y = 0.9, z = -0.2 },
			{ x = -0.7, y = 0.1, z = 0.7 },
		}
		for _, up in cases do
			local r, u, f = Vec.frame(up)
			if
				not approx(Vec.magnitude(r), 1, 1e-6)
				or not approx(Vec.magnitude(u), 1, 1e-6)
				or not approx(Vec.magnitude(f), 1, 1e-6)
				or not approx(Vec.dot(r, u), 0, 1e-6)
				or not approx(Vec.dot(r, f), 0, 1e-6)
				or not approx(Vec.dot(u, f), 0, 1e-6)
			then
				ok = false
			end
		end
		t.ok("every frame is orthonormal", ok)
	end)

	t.test("frameX puts the axis on local X (the cylinder convention)", function()
		local r, u, f = Vec.frameX({ x = 0, y = 1, z = 0 })
		t.ok("local X is the given axis", approx(r.y, 1, 1e-9))
		t.ok("frameX orthonormal", approx(Vec.dot(r, u), 0, 1e-6) and approx(Vec.dot(u, f), 0, 1e-6))
	end)

	t.test("tilt preserves unit length and honours the requested angle", function()
		local d = { x = 0, y = 1, z = 0 }
		local ok = true
		for i = 0, 20 do
			local angle = i * 0.07
			local out = Vec.tilt(d, angle, i * 0.9)
			if not approx(Vec.magnitude(out), 1, 1e-6) then
				ok = false
			end
			if not approx(Vec.dot(out, d), math.cos(angle), 1e-6) then
				ok = false
			end
		end
		t.ok("tilt is a rigid rotation by the given cone angle", ok)
	end)

	t.test("unit() of a zero vector degrades to +Y rather than NaN", function()
		local u = Vec.unit({ x = 0, y = 0, z = 0 })
		t.ok("zero normalises to +Y", u.x == 0 and u.y == 1 and u.z == 0)
	end)

	t.section("ArtGen — trees")

	local TREE_BUDGET: { [string]: number } = {
		-- hero landmark: one instance in the world, so it may be dense
		oldCypress = 460,
		-- canopy trees: scattered by the hundred, so each must stay near the reference template's ~40-60
		baldCypress = 110,
		oak = 110,
		maple = 100,
		pine = 110,
		spruce = 100,
		snowSpruce = 100,
		birch = 60,
		snag = 40,
	}

	t.test("every tree recipe generates finite, non-degenerate, palette-valid geometry", function()
		for key, recipe in TREES do
			local m = ArtGen.tree(recipe, 4242)
			t.ok(key .. ": produces parts", #m.parts > 0)
			t.ok(key .. ": all sizes/positions finite and positive", allFinite(m))
			t.ok(key .. ": all colours are valid 0-255 integer triples", colorsValid(m))
		end
	end)

	t.test("tree part counts stay inside budget across many seeds", function()
		for key, recipe in TREES do
			local budget = TREE_BUDGET[key]
			t.ok(key .. ": has a declared part budget", budget ~= nil)
			if budget ~= nil then
				local worst: number = 0
				for s = 1, 40 do
					worst = math.max(worst, #ArtGen.tree(recipe, s * 613 + 7).parts)
				end
				t.ok(("%s: worst-of-40 part count %d <= %d"):format(key, worst, budget), worst <= budget)
			end
		end
	end)

	t.test("trees are normalised into their declared height band", function()
		for key, recipe in TREES do
			local ok = true
			local worstLow: number, worstHigh: number = math.huge, -math.huge
			for s = 1, 25 do
				local m = ArtGen.tree(recipe, s * 331 + 5)
				local _, hi = ArtGen.bounds(m.parts)
				worstLow = math.min(worstLow, hi.y)
				worstHigh = math.max(worstHigh, hi.y)
				-- 2% slack absorbs the float error of the normalising scale
				if hi.y < recipe.targetHeight.min * 0.98 or hi.y > recipe.targetHeight.max * 1.02 then
					ok = false
				end
			end
			t.ok(
				("%s: height %.1f..%.1f within band %.0f..%.0f"):format(
					key,
					worstLow,
					worstHigh,
					recipe.targetHeight.min,
					recipe.targetHeight.max
				),
				ok
			)
		end
	end)

	t.test("trees are authored ground-up so a raycast drop lands them correctly", function()
		for key, recipe in TREES do
			local m = ArtGen.tree(recipe, 777)
			local lo, _hi = ArtGen.bounds(m.parts)
			-- The base may dip slightly below 0 (buttress flares, sunken roots) but must not float:
			-- a positive minimum Y is the classic hovering-tree tell.
			t.ok(("%s: base does not float (minY %.2f <= 0.5)"):format(key, lo.y), lo.y <= 0.5)
			t.ok(("%s: base does not sink absurdly (minY %.2f >= -8)"):format(key, lo.y), lo.y >= -8)
			t.ok(key .. ": groundPivot is the origin", m.groundPivot.y == 0)
		end
	end)

	t.test("the same seed yields a byte-identical tree; a different seed does not", function()
		local r = ArtKit.trees.baldCypress
		t.ok("same seed -> identical model", identical(ArtGen.tree(r, 2026), ArtGen.tree(r, 2026)))
		t.ok("different seed -> different model", not identical(ArtGen.tree(r, 2026), ArtGen.tree(r, 2027)))
	end)

	t.test("foliage draws only from its recipe palette, and never blocks the player or a raycast", function()
		local r = ArtKit.trees.oak
		local m = ArtGen.tree(r, 51)
		local allowed: { [string]: boolean } = {}
		for _, c in r.foliage.colors do
			allowed[("%d,%d,%d"):format(c[1], c[2], c[3])] = true
		end
		local leaves, distinctLeafColors, offPalette = 0, {}, 0
		local trunkCollidable = false
		for _, p in m.parts do
			if p.name == "Leaf" then
				leaves += 1
				local k = ("%d,%d,%d"):format(p.color[1], p.color[2], p.color[3])
				distinctLeafColors[k] = true
				if not allowed[k] then
					offPalette += 1
				end
				if p.canCollide ~= false or p.canQuery ~= false then
					trunkCollidable = true -- reused flag: any collidable leaf is a defect
				end
			end
		end
		local n = 0
		for _ in distinctLeafColors do
			n += 1
		end
		t.ok("oak has foliage", leaves > 0)
		t.eq("no leaf colour is off-palette", offPalette, 0)
		-- The single highest-impact trick measured off the reference template: multi-hue foliage inside ONE
		-- model. A single-colour canopy is the flat-plastic look this whole pass exists to kill.
		t.ok(("oak canopy uses multiple hues (%d distinct)"):format(n), n >= 3)
		t.ok("no leaf is collidable or queryable", not trunkCollidable)
	end)

	t.test("a tree's trunk stays collidable and queryable so the world has solid boles", function()
		local m = ArtGen.tree(ArtKit.trees.oak, 88)
		local solid = 0
		for _, p in m.parts do
			if p.name == "Trunk" and p.canCollide == true and p.canQuery == true then
				solid += 1
			end
		end
		t.eq("trunk segment count matches the recipe", solid, ArtKit.trees.oak.limb.segments)
	end)

	t.test("conifers build tiered rings, broadleaves build terminal slabs", function()
		local pine = ArtGen.tree(ArtKit.trees.pine, 31)
		local needles, leaves = 0, 0
		for _, p in pine.parts do
			if p.name == "Needle" then
				needles += 1
			elseif p.name == "Leaf" then
				leaves += 1
			end
		end
		t.ok("pine produces needle tiers", needles > 20)
		t.eq("pine produces no broadleaf slabs", leaves, 0)

		local oak = ArtGen.tree(ArtKit.trees.oak, 31)
		local oakLeaves, oakNeedles = 0, 0
		for _, p in oak.parts do
			if p.name == "Leaf" then
				oakLeaves += 1
			elseif p.name == "Needle" then
				oakNeedles += 1
			end
		end
		t.ok("oak produces slabs", oakLeaves > 5)
		t.eq("oak produces no needles", oakNeedles, 0)
	end)

	t.test("the Old Cypress reads as a landmark: taller and wider than any canopy tree", function()
		local hero = ArtGen.tree(ArtKit.trees.oldCypress, 9)
		local ordinary = ArtGen.tree(ArtKit.trees.baldCypress, 9)
		local hlo, hhi = ArtGen.bounds(hero.parts)
		local olo, ohi = ArtGen.bounds(ordinary.parts)
		-- §2.2 wayfinding: the beacon has to be legible over the grove, which is a measurable claim.
		t.ok("hero is taller than a canopy cypress", hhi.y > ohi.y * 1.5)
		t.ok("hero is wider than a canopy cypress", (hhi.x - hlo.x) > (ohi.x - olo.x) * 1.2)
		t.ok("hero has moss drape", (function()
			for _, p in hero.parts do
				if p.name == "Drape" then
					return true
				end
			end
			return false
		end)())
	end)

	t.section("ArtGen — rock and scatter clusters")

	t.test("every rock recipe generates valid faceted geometry that sits in the ground", function()
		for key, recipe in ROCKS do
			local m = ArtGen.rock(recipe, 1234)
			t.ok(key .. ": produces slabs", #m.parts >= recipe.slabMin)
			t.ok(key .. ": finite", allFinite(m))
			t.ok(key .. ": colours valid", colorsValid(m))
			local lo, _hi = ArtGen.bounds(m.parts)
			t.ok(("%s: buried below ground (minY %.2f < 0)"):format(key, lo.y), lo.y < 0)
			local solid = true
			for _, p in m.parts do
				if p.canCollide ~= true or p.canQuery ~= true then
					solid = false
				end
			end
			t.ok(key .. ": rock is solid (collidable + queryable)", solid)
		end
	end)

	t.test("every cluster recipe generates valid, non-blocking scatter", function()
		for key, recipe in CLUSTERS do
			local m = ArtGen.cluster(recipe, 555)
			t.ok(key .. ": produces elements", #m.parts >= recipe.countMin)
			t.ok(key .. ": respects countMax", #m.parts <= recipe.countMax)
			t.ok(key .. ": finite", allFinite(m))
			t.ok(key .. ": colours valid", colorsValid(m))
			local within = true
			for _, p in m.parts do
				local d = math.sqrt(p.pos.x * p.pos.x + p.pos.z * p.pos.z)
				if d > recipe.radius + 1e-6 then
					within = false
				end
			end
			t.ok(key .. ": elements stay inside the cluster radius", within)
		end
	end)

	t.test("decorative scatter never eats a hunting raycast", function()
		-- The hunting loop resolves shots by raycast. Any queryable decoration between the player and an
		-- animal silently absorbs shots, which reads to the player as the gun being broken.
		local offenders = {}
		for key, recipe in CLUSTERS do
			if recipe.canQuery == true and recipe.canCollide ~= true then
				table.insert(offenders, key)
			end
		end
		t.eq("no cluster is queryable-but-not-solid", #offenders, 0)
	end)

	t.section("ArtGen — scatter planning")

	t.test("scatter honours count, radius and minimum spacing", function()
		local spec = {
			center = { x = 40, z = -60 },
			radius = 150,
			count = 120,
			recipeCount = 4,
			scale = { min = 0.8, max = 1.3 },
			minSpacing = ArtKit.budget.treeSpacing,
		}
		local plan = ArtGen.scatter(spec, 606, 30)
		t.ok(("placed %d of %d requested"):format(#plan, spec.count), #plan > 0 and #plan <= spec.count)
		local worstD: number = math.huge
		local outside, badIndex, badScale = 0, 0, 0
		for i = 1, #plan do
			local p = plan[i]
			local dx, dz = p.x - spec.center.x, p.z - spec.center.z
			if math.sqrt(dx * dx + dz * dz) > spec.radius + 1e-6 then
				outside += 1
			end
			if p.recipeIndex < 1 or p.recipeIndex > spec.recipeCount or math.floor(p.recipeIndex) ~= p.recipeIndex then
				badIndex += 1
			end
			if p.scale < spec.scale.min or p.scale > spec.scale.max then
				badScale += 1
			end
			for j = i + 1, #plan do
				local ex, ez = p.x - plan[j].x, p.z - plan[j].z
				worstD = math.min(worstD, math.sqrt(ex * ex + ez * ez))
			end
		end
		t.eq("every point is inside the requested radius", outside, 0)
		t.eq("every recipeIndex is a valid integer index", badIndex, 0)
		t.eq("every scale is inside the requested band", badScale, 0)
		t.ok(
			("minimum pairwise spacing %.2f >= %d"):format(worstD, spec.minSpacing),
			worstD >= spec.minSpacing - 1e-6
		)
	end)

	t.test("scatter is deterministic and terminates on an impossible spacing request", function()
		local spec = {
			center = { x = 0, z = 0 },
			radius = 20,
			count = 500,
			recipeCount = 1,
			scale = { min = 1, max = 1 },
			minSpacing = 15,
		}
		local a = ArtGen.scatter(spec, 7, 8)
		local b = ArtGen.scatter(spec, 7, 8)
		t.eq("same seed -> same plan length", #a, #b)
		t.ok("same seed -> same first point", #a == 0 or (a[1].x == b[1].x and a[1].z == b[1].z))
		-- The real assertion: a 20-radius disc cannot hold 500 points 15 studs apart, so the generator must
		-- give up and return fewer rather than loop forever.
		t.ok(("impossible request degrades gracefully (placed %d of 500)"):format(#a), #a < 500)
	end)

	t.section("ArtGen — the Lodge and outpost")

	t.test("the cabin's outer dimensions match its recipe", function()
		for key, recipe in CABINS do
			local m = ArtGen.cabin(recipe)
			local lo, hi = ArtGen.bounds(m.parts)
			local w, d = hi.x - lo.x, hi.z - lo.z
			t.ok(key .. ": finite", allFinite(m))
			t.ok(key .. ": colours valid", colorsValid(m))
			-- Outer width = interior width + roof overhang each side + the eave fascia that hangs past it.
			-- (Omitting the eave term is why this assertion first failed on the outpost by 0.2 studs — the
			-- geometry was right and the expectation was wrong.)
			local logT = recipe.wallHeight / recipe.logCourses
			local eave = logT * 0.9 * 1.4
			local expectW = recipe.width + recipe.roofOverhang * 2 + eave
			t.ok(
				("%s: width %.1f is within 6%% of the expected %.1f"):format(key, w, expectW),
				approx(w, expectW, expectW * 0.06)
			)
			-- depth also carries the porch, which extends past the south wall
			local expectD = recipe.depth + recipe.roofOverhang * 2 + recipe.porchDepth
			t.ok(
				("%s: depth %.1f is within 8%% of the expected %.1f"):format(key, d, expectD),
				approx(d, expectD, expectD * 0.08)
			)
			local expectH = recipe.wallHeight + recipe.width * 0.5 * recipe.roofPitch
			t.ok(
				("%s: ridge height %.1f is at least the wall+pitch %.1f"):format(key, hi.y, expectH),
				hi.y >= expectH * 0.95
			)
		end
	end)

	t.test("cabin walls are genuinely perforated by their openings", function()
		local recipe = ArtKit.cabins.lodge
		local withWindows = ArtGen.cabin(recipe)
		local solidRecipe = table.clone(recipe)
		solidRecipe.windows = {}
		local noWindows = ArtGen.cabin(solidRecipe)

		local function logSpans(m: ModelDesc, wall: string): number
			local n = 0
			for _, p in m.parts do
				if p.name == wall .. "Log" then
					n += 1
				end
			end
			return n
		end
		-- Cutting a hole SPLITS a course into two spans, so a perforated wall has MORE log parts than a
		-- solid one. That is the cheap, robust proof that the openings are real geometry and not a decal.
		t.ok(
			("east wall gains spans from its 3 windows (%d > %d)"):format(
				logSpans(withWindows, "East"),
				logSpans(noWindows, "East")
			),
			logSpans(withWindows, "East") > logSpans(noWindows, "East")
		)
		local glass = 0
		for _, p in withWindows.parts do
			if p.name == "WindowGlass" then
				glass += 1
			end
		end
		t.eq("one glass pane per authored window", glass, #recipe.windows)
	end)

	t.test("the door opening exists and is walk-through", function()
		local recipe = ArtKit.cabins.lodge
		local m = ArtGen.cabin(recipe)
		-- Sample the south wall plane at the doorway: no collidable log part may occupy it below the head.
		local hd = recipe.depth * 0.5
		local blocked = false
		for _, p in m.parts do
			if p.name == "SouthLog" and p.canCollide ~= false then
				local halfX, halfY = p.size.x * 0.5, p.size.y * 0.5
				local overlapsDoorX = math.abs(p.pos.x) < recipe.doorWidth * 0.5 - 0.1
				local belowHead = p.pos.y - halfY < recipe.doorHeight - 0.1
				local aboveFloor = p.pos.y + halfY > 0.1
				local onSouthWall = p.pos.z < -hd * 0.5
				if overlapsDoorX and belowHead and aboveFloor and onSouthWall and halfX > 0 then
					blocked = true
				end
			end
		end
		t.ok("the doorway is clear of wall logs", not blocked)
	end)

	t.test("the cabin has a closed roof, a chimney and a porch", function()
		local m = ArtGen.cabin(ArtKit.cabins.lodge)
		local counts: { [string]: number } = {}
		for _, p in m.parts do
			counts[p.name] = (counts[p.name] or 0) + 1
		end
		t.eq("two roof slopes", counts.RoofSlope, 2)
		t.eq("one ridge beam", counts.RidgeBeam, 1)
		t.ok("gable in-fill closes both ends", (counts.Gable or 0) >= 4)
		t.ok("chimney is coursed, not one box", (counts.Chimney or 0) >= 3)
		t.ok("has a hearth and firebox", counts.Hearth == 1 and counts.Firebox == 1)
		t.ok("has a porch deck and posts", counts.PorchDeck == 1 and (counts.PorchPost or 0) >= 3)
		t.ok("has interior tie beams", (counts.TieBeam or 0) >= 2)
		t.eq("four corner posts", counts.CornerPost, 4)
	end)

	t.section("ArtGen — budget discipline")

	-- Mean generated part count for a recipe, sampled across seeds. The projection below needs an average
	-- rather than one sample because every recipe's count is itself randomised.
	local function meanParts(kind: string, key: string): number
		local total = 0
		local samples = 12
		for s = 1, samples do
			local seed = s * 8171 + 3
			if kind == "tree" then
				total += #ArtGen.tree(TREES[key], seed).parts
			elseif kind == "rock" then
				total += #ArtGen.rock(ROCKS[key], seed).parts
			else
				total += #ArtGen.cluster(CLUSTERS[key], seed).parts
			end
		end
		return total / samples
	end

	t.test("every scatter patch names recipes that exist in the ArtKit", function()
		local missing = {}
		for biome, patches in PLANS do
			for i, patch in patches do
				local tbl: { [string]: any } = if patch.kind == "tree"
					then TREES
					elseif patch.kind == "rock" then ROCKS
					else CLUSTERS
				for _, key in patch.recipes do
					if tbl[key] == nil then
						table.insert(missing, ("%s patch %d: %s '%s'"):format(biome, i, patch.kind, key))
					end
				end
				if #patch.recipes == 0 then
					table.insert(missing, ("%s patch %d: empty recipe list"):format(biome, i))
				end
			end
		end
		t.eq("no patch references an unknown recipe: " .. table.concat(missing, "; "), #missing, 0)
	end)

	t.test("scatter patches use the ArtKit's declared spacing floors", function()
		local bad = {}
		for biome, patches in PLANS do
			for i, patch in patches do
				local floor = if patch.kind == "cluster" then ArtKit.budget.shrubSpacing else ArtKit.budget.treeSpacing
				if patch.spacing < floor then
					table.insert(bad, ("%s patch %d spacing %g < %g"):format(biome, i, patch.spacing, floor))
				end
				if patch.radius > ArtKit.budget.scatterRadiusCap then
					table.insert(bad, ("%s patch %d radius %g exceeds cap"):format(biome, i, patch.radius))
				end
			end
		end
		t.eq("no patch under-spaces or over-reaches: " .. table.concat(bad, "; "), #bad, 0)
	end)

	t.test("the real per-biome scatter plans stay inside the declared part budget", function()
		-- The budget question that actually matters: at the densities the WORLD BUILDER will use — the very
		-- same ArtKit.scatterPlans data it reads — does each biome fit? This fails in CI rather than on a phone.
		local grand = 0
		for biome, patches in PLANS do
			local projected = 0
			for _, patch in patches do
				local plan = ArtGen.scatter({
					center = patch.center,
					radius = patch.radius,
					count = patch.count,
					recipeCount = #patch.recipes,
					scale = patch.scale,
					minSpacing = patch.spacing,
				}, patch.seed, 30)
				local mean = 0
				for _, key in patch.recipes do
					mean += meanParts(patch.kind, key)
				end
				mean /= #patch.recipes
				projected += #plan * mean
			end
			-- the hero landmark and the biome's building are built unconditionally, on top of the scatter
			projected += #ArtGen.tree(TREES.oldCypress, 1).parts
			projected += #ArtGen.cabin(CABINS.outpost).parts
			projected = math.floor(projected)
			grand += projected
			t.ok(
				("%s: projected %d parts <= budget %d"):format(biome, projected, ArtKit.budget.maxPartsPerBiome),
				projected <= ArtKit.budget.maxPartsPerBiome
			)
		end
		grand += #ArtGen.cabin(CABINS.lodge).parts
		t.ok(
			("all biomes + Lodge: %d parts <= total budget %d"):format(grand, ArtKit.budget.maxPartsTotal),
			grand <= ArtKit.budget.maxPartsTotal
		)
	end)

	t.section("ArtKit — data discipline")

	t.test("every palette entry is a valid RGB triple", function()
		local bad = 0
		for _, biome in (ArtKit.palettes :: { [string]: any }) do
			for _, entry in biome :: any do
				local list = entry
				-- a palette member is either a list of triples or a single triple
				if type(list) == "table" and type(list[1]) == "table" then
					for _, c in list do
						if #c ~= 3 or c[1] < 0 or c[1] > 255 or c[2] < 0 or c[2] > 255 or c[3] < 0 or c[3] > 255 then
							bad += 1
						end
					end
				elseif type(list) == "table" and type(list[1]) == "number" then
					if #list ~= 3 then
						bad += 1
					end
				end
			end
		end
		t.eq("no malformed palette entries", bad, 0)
	end)

	t.test("every foliage palette carries the multi-hue variation the reference proves out", function()
		local thin = {}
		for key, recipe in TREES do
			if recipe.foliage.kind ~= "none" and #recipe.foliage.colors < 3 then
				table.insert(thin, key)
			end
		end
		t.eq("no tree has a single-hue canopy", #thin, 0)
	end)

	-- ── PALETTE DISCIPLINE, as an assertable rule ────────────────────────────────────────────────────
	-- Measured off the reference template's five leaf greens: hue spread 72.3 degrees, saturation spread
	-- 0.665, value spread 0.251. Measured off this project's ORIGINAL foliage palettes: hue 15-28 degrees,
	-- saturation 0.10-0.12. That 3-5x deficit in the hue and saturation axes is precisely why a stylized
	-- world reads as flat programmer-green, and it is invisible to inspection — you have to measure it.
	-- Organic palettes therefore need WIDE hue+saturation and moderate value; mineral palettes (bark, stone,
	-- snow) need the opposite. Getting them backwards is the classic "candy rocks, flat trees" failure.

	local function toHsv(c: Art.RGB): (number, number, number)
		local r, g, b = c[1] / 255, c[2] / 255, c[3] / 255
		local maxc = math.max(r, math.max(g, b))
		local minc = math.min(r, math.min(g, b))
		local d = maxc - minc
		local h = 0
		if d > 1e-9 then
			if maxc == r then
				h = 60 * (((g - b) / d) % 6)
			elseif maxc == g then
				h = 60 * ((b - r) / d + 2)
			else
				h = 60 * ((r - g) / d + 4)
			end
		end
		local s = if maxc <= 1e-9 then 0 else d / maxc
		return h, s, maxc
	end

	-- Spread of a palette on each HSV axis. Hue is measured on the raw 0-360 scale, which is correct for
	-- every palette here (all of them sit well inside one revolution — none wraps through red).
	local function spread(colors: { Art.RGB }): (number, number, number)
		local hLo, hHi = math.huge, -math.huge
		local sLo, sHi = math.huge, -math.huge
		local vLo, vHi = math.huge, -math.huge
		for _, c in colors do
			local h, s, v = toHsv(c)
			if h < hLo then
				hLo = h
			end
			if h > hHi then
				hHi = h
			end
			if s < sLo then
				sLo = s
			end
			if s > sHi then
				sHi = s
			end
			if v < vLo then
				vLo = v
			end
			if v > vHi then
				vHi = v
			end
		end
		return hHi - hLo, sHi - sLo, vHi - vLo
	end

	t.test("the reference template's own foliage satisfies the discipline rule", function()
		-- Calibration check: the thresholds below are only meaningful if the thing they were derived from
		-- passes them. These five RGB values were read live out of Pirate Island's SavannaTree.
		local ref: { Art.RGB } = { { 127, 142, 100 }, { 120, 144, 130 }, { 164, 189, 71 }, { 75, 151, 75 }, { 58, 125, 21 } }
		local dh, ds, dv = spread(ref)
		t.ok(("reference hue spread %.1f >= 60"):format(dh), dh >= 60)
		t.ok(("reference saturation spread %.3f >= 0.42"):format(ds), ds >= 0.42)
		t.ok(("reference value spread %.3f in 0.15..0.30"):format(dv), dv >= 0.15 and dv <= 0.30)
	end)

	t.test("organic palettes spread wide in hue and saturation, per element class", function()
		-- One global floor is the wrong rule: different organic classes have genuinely different available
		-- gamuts, and forcing them all to the canopy's 55 degrees would either fail correct art or push a
		-- palette somewhere it should not go. Each class therefore declares its own floor, with the reason.
		-- What every class still has to clear is the ORIGINAL flatness this pass was fixing: 15-28 degrees
		-- of hue and 0.10-0.12 of saturation.
		type Class = { hue: number, sat: number, why: string }
		local CANOPY: Class = { hue = 55, sat = 0.42, why = "broadleaf masses carry the world's read" }
		local UNDERSTORY: Class = { hue = 48, sat = 0.38, why = "ground cover, seen closer and in smaller pieces" }
		local CONIFER: Class = { hue = 38, sat = 0.34, why = "cold blue-greens occupy a narrow band by nature" }
		local WARM_RAMP: Class = { hue = 40, sat = 0.28, why = "red to yellow is only ~60 degrees of hue to work in" }
		local COLD_GROUND: Class = { hue = 36, sat = 0.26, why = "Alaska carries contrast in value, not chroma" }
		-- Spanish moss is grey-green by nature: its read is SILHOUETTE (long hanging strands breaking the
		-- canopy edge), not colour. Holding it to an understory chroma floor would push it toward a green that
		-- Spanish moss simply is not.
		local DRAPE: Class = { hue = 38, sat = 0.18, why = "hanging moss reads by silhouette, deliberately desaturated" }

		local ORGANIC: { { any } } = {
			{ "bayou.foliage", ArtKit.palettes.bayou.foliage, CANOPY },
			{ "bayou.reed", ArtKit.palettes.bayou.reed, UNDERSTORY },
			{ "bayou.fern", ArtKit.palettes.bayou.fern, UNDERSTORY },
			{ "bayou.duckweed", ArtKit.palettes.bayou.duckweed, UNDERSTORY },
			{ "bayou.lilypad", ArtKit.palettes.bayou.lilypad, UNDERSTORY },
			{ "bayou.moss", ArtKit.palettes.bayou.moss, DRAPE },
			{ "appalachia.foliage", ArtKit.palettes.appalachia.foliage, CANOPY },
			{ "appalachia.autumn", ArtKit.palettes.appalachia.autumn, WARM_RAMP },
			{ "appalachia.needle", ArtKit.palettes.appalachia.needle, CONIFER },
			{ "appalachia.fern", ArtKit.palettes.appalachia.fern, UNDERSTORY },
			{ "appalachia.grassTuft", ArtKit.palettes.appalachia.grassTuft, UNDERSTORY },
			{ "alaska.needle", ArtKit.palettes.alaska.needle, CONIFER },
			{ "alaska.tundra", ArtKit.palettes.alaska.tundra, COLD_GROUND },
		}
		for _, entry in ORGANIC do
			local name = entry[1] :: string
			local cls = entry[3] :: Class
			local dh, ds, dv = spread(entry[2] :: { Art.RGB })
			t.ok(("%s: hue spread %.1f >= %d (%s)"):format(name, dh, cls.hue, cls.why), dh >= cls.hue)
			t.ok(("%s: saturation spread %.3f >= %.2f"):format(name, ds, cls.sat), ds >= cls.sat)
			-- and it must not be a VALUE ramp masquerading as variation
			t.ok(("%s: value spread %.3f <= 0.40"):format(name, dv), dv <= 0.4)
			-- the floor no organic palette may ever fall back to: the flatness this pass replaced
			t.ok(("%s: clears the original flat-green baseline (hue > 30, sat > 0.15)"):format(name), dh > 30 and ds > 0.15)
		end
	end)

	t.test("mineral palettes stay tight in hue and saturation", function()
		local MINERAL = {
			{ "bayou.bark", ArtKit.palettes.bayou.bark },
			{ "bayou.stone", ArtKit.palettes.bayou.stone },
			{ "appalachia.bark", ArtKit.palettes.appalachia.bark },
			{ "appalachia.birchBark", ArtKit.palettes.appalachia.birchBark },
			{ "appalachia.stone", ArtKit.palettes.appalachia.stone },
			{ "alaska.bark", ArtKit.palettes.alaska.bark },
			{ "alaska.stone", ArtKit.palettes.alaska.stone },
			{ "alaska.snow", ArtKit.palettes.alaska.snow },
			{ "alaska.ice", ArtKit.palettes.alaska.ice },
			{ "shared.deadwood", ArtKit.palettes.shared.deadwood },
			{ "lodge.log", ArtKit.palettes.lodge.log },
			{ "lodge.stone", ArtKit.palettes.lodge.stone },
		}
		for _, entry in MINERAL do
			local name = entry[1] :: string
			local dh, ds, dv = spread(entry[2] :: { Art.RGB })
			t.ok(("%s: hue spread %.1f <= 26 (one material, not many)"):format(name, dh), dh <= 26)
			t.ok(("%s: saturation spread %.3f <= 0.24"):format(name, ds), ds <= 0.24)
			-- but it must still vary in VALUE, or the surface renders as one flat plastic tone
			t.ok(("%s: value spread %.3f >= 0.05"):format(name, dv), dv >= 0.05)
		end
	end)

	t.test("snow-laden foliage is bimodal, not a ramp", function()
		-- The read is the value GAP between lit snow and the shadowed needle under it. A smooth ramp between
		-- them produces grey mush, so this palette is asserted to keep two separated clusters.
		local dh, ds, dv = spread(ArtKit.palettes.shared.snowLaden)
		t.ok(("snowLaden value spread %.3f >= 0.5 (two clusters)"):format(dv), dv >= 0.5)
		t.ok(("snowLaden saturation spread %.3f >= 0.4"):format(ds), ds >= 0.4)
		t.ok(("snowLaden hue spread %.1f is bounded"):format(dh), dh <= 200)
	end)

	t.test("every recipe material is a declared Art.MaterialName", function()
		local bad = 0
		for _, recipe in TREES do
			if (Art.Material :: any)[recipe.barkMaterial] == nil then
				bad += 1
			end
			if (Art.Material :: any)[recipe.foliage.material] == nil then
				bad += 1
			end
		end
		for _, recipe in ROCKS do
			if (Art.Material :: any)[recipe.material] == nil then
				bad += 1
			end
		end
		for _, recipe in CLUSTERS do
			if (Art.Material :: any)[recipe.material] == nil then
				bad += 1
			end
		end
		t.eq("no unknown materials", bad, 0)
	end)

	t.test("terrain roles reference declared terrain materials, and biomes do not share them", function()
		local bad = 0
		local owner: { [string]: string } = {}
		local shared = {}
		for biome, roles in (ArtKit.terrainRoles :: { [string]: any }) do
			for _, mat in roles :: any do
				if (Art.TerrainMaterial :: any)[mat] == nil then
					bad += 1
				end
				local prev = owner[mat]
				if prev ~= nil and prev ~= biome then
					table.insert(shared, ("%s (%s vs %s)"):format(mat, prev, biome))
				end
				owner[mat] = biome
			end
		end
		t.eq("no unknown terrain materials", bad, 0)
		-- Terrain material COLOURS are global to a place, so two biomes sharing a material can never have
		-- independently tuned ground colour. This assertion is what keeps the three looks separable.
		t.eq("no terrain material is claimed by two biomes: " .. table.concat(shared, ", "), #shared, 0)
	end)

	t.test("every terrain material a biome paints with has an authored colour", function()
		local missing = {}
		for _, roles in (ArtKit.terrainRoles :: { [string]: any }) do
			for _, mat in roles :: any do
				if mat ~= "Air" and mat ~= "Water" and ArtKit.terrainColors[mat] == nil then
					table.insert(missing, mat)
				end
			end
		end
		t.eq("no painted material lacks a colour: " .. table.concat(missing, ", "), #missing, 0)
	end)

	t.test("every biome look is complete and physically sane", function()
		for name, look in LOOKS do
			t.ok(name .. ": clockTime in 0..24", look.clockTime >= 0 and look.clockTime <= 24)
			t.ok(name .. ": brightness positive", look.brightness > 0)
			t.ok(name .. ": fogStart < fogEnd", look.fogStart < look.fogEnd)
			t.ok(name .. ": atmosphere density in 0..1", look.atmosphere.density >= 0 and look.atmosphere.density <= 1)
			t.ok(name .. ": cloud cover in 0..1", look.clouds.cover >= 0 and look.clouds.cover <= 1)
			t.ok(
				name .. ": water transparency in 0..1",
				look.water.transparency >= 0 and look.water.transparency <= 1
			)
			t.ok(name .. ": image-based lighting is ON", look.environmentDiffuseScale > 0)
			t.ok(name .. ": wind is non-negative", look.windSpeed >= 0)
		end
	end)
end
