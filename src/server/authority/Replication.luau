--!strict
-- READ-ONLY replication projection (§2). The server computes a fresh shadow of display-relevant state
-- (balance, EHT/EFT, Passport sets, ranks, gate readouts) from Step 1's PURE functions and replicates
-- THAT to the client. It is a copy, not a handle: a client that edits its shadow changes nothing
-- server-side (the sets are deep-copied; the numbers are values). The gate readouts are the single
-- source of truth the UI consumes — the client never re-derives gate logic.

local Schema = require("../../types/Schema")
local Balance = require("../../logic/Balance")
local EffectiveTier = require("../../logic/EffectiveTier")
local Gate = require("../../logic/Gate")
local Copy = require("../persistence/Copy")
local TrophyHall = require("../../logic/TrophyHall")
local Progression = require("../../logic/Progression")
local LiveOps = require("../../logic/LiveOps")
local Onboarding = require("../../logic/Onboarding") -- review §6: surface the onboarding beat to the client

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
	-- Weather/traits: the read-only weather surface the client renders (the HUD countdown + "what can I
	-- farm now" chip). Server-time-derived; the client never gates on its own clock (display only).
	activeWeather: string?,
	activeTraits: { string },
	nextWindowChangeAt: number?,
	-- the onboarding objective surface (beat + target kind + progress) — the HUD renders an objective card +
	-- a world-space waypoint from this; DATA only (the client owns the wording). Review §6.
	onboarding: Onboarding.ObjectiveProjection,
}

function M.buildProjection(profile: PlayerData, config: Config, now: number): Projection
	local activeTraitsList: { string } = {}
	for tr in LiveOps.activeTraits(config, now) do
		table.insert(activeTraitsList, tr)
	end
	table.sort(activeTraitsList)
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
		activeWeather = LiveOps.activeWeather(config, now),
		activeTraits = activeTraitsList,
		nextWindowChangeAt = LiveOps.nextWindowChangeAt(config, now),
		onboarding = Onboarding.projection(profile),
	}
end

return M
