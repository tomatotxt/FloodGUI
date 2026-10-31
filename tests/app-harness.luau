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
    local execute=compile(section("local function ExecuteSecondaryScript(modeType)","local function GetRandomPointInPart").."\nreturn ExecuteSecondaryScript")
    execute("Record")
    assert(not env.State.AutoCollect and not env.State.AutoPlay and not env.State.AutoFarm)
    assert(coroutine.resume(collecting) and coroutine.status(collecting)=="dead" and root.CFrame=="editor","Old collection wrote after creator acquired motion")
    print("PASS: actual main startup defaults, movement ownership, selected Farm flow and collection-to-creator handoff")
end
