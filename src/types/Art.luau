--!strict
-- ART DESCRIPTOR VOCABULARY — the pure-data contract between the procedural geometry GENERATORS
-- (src/logic/ArtGen, src/logic/TerrainGen — pure, headless, unit-tested) and the single Studio-side
-- INSTANTIATOR (src/server/world/WorldArt.server.luau, which is the only file that may touch
-- Instance/Vector3/Enum). A generator returns ModelDesc tables; the instantiator walks them.
--
-- Why the closed string-sets live HERE and not in types/Enums.luau: Enums.luau is defined as the vocabulary
-- "every closed string-set THE SCHEMA uses". None of these values ever enters a PlayerData profile, a
-- ledger entry, or a catalog record — they are render-time only. They follow the identical discipline
-- (literal union + frozen value table) so the same guarantees hold.
--
-- ORIENTATION CONTRACT (deliberate, to keep the pure side euler-free): a part's orientation is given as
-- `up` — the world-space direction the part's local +Y axis points — plus `yaw`, an extra rotation about
-- that axis. The instantiator builds the CFrame with CFrame.fromMatrix, so there is no Euler-order
-- ambiguity between the pure math and the engine. `up` defaults to +Y and `yaw` to 0.

local Art = {}

-- {x, y, z} in studs, matching Schema.Vec3 so shell anchors interoperate.
export type Vec3 = { x: number, y: number, z: number }
-- {r, g, b} integers 0-255, matching the ArtAssets palette convention.
export type RGB = { number }

-- Part primitives the instantiator knows how to build. "block"/"ball"/"cylinder" are Part.Shape values;
-- "wedge" is a WedgePart and "cornerWedge" a CornerWedgePart (both needed for roofs and faceted rock).
--
-- CYLINDER AXIS CONVENTION: a Roblox cylinder's circular cross-section lies in the YZ plane and its
-- LENGTH runs along local X. To keep authoring intuitive, `up` is read as the cylinder's AXIS and `size.x`
-- as its length — so a vertical post is `up = {0,1,0}, size = {x = height, y = d, z = d}` and a log lying
-- on the ground is the same size with a near-horizontal `up`. (For every other shape `up` is local +Y.)
export type Shape = "block" | "ball" | "cylinder" | "wedge" | "cornerWedge"
Art.Shape = table.freeze({
	block = "block" :: Shape,
	ball = "ball" :: Shape,
	cylinder = "cylinder" :: Shape,
	wedge = "wedge" :: Shape,
	cornerWedge = "cornerWedge" :: Shape,
})

-- The Enum.Material names this art system uses. Kept to the set the reference template proves out
-- (Wood/Grass/Slate/Rock/Sand/WoodPlanks/Metal/Brick/Fabric/Concrete/Cobblestone) plus the cold-biome and
-- water-adjacent materials the three Wild World destinations need. The instantiator resolves the string
-- via Enum.Material[name]; every value here must be a real Enum.Material member.
export type MaterialName =
	"Plastic"
	| "SmoothPlastic"
	| "Wood"
	| "WoodPlanks"
	| "Grass"
	| "LeafyGrass"
	| "Slate"
	| "Rock"
	| "Basalt"
	| "Sand"
	| "Sandstone"
	| "Limestone"
	| "Concrete"
	| "Cobblestone"
	| "Brick"
	| "Metal"
	| "CorrodedMetal"
	| "DiamondPlate"
	| "Fabric"
	| "Leather"
	| "Ice"
	| "Glacier"
	| "Snow"
	| "Mud"
	| "Ground"
	| "Marble"
	| "Pebble"
	| "Glass"
	| "Neon"
Art.Material = table.freeze({
	Plastic = "Plastic" :: MaterialName,
	SmoothPlastic = "SmoothPlastic" :: MaterialName,
	Wood = "Wood" :: MaterialName,
	WoodPlanks = "WoodPlanks" :: MaterialName,
	Grass = "Grass" :: MaterialName,
	LeafyGrass = "LeafyGrass" :: MaterialName,
	Slate = "Slate" :: MaterialName,
	Rock = "Rock" :: MaterialName,
	Basalt = "Basalt" :: MaterialName,
	Sand = "Sand" :: MaterialName,
	Sandstone = "Sandstone" :: MaterialName,
	Limestone = "Limestone" :: MaterialName,
	Concrete = "Concrete" :: MaterialName,
	Cobblestone = "Cobblestone" :: MaterialName,
	Brick = "Brick" :: MaterialName,
	Metal = "Metal" :: MaterialName,
	CorrodedMetal = "CorrodedMetal" :: MaterialName,
	DiamondPlate = "DiamondPlate" :: MaterialName,
	Fabric = "Fabric" :: MaterialName,
	Leather = "Leather" :: MaterialName,
	Ice = "Ice" :: MaterialName,
	Glacier = "Glacier" :: MaterialName,
	Snow = "Snow" :: MaterialName,
	Mud = "Mud" :: MaterialName,
	Ground = "Ground" :: MaterialName,
	Marble = "Marble" :: MaterialName,
	Pebble = "Pebble" :: MaterialName,
	Glass = "Glass" :: MaterialName,
	Neon = "Neon" :: MaterialName,
})

