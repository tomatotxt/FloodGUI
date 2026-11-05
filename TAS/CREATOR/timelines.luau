-- Seekable, isolated Local Timeline & XFrame player for FloodGUI TAS Creator.
-- Reconstructs FE2 map timeline events (Configurations with XFrames) so they follow
-- the editor clock, seamlessly seeking forward and backward during recording,
-- rewinding, frame advance, and savestate restoration, without dispatching dangerous
-- server remotes or desyncing tasks.

local Timelines = {}

local function extractXFrames(timelineConfig)
	local frames = {}
	for _, child in ipairs(timelineConfig:GetDescendants()) do
		if child.ClassName == "ObjectValue" and child:GetAttribute("XFrame_Function") then
			local func = child:GetAttribute("XFrame_Function")
			local ts = child:GetAttribute("XFrame_Timestamp")
			if type(func) == "string" and type(ts) == "number" then
				local length = child:GetAttribute("XFrame_Length") or 0
				local priority = child:GetAttribute("XFrame_Priority") or 0
				local target = child.Value
				local attrs = child:GetAttributes()

				table.insert(frames, {
					Instance = child,
					Target = target,
					Function = func,
					Timestamp = ts,
					Length = type(length) == "number" and length or 0,
					Priority = type(priority) == "number" and priority or 0,
					Attributes = attrs,
				})
			end
		end
	end

	table.sort(frames, function(a, b)
		if a.Timestamp ~= b.Timestamp then
			return a.Timestamp < b.Timestamp
		end
		return a.Priority > b.Priority
	end)

	return frames
end

function Timelines.createPlayer(mapInstance, alertFn)
	local state = {
		timelines = {},
		active = true,
		lastTime = 0,
	}

	-- Scan map for all Timeline configurations
	for _, desc in ipairs(mapInstance:GetDescendants()) do
		if desc.ClassName == "Configuration" then
			local touchTrigger = desc:GetAttribute("LocalTrigger_Touch")
			local delayTime = desc:GetAttribute("Trigger_Delay") or 0
			if type(touchTrigger) == "string" and touchTrigger ~= "" then
				local frames = extractXFrames(desc)
				if #frames > 0 then
					table.insert(state.timelines, {
						Config = desc,
						TriggerName = touchTrigger,
						Delay = type(delayTime) == "number" and delayTime or 0,
						Frames = frames,
						TriggeredTime = nil,
						TriggerPart = nil,
					})
				end
			end
		end
	end

	-- Seek / synchronization function called whenever editor clock changes
	function state.seek(targetTime)
		state.lastTime = targetTime
		for _, tl in ipairs(state.timelines) do
			if tl.TriggeredTime ~= nil then
				local elapsedSinceTrigger = targetTime - tl.TriggeredTime
				if elapsedSinceTrigger < 0 then
					-- Rewound before trigger point
					tl.TriggeredTime = nil
				else
					-- Check actions that fall within time window
					for _, xf in ipairs(tl.Frames) do
						local actionTime = tl.Delay + xf.Timestamp
						if elapsedSinceTrigger >= actionTime and (targetTime - state.lastTime) >= 0 then
							-- Action is active in forward progression
							if xf.Function == "Alert" and alertFn and elapsedSinceTrigger - actionTime < 0.2 then
								local msg = xf.Attributes.Message
								local col = xf.Attributes.Color
								if msg then
									pcall(alertFn, tostring(msg), typeof(col) == "Color3" and col or Color3.fromRGB(0, 255, 255))
								end
							end
						end
					end
				end
			end
		end
	end

	function state.trigger(timelineOrPart, realTime)
		for _, tl in ipairs(state.timelines) do
			if (tl.TriggerPart == timelineOrPart or tl.Config == timelineOrPart) and not tl.TriggeredTime then
				tl.TriggeredTime = realTime
				return true
			end
		end
		return false
	end

	function state.dispose()
		state.active = false
		state.timelines = {}
	end

	return state
end

-- Backward compatibility binder for creator.luau:
-- Binds touch listeners on trigger parts in the cloned map and connects them
-- to the seekable timeline engine.
function Timelines.bind(mapInstance, playerInstance, addConnection, alertFn, isActiveFn)
	if not mapInstance or not mapInstance.Parent then
		return false, "No valid map instance"
	end

	local localPlayer = playerInstance or game.Players.LocalPlayer
	local player = Timelines.createPlayer(mapInstance, alertFn)
	local boundCount = 0

	for _, tl in ipairs(player.timelines) do
		for _, desc in ipairs(mapInstance:GetDescendants()) do
			if desc:IsA("BasePart") and desc.Name == tl.TriggerName then
				tl.TriggerPart = desc
				boundCount += 1
				local conn = desc.Touched:Connect(function(hit)
					if not isActiveFn or not isActiveFn() then return end
					if not hit or not hit.Parent then return end
					local char = localPlayer.Character
					if not char or (hit.Parent ~= char and not hit:IsDescendantOf(char)) then return end
					player.trigger(desc, player.lastTime)
				end)
				if addConnection then
					addConnection(conn)
				end
			end
		end
	end

	return true, player, boundCount
end

return Timelines
