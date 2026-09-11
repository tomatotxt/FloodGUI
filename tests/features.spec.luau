local Guard = require("../feature-guard")
local Rules = require("../challenge-rules")
local Automation = require("../automation")
local guard = Guard.new(function() end)
guard.add("good",true); guard.add("broken",true); guard.add("missing",false)
assert(not guard.enable("missing",true))
guard.enable("good",true); guard.enable("broken",true)
assert(not guard.run("broken",function() error("changed API") end))
assert(not guard.features.broken.available and not guard.features.broken.enabled)
assert(guard.features.good.available and guard.features.good.enabled)
assert(guard.run("good",function() return true end))
local function challenge(desc) return {desc=desc,amtCurrent=0,amtRequired=1} end
assert(Rules.evaluate({standard={challenge("walljump once")},master={}},false))
assert(not Rules.evaluate({standard={challenge("finish a map")},master={}},false))
assert(not Rules.evaluate({standard={},master={}},false))
assert(not pcall(Rules.evaluate,{standard={{desc="bad"}},master={}},false))
local maps={{ID=1,name="A",displayMap=true,difficulty="Easy",extraVoteCost=10}, {ID=2,name="B",displayMap=true,difficulty="Crazy+",locked=true,unlockCost=30}}
assert(Automation.voteCost(maps[1],{mapID=1,voteCount=3})==30)
local chosen=Automation.select(maps,nil,{Mode="Record",EnforceDifficulty=true,TargetDifficulty="Easy"},function() return false end)
assert(chosen.ID==1)
assert(Automation.select(maps,nil,{Mode="Farm",TargetMapName="B",EnforceDifficulty=true,TargetDifficulty="Easy"},function() return false end)==nil)
chosen=Automation.select(maps,nil,{Mode="Farm",PreferMissingTAS=true},function(name) return name=="A" end)
assert(chosen.ID==2)
local Advanced = require("../advanced")
local function signal() return {Connect=function(_,cb) return {Disconnect=function() end, callback=cb} end} end
local folder = {children={}}
function folder:FindFirstChild(name) return self.children[name] end
local fired=0
local context={runtime={run=function(path) if path=="feature-guard.luau" then return Guard end return Rules end},
    remotes=folder,environment={},player={},session={},track=function(c)return c end,alert=function()end}
local unavailable=Advanced(context)
for _,f in pairs(unavailable.guard.features) do assert(not f.available and not f.enabled) end
for _,name in ipairs({"BoostIntensity","CycleNewChallenges","UpdPlayerData","UpdGoalLocator","PressedMapButton"}) do
    folder.children[name]={Parent=folder,IsA=function(_,class)return class=="RemoteEvent"end,
        FireServer=function()fired+=1 end,OnClientEvent=signal()}
end
local advanced=Advanced(context)
assert(fired==0,"Startup probe performed a remote write")
assert(advanced.guard.features["Auto boost"].available and not advanced.guard.features["Auto boost"].enabled)
advanced.manualBoost(); assert(fired==4)
folder.children.BoostIntensity.Parent=nil
advanced.enable("Auto boost",true); advanced.onMap({})
assert(not advanced.guard.features["Auto boost"].available)
assert(advanced.guard.features["Timed challenges"].available)
print("PASS: feature isolation, startup probes without writes, remote changes, challenge schemas and map voting")