-- Terrain materials a heightfield cell may resolve to. A strict subset of MaterialName (Terrain accepts
-- fewer materials than a Part), kept separate so a bad terrain material is a type error, not a silent
-- no-op at Terrain:FillBlock time. "Air" is the carve value.
export type TerrainMaterialName =
	"Air"
	| "Water"
	| "Grass"
	| "LeafyGrass"
	| "Ground"
	| "Mud"
	| "Sand"
	| "Sandstone"
	| "Rock"
	| "Slate"
	| "Basalt"
	| "Limestone"
	| "Snow"
	| "Glacier"
	| "Ice"
	| "Cobblestone"
	| "Salt"
	| "WoodPlanks"
Art.TerrainMaterial = table.freeze({
	Air = "Air" :: TerrainMaterialName,
	Water = "Water" :: TerrainMaterialName,
	Grass = "Grass" :: TerrainMaterialName,
	LeafyGrass = "LeafyGrass" :: TerrainMaterialName,
	Ground = "Ground" :: TerrainMaterialName,
	Mud = "Mud" :: TerrainMaterialName,
	Sand = "Sand" :: TerrainMaterialName,
	Sandstone = "Sandstone" :: TerrainMaterialName,
	Rock = "Rock" :: TerrainMaterialName,
	Slate = "Slate" :: TerrainMaterialName,
	Basalt = "Basalt" :: TerrainMaterialName,
	Limestone = "Limestone" :: TerrainMaterialName,
	Snow = "Snow" :: TerrainMaterialName,
	Glacier = "Glacier" :: TerrainMaterialName,
	Ice = "Ice" :: TerrainMaterialName,
	Cobblestone = "Cobblestone" :: TerrainMaterialName,
	Salt = "Salt" :: TerrainMaterialName,
	WoodPlanks = "WoodPlanks" :: TerrainMaterialName,
})

-- Enum.NormalId names, for tiling a Texture onto specific faces (the template's ship-planking trick:
-- a white Wood part + a tiled plank Texture reads as real carpentry for one instance instead of ten parts).
export type FaceName = "Top" | "Bottom" | "Front" | "Back" | "Left" | "Right"
Art.Face = table.freeze({
	Top = "Top" :: FaceName,
	Bottom = "Bottom" :: FaceName,
	Front = "Front" :: FaceName,
	Back = "Back" :: FaceName,
	Left = "Left" :: FaceName,
	Right = "Right" :: FaceName,
})

export type TextureDesc = {
	id: string, -- "rbxassetid://N"
	faces: { FaceName },
	studsU: number,
	studsV: number,
	transparency: number?,
	color: RGB?,
}

-- A light attached to a part. Kept in the descriptor so the lighting rig is authored with the geometry
-- (the reference lodges read warm because light sources sit ON the props, not in a separate pass).
export type LightKind = "point" | "spot" | "surface"
Art.LightKind = table.freeze({
	point = "point" :: LightKind,
	spot = "spot" :: LightKind,
	surface = "surface" :: LightKind,
})
export type LightDesc = {
	kind: LightKind,
	color: RGB,
	brightness: number,
	range: number,
	shadows: boolean?,
	angle: number?, -- spot only
	face: FaceName?, -- spot/surface only
}

-- One part. `pos` is the CENTRE of the part, in the model's own coordinate space; the instantiator adds
-- the model's world origin. Optional flags default to the engine's own defaults except where noted.
export type PartDesc = {
	name: string,
	shape: Shape,
	size: Vec3,
	pos: Vec3,
	up: Vec3?, -- world-space direction of the part's local +Y (default {0,1,0})
	yaw: number?, -- extra rotation about `up`, radians (default 0)
	color: RGB,
	material: MaterialName,
	transparency: number?, -- default 0
	reflectance: number?, -- default 0
	castShadow: boolean?, -- default true
	canCollide: boolean?, -- default true
	canQuery: boolean?, -- default true
	anchored: boolean?, -- default true
	texture: TextureDesc?,
	light: LightDesc?,
	-- Free-form label the instantiator may CollectionService-tag, so gameplay can find art parts
	-- (e.g. "windSway" for the foliage wind pass) without the art layer knowing about gameplay.
	tag: string?,
}

