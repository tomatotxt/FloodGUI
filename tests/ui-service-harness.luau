-- Run the shared service with actual touch binding; mock only Roblox/Airflow.
return function(serviceSource, touchSource)
	local function signal()
		local listeners = {}
		return {
			Connect = function(_, fn)
				table.insert(listeners, fn)
				return { Disconnect = function() end }
			end,
			Fire = function(_, ...)
				for _, fn in ipairs(listeners) do
					fn(...)
				end
			end,
		}
	end
	local pending, globals, windows = {}, {}, {}
	local input = { InputEnded = signal(), WindowFocusReleased = signal() }
	local enums = { KeyCode = { J = "J" }, UserInputType = { Touch = "Touch", MouseButton1 = "MouseButton1" } }
	local library = { Theme = {} }
	function library:Window()
		local window = { Open = true, Gui = { Destroying = signal() }, Root = { Visible = true }, cancel = {} }
		window.Root.GetPropertyChangedSignal = function()
			return signal()
		end
		function window:Destroy()
			self._destroyed = true
			self.Gui.Destroying:Fire()
		end
		function window:Toggle(open)
			self.Open = open
		end
		function window:SetScale(value)
			self.scale = value
		end
		function window:Notify(message)
			self.message = message
		end
		function window:_listen(event, fn)
			assert(event == "Cancel")
			table.insert(self.cancel, fn)
		end
		table.insert(windows, window)
		return window
	end
	function library:LoadFont()
		return false
	end
	local runtime = {
		path = function(path)
			return "FloodGUI/" .. path
		end,
	}
	globals.FloodGUIRuntime = runtime
	local env = setmetatable({
		getgenv = function()
			return globals
		end,
		Enum = enums,
		Color3 = {
			fromRGB = function(...)
				return { ... }
			end,
		},
		UDim2 = {
			fromOffset = function(...)
				return { ... }
			end,
		},
		game = {
			GetService = function()
				return input
			end,
		},
		task = {
			spawn = function(fn)
				table.insert(pending, fn)
			end,
		},
		warn = function() end,
	}, { __index = getfenv() })
	local function load(source)
		local fn = assert(loadstring(source))
		setfenv(fn, env)
		return fn()
	end
	local touch = load(touchSource)
	function runtime.run(path)
		if path == "vendor/airflow.luau" then
			return library
		end
		assert(path == "TAS/CREATOR/touch-controls.luau")
		return touch
	end
	local service = load(serviceSource)
	assert(load(serviceSource) == service, "Reuse the live service")
	local main = service.window("main", "FloodGUI")
	local creator = service.window("creator", "Creator")
	assert(not main.Open and creator.Open)
	local frame = { InputBegan = signal(), Destroying = signal() }
	local control = { _frame = frame }
	local page = {
		Window = creator,
		Button = function()
			return control
		end,
	}
	local pressed, released = 0, 0
	local _, stop = service.hold(page, "Hold", "", function()
		pressed += 1
	end, function()
		released += 1
	end, function() end)
	local finger = { UserInputType = "Touch" }
	frame.InputBegan:Fire(finger)
	for _, fn in ipairs(pending) do
		fn()
	end
	table.clear(pending)
	assert(pressed == 1)
	for _, cancel in ipairs(creator.cancel) do
		cancel()
	end
	assert(released == 1 and creator.Root.Visible, "Cancel must release before closing animation")
	input.InputEnded:Fire(finger)
	assert(released == 1)
	control._disabled = true
	frame.InputBegan:Fire(finger)
	for _, fn in ipairs(pending) do
		fn()
	end
	table.clear(pending)
	assert(pressed == 1, "Disabled control must not press")
	stop()
	control._disabled = false
	frame.InputBegan:Fire(finger)
	for _, cancel in ipairs(creator.cancel) do
		cancel()
	end
	for _, fn in ipairs(pending) do
		fn()
	end
	table.clear(pending)
	assert(pressed == 1, "Queued press must be cancelled")
	main:Destroy()
	assert(service.windows.main == nil)
	service.notify("still visible")
	assert(creator.message.Content == "still visible")
	service.destroy()
	assert(creator._destroyed and service.destroyed and next(service.windows) == nil)
	assert(not pcall(service.window, "late", "Late"), "Unloaded service cannot open zombie windows")
	assert(load(serviceSource) ~= service, "Reload must create a usable service after unload")
	print(
		"PASS: actual UI service hold cancellation, disabled/deferred input, window lifecycle, notifications and reload"
	)
end
