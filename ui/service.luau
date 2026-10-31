-- Shared presentation for the main menu, creator, and player.
local Runtime = assert(getgenv().FloodGUIRuntime, "Start FloodGUI through loader.lua")
local existing = getgenv().FloodGUIUI
if existing and existing.runtime == Runtime and not existing.destroyed then
	return existing
end
if existing then
	existing.destroy()
end

local Renderer = Runtime.run("ui/kavo.luau")
local theme = {
	Background = Color3.fromRGB(35, 35, 40),
	Header = Color3.fromRGB(25, 25, 30),
	Surface = Color3.fromRGB(50, 50, 55),
	Surface2 = Color3.fromRGB(23, 21, 23),
	Surface3 = Color3.fromRGB(38, 29, 31),
	Stroke = Color3.fromRGB(57, 34, 37),
	StrokeHover = Color3.fromRGB(146, 53, 56),
	Accent = Color3.fromRGB(0, 100, 255),
	AccentDark = Color3.fromRGB(255, 248, 245),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(174, 161, 162),
	Warning = Color3.fromRGB(255, 186, 99),
	Success = Color3.fromRGB(140, 215, 150),
	Error = Color3.fromRGB(255, 106, 96),
}
for key, value in pairs(theme) do
	Renderer.Theme[key] = value
end
local UI = { runtime = Runtime, library = Renderer, theme = theme, windows = {}, scale = 1, notifications = true }
getgenv().FloodGUIUI = UI

function UI.window(id, title, subtitle, key)
	assert(not UI.destroyed, "This FloodGUI session was unloaded; run the loader again")
	if UI.windows[id] then
		UI.windows[id]:Destroy()
	end
	local window = Renderer:Window({
		Parent = assert(
			game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 10),
			"FloodGUI requires the local PlayerGui"
		),
		Name = "FloodGUI_" .. id,
		Title = title,
		Subtitle = subtitle,
		Icon = "cherry",
		Size = UDim2.fromOffset(525, 318),
		Keybind = key or Enum.KeyCode.J,
		OpenButton = { Title = title, Icon = "cherry" },
		Loading = false,
		KeepOnScreen = true,
		Resizable = false,
		MaxNotifications = 3,
	})
	UI.windows[id] = window
	window.Gui.Destroying:Connect(function()
		if UI.windows[id] == window then
			UI.windows[id] = nil
		end
	end)
	-- Keep each session's reopen button reachable when several windows are active.
	if window.OpenButton then
		local row = ({ main = 0, creator = 1, creatorControls = 2, player = 3 })[id] or 0
		window.OpenButton.AnchorPoint = Vector2.new(0, 0)
		window.OpenButton.Position = UDim2.new(0, 20, 0.5, -22 + row * 50)
	end
	if id ~= "main" and UI.windows.main and not UI.windows.main._destroyed then
		UI.windows.main:Toggle(false)
	end
	if window.SetScale then
		window:SetScale(UI.scale)
	end
	return window
end

function UI.setScale(value)
	UI.scale = value
	for _, window in pairs(UI.windows) do
		if not window._destroyed and window.SetScale then
			window:SetScale(value)
		end
	end
end

function UI.notify(message, kind)
	local window = UI.windows.main
	if not window or window._destroyed then
		for _, candidate in pairs(UI.windows) do
			if not candidate._destroyed then
				window = candidate
				if candidate.Open then
					break
				end
			end
		end
	end
	if UI.notifications and window and not window._destroyed then
		local ok, err = pcall(function()
			window:Notify({ Title = "FloodGUI", Content = tostring(message), Type = kind, Duration = 4 })
		end)
		if not ok and not UI.notificationWarning then
			UI.notificationWarning = true
			warn("[FloodGUI] Notification unavailable; script will continue: " .. tostring(err))
		end
		return ok, err
	end
	return false
end

function UI.confirm(window, title, content, action)
	window:Confirm({ Title = title, Content = content, ConfirmText = "Continue", Callback = action })
end

-- The engine updates the native Kavo labels directly.
function UI.label(tab, text)
	return tab:Label({ Text = text })._frame
end

function UI.hold(tab, name, description, press, release, track)
	local control = tab:Button({ Name = name, Desc = description, Icon = "hand" })
	local touch = Runtime.run("TAS/CREATOR/touch-controls.luau")
	local stop = touch.bindHold(control._frame, game:GetService("UserInputService"), function()
		if not control._disabled and not control._destroyed and tab.Window.Open and not tab.Window._destroyed then
			press()
		end
	end, release, track)
	-- The renderer cancels immediately on hide, tab switch, modal, and disable; waiting
	-- for Root.Visible alone leaves a hold running through the closing animation.
	tab.Window:_listen("Cancel", stop, control)
	track(tab.Window.Root:GetPropertyChangedSignal("Visible"):Connect(function()
		if not tab.Window.Root.Visible then
			stop()
		end
	end))
	track(control._frame.Destroying:Connect(stop))
	return control, stop
end

function UI.destroy()
	if UI.destroyed then
		return
	end
	UI.destroyed = true
	for _, window in pairs(table.clone(UI.windows)) do
		local ok, message = pcall(window.Destroy, window)
		if not ok then
			warn("[FloodGUI] Window cleanup: " .. tostring(message))
		end
	end
	UI.windows = {}
end

-- Match the original fork's Gotham typography; no remote font/icon library.
UI.font = "Gotham"
return UI
