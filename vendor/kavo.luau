-- Vendored from tomatotxt/Kavo-UI-Library @ 330f649263760c9523953ca6d8edf1714b881ab4
-- FloodGUI extensions: PlayerGui hosting, owned lifecycle and control handles.
--// Optimized Event-Driven Rewrite of Kavo UI
--// Fixes & Features: Event-Driven Sizing, Touch-Screen Dragging, Minimize Button replaces Close, Draggable 3-Dot Floating Icon.

local Kavo = {}

local tween = game:GetService("TweenService")
local tweeninfo = TweenInfo.new
local input = game:GetService("UserInputService")
local run = game:GetService("RunService")
local players = game:GetService("Players")

local Utility = {}
local Objects = {}

-- Touch compatibility for Mobile users
function Kavo:DraggingEnabled(frame, parent, Connect)
    Connect = Connect or function(signal,fn) return signal:Connect(fn) end
    parent = parent or frame
    local dragging = false
    local dragInput, mousePos, framePos

    Connect(frame.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            mousePos = input.Position
            framePos = parent.Position
            
            Connect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    Connect(frame.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    Connect(input.InputChanged, function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            parent.Position  = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
        end
    end)
end

function Utility:TweenObject(obj, properties, duration, ...)
    tween:Create(obj, tweeninfo(duration, ...), properties):Play()
end

-- Abstracted Ripple Effect
function Utility:CreateRipple(btn, themeColor)
    if not btn or not btn.Parent then return end
    local ms = players.LocalPlayer:GetMouse()
    local c = Instance.new("ImageLabel")
    c.Name = "Sample"
    c.Parent = btn
    c.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    c.BackgroundTransparency = 1.000
    c.Image = "http://www.roblox.com/asset/?id=4560909609"
    c.ImageColor3 = themeColor
    c.ImageTransparency = 0.600
    
    local x, y = (ms.X - c.AbsolutePosition.X), (ms.Y - c.AbsolutePosition.Y)
    c.Position = UDim2.new(0, x, 0, y)
    local len, size = 0.35, nil
    if btn.AbsoluteSize.X >= btn.AbsoluteSize.Y then
        size = (btn.AbsoluteSize.X * 1.5)
    else
        size = (btn.AbsoluteSize.Y * 1.5)
    end
    c:TweenSizeAndPosition(UDim2.new(0, size, 0, size), UDim2.new(0.5, (-size / 2), 0.5, (-size / 2)), 'Out', 'Quad', len, true, nil)
    for i = 1, 10 do
        c.ImageTransparency = c.ImageTransparency + 0.05
        task.wait(len / 12)
    end
    c:Destroy()
end

-- Abstracted Tooltip/Focus Logic
function Utility:SetupTooltip(viewInfoBtn, moreInfo, btn, infoContainer, blurFrame, state, themeList, Connect)
    Connect = Connect or function(signal,fn) return signal:Connect(fn) end
    Connect(viewInfoBtn.MouseButton1Click, function()
        if not state.viewDe then
            state.generation=(state.generation or 0)+1
            local generation=state.generation
            state.viewDe = true
            state.focusing = true
            for _, v in ipairs(infoContainer:GetChildren()) do
                if v ~= moreInfo then
                    Utility:TweenObject(v, {Position = UDim2.new(0, 0, 2, 0)}, 0.2)
                end
            end
            Utility:TweenObject(moreInfo, {Position = UDim2.new(0, 0, 0, 0)}, 0.2)
            Utility:TweenObject(blurFrame, {BackgroundTransparency = 0.5}, 0.2)
            Utility:TweenObject(btn, {BackgroundColor3 = themeList.ElementColor}, 0.2)
            task.wait(1.5)
            if state.generation~=generation or not state.alive() then return end
            state.focusing = false
            Utility:TweenObject(moreInfo, {Position = UDim2.new(0, 0, 2, 0)}, 0.2)
            Utility:TweenObject(blurFrame, {BackgroundTransparency = 1}, 0.2)
            state.viewDe = false
        end
    end)
    
    Connect(btn.MouseButton1Click, function()
        if state.focusing then
            state.generation=(state.generation or 0)+1
            state.viewDe=false
            for _, v in ipairs(infoContainer:GetChildren()) do
                Utility:TweenObject(v, {Position = UDim2.new(0, 0, 2, 0)}, 0.2)
            end
            state.focusing = false
            Utility:TweenObject(blurFrame, {BackgroundTransparency = 1}, 0.2)
        end
    end)
end

local themes = {
    SchemeColor = Color3.fromRGB(74, 99, 135),
    Background = Color3.fromRGB(36, 37, 43),
    Header = Color3.fromRGB(28, 29, 34),
    TextColor = Color3.fromRGB(255,255,255),
    ElementColor = Color3.fromRGB(32, 32, 38)
}
local themeStyles = {
    DarkTheme = {SchemeColor = Color3.fromRGB(64, 64, 64), Background = Color3.fromRGB(0, 0, 0), Header = Color3.fromRGB(0, 0, 0), TextColor = Color3.fromRGB(255,255,255), ElementColor = Color3.fromRGB(20, 20, 20)},
    LightTheme = {SchemeColor = Color3.fromRGB(150, 150, 150), Background = Color3.fromRGB(255,255,255), Header = Color3.fromRGB(200, 200, 200), TextColor = Color3.fromRGB(0,0,0), ElementColor = Color3.fromRGB(224, 224, 224)},
    BloodTheme = {SchemeColor = Color3.fromRGB(227, 27, 27), Background = Color3.fromRGB(10, 10, 10), Header = Color3.fromRGB(5, 5, 5), TextColor = Color3.fromRGB(255,255,255), ElementColor = Color3.fromRGB(20, 20, 20)},
    GrapeTheme = {SchemeColor = Color3.fromRGB(166, 71, 214), Background = Color3.fromRGB(64, 50, 71), Header = Color3.fromRGB(36, 28, 41), TextColor = Color3.fromRGB(255,255,255), ElementColor = Color3.fromRGB(74, 58, 84)},
    Ocean = {SchemeColor = Color3.fromRGB(86, 76, 251), Background = Color3.fromRGB(26, 32, 58), Header = Color3.fromRGB(38, 45, 71), TextColor = Color3.fromRGB(200, 200, 200), ElementColor = Color3.fromRGB(38, 45, 71)},
    Midnight = {SchemeColor = Color3.fromRGB(26, 189, 158), Background = Color3.fromRGB(44, 62, 82), Header = Color3.fromRGB(57, 81, 105), TextColor = Color3.fromRGB(255, 255, 255), ElementColor = Color3.fromRGB(52, 74, 95)},
    Sentinel = {SchemeColor = Color3.fromRGB(230, 35, 69), Background = Color3.fromRGB(32, 32, 32), Header = Color3.fromRGB(24, 24, 24), TextColor = Color3.fromRGB(119, 209, 138), ElementColor = Color3.fromRGB(24, 24, 24)},
    Synapse = {SchemeColor = Color3.fromRGB(46, 48, 43), Background = Color3.fromRGB(13, 15, 12), Header = Color3.fromRGB(36, 38, 35), TextColor = Color3.fromRGB(152, 99, 53), ElementColor = Color3.fromRGB(24, 24, 24)},
    Serpent = {SchemeColor = Color3.fromRGB(0, 166, 58), Background = Color3.fromRGB(31, 41, 43), Header = Color3.fromRGB(22, 29, 31), TextColor = Color3.fromRGB(255,255,255), ElementColor = Color3.fromRGB(22, 29, 31)}
}

function Kavo:ToggleUI()
    if self._lastWindow then self._lastWindow:Toggle() end
end

function Kavo.CreateLib(kavName, themeList, options)
    options=options or {}
    local connections, alive = {}, true
    local Tabs = {}
    local interactions={}
    function Tabs:CancelInteractions()
        if self.Capturing then self.Capturing:Cancel() end
        for _,cancel in ipairs(interactions)do cancel()end
    end
    local function Connect(signal, callback)
        local c=signal:Connect(function(...)
            if alive then callback(...) end
        end)
        table.insert(connections,c)
        return c
    end
    Tabs.Connect=Connect

    if not themeList then themeList = themes end
    if type(themeList) == "string" and themeStyles[themeList] then
        themeList = themeStyles[themeList]
    else
        themeList.SchemeColor = themeList.SchemeColor or Color3.fromRGB(74, 99, 135)
        themeList.Background = themeList.Background or Color3.fromRGB(36, 37, 43)
        themeList.Header = themeList.Header or Color3.fromRGB(28, 29, 34)
        themeList.TextColor = themeList.TextColor or Color3.fromRGB(255,255,255)
        themeList.ElementColor = themeList.ElementColor or Color3.fromRGB(32, 32, 38)
    end

    local ThemeRegistry = {}
    local function RegisterTheme(instance, prop, themeKey, modifierFunc)
        table.insert(ThemeRegistry, {instance = instance, prop = prop, key = themeKey, modifier = modifierFunc})
        local color = themeList[themeKey]
        instance[prop] = modifierFunc and modifierFunc(color) or color
    end

    function Tabs:ChangeColor(property, color)
        if themeList[property] then
            themeList[property] = color
            for _, entry in ipairs(ThemeRegistry) do
                if entry.key == property and entry.instance and entry.instance.Parent then
                    if not (entry.instance:GetAttribute("Hovering") and property == "ElementColor") then 
                        entry.instance[entry.prop] = entry.modifier and entry.modifier(color) or color
                    end
                end
            end
        end
    end
    function Kavo:ChangeColor(property,color) Tabs:ChangeColor(property,color) end
    function Tabs:RegisterAccent(instance,property) RegisterTheme(instance,property,"SchemeColor") end

    kavName = kavName or "Library"
    table.insert(Kavo, kavName)
    
    for _, v in ipairs((options.Parent or players.LocalPlayer:WaitForChild("PlayerGui")):GetChildren()) do
        if v:IsA("ScreenGui") and v.Name == (options.Name or kavName) then v:Destroy() end
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = options.Name or kavName
    ScreenGui.Parent = options.Parent or players.LocalPlayer:WaitForChild("PlayerGui")
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false

    local Main = Instance.new("Frame", ScreenGui)
    Main.Name = "Main"
    Main.ClipsDescendants = true
    Main.Position = UDim2.new(0.336, 0, 0.275, 0)
    Main.Size = UDim2.new(0, 525, 0, 318)
    RegisterTheme(Main, "BackgroundColor3", "Background")
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 4)

    local MainHeader = Instance.new("Frame", Main)
    MainHeader.Name = "MainHeader"
    MainHeader.Size = UDim2.new(0, 525, 0, 29)
    RegisterTheme(MainHeader, "BackgroundColor3", "Header")
    Instance.new("UICorner", MainHeader).CornerRadius = UDim.new(0, 4)
    Kavo:DraggingEnabled(MainHeader, Main, Connect)

    local coverup = Instance.new("Frame", MainHeader)
    coverup.BorderSizePixel = 0
    coverup.Position = UDim2.new(0, 0, 0.758, 0)
    coverup.Size = UDim2.new(0, 525, 0, 7)
    RegisterTheme(coverup, "BackgroundColor3", "Header")

    local title = Instance.new("TextLabel", MainHeader)
    title.BackgroundTransparency = 1.000
    title.Position = UDim2.new(0.017, 0, 0.344, 0)
    title.Size = UDim2.new(0, 204, 0, 8)
    title.Font = Enum.Font.Gotham
    title.RichText = true
    title.Text = kavName
    title.TextSize = 16.000
    title.TextXAlignment = Enum.TextXAlignment.Left
    RegisterTheme(title, "TextColor3", "TextColor")

    -- NEW: Minimize Button (Replacing Close)
    local minimize = Instance.new("TextButton", MainHeader)
    minimize.BackgroundTransparency = 1.000
    minimize.Position = UDim2.new(0.95, 0, 0.138, 0)
    minimize.Size = UDim2.new(0, 21, 0, 21)
    minimize.ZIndex = 2
    minimize.Font = Enum.Font.Gotham
    minimize.Text = "-"
    minimize.TextSize = 24.000
    RegisterTheme(minimize, "TextColor3", "TextColor")

    -- NEW: Floating Toggle Frame (Restores minimized UI)
    local floatingToggle = Instance.new("Frame", ScreenGui)
    floatingToggle.Name = "FloatingToggle"
    floatingToggle.Size = UDim2.new(0, 45, 0, 45)
    floatingToggle.Position = UDim2.new(0, 20, 0.5, -22)
    floatingToggle.Visible = false
    floatingToggle.ZIndex = 999
    RegisterTheme(floatingToggle, "BackgroundColor3", "Header")
    Instance.new("UICorner", floatingToggle).CornerRadius = UDim.new(1, 0)
    
    -- Procedurally Generated 3-Dot (Kebab) Icon
    local dotLayout = Instance.new("UIListLayout", floatingToggle)
    dotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    dotLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    dotLayout.Padding = UDim.new(0, 4)

    for i = 1, 3 do
        local dot = Instance.new("Frame", floatingToggle)
        dot.Size = UDim2.new(0, 5, 0, 5)
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        RegisterTheme(dot, "BackgroundColor3", "SchemeColor")
    end

    Kavo:DraggingEnabled(floatingToggle, floatingToggle, Connect)

    -- Toggle Minimize/Restore Logic
    local savedPos = UDim2.new(0.336, 0, 0.275, 0)

    Connect(minimize.MouseButton1Click, function() Tabs:Toggle(false) end)

    -- Click vs Drag check for the floating button
    local startPos
    Connect(floatingToggle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            startPos = input.Position
        end
    end)
    
    Connect(floatingToggle.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if startPos then
                local endPos = input.Position
                -- Magnitude check ensures dragging doesn't trigger a click
                if (startPos - endPos).Magnitude < 10 then 
                    Tabs:Toggle(true)
                end
            end
        end
    end)

    local MainSide = Instance.new("Frame", Main)
    MainSide.Position = UDim2.new(0, 0, 0.091, 0)
    MainSide.Size = UDim2.new(0, 149, 0, 289)
    RegisterTheme(MainSide, "BackgroundColor3", "Header")
    Instance.new("UICorner", MainSide).CornerRadius = UDim.new(0, 4)

    local coverup_2 = Instance.new("Frame", MainSide)
    coverup_2.BorderSizePixel = 0
    coverup_2.Position = UDim2.new(0.949, 0, 0, 0)
    coverup_2.Size = UDim2.new(0, 7, 0, 289)
    RegisterTheme(coverup_2, "BackgroundColor3", "Header")

    local tabFrames = Instance.new("Frame", MainSide)
    tabFrames.BackgroundTransparency = 1.000
    tabFrames.Position = UDim2.new(0.043, 0, 0, 0)
    tabFrames.Size = UDim2.new(0, 135, 0, 283)
    Instance.new("UIListLayout", tabFrames).SortOrder = Enum.SortOrder.LayoutOrder

    local pages = Instance.new("Frame", Main)
    pages.BackgroundTransparency = 1.000
    pages.Position = UDim2.new(0.299, 0, 0.122, 0)
    pages.Size = UDim2.new(0, 360, 0, 269)
    local Pages = Instance.new("Folder", pages)

    local infoContainer = Instance.new("Frame", Main)
    infoContainer.BackgroundTransparency = 1.000
    infoContainer.ClipsDescendants = true
    infoContainer.Position = UDim2.new(0.299, 0, 0.874, 0)
    infoContainer.Size = UDim2.new(0, 368, 0, 33)

    local blurFrame = Instance.new("Frame", pages)
    blurFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    blurFrame.BackgroundTransparency = 1
    blurFrame.BorderSizePixel = 0
    blurFrame.Position = UDim2.new(-0.022, 0, -0.037, 0)
    blurFrame.Size = UDim2.new(0, 376, 0, 289)
    blurFrame.ZIndex = 999

    -- Reusable Tooltip Creator
    local function CreateMoreInfo(tipText)
        local moreInfo = Instance.new("TextLabel", infoContainer)
        moreInfo.Position = UDim2.new(0, 0, 2, 0)
        moreInfo.Size = UDim2.new(0, 353, 0, 33)
        moreInfo.ZIndex = 9
        moreInfo.Font = Enum.Font.GothamSemibold
        moreInfo.RichText = true
        moreInfo.Text = "  " .. tipText
        moreInfo.TextSize = 14.000
        moreInfo.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("UICorner", moreInfo).CornerRadius = UDim.new(0, 4)
        RegisterTheme(moreInfo, "BackgroundColor3", "ElementColor")
        RegisterTheme(moreInfo, "TextColor3", "TextColor", function(c)
            return themeList.SchemeColor == Color3.fromRGB(255,255,255) and Color3.fromRGB(0,0,0) or c
        end)
        return moreInfo
    end

    local function BindHover(btn, state)
        Connect(btn.MouseEnter, function()
            if not state.focusing then
                btn:SetAttribute("Hovering", true)
                local ec = themeList.ElementColor
                Utility:TweenObject(btn, {BackgroundColor3 = Color3.fromRGB(math.clamp(ec.r*255+8,0,255), math.clamp(ec.g*255+9,0,255), math.clamp(ec.b*255+10,0,255))}, 0.1)
            end
        end)
        Connect(btn.MouseLeave, function()
            if not state.focusing then
                btn:SetAttribute("Hovering", false)
                Utility:TweenObject(btn, {BackgroundColor3 = themeList.ElementColor}, 0.1)
            end
        end)
    end

    local first = true

    function Tabs:NewTab(tabName)
        tabName = tabName or "Tab"
        local tabButton = Instance.new("TextButton", tabFrames)
        tabButton.Size = UDim2.new(0, 135, 0, 28)
        tabButton.AutoButtonColor = false
        tabButton.Font = Enum.Font.Gotham
        tabButton.Text = tabName
        tabButton.TextSize = 14.000
        tabButton.BackgroundTransparency = 1
        RegisterTheme(tabButton, "BackgroundColor3", "SchemeColor")
        RegisterTheme(tabButton, "TextColor3", "TextColor")
        Instance.new("UICorner", tabButton).CornerRadius = UDim.new(0, 5)

        local page = Instance.new("ScrollingFrame", Pages)
        page.Active = true
        page.BorderSizePixel = 0
        page.Position = UDim2.new(0, 0, -0.003, 0)
        page.Size = UDim2.new(1, 0, 1, 0)
        page.ScrollBarThickness = 5
        page.Visible = false
        RegisterTheme(page, "BackgroundColor3", "Background")
        RegisterTheme(page, "ScrollBarImageColor3", "SchemeColor", function(c)
            return Color3.fromRGB(math.clamp(c.r*255-16,0,255), math.clamp(c.g*255-15,0,255), math.clamp(c.b*255-28,0,255))
        end)

        local pageListing = Instance.new("UIListLayout", page)
        pageListing.SortOrder = Enum.SortOrder.LayoutOrder
        pageListing.Padding = UDim.new(0, 5)

        local function UpdateSize()
            local cS = pageListing.AbsoluteContentSize
            page.CanvasSize = UDim2.new(0, 0, 0, cS.Y)
        end
        Connect(pageListing:GetPropertyChangedSignal("AbsoluteContentSize"), UpdateSize)
        UpdateSize()

        if first then
            first = false
            page.Visible = true
            tabButton.BackgroundTransparency = 0
        end

        local Sections = {_page=page,_button=tabButton}
        function Sections:Select()
            if not tabButton.Visible then return end
            if Tabs.OnCancel then Tabs.OnCancel() end
            UpdateSize()
            for _, v in ipairs(Pages:GetChildren()) do v.Visible = false end
            page.Visible = true
            for _, v in ipairs(tabFrames:GetChildren()) do
                if v:IsA("TextButton") then
                    Utility:TweenObject(v, {BackgroundTransparency = 1}, 0.2)
                end
            end
            Utility:TweenObject(tabButton, {BackgroundTransparency = 0.65}, 0.2)
            Tabs.Selected=self
            if Tabs.OnSelect then Tabs.OnSelect(self) end
        end
        Connect(tabButton.MouseButton1Click, function() Sections:Select() end)
        local state = {focusing = false, viewDe = false,alive=function()return alive end}
        table.insert(interactions,function()
            state.generation=(state.generation or 0)+1
            state.focusing=false
            state.viewDe=false
            blurFrame.BackgroundTransparency=1
            for _,node in ipairs(infoContainer:GetChildren())do node.Position=UDim2.new(0,0,2,0)end
        end)

        function Sections:NewSection(secName, hidden, collapsible)
            secName = secName or "Section"
            local sectionFrame = Instance.new("Frame", page)
            sectionFrame.BorderSizePixel = 0
            RegisterTheme(sectionFrame, "BackgroundColor3", "Background")

            sectionFrame.ClipsDescendants=true
            local expanded=not collapsible

            local sectionHead = Instance.new("Frame", sectionFrame)
            sectionHead.Size = UDim2.new(0, 352, 0, 33)
            sectionHead.Visible = not hidden
            RegisterTheme(sectionHead, "BackgroundColor3", "ElementColor")
            local sectionAccent=Instance.new("Frame",sectionHead)
            sectionAccent.BorderSizePixel=0
            sectionAccent.Size=UDim2.new(0,3,1,0)
            RegisterTheme(sectionAccent,"BackgroundColor3","SchemeColor")
            Instance.new("UICorner", sectionHead).CornerRadius = UDim.new(0, 4)

            local sectionName = Instance.new("TextLabel", sectionHead)
            sectionName.BackgroundTransparency = 1.000
            sectionName.Position = UDim2.new(0.019, 0, 0, 0)
            sectionName.Size = UDim2.new(0.98, 0, 1, 0)
            sectionName.Font = Enum.Font.Gotham
            sectionName.Text = secName
            sectionName.RichText = true
            sectionName.TextSize = 14.000
            sectionName.TextXAlignment = Enum.TextXAlignment.Left
            RegisterTheme(sectionName, "TextColor3", "TextColor", function(c)
                return themeList.SchemeColor == Color3.fromRGB(255,255,255) and Color3.fromRGB(0,0,0) or c
            end)

            local sectionInners = Instance.new("Frame", sectionFrame)
            sectionInners.BackgroundTransparency = 1.000
            sectionInners.Position = UDim2.fromOffset(0, hidden and 0 or 38)
            
            local sectionElListing = Instance.new("UIListLayout", sectionInners)
            sectionElListing.SortOrder = Enum.SortOrder.LayoutOrder
            sectionElListing.Padding = UDim.new(0, 3)

            local function updateSectionFrame()
                sectionInners.Size = UDim2.new(1, 0, 0, sectionElListing.AbsoluteContentSize.Y)
                local headerHeight=hidden and 0 or 33
                local contentHeight=sectionElListing.AbsoluteContentSize.Y
                sectionInners.Visible=expanded
                sectionFrame.Size=UDim2.fromOffset(352,headerHeight+(expanded and (contentHeight+(hidden and 0 or 5)) or 0))
            end

            Connect(sectionElListing:GetPropertyChangedSignal("AbsoluteContentSize"), updateSectionFrame)
            updateSectionFrame()
            
            local Elements = {_frame=sectionInners}
            if collapsible then
                local disclosure=Instance.new("TextButton",sectionHead)
                disclosure.Name="SectionDisclosure"
                disclosure.Size=UDim2.fromScale(1,1)
                disclosure.BackgroundTransparency=1
                disclosure.Text=""
                disclosure.ZIndex=3
                local arrow=Instance.new("Frame",sectionHead)
                arrow.Name="DisclosureArrow"
                arrow.BackgroundTransparency=1
                arrow.Position=UDim2.new(1,-25,0.5,-7)
                arrow.Size=UDim2.fromOffset(14,14)
                for index,rotation in ipairs({45,-45})do
                    local arm=Instance.new("Frame",arrow)
                    arm.BorderSizePixel=0
                    arm.Size=UDim2.fromOffset(8,2)
                    arm.Position=UDim2.fromOffset(3,index==1 and 4 or 9)
                    arm.Rotation=rotation
                    RegisterTheme(arm,"BackgroundColor3","TextColor")
                end
                sectionName.Size=UDim2.new(1,-36,1,0)
                local function refresh()
                    sectionName.Text=secName
                    arrow.Rotation=expanded and 90 or 0
                    updateSectionFrame()
                end
                function Elements:SetExpanded(value) expanded=value==true;refresh() end
                Connect(disclosure.Activated,function()
                    if Tabs.OnCancel then Tabs.OnCancel()end
                    expanded=not expanded;refresh()
                end)
                Connect(sectionElListing:GetPropertyChangedSignal("AbsoluteContentSize"),refresh)
                refresh()
            end

            function Elements:NewButton(bname, tipINf, callback)
                local ButtonFunction = {}
                bname = bname or "Click Me!"
                tipINf = tipINf or "Tip: Clicking this nothing will happen!"
                callback = callback or function() end

                local btn = Instance.new("TextButton", sectionInners)
                btn.Size = UDim2.new(0, 352, 0, 33)
                btn.AutoButtonColor = false
                btn.Text = ""
                RegisterTheme(btn, "BackgroundColor3", "ElementColor")
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                btn.ClipsDescendants = true

                local btnInfo = Instance.new("TextLabel", btn)
                btnInfo.BackgroundTransparency = 1.000
                btnInfo.Position = UDim2.new(0.096, 0, 0.272, 0)
                btnInfo.Size = UDim2.new(0, 314, 0, 14)
                btnInfo.Font = Enum.Font.GothamSemibold
                btnInfo.Text = bname
                btnInfo.TextSize = 14.000
                btnInfo.TextXAlignment = Enum.TextXAlignment.Left
                RegisterTheme(btnInfo, "TextColor3", "TextColor")

                local touch = Instance.new("ImageLabel", btn)
                touch.BackgroundTransparency = 1.000
                touch.Position = UDim2.new(0.019, 0, 0.18, 0)
                touch.Size = UDim2.new(0, 21, 0, 21)
                touch.Image = "rbxassetid://3926305904"
                touch.ImageRectOffset = Vector2.new(84, 204)
                touch.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(touch, "ImageColor3", "SchemeColor")

                local viewInfo = Instance.new("ImageButton", btn)
                viewInfo.BackgroundTransparency = 1.000
                viewInfo.Position = UDim2.new(0.93, 0, 0.151, 0)
                viewInfo.Size = UDim2.new(0, 23, 0, 23)
                viewInfo.Image = "rbxassetid://3926305904"
                viewInfo.ImageRectOffset = Vector2.new(764, 764)
                viewInfo.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(viewInfo, "ImageColor3", "SchemeColor")

                local moreInfo = CreateMoreInfo(tipINf)
                Utility:SetupTooltip(viewInfo, moreInfo, btn, infoContainer, blurFrame, state, themeList, Connect)
                BindHover(btn, state)

                Connect(btn.MouseButton1Click, function()
                    if not state.focusing then
                        callback()
                        Utility:CreateRipple(btn, themeList.SchemeColor)
                    end
                end)

                function ButtonFunction:UpdateButton(newTitle)
                    btnInfo.Text = newTitle
                end
                ButtonFunction.Frame=btn
                return ButtonFunction
            end

            function Elements:NewTextBox(tname, tTip, callback)
                local btn = Instance.new("TextButton", sectionInners)
                btn.Size = UDim2.new(0, 352, 0, 33)
                btn.AutoButtonColor = false
                btn.Text = ""
                RegisterTheme(btn, "BackgroundColor3", "ElementColor")
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                btn.ClipsDescendants = true

                local write = Instance.new("ImageLabel", btn)
                write.BackgroundTransparency = 1.000
                write.Position = UDim2.new(0.019, 0, 0.18, 0)
                write.Size = UDim2.new(0, 21, 0, 21)
                write.Image = "rbxassetid://3926305904"
                write.ImageRectOffset = Vector2.new(324, 604)
                write.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(write, "ImageColor3", "SchemeColor")

                local togName = Instance.new("TextLabel", btn)
                togName.BackgroundTransparency = 1.000
                togName.Position = UDim2.new(0.096, 0, 0.272, 0)
                togName.Size = UDim2.new(0, 138, 0, 14)
                togName.Font = Enum.Font.GothamSemibold
                togName.Text = tname or "Textbox"
                togName.TextSize = 14.000
                togName.TextXAlignment = Enum.TextXAlignment.Left
                RegisterTheme(togName, "TextColor3", "TextColor")

                local TextBox = Instance.new("TextBox", btn)
                TextBox.BorderSizePixel = 0
                TextBox.Position = UDim2.new(0.488, 0, 0.212, 0)
                TextBox.Size = UDim2.new(0, 150, 0, 18)
                TextBox.ClearTextOnFocus = false
                TextBox.Font = Enum.Font.Gotham
                TextBox.PlaceholderText = "Type here!"
                TextBox.Text = ""
                TextBox.TextSize = 12.000
                Instance.new("UICorner", TextBox).CornerRadius = UDim.new(0, 4)
                
                RegisterTheme(TextBox, "BackgroundColor3", "ElementColor", function(c)
                    return Color3.fromRGB(math.clamp(c.r*255-6,0,255), math.clamp(c.g*255-6,0,255), math.clamp(c.b*255-7,0,255))
                end)
                RegisterTheme(TextBox, "PlaceholderColor3", "SchemeColor", function(c)
                    return Color3.fromRGB(math.clamp(c.r*255-19,0,255), math.clamp(c.g*255-26,0,255), math.clamp(c.b*255-35,0,255))
                end)
                RegisterTheme(TextBox, "TextColor3", "SchemeColor")

                local viewInfo = Instance.new("ImageButton", btn)
                viewInfo.BackgroundTransparency = 1.000
                viewInfo.Position = UDim2.new(0.93, 0, 0.151, 0)
                viewInfo.Size = UDim2.new(0, 23, 0, 23)
                viewInfo.Image = "rbxassetid://3926305904"
                viewInfo.ImageRectOffset = Vector2.new(764, 764)
                viewInfo.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(viewInfo, "ImageColor3", "SchemeColor")

                local moreInfo = CreateMoreInfo(tTip or "Gets a value of Textbox")
                Utility:SetupTooltip(viewInfo, moreInfo, btn, infoContainer, blurFrame, state, themeList, Connect)
                BindHover(btn, state)

                Connect(TextBox.FocusLost, function(EnterPressed)
                    if callback then callback(TextBox.Text) end
                end)
                return {Frame=btn, TextBox=TextBox}
            end

            function Elements:NewToggle(tname, nTip, callback)
                local TogFunction = {}
                local toggled = false
                tname = tname or "Toggle"
                callback = callback or function() end

                local btn = Instance.new("TextButton", sectionInners)
                btn.Size = UDim2.new(0, 352, 0, 33)
                btn.AutoButtonColor = false
                btn.Text = ""
                RegisterTheme(btn, "BackgroundColor3", "ElementColor")
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                btn.ClipsDescendants = true

                local toggleDisabled = Instance.new("ImageLabel", btn)
                toggleDisabled.BackgroundTransparency = 1.000
                toggleDisabled.Position = UDim2.new(0.019, 0, 0.18, 0)
                toggleDisabled.Size = UDim2.new(0, 21, 0, 21)
                toggleDisabled.Image = "rbxassetid://3926309567"
                toggleDisabled.ImageRectOffset = Vector2.new(628, 420)
                toggleDisabled.ImageRectSize = Vector2.new(48, 48)
                RegisterTheme(toggleDisabled, "ImageColor3", "SchemeColor")

                local toggleEnabled = Instance.new("ImageLabel", btn)
                toggleEnabled.BackgroundTransparency = 1.000
                toggleEnabled.Position = UDim2.new(0.019, 0, 0.18, 0)
                toggleEnabled.Size = UDim2.new(0, 21, 0, 21)
                toggleEnabled.Image = "rbxassetid://3926309567"
                toggleEnabled.ImageRectOffset = Vector2.new(784, 420)
                toggleEnabled.ImageRectSize = Vector2.new(48, 48)
                toggleEnabled.ImageTransparency = 1.000
                RegisterTheme(toggleEnabled, "ImageColor3", "SchemeColor")

                local togName = Instance.new("TextLabel", btn)
                togName.BackgroundTransparency = 1.000
                togName.Position = UDim2.new(0.096, 0, 0.272, 0)
                togName.Size = UDim2.new(0, 288, 0, 14)
                togName.Font = Enum.Font.GothamSemibold
                togName.Text = tname
                togName.TextSize = 14.000
                togName.TextXAlignment = Enum.TextXAlignment.Left
                RegisterTheme(togName, "TextColor3", "TextColor")

                local viewInfo = Instance.new("ImageButton", btn)
                viewInfo.BackgroundTransparency = 1.000
                viewInfo.Position = UDim2.new(0.93, 0, 0.151, 0)
                viewInfo.Size = UDim2.new(0, 23, 0, 23)
                viewInfo.Image = "rbxassetid://3926305904"
                viewInfo.ImageRectOffset = Vector2.new(764, 764)
                viewInfo.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(viewInfo, "ImageColor3", "SchemeColor")

                local moreInfo = CreateMoreInfo(nTip or "Prints Current Toggle State")
                Utility:SetupTooltip(viewInfo, moreInfo, btn, infoContainer, blurFrame, state, themeList, Connect)
                BindHover(btn, state)

                Connect(btn.MouseButton1Click, function()
                    if not state.focusing then
                        toggled = not toggled
                        Utility:TweenObject(toggleEnabled, {ImageTransparency = toggled and 0 or 1}, 0.11)
                        Utility:CreateRipple(btn, themeList.SchemeColor)
                        pcall(callback, toggled)
                    end
                end)

                function TogFunction:UpdateToggle(newText, isTogOn)
                    if newText then togName.Text = newText end
                    toggled = isTogOn
                    Utility:TweenObject(toggleEnabled, {ImageTransparency = toggled and 0 or 1}, 0.11)
                    pcall(callback, toggled)
                end
                TogFunction.Frame=btn
                return TogFunction
            end

            function Elements:NewSlider(slidInf, slidTip, maxvalue, minvalue, callback)
                minvalue = minvalue or 16
                maxvalue = maxvalue or 500

                local btn = Instance.new("TextButton", sectionInners)
                btn.Size = UDim2.new(0, 352, 0, 33)
                btn.AutoButtonColor = false
                btn.Text = ""
                RegisterTheme(btn, "BackgroundColor3", "ElementColor")
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                btn.ClipsDescendants = true

                local write = Instance.new("ImageLabel", btn)
                write.BackgroundTransparency = 1.000
                write.Position = UDim2.new(0.019, 0, 0.18, 0)
                write.Size = UDim2.new(0, 21, 0, 21)
                write.Image = "rbxassetid://3926307971"
                write.ImageRectOffset = Vector2.new(404, 164)
                write.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(write, "ImageColor3", "SchemeColor")

                local togName = Instance.new("TextLabel", btn)
                togName.BackgroundTransparency = 1.000
                togName.Position = UDim2.new(0.096, 0, 0.272, 0)
                togName.Size = UDim2.new(0, 138, 0, 14)
                togName.Font = Enum.Font.GothamSemibold
                togName.Text = slidInf or "Slider"
                togName.TextSize = 14.000
                togName.TextXAlignment = Enum.TextXAlignment.Left
                RegisterTheme(togName, "TextColor3", "TextColor")

                local val = Instance.new("TextLabel", btn)
                val.BackgroundTransparency = 1.000
                val.Position = UDim2.new(0.352, 0, 0.272, 0)
                val.Size = UDim2.new(0, 41, 0, 14)
                val.Font = Enum.Font.GothamSemibold
                val.Text = tostring(minvalue)
                val.TextSize = 14.000
                val.TextTransparency = 1.000
                val.TextXAlignment = Enum.TextXAlignment.Right
                RegisterTheme(val, "TextColor3", "TextColor")

                local sliderBtn = Instance.new("TextButton", btn)
                sliderBtn.BorderSizePixel = 0
                sliderBtn.Position = UDim2.new(0.488, 0, 0.393, 0)
                sliderBtn.Size = UDim2.new(0, 149, 0, 6)
                sliderBtn.AutoButtonColor = false
                sliderBtn.Text = ""
                Instance.new("UICorner", sliderBtn)
                RegisterTheme(sliderBtn, "BackgroundColor3", "ElementColor", function(c)
                    return Color3.fromRGB(math.clamp(c.r*255+5,0,255), math.clamp(c.g*255+5,0,255), math.clamp(c.b*255+5,0,255))
                end)
                
                local UIListLayout = Instance.new("UIListLayout", sliderBtn)
                UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center

                local sliderDrag = Instance.new("Frame", sliderBtn)
                sliderDrag.BorderSizePixel = 0
                sliderDrag.Size = UDim2.new(0, 0, 1, 0)
                Instance.new("UICorner", sliderDrag)
                RegisterTheme(sliderDrag, "BackgroundColor3", "SchemeColor")

                local viewInfo = Instance.new("ImageButton", btn)
                viewInfo.BackgroundTransparency = 1.000
                viewInfo.Position = UDim2.new(0.93, 0, 0.151, 0)
                viewInfo.Size = UDim2.new(0, 23, 0, 23)
                viewInfo.Image = "rbxassetid://3926305904"
                viewInfo.ImageRectOffset = Vector2.new(764, 764)
                viewInfo.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(viewInfo, "ImageColor3", "SchemeColor")

                local moreInfo = CreateMoreInfo(slidTip or "Slider tip here")
                Utility:SetupTooltip(viewInfo, moreInfo, btn, infoContainer, blurFrame, state, themeList, Connect)
                BindHover(btn, state)

                local mouse = players.LocalPlayer:GetMouse()
                local uis = game:GetService("UserInputService")
                local Value = minvalue

                local dragging
                local sliderHandle={Frame=btn}
                function sliderHandle:Cancel()
                    dragging=nil
                    val.TextTransparency=0
                end
                table.insert(interactions,function()sliderHandle:Cancel()end)
                local function updateSlider(x)
                    local fraction=math.clamp((x-sliderBtn.AbsolutePosition.X)/math.max(sliderBtn.AbsoluteSize.X,1),0,1)
                    Value=minvalue+(maxvalue-minvalue)*fraction
                    sliderDrag.Size=UDim2.new(fraction,0,0,6)
                    val.Text=tostring(Value)
                    val.TextTransparency=0
                    if callback then callback(Value)end
                end
                Connect(sliderBtn.InputBegan,function(pointer)
                    if state.focusing or sliderHandle.Disabled then return end
                    if pointer.UserInputType==Enum.UserInputType.Touch or pointer.UserInputType==Enum.UserInputType.MouseButton1 then
                        dragging=pointer
                        updateSlider(pointer.Position.X)
                    end
                end)
                Connect(uis.InputChanged,function(pointer)
                    if not dragging then return end
                    if pointer==dragging or (dragging.UserInputType==Enum.UserInputType.MouseButton1 and pointer.UserInputType==Enum.UserInputType.MouseMovement)then
                        updateSlider(pointer.Position.X)
                    end
                end)
                Connect(uis.InputEnded,function(pointer)
                    if pointer==dragging then sliderHandle:Cancel()end
                end)
                function sliderHandle:Set(value)
                    Value=math.clamp(value,minvalue,maxvalue)
                    val.Text=tostring(Value)
                    val.TextTransparency=0
                    sliderDrag.Size=UDim2.new(maxvalue==minvalue and 0 or (Value-minvalue)/(maxvalue-minvalue),0,0,6)
                end
                return sliderHandle
            end

            function Elements:NewDropdown(dropname, dropinf, list, callback)
                local DropFunction = {}
                local opened = false
                local dropFrame = Instance.new("Frame", sectionInners)
                dropFrame.BorderSizePixel = 0
                dropFrame.Size = UDim2.new(0, 352, 0, 33)
                dropFrame.ClipsDescendants = true
                RegisterTheme(dropFrame, "BackgroundColor3", "Background")

                local UIListLayout = Instance.new("UIListLayout", dropFrame)
                UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                UIListLayout.Padding = UDim.new(0, 3)

                local dropOpen = Instance.new("TextButton", dropFrame)
                dropOpen.Size = UDim2.new(0, 352, 0, 33)
                dropOpen.AutoButtonColor = false
                dropOpen.Text = ""
                RegisterTheme(dropOpen, "BackgroundColor3", "ElementColor")
                Instance.new("UICorner", dropOpen).CornerRadius = UDim.new(0, 4)

                local listImg = Instance.new("ImageLabel", dropOpen)
                listImg.BackgroundTransparency = 1.000
                listImg.Position = UDim2.new(0.019, 0, 0.18, 0)
                listImg.Size = UDim2.new(0, 21, 0, 21)
                listImg.Image = "rbxassetid://3926305904"
                listImg.ImageRectOffset = Vector2.new(644, 364)
                listImg.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(listImg, "ImageColor3", "SchemeColor")

                local itemTextbox = Instance.new("TextLabel", dropOpen)
                itemTextbox.BackgroundTransparency = 1.000
                itemTextbox.Position = UDim2.new(0.097, 0, 0.273, 0)
                itemTextbox.Size = UDim2.new(0, 138, 0, 14)
                itemTextbox.Font = Enum.Font.GothamSemibold
                itemTextbox.Text = dropname or "Dropdown"
                itemTextbox.TextSize = 14.000
                itemTextbox.TextXAlignment = Enum.TextXAlignment.Left
                RegisterTheme(itemTextbox, "TextColor3", "TextColor")

                local viewInfo = Instance.new("ImageButton", dropOpen)
                viewInfo.BackgroundTransparency = 1.000
                viewInfo.Position = UDim2.new(0.93, 0, 0.151, 0)
                viewInfo.Size = UDim2.new(0, 23, 0, 23)
                viewInfo.Image = "rbxassetid://3926305904"
                viewInfo.ImageRectOffset = Vector2.new(764, 764)
                viewInfo.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(viewInfo, "ImageColor3", "SchemeColor")

                local moreInfo = CreateMoreInfo(dropinf or "Dropdown info")
                Utility:SetupTooltip(viewInfo, moreInfo, dropOpen, infoContainer, blurFrame, state, themeList, Connect)
                BindHover(dropOpen, state)

                Connect(dropOpen.MouseButton1Click, function()
                    if not state.focusing then
                        opened = not opened
                        local ySize = opened and UIListLayout.AbsoluteContentSize.Y or 33
                        dropFrame:TweenSize(UDim2.new(0, 352, 0, ySize), "InOut", "Linear", 0.08, true)
                        Utility:CreateRipple(dropOpen, themeList.SchemeColor)
                    end
                end)

                local function AddOptions(newList)
                    for _, v in next, newList do
                        local optionSelect = Instance.new("TextButton", dropFrame)
                        optionSelect.Size = UDim2.new(0, 352, 0, 33)
                        optionSelect.AutoButtonColor = false
                        optionSelect.Font = Enum.Font.GothamSemibold
                        optionSelect.Text = "  " .. v
                        optionSelect.TextSize = 14.000
                        optionSelect.TextXAlignment = Enum.TextXAlignment.Left
                        optionSelect.ClipsDescendants = true
                        Instance.new("UICorner", optionSelect).CornerRadius = UDim.new(0, 4)
                        
                        RegisterTheme(optionSelect, "BackgroundColor3", "ElementColor")
                        RegisterTheme(optionSelect, "TextColor3", "TextColor", function(c)
                            return Color3.fromRGB(math.clamp(c.r*255-6,0,255), math.clamp(c.g*255-6,0,255), math.clamp(c.b*255-6,0,255))
                        end)
                        BindHover(optionSelect, state)

                        Connect(optionSelect.MouseButton1Click, function()
                            if not state.focusing then
                                opened = false
                                callback(v)
                                itemTextbox.Text = v
                                dropFrame:TweenSize(UDim2.new(0, 352, 0, 33), 'InOut', 'Linear', 0.08)
                                Utility:CreateRipple(optionSelect, themeList.SchemeColor)
                            end
                        end)
                    end
                end
                
                if list then AddOptions(list) end

                function DropFunction:Refresh(newList)
                    for _, v in ipairs(dropFrame:GetChildren()) do
                        if v:IsA("TextButton") and v ~= dropOpen then v:Destroy() end
                    end
                    AddOptions(newList or {})
                    if opened then
                        dropFrame:TweenSize(UDim2.new(0, 352, 0, UIListLayout.AbsoluteContentSize.Y), "InOut", "Linear", 0.08, true)
                    end
                end
                DropFunction.Frame=dropFrame
                function DropFunction:Set(value) itemTextbox.Text=value or dropname end
                return DropFunction
            end

            function Elements:NewKeybind(keytext, keyinf, first, callback)
                local oldKey = first.Name
                local btn = Instance.new("TextButton", sectionInners)
                btn.Size = UDim2.new(0, 352, 0, 33)
                btn.AutoButtonColor = false
                btn.Text = ""
                RegisterTheme(btn, "BackgroundColor3", "ElementColor")
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                btn.ClipsDescendants = true

                local touch = Instance.new("ImageLabel", btn)
                touch.BackgroundTransparency = 1.000
                touch.Position = UDim2.new(0.019, 0, 0.18, 0)
                touch.Size = UDim2.new(0, 21, 0, 21)
                touch.Image = "rbxassetid://3926305904"
                touch.ImageRectOffset = Vector2.new(364, 284)
                touch.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(touch, "ImageColor3", "SchemeColor")

                local togName = Instance.new("TextLabel", btn)
                togName.BackgroundTransparency = 1.000
                togName.Position = UDim2.new(0.096, 0, 0.272, 0)
                togName.Size = UDim2.new(0, 222, 0, 14)
                togName.Font = Enum.Font.GothamSemibold
                togName.Text = keytext or "KeybindText"
                togName.TextSize = 14.000
                togName.TextXAlignment = Enum.TextXAlignment.Left
                RegisterTheme(togName, "TextColor3", "TextColor")

                local togName_2 = Instance.new("TextLabel", btn)
                togName_2.BackgroundTransparency = 1.000
                togName_2.Position = UDim2.new(0.727, 0, 0.272, 0)
                togName_2.Size = UDim2.new(0, 70, 0, 14)
                togName_2.Font = Enum.Font.GothamSemibold
                togName_2.Text = oldKey
                togName_2.TextSize = 14.000
                togName_2.TextXAlignment = Enum.TextXAlignment.Right
                RegisterTheme(togName_2, "TextColor3", "SchemeColor")

                local viewInfo = Instance.new("ImageButton", btn)
                viewInfo.BackgroundTransparency = 1.000
                viewInfo.Position = UDim2.new(0.93, 0, 0.151, 0)
                viewInfo.Size = UDim2.new(0, 23, 0, 23)
                viewInfo.Image = "rbxassetid://3926305904"
                viewInfo.ImageRectOffset = Vector2.new(764, 764)
                viewInfo.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(viewInfo, "ImageColor3", "SchemeColor")

                local moreInfo = CreateMoreInfo(keyinf or "KebindInfo")
                Utility:SetupTooltip(viewInfo, moreInfo, btn, infoContainer, blurFrame, state, themeList, Connect)
                BindHover(btn, state)

                local keyHandle={Frame=btn}
                local capturing=false
                function keyHandle:Set(key)
                    oldKey=key.Name
                    togName_2.Text=oldKey
                end
                function keyHandle:Cancel()
                    capturing=false
                    if Tabs.Capturing==keyHandle then Tabs.Capturing=nil end
                    togName_2.Text=oldKey
                end
                Connect(btn.MouseButton1Click,function()
                    if state.focusing then return end
                    if Tabs.Capturing then Tabs.Capturing:Cancel() end
                    capturing=true;Tabs.Capturing=keyHandle;togName_2.Text=". . ."
                end)
                Connect(input.InputBegan,function(current,processed)
                    if capturing then
                        if current.UserInputType~=Enum.UserInputType.Keyboard then return end
                        keyHandle:Cancel()
                        if current.KeyCode~=Enum.KeyCode.Escape and current.KeyCode~=Enum.KeyCode.Unknown then
                            keyHandle:Set(current.KeyCode)
                            if keyHandle.OnChanged then keyHandle.OnChanged(current.KeyCode) end
                        end
                    elseif not Tabs.Capturing and not processed and not input:GetFocusedTextBox() and current.KeyCode.Name==oldKey then
                        if callback then callback() end
                    end
                end)
                return keyHandle
            end

            function Elements:NewColorPicker(colText, colInf, defcolor, callback)
                defcolor = defcolor or Color3.fromRGB(255,255,255)
                local h, s, v = Color3.toHSV(defcolor)
                local colorOpened = false

                local btn = Instance.new("TextButton", sectionInners)
                btn.BackgroundTransparency = 1.000
                btn.Size = UDim2.new(0, 352, 0, 33)
                btn.AutoButtonColor = false
                btn.Text = ""
                btn.ClipsDescendants = true
                RegisterTheme(btn, "BackgroundColor3", "ElementColor")
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

                local colorHeader = Instance.new("Frame", btn)
                colorHeader.Size = UDim2.new(0, 352, 0, 33)
                colorHeader.ClipsDescendants = true
                RegisterTheme(colorHeader, "BackgroundColor3", "ElementColor")
                Instance.new("UICorner", colorHeader).CornerRadius = UDim.new(0, 4)

                local touch = Instance.new("ImageLabel", colorHeader)
                touch.BackgroundTransparency = 1.000
                touch.Position = UDim2.new(0.019, 0, 0.18, 0)
                touch.Size = UDim2.new(0, 21, 0, 21)
                touch.Image = "rbxassetid://3926305904"
                touch.ImageRectOffset = Vector2.new(44, 964)
                touch.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(touch, "ImageColor3", "SchemeColor")

                local togName = Instance.new("TextLabel", colorHeader)
                togName.BackgroundTransparency = 1.000
                togName.Position = UDim2.new(0.096, 0, 0.272, 0)
                togName.Size = UDim2.new(0, 288, 0, 14)
                togName.Font = Enum.Font.GothamSemibold
                togName.Text = colText or "ColorPicker"
                togName.TextSize = 14.000
                togName.TextXAlignment = Enum.TextXAlignment.Left
                RegisterTheme(togName, "TextColor3", "TextColor")

                local colorCurrent = Instance.new("Frame", colorHeader)
                colorCurrent.BackgroundColor3 = defcolor
                colorCurrent.Position = UDim2.new(0.793, 0, 0.212, 0)
                colorCurrent.Size = UDim2.new(0, 42, 0, 18)
                Instance.new("UICorner", colorCurrent).CornerRadius = UDim.new(0, 4)

                local viewInfo = Instance.new("ImageButton", colorHeader)
                viewInfo.BackgroundTransparency = 1.000
                viewInfo.Position = UDim2.new(0.93, 0, 0.151, 0)
                viewInfo.Size = UDim2.new(0, 23, 0, 23)
                viewInfo.Image = "rbxassetid://3926305904"
                viewInfo.ImageRectOffset = Vector2.new(764, 764)
                viewInfo.ImageRectSize = Vector2.new(36, 36)
                RegisterTheme(viewInfo, "ImageColor3", "SchemeColor")

                local moreInfo = CreateMoreInfo(colInf or "ColorPicker info")
                Utility:SetupTooltip(viewInfo, moreInfo, btn, infoContainer, blurFrame, state, themeList, Connect)
                BindHover(btn, state)

                local UIListLayout = Instance.new("UIListLayout", btn)
                UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                UIListLayout.Padding = UDim.new(0, 3)

                local colorInners = Instance.new("Frame", btn)
                colorInners.Position = UDim2.new(0, 0, 0.255, 0)
                colorInners.Size = UDim2.new(0, 352, 0, 105)
                RegisterTheme(colorInners, "BackgroundColor3", "ElementColor")
                Instance.new("UICorner", colorInners).CornerRadius = UDim.new(0, 4)

                local rgb = Instance.new("ImageButton", colorInners)
                rgb.BackgroundTransparency = 1.000
                rgb.Position = UDim2.new(0.02, 0, 0.048, 0)
                rgb.Size = UDim2.new(0, 211, 0, 93)
                rgb.Image = "http://www.roblox.com/asset/?id=6523286724"
                Instance.new("UICorner", rgb).CornerRadius = UDim.new(0, 4)

                local rbgcircle = Instance.new("ImageLabel", rgb)
                rbgcircle.BackgroundTransparency = 1.000
                rbgcircle.Size = UDim2.new(0, 14, 0, 14)
                rbgcircle.Image = "rbxassetid://3926309567"
                rbgcircle.ImageColor3 = Color3.fromRGB(0, 0, 0)
                rbgcircle.ImageRectOffset = Vector2.new(628, 420)
                rbgcircle.ImageRectSize = Vector2.new(48, 48)

                local darkness = Instance.new("ImageButton", colorInners)
                darkness.BackgroundTransparency = 1.000
                darkness.Position = UDim2.new(0.636, 0, 0.048, 0)
                darkness.Size = UDim2.new(0, 18, 0, 93)
                darkness.Image = "http://www.roblox.com/asset/?id=6523291212"
                Instance.new("UICorner", darkness).CornerRadius = UDim.new(0, 4)

                local darkcircle = Instance.new("ImageLabel", darkness)
                darkcircle.AnchorPoint = Vector2.new(0.5, 0)
                darkcircle.BackgroundTransparency = 1.000
                darkcircle.Size = UDim2.new(0, 14, 0, 14)
                darkcircle.Image = "rbxassetid://3926309567"
                darkcircle.ImageColor3 = Color3.fromRGB(0, 0, 0)
                darkcircle.ImageRectOffset = Vector2.new(628, 420)
                darkcircle.ImageRectSize = Vector2.new(48, 48)

                Connect(btn.MouseButton1Click, function()
                    if not state.focusing then
                        colorOpened = not colorOpened
                        btn:TweenSize(UDim2.new(0, 352, 0, colorOpened and 141 or 33), "InOut", "Linear", 0.08, true)
                        Utility:CreateRipple(colorHeader, themeList.SchemeColor)
                    end
                end)

                -- Color Math Logic
                local mouse = players.LocalPlayer:GetMouse()
                local uis = game:GetService('UserInputService')
                local colorpicker = false
                local darknesss = false
                local color = {h,s,v}
                
                local function setcolor(tbl)
                    local cx = rbgcircle.AbsoluteSize.X/2
                    local cy = rbgcircle.AbsoluteSize.Y/2
                    color = {tbl[1],tbl[2],tbl[3]}
                    rbgcircle.Position = UDim2.new(color[1],-cx,color[2]-1,-cy)
                    darkcircle.Position = UDim2.new(0.5,0,color[3]-1,-cy)
                    local realcolor = Color3.fromHSV(color[1],color[2],color[3])
                    colorCurrent.BackgroundColor3 = realcolor
                end
                
                local function cp()
                    if colorpicker then
                        local x,y = mouse.X - rgb.AbsolutePosition.X, mouse.Y - rgb.AbsolutePosition.Y
                        local maxX,maxY = rgb.AbsoluteSize.X, rgb.AbsoluteSize.Y
                        x = math.clamp(x, 0, maxX) / maxX
                        y = math.clamp(y, 0, maxY) / maxY
                        rbgcircle.Position = UDim2.new(x, -(rbgcircle.AbsoluteSize.X/2), y, -(rbgcircle.AbsoluteSize.Y/2))
                        color = {1-x, 1-y, color[3]}
                        local realcolor = Color3.fromHSV(color[1], color[2], color[3])
                        colorCurrent.BackgroundColor3 = realcolor
                        pcall(callback, realcolor)
                    end
                    if darknesss then
                        local y = math.clamp(mouse.Y - darkness.AbsolutePosition.Y, 0, darkness.AbsoluteSize.Y) / darkness.AbsoluteSize.Y
                        darkcircle.Position = UDim2.new(0.5, 0, y, -(darkcircle.AbsoluteSize.Y/2))
                        darkcircle.ImageColor3 = Color3.fromHSV(0,0,y)
                        color = {color[1], color[2], 1-y}
                        local realcolor = Color3.fromHSV(color[1], color[2], color[3])
                        colorCurrent.BackgroundColor3 = realcolor
                        pcall(callback, realcolor)
                    end
                end

                Connect(mouse.Move, cp)
                Connect(rgb.MouseButton1Down, function() colorpicker=true end)
                Connect(darkness.MouseButton1Down, function() darknesss=true end)
                Connect(uis.InputEnded, function(input)
                    if input.UserInputType.Name == 'MouseButton1' then
                        darknesss, colorpicker = false, false
                    end
                end)
                setcolor({h,s,v})
            end
            
            function Elements:NewLabel(title)
                local labelFunctions = {}
                local label = Instance.new("TextLabel", sectionInners)
                label.BorderSizePixel = 0
                label.ClipsDescendants = true
                label.Size = UDim2.new(0, 352, 0, 33)
                label.Font = Enum.Font.Gotham
                label.Text = title
                label.RichText = true
                label.TextSize = 14.000
                label.TextXAlignment = Enum.TextXAlignment.Left
                local padding=Instance.new("UIPadding",label)
                padding.PaddingLeft=UDim.new(0,10)
                padding.PaddingRight=UDim.new(0,10)
                Instance.new("UICorner", label).CornerRadius = UDim.new(0, 4)
                
                RegisterTheme(label, "BackgroundColor3", "ElementColor")
                RegisterTheme(label, "TextColor3", "TextColor", function(c)
                    return themeList.SchemeColor == Color3.fromRGB(255,255,255) and Color3.fromRGB(0,0,0) or c
                end)

                function labelFunctions:UpdateLabel(newText)
                    label.Text = newText
                end 
                labelFunctions.Frame=label
                return labelFunctions
            end 
            return Elements
        end
        return Sections
    end  
    Tabs.Gui,Tabs.Root,Tabs.OpenButton,Tabs.Title=ScreenGui,Main,floatingToggle,title
    function Tabs:Toggle(open)
        if self._destroyed then return end
        if open==nil then open=not Main.Visible end
        if not open then
            self:CancelInteractions()
            if self.OnCancel then self.OnCancel() end
        end
        Main.Visible=open
        floatingToggle.Visible=not open
    end
    function Tabs:Destroy()
        if self._destroyed then return end
        self._destroyed=true
        self:CancelInteractions()
        if self.OnCancel then self.OnCancel() end
        alive=false
        for _,c in ipairs(connections) do c:Disconnect() end
        table.clear(connections)
        ScreenGui:Destroy()
    end
    Connect(ScreenGui.Destroying,function() Tabs:Destroy() end)
    Kavo._lastWindow=Tabs
    return Tabs
end
return Kavo
