--!strict
-- In-memory FAKES implementing the persistence interfaces — the headless-test substrate. The
-- InMemoryDataStore deep-copies on store AND read (a real DataStore serializes values), so a mutation
-- to an in-memory profile can never leak into the durable copy — essential for the atomicity tests.

local Types = require("@src/server/persistence/Types")
local Schema = require("@src/types/Schema")
local Copy = require("@src/server/persistence/Copy")

type DataStoreLike = Types.DataStoreLike
type Clock = Types.Clock
type IdGenerator = Types.IdGenerator
type AuditSink = Types.AuditSink
type Telemetry = Types.Telemetry

local Fakes = {}

local deepCopy = Copy.deep

-- ── InMemoryDataStore ──────────────────────────────────────────────────────────
export type DataStoreControls = {
	failNextN: (n: number) -> (), -- make the next n updateAsync calls fail (throttle/error simulation)
	peek: (key: string) -> any, -- read the durable value WITHOUT going through updateAsync (test inspection)
	setRaw: (key: string, value: any) -> (), -- seed a durable value
}
function Fakes.newDataStore(): (DataStoreLike, DataStoreControls)
	local store: { [string]: any } = {}
	local failNext = 0
	local ds: DataStoreLike = {
		updateAsync = function(key, transform)
			if failNext > 0 then
				failNext -= 1
				return false, nil
			end
			local current = deepCopy(store[key])
			local newValue = transform(current)
			store[key] = deepCopy(newValue)
			return true, deepCopy(store[key])
		end,
		getAsync = function(key)
			return true, deepCopy(store[key])
		end,
	}
	local controls: DataStoreControls = {
		failNextN = function(n)
			failNext = n
		end,
		peek = function(key)
			return deepCopy(store[key])
		end,
		setRaw = function(key, value)
			store[key] = deepCopy(value)
		end,
	}
	return ds, controls
end

-- ── FakeClock ──────────────────────────────────────────────────────────────────
export type ClockControls = { set: (v: number) -> (), advance: (delta: number) -> () }
function Fakes.newClock(start: number): (Clock, ClockControls)
	local t = start
	local clock: Clock = { now = function()
		return t
	end }
	local controls: ClockControls = {
		set = function(v)
			t = v
		end,
		advance = function(delta)
			t += delta
		end,
	}
	return clock, controls
end

-- ── SeqIdGenerator (deterministic; runtime uses HttpService:GenerateGUID) ────────
function Fakes.newIdGenerator(): IdGenerator
	local counters: { [string]: number } = {}
	return {
		next = function(prefix)
			counters[prefix] = (counters[prefix] or 0) + 1
			return prefix .. "-" .. counters[prefix]
		end,
	}
end

-- ── InMemoryAuditLog ─────────────────────────────────────────────────────────────
function Fakes.newAuditLog(): AuditSink
	local logs: { [string]: { Schema.LedgerEntry } } = {}
	return {
		append = function(playerKey, entries)
			local l = logs[playerKey]
			if l == nil then
				l = {}
				logs[playerKey] = l
			end
			for _, e in entries do
				table.insert(l, deepCopy(e))
			end
		end,
		read = function(playerKey)
			return deepCopy(logs[playerKey] or {})
		end,
	}
end

-- ── InMemoryTelemetry ────────────────────────────────────────────────────────────
function Fakes.newTelemetry(): Telemetry
	local m: { [string]: number } = {}
	return {
		incr = function(metric, by)
			m[metric] = (m[metric] or 0) + (by or 1)
		end,
		snapshot = function()
			return deepCopy(m)
		end,
	}
end

return Fakes
