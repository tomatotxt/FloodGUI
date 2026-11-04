local createGameState = require("../gamestate")

local function mockSignal()
	local listeners = {}
	return {
		Connect = function(_, cb)
			table.insert(listeners, cb)
			return {
				Disconnect = function()
					local idx = table.find(listeners, cb)
					if idx then
						table.remove(listeners, idx)
					end
				end,
			}
		end,
		fire = function(_, ...)
			for _, cb in ipairs(listeners) do
				cb(...)
			end
		end,
		listenerCount = function()
			return #listeners
		end,
	}
end

local function mockRemote(class)
	local sig = mockSignal()
	return {
		IsA = function(_, c)
			return c == class
		end,
		OnClientEvent = sig,
		fire = function(_, ...)
			sig:fire(...)
		end,
		listenerCount = function()
			return sig:listenerCount()
		end,
	}
end

local remotes = {
	children = {},
	FindFirstChild = function(self, name)
		return self.children[name]
	end,
}

remotes.children["UpdateGameState"] = mockRemote("RemoteEvent")
remotes.children["UpdIngameStats"] = mockRemote("RemoteEvent")
remotes.children["UpdGoalLocator"] = mockRemote("RemoteEvent")
remotes.children["Survived"] = mockRemote("RemoteEvent")

local tracked = {}
local function track(conn)
	table.insert(tracked, conn)
	return conn
end

local gs = createGameState(remotes, track)

-- Initial state before any events
assert(not gs.hasState(), "Should not have state initially")
assert(gs.getState() == nil, "Initial state should be nil")
assert(gs.isLobby(), "Initial phase should be considered lobby")
assert(not gs.isInLift(), "Initial state is not in lift")
assert(not gs.isInGame(), "Initial state is not in game")
assert(gs.getRemainingButtons() == nil, "Remaining buttons should be nil initially")
assert(not gs.areButtonsComplete(), "Buttons complete should be false initially")
assert(gs.getGameSpeedMultiplier() == 1, "Default gamespeed multiplier should be 1")
assert(gs.getActiveButton() == nil, "Active button should be nil initially")

-- UpdateGameState transition to waiting (lift)
local stateEvents = {}
gs.onStateChanged(function(st, data, streak)
	table.insert(stateEvents, { state = st, data = data, streak = streak })
end)

remotes.children["UpdateGameState"]:fire("waiting", { Name = "Active Volcanic Mines", Difficulty = 3 }, 5)
assert(gs.hasState(), "Should have received state")
assert(gs.getState() == "waiting")
assert(gs.isInLift())
assert(not gs.isInGame())
assert(not gs.isLobby())
assert(#stateEvents == 1)
assert(stateEvents[1].state == "waiting")
assert(stateEvents[1].data.Name == "Active Volcanic Mines")
assert(stateEvents[1].streak == 5)

-- Transition to loading
remotes.children["UpdateGameState"]:fire("loading", nil, nil)
assert(gs.getState() == "loading")
assert(gs.isLoading())
assert(not gs.isInLift())
assert(not gs.isInGame())

-- Transition to ingame
remotes.children["UpdateGameState"]:fire("ingame", nil, nil)
assert(gs.getState() == "ingame")
assert(gs.isInGame())
assert(not gs.isInLift())
assert(not gs.isLoading())

-- UpdIngameStats event
remotes.children["UpdIngameStats"]:fire({
	gameStatus = "ingame",
	currentButton = 4,
	gamespeedMultiplier = 1.25,
})
assert(gs.getRemainingButtons() == 4)
assert(not gs.areButtonsComplete())
assert(gs.getGameSpeedMultiplier() == 1.25)

remotes.children["UpdIngameStats"]:fire({
	gameStatus = "ingame",
	currentButton = 0,
	gamespeedMultiplier = 1.5,
})
assert(gs.getRemainingButtons() == 0)
assert(gs.areButtonsComplete())
assert(gs.getGameSpeedMultiplier() == 1.5)

-- UpdGoalLocator with direct BasePart
local mockPart = {
	IsA = function(_, class)
		return class == "BasePart"
	end,
	Name = "ButtonPart",
}
remotes.children["UpdGoalLocator"]:fire("GoalExit", mockPart, nil, nil, nil)
assert(gs.getActiveButton() == mockPart)
assert(gs.getActiveGoal() == "GoalExit")

-- UpdGoalLocator with nested table resolution
local nestedTarget = {
	IsA = function(_, class)
		return class == "BasePart"
	end,
	Name = "NestedButton",
}
local complexStructure = {
	model = {
		parts = { nestedTarget },
	},
}
remotes.children["UpdGoalLocator"]:fire("Goal2", complexStructure, nil, nil, nil)
assert(gs.getActiveButton() == nestedTarget)

-- Survived event
local survivedCalls = {}
gs.onSurvived(function(survived, escapeTime, runXP)
	table.insert(survivedCalls, { survived = survived, escapeTime = escapeTime, runXP = runXP })
end)

remotes.children["Survived"]:fire(true, 73.45, 1200)
assert(#survivedCalls == 1)
assert(survivedCalls[1].survived == true)
assert(math.abs(survivedCalls[1].escapeTime - 73.45) < 0.001)
assert(survivedCalls[1].runXP == 1200)

-- Returning to lobby resets in-game state
remotes.children["UpdateGameState"]:fire(nil, nil, nil)
assert(gs.getState() == nil)
assert(gs.isLobby())
assert(not gs.isInGame())
assert(gs.getRemainingButtons() == nil)
assert(gs.getActiveButton() == nil)

-- Empty / nil remotes folder gracefully handled
local emptyRemotes = {
	FindFirstChild = function()
		return nil
	end,
}
local gsEmpty = createGameState(emptyRemotes)
assert(not gsEmpty.hasState())
assert(gsEmpty.getState() == nil)
assert(gsEmpty.isLobby())
assert(not gsEmpty.isInLift())
assert(not gsEmpty.isInGame())
assert(gsEmpty.getRemainingButtons() == nil)
assert(gsEmpty.getActiveButton() == nil)
gsEmpty.destroy()

-- Cleanup
gs.destroy()
assert(remotes.children["UpdateGameState"]:listenerCount() == 0)
assert(remotes.children["UpdIngameStats"]:listenerCount() == 0)
assert(remotes.children["UpdGoalLocator"]:listenerCount() == 0)
assert(remotes.children["Survived"]:listenerCount() == 0)

print("PASS: FE2 native round lifecycle, remaining buttons, goal locator, and server outcome confirmation")
