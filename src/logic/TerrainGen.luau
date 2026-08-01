--!strict
-- PURE terrain generation. Produces a HEIGHTFIELD and a per-column material from seeded noise, plus the
-- flattening and basin-carving that keep the authored gameplay zones playable. The Studio side samples
-- these functions and pushes the result through Terrain:WriteVoxels — it makes no terrain decisions itself.
--
-- WHY PURE. The reference bar's landmasses are sculpted smooth Terrain, not parts, and the previous Wild
-- World build approximated that with a handful of FillBlock slabs and FillBall blobs — flat pans with
-- spheres on them. Real sculpting needs noise, and noise needs to be verifiable: this module lets
-- ./run-tests.sh assert the things that actually ruin a world — a hunting zone on a 40-degree slope, a
-- fishing zone with no water in it, a spawn point inside a hill, a discontinuity the player can fall through.
--
-- Zero content literals: every amplitude, frequency, band threshold and anchor arrives in the spec.

local Art = require("../types/Art")
local Rand = require("./Rand")

type TerrainMaterialName = Art.TerrainMaterialName
type TerrainColumn = Art.TerrainColumn
type FbmParams = Rand.FbmParams

local TerrainGen = {}

-- A disc that pulls the heightfield toward a fixed height — this is what makes a zone stand on flat,
-- walkable ground instead of wherever the noise happened to land.
export type Flat = {
	x: number,
	z: number,
	radius: number, -- fully flat inside this
	falloff: number, -- blends back to natural terrain across this extra distance
	height: number,
}

-- A disc that subtracts height, carving a basin the water level then fills.
export type Basin = {
	x: number,
	z: number,
	radius: number,
	falloff: number,
	depth: number, -- studs below the basin's rim
}

-- Material banding by altitude, evaluated in ascending order: the first band whose `upTo` is at or above
-- the column's height wins, and the last band is the fallback for everything higher. An ordered LIST rather
-- than named roles because the interesting cases are not symmetric — a swamp needs submerged mud BELOW a
-- narrow sand waterline strip, which a fixed beach/bank/ground/high schema cannot express.
export type HeightBand = { upTo: number, material: TerrainMaterialName }

export type BiomeTerrainSpec = {
	seed: number,
	extent: { x: number, z: number }, -- playable footprint, centred on the biome's local origin
	center: { x: number, z: number },
	amplitude: number, -- studs of large-scale relief
	detailAmplitude: number,
	base: FbmParams,
	detail: FbmParams,
	ridged: boolean, -- ridged multifractal (mountains) vs plain fbm (lowland)
	baseHeight: number, -- height the noise is measured from
	waterLevel: number, -- water fills every column whose surface is below this
	shoreFalloff: number, -- studs of taper at the map edge, so the world ends in water not a wall
	flats: { Flat },
	basins: { Basin },
	bands: { HeightBand }, -- ascending by `upTo`; the last entry is the fallback for anything higher
	cliffSlope: number, -- gradient (rise per run) at/above which the column is a cliff face
	cliffMaterial: TerrainMaterialName,
}

-- ── height ────────────────────────────────────────────────────────────────────────────────────────────

-- Raw noise relief before flats, basins and the shore taper.
function TerrainGen.naturalHeight(spec: BiomeTerrainSpec, x: number, z: number): number
	local n = if spec.ridged
		then Rand.ridge2(x, z, spec.seed, spec.base)
		else Rand.fbm2(x, z, spec.seed, spec.base)
	local d = Rand.fbm2(x, z, spec.seed + 7717, spec.detail)
	return spec.baseHeight + n * spec.amplitude + (d - 0.5) * 2 * spec.detailAmplitude
end

