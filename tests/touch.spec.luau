local Controls=require("../TAS/CREATOR/touch-controls")
local function signal()
    local callbacks={}
    return {Connect=function(_,fn)table.insert(callbacks,fn);return {Disconnect=function()end}end,
        fire=function(...)for _,fn in ipairs(callbacks)do fn(...)end end}
end
local queued={}
local env=setmetatable({Enum={UserInputType={Touch="touch",MouseButton1="mouse"}},task={spawn=function(fn)table.insert(queued,fn)end}}, {__index=getfenv()})
setfenv(Controls.bindHold,env)
local button={InputBegan=signal()}
local inputs={InputEnded=signal(),WindowFocusReleased=signal()}
local presses,releases=0,0
local stop=Controls.bindHold(button,inputs,function()presses+=1 end,function()releases+=1 end,function(c)return c end)
local first={UserInputType="touch"}
button.InputBegan.fire(first); inputs.InputEnded.fire(first)
queued[1](); assert(presses==0 and releases==1,"Released touch started a delayed hold")
button.InputBegan.fire(first); queued[2](); assert(presses==1)
inputs.InputEnded.fire({UserInputType="touch"}); assert(releases==1,"Unrelated finger ended hold")
inputs.WindowFocusReleased.fire(); assert(releases==2)
stop(); assert(releases==2)
print("PASS: fast touch release, multi-touch ownership and focus-loss cleanup")
