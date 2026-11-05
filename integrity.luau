-- Module Integrity and Update Checker for FloodGUI
-- Checks local/remote module checksums against a persistent workspace hash file.
-- Alerts when any module or script has been updated.

local Integrity = {}

-- FNV-1a 32-bit hash function (fast, deterministic, zero-dependency)
local function fnv1a(str: string): string
	local hash = 2166136261
	for i = 1, #str do
		local b = string.byte(str, i)
		hash = bit32.bxor(hash, b)
		hash = bit32.band(hash * 16777619, 0xFFFFFFFF)
	end
	return string.format("%08x", hash)
end

Integrity.hash = fnv1a

-- List of core project scripts and modules to track
Integrity.TRACKED_MODULES = {
	"FloodGUI.luau",
	"advanced.luau",
	"automation.luau",
	"challenge-rules.luau",
	"compat.luau",
	"feature-guard.luau",
	"gamestate.luau",
	"launches.luau",
	"loader.lua",
	"minigui.luau",
	"overrides.luau",
	"preferences.luau",
	"reach.luau",
	"rejoin.luau",
	"runtime.luau",
	"swimming.luau",
	"tashelper.luau",
	"zipline.luau",
	"TAS/codec.luau",
	"TAS/recordings.luau",
	"TAS/CREATOR/creator.luau",
	"TAS/CREATOR/environment.luau",
	"TAS/CREATOR/recording-buffer.luau",
	"TAS/CREATOR/timelines.luau",
	"TAS/CREATOR/touch-controls.luau",
	"TAS/PLAYER/newtasplayer.luau",
	"TAS/PLAYER/timeline.luau",
	"ui/creator.luau",
	"ui/kavo.luau",
	"ui/main.luau",
	"ui/player.luau",
	"ui/recordings.luau",
	"ui/service.luau",
	"vendor/airflow.luau",
	"vendor/input.luau",
	"vendor/kavo.luau",
}

-- Checks tracked modules against the persistent hash store in workspace.
-- On first run: creates the hash store.
-- On subsequent runs: compares hashes, alerts for any updated modules, and updates the file.
function Integrity.check(runtime, httpService, alertFn)
	local isfile = getfenv().isfile
	local readfile = getfenv().readfile
	local writefile = getfenv().writefile

	if type(isfile) ~= "function" or type(writefile) ~= "function" or type(readfile) ~= "function" then
		return false, "File IO unavailable"
	end

	local hashFilePath = runtime.root .. "/module-hashes.json"
	local previousHashes = {}
	local isFirstRun = true

	if isfile(hashFilePath) then
		local ok, content = pcall(readfile, hashFilePath)
		if ok and type(content) == "string" and content ~= "" then
			local decodeOk, decoded = pcall(function()
				return httpService:JSONDecode(content)
			end)
			if decodeOk and type(decoded) == "table" then
				previousHashes = decoded
				isFirstRun = false
			end
		end
	end

	local currentHashes = {}
	local updatedModules = {}
	local newModules = {}

	for _, modulePath in ipairs(Integrity.TRACKED_MODULES) do
		local ok, source = pcall(function()
			return runtime.read(modulePath)
		end)
		if ok and type(source) == "string" then
			local h = fnv1a(source)
			currentHashes[modulePath] = h

			if not isFirstRun then
				local prev = previousHashes[modulePath]
				if prev ~= nil and prev ~= h then
					local moduleName = modulePath:match("([^/]+)%.luau?$") or modulePath
					table.insert(updatedModules, { path = modulePath, name = moduleName })
				elseif prev == nil then
					local moduleName = modulePath:match("([^/]+)%.luau?$") or modulePath
					table.insert(newModules, { path = modulePath, name = moduleName })
				end
			end
		end
	end

	-- Save current hashes back to workspace
	pcall(function()
		local encoded = httpService:JSONEncode(currentHashes)
		writefile(hashFilePath, encoded)
	end)

	if isFirstRun then
		if alertFn then
			alertFn("Module hashes saved (" .. tostring(#Integrity.TRACKED_MODULES) .. " modules tracked)", "Info")
		end
	else
		if #updatedModules > 0 then
			for _, item in ipairs(updatedModules) do
				if alertFn then
					alertFn(item.name .. " Updated!", "Warning")
				end
			end
		end
		if #newModules > 0 then
			for _, item in ipairs(newModules) do
				if alertFn then
					alertFn("New Module: " .. item.name, "Info")
				end
			end
		end
	end

	return true, {
		isFirstRun = isFirstRun,
		updated = updatedModules,
		new = newModules,
		hashes = currentHashes,
	}
end

return Integrity
