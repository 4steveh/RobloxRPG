--!strict
-- PURE procedural geometry generators. Given a recipe (src/config/ArtKit.luau) and a seed, each function
-- returns an Art.ModelDesc — a bag of part descriptors in the model's own coordinate space. No Roblox
-- globals, no content literals: every dimension, colour and count comes from the recipe argument.
--
-- WHY THIS EXISTS. The reference bar (Roblox's own Pirate Island template) is 15,364 plain Parts and zero
-- MeshParts: its polish comes from part-level density, per-part colour variation inside a single model,
-- and a tuned lighting stack — not from imported assets. Generating that geometry from seeded pure
-- functions makes it (a) reproducible from the repo with no asset-authorisation dependency, and (b) the
-- first art layer in this project that ./run-tests.sh can actually assert on.
--
-- CONVENTIONS
--   * A model is authored with its ground contact at y = 0 and `groundPivot` = origin, so the Studio
--     instantiator can drop it onto a raycast hit without re-deriving a bounding box.
--   * Orientation is (up, yaw) per Art's orientation contract — never Euler triples.
--   * Decorative parts set canCollide = false / canQuery = false so they never block a player or absorb a
--     hunting raycast. Only structural parts (trunks, walls, floors) stay collidable.

local Art = require("../types/Art")
local Rand = require("./Rand")
local Vec = require("./Vec")

type Vec3 = Art.Vec3
type RGB = Art.RGB
type PartDesc = Art.PartDesc
type ModelDesc = Art.ModelDesc
type TreeRecipe = Art.TreeRecipe
type RockRecipe = Art.RockRecipe
type ClusterRecipe = Art.ClusterRecipe
type CabinRecipe = Art.CabinRecipe
type FoliageRecipe = Art.FoliageRecipe
type Stream = Rand.Stream

local UP: Vec3 = { x = 0, y = 1, z = 0 }
local TAU = math.pi * 2

local ArtGen = {}

-- ── colour ────────────────────────────────────────────────────────────────────────────────────────────

-- Blend `a` toward `b` by t, staying in 0..255 integers.
function ArtGen.blend(a: RGB, b: RGB, t: number): RGB
	return {
		math.floor(Rand.lerp(a[1], b[1], t) + 0.5),
		math.floor(Rand.lerp(a[2], b[2], t) + 0.5),
		math.floor(Rand.lerp(a[3], b[3], t) + 0.5),
	}
end

-- Per-channel value jitter. `amount` is a FRACTION of the channel, so dark colours jitter less in
-- absolute terms than light ones — which is what keeps a jittered palette reading as one material.
function ArtGen.jitterColor(st: Stream, c: RGB, amount: number): RGB
	local out: RGB = {}
	for i = 1, 3 do
		local v = c[i] * (1 + Rand.jitter(st, amount))
		out[i] = math.floor(Rand.clamp(v, 0, 255) + 0.5)
	end
	return out
end

-- The darkest entry of a palette, used as the contact-shade target (fake ambient occlusion).
function ArtGen.darkest(colors: { RGB }): RGB
	local best = colors[1]
	local bestSum = best[1] + best[2] + best[3]
	for i = 2, #colors do
		local c = colors[i]
		local sum = c[1] + c[2] + c[3]
		if sum < bestSum then
			best, bestSum = c, sum
		end
	end
	return best
end

-- ── model helpers ─────────────────────────────────────────────────────────────────────────────────────

-- The orthonormal basis a part's (up, yaw) resolves to: local X→r, local Y→u, local Z→f. This is the
-- SAME construction the Studio instantiator feeds CFrame.fromMatrix, so pure bounds math and the engine's
-- actual placement agree exactly rather than approximately.
function ArtGen.basis(up: Vec3?, yaw: number?): (Vec3, Vec3, Vec3)
	local r, u, f = Vec.frame(up or UP)
	local y = yaw or 0
	if y ~= 0 then
		local c, s = math.cos(y), math.sin(y)
		local r2 = Vec.add(Vec.scale(r, c), Vec.scale(f, s))
		local f2 = Vec.add(Vec.scale(r, -s), Vec.scale(f, c))
		r, f = r2, f2
	end
	return r, u, f
end

-- Cylinder basis: `up` is read as the AXIS (local X), yaw spins about it.
function ArtGen.cylinderBasis(axis: Vec3?, yaw: number?): (Vec3, Vec3, Vec3)
	local r, u, f = Vec.frameX(axis or UP)
	local y = yaw or 0
	if y ~= 0 then
		local c, s = math.cos(y), math.sin(y)
		local u2 = Vec.add(Vec.scale(u, c), Vec.scale(f, s))
		local f2 = Vec.add(Vec.scale(u, -s), Vec.scale(f, c))
		u, f = u2, f2
	end
	return r, u, f
end

-- The basis a given part actually resolves to. Cylinders take the axis convention; everything else takes
-- `up` as local +Y. bounds() and the Studio instantiator both route through here, so they cannot diverge.
function ArtGen.partBasis(p: PartDesc): (Vec3, Vec3, Vec3)
	if p.shape == Art.Shape.cylinder then
		return ArtGen.cylinderBasis(p.up, p.yaw)
	end
	return ArtGen.basis(p.up, p.yaw)
end

-- Exact axis-aligned bounds of a bag of oriented boxes: project each half-extent onto the world axes
-- through the absolute basis. (The earlier conservative diagonal both inflated reported extents and, worse,
-- fed heightOf — which normalises tree scale — so a wide-canopy tree came out shorter than its recipe asked.)
local function bounds(parts: { PartDesc }): (Vec3, Vec3)
	local lo: Vec3 = { x = math.huge, y = math.huge, z = math.huge }
	local hi: Vec3 = { x = -math.huge, y = -math.huge, z = -math.huge }
	for _, p in parts do
		local r, u, f = ArtGen.partBasis(p)
		local hx, hy, hz = p.size.x * 0.5, p.size.y * 0.5, p.size.z * 0.5
		local ex = math.abs(r.x) * hx + math.abs(u.x) * hy + math.abs(f.x) * hz
		local ey = math.abs(r.y) * hx + math.abs(u.y) * hy + math.abs(f.y) * hz
		local ez = math.abs(r.z) * hx + math.abs(u.z) * hy + math.abs(f.z) * hz
		lo.x = math.min(lo.x, p.pos.x - ex)
		lo.y = math.min(lo.y, p.pos.y - ey)
		lo.z = math.min(lo.z, p.pos.z - ez)
		hi.x = math.max(hi.x, p.pos.x + ex)
		hi.y = math.max(hi.y, p.pos.y + ey)
		hi.z = math.max(hi.z, p.pos.z + ez)
	end
	return lo, hi
end

ArtGen.bounds = bounds

-- Uniformly scale every part about the origin. Used to normalise a generated tree into its target
-- height band, so one recipe yields a whole size range without re-tuning segment lengths.
local function scaleParts(parts: { PartDesc }, s: number)
	for _, p in parts do
		p.size = { x = p.size.x * s, y = p.size.y * s, z = p.size.z * s }
		p.pos = { x = p.pos.x * s, y = p.pos.y * s, z = p.pos.z * s }
	end
end

-- Total height of a part bag measured from y = 0 (models are authored ground-up).
local function heightOf(parts: { PartDesc }): number
	local _, hi = bounds(parts)
	return math.max(hi.y, 0)
end

ArtGen.heightOf = heightOf

-- ── trees ─────────────────────────────────────────────────────────────────────────────────────────────

-- `density` scales both the plate count and the plate size, so an inner-canopy pass costs less and reads
-- as smaller leaf clusters deeper in the tree.
local function emitSlabFoliage(out: { PartDesc }, st: Stream, tip: Vec3, f: FoliageRecipe, density: number)
	local n = math.max(1, math.floor(Rand.int(st, f.countMin, f.countMax) * density + 0.5))
	for _ = 1, n do
		local az = Rand.range(st, 0, TAU)
		local d = Rand.range(st, 0, f.spread)
		local pos = Vec.add(tip, { x = math.cos(az) * d, y = Rand.range(st, 0, f.rise), z = math.sin(az) * d })
		local jit = 1 + Rand.jitter(st, f.sizeJitter)
		table.insert(out, {
			name = "Leaf",
			shape = Art.Shape.block,
			size = {
				x = f.size.x * jit * (0.55 + 0.45 * density),
				y = f.size.y * jit,
				z = f.size.z * jit * (0.55 + 0.45 * density),
			},
			pos = pos,
			up = Vec.tilt(UP, Rand.range(st, 0, f.tilt), Rand.range(st, 0, TAU)),
			yaw = Rand.range(st, 0, TAU),
			color = Rand.pick(st, f.colors),
			material = f.material,
			canCollide = false,
			canQuery = false,
			tag = "windSway",
		})
	end
end

-- Conifer: rings of downward-tilted plates whose radius tapers to a point, one ring per trunk segment
-- above `branchStart`. This is what separates a spruce silhouette from a lollipop.
local function emitTierFoliage(
	out: { PartDesc },
	st: Stream,
	base: Vec3,
	topY: number,
	startY: number,
	f: FoliageRecipe
)
	local tiers = math.max(1, math.floor(f.countMax))
	for i = 0, tiers - 1 do
		local t = tiers > 1 and i / (tiers - 1) or 0
		local y = Rand.lerp(startY, topY, t)
		local taper = 1 - t
		local ringR = f.spread * (taper * taper * 0.65 + 0.35)
		local perRing = math.max(3, Rand.int(st, f.countMin, f.countMax))
		local baseAz = Rand.range(st, 0, TAU)
		for k = 0, perRing - 1 do
			local az = baseAz + (k / perRing) * TAU + Rand.jitter(st, TAU / (perRing * 3))
			local d = ringR * Rand.range(st, 0.55, 1)
			local jit = (1 + Rand.jitter(st, f.sizeJitter)) * (taper * 0.55 + 0.45)
			local pos = Vec.add(base, {
				x = math.cos(az) * d,
				y = y + Rand.jitter(st, f.rise),
				z = math.sin(az) * d,
			})
			-- plates hinge downward and outward from the trunk: the bough droop
			local outward = Vec.unit({ x = math.cos(az), y = 0, z = math.sin(az) })
			local up = Vec.unit(Vec.add(UP, Vec.scale(outward, math.tan(f.tilt))))
			table.insert(out, {
				name = "Needle",
				shape = Art.Shape.block,
				size = { x = f.size.x * jit, y = f.size.y * jit, z = f.size.z * jit },
				pos = pos,
				up = up,
				yaw = az,
				color = Rand.pick(st, f.colors),
				material = f.material,
				canCollide = false,
				canQuery = false,
				tag = "windSway",
			})
		end
	end
end

-- Palm/fern crown: long blades radiating from the tip and drooping.
local function emitFrondFoliage(out: { PartDesc }, st: Stream, tip: Vec3, f: FoliageRecipe)
	local n = Rand.int(st, f.countMin, f.countMax)
	local baseAz = Rand.range(st, 0, TAU)
	for i = 0, n - 1 do
		local az = baseAz + (i / n) * TAU + Rand.jitter(st, 0.25)
		local droop = Rand.range(st, f.tilt * 0.5, f.tilt)
		local dir = Vec.tilt(UP, math.pi * 0.5 - droop, az)
		local jit = 1 + Rand.jitter(st, f.sizeJitter)
		local len = f.size.z * jit
		local pos = Vec.add(Vec.add(tip, { x = 0, y = f.rise, z = 0 }), Vec.scale(dir, len * 0.5))
		table.insert(out, {
			name = "Frond",
			shape = Art.Shape.block,
			size = { x = f.size.x * jit, y = f.size.y * jit, z = len },
			pos = pos,
			up = Vec.tilt(dir, math.pi * 0.5, az + math.pi),
			yaw = 0,
			color = Rand.pick(st, f.colors),
			material = f.material,
			canCollide = false,
			canQuery = false,
			tag = "windSway",
		})
	end
end

-- Recursive limb. Emits its own segment, then either children or terminal foliage.
local function limb(
	out: { PartDesc },
	st: Stream,
	r: TreeRecipe,
	base: Vec3,
	dir: Vec3,
	radius: number,
	length: number,
	level: number
)
	local L = r.limb
	local tip = Vec.add(base, Vec.scale(dir, length))
	local shade = ArtGen.darkest(r.barkColors)
	local col = ArtGen.jitterColor(st, Rand.pick(st, r.barkColors), 0.06)
	table.insert(out, {
		name = "Branch",
		shape = Art.Shape.block,
		size = { x = radius * 2, y = length, z = radius * 2 },
		pos = Vec.lerp(base, tip, 0.5),
		up = dir,
		yaw = Rand.range(st, 0, TAU),
		color = ArtGen.blend(col, shade, r.contactShade * (1 - level / math.max(L.levels, 1))),
		material = r.barkMaterial,
		canCollide = false,
		canQuery = false,
	})

	if r.drape ~= nil and level >= r.drape.minLevel then
		local dr = r.drape
		for _ = 1, dr.count do
			local len = Rand.range(st, dr.length.min, dr.length.max)
			local at = Vec.lerp(base, tip, Rand.range(st, 0.3, 0.95))
			table.insert(out, {
				name = "Drape",
				shape = Art.Shape.block,
				size = { x = dr.thickness, y = len, z = dr.thickness },
				pos = Vec.add(at, { x = Rand.jitter(st, dr.thickness), y = -len * 0.5, z = Rand.jitter(st, dr.thickness) }),
				up = UP,
				yaw = Rand.range(st, 0, TAU),
				color = Rand.pick(st, dr.colors),
				material = dr.material,
				transparency = 0.15,
				canCollide = false,
				canQuery = false,
				castShadow = false,
				tag = "windSway",
			})
		end
	end

	if level >= L.levels then
		if r.foliage.kind == "slab" then
			emitSlabFoliage(out, st, tip, r.foliage, 1)
		elseif r.foliage.kind == "frond" then
			emitFrondFoliage(out, st, tip, r.foliage)
		end
		return
	end
	-- Canopy DEPTH: also hang a thinner set of plates off the second-to-last level. Terminal-only foliage
	-- piles every plate at the same height and reads as a lollipop on a bare pole; the reference template's
	-- trees carry leaf mass through the whole branch volume.
	if r.foliage.kind == "slab" and level == L.levels - 1 and L.levels >= 2 then
		emitSlabFoliage(out, st, tip, r.foliage, 0.55)
	end

	local n = Rand.int(st, L.childMin, L.childMax)
	local baseAz = Rand.range(st, 0, TAU)
	for i = 0, n - 1 do
		local az = baseAz + (i / math.max(n, 1)) * TAU + Rand.jitter(st, 0.5)
		local childDir = Vec.tilt(dir, Rand.range(st, L.spread.min, L.spread.max), az)
		childDir = Vec.unit(Vec.lerp(childDir, UP, L.upBias))
		limb(out, st, r, tip, childDir, radius * L.childRadiusScale, length * L.childLengthScale, level + 1)
	end
end

-- Generate one tree. Deterministic in `seed`; normalised into recipe.targetHeight.
function ArtGen.tree(r: TreeRecipe, seed: number): ModelDesc
	local st = Rand.stream(seed)
	local out: { PartDesc } = {}
	local L = r.limb
	local shade = ArtGen.darkest(r.barkColors)

	-- buttressed flare at the base (kills the "cylinder stuck in dirt" tell)
	if r.flare ~= nil then
		local fl = r.flare
		local baseAz = Rand.range(st, 0, TAU)
		for i = 0, fl.count - 1 do
			local az = baseAz + (i / fl.count) * TAU + Rand.jitter(st, 0.3)
			local outward = { x = math.cos(az), y = 0, z = math.sin(az) }
			local d = fl.radius * Rand.range(st, 0.6, 1)
			table.insert(out, {
				name = "Flare",
				shape = Art.Shape.wedge,
				size = { x = fl.thickness, y = fl.height * Rand.range(st, 0.7, 1), z = d },
				pos = Vec.add(Vec.scale(outward, d * 0.5), { x = 0, y = fl.height * 0.35, z = 0 }),
				up = UP,
				yaw = az + math.pi,
				color = ArtGen.blend(ArtGen.jitterColor(st, Rand.pick(st, r.barkColors), 0.05), shade, r.contactShade),
				material = r.barkMaterial,
				canCollide = false,
				canQuery = false,
			})
		end
	end

	-- trunk: `segments` stacked segments with drift; side branches from `branchStart` up
	local pos: Vec3 = { x = 0, y = 0, z = 0 }
	local dir: Vec3 = UP
	local radius = L.radius
	local length = L.length
	local branchFromSeg = math.max(1, math.floor(L.segments * Rand.clamp(L.branchStart, 0, 1) + 0.5))
	for seg = 1, L.segments do
		local tip = Vec.add(pos, Vec.scale(dir, length))
		local col = ArtGen.jitterColor(st, Rand.pick(st, r.barkColors), 0.05)
		table.insert(out, {
			name = "Trunk",
			shape = Art.Shape.block,
			size = { x = radius * 2, y = length, z = radius * 2 },
			pos = Vec.lerp(pos, tip, 0.5),
			up = dir,
			yaw = Rand.range(st, 0, TAU),
			-- darkest at the base, lightening upward: reads as occlusion in the undergrowth
			color = ArtGen.blend(col, shade, r.contactShade * (1 - (seg - 1) / L.segments)),
			material = r.barkMaterial,
			-- the trunk is the only collidable part of a tree: players bump into boles, not canopies
			canCollide = true,
			canQuery = true,
		})
		if seg >= branchFromSeg then
			local n = Rand.int(st, L.childMin, L.childMax)
			local baseAz = Rand.range(st, 0, TAU)
			for i = 0, n - 1 do
				local az = baseAz + (i / math.max(n, 1)) * TAU + Rand.jitter(st, 0.6)
				local childDir = Vec.tilt(dir, Rand.range(st, L.spread.min, L.spread.max), az)
				childDir = Vec.unit(Vec.lerp(childDir, UP, L.upBias))
				limb(out, st, r, tip, childDir, radius * L.childRadiusScale, length * L.childLengthScale, 1)
			end
		end
		pos = tip
		dir = Vec.tilt(dir, Rand.range(st, 0, L.lean), Rand.range(st, 0, TAU))
		radius *= L.radiusTaper
		length *= L.lengthTaper
	end

	-- conifer rings run up the whole trunk, so they are emitted once against its measured extent
	if r.foliage.kind == "tier" then
		local trunkTop = pos.y
		local tierStart = r.foliage.tierStart or 0.25
		emitTierFoliage(out, st, { x = 0, y = 0, z = 0 }, trunkTop, trunkTop * Rand.clamp(tierStart, 0, 0.95), r.foliage)
	elseif r.foliage.kind == "frond" then
		emitFrondFoliage(out, st, pos, r.foliage)
	end

	-- normalise to the target height band
	local h = heightOf(out)
	if h > 0 then
		scaleParts(out, Rand.range(st, r.targetHeight.min, r.targetHeight.max) / h)
	end

	return { name = r.name, parts = out, groundPivot = { x = 0, y = 0, z = 0 } }
end

-- ── rock ──────────────────────────────────────────────────────────────────────────────────────────────

-- Faceted stone: overlapping rotated slabs, value-banded by height so the top catches light and the base
-- sits in shadow. `sink` buries a fraction of the form so it grows out of the ground.
function ArtGen.rock(r: RockRecipe, seed: number): ModelDesc
	local st = Rand.stream(seed)
	local out: { PartDesc } = {}
	local jit = 1 + Rand.jitter(st, r.sizeJitter)
	local form: Vec3 = { x = r.size.x * jit, y = r.size.y * jit, z = r.size.z * jit }
	local n = Rand.int(st, r.slabMin, r.slabMax)
	local shade = ArtGen.darkest(r.colors)
	for i = 1, n do
		local t = n > 1 and (i - 1) / (n - 1) or 0
		-- higher slabs are smaller and sit inboard, producing a tapered cairn rather than a cube pile
		local f = Rand.range(st, r.slabScale.min, r.slabScale.max) * (1 - t * 0.45)
		local az = Rand.range(st, 0, TAU)
		local d = Rand.range(st, 0, form.x * 0.35 * (1 - t))
		local y = form.y * (t * 0.8) - form.y * r.sink
		local shape = Rand.chance(st, r.wedgeChance) and Art.Shape.wedge or Art.Shape.block
		table.insert(out, {
			name = "Stone",
			shape = shape,
			size = { x = form.x * f, y = form.y * f * Rand.range(st, 0.6, 1.1), z = form.z * f },
			pos = { x = math.cos(az) * d, y = y, z = math.sin(az) * d },
			up = Vec.tilt(UP, Rand.range(st, 0, r.tilt), Rand.range(st, 0, TAU)),
			yaw = Rand.range(st, 0, TAU),
			-- value banding: base slabs pulled toward the darkest tone, crest slabs left bright
			color = ArtGen.blend(ArtGen.jitterColor(st, Rand.pick(st, r.colors), 0.07), shade, (1 - t) * 0.45),
			material = r.material,
			canCollide = true,
			canQuery = true,
		})
	end
	return { name = r.name, parts = out, groundPivot = { x = 0, y = 0, z = 0 } }
end

-- ── ground scatter ────────────────────────────────────────────────────────────────────────────────────

-- A small cluster of like elements (reeds, ferns, tufts, lily pads, mushrooms, driftwood, snow).
function ArtGen.cluster(r: ClusterRecipe, seed: number): ModelDesc
	local st = Rand.stream(seed)
	local out: { PartDesc } = {}
	local n = Rand.int(st, r.countMin, r.countMax)
	for _ = 1, n do
		local az = Rand.range(st, 0, TAU)
		local d = Rand.range(st, 0, r.radius)
		local jit = 1 + Rand.jitter(st, r.sizeJitter)
		local size = { x = r.size.x * jit, y = r.size.y * jit, z = r.size.z * jit }
		table.insert(out, {
			name = r.name,
			shape = r.shape,
			size = size,
			-- authored so the element's BASE sits at y = rise: half its height up, then the rise offset
			pos = { x = math.cos(az) * d, y = size.y * 0.5 + r.rise, z = math.sin(az) * d },
			up = Vec.tilt(UP, Rand.range(st, 0, r.tilt), Rand.range(st, 0, TAU)),
			yaw = Rand.range(st, 0, TAU),
			color = ArtGen.jitterColor(st, Rand.pick(st, r.colors), 0.08),
			material = r.material,
			transparency = r.transparency,
			castShadow = r.castShadow,
			canCollide = r.canCollide,
			canQuery = r.canQuery,
			tag = "windSway",
		})
	end
	return { name = r.name, parts = out, groundPivot = { x = 0, y = 0, z = 0 } }
end

-- ── scatter planning ──────────────────────────────────────────────────────────────────────────────────
-- Where props go, decided purely. The Studio side raycasts each candidate to find the real ground Y and
-- rejects the ones that land in water or on a slope — but the CANDIDATE SET is deterministic and testable.

export type ScatterPlan = { x: number, z: number, seed: number, recipeIndex: number, yaw: number, scale: number }

export type ScatterSpec = {
	center: { x: number, z: number },
	radius: number,
	count: number,
	recipeCount: number, -- how many recipes the caller will round-robin/weight across
	scale: Art.Range,
	minSpacing: number, -- reject candidates closer than this to an already-placed one
}

-- Poisson-ish scatter by dart throwing with a spacing reject. Deterministic, and it never loops forever:
-- each requested item gets a bounded number of attempts, then is dropped.
function ArtGen.scatter(spec: ScatterSpec, seed: number, attemptsPerItem: number): { ScatterPlan }
	local st = Rand.stream(seed)
	local out: { ScatterPlan } = {}
	local minSq = spec.minSpacing * spec.minSpacing
	for i = 1, spec.count do
		for _ = 1, math.max(1, math.floor(attemptsPerItem)) do
			local az = Rand.range(st, 0, TAU)
			-- sqrt-distributed radius gives uniform area density instead of a centre clump
			local d = spec.radius * math.sqrt(Rand.unit(st))
			local x = spec.center.x + math.cos(az) * d
			local z = spec.center.z + math.sin(az) * d
			local okSpot = true
			for _, p in out do
				local dx, dz = p.x - x, p.z - z
				if dx * dx + dz * dz < minSq then
					okSpot = false
					break
				end
			end
			if okSpot then
				table.insert(out, {
					x = x,
					z = z,
					seed = seed + i * 7919,
					recipeIndex = Rand.int(st, 1, math.max(1, spec.recipeCount)),
					yaw = Rand.range(st, 0, TAU),
					scale = Rand.range(st, spec.scale.min, spec.scale.max),
				})
				break
			end
		end
	end
	return out
end

-- ── cabin ─────────────────────────────────────────────────────────────────────────────────────────────

-- A parametric log building: coursed log walls with real door and window openings, a gabled wedge roof
-- with overhang, a plank floor, ridge/tie beams, an optional stone chimney, and a porch.
-- Openings are produced by SPLITTING each course into spans around them — the walls are genuinely
-- perforated, not a solid box with a dark decal, which is the difference a player reads instantly.
function ArtGen.cabin(r: CabinRecipe): ModelDesc
	local st = Rand.stream(#r.name + math.floor(r.width * 131 + r.depth * 17))
	local out: { PartDesc } = {}
	local hw, hd = r.width * 0.5, r.depth * 0.5
	local courseH = r.wallHeight / r.logCourses
	local logT = courseH -- square-ish logs read best; thickness tracks course height
	local stoneShade = ArtGen.darkest(r.stoneColors)

	-- floor
	table.insert(out, {
		name = "Floor",
		shape = Art.Shape.block,
		size = { x = r.width + logT * 2, y = logT, z = r.depth + logT * 2 },
		pos = { x = 0, y = -logT * 0.5, z = 0 },
		color = Rand.pick(st, r.floorColors),
		material = r.floorMaterial,
	})

	-- Collect openings per wall so a course can be split around them.
	type Opening = { lo: number, hi: number, bottom: number, top: number }
	local openings: { [string]: { Opening } } = { north = {}, south = {}, east = {}, west = {} }
	for _, w in r.windows do
		local list = openings[w.wall]
		if list ~= nil then
			table.insert(list, {
				lo = w.offset - w.width * 0.5,
				hi = w.offset + w.width * 0.5,
				bottom = w.sill,
				top = w.sill + w.height,
			})
		end
	end
	-- the door always sits centred in the south wall
	table.insert(openings.south, {
		lo = -r.doorWidth * 0.5,
		hi = r.doorWidth * 0.5,
		bottom = 0,
		top = r.doorHeight,
	})

	-- One coursed log wall. `axis` is "x" for the north/south walls, "z" for east/west.
	local function wall(name: string, axis: string, fixed: number, span: number, list: { Opening })
		local half = span * 0.5
		for c = 0, r.logCourses - 1 do
			local yLo = c * courseH
			local yHi = yLo + courseH
			local yMid = yLo + courseH * 0.5
			-- spans of solid log left on this course, walking from the wall's low edge upward
			local cuts: { { number } } = {}
			for _, o in list do
				if o.bottom < yHi and o.top > yLo then
					table.insert(cuts, { o.lo, o.hi })
				end
			end
			table.sort(cuts, function(a: { number }, b: { number }): boolean
				return a[1] < b[1]
			end)
			local segStart = -half
			local segments: { { number } } = {}
			for _, cut in cuts do
				local lo = math.max(cut[1], -half)
				if lo > segStart then
					table.insert(segments, { segStart, lo })
				end
				segStart = math.max(segStart, math.min(cut[2], half))
			end
			if segStart < half then
				table.insert(segments, { segStart, half })
			end
			for _, s in segments do
				local len = s[2] - s[1]
				if len > 0.05 then
					local mid = (s[1] + s[2]) * 0.5
					local size: Vec3 = if axis == "x"
						then { x = len, y = courseH, z = logT }
						else { x = logT, y = courseH, z = len }
					local pos: Vec3 = if axis == "x"
						then { x = mid, y = yMid, z = fixed }
						else { x = fixed, y = yMid, z = mid }
					table.insert(out, {
						name = name .. "Log",
						shape = Art.Shape.block,
						size = size,
						pos = pos,
						-- alternate course tone so the coursing reads as separate logs at distance
						color = ArtGen.jitterColor(st, r.logColors[(c % #r.logColors) + 1], 0.05),
						material = r.logMaterial,
					})
				end
			end
		end
	end

	wall("North", "x", hd + logT * 0.5, r.width, openings.north)
	wall("South", "x", -hd - logT * 0.5, r.width, openings.south)
	wall("East", "z", hw + logT * 0.5, r.depth, openings.east)
	wall("West", "z", -hw - logT * 0.5, r.depth, openings.west)

	-- corner posts hide the log-end joinery (cylinder: `up` is the axis, size.x is the length)
	for _, c in { { hw, hd }, { -hw, hd }, { hw, -hd }, { -hw, -hd } } do
		table.insert(out, {
			name = "CornerPost",
			shape = Art.Shape.cylinder,
			size = { x = r.wallHeight, y = logT * 1.6, z = logT * 1.6 },
			pos = { x = c[1], y = r.wallHeight * 0.5, z = c[2] },
			up = UP,
			color = Rand.pick(st, r.trimColors),
			material = r.logMaterial,
		})
	end

	-- window glass + sill + head trim, so an opening reads as a window rather than a hole
	for _, w in r.windows do
		local isX = w.wall == "north" or w.wall == "south"
		local fixed = if w.wall == "north"
			then hd + logT * 0.5
			elseif w.wall == "south" then -hd - logT * 0.5
			elseif w.wall == "east" then hw + logT * 0.5
			else -hw - logT * 0.5
		local glassSize: Vec3 = if isX
			then { x = w.width, y = w.height, z = logT * 0.25 }
			else { x = logT * 0.25, y = w.height, z = w.width }
		local glassPos: Vec3 = if isX
			then { x = w.offset, y = w.sill + w.height * 0.5, z = fixed }
			else { x = fixed, y = w.sill + w.height * 0.5, z = w.offset }
		table.insert(out, {
			name = "WindowGlass",
			shape = Art.Shape.block,
			size = glassSize,
			pos = glassPos,
			color = r.glassColor,
			material = Art.Material.Glass,
			transparency = 0.55,
			reflectance = 0.15,
			canCollide = false,
			castShadow = false,
		})
		for _, band in { { w.sill - logT * 0.3, logT * 0.6 }, { w.sill + w.height + logT * 0.3, logT * 0.5 } } do
			local trimSize: Vec3 = if isX
				then { x = w.width + logT * 0.8, y = band[2], z = logT * 1.1 }
				else { x = logT * 1.1, y = band[2], z = w.width + logT * 0.8 }
			local trimPos: Vec3 = if isX
				then { x = w.offset, y = band[1], z = fixed }
				else { x = fixed, y = band[1], z = w.offset }
			table.insert(out, {
				name = "WindowTrim",
				shape = Art.Shape.block,
				size = trimSize,
				pos = trimPos,
				color = Rand.pick(st, r.trimColors),
				material = r.logMaterial,
			})
		end
	end

	-- door head trim
	table.insert(out, {
		name = "DoorLintel",
		shape = Art.Shape.block,
		size = { x = r.doorWidth + logT * 1.2, y = logT * 0.7, z = logT * 1.2 },
		pos = { x = 0, y = r.doorHeight + logT * 0.35, z = -hd - logT * 0.5 },
		color = Rand.pick(st, r.trimColors),
		material = r.logMaterial,
	})

	-- gabled roof: two wedge slopes + a ridge beam, with overhang past the walls
	local rise = hw * r.roofPitch
	local slopeRun = hw + r.roofOverhang
	local slopeLen = r.depth + r.roofOverhang * 2
	local slopeThickness = logT * 0.9
	for _, sgn in { 1, -1 } do
		table.insert(out, {
			name = "RoofSlope",
			shape = Art.Shape.wedge,
			-- MEASURED, not assumed: a WedgePart is ZERO height at its local -Z and FULL height at its
			-- local +Z (probed live in Studio with a raycast grid). The first version had this backwards, so
			-- both slopes rose toward the EAVE instead of the ridge — the roof formed a valley, the gable
			-- in-fill stuck up through it, and the chimney sat inside an open cavity.
			-- yaw = +sgn*pi/2 points local +Z at the ridge (x = 0) from either side, so each slope is full
			-- height at the peak and tapers to nothing at its eave. size.x spans the building's depth.
			size = { x = slopeLen, y = rise, z = slopeRun },
			pos = { x = sgn * slopeRun * 0.5, y = r.wallHeight + rise * 0.5, z = 0 },
			up = UP,
			yaw = sgn * math.pi * 0.5,
			color = Rand.pick(st, r.roofColors),
			material = r.roofMaterial,
		})
		-- eave fascia
		table.insert(out, {
			name = "Eave",
			shape = Art.Shape.block,
			size = { x = slopeThickness * 1.4, y = slopeThickness, z = slopeLen },
			pos = { x = sgn * slopeRun, y = r.wallHeight, z = 0 },
			color = Rand.pick(st, r.trimColors),
			material = r.logMaterial,
		})
	end
	table.insert(out, {
		name = "RidgeBeam",
		shape = Art.Shape.block,
		size = { x = logT * 1.3, y = logT * 1.3, z = slopeLen },
		pos = { x = 0, y = r.wallHeight + rise, z = 0 },
		color = Rand.pick(st, r.trimColors),
		material = r.logMaterial,
	})
	-- gable in-fill so the roof triangle is closed at both ends
	-- Gable in-fill, closing the roof triangle at each end of the ridge.
	--
	-- Each course's width is DERIVED from the roof plane rather than tapered linearly against it. The naive
	-- `width * (1 - t)` taper put every block's top corners slightly proud of the slope, so the gable poked
	-- through the roof as a visible staircase (caught in the offline preview). The roof surface at distance x
	-- from the ridge sits at wallHeight + rise*(1 - x/slopeRun); solving that for the course's TOP height
	-- gives the half-width at which its corners land exactly on the slope.
	for _, sgn in { 1, -1 } do
		local steps = math.max(2, r.logCourses)
		local courseH = rise / steps
		for i = 0, steps - 1 do
			local t = i / steps
			local halfW = slopeRun * (1 - t - 1 / steps)
			if halfW > 0.25 then
				table.insert(out, {
					name = "Gable",
					shape = Art.Shape.block,
					size = { x = halfW * 2, y = courseH, z = logT },
					pos = { x = 0, y = r.wallHeight + rise * t + courseH * 0.5, z = sgn * (hd + logT * 0.5) },
					color = ArtGen.jitterColor(st, r.logColors[(i % #r.logColors) + 1], 0.05),
					material = r.logMaterial,
				})
			end
		end
	end

	-- interior tie beams (the ceiling detail that makes an interior feel built)
	local beams = math.max(2, math.floor(r.depth / (r.width * 0.25)))
	for i = 0, beams - 1 do
		local z = -hd + r.depth * (i + 0.5) / beams
		table.insert(out, {
			name = "TieBeam",
			shape = Art.Shape.block,
			size = { x = r.width + logT, y = logT * 0.8, z = logT * 0.8 },
			pos = { x = 0, y = r.wallHeight - logT * 0.4, z = z },
			color = Rand.pick(st, r.trimColors),
			material = r.logMaterial,
		})
	end

	-- porch: deck, posts, shed roof
	if r.porchDepth > 0 then
		local pz = -hd - r.porchDepth * 0.5 - logT
		table.insert(out, {
			name = "PorchDeck",
			shape = Art.Shape.block,
			size = { x = r.width + logT * 2, y = logT * 0.6, z = r.porchDepth },
			pos = { x = 0, y = -logT * 0.3, z = pz },
			color = Rand.pick(st, r.floorColors),
			material = r.floorMaterial,
		})
		local postH = r.wallHeight * 0.85
		for _, px in { -hw + logT, 0, hw - logT } do
			table.insert(out, {
				name = "PorchPost",
				shape = Art.Shape.cylinder,
				size = { x = postH, y = logT * 1.2, z = logT * 1.2 },
				pos = { x = px, y = postH * 0.5, z = -hd - r.porchDepth - logT * 0.5 },
				up = UP,
				yaw = 0,
				color = Rand.pick(st, r.trimColors),
				material = r.logMaterial,
			})
		end
		table.insert(out, {
			name = "PorchRoof",
			shape = Art.Shape.wedge,
			-- shed roof: full height where it meets the cabin wall (+Z), tapering down to the outer edge.
			-- Local +Z is the full-height end, so yaw = 0 points it at the wall.
			size = { x = r.width + logT * 2, y = rise * 0.35, z = r.porchDepth + logT },
			pos = { x = 0, y = postH + rise * 0.175, z = pz },
			up = UP,
			yaw = 0,
			color = Rand.pick(st, r.roofColors),
			material = r.roofMaterial,
		})
	end

	-- stone chimney with a firebox recess
	if r.chimney ~= nil then
		local ch = r.chimney
		local cz = hd + ch.depth * 0.5
		local steps = math.max(3, math.floor(ch.height / (ch.width * 0.6)))
		for i = 0, steps - 1 do
			local t = i / steps
			local w = ch.width * (1 - t * 0.25)
			table.insert(out, {
				name = "Chimney",
				shape = Art.Shape.block,
				size = { x = w, y = ch.height / steps, z = ch.depth * (1 - t * 0.15) },
				pos = { x = ch.offset, y = ch.height * (t + 0.5 / steps), z = cz },
				color = ArtGen.blend(ArtGen.jitterColor(st, Rand.pick(st, r.stoneColors), 0.09), stoneShade, 1 - t),
				material = r.stoneMaterial,
			})
		end
		table.insert(out, {
			name = "Hearth",
			shape = Art.Shape.block,
			size = { x = ch.width * 1.5, y = ch.width * 0.9, z = ch.depth * 0.9 },
			pos = { x = ch.offset, y = ch.width * 0.45, z = hd - ch.depth * 0.35 },
			color = ArtGen.blend(Rand.pick(st, r.stoneColors), stoneShade, 0.4),
			material = r.stoneMaterial,
		})
		table.insert(out, {
			name = "Firebox",
			shape = Art.Shape.block,
			size = { x = ch.width * 0.9, y = ch.width * 0.55, z = ch.depth * 0.5 },
			pos = { x = ch.offset, y = ch.width * 0.3, z = hd - ch.depth * 0.15 },
			color = { 16, 13, 10 },
			material = Art.Material.Slate,
			canCollide = false,
		})
	end

	return { name = r.name, parts = out, groundPivot = { x = 0, y = 0, z = 0 } }
end

-- ── creatures ─────────────────────────────────────────────────────────────────────────────────────────
-- Authored with the TORSO CENTRE at the origin and -Z forward, so the Studio side can weld the visual
-- straight onto WorldServer's hitbox PrimaryPart with no offset arithmetic. Every part is non-collidable
-- and NON-QUERYABLE: the hunting raycast must keep hitting the underlying hitZone-tagged boxes, or the
-- headshot multiplier silently stops working.

local BONE: RGB = { 232, 228, 216 }

local function creaturePart(
	out: { PartDesc },
	name: string,
	size: Vec3,
	pos: Vec3,
	up: Vec3?,
	yaw: number?,
	color: RGB,
	material: Art.MaterialName,
	shape: Art.Shape?
)
	table.insert(out, {
		name = name,
		shape = shape or Art.Shape.block,
		size = size,
		pos = pos,
		up = up,
		yaw = yaw,
		color = color,
		material = material,
		canCollide = false,
		-- LOAD-BEARING: a queryable visual part would absorb the shot meant for the hitbox underneath.
		canQuery = false,
	})
end

-- The coarse anatomy of a creature: where its torso, head and tail sit, and how far the torso centre is
-- above the ground. This exists so the GAMEPLAY hitbox and the VISUAL mesh are derived from one place.
--
-- Why that matters: WorldServer builds a 3-box hitbox whose head carries hitZone = "vital", and
-- Combat.zoneMultiplier pays a headshot bonus off it. If the hitbox head and the visible head disagree, the
-- player aims at the head they can see and silently gets a body hit — the gun feels broken and nothing in
-- the logs says why. Both now read these numbers.
export type CreatureAnatomy = {
	torso: { size: Vec3, pos: Vec3 },
	head: { size: Vec3, pos: Vec3 },
	tail: { size: Vec3, pos: Vec3 }?,
	footDrop: number, -- studs from the torso centre down to the ground contact
	forward: Vec3, -- the direction the creature faces in its own space
}

function ArtGen.creatureAnatomy(r: Art.CreatureRecipe): CreatureAnatomy
	local FWD = -1
	local halfLen, halfH = r.length * 0.5, r.height * 0.5
	local n = r.neck
	local neckDir = Vec.unit({ x = 0, y = math.sin(n.angle), z = FWD * math.cos(n.angle) })
	local neckBase: Vec3 = { x = 0, y = halfH * 0.45 + r.shoulderHump * r.height * 0.5, z = FWD * halfLen * 0.9 }
	local headPos = Vec.add(neckBase, Vec.scale(neckDir, n.length + r.head.length * 0.4))
	-- the head hitbox swallows the snout, so a nose shot still counts as a head shot
	local snoutLen = if r.snout ~= nil then r.snout.length else 0
	local headSize: Vec3 = {
		x = math.max(r.head.width, if r.snout ~= nil then r.snout.width else 0),
		y = r.head.height,
		z = r.head.length + snoutLen,
	}
	local headCentre = Vec.add(headPos, { x = 0, y = 0, z = FWD * snoutLen * 0.5 })

	local tail = nil
	if r.tail ~= nil then
		local T = r.tail
		local dir = Vec.unit({ x = 0, y = math.sin(T.angle), z = -FWD * math.cos(T.angle) })
		local base: Vec3 = { x = 0, y = halfH * 0.2, z = -FWD * halfLen * 0.95 }
		tail = {
			size = { x = T.thickness * 1.2, y = T.thickness * 1.2, z = T.length },
			pos = Vec.add(base, Vec.scale(dir, T.length * 0.5)),
		}
	end

	local footDrop = halfH * 0.6 + (if r.legs ~= nil then r.legs.length * math.cos(r.legs.splay) else halfH * 0.4)
	return {
		torso = {
			size = { x = r.width, y = r.height * (1 + r.shoulderHump * 0.5), z = r.length },
			pos = { x = 0, y = 0, z = 0 },
		},
		head = { size = headSize, pos = headCentre },
		tail = tail,
		footDrop = footDrop,
		forward = { x = 0, y = 0, z = FWD },
	}
end

function ArtGen.creature(r: Art.CreatureRecipe, seed: number): ModelDesc
	local st = Rand.stream(seed)
	local out: { PartDesc } = {}
	local pale = r.pale or 0
	local function tone(set: { RGB }, jitter: number): RGB
		local c = ArtGen.jitterColor(st, Rand.pick(st, set), jitter)
		if pale > 0 then
			c = ArtGen.blend(c, BONE, pale)
		end
		return c
	end
	local FWD = -1 -- forward is -Z

	local halfLen = r.length * 0.5
	local halfH = r.height * 0.5

	-- ── torso: segments along the body axis, tapering toward the hip, with an optional shoulder hump ──
	local segs = math.max(1, math.floor(r.torsoSegments))
	for i = 1, segs do
		local t = (i - 0.5) / segs -- 0 at the nose end, 1 at the hip
		local z = FWD * (halfLen - t * r.length)
		-- Girth peaks just behind the shoulder. Fish need a far stronger spindle than a quadruped: a
		-- constant-width tube with a block head on it reads as a crate, which is exactly how the first pass
		-- rendered. sin(pi * t^0.75) gives a rounded shoulder and a genuinely pointed tail.
		local girth
		if r.form == "fish" then
			girth = 0.22 + 0.78 * math.sin(math.pi * (t ^ 0.75))
		else
			girth = 1 - 0.28 * math.abs(t - 0.35) / 0.65
		end
		local hump = r.shoulderHump * r.height * math.max(0, 1 - t * 2.4)
		creaturePart(
			out,
			"Torso",
			{ x = r.width * girth, y = r.height * girth + hump, z = r.length / segs * 1.06 },
			{ x = 0, y = hump * 0.5, z = z },
			nil,
			0,
			tone(r.back, 0.05),
			r.material
		)
		-- counter-shaded belly: real animals are pale underneath, and faking it is most of what makes a
		-- flat-lit part animal read as a volume
		creaturePart(
			out,
			"Belly",
			{ x = r.width * girth * 0.82, y = r.height * 0.3, z = r.length / segs * 1.02 },
			{ x = 0, y = -halfH * 0.72, z = z },
			nil,
			0,
			tone(r.belly, 0.05),
			r.material
		)
	end

	if r.shell ~= nil then
		local sh = r.shell
		local plates = math.max(1, math.floor(sh.plates))
		for i = 1, plates do
			local t = (i - 0.5) / plates
			local dome = math.sin(t * math.pi)
			creaturePart(
				out,
				"Shell",
				{ x = sh.width * (0.55 + 0.45 * dome), y = sh.height * (0.4 + 0.6 * dome), z = sh.length / plates * 1.1 },
				{ x = 0, y = halfH * 0.5 + sh.height * 0.3 * dome, z = FWD * (sh.length * 0.5 - t * sh.length) },
				nil,
				0,
				tone(r.accent, 0.07),
				r.material
			)
		end
	end

	-- ── neck + head ──
	-- The head position comes from creatureAnatomy, the same function the gameplay hitbox reads, so the
	-- visible head and the "vital" hit zone can never drift apart.
	local anatomy = ArtGen.creatureAnatomy(r)
	local n = r.neck
	local neckDir = Vec.unit({ x = 0, y = math.sin(n.angle), z = FWD * math.cos(n.angle) })
	local neckBase: Vec3 = { x = 0, y = halfH * 0.45 + r.shoulderHump * r.height * 0.5, z = FWD * halfLen * 0.9 }
	local neckSegs = 2
	local cursor = neckBase
	for i = 1, neckSegs do
		local len = n.length / neckSegs
		local mid = Vec.add(cursor, Vec.scale(neckDir, len * 0.5))
		creaturePart(
			out,
			"Neck",
			{ x = n.thickness * (1 - 0.12 * i), y = n.thickness * (1 - 0.12 * i), z = len * 1.1 },
			mid,
			neckDir,
			0,
			tone(r.back, 0.05),
			r.material
		)
		cursor = Vec.add(cursor, Vec.scale(neckDir, len))
	end

	local h = r.head
	local headPos = Vec.add(neckBase, Vec.scale(neckDir, n.length + h.length * 0.4))
	creaturePart(out, "Head", { x = h.width, y = h.height, z = h.length }, headPos, nil, 0, tone(r.back, 0.04), r.material)

	if r.snout ~= nil then
		local s = r.snout
		creaturePart(
			out,
			"Snout",
			{ x = s.width, y = s.height, z = s.length },
			Vec.add(headPos, { x = 0, y = -s.droop, z = FWD * (h.length * 0.5 + s.length * 0.45) }),
			nil,
			0,
			tone(r.back, 0.05),
			r.material
		)
		-- nose/beak tip in the accent tone: a tiny part that reads as a face from 40 studs away
		creaturePart(
			out,
			"Nose",
			{ x = s.width * 0.55, y = s.height * 0.5, z = s.length * 0.24 },
			Vec.add(headPos, { x = 0, y = -s.droop, z = FWD * (h.length * 0.5 + s.length * 0.98) }),
			nil,
			0,
			tone(r.accent, 0.05),
			r.material
		)
	end

	if r.ears ~= nil then
		local e = r.ears
		local count = math.max(1, math.floor(e.count))
		for i = 1, count do
			local side = if i % 2 == 1 then -1 else 1
			creaturePart(
				out,
				"Ear",
				{ x = e.width, y = e.length, z = e.width * 0.5 },
				Vec.add(headPos, { x = side * h.width * 0.42, y = h.height * 0.5 + e.length * 0.4, z = 0 }),
				Vec.tilt(UP, e.angle, if side < 0 then math.pi * 0.5 else math.pi * 1.5),
				0,
				tone(r.back, 0.06),
				r.material
			)
		end
	end

	if r.antlers ~= nil then
		local a = r.antlers
		for _, side in { -1, 1 } do
			local base = Vec.add(headPos, { x = side * h.width * 0.32, y = h.height * 0.5, z = FWD * -h.length * 0.1 })
			local beamDir = Vec.unit({ x = side * math.sin(a.sweep), y = math.cos(a.sweep), z = FWD * 0.25 })
			local beamSegs = 3
			local cur = base
			for i = 1, beamSegs do
				local len = a.beamLength / beamSegs
				local th = a.thickness * (1 - 0.16 * i)
				creaturePart(
					out,
					"Antler",
					{ x = th, y = len * 1.08, z = th },
					Vec.add(cur, Vec.scale(beamDir, len * 0.5)),
					beamDir,
					0,
					tone(r.accent, 0.05),
					r.material
				)
				cur = Vec.add(cur, Vec.scale(beamDir, len))
				beamDir = Vec.unit(Vec.add(beamDir, { x = side * 0.16, y = -0.08, z = 0 }))
			end
			if a.palmate then
				-- moose: one broad paddle per side rather than a tine rack
				creaturePart(
					out,
					"Palm",
					{ x = a.beamLength * 0.85, y = a.thickness * 1.4, z = a.pointLength * 1.5 },
					Vec.add(cur, { x = side * a.beamLength * 0.3, y = 0, z = 0 }),
					nil,
					0,
					tone(r.accent, 0.05),
					r.material
				)
				for p = 1, math.max(1, math.floor(a.points)) do
					local frac = p / (a.points + 1)
					creaturePart(
						out,
						"Tine",
						{ x = a.thickness * 0.8, y = a.pointLength * 0.7, z = a.thickness * 0.8 },
						Vec.add(cur, {
							x = side * a.beamLength * (0.05 + frac * 0.55),
							y = a.pointLength * 0.4,
							z = FWD * a.pointLength * 0.5,
						}),
						nil,
						0,
						tone(r.accent, 0.05),
						r.material
					)
				end
			else
				local pts = math.max(1, math.floor(a.points))
				for p = 1, pts do
					local frac = p / (pts + 1)
					local from = Vec.lerp(base, cur, 0.25 + frac * 0.7)
					creaturePart(
						out,
						"Tine",
						{ x = a.thickness * 0.75, y = a.pointLength * (1.1 - frac * 0.4), z = a.thickness * 0.75 },
						Vec.add(from, { x = side * a.thickness, y = a.pointLength * 0.5, z = 0 }),
						Vec.tilt(UP, 0.32, if side < 0 then math.pi * 0.5 else math.pi * 1.5),
						0,
						tone(r.accent, 0.05),
						r.material
					)
				end
			end
		end
	end

	-- ── legs ──
	if r.legs ~= nil then
		local L = r.legs
		local segCount = math.max(1, math.floor(L.segments))
		for _, sx in { -1, 1 } do
			for _, front in { true, false } do
				local zBase = FWD * (if front then halfLen * 0.62 else -halfLen * 0.62)
				local dir = Vec.unit({ x = sx * math.sin(L.splay), y = -math.cos(L.splay), z = 0 })
				local cur: Vec3 = { x = sx * r.width * 0.36, y = -halfH * 0.6, z = zBase }
				for i = 1, segCount do
					local len = L.length / segCount
					local th = L.thickness * (1 - 0.18 * (i - 1))
					creaturePart(
						out,
						if front then "ForeLeg" else "HindLeg",
						{ x = th, y = len * 1.08, z = th },
						Vec.add(cur, Vec.scale(dir, len * 0.5)),
						dir,
						0,
						tone(r.back, 0.05),
						r.material
					)
					cur = Vec.add(cur, Vec.scale(dir, len))
					-- lower segments angle back under the body, the way a real leg does
					dir = Vec.unit(Vec.add(dir, { x = -sx * 0.1, y = 0, z = (if front then 0.12 else -0.12) }))
				end
				if L.hoof > 0 then
					creaturePart(
						out,
						"Hoof",
						{ x = L.thickness * L.hoof, y = L.thickness * 0.6, z = L.thickness * L.hoof * 1.2 },
						cur,
						nil,
						0,
						tone(r.accent, 0.04),
						r.material
					)
				end
			end
		end
	end

	-- ── tail ──
	if r.tail ~= nil then
		local T = r.tail
		local dir = Vec.unit({ x = 0, y = math.sin(T.angle), z = -FWD * math.cos(T.angle) })
		local cur: Vec3 = { x = 0, y = halfH * 0.2, z = -FWD * halfLen * 0.95 }
		local segCount = math.max(1, math.floor(T.segments))
		local th = T.thickness
		for i = 1, segCount do
			local len = T.length / segCount
			creaturePart(
				out,
				"Tail",
				{ x = th, y = th, z = len * 1.08 },
				Vec.add(cur, Vec.scale(dir, len * 0.5)),
				dir,
				0,
				tone(r.back, 0.05),
				r.material
			)
			cur = Vec.add(cur, Vec.scale(dir, len))
			th *= T.taper
			dir = Vec.unit(Vec.add(dir, { x = 0, y = -0.06, z = 0 }))
		end
		if T.tuft > 0 then
			creaturePart(out, "Tuft", { x = T.tuft, y = T.tuft, z = T.tuft }, cur, nil, 0, tone(r.belly, 0.06), r.material)
		end
	end

	-- ── wings ──
	if r.wings ~= nil then
		local W = r.wings
		for _, sx in { -1, 1 } do
			creaturePart(
				out,
				"Wing",
				{ x = W.thickness, y = W.width, z = W.length },
				{ x = sx * (r.width * 0.5 + W.thickness * 0.5), y = halfH * 0.15, z = FWD * -r.length * 0.05 },
				Vec.tilt(UP, W.fold, if sx < 0 then math.pi * 0.5 else math.pi * 1.5),
				0,
				tone(r.back, 0.06),
				r.material
			)
		end
	end

	-- ── fins (fish) ──
	if r.fins ~= nil then
		local F = r.fins
		-- caudal: the tail fin, a vertical plate at the rear
		creaturePart(
			out,
			"CaudalFin",
			{ x = r.width * 0.18, y = F.caudal, z = F.caudal * 0.85 },
			{ x = 0, y = 0, z = -FWD * (halfLen + F.caudal * 0.4) },
			nil,
			0,
			tone(r.accent, 0.06),
			r.material
		)
		if F.dorsal > 0 then
			creaturePart(
				out,
				"DorsalFin",
				{ x = r.width * 0.16, y = F.dorsal, z = r.length * 0.34 },
				{ x = 0, y = halfH + F.dorsal * 0.42, z = 0 },
				nil,
				0,
				tone(r.accent, 0.06),
				r.material
			)
		end
		if F.anal > 0 then
			creaturePart(
				out,
				"AnalFin",
				{ x = r.width * 0.14, y = F.anal, z = r.length * 0.2 },
				{ x = 0, y = -halfH - F.anal * 0.4, z = -FWD * r.length * 0.22 },
				nil,
				0,
				tone(r.accent, 0.06),
				r.material
			)
		end
		if F.pectoral > 0 then
			for _, sx in { -1, 1 } do
				creaturePart(
					out,
					"PectoralFin",
					{ x = F.pectoral * 0.9, y = r.height * 0.12, z = F.pectoral * 0.6 },
					{ x = sx * (r.width * 0.5 + F.pectoral * 0.3), y = -halfH * 0.3, z = FWD * r.length * 0.2 },
					Vec.tilt(UP, 1.1, if sx < 0 then math.pi * 0.5 else math.pi * 1.5),
					0,
					tone(r.accent, 0.06),
					r.material
				)
			end
		end
	end

	-- groundPivot: how far the torso centre sits above the ground, so the Studio side can place a creature
	-- standalone (set dressing) as well as welded to a hitbox. Same number the hitbox uses for its foot lift.
	return { name = r.name, parts = out, groundPivot = { x = 0, y = -anatomy.footDrop, z = 0 } }
end

-- ── aggregate helpers ─────────────────────────────────────────────────────────────────────────────────

-- Total part count of a model — the budget instrument the tests assert against.
function ArtGen.partCount(m: ModelDesc): number
	return #m.parts
end

-- Merge several models into one (used to assemble a composite prop before instantiation).
function ArtGen.merge(name: string, models: { ModelDesc }): ModelDesc
	local parts: { PartDesc } = {}
	for _, m in models do
		for _, p in m.parts do
			table.insert(parts, p)
		end
	end
	return { name = name, parts = parts, groundPivot = { x = 0, y = 0, z = 0 } }
end

-- Translate every part of a model (composing props at authoring time).
function ArtGen.translated(m: ModelDesc, by: Vec3): ModelDesc
	local parts: { PartDesc } = {}
	for _, p in m.parts do
		local q = table.clone(p)
		q.pos = Vec.add(p.pos, by)
		table.insert(parts, q)
	end
	return { name = m.name, parts = parts, groundPivot = Vec.add(m.groundPivot, by) }
end

return table.freeze(ArtGen)
