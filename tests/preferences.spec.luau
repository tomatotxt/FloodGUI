local create = require("../preferences")
local payload, saved
local http = {
	JSONDecode = function()
		return payload
	end,
	JSONEncode = function(_, data)
		saved = data
		return "encoded"
	end,
}
local files = {
	isfile = function()
		return true
	end,
	readfile = function()
		return "preferences"
	end,
	writefile = function(path, bytes)
		assert(path == "FloodGUI/preferences.json" and bytes == "encoded")
	end,
}
local preferences = create({
	path = function(p)
		return "FloodGUI/" .. p
	end,
}, http, files)
local state = { AutoFarm = false, GodMode = false, InterfaceScale = 1, Notifications = true, PlaybackSpeed = 1 }
payload = {
	version = 1,
	values = { AutoFarm = true, GodMode = true, InterfaceScale = 1.2, Notifications = false, PlaybackSpeed = 100, Unknown = "ignored" },
}
assert(preferences.load(state))
assert(state.InterfaceScale == 1.2 and state.Notifications == false and state.PlaybackSpeed == 1)
assert(not state.AutoFarm and not state.GodMode and not state.Unknown)
assert(preferences.save(state))
assert(saved.version == 1 and saved.values.InterfaceScale == 1.2 and saved.values.Notifications == false)
assert(saved.values.AutoFarm == nil and saved.values.GodMode == nil)
payload = { version = 100, values = { InterfaceScale = 0.8 } }
assert(not preferences.load(state))
assert(state.InterfaceScale == 1.2)
assert(not preferences.save(state), "Future settings must not be overwritten implicitly")
payload = { version = 1, values = { InterfaceScale = 0 / 0, Notifications = "yes" } }
assert(preferences.load(state))
assert(state.InterfaceScale == 1.2 and state.Notifications == false)
state.AutoFarm = true
preferences.reset(state)
assert(state.AutoFarm and state.InterfaceScale == 1 and state.Notifications)
files.writefile = function()
	error("disk full")
end
assert(not preferences.save(state))
assert(not preferences.accepts("AutoFarm") and preferences.accepts("InterfaceScale"))
print(
	"PASS: safe preference allowlist, type/range validation, future schema protection, reset and I/O failure isolation"
)
