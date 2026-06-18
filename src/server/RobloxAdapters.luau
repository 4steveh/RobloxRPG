--!strict
-- THIN ROBLOX ADAPTERS — wrap the real Roblox services in the persistence interfaces. INJECTION-BASED:
-- the services are passed in (typed loosely), so this module references NO Roblox globals and stays
-- --!strict-clean headless. The actual `game:GetService(...)` wiring is the Studio bootstrap (documented
-- in the README) — that one-screen edge is Studio-only and NOT headless-tested (honest coverage).
--
-- These adapters are thin passthroughs; the integrity LOGIC lives in the interface-side modules
-- (ProfileStore/Ledger/etc.) which ARE headless-tested. Anything risky here (yields, throttling, the
-- 4 MB key limit, ProcessReceipt redelivery) is a Roblox reality the logic already accounts for.

local Types = require("./persistence/Types")
local Schema = require("../types/Schema")

local M = {}

-- Wrap a Roblox DataStore (from DataStoreService:GetDataStore(...)). UpdateAsync yields + can error, so
-- pcall it and map a failure to (false, nil) — the retry territory ProfileStore.save already handles.
-- Use UpdateAsync (read-modify-write), NOT SetAsync (the lock + UpdateAsync are the concurrency defense).
function M.dataStore(robloxDataStore: any): Types.DataStoreLike
	return {
		updateAsync = function(key, transform)
			local ok, result = pcall(function()
				return robloxDataStore:UpdateAsync(key, function(current)
					return transform(current)
				end)
			end)
			if not ok then
				return false, nil
			end
			return true, result
		end,
		getAsync = function(key)
			local ok, result = pcall(function()
				return robloxDataStore:GetAsync(key)
			end)
			if not ok then
				return false, nil
			end
			return true, result
		end,
	}
end

-- Server wall-clock. os.time() is monotonic-enough server time; Roblox can swap in
-- workspace:GetServerTimeNow() for sub-second precision. Boost expiry / idle use this (never a client clock).
function M.clock(): Types.Clock
	return { now = function()
		return os.time()
	end }
end

-- GUID id generator (artifactIdScheme = GUID — globally unique across players, required for trade).
function M.idGenerator(httpService: any): Types.IdGenerator
	return { next = function(prefix)
		return prefix .. "-" .. httpService:GenerateGUID(false)
	end }
end

-- Audit sink backed by a SEPARATE append-only DataStore (the one deliberate non-whole-profile store).
-- TODO(ops): a separate date/player-keyed DataStore (in-platform) vs an external telemetry sink.
function M.auditSink(robloxAuditStore: any): Types.AuditSink
	return {
		append = function(playerKey, entries)
			pcall(function()
				robloxAuditStore:UpdateAsync(playerKey, function(current: any)
					local list = current or {}
					for _, e in entries do
						table.insert(list, e)
					end
					return list
				end)
			end)
		end,
		read = function(playerKey): { Schema.LedgerEntry }
			local ok, result = pcall(function()
				return robloxAuditStore:GetAsync(playerKey)
			end)
			if ok and type(result) == "table" then
				return result
			end
			return {}
		end,
	}
end

-- Telemetry forwarded to an injected reporter (e.g. an AnalyticsService logger).
function M.telemetry(report: (metric: string, value: number) -> ()): Types.Telemetry
	local counts: { [string]: number } = {}
	return {
		incr = function(metric, by)
			counts[metric] = (counts[metric] or 0) + (by or 1)
			report(metric, by or 1)
		end,
		snapshot = function()
			return counts
		end,
	}
end

return M
