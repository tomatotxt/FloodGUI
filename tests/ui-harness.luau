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
			local page = { Name = options.Name, Window = self, Controls = {} }
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
	local UI = {
		window = makeWindow,
		setScale = function(value)
			effects.scale = value
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
	local env = setmetatable({
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
					return { LocalPlayer = {
						FindFirstChild = function()
							return nil
						end,
					} }
				end
				return { TouchEnabled = true }
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
	})
	for _, id in ipairs({ "home", "farm", "maps", "tas", "files", "movement", "advanced", "settings", "about" }) do
		assert(main.tabs[id], "Missing main tab: " .. id)
	end
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
	main.controls.Noclip:Set(true)
	assert(effects.noclip)
	state.Noclip = false
	main.sync()
	assert(not main.controls.Noclip:Get(), "Keyboard change not reflected")
	main.controls.StartDelay:Set(2.5)
	assert(state.StartDelay == 2.5)
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
	localChoice:Set("Map A.json")
	control(main.window, "Save selected as binary").Options.Callback()
	assert(effects.convert[1] == "Map A.json" and effects.convert[2] == "binary")
	control(main.window, "Recording URL"):Set("https://valid")
	control(main.window, "Map name"):Set("New map")
	control(main.window, "Import and save binary").Options.Callback()
	assert(effects.saved[1] == "New map")
	effects.saved = nil
	control(main.window, "Recording URL"):Set("https://invalid")
	control(main.window, "Import and save binary").Options.Callback()
	assert(not effects.saved, "Bad file imported")
	local creator = loadModule("ui/creator.luau").Create()
	local clicked = 0
	creator.BindAction("SaveRun", function()
		clicked += 1
	end)
	creator.Buttons.SaveRun.Options.Callback()
	assert(clicked == 1)
	creator.BindAction("AutoSwim", function()
		clicked += 1
	end)
	creator.Buttons.AutoSwim:Set(false)
	assert(clicked == 2)
	creator.SyncSettings({ AutoSwim = true })
	assert(creator.Buttons.AutoSwim:Get() and clicked == 2)
	creator.SetFiles({ "One.json" }, function(name)
		effects.selected = name
	end)
	control(creator.Window, "Local recording"):Set("One.json")
	assert(effects.selected == "One.json")
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
	control(creator.Window, "Save recording").Options.OnChanged(enums.KeyCode.B)
	assert(keys.SaveRun == "B")
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
	assert(creator.Window._destroyed)
	print(
		"PASS: Airflow main/creator/player wiring, feature parity, synchronized toggles, spending confirmation, file actions and cleanup"
	)
end
