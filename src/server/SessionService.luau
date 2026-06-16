--!strict
-- SESSION ORCHESTRATION — ties the substrate together over the session lifecycle. Replaces the Step 1
-- PersistenceStub. login = acquire lock → load durable profile (or freshProfile) → idle credit →
-- write-through (persist sessionOpen + idle). logout = write logoutTimestamp + sessionOpen=false → final
-- whole-profile flush → release lock cleanly. Provides the gauntlet's saveFn/markDirty per session.

local Schema = require("@src/types/Schema")
local Types = require("@src/server/persistence/Types")
local ProfileStore = require("@src/server/persistence/ProfileStore")
local Idle = require("@src/server/idle/Idle")
local Profile = require("@src/logic/Profile")

type PlayerData = Schema.PlayerData
type Config = Schema.Config

local M = {}

export type Deps = {
	store: Types.DataStoreLike,
	clock: Types.Clock,
	config: Config,
	serverId: string,
	idleAmountFn: Idle.IdleAmountFn?, -- defaults to Idle.economyAmount (the Step-6 real amount, T_idle = max(EHT,EFT))
	telemetry: Types.Telemetry?,
	sleep: ((seconds: number) -> ())?, -- runtime retry backoff; nil headless
}
export type Session = { playerId: number, profile: PlayerData, dirty: boolean, live: boolean }
export type SessionService = { deps: Deps, sessions: { [number]: Session } }
export type LoginResult = { ok: boolean, session: Session?, reason: string? }

function M.new(deps: Deps): SessionService
	return { deps = deps, sessions = {} }
end

local function incr(self: SessionService, metric: string)
	if self.deps.telemetry ~= nil then
		self.deps.telemetry.incr(metric, 1)
	end
end

local function saveOpts(self: SessionService): ProfileStore.SaveOpts
	local p = self.deps.config.tuning.persistence
	return { maxAttempts = p.saveRetryMaxAttempts, backoffSeconds = p.saveRetryBackoffSeconds, sleep = self.deps.sleep }
end

-- login: the keystone path. Reject if another live session holds the lock.
function M.login(self: SessionService, playerId: number): LoginResult
	local deps = self.deps
	local key = ProfileStore.keyFor(playerId)
	local now = deps.clock.now()
	local timeout = deps.config.tuning.persistence.sessionLockTimeoutSeconds

	local acq = ProfileStore.acquireLock(deps.store, key, deps.serverId, now, timeout)
	if not acq.ok then
		incr(self, "session.login_rejected")
		return { ok = false, reason = acq.reason }
	end

	local profile = acq.data or Profile.freshProfile(deps.config)
	local idleFn = deps.idleAmountFn or Idle.economyAmount
	Idle.creditOnLogin(profile, deps.config, now, idleFn) -- sets sessionOpen=true (+ maybe an idle entry)
	profile.lastSaveTimestamp = now

	-- write-through the login state so a crash is detectable (sessionOpen) and idle isn't lost.
	local saved = ProfileStore.save(deps.store, key, deps.serverId, profile, now, saveOpts(self))
	if not saved.ok then
		ProfileStore.releaseLock(deps.store, key, deps.serverId)
		incr(self, "session.login_save_failed")
		return { ok = false, reason = "login_save_failed" }
	end

	local session: Session = { playerId = playerId, profile = profile, dirty = false, live = true }
	self.sessions[playerId] = session
	incr(self, "session.login_ok")
	return { ok = true, session = session }
end

function M.heartbeat(self: SessionService, playerId: number): boolean
	local s = self.sessions[playerId]
	if s == nil then
		return false
	end
	local ok = ProfileStore.heartbeat(self.deps.store, ProfileStore.keyFor(playerId), self.deps.serverId, self.deps.clock.now())
	if not ok then
		incr(self, "session.heartbeat_lost")
	end
	return ok
end

function M.markDirty(self: SessionService, playerId: number)
	local s = self.sessions[playerId]
	if s ~= nil then
		s.dirty = true
	end
end

-- write-through persist of the live profile (the gauntlet's saveFn for critical handlers).
function M.saveNow(self: SessionService, playerId: number): boolean
	local s = self.sessions[playerId]
	if s == nil then
		return false
	end
	local now = self.deps.clock.now()
	s.profile.lastSaveTimestamp = now
	local r = ProfileStore.save(self.deps.store, ProfileStore.keyFor(playerId), self.deps.serverId, s.profile, now, saveOpts(self))
	if r.ok then
		s.dirty = false
		incr(self, "save.ok")
	else
		incr(self, "save.fail")
		if r.reason == "retry_exhausted" then
			incr(self, "save.retry_exhausted")
		end
	end
	return r.ok
end

-- periodic autosave (only if dirty).
function M.autosaveIfDirty(self: SessionService, playerId: number): boolean
	local s = self.sessions[playerId]
	if s == nil or not s.dirty then
		return true
	end
	return M.saveNow(self, playerId)
end

-- clean session-end: write logoutTimestamp, mark sessionOpen=false, flush whole-profile, release lock.
function M.logout(self: SessionService, playerId: number): boolean
	local s = self.sessions[playerId]
	if s == nil then
		return false
	end
	local deps = self.deps
	local key = ProfileStore.keyFor(playerId)
	local now = deps.clock.now()
	s.profile.logoutTimestamp = now
	s.profile.sessionOpen = false
	s.profile.lastSaveTimestamp = now
	local r = ProfileStore.save(deps.store, key, deps.serverId, s.profile, now, saveOpts(self))
	ProfileStore.releaseLock(deps.store, key, deps.serverId)
	s.live = false
	self.sessions[playerId] = nil
	incr(self, "session.logout")
	return r.ok
end

return M
