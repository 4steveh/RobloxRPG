--!strict
-- PURE deterministic randomness + coherent noise. No Roblox globals, no `math.random` (which carries
-- process-global state and would make the world differ between server boots). Every function is a
-- function of its arguments only, so a seeded world build is byte-identical on every machine — which is
-- what makes the procedural art layer unit-testable headlessly instead of eyeball-only in Studio.
--
-- The numeric constants below are ALGORITHM constants (xorshift shift triple, the 32-bit integer-hash
-- multipliers), not tunable content: changing them changes the bit-mixing quality, not any game value.
-- Tunable shape parameters (octaves, lacunarity, gain, amplitude) are arguments, per the config/logic split.
--
-- All integer math is exact: 32-bit multiplies go through mul32, which splits into 16-bit halves so no
-- intermediate exceeds 2^53 and IEEE doubles stay exact.

local Rand = {}

local MASK32 = 0xFFFFFFFF
local MASK16 = 0xFFFF
-- xorshift32 shift triple (Marsaglia) — full-period on 32 bits.
local XS_A, XS_B, XS_C = 13, 17, 5
-- Integer-hash multipliers (Knuth 2654435761 = golden-ratio * 2^32; the two others are widely used
-- avalanche multipliers from the "Hash prospector" search space).
local KNUTH = 2654435761
local AVAL_1 = 0x7FEB352D
local AVAL_2 = 0x846CA68B
-- Fixed odd co-prime strides that decorrelate the two lattice axes and the seed from each other.
local STRIDE_X = 0x27D4EB2D
local STRIDE_Z = 0x165667B1
local STRIDE_S = 0x9E3779B9

-- Exact 32-bit multiply. (a*b) mod 2^32 via 16-bit halves, so no product exceeds 2^33.
local function mul32(a: number, b: number): number
	local ah = bit32.rshift(a, 16)
	local al = bit32.band(a, MASK16)
	local bh = bit32.rshift(b, 16)
	local bl = bit32.band(b, MASK16)
	local lo = al * bl
	local mid = bit32.band(ah * bl + al * bh, MASK16)
	return bit32.band(lo + bit32.lshift(mid, 16), MASK32)
end
Rand.mul32 = mul32

-- Avalanche a 32-bit word so adjacent inputs produce uncorrelated outputs.
local function avalanche(x: number): number
	local v = bit32.band(x, MASK32)
	v = bit32.bxor(v, bit32.rshift(v, 16))
	v = mul32(v, AVAL_1)
	v = bit32.bxor(v, bit32.rshift(v, 15))
	v = mul32(v, AVAL_2)
	v = bit32.bxor(v, bit32.rshift(v, 16))
	return v
end
Rand.avalanche = avalanche

-- ── Stateful stream ───────────────────────────────────────────────────────────────────────────────────
-- A tiny mutable cursor. Passed explicitly (never global), so two generators can draw from independent
-- streams and a caller can reproduce any single prop by re-seeding.
export type Stream = { state: number }

function Rand.stream(seed: number): Stream
	local s = avalanche(bit32.band(math.floor(seed), MASK32))
	if s == 0 then
		s = STRIDE_S -- xorshift32 has a fixed point at 0; nudge off it
	end
	return { state = s }
end

-- Raw next word, [0, 2^32).
function Rand.nextUInt(st: Stream): number
	local x = st.state
	x = bit32.bxor(x, bit32.lshift(x, XS_A))
	x = bit32.bxor(x, bit32.rshift(x, XS_B))
	x = bit32.bxor(x, bit32.lshift(x, XS_C))
	x = bit32.band(x, MASK32)
	if x == 0 then
		x = STRIDE_S
	end
	st.state = x
	return x
end

-- Uniform in [0, 1).
function Rand.unit(st: Stream): number
	return Rand.nextUInt(st) / 4294967296
end

-- Uniform in [lo, hi).
function Rand.range(st: Stream, lo: number, hi: number): number
	return lo + (hi - lo) * Rand.unit(st)
end

-- Uniform integer in [lo, hi] inclusive.
function Rand.int(st: Stream, lo: number, hi: number): number
	if hi <= lo then
		return lo
	end
	return lo + math.floor(Rand.unit(st) * (hi - lo + 1))
end

-- Symmetric jitter in [-amount, amount].
function Rand.jitter(st: Stream, amount: number): number
	return (Rand.unit(st) * 2 - 1) * amount
end

-- true with probability p.
function Rand.chance(st: Stream, p: number): boolean
	return Rand.unit(st) < p
end

