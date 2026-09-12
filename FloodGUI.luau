local Runtime = assert(getgenv().FloodGUIRuntime, "Start FloodGUI through loader.lua")
local Automation = Runtime.run("automation.luau")
local Compat = Runtime.run("compat.luau")()
local Overrides = Runtime.run("overrides.luau")()
local Recordings = Runtime.run("TAS/recordings.luau")(Runtime)
getgenv().FloodGUIRecordings = Recordings
-- ==============================================================================
-- FloodGUI
-- Description: Exploit GUI for Flood Escape 2 providing various cheats and utilities.
-- Credits:
--      TAS System: Tomato (Base by Voiz#5668)
--      Reverse Engineering/Base GUI: Tomato
--      UI Library: Airflow
-- ==============================================================================

-- ==============================================================================
-- [1] INSTANCE CLEARING & SETUP
-- ==============================================================================
if getgenv().FloodGUISession then
    getgenv().FloodGUISession.Cancelled = true
    if getgenv().FloodGUISession.Cleanup then pcall(getgenv().FloodGUISession.Cleanup) end
end
local Session = {Cancelled = false}
getgenv().FloodGUISession = Session
if getgenv().FloodGUI_Connections or getgenv().TomatoConnections then
    print("[FloodGUI]: Overriding previous instance...")
    for _, connection in pairs(getgenv().FloodGUI_Connections or {}) do
        if connection then pcall(function() connection:Disconnect() end) end
    end
    for _, connection in pairs(getgenv().TomatoConnections or {}) do
        if connection then pcall(function() connection:Disconnect() end) end
    end
    _G.LoopCancel = true
    getgenv().TomatoAutoFarm = false
    getgenv().IsTASPlaying = false
    task.wait(0.2)
end

getgenv().FloodGUI_Connections = {}
getgenv().TomatoConnections = getgenv().FloodGUI_Connections -- Aliased for clean environment overrides
getgenv().TasFileCache = {}
getgenv().TomatoAutoFarm = false
getgenv().IsTASPlaying = false

local function TrackConnection(connection)
    table.insert(getgenv().FloodGUI_Connections, connection)
    return connection
end

-- ==============================================================================
-- [2] SERVICES & CONSTANTS
-- ==============================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Multiplayer = Workspace:WaitForChild("Multiplayer")

-- Remotes
local RemoteFolder = ReplicatedStorage:WaitForChild("Remote")
local ReqPasskey = RemoteFolder:WaitForChild("ReqPasskey")
local ReqRebirth = RemoteFolder:WaitForChild("ReqRebirth")
local NewMapVote = RemoteFolder:WaitForChild("NewMapVote")
local UpdMapVote = RemoteFolder:WaitForChild("UpdMapVote")
local AddedWaiting = RemoteFolder:WaitForChild("AddedWaiting")
local AlertRemote = RemoteFolder:WaitForChild("Alert")

local CONFIG = {
    UI_LIBRARY_PATH = "vendor/airflow.luau",
    TAS_CREATOR_PATH = "TAS/CREATOR/creator.luau",
    TAS_PLAYER_PATH = "TAS/PLAYER/newtasplayer.luau",
    DISCORD_INVITE = "https://discord.gg/8N2M9fHJqa"
}

local DIFFICULTY_RANKS = {
    ["None"] = 999, ["Easy"] = 1, ["Normal"] = 2, ["Hard"] = 3, ["Insane"] = 4, ["Crazy"] = 5, ["Crazy+"] = 6
}

local COLORS = {
    System  = Color3.fromRGB(200, 200, 200),
    Success = Color3.fromRGB(0, 255, 127),
    Warning = Color3.fromRGB(255, 170, 0),
    Error   = Color3.fromRGB(255, 60, 60),
    Info    = Color3.fromRGB(0, 220, 255),
    Item    = Color3.fromRGB(170, 85, 255)
}



-- ==============================================================================
-- [3] STATE MANAGEMENT
-- ==============================================================================
_G.LoopCancel = false

local State = {
    AutoJoinLift = true,
    AntiAFK = true,
    RebirthInterval = 60,
    ChallengeInterval = 600,
    MovementOverrides = true,
    InterfaceScale = 1,
    Notifications = true,
    PlaybackSpeed = 1,
    SwimSmoothness = 0.04,
    StartDelay = 0,
    ResetDelay = 0,
    ResetAfterEscape = false,
    PlayAfterButtons = false,
    PreferMissingTAS = false,
    SelectTASMaps = false,
    ResettingCharacter = false,
    EscapeSerial = 0,
    AlertsEnabled = true,
    HighlightOnlyMaps = {},
    AutoPlay = false,
    FallbackToFarm = false,
    AutoFarm = false,
    AutoCollect = false,
    AutoRebirth = false,
    AutoLeave = false,
    UIEnabled = true,

    Mode = "Farm",
    TargetDifficulty = "Normal",
    TargetMapName = "",
    EnforceDifficulty = false,
    CurrentlyFarming = false,
    Escaped = false,
    ResettingForDifficulty = false,

    -- Char Mods
    WalkSpeed = 20,
    JumpPower = 50,
    GodMode = false,
    Noclip = false,
    AirJump = false,
    SwimEnabled = false
}

-- Preserve the player/GUI compatibility contract used by the older branches.
getgenv().State = function() return State end
pcall(function()
    local library = require(ReplicatedStorage:FindFirstChild("FE2Library", true))
    local official = {}
    for _, map in pairs(library.getOfficialMapData()) do official[map.mapName] = true end
    local gui = LocalPlayer:WaitForChild("PlayerGui")
    local highlights = gui:FindFirstChild("Highlights", true)
    if highlights then
        for _, frame in ipairs(highlights:GetDescendants()) do
            if frame.Name == "HighlightFrame" then
                local label = frame:FindFirstChild("MapName")
                local name = label and label.Text:match("%[(.+)%]")
                if name then
                    name = name:gsub("%s*$", "")
                    if not official[name] and not table.find(State.HighlightOnlyMaps, name) then
                        table.insert(State.HighlightOnlyMaps, name)
                    end
                end
            end
        end
    end
end)

-- ==============================================================================
-- [4] UTILITIES & ALERT SYSTEM
-- ==============================================================================
local CLMAIN = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("CL_MAIN_GameScript")
local CLMAINenv = nil
pcall(function() CLMAINenv = getsenv(CLMAIN) end)

local UI
local function Alert(Text, ColorType)
    local Output = tostring(Text)
    local SelectedColor = COLORS[ColorType] or COLORS.System
    if State.AlertsEnabled and CLMAINenv and CLMAINenv.newAlert then
        Compat.gameAlert(CLMAINenv.newAlert, Output, SelectedColor, nil, nil)
    end
    if UI then UI.notify(Output, ColorType) end
    print("[FloodGUI]: " .. Output)
end

local Advanced
local advancedOK, advancedResult = pcall(function()
    return Runtime.run("advanced.luau")({runtime = Runtime, remotes = RemoteFolder,
        environment = CLMAINenv, player = LocalPlayer, session = Session,
        track = TrackConnection, alert = Alert, settings = State})
end)
if advancedOK then
    Advanced = advancedResult
    Session.Cleanup = Advanced.cleanup
else
    Alert("Advanced features unavailable: " .. tostring(advancedResult), "Warning")
    Advanced = {guard = {features = {}}, forceWin = function() end, directTarget = function() end,
        onMap = function() end, tick = function() end, cleanup = function() end}
end

local function LoadExternalScript(url)
    local success, response = pcall(function() return game:HttpGet(url) end)
    if success and response then
        local func = loadstring(response)
        if func then func() end
    end
end

local function isRandomString(str)
    if #str == 0 then return false end
    for i = 1, #str do
        local ltr = str:sub(i, i)
        if ltr:lower() == ltr then return false end
    end
    return true
end

local function CleanMapName(name)
    if not name then return "" end
    return name:gsub("\160", " "):gsub("^%s*(.-)%s*$", "%1")
end

local function GetChar()
    -- Event and render handlers must not pile up waiting for a respawn.
    return LocalPlayer.Character
end

local collisionState = setmetatable({}, {__mode = "k"})
local function Noclip(Toggle)
    local char = GetChar()
    if char then
        for _, v in pairs(char:GetChildren()) do
            if v:IsA("BasePart") then
                if Toggle then
                    if collisionState[v] == nil then collisionState[v] = v.CanCollide end
                    v.CanCollide = false
                elseif collisionState[v] ~= nil then
                    v.CanCollide = collisionState[v]
                    collisionState[v] = nil
                end
            end
        end
    end
end

local function Check(Flag)
    local char = GetChar()
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    if Flag == "InLift" then
        return (hrp.Position.X < 50 and hrp.Position.Z > 70)
    elseif Flag == "InGame" then
        return (hrp.Position.X > 50)
    end
    return false
end

local function GetSessionKey()
    local success, key = pcall(function() return ReqPasskey:InvokeServer() end)
    return success and type(key) == "number" and key == key and math.abs(key) ~= math.huge and -key or nil
end

local function HasTASFile(rawName)
    local mapName = CleanMapName(rawName)
    local ok, exists = pcall(Recordings.hasMap, mapName)
    return ok and exists
end

-- Auto-collect was independent of farming in main/testing.
local function CollectMapItems(Map)
    if not State.AutoCollect then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local rescue = Map:FindFirstChild("_Rescue", true)
    for _, part in pairs({Map:FindFirstChild("_LostPage", true), rescue and rescue:FindFirstChild("Contact")}) do
        if part:IsA("BasePart") then
            local original = root.CFrame
            root.CFrame = part.CFrame
            task.wait(0.1)
            if root.Parent then root.CFrame = original end
        end
    end
end

local function ExecuteSecondaryScript(modeType)
    Alert("Executing TAS Script for Mode: " .. modeType, "Info")
    if modeType == "Record" then
        if getgenv().TAS_Active then Alert("Creator already active.", "Warning"); return end
        State.AutoPlay, State.AutoFarm, State.SelectTASMaps = false, false, false
        getgenv().TomatoAutoFarm = false
        if getgenv().FloodGUIStopPlayer then pcall(getgenv().FloodGUIStopPlayer, false) end
        local ok, err = pcall(Runtime.run, CONFIG.TAS_CREATOR_PATH)
        if not ok then
            getgenv().TAS_Active = false
            Alert("TAS Creator stopped: " .. tostring(err), "Error")
        end
    elseif modeType == "Play" then
        Runtime.run(CONFIG.TAS_PLAYER_PATH)
    end
end

local function GetRandomPointInPart(Part)
    local Size = Part.Size
    local CFramePos = Part.CFrame

    local Rx = (math.random() - 0.5) * (Size.X * 0.9)
    local Ry = (math.random() - 0.5) * (Size.Y * 0.9)
    local Rz = (math.random() - 0.5) * (Size.Z * 0.9)

    return CFramePos * CFrame.new(Rx, Ry, Rz)
end

-- ==============================================================================
-- [5] CUSTOM TAS FILE MANAGER (SEPARATE UI)
-- ==============================================================================


-- ==============================================================================
-- [6] AUTO FARM ENGINE (UPDATED MECHANICS)
-- ==============================================================================
local function StartAutoFarm(Map)
    if State.CurrentlyFarming or State.PracticeMap == Map then return end
    State.CurrentlyFarming = true
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then State.CurrentlyFarming = false; return end
    local initialPosition, initialCamera = root.CFrame, Camera.CFrame
    local function cancelled()
        return Session.Cancelled or not Map.Parent or LocalPlayer.Character ~= char
            or hum.Health <= 0 or not (State.AutoFarm or State.AutoPlay)
    end
    local function delay(seconds)
        local deadline = os.clock() + seconds
        repeat
            if cancelled() then return false end
            task.wait(0.1)
        until os.clock() >= deadline
        return true
    end
    local ok, err = pcall(function()
        local deadline = os.clock() + 60
        repeat
            if cancelled() or os.clock() > deadline then return end
            task.wait(0.1)
        until Check("InGame") and not root.Anchored
        initialPosition, initialCamera = root.CFrame, Camera.CFrame
        if not delay(State.StartDelay) then return end
        local buttons = {}
        for _, object in ipairs(Map:GetDescendants()) do
            if isRandomString(object.Name) and object:IsA("Model") then
                for _, part in ipairs(object:GetChildren()) do
                    if part:IsA("BasePart") and tostring(part.BrickColor) ~= "Medium stone grey" then
                        table.insert(buttons, {model = object, part = part})
                        break
                    end
                end
            end
        end
        local exitStart
        local escapeSerial = State.EscapeSerial
        while not cancelled() and Check("InGame") do
            local exit = Map:FindFirstChild("ExitRegion", true)
            if exit then
                if State.PlayAfterButtons then
                    root.Anchored = false
                    root.CFrame, root.Velocity = initialPosition, Vector3.zero
                    Camera.CameraSubject, Camera.CFrame = hum, initialCamera
                    State.PracticeMap = Map
                    Alert("Buttons complete. Returned to spawn for manual play.", "Success")
                    return
                end
                Noclip(State.Noclip)
                root.Anchored = false
                exitStart = exitStart or os.clock()
                if State.EscapeSerial ~= escapeSerial then
                    Alert("Escape confirmed.", "Success")
                    if State.ResetAfterEscape and delay(State.ResetDelay) then
                        State.ResettingCharacter = true
                        hum.Health = 0
                    end
                    return
                end
                if os.clock() - exitStart > 15 then
                    Alert("No escape confirmation; stopping this map.", "Warning")
                    State.PracticeMap = Map
                    return
                end
                Advanced.forceWin()
                root.CFrame = GetRandomPointInPart(exit)
                root.Velocity = Vector3.zero
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            else
                Noclip(true)
                local direct = Advanced.directTarget(Map)
                if direct then
                    root.Anchored = false
                    root.CFrame = direct.CFrame
                else
                    for _, entry in ipairs(buttons) do
                        if cancelled() then break end
                        if entry.part.Parent and entry.model:FindFirstChild("TouchInterest", true)
                            and entry.model:FindFirstChildWhichIsA("BillboardGui", true) then
                            root.Anchored = false
                            root.CFrame = entry.part.CFrame
                            hum:ChangeState(Enum.HumanoidStateType.Jumping)
                            task.wait(0.05)
                            hum:ChangeState(Enum.HumanoidStateType.Running)
                            task.wait(0.05)
                        end
                    end
                end
            end
            task.wait(0.1)
        end
    end)
    if root.Parent then root.Anchored = false end
    if hum.Parent then Camera.CameraSubject = hum end
    Noclip(State.Noclip)
    State.CurrentlyFarming = false
    if not ok then Alert("Farm stopped: " .. tostring(err), "Error") end
end

-- ==============================================================================
-- [7] MAP LOAD EVENT & VOTING HANDLER
-- ==============================================================================

-- IMMEDIATE VOTING LOGIC & TAS PLAYER INJECTION
TrackConnection(NewMapVote.OnClientEvent:Connect(function(dataPacket)
    if Session.Cancelled or (not State.AutoFarm and not State.AutoPlay and not State.SelectTASMaps) then return end
    local maps = dataPacket.mapData
    if not maps then return end

    local votes = dataPacket.pVotes or {}
    local options = {TargetMapName = State.TargetMapName, TargetDifficulty = State.TargetDifficulty,
        EnforceDifficulty = State.EnforceDifficulty, PreferMissingTAS = State.PreferMissingTAS,
        Mode = State.SelectTASMaps and State.Mode or (State.AutoPlay and "Play" or "Farm")}
    local targetMapData, lowestCost = Automation.select(maps, votes[tostring(LocalPlayer.UserId)], options, HasTASFile)

    if targetMapData then
        local key = GetSessionKey()
        if key then
            UpdMapVote:FireServer(key, targetMapData.ID, lowestCost)
            Alert("Voted for Target Map: " .. targetMapData.name .. " (Cost: " .. lowestCost .. ")", "Success")
        end
    end

    -- Execution moved to background loop to avoid NewMapVote delays
    if State.SelectTASMaps and State.Mode == "Record" and targetMapData then
        ExecuteSecondaryScript("Record")
    elseif State.SelectTASMaps and State.Mode == "Play" and targetMapData then
        State.AutoPlay = true
    end
end))

-- MAP LOAD PHASE (Handle Fallbacks & Difficulty Resetting)
TrackConnection(Multiplayer.ChildAdded:Connect(function(NewMap)
    if Session.Cancelled or (NewMap.Name ~= "NewMap" and NewMap.Name ~= "Map") then return end
    Advanced.onMap(NewMap)
    if NewMap.Name == "NewMap" then NewMap:GetPropertyChangedSignal("Name"):Wait() end
    if Session.Cancelled or NewMap.Name ~= "Map" then return end
    CollectMapItems(NewMap)
    if not State.AutoFarm and not State.AutoPlay then return end

    local Settings = NewMap:WaitForChild("Settings", 10)
    local MapName = Settings and Settings:GetAttribute("MapName") or NewMap.Name
    local cleanName = CleanMapName(MapName)
    local hasTasFile = HasTASFile(cleanName)

    local success, result = pcall(function()
        local diffText = Workspace.Lobby.GameInfo.SurfaceGui.Frame.Difficulty.Difficulty.Text
        return diffText:split(":")[1]:gsub("^%s*(.-)%s*$", "%1")
    end)
    local currentRank = DIFFICULTY_RANKS[result] or 0
    local targetRank = DIFFICULTY_RANKS[State.TargetDifficulty] or 999

    if State.EnforceDifficulty and currentRank > targetRank then
        Alert("Map is too hard ("..result.."). Resetting...", "Error")
        State.ResettingForDifficulty = true
        task.wait(1)
        if Session.Cancelled then return end
        local character = GetChar()
        local h = character and character:FindFirstChild("Humanoid")
        if h then h.Health = 0 end
        return
    end

    if State.AutoPlay then
        if not hasTasFile and State.FallbackToFarm then
            Alert("No TAS found for map. Forcing Blatant Fallback...", "Warning")

            if getgenv().TASConnections then
                for _, conn in pairs(getgenv().TASConnections) do pcall(function() conn:Disconnect() end) end
            end
            getgenv().IsTASPlaying = false

            StartAutoFarm(NewMap)
        end
        return
    end

    if State.AutoFarm and not State.AutoPlay then
        Alert("Starting Auto-Farm operation on: " .. MapName, "Info")
        StartAutoFarm(NewMap)
    end
end))

-- Win Tracker
TrackConnection(AlertRemote.OnClientEvent:Connect(function(msg)
    if type(msg) == "string" and State.CurrentlyFarming and (msg:lower():match("escaped") or msg:lower():match("survived")) then
        State.EscapeSerial = State.EscapeSerial + 1
        State.Escaped = true
        -- This delay and reset makes sure the script doesnt reset before escaping.
        task.wait(1)
        State.Escaped = false
    end
end))

-- ==============================================================================
-- [8] BACKGROUND LOOPS & MODS
-- ==============================================================================

-- TAS Auto-Play Loop
task.spawn(function()
    while task.wait(1) do
        if Session.Cancelled then break end

        -- Trigger if AutoPlay is enabled, TAS isn't currently playing, and fallback farm isn't active
        if State.AutoPlay and not getgenv().IsTASPlaying and not State.CurrentlyFarming then
            getgenv().IsTASPlaying = true -- Prevent spam HTTP requests while downloading

            task.spawn(function()
                local success, err = pcall(function()
                    ExecuteSecondaryScript("Play")
                end)

                if not success then
                    Alert("Failed to load TAS script: " .. tostring(err), "Error")
                    getgenv().IsTASPlaying = false -- Revert if HTTP request or execution fails
                end
            end)
        end
    end
end)

-- Lift Rejoin Loop
task.spawn(function()
    while task.wait(1) do
        if Session.Cancelled then break end
        Advanced.tick()
        if State.AutoJoinLift and (State.AutoFarm or State.AutoPlay or State.SelectTASMaps) and not State.CurrentlyFarming and not (State.PracticeMap and State.PracticeMap.Parent) then
            if not Check("InLift") and not Check("InGame") then
                AddedWaiting:FireServer()
            end
        end
    end
end)

-- Auto Rebirth Loop
task.spawn(function()
    local lastRebirthAttempt = 0
    while task.wait(1) do
        if Session.Cancelled then break end
        if State.AutoRebirth then
            local now = os.time()
            if now - lastRebirthAttempt >= State.RebirthInterval then
                local key = GetSessionKey()
                if key then
                    pcall(function()
                        ReqRebirth:FireServer(key)
                        Alert("Attempted Auto Rebirth", "Success")
                    end)
                end
                lastRebirthAttempt = now
            end
        end
    end
end)

-- Mod & Movement Loop
TrackConnection(RunService.Heartbeat:Connect(function()
    if Session.Cancelled then return end
    if State.Noclip then Noclip(true) end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        -- [FIX APPLIED HERE]
        -- 1. `not getgenv().IsTASPlaying`: Completely stops the GUI from messing with movement if TAS is active.
        -- 2. `hum.WalkSpeed > 0`: Allows the GUI to respect the Map's 0 WalkSpeed cooldown.
        if State.MovementOverrides and not getgenv().IsTASPlaying and not getgenv().TAS_Active and hum.WalkSpeed > 0 then
            Overrides.set(hum, "WalkSpeed", State.WalkSpeed)
            Overrides.set(hum, "JumpPower", State.JumpPower)
        elseif not State.MovementOverrides and not getgenv().IsTASPlaying and not getgenv().TAS_Active then
            Overrides.restore(hum, "WalkSpeed")
            Overrides.restore(hum, "JumpPower")
        end

        if State.GodMode and not State.ResettingCharacter and not State.ResettingForDifficulty then
            Overrides.set(hum, "MaxHealth", 100000)
            hum.Health = 100000
        elseif not State.GodMode and Overrides.restore(hum, "MaxHealth") then
            hum.Health = math.min(hum.Health, hum.MaxHealth)
        end
    end
end))

-- Air jump uses Roblox's keyboard, controller, and touch jump request.
TrackConnection(UserInputService.JumpRequest:Connect(function()
    if not State.AirJump or getgenv().IsTASPlaying or getgenv().TAS_Active then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if hum and root and hum:GetState() == Enum.HumanoidStateType.Freefall then
        root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, State.JumpPower * 0.8, root.AssemblyLinearVelocity.Z)
    end
end))

