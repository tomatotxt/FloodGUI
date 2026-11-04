local IsLaunchCurrent, Own = ...
IsLaunchCurrent = IsLaunchCurrent or function() return true end
Own = Own or function() end
if not IsLaunchCurrent() then return end
local BaseRuntime = assert(getgenv().FloodGUIRuntime, "Start FloodGUI through loader.lua")
local Runtime = table.clone(BaseRuntime)
function Runtime.run(path, ...)
    return BaseRuntime.runScoped(IsLaunchCurrent, path, ...)
end
local Compat = Runtime.run("compat.luau")()

local Recordings = Runtime.run("TAS/recordings.luau")(Runtime)
local Timeline = Runtime.run("TAS/PLAYER/timeline.luau")
local Buffer = Runtime.run("TAS/CREATOR/recording-buffer.luau")
local Environment = Runtime.run("TAS/CREATOR/environment.luau")
local ZiplineModule = Runtime.run("zipline.luau")
local ZiplineAssistant = ZiplineModule(LocalPlayer, game:GetService("ReplicatedStorage"):FindFirstChild("Remote"), AddConnection)
local CharacterOverrides = Runtime.run("overrides.luau")()
Own(CharacterOverrides.restoreAll)
local UI_API_PATH = "ui/creator.luau"
if not IsLaunchCurrent() then return end
getgenv().TAS_Active = true
getgenv().FloodGUICreatorOwner = IsLaunchCurrent
Own(function()
    if getgenv().FloodGUICreatorOwner==IsLaunchCurrent then getgenv().TAS_Active=false end
end)

print("FloodGUI TAS Creator loaded")

-- // NEW CONFIGURATIONS //
getgenv().ExtremeSmoothing = false
getgenv().TargetSmoothingFPS = 24
getgenv().ShowTASPathDuringPlayback = false
getgenv().PlaybackCamera = false
getgenv().ShowVelocityPredictor = false
getgenv().EnableAutoSwim = true
getgenv().AutoSaveOnExit = true

local Keybinds = {
    AddSavestate = "One",
    RemoveSavestate = "Two",
    BackSavestate = "Three",
    GoFrameBack = "Four",
    GoFrameForward = "Five",
    SaveRun = "Six",
    UserPause = "CapsLock",
    CollisionToggler = "C",
    ResetToNormal = "Delete",
    ViewTAS = "Zero",
    Resync = "F8",
    EnvPause = "Equals",
    ToggleTimeReset = "Seven",
    DebugToggler = "V",
    AutoSwimToggler = "T" -- Added Auto-Swim toggle keybind (T)
}

-- // SERVICES //
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- // ALERT SYSTEM //
local NewAlert = nil
local function SetupAlerts()
    local GameScript = LocalPlayer.PlayerScripts:WaitForChild("CL_MAIN_GameScript", 5)
    if GameScript then
        local success, env = pcall(getsenv, GameScript)
        if success and type(env) == "table" and type(env.newAlert) == "function" then NewAlert = env.newAlert end
    end
end
SetupAlerts()
if not IsLaunchCurrent() then return end

local function SendAlert(msg, color)
    if NewAlert then
        Compat.gameAlert(NewAlert, msg, color, 1.5, nil)
    else
        local GameScript = LocalPlayer.PlayerScripts:FindFirstChild("CL_MAIN_GameScript")
        if GameScript then
            local s, e = pcall(getsenv, GameScript)
            if s and type(e) == "table" and type(e.newAlert) == "function" then
                NewAlert = e.newAlert
                Compat.gameAlert(NewAlert, msg, color, 1.5, nil)
            end
        end
    end
end

SendAlert("FloodGUI TAS Creator Initialized", Color3.fromRGB(238, 58, 48))

-- // BYPASSES //
if type(hookmetamethod)=="function" and type(checkcaller)=="function" and not getgenv().FloodGUICreatorHookApplied then
local OldIndex
OldIndex = hookmetamethod(game, "__index", function(self, key)
    if not checkcaller() then
        if IsLaunchCurrent() and getgenv().TAS_Active and key == "Archivable" then return false end
    end
    return OldIndex(self, key)
end)
getgenv().FloodGUICreatorHookApplied = true
end

-- Let FE2's character controller query swimming without a global Position hook.
if BaseRuntime.NativeSwim then
    local releaseSwim=BaseRuntime.NativeSwim.override(function()
        if IsLaunchCurrent() and getgenv().TAS_Active and getgenv().EnableAutoSwim
            and getgenv().IsSwimming and not getgenv().PauseSpoofing then return true end
    end)
    Own(releaseSwim)
end

pcall(function() ReplicatedStorage.Remote.ReqPasskey:InvokeServer() end)

-- // VARIABLES //
local CurrentAnim = {}
local Savestates = {}
local Frames = {}
local TimeOffset = 0
local PreviewOffset = 0
local IsPaused = true
local EnvPaused = false
local PauseStart
local OriginalPlayAnim
local AnimEnv
local RunStart
local SavedVelocity = Vector3.new(0, 0, 0)
local Connections = {}
local Stopped = false

-- Flags
local IsPreviewingForward = false
local IsPreviewingBackward = false
local IsAdvancingFrame = false
local IsRewinding = false
local IsViewingTAS = false
local AutoSaved = false
local LastAutoSaveAttempt = -math.huge
local AutoResetEnv = false

-- Recorder & Map
local ClonedMap
local RopeTable
local MapX, MapY, MapZ
local MapCapture, LightingCapture
local LastMapTime = 0

-- Button Order Tracking
local RecordedButtonSequence = {}
local OrderedButtonRegistry = {}

-- Lighting Storage
local SavedLighting = {Props = {}, Children = {}}
local LightingCaptured = false

-- Recording Cap
local RecordAccumulator = 0
local TARGET_FPS = 60
local RECORD_INTERVAL = 1 / TARGET_FPS

-- Auto-Swim
getgenv().IsSwimming = false
getgenv().PauseSpoofing = false -- Track zipline contact to pause position spoofing
local WaterParts = {}

-- Button Tracking
local TotalButtons = {}
local ButtonRegistry = {}

-- // NEW VISUALIZER VARIABLES //
local OriginalVisuals = setmetatable({}, { __mode = "k" })
local DebugActive = false
local TrajectoryFolder = Instance.new("Folder", workspace)
Own(function() TrajectoryFolder:Destroy() end)
TrajectoryFolder.Name = "TAS_Trajectory"
local TrajectoryLines = {}
local PathLines = {}
local SelectedFileToLoad = ""

-- // UI Variables //
local TAS_UI = Runtime.run(UI_API_PATH)
local UI_Elements = nil
local TimeText, FrameCountLabel, StatusLabel, MapEventLabel

-- // DATA PACKING (OPTIMIZATION) //
-- PACK_FORMAT includes a trailing byte for flags: bit 0 = Sliding, bit 1 = Swimming
local PACK_FORMAT = "d" .. string.rep("f", 28) .. "sB"
local LEGACY_PACK_FORMAT = "d" .. string.rep("f", 28) .. "s"

local function PackFrame(Time, Vel, CF, CamCF, Anim, isSliding, isSwimming)
    local animName = Anim and Anim[1] or "idle"
    local animSpeed = Anim and Anim[2] or 0
    local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = CF:GetComponents()
    local cx, cy, cz, cR00, cR01, cR02, cR10, cR11, cR12, cR20, cR21, cR22 = CamCF:GetComponents()
    local flags = (isSliding and 1 or 0) + (isSwimming and 2 or 0)
    return string.pack(PACK_FORMAT, Time, Vel.X, Vel.Y, Vel.Z, x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22, cx, cy, cz, cR00, cR01, cR02, cR10, cR11, cR12, cR20, cR21, cR22, animSpeed, animName, flags)
end

local function UnpackFrame(data)
    local ok, t, vx, vy, vz, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, cm1, cm2, cm3, cm4, cm5, cm6, cm7, cm8, cm9, cm10, cm11, cm12, asp, anm, flags = pcall(string.unpack, PACK_FORMAT, data)
    if not ok then
        t, vx, vy, vz, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, cm1, cm2, cm3, cm4, cm5, cm6, cm7, cm8, cm9, cm10, cm11, cm12, asp, anm = string.unpack(LEGACY_PACK_FORMAT, data)
        flags = 0
    end
    return {
        Time = t, Velocity = Vector3.new(vx, vy, vz),
        CFrame = CFrame.new(c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12),
        CameraCFrame = CFrame.new(cm1, cm2, cm3, cm4, cm5, cm6, cm7, cm8, cm9, cm10, cm11, cm12),
        Animation = {anm, asp},
        Sliding = bit32.band(flags, 1) ~= 0,
        Swimming = bit32.band(flags, 2) ~= 0
    }
end

-- // HELPER FUNCTIONS //
local function AddConnection(con)
    if Stopped then con:Disconnect() else table.insert(Connections, con) end
    Own(function() con:Disconnect() end)
    return con
end

local function isRandomString(str)
    if #str == 0 then return false end
    for i = 1, #str do
        local ltr = str:sub(i, i)
        if ltr:lower() == ltr then return false end
    end
    return true
end

