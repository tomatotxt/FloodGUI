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
--      UI Library: xHeptc Kavo, tomatotxt fork
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
local Launches = Runtime.run("launches.luau")(Session)
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

local SessionConnections = {}
getgenv().FloodGUI_Connections = SessionConnections
getgenv().TomatoConnections = getgenv().FloodGUI_Connections -- Aliased for clean environment overrides
getgenv().TomatoAutoFarm = false
getgenv().IsTASPlaying = false

local function TrackConnection(connection)
    table.insert(SessionConnections, connection)
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
local PressedMapButton = RemoteFolder:FindFirstChild("PressedMapButton")

-- Native FE2 round lifecycle and state manager
local GameState = Runtime.run("gamestate.luau")(RemoteFolder, TrackConnection)
Runtime.GameState = GameState

-- Native FE2 zipline assistant
local NativeZipline = Runtime.run("zipline.luau")(LocalPlayer, RemoteFolder, TrackConnection)
Runtime.NativeZipline = NativeZipline

local CONFIG = {
    UI_LIBRARY_PATH = "vendor/kavo.luau",
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
    MovementOverrides = false,
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
    CatalogMaps = {},
    AutoPlay = false,
    FallbackToFarm = false,
    AutoFarm = false,
    AutoCollect = false,
    AutoRebirth = false,
    AutoLeave = false,
    UIEnabled = true,

    Mode = "Farm",
    VoteStrategy = "Lowest cost",
    MinDifficulty = "None",
    TargetDifficulty = "Normal",
    TargetMapName = "",
    PartialMapMatch = false,
    RequireTASFile = false,
    EnforceDifficulty = false,
    VoteDuringAutomation = true,
    AllowPaidVotes = true,
    MaxVoteCost = 50,
    VoteMultiplier = 1,
    SessionVotes = 0,
    LastVotedMap = "",
    LastVoteCost = 0,
    CurrentBallotSummary = "",
    LastVotePacket = nil,
    CurrentlyFarming = false,
    FarmPhase = "Idle",
    CurrentMapName = "",
    SessionEscapes = 0,
    LastEscapeTime = "",
    Escaped = false,
    ResettingForDifficulty = false,

    -- Char Mods
    WalkSpeed = 20,
    JumpPower = 50,
    GodMode = false,
    Noclip = false,
    AirJump = false,
    SwimEnabled = false,
    AutoZipline = false
}

