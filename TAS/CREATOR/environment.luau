-- Reversible, session-local environment capture. Instances are retained while
-- absent instead of destroyed, so seeking can restore their exact parent/state.
local Environment = {}
local properties = {
    BasePart={"CFrame","Transparency","CanCollide","CanTouch","Color","Size","Anchored","Material","Reflectance"},
    Decal={"Transparency","Color3","Texture"},
    Texture={"Transparency","Color3","Texture","OffsetStudsU","OffsetStudsV","StudsPerTileU","StudsPerTileV"},
    ValueBase={"Value"},
    Lighting={"Ambient","OutdoorAmbient","Brightness","ClockTime","FogColor","FogEnd","FogStart","GlobalShadows","ExposureCompensation"},
    Sky={"CelestialBodiesShown","MoonAngularSize","MoonTextureId","SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp","StarCount","SunAngularSize","SunTextureId"},
    Atmosphere={"Density","Offset","Color","Decay","Glare","Haze"},
    BloomEffect={"Enabled","Intensity","Size","Threshold"},
    BlurEffect={"Enabled","Size"},
    ColorCorrectionEffect={"Enabled","Brightness","Contrast","Saturation","TintColor"},
    DepthOfFieldEffect={"Enabled","FarIntensity","FocusDistance","InFocusRadius","NearIntensity"},
    SunRaysEffect={"Enabled","Intensity","Spread"},
}
function Environment.apply(event, forward)
    local value
    if forward then value=event.NewVal else value=event.OldVal end
    if event.Attribute then event.Instance:SetAttribute(event.Prop, value)
    else event.Instance[event.Prop]=value end
end
function Environment.seek(state, target)
    while state.cursor<=#state.events and state.events[state.cursor].Time<=target do
        Environment.apply(state.events[state.cursor],true)
        state.cursor+=1
    end
    while state.cursor>1 and state.events[state.cursor-1].Time>target do
        state.cursor-=1
        Environment.apply(state.events[state.cursor],false)
    end
end
function Environment.capture(source, getId, now, track, options)
    options=options or {}
    local identities, sources, originalTags = {}, {}, {}
    local function identity(node)
        if identities[node] then return identities[node] end
        originalTags[node]=node:GetAttribute("TAS_UUID")
        local id=getId(node)
        -- A runtime Clone inherits attributes, including our original UUID.
        if sources[id] and sources[id]~=node then
            node:SetAttribute("TAS_UUID",nil)
            id=getId(node)
        end
        assert(not sources[id],"Environment object identity collision")
        identities[node],sources[id]=id,node
        return id
    end
    local originals={source}
    for _,node in ipairs(source:GetDescendants()) do table.insert(originals,node) end
    local originalArchivable={}
    for _,node in ipairs(originals) do
        identity(node)
        originalArchivable[node]=node.Archivable
        node.Archivable=true
    end
    local cloned
    local ok,err=pcall(function()
        if options.cloneRoot then cloned=options.cloneRoot(source) else cloned=source:Clone() end
    end)
    for node,value in pairs(originalArchivable) do node.Archivable=value end
    assert(ok and cloned, "Cannot capture environment: "..tostring(err))
    cloned.Parent=nil
    local state={root=cloned,objects={},events={},cursor=1,connections={},recording=true}
    state.objects[identity(source)]=options.replayRoot or cloned
    for _,node in ipairs(cloned:GetDescendants()) do
        local id=node:GetAttribute("TAS_UUID")
        if id then state.objects[id]=node end
    end
    local watched={}
    local rootBaseline={}
    local function connect(signal,callback)
        local connection=signal:Connect(callback)
        table.insert(state.connections,connection)
        track(connection)
    end
    local function event(target,prop,old,new,attribute)
        if old==new then return end
        table.insert(state.events,{Time=now(),Instance=target,Prop=prop,OldVal=old,NewVal=new,Attribute=attribute})
    end
    local watch
    local function ensure(node)
        if not node then return nil end
        if node~=source and not node:IsDescendantOf(source) then return nil end
        local target=state.objects[identity(node)]
        if not target then
            local parent=ensure(node.Parent)
            local archivable=node.Archivable
            node.Archivable=true
            local worked,result=pcall(function() return node:Clone() end)
            node.Archivable=archivable
            assert(worked and result,"Cannot capture created object: "..node.Name)
            target=result
            target.Parent=nil
            target:ClearAllChildren() -- Every child gets its own identity/event.
            state.objects[identity(node)]=target
            event(target,"Parent",nil,parent)
        end
        watch(node,target)
        return target
    end
    local function remap(value)
        if typeof(value)=="Instance" then return ensure(value) end
        return value
    end
    watch=function(node,target)
        if watched[node] then return end
        watched[node]=true
        local fields={Name=true}
        for class,list in pairs(properties) do
            if node:IsA(class) then for _,name in ipairs(list) do fields[name]=true end end
        end
        local cache={}
        for name in pairs(fields) do
            local worked,value=pcall(function() return remap(node[name]) end)
            if worked then
                cache[name]=value
                if node==source then rootBaseline[name]=value end
                if name=="Value" and typeof(node[name])=="Instance" then target[name]=value end
            end
        end
        local attributes=node:GetAttributes()
        connect(node.Changed,function(name)
            if not state.recording or not fields[name] then return end
            local value=remap(node[name])
            event(target,name,cache[name],value)
            cache[name]=value
        end)
        connect(node.AttributeChanged,function(name)
            if not state.recording or name=="TAS_UUID" then return end
            local value=node:GetAttribute(name)
            event(target,name,attributes[name],value,true)
            attributes[name]=value
        end)
        local parent=ensure(node.Parent)
        if node==source then parent=nil end
        connect(node:GetPropertyChangedSignal("Parent"),function()
            if not state.recording or node==source then return end
            local value=ensure(node.Parent)
            event(target,"Parent",parent,value)
            parent=value
        end)
        connect(node.Destroying,function()
            if not state.recording or node==source then return end
            event(target,"Parent",parent,nil)
            parent=nil
        end)
    end
    for _,node in ipairs(originals) do ensure(node) end
    connect(source.DescendantAdded,function(node)
        if state.recording then ensure(node) end
    end)
    function state.stop()
        state.recording=false
        for _,connection in ipairs(state.connections) do connection:Disconnect() end
        table.clear(state.connections)
    end
    function state.prepare()
        state.stop()
        if options.replayRoot then
            for name,value in pairs(rootBaseline) do
                if options.replayRoot[name]~=value then options.replayRoot[name]=value end
            end
            options.replayRoot:ClearAllChildren()
            for _,child in ipairs(cloned:GetChildren()) do child.Parent=options.replayRoot end
        end
        state.cursor=1
    end
    function state.seek(target) Environment.seek(state,target) end
    function state.dispose()
        state.stop()
        for _,node in pairs(state.objects) do
            if node~=options.replayRoot then node:Destroy() end
        end
        cloned:Destroy()
        for node,id in pairs(identities) do
            pcall(function()
                if node:GetAttribute("TAS_UUID")==id then node:SetAttribute("TAS_UUID",originalTags[node]) end
            end)
        end
        table.clear(identities)
        table.clear(sources)
    end
    return state
end
return Environment