-- Auto Leave Handler
TrackConnection(Players.PlayerAdded:Connect(function(player)
    if State.AutoLeave and player ~= LocalPlayer then
        Alert(("Player '%s' joined. Auto-leaving as configured."):format(player.Name), "Warning")
        task.wait(0.5)
        pcall(LocalPlayer.Kick, LocalPlayer, "FloodGUI: Auto-Leave triggered by player joining.")
    end
end))

-- Anti-AFK
TrackConnection(LocalPlayer.Idled:Connect(function()
    if not State.AntiAFK then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end))

-- Respawn & Lift Re-entry System
TrackConnection(LocalPlayer.CharacterAdded:Connect(function(char)
    State.ResettingCharacter = false
    if State.ResettingForDifficulty then
        char:WaitForChild("HumanoidRootPart", 10)
        task.wait(0.5)
        AddedWaiting:FireServer()
        State.ResettingForDifficulty = false
    end
end))

-- Hook Swim Mode
if type(hookmetamethod) == "function" and type(checkcaller) == "function" then
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, index)
        if not Session.Cancelled and State.SwimEnabled and index == "Position" and tostring(self) == "HumanoidRootPart" and not checkcaller() then
            return Vector3.new(-23, -153, 0)
        end
        return oldIndex(self, index)
    end)
