local create = require("../rejoin")
local source, hops, failure, alert = nil, 0, nil, nil
local player = {}
local teleport = {
	TeleportInitFailed = {
		Connect = function(_, fn)
			failure = fn
			return {}
		end,
	},
	Teleport = function(_, place, who)
		assert(place == 95206881 and who == player)
		hops += 1
	end,
}
local env = {
	game = {
		PlaceId = 123456,
		JobId = 'server-"quoted"',
		GetService = function(_, name)
			return name == "Players" and { LocalPlayer = player } or teleport
		end,
	},
}
local function instance()
	return create(env, function(message)
		alert = message
	end, function() end)
end
instance()()
assert(hops == 0 and alert:find("queue_on_teleport", 1, true))
env.queueonteleport = function(text)
	source = text
end
local rejoin = instance()
rejoin()
rejoin()
assert(hops == 1 and source)
failure(player, nil, "failed", 95206881)
rejoin()
assert(hops == 2)
env.queue_on_teleport = function()
	error("queue failure")
end
instance()()
assert(hops == 2 and alert:find("queue failure", 1, true))
local chunk = assert(loadstring(source))
-- A retained queue must not destroy anything in the original place.
setfenv(chunk, { game = { PlaceId = 123456 } })
chunk()
local clock, cleared, returns = 0, 0, 0
local globals, objects = {}, {}
local camera = {}
local function destroy()
	cleared += 1
end
local destinationPlayer = {
	Character = { Destroy = destroy },
	WaitForChild = function()
		return {}
	end,
}
local destinationTeleport = {
	TeleportInitFailed = { Connect = function() end },
	TeleportToPlaceInstance = function(_, place, job, who)
		assert(place == 123456 and job == 'server-"quoted"' and who == destinationPlayer)
		assert(clock >= 3.6)
		returns += 1
	end,
}
local function values(...)
	return { ... }
end
local destination = setmetatable({
	game = {
		PlaceId = 95206881,
		GetService = function(_, name)
			if name == "Players" then
				return {
					LocalPlayer = destinationPlayer,
					GetPlayers = function()
						return { destinationPlayer }
					end,
				}
			end
			if name == "TeleportService" then
				return destinationTeleport
			end
			return { RenderStepped = {
				Wait = function()
					clock += 0.1
				end,
			} }
		end,
	},
	getgenv = function()
		return globals
	end,
	workspace = {
		CurrentCamera = camera,
		GetChildren = function()
			return { camera, { Destroy = destroy } }
		end,
	},
	Instance = {
		new = function(class)
			local object = { ClassName = class }
			table.insert(objects, object)
			return object
		end,
	},
	UDim2 = { fromScale = values, new = values },
	Vector2 = { new = values },
	Color3 = { fromRGB = values },
	CFrame = { new = values },
	Enum = { Font = { Gotham = "Gotham", GothamBold = "GothamBold" }, CameraType = { Scriptable = "Scriptable" } },
	os = {
		clock = function()
			return clock
		end,
	},
}, { __index = getfenv() })
setfenv(chunk, destination)
chunk()
assert(cleared == 2 and returns == 1 and camera.CameraType == "Scriptable")
chunk()
assert(cleared == 2 and returns == 1, "Duplicate queue execution must be ignored")
assert(objects[#objects].Text == "0.000")
print(
	"PASS: queued same-server rejoin, aliases, missing/failed queue, 3.6-second countdown, baseplate-only clearing and duplicate protection"
)