-- Weight of a disc at (x, z): 1 inside `radius`, easing to 0 across `falloff`.
local function discWeight(x: number, z: number, cx: number, cz: number, radius: number, falloff: number): number
	local dx, dz = x - cx, z - cz
	local d = math.sqrt(dx * dx + dz * dz)
	if d <= radius then
		return 1
	end
	if falloff <= 0 or d >= radius + falloff then
		return 0
	end
	return 1 - Rand.smoothstep(radius, radius + falloff, d)
end

TerrainGen.discWeight = discWeight

-- The finished surface height.
--
-- ORDER IS LOAD-BEARING, and got this wrong once: basins were applied AFTER flats, so a fishing basin whose
-- falloff reached a neighbouring zone punched straight through it — the Bayou arrival clearing came out 81%
-- underwater because the channel basin 27 studs away subtracted 7 studs from it. Basins are now natural
-- depressions applied to the NOISE, and flats are the authoritative last word on a zone's elevation.
--
-- Flats compose by WEIGHTED AVERAGE, not winner-take-all. Winner-take-all leaves a hard step wherever two
-- discs both reach full strength; averaging turns the same overlap into a graded shoreline, which is exactly
-- what you want where a dry clearing meets a fishing channel. A flat's `height` may be BELOW waterLevel —
-- that is how water zones are authored, and it is why they no longer need a basin at all.
function TerrainGen.heightAt(spec: BiomeTerrainSpec, x: number, z: number): number
	local h = TerrainGen.naturalHeight(spec, x, z)

	for _, b in spec.basins do
		local w = discWeight(x, z, b.x, b.z, b.radius, b.falloff)
		if w > 0 then
			h -= b.depth * w
		end
	end

	local sumW, sumWH = 0, 0
	for _, f in spec.flats do
		local w = discWeight(x, z, f.x, f.z, f.radius, f.falloff)
		if w > 0 then
			sumW += w
			sumWH += w * f.height
		end
	end
	if sumW > 0 then
		h = Rand.lerp(h, sumWH / sumW, math.min(sumW, 1))
	end

	-- shore taper, measured from the playable rectangle's edge
	local hx = spec.extent.x * 0.5
	local hz = spec.extent.z * 0.5
	local edge = math.max(math.abs(x - spec.center.x) - hx, math.abs(z - spec.center.z) - hz)
	if edge > 0 then
		local t = Rand.clamp(edge / math.max(spec.shoreFalloff, 1e-6), 0, 1)
		-- drops to a full amplitude below the water line, guaranteeing open water past the boundary
		h = Rand.lerp(h, spec.waterLevel - spec.amplitude * 0.5 - 8, Rand.smoothstep(0, 1, t))
	end

	return h
end

-- Gradient magnitude (rise per run) via central differences. `h` is the sample spacing in studs; use the
-- voxel resolution so the slope you measure is the slope the engine will actually build.
function TerrainGen.slopeAt(spec: BiomeTerrainSpec, x: number, z: number, h: number): number
	local dx = (TerrainGen.heightAt(spec, x + h, z) - TerrainGen.heightAt(spec, x - h, z)) / (2 * h)
	local dz = (TerrainGen.heightAt(spec, x, z + h) - TerrainGen.heightAt(spec, x, z - h)) / (2 * h)
	return math.sqrt(dx * dx + dz * dz)
end

-- ── material ──────────────────────────────────────────────────────────────────────────────────────────