end

-- ==============================================================================
-- [9] AIRFLOW USER INTERFACE
-- ==============================================================================
UI = Runtime.run("ui/service.luau")
local Preferences = Runtime.run("preferences.luau")(Runtime, HttpService)
local preferencesOK, preferencesError = Preferences.load(State)
UI.notifications = State.Notifications
UI.setScale(State.InterfaceScale)
if not preferencesOK then Alert("Preferences not loaded; using defaults: " .. tostring(preferencesError), "Warning") end
local preferenceGeneration = 0
local preferencesDirty = false
local function SavePreferences(key)
    if key and not Preferences.accepts(key) then return end
    preferenceGeneration += 1
    preferencesDirty = true
    local generation = preferenceGeneration
    task.delay(0.4, function()
        if generation ~= preferenceGeneration or Session.Cancelled then return end
        local ok, message = Preferences.save(State)
        if ok then preferencesDirty = false end
        if not ok then Alert("Preferences not saved: " .. tostring(message), "Warning") end
    end)
end
local function StopAutomation()
    State.AutoFarm, State.AutoPlay, State.SelectTASMaps = false, false, false
    State.AutoCollect, State.AutoRebirth = false, false
    getgenv().TomatoAutoFarm = false
    if getgenv().FloodGUIStopPlayer then pcall(getgenv().FloodGUIStopPlayer, false) end
    Advanced.cleanup()
    Alert("Automation stopped.", "Info")
