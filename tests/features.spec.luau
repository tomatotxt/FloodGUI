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
maps[1].cooldown=true
assert(Automation.select({maps[1]},nil,{Mode="Farm"},function()return true end)==nil)
assert(Automation.select({maps[1]},{mapID=1,voteCount=1},{Mode="Farm"},function()return true end)==maps[1],"Existing vote eligibility differs from a new cooldown vote")
local ballot={
    {ID=10,name="Chill Creek",displayMap=true,difficulty="Easy",extraVoteCost=10},
    {ID=11,name="Sandswept Ruins",displayMap=true,difficulty="Crazy",extraVoteCost=10},
    {ID=12,name="Community Gem",displayMap=true,difficulty="Insane",locked=true,unlockCost=25},
}
local pVotes={["1"]={mapID=10,voteCount=3},["2"]={mapID=11,voteCount=1}}
assert(Automation.select(ballot,nil,{Mode="Manual",VoteStrategy="Hardest"},function()return false end).ID==11,"Hardest strategy must pick Crazy over Insane/Easy")
assert(Automation.select(ballot,nil,{Mode="Manual",VoteStrategy="Easiest"},function()return false end).ID==10,"Easiest strategy must pick Easy")
assert(Automation.select(ballot,nil,{Mode="Manual",VoteStrategy="Most popular"},function()return false end,pVotes).ID==10,"Most popular strategy must follow server votes")
assert(Automation.select(ballot,nil,{Mode="Manual",VoteStrategy="Underdog"},function()return false end,pVotes).ID==12,"Underdog strategy must pick 0-vote map")
assert(Automation.select(ballot,nil,{Mode="Manual",VoteStrategy="Highlight / Community",HighlightMaps={"Community Gem"}},function()return false end,pVotes).ID==12,"Highlight strategy must prioritize highlight maps")
assert(Automation.select(ballot,nil,{Mode="Manual",VoteStrategy="Random",Random=function()return 2 end},function()return false end).ID==12,"Deterministic Random strategy must pick indexed candidate")
assert(Automation.select(ballot,nil,{Mode="Manual",TargetMapName="ruins",PartialMapMatch=true},function()return false end).ID==11,"Partial map match must snipe substring")
assert(Automation.select(ballot,nil,{Mode="Manual",MinDifficulty="Insane",AllowPaidVotes=false},function()return false end).ID==11,"MinDifficulty + AllowPaidVotes=false must pick free Crazy map")
assert(Automation.select(ballot,nil,{Mode="Manual",MaxVoteCost=20,TargetMapName="Community Gem"},function()return false end)==nil,"MaxVoteCost must block overpriced locked map")
assert(Automation.select(ballot,nil,{Mode="Manual",RequireTASFile=true},function(name)return name=="Sandswept Ruins" end).ID==11,"RequireTASFile must filter to recorded maps")
local items,summary=Automation.describeBallot(ballot,nil,pVotes)
assert(#items==3 and summary:find("Chill Creek %[Easy%] %(3v%)")~=nil,"describeBallot must summarize difficulty and votes")
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
