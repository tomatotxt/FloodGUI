-- Executes the actual library; only Roblox services and geometry are mocked.
return function(source, iconNames)
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
	local vector = {}
	local function vec(x, y)
		return setmetatable({ X = x, Y = y }, vector)
	end
	vector.__add = function(a, b)
		return vec(a.X + b.X, a.Y + b.Y)
	end
	vector.__sub = function(a, b)
		return vec(a.X - b.X, a.Y - b.Y)
	end
	vector.__mul = function(a, b)
		return vec(a.X * b.X, a.Y * b.Y)
	end
	vector.__index = function(a, k)
		if k == "Magnitude" then
			return math.sqrt(a.X * a.X + a.Y * a.Y)
		end
	end
	local enum = setmetatable({}, {
		__index = function(t, k)
			local values = setmetatable({}, {
				__index = function(v, n)
					local item = { Name = n }
					rawset(v, n, item)
					return item
				end,
			})
			rawset(t, k, values)
			return values
		end,
	})
	local mouse = vec(20, 20)
	local input = {
		TouchEnabled = false,
		InputChanged = signal(),
		InputEnded = signal(),
		GetMouseLocation = function()
			return mouse
		end,
	}
	local services = {
		TweenService = {},
		UserInputService = input,
		Players = { LocalPlayer = {} },
		HttpService = {
			JSONEncode = function()
				return "{}"
			end,
		},
	}
	local now, attempts, response = 0, 0, nil
	local queue, files = {}, {}
	local env = setmetatable({
		game = {
			GetService = function(_, name)
				return services[name] or {}
			end,
			HttpGet = function()
				attempts += 1
				if not response then
					error("offline")
				end
				return response
			end,
		},
		Enum = enum,
		Color3 = {
			fromRGB = function(...)
				return { ... }
			end,
			new = function(...)
				return { ... }
			end,
		},
		Vector2 = { new = vec, zero = vec(0, 0) },
		UDim = {
			new = function(...)
				return { ... }
			end,
		},
		UDim2 = {
			fromOffset = function(x, y)
				return { X = { Offset = x }, Y = { Offset = y } }
			end,
		},
		Font = {
			new = function(asset, weight)
				return { Family = asset, Weight = weight }
			end,
		},
		task = {
			spawn = function(fn)
				table.insert(queue, fn)
			end,
		},
		os = {
			clock = function()
				return now
			end,
		},
		warn = function() end,
		isfolder = function()
			return true
		end,
		makefolder = function() end,
		isfile = function(path)
			return files[path] ~= nil
		end,
		readfile = function(path)
			return files[path]
		end,
		writefile = function(path, bytes)
			files[path] = bytes
		end,
		getcustomasset = function(path)
			return path
		end,
	}, { __index = getfenv() })
	-- Expose the real window methods to a small synthetic window, not production.
	source = source:gsub("return f%s*$", "f._testWindow = g; f._testTab = j; f._testControl = n; return f")
	local chunk = assert(loadstring(source))
	setfenv(chunk, env)
	local library = chunk()
	for _, name in ipairs(iconNames) do
		assert(library:ResolveIcon(name), "Missing Lucide icon: " .. name)
	end
	assert(#queue == 1, "one asynchronous request only")
	table.remove(queue, 1)()
	assert(attempts == 1)
	assert(library:ResolveIcon("cherry"):match("rbxassetid://"))
	assert(#queue == 0, "failed requests must be throttled")
	now = 31
	response = 'return {["test-icon"] = "rbxassetid://123"}; error("must not execute remote Lua")'
	library:PreloadIcons()
	table.remove(queue, 1)()
	assert(library:ResolveIcon("test-icon") == "rbxassetid://123")
	assert(library:ResolveIcon("file-json") == library:ResolveIcon("file-code"))
	assert(library:ResolveIcon(42) == "rbxassetid://42")
	local old = library.Fonts.Regular
	response = "not a font"
	assert(not library:LoadFont())
	assert(library.Fonts.Regular == old)
	files["AirFlowFonts/ValleySans-Regular.ttf"] = "corrupt cache"
	response = string.char(0, 1, 0, 0) .. string.rep("x", 110)
	assert(library:LoadFont())
	assert(files["AirFlowFonts/ValleySans-Regular.ttf"] == response)
	assert(library.Fonts.Regular ~= old)

	-- Construct the real controls using a small deterministic Instance tree.
	local objects, timers = {}, {}
	local dimension = {}
	local function dim(xs, xo, ys, yo)
		return setmetatable({ X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }, dimension)
	end
	dimension.__add = function(a, b)
		return dim(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset)
	end
	dimension.__sub = function(a, b)
		return dim(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset)
	end
	env.UDim2 = {
		new = dim,
		fromOffset = function(x, y)
			return dim(0, x, 0, y)
		end,
		fromScale = function(x, y)
			return dim(x, 0, y, 0)
		end,
	}
	env.TweenInfo = {
		new = function()
			return {}
		end,
	}
	services.TweenService.Create = function(_, object, _, properties)
		return {
			Play = function()
				for key, value in pairs(properties) do
					object[key] = value
				end
			end,
		}
	end
	env.task.defer = function(fn, ...)
		local args = table.pack(...)
		table.insert(queue, function()
			fn(table.unpack(args, 1, args.n))
		end)
	end
	env.task.delay = function(_, fn)
		table.insert(timers, fn)
	end
	env.task.wait = function() end
	local function flush()
		while #queue > 0 do
			table.remove(queue, 1)()
		end
	end
	local function instance(class)
		local object = {
			ClassName = class,
			Visible = true,
			ZIndex = 1,
			Image = "",
			Text = "",
			AbsoluteSize = vec(500, 100),
			AbsolutePosition = vec(0, 0),
			TextBounds = vec(35, 18),
			attributes = {},
			changes = {},
		}
		for _, event in ipairs({
			"InputBegan",
			"InputEnded",
			"MouseEnter",
			"MouseLeave",
			"Activated",
			"Focused",
			"FocusLost",
			"Destroying",
		}) do
			object[event] = signal()
		end
		function object:IsA(name)
			return name == class
				or (name == "GuiButton" and class == "TextButton")
				or (
					name == "GuiObject"
					and (class == "Frame" or class == "TextButton" or class == "TextLabel" or class == "TextBox")
				)
		end
		function object:GetChildren()
			local children = {}
			for _, item in ipairs(objects) do
				if item.Parent == self then
					table.insert(children, item)
				end
			end
			return children
		end
		function object:GetDescendants()
			local children = {}
			for _, item in ipairs(self:GetChildren()) do
				table.insert(children, item)
				for _, child in ipairs(item:GetDescendants()) do
					table.insert(children, child)
				end
			end
			return children
		end
		function object:FindFirstChild(name)
			for _, child in ipairs(self:GetChildren()) do
				if child.Name == name then
					return child
				end
			end
		end
		function object:SetAttribute(name, value)
			self.attributes[name] = value
		end
		function object:GetAttribute(name)
			return self.attributes[name]
		end
		function object:GetPropertyChangedSignal(name)
			self.changes[name] = self.changes[name] or signal()
			return self.changes[name]
		end
		function object:IsFocused()
			return input.focused == self
		end
		function object:CaptureFocus()
			input.focused = self
			self.Focused:Fire()
		end
		function object:ReleaseFocus()
			input.focused = nil
			self.FocusLost:Fire(false)
		end
		function object:Destroy()
			if self.destroyed then
				return
			end
			self.destroyed = true
			self.Destroying:Fire()
			for _, child in ipairs(self:GetChildren()) do
				child:Destroy()
			end
			self.Parent = nil
		end
		table.insert(objects, object)
		return object
	end
	env.Instance = { new = instance }
	input.GetFocusedTextBox = function()
		return input.focused
	end
	local widgetWindow = setmetatable({
		Open = true,
		_introDone = true,
		Scale = { Scale = 1 },
		Gui = instance("ScreenGui"),
		Body = instance("Frame"),
		Root = instance("Frame"),
		BodyStroke = {},
		Shadow = {},
		_inputListeners = { Began = {}, Changed = {}, Ended = {}, Render = {}, Cancel = {} },
		_connections = {},
		_frameSteps = {},
		_autoSave = function() end,
	}, { __index = library._testWindow })
	local tab = setmetatable(
		{ Window = widgetWindow, List = instance("Frame"), _order = 0 },
		{ __index = library._testTab }
	)
	local function fire(event, ...)
		for _, listener in ipairs(table.clone(widgetWindow._inputListeners[event])) do
			listener(...)
		end
	end
	local changed = 0
	local toggle = tab:Toggle({
		Name = "Test",
		Flag = "lifecycle-test",
		Callback = function()
			changed += 1
		end,
	})
	toggle:Set(true)
	assert(toggle:Get() and changed == 1)
	toggle:SetDisabled(true, "Test unavailable")
	toggle:Set(false)
	toggle._frame.Activated:Fire()
	assert(toggle:Get() and changed == 1, "disabled toggle cannot mutate")
	toggle:Set(false, true)
	assert(not toggle:Get() and changed == 1, "silent state sync still works while disabled")
	local pointer = { UserInputType = enum.UserInputType.Touch }
	local presses, releases = 0, 0
	local hold = tab:Hold({
		Name = "Hold",
		Press = function()
			presses += 1
		end,
		Release = function()
			releases += 1
		end,
	})
	hold._frame.InputBegan:Fire(pointer)
	flush()
	assert(presses == 1)
	hold:SetDisabled(true)
	assert(releases == 1, "disabling an active hold releases it immediately")
	hold:SetDisabled(false)
	fire("Ended", pointer)
	assert(releases == 1, "hold release is exact once")
	hold._frame.InputBegan:Fire(pointer)
	widgetWindow:Toggle(false)
	flush()
	assert(presses == 1 and releases == 2, "hide before queued press cancels it")
	widgetWindow:Toggle(true)

	local dropdownChanges = 0
	local dropdown = tab:Dropdown({
		Name = "Files",
		Options = { "A", "B" },
		Callback = function()
			dropdownChanges += 1
		end,
	})
	dropdown:SetOpen(true)
	flush()
	local optionButton
	for _, child in ipairs(dropdown._frame:GetDescendants()) do
		if child.ClassName == "TextLabel" and child.Text == "A" then
			optionButton = child.Parent
		end
	end
	assert(optionButton)
	optionButton.Activated:Fire()
	assert(dropdown:Get() == "A" and dropdownChanges == 1)
	dropdown:SetOpen(true)
	dropdown:SetDisabled(true)
	optionButton.Activated:Fire()
	dropdown:SetOpen(true)
	assert(
		not dropdown.Open and dropdown:Get() == "A" and dropdownChanges == 1,
		"disabled dropdown closes and rejects stale clicks"
	)
	dropdown:SetDisabled(false)
	dropdown:Refresh({ "B" }, true)
	dropdown:Refresh({ "A", "B" }, true)
	assert(dropdown:Get() == nil, "removed selection cannot resurrect when options return")

	local binds = 0
	local keybind = tab:Keybind({
		Name = "Key",
		Default = enum.KeyCode.J,
		Callback = function()
			binds += 1
		end,
	})
	local keyButton
	for _, child in ipairs(keybind._frame:GetChildren()) do
		if child.ClassName == "TextButton" then
			keyButton = child
		end
	end
	local key = { UserInputType = enum.UserInputType.Keyboard, KeyCode = enum.KeyCode.J }
	keyButton.Activated:Fire()
	assert(keybind.Listening)
	widgetWindow._inLayer, widgetWindow._outLayer = instance("Frame"), instance("Frame")
	widgetWindow.Content, widgetWindow.Indicator, widgetWindow.Compact = instance("Frame"), instance("Frame"), true
	widgetWindow:SelectTab({ _button = {}, _stroke = {}, _label = {}, _page = instance("Frame") })
	assert(not keybind.Listening, "switching tabs clears key capture")
	input.focused = {}
	fire("Began", key, false)
	assert(binds == 0, "typing suppresses shortcuts even if executor omits processed flag")
	input.focused = nil
	fire("Began", key, false)
	assert(binds == 1)
	keyButton.Activated:Fire()
	keybind:SetDisabled(true)
	assert(not keybind.Listening)
	fire("Began", key, false)
	assert(binds == 1, "disabled keybind is inert")
	keybind:SetDisabled(false)

	local confirms, cancels = 0, 0
	local function confirm()
		return widgetWindow:Confirm({
			Title = "Delete?",
			Callback = function()
				confirms += 1
			end,
			OnCancel = function()
				cancels += 1
			end,
		})
	end
	confirm()
	local confirmButton, cancelButton
	for _, child in ipairs(widgetWindow.Body:GetDescendants()) do
		if child.ClassName == "TextLabel" then
			if child.Text == "Confirm" then
				confirmButton = child.Parent
			end
			if child.Text == "Cancel" then
				cancelButton = child.Parent
			end
		end
	end
	fire("Began", key, false)
	assert(binds == 1, "modal dialog suppresses shortcuts")
	confirmButton.Activated:Fire()
	confirmButton.Activated:Fire()
	cancelButton.Activated:Fire()
	assert(confirms == 1 and cancels == 0, "confirmation resolves once during fade-out")
	local staleCalls = 0
	local disposable = library._testControl(tab, {}, {}, instance("Frame"), "Test")
	widgetWindow:_listen("Render", function()
		disposable:Destroy()
	end)
	widgetWindow:_listen("Render", function()
		staleCalls += 1
	end, disposable)
	fire("Render")
	assert(staleCalls == 0, "destroy during event dispatch invalidates already-copied listeners")

	-- Cleanup must continue after a callback fails and must not retain dead controls.
	local cleanup = 0
	table.insert(toggle._listeners, function()
		error("deliberate cleanup failure")
	end)
	table.insert(toggle._listeners, function()
		cleanup += 1
	end)
	toggle:Destroy()
	assert(cleanup == 1 and toggle._frame.destroyed and library.Flags["lifecycle-test"] == nil)
	assert(not table.find(widgetWindow.Controls, toggle), "destroyed control removed from window registry")
	toggle:SetDisabled(false)
	local remaining = table.clone(widgetWindow.Controls)
	widgetWindow:Destroy()
	for _, control in ipairs(remaining) do
		assert(control._destroyed, "window destroys every control without array skipping")
	end
	assert(#widgetWindow._inputListeners.Began == 0 and widgetWindow.Gui.destroyed)
	assert(widgetWindow:Dialog({ Title = "Too late" }) == nil)
	print(
		"PASS: actual Airflow controls disabled/silent sync, hold/key capture cancellation, dropdown refresh, exact-once dialogs, resilient cleanup"
	)

	local children = {}
	local body = {
		AbsolutePosition = vec(0, 0),
		AbsoluteSize = vec(500, 400),
		GetDescendants = function()
			return children
		end,
	}
	local listeners = {}
	local window = setmetatable({
		Open = true,
		Body = body,
		Root = { AbsolutePosition = vec(0, 0), AbsoluteSize = vec(500, 400), AnchorPoint = vec(0.5, 0.5) },
		Gui = { AbsolutePosition = vec(0, 0) },
		_connections = {},
		_controls = {},
		_controlsDirty = true,
		_listen = function(_, event, fn)
			listeners[event] = fn
		end,
		_clampToScreen = function(_, immediate)
			assert(immediate)
		end,
	}, { __index = library._testWindow })
	table.insert(library.Windows, window)
	window:_enableDrag()
	local click = { UserInputType = enum.UserInputType.MouseButton1 }
	listeners.Began(click)
	mouse = vec(50, 60)
	input.InputChanged:Fire({ UserInputType = enum.UserInputType.MouseMovement })
	assert(window.Root.Position.X.Offset == 280 and window.Root.Position.Y.Offset == 240, "background drag")
	listeners.Cancel()
	local position = window.Root.Position
	mouse = vec(60, 70)
	input.InputChanged:Fire({ UserInputType = enum.UserInputType.MouseMovement })
	assert(window.Root.Position == position)
	local control = {
		AbsolutePosition = vec(0, 0),
		AbsoluteSize = vec(100, 100),
		Visible = true,
		Parent = body,
		IsA = function(_, name)
			return name == "GuiButton" or name == "GuiObject"
		end,
		GetAttribute = function() end,
	}
	children = { control }
	window._controlsDirty = true
	listeners.Began(click)
	mouse = vec(80, 90)
	input.InputChanged:Fire({ UserInputType = enum.UserInputType.MouseMovement })
	assert(window.Root.Position == position, "control must not drag")
	control.Visible = false
	window._controlsDirty = true
	local touch = { UserInputType = enum.UserInputType.Touch, Position = vec(150, 150) }
	listeners.Began(touch)
	input.InputEnded:Fire({ UserInputType = enum.UserInputType.Touch })
	input.InputChanged:Fire({ UserInputType = enum.UserInputType.Touch, Position = vec(300, 300) })
	assert(window.Root.Position == position, "unrelated finger cannot move drag")
	touch.Position = vec(160, 170)
	input.InputChanged:Fire(touch)
	assert(
		window.Root.Position.X.Offset == 260 and window.Root.Position.Y.Offset == 220,
		"owning finger survives other finger release"
	)
	input.InputEnded:Fire(touch)
	position = window.Root.Position
	touch.Position = vec(200, 200)
	input.InputChanged:Fire(touch)
	assert(window.Root.Position == position)
	local scroller = {
		AbsolutePosition = vec(0, 0),
		AbsoluteSize = vec(500, 400),
		Visible = true,
		Parent = body,
		ScrollingEnabled = true,
		AbsoluteCanvasSize = vec(500, 800),
		AbsoluteWindowSize = vec(500, 400),
		IsA = function(_, name)
			return name == "ScrollingFrame" or name == "GuiObject"
		end,
		GetAttribute = function() end,
	}
	children = { scroller }
	window._controlsDirty = true
	listeners.Began(touch)
	touch.Position = vec(210, 220)
	input.InputChanged:Fire(touch)
	assert(window.Root.Position == position, "touch scroll must not drag window")
	children = {}
	window._controlsDirty = true
	local other = { Open = true, Body = body }
	table.insert(library.Windows, other)
	listeners.Began(click)
	mouse = vec(100, 100)
	input.InputChanged:Fire({ UserInputType = enum.UserInputType.MouseMovement })
	assert(window.Root.Position == position, "covered window must not drag")
	table.remove(library.Windows)
	window._dialog = {}
	listeners.Began(click)
	mouse = vec(110, 110)
	input.InputChanged:Fire({ UserInputType = enum.UserInputType.MouseMovement })
	assert(window.Root.Position == position, "dialog must block drag")
	window._dialog = nil
	-- Exercise the actual stepper binding without rebuilding its visual tree.
	local binding = assert(source:match("local function I%(b, c%)\n(.-)\n\tI%(C, %-1%)"))
	local held, delayed, steps = {}, {}, 0
	local controlState = { _listeners = {} }
	local stepWindow = {
		Open = true,
		_listen = function(_, event, fn)
			held[event] = fn
		end,
	}
	local button = { InputBegan = signal(), MouseLeave = signal() }
	local stepEnv = setmetatable({
		f = controlState,
		self = { Window = stepWindow },
		p = function()
			return true
		end,
		G = function()
			steps += 1
		end,
		task = {
			delay = function(_, fn)
				table.insert(delayed, fn)
			end,
			wait = function()
				held.Cancel()
			end,
		},
	}, { __index = getfenv() })
	local bind = assert(loadstring("local function I(b,c)\n" .. binding .. "\nreturn I"))
	setfenv(bind, stepEnv)
	bind()(button, 1)
	button.InputBegan:Fire(click)
	held.Ended(click)
	button.InputBegan:Fire(touch)
	assert(steps == 2)
	table.remove(delayed, 1)()
	assert(steps == 2, "stale repeat timer must not restart")
	held.Ended(click)
	table.remove(delayed, 1)()
	assert(steps == 3, "other pointer release must not cancel repeat")
	button.InputBegan:Fire(click)
	held.Cancel()
	table.remove(delayed, 1)()
	assert(steps == 4, "focus cancellation stops repeat")
	print(
		"PASS: actual Airflow icon fallback/refresh/aliases, font repair/fallback, whole-window drag/control exclusion/pointer ownership"
	)
end
