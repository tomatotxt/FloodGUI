-- Standalone targeted map sniper & automated runner for FloodGUI.
-- Optimal implementation using FE2 native lifecycle and automation rules.
local options = ... or {}
local targetMap = options.TargetMapName or "Sandswept Ruins"
local targetDifficulty = options.TargetDifficulty or "Crazy"
local mode = options.Mode or "Record"

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
		state.TargetMapName = targetMap
		state.TargetDifficulty = targetDifficulty
		state.EnforceDifficulty = true
		if mode == "Farm" then
			state.AutoFarm = true
			getgenv().TomatoAutoFarm = true
		elseif mode == "Play" then
			state.AutoPlay = true
		end
		print(("[FloodGUI Reach]: Configured sniper for map '%s' (%s) in mode '%s'"):format(targetMap, targetDifficulty, mode))
	end
end
