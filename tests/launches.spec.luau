local Launches=require("../launches")
local Runtime=require("../runtime")
local session={Cancelled=false}
local launches=Launches(session)
local player=launches.begin("player")
assert(player())
launches.cancel("player");assert(not player())
local creator=launches.begin("creator")
launches.cancel("player");assert(creator(),"Player stop must not close the editing session")
local replacement=launches.begin("player")
assert(not creator() and replacement())
session.Cancelled=true;assert(not replacement())
local resources=Launches({Cancelled=false})
local active,own=resources.begin("creator")
local disposed=0
own(function()assert(not active());disposed+=1 end)
resources.cancel("creator")
assert(disposed==1)
own(function()disposed+=1 end)
assert(disposed==2,"Resources acquired after cancellation must be released immediately")
resources.cancel("creator");assert(disposed==2,"Cancellation must not dispose resources twice")
for _,unload in ipairs({false,true}) do
    local owner={Cancelled=false}
    local tokens=Launches(owner)
    local current=tokens.begin("player")
    local runtime=Runtime("FloodGUI",{localOnly=false})
    local compilations=0
    local env=setmetatable({game={HttpGet=function()
        coroutine.yield("pending HTTP")
        return "return 'started'"
    end},loadstring=function(...)
        compilations+=1
        return loadstring(...)
    end},{__index=getfenv()})
    for _,fn in pairs(runtime) do if type(fn)=="function" then setfenv(fn,env) end end
    local succeeded
    local worker=coroutine.create(function() succeeded=pcall(runtime.runScoped,current,"engine.luau") end)
    assert(coroutine.resume(worker) and coroutine.status(worker)=="suspended")
    if unload then owner.Cancelled=true else tokens.cancel("player") end
    assert(coroutine.resume(worker) and coroutine.status(worker)=="dead")
    assert(succeeded==false and compilations==0,"Cancelled download executed or compiled stale code")
    assert(not pcall(runtime.runScoped,current,"cached.luau"))
end
print("PASS: exclusive launch generations, stop/unload during yielded source loading, cancelled cached launches")
