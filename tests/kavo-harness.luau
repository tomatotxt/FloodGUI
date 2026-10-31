-- Actual vendored Kavo plus the actual adapter; only Roblox is mocked.
return function(vendorSource,adapterSource)
    local function signal()
        local s={listeners={}}
        function s:Connect(fn)
            local c={active=true};function c:Disconnect()self.active=false end
            table.insert(self.listeners,{c,fn});return c
        end
        function s:Fire(...)
            for _,l in ipairs(table.clone(self.listeners))do if l[1].active then l[2](...)end end
        end
        function s:Count()local n=0;for _,l in ipairs(self.listeners)do if l[1].active then n+=1 end end;return n end
        function s:Clear()for _,l in ipairs(self.listeners)do l[1]:Disconnect()end end
        return s
    end
    local vmt={}
    local function vec(x,y)return setmetatable({X=x,Y=y},vmt)end
    vmt.__sub=function(a,b)return vec(a.X-b.X,a.Y-b.Y)end
    vmt.__add=function(a,b)return vec(a.X+b.X,a.Y+b.Y)end
    vmt.__index=function(a,k)if k=="Magnitude"then return math.sqrt(a.X*a.X+a.Y*a.Y)end end
    local function dim(xs,x,ys,y)return {X={Scale=xs,Offset=x},Y={Scale=ys,Offset=y}}end
    local enums=setmetatable({},{__index=function(t,k)
        local group=setmetatable({},{__index=function(g,n)local e={Name=n};rawset(g,n,e);return e end})
        rawset(t,k,group);return group
    end})
    local input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal(),WindowFocusReleased=signal(),GetFocusedTextBox=function()return nil end}
    local mouse={X=0,Y=0,Move=signal()}
    local objects={}
    local methods={}
    local mt={__index=function(t,k)return methods[k]or t.props[k]or t.events[k]end}
    mt.__newindex=function(t,k,v)
        local previous=t.props[k];t.props[k]=v
        if previous~=v and t.changes[k]then t.changes[k]:Fire()end
    end
    local function instance(class,parent)
        local t=setmetatable({props={ClassName=class,Name=class,Visible=true,Text="",ZIndex=1,
            AbsoluteSize=vec(149,33),AbsolutePosition=vec(0,0),AbsoluteContentSize=vec(352,100),TextBounds=vec(100,18)},
            events={},changes={},attributes={}},mt)
        for _,name in ipairs({"MouseButton1Click","MouseButton1Down","MouseEnter","MouseLeave","InputBegan","InputChanged","InputEnded","Changed","FocusLost","Activated","Destroying"})do t.events[name]=signal()end
        table.insert(objects,t);t.Parent=parent;return t
    end
    function methods:IsA(class)return self.ClassName==class or(class=="GuiObject"and table.find({"Frame","ScrollingFrame","TextLabel","TextButton","TextBox","ImageLabel","ImageButton"},self.ClassName)~=nil)end
    function methods:GetChildren()local r={};for _,o in ipairs(objects)do if o.Parent==self then table.insert(r,o)end end;return r end
    function methods:GetDescendants()local r={};for _,c in ipairs(self:GetChildren())do table.insert(r,c);for _,d in ipairs(c:GetDescendants())do table.insert(r,d)end end;return r end
    function methods:FindFirstChild(name)for _,o in ipairs(self:GetChildren())do if o.Name==name then return o end end end
    function methods:FindFirstChildWhichIsA(class,recursive)for _,o in ipairs(recursive and self:GetDescendants()or self:GetChildren())do if o:IsA(class)then return o end end end
    function methods:WaitForChild(name)return assert(self:FindFirstChild(name),name)end
    function methods:GetPropertyChangedSignal(k)self.changes[k]=self.changes[k]or signal();return self.changes[k]end
    function methods:SetAttribute(k,v)self.attributes[k]=v end
    function methods:GetAttribute(k)return self.attributes[k]end
    function methods:TweenSize(size)self.Size=size end
    function methods:TweenSizeAndPosition(size,pos)self.Size=size;self.Position=pos end
    function methods:Destroy()
        if self.props.destroyed then return end
        self.props.destroyed=true
        self.Destroying:Fire()
        for _,c in ipairs(self:GetChildren())do c:Destroy()end
        for _,event in pairs(self.events)do event:Clear()end
        for _,event in pairs(self.changes)do event:Clear()end
        self.Parent=nil
    end
    local playerGui=instance("PlayerGui")
    local services={UserInputService=input,RunService={},Players={LocalPlayer={GetMouse=function()return mouse end,WaitForChild=function()return playerGui end}},TweenService={}}
    function services.TweenService:Create(node,_,values)return {Play=function()for k,v in pairs(values)do node[k]=v end end}end
    local runtime={}
    local globals={FloodGUIRuntime=runtime}
    local timers={}
    local color=function(r,g,b)return {r=r/255,g=g/255,b=b/255}end
    local env=setmetatable({getgenv=function()return globals end,Enum=enums,Instance={new=instance},
        game={GetService=function(_,name)return assert(services[name],name)end},
        workspace={CurrentCamera={ViewportSize=vec(1280,720)}},Color3={fromRGB=color},
        UDim={new=function(s,o)return {Scale=s,Offset=o}end},UDim2={new=dim,fromOffset=function(x,y)return dim(0,x,0,y)end,fromScale=function(x,y)return dim(x,0,y,0)end},
        Vector2={new=vec},TweenInfo={new=function()return {}end},
        task={wait=function()end,delay=function(_,fn)table.insert(timers,fn)end},
    },{__index=getfenv()})
    local function load(source)local fn=assert(loadstring(source));setfenv(fn,env);return fn()end
    local vendor=load(vendorSource)
    function runtime.run(path)assert(path=="vendor/kavo.luau");return vendor end
    local library=load(adapterSource)
    library.Theme={Accent=color(0,100,255),Background=color(35,35,40),Header=color(25,25,30),Surface=color(50,50,55),Text=color(255,255,255)}
    local w=library:Window({Title="FloodGUI",Name="FloodGUI_main",Parent=playerGui,Keybind=enums.KeyCode.J})
    assert(w.Gui.Parent==playerGui and w.Root.Size.X.Offset==525 and w.Root.Size.Y.Offset==318)
    assert(w.Root.BackgroundColor3.r==35/255,"Must retain the original fork palette")
    local page=w:Tab({Name="TAS"});page:Section("Recording")
    local calls=0
    local toggle=page:Toggle({Name="Auto play",Default=true,Callback=function()calls+=1 end})
    assert(toggle:Get()==true and calls==0,"Initial model synchronization must be silent")
    toggle:Set(false,true);assert(calls==0)
    toggle._frame.MouseButton1Click:Fire();assert(toggle:Get()==true and calls==1)
    toggle:SetDisabled(true,"Unavailable")
    toggle._frame.MouseButton1Click:Fire();assert(calls==1 and toggle:Get()==true,"Disabled native widget changed the model")
    toggle:SetDisabled(false)
    local text=page:Input({Name="Filename",Default="My Run"})
    assert(text:Get()=="My Run")
    text._native.TextBox.Text="Edited";text._native.TextBox.FocusLost:Fire(false)
    assert(text:Get()=="Edited","Text must not clear when focus leaves")
    local sliderValue
    local slider=page:Slider({Name="Speed",Min=0.1,Max=3,Step=0.05,Default=1.25,Callback=function(v)sliderValue=v end})
    assert(slider:Get()==1.25)
    local sliderBar
    for _,o in ipairs(slider._frame:GetChildren())do if o:IsA("TextButton")then sliderBar=o end end
    assert(sliderBar)
    sliderBar.AbsoluteSize=vec(149,6)
    local finger={UserInputType=enums.UserInputType.Touch,Position=vec(75,0)}
    sliderBar.InputBegan:Fire(finger)
    assert(sliderValue and sliderValue%1~=0,"Fractional slider values were rounded to integers")
    local prior=sliderValue
    w:Toggle(false);finger.Position=vec(140,0);input.InputChanged:Fire(finger)
    assert(sliderValue==prior,"Hidden window retained slider drag")
    w:Toggle(true)
    local selected
    local choice=page:Dropdown({Name="Files",Options={"A","B"},Default="A",Callback=function(v)selected=v end})
    choice:Set("B",true);assert(choice:Get()=="B"and selected==nil)
    choice:Refresh({"B","C"},true);assert(choice:Get()=="B")
    for _,o in ipairs(choice._frame:GetChildren())do if o:IsA("TextButton")and o.Text=="  C"then o.MouseButton1Click:Fire()end end
    assert(choice:Get()=="C"and selected=="C")
    local changed
    local key=page:Keybind({Name="Shortcut",Default=enums.KeyCode.G,OnChanged=function(k)changed=k end})
    key._frame.MouseButton1Click:Fire()
    input.InputBegan:Fire({KeyCode=enums.KeyCode.J,UserInputType=enums.UserInputType.Keyboard},false)
    assert(changed==enums.KeyCode.J and w.Open,"Binding J must not hide the window")
    key._frame.MouseButton1Click:Fire();input.WindowFocusReleased:Fire();assert(not w._native.Capturing)
    local cancelled=0;w:_listen("Cancel",function()cancelled+=1 end)
    local other=w:Tab({Name="Other"})
    other._page.Visible=false
    -- Native tabs must release held controls before switching pages.
    local nativeTabButton=w._native.Root:GetDescendants()
    for _,o in ipairs(nativeTabButton)do if o:IsA("TextButton")and o.Text=="Other"then o.MouseButton1Click:Fire()end end
    assert(cancelled>0 and other._page.Visible)
    local confirmed=0
    w:Confirm({Title="Confirm",Content="Continue?",Callback=function()confirmed+=1 end})
    local confirmButton
    for _,o in ipairs(w._modal:GetChildren())do if o:IsA("TextButton")and o.Text=="Continue"then confirmButton=o end end
    confirmButton.Activated:Fire();confirmButton.Activated:Fire();assert(confirmed==1 and w._modal==nil)
    w:Confirm({Callback=function()confirmed+=1 end});w:Toggle(false);assert(confirmed==1 and w._modal==nil)
    w:Notify({Content="Saved"});assert(#w._toasts==1)
    for _,fn in ipairs(timers)do fn()end;assert(#w._toasts==0)
    w:SetScale(1.25);assert(w.Root:FindFirstChild("KavoScale").Scale==1.25)
    local inputBefore=input.InputBegan:Count()
    assert(inputBefore>0)
    w.Gui:Destroy()
    assert(w._destroyed and input.InputBegan:Count()==0 and input.InputChanged:Count()==0,"External destruction leaked Kavo input listeners")
    toggle:Set(false);choice:Refresh({});slider:SetDisabled(true)
    assert(calls==1,"Destroyed controls must not invoke callbacks")
    print("PASS: actual Kavo fork and renderer, original style, silent state, fractional/touch sliders, files, key capture, modal safety and cleanup")
end
