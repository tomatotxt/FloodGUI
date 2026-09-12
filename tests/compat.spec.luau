local create = require("../compat")

-- A separate coroutine and identity slot per scheduled task are important here:
-- a synchronous task.spawn stub would hide the caller-contamination regression.
local function fixture(getterName, setterName)
	local parent = coroutine.running()
	local state = { identities = { [parent] = 7 }, workers = {}, sets = {}, warnings = {}, parent = parent }
	local env = {
		warn = function(message)
			table.insert(state.warnings, message)
		end,
		task = {},
	}
	function env.task.spawn(callback)
		local worker = coroutine.create(callback)
		state.identities[worker] = state.identities[coroutine.running()]
		table.insert(state.workers, worker)
		local ok, message = coroutine.resume(worker)
		assert(ok, message)
		return worker
	end
	if getterName then
		env[getterName] = function()
			return state.identities[coroutine.running()]
		end
	end
	if setterName then
		env[setterName] = function(value)
			table.insert(state.sets, { thread = coroutine.running(), value = value })
			state.identities[coroutine.running()] = value
		end
	end
	state.env = env
	return state
end

for _, names in ipairs({
	{ "getthreadidentity", "setthreadidentity" },
	{ "getidentity", "setidentity" },
	{ "getthreadcontext", "setthreadcontext" },
}) do
	local state = fixture(names[1], names[2])
	local compat = create(state.env)
	local calls = 0
	local scheduled, worker = compat.gameAlert(function(...)
		calls += 1
		assert(coroutine.running() ~= state.parent, "Game callback must not run in its caller's thread")
		local args = table.pack(...)
		assert(args.n == 4 and args[1] == "message" and args[2] == nil and args[3] == 1.5 and args[4] == nil)
		state.identities[coroutine.running()] = 2
	end, "message", nil, 1.5, nil)
	assert(scheduled and calls == 1 and coroutine.status(worker) == "dead")
	assert(state.identities[state.parent] == 7, "Game callback contaminated the UI caller's identity")
	assert(state.identities[worker] == 7 and #state.sets == 1 and state.sets[1].value == 7)
	assert(state.sets[1].thread == worker and #state.warnings == 0, "Restore only the worker's original level")
end

do
	local state = fixture("getthreadidentity", "setthreadidentity")
	local compat = create(state.env)
	local scheduled, pending = compat.gameAlert(function()
		state.identities[coroutine.running()] = 2
		coroutine.yield("game animation waits for a frame")
		assert(state.identities[coroutine.running()] == 2)
	end)
	assert(scheduled and coroutine.status(pending) == "suspended" and #state.sets == 0)
	assert(state.identities[state.parent] == 7)
	local _, second = compat.gameAlert(function()
		assert(state.identities[coroutine.running()] == 7)
		state.identities[coroutine.running()] = 3
	end)
	assert(state.identities[second] == 7 and state.identities[pending] == 2)
	assert(coroutine.resume(pending))
	assert(coroutine.status(pending) == "dead" and state.identities[pending] == 7)
	assert(#state.sets == 2 and state.identities[state.parent] == 7)
end

do
	local state = fixture("getthreadidentity", "setthreadidentity")
	local compat = create(state.env)
	for _ = 1, 2 do
		local scheduled, worker = compat.gameAlert(function()
			state.identities[coroutine.running()] = 2
			error("game alert internals changed")
		end)
		assert(scheduled and state.identities[worker] == 7 and state.identities[state.parent] == 7)
	end
	assert(#state.warnings == 1 and state.warnings[1]:find("game alert internals changed", 1, true))
	assert(#state.sets == 2, "Callback errors must still restore the worker")
end

for _, names in ipairs({ {}, { "getidentity" }, { false, "setidentity" } }) do
	local state = fixture(names[1], names[2])
	if names[1] then
		state.env[names[1]] = function()
			error("Do not read identity without its setter")
		end
	end
	local compat = create(state.env)
	local scheduled, worker = compat.gameAlert(function()
		state.identities[coroutine.running()] = 2
	end)
	assert(scheduled and state.identities[state.parent] == 7 and state.identities[worker] == 2)
	assert(#state.sets == 0 and #state.warnings == 0, "Isolation must not require executor identity APIs")
end

for _, invalid in ipairs({ "7", false, 0 / 0, math.huge, -math.huge }) do
	local state = fixture("getthreadidentity", "setthreadidentity")
	state.env.getthreadidentity = function()
		return invalid
	end
	local compat = create(state.env)
	assert(compat.gameAlert(function() end))
	assert(#state.sets == 0, "Never restore an unknown or non-finite identity")
end

do
	local state = fixture("getthreadidentity", "setthreadidentity")
	state.env.getthreadidentity = function()
		error("identity access denied")
	end
	local calls = 0
	assert(create(state.env).gameAlert(function()
		calls += 1
	end))
	assert(calls == 1 and #state.sets == 0 and state.identities[state.parent] == 7)
end

do
	local state = fixture("getthreadidentity", "setthreadidentity")
	state.env.setthreadidentity = function()
		error("identity restoration unavailable")
	end
	local compat = create(state.env)
	assert(compat.gameAlert(function()
		state.identities[coroutine.running()] = 2
	end))
	assert(state.identities[state.parent] == 7 and #state.warnings == 1)
	assert(state.warnings[1]:find("identity restoration unavailable", 1, true))
end

do
	local state = fixture("getthreadidentity", "setthreadidentity")
	state.env.getidentity = function()
		error("Do not prefer an alias over the canonical getter")
	end
	state.env.setidentity = function()
		error("Do not prefer an alias over the canonical setter")
	end
	assert(create(state.env).gameAlert(function() end))
	assert(#state.sets == 1 and #state.warnings == 0)
end

do
	local state = fixture()
	local compat = create(state.env)
	assert(not compat.gameAlert(nil))
	assert(not compat.gameAlert("not a callback"))
	assert(#state.workers == 0 and #state.warnings == 0)
	state.env.task.spawn = function()
		error("scheduler unavailable")
	end
	for _ = 1, 2 do
		local scheduled, message = compat.gameAlert(function()
			error("Must not be called synchronously as a fallback")
		end)
		assert(not scheduled and tostring(message):find("scheduler unavailable", 1, true))
	end
	assert(#state.warnings == 1 and #state.workers == 0)
	state.env.warn = function()
		error("console unavailable")
	end
	assert(not create(state.env).gameAlert(function() end), "Even reporting failures must stay contained")
	state.env.task = nil
	assert(not create(state.env).gameAlert(function() end), "Missing task API must fail without calling inline")
end

print("PASS: game-alert worker isolation, nil arguments, yielding, UNC identity aliases and restoration, optional API and callback failure containment")
