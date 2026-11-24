local Integrity = require("../integrity")

-- Test fnv1a hashing (including official 32-bit FNV-1a test vectors to verify zero float64 precision loss)
assert(Integrity.hash("") == "811c9dc5", "FNV-1a empty string vector mismatch")
assert(Integrity.hash("a") == "e40c292c", "FNV-1a 'a' vector mismatch")
assert(Integrity.hash("foobar") == "bf9cf968", "FNV-1a 'foobar' vector mismatch")
local h1 = Integrity.hash("hello world")
local h2 = Integrity.hash("hello world")
local h3 = Integrity.hash("hello world!")
assert(type(h1) == "string" and #h1 == 8, "Expected 8 hex characters")
assert(h1 == h2, "Hashes must be deterministic")
assert(h1 ~= h3, "Hashes must change when string changes")

-- Test tracking and first-run behavior
local mockFiles = {}
local alerts = {}
local function mockAlert(msg, level)
	table.insert(alerts, { msg = msg, level = level })
end

local mockHttp = {
	JSONDecode = function(_, str)
		-- Simple json parse for testing
		local result = {}
		for k, v in string.gmatch(str, '"([^"]+)":%s*"([^"]+)"') do
			result[k] = v
		end
		return result
	end,
	JSONEncode = function(_, tbl)
		local parts = {}
		for k, v in pairs(tbl) do
			table.insert(parts, string.format('"%s": "%s"', k, tostring(v)))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end,
}

local mockRuntime = {
	root = "FloodGUI",
	read = function(rel)
		return "content of " .. rel
	end,
}

local env = setmetatable({
	isfile = function(p)
		return mockFiles[p] ~= nil
	end,
	readfile = function(p)
		return assert(mockFiles[p], "file not found: " .. tostring(p))
	end,
	writefile = function(p, content)
		mockFiles[p] = content
	end,
}, { __index = getfenv() })

setfenv(Integrity.check, env)

-- First run: should save hashes
local ok1, res1 = Integrity.check(mockRuntime, mockHttp, mockAlert)
assert(ok1 and res1.isFirstRun == true)
assert(#res1.updated == 0)
assert(mockFiles["FloodGUI/module-hashes.json"] ~= nil)
assert(#alerts == 1 and alerts[1].msg:find("Module hashes saved"))

-- Second run: no changes
alerts = {}
local ok2, res2 = Integrity.check(mockRuntime, mockHttp, mockAlert)
assert(ok2 and res2.isFirstRun == false)
assert(#res2.updated == 0)
assert(#alerts == 0)

-- Third run: a module content changes
mockRuntime.read = function(rel)
	if rel == "advanced.luau" then
		return "MODIFIED content of advanced.luau"
	end
	return "content of " .. rel
end

alerts = {}
local ok3, res3 = Integrity.check(mockRuntime, mockHttp, mockAlert)
assert(ok3 and res3.isFirstRun == false)
assert(#res3.updated == 1)
assert(res3.updated[1].name == "advanced")
assert(#alerts == 1)
assert(alerts[1].msg == "advanced Updated!" and alerts[1].level == "Warning")

-- Fourth run: transient read failure must preserve previous hash (no spurious New Module on recovery)
mockRuntime.read = function(rel)
	if rel == "rejoin.luau" then
		error("transient network timeout")
	end
	if rel == "advanced.luau" then
		return "MODIFIED content of advanced.luau"
	end
	return "content of " .. rel
end
alerts = {}
local ok4, res4 = Integrity.check(mockRuntime, mockHttp, mockAlert)
assert(ok4 and #res4.updated == 0 and #res4.new == 0 and #alerts == 0)

mockRuntime.read = function(rel)
	if rel == "advanced.luau" then
		return "MODIFIED content of advanced.luau"
	end
	return "content of " .. rel
end
alerts = {}
local ok5, res5 = Integrity.check(mockRuntime, mockHttp, mockAlert)
assert(ok5 and #res5.updated == 0 and #res5.new == 0 and #alerts == 0, "Recovered module must not be misreported as New Module")

print("PASS: module integrity hashing, first-run workspace saving, and update alerts")
