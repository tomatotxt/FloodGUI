-- Modern FloodGUI control contract rendered with tomatotxt's Kavo fork.
-- Engine/UI state stays in the existing controllers; this layer owns presentation.
local Runtime=assert(getgenv().FloodGUIRuntime,"Start FloodGUI through loader.lua")
local Kavo=Runtime.run("vendor/kavo.luau")
local Library={Theme={}}
local function create(class,parent,props)
    local node=Instance.new(class)
    for key,value in pairs(props or {})do node[key]=value end
    node.Parent=parent
    return node
end

function Library:Window(options)
    local theme={SchemeColor=self.Theme.Accent,Background=self.Theme.Background,
        Header=self.Theme.Header,TextColor=self.Theme.Text,ElementColor=self.Theme.Surface}
    local native=Kavo.CreateLib(options.Title,theme,{Parent=options.Parent,Name=options.Name})
    local window={Gui=native.Gui,Root=native.Root,OpenButton=native.OpenButton,Open=true,
        _destroyed=false,_listeners={},_native=native,_key=options.Keybind,_tabs={},_toasts={}}
    local input=game:GetService("UserInputService")
    local function connect(signal,fn)return native.Connect(signal,fn)end
    function window:_listen(event,fn,owner)
        assert(event=="Cancel","Unsupported window event")
        table.insert(self._listeners,{fn=fn,owner=owner})
    end
    function window:_cancel()
        native:CancelInteractions()
        for _,listener in ipairs(table.clone(self._listeners))do
            if not listener.owner or not listener.owner._destroyed then pcall(listener.fn)end
        end
        if self._closeModal then self._closeModal(false)end
    end
    native.OnCancel=function()window:_cancel()end
    function window:Toggle(open)
        if self._destroyed then return end
        native:Toggle(open)
        self.Open=self.Root.Visible
    end
    connect(window.Root:GetPropertyChangedSignal("Visible"),function()
        window.Open=window.Root.Visible
        if not window.Open then window:_cancel()end
    end)
    function window:SetKeybind(key)self._key=key end
    function window:SetStatus(text)
        if not self._destroyed then
            native.Title.Text="FloodGUI | "..text
            native.Title.TextSize=13
            native.Title.Size=UDim2.fromOffset(260,20)
            native.Title.Position=UDim2.new(0.017,0,0,4)
            native.Title.TextTruncate=Enum.TextTruncate.AtEnd
        end
    end
    function window:ConfigureModes(spec)
        self._modeSpec=spec
        self._modeTabs={}
        local header=self.Root:FindFirstChild("MainHeader")
        local switch=create("TextButton",header,{Name="ModeSwitch",Position=UDim2.fromOffset(285,2),
            Size=UDim2.fromOffset(207,25),BackgroundColor3=theme.Header,BorderSizePixel=0,
            Font=Enum.Font.Gotham,TextSize=13,TextColor3=theme.TextColor,AutoButtonColor=true,ZIndex=4})
        create("UICorner",switch,{CornerRadius=UDim.new(0,4)})
        self.ModeSwitch=switch
        native.OnSelect=function(selected)
            if self.Mode then self._modeTabs[self.Mode]=selected end
        end
        connect(switch.Activated,function()
            self:SetMode(self.Mode=="TAS" and "Tools" or "TAS")
        end)
        self:SetMode(spec.Default or "TAS")
    end
    function window:SetMode(mode)
        if self._destroyed or not self._modeSpec or not self._modeSpec[mode]then return end
        self:_cancel()
        self.Mode=mode
        local config=self._modeSpec[mode]
        for key,value in pairs({SchemeColor=config.Accent,Header=config.Header or self._modeSpec.TAS.Header or theme.Header})do
            theme[key]=value
            native:ChangeColor(key,value)
        end
        self.ModeSwitch.Text=mode=="TAS" and "TAS | Switch to Tools >" or "Tools | Switch to TAS >"
        self.ModeSwitch.TextColor3=config.Accent
        self.ModeSwitch.BackgroundColor3=theme.Header
        self.ModeSwitch:SetAttribute("CurrentMode",mode)
        local first
        for _,tab in ipairs(self._tabs)do
            local visible=tab.Mode==nil or tab.Mode==mode
            tab._native._button.Visible=visible
            tab._page.Visible=false
            if visible and not first then first=tab._native end
        end
        local selected=self._modeTabs[mode] or first
        if selected then selected:Select()end
    end
    connect(input.InputBegan,function(pressed,processed)
        if processed or native.Capturing or input:GetFocusedTextBox()then return end
        if pressed.KeyCode==window._key then window:Toggle()end
    end)
    connect(input.WindowFocusReleased,function()window:_cancel()end)
    function window:SetScale(value)
        local scale=self.Root:FindFirstChild("KavoScale") or create("UIScale",self.Root,{Name="KavoScale"})
        local camera=workspace.CurrentCamera
        local size=camera and camera.ViewportSize
        local fit=size and math.min((size.X-20)/525,(size.Y-20)/318)or 1
        scale.Scale=math.clamp(math.min(tonumber(value)or 1,fit),0.25,1.5)
    end
    function window:Destroy()
        if self._destroyed then return end
        self._destroyed=true
        self:_cancel()
        native:Destroy()
        table.clear(self._listeners)
    end
    -- This is intentionally an Instance-owned listener: external destruction
    -- must mark the wrapper closed even after native listeners are disposed.
    window.Gui.Destroying:Connect(function()window:Destroy()end)

    function window:Notify(message)
        if self._destroyed then return end
        local toast=create("Frame",self.Gui,{Name="KavoNotification",Size=UDim2.fromOffset(300,80),
            AnchorPoint=Vector2.new(1,1),BackgroundColor3=theme.Header,BorderSizePixel=0,ZIndex=1000})
        create("UICorner",toast,{CornerRadius=UDim.new(0,4)})
        create("Frame",toast,{Size=UDim2.new(0,3,1,0),BackgroundColor3=theme.SchemeColor,BorderSizePixel=0,ZIndex=1001})
        create("TextLabel",toast,{Position=UDim2.fromOffset(12,5),Size=UDim2.new(1,-24,1,-10),
            BackgroundTransparency=1,Text=(message.Title or "FloodGUI").."\n"..tostring(message.Content),
            Font=Enum.Font.Gotham,TextSize=13,TextWrapped=true,TextColor3=theme.TextColor,
            TextXAlignment=Enum.TextXAlignment.Left,ZIndex=1002})
        table.insert(self._toasts,toast)
        while #self._toasts>(options.MaxNotifications or 3)do table.remove(self._toasts,1):Destroy()end
        local function layout()
            for i,node in ipairs(self._toasts)do node.Position=UDim2.new(1,-12,1,-12-(#self._toasts-i)*86)end
        end
        layout()
        task.delay(message.Duration or 4,function()
            if self._destroyed then return end
            local i=table.find(self._toasts,toast)
            if i then table.remove(self._toasts,i);toast:Destroy();layout()end
        end)
    end
    function window:Confirm(spec)
        if self._destroyed then return end
        self:_cancel()
        local modal=create("Frame",self.Root,{Name="KavoConfirm",Size=UDim2.fromScale(1,1),
            BackgroundColor3=theme.Background,BorderSizePixel=0,ZIndex=2000,Active=true})
        self._modal=modal
        local finished=false
        local function close(accepted)
            if finished then return end
            finished=true
            modal:Destroy()
            self._modal=nil;self._closeModal=nil
            if accepted and not self._destroyed and spec.Callback then spec.Callback()end
        end
        self._closeModal=close
        create("TextLabel",modal,{Position=UDim2.fromOffset(20,16),Size=UDim2.new(1,-40,0,30),
            BackgroundTransparency=1,Text=spec.Title or "Confirm",Font=Enum.Font.GothamSemibold,
            TextSize=17,TextColor3=theme.TextColor,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=2001})
        create("TextLabel",modal,{Position=UDim2.fromOffset(20,55),Size=UDim2.new(1,-40,1,-125),
            BackgroundTransparency=1,Text=tostring(spec.Content or ""),Font=Enum.Font.Gotham,
            TextSize=14,TextWrapped=true,TextColor3=theme.TextColor,TextXAlignment=Enum.TextXAlignment.Left,
            TextYAlignment=Enum.TextYAlignment.Top,ZIndex=2001})
        for index,label in ipairs({"Cancel",spec.ConfirmText or "Continue"})do
            local button=create("TextButton",modal,{Position=UDim2.new(index==1 and 0 or 0.5,20,1,-52),
                Size=UDim2.new(0.5,-30,0,32),Text=label,Font=Enum.Font.GothamSemibold,TextSize=14,
                TextColor3=theme.TextColor,BackgroundColor3=index==1 and theme.ElementColor or theme.SchemeColor,
                BorderSizePixel=0,ZIndex=2002})
            create("UICorner",button,{CornerRadius=UDim.new(0,4)})
            connect(button.Activated,function()close(index==2)end)
        end
    end

    function window:Tab(spec)
        local page=native:NewTab(spec.Name)
        page._button.LayoutOrder=spec.Order or #self._tabs+1
        local tab={Window=self,_page=page._page,_native=page,Mode=spec.Mode}
        local section
        function tab:Section(name,collapsed)
            section=page:NewSection(name,false,true)
            section:SetExpanded(false)
            return section
        end
        local function group()
            if not section then section=page:NewSection(spec.Name,true)end
            return section
        end
        local function control(kind,opts)
            opts=opts or {}
            local c={_disabled=false,_destroyed=false,_value=opts.Default,_name=opts.Name or opts.Text or "",_options=opts.Options or {}}
            local handle,suppressed
            local function fire(value)
                if suppressed or c._destroyed or window._destroyed then return end
                if c._disabled or window._modal then
                    if c._render then c._render(c._value)end
                    return
                end
                if kind=="Slider" then
                    local step=opts.Step or 1
                    value=math.clamp(math.round((value-(opts.Min or 0))/step)*step+(opts.Min or 0),opts.Min or 0,opts.Max or 100)
                end
                c._value=value
                if c._render then c._render(value)end
                if opts.Callback then opts.Callback(value)end
            end
            local g=group()
            if kind=="Button"then handle=g:NewButton(c._name,opts.Desc,function()fire(nil)end)
            elseif kind=="Toggle"then handle=g:NewToggle(c._name,opts.Desc,fire)
            elseif kind=="Slider"then handle=g:NewSlider(c._name,opts.Desc,opts.Max or 100,opts.Min or 0,fire)
            elseif kind=="Input"then handle=g:NewTextBox(c._name,opts.Desc,fire)
            elseif kind=="Dropdown"then handle=g:NewDropdown(c._name,opts.Desc,c._options,fire)
            elseif kind=="Keybind"then
                handle=g:NewKeybind(c._name,opts.Desc,opts.Default or Enum.KeyCode.Unknown,function()
                    if not c._disabled and not c._destroyed and not window._modal and opts.Callback then opts.Callback()end
                end)
                handle.OnChanged=function(key)
                    c._value=key
                    if opts.OnChanged then opts.OnChanged(key)end
                end
            else handle=g:NewLabel(opts.Text or c._name)end
            c._frame=handle.Frame
            c._native=handle
            local symbols={clapperboard="record",video="record",play="play",square="stop"}
            if kind=="Button" and symbols[opts.Icon]then
                local old=c._frame:FindFirstChildWhichIsA("ImageLabel")
                if old then
                    old.Visible=false
                    local icon=create("Frame",c._frame,{Name="ActionSymbol",Position=old.Position,Size=old.Size,BackgroundTransparency=1})
                    if symbols[opts.Icon]=="play"then
                        for index,rotation in ipairs({45,-45})do
                            local arm=create("Frame",icon,{BorderSizePixel=0,Size=UDim2.fromOffset(10,3),Position=UDim2.fromOffset(5,index==1 and 6 or 12),Rotation=rotation})
                            native:RegisterAccent(arm,"BackgroundColor3")
                        end
                    else
                        local shape=create("Frame",icon,{BorderSizePixel=0,Size=UDim2.fromOffset(11,11),Position=UDim2.fromOffset(5,5)})
                        if symbols[opts.Icon]=="record"then create("UICorner",shape,{CornerRadius=UDim.new(1,0)})end
                        native:RegisterAccent(shape,"BackgroundColor3")
                    end
                end
            end
            if kind=="Button" and opts.Style=="Primary"then
                local outline=create("UIStroke",c._frame,{Thickness=1.5,Transparency=0.2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
                native:RegisterAccent(outline,"Color")
            end
            function c._render(value)
                suppressed=true
                if kind=="Toggle"then handle:UpdateToggle(c._name,value==true)
                elseif kind=="Slider"then handle:Set(tonumber(value)or opts.Min or 0)
                elseif kind=="Input"then handle.TextBox.Text=tostring(value or "")
                elseif kind=="Dropdown"then handle:Set(value)
                elseif kind=="Keybind"then if value then handle:Set(value)end
                elseif kind=="Label"then handle:UpdateLabel(tostring(value or ""))
                elseif kind=="Paragraph"then handle:UpdateLabel((c._name~="" and c._name.."\n" or "")..tostring(value or ""))
                elseif kind=="Progress"then handle:UpdateLabel(c._name.."  "..math.floor((value or 0)*100).."%")end
                suppressed=false
            end
            function c:Get()
                if kind=="Input"then return handle.TextBox.Text end
                return self._value
            end
            function c:Set(value,silent)
                if self._destroyed or window._destroyed then return end
                if kind=="Slider"then value=math.clamp(value,opts.Min or 0,opts.Max or 100)end
                self._value=value
                self._render(value)
                if not silent and opts.Callback and kind~="Label" and kind~="Paragraph" and kind~="Progress"then opts.Callback(value)end
            end
            function c:Refresh(values,preserve)
                if self._destroyed or window._destroyed then return end
                assert(kind=="Dropdown","Only dropdowns have options")
                self._options=values
                handle:Refresh(values)
                if not preserve or (self._value~=nil and not table.find(values,self._value))then self._value=nil end
                self._render(self._value)
            end
            function c:SetDisabled(disabled,reason)
                if self._destroyed or window._destroyed then return end
                self._disabled=disabled==true
                handle.Disabled=self._disabled
                if disabled then
                    window:_cancel()
                    if not self._blocker then
                        self._blocker=create("TextButton",self._frame,{Name="Disabled",Text="",Size=UDim2.fromScale(1,1),
                            BackgroundColor3=theme.Background,BackgroundTransparency=0.45,BorderSizePixel=0,ZIndex=50,Active=true})
                    end
                    self._blocker.Visible=true
                elseif self._blocker then self._blocker.Visible=false end
                self._reason=reason
            end
            function c:Destroy()
                if self._destroyed then return end
                window:_cancel()
                self._destroyed=true
                self._frame:Destroy()
            end
            if kind=="Paragraph"then
                c._frame.TextWrapped=true
                c._frame.TextYAlignment=Enum.TextYAlignment.Top
                local padding=c._frame:FindFirstChildWhichIsA("UIPadding")
                padding.PaddingTop=UDim.new(0,8)
                padding.PaddingBottom=UDim.new(0,8)
                c._frame.BackgroundColor3=theme.ElementColor
                local function resize()
                    c._frame.Size=UDim2.fromOffset(352,math.max(44,c._frame.TextBounds.Y+16))
                end
                connect(c._frame:GetPropertyChangedSignal("TextBounds"),resize)
                c._value=opts.Content or ""
                c._render(c._value);resize()
            elseif kind=="Label"then c._value=opts.Text or ""
            else
                if kind=="Progress"then c._value=opts.Default or 0 end
                c._render(c._value)
            end
            return c
        end
        for _,kind in ipairs({"Button","Toggle","Slider","Input","Dropdown","Keybind","Label","Paragraph","Progress"})do
            tab[kind]=function(_,opts)return control(kind,opts)end
        end
        table.insert(self._tabs,tab)
        return tab
    end
    return window
end
return Library
