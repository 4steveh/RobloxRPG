--!strict
-- SESSION-LOCKED, SINGLE-WRITER PROFILE STORE (RD5 — the keystone; the precondition for every other
-- anti-dupe rule). The lock lives IN the profile key (the ProfileStore idiom; DataStore-based, MVL).
-- Cross-server MemoryStore brokering is TODO(open), not MVL. Logic-only — yields/backoff sleeping is the
-- adapter's job (inject `sleep`); the in-memory transform is synchronous (no yield, the serialization point).

local Types = require("./Types")
local Schema = require("../../types/Schema")

type DataStoreLike = Types.DataStoreLike
type StoredProfile = Types.StoredProfile
type PlayerData = Schema.PlayerData

local M = {}

export type AcquireResult = { ok: boolean, data: PlayerData?, reason: string? }
export type SaveResult = { ok: boolean, attempts: number, reason: string? }
export type SaveOpts = { maxAttempts: number, backoffSeconds: number?, sleep: ((seconds: number) -> ())? }

function M.keyFor(playerId: number): string
	return "profile:" .. playerId
end

-- Acquire the session lock. Grants if there is no lock, the lock is ours, or the lock is STALE
-- (no heartbeat past `timeoutSeconds`). A LIVE lock held by another server is NEVER stolen — that
-- pure-timeout steal is exactly the two-writer dupe the lock exists to prevent.
function M.acquireLock(store: DataStoreLike, key: string, serverId: string, now: number, timeoutSeconds: number): AcquireResult
	local granted = false
	local ok, stored = store.updateAsync(key, function(current: any): any
		local cur: StoredProfile = current or { data = nil, lock = nil }
		local lock = cur.lock
		if lock ~= nil and lock.serverId ~= serverId and (now - lock.heartbeat) < timeoutSeconds then
			granted = false -- a live lock held by another server → reject (return unchanged)
			return cur
		end
		granted = true
		return { data = cur.data, lock = { serverId = serverId, heartbeat = now } }
	end)
	if not ok then
		return { ok = false, reason = "datastore_error" }
	end
	if not granted then
		return { ok = false, reason = "locked" }
	end
	local s: StoredProfile = stored
	return { ok = true, data = s.data }
end

-- Refresh our lock's heartbeat (the holding server calls this on `lockHeartbeatIntervalSeconds`).
function M.heartbeat(store: DataStoreLike, key: string, serverId: string, now: number): boolean
	local refreshed = false
	local ok = store.updateAsync(key, function(current: any): any
		local cur: StoredProfile = current or { data = nil, lock = nil }
		if cur.lock ~= nil and cur.lock.serverId == serverId then
			cur.lock.heartbeat = now
			refreshed = true
		end
		return cur
	end)
	return ok and refreshed
end

-- Whole-profile, all-or-nothing write. Writes ONLY if we still hold the lock (a server that lost the
-- lock must never overwrite the new owner's data). Retries on DataStore failure up to maxAttempts; on
-- exhaustion returns failure and the durable value is unchanged (revert-to-last-good; never corruption).
function M.save(store: DataStoreLike, key: string, serverId: string, profile: PlayerData, now: number, opts: SaveOpts): SaveResult
	local attempts = 0
	while attempts < opts.maxAttempts do
		attempts += 1
		local wrote = false
		local lostLock = false
		local ok = store.updateAsync(key, function(current: any): any
			local cur: StoredProfile = current or { data = nil, lock = nil }
			if cur.lock == nil or cur.lock.serverId ~= serverId then
				lostLock = true -- we no longer hold the lock → do NOT overwrite
				return cur
			end
			cur.data = profile
			cur.lock.heartbeat = now
			wrote = true
			return cur
		end)
		if ok and lostLock then
			return { ok = false, attempts = attempts, reason = "lock_lost" }
		end
		if ok and wrote then
			return { ok = true, attempts = attempts }
		end
		-- DataStore failure → retry (the runtime adapter sleeps `backoffSeconds`; headless skips).
		if opts.sleep ~= nil and opts.backoffSeconds ~= nil then
			opts.sleep(opts.backoffSeconds * attempts)
		end
	end
	return { ok = false, attempts = attempts, reason = "retry_exhausted" }
end

-- Clean release (on leave): clear our lock, keep the data. A second session can then load immediately.
function M.releaseLock(store: DataStoreLike, key: string, serverId: string): boolean
	local released = false
	local ok = store.updateAsync(key, function(current: any): any
		local cur: StoredProfile = current or { data = nil, lock = nil }
		if cur.lock ~= nil and cur.lock.serverId == serverId then
			cur.lock = nil
			released = true
		end
		return cur
	end)
	return ok and released
end

return M
