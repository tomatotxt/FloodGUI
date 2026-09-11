local Runtime = assert(getgenv().FloodGUIRuntime, "Start FloodGUI through loader.lua")
local UI = Runtime.run("ui/service.luau")
local TAS_UI = {}

function TAS_UI.Create()
	local window = UI.window("creator", "TAS Creator", "FloodGUI • binary", Enum.KeyCode.F6)
	local actions, toggles = {}, {}
	local result = { ScreenGui = window.Gui, Window = window, Buttons = {} }
	local controls =
		window:Tab({ Name = "Record", Icon = "clapperboard", Desc = "Recording, savestates, and frame control" })
	local visuals =
		window:Tab({ Name = "Options", Icon = "sliders-horizontal", Desc = "Preview and environment settings" })
	local files = window:Tab({ Name = "Files", Icon = "folder-open", Desc = "Save, preview, and convert recordings" })
	local shortcuts =
		window:Tab({ Name = "Shortcuts", Icon = "keyboard", Desc = "Rebind the creator's keyboard controls" })
	result.TimeText = UI.label(controls, "0:00.000")
	result.StatusText = UI.label(controls, "PAUSED")
	result.MapEventInfo = UI.label(controls, "Waiting for map…")
	result.SavestatesCount = UI.label(controls, "States: 0")
	result.FrameCount = UI.label(controls, "Frames: 0")
	local function action(page, id, name, description, icon, primary)
		result.Buttons[id] = page:Button({
			Name = name,
			Desc = description,
			Icon = icon,
			Style = primary and "Primary" or nil,
			Callback = function()
				if actions[id] then
					actions[id]()
				end
			end,
		})
	end
	local function toggle(id, name, description, default)
		toggles[id] = visuals:Toggle({
			Name = name,
			Desc = description,
			Default = default == true,
			Callback = function(value)
				if actions[id] then
					actions[id](value)
				end
			end,
		})
		result.Buttons[id] = toggles[id]
	end
	action(controls, "Pause", "Play / pause", "Pause or resume recording.", "pause", true)
	controls:Section("Savestates")
	action(controls, "AddState", "Add savestate", nil, "bookmark-plus")
	action(controls, "LoadState", "Load last savestate", nil, "history")
	action(controls, "RemState", "Remove last savestate", nil, "bookmark-minus")
	controls:Section("Frame tools")
	action(controls, "StepBack", "Rewind one frame", nil, "step-back")
	action(controls, "StepFwd", "Advance one frame", nil, "step-forward")
	action(controls, "Resync", "Resync visuals", "Clear the visual time offset.", "refresh-cw")
	action(controls, "PlayTAS", "Preview recorded run", nil, "play")
	action(
		controls,
		"Collision",
		"Toggle pointed part collision",
		"Toggle collision on the map part under your pointer.",
		"box"
	)
	action(
		controls,
		"TouchControls",
		"Open hold controls",
		"Rewind, advance, and preview with press-and-hold buttons.",
		"hand"
	)
	action(controls, "Stop", "Stop creator", "Finish recording mode and reset the character.", "square")
	visuals:Section("Movement and environment")
	toggle("AutoSwim", "Auto swim", "Automatically switch swimming state in water.", true)
	toggle("EnvSync", "Reset environment with savestates", "Synchronize map state when rewinding.")
	toggle("EnvPause", "Pause map updates", "Freeze the map timeline independently of recording.")
	toggle("AutoSave", "Save at the exit", "Automatically save a binary recording on reaching the exit.", true)
	visuals:Section("Preview visuals")
	toggle("DebugView", "Debug hitboxes", "Highlight hitboxes and water volumes.")
	toggle("SmoothMode", "Extreme smoothing", "Use fewer keyframes while previewing.")
	visuals:Slider({
		Name = "Smoothing sample rate",
		Desc = "Used when extreme smoothing is enabled.",
		Min = 10,
		Max = 60,
		Step = 1,
		Default = 24,
		Suffix = " fps",
		Callback = function(value)
			getgenv().TargetSmoothingFPS = value
		end,
	})
	toggle("PathTracing", "Show TAS path", "Draw the recorded path during previews.")
	toggle("Trajectory", "Velocity predictor", "Show projected motion.")
	toggle("CamMode", "Recorded camera", "Follow recorded camera movement during previews.")
	local name = files:Input({ Name = "Save name", Placeholder = "Default: current map", Default = "" })
	result.SaveBox = name._frame:FindFirstChildWhichIsA("TextBox", true)
	action(
		files,
		"SaveRun",
		"Save binary recording",
		"Creates a new revision when the name already exists.",
		"save",
		true
	)
	local choice = files:Dropdown({
		Name = "Local recording",
		Options = {},
		SearchAfter = 0,
		Callback = function(value)
			if result.OnSelect then
				result.OnSelect(value)
			end
		end,
	})
	result.SelectedLabel = UI.label(files, "Selected: None")
	action(files, "RefreshList", "Refresh local files", nil, "refresh-cw")
	action(files, "LoadRun", "Preview selected recording", nil, "play")
	action(files, "ConvertBinary", "Convert selected to binary", nil, "file-down")
	action(files, "ExportJSON", "Export selected to JSON", "Existing JSON files will not be overwritten.", "file-json")
	function result.BindAction(id, callback)
		actions[id] = callback
	end
	function result.Destroy()
		if result.PadWindow then
			result.PadWindow:Destroy()
		end
		window:Destroy()
	end
	function result.SetFiles(names, onSelect)
		choice:Refresh(names, true)
		result.OnSelect = onSelect
	end
	function result.SyncSettings(values)
		for id, value in pairs(values) do
			local control = toggles[id]
			if control and control:Get() ~= value then
				control:Set(value, true)
			end
		end
	end
	function result.SetKeybinds(keys)
		local names = {
			AddSavestate = "Add savestate",
			RemoveSavestate = "Remove savestate",
			BackSavestate = "Load savestate",
			GoFrameBack = "Hold rewind",
			GoFrameForward = "Hold advance",
			SaveRun = "Save recording",
			UserPause = "Play / pause",
			CollisionToggler = "Collision",
			ResetToNormal = "Stop creator",
			ViewTAS = "Preview run",
			Resync = "Resync visuals",
			EnvPause = "Pause map",
			ToggleTimeReset = "Environment reset",
			DebugToggler = "Debug hitboxes",
			AutoSwimToggler = "Auto swim",
		}
		for _, id in ipairs({
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
			shortcuts:Keybind({
				Name = names[id],
				Default = Enum.KeyCode[keys[id]],
				OnChanged = function(key)
					if key then
						keys[id] = key.Name
					end
				end,
			})
		end
		shortcuts:Paragraph({
			Name = "Visual preview",
			Content = "Hold Up / Down to move visual time forward or backward. F6 hides the creator menu; the floating button reopens it.",
		})
	end
	function result.CreateTouchControls(padActions, track)
		local padWindow = UI.window("creatorControls", "TAS Hold", "FloodGUI", Enum.KeyCode.F7)
		local pad = padWindow:Tab({ Name = "Controls", Icon = "hand" })
		local stops = {}
		for _, entry in ipairs(padActions) do
			if entry.release then
				local _, stop =
					UI.hold(pad, entry.name, "Press and hold; release to stop.", entry.press, entry.release, track)
				table.insert(stops, stop)
			else
				pad:Button({ Name = entry.name, Callback = entry.press })
			end
		end
		local function release()
			for _, stop in ipairs(stops) do
				stop()
			end
		end
		track(window.Gui.Destroying:Connect(function()
			release()
			padWindow:Destroy()
		end))
		task.defer(function()
			padWindow:Toggle(game:GetService("UserInputService").TouchEnabled)
		end)
		result.PadWindow = padWindow
		return padWindow.Root, release
	end
	local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	local gameGui = playerGui and playerGui:FindFirstChild("GameGui")
	if gameGui then
		local previous = gameGui.Enabled
		gameGui.Enabled = false
		window.Gui.Destroying:Connect(function()
			if gameGui.Parent then
				gameGui.Enabled = previous
			end
		end)
	end
	return result
end
return TAS_UI
