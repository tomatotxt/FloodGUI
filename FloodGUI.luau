local Runtime = assert(getgenv().FloodGUIRuntime, "Start FloodGUI through loader.lua")
local Automation = Runtime.run("automation.luau")
local Recordings = Runtime.run("TAS/recordings.luau")(Runtime)
getgenv().FloodGUIRecordings = Recordings
-- ==============================================================================
-- FloodGUI
-- Description: Exploit GUI for Flood Escape 2 providing various cheats and utilities.
-- Credits:
--      TAS System: Tomato (Base by Voiz#5668)
--      Reverse Engineering/Base GUI: Tomato
--      UI Library: xHeptc (Kavo)
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

-- Custom Kavo UI Theme
local KAVO_THEME = {
    SchemeColor = Color3.fromRGB(0, 100, 255),
    Background = Color3.fromRGB(35, 35, 40),
    Header = Color3.fromRGB(25, 25, 30),
    TextColor = Color3.fromRGB(255, 255, 255),
    ElementColor = Color3.fromRGB(50, 50, 55)
}

-- ==============================================================================
-- [3] STATE MANAGEMENT
-- ==============================================================================
_G.LoopCancel = false

local State = {
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

local function Alert(Text, ColorType)
    local Output = tostring(Text)
    local SelectedColor = COLORS[ColorType] or COLORS.System
    if State.AlertsEnabled and CLMAINenv and CLMAINenv.newAlert then
        pcall(function()
            -- Structure: newAlert(Message, Color, Time, Style)
            CLMAINenv.newAlert(Output, SelectedColor, nil, nil)
        end)
    end
    print("[FloodGUI]: " .. Output)
end

local Advanced
local advancedOK, advancedResult = pcall(function()
    return Runtime.run("advanced.luau")({runtime = Runtime, remotes = RemoteFolder,
        environment = CLMAINenv, player = LocalPlayer, session = Session,
        track = TrackConnection, alert = Alert})
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
    return LocalPlayer.Character or (LocalPlayer.CharacterAdded:wait() and LocalPlayer.Character)
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
    return success and -key or nil
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
local function OpenTASFileManager()
    local CoreGui = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
    if CoreGui:FindFirstChild("TAS_FileManager") then
        CoreGui.TAS_FileManager.Enabled = not CoreGui.TAS_FileManager.Enabled
        return
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "TAS_FileManager"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 500, 0, 420)
    MainFrame.Position = UDim2.new(0.5, -250, 0.5, -210)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner", MainFrame)
    UICorner.CornerRadius = UDim.new(0, 8)

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 35)
    TopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame
    Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 8)

    local FixSquare = Instance.new("Frame", TopBar)
    FixSquare.Size = UDim2.new(1, 0, 0, 8)
    FixSquare.Position = UDim2.new(0, 0, 1, -8)
    FixSquare.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    FixSquare.BorderSizePixel = 0

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -40, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "TAS File Manager"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TopBar

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 35, 0, 35)
    CloseBtn.Position = UDim2.new(1, -35, 0, 0)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 14
    CloseBtn.Parent = TopBar
    CloseBtn.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

    -- Draggable Logic
    local dragging, dragInput, dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = MainFrame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    TopBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Layout
    local ContentFrame = Instance.new("Frame", MainFrame)
    ContentFrame.Size = UDim2.new(1, -20, 1, -145)
    ContentFrame.Position = UDim2.new(0, 10, 0, 45)
    ContentFrame.BackgroundTransparency = 1

    local function CreateList(titleTxt, posX)
        local Frame = Instance.new("Frame", ContentFrame)
        Frame.Size = UDim2.new(0.5, -5, 1, 0)
        Frame.Position = UDim2.new(posX, 0, 0, 0)
        Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 6)

        local Lbl = Instance.new("TextLabel", Frame)
        Lbl.Size = UDim2.new(1, 0, 0, 25)
        Lbl.BackgroundTransparency = 1
        Lbl.Text = titleTxt
        Lbl.TextColor3 = COLORS.Info
        Lbl.Font = Enum.Font.GothamBold
        Lbl.TextSize = 13

        local Scroll = Instance.new("ScrollingFrame", Frame)
        Scroll.Size = UDim2.new(1, -10, 1, -30)
        Scroll.Position = UDim2.new(0, 5, 0, 25)
        Scroll.BackgroundTransparency = 1
        Scroll.BorderSizePixel = 0
        Scroll.ScrollBarThickness = 4
        Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

        local UIListLayout = Instance.new("UIListLayout", Scroll)
        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout.Padding = UDim.new(0, 3)

        return Scroll, UIListLayout
    end

    local OnlineList, OnlineLayout = CreateList("Bundled TAS Files", 0)
    local LocalList, LocalLayout = CreateList("Local TAS Files (Workspace)", 0.5 + (5/480))

    local function AddItemToList(scroll, layout, txt)
        local lbl = Instance.new("TextLabel", scroll)
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.Text = " • " .. txt
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
    end

    local function RefreshLocalList()
        for _, v in ipairs(LocalList:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end
        if getgenv().listfiles and getgenv().isfolder then
            if not isfolder(Runtime.root) then makefolder(Runtime.root) end
            if not isfolder(Runtime.root .. "/TAS FILES") then makefolder(Runtime.root .. "/TAS FILES") end

            local s2, files = pcall(listfiles, Runtime.root .. "/TAS FILES")
            if s2 and files then
                for _, path in ipairs(files) do
                    local name = path:match("([^/\\]+)%.json$") or path:match("([^/\\]+)%.fe2tomatas$")
                    if name then AddItemToList(LocalList, LocalLayout, name) end
                end
            else
                AddItemToList(LocalList, LocalLayout, "Folder empty or read error.")
            end
        else
            AddItemToList(LocalList, LocalLayout, "Executor doesn't support listfiles.")
        end
    end

    -- Import Section
    local ImportFrame = Instance.new("Frame", MainFrame)
    ImportFrame.Size = UDim2.new(1, -20, 0, 85)
    ImportFrame.Position = UDim2.new(0, 10, 1, -95)
    ImportFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    Instance.new("UICorner", ImportFrame).CornerRadius = UDim.new(0, 6)

    -- Row 1: Single Import
    local URLBox = Instance.new("TextBox", ImportFrame)
    URLBox.Size = UDim2.new(0.5, -10, 0, 30)
    URLBox.Position = UDim2.new(0, 5, 0, 10)
    URLBox.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    URLBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    URLBox.PlaceholderText = "Raw JSON or FE2T URL..."
    URLBox.Text = ""
    URLBox.Font = Enum.Font.Gotham
    URLBox.TextSize = 12
    URLBox.TextWrapped = true
    Instance.new("UICorner", URLBox).CornerRadius = UDim.new(0, 4)

    local NameBox = Instance.new("TextBox", ImportFrame)
    NameBox.Size = UDim2.new(0.25, -10, 0, 30)
    NameBox.Position = UDim2.new(0.5, 0, 0, 10)
    NameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    NameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameBox.PlaceholderText = "Map Name..."
    NameBox.Text = ""
    NameBox.Font = Enum.Font.Gotham
    NameBox.TextSize = 12
    Instance.new("UICorner", NameBox).CornerRadius = UDim.new(0, 4)

    local ImportBtn = Instance.new("TextButton", ImportFrame)
    ImportBtn.Size = UDim2.new(0.25, -10, 0, 30)
    ImportBtn.Position = UDim2.new(0.75, 5, 0, 10)
    ImportBtn.BackgroundColor3 = COLORS.Info
    ImportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ImportBtn.Text = "Import Link"
    ImportBtn.Font = Enum.Font.GothamBold
    ImportBtn.TextSize = 12
    Instance.new("UICorner", ImportBtn).CornerRadius = UDim.new(0, 4)

    -- Row 2: Mass Download
    local DownloadAllBtn = Instance.new("TextButton", ImportFrame)
    DownloadAllBtn.Size = UDim2.new(1, -10, 0, 30)
    DownloadAllBtn.Position = UDim2.new(0, 5, 0, 45)
    DownloadAllBtn.BackgroundColor3 = Color3.fromRGB(30, 140, 60)
    DownloadAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    DownloadAllBtn.Text = "Refresh Bundled TAS Files"
    DownloadAllBtn.Font = Enum.Font.GothamBold
    DownloadAllBtn.TextSize = 12
    Instance.new("UICorner", DownloadAllBtn).CornerRadius = UDim.new(0, 4)

    -- Fetch Data & Cache
    local OnlineFilesCache = {}

    task.spawn(function()
        AddItemToList(OnlineList, OnlineLayout, "Reading bundled catalog...")
        local s, r = pcall(Runtime.read, "tas-catalog.json")
        for _, v in ipairs(OnlineList:GetChildren()) do if v:IsA("TextLabel") then v:Destroy() end end

        if s and r then
            local successDec, data = pcall(function() return HttpService:JSONDecode(r) end)
            if successDec and type(data) == "table" then
                OnlineFilesCache = data
                for _, file in ipairs(data) do
                    if file.name and file.name:match("%.json$") then
                        AddItemToList(OnlineList, OnlineLayout, file.name:gsub("%.json$", ""))
                    end
                end
            else
                AddItemToList(OnlineList, OnlineLayout, "Error decoding bundled catalog.")
            end
        else
            AddItemToList(OnlineList, OnlineLayout, "Bundled catalog could not be read.")
        end

        RefreshLocalList()
    end)

    -- Single Import Logic
    ImportBtn.MouseButton1Click:Connect(function()
        if not getgenv().writefile then
            ImportBtn.Text = "Not Supported"
            task.wait(1); ImportBtn.Text = "Import Link"
            return
        end

        local url = URLBox.Text
        local mapName = NameBox.Text
        if url == "" or mapName == "" then return end

        ImportBtn.Text = "Downloading..."
        local s, r = pcall(game.HttpGet, game, url)
        if s and r and #r > 10 then
            local imported, reason = pcall(function()
                local frames, metadata = Recordings.codec.decode(r)
                metadata.mapName = mapName
                return Recordings.save(mapName, frames, metadata)
            end)
            ImportBtn.Text = imported and "Saved binary!" or "Invalid recording"
            if imported then RefreshLocalList() else Alert(tostring(reason), "Error") end
        else
            ImportBtn.Text = "Failed!"
        end
        task.wait(2); ImportBtn.Text = "Import Link"
    end)

    -- Recordings ship with the project; refresh without overwriting edited runs.
    DownloadAllBtn.MouseButton1Click:Connect(function()
        RefreshLocalList()
        DownloadAllBtn.Text = "Local files refreshed"
        task.wait(2)
        DownloadAllBtn.Text = "Refresh Bundled TAS Files"
    end)
end

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
        local h = GetChar():FindFirstChild("Humanoid")
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
        if (State.AutoFarm or State.AutoPlay or State.SelectTASMaps) and not State.CurrentlyFarming and not (State.PracticeMap and State.PracticeMap.Parent) then
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
            if now - lastRebirthAttempt >= 60 then
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
    if State.Noclip then Noclip(true) end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        -- [FIX APPLIED HERE]
        -- 1. `not getgenv().IsTASPlaying`: Completely stops the GUI from messing with movement if TAS is active.
        -- 2. `hum.WalkSpeed > 0`: Allows the GUI to respect the Map's 0 WalkSpeed cooldown.
        if not getgenv().IsTASPlaying and not getgenv().TAS_Active and hum.WalkSpeed > 0 then
            if hum.WalkSpeed ~= State.WalkSpeed then hum.WalkSpeed = State.WalkSpeed end
            if hum.JumpPower ~= State.JumpPower then hum.JumpPower = State.JumpPower end
        end

        if State.GodMode and not State.ResettingCharacter and not State.ResettingForDifficulty then
            hum.MaxHealth = 100000
            hum.Health = 100000
        end
    end
end))