local function GetUUID(part)
    if not part then return nil end
    local id = part:GetAttribute("TAS_UUID")
    if not id then
        id = HttpService:GenerateGUID(false)
        part:SetAttribute("TAS_UUID", id)
    end
    return id
end

local function ToggleCollision()
    local mouse = LocalPlayer:GetMouse()
    if mouse and mouse.Target then
        local target = mouse.Target
        target.CanCollide = not target.CanCollide
        SendAlert("Collision " .. (target.CanCollide and "Enabled" or "Disabled"), Color3.fromRGB(255, 255, 0))
    end
end

local function IsPointInPart(part, point)
    local rel = part.CFrame:PointToObjectSpace(point)
    local halfSize = part.Size / 2
    return math.abs(rel.X) <= halfSize.X and math.abs(rel.Y) <= halfSize.Y and math.abs(rel.Z) <= halfSize.Z
end

-- [[ ENTIRE BOUNDING BOX WATER DETECTION ]]
local function IsPartEntirelyInPart(containerPart, targetPart)
    local tCF = targetPart.CFrame
    local tSize = targetPart.Size / 2
    local cCFInv = containerPart.CFrame:Inverse()
    local cSize = containerPart.Size / 2

    local corners = {
        tCF * Vector3.new( tSize.X,  tSize.Y,  tSize.Z),
        tCF * Vector3.new( tSize.X,  tSize.Y, -tSize.Z),
        tCF * Vector3.new( tSize.X, -tSize.Y,  tSize.Z),
        tCF * Vector3.new( tSize.X, -tSize.Y, -tSize.Z),
        tCF * Vector3.new(-tSize.X,  tSize.Y,  tSize.Z),
        tCF * Vector3.new(-tSize.X,  tSize.Y, -tSize.Z),
        tCF * Vector3.new(-tSize.X, -tSize.Y,  tSize.Z),
        tCF * Vector3.new(-tSize.X, -tSize.Y, -tSize.Z)
    }

    for _, corner in ipairs(corners) do
        local rel = cCFInv * corner
        if math.abs(rel.X) > cSize.X or math.abs(rel.Y) > cSize.Y or math.abs(rel.Z) > cSize.Z then
            return false
        end
    end
    return true
end

local function GetPlayerCFrame()
    local Root = LocalPlayer.Character.HumanoidRootPart
    local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = Root.CFrame:GetComponents()
    return CFrame.new(x - MapX, y - MapY + 1000, z - MapZ, R00, R01, R02, R10, R11, R12, R20, R21, R22)
end

local LastRecordedTime = 0
local function IsCharacterSliding()
    local character = LocalPlayer.Character
    if not character then return false end
    if CurrentAnim and CurrentAnim[1] == "slide" then return true end
    local root = character:FindFirstChild("HumanoidRootPart")
    if root and root.Size.Y <= 1.2 then return true end
    local hum = character:FindFirstChild("Humanoid")
    if hum and hum.HipHeight <= -1 then return true end
    if root then
        local sp = root:FindFirstChild("SlideParticles")
        if sp and sp.Enabled == true then return true end
    end
    return false
end

local function IsCharacterSwimming()
    local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local clMain = playerScripts and playerScripts:FindFirstChild("CL_MAIN_GameScript")
    local isSwimmingFn = clMain and clMain:FindFirstChild("isSwimming")
    if isSwimmingFn and isSwimmingFn:IsA("RemoteFunction") or (isSwimmingFn and isSwimmingFn:IsA("BindableFunction")) then
        local ok, val = pcall(function() return isSwimmingFn:Invoke() end)
        if ok and type(val) == "boolean" then return val end
    end
    if getgenv().IsSwimming ~= nil then return getgenv().IsSwimming end
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if root and WaterParts then
        for _, wp in ipairs(WaterParts) do
            if IsPartEntirelyInPart(wp, root) then return true end
        end
    end
    return false
end

local function CaptureFrameData()
    local rawTime = os.clock() - RunStart - TimeOffset
    local frameTime = math.max(LastRecordedTime, rawTime)
    LastRecordedTime = frameTime
    local isSliding = IsCharacterSliding()
    local isSwimming = IsCharacterSwimming()
    return PackFrame(
        frameTime,
        LocalPlayer.Character.HumanoidRootPart.Velocity,
        GetPlayerCFrame(),
        workspace.CurrentCamera.CFrame,
        CurrentAnim,
        isSliding,
        isSwimming
    )
end

-- [[ COMPILER & FILE LOGIC ]] --
local function CompileTASData()
    local Data = {}
    local function AddList(list)
         for j = 1, #list do
            local FramePacked = list[j]
            if type(FramePacked) == "string" then
                local F = UnpackFrame(FramePacked)
                local rx, ry, rz = F.CFrame:ToEulerAnglesXYZ()
                local crx, cry, crz = F.CameraCFrame:ToEulerAnglesXYZ()
                table.insert(Data, {
                    AAnimationChanged = F.Animation[2],
                    CCameraCFrame = {F.CameraCFrame.X - MapX, F.CameraCFrame.Y - (MapY - 1000), F.CameraCFrame.Z - MapZ, crx, cry, crz},
                    CCFrame = {F.CFrame.X, F.CFrame.Y, F.CFrame.Z, rx, ry, rz},
                    VVelocity = {F.Velocity.X, F.Velocity.Y, F.Velocity.Z},
                    AAnimation = F.Animation or {"walk", 0.1},
                    time = F.Time,
                    Sliding = F.Sliding == true or nil,
                    Swimming = F.Swimming == true or nil
                })
            end
         end
    end
    for i = 1, #Savestates do AddList(Savestates[i]) end
    AddList(Frames)
    return Data
end

local function SaveRecording(name, frames)
    local actualMap = ClonedMap and ClonedMap:FindFirstChild("Settings")
    local saved, path = pcall(Recordings.save, name, frames, {author = LocalPlayer.Name, fps = TARGET_FPS,
        mapName = actualMap and actualMap:GetAttribute("MapName") or name})
    if not saved then
        SendAlert("Recording was not saved: " .. tostring(path) .. ". Your frames are still in the creator.", Color3.fromRGB(255,106,96))
        return nil
    end
    SendAlert("Saved binary: " .. path, Color3.fromRGB(0, 255, 0))
    return path
end

local function RefreshFileList()
    if not UI_Elements then return end
    local names = {}
    local ok, message = pcall(function()
        for _, file in ipairs(listfiles(Runtime.path("TAS FILES"))) do
            if file:match("%.json$") or file:match("%.fe2tomatas$") then table.insert(names, file:match("([^/\\]+)$")) end
        end
    end)
    if not ok then SendAlert("Local file list unavailable: " .. tostring(message), Color3.fromRGB(255,170,0)) end
    table.sort(names)
    UI_Elements.SetFiles(names, function(filename)
        SelectedFileToLoad = filename or ""
        UI_Elements.SelectedLabel.Text = "Selected: " .. (filename or "None")
    end)
end

-- // CORE LOGIC / FORWARD DECLARATIONS //
local TogglePause, AddSavestate, RemoveSavestate, LoadLastSavestate, RewindFrame, StepForward, PlaybackTAS, ResetToNormal, RewindLoop, FrameAdvanceLoop, Noclip
local StepInProgress = false
local StopPreview
local ReleaseTouchControls
local CreatorActions = {}

