--!strict
-- READ-ONLY replication projection (§2). The server computes a fresh shadow of display-relevant state
-- (balance, EHT/EFT, Passport sets, ranks, gate readouts) from Step 1's PURE functions and replicates
-- THAT to the client. It is a copy, not a handle: a client that edits its shadow changes nothing
-- server-side (the sets are deep-copied; the numbers are values). The gate readouts are the single
-- source of truth the UI consumes — the client never re-derives gate logic.

local Schema = require("@src/types/Schema")
local Balance = require("@src/logic/Balance")
local EffectiveTier = require("@src/logic/EffectiveTier")
local Gate = require("@src/logic/Gate")
local Copy = require("@src/server/persistence/Copy")
local TrophyHall = require("@src/logic/TrophyHall")
local Progression = require("@src/logic/Progression")

type PlayerData = Schema.PlayerData
type Config = Schema.Config

local M = {}

export type Projection = {
	balance: number,
	eht: number,
	eft: number,
	unlockedDestinations: { [string]: boolean },
	conqueredDestinations: { [string]: boolean },
	hunterRankXP: number,
	anglerRankXP: number,
	gates: { [string]: Gate.GateResult },
	trophyHall: { displayed: { Schema.Artifact }, slotsUsed: number, slotsTotal: number },
	-- Step 9: the World-Map pins (unlocked from the PERSISTED set, unmetReasons for locked pins) + the
	-- Passport counts — the server-authoritative progression surface the client renders (never re-derives).
	worldMap: { [string]: Progression.Pin },
	passport: Progression.PassportCounts,
}

function M.buildProjection(profile: PlayerData, config: Config): Projection
	local gates: { [string]: Gate.GateResult } = {}
	for id, destination in config.destinations do
		gates[id] = Gate.evaluateGate(profile, destination, config)
	end
	local usage = TrophyHall.slotUsage(profile, config)
	return {
		balance = Balance.balanceOf(profile),
		eht = EffectiveTier.effectiveHuntingTier(profile, config),
		eft = EffectiveTier.effectiveFishingTier(profile, config),
		unlockedDestinations = Copy.deep(profile.unlockedDestinations),
		conqueredDestinations = Copy.deep(profile.conqueredDestinations),
		hunterRankXP = profile.hunterRankXP,
		anglerRankXP = profile.anglerRankXP,
		gates = gates,
		-- the Trophy Hall is a VIEW (filter artifacts, DISPLAYED) — the client renders it from this read-only
		-- shadow; deep-copied so a client edit changes nothing server-side. No parallel structure is persisted.
		trophyHall = { displayed = Copy.deep(TrophyHall.displayed(profile)), slotsUsed = usage.used, slotsTotal = usage.total },
		worldMap = Progression.worldMapPins(profile, config),
		passport = Progression.passportCounts(profile, config),
	}
end

return M
