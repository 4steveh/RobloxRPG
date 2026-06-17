--!strict
-- THE TROPHY HALL AS A VIEW (SYS_lodge_trophy §2 / build notes; SYS_data_integrity §4). The Hall stores
-- NOTHING: it is filter(profile.artifacts, disposition == DISPLAYED). The one authoritative record per
-- trophy is the artifact + its provenance — there is no parallel "trophyWall" list, hence no desync/dupe
-- surface between inventory and wall. Display/un-display/salvage are §4 CAS transitions (ArtifactStore);
-- this module only READS state. Pure: zero content literals, zero mutation.

local Schema = require("@src/types/Schema")
local Enums = require("@src/types/Enums")

type PlayerData = Schema.PlayerData
type Artifact = Schema.Artifact
type Config = Schema.Config

local M = {}

local D = Enums.Disposition

-- displayed(profile): the wall — every artifact whose disposition == DISPLAYED, in a deterministic order
-- (by artifactId) so the render is stable. Computed, never stored.
function M.displayed(profile: PlayerData): { Artifact }
	local ids: { string } = {}
	for id, a in profile.artifacts do
		if a.disposition == D.DISPLAYED then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local out: { Artifact } = {}
	for _, id in ids do
		table.insert(out, profile.artifacts[id])
	end
	return out
end

function M.countDisplayed(profile: PlayerData): number
	local n = 0
	for _, a in profile.artifacts do
		if a.disposition == D.DISPLAYED then
			n += 1
		end
	end
	return n
end

-- totalSlots = baseTrophySlots + boughtSlots (derived; uncapped — no maxTrophySlots at MVL).
function M.totalSlots(profile: PlayerData, config: Config): number
	return config.tuning.lodge.baseTrophySlots + profile.lodge.boughtSlots
end

export type SlotUsage = { used: number, total: number }
function M.slotUsage(profile: PlayerData, config: Config): SlotUsage
	return { used = M.countDisplayed(profile), total = M.totalSlots(profile, config) }
end

-- The provenance plaque (what / where / when / loop / tier / rarity), READ from the artifact's provenance +
-- the target index — never re-entered or stored on the wall (one source of truth). The rendered weight-kg
-- label is a Studio concern (derived from the source species' weight data); Provenance carries sourceId +
-- mintedAt, not a per-catch weight. Fields are nil when provenance.sourceId is absent (a non-source mint).
export type Plaque = {
	what: string?, -- the source creature/fish name
	where: string?, -- the source's home DestinationId
	when: number?, -- mintedAt (server time)
	loop: Enums.Loop?,
	tier: number?,
	rarity: Enums.Rarity?,
}
function M.plaque(config: Config, artifact: Artifact): Plaque
	local sid = artifact.provenance.sourceId
	local idx = if sid ~= nil then config.targetIndex[sid] else nil
	local what: string? = nil
	if sid ~= nil then
		local c = config.creatures[sid]
		local f = config.fish[sid]
		what = if c ~= nil then c.name elseif f ~= nil then f.name else nil
	end
	return {
		what = what,
		where = if idx ~= nil then idx.destinationId else nil,
		when = artifact.provenance.mintedAt,
		loop = if idx ~= nil then idx.loop else nil,
		tier = if idx ~= nil then idx.tier else nil,
		rarity = if idx ~= nil then idx.rarity else nil,
	}
end

return M
