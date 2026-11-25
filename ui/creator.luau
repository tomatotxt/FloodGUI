-- FloodGUI TAS Creator HUD & Tabbed Menu
-- Remade from Flood-GUI (testing branch TAS/CREATOR/uiapi.luau) as a dedicated
-- bottom-docked telemetry HUD + expandable tabbed panel, upgraded with PlayerGui
-- hosting, responsive scaling, interactive keybind capture, smoothing slider,
-- searchable run explorer, and a matching draggable touch hold pad.

local Runtime = assert(getgenv().FloodGUIRuntime, "Start FloodGUI through loader.lua")
local UI = Runtime.run("ui/service.luau")

local TAS_UI = {}

local THEME = {
	Background = Color3.fromRGB(25, 25, 30),
	Surface = Color3.fromRGB(32, 32, 38),
	TabBg = Color3.fromRGB(35, 35, 42),
	Stroke = Color3.fromRGB(60, 60, 72),
	TextMain = Color3.fromRGB(240, 240, 245),
	TextDim = Color3.fromRGB(175, 175, 185),
	Accent = Color3.fromRGB(85, 170, 255),
	Alert = Color3.fromRGB(255, 200, 80),
	ActiveOn = Color3.fromRGB(0, 150, 100),
	GreenBtn = Color3.fromRGB(40, 92, 48),
	RedBtn = Color3.fromRGB(95, 40, 45),
	Danger = Color3.fromRGB(150, 25, 30),
	Button = Color3.fromRGB(45, 45, 55),
	ButtonHover = Color3.fromRGB(55, 55, 68),
}

local SHORT_KEY_NAMES = {
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
	Zero = "0",
	Delete = "Del",
	Equals = "=",
	Minus = "-",
	Return = "Enter",
	BackSlash = "\\",
}

local function formatKey(keyName)
	if type(keyName) ~= "string" or keyName == "" then
		return "?"
	end
	return SHORT_KEY_NAMES[keyName] or keyName
end

