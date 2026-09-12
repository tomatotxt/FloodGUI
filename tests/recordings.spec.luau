local factory = require("../TAS/recordings")
local Codec = require("../TAS/codec")
local frame = require("./recording-fixtures")[1]
local files, network = {}, {}
local catalog = { { name = "Test Map.json", path = "TAS FILES/Test Map.json" } }
local bytes = Codec.encodeBinary({ frame }, { mapName = "Test Map" })
local adapter = table.clone(Codec)
function adapter.decode(data)
	if data == "legacy-json" then
		return { frame }, { format = "json", fps = 60 }
	end
	return Codec.decodeBinary(data)
end
function adapter.encodeJSON(frames)
	Codec.validate(frames)
	return "legacy-json"
end
local runtime = {
	root = "FloodGUI",
	localOnly = false,
	path = function(p)
		return "FloodGUI/" .. p
	end,
	run = function()
		return adapter
	end,
	catalog = function()
		return catalog
	end,
}
function runtime.read(p)
	return assert(files[runtime.path(p)] or network[p], "missing " .. p)
end
function runtime.readRemote(p)
	return assert(network[p], "missing remote " .. p)
end
local onWrite
local env = setmetatable({
	isfile = function(p)
		return files[p] ~= nil
	end,
	isfolder = function()
		return true
	end,
	makefolder = function() end,
	readfile = function(p)
		return assert(files[p], "missing local " .. p)
	end,
	writefile = function(p, v)
		if onWrite then
			onWrite(p, v)
		else
			files[p] = v
		end
	end,
	listfiles = function()
		local result = {}
		for p in pairs(files) do
			table.insert(result, p)
		end
		return result
	end,
}, { __index = getfenv() })
setfenv(factory, env)
local api = factory(runtime)
network["TAS FILES/Test Map.json"] = "legacy-json"
assert(api.hasMap("Test Map"))
local frames, meta = api.loadMap("Test Map")
assert(#frames == 1 and meta.format == "json")
local first = api.save("Test Map", { frame }, { mapName = "Test Map", author = "Tester" })
local second = api.save("Test Map", { frame }, { mapName = "Test Map", author = "Revision 2" })
assert(first ~= second and files[runtime.path(first)] ~= nil)
frames, meta = api.loadMap("Test Map")
assert(meta.author == "Revision 2")
files[runtime.path(second)] = "FE2Tbad"
frames, meta = api.loadMap("Test Map")
assert(meta.author == "Tester")
files[runtime.path(first)] = "bad"
frames, meta = api.loadMap("Test Map")
assert(meta.format == "json")
files["FloodGUI/TAS FILES/Test Map.json"] = "damaged local JSON"
frames, meta = api.loadMap("Test Map")
assert(meta.format == "json")
assert(files["FloodGUI/TAS FILES/Test Map.json"] == "damaged local JSON", "Remote fallback changed local data")

-- Removing the original must not hide valid revisions or make the next save stale.
files[runtime.path(first)] = nil
files[runtime.path(second)] = bytes
catalog = {}
assert(api.hasMap("Test Map"), "Revision-only recordings must remain discoverable")
local third = api.save("Test Map", { frame }, { author = "Newest" })
assert(third == "TAS FILES/Test Map (3).fe2tomatas")
frames, meta = api.loadMap("Test Map")
assert(meta.author == "Newest")
assert(meta.mapName == "Test Map", "Partial metadata must still include the recording's map name")

-- A partial/failed write must be reported and never replace earlier valid runs.
onWrite = function(p, v)
	files[p] = v:sub(1, -2)
end
assert(not pcall(api.save, "Test Map", { frame }, { author = "Truncated" }))
onWrite = nil
frames, meta = api.loadMap("Test Map")
assert(meta.author == "Newest")
assert(api.save("Test Map", { frame }, { author = "Retried" }) == "TAS FILES/Test Map (5).fe2tomatas")

-- Two save requests can overlap when an executor's file API yields.
local suspended = false
onWrite = function(p, v)
	if not suspended then
		suspended = true
		coroutine.yield()
	end
	files[p] = v
end
local firstConcurrent
local writer = coroutine.create(function()
	firstConcurrent = api.save("Concurrent", { frame })
end)
assert(coroutine.resume(writer))
assert(coroutine.status(writer) == "suspended")
local secondConcurrent = api.save("Concurrent", { frame })
assert(secondConcurrent == "TAS FILES/Concurrent (2).fe2tomatas")
assert(coroutine.resume(writer) and coroutine.status(writer) == "dead")
assert(
	firstConcurrent ~= secondConcurrent
		and files[runtime.path(firstConcurrent)] == files[runtime.path(secondConcurrent)]
)
onWrite = nil

-- Export verification leaves the source unchanged and handles missing folders.
env.isfolder = function()
	return false
end
local created = false
env.makefolder = function()
	created = true
end
local exported = api.convertFile("Concurrent.fe2tomatas", "json")
assert(created and files[runtime.path(exported)] == "legacy-json")
assert(not pcall(api.convertFile, "Concurrent.fe2tomatas", "json"), "Existing exports must not be overwritten")
local preservedSource = files[runtime.path(secondConcurrent)]
onWrite = function(p, v)
	files[p] = "partial"
end
assert(not pcall(api.convertFile, "Concurrent (2).fe2tomatas", "json"))
onWrite = nil
assert(files[runtime.path(secondConcurrent)] == preservedSource, "Failed export changed the binary source")

-- A catalog listing is not a usable offline recording without its local bytes.
catalog = { { name = "Missing.json" }, "malformed catalog entry" }
runtime.localOnly = true
assert(not api.hasMap("Missing"))
runtime.localOnly = false
assert(api.hasMap("Missing"))

for _, name in ipairs({ "../escape", "CON", "aux.json", "LPT1", "NUL.notes", "Trailing.", "bad\0name" }) do
	assert(not pcall(api.save, name, { frame }), "Unsafe name accepted: " .. name)
end
assert(api.save(" Upper.JSON ", { frame }) == "TAS FILES/Upper.fe2tomatas")
assert(api.save(".Hidden", { frame }) == "TAS FILES/.Hidden.fe2tomatas")
assert(not pcall(api.loadFile, nil))
print(
	"PASS: remote fallback without local overwrite, revision gaps/discovery, verified writes, concurrent saves, safe JSON export and filenames"
)