-- Input Handlers (Spacebar Jump Logic)
TrackConnection(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    if State.AirJump and (input.KeyCode == Enum.KeyCode.ButtonA or input.KeyCode == Enum.KeyCode.Space) then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hum and hrp and hum:GetState() == Enum.HumanoidStateType.Freefall then
            hrp.Velocity = Vector3.new(hrp.Velocity.X, State.JumpPower * 0.8, hrp.Velocity.Z)
        end
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
if getgenv().hookmetamethod then
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, index)
        if not Session.Cancelled and State.SwimEnabled and index == "Position" and tostring(self) == "HumanoidRootPart" and not checkcaller() then
            return Vector3.new(-23, -153, 0)
        end
        return oldIndex(self, index)
    end)
end

-- ==============================================================================
-- [9] USER INTERFACE (KAVO)
-- ==============================================================================

local function InitializeUI()
    local Kavo = Runtime.run(CONFIG.UI_LIBRARY_PATH)
    local Window = Kavo.CreateLib("FloodGUI", KAVO_THEME)

    -- === 1. TAS TAB ===
    local tasTab = Window:NewTab("TAS")

    local stealthSec = tasTab:NewSection("Auto-Play (Stealth Farm)")
    stealthSec:NewToggle("Enable Auto-Play", "Automatically plays local TAS files.", function(state)
        State.AutoPlay = state
        Alert("Auto-Play (Stealth) " .. (state and "Enabled" or "Disabled"), state and "Success" or "Error")
    end)

    stealthSec:NewToggle("Fallback to Blatant Farm", "[NOT RECOMMENDED] Farm manually if TAS is missing.", function(state)
        State.FallbackToFarm = state
        Alert("TAS Fallback " .. (state and "Enabled" or "Disabled"), "Warning")
    end)

    local tasSec = tasTab:NewSection("TAS Manager & Sniping")
    tasSec:NewButton("TAS File Manager", "View bundled/local recordings and import a URL.", function()
        OpenTASFileManager()
    end)

    tasSec:NewDropdown("Operation Mode", "What to do on target maps.", {"Farm", "Play", "Record"}, function(current)
        State.Mode = current
        Alert("Mode set to: " .. current, "Info")
    end)

    tasSec:NewToggle("Enable TAS map selection", "Vote for maps matching the selected mode.", function(value) State.SelectTASMaps = value end)
    tasSec:NewToggle("Prefer maps missing TAS", "Prioritize unrecorded maps when eligible.", function(value) State.PreferMissingTAS = value end)

    tasSec:NewTextBox("Target Map Snipe", "Exact Name (e.g. Sandswept Ruins)", function(txt)
        State.TargetMapName = txt
        Alert("Target map set to: " .. txt, "System")
    end)

    tasSec:NewKeybind("Toggle Swim Mode [TAS]", "Simulate water state for TAS.", Enum.KeyCode.Y, function()
        State.SwimEnabled = not State.SwimEnabled
        Alert("TAS Swim Mode " .. (State.SwimEnabled and "Enabled" or "Disabled"), "Info")
    end)

    tasSec:NewButton("Force Load TAS Player", "Manually inject TAS Player (If joined late).", function()
        ExecuteSecondaryScript("Play")
    end)

    tasSec:NewButton("Create TAS", "Launch TAS Creator script immediately.", function()
        ExecuteSecondaryScript("Record")
    end)

    tasSec:NewButton("Load Infinite Yield", "Loads Infinite Yield Admin Script", function()
        LoadExternalScript("https://raw.githubusercontent.com/edgeiy/infiniteyield/master/source")
        Alert("Infinite Yield Loaded.", "Info")
    end)

    -- === 2. AUTO FARM TAB (BLATANT) ===
    local autoTab = Window:NewTab("Auto Farm")
    local mainSec = autoTab:NewSection("Blatant Auto Farm Options")

    mainSec:NewToggle("Enable Auto-Farm", "Instantly teleports to hitboxes to win.", function(state)
        State.PracticeMap = nil
        State.AutoFarm = state
        getgenv().TomatoAutoFarm = state
        Alert("Blatant Auto Farm " .. (state and "Enabled" or "Disabled"), state and "Success" or "Error")
    end)

    mainSec:NewToggle("Play after buttons", "Return to spawn after buttons; finish manually.", function(value) State.PlayAfterButtons = value end)
    mainSec:NewSlider("Farm start delay", "Wait before navigating (seconds).", 30, 0, function(value) State.StartDelay = value end)
    mainSec:NewToggle("Reset after escape", "Reset only after an escape confirmation.", function(value) State.ResetAfterEscape = value end)
    mainSec:NewSlider("Reset delay", "Wait after confirmed escape (seconds).", 10, 0, function(value) State.ResetDelay = value end)

    local advancedSec = autoTab:NewSection("Optional Quickfarm Features")
    if not advancedOK then advancedSec:NewLabel("DISABLED: advanced module failed to initialize") end
    for _, name in ipairs({"Fast load", "Forced win", "Direct buttons", "Auto boost", "Manual boost", "Smart challenges", "Timed challenges"}) do
        local feature = Advanced.guard.features[name]
        if feature then
            if not feature.available then
                advancedSec:NewLabel("DISABLED: " .. name .. " — " .. tostring(feature.reason))
            else
                local label = advancedSec:NewLabel(name .. ": available, OFF")
                feature.changed = function(f)
                    if label and type(label.UpdateLabel) == "function" then
                        label:UpdateLabel(f.available and (name .. (f.enabled and ": ON" or ": OFF")) or ("DISABLED: " .. name .. " — " .. f.reason))
                    end
                end
                if name == "Manual boost" then
                    advancedSec:NewButton("Full boost (20 gems expected)", "Send four boost requests; spends gems.", Advanced.manualBoost)
                else
                    local description = "Optional; automatically disabled if its checks fail."
                    if name == "Auto boost" then description = "Spends approximately 20 gems each new round." end
                    if name == "Smart challenges" then description = "Costs coins. Uses description heuristics, not guaranteed impossibility." end
                    if name == "Timed challenges" then description = "Cycles challenges every 10 minutes; may spend coins." end
                    advancedSec:NewToggle(name, description, function(value) Advanced.enable(name, value) end)
                end
            end
        end
    end

    mainSec:NewToggle("Auto Collect (Page-Escapee)", "Collects LostPage and Escapee automatically.", function(state)
        State.AutoCollect = state
        Alert("Auto Collect " .. (state and "Enabled" or "Disabled"), "Info")
    end)

    mainSec:NewToggle("Auto Rebirth", "Automatically attempts to rebirth every 60 seconds.", function(state)
        State.AutoRebirth = state
        Alert("Auto Rebirth " .. (state and "Enabled" or "Disabled"), state and "Success" or "Error")
    end)

    mainSec:NewDropdown("Max Difficulty Level", "Skip maps harder than this.", {"None", "Crazy+", "Crazy", "Insane", "Hard", "Normal", "Easy"}, function(current)
        State.TargetDifficulty = current
        Alert("Max Difficulty set to: " .. current, "System")
    end)

    mainSec:NewToggle("Enforce Difficulty Limiter", "Suicides to skip if map is too hard.", function(state)
        State.EnforceDifficulty = state
        Alert("Difficulty Limiter " .. (state and "Enabled" or "Disabled"), "Info")
    end)

    -- === 3. LOCAL PLAYER TAB ===
    local charTab = Window:NewTab("Local Player")
    local moveSec = charTab:NewSection("Movement Settings")

    moveSec:NewSlider("WalkSpeed", "Changes player speed.", 100, 20, function(s)
        State.WalkSpeed = math.max(1, s)
    end)

    moveSec:NewSlider("JumpPower", "Changes jump height.", 200, 50, function(s)
        State.JumpPower = math.max(0, s)
    end)

    -- === 4. BLATANT TAB ===
    local blatantTab = Window:NewTab("Blatant")
    local exploitSec = blatantTab:NewSection("Exploits")

    exploitSec:NewKeybind("Infinite Air / GodMode", "Prevents drowning / God Mode.", Enum.KeyCode.R, function()
        State.GodMode = not State.GodMode
        Alert("Infinite Air " .. (State.GodMode and "Enabled" or "Disabled"), State.GodMode and "Success" or "Error")
    end)

    exploitSec:NewKeybind("Noclip", "Allows walking through walls.", Enum.KeyCode.G, function()
        State.Noclip = not State.Noclip
        Noclip(State.Noclip)
        Alert("Noclip " .. (State.Noclip and "Enabled" or "Disabled"), State.Noclip and "Success" or "Error")
    end)

    exploitSec:NewKeybind("Air Jump", "Allows jumping while mid-air.", Enum.KeyCode.M, function()
        State.AirJump = not State.AirJump
        Alert("Air Jump " .. (State.AirJump and "Enabled" or "Disabled"), State.AirJump and "Success" or "Error")
    end)

    -- === 5. OTHER TAB ===
    local miscTab = Window:NewTab("Other")
    local utilSec = miscTab:NewSection("Utilities")
    utilSec:NewToggle("Game alerts", "Show status messages in the game alert feed.", function(value) State.AlertsEnabled = value end)
    utilSec:NewButton("Stop automation", "Stop farming, playback and optional quickfarm actions.", function()
        State.AutoFarm, State.AutoPlay, State.SelectTASMaps, State.AutoCollect, State.AutoRebirth = false, false, false, false, false
        getgenv().TomatoAutoFarm = false
        if getgenv().FloodGUIStopPlayer then pcall(getgenv().FloodGUIStopPlayer, false) end
        Advanced.cleanup()
        Alert("Automation stopped.", "Info")
    end)

    utilSec:NewKeybind("Toggle UI", "Toggles the GUI visibility.", Enum.KeyCode.J, function()
        State.UIEnabled = not State.UIEnabled
        Kavo:ToggleUI()
        Alert("UI " .. (State.UIEnabled and "Enabled" or "Disabled"), "Info")
    end)

    utilSec:NewToggle("Auto-Leave", "Automatically leaves if another player joins.", function(state)
        State.AutoLeave = state
        Alert("Auto-Leave " .. (state and "Enabled" or "Disabled"), "Info")
    end)

    utilSec:NewButton("Rejoin Server", "Teleports you to a new server of the same game.", function()
        Alert("Attempting to rejoin...", "Info")
        pcall(TeleportService.Teleport, TeleportService, game.PlaceId, LocalPlayer)
    end)

    -- === 6. CREDITS TAB ===
    local credTab = Window:NewTab("Credits")
    local credSec = credTab:NewSection("Credits & Info")
    credSec:NewLabel("TAS System: Tomato (Base by Voiz#5668)")
    credSec:NewLabel("Reverse Engineering/Base GUI: Tomato")
    credSec:NewLabel("UI Library: xHeptc (Kavo)")

    credSec:NewButton("Copy Support Server Invite", "Copies Discord invite.", function()
        if setclipboard then
            pcall(setclipboard, CONFIG.DISCORD_INVITE)
            Alert("Discord invite copied to clipboard!", "Success")
        else
            Alert("Clipboard access not supported by your exploit.", "Warning")
        end
    end)
end

InitializeUI()
Alert("FloodGUI Loaded Successfully!", "Rainbow")
