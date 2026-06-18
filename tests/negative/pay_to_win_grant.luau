--!strict
-- NEGATIVE FIXTURE — MUST FAIL `luau-analyze`. The pay-proof keystone (SYS_economy §7 / 00 §4): a
-- real-money grant that buys a conquest/milestone/tier is UNREPRESENTABLE. `ProductGrant` is a CLOSED
-- tagged union { cash | item | cosmetic | multiplier } with NO conquest/tier/effective-tier variant — so a
-- "skip the grind to unlock" / "buy the milestone" product cannot even be WRITTEN, the same type-level
-- guarantee the Reward XOR and the cosmetic no-stats field give. A mis-tagged config can't sneak past it.
local Schema = require("@src/types/Schema")

-- ← type error: { kind = "conquest", … } is not a member of the ProductGrant union (no such grant kind),
-- and `destinationId` is a field of no variant. There is no way to construct a grant that writes conquest.
local bad: Schema.ProductGrant = { kind = "conquest", destinationId = "alaska" }

return bad
