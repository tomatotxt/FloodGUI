-- Exercises the actual engine control functions without needing a Roblox game.
return function(creatorSource, playerSource)
    local function section(source, marker, ending)
        local start = assert(source:find(marker, 1, true), marker)
        local finish = assert(source:find(ending, start + #marker, true), ending)
        return source:sub(start, finish - 1)
    end
    local function functionSource(source, name, isLocal)
        local marker = (isLocal and "local " or "") .. "function " .. name .. "("
        return section(source, marker, "\nend") .. "\nend"
    end
    local environment = setmetatable({}, {__index=getfenv()})
    local function compile(source)
        local chunk = assert(loadstring(source))
        setfenv(chunk, environment)
        return chunk()
    end
    local clock = 0
    local root = {Anchored=true, Velocity="saved", Parent=true, CFrame="recorded pose"}
    local character = {FindFirstChild=function(_, name) return name=="HumanoidRootPart" and root or nil end}
    local globals = {TAS_Active=true}
    environment.getgenv=function()return globals end
    environment.os={clock=function()return clock end}
    environment.LocalPlayer={Character=character}
    environment.Color3={fromRGB=function()return {}end}
    environment.SendAlert=function()end
    environment.Log=function()end
    environment.Stopped=false
    environment.StepInProgress=false
    environment.IsPaused=true
    environment.IsViewingTAS=false
    environment.IsRewinding=false
    environment.IsAdvancingFrame=true
    environment.RunStart=0
    environment.PauseStart=0
    environment.SavedVelocity="saved"
    environment.TimeOffset=0
    environment.RecordAccumulator=0
    environment.RECORD_INTERVAL=1/60
    environment.LastHeartbeat=0
    environment.Frames={}
    environment.CaptureFrameData=function()return clock end

    -- Keep the real heartbeat's recording exclusions, so restoring the former
    -- IsAdvancingFrame exclusion would make the held-advance regression fail.
    local guard=section(creatorSource,"    if IsViewingTAS or IsRewinding", "    local character =")
    local record=section(creatorSource,"    if not IsPaused then\n        RecordAccumulator", "        if ClonedMap then")
    local heartbeat=compile("return function(dt)\n"..guard..record.."    end\nend")
    local waits=0
    environment.RunService={Heartbeat={Wait=function()
        waits+=1
        assert(waits<200,"Frame advance is stuck waiting for its own recorder")
        clock+=1/60
        heartbeat(1/60)
    end}}
    compile(functionSource(creatorSource,"TogglePause",false))
    compile(functionSource(creatorSource,"StepForward",false))
    compile(functionSource(creatorSource,"FrameAdvanceLoop",false))
    environment.StepForward()
    assert(#environment.Frames==1 and environment.IsPaused and root.Anchored and not environment.StepInProgress)
    environment.IsAdvancingFrame=false
    local cycles=0
    environment.task={wait=function()
        cycles+=1
        if cycles==3 then environment.IsAdvancingFrame=false end
    end}
    environment.FrameAdvanceLoop()
    assert(#environment.Frames==4 and environment.IsPaused and cycles==3)

    -- Cleanup during a pending frame must cancel without toggling the stopped
    -- character back into active recording.
    environment.RunService.Heartbeat.Wait=function()environment.Stopped=true end
    environment.StepForward()
    assert(environment.Stopped and not environment.StepInProgress and #environment.Frames==4)

    environment.CleanedUp=false
    environment.RootPart=root
    environment.Humanoid={}
    environment.PAUSED=false
    environment.OriginalPlayAnim=function()end
    local pause=compile(functionSource(playerSource,"TriggerPauseToggle",true).."\nreturn TriggerPauseToggle")
    pause(true)
    assert(environment.PAUSED and environment.PauseCFrame==root.CFrame)
    pause(false)
    assert(not environment.PAUSED and environment.PauseCFrame==nil and environment.LastClock==clock)
    pause(true)
    environment.CleanedUp=true
    pause(false)
    assert(environment.PAUSED, "Stopped player must ignore late UI/input callbacks")

    -- Preview must release ownership on both setup and asynchronous frame errors.
    environment.Stopped=false
    environment.IsViewingTAS=false
    environment.StepInProgress=false
    environment.IsPaused=true
    root.Parent=character
    root.Size="original size"
    local humanoid={HipHeight=2,Parent=character}
    character.FindFirstChildOfClass=function()return humanoid end
    environment.workspace={CurrentCamera={CFrame="camera",Parent=true}}
    environment.ClonedMap={PrimaryPart={Position=0},FindFirstChild=function()return nil end}
    environment.Recordings={codec={validate=function(frames)assert(type(frames)=="table" and #frames>0)end}}
    environment.Timeline={compatible=function()return true end,sample=function()error("simulated sample failure")end}
    environment.ButtonRegistry={}
    environment.PathLines={}
    environment.LastMapTime=4
    local restoredTime
    environment.MapCapture={seek=function(t)restoredTime=t end}
    environment.Vector3={new=function()return 0 end}
    environment.CFrame={new=function()end,fromEulerAnglesXYZ=function()end}
    environment.AddConnection=function(c)return c end
    environment.UpdateMapState=function()end
    environment.SyncButtonState=function()end
    environment.StopPreview=nil
    local preview=compile(functionSource(creatorSource,"PlaybackTAS",false).."\nreturn PlaybackTAS")
    globals.ExtremeSmoothing=true;globals.TargetSmoothingFPS=0
    preview({{time=0}})
    assert(not environment.IsViewingTAS and environment.StopPreview==nil,"Failed setup left preview ownership acquired")
    assert(root.Size=="original size" and restoredTime==4)
    globals.ExtremeSmoothing=false
    local onFrame,disconnected
    environment.RunService.Heartbeat.Connect=function(_,fn)
        onFrame=fn
        return {Disconnect=function()disconnected=true end}
    end
    preview({{time=0}})
    assert(environment.IsViewingTAS and onFrame)
    onFrame()
    assert(not environment.IsViewingTAS and environment.StopPreview==nil and disconnected,"Frame failure left preview running")
    character.FindFirstChild=function()return nil end
    assert(not pcall(preview,{{time=0}}) and not environment.IsViewingTAS,"Missing character acquired preview state")
    print("PASS: actual TAS held frame advance, cancellation, and immediate reversible player pause")
    print("PASS: actual creator preview setup/frame failure rollback, dependency loss and original environment restoration")
end
