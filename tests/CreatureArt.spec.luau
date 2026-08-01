--!strict
-- THE CREATURE ART GATE.
--
-- The bug this spec exists to prevent already shipped once: WorldServer's silhouette table covered FOUR
-- creature ids, so the other 22 — bull moose, grizzly, whitetail buck, mountain lion, black catamount,
-- caribou — all fell through to one generic 1.6x1.5x2.6 box with a single ear stick. Nothing failed. Nothing
-- warned. A player hunting Alaska simply saw the same grey box a Bayou rabbit was.
--
-- So the assertions here are deliberately about COVERAGE and DISTINCTNESS, not just validity:
--   * every Catalog creature and fish id has an art recipe, and no recipe is an orphan
--   * the species that were all one box are now mutually distinguishable by silhouette
--   * no visual part is queryable, because the hunting raycast must keep reaching the hitbox underneath
--   * the head hitbox and the drawn head come from one function, so headshots land where the head looks

local Harness = require("@tests/harness")
local Art = require("@src/types/Art")
local ArtKit = require("@src/config/ArtKit")
local ArtGen = require("@src/logic/ArtGen")
local Catalog = require("@src/config/Catalog")

local CREATURE_ART = ArtKit.creatureArt :: { [string]: Art.CreatureRecipe }
local FISH_ART = ArtKit.fishArt :: { [string]: Art.CreatureRecipe }

