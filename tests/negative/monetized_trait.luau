--!strict
-- NEGATIVE FIXTURE — MUST FAIL `luau-analyze`. The weather-trait pay/power proof (SYS_liveops_weather_traits
-- §9.7): a weather TRAIT can never be sold or made a power input. `ProductGrant` is a CLOSED union
-- { cash | item | cosmetic | multiplier } with NO trait variant, so "buy a Storm-Touched bonus" is
-- UNREPRESENTABLE — a trait flows ONLY through KillEvent (server-rolled at kill/catch) and the RewardPipeline
-- Cash branch, never a purchase and never a tier/conquest input. A mis-tagged config cannot write it.
local Schema = require("@src/types/Schema")

-- ← type error: { kind = "trait", … } is not a member of the ProductGrant union (no such grant kind), and
-- `trait` is a field of no variant. There is no way to construct a product that grants a weather trait.
local bad: Schema.ProductGrant = { kind = "trait", trait = "stormTouched" }

return bad
