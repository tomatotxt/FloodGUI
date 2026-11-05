local Integrity = require("../integrity")

-- Test fnv1a hashing
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

print("PASS: module integrity hashing, first-run workspace saving, and update alerts")