-- [[ UI API LOADING & BINDING ]] --
local function BindUI()
    if not UI_Elements or not UI_Elements.Buttons then return end
    local btns = UI_Elements.Buttons
    local actions = CreatorActions
    local function BindButton(name, callback)
        actions[name] = callback
        UI_Elements.BindAction(name, callback)
    end

    -- Controls
    BindButton("Pause", TogglePause)
    BindButton("AddState", AddSavestate)
    BindButton("RemState", RemoveSavestate)
    BindButton("LoadState", function() task.spawn(LoadLastSavestate) end)
    BindButton("StepBack", RewindFrame)
    BindButton("StepFwd", StepForward)
    BindButton("Resync", function() IsPreviewingForward = false; IsPreviewingBackward = false; PreviewOffset = 0; SendAlert("Visuals Resynced", Color3.fromRGB(0, 255, 255)) end)
    BindButton("PlayTAS", function() if not IsViewingTAS then PlaybackTAS(CompileTASData()) end end)
    BindButton("Collision", ToggleCollision)
    BindButton("Stop", function() task.spawn(ResetToNormal) end)

    -- Configs / Vis
    BindButton("DebugView", function()
        DebugActive = not DebugActive
        if DebugActive then
            if ClonedMap then
                for _, v in pairs(ClonedMap:GetDescendants()) do
                    if v:IsA("BasePart") then
                        OriginalVisuals[v] = {Color = v.Color, Transparency = v.Transparency}
                        if v.Name == "Hitbox" or v.Name:find("_Water") then
                            v.Color = Color3.fromHSV(math.random(), 1, 1); v.Transparency = 0.2
                        else
                            v.Color = Color3.new(0.4, 0.4, 0.4); if v.Transparency == 1 then v.Transparency = 0.8 end
                        end
                    end
                end
            end
        else
            for part, props in pairs(OriginalVisuals) do if part and part.Parent then part.Color = props.Color; part.Transparency = props.Transparency end end
            OriginalVisuals = setmetatable({}, { __mode = "k" })
        end
    end)
    BindButton("SmoothMode", function()
        getgenv().ExtremeSmoothing = not getgenv().ExtremeSmoothing
    end)
    BindButton("PathTracing", function()
        getgenv().ShowTASPathDuringPlayback = not getgenv().ShowTASPathDuringPlayback
    end)
    BindButton("Trajectory", function()
        getgenv().ShowVelocityPredictor = not getgenv().ShowVelocityPredictor
    end)
    BindButton("CamMode", function()
        getgenv().PlaybackCamera = not getgenv().PlaybackCamera
    end)
    BindButton("EnvSync", function()
        AutoResetEnv = not AutoResetEnv
    end)

    -- Added: Backwards compatible registration for AutoSwim button logic
    if btns.AutoSwim then
        BindButton("AutoSwim", function()
            getgenv().EnableAutoSwim = not getgenv().EnableAutoSwim
            SendAlert("Auto-Swim " .. (getgenv().EnableAutoSwim and "Enabled" or "Disabled"), getgenv().EnableAutoSwim and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0))
        end)
    end

    BindButton("EnvPause", function() EnvPaused = not EnvPaused end)
    BindButton("AutoSave", function() getgenv().AutoSaveOnExit = not getgenv().AutoSaveOnExit end)

    -- Files
    BindButton("SaveRun", function()
        local name = (UI_Elements.SaveBox and UI_Elements.SaveBox.Text ~= "") and UI_Elements.SaveBox.Text or (ClonedMap and ClonedMap.Settings:GetAttribute("MapName") or "MyRun")
        if SaveRecording(name, CompileTASData()) then RefreshFileList() end
    end)
    BindButton("RefreshList", RefreshFileList)
    BindButton("LoadRun", function()
        if SelectedFileToLoad == "" then SendAlert("No file selected!", Color3.fromRGB(255,0,0)); return end
        local ok, message = pcall(function() PlaybackTAS(Recordings.loadFile(SelectedFileToLoad)) end)
        if not ok then SendAlert(tostring(message), Color3.fromRGB(255,106,96)) end
    end)
    BindButton("ConvertBinary", function()
        if SelectedFileToLoad == "" then return end
        local ok, result = pcall(Recordings.convertFile, SelectedFileToLoad, "binary")
        SendAlert(ok and ("Converted: " .. result) or tostring(result), ok and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0))
        RefreshFileList()
    end)
    BindButton("ExportJSON", function()
        if SelectedFileToLoad == "" then return end
        local ok, result = pcall(Recordings.convertFile, SelectedFileToLoad, "json")
        SendAlert(ok and ("Exported: " .. result) or tostring(result), ok and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0))
        RefreshFileList()
    end)

    local padActions = {}
    for _, item in ipairs({
        {"Pause", "Pause"}, {"Save state", "AddState"}, {"Remove state", "RemState"},
        {"Load state", "LoadState"}, {"Save run", "SaveRun"}, {"Preview", "PlayTAS"},
        {"Collision", "Collision"}, {"Resync", "Resync"}, {"Auto-swim", "AutoSwim"},
        {"Debug view", "DebugView"}, {"Environment sync", "EnvSync"}, {"Stop creator", "Stop"},
    }) do
        table.insert(padActions, {name = item[1], press = actions[item[2]]})
    end
    table.insert(padActions, {name = "Hold rewind", press = function()
        IsAdvancingFrame = false
        if not IsRewinding then RewindLoop() end
    end, release = function() IsRewinding = false end})
    table.insert(padActions, {name = "Hold advance", press = function()
        if not IsRewinding then FrameAdvanceLoop() end
    end, release = function() IsAdvancingFrame = false end})
    table.insert(padActions, {name = "Visual forward", press = function() IsPreviewingForward = true end,
        release = function() IsPreviewingForward = false end})
    table.insert(padActions, {name = "Visual back", press = function() IsPreviewingBackward = true end,
        release = function() IsPreviewingBackward = false end})
    table.insert(padActions, {name = "Pause map", press = function() EnvPaused = not EnvPaused end})
    local pad
    pad, ReleaseTouchControls = UI_Elements.CreateTouchControls(padActions, AddConnection)
    BindButton("TouchControls", function() UI_Elements.PadWindow:Toggle() end)
    UI_Elements.SetKeybinds(Keybinds)
    RefreshFileList()
end

local function LoadUI(MapName)
    if UI_Elements and UI_Elements.ScreenGui and UI_Elements.ScreenGui.Parent then return end
    UI_Elements = TAS_UI.Create()
    TimeText = UI_Elements.TimeText
    FrameCountLabel = UI_Elements.FrameCount
    StatusLabel = UI_Elements.StatusText
    MapEventLabel = UI_Elements.MapEventInfo

    if MapName and MapEventLabel then MapEventLabel.Text = MapName end
    BindUI()
end

local function UpdateTimeDisplay(DisplayTime)
    if not TimeText then return end
    local m = math.floor(DisplayTime / 60)
    local s = math.floor(DisplayTime % 60)
    local ms = math.floor(DisplayTime * 1000 % 1000)
    TimeText.Text = string.format("%d:%02d.%03d", m, s, ms)
end

-- // LIGHTING MANAGER //
local function CaptureLighting()
    if LightingCaptured then return end
    SavedLighting.Props = {
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime, FogColor = Lighting.FogColor, FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart, GlobalShadows = Lighting.GlobalShadows,
        ExposureCompensation = Lighting.ExposureCompensation, TimeOfDay = Lighting.TimeOfDay
    }
    SavedLighting.Children = {}
    for _, child in ipairs(Lighting:GetChildren()) do
        local archived=child.Archivable
        child.Archivable=true
        local copy=child:Clone()
        child.Archivable=archived
        if copy then table.insert(SavedLighting.Children,copy) end
    end
    LightingCaptured = true
end

-- // MAP MONITOR //
local MonitorCon = workspace.Multiplayer.ChildAdded:Connect(function(child)
    if not getgenv().TAS_Active then return end
    if ClonedMap and (child.Name == "Map" or child.Name == "NewMap") then task.wait(); child:Destroy() end
end)
AddConnection(MonitorCon)

-- // MAP PLAYBACK ENGINE //
local function UpdateMapState(TargetTime)
    if EnvPaused then return end
    if MapCapture then MapCapture.seek(TargetTime) end
    if LightingCapture then LightingCapture.seek(TargetTime) end
    LastMapTime = TargetTime
end

-- // BUTTON SYNC LOGIC //
local function SyncButtonState(VisualTime, RealTime)
    for part, data in pairs(ButtonRegistry) do
        if data.IsPressed and data.TruePressTime > RealTime then
            data.IsPressed = false; data.PressTime = nil
        end
    end

    local NextIndex = 1
    for i = 1, #RecordedButtonSequence do
        local btnData = OrderedButtonRegistry[i]
        if btnData and not btnData.IsPressed then NextIndex = i; break end
        if i == #RecordedButtonSequence then NextIndex = i + 1 end
    end

    for part, data in pairs(ButtonRegistry) do
        local isVisuallyPressed = (data.TruePressTime and data.TruePressTime <= VisualTime)
        if isVisuallyPressed then data.SelectionBox.Color3 = Color3.fromRGB(0, 255, 0)
        elseif data.Order ~= 999 then
            if data.Order == NextIndex then data.SelectionBox.Color3 = Color3.fromRGB(255, 255, 0)
            elseif data.Order > NextIndex then data.SelectionBox.Color3 = Color3.fromRGB(255, 0, 0)
            else data.SelectionBox.Color3 = Color3.fromRGB(0, 255, 0) end
        else
            data.SelectionBox.Color3 = Color3.fromRGB(255, 140, 0)
        end
    end
end

local function HookAnimations()
    repeat
        if Stopped or not IsLaunchCurrent() then return end
        local character = LocalPlayer.Character
        if not character then return end
        local script = character:WaitForChild("Animate", 10)
        if Stopped or not IsLaunchCurrent() then return end
        assert(script, "Character animation controller is not ready")
        AnimEnv = getsenv(script)
        task.wait()
    until AnimEnv.playAnimation ~= nil
    if Stopped or not IsLaunchCurrent() then return end
    OriginalPlayAnim = AnimEnv.playAnimation
    AnimEnv.playAnimation = function(anim, speed)
        if not IsPaused then
            CurrentAnim = {anim, speed}
            OriginalPlayAnim(CurrentAnim[1], CurrentAnim[2], LocalPlayer.Character.Humanoid)
        end
    end
end