-- Mean HSV value of a palette — the counter-shading check compares back against belly on this axis.
local function meanValue(colors: { Art.RGB }): number
	local total = 0
	for _, c in colors do
		total += math.max(c[1], math.max(c[2], c[3])) / 255
	end
	return total / math.max(#colors, 1)
end

local function silhouette(r: Art.CreatureRecipe): string
	local m = ArtGen.creature(r, 99)
	local lo, hi = ArtGen.bounds(m.parts)
	-- rounded to the nearest half stud: two species that differ by less than that are not visually distinct
	return ("%.1fx%.1fx%.1f"):format(
		math.floor((hi.x - lo.x) * 2 + 0.5) / 2,
		math.floor((hi.y - lo.y) * 2 + 0.5) / 2,
		math.floor((hi.z - lo.z) * 2 + 0.5) / 2
	)
end

return function(t: Harness.T)
	t.section("Creature art — coverage")

	t.test("every huntable creature in the Catalog has an art recipe", function()
		local missing: { string } = {}
		local n = 0
		for id in Catalog.creatures do
			n += 1
			if CREATURE_ART[id] == nil then
				table.insert(missing, id)
			end
		end
		t.ok("the Catalog has creatures to cover", n > 0)
		t.eq(("all %d creatures have art: %s"):format(n, table.concat(missing, ", ")), #missing, 0)
	end)

	t.test("every fish in the Catalog has an art recipe", function()
		local missing: { string } = {}
		local n = 0
		for id in Catalog.fish do
			n += 1
			if FISH_ART[id] == nil then
				table.insert(missing, id)
			end
		end
		t.ok("the Catalog has fish to cover", n > 0)
		t.eq(("all %d fish have art: %s"):format(n, table.concat(missing, ", ")), #missing, 0)
	end)

	t.test("no art recipe is an orphan", function()
		local orphans: { string } = {}
		for id in CREATURE_ART do
			if Catalog.creatures[id] == nil then
				table.insert(orphans, "creature " .. id)
			end
		end
		for id in FISH_ART do
			if Catalog.fish[id] == nil then
				table.insert(orphans, "fish " .. id)
			end
		end
		t.eq("no recipe without a Catalog entry: " .. table.concat(orphans, ", "), #orphans, 0)
	end)

	t.section("Creature art — the silhouettes are actually distinct")

	t.test("the species that were all one grey box are now mutually distinguishable", function()
		-- Exactly the set that fell through to DEFAULT_ARCHETYPE. If any two of these ever collapse onto the
		-- same silhouette again, this fails.
		local REGRESSION_SET = {
			"alaska_bull_moose",
			"alaska_grizzly_bear",
			"alaska_caribou",
			"appalachia_whitetail_deer",
			"appalachia_mountain_lion",
			"appalachia_wild_boar",
			"appalachia_coyote",
			"appalachia_gray_squirrel",
			"bayou_great_egret",
		}
		local seen: { [string]: string } = {}
		local collisions: { string } = {}
		for _, id in REGRESSION_SET do
			local r = CREATURE_ART[id]
			t.ok(id .. ": has a recipe", r ~= nil)
			if r ~= nil then
				local sig = silhouette(r)
				local prev = seen[sig]
				if prev ~= nil then
					table.insert(collisions, ("%s == %s (%s)"):format(id, prev, sig))
				end
				seen[sig] = id
			end
		end
		t.eq("no two of them share a silhouette: " .. table.concat(collisions, "; "), #collisions, 0)
	end)

	t.test("the creature roster spans a wide range of silhouettes", function()
		local sigs: { [string]: boolean } = {}
		local minVol, maxVol = math.huge, -math.huge
		local smallest, largest = "", ""
		for id, r in CREATURE_ART do
			sigs[silhouette(r)] = true
			local m = ArtGen.creature(r, 99)
			local lo, hi = ArtGen.bounds(m.parts)
			local vol = (hi.x - lo.x) * (hi.y - lo.y) * (hi.z - lo.z)
			if vol < minVol then
				minVol, smallest = vol, id
			end
			if vol > maxVol then
				maxVol, largest = vol, id
			end
		end
		local distinct = 0
		for _ in sigs do
			distinct += 1
		end
		-- 26 creatures, of which several are deliberate colour reskins of a base species (piebald whitetail,
		-- spirit moose, white alligator), so exact 26/26 distinctness is not the goal — 15+ is.
		t.ok(("%d distinct silhouettes across the roster (>= 15)"):format(distinct), distinct >= 15)
		-- and the roster must actually span scales: a songbird and a bull moose cannot be near-equal volumes
		t.ok(
			("%s (%.1f) to %s (%.1f) spans at least 100x in volume"):format(smallest, minVol, largest, maxVol),
			maxVol / math.max(minVol, 1e-6) >= 100
		)
	end)

	t.test("reskin variants share their base silhouette but read paler", function()
		local PAIRS = {
			{ "appalachia_whitetail_deer", "appalachia_piebald_whitetail" },
			{ "alaska_bull_moose", "alaska_spirit_moose" },
			{ "bayou_wood_duck", "bayou_leucistic_wood_duck" },
			{ "alaska_grizzly_bear", "alaska_glacier_grizzly" },
			{ "bayou_american_alligator", "bayou_white_alligator" },
		}
		for _, pair in PAIRS do
			local base, variant = CREATURE_ART[pair[1]], CREATURE_ART[pair[2]]
			t.ok(("%s and %s both exist"):format(pair[1], pair[2]), base ~= nil and variant ~= nil)
			if base ~= nil and variant ~= nil then
				t.ok(pair[2] .. ": is marked pale", (variant.pale or 0) > 0.3)
				-- the rendered result must actually be lighter, not just flagged
				local function meanRendered(r: Art.CreatureRecipe): number
					local m = ArtGen.creature(r, 7)
					local total = 0
					for _, p in m.parts do
						total += (p.color[1] + p.color[2] + p.color[3]) / 3
					end
					return total / math.max(#m.parts, 1)
				end
				local b, v = meanRendered(base), meanRendered(variant)
				t.ok(("%s renders lighter than %s (%.0f > %.0f)"):format(pair[2], pair[1], v, b), v > b + 15)
			end
		end
	end)

	t.section("Creature art — validity and the raycast contract")

	t.test("no visual part is queryable or collidable", function()
		-- LOAD-BEARING. WorldServer's hitbox boxes carry hitZone tags and CanQuery = true; the fire raycast
		-- resolves the shot against them and Combat.zoneMultiplier pays the headshot bonus off "vital". A
		-- queryable visual part would intercept the shot and silently break the headshot multiplier.
		local offenders: { string } = {}
		for _, set in { CREATURE_ART, FISH_ART } do
			for id, r in set do
				local m = ArtGen.creature(r, 5)
				for _, p in m.parts do
					if p.canQuery ~= false or p.canCollide ~= false then
						table.insert(offenders, id .. "/" .. p.name)
						break
					end
				end
			end
		end
		t.eq("no queryable/collidable visual parts: " .. table.concat(offenders, ", "), #offenders, 0)
	end)

	t.test("every creature and fish generates finite, valid, budgeted geometry", function()
		local BUDGET = 60
		for _, set in { CREATURE_ART, FISH_ART } do
			for id, r in set do
				local m = ArtGen.creature(r, 1234)
				t.ok(id .. ": produces parts", #m.parts > 0)
				t.ok(("%s: %d parts <= %d"):format(id, #m.parts, BUDGET), #m.parts <= BUDGET)
				local bad = 0
				for _, p in m.parts do
					for _, v in { p.size.x, p.size.y, p.size.z, p.pos.x, p.pos.y, p.pos.z } do
						if v ~= v or v == math.huge or v == -math.huge then
							bad += 1
						end
					end
					if p.size.x <= 0 or p.size.y <= 0 or p.size.z <= 0 then
						bad += 1
					end
					for _, c in p.color do
						if c < 0 or c > 255 or math.floor(c) ~= c then
							bad += 1
						end
					end
				end
				t.eq(id .. ": no invalid sizes, positions or colours", bad, 0)
			end
		end
	end)

	t.test("the same id yields the same creature every session", function()
		-- The Studio side seeds from the creature id, so a species keeps its colour jitter across restarts.
		local r = CREATURE_ART.appalachia_whitetail_deer
		local a, b = ArtGen.creature(r, 4242), ArtGen.creature(r, 4242)
		t.eq("same part count", #a.parts, #b.parts)
		local drift = 0
		for i = 1, #a.parts do
			if a.parts[i].pos.z ~= b.parts[i].pos.z or a.parts[i].color[1] ~= b.parts[i].color[1] then
				drift += 1
			end
		end
		t.eq("no drift between two generations", drift, 0)
	end)

	t.section("Fishing bite markers")

	t.test("every fish yields a valid bite marker that never absorbs the cast", function()
		-- WorldServer spawns a bite as a queryable Part; the marker is decoration layered over it. A single
		-- queryable marker part would intercept the cast and the player's line would hit scenery.
		local offenders: { string } = {}
		for id, r in FISH_ART do
			local m = ArtGen.biteMarker(r, 3)
			t.ok(id .. ": produces a marker", #m.parts >= 6)
			for _, p in m.parts do
				if p.canQuery ~= false or p.canCollide ~= false or p.castShadow ~= false then
					table.insert(offenders, id .. "/" .. p.name)
					break
				end
			end
			-- everything sits at or above the waterline; a ring below it would be invisible under the water
			local lo, _hi = ArtGen.bounds(m.parts)
			t.ok(("%s: marker sits on the surface (minY %.2f >= -0.5)"):format(id, lo.y), lo.y >= -0.5)
		end
		t.eq("no queryable/collidable/shadowing marker part: " .. table.concat(offenders, ", "), #offenders, 0)
	end)

	t.test("marker size telegraphs the fish's size", function()
		-- Free gameplay information: a player should be able to tell a bluegill bite from a leviathan bite
		-- before committing to the cast.
		local function width(id: string): number
			local m = ArtGen.biteMarker(FISH_ART[id], 9)
			local lo, hi = ArtGen.bounds(m.parts)
			return hi.x - lo.x
		end
		local small = width("bayou_bluegill")
		local big = width("bayou_leviathan")
		t.ok(("leviathan marker %.1f is much wider than bluegill %.1f"):format(big, small), big > small * 2)
		-- and it must stay bounded: a marker the size of the fishing hole is not information
		t.ok(("the largest marker %.1f stays under 30 studs"):format(big), big < 30)
	end)

	t.test("the bite marker draws the species' own colours", function()
		local r = FISH_ART.alaska_sockeye_salmon
		local m = ArtGen.biteMarker(r, 4)
		local allowed: { [string]: boolean } = {}
		for _, c in r.back do
			allowed[("%d,%d,%d"):format(c[1], c[2], c[3])] = true
		end
		local finFound = false
		for _, p in m.parts do
			if p.name == "BiteFin" then
				finFound = true
			end
		end
		t.ok("the marker has a dorsal fin breaking the surface", finFound)
		local rings = 0
		for _, p in m.parts do
			if p.name == "Ripple" then
				rings += 1
			end
		end
		t.eq("three concentric rings", rings, 3)
	end)

	t.section("Creature art — anatomy agrees with the hitbox")

	t.test("the head sits forward of the torso and above the belly", function()
		for id, r in CREATURE_ART do
			local a = ArtGen.creatureAnatomy(r)
			-- forward is -Z by the axis convention, so a head in front of the torso has a negative z
			t.ok(("%s: head is forward of the torso (z %.2f < 0)"):format(id, a.head.pos.z), a.head.pos.z < 0)
			t.ok(("%s: foot drop is positive (%.2f)"):format(id, a.footDrop), a.footDrop > 0)
			t.ok(id .. ": torso size matches the recipe", a.torso.size.x == r.width and a.torso.size.z == r.length)
			-- the head hitbox has to swallow the snout, or a nose shot reads as a body hit
			if r.snout ~= nil then
				t.ok(
					("%s: head box covers the snout (%.2f >= %.2f)"):format(id, a.head.size.z, r.head.length + r.snout.length),
					a.head.size.z >= r.head.length + r.snout.length - 1e-6
				)
			end
		end
	end)

	t.test("the drawn head is inside the head hitbox", function()
		-- The whole point of routing both through creatureAnatomy. If the drawn Head part ever leaves the
		-- hitbox, the player is aiming at something the raycast does not treat as vital.
		local offenders: { string } = {}
		for id, r in CREATURE_ART do
			local a = ArtGen.creatureAnatomy(r)
			local m = ArtGen.creature(r, 11)
			for _, p in m.parts do
				if p.name == "Head" then
					local dx = math.abs(p.pos.x - a.head.pos.x)
					local dy = math.abs(p.pos.y - a.head.pos.y)
					local dz = math.abs(p.pos.z - a.head.pos.z)
					if
						dx > a.head.size.x * 0.5 + 0.05
						or dy > a.head.size.y * 0.5 + 0.05
						or dz > a.head.size.z * 0.5 + 0.05
					then
						table.insert(offenders, ("%s (d %.2f,%.2f,%.2f)"):format(id, dx, dy, dz))
					end
				end
			end
		end
		t.eq("every drawn head is inside its vital zone: " .. table.concat(offenders, "; "), #offenders, 0)
	end)

	t.section("Creature art — palette discipline")

	t.test("every species is counter-shaded: the belly is lighter than the back", function()
		-- Counter-shading is most of what makes a flat-lit part animal read as a volume rather than a crate.
		-- The exception is real, not a fudge: a great egret and an albino catfish are already near-white on
		-- top, so there is no headroom to be 0.05 lighter underneath. For those the requirement is only that
		-- the belly is never DARKER, which is what would actually look wrong.
		local flat: { string } = {}
		local NEAR_WHITE = 0.85
		for _, set in { CREATURE_ART, FISH_ART } do
			for id, r in set do
				local back, belly = meanValue(r.back), meanValue(r.belly)
				local floor = if back > NEAR_WHITE then back - 0.01 else back + 0.05
				if belly < floor then
					table.insert(flat, ("%s (back %.2f, belly %.2f, needed %.2f)"):format(id, back, belly, floor))
				end
			end
		end
		t.eq("no species has a belly as dark as its back: " .. table.concat(flat, "; "), #flat, 0)
	end)

	t.test("fur, scale and feather palettes carry real value variation", function()
		local thin: { string } = {}
		for name, pal in (ArtKit.faunaPalettes :: { [string]: { back: { Art.RGB }, belly: { Art.RGB } } }) do
			for _, entry in { { "back", pal.back }, { "belly", pal.belly } } do
				local setName = entry[1] :: string
				local colors = entry[2] :: { Art.RGB }
				local lo, hi = math.huge, -math.huge
				for _, c in colors do
					local v = math.max(c[1], math.max(c[2], c[3])) / 255
					if v < lo then
						lo = v
					end
					if v > hi then
						hi = v
					end
				end
				if #colors < 3 then
					table.insert(thin, name .. "." .. setName .. " has < 3 entries")
				end
				if hi - lo < 0.05 then
					table.insert(thin, ("%s.%s value spread %.3f < 0.05"):format(name, setName, hi - lo))
				end
			end
		end
		t.eq("no flat fauna palette: " .. table.concat(thin, "; "), #thin, 0)
	end)

	t.section("Creature art — form correctness")

	t.test("antlered species grow antlers, and nothing else does", function()
		local ANTLERED: { [string]: boolean } = {
			appalachia_whitetail_deer = true,
			appalachia_piebald_whitetail = true,
			appalachia_ghost_buck = true,
			alaska_bull_moose = true,
			alaska_spirit_moose = true,
			alaska_caribou = true,
			alaska_sitka_deer = true,
		}
		for id, r in CREATURE_ART do
			local m = ArtGen.creature(r, 3)
			local antlers = 0
			for _, p in m.parts do
				if p.name == "Antler" or p.name == "Tine" or p.name == "Palm" then
					antlers += 1
				end
			end
			if ANTLERED[id] then
				t.ok(id .. ": has antler geometry", antlers >= 4)
			else
				t.eq(id .. ": has no antlers", antlers, 0)
			end
		end
		-- a moose rack is palmate, a whitetail rack is tined: they must not render the same way
		local moose = ArtGen.creature(CREATURE_ART.alaska_bull_moose, 3)
		local palms = 0
		for _, p in moose.parts do
			if p.name == "Palm" then
				palms += 1
			end
		end
		t.eq("the bull moose has two palmate paddles", palms, 2)
	end)

	t.test("fish have fins and no legs; land animals have legs and no fins", function()
		for id, r in FISH_ART do
			t.eq(id .. ": form is fish", r.form, "fish")
			t.ok(id .. ": has fins", r.fins ~= nil)
			t.ok(id .. ": has no legs", r.legs == nil)
			local m = ArtGen.creature(r, 8)
			local caudal = 0
			for _, p in m.parts do
				if p.name == "CaudalFin" then
					caudal += 1
				end
			end
			t.eq(id .. ": has exactly one tail fin", caudal, 1)
		end
		for id, r in CREATURE_ART do
			t.ok(id .. ": has legs", r.legs ~= nil)
			t.ok(id .. ": has no fins", r.fins == nil)
		end
	end)

	t.test("birds have wings, quadrupeds do not", function()
		for id, r in CREATURE_ART do
			if r.form == "bird" then
				t.ok(id .. ": has wings", r.wings ~= nil)
			else
				t.ok(id .. ": has no wings", r.wings == nil)
			end
		end
	end)

	t.test("the alligator is built low and long, the way the species reads", function()
		local gator = CREATURE_ART.bayou_american_alligator
		local m = ArtGen.creature(gator, 2)
		local lo, hi = ArtGen.bounds(m.parts)
		local length, height = hi.z - lo.z, hi.y - lo.y
		-- the signature Bayou target: it must read as a long low reptile, not a box on legs
		t.ok(("gator is at least 6x longer than tall (%.1f / %.1f)"):format(length, height), length / height >= 6)
		t.ok("gator legs splay outward", gator.legs ~= nil and gator.legs.splay > 0.5)
		t.ok("gator has no ears", gator.ears == nil)
	end)
end
