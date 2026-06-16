--!strict
-- IDLE / AFK INTEGRITY MECHANISM (§6). This layer owns the INTEGRITY of idle's inputs and the
-- single-entry idempotent crediting; it does NOT own the amount — economy does (Step 6). Belongs here
-- because it is intrinsic to the session lifecycle (logout timestamp written at end, read at login) and
-- its idempotency is anti-dupe. Idle credits Cash ONLY — never Rank XP, never a conquest flag.

local Schema = require("@src/types/Schema")
local Ledger = require("@src/server/ledger/Ledger")
local Economy = require("@src/logic/Economy")
local EffectiveTier = require("@src/logic/EffectiveTier")

type PlayerData = Schema.PlayerData
type Config = Schema.Config

local M = {}

export type IdleAmountFn = (profile: PlayerData, config: Config, hours: number) -> number

-- The REAL idle amount (Step 6): idleFraction · Income(T_idle) · hours, with **T_idle = max(EHT, EFT)** —
-- the player's best effective (gated) tier. Rationale: idle is "a fraction of active income" (§6), and
-- active income scales with the tier you can actually play; tying idle to max(EHT, EFT) rewards gear
-- investment, stays idle-PROOF (capped + fractional + still can't conquer), and uses the effective (min-rule)
-- tier so one high item can't inflate it. The hours are already clamped to idleCapHours by creditOnLogin.
--   [Step 6's resolution of the Step-2 / SYS_economy open "current tier" question — flagged to ratify;
--    the alternatives (highest-conquered, last-location) are viable, this is the simplest principled default.]
function M.economyAmount(profile: PlayerData, config: Config, hours: number): number
	local tIdle = math.max(EffectiveTier.effectiveHuntingTier(profile, config), EffectiveTier.effectiveFishingTier(profile, config))
	-- FLOOR (not round): idle under-credits by design — over-crediting mints Cash; the safe direction (§6).
	return math.floor(config.tuning.economy.idleFraction * Economy.income(config, tIdle) * hours)
end

-- A simple linear amount-fn retained for the mechanism tests (clamp / idempotency / crash-fallback are
-- amount-agnostic; this keeps those tests independent of the economy curve). NOT used in production.
function M.stubAmount(_profile: PlayerData, _config: Config, hours: number): number
	return math.floor(hours * 100)
end

export type CreditResult = { credited: number, hours: number, basis: string }

-- creditOnLogin: determine the offline basis, clamp to idleCapHours, credit EXACTLY ONE `idle` entry,
-- mark the session open. Idempotent: once sessionOpen is true (persisted by the caller's login save), a
-- replayed/reconnect login takes the crash path against lastSaveTimestamp → ~0, so idle can't double-credit.
function M.creditOnLogin(profile: PlayerData, config: Config, now: number, idleAmountFn: IdleAmountFn): CreditResult
	local capSeconds = config.tuning.economy.idleCapHours * 3600
	local basis: number
	local basisName: string

	if profile.sessionOpen then
		-- prior session crashed (never wrote a clean logout) → fall back to the last-save timestamp.
		-- This UNDER-credits (loses the unsaved tail) — the safe direction; over-crediting mints Cash.
		basis = profile.lastSaveTimestamp
		basisName = "crash_fallback"
	elseif profile.logoutTimestamp > 0 then
		basis = profile.logoutTimestamp
		basisName = "clean_logout"
	else
		profile.sessionOpen = true -- brand-new / never logged out → no idle, just claim the session
		return { credited = 0, hours = 0, basis = "fresh" }
	end

	profile.sessionOpen = true -- claim the session (the caller persists this → reconnect-race protection)

	local elapsed = now - basis
	if elapsed < 0 then
		elapsed = 0
	end
	if elapsed > capSeconds then
		elapsed = capSeconds
	end
	local hours = elapsed / 3600
	if hours <= 0 then
		return { credited = 0, hours = 0, basis = basisName }
	end

	local amount = idleAmountFn(profile, config, hours)
	if amount <= 0 then
		return { credited = 0, hours = hours, basis = basisName }
	end
	-- exactly one idle-tagged ledger entry; Cash only (no Rank XP, no conquest)
	Ledger.applyEntry(profile.cash, {
		type = "idle",
		amount = amount,
		loop = "none",
		validatingEventId = "idle:" .. basis, -- keyed to the basis time (§6 idempotency naming)
	}, now)
	return { credited = amount, hours = hours, basis = basisName }
end

return M
