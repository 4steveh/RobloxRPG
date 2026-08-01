--!nonstrict
-- DEV TOOL (not part of the game, not shipped). Dumps generated geometry as JSON so tools/preview_art.py
-- can render an offline preview. This exists because the procedural art layer is pure: the exact part list
-- the engine will build can be produced headlessly, so silhouette and palette work does not have to wait
-- on a Studio session. It is NOT a substitute for a Studio playtest — it has no Roblox lighting, no
-- atmosphere and no terrain — it answers "does this read as a tree" and nothing more.
--
--   luau tools/dump_art.luau > /tmp/art.json
local ArtKit = require("../src/config/ArtKit")
local ArtGen = require("../src/logic/ArtGen")

local function esc(s) return (s:gsub('"', '\\"')) end
local buf = {}
local function w(s) table.insert(buf, s) end

local function dumpModel(label, m)
	w('{"label":"' .. esc(label) .. '","parts":[')
	local first = true
	for _, p in ipairs(m.parts) do
		local r, u, f = ArtGen.partBasis(p)
		if not first then w(",") end
		first = false
		w(string.format(
			'{"n":"%s","sh":"%s","s":[%.4f,%.4f,%.4f],"p":[%.4f,%.4f,%.4f],'
			.. '"r":[%.5f,%.5f,%.5f],"u":[%.5f,%.5f,%.5f],"f":[%.5f,%.5f,%.5f],"c":[%d,%d,%d],"t":%.3f}',
			esc(p.name), p.shape, p.size.x, p.size.y, p.size.z, p.pos.x, p.pos.y, p.pos.z,
			r.x, r.y, r.z, u.x, u.y, u.z, f.x, f.y, f.z,
			p.color[1], p.color[2], p.color[3], p.transparency or 0))
	end
	w(']}')
end

local subjects = {}
local function add(label, m) table.insert(subjects, { label = label, model = m }) end

for _, k in ipairs({ "baldCypress", "oldCypress", "snag", "oak", "maple", "birch", "pine", "spruce", "snowSpruce" }) do
	add("tree:" .. k, ArtGen.tree(ArtKit.trees[k], 20260801))
end
for _, k in ipairs({ "boulder", "outcrop", "iceShard" }) do
	add("rock:" .. k, ArtGen.rock(ArtKit.rocks[k], 4242))
end
for _, k in ipairs({ "cattail", "swampFern", "snowDrift", "lilyPad" }) do
	add("cluster:" .. k, ArtGen.cluster(ArtKit.clusters[k], 77))
end
for _, k in ipairs({ "lodge", "outpost" }) do
	add("cabin:" .. k, ArtGen.cabin(ArtKit.cabins[k]))
end
for _, k in ipairs({
	"alaska_bull_moose", "appalachia_whitetail_deer", "alaska_grizzly_bear", "bayou_american_alligator",
	"appalachia_mountain_lion", "bayou_great_egret", "bayou_wood_duck", "bayou_swamp_rabbit",
	"appalachia_wild_boar", "alaska_cross_fox", "bayou_painted_turtle", "alaska_caribou",
}) do
	add("creature:" .. k, ArtGen.creature(ArtKit.creatureArt[k], 1234))
end
for _, k in ipairs({ "alaska_king_salmon", "bayou_blue_catfish", "appalachia_trophy_largemouth_bass", "deepsea_marlin" }) do
	add("fish:" .. k, ArtGen.creature(ArtKit.fishArt[k], 1234))
end

do
	local rifle = ArtGen.rifle(ArtKit.weapons.huntingRifle)
	add("weapon:huntingRifle", rifle.model)
end

-- a grove: many trees scattered, to judge DENSITY and palette variety in aggregate
local grove = { parts = {} }
local plan = ArtGen.scatter({
	center = { x = 0, z = 0 }, radius = 95, count = 26, recipeCount = 2,
	scale = { min = 0.85, max = 1.2 }, minSpacing = ArtKit.budget.treeSpacing,
}, 1101, 30)
local keys = { "baldCypress", "snag" }
for _, c in ipairs(plan) do
	local t = ArtGen.tree(ArtKit.trees[keys[c.recipeIndex] or "baldCypress"], c.seed)
	local cy, sy = math.cos(c.yaw), math.sin(c.yaw)
	for _, p in ipairs(t.parts) do
		local q = table.clone(p)
		local px, pz = p.pos.x * c.scale, p.pos.z * c.scale
		q.pos = { x = c.x + px * cy + pz * sy, y = p.pos.y * c.scale, z = c.z - px * sy + pz * cy }
		q.size = { x = p.size.x * c.scale, y = p.size.y * c.scale, z = p.size.z * c.scale }
		if p.up ~= nil then
			q.up = { x = p.up.x * cy + p.up.z * sy, y = p.up.y, z = -p.up.x * sy + p.up.z * cy }
		end
		table.insert(grove.parts, q)
	end
end
add("scene:cypressGrove", grove)

w('{"subjects":[')
for i, s in ipairs(subjects) do
	if i > 1 then w(",") end
	dumpModel(s.label, s.model)
end
w(']}')
print(table.concat(buf))
