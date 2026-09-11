local create=require("../runtime")
local requests={}
local runtime=create("FloodGUI",{localOnly=false})
local env=setmetatable({isfile=function(path)return path=="FloodGUI/TAS FILES/Local.json"end,
    readfile=function()return "local-run"end,
    game={HttpGet=function(_,url)table.insert(requests,url);return "return 42"end}}, {__index=getfenv()})
for _,fn in pairs(runtime)do if type(fn)=="function"then setfenv(fn,env)end end
assert(runtime.url("TAS FILES/A #1.json")=="https://raw.githubusercontent.com/tomatotxt/FloodGUI/live/TAS%20FILES/A%20%231.json")
assert(runtime.run("automation.luau")==42)
assert(runtime.run("automation.luau")==42 and #requests==1)
assert(runtime.read("TAS FILES/Local.json")=="local-run" and #requests==1)
assert(runtime.read("TAS FILES/Online.json")=="return 42" and #requests==2)
print("PASS: live URLs, escaping, session cache and local recording precedence")
