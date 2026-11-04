-- Standalone one-time TAS manager & farm helper for FloodGUI.
-- Optimal implementation using FE2 native lifecycle and automation rules.
local options = ... or {}
local mode = options.Mode or "Farm"
local targetDifficulty = options.TargetDifficulty or "Normal"

local Runtime = getgenv().FloodGUIRuntime
if not Runtime then
	local loader = loadfile and loadfile("FloodGUI/loader.lua")
	if loader then
		loader({ localOnly = true })
	end
	Runtime = getgenv().FloodGUIRuntime
end

if Runtime and getgenv().State then
	local state = getgenv().State()
	if state then
		state.SelectTASMaps = true
		state.Mode = mode
		state.TargetDifficulty = targetDifficulty
		state.PreferMissingTAS = true
		state.EnforceDifficulty = true
		if mode == "Farm" then
			state.AutoFarm = true
			getgenv().TomatoAutoFarm = true
		elseif mode == "Play" then
			state.AutoPlay = true
		end
		print(("[FloodGUI TASHelper]: Configured TAS helper for difficulty '%s' in mode '%s'"):format(targetDifficulty, mode))
	end
end
