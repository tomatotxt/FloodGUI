-- Standalone minimal GUI for FloodGUI.
-- Lightweight interface using vendored Kavo and native FE2 game engine.
local Runtime = getgenv().FloodGUIRuntime
if not Runtime then
	local loader = loadfile and loadfile("FloodGUI/loader.lua")
	if loader then
		loader({ localOnly = true })
	end
	Runtime = getgenv().FloodGUIRuntime
end

assert(Runtime, "Start FloodGUI through loader.lua first")
local Kavo = Runtime.run("vendor/kavo.luau")
local state = getgenv().State and getgenv().State() or {}

local window = Kavo.CreateLib("FloodGUI Mini", "Ocean")
local tab = window:NewTab("Auto")
local section = tab:NewSection("Main")

section:NewToggle("Auto-Farm", "Wins for your noob self!", function(enabled)
	state.AutoFarm = enabled
	getgenv().TomatoAutoFarm = enabled
	if enabled then
		state.AutoPlay = false
	end
end)

section:NewToggle("Auto-Play (TAS)", "Automatically plays TAS runs.", function(enabled)
	state.AutoPlay = enabled
	if enabled then
		state.AutoFarm = false
		getgenv().TomatoAutoFarm = false
	end
end)

section:NewToggle("Noclip", "Walk through walls.", function(enabled)
	state.Noclip = enabled
end)

section:NewButton("Stop Automation", "Stops active farming and playback.", function()
	state.AutoFarm = false
	state.AutoPlay = false
	getgenv().TomatoAutoFarm = false
	getgenv().IsTASPlaying = false
	if getgenv().FloodGUIStopPlayer then
		pcall(getgenv().FloodGUIStopPlayer, false)
	end
end)

section:NewLabel("FloodGUI Mini | Tomato")
