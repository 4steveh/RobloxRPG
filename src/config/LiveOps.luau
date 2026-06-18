--!strict
-- LIVEOPS EVENT CONFIG (Step 13 — SYS_liveops_calendar §A). The data-driven event calendar + the
-- daily-quest pool, joined into the aggregated `Config` (Catalog) as `config.liveOps`. A new event/season
-- is a CONFIG RECORD here, not code (RD4). The scheduler (src/logic/LiveOps.luau) reads this; the
-- scarcity-discipline guard (Validation.assertEventConfig / validateLiveOps) validates it at require time.
--
-- STUB (Task 1): the field exists so downstream tasks read `config.liveOps`; the real Winter Freeze +
-- Salmon Run records and the daily-quest pool are authored in Task 5.

local Schema = require("@src/types/Schema")

local LiveOps: Schema.LiveOpsConfig = {
	events = {},
	dailyQuestPool = {},
}

return LiveOps
