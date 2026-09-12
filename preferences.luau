-- Persist preferences only, never active automation, spending, or movement toggles.
return function(runtime, http, filesystem)
	local io = filesystem or getfenv()
	local path = runtime.path("preferences.json")
	local rules = {
		InterfaceScale = { 1, 0.8, 1.25 },
		Notifications = { true },
		AlertsEnabled = { true },
		PlaybackSpeed = { 1, 0.25, 3 },
		SwimSmoothness = { 0.04, 0.01, 0.1 },
		StartDelay = { 0, 0, 30 },
		ResetDelay = { 0, 0, 15 },
		RebirthInterval = { 60, 60, 600 },
		ChallengeInterval = { 600, 60, 1800 },
	}
	local function valid(value, rule)
		if type(rule[1]) == "boolean" then
			return type(value) == "boolean"
		end
		return type(value) == "number" and value == value and value >= rule[2] and value <= rule[3]
	end
	local preferences = {}
	local writeBlocked = false
	function preferences.accepts(key)
		return rules[key] ~= nil
	end
	function preferences.reset(state)
		writeBlocked = false
		for key, rule in pairs(rules) do
			state[key] = rule[1]
		end
	end
	function preferences.load(state)
		return pcall(function()
			if type(io.isfile) ~= "function" or not io.isfile(path) then
				return
			end
			assert(type(io.readfile) == "function", "Reading preferences is unavailable")
			local data = http:JSONDecode(io.readfile(path))
			if type(data) == "table" and data.version ~= 1 then
				writeBlocked = true
			end
			assert(
				type(data) == "table" and data.version == 1 and type(data.values) == "table",
				"Unrecognized preferences file"
			)
			for key, rule in pairs(rules) do
				local value = data.values[key]
				if valid(value, rule) then
					state[key] = value
				end
			end
		end)
	end
	function preferences.save(state)
		return pcall(function()
			assert(
				not writeBlocked,
				"Unrecognized preferences version; restore preference defaults before replacing it"
			)
			assert(type(io.writefile) == "function", "Saving preferences is unavailable")
			local values = {}
			for key, rule in pairs(rules) do
				if valid(state[key], rule) then
					values[key] = state[key]
				end
			end
			io.writefile(path, http:JSONEncode({ version = 1, values = values }))
		end)
	end
	return preferences
end
