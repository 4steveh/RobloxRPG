--!strict
-- ARTIFACT anti-dupe primitives (§4/§5). Scarce things are unique IDs under a single authoritative
-- owner+disposition; every change is a no-yield CAS. This module builds the PRIMITIVES (mint, the CAS
-- disposition transition, tombstone). The FLOWS that invoke specific transitions are deferred:
-- display/salvage → Step 8; escrow/the two-sided swap + ownership transfer → Step 12.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")
local Validation = require("@src/config/Validation")
local Types = require("@src/server/persistence/Types")

type PlayerData = Schema.PlayerData
type Artifact = Schema.Artifact
type Disposition = Enums.Disposition
type IdGenerator = Types.IdGenerator

local M = {}

local D = Enums.Disposition

-- The §4 transition table as a CLOSED legal (from→to) edge set. The primitive enforces this so a future
-- flow (Step 8/12) cannot pass an illegal pair (e.g. ESCROWED→SALVAGED, which would salvage an item locked
-- in a live trade, or DISPLAYED→ESCROWED, which must go via HELD first). mint→HELD is owned by M.mint;
-- ESCROWED→(new owner, HELD) is the Step-12 swap (ownership transfer rides this ESCROWED→HELD edge).
local LEGAL_EDGES: { [string]: boolean } = {
	["HELD->DISPLAYED"] = true,
	["DISPLAYED->HELD"] = true,
	["HELD->ESCROWED"] = true,
	["ESCROWED->HELD"] = true,
	["HELD->SALVAGED"] = true,
	["DISPLAYED->SALVAGED"] = true,
}

export type MintArgs = {
	kind: Enums.ArtifactKind,
	tradeable: boolean,
	owner: string,
	sourceId: string?, -- the creature/fish it was minted from (provenance)
	validatingEventId: string?,
}

-- One rare spawn → ONE mint → one globally-unique id (artifactIdScheme = GUID via the injected
-- generator). Provenance recorded; initial disposition HELD (the default at mint). NO-YIELD.
-- (Reward pipelines call this in Steps 4/5; here it is the standalone primitive.)
function M.mint(profile: PlayerData, args: MintArgs, idGen: IdGenerator, now: number): Artifact
	local id = idGen.next("art")
	assert(profile.artifacts[id] == nil, "ArtifactStore.mint: id collision (generator must be unique): " .. id)
	local artifact: Artifact = {
		artifactId = id,
		owner = args.owner,
		kind = args.kind,
		disposition = D.HELD,
		tradeable = args.tradeable,
		tombstoned = false,
		provenance = { sourceId = args.sourceId, mintedAt = now, validatingEventId = args.validatingEventId },
	}
	profile.artifacts[id] = artifact
	profile.inventory.artifactIds[id] = true
	return artifact
end

export type TransitionResult = { ok: boolean, reason: string? }

-- Compare-and-swap disposition transition (RD4). Succeeds ONLY if the current disposition matches
-- `expected`, applied with no intervening yield — this is what defeats the display/salvage/trade race
-- (the first commit leaves a state that fails the second's precondition). Honors kind-gating
-- (DISPLAYED/SALVAGED are Trophy-only). →SALVAGED is terminal: tombstone (marked, never erased).
function M.transition(profile: PlayerData, artifactId: string, expected: Disposition, to: Disposition): TransitionResult
	local a = profile.artifacts[artifactId]
	if a == nil then
		return { ok = false, reason = "no_such_artifact" }
	end
	if a.tombstoned then
		return { ok = false, reason = "tombstoned" }
	end
	if a.disposition ~= expected then
		return { ok = false, reason = "precondition_mismatch" } -- CAS failure (defeats the double-spend race)
	end
	if not LEGAL_EDGES[expected .. "->" .. to] then
		return { ok = false, reason = "illegal_transition" } -- not an edge in the §4 table (incl. self-transitions)
	end
	if not Validation.isDispositionLegal(a.kind, to) then
		return { ok = false, reason = "illegal_for_kind" } -- e.g. a non-trophy → DISPLAYED/SALVAGED
	end
	a.disposition = to
	-- `inventory.artifactIds` is the OWNED set (membership); disposition is the where (HELD/DISPLAYED/
	-- ESCROWED stay owned). Only SALVAGED (terminal) leaves the set and tombstones.
	if to == D.SALVAGED then
		a.tombstoned = true
		profile.inventory.artifactIds[artifactId] = nil
	end
	return { ok = true }
end

-- ── Step 12: the cross-profile OWNERSHIP TRANSFER (the swap's per-artifact move; SYS_data_integrity §5).
-- Rides the ESCROWED → (new owner, HELD) edge: the new owner gets a LIVE copy (owner flipped, HELD, owned);
-- the old owner's record is TOMBSTONED (marked traded-away, never erased — audit/rollback, exactly as SALVAGE
-- tombstones) and leaves the owned set. CAS on the expected ESCROWED state defeats the double-spend race.
-- THE anti-dupe invariant: no artifact is ever LIVE in two profiles (the old side is a tombstone, not live).
-- The two-profile atomicity (all-or-nothing, no-yield, restore-both-on-failure) is the CALLER's job (TradeSwap
-- over PairTransaction); this is the single-artifact primitive it composes.
function M.transferOwnership(fromProfile: PlayerData, toProfile: PlayerData, artifactId: string, expected: Disposition, newOwner: string): TransitionResult
	local a = fromProfile.artifacts[artifactId]
	if a == nil then
		return { ok = false, reason = "no_such_artifact" }
	end
	if a.tombstoned then
		return { ok = false, reason = "tombstoned" }
	end
	if a.disposition ~= expected then
		return { ok = false, reason = "precondition_mismatch" } -- CAS failure (the artifact isn't ESCROWED as expected)
	end
	if not a.tradeable then
		return { ok = false, reason = "not_tradeable" }
	end
	-- the new owner's LIVE record: owner flipped, HELD; provenance preserved (immutable mint history).
	local live: Artifact = {
		artifactId = a.artifactId,
		owner = newOwner,
		kind = a.kind,
		disposition = D.HELD,
		tradeable = a.tradeable,
		tombstoned = false,
		provenance = { sourceId = a.provenance.sourceId, mintedAt = a.provenance.mintedAt, validatingEventId = a.provenance.validatingEventId },
	}
	toProfile.artifacts[artifactId] = live -- overwrites any prior tombstone of this id (a re-acquisition)
	toProfile.inventory.artifactIds[artifactId] = true
	-- the old owner's side: a TOMBSTONE (audit, never erased), out of the owned set (not live, not tradeable).
	a.tombstoned = true
	fromProfile.inventory.artifactIds[artifactId] = nil
	return { ok = true }
end

return M
