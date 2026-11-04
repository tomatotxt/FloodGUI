-- Native FE2 round lifecycle, in-game stats, goal locators, and server outcome tracking.
-- Sourced from FE2 reverse engineering analysis:
--   - UpdateGameState (CL_MAIN_GameScript line 43650, CL_QuickInfo line 86)
--   - UpdIngameStats (CL_MAIN_GameScript line 44307, FE2_Character line 1363)
--   - UpdGoalLocator (CL_Buttons line 313)
--   - Survived (CL_MAIN_GameScript line 43578, CL_QuickInfo line 114)

local function isBasePart(val)
	if not val then
		return false
	end
	if typeof(val) == "Instance" then
		return val:IsA("BasePart")
	end
	if type(val) == "table" and type(val.IsA) == "function" then
		return val:IsA("BasePart")
	end
	return false
end

local function resolvePart(value, seen, depth)
	if isBasePart(value) then
		return value
	end
	if type(value) ~= "table" or depth > 6 or seen[value] then
		return nil
	end
	seen[value] = true
	for _, child in pairs(value) do
		local found = resolvePart(child, seen, depth + 1)
		if found then
			return found
		end
	end
	return nil
end

return function(remotes, trackConnection)
	local state = nil
	local hasReceivedState = false
	local mapData = nil
	local mapStreak = 0

	local roundStats = nil
	local remainingButtons = nil
	local gamespeedMultiplier = 1

	local currentGoal = nil
	local currentButtonPart = nil
	local nextGoal = nil

	local survivedCallbacks = {}
	local stateCallbacks = {}

	local connections = {}

	local function track(conn)
		if not conn then
			return nil
		end
		table.insert(connections, conn)
		if trackConnection then
			trackConnection(conn)
		end
		return conn
	end

	-- 1. Round lifecycle & game phase
	local updateGameState = remotes:FindFirstChild("UpdateGameState")
	if updateGameState and updateGameState:IsA("RemoteEvent") then
		track(updateGameState.OnClientEvent:Connect(function(newState, newMapData, newMapStreak)
			state = newState
			hasReceivedState = true
			if newMapData then
				mapData = newMapData
			end
			if newMapStreak then
				mapStreak = newMapStreak
			end
			-- Reset per-map round values when leaving in-game
			if state ~= "ingame" then
				roundStats = nil
				remainingButtons = nil
				currentGoal = nil
				currentButtonPart = nil
				nextGoal = nil
			end
			for _, cb in ipairs(stateCallbacks) do
				pcall(cb, state, mapData, mapStreak)
			end
		end))
	end

	-- 2. In-game stats & remaining button counter
	local updIngameStats = remotes:FindFirstChild("UpdIngameStats")
	if updIngameStats and updIngameStats:IsA("RemoteEvent") then
		track(updIngameStats.OnClientEvent:Connect(function(stats)
			if type(stats) == "table" then
				roundStats = stats
				if type(stats.currentButton) == "number" then
					remainingButtons = stats.currentButton
				end
				if type(stats.gamespeedMultiplier) == "number" then
					gamespeedMultiplier = stats.gamespeedMultiplier
				end
			end
		end))
	end

	-- 3. Active goal & button locator
	local updGoalLocator = remotes:FindFirstChild("UpdGoalLocator")
	if updGoalLocator and updGoalLocator:IsA("RemoteEvent") then
		track(updGoalLocator.OnClientEvent:Connect(function(goal, buttonPart, locatorGui, nextGoalPart, nextLocatorGui)
			currentGoal = goal
			currentButtonPart = resolvePart(buttonPart, {}, 0) or buttonPart
			nextGoal = resolvePart(nextGoalPart, {}, 0) or nextGoalPart
		end))
	end

	-- 4. Server-confirmed win / survived outcome
	local survivedRemote = remotes:FindFirstChild("Survived")
	if survivedRemote and survivedRemote:IsA("RemoteEvent") then
		track(survivedRemote.OnClientEvent:Connect(function(survived, escapeTime, runXP)
			for _, cb in ipairs(survivedCallbacks) do
				pcall(cb, survived, escapeTime, runXP)
			end
		end))
	end

	local api = {}

	function api.hasState()
		return hasReceivedState
	end

	function api.getState()
		return state
	end

	function api.isInLift()
		return state == "waiting"
	end

	function api.isInGame()
		return state == "ingame"
	end

	function api.isLoading()
		return state == "loading"
	end

	function api.isLobby()
		return state == nil or (state ~= "waiting" and state ~= "ingame" and state ~= "loading")
	end

	function api.getMapData()
		return mapData
	end

	function api.getRemainingButtons()
		return remainingButtons
	end

	function api.areButtonsComplete()
		return remainingButtons == 0
	end

	function api.getGameSpeedMultiplier()
		return gamespeedMultiplier
	end

	function api.getActiveButton()
		if isBasePart(currentButtonPart) then
			return currentButtonPart
		end
		return nil
	end

	function api.getActiveGoal()
		return currentGoal
	end

	function api.onStateChanged(callback)
		table.insert(stateCallbacks, callback)
		return function()
			local idx = table.find(stateCallbacks, callback)
			if idx then
				table.remove(stateCallbacks, idx)
			end
		end
	end

	function api.onSurvived(callback)
		table.insert(survivedCallbacks, callback)
		return function()
			local idx = table.find(survivedCallbacks, callback)
			if idx then
				table.remove(survivedCallbacks, idx)
			end
		end
	end

	function api.destroy()
		for _, conn in ipairs(connections) do
			if conn and conn.Disconnect then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end
		connections = {}
		table.clear(stateCallbacks)
		table.clear(survivedCallbacks)
	end

	return api
end