-- Preserve the player/GUI compatibility contract used by the older branches.
getgenv().State = function() return State end
pcall(function()
    local library = require(ReplicatedStorage:FindFirstChild("FE2Library", true))
    local official = {}
    for _, map in pairs(library.getOfficialMapData()) do
        if map.mapName then
            official[map.mapName] = true
            if not table.find(State.CatalogMaps, map.mapName) then
                table.insert(State.CatalogMaps, map.mapName)
            end
        end
    end
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
                    if not table.find(State.CatalogMaps, name) then
                        table.insert(State.CatalogMaps, name)
                    end
                end
            end
        end
    end
    table.sort(State.CatalogMaps)
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
    if not success or type(response) ~= "string" or response == "" then
        Alert("Failed to download external script: " .. tostring(response), "Error")
        return
    end
    local func, compileErr = loadstring(response)
    if not func then
        Alert("Failed to compile external script: " .. tostring(compileErr), "Error")
        return
    end
    local runOk, runErr = pcall(func)
    if not runOk then
        Alert("External script error: " .. tostring(runErr), "Error")
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
local ActiveCollectionCleanup
local function CancelCollection()
    if ActiveCollectionCleanup then ActiveCollectionCleanup() end
end
local function CollectMapItems(Map)
    if Session.Cancelled or getgenv().TAS_Active or getgenv().IsTASPlaying then return end
    if not State.AutoCollect or ActiveCollectionCleanup then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local original, finished = root.CFrame, false
    local function release()
        if finished then return end
        finished=true
        if root.Parent and LocalPlayer.Character==char then root.CFrame=original end
        if ActiveCollectionCleanup==release then ActiveCollectionCleanup=nil end
    end
    ActiveCollectionCleanup=release
    local ok,err=pcall(function()
        local hitbox = char:FindFirstChild("FE2_Hitbox") or root
        local rescue = Map:FindFirstChild("_Rescue", true)
        for _, part in pairs({Map:FindFirstChild("_LostPage", true), rescue and rescue:FindFirstChild("Contact")}) do
            if finished or Session.Cancelled or getgenv().TAS_Active or getgenv().IsTASPlaying then return end
            if part:IsA("BasePart") then
                root.CFrame = part.CFrame
                if type(firetouchinterest) == "function" then
                    pcall(firetouchinterest, hitbox, part, 0)
                    pcall(firetouchinterest, hitbox, part, 1)
                end
                task.wait()
                if finished then return end
            end
        end
    end)
    release()
    if not ok then Alert("Collection stopped: "..tostring(err),"Warning") end
end

local function ExecuteSecondaryScript(modeType)
    if Session.Cancelled then return end
    Alert("Executing TAS Script for Mode: " .. modeType, "Info")
    if modeType == "Record" then
        if getgenv().TAS_Active then Alert("Creator already active.", "Warning"); return end
        CancelCollection()
        State.AutoPlay, State.AutoFarm, State.SelectTASMaps = false, false, false
        State.AutoCollect, State.AutoRebirth = false, false
        getgenv().TomatoAutoFarm = false
        if getgenv().FloodGUIStopPlayer then pcall(getgenv().FloodGUIStopPlayer, false) end
        Noclip(false)
        Overrides.restoreAll()
        local isCurrent, own = Launches.begin("creator")
        local ok, err = pcall(Runtime.runScoped, isCurrent, CONFIG.TAS_CREATOR_PATH, isCurrent, own)
        if not ok and isCurrent() then
            Launches.cancel("creator")
            getgenv().TAS_Active = false
            Alert("TAS Creator stopped: " .. tostring(err), "Error")
        end
    elseif modeType == "Play" then
        if getgenv().TAS_Active then return end
        CancelCollection()
        local isCurrent, own = Launches.begin("player")
        getgenv().FloodGUIPlayerOwner = isCurrent
        own(function()
            if getgenv().FloodGUIPlayerOwner==isCurrent then getgenv().IsTASPlaying=false end
        end)
        local ok, err = pcall(Runtime.runScoped, isCurrent, CONFIG.TAS_PLAYER_PATH, isCurrent, own)
        if not ok and isCurrent() then Launches.cancel("player");error(err) end
    end
end

-- ==============================================================================
-- [5] CUSTOM TAS FILE MANAGER (SEPARATE UI)
-- ==============================================================================


-- ==============================================================================
-- [6] AUTO FARM ENGINE (UPDATED MECHANICS)
-- ==============================================================================
local CompletedMaps = setmetatable({}, {__mode = "k"})
local ActiveMapTasks = setmetatable({}, {__mode = "k"})
local MapReadyAt = setmetatable({}, {__mode = "k"})
local RANK_BY_NUMBER = {[1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6}
local NAME_BY_NUMBER = {[1] = "Easy", [2] = "Normal", [3] = "Hard", [4] = "Insane", [5] = "Crazy", [6] = "Crazy+"}

local function GetCamera()
    return (Workspace and Workspace.CurrentCamera) or Camera
end

local function ZeroVelocity(part)
    if not part or not Vector3 then return end
    local zero = Vector3.zero
    part.Velocity = zero
    pcall(function()
        part.AssemblyLinearVelocity = zero
        part.AssemblyAngularVelocity = zero
    end)
end

local function GetRandomPointInPart(Part)
    local Size = Part.Size
    local CFramePos = Part.CFrame
    if not Size or typeof(CFramePos) ~= "CFrame" then
        return CFramePos
    end
    local Rx = (math.random() - 0.5) * (Size.X * 0.9)
    local Ry = (math.random() - 0.5) * (Size.Y * 0.9)
    local Rz = (math.random() - 0.5) * (Size.Z * 0.9)
    return CFramePos * CFrame.new(Rx, Ry, Rz)
end

local function GetButtonTouchCFrame(part)
    if part.Size and typeof(part.CFrame) == "CFrame" then
        return GetRandomPointInPart(part)
    end
    local pos = part.Position
    if typeof(pos) == "Vector3" then
        return CFrame.new(pos + Vector3.new((math.random() - 0.5), (math.random() - 0.5), (math.random() - 0.5)))
    end
    return part.CFrame
end

local function ScanMapButtons(Map, buttons, seenModels)
    for _, object in ipairs(Map:GetDescendants()) do
        if not seenModels[object] and object:IsA("Model") and (isRandomString(object.Name) or object.Name:match("^Button%d*$") ~= nil) then
            for _, part in ipairs(object:GetChildren()) do
                if part:IsA("BasePart") and tostring(part.BrickColor) ~= "Medium stone grey" then
                    seenModels[object] = true
                    table.insert(buttons, {model = object, part = part})
                    break
                end
            end
        end
    end
end

local function ResolveMapDifficulty(Settings)
    local ok, label = pcall(function()
        local diffText = Workspace.Lobby.GameInfo.SurfaceGui.Frame.Difficulty.Difficulty.Text
        return diffText:split(":")[1]:gsub("^%s*(.-)%s*$", "%1")
    end)
    if ok and label and DIFFICULTY_RANKS[label] then
        return DIFFICULTY_RANKS[label], label
    end
    local raw = Settings and Settings:GetAttribute("Difficulty")
    if raw == nil and Settings and Settings.FindFirstChild then
        local valObj = Settings:FindFirstChild("Difficulty")
        raw = valObj and valObj.Value or nil
    end
    if raw == nil and GameState and GameState.getMapData then
        local mapData = GameState.getMapData()
        raw = type(mapData) == "table" and (mapData.Difficulty or mapData.difficulty) or nil
    end
    if type(raw) == "string" and DIFFICULTY_RANKS[raw] then
        return DIFFICULTY_RANKS[raw], raw
    elseif type(raw) == "number" and RANK_BY_NUMBER[raw] then
        return RANK_BY_NUMBER[raw], NAME_BY_NUMBER[raw]
    end
    return 0, tostring(label or "Unknown")
end

local function StartAutoFarm(Map, mapDisplayName)
    if State.CurrentlyFarming or State.PracticeMap == Map or (CompletedMaps and CompletedMaps[Map]) then return end
    local function aborted()
        return Session.Cancelled or not Map.Parent or getgenv().TAS_Active
            or not (State.AutoFarm or State.AutoPlay)
    end

    -- Stage 1: Wait until the player is physically teleported into the map zone (X > 50).
    -- Do not set CurrentlyFarming yet so lobby players are never blocked from joining the lift.
    local enterDeadline = os.clock() + 25
    local lobbyDeadline = os.clock() + 5
    while not Check("InGame") do
        if aborted() or os.clock() > enterDeadline then return end
        if Check("InLift") then
            State.FarmPhase = "Waiting for teleport"
            lobbyDeadline = os.clock() + 8
        elseif os.clock() > lobbyDeadline then
            if CompletedMaps then CompletedMaps[Map] = true end
            return
        end
        task.wait(0.03)
    end

    if State.CurrentlyFarming or State.PracticeMap == Map or (CompletedMaps and CompletedMaps[Map]) then return end
    State.CurrentlyFarming = true
    State.Escaped = false
    if mapDisplayName and mapDisplayName ~= "" then
        State.CurrentMapName = mapDisplayName
    end
    State.FarmPhase = "Waiting for countdown"

    local char, root, hum
    local healthConn, descendantConn
    local function cancelled()
        return aborted() or LocalPlayer.Character ~= char
            or not root or not root.Parent or not hum or not hum.Parent or hum.Health <= 0
    end
    local function delay(seconds)
        if seconds <= 0 then return not cancelled() end
        local deadline = os.clock() + seconds
        repeat
            if cancelled() then return false end
            task.wait(0.03)
        until os.clock() >= deadline
        return true
    end

    local ok, err = pcall(function()
        -- Stage 2: Frame-exact wait for FE2's round-start intro countdown to unanchor HumanoidRootPart.
        local unanchorDeadline = os.clock() + 25
        repeat
            if aborted() or os.clock() > unanchorDeadline then return end
            char = GetChar()
            root = char and char:FindFirstChild("HumanoidRootPart")
            hum = char and char:FindFirstChildOfClass("Humanoid")
            if root and not Check("InGame") then return end
            if root and not root.Anchored and hum and hum.Health > 0 then break end
            RunService.Heartbeat:Wait()
        until false

        local cam = GetCamera()
        local initialPosition, initialCamera = root.CFrame, cam and cam.CFrame
        if State.AutoCollect then
            State.FarmPhase = "Collecting items"
            CollectMapItems(Map)
            if cancelled() or not Check("InGame") then return end
            root.CFrame = initialPosition
        end
        if State.StartDelay > 0 then
            State.FarmPhase = "Start delay"
            if not delay(State.StartDelay) then return end
        end

        local buttons, seenModels = {}, {}
        ScanMapButtons(Map, buttons, seenModels)
        if Map.DescendantAdded then
            descendantConn = Map.DescendantAdded:Connect(function(descendant)
                if descendant:IsA("Model") or descendant:IsA("BasePart") then
                    local model = descendant:IsA("Model") and descendant or descendant.Parent
                    if model and not seenModels[model] and model:IsA("Model")
                        and (isRandomString(model.Name) or model.Name:match("^Button%d*$") ~= nil) then
                        for _, part in ipairs(model:GetChildren()) do
                            if part:IsA("BasePart") and tostring(part.BrickColor) ~= "Medium stone grey" then
                                seenModels[model] = true
                                table.insert(buttons, {model = model, part = part})
                                break
                            end
                        end
                    end
                end
            end)
        end

        if hum.GetPropertyChangedSignal then
            healthConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
                if not State.ResettingCharacter and not State.ResettingForDifficulty and hum.Health > 0 and hum.Health < hum.MaxHealth then
                    hum.Health = hum.MaxHealth
                end
            end)
        end

        local exitStart
        local lastLocatorHit = os.clock()
        local lastRemotePress = setmetatable({}, {__mode = "k"})
        local pressRemote = PressedMapButton or (RemoteFolder and RemoteFolder:FindFirstChild("PressedMapButton"))
        local hitbox = char:FindFirstChild("FE2_Hitbox") or root
        local escapeSerial = State.EscapeSerial

        local function pressButtonPart(targetPart)
            root.Anchored = false
            root.CFrame = GetButtonTouchCFrame(targetPart)
            ZeroVelocity(root)
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            if type(firetouchinterest) == "function" and hitbox and hitbox.Parent then
                pcall(firetouchinterest, hitbox, targetPart, 0)
                pcall(firetouchinterest, hitbox, targetPart, 1)
            end
            -- Step one physics frame so the character's position at the button replicates alongside the remote.
            RunService.Heartbeat:Wait()
            if pressRemote and pressRemote:IsA("RemoteEvent") then
                local now = os.clock()
                if now - (lastRemotePress[targetPart] or -math.huge) >= 0.05 then
                    lastRemotePress[targetPart] = now
                    pcall(pressRemote.FireServer, pressRemote, targetPart)
                end
            end
        end

        while not cancelled() and Check("InGame") do
            cam = GetCamera()
            local exit = Map:FindFirstChild("ExitRegion", true)
            if exit then
                if State.PlayAfterButtons then
                    if healthConn then healthConn:Disconnect(); healthConn = nil end
                    root.Anchored = false
                    Noclip(State.Noclip)
                    root.CFrame = initialPosition
                    ZeroVelocity(root)
                    if cam then
                        cam.CameraSubject = hum
                        if initialCamera then cam.CFrame = initialCamera end
                    end
                    State.PracticeMap = Map
                    State.FarmPhase = "Manual finish"
                    if CompletedMaps then CompletedMaps[Map] = true end
                    Alert("Buttons complete. Returned to spawn for manual play.", "Success")
                    return
                end
                State.FarmPhase = "Touching exit"
                Noclip(false)
                root.Anchored = false
                if cam and cam.CameraSubject ~= exit then
                    cam.CameraSubject = exit
                end
                exitStart = exitStart or os.clock()
                if State.EscapeSerial ~= escapeSerial or State.Escaped then
                    if CompletedMaps then CompletedMaps[Map] = true end
                    if healthConn then healthConn:Disconnect(); healthConn = nil end
                    if cam then cam.CameraSubject = hum end
                    State.FarmPhase = "Escaped"
                    Alert("Escape confirmed.", "Success")
                    if State.ResetAfterEscape and delay(State.ResetDelay) then
                        State.ResettingCharacter = true
                        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
                        hum.Health = 0
                    end
                    return
                end
                if os.clock() - exitStart > 15 then
                    if CompletedMaps then CompletedMaps[Map] = true end
                    if cam then cam.CameraSubject = hum end
                    State.FarmPhase = "Idle"
                    Alert("No escape confirmation; stopping this map.", "Warning")
                    State.PracticeMap = Map
                    return
                end
                Advanced.forceWin()
                root.CFrame = GetRandomPointInPart(exit)
                ZeroVelocity(root)
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                RunService.Heartbeat:Wait()
            else
                if cam and cam.CameraSubject ~= hum then
                    cam.CameraSubject = hum
                end
                Noclip(true)
                local direct = Advanced.directTarget(Map)
                if direct then
                    State.FarmPhase = "Pressing buttons"
                    lastLocatorHit = os.clock()
                    pressButtonPart(direct)
                else
                    root.Anchored = true
                    ZeroVelocity(root)
                    local allowNoGuiFallback = (os.clock() - lastLocatorHit) > 2.5
                    local touchedAny = false
                    for _, entry in ipairs(buttons) do
                        if cancelled() or Map:FindFirstChild("ExitRegion", true) then break end
                        local touch = entry.part.Parent and entry.model:FindFirstChild("TouchInterest", true)
                        local hasGui = touch and entry.model:FindFirstChildWhichIsA("BillboardGui", true)
                        if touch and (hasGui or allowNoGuiFallback) then
                            touchedAny = true
                            if hasGui then lastLocatorHit = os.clock() end
                            State.FarmPhase = "Pressing buttons"
                            local targetPart = (touch.Parent and touch.Parent.IsA and touch.Parent:IsA("BasePart")) and touch.Parent or entry.part
                            pressButtonPart(targetPart)
                        end
                    end
                    if root.Parent and not Map:FindFirstChild("ExitRegion", true) then
                        root.Anchored = true
                        ZeroVelocity(root)
                    end
                    if not touchedAny then
                        State.FarmPhase = #buttons == 0 and "Waiting for exit" or "Waiting for button"
                        RunService.Heartbeat:Wait()
                    end
                end
            end
        end
        if exitStart and CompletedMaps then
            CompletedMaps[Map] = true
        end
    end)
    if descendantConn then pcall(function() descendantConn:Disconnect() end) end
    if healthConn then pcall(function() healthConn:Disconnect() end) end
    if root and root.Parent then root.Anchored = false end
    local cam = GetCamera()
    if cam and hum and hum.Parent then cam.CameraSubject = hum end
    Noclip(State.Noclip)
    State.CurrentlyFarming = false
    if State.FarmPhase ~= "Manual finish" and State.FarmPhase ~= "Escaped" then
        State.FarmPhase = (State.AutoFarm or State.AutoPlay) and (Check("InLift") and "Waiting in lift" or "Waiting in lobby") or "Idle"
    end
    if not ok then Alert("Farm stopped: " .. tostring(err), "Error") end
end

-- ==============================================================================
-- [7] MAP LOAD EVENT & VOTING HANDLER
-- ==============================================================================

-- IMMEDIATE VOTING LOGIC & TAS PLAYER INJECTION
TrackConnection(NewMapVote.OnClientEvent:Connect(function(dataPacket)
    if Session.Cancelled or type(dataPacket) ~= "table" then return end
    local maps = dataPacket.mapData
    if not maps then return end
    State.LastVotePacket = dataPacket
    local votes = dataPacket.pVotes or {}
    local myVote = votes[tostring(LocalPlayer.UserId)]
    if Automation.describeBallot then
        local _, summary = Automation.describeBallot(maps, myVote, votes)
        State.CurrentBallotSummary = summary or ""
    end
    if State.CastVote then
        State.CastVote(dataPacket, false)
    end
end))

function State.CastVote(dataPacket, forceManual)
    if Session.Cancelled then return false end
    if type(dataPacket) ~= "table" or not dataPacket.mapData then
        if forceManual then
            Alert("No active map ballot right now; wait for voting to open.", "Info")
        end
        return false
    end
    local passiveVote = (State.VoteDuringAutomation ~= false) and (State.AutoFarm or State.AutoPlay)
    if not forceManual and not State.SelectTASMaps and not passiveVote then
        return false
    end

    local maps = dataPacket.mapData
    local votes = dataPacket.pVotes or {}
    local myVote = votes[tostring(LocalPlayer.UserId)]
    local effectiveMode = State.SelectTASMaps and (State.Mode or "Farm")
        or (State.AutoPlay and "Play" or (State.AutoFarm and "Farm" or "Manual"))
    local options = {
        TargetMapName = State.TargetMapName,
        PartialMapMatch = State.PartialMapMatch,
        MinDifficulty = State.MinDifficulty,
        TargetDifficulty = State.TargetDifficulty,
        EnforceDifficulty = State.EnforceDifficulty,
        PreferMissingTAS = State.PreferMissingTAS,
        RequireTASFile = State.RequireTASFile,
        AllowPaidVotes = State.AllowPaidVotes,
        MaxVoteCost = State.MaxVoteCost,
        VoteStrategy = State.VoteStrategy,
        HighlightMaps = State.HighlightOnlyMaps,
        Mode = effectiveMode,
    }
    local targetMapData, lowestCost = Automation.select(maps, myVote, options, HasTASFile, votes)
    if not targetMapData then
        if forceManual then
            Alert("No map on the current ballot matched your voting filters.", "Warning")
        end
        return false
    end

    local key = GetSessionKey()
    if key then
        local maxBudget = (State.AllowPaidVotes == false) and 0 or (tonumber(State.MaxVoteCost) or 50)
        local desiredVotes = math.clamp(math.floor(tonumber(State.VoteMultiplier) or 1), 1, 5)
        UpdMapVote:FireServer(key, targetMapData.ID, lowestCost)
        local totalCost = lowestCost
        local castCount = 1
        local simVoteCount = ((myVote and myVote.mapID == targetMapData.ID) and (tonumber(myVote.voteCount) or 1) or 0) + 1
        for _ = 2, desiredVotes do
            local simVote = {mapID = targetMapData.ID, voteCount = simVoteCount}
            local extraCost = Automation.voteCost and Automation.voteCost(targetMapData, simVote) or 10
            if totalCost + extraCost > maxBudget then
                break
            end
            UpdMapVote:FireServer(key, targetMapData.ID, extraCost)
            totalCost += extraCost
            castCount += 1
            simVoteCount += 1
        end
        State.SessionVotes = (State.SessionVotes or 0) + castCount
        local diffTag = targetMapData.difficulty and (" [" .. tostring(targetMapData.difficulty) .. "]") or ""
        State.LastVotedMap = tostring(targetMapData.name or targetMapData.ID) .. diffTag
        State.LastVoteCost = totalCost
        local multText = castCount > 1 and (tostring(castCount) .. "x, ") or ""
        Alert("Voted for " .. tostring(targetMapData.name) .. diffTag .. " (" .. multText .. "Cost: " .. tostring(totalCost) .. ")", "Success")
    elseif forceManual then
        Alert("Could not obtain session passkey to cast vote.", "Error")
        return false
    end

    if State.SelectTASMaps then
        if State.Mode == "Record" then
            ExecuteSecondaryScript("Record")
        elseif State.Mode == "Play" then
            State.AutoPlay = true
        elseif State.Mode == "Farm" then
            State.AutoFarm = true
            State.AutoPlay = false
            getgenv().TomatoAutoFarm = true
        end
    end
    return true
end

function State.InspectBallot()
    local packet = State.LastVotePacket
    if type(packet) ~= "table" or not packet.mapData then
        Alert("No active map ballot right now; wait for voting in the lobby.", "Info")
        return
    end
    local votes = packet.pVotes or {}
    local myVote = votes[tostring(LocalPlayer.UserId)]
    if Automation.describeBallot then
        local items, summary = Automation.describeBallot(packet.mapData, myVote, votes)
        State.CurrentBallotSummary = summary or ""
        if #items == 0 then
            Alert("Current ballot has no displayed maps.", "Warning")
        else
            Alert("Ballot (" .. tostring(#items) .. " maps): " .. summary, "Info")
        end
    end
end

-- MAP LOAD PHASE (Handle Fallbacks & Difficulty Resetting)
local function CollectMapItemsWhenReady(TargetMap)
    task.spawn(function()
        local deadline = os.clock() + 30
        while TargetMap.Parent == Multiplayer and not Session.Cancelled and os.clock() < deadline do
            if not State.AutoCollect or State.AutoFarm or getgenv().TAS_Active or getgenv().IsTASPlaying then
                return
            end
            local char = GetChar()
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if Check("InGame") and root and not root.Anchored then
                CollectMapItems(TargetMap)
                return
            end
            task.wait(0.1)
        end
    end)
end

local function ProcessMap(NewMap)
    if Session.Cancelled or not NewMap or (NewMap.Name ~= "NewMap" and NewMap.Name ~= "Map") then return end
    if ActiveMapTasks[NewMap] or CompletedMaps[NewMap] or State.PracticeMap == NewMap then return end
    ActiveMapTasks[NewMap] = true
    local ok, err = pcall(function()
        Advanced.onMap(NewMap)
        local readyDeadline = os.clock() + 120
        while NewMap.Name == "NewMap" and NewMap.Parent == Multiplayer and not Session.Cancelled and os.clock() < readyDeadline do
            if (State.AutoFarm or State.AutoPlay) and not State.CurrentlyFarming then
                State.FarmPhase = "Loading map"
            end
            RunService.Heartbeat:Wait()
        end
        if Session.Cancelled or NewMap.Parent ~= Multiplayer then return end
        if NewMap.Name ~= "Map" then
            Alert("Map preparation timed out; waiting for the next map.", "Warning")
            return
        end
        MapReadyAt[NewMap] = MapReadyAt[NewMap] or os.clock()
        State.LastVotePacket = nil
        State.CurrentBallotSummary = ""
        if State.AutoCollect and not State.AutoFarm then
            CollectMapItemsWhenReady(NewMap)
        end
        if not State.AutoFarm and not State.AutoPlay then return end

        local Settings = NewMap:WaitForChild("Settings", 10)
        local MapName = Settings and Settings:GetAttribute("MapName") or NewMap.Name
        local cleanName = CleanMapName(MapName)
        State.CurrentMapName = cleanName
        local hasTasFile = HasTASFile(cleanName)

        local currentRank, result = ResolveMapDifficulty(Settings)
        local targetRank = DIFFICULTY_RANKS[State.TargetDifficulty] or 999
        local minRank = (State.MinDifficulty and State.MinDifficulty ~= "None" and DIFFICULTY_RANKS[State.MinDifficulty]) or 0
        local outOfRange = currentRank > targetRank or (minRank > 0 and currentRank > 0 and currentRank < minRank)

        if State.EnforceDifficulty and outOfRange then
            local resetDeadline = os.clock() + 25
            local lobbyTimeout = os.clock() + 5
            while not Session.Cancelled and NewMap.Parent == Multiplayer and os.clock() < resetDeadline do
                if Check("InLift") then
                    lobbyTimeout = os.clock() + 8
                elseif not Check("InGame") and os.clock() > lobbyTimeout then
                    CompletedMaps[NewMap] = true
                    return
                end
                local character = GetChar()
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local h = character and character:FindFirstChildOfClass("Humanoid")
                if Check("InGame") and root and not root.Anchored and h and h.Health > 0 then
                    local reason = currentRank > targetRank and "too hard" or "below minimum difficulty"
                    Alert("Map is " .. reason .. " (" .. tostring(result) .. "). Resetting...", "Error")
                    CompletedMaps[NewMap] = true
                    State.FarmPhase = "Resetting (difficulty)"
                    State.ResettingForDifficulty = true
                    h.Health = 0
                    return
                end
                task.wait(0.1)
            end
            return
        end

        if State.AutoPlay then
            if not hasTasFile and State.FallbackToFarm then
                Alert("No TAS found for map. Forcing Blatant Fallback...", "Warning")
                if getgenv().FloodGUIStopPlayer then pcall(getgenv().FloodGUIStopPlayer, false) end
                if getgenv().TASConnections then
                    for _, conn in pairs(getgenv().TASConnections) do pcall(function() conn:Disconnect() end) end
                end
                getgenv().IsTASPlaying = false
                StartAutoFarm(NewMap, cleanName)
            end
            return
        end

        if State.AutoFarm and not State.AutoPlay then
            Alert("Starting Auto-Farm operation on: " .. tostring(cleanName ~= "" and cleanName or MapName), "Info")
            StartAutoFarm(NewMap, cleanName)
        end
    end)
    ActiveMapTasks[NewMap] = nil
    if not ok and not Session.Cancelled then
        Alert("Map handler error: " .. tostring(err), "Error")
    end
end

TrackConnection(Multiplayer.ChildAdded:Connect(function(NewMap)
    if Session.Cancelled or (NewMap.Name ~= "NewMap" and NewMap.Name ~= "Map") then return end
    ProcessMap(NewMap)
end))

-- Win Tracker
if GameState then
    GameState.onSurvived(function(survived, escapeTime)
        if survived == true and (State.CurrentlyFarming or getgenv().IsTASPlaying) then
            local formatted = escapeTime and string.format("%01d:%06.3f", math.floor(escapeTime / 60) % 60, escapeTime % 60) or nil
            if formatted then State.LastEscapeTime = formatted end
            if not State.Escaped then
                State.EscapeSerial = State.EscapeSerial + 1
                State.SessionEscapes = (State.SessionEscapes or 0) + 1
                State.Escaped = true
                task.delay(1, function()
                    State.Escaped = false
                end)
            end
            Alert(formatted and ("Escape confirmed by server (Time: " .. formatted .. ")") or "Escape confirmed by server.", "Success")
        end
    end)
end

TrackConnection(AlertRemote.OnClientEvent:Connect(function(msg)
    if type(msg) == "string" and State.CurrentlyFarming and (msg:lower():match("escaped") or msg:lower():match("survived")) then
        if not State.Escaped then
            State.EscapeSerial = State.EscapeSerial + 1
            State.SessionEscapes = (State.SessionEscapes or 0) + 1
            State.Escaped = true
            task.delay(1, function()
                State.Escaped = false
            end)
        end
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

-- Lift Rejoin & Active Map Pickup Loop
task.spawn(function()
    local lastLiftFire = -math.huge
    while task.wait(0.25) do
        if Session.Cancelled then break end
        Advanced.tick()
        if not State.AutoFarm and not State.AutoPlay then
            if CompletedMaps then table.clear(CompletedMaps) end
            if State.FarmPhase ~= "Manual finish" then
                State.FarmPhase = "Idle"
                State.CurrentMapName = ""
            end
        elseif State.AutoFarm and not State.CurrentlyFarming and not (State.PracticeMap and State.PracticeMap.Parent) then
            if Check("InLift") then
                if State.FarmPhase ~= "Loading map" and State.FarmPhase ~= "Waiting for teleport" then
                    State.FarmPhase = "Waiting in lift"
                end
            elseif not Check("InGame") then
                State.FarmPhase = State.AutoJoinLift and "Joining lift" or "Waiting in lobby"
                State.CurrentMapName = ""
            end
        end
        if (State.AutoFarm or State.AutoPlay) and not State.CurrentlyFarming and not getgenv().TAS_Active then
            local pendingNewMap = Multiplayer:FindFirstChild("NewMap")
            if pendingNewMap and not ActiveMapTasks[pendingNewMap] then
                task.spawn(ProcessMap, pendingNewMap)
            else
                local activeMap = Multiplayer:FindFirstChild("Map")
                if activeMap and not ActiveMapTasks[activeMap] and not CompletedMaps[activeMap] and State.PracticeMap ~= activeMap then
                    local recentTransition = MapReadyAt[activeMap] and (os.clock() - MapReadyAt[activeMap] < 12)
                    if Check("InGame") or (Check("InLift") and recentTransition) then
                        task.spawn(ProcessMap, activeMap)
                    end
                end
            end
        end
        if State.AutoJoinLift and (State.AutoFarm or State.AutoPlay or State.SelectTASMaps)
            and not (State.PracticeMap and State.PracticeMap.Parent) and not getgenv().TAS_Active then
            local char = GetChar()
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local now = os.clock()
            if root and hum and hum.Health > 0 and not Check("InLift") and not Check("InGame") and (now - lastLiftFire >= 0.5) then
                lastLiftFire = now
                AddedWaiting:FireServer()
            end
        end
    end
end)

-- Auto Rebirth Loop
task.spawn(function()
    local lastRebirthAttempt = -math.huge
    while task.wait(1) do
        if Session.Cancelled then break end
        if State.AutoRebirth and not State.CurrentlyFarming and not Check("InGame") then
            local now = os.clock()
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
    local engineOwnsCharacter = getgenv().IsTASPlaying or getgenv().TAS_Active
    if engineOwnsCharacter then return end
    if State.Noclip and not State.CurrentlyFarming then Noclip(true) end
    if State.AutoZipline and not engineOwnsCharacter then NativeZipline.check() end
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
    local wasResetting = State.ResettingCharacter or State.ResettingForDifficulty
    State.ResettingCharacter = false
    State.ResettingForDifficulty = false
    if State.AutoJoinLift and (wasResetting or State.AutoFarm or State.AutoPlay or State.SelectTASMaps)
        and not (State.PracticeMap and State.PracticeMap.Parent) and not getgenv().TAS_Active then
        local root = char:WaitForChild("HumanoidRootPart", 10)
        task.wait(0.1)
        if root and not Session.Cancelled and State.AutoJoinLift and not Check("InLift") and not Check("InGame") then
            AddedWaiting:FireServer()
        end
    end
end))

-- Native FE2 swimming query, shared with the creator and scoped to this session.
local NativeSwim = Runtime.run("swimming.luau")(LocalPlayer, RunService.Heartbeat)
Runtime.NativeSwim = NativeSwim
-- Retain both disposers even if later UI loading fails before full cleanup is installed.
Session.Cleanup = function()
    if Advanced and Advanced.cleanup then pcall(Advanced.cleanup) end
    NativeSwim.destroy()
end
NativeSwim.override(function()
    if not Session.Cancelled and not getgenv().TAS_Active and not getgenv().IsTASPlaying and State.SwimEnabled then
        return true
    end
end)

-- ==============================================================================
-- [9] KAVO USER INTERFACE
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
    CancelCollection()
    Launches.cancel("player")
    getgenv().IsTASPlaying = false
    State.AutoFarm, State.AutoPlay, State.SelectTASMaps = false, false, false
    State.AutoCollect, State.AutoRebirth = false, false
    State.PracticeMap = nil
    State.FarmPhase = "Idle"
    State.CurrentMapName = ""
    if CompletedMaps then table.clear(CompletedMaps) end
    getgenv().TomatoAutoFarm = false
    if getgenv().FloodGUIStopPlayer then pcall(getgenv().FloodGUIStopPlayer, false) end
    Advanced.cleanup()
    Alert("Automation stopped.", "Info")
end
getgenv().FloodGUIStopAutomation = StopAutomation
Session.Cleanup = function()
    if Session.Cleaned then return end
    Session.Cleaned = true
    Session.Cancelled = true
    CancelCollection()
    local stopPlayer, stopCreator = getgenv().FloodGUIStopPlayer, getgenv().FloodGUIStopCreator
    Launches.cancel()
    getgenv().IsTASPlaying = false
    getgenv().TAS_Active = false
    if preferencesDirty then Preferences.save(State); preferencesDirty = false end
    State.AutoFarm, State.AutoPlay, State.SelectTASMaps = false, false, false
    State.AutoCollect, State.AutoRebirth, State.Noclip, State.SwimEnabled = false, false, false, false
    getgenv().TomatoAutoFarm = false
    if Advanced and Advanced.cleanup then pcall(Advanced.cleanup) end
    if stopPlayer then pcall(stopPlayer, false) end
    if stopCreator then pcall(stopCreator) end
    for _, connection in ipairs(SessionConnections) do pcall(function() connection:Disconnect() end) end
    pcall(Noclip, false)
    Overrides.restoreAll()
    NativeSwim.destroy()
    if NativeZipline and NativeZipline.destroy then NativeZipline.destroy() end
    if GameState and GameState.destroy then GameState.destroy() end
    UI.destroy()
end
local Interface = Runtime.run("ui/main.luau")({
    runtime=Runtime, ui=UI, state=State, advanced=Advanced, recordings=Recordings, session=Session,
    noclip=Noclip, alert=Alert, execute=ExecuteSecondaryScript, stop=StopAutomation,
    voteNow=function() if State.CastVote then State.CastVote(State.LastVotePacket, true) end end,
    inspectBallot=function() if State.InspectBallot then State.InspectBallot() end end,
    cancelPlayerLaunch=function() Launches.cancel("player"); getgenv().IsTASPlaying = false end,
    savePreferences=SavePreferences,
    resetPreferences=function() Preferences.reset(State); UI.notifications=State.Notifications; UI.setScale(State.InterfaceScale); SavePreferences() end,
    unload=Session.Cleanup,
    swimAvailable=NativeSwim.available(),
    zipline=NativeZipline,
    rejoin=Runtime.run("rejoin.luau")(getfenv(), Alert, TrackConnection),
    infiniteYield=function() LoadExternalScript("https://raw.githubusercontent.com/edgeiy/infiniteyield/master/source") end,
    copyInvite=function()
        if type(setclipboard)=="function" then setclipboard(CONFIG.DISCORD_INVITE); Alert("Support invite copied.","Success")
        else Alert(CONFIG.DISCORD_INVITE,"Info") end
    end,
})
getgenv().FloodGUIInterface = Interface
local Integrity = Runtime.run("integrity.luau")
task.spawn(function()
    if Session.Cancelled then return end
    pcall(function()
        Integrity.check(Runtime, HttpService, function(msg, level)
            if not Session.Cancelled then Alert(msg, level) end
        end, Session)
    end)
end)
Alert("FloodGUI is ready.", "Success")
