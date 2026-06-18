--!strict
-- Persistence INTERFACES. Every Roblox service the substrate needs sits behind one of these, so the
-- logic is unit-testable headless against in-memory fakes (Fakes.luau) and runs in Studio against thin
-- adapters (RobloxAdapters.luau). Logic depends on THESE types, never on DataStoreService directly.

local Schema = require("../../types/Schema")

local T = {}

-- A DataStore-shaped key/value store. `updateAsync` is read-modify-write: it calls `transform(current)`
-- synchronously (no yield in the fake; UpdateAsync also runs its transform synchronously in Roblox) and
-- stores the result. Returns (ok, value): ok=false models a throttle/failure (retry territory). The
-- transform may return the unchanged value to signal "no change" (e.g. a rejected lock acquire).
export type DataStoreLike = {
	updateAsync: (key: string, transform: (current: any) -> any) -> (boolean, any),
	getAsync: (key: string) -> (boolean, any),
}

-- Injectable wall-clock (server time, seconds). Fake is settable so lock timeouts / idle elapsed are
-- deterministic; the runtime adapter wraps os.time()/workspace:GetServerTimeNow().
export type Clock = { now: () -> number }

-- Injectable unique-id source. Fake is a deterministic counter ("art-1", "ci-4"); runtime uses
-- HttpService:GenerateGUID (artifactIdScheme = GUID — globally unique, required since artifacts trade
-- across players, so a monotonic-per-player id would collide). TODO(noted): GUID chosen.
export type IdGenerator = { next: (prefix: string) -> string }

-- Append-only audit sink for offloaded (compacted) ledger history (§3). Default destination is a
-- separate DataStore (in-memory fake for tests). TODO(ops): external telemetry sink vs DataStore.
export type AuditSink = {
	append: (playerKey: string, entries: { Schema.LedgerEntry }) -> (),
	read: (playerKey: string) -> { Schema.LedgerEntry },
}

-- Integrity telemetry (build-notes). In-memory fake; runtime adapter forwards to an analytics service.
export type Telemetry = {
	incr: (metric: string, by: number?) -> (),
	snapshot: () -> { [string]: number },
}

-- The value stored at a player's profile key: the profile data + the session lock (the lock lives IN
-- the profile key — the ProfileStore idiom; DataStore-based, MVL). Cross-server MemoryStore brokering is
-- TODO(open), not MVL.
export type LockInfo = { serverId: string, heartbeat: number }
export type StoredProfile = { data: Schema.PlayerData?, lock: LockInfo? }

return T