-- // CLEANUP //
function ResetToNormal()
    if Stopped then return end
    Stopped = true
    if StopPreview then StopPreview(false) end
    if ReleaseTouchControls then ReleaseTouchControls() end
    IsRewinding, IsAdvancingFrame, IsPreviewingForward, IsPreviewingBackward, IsViewingTAS = false, false, false, false, false
    if getgenv().FloodGUICreatorOwner == IsLaunchCurrent then
        getgenv().TAS_Active = false
        getgenv().FloodGUICreatorOwner = nil
    end
    getgenv().IsSwimming = false
    getgenv().PauseSpoofing = false
    getgenv().EnableAutoSwim = false

    -- Disconnect all event listeners safely
    for _, con in pairs(Connections) do
        pcall(function() con:Disconnect() end)
    end
    Connections = {}
    if MapCapture then MapCapture.dispose(); MapCapture = nil end
    if LightingCapture then LightingCapture.dispose(); LightingCapture = nil end

    -- Restore original animation engine
    if AnimEnv and OriginalPlayAnim then
        pcall(function()
            AnimEnv.playAnimation = OriginalPlayAnim
        end)
    end

    -- Restore native ambient lighting properties
    if LightingCaptured and SavedLighting.Props then
        pcall(function()
            for prop, val in pairs(SavedLighting.Props) do
                Lighting[prop] = val
            end
            Lighting:ClearAllChildren()
            for _, c in ipairs(SavedLighting.Children) do
                c:Clone().Parent = Lighting
            end
        end)
    end

    -- Clean up path & trajectory rendering elements
    for _, line in ipairs(TrajectoryLines) do pcall(function() line:Destroy() end) end
    TrajectoryLines = {}
    for _, line in ipairs(PathLines) do pcall(function() line:Destroy() end) end
    PathLines = {}
    if TrajectoryFolder then pcall(function() TrajectoryFolder:Destroy() end) end

    -- Release the character values this editor actually owned.
    pcall(function() Noclip(false) end)
    CharacterOverrides.restoreAll()
    pcall(function()
        local Root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if Root then Root.Anchored = false end
    end)

    TotalButtons = {}; ButtonRegistry = {}; OrderedButtonRegistry = {}; RecordedButtonSequence = {}
    SavedLighting = {Props = {}, Children = {}}; LightingCaptured = false; AutoSaved = false

    if ClonedMap then pcall(function() ClonedMap:Destroy() end); ClonedMap = nil end
    if UI_Elements then pcall(UI_Elements.Destroy) end
    UI_Elements = nil

    -- Clear physical character state variables through standard reset
    pcall(function() LocalPlayer.Character:BreakJoints() end)
    SendAlert("TAS Creator Stopped", Color3.fromRGB(255, 0, 0))
    Own(nil)
end
getgenv().FloodGUIStopCreator = ResetToNormal
Own(ResetToNormal)
AddConnection(RunService.Heartbeat:Connect(function()
    if not IsLaunchCurrent() and not Stopped then ResetToNormal() end
end))

-- // CORE LOGIC IMPLEMENTATIONS //
function TogglePause()
        if Stopped or IsViewingTAS or not RunStart then return end
        local character = LocalPlayer.Character
        local Root = character and character:FindFirstChild("HumanoidRootPart")
        if not Root then return end
        IsPaused = not IsPaused
        if IsPaused then
            SavedVelocity = Root.Velocity; Root.Anchored = true; PauseStart = os.clock()
            if ZiplineAssistant and ZiplineAssistant.setPaused then ZiplineAssistant.setPaused(true) end
            if StatusLabel then StatusLabel.Text = "PAUSED"; StatusLabel.TextColor3 = Color3.fromRGB(255, 200, 80) end
            SendAlert("Paused", Color3.fromRGB(255, 255, 0))
        else
            Root.Anchored = false; Root.Velocity = SavedVelocity; TimeOffset = TimeOffset + os.clock() - (PauseStart or os.clock())
            if ZiplineAssistant and ZiplineAssistant.setPaused then ZiplineAssistant.setPaused(false) end
            if StatusLabel then StatusLabel.Text = "PLAYING"; StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255) end
            RecordAccumulator = 0
            SendAlert("Unpaused", Color3.fromRGB(0, 255, 0))
        end
end

