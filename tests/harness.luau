--!strict
-- Tiny assert-based test harness. No Roblox APIs — runs headless under `luau`.
-- Each spec module returns `(t: T) -> ()`; `tests/run.luau` wires them together.

export type T = {
	test: (name: string, fn: () -> ()) -> (),
	ok: (name: string, cond: boolean) -> (),
	eq: (name: string, actual: any, expected: any) -> (),
	errs: (name: string, fn: () -> ()) -> (), -- passes iff fn raises
	section: (name: string) -> (),
	finish: () -> number, -- prints summary, returns process exit code
}

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in pairs(a) do
		if not deepEqual(v, (b :: any)[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if (a :: any)[k] == nil then
			return false
		end
	end
	return true
end

local function show(v: any): string
	if type(v) == "table" then
		local parts: { string } = {}
		for k, val in pairs(v) do
			table.insert(parts, tostring(k) .. "=" .. tostring(val))
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local M = {}

function M.new(label: string): T
	local passed = 0
	local failed = 0

	local function record(name: string, success: boolean, detail: string?)
		if success then
			passed += 1
		else
			failed += 1
			print(string.format("  ✗ %s%s", name, detail and (" — " .. detail) or ""))
		end
	end

	local t = {}

	function t.section(name: string)
		print(string.format("• %s", name))
	end

	function t.test(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		local detail: string? = nil
		if not ok then
			detail = tostring(err)
		end
		record(name, ok, detail)
	end

	function t.ok(name: string, cond: boolean)
		local detail: string? = nil
		if cond ~= true then
			detail = "expected truthy"
		end
		record(name, cond == true, detail)
	end

	function t.eq(name: string, actual: any, expected: any)
		local equal = deepEqual(actual, expected)
		local detail: string? = nil
		if not equal then
			detail = show(actual) .. " ≠ " .. show(expected)
		end
		record(name, equal, detail)
	end

	function t.errs(name: string, fn: () -> ())
		local ok = pcall(fn)
		local detail: string? = nil
		if ok then
			detail = "expected an error but none was raised"
		end
		record(name, not ok, detail)
	end

	function t.finish(): number
		print(string.format("\n[%s] %d passed, %d failed", label, passed, failed))
		return failed > 0 and 1 or 0
	end

	return t
end

return M
