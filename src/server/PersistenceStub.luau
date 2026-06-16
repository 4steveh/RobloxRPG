--!strict
-- PERSISTENCE INTERFACE STUB — names Step 2. Step 1 defines the in-memory authoritative PlayerData
-- shape (Schema.PlayerData) and the freshProfile constructor; it deliberately ships NO durable storage.
--
-- STEP 2 OWNS (do not implement here): DataStore load/save, session-locking (ProfileService-style),
-- the Cash ledger checkpoint + bounded tail + audit-log offload, periodic autosave + write-through
-- critical saves, writing the logout timestamp, idle/AFK accrual, real-money PurchaseId idempotency,
-- and the RemoteEvent/server-authority request boundary. See SYS_data_integrity.

local Schema = require("@src/types/Schema")

type PlayerData = Schema.PlayerData

local M = {}

function M.acquireSessionLock(_userId: number): ()
	error("TODO(step-2): session-locking (single live authoritative session per player, heartbeat-gated steal).")
end

function M.load(_userId: number): PlayerData
	error("TODO(step-2): DataStore load of the session-locked profile (or freshProfile for a new player).")
end

function M.save(_userId: number, _profile: PlayerData): ()
	error("TODO(step-2): whole-profile, all-or-nothing write (UpdateAsync); write-through for critical mutations.")
end

function M.releaseSessionLock(_userId: number): ()
	error("TODO(step-2): flush a final save (writing the logout timestamp) and release the lock cleanly.")
end

return M