-- Uniform pick from a non-empty list. Errors on an empty list rather than returning nil, so a
-- mis-authored palette fails loudly at build time instead of producing a nil colour.
function Rand.pick<T>(st: Stream, list: { T }): T
	local n = #list
	assert(n > 0, "Rand.pick: empty list")
	return list[Rand.int(st, 1, n)]
end

-- Fisher-Yates over a COPY (pure: the caller's list is untouched).
function Rand.shuffled<T>(st: Stream, list: { T }): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = Rand.int(st, 1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- ── Stateless lattice hash + coherent noise ───────────────────────────────────────────────────────────
-- hash2 is a pure function of (ix, iz, seed): the same lattice cell always yields the same value, which
-- is what makes a heightfield tile-able and resumable without carrying state across calls.
function Rand.hash2(ix: number, iz: number, seed: number): number
	local h = bit32.bxor(
		mul32(bit32.band(math.floor(ix), MASK32), STRIDE_X),
		mul32(bit32.band(math.floor(iz), MASK32), STRIDE_Z)
	)
	h = bit32.bxor(h, mul32(bit32.band(math.floor(seed), MASK32), STRIDE_S))
	return avalanche(mul32(h, KNUTH)) / 4294967296
end

-- Quintic smoothstep — C2 continuous, so an fbm heightfield has no visible lattice creases.
local function fade(t: number): number
	return t * t * t * (t * (t * 6 - 15) + 10)
end
Rand.fade = fade

-- Value noise in [0, 1] at continuous (x, z) on a unit lattice.
function Rand.valueNoise2(x: number, z: number, seed: number): number
	local x0 = math.floor(x)
	local z0 = math.floor(z)
	local fx = fade(x - x0)
	local fz = fade(z - z0)
	local v00 = Rand.hash2(x0, z0, seed)
	local v10 = Rand.hash2(x0 + 1, z0, seed)
	local v01 = Rand.hash2(x0, z0 + 1, seed)
	local v11 = Rand.hash2(x0 + 1, z0 + 1, seed)
	local a = v00 + (v10 - v00) * fx
	local b = v01 + (v11 - v01) * fx
	return a + (b - a) * fz
end

export type FbmParams = {
	frequency: number, -- lattice cells per stud
	octaves: number,
	lacunarity: number, -- frequency multiplier per octave
	gain: number, -- amplitude multiplier per octave
}

-- Fractal Brownian motion, normalised to [0, 1] by the sum of amplitudes actually used.
function Rand.fbm2(x: number, z: number, seed: number, p: FbmParams): number
	local total = 0
	local amp = 1
	local norm = 0
	local freq = p.frequency
	local octaves = math.max(1, math.floor(p.octaves))
	for i = 0, octaves - 1 do
		total += Rand.valueNoise2(x * freq, z * freq, seed + i * 1013) * amp
		norm += amp
		amp *= p.gain
		freq *= p.lacunarity
	end
	if norm <= 0 then
		return 0
	end
	return total / norm
end

-- Ridged multifractal in [0, 1]: sharp crests, smooth valleys. This is what turns a soft blobby fbm
-- heightfield into readable mountain ridges (Appalachia) and glacier spines (Alaska).
function Rand.ridge2(x: number, z: number, seed: number, p: FbmParams): number
	local total = 0
	local amp = 1
	local norm = 0
	local freq = p.frequency
	local octaves = math.max(1, math.floor(p.octaves))
	for i = 0, octaves - 1 do
		local n = Rand.valueNoise2(x * freq, z * freq, seed + i * 1013)
		local r = 1 - math.abs(n * 2 - 1)
		total += r * r * amp
		norm += amp
		amp *= p.gain
		freq *= p.lacunarity
	end
	if norm <= 0 then
		return 0
	end
	return total / norm
end

-- ── Small pure helpers the generators lean on ─────────────────────────────────────────────────────────

function Rand.clamp(v: number, lo: number, hi: number): number
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end

function Rand.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Maps v from [inLo, inHi] to [outLo, outHi], clamped at both ends.
function Rand.remap(v: number, inLo: number, inHi: number, outLo: number, outHi: number): number
	if inHi == inLo then
		return outLo
	end
	local t = Rand.clamp((v - inLo) / (inHi - inLo), 0, 1)
	return outLo + (outHi - outLo) * t
end

-- Smooth 0→1 ramp across [edge0, edge1].
function Rand.smoothstep(edge0: number, edge1: number, v: number): number
	if edge1 == edge0 then
		return v >= edge1 and 1 or 0
	end
	local t = Rand.clamp((v - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

return table.freeze(Rand)