-- A prop/structure: a bag of parts plus the local-space point that should land on the ground.
-- `groundPivot` is subtracted from every part's `pos` by the instantiator's placement helper, so a
-- generator can author a tree from y=0 upward and still be dropped onto a raycast hit exactly.
export type ModelDesc = {
	name: string,
	parts: { PartDesc },
	groundPivot: Vec3,
}

-- ── RECIPES ───────────────────────────────────────────────────────────────────────────────────────────
-- The parameter tables src/config/ArtKit.luau authors and src/logic/ArtGen.luau consumes. They live here
-- (not in ArtGen) for the same reason Schema.luau holds the catalog types: the DATA module and the LOGIC
-- module must agree on a shape neither of them owns.

export type Range = { min: number, max: number }

-- How a limb tapers and where its children leave it. Shared by every branching form.
export type LimbRecipe = {
	radius: number, -- base limb radius in studs (part size is 2*radius square)
	length: number, -- base limb length in studs
	segments: number, -- segments in the main trunk before branching begins
	radiusTaper: number, -- radius multiplier per segment/level (< 1)
	lengthTaper: number, -- length multiplier per segment (< 1)
	lean: number, -- max radians the trunk drifts per segment (trunk crookedness)
	levels: number, -- recursive branch depth after the trunk
	branchStart: number, -- fraction up the trunk (0..1) where side branching begins
	childMin: number,
	childMax: number,
	spread: Range, -- radians a child leaves its parent's axis
	childRadiusScale: number,
	childLengthScale: number,
	upBias: number, -- 0 = keep the tilted direction, 1 = pull children back toward +Y
}

-- Terminal foliage. "slab" = the reference template's flat rotated leaf plates (reads as a canopy from
-- any angle for ~1 part each); "tier" = stacked conical rings for conifers; "frond" = long drooping blades.
export type FoliageKind = "slab" | "tier" | "frond" | "none"

export type FoliageRecipe = {
	kind: FoliageKind,
	countMin: number,
	countMax: number,
	size: Vec3, -- nominal slab size; jittered per instance
	sizeJitter: number, -- fraction, 0..1
	spread: number, -- lateral studs the cluster fans out from the limb tip
	rise: number, -- studs the cluster centre sits above the tip
	tilt: number, -- max radians of random plate tilt
	-- "tier" only: fraction UP THE TRUNK where the lowest whorl sits. Separate from limb.branchStart, which
	-- conifers set to 1 to mean "no side branches" — reusing it collapsed every tier onto the treetop and
	-- rendered a spruce as a bare pole with one umbrella.
	tierStart: number?,
	material: MaterialName,
	colors: { RGB },
}

-- Optional buttressed flare at the base (bald cypress knees, redwood root swell).
export type FlareRecipe = {
	count: number,
	radius: number, -- how far out from the trunk axis
	height: number,
	thickness: number,
}

-- Optional hanging drape (Spanish moss, vines, snow-laden boughs).
export type DrapeRecipe = {
	count: number,
	length: Range,
	thickness: number,
	material: MaterialName,
	colors: { RGB },
	minLevel: number, -- only hang from limbs at or beyond this recursion level
}

export type TreeRecipe = {
	name: string,
	limb: LimbRecipe,
	foliage: FoliageRecipe,
	flare: FlareRecipe?,
	drape: DrapeRecipe?,
	barkMaterial: MaterialName,
	barkColors: { RGB },
	-- Fraction of a limb's colour pulled toward the darkest bark colour at contact points; fakes
	-- ambient occlusion so a part pile reads as a solid form.
	contactShade: number,
	targetHeight: Range, -- the generator normalises the finished model to a height in this band
}

-- A faceted stone form: overlapping rotated blocks/wedges with value-banded colour.
export type RockRecipe = {
	name: string,
	size: Vec3, -- overall bounding form
	sizeJitter: number,
	slabMin: number,
	slabMax: number,
	slabScale: Range, -- each slab's size as a fraction of `size`
	tilt: number, -- max radians of random facet tilt
	sink: number, -- fraction of the form buried below y=0 (kills the floating-boulder tell)
	material: MaterialName,
	colors: { RGB },
	wedgeChance: number,
}

-- A small ground cluster: ferns, reeds, tufts, lily pads, mushrooms, driftwood, snow drift.
export type ClusterRecipe = {
	name: string,
	countMin: number,
	countMax: number,
	radius: number, -- cluster footprint radius
	shape: Shape,
	size: Vec3,
	sizeJitter: number,
	tilt: number,
	rise: number, -- lift the cluster centre off the ground (lily pads sit at 0, tufts slightly under)
	material: MaterialName,
	colors: { RGB },
	transparency: number?,
	castShadow: boolean?,
	canCollide: boolean?,
	canQuery: boolean?,
}

