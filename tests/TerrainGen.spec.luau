--!strict
-- The generated TERRAIN under headless assertion, driven off the real gameplay layout.
--
-- The zone list is derived from src/config/Shells.luau rather than restated here, so a zone added to the
-- shell is automatically covered: if someone drops a new fishing hole into the Bayou and the sculpt leaves
-- it high and dry, this spec fails without anyone remembering to update it.
--
-- What it proves: hunting/arrival/vendor ground is dry and not a cliff face, fishing water is actually
-- water, the world is bounded by water rather than by an invisible wall, the heightfield is continuous, the
-- flats hold their authored elevation, and the material banding resolves the way the palette assumes.

local Harness = require("@tests/harness")
local Art = require("@src/types/Art")
local ArtKit = require("@src/config/ArtKit")
local Shells = require("@src/config/Shells")
local TerrainGen = require("@src/logic/TerrainGen")
local Schema = require("@src/types/Schema")

type Spec = TerrainGen.BiomeTerrainSpec

local SPECS = ArtKit.terrainSpecs :: { [string]: Spec }
-- The voxel resolution the instantiator writes at; slope must be measured at the same spacing, or the test
-- would be judging a surface finer than the engine will ever build.
local RES = 4

-- Zones the player must stand and hunt on. `rareSite` is deliberately excluded: cottonmouth_slough is
-- water and salmon_falls is land, so the kind alone does not determine the element.
local DRY_KINDS: { [string]: boolean } = { arrival = true, hunting = true, vendor = true }
local WET_KINDS: { [string]: boolean } = { fishing = true }