end
local previousCleanup = Session.Cleanup
Session.Cleanup = function()
    if Session.Cleaned then return end
    Session.Cleaned = true
    Session.Cancelled = true
    if preferencesDirty then Preferences.save(State); preferencesDirty = false end
    State.AutoFarm, State.AutoPlay, State.SelectTASMaps = false, false, false
    State.AutoCollect, State.AutoRebirth, State.Noclip, State.SwimEnabled = false, false, false, false
    getgenv().TomatoAutoFarm = false
    if previousCleanup then pcall(previousCleanup) end
    if getgenv().FloodGUIStopPlayer then pcall(getgenv().FloodGUIStopPlayer, false) end
    if getgenv().TAS_Active and getgenv().FloodGUIStopCreator then pcall(getgenv().FloodGUIStopCreator) end
    for _, connection in ipairs(getgenv().FloodGUI_Connections or {}) do pcall(function() connection:Disconnect() end) end
    pcall(Noclip, false)
    Overrides.restoreAll()
    UI.destroy()
end
local Interface = Runtime.run("ui/main.luau")({
    runtime=Runtime, ui=UI, state=State, advanced=Advanced, recordings=Recordings, session=Session,
    noclip=Noclip, alert=Alert, execute=ExecuteSecondaryScript, stop=StopAutomation,
    savePreferences=SavePreferences,
    resetPreferences=function() Preferences.reset(State); UI.notifications=State.Notifications; UI.setScale(State.InterfaceScale); SavePreferences() end,
    unload=Session.Cleanup,
    swimAvailable=type(hookmetamethod)=="function" and type(checkcaller)=="function",
    rejoin=function() TeleportService:Teleport(game.PlaceId,LocalPlayer) end,
    infiniteYield=function() LoadExternalScript("https://raw.githubusercontent.com/edgeiy/infiniteyield/master/source") end,
    copyInvite=function()
        if type(setclipboard)=="function" then setclipboard(CONFIG.DISCORD_INVITE); Alert("Support invite copied.","Success")
        else Alert(CONFIG.DISCORD_INVITE,"Info") end
    end,
})
getgenv().FloodGUIInterface = Interface
Alert("FloodGUI is ready.", "Success")
