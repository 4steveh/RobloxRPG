--!strict
-- NEGATIVE FIXTURE — MUST FAIL `luau-analyze`. The Reward XOR makes "cash + artifact on one target"
-- unrepresentable: the union has NO member carrying both fields, so neither `.cash` nor `.artifact`
-- is accessible on a Reward without first narrowing on `kind` — and narrowing to one kind excludes the
-- other. A function that reads BOTH therefore cannot type-check, proving no value is ever both.
local Schema = require("@src/types/Schema")

local function readsBoth(r: Schema.Reward): (any, any)
	return r.cash, r.artifact -- ← two type errors: neither field exists on the whole union
end

return readsBoth