return function(t: Harness.T)
	t.section("TerrainGen — the sculpt is driven by the gameplay layout")

	t.test("every destination shell has a terrain spec", function()
		local missing = {}
		for destId in Shells.byDestination do
			if SPECS[destId] == nil then
				table.insert(missing, destId)
			end
		end
		t.eq("no shell lacks a sculpt: " .. table.concat(missing, ", "), #missing, 0)
	end)

	t.test("material bands are ascending and end in an open-topped fallback", function()
		for name, spec in SPECS do
			local ascending = true
			for i = 2, #spec.bands do
				if spec.bands[i].upTo < spec.bands[i - 1].upTo then
					ascending = false
				end
			end
			t.ok(name .. ": bands ascend by height", ascending)
			t.ok(name .. ": has at least two bands", #spec.bands >= 2)
			t.ok(name .. ": the top band is open-ended", spec.bands[#spec.bands].upTo == math.huge)
			t.ok(name .. ": cliff slope is positive", spec.cliffSlope > 0)
		end
	end)

	t.test("heightAt is deterministic", function()
		for name, spec in SPECS do
			local same = true
			for i = 1, 60 do
				local x, z = i * 13.7 - 200, i * -7.3 + 90
				if TerrainGen.heightAt(spec, x, z) ~= TerrainGen.heightAt(spec, x, z) then
					same = false
				end
			end
			t.ok(name .. ": same point, same height", same)
		end
	end)

	t.test("the heightfield is continuous at voxel resolution", function()
		-- A jump larger than the biome's own relief between two adjacent voxel columns would be a wall or a
		-- hole the player can fall through. This is the assertion that would have caught a broken
		-- interpolation in the noise, which is invisible until you walk the world.
		for name, spec in SPECS do
			local worst = 0
			local x = spec.center.x - spec.extent.x * 0.5
			while x <= spec.center.x + spec.extent.x * 0.5 do
				local z = spec.center.z - spec.extent.z * 0.5
				local prev: number? = nil
				while z <= spec.center.z + spec.extent.z * 0.5 do
					local h = TerrainGen.heightAt(spec, x, z)
					if prev ~= nil then
						local d = math.abs(h - prev)
						if d > worst then
							worst = d
						end
					end
					prev = h
					z += RES
				end
				x += RES * 5
			end
			-- Carved gorge walls and cliff faces are intentional and DO exceed 45 degrees, so the bar here is
			-- not steepness — it is continuity. A genuine break in the heightfield (bad interpolation, a
			-- lattice seam, an unclamped flat) shows up as a step many times the biome's own relief.
			t.ok(
				("%s: worst adjacent-column step %.2f studs over %d (< %d)"):format(name, worst, RES, RES * 6),
				worst < RES * 6
			)
		end
	end)

	t.test("each flat holds its authored elevation at its centre", function()
		for name, spec in SPECS do
			local bad = {}
			for i, f in spec.flats do
				local h = TerrainGen.heightAt(spec, f.x, f.z)
				-- Neighbouring flats blend in by weighted average, so the centre is allowed to drift — but a
				-- large drift means two zones are fighting, which is exactly the bug that put the Bayou
				-- arrival clearing underwater. 4 studs is the tolerance.
				if math.abs(h - f.height) > 4 then
					table.insert(bad, ("%s flat %d wanted %.1f got %.1f"):format(name, i, f.height, h))
				end
			end
			t.eq(name .. ": no flat is overpowered by a neighbour: " .. table.concat(bad, "; "), #bad, 0)
		end
	end)

	t.test("the world is bounded by water, not by a wall", function()
		for name, spec in SPECS do
			local hx = spec.extent.x * 0.5 + spec.shoreFalloff + RES
			local hz = spec.extent.z * 0.5 + spec.shoreFalloff + RES
			local dry = 0
			local n = 0
			for i = 0, 40 do
				local a = (i / 41) * math.pi * 2
				-- The shore taper is measured with a CHEBYSHEV edge distance (max of the two axes), so the
				-- boundary is a rectangle. Sampling an ellipse put the 45-degree samples ~30% inside the
				-- taper, where the world is legitimately still dry — the test was wrong, not the terrain.
				local cx, cz = math.cos(a), math.sin(a)
				local k = math.max(math.abs(cx), math.abs(cz))
				local x = spec.center.x + (cx / k) * hx
				local z = spec.center.z + (cz / k) * hz
				if TerrainGen.heightAt(spec, x, z) >= spec.waterLevel then
					dry += 1
				end
				n += 1
			end
			t.eq(("%s: the boundary ring is fully below the water line (%d/%d dry)"):format(name, dry, n), dry, 0)
		end
	end)

	t.section("TerrainGen — every gameplay zone is the right element")

	t.test("dry zones are dry, above water, and not rendered as cliff face", function()
		for destId, shell in Shells.byDestination do
			local spec = SPECS[destId]
			if spec ~= nil then
				for _, zone in (shell.zones :: { [string]: Schema.Zone }) do
					if DRY_KINDS[zone.kind] then
						-- probe the inner half of the zone: the outer edge is allowed to meet a shoreline
						local radius = math.max(zone.size.x, zone.size.z) * 0.25
						local p = TerrainGen.probe(spec, zone.center.x, zone.center.z, radius, 3, 10, RES)
						local centreH = TerrainGen.heightAt(spec, zone.center.x, zone.center.z)
						local centreSlope = TerrainGen.slopeAt(spec, zone.center.x, zone.center.z, RES)
						t.ok(
							("%s/%s: centre is above water (%.1f > %.1f)"):format(destId, zone.id, centreH, spec.waterLevel),
							centreH > spec.waterLevel
						)
						t.ok(
							("%s/%s: centre is walkable ground, not cliff (slope %.2f < %.2f)"):format(
								destId,
								zone.id,
								centreSlope,
								spec.cliffSlope
							),
							centreSlope < spec.cliffSlope
						)
						t.ok(
							("%s/%s: mostly dry (%.0f%% wet)"):format(destId, zone.id, p.waterFraction * 100),
							p.waterFraction <= 0.25
						)
						t.ok(
							("%s/%s: mean slope %.2f is not a cliff face"):format(destId, zone.id, p.meanSlope),
							p.meanSlope < spec.cliffSlope
						)
					end
				end
			end
		end
	end)

	t.test("fishing zones actually contain water", function()
		for destId, shell in Shells.byDestination do
			local spec = SPECS[destId]
			if spec ~= nil then
				for _, zone in (shell.zones :: { [string]: Schema.Zone }) do
					if WET_KINDS[zone.kind] then
						local radius = math.max(zone.size.x, zone.size.z) * 0.25
						local p = TerrainGen.probe(spec, zone.center.x, zone.center.z, radius, 3, 10, RES)
						local centreH = TerrainGen.heightAt(spec, zone.center.x, zone.center.z)
						t.ok(
							("%s/%s: centre is below the water line (%.1f < %.1f)"):format(
								destId,
								zone.id,
								centreH,
								spec.waterLevel
							),
							centreH < spec.waterLevel
						)
						-- A fishing hole that is only wet at one point is not fishable: the player has to be
						-- able to stand somewhere and have water in casting range.
						t.ok(
							("%s/%s: majority of the zone is water (%.0f%%)"):format(
								destId,
								zone.id,
								p.waterFraction * 100
							),
							p.waterFraction >= 0.6
						)
					end
				end
			end
		end
	end)

	t.test("every landmark anchor stands on solid, above-water ground", function()
		-- Landmarks are the §2.2 wayfinding beacons; a beacon standing in a lake reads as a bug.
		for destId, shell in Shells.byDestination do
			local spec = SPECS[destId]
			if spec ~= nil then
				-- A landmark may itself BE a water feature — mill_pond, hollow_creek, open_gulf and
				-- frozen_lake are all fishing zones promoted to landmarks — so only the dry-land beacons
				-- are held to standing on solid ground.
				local wetZone: { [string]: boolean } = {}
				for _, zone in (shell.zones :: { [string]: Schema.Zone }) do
					if WET_KINDS[zone.kind] then
						wetZone[zone.id] = true
					end
				end
				for _, lm in (shell.landmarks :: { [string]: Schema.Landmark }) do
					if not wetZone[lm.id] then
						local h = TerrainGen.heightAt(spec, lm.anchor.x, lm.anchor.z)
						t.ok(
							("%s/%s: dry-land landmark anchor is above water (%.1f)"):format(destId, lm.id, h),
							h > spec.waterLevel
						)
					end
				end
			end
		end
	end)

	t.section("TerrainGen — material banding")

	t.test("submerged ground uses the biome's bed material, high ground its summit material", function()
		for name, spec in SPECS do
			local bed = spec.bands[1].material
			local summit = spec.bands[#spec.bands].material
			-- a column well below the water line, on flat ground
			local deep = TerrainGen.materialAt(spec, spec.bands[1].upTo - 5, 0)
			t.eq(name .. ": deep water bed is the first band", deep, bed)
			-- a column above every band's ceiling, on flat ground
			local high = TerrainGen.materialAt(spec, spec.bands[#spec.bands - 1].upTo + 50, 0)
			t.eq(name .. ": above the top band is the summit material", high, summit)
			-- slope beats altitude
			local steep = TerrainGen.materialAt(spec, spec.bands[1].upTo - 5, spec.cliffSlope + 0.5)
			t.eq(name .. ": a steep column is cliff regardless of height", steep, spec.cliffMaterial)
		end
	end)

	t.test("a biome only ever paints with the materials it declares", function()
		local roles = ArtKit.terrainRoles :: { [string]: any }
		for name, spec in SPECS do
			local declared: { [string]: boolean } = {}
			for _, mat in roles[name] do
				declared[mat] = true
			end
			local strays: { string } = {}
			for _, band in spec.bands do
				if not declared[band.material] then
					table.insert(strays, band.material :: any)
				end
			end
			if not declared[spec.cliffMaterial] then
				table.insert(strays, spec.cliffMaterial :: any)
			end
			-- Terrain material colours are GLOBAL to the place, so a biome painting outside its declared set
			-- would silently recolour another biome's ground.
			t.eq(name .. ": no material outside its declared set: " .. table.concat(strays, ", "), #strays, 0)
		end
	end)

	t.test("a sweep of the whole biome only produces declared materials", function()
		local roles = ArtKit.terrainRoles :: { [string]: any }
		for name, spec in SPECS do
			local declared: { [string]: boolean } = {}
			for _, mat in roles[name] do
				declared[mat] = true
			end
			local seen: { [string]: number } = {}
			local strays = 0
			local matName: (Art.TerrainMaterialName) -> string = function(m)
				return m :: any
			end
			local x = spec.center.x - spec.extent.x * 0.5
			while x <= spec.center.x + spec.extent.x * 0.5 do
				local z = spec.center.z - spec.extent.z * 0.5
				while z <= spec.center.z + spec.extent.z * 0.5 do
					local col = TerrainGen.column(spec, x, z, RES)
					local key = matName(col.material)
					seen[key] = (seen[key] or 0) + 1
					if not declared[key] then
						strays += 1
					end
					z += RES * 6
				end
				x += RES * 6
			end
			t.eq(name .. ": no stray material across the whole footprint", strays, 0)
			local kinds = 0
			for _ in seen do
				kinds += 1
			end
			-- A biome that resolves to one material everywhere is a flat pan, which is what the previous
			-- FillBlock sculpt produced. Real relief shows at least three of its bands.
			t.ok(("%s: the sculpt uses %d distinct materials (>= 3)"):format(name, kinds), kinds >= 3)
			t.ok(name .. ": every terrain material is a declared Art.TerrainMaterialName", (function()
				for mat in seen do
					if (Art.TerrainMaterial :: any)[mat] == nil then
						return false
					end
				end
				return true
			end)())
		end
	end)

	t.section("TerrainGen — voxel planning")

	t.test("the voxel span covers the real height range and stays affordable", function()
		for name, spec in SPECS do
			local span = TerrainGen.voxelSpan(spec, RES, 8)
			t.ok(name .. ": span is resolution-aligned", span.minY % RES == 0 and span.maxY % RES == 0)
			t.ok(name .. ": span is non-empty", span.maxY > span.minY)
			t.ok(name .. ": span reaches the water line", span.maxY >= spec.waterLevel)
			-- verify against an independent dense sweep: nothing may poke out of the span
			local worstHigh, worstLow = -math.huge, math.huge
			local x = spec.center.x - spec.extent.x * 0.5
			while x <= spec.center.x + spec.extent.x * 0.5 do
				local z = spec.center.z - spec.extent.z * 0.5
				while z <= spec.center.z + spec.extent.z * 0.5 do
					local h = TerrainGen.heightAt(spec, x, z)
					if h > worstHigh then
						worstHigh = h
					end
					if h < worstLow then
						worstLow = h
					end
					z += RES * 3
				end
				x += RES * 3
			end
			t.ok(
				("%s: span top %.0f covers the tallest column %.1f"):format(name, span.maxY, worstHigh),
				span.maxY >= worstHigh
			)
			t.ok(
				("%s: span floor %.0f is under the lowest column %.1f"):format(name, span.minY, worstLow),
				span.minY <= worstLow
			)
			local layers = (span.maxY - span.minY) / RES
			t.ok(("%s: %d voxel layers (<= 80)"):format(name, layers), layers <= 80)
		end
	end)
end