function LoadLastSavestate()
    if Stopped or IsViewingTAS or StepInProgress then return end
    local LastState = Savestates[#Savestates]
    if LastState then
        local FramePacked = LastState[#LastState]
        if not FramePacked then return end
        local Frame = UnpackFrame(FramePacked)

        Frames = {}; IsPaused = true; PreviewOffset = 0
        local Root = LocalPlayer.Character.HumanoidRootPart
        Root.Anchored = true; Root.CFrame = Frame.CFrame + Vector3.new(MapX, MapY - 1000, MapZ)
        Root.Velocity = Frame.Velocity; SavedVelocity = Frame.Velocity

        workspace.CurrentCamera.CFrame = Frame.CameraCFrame
        PauseStart = os.clock(); RunStart = os.clock() - Frame.Time; TimeOffset = 0
        LastRecordedTime = Frame.Time
        local isSwing = Frame.Animation and (Frame.Animation[1] == "swing" or Frame.Animation[1] == "zipline")
        if isSwing and ZiplineAssistant and ZiplineAssistant.seekPosition then
            ZiplineAssistant.seekPosition(Frame.CFrame.Position + Vector3.new(MapX, MapY - 1000, MapZ))
        elseif not isSwing and ZiplineAssistant and ZiplineAssistant.isZiplining and ZiplineAssistant.isZiplining() then
            ZiplineAssistant.cancel()
        end

        SyncButtonState(Frame.Time, Frame.Time); UpdateMapState(Frame.Time)

        OriginalPlayAnim(Frame.Animation[1], Frame.Animation[2], LocalPlayer.Character.Humanoid)
        if Frame.Animation[1] == "walk" then AnimEnv.setAnimationSpeed(0.76) end

        ToggleTASSlide(Frame.Sliding == true)
        getgenv().IsSwimming = (Frame.Swimming == true)

        task.spawn(function() UpdateTimeDisplay(Frame.Time) end)
        SendAlert("Savestate Loaded", Color3.fromRGB(0, 255, 255))
    end
end

function AddSavestate()
    if Stopped or IsViewingTAS or StepInProgress or #Frames == 0 then
        SendAlert("Record at least one new frame before adding a savestate", Color3.fromRGB(255,170,0))
        return
    end
    table.insert(Savestates, Frames); Frames = {}
    SendAlert("Savestate Added (" .. #Savestates .. ")", Color3.fromRGB(0, 255, 0))
end

local RemoveConfirm = false; local RemoveConfirmTime = 0
function RemoveSavestate()
    if Stopped or IsViewingTAS or StepInProgress then return end
    if not RemoveConfirm or (os.clock() - RemoveConfirmTime > 2) then
        RemoveConfirm = true; RemoveConfirmTime = os.clock()
        SendAlert("Press again to remove last state", Color3.fromRGB(255, 170, 0))
        return
    end
    RemoveConfirm = false
    if #Savestates > 1 then
        table.remove(Savestates); task.spawn(LoadLastSavestate)
        SendAlert("Savestate Removed", Color3.fromRGB(255, 0, 0))
    else
        SendAlert("Cannot remove initial state", Color3.fromRGB(255, 0, 0))
    end
end

function Noclip(Toggle)
    local char = LocalPlayer.Character
    if char then
        for i, v in char:GetChildren() do if v:IsA("BasePart") then v.CanCollide = not Toggle end end
    end
end

-- // ADVANCED MAP RECORDER //
local function SetupMap()
    local MP = game.Workspace.Multiplayer
    local LiveMap = MP:WaitForChild("Map", 9e9)
    local Settings = LiveMap:FindFirstChild("Settings")
    local MapName = Settings and Settings:GetAttribute("MapName") or "Unknown Map"

    SendAlert("Map Detected: " .. MapName, Color3.fromRGB(0, 255, 255))

    local Spawn = LiveMap:FindFirstChild("Spawn", true)

    if not Spawn then
        local target = nil; local connections = {}
        for _, child in ipairs(LiveMap:GetChildren()) do
            if child.Name == "Part" and child.Size.Y < 5 then
                table.insert(connections, child:GetPropertyChangedSignal("Rotation"):Connect(function()
                    target = child
                    for _, con in ipairs(connections) do con:Disconnect() end
                end))
            end
        end
        local deadline = os.clock() + 15
        repeat task.wait() until target or Stopped or not LiveMap.Parent or os.clock() >= deadline
        for _, con in ipairs(connections) do con:Disconnect() end
        if Stopped then return end
        assert(target, "Could not find the map spawn; creator setup stopped")
        LiveMap.PrimaryPart = target
    else
        LiveMap.PrimaryPart = Spawn
    end

    CaptureLighting()

    local Char = LocalPlayer.Character
    local Root = Char:WaitForChild("HumanoidRootPart")
    local Hum = Char:WaitForChild("Humanoid")
    local CaptureMovement={WalkSpeed=Hum.WalkSpeed,JumpPower=Hum.JumpPower}

    local Recording = true
    local StartTime = os.clock()
    local function captureTime() return os.clock() - StartTime end
    MapCapture = Environment.capture(LiveMap, GetUUID, captureTime, AddConnection)
    ClonedMap = MapCapture.root
    LightingCapture = Environment.capture(Lighting, GetUUID, captureTime, AddConnection, {
        replayRoot = Lighting,
        cloneRoot = function(source)
            local folder = Instance.new("Folder")
            for _, child in ipairs(source:GetChildren()) do child:Clone().Parent = folder end
            return folder
        end,
    })

    SendAlert("Scanning for Buttons...", Color3.fromRGB(255, 170, 0))
    Hum.Health = 99999 -- God Mode

    local Buttons = {}
    for i, MapObject in pairs(LiveMap:GetDescendants()) do
        if isRandomString(MapObject.Name) and MapObject:IsA("Model") then
            local Hitbox
            for i, Candidate in pairs(MapObject:GetChildren()) do
                if Candidate:IsA("BasePart") and tostring(Candidate.BrickColor) ~= "Medium stone grey" then Hitbox = Candidate; break end
            end
            if Hitbox and isRandomString(Hitbox.Name) then Hitbox.Name = "Hitbox"; table.insert(Buttons, MapObject) end
        end
    end

    SendAlert("Autofarm: Found " .. #Buttons .. " Buttons", Color3.fromRGB(0, 255, 0))
    SendAlert("Commencing Auto Farm", Color3.fromRGB(255, 170, 0))

    Noclip(true)
    local GodModeCon = AddConnection(RunService.RenderStepped:Connect(function() if Hum and Hum.Parent then Hum.Health = 99999 end end))

    local LastSafePos = CFrame.new(0, 1000, 0)
    local LiveExitRegion = nil
    local LastTargetButton = nil
    RecordedButtonSequence = {}; local ButtonPressTimings = {}

    while Recording and LiveMap.Parent and Hum.Health > 0 and getgenv().TAS_Active do
        Hum.Jump = true
        if not LiveExitRegion then LiveExitRegion = LiveMap:FindFirstChild("ExitRegion", true) end

        local FailedScan = true; Root.Anchored = true

        for i, Button in pairs(Buttons) do
            local ButtonHitbox = Button:FindFirstChild("Hitbox")
            if ButtonHitbox then
                local TouchFound = Button:FindFirstChild("TouchInterest", true)
                local GuiFound = Button:FindFirstChildWhichIsA("BillboardGui", true)

                if (TouchFound and GuiFound) then
                    FailedScan = false; Root.Anchored = false

                    -- Experimental creator traversal: timestamp after reaching the button.
                    local startPosition, targetPosition = Root.Position, ButtonHitbox.Position
                    local distance = (targetPosition - startPosition).Magnitude
                    local duration = distance / 20
                    local started = os.clock()
                    while duration > 0 and os.clock() - started < duration and Recording
                        and LiveMap.Parent and Hum.Health > 0 and getgenv().TAS_Active do
                        Root.CFrame = CFrame.new(startPosition:Lerp(targetPosition, math.clamp((os.clock() - started) / duration, 0, 1)))
                        Root.Velocity = (targetPosition - startPosition).Unit * 20
                        RunService.Heartbeat:Wait()
                    end
                    if not getgenv().TAS_Active or not LiveMap.Parent or Hum.Health <= 0 then break end
                    Root.CFrame = CFrame.new(targetPosition)
                    Root.Velocity = Vector3.zero
                    Hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    task.wait(0.1)
                    local uuid = GetUUID(ButtonHitbox)
                    if uuid and not table.find(RecordedButtonSequence, uuid) then
                        table.insert(RecordedButtonSequence, uuid)
                        ButtonPressTimings[uuid] = os.clock() - StartTime
                    end
                    LastTargetButton = Button
                end
            end
        end

        if FailedScan then
            Root.Anchored = false
            Hum:ChangeState(Enum.HumanoidStateType.Running)
            if LiveExitRegion then Root.CFrame = LiveExitRegion.CFrame + Vector3.new(0, 100, 0); Root.Velocity = Vector3.new(0,0,0)
            else Root.CFrame = LastSafePos + Vector3.new(0, 10, 0); Root.Velocity = Vector3.new(0,0,0) end
        else
            LastSafePos = Root.CFrame
        end
        RunService.Heartbeat:Wait()
    end

    Recording = false
    if GodModeCon then GodModeCon:Disconnect() end
    SendAlert("Recording Finished", Color3.fromRGB(255, 0, 0))
    Noclip(false)
    MapCapture.stop()
    LightingCapture.stop()
    if Stopped then return end

    SendAlert("Processing Map...", Color3.fromRGB(0, 200, 255))
    if LiveMap then LiveMap.Archivable = true; LiveMap:Destroy() end

    ClonedMap.Parent = workspace
    MapCapture.prepare()
    LightingCapture.prepare()
    UpdateMapState(0)

    if not ClonedMap.PrimaryPart then
         error("Captured map has no spawn; creator setup stopped")
    end

    local MapPos = ClonedMap.PrimaryPart.Position
    MapX, MapY, MapZ = MapPos.X, MapPos.Y, MapPos.Z

    LocalPlayer.Character:BreakJoints()
    SendAlert("Respawning...", Color3.fromRGB(255, 255, 0))
    LocalPlayer.CharacterAdded:Wait(); Char = LocalPlayer.Character; task.wait(1)
    if Stopped then return end
    local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remote")
    local removeWaiting = remote:FindFirstChild("RemoveWaiting")
    if removeWaiting then removeWaiting:FireServer() end

    local FE2Env = getsenv(Char:WaitForChild("FE2_Character"))
    local startZipline = FE2Env.startZipline
    if ZiplineAssistant and ZiplineAssistant.attach then
        ZiplineAssistant.attach(Char)
    end
    if RopeTable and #RopeTable >= 1 then
        if ZiplineAssistant and ZiplineAssistant.setCanonicalRopes then
            ZiplineAssistant.setCanonicalRopes(RopeTable)
        end
        SendAlert("Zipline Data Restored", Color3.fromRGB(0, 255, 255))
        task.spawn(function()
            while not Stopped and Char and Char.Parent and Char.Humanoid.Health >= 1 do
                local worked = pcall(setupvalue, startZipline, 2, RopeTable)
                if not worked then SendAlert("Zipline restoration disabled: game internals changed", Color3.fromRGB(255,170,0)); break end
                task.wait()
            end
        end)
    end

    Root = Char:WaitForChild("HumanoidRootPart"); Hum = Char:WaitForChild("Humanoid")
    CharacterOverrides.set(Hum,"WalkSpeed",0); CharacterOverrides.set(Hum,"JumpPower",0)
    task.wait(0.5)
    if Stopped then return end
    CharacterOverrides.set(Hum,"WalkSpeed",0); CharacterOverrides.set(Hum,"JumpPower",0)

    Root.CFrame = CFrame.new(ClonedMap.PrimaryPart.Position) + Vector3.new(0, ClonedMap.PrimaryPart.Size.Y/2, 0) + Vector3.new(0, Root.Size.Y/2, 0) + Vector3.new(0, Char["Left Leg"].Size.Y, 0)
    task.wait(0.5)
    if Stopped then return end
    Root.Anchored = true
    CharacterOverrides.set(Hum,"WalkSpeed",CaptureMovement.WalkSpeed)
    CharacterOverrides.set(Hum,"JumpPower",CaptureMovement.JumpPower)

    table.insert(Savestates, {PackFrame(0, Vector3.new(0,0,0), GetPlayerCFrame(), workspace.CurrentCamera.CFrame, {"idle", 0})})
    PauseStart = os.clock(); RunStart = os.clock(); HookAnimations()

    AddConnection(LocalPlayer.CharacterAdded:Connect(function(c)
        local anim = c:WaitForChild("Animate")
        if anim.Enabled then HookAnimations() end
    end))

    LoadUI(MapName)

    WaterParts = {}; TotalButtons = {}; ButtonRegistry = {}; OrderedButtonRegistry = {}
    local CheckedButtonParts = {}

    for _, obj in ipairs(ClonedMap:GetDescendants()) do
        if obj:IsA("BasePart") then
             if obj.Name:find("_Water") then
                 local waterState = obj:FindFirstChild("WaterState")
                 if not obj.Name:find("NoSwim") and obj:GetAttribute("NoSwim") ~= true
                     and not (waterState and waterState:GetAttribute("NoSwim") == true) then
                     table.insert(WaterParts, obj)
                 end
             end

             -- Dynamic Zipline / Rope Touch Listener
             if obj.Name == "RopeStart" then
                 AddConnection(obj.Touched:Connect(function(hit)
                     if hit.Parent == LocalPlayer.Character and not getgenv().PauseSpoofing then
                         getgenv().PauseSpoofing = true
                         -- Pause spoofing temporarily to let the engine register the zipline touch and attach the player
                         task.wait(0.5)
                         getgenv().PauseSpoofing = false
                     end
                 end))
             end
        end
        if obj.Name == "ButtonIcon" then
            local ButtonPart = nil
            if obj.Parent and obj.Parent.Parent and obj.Parent.Parent:IsA("BasePart") then ButtonPart = obj.Parent.Parent
            elseif obj.Parent and obj.Parent.Parent and obj.Parent.Parent:IsA("Model") then ButtonPart = obj.Parent.Parent:FindFirstChildOfClass("BasePart") end
            if ButtonPart and not CheckedButtonParts[ButtonPart] then
                CheckedButtonParts[ButtonPart] = true
                table.insert(TotalButtons, ButtonPart)

                local sel = Instance.new("SelectionBox", ButtonPart)
                sel.Adornee = ButtonPart; sel.Color3 = Color3.fromRGB(255, 140, 0); sel.SurfaceTransparency = 0.8
                ButtonPart.CanTouch = true

                local uuid = GetUUID(ButtonPart)
                local order = table.find(RecordedButtonSequence, uuid) or 999
                local recTime = ButtonPressTimings[uuid]

                local bData = {IsPressed = false, PressTime = nil, SelectionBox = sel, Order = order, RecordedTime = recTime}
                ButtonRegistry[ButtonPart] = bData; OrderedButtonRegistry[order] = bData

                AddConnection(ButtonPart.Touched:Connect(function(hit)
                    if hit.Parent == LocalPlayer.Character and not bData.IsPressed then
                        if not RunStart then return end
                        if bData.Order and bData.Order > 1 then
                            local prevBtn = OrderedButtonRegistry[bData.Order - 1]
                            if prevBtn and not prevBtn.IsPressed then SendAlert("WRONG ORDER! Press Button #" .. (bData.Order - 1) .. " first!", Color3.fromRGB(255, 0, 0)); return end
                        end

                        local RealTime = os.clock() - RunStart - TimeOffset
                        if AutoResetEnv and bData.RecordedTime then
                            PreviewOffset = bData.RecordedTime - RealTime
                            SendAlert("Synced to " .. string.format("%.2fs", bData.RecordedTime), Color3.fromRGB(0, 255, 255))
                        end

                        bData.IsPressed = true; bData.PressTime = RealTime; bData.TruePressTime = RealTime
                        sel.Color3 = Color3.fromRGB(0, 255, 0)
                        SendAlert("Button " .. (order ~= 999 and "#"..order or "") .. " Pressed!", Color3.fromRGB(0, 255, 0))
                    end
                end))
            end
        end

        if isRandomString(obj.Name) and obj:IsA("Model") then
            if obj.Name == "NPC" or obj:FindFirstAncestor("_Rescue") then
            else
                local hp = obj:FindFirstChild("Hitbox")
                if not hp then
                    for _, c in ipairs(obj:GetChildren()) do
                        if c:IsA("BasePart") and tostring(c.BrickColor) ~= "Medium stone grey" then hp = c; break end
                    end
                end
                if hp and not CheckedButtonParts[hp] then
                    CheckedButtonParts[hp] = true
                    table.insert(TotalButtons, hp)

                    local sel = Instance.new("SelectionBox", hp)
                    sel.Adornee = hp; sel.Color3 = Color3.fromRGB(255, 140, 0); sel.SurfaceTransparency = 0.8
                    hp.CanTouch = true

                    local uuid = GetUUID(hp)
                    local order = table.find(RecordedButtonSequence, uuid) or 999
                    local recTime = ButtonPressTimings[uuid]

                    local bData = {IsPressed = false, PressTime = nil, SelectionBox = sel, Order = order, RecordedTime = recTime}
                    ButtonRegistry[hp] = bData; OrderedButtonRegistry[order] = bData

                    AddConnection(hp.Touched:Connect(function(hit)
                        if hit.Parent == LocalPlayer.Character and not bData.IsPressed then
                            if not RunStart then return end
                            if bData.Order and bData.Order > 1 then
                                local prevBtn = OrderedButtonRegistry[bData.Order - 1]
                                if prevBtn and not prevBtn.IsPressed then SendAlert("WRONG ORDER! Press Button #" .. (bData.Order - 1) .. " first!", Color3.fromRGB(255, 0, 0)); return end
                            end

                            local RealTime = os.clock() - RunStart - TimeOffset
                            if AutoResetEnv and bData.RecordedTime then
                                PreviewOffset = bData.RecordedTime - RealTime
                                SendAlert("Synced to " .. string.format("%.2fs", bData.RecordedTime), Color3.fromRGB(0, 255, 255))
                            end

                            bData.IsPressed = true; bData.PressTime = RealTime; bData.TruePressTime = RealTime
                            sel.Color3 = Color3.fromRGB(0, 255, 0)
                            SendAlert("Button " .. (order ~= 999 and "#"..order or "") .. " Pressed!", Color3.fromRGB(0, 255, 0))
                        end
                    end))
                end
            end
        end
    end
    local timelines = Runtime.run("TAS/CREATOR/timelines.luau")
    local ok, supported, reason = pcall(timelines.bind, ClonedMap, LocalPlayer, AddConnection,
        function(message) SendAlert(message, Color3.fromRGB(255, 170, 0)) end,
        function() return getgenv().TAS_Active == true end)
    if not ok or not supported then
        local message = "DISABLED: Local timelines — " .. tostring(ok and reason or supported)
        SendAlert(message, Color3.fromRGB(255, 170, 0))
        if MapEventLabel then MapEventLabel.Text = message end
    end
    SendAlert("Map Ready & Linked", Color3.fromRGB(0, 255, 0))
end

-- // FAST FORWARD / REWIND PLAYER //
function StepForward()
    if Stopped or StepInProgress or IsViewingTAS or not IsPaused or not RunStart then return end
    StepInProgress = true
    local InitialFrames = #Frames
    if ZiplineAssistant and ZiplineAssistant.isZiplining and ZiplineAssistant.isZiplining() then
        local finished = ZiplineAssistant.step(RECORD_INTERVAL)
        table.insert(Frames, CaptureFrameData())
        local VisualTime = os.clock() - RunStart - TimeOffset + PreviewOffset
        SyncButtonState(VisualTime, os.clock() - RunStart - TimeOffset)
        UpdateMapState(VisualTime)
        task.spawn(function() UpdateTimeDisplay(VisualTime) end)
        if finished then
            ZiplineAssistant.cancel()
        end
        StepInProgress = false
        return
    end
    TogglePause()
    RecordAccumulator = RECORD_INTERVAL
    local deadline = os.clock() + 2
    repeat
        RunService.Heartbeat:Wait()
        local character = LocalPlayer.Character
        if Stopped or IsRewinding or not character or not character:FindFirstChild("HumanoidRootPart") then break end
    until #Frames > InitialFrames or os.clock() >= deadline
    if not Stopped and not IsPaused then TogglePause() end
    StepInProgress = false
end

function FrameAdvanceLoop()
    if IsRewinding then return end
    if IsAdvancingFrame then return end
    IsAdvancingFrame = true; SendAlert("Step Forward", Color3.fromRGB(0, 255, 0))
    while IsAdvancingFrame and getgenv().TAS_Active do
        if IsRewinding then IsAdvancingFrame = false; break end
        StepForward()
        task.wait()
    end
end

function RewindFrame()
    if Stopped or IsViewingTAS or StepInProgress then return end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local FramePacked
        Frames, FramePacked = Buffer.rewind(Savestates, Frames)
        if FramePacked then
            local Frame = UnpackFrame(FramePacked)
            if not IsPaused then TogglePause() end
            local Root = LocalPlayer.Character.HumanoidRootPart
            Root.CFrame = Frame.CFrame + Vector3.new(MapX, MapY - 1000, MapZ)
            Root.Velocity = Frame.Velocity; SavedVelocity = Frame.Velocity
            workspace.CurrentCamera.CFrame = Frame.CameraCFrame
            PauseStart = os.clock(); RunStart = os.clock() - Frame.Time; TimeOffset = 0
            LastRecordedTime = Frame.Time
            local isRewindSwing = Frame.Animation and (Frame.Animation[1] == "swing" or Frame.Animation[1] == "zipline")
            if isRewindSwing and ZiplineAssistant and ZiplineAssistant.seekPosition then
                ZiplineAssistant.seekPosition(Frame.CFrame.Position + Vector3.new(MapX, MapY - 1000, MapZ))
            elseif not isRewindSwing and ZiplineAssistant and ZiplineAssistant.isZiplining and ZiplineAssistant.isZiplining() then
                ZiplineAssistant.cancel()
            end

            local VisualTime = Frame.Time + PreviewOffset
            SyncButtonState(VisualTime, Frame.Time); UpdateMapState(VisualTime)

            if Frame.Animation[1] then OriginalPlayAnim(Frame.Animation[1], Frame.Animation[2], LocalPlayer.Character.Humanoid) end
            if Frame.Animation[1] == "walk" then AnimEnv.setAnimationSpeed(0.76) end

            ToggleTASSlide(Frame.Sliding == true)
            getgenv().IsSwimming = (Frame.Swimming == true)

            task.spawn(function() UpdateTimeDisplay(VisualTime) end)
        end
    end
end

function RewindLoop()
    if IsAdvancingFrame then return end
    IsRewinding = true; SendAlert("Rewinding...", Color3.fromRGB(255, 0, 0))
    RewindFrame(); while task.wait(0.05) and IsRewinding and not Stopped do RewindFrame() end
end

-- // VIEW TAS (IMPROVED PLAYER LOGIC) //
local IsTASSliding = false
local function ToggleTASSlide(val)
    if not LocalPlayer.Character then return end
    if val then
        if LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then LocalPlayer.Character.HumanoidRootPart.Size = Vector3.new(2, 1, 1) end
        if LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.HipHeight = -1.5 end
    else
        if LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then LocalPlayer.Character.HumanoidRootPart.Size = Vector3.new(2, 2, 1) end
        if LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.HipHeight = 0 end
    end
end

local LastTASAnim = nil
local function ActivateTASAnimation(AnimData)
    if not AnimData then OriginalPlayAnim("idle", 0.1, LocalPlayer.Character.Humanoid); return end
    if not LocalPlayer.Character then return end
    local n = AnimData[1]; local animTime = AnimData[2] or 0.1
    if LocalPlayer.Character.Humanoid:GetState() == Enum.HumanoidStateType.Physics then n = "swing" end
    if n == "idle" then
        local vel = LocalPlayer.Character.HumanoidRootPart.Velocity
        if vel.Magnitude > 1 then
            if LocalPlayer.Character.Humanoid.FloorMaterial ~= Enum.Material.Air then n = "walk"; animTime = 0.1 else n = "fall"; animTime = 0.3 end
        end
    end
    if n == "fall" and LocalPlayer.Character.HumanoidRootPart.Velocity.Magnitude < 0.1 then n = "swing" end
    if n == "slide" then if not IsTASSliding then ToggleTASSlide(true); IsTASSliding = true end else if IsTASSliding then ToggleTASSlide(false); IsTASSliding = false end end
    if n and (n == "swing" or n == "zipline" or n ~= LastTASAnim) then
        OriginalPlayAnim(n, animTime, LocalPlayer.Character.Humanoid)
        if n == "walk" then AnimEnv.setAnimationSpeed(0.76) end
        LastTASAnim = n
    end
end

function PlaybackTAS(Data, metadata)
    if Stopped or IsViewingTAS or StepInProgress then return end
    Recordings.codec.validate(Data)
    local character = LocalPlayer.Character
    local Root = character and character:FindFirstChild("HumanoidRootPart")
    local Cam = workspace.CurrentCamera
    assert(Root and Root.Parent and Cam and ClonedMap and ClonedMap.PrimaryPart,
        "The character, camera and captured map must be ready before previewing")
    local settings = ClonedMap:FindFirstChild("Settings")
    local compatible, reason = Timeline.compatible(metadata, settings and settings:GetAttribute("MapName"))
    assert(compatible, reason)
    if not IsPaused then TogglePause() end
    local returnPose, returnVelocity, returnCamera = Root.CFrame, SavedVelocity, Cam.CFrame
    local returnAnimation=table.clone(CurrentAnim or {})
    local returnMapTime = LastMapTime
    local returnSize = Root.Size
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local returnHip = humanoid and humanoid.HipHeight
    local buttonState = {}
    for part, data in pairs(ButtonRegistry) do
        buttonState[part] = {values=table.clone(data), color=data.SelectionBox and data.SelectionBox.Color3}
    end
    local Con
    local previewEnded, finalFrameShown = false, false
    local function finishPreview(completed)
        if previewEnded then return end
        previewEnded = true
        IsViewingTAS = false
        if Con then Con:Disconnect() end
        -- Each restoration is independent; one vanished instance cannot prevent
        -- the rest of the session from releasing its resources.
        pcall(function()
            if Root.Parent and LocalPlayer.Character == character then
                Root.CFrame, Root.Velocity, Root.Anchored = returnPose, returnVelocity, true
                Root.Size = returnSize
                if humanoid and humanoid.Parent then humanoid.HipHeight = returnHip end
            end
        end)
        pcall(function() if Cam.Parent and workspace.CurrentCamera == Cam then Cam.CFrame = returnCamera end end)
        pcall(function() if MapCapture then MapCapture.seek(returnMapTime) end end)
        pcall(function() if LightingCapture then LightingCapture.seek(returnMapTime) end end)
        LastMapTime = returnMapTime
        for part, snapshot in pairs(buttonState) do
            local data = ButtonRegistry[part]
            if data then
                table.clear(data)
                for key, value in pairs(snapshot.values) do data[key] = value end
                pcall(function() if data.SelectionBox then data.SelectionBox.Color3 = snapshot.color end end)
            end
        end
        pcall(function()
            if character:FindFirstChild("Animate") and character.Animate:FindFirstChild("Sliding") then
                character.Animate.Sliding:Fire(returnAnimation[1]=="slide")
            end
        end)
        pcall(function()
            if returnAnimation[1] and humanoid and humanoid.Parent and type(OriginalPlayAnim)=="function" then
                OriginalPlayAnim(returnAnimation[1],returnAnimation[2],humanoid)
            end
        end)
        IsTASSliding = false
        for _, line in ipairs(PathLines) do pcall(function() line:Destroy() end) end
        PathLines = {}
        if StopPreview == finishPreview then StopPreview = nil end
        if completed and not Stopped then
            SendAlert("TAS preview finished; recording position restored", Color3.fromRGB(0, 255, 0))
        end
    end
    -- Acquire state only after cleanup is installed.
    StopPreview = finishPreview
    IsViewingTAS = true
    local setupOK, setupError = pcall(function()
        if getgenv().ExtremeSmoothing then
            local fps = getgenv().TargetSmoothingFPS
            assert(type(fps)=="number" and fps==fps and fps>0 and fps<math.huge, "Invalid smoothing FPS")
            local smoothed, nextT = {}, 0
            for i, sample in ipairs(Data) do
                if sample.time>=nextT or i==1 or i==#Data then
                    table.insert(smoothed,sample)
                    nextT=sample.time+1/math.clamp(fps,1,240)
                end
            end
            Data=smoothed
        end
        local Offset = ClonedMap.PrimaryPart.Position - Vector3.new(0,1000,0)
        local OldFrame, PlayStart = 1, os.clock()
        IsTASSliding, LastTASAnim = false, nil
        local NewC, AngC, NewV = CFrame.new, CFrame.fromEulerAnglesXYZ, Vector3.new
        if getgenv().ShowTASPathDuringPlayback then
            for _, line in ipairs(PathLines) do line:Destroy() end; PathLines = {}
            for i = 1, #Data - 1, (getgenv().ExtremeSmoothing and 1 or 4) do
                local p1 = NewV(Data[i].CCFrame[1], Data[i].CCFrame[2], Data[i].CCFrame[3]) + Offset
                local p2 = NewV(Data[i+1].CCFrame[1], Data[i+1].CCFrame[2], Data[i+1].CCFrame[3]) + Offset
                local dist = (p2 - p1).Magnitude
                if dist > 0.05 then
                    local line = Instance.new("CylinderHandleAdornment")
                    line.Radius = 0.15; line.Color3 = Color3.fromRGB(0, 255, 255); line.Transparency = 0.3
                    line.Height = dist; line.CFrame = CFrame.lookAt(p1 + (p2 - p1)/2, p2)
                    line.Adornee = workspace.Terrain; line.Parent = TrajectoryFolder
                    table.insert(PathLines, line)
                end
            end
        end


        Con = RunService.Heartbeat:Connect(function()
            if previewEnded then return end
            if not IsViewingTAS or Stopped or not Root.Parent or LocalPlayer.Character~=character or finalFrameShown then
                finishPreview(finalFrameShown)
                return
            end
            local worked, err = pcall(function()
                Root.Anchored=true
                local Elapsed = os.clock() - PlayStart
                UpdateMapState(Elapsed)
                SyncButtonState(Elapsed, Elapsed)

                local FA, FB, Alpha, nextFrame, atEnd = Timeline.sample(Data, Elapsed, OldFrame)
                OldFrame = nextFrame

                local cfA = NewC(unpack(FA.CCFrame, 1, 3)) * AngC(unpack(FA.CCFrame, 4, 6))
                local cfB = NewC(unpack(FB.CCFrame, 1, 3)) * AngC(unpack(FB.CCFrame, 4, 6))
                Root.CFrame = cfA:Lerp(cfB, Alpha) + Offset

                local vA = NewV(unpack(FA.VVelocity)); local vB = NewV(unpack(FB.VVelocity))
                Root.Velocity = vA:Lerp(vB, Alpha)

                if getgenv().PlaybackCamera then
                    local camA = NewC(unpack(FA.CCameraCFrame, 1, 3)) * AngC(unpack(FA.CCameraCFrame, 4, 6))
                    local camB = NewC(unpack(FB.CCameraCFrame, 1, 3)) * AngC(unpack(FB.CCameraCFrame, 4, 6))
                    Cam.CFrame = camA:Lerp(camB, Alpha) + Offset
                end
                pcall(ActivateTASAnimation, FA.AAnimation)
                finalFrameShown = atEnd

            end)
            if not worked then
                finishPreview(false)
                SendAlert("Preview stopped: "..tostring(err),Color3.fromRGB(255,106,96))
            end
        end)
        AddConnection(Con)
    end)
    if not setupOK then
        finishPreview(false)
        SendAlert("Preview could not start: "..tostring(setupError),Color3.fromRGB(255,106,96))
    end
end

-- // PREDICTIVE TRAJECTORY VISUALIZER //
local LastTrajectoryUpdate = 0
AddConnection(RunService.RenderStepped:Connect(function()
    if not getgenv().TAS_Active or not getgenv().ShowVelocityPredictor or IsViewingTAS then
        for _, l in ipairs(TrajectoryLines) do l.Visible = false end; return
    end

    local now = os.clock()
    if now - LastTrajectoryUpdate < 1/15 then return end
    LastTrajectoryUpdate = now

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and root.Velocity.Magnitude > 0.5 then
        local p = root.Position; local v = root.Velocity; local dt = 1/60
        local grav = getgenv().IsSwimming and Vector3.new(0, -20, 0) or Vector3.new(0, -workspace.Gravity, 0)
        local rayParams = RaycastParams.new(); rayParams.FilterDescendantsInstances = {char}

        local points, vels = {p}, {v}
        for frame = 1, 90 do
            if getgenv().IsSwimming then v = v * 0.95 end
            v = v + (grav * dt); local stepVec = v * dt

            local hit = workspace:Raycast(p, stepVec, rayParams)
            if hit then p = hit.Position; table.insert(points, p); table.insert(vels, v); break end
            p = p + stepVec; table.insert(points, p); table.insert(vels, v)
        end

        for i = 1, #points - 1 do
            local line = TrajectoryLines[i]
            if not line then
                line = Instance.new("CylinderHandleAdornment"); line.Radius = 0.15; line.Adornee = workspace.Terrain; line.Parent = TrajectoryFolder; TrajectoryLines[i] = line
            end
            local p1, p2 = points[i], points[i+1]
            line.Height = (p2 - p1).Magnitude; line.CFrame = CFrame.lookAt(p1 + (p2 - p1)/2, p2)
            local speed = vels[i].Magnitude; line.Color3 = speed > 30 and Color3.new(1,0,0) or Color3.new(0,1,0)
            line.Visible = true
        end
        for i = #points, #TrajectoryLines do TrajectoryLines[i].Visible = false end
    else
        for _, l in ipairs(TrajectoryLines) do l.Visible = false end
    end
end))

-- // MAIN EXECUTION //
task.spawn(function()
    local remote = game:GetService("ReplicatedStorage"):WaitForChild("Remote")
    local RopeEvent = remote:FindFirstChild("UpdRopeData") or remote:FindFirstChild("oBoPcLGDkNQjGAPHvlWujHyuqmatLeGx")
    if RopeEvent then
        AddConnection(RopeEvent.OnClientEvent:Connect(function(val) if type(val) == "table" and not ClonedMap then RopeTable = val end end))
    end
end)

local multiplayer = game.Workspace.Multiplayer
repeat task.wait(0.1) until Stopped or multiplayer:FindFirstChild("NewMap") or multiplayer:FindFirstChild("Map")
repeat task.wait(0.1) until Stopped or multiplayer:FindFirstChild("Map")
repeat
    task.wait()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
until Stopped or (root and not root.Anchored)
if Stopped then return end
local setupOK, setupError = pcall(SetupMap)
if not setupOK then
    SendAlert("Creator setup failed: " .. tostring(setupError), Color3.fromRGB(255,106,96))
    ResetToNormal()
    return
end
if Stopped then return end

-- // HEARTBEAT LOOP //
local LastHeartbeat = os.clock()
local HBCon = RunService.Heartbeat:Connect(function(dt)
    if not getgenv().TAS_Active then return end
    if not UI_Elements or not UI_Elements.ScreenGui or not UI_Elements.ScreenGui.Parent then return end

    if not RunStart then return end
    if IsViewingTAS or IsRewinding then return end
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") or not workspace.CurrentCamera then return end

    if IsPreviewingForward then PreviewOffset = PreviewOffset + (dt * 5) end
    if IsPreviewingBackward then PreviewOffset = PreviewOffset - (dt * 5) end

    local RealTime = 0
    if not IsPaused then RealTime = os.clock() - RunStart - TimeOffset else RealTime = (PauseStart or os.clock()) - RunStart - TimeOffset end

    local VisualTime = RealTime + PreviewOffset; if VisualTime < 0 then VisualTime = 0 end

    UpdateMapState(VisualTime); SyncButtonState(VisualTime, RealTime); UpdateTimeDisplay(VisualTime)

    UI_Elements.SyncSettings({DebugView=DebugActive, SmoothMode=getgenv().ExtremeSmoothing,
        PathTracing=getgenv().ShowTASPathDuringPlayback, Trajectory=getgenv().ShowVelocityPredictor,
        CamMode=getgenv().PlaybackCamera, EnvSync=AutoResetEnv, AutoSwim=getgenv().EnableAutoSwim,
        EnvPause=EnvPaused, AutoSave=getgenv().AutoSaveOnExit})
    if UI_Elements.SavestatesCount then UI_Elements.SavestatesCount.Text = "States: " .. tostring(#Savestates) end
    if UI_Elements.FrameCount then UI_Elements.FrameCount.Text = "Frames: " .. tostring(Buffer.count(Savestates, Frames)) end

    if PreviewOffset > 0.1 then TimeText.TextColor3 = Color3.fromRGB(0, 255, 0)
    elseif PreviewOffset < -0.1 then TimeText.TextColor3 = Color3.fromRGB(255, 0, 0)
    else
        if IsPaused then TimeText.TextColor3 = Color3.fromRGB(255, 255, 0) else TimeText.TextColor3 = Color3.fromRGB(255, 255, 255) end
    end

    if not IsPaused then
        RecordAccumulator = RecordAccumulator + dt
        local maxDrain = StepInProgress and 1 or 5
        local drained = 0
        while RecordAccumulator >= RECORD_INTERVAL and drained < maxDrain and #Frames < 2000000 do
            RecordAccumulator = RecordAccumulator - RECORD_INTERVAL
            table.insert(Frames, CaptureFrameData())
            drained = drained + 1
        end
        if RecordAccumulator > RECORD_INTERVAL * 2 then
            RecordAccumulator = RECORD_INTERVAL
        end
        if os.clock() - LastHeartbeat >= 2 then LastHeartbeat = os.clock() end

        if ClonedMap then
            local ExitRegion = ClonedMap:FindFirstChild("ExitRegion", true)
            if getgenv().AutoSaveOnExit and ExitRegion and not AutoSaved and os.clock() - LastAutoSaveAttempt >= 5 then
                if IsPointInPart(ExitRegion, LocalPlayer.Character.HumanoidRootPart.CFrame.Position) then
                    LastAutoSaveAttempt = os.clock()
                    SendAlert("Reached Exit - Auto Saving...", Color3.fromRGB(0, 255, 0))

                    local Export = CompileTASData()
                    local name = ClonedMap.Settings:GetAttribute("MapName") or "AutoSaveRun"
                    if UI_Elements.SaveBox and UI_Elements.SaveBox.Text ~= "" then name = UI_Elements.SaveBox.Text end
                    AutoSaved = SaveRecording(name, Export) ~= nil
                    if AutoSaved then RefreshFileList() end
                end
            end
        end
    else
        LastHeartbeat = os.clock()
    end

    local RootPart = LocalPlayer.Character.HumanoidRootPart
    local InWater = false
    local IsSliding = (CurrentAnim and CurrentAnim[1] == "slide")

    -- Updated: Active water check will now skip scanning if EnableAutoSwim is false
    if getgenv().EnableAutoSwim and not IsSliding and RootPart then
        for _, waterPart in ipairs(WaterParts) do
            if IsPartEntirelyInPart(waterPart, RootPart) then InWater = true; break end
        end
    end
    getgenv().IsSwimming = InWater
end)
AddConnection(HBCon)

-- // INPUTS //
local InputCon = UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    local key = input.KeyCode.Name
    if key == Keybinds.GoFrameForward then
        if not IsRewinding and not IsAdvancingFrame then task.spawn(FrameAdvanceLoop) end
    elseif key == Keybinds.GoFrameBack then
        IsAdvancingFrame = false
        if not IsRewinding then task.spawn(RewindLoop) end
    elseif key == "Up" then IsPreviewingForward = true
    elseif key == "Down" then IsPreviewingBackward = true
    else
        local mapping = {UserPause="Pause", AddSavestate="AddState", RemoveSavestate="RemState", BackSavestate="LoadState",
            CollisionToggler="Collision", SaveRun="SaveRun", ResetToNormal="Stop", EnvPause="EnvPause", ToggleTimeReset="EnvSync",
            Resync="Resync", ViewTAS="PlayTAS", AutoSwimToggler="AutoSwim", DebugToggler="DebugView"}
        for binding, action in pairs(mapping) do
            if key == Keybinds[binding] and CreatorActions[action] then CreatorActions[action](); break end
        end
    end
end)
AddConnection(InputCon)
getgenv().FloodGUIStopCreator = ResetToNormal
AddConnection(UserInputService.WindowFocusReleased:Connect(function()
    IsRewinding, IsAdvancingFrame, IsPreviewingForward, IsPreviewingBackward = false, false, false, false
end))

local InputEndCon = UserInputService.InputEnded:Connect(function(input, gpe)
    do
        if input.KeyCode.Name == Keybinds.GoFrameBack then IsRewinding = false end
        if input.KeyCode.Name == Keybinds.GoFrameForward then IsAdvancingFrame = false end
        if input.KeyCode.Name == "Up" then IsPreviewingForward = false end
        if input.KeyCode.Name == "Down" then IsPreviewingBackward = false end
    end
end)
AddConnection(InputEndCon)

local DiedCon = LocalPlayer.Character.Humanoid.Died:Connect(function()
    if StopPreview then StopPreview(false) end
    task.wait(0.1); if not IsPaused then TogglePause() end
    LocalPlayer.CharacterAdded:Wait(); task.wait(0.1)
    if not Stopped and ClonedMap and ClonedMap.Parent then LoadLastSavestate() end
end)
AddConnection(DiedCon)
