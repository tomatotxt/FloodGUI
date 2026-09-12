-- Queue a self-contained baseplate countdown, then return to the same server.
return function(environment, alert, track)
	local env = environment or getfenv()
	local teleport = env.game:GetService("TeleportService")
	local player = env.game:GetService("Players").LocalPlayer
	local baseplate, delay = 95206881, 3.6
	local busy = false
	local function failed(message)
		busy = false
		alert("Rejoin failed: " .. tostring(message), "Error")
	end
	if teleport.TeleportInitFailed then
		local connection = teleport.TeleportInitFailed:Connect(function(who, _, message, place)
			if busy and who == player and place == baseplate then
				failed(message)
			end
		end)
		track(connection)
	end
	return function()
		if busy then
			return
		end
		local queue = type(env.queue_on_teleport) == "function" and env.queue_on_teleport or env.queueonteleport
		if type(queue) ~= "function" then
			alert("Rejoin requires queue_on_teleport or queueonteleport; no teleport was attempted.", "Warning")
			return
		end
		local place, job = env.game.PlaceId, env.game.JobId
		if type(place) ~= "number" or type(job) ~= "string" or job == "" then
			alert("This session has no original server ID to rejoin.", "Warning")
			return
		end
		local source = string.format(
			"local PlaceId, JobId, RejoinDelay, BaseplatePlaceId = %.0f, %q, %.3f, %d\n",
			place,
			job,
			delay,
			baseplate
		) .. [=[
-- Never clear the original game if the executor replays its queue elsewhere.
if game.PlaceId ~= BaseplatePlaceId then return end
local globals = getgenv()
if globals.FloodGUIRejoinExecuted == JobId then return end
globals.FloodGUIRejoinExecuted = JobId
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FloodGUIRejoinOverlay"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = Player:WaitForChild("PlayerGui")
local Background = Instance.new("Frame")
Background.Size = UDim2.fromScale(1, 1)
Background.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Background.BorderSizePixel = 0
Background.Parent = ScreenGui
local function label(y, height)
    local text = Instance.new("TextLabel")
    text.AnchorPoint = Vector2.new(0.5, 0.5)
    text.Position = UDim2.fromScale(0.5, y)
    text.Size = UDim2.new(0.8, 0, 0, height)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.TextScaled = true
    text.Font = Enum.Font.Gotham
    text.Parent = Background
    return text
end
local Title = label(0.44, 60)
Title.Font = Enum.Font.GothamBold
Title.Text = "REJOINING SERVER"
local Timer = label(0.54, 80)
Timer.Text = string.format("%.3f", RejoinDelay)
for _, other in ipairs(Players:GetPlayers()) do
    if other.Character then pcall(function() other.Character:Destroy() end) end
end
local Camera = workspace.CurrentCamera
for _, object in ipairs(workspace:GetChildren()) do
    if object ~= Camera then pcall(function() object:Destroy() end) end
end
if Camera then
    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.CFrame = CFrame.new(0, 100000, 0)
end
local function failure(message)
    Title.Text = "REJOIN FAILED"
    Timer.Text = "The original server may be full or closed."
    warn("[FloodGUI] Return teleport failed: " .. tostring(message))
end
TeleportService.TeleportInitFailed:Connect(function(who, _, message, place)
    if who == Player and place == PlaceId then failure(message) end
end)
local EndTime = os.clock() + RejoinDelay
while os.clock() < EndTime do
    Timer.Text = string.format("%.3f", math.max(0, EndTime - os.clock()))
    RunService.RenderStepped:Wait()
end
Timer.Text = "0.000"
Title.Text = "REJOINING..."
local ok, message = pcall(function()
    TeleportService:TeleportToPlaceInstance(PlaceId, JobId, Player)
end)
if not ok then failure(message) end
]=]
		busy = true
		local ok, message = pcall(function()
			queue(source)
			teleport:Teleport(baseplate, player)
		end)
		if not ok then
			failed(message)
		end
	end
end