-- A parametric log building (the Lodge, outposts, cabins).
export type CabinRecipe = {
	name: string,
	width: number, -- X extent, interior
	depth: number, -- Z extent, interior
	wallHeight: number,
	logCourses: number, -- horizontal log rows per wall (the visible log-cabin banding)
	roofPitch: number, -- rise over half-width
	roofOverhang: number,
	doorWidth: number,
	doorHeight: number,
	windows: { { wall: string, offset: number, width: number, height: number, sill: number } },
	porchDepth: number,
	chimney: { width: number, depth: number, height: number, offset: number }?,
	logColors: { RGB },
	trimColors: { RGB },
	roofColors: { RGB },
	floorColors: { RGB },
	stoneColors: { RGB },
	logMaterial: MaterialName,
	roofMaterial: MaterialName,
	floorMaterial: MaterialName,
	stoneMaterial: MaterialName,
	glassColor: RGB,
}

-- ── CREATURES ─────────────────────────────────────────────────────────────────────────────────────────
-- Wild World has 26 huntable creatures and 25 fish. As shipped, only FOUR creature ids had a silhouette
-- archetype; the other 22 — moose, grizzly, whitetail, cougar, catamount — all fell through to one generic
-- box with a single ear. These recipes give every species its own silhouette from parts.
--
-- AXIS CONVENTION: authored with the TORSO CENTRE at the origin and -Z as FORWARD, matching the PrimaryPart
-- that WorldServer's hitbox model uses, so the visual welds straight on with no offset arithmetic.

export type CreatureForm = "quadruped" | "bird" | "fish"

export type NeckRecipe = { length: number, thickness: number, angle: number } -- angle: radians above horizontal
export type HeadRecipe = { length: number, height: number, width: number }
export type SnoutRecipe = { length: number, height: number, width: number, droop: number }
export type EarRecipe = { length: number, width: number, angle: number, count: number }
export type AntlerRecipe = {
	beamLength: number,
	thickness: number,
	sweep: number, -- radians the beam leaves vertical, outward
	points: number, -- tines per side
	pointLength: number,
	palmate: boolean, -- true = moose paddle, false = whitetail tine rack
}
export type LegRecipe = {
	length: number,
	thickness: number,
	splay: number, -- radians outward from vertical; a gator splays wide, a deer barely at all
	segments: number,
	hoof: number, -- extra width at the foot, 0 for none
}
export type TailRecipe = {
	length: number,
	thickness: number,
	angle: number, -- radians above horizontal at the base
	segments: number,
	taper: number,
	tuft: number, -- terminal tuft size, 0 for none
}
export type ShellRecipe = { length: number, height: number, width: number, plates: number }
export type WingRecipe = { length: number, width: number, thickness: number, fold: number }
export type FinRecipe = { dorsal: number, caudal: number, pectoral: number, anal: number }

export type CreatureRecipe = {
	name: string,
	form: CreatureForm,
	length: number, -- torso length, nose-to-hip proportions derive from it
	height: number, -- torso height
	width: number,
	torsoSegments: number,
	shoulderHump: number, -- 0..1 extra torso height at the shoulder (bear, boar, moose)
	neck: NeckRecipe,
	head: HeadRecipe,
	snout: SnoutRecipe?,
	ears: EarRecipe?,
	antlers: AntlerRecipe?,
	legs: LegRecipe?,
	tail: TailRecipe?,
	shell: ShellRecipe?,
	wings: WingRecipe?,
	fins: FinRecipe?,
	back: { RGB }, -- dorsal colour set
	belly: { RGB }, -- ventral counter-shading
	accent: { RGB }, -- beak/hoof/antler/marking
	material: MaterialName,
	-- Rare leucistic variants (Ghost Gator, Spirit Moose, Ghost Buck, Pale Drake, Glacier Grizzly): every
	-- colour is pulled toward bone-white by this fraction, so a marquee target reads instantly at distance.
	pale: number?,
}

-- One cell of a generated heightfield: the surface height and what the column is made of.
export type TerrainColumn = {
	x: number,
	z: number,
	height: number, -- world Y of the surface
	material: TerrainMaterialName,
	waterTop: number?, -- if set, fill Water from `height` up to this Y
}

-- A rectangular terrain write the instantiator turns into Terrain:FillBlock calls.
export type TerrainBlock = {
	center: Vec3,
	size: Vec3,
	material: TerrainMaterialName,
}

return table.freeze(Art)
