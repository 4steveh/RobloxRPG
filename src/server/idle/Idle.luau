--!strict
-- IDLE / AFK INTEGRITY MECHANISM (§6). This layer owns the INTEGRITY of idle's inputs and the
-- single-entry idempotent crediting; it does NOT own the amount — economy does (Step 6). Belongs here
-- because it is intrinsic to the session lifecycle (logout timestamp written at end, read at login) and
-- its idempotency is anti-dupe. Idle credits Cash ONLY — never Rank XP, never a conquest flag.

local Schema = require("@src/types/Schema")
local Ledger = require("@src/server/ledger/Ledger")

type PlayerData = Schema.PlayerData
type Config = Schema.Config

local M = {}

-- The amount is economy's formula (idleFraction × current-tier income × hours). STUB for Step 2 so the
-- mechanism's clamping/idempotency/idle-proof guarantees are testable without the formula.
-- TODO(step-6 / economy open question): the corpus does NOT define a player's "current tier" while
-- offline (EHT? EFT? highest tier reached? last location?) — it is an economy decision, not ours.
export type IdleAmountFn = (profile: PlayerData, config: Config, hours: number) -> number
function M.stubAmount(_profile: PlayerData, _config: Config, hours: number): number
	return math.floor(hours * 100) -- placeholder fixed rate; real formula lands in Step 6
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
