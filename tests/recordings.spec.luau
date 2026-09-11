local factory = require("../TAS/recordings")
local Codec = require("../TAS/codec")
local frame = require("./recording-fixtures")[1]
local files, network = {}, {}
local catalog = {{name="Test Map.json",path="TAS FILES/Test Map.json"}}
local bytes=Codec.encodeBinary({frame},{mapName="Test Map"})
local adapter=table.clone(Codec)
function adapter.decode(data) if data=="legacy-json" then return {frame},{format="json",fps=60} end return Codec.decodeBinary(data) end
local runtime={root="FloodGUI",localOnly=false,path=function(p)return "FloodGUI/"..p end,
    run=function()return adapter end,catalog=function()return catalog end}
function runtime.read(p) return assert(files[runtime.path(p)] or network[p],"missing "..p) end
local env=setmetatable({isfile=function(p)return files[p]~=nil end,isfolder=function()return true end,
    makefolder=function()end,writefile=function(p,v)files[p]=v end,
    listfiles=function()local result={} for p in pairs(files)do table.insert(result,p)end return result end}, {__index=getfenv()})
setfenv(factory,env)
local api=factory(runtime)
network["TAS FILES/Test Map.json"]="legacy-json"
assert(api.hasMap("Test Map"))
local frames,meta=api.loadMap("Test Map"); assert(#frames==1 and meta.format=="json")
local first=api.save("Test Map",{frame},{mapName="Test Map",author="Tester"})
local second=api.save("Test Map",{frame},{mapName="Test Map",author="Revision 2"})
assert(first~=second and files[runtime.path(first)]~=nil)
frames,meta=api.loadMap("Test Map"); assert(meta.author=="Revision 2")
files[runtime.path(second)]="FE2Tbad"
frames,meta=api.loadMap("Test Map"); assert(meta.author=="Tester")
files[runtime.path(first)]="bad"
frames,meta=api.loadMap("Test Map"); assert(meta.format=="json")
assert(not pcall(api.save,"../escape",{frame}))
print("PASS: online legacy fallback, binary preference, revision selection, corrupt-file fallback, no overwrites")
