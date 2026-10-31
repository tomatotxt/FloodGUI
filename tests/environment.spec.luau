local Environment=require("../TAS/CREATOR/environment")
local function signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={active=true};function c:Disconnect() self.active=false end
        table.insert(self.listeners,{c,fn});return c
    end
    function s:Fire(...)
        for _,l in ipairs(table.clone(self.listeners)) do if l[1].active then l[2](...) end end
    end
    return s
end
local methods={}
local mt={__index=function(t,k)return methods[k] or t.props[k] end}
local function object(class,name)
    return setmetatable({props={ClassName=class,Name=name or class,Archivable=true},attributes={},children={},signals={},
        Changed=signal(),AttributeChanged=signal(),DescendantAdded=signal(),Destroying=signal()},mt)
end
function mt.__newindex(t,k,v)
    local old=t.props[k]
    if old==v then return end
    if k=="Parent" and old then
        local i=table.find(old.children,t);if i then table.remove(old.children,i) end
    end
    t.props[k]=v
    if k=="Parent" and v then table.insert(v.children,t) end
    t.Changed:Fire(k)
    if t.signals[k] then t.signals[k]:Fire() end
    if k=="Parent" and v then
        local additions={t};for _,d in ipairs(t:GetDescendants()) do table.insert(additions,d) end
        local p=v
        while p do for _,d in ipairs(additions) do p.DescendantAdded:Fire(d) end;p=p.Parent end
    end
end
function methods:IsA(c)return self.ClassName==c or (c=="ValueBase" and self.ClassName=="NumberValue") end
function methods:IsDescendantOf(root)local p=self.Parent;while p do if p==root then return true end;p=p.Parent end;return false end
function methods:GetChildren()return table.clone(self.children)end
function methods:GetDescendants()
    local result={}
    local function visit(n)for _,c in ipairs(n.children) do table.insert(result,c);visit(c)end end
    visit(self);return result
end
function methods:GetAttribute(k)return self.attributes[k]end
function methods:GetAttributes()return table.clone(self.attributes)end
function methods:SetAttribute(k,v)if self.attributes[k]~=v then self.attributes[k]=v;self.AttributeChanged:Fire(k)end end
function methods:GetPropertyChangedSignal(k)self.signals[k]=self.signals[k] or signal();return self.signals[k]end
function methods:Clone()
    if not self.Archivable then return nil end
    local clone=object(self.ClassName)
    for k,v in pairs(self.props) do if k~="Parent" then clone.props[k]=v end end
    clone.attributes=table.clone(self.attributes)
    for _,c in ipairs(self.children) do local copy=c:Clone();if copy then copy.Parent=clone end end
    return clone
end
function methods:ClearAllChildren()for _,c in ipairs(self:GetChildren())do c:Destroy()end end
function methods:Destroy()self.Destroying:Fire();self:ClearAllChildren();self.Parent=nil end
local serial=0
local function id(n)local v=n:GetAttribute("TAS_UUID");if not v then serial+=1;v=tostring(serial);n:SetAttribute("TAS_UUID",v)end;return v end
local now=0
local map=object("Model","Map");local part=object("BasePart","Platform")
part.Anchored=true;part.Transparency=0.5;part.CFrame=10;part.CanCollide=false;part.Parent=map
local state=Environment.capture(map,id,function()return now end,function()end)
local platform=state.objects[id(part)]
now=1;part.Anchored=false;part.Transparency=0.8
local duplicate=part:Clone();duplicate.Parent=map
assert(id(duplicate)~=id(part),"A cloned live object reused the original capture identity")
local folder=object("Folder","Created");local water=object("BasePart","_Water");water.Transparency=1;water.Parent=folder;folder.Parent=map
water:SetAttribute("NoSwim",true)
now=2;part.Parent=folder;water:SetAttribute("NoSwim",nil);part.CFrame=20
now=3;part:Destroy()
state.prepare();state.seek(3)
assert(platform.Parent==nil)
assert(state.objects[id(folder)].Parent==state.root)
assert(state.objects[id(duplicate)]~=platform and state.objects[id(duplicate)].Parent==state.root)
assert(state.objects[id(water)].Parent==state.objects[id(folder)])
assert(state.objects[id(water)]:GetAttribute("NoSwim")==nil)
state.seek(0)
assert(platform.Parent==state.root and platform.Transparency==0.5 and platform.Anchored==true and platform.CFrame==10)
assert(state.objects[id(folder)].Parent==nil and state.objects[id(water)].Parent==nil)
state.seek(1.5)
assert(platform.Transparency==0.8 and platform.Anchored==false and platform.Parent==state.root)
assert(state.objects[id(water)]:GetAttribute("NoSwim")==true)
state.seek(3);state.seek(0)
assert(platform.Transparency==0.5 and platform.Parent==state.root)
local eventCount=#state.events;part.CFrame=99;assert(#state.events==eventCount,"Stopped capture still listens")
state.dispose()

-- Lighting root changes and dynamic effects use the exact same seek clock.
now=0
local lighting=object("Lighting","Lighting");lighting.ClockTime=8
local sky=object("Sky");sky.StarCount=100;sky.Parent=lighting
local light=Environment.capture(lighting,id,function()return now end,function()end,{
    replayRoot=lighting,
    cloneRoot=function(root)local f=object("Folder");for _,c in ipairs(root:GetChildren())do c:Clone().Parent=f end;return f end,
})
now=1;lighting.ClockTime=18;sky.StarCount=200
local bloom=object("BloomEffect");bloom.Intensity=2;bloom.Parent=lighting
now=2;bloom.Intensity=3
light.prepare();light.seek(0)
assert(lighting.ClockTime==8 and light.objects[id(sky)].StarCount==100)
assert(light.objects[id(bloom)].Parent==nil)
light.seek(2);assert(lighting.ClockTime==18 and light.objects[id(bloom)].Intensity==3 and light.objects[id(bloom)].Parent==lighting)
light.seek(0);assert(lighting.ClockTime==8 and light.objects[id(bloom)].Parent==nil)
light.dispose();assert(lighting.Name=="Lighting")
local TimelineBinding=require("../TAS/CREATOR/timelines")
assert(TimelineBinding.bind()==false,"Editor must not dispatch native, uncancellable player actions")
print("PASS: created/removed/reparented map objects, reversible properties/attributes, timed lighting and isolated timeline policy")