local function create(className, parent, props)
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			inst[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function makeDraggable(handle, target, connect)
	local uis = game:GetService("UserInputService")
	local dragging = false
	local dragInput, dragStart, startPos

	connect(handle.InputBegan, function(inputObj)
		if
			inputObj.UserInputType == Enum.UserInputType.MouseButton1
			or inputObj.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = inputObj.Position
			startPos = target.Position
			connect(inputObj.Changed, function()
				if inputObj.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	connect(handle.InputChanged, function(inputObj)
		if
			inputObj.UserInputType == Enum.UserInputType.MouseMovement
			or inputObj.UserInputType == Enum.UserInputType.Touch
		then
			dragInput = inputObj
		end
	end)

	connect(uis.InputChanged, function(inputObj)
		if inputObj == dragInput and dragging and dragStart and startPos then
			local delta = inputObj.Position - dragStart
			target.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	connect(uis.WindowFocusReleased, function()
		dragging = false
	end)
end

function TAS_UI.Create()
	local Players = game:GetService("Players")
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")
	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = assert(LocalPlayer:WaitForChild("PlayerGui", 10), "TAS Creator requires local PlayerGui")

	-- Clean up any stale TAS_HUD in PlayerGui
	for _, child in ipairs(PlayerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child.Name == "TAS_HUD" then
			child:Destroy()
		end
	end

	-- Minimize main FloodGUI Kavo menu while creator HUD is active
	if UI and UI.windows and UI.windows.main and not UI.windows.main._destroyed then
		pcall(function()
			UI.windows.main:Toggle(false)
		end)
	end

	-- Preserve FE2 Alerts inside LocatorGui while hiding GameGui's bottom bar
	local GameGui = PlayerGui:FindFirstChild("GameGui")
	local LocatorGui = PlayerGui:FindFirstChild("LocatorGui")
	local AlertsFrame = GameGui and GameGui:FindFirstChild("Alerts")
	local previousGameGuiEnabled = GameGui and GameGui.Enabled
	local movedAlerts = false

	if AlertsFrame and LocatorGui then
		AlertsFrame.Parent = LocatorGui
		movedAlerts = true
	end
	if GameGui then
		GameGui.Enabled = false
	end

	local alive = true
	local connections = {}
	local function connect(signal, fn)
		if not signal then
			return nil
		end
		local conn = signal:Connect(function(...)
			if alive then
				fn(...)
			end
		end)
		table.insert(connections, conn)
		return conn
	end

	-- 1. Root ScreenGui (hosted in PlayerGui above game HUDs)
	local ScreenGui = create("ScreenGui", PlayerGui, {
		Name = "TAS_HUD",
		DisplayOrder = 1000000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
	})

	local capturingBind = nil
	local capturedInput = nil
	local removeBlocker = nil
	if UI and type(UI.addKeyboardBlocker) == "function" then
		removeBlocker = UI.addKeyboardBlocker(function(pressed)
			if not alive then
				return false
			end
			return capturingBind ~= nil or (pressed ~= nil and capturedInput == pressed)
		end)
	end

	-- 2. Bottom-Centered Horizontal Layout Container (StatsPanel + MenuFrame)
	local Container = create("Frame", ScreenGui, {
		Name = "LayoutContainer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.955, 0),
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
	})

	local HUDScale = create("UIScale", Container, { Name = "HUDScale", Scale = 1 })

	create("UIListLayout", Container, {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 14),
	})

	-- 3. Compact Live Telemetry StatsPanel
	local StatsPanel = create("Frame", Container, {
		Name = "StatsPanel",
		BackgroundColor3 = THEME.Background,
		BackgroundTransparency = 0.12,
		LayoutOrder = 1,
		Size = UDim2.new(0, 360, 0, 88),
		Active = true,
	})
	create("UICorner", StatsPanel, { CornerRadius = UDim.new(0, 12) })
	create("UIStroke", StatsPanel, {
		Color = THEME.Stroke,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	local TimeText = create("TextLabel", StatsPanel, {
		Name = "TimeText",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.045, 0, 0.08, 0),
		Size = UDim2.new(0.39, 0, 0.50, 0),
		Font = Enum.Font.Highway,
		Text = "0:00.000",
		TextColor3 = THEME.TextMain,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local StatusBadge = create("TextLabel", StatsPanel, {
		Name = "StatusBadge",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.445, 0, 0.16, 0),
		Size = UDim2.new(0.15, 0, 0.22, 0),
		Font = Enum.Font.GothamBold,
		Text = "PAUSED",
		TextColor3 = THEME.Alert,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local function createRightStat(name, text, posY)
		return create("TextLabel", StatsPanel, {
			Name = name,
			BackgroundTransparency = 1,
			Position = UDim2.new(0.60, 0, posY, 0),
			Size = UDim2.new(0.355, 0, 0.21, 0),
			Font = Enum.Font.Highway,
			Text = text,
			TextColor3 = THEME.TextDim,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end

	local SavestatesCount = createRightStat("SavestatesCount", "States: 0", 0.12)
	local FrameCount = createRightStat("FrameCount", "Frames: 0", 0.36)

	local MenuToggleButton = create("TextButton", StatsPanel, {
		Name = "MenuToggleButton",
		BackgroundColor3 = Color3.fromRGB(40, 40, 48),
		Position = UDim2.new(0.60, 0, 0.62, 0),
		Size = UDim2.new(0.355, 0, 0.27, 0),
		Font = Enum.Font.GothamBold,
		Text = "Open Menu",
		TextColor3 = THEME.TextMain,
		TextSize = 13,
		AutoButtonColor = true,
	})
	create("UICorner", MenuToggleButton, { CornerRadius = UDim.new(0, 6) })
	create("UIStroke", MenuToggleButton, {
		Color = THEME.Stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	local MapEventInfo = create("TextLabel", StatsPanel, {
		Name = "MapEventInfo",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.045, 0, 0.63, 0),
		Size = UDim2.new(0.53, 0, 0.25, 0),
		Font = Enum.Font.GothamBold,
		Text = "Waiting for map...",
		TextColor3 = THEME.Accent,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- 4. Expandable Tabbed MenuFrame
	local MenuFrame = create("Frame", Container, {
		Name = "MenuFrame",
		BackgroundColor3 = THEME.Background,
		BackgroundTransparency = 0.08,
		LayoutOrder = 2,
		Size = UDim2.new(0, 304, 0, 425),
		Visible = false,
		ClipsDescendants = true,
		Active = true,
	})
	create("UICorner", MenuFrame, { CornerRadius = UDim.new(0, 10) })
	local MFStroke = create("UIStroke", MenuFrame, {
		Color = THEME.Accent,
		Transparency = 0.45,
		Thickness = 1.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	-- 5. Tab Bar & Pages
	local TabBar = create("Frame", MenuFrame, {
		Name = "TabBar",
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = THEME.TabBg,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	})
	create("UIListLayout", TabBar, {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local PagesContainer = create("Frame", MenuFrame, {
		Name = "PagesContainer",
		Position = UDim2.new(0, 0, 0, 38),
		Size = UDim2.new(1, 0, 1, -38),
		BackgroundTransparency = 1,
	})

	local Tabs = {}
	local TabIndicators = {}
	local Pages = {}

	local function cancelKeyCapture()
		if capturingBind then
			local prev = capturingBind
			capturingBind = nil
			prev.refresh()
		end
	end

	local function createPage(name, order)
		local tabBtn = create("TextButton", TabBar, {
			Name = name .. "Tab",
			Size = UDim2.new(0.25, 0, 1, 0),
			LayoutOrder = order,
			BackgroundColor3 = THEME.TabBg,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = name,
			Font = Enum.Font.GothamBold,
			TextColor3 = THEME.TextDim,
			TextSize = 12,
		})

		local indicator = create("Frame", tabBtn, {
			Name = "ActiveBar",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(0.7, 0, 0, 2),
			BackgroundColor3 = THEME.Accent,
			BorderSizePixel = 0,
			Visible = false,
		})
		create("UICorner", indicator, { CornerRadius = UDim.new(1, 0) })

		local page = create("ScrollingFrame", PagesContainer, {
			Name = name .. "Page",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = THEME.Accent,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			Visible = false,
		})

		create("UIListLayout", page, {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		})
		create("UIPadding", page, {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		})

		Tabs[name] = tabBtn
		TabIndicators[name] = indicator
		Pages[name] = page

		connect(tabBtn.Activated, function()
			cancelKeyCapture()
			for k, p in pairs(Pages) do
				p.Visible = false
				Tabs[k].TextColor3 = THEME.TextDim
				TabIndicators[k].Visible = false
			end
			page.Visible = true
			tabBtn.TextColor3 = THEME.Accent
			indicator.Visible = true
		end)

		return page
	end

	local CtrlPage = createPage("Controls", 1)
	local ConfigPage = createPage("Config", 2)
	local FilePage = createPage("Files", 3)
	local KeysPage = createPage("Keys", 4)
	Pages.Controls.Visible = true
	Tabs.Controls.TextColor3 = THEME.Accent
	TabIndicators.Controls.Visible = true

	-- Action & Toggle Registry
	local actions = {}
	local toggles = {}
	local exportedButtons = {}
	local controlKeyLabels = {}
	local currentKeys = nil
	local itemOrder = 0
	local function nextOrder()
		itemOrder += 1
		return itemOrder
	end

	local function addSectionHeader(parent, titleText)
		return create("TextLabel", parent, {
			Name = titleText .. "Header",
			LayoutOrder = nextOrder(),
			Size = UDim2.new(0.9, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = string.upper(titleText),
			Font = Enum.Font.GothamBold,
			TextColor3 = THEME.TextDim,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	local function addActionBtn(parent, actionId, baseLabel, keySlot, color)
		local btn = create("TextButton", parent, {
			Name = actionId .. "Button",
			LayoutOrder = nextOrder(),
			Size = UDim2.new(0.9, 0, 0, 34),
			BackgroundColor3 = color or THEME.Button,
			Text = baseLabel,
			Font = Enum.Font.GothamBold,
			TextColor3 = THEME.TextMain,
			TextSize = 13,
			AutoButtonColor = true,
		})
		create("UICorner", btn, { CornerRadius = UDim.new(0, 6) })

		local handle = {
			_frame = btn,
			Button = btn,
			Kind = "Button",
		}
		local function trigger()
			if actions[actionId] then
				actions[actionId]()
			end
		end
		handle.Options = { Name = baseLabel, Callback = trigger }
		function handle:Activate()
			trigger()
		end
		connect(btn.Activated, trigger)

		if keySlot then
			controlKeyLabels[keySlot] = function(keyName)
				btn.Text = string.format("%s (%s)", baseLabel, formatKey(keyName))
			end
		end

		exportedButtons[actionId] = handle
		return handle
	end

	local function addToggleBtn(parent, toggleId, labelText, defaultValue)
		local stateValue = defaultValue == true
		local btn = create("TextButton", parent, {
			Name = toggleId .. "Toggle",
			LayoutOrder = nextOrder(),
			Size = UDim2.new(0.9, 0, 0, 34),
			BackgroundColor3 = stateValue and THEME.ActiveOn or THEME.Button,
			Text = labelText .. ": " .. (stateValue and "ON" or "OFF"),
			Font = Enum.Font.GothamBold,
			TextColor3 = THEME.TextMain,
			TextSize = 13,
			AutoButtonColor = true,
		})
		create("UICorner", btn, { CornerRadius = UDim.new(0, 6) })

		local function render()
			btn.Text = labelText .. ": " .. (stateValue and "ON" or "OFF")
			btn.BackgroundColor3 = stateValue and THEME.ActiveOn or THEME.Button
		end

		local handle = {
			_frame = btn,
			Button = btn,
			Kind = "Toggle",
		}
		function handle:Get()
			return stateValue
		end
		function handle:Set(newValue, silent)
			local normalized = newValue == true
			if silent and stateValue == normalized then
				return
			end
			stateValue = normalized
			render()
			if not silent and actions[toggleId] then
				actions[toggleId](stateValue)
			end
		end
		handle.Options = {
			Name = labelText,
			Default = stateValue,
			Callback = function(v)
				handle:Set(v, false)
			end,
		}

		connect(btn.Activated, function()
			handle:Set(not stateValue, false)
		end)

		toggles[toggleId] = handle
		exportedButtons[toggleId] = handle
		return handle
	end

	-- Populate Controls Page
	addSectionHeader(CtrlPage, "Transport & Savestates")
	addActionBtn(CtrlPage, "Pause", "Play / Pause", "UserPause", Color3.fromRGB(45, 75, 125))
	addActionBtn(CtrlPage, "AddState", "Add Savestate", "AddSavestate", THEME.GreenBtn)
	addActionBtn(CtrlPage, "RemState", "Remove Savestate", "RemoveSavestate", THEME.RedBtn)
	addActionBtn(CtrlPage, "LoadState", "Load Last State", "BackSavestate")

	addSectionHeader(CtrlPage, "Frame & Preview Tools")
	addActionBtn(CtrlPage, "StepBack", "Rewind Frame", "GoFrameBack")
	addActionBtn(CtrlPage, "StepFwd", "Step Forward", "GoFrameForward")
	addActionBtn(CtrlPage, "Resync", "Resync Visuals", "Resync")
	addActionBtn(CtrlPage, "PlayTAS", "Preview TAS", "ViewTAS", Color3.fromRGB(35, 100, 135))
	addActionBtn(CtrlPage, "Collision", "Toggle Collision", "CollisionToggler")
	addActionBtn(CtrlPage, "TouchControls", "Hold Controls Pad (F7)", nil)

	addSectionHeader(CtrlPage, "Session")
	addActionBtn(CtrlPage, "Stop", "STOP CREATOR", "ResetToNormal", THEME.Danger)

	-- Populate Config Page
	addSectionHeader(ConfigPage, "Movement & Environment")
	addToggleBtn(ConfigPage, "AutoSwim", "Auto-Swim", true)
	addToggleBtn(ConfigPage, "EnvSync", "Auto-Reset Env", false)
	addToggleBtn(ConfigPage, "EnvPause", "Pause Map Updates", false)
	addToggleBtn(ConfigPage, "AutoSave", "Auto-Save at Exit", true)

	addSectionHeader(ConfigPage, "Visuals & Smoothing")
	addToggleBtn(ConfigPage, "DebugView", "Debug Hitboxes", false)
	addToggleBtn(ConfigPage, "SmoothMode", "Extreme Smoothing", false)

	-- Interactive Smoothing Sample Rate Slider (10..60 fps)
	local sliderMin, sliderMax = 10, 60
	local sliderValue = math.clamp(tonumber(getgenv().TargetSmoothingFPS) or 24, sliderMin, sliderMax)
	getgenv().TargetSmoothingFPS = sliderValue

	local SliderCard = create("Frame", ConfigPage, {
		Name = "SmoothingSlider",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(0.9, 0, 0, 48),
		BackgroundColor3 = THEME.Surface,
		Active = true,
	})
	create("UICorner", SliderCard, { CornerRadius = UDim.new(0, 6) })
	create("UIStroke", SliderCard, {
		Color = THEME.Stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	local SliderTitle = create("TextLabel", SliderCard, {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 5),
		Size = UDim2.new(1, -20, 0, 16),
		Font = Enum.Font.GothamBold,
		Text = string.format("Smoothing Rate: %d fps", sliderValue),
		TextColor3 = THEME.TextMain,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local SliderTrack = create("Frame", SliderCard, {
		Name = "Track",
		Position = UDim2.new(0, 10, 0, 29),
		Size = UDim2.new(1, -20, 0, 8),
		BackgroundColor3 = THEME.Background,
		Active = true,
	})
	create("UICorner", SliderTrack, { CornerRadius = UDim.new(1, 0) })

	local SliderFill = create("Frame", SliderTrack, {
		Name = "Fill",
		Size = UDim2.new((sliderValue - sliderMin) / (sliderMax - sliderMin), 0, 1, 0),
		BackgroundColor3 = THEME.Accent,
		BorderSizePixel = 0,
	})
	create("UICorner", SliderFill, { CornerRadius = UDim.new(1, 0) })

	local function setSliderValue(val)
		sliderValue = math.clamp(math.round(tonumber(val) or 24), sliderMin, sliderMax)
		getgenv().TargetSmoothingFPS = sliderValue
		SliderTitle.Text = string.format("Smoothing Rate: %d fps", sliderValue)
		SliderFill.Size = UDim2.new((sliderValue - sliderMin) / (sliderMax - sliderMin), 0, 1, 0)
	end

	local draggingSlider = false
	local sliderPointer = nil
	local function updateSliderFromX(posX)
		local absPos = SliderTrack.AbsolutePosition
		local absSize = SliderTrack.AbsoluteSize
		if not absPos or not absSize or absSize.X <= 0 then
			return
		end
		local alpha = math.clamp((posX - absPos.X) / absSize.X, 0, 1)
		setSliderValue(sliderMin + alpha * (sliderMax - sliderMin))
	end

	connect(SliderTrack.InputBegan, function(inputObj)
		if
			inputObj.UserInputType == Enum.UserInputType.MouseButton1
			or inputObj.UserInputType == Enum.UserInputType.Touch
		then
			draggingSlider = true
			sliderPointer = inputObj
			updateSliderFromX(inputObj.Position.X)
		end
	end)
	connect(UserInputService.InputChanged, function(inputObj)
		if not draggingSlider then
			return
		end
		if
			inputObj == sliderPointer
			or (
				inputObj.UserInputType == Enum.UserInputType.MouseMovement
				and sliderPointer
				and sliderPointer.UserInputType == Enum.UserInputType.MouseButton1
			)
		then
			updateSliderFromX(inputObj.Position.X)
		end
	end)
	connect(UserInputService.InputEnded, function(inputObj)
		if
			inputObj == sliderPointer
			or inputObj.UserInputType == Enum.UserInputType.MouseButton1
		then
			draggingSlider = false
			sliderPointer = nil
		end
	end)
	connect(UserInputService.WindowFocusReleased, function()
		draggingSlider = false
		sliderPointer = nil
	end)

	exportedButtons.SmoothingFPS = {
		_frame = SliderCard,
		Kind = "Slider",
		Get = function()
			return sliderValue
		end,
		Set = function(_, v)
			setSliderValue(v)
		end,
	}

	addToggleBtn(ConfigPage, "PathTracing", "TAS Path Tracing", false)
	addToggleBtn(ConfigPage, "Trajectory", "Predictive Velocity", false)
	addToggleBtn(ConfigPage, "CamMode", "Camera Follow", false)

	-- Populate Files Page (SaveBox + Scrollable Run Explorer + Convert/Export)
	addSectionHeader(FilePage, "Save Current Run")
	local SaveBox = create("TextBox", FilePage, {
		Name = "SaveBox",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(0.9, 0, 0, 34),
		BackgroundColor3 = THEME.Surface,
		Text = "",
		PlaceholderText = "Save filename (default: map name)...",
		PlaceholderColor3 = THEME.TextDim,
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.TextMain,
		TextSize = 12,
		ClearTextOnFocus = false,
	})
	create("UICorner", SaveBox, { CornerRadius = UDim.new(0, 6) })
	create("UIStroke", SaveBox, {
		Color = THEME.Stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	addActionBtn(FilePage, "SaveRun", "SAVE BINARY RUN", "SaveRun", THEME.Accent)

	addSectionHeader(FilePage, "Local Run Explorer")
	local FilterBox = create("TextBox", FilePage, {
		Name = "FilterBox",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(0.9, 0, 0, 28),
		BackgroundColor3 = THEME.Surface,
		Text = "",
		PlaceholderText = "Search local files...",
		PlaceholderColor3 = THEME.TextDim,
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.TextMain,
		TextSize = 12,
		ClearTextOnFocus = false,
	})
	create("UICorner", FilterBox, { CornerRadius = UDim.new(0, 6) })
	create("UIStroke", FilterBox, {
		Color = THEME.Stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	local FileList = create("ScrollingFrame", FilePage, {
		Name = "FileList",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(0.9, 0, 0, 132),
		BackgroundColor3 = THEME.Surface,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = THEME.Accent,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
	})
	create("UICorner", FileList, { CornerRadius = UDim.new(0, 6) })
	create("UIStroke", FileList, {
		Color = THEME.Stroke,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	create("UIListLayout", FileList, {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
	create("UIPadding", FileList, {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	})

	local SelectedLabel = create("TextLabel", FilePage, {
		Name = "SelectedLabel",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(0.9, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = "Selected: None",
		Font = Enum.Font.Gotham,
		TextColor3 = THEME.TextDim,
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	addActionBtn(FilePage, "RefreshList", "Refresh File List", nil)
	addActionBtn(FilePage, "LoadRun", "PREVIEW SELECTED RUN", nil, THEME.ActiveOn)

	addSectionHeader(FilePage, "Format Conversion")
	addActionBtn(FilePage, "ConvertBinary", "Convert Selected to Binary", nil)
	addActionBtn(FilePage, "ExportJSON", "Export Selected to JSON", nil)

	local currentFileNames = {}
	local selectedFileName = nil
	local onSelectCallback = nil
	local fileButtons = {}

	local function selectFile(filename)
		selectedFileName = filename
		for name, btn in pairs(fileButtons) do
			local active = (name == selectedFileName)
			btn.BackgroundColor3 = active and THEME.Accent or Color3.fromRGB(40, 40, 48)
			btn.TextColor3 = active and Color3.fromRGB(15, 20, 28) or THEME.TextMain
		end
		if onSelectCallback then
			onSelectCallback(selectedFileName)
		end
	end

	local function rebuildFileRows()
		for _, child in ipairs(FileList:GetChildren()) do
			if child:IsA("TextButton") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		table.clear(fileButtons)
		local query = (FilterBox.Text or ""):lower():match("^%s*(.-)%s*$")
		local shown = 0
		for index, filename in ipairs(currentFileNames) do
			if query == "" or filename:lower():find(query, 1, true) then
				shown += 1
				local active = (filename == selectedFileName)
				local rowBtn = create("TextButton", FileList, {
					Name = filename,
					LayoutOrder = index,
					Size = UDim2.new(1, -10, 0, 26),
					BackgroundColor3 = active and THEME.Accent or Color3.fromRGB(40, 40, 48),
					Text = "  " .. filename,
					Font = Enum.Font.GothamMedium,
					TextColor3 = active and Color3.fromRGB(15, 20, 28) or THEME.TextMain,
					TextSize = 12,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				create("UICorner", rowBtn, { CornerRadius = UDim.new(0, 4) })
				fileButtons[filename] = rowBtn
				connect(rowBtn.Activated, function()
					selectFile(filename)
				end)
			end
		end
		if shown == 0 then
			create("TextLabel", FileList, {
				Name = "EmptyHint",
				Size = UDim2.new(1, -10, 0, 28),
				BackgroundTransparency = 1,
				Text = #currentFileNames == 0 and "No local recordings yet" or "No matching files",
				Font = Enum.Font.Gotham,
				TextColor3 = THEME.TextDim,
				TextSize = 12,
			})
		end
	end

	connect(FilterBox:GetPropertyChangedSignal("Text"), rebuildFileRows)

	-- Menu Open / Close Animation & Responsive Viewport Fit
	local isMenuOpen = false
	local menuTweenGen = 0

	local function updateResponsiveScale()
		if not alive then
			return
		end
		local camera = workspace and workspace.CurrentCamera
		local vp = ScreenGui.AbsoluteSize
		if (not vp or vp.X <= 0 or vp.Y <= 0) and camera then
			vp = camera.ViewportSize
		end
		if not vp or vp.X <= 0 or vp.Y <= 0 then
			return
		end
		local neededW = isMenuOpen and (360 + 14 + 304 + 24) or (360 + 24)
		local neededH = isMenuOpen and (425 + 48) or (88 + 48)
		local fit = math.min(vp.X / neededW, vp.Y / neededH)
		local userScale = (UI and tonumber(UI.scale)) or 1
		HUDScale.Scale = math.clamp(math.min(userScale, fit), 0.55, 1.25)
	end

	local function setMenuOpen(open)
		if open == nil then
			open = not isMenuOpen
		end
		if isMenuOpen == open then
			return
		end
		isMenuOpen = open
		menuTweenGen += 1
		local gen = menuTweenGen
		if not isMenuOpen then
			cancelKeyCapture()
			draggingSlider = false
			sliderPointer = nil
		end
		updateResponsiveScale()

		if isMenuOpen then
			MenuFrame.Visible = true
			MenuFrame.BackgroundTransparency = 1
			MFStroke.Transparency = 1
			TweenService:Create(MenuFrame, TweenInfo.new(0.22), { BackgroundTransparency = 0.08 }):Play()
			TweenService:Create(MFStroke, TweenInfo.new(0.22), { Transparency = 0.45 }):Play()
			MenuToggleButton.Text = "Close Menu"
			MenuToggleButton.TextColor3 = THEME.Accent
		else
			local fadeTween = TweenService:Create(MenuFrame, TweenInfo.new(0.16), { BackgroundTransparency = 1 })
			TweenService:Create(MFStroke, TweenInfo.new(0.16), { Transparency = 1 }):Play()
			if fadeTween.Completed then
				local doneConn
				doneConn = fadeTween.Completed:Connect(function()
					if doneConn then
						doneConn:Disconnect()
						doneConn = nil
					end
					if alive and menuTweenGen == gen and not isMenuOpen then
						MenuFrame.Visible = false
					end
				end)
				fadeTween:Play()
			else
				fadeTween:Play()
				MenuFrame.Visible = false
			end
			MenuToggleButton.Text = "Open Menu"
			MenuToggleButton.TextColor3 = THEME.TextMain
		end
	end

	connect(MenuToggleButton.Activated, function()
		setMenuOpen(not isMenuOpen)
	end)
	connect(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"), updateResponsiveScale)
	updateResponsiveScale()

	-- Keyboard Capture & F6 Menu Toggle
	local keybindHandles = {}

	connect(UserInputService.InputBegan, function(inputObj, processed)
		if capturingBind then
			if inputObj.UserInputType == Enum.UserInputType.Keyboard then
				local code = inputObj.KeyCode
				if code and code ~= Enum.KeyCode.Unknown then
					local activeBind = capturingBind
					capturingBind = nil
					capturedInput = inputObj
					task.defer(function()
						if capturedInput == inputObj then
							capturedInput = nil
						end
					end)
					if code == Enum.KeyCode.Escape then
						activeBind.refresh()
					else
						activeBind.assign(code)
					end
				end
			end
			return
		end

		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if UI and UI.isKeyboardBlocked and UI.isKeyboardBlocked(inputObj) then
			return
		end
		if inputObj.KeyCode == Enum.KeyCode.F6 then
			setMenuOpen(not isMenuOpen)
		end
	end)

	connect(UserInputService.WindowFocusReleased, function()
		cancelKeyCapture()
	end)

	local result = {
		ScreenGui = ScreenGui,
		StatsPanel = StatsPanel,
		MenuFrame = MenuFrame,
		MenuToggleButton = MenuToggleButton,
		TimeText = TimeText,
		SavestatesCount = SavestatesCount,
		FrameCount = FrameCount,
		StatusText = StatusBadge,
		MapEventInfo = MapEventInfo,
		Buttons = exportedButtons,
		Keybinds = keybindHandles,
		SaveBox = SaveBox,
		FilterBox = FilterBox,
		FileList = FileList,
		SelectedLabel = SelectedLabel,
	}

	function result.ToggleMenu(open)
		setMenuOpen(open)
	end

	function result.BindAction(id, callback)
		actions[id] = callback
	end

	function result.SetFiles(names, onSelect)
		currentFileNames = type(names) == "table" and table.clone(names) or {}
		onSelectCallback = onSelect
		if selectedFileName and not table.find(currentFileNames, selectedFileName) then
			selectedFileName = nil
		end
		rebuildFileRows()
	end

	function result.SelectFile(filename)
		if filename == nil or table.find(currentFileNames, filename) then
			selectFile(filename)
		end
	end

	function result.SyncSettings(values)
		if type(values) ~= "table" then
			return
		end
		for id, value in pairs(values) do
			local control = toggles[id]
			if control and control:Get() ~= (value == true) then
				control:Set(value == true, true)
			end
		end
	end

	function result.SetKeybinds(keys)
		currentKeys = keys
		for _, child in ipairs(KeysPage:GetChildren()) do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		table.clear(keybindHandles)

		for slot, updater in pairs(controlKeyLabels) do
			if keys[slot] then
				updater(keys[slot])
			end
		end

		addSectionHeader(KeysPage, "Click a shortcut to rebind")

		local labels = {
			UserPause = "Play / Pause",
			AddSavestate = "Add Savestate",
			RemoveSavestate = "Remove Savestate",
			BackSavestate = "Load Savestate",
			GoFrameBack = "Hold Rewind",
			GoFrameForward = "Hold Advance",
			SaveRun = "Save Recording",
			CollisionToggler = "Toggle Collision",
			ResetToNormal = "Stop Creator",
			ViewTAS = "Preview Run",
			Resync = "Resync Visuals",
			EnvPause = "Pause Map",
			ToggleTimeReset = "Auto-Reset Env",
			DebugToggler = "Debug Hitboxes",
			AutoSwimToggler = "Auto-Swim",
		}

		local orderedIds = {
			"UserPause",
			"AddSavestate",
			"RemoveSavestate",
			"BackSavestate",
			"GoFrameBack",
			"GoFrameForward",
			"SaveRun",
			"CollisionToggler",
			"ResetToNormal",
			"ViewTAS",
			"Resync",
			"EnvPause",
			"ToggleTimeReset",
			"DebugToggler",
			"AutoSwimToggler",
		}

		for idx, id in ipairs(orderedIds) do
			local row = create("Frame", KeysPage, {
				Name = id .. "Row",
				LayoutOrder = nextOrder() + idx,
				Size = UDim2.new(0.9, 0, 0, 30),
				BackgroundColor3 = THEME.Surface,
			})
			create("UICorner", row, { CornerRadius = UDim.new(0, 6) })

			create("TextLabel", row, {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0, 0),
				Size = UDim2.new(0.58, -10, 1, 0),
				Font = Enum.Font.GothamMedium,
				Text = labels[id] or id,
				TextColor3 = THEME.TextMain,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			local keyBtn = create("TextButton", row, {
				Name = "KeyButton",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.new(0.38, 0, 0, 22),
				BackgroundColor3 = THEME.Button,
				Font = Enum.Font.GothamBold,
				Text = formatKey(keys[id]),
				TextColor3 = THEME.Accent,
				TextSize = 11,
			})
			create("UICorner", keyBtn, { CornerRadius = UDim.new(0, 4) })

			local entry
			local function refreshKeyBtn()
				keyBtn.Text = formatKey(keys[id])
				keyBtn.TextColor3 = THEME.Accent
				keyBtn.BackgroundColor3 = THEME.Button
			end

			local function assignKey(keyCode)
				if keyCode and keyCode.Name then
					keys[id] = keyCode.Name
					if controlKeyLabels[id] then
						controlKeyLabels[id](keys[id])
					end
				end
				refreshKeyBtn()
			end

			entry = {
				id = id,
				Button = keyBtn,
				Row = row,
				refresh = refreshKeyBtn,
				assign = assignKey,
				Set = function(_, keyCode)
					assignKey(keyCode)
				end,
				Options = {
					Name = labels[id] or id,
					OnChanged = assignKey,
				},
			}

			connect(keyBtn.Activated, function()
				if capturingBind == entry then
					cancelKeyCapture()
					return
				end
				cancelKeyCapture()
				capturingBind = entry
				keyBtn.Text = "..."
				keyBtn.TextColor3 = THEME.Alert
				keyBtn.BackgroundColor3 = Color3.fromRGB(55, 50, 38)
			end)

			keybindHandles[id] = entry
		end

		create("TextLabel", KeysPage, {
			Name = "KeysHint",
			LayoutOrder = nextOrder() + 100,
			Size = UDim2.new(0.9, 0, 0, 40),
			BackgroundTransparency = 1,
			Text = "Hold Up / Down to offset visual preview time.\nF6 toggles this menu | F7 toggles Hold Pad | Esc cancels key capture.",
			Font = Enum.Font.Gotham,
			TextColor3 = THEME.TextDim,
			TextSize = 11,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	-- 6. Matching TAS_HUD Draggable Hold Pad (Touch / Mobile & F7)
	function result.CreateTouchControls(padActions, track)
		local touchModule = Runtime.run("TAS/CREATOR/touch-controls.luau")

		local HoldPad = create("Frame", ScreenGui, {
			Name = "HoldPad",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -16, 0.5, 0),
			Size = UDim2.new(0, 196, 0, 290),
			BackgroundColor3 = THEME.Background,
			BackgroundTransparency = 0.1,
			Visible = false,
			Active = true,
			ClipsDescendants = true,
		})
		create("UICorner", HoldPad, { CornerRadius = UDim.new(0, 10) })
		create("UIStroke", HoldPad, {
			Color = THEME.Stroke,
			Thickness = 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})

		local PadHeader = create("Frame", HoldPad, {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = THEME.TabBg,
			BorderSizePixel = 0,
			Active = true,
		})
		create("UICorner", PadHeader, { CornerRadius = UDim.new(0, 10) })

		create("TextLabel", PadHeader, {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(1, -36, 1, 0),
			Font = Enum.Font.GothamBold,
			Text = "TAS Hold Pad",
			TextColor3 = THEME.Accent,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		})

		local PadClose = create("TextButton", PadHeader, {
			Name = "CloseButton",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.new(0, 22, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = "-",
			TextColor3 = THEME.TextDim,
			TextSize = 16,
		})

		makeDraggable(PadHeader, HoldPad, connect)

		local PadScroll = create("ScrollingFrame", HoldPad, {
			Name = "PadScroll",
			Position = UDim2.new(0, 0, 0, 32),
			Size = UDim2.new(1, 0, 1, -32),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = THEME.Accent,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
		})
		create("UIPadding", PadScroll, {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		})
		create("UIListLayout", PadScroll, {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 5),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		})

		local stops = {}
		local padDestroyed = false
		local padWindow = {
			Root = HoldPad,
			Open = false,
			_destroyed = false,
		}

		local function releaseAllHolds()
			for _, stop in ipairs(stops) do
				pcall(stop)
			end
		end

		function padWindow:Toggle(open)
			if padDestroyed or not alive then
				return
			end
			if open == nil then
				open = not HoldPad.Visible
			end
			if not open then
				releaseAllHolds()
			end
			HoldPad.Visible = open == true
			self.Open = HoldPad.Visible
		end

		function padWindow:Destroy()
			if padDestroyed then
				return
			end
			padDestroyed = true
			self._destroyed = true
			self.Open = false
			releaseAllHolds()
			if HoldPad.Parent then
				HoldPad:Destroy()
			end
		end

		-- Place press-and-hold buttons first at the top for immediate thumb reach, followed by quick actions
		local holdEntries, tapEntries = {}, {}
		for _, entry in ipairs(padActions or {}) do
			if entry.release then
				table.insert(holdEntries, entry)
			else
				table.insert(tapEntries, entry)
			end
		end

		local order = 0
		for _, entry in ipairs(holdEntries) do
			order += 1
			local btn = create("TextButton", PadScroll, {
				Name = entry.name,
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundColor3 = Color3.fromRGB(40, 65, 98),
				Font = Enum.Font.GothamBold,
				Text = entry.name,
				TextColor3 = THEME.TextMain,
				TextSize = 12,
				Active = true,
			})
			create("UICorner", btn, { CornerRadius = UDim.new(0, 6) })
			create("UIStroke", btn, {
				Color = THEME.Accent,
				Transparency = 0.55,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			})

			local stop = touchModule.bindHold(
				btn,
				UserInputService,
				function()
					if alive and not padDestroyed and HoldPad.Visible and entry.press then
						btn.BackgroundColor3 = THEME.Accent
						entry.press()
					end
				end,
				function()
					btn.BackgroundColor3 = Color3.fromRGB(40, 65, 98)
					if entry.release then
						entry.release()
					end
				end,
				track or connect
			)
			table.insert(stops, stop)
		end

		-- 2-column grid container for quick-tap actions
		if #tapEntries > 0 then
			order += 1
			local rows = math.ceil(#tapEntries / 2)
			local TapGrid = create("Frame", PadScroll, {
				Name = "QuickActions",
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, rows * 30 + math.max(0, rows - 1) * 5),
				BackgroundTransparency = 1,
			})
			create("UIGridLayout", TapGrid, {
				CellSize = UDim2.new(0.5, -3, 0, 30),
				CellPadding = UDim2.new(0, 6, 0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			for idx, entry in ipairs(tapEntries) do
				local btn = create("TextButton", TapGrid, {
					Name = entry.name,
					LayoutOrder = idx,
					BackgroundColor3 = entry.name == "Stop creator" and THEME.Danger or THEME.Button,
					Font = Enum.Font.GothamBold,
					Text = entry.name,
					TextColor3 = THEME.TextMain,
					TextSize = 11,
				})
				create("UICorner", btn, { CornerRadius = UDim.new(0, 5) })
				connect(btn.Activated, function()
					if alive and not padDestroyed and entry.press then
						entry.press()
					end
				end)
			end
		end

		connect(PadClose.Activated, function()
			padWindow:Toggle(false)
		end)

		connect(UserInputService.InputBegan, function(inputObj, processed)
			if processed or UserInputService:GetFocusedTextBox() or capturingBind then
				return
			end
			if UI and UI.isKeyboardBlocked and UI.isKeyboardBlocked(inputObj) then
				return
			end
			if inputObj.KeyCode == Enum.KeyCode.F7 then
				padWindow:Toggle()
			end
		end)

		task.defer(function()
			if alive and not padDestroyed then
				padWindow:Toggle(UserInputService.TouchEnabled == true)
			end
		end)

		result.PadWindow = padWindow
		return HoldPad, releaseAllHolds
	end

	local destroyed = false
	function result.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		alive = false
		cancelKeyCapture()
		capturedInput = nil
		if removeBlocker then
			removeBlocker()
			removeBlocker = nil
		end
		if result.PadWindow then
			pcall(function()
				result.PadWindow:Destroy()
			end)
		end
		for _, conn in ipairs(connections) do
			pcall(function()
				conn:Disconnect()
			end)
		end
		table.clear(connections)
		if movedAlerts and AlertsFrame and GameGui and GameGui.Parent then
			pcall(function()
				AlertsFrame.Parent = GameGui
			end)
		end
		if GameGui and GameGui.Parent and previousGameGuiEnabled ~= nil then
			pcall(function()
				GameGui.Enabled = previousGameGuiEnabled
			end)
		end
		if ScreenGui.Parent then
			ScreenGui:Destroy()
		end
	end

	ScreenGui.Destroying:Connect(function()
		result.Destroy()
	end)

	return result
end

return TAS_UI
