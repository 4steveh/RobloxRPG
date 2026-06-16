--!strict
-- Deep copy / in-place restore. Used for transaction snapshots (atomic revert) and read-only
-- replication projections. Profiles are plain data tables (no metatables/functions), so a structural
-- recursive copy is exact.

local Copy = {}

function Copy.deep(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local c: { [any]: any } = {}
	for k, val in pairs(v) do
		c[k] = Copy.deep(val)
	end
	return c
end

-- Restore `source` INTO `target` in place (target keeps its identity so existing references stay valid).
function Copy.restoreInto(target: { [any]: any }, source: { [any]: any })
	for k in pairs(target) do
		target[k] = nil
	end
	for k, val in pairs(source) do
		target[k] = Copy.deep(val)
	end
end

return Copy