-- Which material a column's surface is made of. Slope wins over altitude: a steep column is cliff face
-- regardless of how high it is, which is what stops a vertical snowfield reading as a frosted lawn.
function TerrainGen.materialAt(spec: BiomeTerrainSpec, height: number, slope: number): TerrainMaterialName
	if slope >= spec.cliffSlope then
		return spec.cliffMaterial
	end
	for _, band in spec.bands do
		if height <= band.upTo then
			return band.material
		end
	end
	return spec.bands[#spec.bands].material
end

-- One fully resolved column. `waterTop` is set when the surface sits below the water line, which is what
-- the instantiator uses to decide whether to fill Water above the ground.
function TerrainGen.column(spec: BiomeTerrainSpec, x: number, z: number, sampleSpacing: number): TerrainColumn
	local height = TerrainGen.heightAt(spec, x, z)
	local slope = TerrainGen.slopeAt(spec, x, z, sampleSpacing)
	return {
		x = x,
		z = z,
		height = height,
		material = TerrainGen.materialAt(spec, height, slope),
		waterTop = if height < spec.waterLevel then spec.waterLevel else nil,
	}
end

-- ── walkability, as an assertable property ────────────────────────────────────────────────────────────

export type ZoneProbe = {
	maxSlope: number, -- worst gradient found in the disc
	meanSlope: number,
	minHeight: number,
	maxHeight: number,
	relief: number, -- maxHeight - minHeight
	waterFraction: number, -- share of samples below the water line
	samples: number,
}

-- Probe a disc of terrain. This is the primitive the tests use to prove a hunting zone is walkable and a
-- fishing zone actually contains water, before anyone opens Studio.
function TerrainGen.probe(
	spec: BiomeTerrainSpec,
	cx: number,
	cz: number,
	radius: number,
	rings: number,
	spokes: number,
	sampleSpacing: number
): ZoneProbe
	local maxSlope, sumSlope = 0, 0
	local minH, maxH = math.huge, -math.huge
	local wet, n = 0, 0
	local ringCount = math.max(1, math.floor(rings))
	local spokeCount = math.max(1, math.floor(spokes))
	for ri = 0, ringCount do
		local r = radius * (ri / ringCount)
		-- the centre is one sample, not `spokes` duplicates
		local count = if ri == 0 then 1 else spokeCount
		for si = 0, count - 1 do
			local a = (si / count) * math.pi * 2
			local x = cx + math.cos(a) * r
			local z = cz + math.sin(a) * r
			local h = TerrainGen.heightAt(spec, x, z)
			local s = TerrainGen.slopeAt(spec, x, z, sampleSpacing)
			if s > maxSlope then
				maxSlope = s
			end
			sumSlope += s
			if h < minH then
				minH = h
			end
			if h > maxH then
				maxH = h
			end
			if h < spec.waterLevel then
				wet += 1
			end
			n += 1
		end
	end
	return {
		maxSlope = maxSlope,
		meanSlope = sumSlope / n,
		minHeight = minH,
		maxHeight = maxH,
		relief = maxH - minH,
		waterFraction = wet / n,
		samples = n,
	}
end

-- ── voxel planning ────────────────────────────────────────────────────────────────────────────────────

-- The vertical span the instantiator must write, derived from the actual heightfield rather than guessed:
-- writing fewer voxels than the terrain occupies leaves floating shelves, writing far more is wasted time.
export type VoxelSpan = { minY: number, maxY: number, columns: number }

function TerrainGen.voxelSpan(spec: BiomeTerrainSpec, resolution: number, margin: number): VoxelSpan
	local res = math.max(resolution, 1)
	local hx, hz = spec.extent.x * 0.5 + spec.shoreFalloff, spec.extent.z * 0.5 + spec.shoreFalloff
	local minH, maxH = math.huge, -math.huge
	local columns = 0
	-- a coarse sweep is enough for a bound; the instantiator clamps anyway
	local step = res * 2
	local x = spec.center.x - hx
	while x <= spec.center.x + hx do
		local z = spec.center.z - hz
		while z <= spec.center.z + hz do
			local h = TerrainGen.heightAt(spec, x, z)
			if h < minH then
				minH = h
			end
			if h > maxH then
				maxH = h
			end
			columns += 1
			z += step
		end
		x += step
	end
	local top = math.max(maxH, spec.waterLevel)
	return {
		minY = math.floor((minH - margin) / res) * res,
		maxY = math.ceil((top + margin) / res) * res,
		columns = columns,
	}
end

return table.freeze(TerrainGen)
