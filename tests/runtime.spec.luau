local createRuntime = require("../runtime")
local runtime = createRuntime("workspace/Flood GUI")
local files = {
	["workspace/Flood GUI/example.luau"] = "return ...",
	["workspace/Flood GUI/tas-catalog.json"] = "[]",
}
local env = setmetatable({
	isfile = function(path)
		return files[path] ~= nil
	end,
	readfile = function(path)
		return assert(files[path], "missing")
	end,
	game = {
		GetService = function(_, name)
			assert(name == "HttpService")
			return {
				JSONDecode = function(_, text)
					assert(text == "[]")
					return {}
				end,
			}
		end,
	},
}, { __index = getfenv() })
for _, method in pairs(runtime) do
	if type(method) == "function" then
		setfenv(method, env)
	end
end
assert(runtime.path("TAS FILES/Blue Moon.json") == "workspace/Flood GUI/TAS FILES/Blue Moon.json")
assert(runtime.read("example.luau") == "return ...")
assert(runtime.run("example.luau", "local changes") == "local changes")
assert(#runtime.catalog() == 0)
assert(not pcall(runtime.read, "missing.luau"))
for _, invalid in ipairs({
	"../escape",
	"/absolute",
	"C:/absolute",
	"a/../../escape",
	"a\\b",
	"./file",
	"",
	"a//b",
	"a/",
	"a /b",
	"a./b",
	"a\0b",
	"a?b",
	"CON",
	"nested/AUX",
	"nested/Lpt1.more",
}) do
	assert(not pcall(runtime.path, invalid), "Accepted invalid path " .. invalid)
	assert(not pcall(createRuntime, invalid), "Accepted invalid root " .. invalid)
end
assert(not pcall(createRuntime, "FloodGUI", "invalid options"))
assert(not pcall(createRuntime, "FloodGUI", { localOnly = "true" }))
local custom = createRuntime("FloodGUI", { baseURL = "https://example.test/raw" })
assert(custom.url("folder/file.luau") == "https://example.test/raw/folder/file.luau")
files["workspace/Flood GUI/example.luau"] = "this is not valid lua"
assert(not pcall(runtime.run, "example.luau"), "Compilation errors must propagate")
print("PASS: local paths, reads, execution, catalog, missing files, traversal rejection, syntax errors")
