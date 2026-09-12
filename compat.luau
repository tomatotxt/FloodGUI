-- Keep game-environment callbacks from changing the caller's thread context.
-- UNC/sUNC functions are optional: a supplied checker is not a passed result.
return function(environment)
	local env = environment or getfenv()
	local function find(names)
		for _, name in ipairs(names) do
			if type(env[name]) == "function" then
				return env[name]
			end
		end
	end
	local getIdentity = find({ "getthreadidentity", "getidentity", "getthreadcontext" })
	local setIdentity = find({ "setthreadidentity", "setidentity", "setthreadcontext" })
	local warned = false
	local function report(message)
		if warned then
			return
		end
		warned = true
		if type(env.warn) == "function" then
			pcall(env.warn, "[FloodGUI] Game alerts unavailable: " .. tostring(message))
		end
	end
	local Compat = {}
	function Compat.gameAlert(callback, ...)
		if type(callback) ~= "function" then
			return false, "Game alert unavailable"
		end
		local args = table.pack(...)
		local scheduled, result = pcall(function()
			return env.task.spawn(function()
				local readable, original = false, nil
				if getIdentity and setIdentity then
					readable, original = pcall(getIdentity)
				end
				local ok, message = pcall(callback, table.unpack(args, 1, args.n))
				-- Restore only the identity this worker already had, never assume an
				-- executor-specific privileged level. The caller runs on another thread.
				if
					readable
					and type(original) == "number"
					and original == original
					and math.abs(original) < math.huge
				then
					local restored, restoreError = pcall(setIdentity, original)
					if not restored then
						report(restoreError)
					end
				end
				if not ok then
					report(message)
				end
			end)
		end)
		if not scheduled then
			report(result)
		end
		return scheduled, result
	end
	return Compat
end
