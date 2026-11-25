-- Run by check.mjs with the actual UI modules injected; mocks only Airflow/Roblox.
return function(sources)
	local globals, windows, pendingConfirm, effects = {}, {}, nil, {}
	local function signal()
		local callbacks = {}
		return {
			Connect = function(_, fn)
				table.insert(callbacks, fn)
				return { Disconnect = function() end }
			end,
			Fire = function(_, ...)
				for _, fn in ipairs(callbacks) do
					fn(...)
				end
			end,
		}
	end
	local function frame()
		local text = { Text = "" }
		return {
			Visible = true,
			Parent = true,
			Destroying = signal(),
			FindFirstChildWhichIsA = function()
				return text
			end,
			GetPropertyChangedSignal = function()
				return signal()
			end,
		}
	end
	local enums = setmetatable({}, {
		__index = function(t, key)
			local value = setmetatable({}, {
				__index = function(group, item)
					local enum = { Name = item }
					rawset(group, item, enum)
					return enum
				end,
			})
			rawset(t, key, value)
			return value
		end,
	})
	local taskMock = {}
	function taskMock.spawn(fn, ...)
		local thread = coroutine.create(fn)
		local ok, err = coroutine.resume(thread, ...)
		assert(ok, err)
		return thread
	end
	taskMock.defer = taskMock.spawn
	taskMock.wait = coroutine.yield
	local function makeWindow(id)
		local window = { Tabs = {}, Controls = {}, Root = frame(), Gui = frame(), Open = true }
		function window:Tab(options)
			local page = { Name = options.Name, Mode = options.Mode, Window = self, Controls = {} }
			for _, kind in ipairs({
				"Button",
				"Toggle",
				"Slider",
				"Dropdown",
				"Input",
				"Section",
				"Label",
				"Paragraph",
				"Keybind",
				"Progress",
			}) do
				page[kind] = function(_, options)
					if type(options) == "string" then
						options = { Name = options }
					end
					local control = { Options = options, Kind = kind, Value = options.Default, _frame = frame() }
					control._frame.Text = options.Text or ""
					function control:Get()
						return self.Value
					end
					function control:Set(value, silent)
						if self.Value == value then
							return
						end
						self.Value = value
						if not silent and options.Callback then
							options.Callback(value)
						end
					end
					function control:Refresh(values)
						self.Choices = values
					end
					function control:SetDisabled(value)
						self.Disabled = value
					end
					function control:Destroy()
						self.Destroyed = true
					end
					table.insert(page.Controls, control)
					table.insert(window.Controls, control)
					if kind == "Toggle" and options.Default and options.Callback then
						options.Callback(true)
					end
					return control
				end
			end
			table.insert(self.Tabs, page)
			return page
		end
		function window:SetKeybind(key)
			self.Keybind = key
		end
		function window:ConfigureModes(spec) self.ModeSpec=spec;self.Mode=spec.Default end
		function window:SetStatus(text) self.Status=text end
		function window:Toggle(value)
			if value == nil then
				value = not self.Open
			end
			self.Open = value
		end
		function window:Destroy()
			if self._destroyed then
				return
			end
			self._destroyed = true
			self.Gui.Destroying:Fire()
		end
		windows[id] = window
		return window
	end
	local keyboardBlockers = {}
	local UI = {
		windows = windows,
		scale = 1,
		window = makeWindow,
		setScale = function(value)
			effects.scale = value
		end,
		addKeyboardBlocker = function(fn)
			table.insert(keyboardBlockers, fn)
			return function()
				local i = table.find(keyboardBlockers, fn)
				if i then
					table.remove(keyboardBlockers, i)
				end
			end
		end,
		isKeyboardBlocked = function(pressed)
			for _, fn in ipairs(keyboardBlockers) do
				if fn(pressed) then
					return true
				end
			end
			return false
		end,
		confirm = function(_, _, _, callback)
			pendingConfirm = callback
		end,
		label = function(tab, text)
			return tab:Label({ Text = text })._frame
		end,
		hold = function(tab, name, desc, press, release)
			local control = tab:Button({ Name = name, Desc = desc, Callback = press })
			control.Release = release
			return control, release
		end,
	}
	local files = { "Map A.json" }
	local codec = {
		decode = function(bytes)
			assert(bytes == "valid", "Bad recording")
			return { { time = 0 }, { time = 2 } }, {}
		end,
	}
	local recordings = {
		codec = codec,
		loadFile = function(name)
			return { { time = 0 }, { time = 2 } }, { mapName = name }
		end,
		convertFile = function(name, format)
			effects.convert = { name, format }
			return name .. " converted"
		end,
		save = function(name, data)
			assert(name ~= "")
			effects.saved = { name, #data }
			return name .. ".fe2tomatas"
		end,
	}
	local runtime = {
		path = function(p)
			return "FloodGUI/" .. p
		end,
		catalog = function()
			return { { name = "Map A.json" }, { name = "Map B.json" } }
		end,
	}
	globals.FloodGUIRuntime = runtime
	local vecMt = {}
	local function vec2(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, vecMt)
	end
	vecMt.__sub = function(a, b)
		return vec2(a.X - b.X, a.Y - b.Y)
	end
	local allInstances = {}
	local instMethods = {}
	local instMt = {
		__index = function(t, k)
			return instMethods[k] or t._props[k] or t._signals[k]
		end,
		__newindex = function(t, k, v)
			local prev = t._props[k]
			t._props[k] = v
			if prev ~= v and t._propSignals[k] then
				t._propSignals[k]:Fire()
			end
		end,
	}
	function instMethods:IsA(cls)
		return self.ClassName == cls
	end
	function instMethods:GetChildren()
		local res = {}
		for _, item in ipairs(allInstances) do
			if item.Parent == self and not item._destroyed then
				table.insert(res, item)
			end
		end
		return res
	end
	function instMethods:FindFirstChild(name)
		for _, child in ipairs(self:GetChildren()) do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function instMethods:GetPropertyChangedSignal(prop)
		self._propSignals[prop] = self._propSignals[prop] or signal()
		return self._propSignals[prop]
	end
	function instMethods:Destroy()
		if self._destroyed then
			return
		end
		self._destroyed = true
		self._signals.Destroying:Fire()
		for _, child in ipairs(self:GetChildren()) do
			child:Destroy()
		end
		self.Parent = nil
	end
	local function makeInstance(className, parent)
		local obj = setmetatable({
			_props = {
				ClassName = className,
				Name = className,
				Visible = true,
				Enabled = true,
				Text = "",
				AbsolutePosition = vec2(0, 0),
				AbsoluteSize = vec2(200, 20),
			},
			_signals = {
				Activated = signal(),
				InputBegan = signal(),
				InputChanged = signal(),
				InputEnded = signal(),
				Changed = signal(),
				Destroying = signal(),
			},
			_propSignals = {},
		}, instMt)
		table.insert(allInstances, obj)
		if parent then
			obj.Parent = parent
		end
		return obj
	end

	local mockPlayerGui = makeInstance("PlayerGui")
	mockPlayerGui.AbsoluteSize = vec2(1280, 720)
	local mockGameGui = makeInstance("ScreenGui", mockPlayerGui)
	mockGameGui.Name = "GameGui"
	mockGameGui.Enabled = true
	local mockAlerts = makeInstance("Frame", mockGameGui)
	mockAlerts.Name = "Alerts"
	local mockLocatorGui = makeInstance("ScreenGui", mockPlayerGui)
	mockLocatorGui.Name = "LocatorGui"

	local uis = {
		TouchEnabled = true,
		InputBegan = signal(),
		InputChanged = signal(),
		InputEnded = signal(),
		WindowFocusReleased = signal(),
		GetFocusedTextBox = function()
			return nil
		end,
	}

	local env = setmetatable({
		Instance = { new = makeInstance },
		Vector2 = { new = vec2 },
		UDim = { new = function(s, o) return { Scale = s, Offset = o } end },
		UDim2 = {
			new = function(xs, xo, ys, yo)
				return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
			end,
			fromOffset = function(x, y)
				return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
			end,
			fromScale = function(x, y)
				return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } }
			end,
		},
		TweenInfo = { new = function(...) return { ... } end },
		Color3 = { fromRGB = function(r, g, b) return { r = r / 255, g = g / 255, b = b / 255 } end },
		workspace = { CurrentCamera = { ViewportSize = vec2(1280, 720) } },
		getgenv = function()
			return globals
		end,
		Enum = enums,
		task = taskMock,
		listfiles = function()
			return files
		end,
		game = {
			HttpGet = function(_, url)
				return url == "https://valid" and "valid" or "bad"
			end,
			GetService = function(_, name)
				if name == "Players" then
					local lp = {
						FindFirstChild = function(_, child)
							return child == "PlayerGui" and mockPlayerGui or nil
						end,
						WaitForChild = function(_, child)
							return child == "PlayerGui" and mockPlayerGui or nil
						end,
					}
					return { LocalPlayer = lp }
				elseif name == "TweenService" then
					return {
						Create = function(_, target, _, goal)
							local completed = signal()
							return {
								Completed = completed,
								Play = function()
									for k, v in pairs(goal) do
										target[k] = v
									end
									completed:Fire()
								end,
							}
						end,
					}
				elseif name == "UserInputService" then
					return uis
				end
				return uis
			end,
		},
	}, { __index = getfenv() })
	local function loadModule(name)
		local fn = assert(loadstring(assert(sources[name], name), "@" .. name))
		setfenv(fn, env)
		return fn()
	end
	function runtime.run(name)
		if name == "ui/service.luau" then
			return UI
		end
		return loadModule(name)
	end
	local state = {
		StartDelay = 0,
		ResetDelay = 0,
		ResetAfterEscape = false,
		PlayAfterButtons = false,
		AutoJoinLift = true,
		RebirthInterval = 60,
		AutoPlay = false,
		AutoFarm = false,
		AutoCollect = false,
		AutoRebirth = false,
		PreferMissingTAS = false,
		Mode = "Farm",
		TargetDifficulty = "Normal",
		TargetMapName = "",
		SelectTASMaps = false,
		EnforceDifficulty = false,
		WalkSpeed = 20,
		JumpPower = 50,
		MovementOverrides = true,
		GodMode = false,
		Noclip = false,
		AirJump = false,
		SwimEnabled = false,
		AlertsEnabled = true,
		Notifications = true,
		AntiAFK = true,
		AutoLeave = false,
		InterfaceScale = 1,
		PlaybackSpeed = 1,
		SwimSmoothness = 0.04,
		ChallengeInterval = 600,
		FallbackToFarm = false,
	}
	local Advanced = { guard = { features = {} } }
	for _, name in ipairs({
		"Fast load",
		"Forced win",
		"Direct buttons",
		"Auto boost",
		"Manual boost",
		"Smart challenges",
		"Timed challenges",
	}) do
		Advanced.guard.features[name] =
			{ available = name ~= "Forced win", enabled = false, reason = "Changed internals" }
	end
	function Advanced.enable(name, value)
		local feature = Advanced.guard.features[name]
		feature.enabled = value and feature.available
		if feature.changed then
			feature.changed(feature)
		end
	end
	function Advanced.manualBoost()
		effects.boost = true
	end
	globals.FloodGUIStopPlayer = function()
		effects.playerStopped = true
	end
	local session = { Cancelled = false }
	local main = loadModule("ui/main.luau")({
		ui = UI,
		state = state,
		session = session,
		runtime = runtime,
		recordings = recordings,
		advanced = Advanced,
		alert = function(message)
			effects.alert = message
		end,
		noclip = function(value)
			effects.noclip = value
		end,
		execute = function(mode)
			effects.execute = mode
		end,
		swimAvailable = true,
		stop = function()
			state.AutoPlay = false
			state.AutoFarm = false
			for name in pairs(Advanced.guard.features) do
				Advanced.enable(name, false)
			end
		end,
		rejoin = function()
			effects.rejoin = true
		end,
		infiniteYield = function()
			effects.iy = true
		end,
		copyInvite = function()
			effects.invite = true
		end,
		savePreferences = function(key)
			effects.preferenceKey = key
		end,
		resetPreferences = function()
			state.InterfaceScale = 1
			effects.preferencesReset = true
		end,
		unload = function()
			effects.unloaded = true
		end,
	})
	for _, id in ipairs({ "home", "farm", "maps", "tas", "files", "movement", "advanced", "settings", "about" }) do
		assert(main.tabs[id], "Missing main tab: " .. id)
	end
	assert(#main.tabs.home.Window.Tabs == 8, "Expected focused task pages and shared Settings")
	assert(main.tabs.home.Mode=="TAS" and main.tabs.files.Mode=="TAS" and main.tabs.tas.Mode=="TAS")
	assert(main.tabs.farm.Mode=="Tools" and main.tabs.movement.Mode=="Tools" and main.tabs.advanced.Mode=="Tools")
	assert(main.tabs.settings.Mode==nil and main.tabs.maps.Mode==nil and main.tabs.about==main.tabs.settings)
	assert(main.window.Mode=="TAS", "Start in the blue TAS workspace")
	for _, key in ipairs({
		"AutoPlay",
		"FallbackToFarm",
		"SelectTASMaps",
		"PreferMissingTAS",
		"TargetMapName",
		"SwimEnabled",
		"AutoFarm",
		"PlayAfterButtons",
		"StartDelay",
		"ResetAfterEscape",
		"ResetDelay",
		"AutoCollect",
		"AutoRebirth",
		"TargetDifficulty",
		"EnforceDifficulty",
		"WalkSpeed",
		"JumpPower",
		"GodMode",
		"Noclip",
		"AirJump",
		"AlertsEnabled",
		"AutoLeave",
	}) do
		assert(main.controls[key], "Lost existing feature: " .. key)
	end
	main.controls.AutoPlay:Set(true)
	main.controls.AutoFarm:Set(true)
	assert(state.AutoFarm and not state.AutoPlay and globals.TomatoAutoFarm and effects.playerStopped)
	-- Primary Farming controls must appear at the top of the Farming tab before any collapsed Section.
	assert(main.tabs.farm.Controls[1] == main.controls.FarmStatus, "FarmStatus card must lead the Farming tab")
	assert(main.tabs.farm.Controls[2] == main.controls.AutoFarm, "AutoFarm toggle must be immediately visible at top of Farming tab")
	assert(main.tabs.farm.Controls[3] == main.controls.AutoJoinLift, "AutoJoinLift toggle must sit directly beneath AutoFarm")
	assert(main.tabs.farm.Controls[4] == main.controls.StopTools, "StopTools button must sit in primary Farming group")
	assert(main.tabs.farm.Controls[5].Kind == "Section", "Secondary Round behavior options follow in a collapsible section")
	assert(not tostring(main.window.Status):find("Idle | Farm on", 1, true), "Active farm status must not read 'Idle | Farm on'")
	-- Minimizing UI and firing unbound AutoFarm shortcut callback (even from stale native renderer) must never toggle AutoFarm.
	local farmShortcut = assert(main.controls["Shortcut:AutoFarm"], "Missing AutoFarm shortcut control")
	main.window:Toggle(false)
	farmShortcut.Options.Callback()
	farmShortcut.Options.Callback(enums.KeyCode.Unknown)
	assert(state.AutoFarm and main.controls.AutoFarm:Get(), "Unbound AutoFarm shortcut must ignore clicks and Unknown keys when minimized")
	farmShortcut.Options.OnChanged(enums.KeyCode.F)
	farmShortcut.Options.Callback(enums.KeyCode.Unknown)
	assert(state.AutoFarm, "Mismatched key must not toggle bound AutoFarm shortcut")
	farmShortcut.Options.Callback(enums.KeyCode.F)
	assert(not state.AutoFarm and not main.controls.AutoFarm:Get(), "Bound AutoFarm keyboard shortcut must toggle AutoFarm")
	farmShortcut.Options.OnChanged(enums.KeyCode.Unknown)
	farmShortcut.Options.Callback()
	assert(not state.AutoFarm, "Cleared AutoFarm shortcut must ignore callbacks again")
	main.window:Toggle(true)
	main.controls.AutoFarm:Set(true)
	main.controls.Noclip:Set(true)
	assert(effects.noclip)
	state.Noclip = false
	main.sync()
	assert(not main.controls.Noclip:Get(), "Keyboard change not reflected")
	local target=main.controls.TargetMapName
	target.Value="Draft map name"
	target.IsEditing=function()return true end
	main.sync()
	assert(target:Get()=="Draft map name","Background UI synchronization erased an unfinished map name")
	target.IsEditing=function()return false end
	main.sync()
	assert(target:Get()==state.TargetMapName,"Unfocused input must still synchronize model changes")
	main.controls.StartDelay:Set(2.5)
	assert(state.StartDelay == 2.5)
	assert(effects.preferenceKey == "StartDelay", "Preference changes must reach persistence")
	main.controls.ChallengeInterval:Set(120)
	assert(state.ChallengeInterval == 120)
	main.controls.Creator.Options.Callback()
	assert(effects.execute == "Record")
	local boost = main.controls["Advanced:Auto boost"]
	boost:Set(true)
	assert(not boost:Get() and not Advanced.guard.features["Auto boost"].enabled and pendingConfirm)
	pendingConfirm()
	assert(boost:Get() and Advanced.guard.features["Auto boost"].enabled)
	local feature = Advanced.guard.features["Fast load"]
	feature.available = false
	feature.enabled = false
	feature.changed(feature)
	assert(main.controls["Advanced:Fast load"].Disabled and not main.controls["Advanced:Fast load"]:Get())
	main.controls.Stop.Options.Callback()
	assert(not main.controls.AutoFarm:Get() and not boost:Get())
	local function control(window, name)
		for _, item in ipairs(window.Controls) do
			if item.Options.Name == name then
				return item
			end
		end
		error("Missing control: " .. name)
	end
	local localChoice = control(main.window, "Local files")
	assert(#localChoice.Choices == 1)
	local bundledChoice = control(main.window, "Bundled files")
	assert(
		#bundledChoice.Choices == 1 and bundledChoice.Choices[1] == "Map B.json",
		"Do not duplicate local runs in download list"
	)
	localChoice:Set("Map A.json")
	bundledChoice:Set("Map B.json")
	assert(localChoice:Get() == nil, "Only one recording selection may be active")
	localChoice:Set("Map A.json")
	assert(bundledChoice:Get() == nil)
	control(main.window, "Save selected as binary").Options.Callback()
	assert(effects.convert[1] == "Map A.json" and effects.convert[2] == "binary")
	control(main.window, "Recording URL"):Set("  https://valid  ")
	control(main.window, "Map name"):Set("  New map  ")
	control(main.window, "Import and save binary").Options.Callback()
	assert(effects.saved[1] == "New map")
	effects.saved = nil
	control(main.window, "Recording URL"):Set("https://invalid")
	control(main.window, "Import and save binary").Options.Callback()
	assert(not effects.saved, "Bad file imported")
	files = {}
	effects.convert = nil
	control(main.window, "Refresh recordings").Options.Callback()
	-- A moved local file can remain selected if it is available in the bundle.
	assert(localChoice:Get() == nil and bundledChoice:Get() == "Map A.json")
	-- A save occurring during a yielding catalog request must queue another scan.
	local originalCatalog, waiting = runtime.catalog, true
	runtime.catalog = function()
		if waiting then
			coroutine.yield()
		end
		return originalCatalog()
	end
	local refreshThread = coroutine.create(control(main.window, "Refresh recordings").Options.Callback)
	assert(coroutine.resume(refreshThread))
	files = { "Just saved.fe2tomatas" }
	control(main.window, "Refresh recordings").Options.Callback()
	waiting = false
	assert(coroutine.resume(refreshThread))
	assert(table.find(localChoice.Choices, "Just saved.fe2tomatas"), "A busy refresh dropped the new recording")
	runtime.catalog = originalCatalog
	main.controls.ResetPreferences.Options.Callback()
	assert(not effects.preferencesReset)
	pendingConfirm()
	assert(effects.preferencesReset)
	main.controls.Unload.Options.Callback()
	assert(not effects.unloaded)
	pendingConfirm()
	assert(effects.unloaded)
	-- Test custom TAS_HUD creator UI (StatsPanel + expandable MenuFrame + Run Explorer + Key Capture + HoldPad)
	main.window.Open = true
	local creator = loadModule("ui/creator.luau").Create()
	assert(creator.ScreenGui.Parent == mockPlayerGui and creator.ScreenGui.Name == "TAS_HUD", "Creator HUD must mount in PlayerGui")
	assert(not main.window.Open, "Opening TAS Creator must minimize main Kavo window")
	assert(not mockGameGui.Enabled and mockAlerts.Parent == mockLocatorGui, "Creator must hide GameGui while preserving Alerts in LocatorGui")
	assert(creator.StatsPanel and not creator.MenuFrame.Visible, "StatsPanel starts visible with MenuFrame collapsed")

	-- Open and close MenuFrame via MenuToggleButton and F6
	creator.MenuToggleButton.Activated:Fire()
	assert(creator.MenuFrame.Visible and creator.MenuToggleButton.Text == "Close Menu")
	uis.InputBegan:Fire({ UserInputType = enums.UserInputType.Keyboard, KeyCode = enums.KeyCode.F6 }, false)
	assert(not creator.MenuFrame.Visible and creator.MenuToggleButton.Text == "Open Menu")
	creator.ToggleMenu(true)
	assert(creator.MenuFrame.Visible)

	local clicked = 0
	creator.BindAction("SaveRun", function()
		clicked += 1
	end)
	creator.Buttons.SaveRun.Button.Activated:Fire()
	assert(clicked == 1)

	creator.BindAction("AutoSwim", function()
		clicked += 1
	end)
	creator.Buttons.AutoSwim:Set(false)
	assert(clicked == 2 and creator.Buttons.AutoSwim.Button.Text == "Auto-Swim: OFF")
	creator.SyncSettings({ AutoSwim = true })
	assert(creator.Buttons.AutoSwim:Get() and clicked == 2 and creator.Buttons.AutoSwim.Button.Text == "Auto-Swim: ON")

	-- Smoothing FPS slider
	creator.Buttons.SmoothingFPS:Set(45)
	assert(globals.TargetSmoothingFPS == 45 and creator.Buttons.SmoothingFPS:Get() == 45)

	-- Scrollable FileList & live search filter
	creator.SetFiles({ "One.json", "Two.fe2tomatas" }, function(name)
		effects.selected = name
	end)
	local oneBtn = creator.FileList:FindFirstChild("One.json")
	assert(oneBtn ~= nil and creator.FileList:FindFirstChild("Two.fe2tomatas") ~= nil)
	oneBtn.Activated:Fire()
	assert(effects.selected == "One.json")
	creator.FilterBox.Text = "two"
	assert(creator.FileList:FindFirstChild("One.json") == nil and creator.FileList:FindFirstChild("Two.fe2tomatas") ~= nil)
	creator.FilterBox.Text = ""

	-- Interactive keybind capture & keyboard blocking
	local keys = {}
	for _, key in ipairs({
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
	}) do
		keys[key] = "A"
	end
	creator.SetKeybinds(keys)
	assert(creator.Buttons.SaveRun.Button.Text:find("%(A%)") ~= nil, "Action button must display bound shortcut")
	creator.Keybinds.SaveRun.Button.Activated:Fire()
	assert(UI.isKeyboardBlocked(nil), "Active key capture must block creator/window hotkeys")
	local bindEvent = { UserInputType = enums.UserInputType.Keyboard, KeyCode = enums.KeyCode.B }
	local deferredClear = {}
	local origDefer = taskMock.defer
	taskMock.defer = function(fn)
		table.insert(deferredClear, fn)
	end
	uis.InputBegan:Fire(bindEvent, false)
	assert(keys.SaveRun == "B", "Key capture must update bound key")
	assert(creator.Buttons.SaveRun.Button.Text:find("%(B%)") ~= nil, "Rebinding must refresh Controls button hint")
	assert(UI.isKeyboardBlocked(bindEvent), "Captured InputObject must remain blocked until deferred frame finishes")
	for _, fn in ipairs(deferredClear) do
		fn()
	end
	taskMock.defer = origDefer
	assert(not UI.isKeyboardBlocked(bindEvent), "Keyboard blocker must clear after capture event finishes")

	-- Matching TAS_HUD HoldPad (CreateTouchControls)
	local holdReleased = 0
	local padFrame = creator.CreateTouchControls({
		{
			name = "Hold rewind",
			press = function() end,
			release = function()
				holdReleased += 1
			end,
		},
		{ name = "Pause", press = function() end },
	}, function() end)
	assert(padFrame.Visible and creator.PadWindow.Open, "Touch-enabled device must auto-open HoldPad")
	local holdBtn = padFrame:FindFirstChild("PadScroll"):FindFirstChild("Hold rewind")
	local touchInput = { UserInputType = enums.UserInputType.Touch, Position = vec2(10, 10), Changed = signal() }
	holdBtn.InputBegan:Fire(touchInput)
	creator.PadWindow:Toggle(false)
	assert(not padFrame.Visible and holdReleased == 1, "Hiding HoldPad must release active holds immediately")

	local player = loadModule("ui/player.luau")({
		mapName = "Test",
		smoothness = 0.04,
		track = function() end,
		pause = function(value)
			effects.paused = value
		end,
		stop = function()
			effects.stopped = true
		end,
		setSpeed = function(value)
			effects.speed = value
		end,
		setSmoothness = function(value)
			effects.smooth = value
		end,
		zipline = function(value)
			effects.zip = value
		end,
		slide = function(value)
			effects.slide = value
		end,
		status = function()
			return { speed = 1, effectiveSpeed = 1, paused = false, elapsed = 1, duration = 2, finished = false }
		end,
	})
	control(player.Window, "Playback speed"):Set(2)
	assert(effects.speed == 2)
	control(player.Window, "Pause playback"):Set(true)
	assert(effects.paused)
	control(player.Window, "Hold zipline / swing").Options.Callback()
	assert(effects.zip)
	player.Destroy()
	assert(not effects.zip and not effects.slide and player.Window._destroyed)
	creator.Destroy()
	assert(creator.ScreenGui._destroyed and creator.PadWindow._destroyed)
	assert(mockGameGui.Enabled and mockAlerts.Parent == mockGameGui, "Destroying creator must restore GameGui and Alerts")
	print(
		"PASS: main/creator/player wiring, task-based TAS/Tools groups, feature parity, synchronized toggles, spending confirmation, file actions and cleanup"
	)
end
