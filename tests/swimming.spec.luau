local create=require("../swimming")
local pulse,disconnected
local heartbeat={Connect=function(_,fn)pulse=fn;return {Disconnect=function()disconnected=true end}end}
local nativeCalls=0
local original=function(...)nativeCalls+=1;return "native",... end
local target={OnInvoke=original,IsA=function(_,class)return class=="BindableFunction"end}
local activeTarget=target
local main={FindFirstChild=function(_,name)assert(name=="isSwimming");return activeTarget end}
local scripts={FindFirstChild=function(_,name)assert(name=="CL_MAIN_GameScript");return main end}
local player={FindFirstChild=function(_,name)assert(name=="PlayerScripts");return scripts end}
local api=create(player,heartbeat)
assert(api.available() and target.OnInvoke==original,"Capability probe must not modify the game")
local enabled=false
local release=api.override(function()if enabled then return true end end)
assert(target.OnInvoke==original)
enabled=true;pulse();assert(target.OnInvoke()==true and nativeCalls==0)
local overridden=target.OnInvoke
enabled=false
local a,b=overridden("argument")
assert(a=="native" and b=="argument","Inactive wrappers must delegate immediately, preserving arguments and results")
pulse();assert(target.OnInvoke==original,"Disabling must restore the original callback")
enabled=true;pulse()
local creator=true
local releaseCreator=api.override(function()if creator then return false end end)
assert(target.OnInvoke()==false,"A higher-priority native false result must survive")
releaseCreator();assert(target.OnInvoke()==true)
local replacement=function()return "external"end
target.OnInvoke=replacement
release();assert(target.OnInvoke==replacement,"Cleanup must preserve an external replacement")
local releaseAgain=api.override(function()return true end)
assert(target.OnInvoke()==true)
local nextOriginal=function()return "respawn"end
local nextTarget={OnInvoke=nextOriginal,IsA=target.IsA}
activeTarget=nextTarget;pulse()
assert(target.OnInvoke==replacement and nextTarget.OnInvoke()==true,"Game-script replacement must restore the old binding and acquire the new one")
activeTarget=nil;pulse();assert(nextTarget.OnInvoke==nextOriginal and not api.available())
activeTarget=nextTarget;pulse();assert(nextTarget.OnInvoke()==true)
api.destroy();assert(disconnected and nextTarget.OnInvoke==nextOriginal)
releaseAgain();api.step();assert(not api.available() and nextTarget.OnInvoke==nextOriginal)

local inaccessible=setmetatable({IsA=target.IsA},{__index=function()error("Callback cannot be read")end})
activeTarget=inaccessible
local unsupported=create(player,heartbeat)
assert(not unsupported.available())
unsupported.override(function()return true end)
assert(rawget(inaccessible,"OnInvoke")==nil,"Unreadable native callbacks must never be replaced")
unsupported.destroy()
-- Roblox callback properties can be write-only; exercise the executor reader path.
local stored=original
local opaque=setmetatable({IsA=target.IsA},{
    __index=function()error("OnInvoke is write-only")end,
    __newindex=function(_,key,value)assert(key=="OnInvoke");stored=value end,
})
activeTarget=opaque
setfenv(create,setmetatable({getcallbackvalue=function(instance,key)
    assert(instance==opaque and key=="OnInvoke");return stored
end},{__index=getfenv()}))
local readable=create(player,heartbeat)
assert(readable.available())
local releaseOpaque=readable.override(function()return true end)
assert(stored()==true)
releaseOpaque();assert(stored==original)
local releaseFailed=readable.override(function()error("predicate failed")end)
assert(stored==original,"Failed predicates must leave native behavior intact")
releaseFailed();readable.destroy()
print("PASS: native isSwimming binding, true/false precedence, delegation, safe probing, disable/unload restoration and game-script replacement")
