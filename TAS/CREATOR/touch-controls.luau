-- Touch pad inspired by mobile/mobile2; uses the existing creator actions.
local Controls = {}

function Controls.bindHold(button, inputService, press, release, track)
    local held
    track(button.InputBegan:Connect(function(input)
        if held or (input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1) then return end
        held = input
        task.spawn(function() if held == input then press() end end)
    end))
    local function stop()
        if held then held = nil; release() end
    end
    track(inputService.InputEnded:Connect(function(input)
        if held == input then stop() end
    end))
    track(inputService.WindowFocusReleased:Connect(stop))
    return stop
end

function Controls.create(parent, actions, track)
    local inputService = game:GetService("UserInputService")
    local panel = Instance.new("Frame")
    panel.Name = "TouchControls"
    panel.Size = UDim2.fromOffset(224, 280)
    panel.Position = UDim2.new(1, -234, 0.2, 0)
    panel.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    panel.Visible = inputService.TouchEnabled
    panel.Parent = parent
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
    local title = Instance.new("TextButton", panel)
    title.Size = UDim2.new(1, 0, 0, 32)
    title.Text = "TAS controls   −"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    local body = Instance.new("ScrollingFrame", panel)
    body.Position = UDim2.fromOffset(6, 38)
    body.Size = UDim2.new(1, -12, 1, -44)
    body.BackgroundTransparency = 1
    body.ScrollBarThickness = 4
    body.AutomaticCanvasSize = Enum.AutomaticSize.Y
    body.CanvasSize = UDim2.new()
    local grid = Instance.new("UIGridLayout", body)
    grid.CellSize = UDim2.new(0.5, -5, 0, 38)
    grid.CellPadding = UDim2.fromOffset(4, 4)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    local stops = {}
    for index, action in ipairs(actions) do
        local button = Instance.new("TextButton", body)
        button.Name = action.name
        button.LayoutOrder = index
        button.Text = action.name
        button.Font = Enum.Font.Gotham
        button.TextSize = 12
        button.TextWrapped = true
        button.TextColor3 = Color3.new(1, 1, 1)
        button.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 5)
        if action.release then
            table.insert(stops, Controls.bindHold(button, inputService, action.press, action.release, track))
        else
            track(button.Activated:Connect(action.press))
        end
    end
    local function releaseAll() for _, stop in ipairs(stops) do stop() end end
    track(panel:GetPropertyChangedSignal("Visible"):Connect(function() if not panel.Visible then releaseAll() end end))
    track(panel.Destroying:Connect(releaseAll))
    local dragging, start, origin, moved
    track(title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, start, origin, moved = input, input.Position, panel.AbsolutePosition, false
        end
    end))
    track(inputService.InputChanged:Connect(function(input)
        if not dragging or (input ~= dragging and input.UserInputType ~= Enum.UserInputType.MouseMovement) then return end
        local delta = input.Position - start
        if delta.Magnitude > 5 then moved = true end
        if moved then
            local viewport = workspace.CurrentCamera.ViewportSize
            panel.Position = UDim2.fromOffset(math.clamp(origin.X + delta.X, 0, math.max(0, viewport.X - panel.AbsoluteSize.X)), math.clamp(origin.Y + delta.Y, 0, math.max(0, viewport.Y - panel.AbsoluteSize.Y)))
        end
    end))
    track(inputService.InputEnded:Connect(function(input) if input == dragging then dragging = nil end end))
    track(title.Activated:Connect(function()
        if moved then return end
        releaseAll()
        body.Visible = not body.Visible
        panel.Size = UDim2.fromOffset(224, body.Visible and 280 or 32)
        title.Text = body.Visible and "TAS controls   −" or "TAS controls   +"
    end))
    return panel, releaseAll
end
return Controls
