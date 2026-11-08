-- Actual vendored Kavo plus the actual adapter; only Roblox is mocked.
return function(vendorSource,adapterSource,inputSource)
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
    local focused
    input.GetFocusedTextBox=function()return focused end
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
            AbsoluteSize=class=="ScreenGui" and vec(1280,720) or vec(149,33),AbsolutePosition=vec(0,0),AbsoluteContentSize=vec(352,100),TextBounds=vec(100,18)},
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
        typeof=function(v)if type(v)=="table" and v.Name then return "EnumItem" end;return type(v)end,
        task={spawn=function(fn,...)fn(...)end,wait=function(seconds)if seconds==1.5 then coroutine.yield()end end,delay=function(_,fn)table.insert(timers,fn)end},
    },{__index=getfenv()})
    local function load(source)local fn=assert(loadstring(source));setfenv(fn,env);return fn()end
    local vendor=load(vendorSource)
    function runtime.run(path)assert(path=="vendor/kavo.luau");return vendor end
    local library=load(adapterSource)
    library.Theme={Accent=color(0,100,255),Background=color(35,35,40),Header=color(25,25,30),Surface=color(50,50,55),Text=color(255,255,255)}
    local w=library:Window({Title="FloodGUI",Name="FloodGUI_main",Parent=playerGui,Keybind=enums.KeyCode.J})
    assert(w.Gui.Parent==playerGui and w.Root.Size.X.Offset==525 and w.Root.Size.Y.Offset==318)
    assert(w.Root.BackgroundColor3.r==35/255,"Must retain the original fork palette")
    local page=w:Tab({Name="TAS",Mode="TAS"})
    local initialCategory=page:Section("Recording",false)
    assert(not initialCategory._frame.Visible,"All categories must start closed, including older open-default callers")
    local calls=0
    local explanation=page:Paragraph({Name="Details",Content="First line\nSecond line"})
    assert(explanation._frame.Text=="Details\nFirst line\nSecond line","Paragraphs must not indent only the first line")
    local paragraphPadding=explanation._frame:FindFirstChildWhichIsA("UIPadding")
    assert(paragraphPadding.PaddingLeft.Offset==10 and paragraphPadding.PaddingTop.Offset==8)
    local toggle=page:Toggle({Name="Auto play",Default=true,Callback=function()calls+=1 end})
    assert(toggle:Get()==true and calls==0,"Initial model synchronization must be silent")
    toggle:Set(false,true);assert(calls==0)
    toggle._frame.MouseButton1Click:Fire();assert(toggle:Get()==true and calls==1)
    toggle:SetDisabled(true,"Unavailable")
    toggle._frame.MouseButton1Click:Fire();assert(calls==1 and toggle:Get()==true,"Disabled native widget changed the model")
    toggle:SetDisabled(false)
    local text=page:Input({Name="Filename",Default="My Run"})
    assert(text:Get()=="My Run")
    focused=text._native.TextBox
    assert(text:IsEditing(),"Input must expose focus so polling cannot replace drafts")
    focused=nil
    assert(not text:IsEditing())
    text._native.TextBox.Text="Edited";text._native.TextBox.FocusLost:Fire(false)
    assert(text:Get()=="Edited","Text must not clear when focus leaves")
    local progress=page:Progress({Name="Playback",Default=0})
    progress:Set(0.5,true)
    local progressFill=progress._frame:FindFirstChild("ProgressTrack"):FindFirstChild("ProgressFill")
    assert(progressFill.Size.X.Scale==0.5 and progress._frame.Text=="Playback  50%","Progress bar and percentage must agree")
    progress:Set(2,true);assert(progressFill.Size.X.Scale==1,"Progress fill must stay inside its track")
    local sliderValue
    local slider=page:Slider({Name="Speed",Min=0.1,Max=3,Step=0.05,Suffix="x",Default=1.25,Callback=function(v)sliderValue=v end})
    assert(slider:Get()==1.25)
    local sliderBar
    for _,o in ipairs(slider._frame:GetChildren())do if o:IsA("TextButton")then sliderBar=o end end
    assert(sliderBar)
    assert(slider._frame.Size.Y.Offset==52 and sliderBar.Size.Y.Offset==20,"Slider needs separate text and accessible drag rows")
    assert(sliderBar:FindFirstChild("SliderTrack").Size.Y.Offset==6,"Wider target must retain the slim visual track")
    local valueLabel
    for _,node in ipairs(slider._frame:GetChildren())do if node:IsA("TextLabel") and node.Text=="1.25x"then valueLabel=node end end
    assert(valueLabel,"Slider must display stable precision and its unit")
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
    -- A rejected selection must leave both the displayed label and model intact.
    choice:SetDisabled(true)
    for _,o in ipairs(choice._frame:GetChildren())do if o:IsA("TextButton")and o.Text=="  B"then o.MouseButton1Click:Fire()end end
    local choiceLabel=choice._frame:FindFirstChildWhichIsA("TextButton"):FindFirstChildWhichIsA("TextLabel")
    assert(choice:Get()=="C" and choiceLabel.Text=="C","Disabled dropdown changed its displayed selection")
    choice:SetDisabled(false)
    choice._frame:FindFirstChildWhichIsA("TextButton").MouseButton1Click:Fire()
    assert(choice._frame.Size.Y.Offset>33,"Test must open the dropdown before cancellation")
    w:_cancel()
    assert(choice._frame.Size.Y.Offset==33,"Cancellation must collapse open dropdowns")
    -- Exercise a callback that deliberately clears its own selection.
    local resetChoice
    resetChoice=page:Dropdown({Name="Clear on select",Options={"A","B"},Default="A",Callback=function()resetChoice:Set(nil,true)end})
    for _,o in ipairs(resetChoice._frame:GetChildren())do if o:IsA("TextButton")and o.Text=="  B"then o.MouseButton1Click:Fire()end end
    assert(resetChoice:Get()==nil and resetChoice._frame:FindFirstChildWhichIsA("TextButton"):FindFirstChildWhichIsA("TextLabel").Text=="Clear on select","Native dropdown overwrote callback's chosen label")
    local changed
    local key=page:Keybind({Name="Shortcut",Default=enums.KeyCode.G,OnChanged=function(k)changed=k end})
    key._frame.MouseButton1Click:Fire()
    input.InputBegan:Fire({KeyCode=enums.KeyCode.J,UserInputType=enums.UserInputType.Keyboard},false)
    assert(changed==enums.KeyCode.J and w.Open,"Binding J must not hide the window")
    key._frame.MouseButton1Click:Fire();input.WindowFocusReleased:Fire();assert(not w._native.Capturing)
    local reboundActions=0
    local binding=page:Keybind({Name="Bind",Default=enums.KeyCode.Q})
    page:Keybind({Name="Existing",Default=enums.KeyCode.R,Callback=function()reboundActions+=1 end})
    binding._frame.MouseButton1Click:Fire()
    input.InputBegan:Fire({KeyCode=enums.KeyCode.R,UserInputType=enums.UserInputType.Keyboard},false)
    assert(reboundActions==0,"Capturing a key must not trigger another shortcut on the same input event")
    binding:SetDisabled(true)
    binding._frame.MouseButton1Click:Fire()
    assert(not w._native.Capturing,"Disabled shortcut entered capture mode")
    binding:SetDisabled(false);binding:Destroy()
    binding._native.Frame.MouseButton1Click:Fire()
    assert(not w._native.Capturing,"Destroyed shortcut entered capture mode")
    local cancelled=0;w:_listen("Cancel",function()cancelled+=1 end)
    local other=w:Tab({Name="Other",Mode="Tools"})
    other._page.Visible=false
    -- Native tabs must release held controls before switching pages.
    local nativeTabButton=w._native.Root:GetDescendants()
    for _,o in ipairs(nativeTabButton)do if o:IsA("TextButton")and o.Text=="Other"then o.MouseButton1Click:Fire()end end
    assert(cancelled>0 and other._page.Visible)
    local tuning=page:Section("Recording options",true)
    page:Toggle({Name="Capture lighting",Default=false})
    assert(not tuning._frame.Visible,"Secondary options should start collapsed")
    local disclosure=tuning._frame.Parent:FindFirstChildWhichIsA("Frame"):FindFirstChild("SectionDisclosure")
    assert(disclosure);disclosure.Activated:Fire()
    assert(tuning._frame.Visible,"Disclosure must reveal secondary controls")
    assert(tuning._frame.Position.Y.Offset==38 and tuning._frame.Parent.Size.Y.Offset==138)
    assert(tuning._frame.Parent.ClipsDescendants,"Closed category content must not overlap the next category")
    local categoryLayout=tuning._frame:FindFirstChildWhichIsA("UIListLayout")
    categoryLayout.AbsoluteContentSize=vec(352,220)
    assert(tuning._frame.Parent.Size.Y.Offset==258,"Expanded height must track dropdown and text resizing")
    disclosure.Activated:Fire();assert(not tuning._frame.Visible,"Disclosure must collapse again")
    assert(tuning._frame.Parent.Size.Y.Offset==33,"Closed category must occupy exactly its header height")
    categoryLayout.AbsoluteContentSize=vec(352,300)
    assert(tuning._frame.Parent.Size.Y.Offset==33,"Hidden content updates must not reopen or resize a closed category")
    for _=1,20 do disclosure.Activated:Fire();disclosure.Activated:Fire()end
    assert(tuning._frame.Parent.Size.Y.Offset==33 and not tuning._frame.Visible)
    local arrow=disclosure.Parent:FindFirstChild("DisclosureArrow")
    assert(arrow and arrow:IsA("Frame") and #arrow:GetChildren()==2,"Category arrows must use geometry instead of unsupported font glyphs")
    local shared=w:Tab({Name="Settings"})
    w:ConfigureModes({Default="TAS",TAS={Accent=color(70,150,255)},Tools={Accent=color(245,105,110)}})
    assert(w.Mode=="TAS" and page._page.Visible and not other._native._button.Visible and shared._native._button.Visible)
    local before=calls
    page._page.CanvasPosition=vec(0,125)
    local tooltipThread=coroutine.create(function()
        toggle._frame:FindFirstChildWhichIsA("ImageButton").MouseButton1Click:Fire()
    end)
    assert(coroutine.resume(tooltipThread))
    assert(coroutine.status(tooltipThread)=="suspended")
    finger.Position=vec(80,0);sliderBar.InputBegan:Fire(finger)
    local beforeModeSlider=sliderValue
    w.ModeSwitch.Activated:Fire()
    assert(coroutine.resume(tooltipThread),"An old tooltip worker failed after switching modes")
    finger.Position=vec(140,0);input.InputChanged:Fire(finger)
    assert(sliderValue==beforeModeSlider,"Mode switch retained a hidden slider drag")
    assert(w.Mode=="Tools" and other._page.Visible and not page._native._button.Visible)
    assert(w.ModeSwitch.Text:find("Tools") and w._native.OpenButton:GetChildren()[1]~=nil)
    shared._native:Select()
    w:SetMode("TAS");assert(page._page.Visible and toggle:Get()==true and calls==before)
    assert(page._page.CanvasPosition.Y==125,"Switching modes lost the user's scroll position")
    w:SetMode("Tools");assert(shared._page.Visible,"Each mode must remember its last selected page")
    local modeConfirmed=false
    w:Confirm({Callback=function()modeConfirmed=true end})
    w:SetMode("TAS");assert(w._modal==nil and not modeConfirmed,"Mode switching must cancel pending confirmations")
    w:SetMode("Tools")
    w:SetMode("invalid");assert(w.Mode=="Tools")
    local second=library:Window({Title="Creator",Name="Creator",Parent=playerGui})
    local oldColor=second.Root.BackgroundColor3
    local secondPage=second:Tab({Name="Record"})
    local secondAccent=secondPage._native._button.BackgroundColor3
    w:SetMode("TAS")
    assert(secondPage._native._button.BackgroundColor3==secondAccent and second.Root.BackgroundColor3==oldColor,"Mode theme leaked to another window")
    second:Destroy()
    w:SetStatus("Recording");assert(w._native.Title.Text=="FloodGUI | Recording")
    local confirmed=0
    w:Confirm({Title="Confirm",Content="Continue?",Callback=function()confirmed+=1 end})
    local confirmButton
    for _,o in ipairs(w._modal:GetChildren())do if o:IsA("TextButton")and o.Text=="Continue"then confirmButton=o end end
    confirmButton.Activated:Fire();confirmButton.Activated:Fire();assert(confirmed==1 and w._modal==nil)
    w:Confirm({Callback=function()confirmed+=1 end});w:Toggle(false);assert(confirmed==1 and w._modal==nil)
    assert(not w.Root.Visible and w.OpenButton.Visible, "Minimizing must hide window and show floating open button")
    assert(w.Gui.DisplayOrder == 2147483647, "Minimizing window must make ScreenGui DisplayOrder topmost (2147483647)")
    assert(w.OpenButton.ZIndex >= 100000, "Floating button must have topmost ZIndex")
    local dotContainer = w.OpenButton:FindFirstChild("DotContainer")
    assert(dotContainer and dotContainer:IsA("Frame"), "Floating open button must have a dedicated DotContainer")
    local dotLayout = dotContainer:FindFirstChildWhichIsA("UIListLayout")
    assert(dotLayout and dotLayout.VerticalAlignment.Name == "Center" and dotLayout.HorizontalAlignment.Name == "Center", "Dots must be centered")
    local floatingClick = w.OpenButton:FindFirstChild("FloatingClick")
    assert(floatingClick and floatingClick:IsA("TextButton"), "Floating open button must have interactive clickable child")
    floatingClick.Activated:Fire()
    assert(w.Root.Visible and not w.OpenButton.Visible, "Clicking floating button must restore window and hide button")
    assert(w.Gui.DisplayOrder < 2147483647, "Restoring window must revert ScreenGui DisplayOrder to normal")
    local minBtn = w.Root:FindFirstChild("MainHeader"):FindFirstChildWhichIsA("TextButton")
    assert(minBtn and minBtn.Text == "-", "Minimize button must be present in header")
    minBtn.MouseButton1Click:Fire()
    assert(not w.Root.Visible and w.OpenButton.Visible, "Clicking minimize button must minimize window")
    assert(w.Gui.DisplayOrder == 2147483647, "Clicking minimize button must set topmost DisplayOrder")
    floatingClick.MouseButton1Click:Fire()
    assert(w.Root.Visible and not w.OpenButton.Visible, "MouseButton1Click on floating button must restore window")
    assert(w.Gui.DisplayOrder < 2147483647, "Restoring window must revert ScreenGui DisplayOrder to normal")
    w:Notify({Content="Saved"});assert(#w._toasts==1)
    for _,fn in ipairs(timers)do fn()end;assert(#w._toasts==0)
    w:SetScale(1.25);assert(w.Root:FindFirstChild("KavoScale").Scale==1.25)
    -- Window drag belongs to one pointer and stops on focus loss/hide.
    w.Gui.AbsoluteSize=vec(1280,720);w.Root.AbsoluteSize=vec(525,318)
    w.Root.AnchorPoint=vec(0,0);w.Root.Position=dim(0,100,0,100)
    local header=w.Root:FindFirstChild("MainHeader")
    local dragFinger={UserInputType=enums.UserInputType.Touch,Position=vec(100,100)}
    local intruder={UserInputType=enums.UserInputType.Touch,Position=vec(200,200)}
    header.InputBegan:Fire(dragFinger);header.InputBegan:Fire(intruder)
    intruder.Position=vec(900,900);input.InputChanged:Fire(intruder)
    assert(w.Root.Position.X.Offset==100,"Second finger stole the window drag")
    dragFinger.Position=vec(5000,5000);input.InputChanged:Fire(dragFinger)
    assert(w.Root.Position.X.Offset==755 and w.Root.Position.Y.Offset==402,"Window must remain reachable inside screen bounds")
    input.WindowFocusReleased:Fire()
    dragFinger.Position=vec(0,0);input.InputChanged:Fire(dragFinger)
    assert(w.Root.Position.X.Offset==755,"Focus loss left a stuck window drag")
    header.InputBegan:Fire(dragFinger);w:Toggle(false)
    dragFinger.Position=vec(300,300);input.InputChanged:Fire(dragFinger)
    assert(w.Root.Position.X.Offset==755,"Hidden window continued dragging")
    w:Toggle(true)
    local inputAPI=load(inputSource)
    local presses=0
    inputAPI[enums.KeyCode.P].Pressed:Connect(function()presses+=1 end)
    local pauseInput={KeyCode=enums.KeyCode.P,UserInputType=enums.UserInputType.Keyboard}
    input.InputBegan:Fire(pauseInput,false)
    assert(presses==1,"Default input policy must allow gameplay shortcuts")
    focused=text._native.TextBox
    input.InputBegan:Fire(pauseInput,false)
    assert(presses==1,"Typing must not trigger playback shortcuts")
    focused=nil
    inputAPI.ShouldIgnore=function(pressed)return library:IsKeyboardBlocked(pressed)end
    w:Confirm({Title="Modal"})
    input.InputBegan:Fire(pauseInput,false)
    assert(presses==1,"Confirmation must block playback shortcuts")
    w:_cancel()
    key._frame.MouseButton1Click:Fire()
    local capturedPause={KeyCode=enums.KeyCode.P,UserInputType=enums.UserInputType.Keyboard}
    input.InputBegan:Fire(capturedPause,false)
    assert(presses==1,"Rebinding must not trigger playback on the capture event")
    input.InputBegan:Fire({KeyCode=enums.KeyCode.P,UserInputType=enums.UserInputType.Keyboard},false)
    assert(presses==2,"Normal input must resume after capture")
    inputAPI:Destroy()
    w:SetScale(1.25)
    w.Gui.AbsoluteSize=vec(375,667)
    local responsiveScale=w.Root:FindFirstChild("KavoScale").Scale
    assert(responsiveScale<1 and math.abs(responsiveScale-355/525)<0.001,"Screen resize must refit the window")
    assert(w.Root.Position.X.Offset+525*responsiveScale<=375.01,"Resized window extends outside the screen")
    w.Gui.AbsoluteSize=vec(1280,720)
    assert(w.Root:FindFirstChild("KavoScale").Scale==1.25,"Growing viewport must restore requested scale")
    local inputBefore=input.InputBegan:Count()
    assert(inputBefore>0)
    w.Gui:Destroy()
    assert(w._destroyed and input.InputBegan:Count()==0 and input.InputChanged:Count()==0,"External destruction leaked Kavo input listeners")
    toggle:Set(false);choice:Refresh({});slider:SetDisabled(true)
    assert(calls==1,"Destroyed controls must not invoke callbacks")
    print("PASS: actual Kavo modes, remembered pages, state preservation, isolated themes, disclosure, silent state, touch sliders, dialogs and cleanup")
end
