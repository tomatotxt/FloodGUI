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
	source = source:gsub("return f%s*$", "f._testWindow = g; return f")
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
