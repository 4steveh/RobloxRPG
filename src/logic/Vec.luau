--!strict
-- PURE 3-vector math on Schema/Art's plain {x,y,z} tables. Exists so the procedural geometry generators
-- can do real spatial work (branch directions, orthonormal frames, slope) headlessly — Vector3 is a Roblox
-- global and is therefore forbidden in src/logic. The Studio instantiator converts at the boundary.
--
-- Every function is total and allocation-per-call; these run at world-build time (once), not per frame.

local Art = require("../types/Art")

type Vec3 = Art.Vec3

local Vec = {}

function Vec.new(x: number, y: number, z: number): Vec3
	return { x = x, y = y, z = z }
end

function Vec.add(a: Vec3, b: Vec3): Vec3
	return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
end

function Vec.sub(a: Vec3, b: Vec3): Vec3
	return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

function Vec.scale(a: Vec3, s: number): Vec3
	return { x = a.x * s, y = a.y * s, z = a.z * s }
end

function Vec.mul(a: Vec3, b: Vec3): Vec3
	return { x = a.x * b.x, y = a.y * b.y, z = a.z * b.z }
end

function Vec.dot(a: Vec3, b: Vec3): number
	return a.x * b.x + a.y * b.y + a.z * b.z
end

function Vec.cross(a: Vec3, b: Vec3): Vec3
	return {
		x = a.y * b.z - a.z * b.y,
		y = a.z * b.x - a.x * b.z,
		z = a.x * b.y - a.y * b.x,
	}
end

function Vec.magnitude(a: Vec3): number
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
end

-- Horizontal (XZ) magnitude — the one the shell/walk math cares about.
function Vec.magnitudeXZ(a: Vec3): number
	return math.sqrt(a.x * a.x + a.z * a.z)
end

-- Unit vector. A zero vector normalises to +Y rather than producing NaN, so a degenerate recipe yields
-- an upright part instead of an invisible one with a corrupt CFrame.
function Vec.unit(a: Vec3): Vec3
	local m = Vec.magnitude(a)
	if m <= 1e-9 then
		return { x = 0, y = 1, z = 0 }
	end
	return { x = a.x / m, y = a.y / m, z = a.z / m }
end

function Vec.lerp(a: Vec3, b: Vec3, t: number): Vec3
	return { x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t, z = a.z + (b.z - a.z) * t }
end

-- Any unit vector perpendicular to `a`. The reference axis is +Z, not +Y, for a load-bearing reason:
-- cross({0,1,0}, {0,0,1}) = {1,0,0}, so `frame({0,1,0})` comes out as the exact IDENTITY basis. With +Y as
-- the reference it produced right = {0,0,-1}, which silently TRANSPOSED authored size.x and size.z on every
-- unrotated part (a 76x60 cabin measured 154 studs across). +Z is swapped out only when `a` is itself
-- near ±Z, where the cross product would degenerate.
function Vec.perpendicular(a: Vec3): Vec3
	local u = Vec.unit(a)
	local ref: Vec3 = if math.abs(u.z) > 0.9 then { x = 0, y = 1, z = 0 } else { x = 0, y = 0, z = 1 }
	return Vec.unit(Vec.cross(u, ref))
end

-- Orthonormal frame with `up` as the Y axis. Returns (right, up, forward) — the exact triple the
-- instantiator feeds CFrame.fromMatrix(pos, right, up), whose implied third axis is right x up = forward.
-- frame({0,1,0}) is the identity, so an unrotated part's size maps 1:1 onto world XYZ.
function Vec.frame(up: Vec3): (Vec3, Vec3, Vec3)
	local u = Vec.unit(up)
	local right = Vec.perpendicular(u)
	local forward = Vec.unit(Vec.cross(right, u))
	return right, u, forward
end

-- Orthonormal frame with `axis` as the X axis — the cylinder case, where the primitive's length runs along
-- local X (see the CYLINDER AXIS CONVENTION note in types/Art.luau).
function Vec.frameX(axis: Vec3): (Vec3, Vec3, Vec3)
	local r = Vec.unit(axis)
	local up = Vec.perpendicular(r)
	local forward = Vec.unit(Vec.cross(r, up))
	return r, up, forward
end

-- Rotate `dir` away from itself by `angle` radians, around the azimuth `az` in the plane perpendicular
-- to `dir`. This is the primitive that makes recursive branching read organic: a child limb leaves its
-- parent at a fixed cone angle but a random azimuth.
function Vec.tilt(dir: Vec3, angle: number, az: number): Vec3
	local d = Vec.unit(dir)
	local right, _, forward = Vec.frame(d)
	local perp = Vec.add(Vec.scale(right, math.cos(az)), Vec.scale(forward, math.sin(az)))
	return Vec.unit(Vec.add(Vec.scale(d, math.cos(angle)), Vec.scale(perp, math.sin(angle))))
end

-- Rotate `v` about the world Y axis by `yaw` radians.
function Vec.rotateY(v: Vec3, yaw: number): Vec3
	local c, s = math.cos(yaw), math.sin(yaw)
	return { x = v.x * c + v.z * s, y = v.y, z = -v.x * s + v.z * c }
end

-- Yaw (radians, about +Y) that points +Z at the XZ direction of `v`. Used for signage and props that
-- must face a target without a full frame.
function Vec.yawTo(v: Vec3): number
	return math.atan2(v.x, v.z)
end

return table.freeze(Vec)
