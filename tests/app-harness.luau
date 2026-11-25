return function(source)
    local function section(start,ending)
        local a=assert(source:find(start,1,true));local b=assert(source:find(ending,a+#start,1,true))
        return source:sub(a,b-1)
    end
    local globals={}
    local env=setmetatable({getgenv=function()return globals end},{__index=getfenv()})
    local function compile(code)local fn=assert(loadstring(code));setfenv(fn,env);return fn()end
    env.State=compile(section("local State = {","-- Preserve").."\nreturn State")
    env.Session={Cancelled=false}
    env.TrackConnection=function(c)return c end
    local heartbeat
    env.RunService={Heartbeat={Connect=function(_,fn)heartbeat=fn;return {}end}}
    local writes=0
    env.Overrides={set=function()writes+=1 end,restore=function()return false end,restoreAll=function()end}
    env.Noclip=function()writes+=1 end
    local root={CFrame="before",Parent=true}
    local humanoid={WalkSpeed=17,JumpPower=55,Health=100,MaxHealth=100}
    local character={FindFirstChildOfClass=function()return humanoid end,FindFirstChild=function()return root end}
    env.LocalPlayer={Character=character,UserId=7}
    compile(section("-- Mod & Movement Loop","-- Air jump"))
    heartbeat()
    assert(writes==0 and not env.State.MovementOverrides,"Idle startup changed movement")
    env.State.MovementOverrides=true;heartbeat();assert(writes==2)
    env.State.GodMode=true;env.State.Noclip=true;globals.TAS_Active=true
    heartbeat();assert(writes==2,"Main modifiers retained ownership during creation")
    globals.TAS_Active=false;env.State.GodMode=false;env.State.Noclip=false

    local vote
    env.NewMapVote={OnClientEvent={Connect=function(_,fn)vote=fn;return {}end}}
    local sent
    env.UpdMapVote={FireServer=function(_,key,id,cost)sent={key,id,cost}end}
    env.GetSessionKey=function()return -12 end
    env.Alert=function()end
    env.HasTASFile=function()return false end
    env.Automation={select=function()return {ID=9,name="Test"},0 end}
    env.State.SelectTASMaps=true;env.State.Mode="Farm";env.State.AutoFarm=false;env.State.AutoPlay=false
    compile(section("TrackConnection(NewMapVote.OnClientEvent:Connect(function(dataPacket)","-- MAP LOAD PHASE"))
    vote({mapData={},pVotes={}})
    assert(sent[2]==9 and env.State.AutoFarm and globals.TomatoAutoFarm,"Selected Farm never armed the map-arrival action")

    -- A root-moving collection can be suspended when the creator takes over.
    local collection=compile(section("local ActiveCollectionCleanup","local function ExecuteSecondaryScript").."\nreturn {collect=CollectMapItems,cancel=CancelCollection}")
    local page={CFrame="page",IsA=function()return true end}
    local map={FindFirstChild=function(_,name)if name=="_LostPage" then return page end end}
    env.task={wait=function()coroutine.yield()end}
    env.State.AutoCollect=true
    local collecting=coroutine.create(function()collection.collect(map)end)
    assert(coroutine.resume(collecting) and coroutine.status(collecting)=="suspended" and root.CFrame=="page")
    env.CancelCollection=collection.cancel
    env.Launches={begin=function()return function()return true end,function()end end,cancel=function()end}
    env.Runtime={runScoped=function()root.CFrame="editor"end}
    env.CONFIG={TAS_CREATOR_PATH="creator"}
    env.Noclip=function()end
    local execute=compile(section("local function ExecuteSecondaryScript(modeType)","-- [5] CUSTOM TAS FILE MANAGER").."\nreturn ExecuteSecondaryScript")
    execute("Record")
    assert(not env.State.AutoCollect and not env.State.AutoPlay and not env.State.AutoFarm)
    assert(coroutine.resume(collecting) and coroutine.status(collecting)=="dead" and root.CFrame=="editor","Old collection wrote after creator acquired motion")

    -- Both early and full Session.Cleanup must invoke Advanced.cleanup and NativeSwim.destroy.
    local advancedCleaned, swimDestroyed, uiDestroyed = 0, 0, 0
    env.Advanced={cleanup=function()advancedCleaned+=1 end}
    env.NativeSwim={destroy=function()swimDestroyed+=1 end}
    env.NativeZipline={destroy=function()end}
    env.GameState={destroy=function()end}
    env.UI={destroy=function()uiDestroyed+=1 end}
    env.Preferences={save=function()return true end}
    env.preferencesDirty=false
    env.SessionConnections={}
    compile(section("-- Retain both disposers","NativeSwim.override"))
    env.Session.Cleanup()
    assert(advancedCleaned==1 and swimDestroyed==1,"Early Session.Cleanup must clean up both Advanced and NativeSwim")
    compile(section("local function StopAutomation()","local Interface = Runtime.run"))
    env.Session.Cleanup()
    assert(advancedCleaned==2 and swimDestroyed==2 and uiDestroyed==1,"Full Session.Cleanup must clean up Advanced hooks, NativeSwim, and UI")
    env.Session.Cleanup()
    assert(advancedCleaned==2 and swimDestroyed==2,"Session.Cleanup must be idempotent")

    -- Physical Check("InLift") / Check("InGame") must remain authoritative even with stale GameState.
    env.Session.Cancelled=false
    env.GetChar=function()return env.LocalPlayer.Character end
    env.GameState={
        hasState=function()return true end,
        isInLift=function()return false end,
        isInGame=function()return true end,
        getRemainingButtons=function()return 4 end,
        getActiveButton=function()return {IsDescendantOf=function()return true end,CFrame="stale_goal"} end,
    }
    root.Position={X=0,Y=-144,Z=0}
    local checkFn=compile(section("local function Check(Flag)","local function GetSessionKey").."\nreturn Check")
    env.Check=checkFn
    assert(not checkFn("InLift") and not checkFn("InGame"),"Lobby position must not report InLift/InGame from stale GameState")
    root.Position={X=-25,Y=-144,Z=139}
    assert(checkFn("InLift") and not checkFn("InGame"),"Lift coordinates must report InLift even during loading state")
    root.Position={X=9000,Y=3200,Z=9000}
    assert(not checkFn("InLift") and checkFn("InGame"),"Map coordinates must report InGame")

    -- Lift entry fires AddedWaiting cleanly without yanking CFrame to WaitTeleport, and works from Lobby.
    local liftFires=0
    env.AddedWaiting={FireServer=function()liftFires+=1 end}
    env.Multiplayer={FindFirstChild=function()return nil end}
    env.Advanced={tick=function()end,forceWin=function()end,directTarget=function()return nil end,onMap=function()end,cleanup=function()end}
    local liftThread
    env.task={
        wait=function(t)coroutine.yield();return t or 1 end,
        spawn=function(fn,...)
            if not liftThread then liftThread=coroutine.create(fn) else fn(...) end
        end,
    }
    env.State.AutoJoinLift=true;env.State.AutoFarm=true;env.State.CurrentlyFarming=true
    root.Position={X=0,Y=-144,Z=0};root.CFrame="lobby_spawn";humanoid.Health=100;humanoid.Parent=true
    env.CompletedMaps={};env.ActiveMapTasks={};env.MapReadyAt={}
    local pickedMap=nil
    env.ProcessMap=function(m)pickedMap=m end
    compile(section("-- Lift Rejoin & Active Map Pickup Loop","-- Auto Rebirth Loop"))
    assert(coroutine.resume(liftThread)) -- starts loop at while task.wait(1)
    assert(coroutine.resume(liftThread)) -- executes one tick in Lobby
    assert(liftFires==1 and root.CFrame=="lobby_spawn","Lobby player must fire AddedWaiting without WaitTeleport CFrame yank")
    root.Position={X=-25,Y=-144,Z=139}
    assert(coroutine.resume(liftThread)) -- executes tick in Lift
    assert(liftFires==1,"Player inside lift must not spam AddedWaiting during loading")
    -- Mid-round AutoFarm enable: existing Multiplayer.Map is picked up when physically InGame, ignored when stale in Lift.
    local liveMap={Name="Map",Parent=env.Multiplayer}
    env.Multiplayer={FindFirstChild=function(_,n)return n=="Map" and liveMap or nil end}
    env.State.CurrentlyFarming=false
    assert(coroutine.resume(liftThread)) -- in Lift with stale Map -> must NOT pick up other players' old Map
    assert(pickedMap==nil,"Must not attach to stale ongoing Map while waiting in Lift")
    root.Position={X=9000,Y=3200,Z=9000}
    assert(coroutine.resume(liftThread)) -- physically InGame -> must pick up existing Map!
    assert(pickedMap==liveMap,"Enabling AutoFarm mid-round must pick up existing Map")

    -- StartAutoFarm waits for physical map arrival + unanchor, anchors between scans, and enters ExitRegion despite stale GameState.
    env.isRandomString=compile(section("local function isRandomString(str)","local function CleanMapName").."\nreturn isRandomString")
    env.Camera={CFrame="cam_init",CameraSubject=humanoid}
    env.Enum={HumanoidStateType={Jumping="Jumping",Running="Running",Dead="Dead"}}
    local noclipStates={}
    env.Noclip=function(v)table.insert(noclipStates,v)end
    env.RunService={Heartbeat={Wait=function()coroutine.yield();return 0.016 end}}
    env.task={wait=function(t)coroutine.yield();return t or 0.05 end,spawn=function(fn,...)fn(...)end}
    local btnPart={
        Parent=true,
        BrickColor="Bright blue",
        CFrame="btn_cf",
        IsA=function(_,c)return c=="BasePart" end,
    }
    local touchInterest={Name="TouchInterest"}
    local billboard={IsA=function(_,c)return c=="BillboardGui" end}
    local btnModel
    btnModel={
        Name="ABCDEFGH",
        IsA=function(_,c)return c=="Model" end,
        GetChildren=function()return {btnPart} end,
        FindFirstChild=function(_,name)
            if name=="TouchInterest" then return touchInterest end
            return nil
        end,
        FindFirstChildWhichIsA=function(_,cls)
            if cls=="BillboardGui" then return billboard end
            return nil
        end,
    }
    local exitPart=nil
    local farmMap={
        Parent=true,
        GetDescendants=function()return {btnModel} end,
        FindFirstChild=function(_,name)
            if name=="ExitRegion" then return exitPart end
            return nil
        end,
    }
    humanoid.ChangeState=function()end
    env.CollectMapItems=function()root.CFrame="collected" end
    env.State.AutoFarm=true;env.State.AutoCollect=true;env.State.StartDelay=0;env.State.EscapeSerial=0;env.State.Escaped=false
    -- Start in lift (unanchored!): StartAutoFarm must NOT start farming or collect items in lift.
    root.Position={X=-25,Y=-144,Z=139};root.Anchored=false;root.CFrame="in_lift"
    local farmModule=compile(section("-- [6] AUTO FARM ENGINE","-- [7] MAP LOAD EVENT").."\nreturn {farm=StartAutoFarm,diff=ResolveMapDifficulty}")
    local farm=farmModule.farm
    -- Streamed-out Lobby difficulty fallback must read Settings attribute / GameState mapData.
    env.Workspace={}
    local rankAttr,nameAttr=farmModule.diff({GetAttribute=function(_,k)return k=="Difficulty" and 5 or nil end})
    assert(rankAttr==5 and nameAttr=="Crazy","ResolveMapDifficulty must map numeric Settings Difficulty attribute when Lobby is streamed out")
    local farmCo=coroutine.create(function()farm(farmMap,"Blue Moon")end)
    assert(coroutine.resume(farmCo) and coroutine.status(farmCo)=="suspended")
    assert(not env.State.CurrentlyFarming and env.State.FarmPhase=="Waiting for teleport" and root.CFrame=="in_lift","Must not start farming or collect items while still in lift")
    -- Teleport to map while anchored for countdown: still must wait for unanchor!
    root.Position={X=9000,Y=3200,Z=9000};root.Anchored=true;root.CFrame="map_spawn"
    assert(coroutine.resume(farmCo) and coroutine.status(farmCo)=="suspended")
    assert(env.State.CurrentlyFarming and env.State.CurrentMapName=="Blue Moon" and env.State.FarmPhase=="Waiting for countdown" and root.CFrame=="map_spawn","Must wait for round-start unanchor before moving root")
    -- Unanchor -> round starts: collects items, restores map_spawn, then touches active button (ignoring stale activeBtn).
    root.Anchored=false
    assert(coroutine.resume(farmCo) and root.CFrame=="btn_cf" and env.State.FarmPhase=="Pressing buttons","Must touch active button hitbox after unanchor")
    assert(coroutine.resume(farmCo)) -- finish 0.05s Jumping wait
    -- Clear button TouchInterest -> re-anchors between scans, then spawn ExitRegion -> enters ExitRegion despite stale GameState.
    touchInterest=nil
    assert(coroutine.resume(farmCo)) -- finish 0.05s Running wait -> anchors root & yields on Heartbeat
    assert(root.Anchored,"Must re-anchor root between button scans so Noclip never drops player into void")
    exitPart={CFrame="exit_cf"}
    assert(coroutine.resume(farmCo)) -- next iteration sees ExitRegion -> Noclip(false), moves to exit_cf, yields on Heartbeat
    assert(root.CFrame=="exit_cf" and env.State.FarmPhase=="Touching exit" and env.Camera.CameraSubject==exitPart,"Must enter ExitRegion immediately when it spawns")
    -- Confirm escape -> exits cleanly and restores CameraSubject + CurrentlyFarming=false.
    env.State.EscapeSerial=1
    assert(coroutine.resume(farmCo) and coroutine.status(farmCo)=="dead")
    assert(not env.State.CurrentlyFarming and env.State.FarmPhase=="Escaped" and env.Camera.CameraSubject==humanoid,"Farm must clean up state after confirmed escape")

    print("PASS: actual main startup defaults, movement ownership, selected Farm flow, lift/round-start truth and autofarm lifecycle")
end
