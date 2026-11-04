-- Native FE2 zipline assistant and trajectory recovery.
-- Sourced from FE2 reverse engineering analysis:
--   - FE2_Character lines 790-890 (startZipline, RopeSpeed clamp 20..200, default 40)
--   - FE2_Character lines 1039-1052 (RopeStart touch validation, 8-stud radius)
--   - UpdRopeData remote and community map alias oBoPcLGDkNQjGAPHvlWujHyuqmatLeGx

local readUpvalue = debug and debug.getupvalue or getupvalue
local writeUpvalue = debug and debug.setupvalue or setupvalue
local getScriptEnv = getsenv

local function getEndpoints(part)
	local size = part.Size
	local cf = part.CFrame
	local halfLength = math.max(size.X, size.Y, size.Z) / 2
	local axis
	if size.X >= size.Y and size.X >= size.Z then
		axis = cf.RightVector
	elseif size.Y >= size.X and size.Y >= size.Z then
		axis = cf.UpVector
	else
		axis = cf.LookVector
	end
	return cf.Position + axis * halfLength, cf.Position - axis * halfLength
end

local function subdividePath(nodes, totalSubdivisions)
	totalSubdivisions = totalSubdivisions or 100
	local totalDistance = 0
	local segmentLengths = {}
	for i = 1, #nodes - 1 do
		local dist = (nodes[i + 1] - nodes[i]).Magnitude
		segmentLengths[i] = dist
		totalDistance = totalDistance + dist
	end
	local path = {}
	for i = 0, totalSubdivisions do
		local targetDist = (i / totalSubdivisions) * totalDistance
		local accum = 0
		local point = nodes[#nodes]
		for j = 1, #nodes - 1 do
			local segLen = segmentLengths[j]
			if accum + segLen >= targetDist then
				local ratio = (targetDist - accum) / (segLen > 0 and segLen or 1)
				point = nodes[j]:Lerp(nodes[j + 1], ratio)
				break
			end
			accum = accum + segLen
		end
		table.insert(path, point)
	end
	return path, totalDistance
end

local function findRopeModel(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") then
			if current.Name == "RopeModel" or (current:FindFirstChild("RopeStart") and current:FindFirstChild("Visual")) then
				return current
			end
		end
		current = current.Parent
	end
	return nil
end

local function reconstructRopeGeometry(ropeModel)
	local ropeStart = ropeModel:FindFirstChild("RopeStart")
	local visualFolder = ropeModel:FindFirstChild("Visual")
	if not ropeStart or not visualFolder then
		return nil, 0
	end
	local origin = ropeStart.Position
	local unvisited = {}
	for _, child in ipairs(visualFolder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(unvisited, child)
		end
	end
	local nodes = { origin }
	local currentPoint = origin
	while #unvisited > 0 do
		local closestPart, closestIdx = nil, nil
		local minDistance = math.huge
		for i, part in ipairs(unvisited) do
			local dist = (part.Position - currentPoint).Magnitude
			if dist < minDistance then
				minDistance = dist
				closestPart = part
				closestIdx = i
			end
		end
		if not closestPart then
			break
		end
		table.remove(unvisited, closestIdx)
		local p1, p2 = getEndpoints(closestPart)
		local dist1 = (p1 - currentPoint).Magnitude
		local dist2 = (p2 - currentPoint).Magnitude
		local farPoint = dist1 < dist2 and p2 or p1
		table.insert(nodes, farPoint)
		currentPoint = farPoint
	end
	if #nodes < 2 then
		return nil, 0
	end
	return subdividePath(nodes, 100)
end

return function(localPlayer, remotes, trackConnection)
	local connections = {}
	local active = false
	local enabled = false
	local canonicalRopes = {}

	local function track(conn)
		if not conn then
			return nil
		end
		table.insert(connections, conn)
		if trackConnection then
			trackConnection(conn)
		end
		return conn
	end

	-- Listen for native UpdRopeData from server
	if remotes then
		local ropeRemote = remotes:FindFirstChild("UpdRopeData")
			or remotes:FindFirstChild("oBoPcLGDkNQjGAPHvlWujHyuqmatLeGx")
		if ropeRemote and ropeRemote:IsA("RemoteEvent") then
			track(ropeRemote.OnClientEvent:Connect(function(val)
				if type(val) == "table" then
					canonicalRopes = val
				end
			end))
		end
	end

	local function isZiplining(startZiplineFn)
		if type(readUpvalue) ~= "function" then
			return false
		end
		-- u14 in startZipline is the active boolean flag
		for i = 1, 5 do
			local ok, name, val = pcall(readUpvalue, startZiplineFn, i)
			if ok and type(val) == "boolean" and val == true then
				return true
			end
		end
		return false
	end

	local function findRopeTableUpvalue(startZiplineFn)
		if type(readUpvalue) ~= "function" then
			return nil, nil
		end
		for i = 1, 20 do
			local ok, name, val = pcall(readUpvalue, startZiplineFn, i)
			if ok and type(val) == "table" then
				return i, val
			end
		end
		return 2, nil
	end

	local function triggerZipline(ropeModel)
		if active or not enabled then
			return
		end
		local char = localPlayer.Character
		if not char then
			return
		end
		local fe2CharScript = char:FindFirstChild("FE2_Character")
		if not fe2CharScript or type(getScriptEnv) ~= "function" then
			return
		end
		local env = nil
		pcall(function()
			env = getScriptEnv(fe2CharScript)
		end)
		if not env or type(env.startZipline) ~= "function" then
			return
		end
		local startZipline = env.startZipline

		if isZiplining(startZipline) then
			return
		end

		local ropeStart = ropeModel:FindFirstChild("RopeStart")
		if not ropeStart or not ropeStart:IsA("BasePart") then
			return
		end

		active = true
		task.delay(0.2, function()
			active = false
		end)

		-- Native FE2 RopeSpeed: default 40, clamped to [20, 200]
		local rawSpeed = ropeModel:GetAttribute("RopeSpeed")
		local speed = math.clamp(tonumber(rawSpeed) or 40, 20, 200)

		local upvalueIdx, ropesTable = findRopeTableUpvalue(startZipline)
		ropesTable = ropesTable or canonicalRopes

		-- Check if rope is already in canonical data
		local foundRope = nil
		if ropesTable then
			for _, rope in pairs(ropesTable) do
				if type(rope) == "table" and type(rope.positions) == "table" and #rope.positions > 0 then
					if (ropeStart.Position - rope.positions[1]).Magnitude < 1 then
						foundRope = rope
						break
					end
				end
			end
		end

		local injected = false
		local mockRope = nil
		if not foundRope then
			local path, totalDist = reconstructRopeGeometry(ropeModel)
			if path and #path > 1 then
				mockRope = {
					positions = path,
					length = totalDist,
				}
				if ropesTable and type(writeUpvalue) == "function" and upvalueIdx then
					table.insert(ropesTable, mockRope)
					pcall(writeUpvalue, startZipline, upvalueIdx, ropesTable)
					injected = true
				end
				foundRope = mockRope
			end
		end

		-- Execute native startZipline
		pcall(startZipline, ropeStart)

		if injected and mockRope and ropesTable and type(writeUpvalue) == "function" and upvalueIdx then
			local duration = ((mockRope.length or 100) / speed) + 2.0
			task.delay(duration, function()
				local idx = table.find(ropesTable, mockRope)
				if idx then
					table.remove(ropesTable, idx)
					pcall(writeUpvalue, startZipline, upvalueIdx, ropesTable)
				end
			end)
		end
	end

	local function checkProximityToRopes()
		if not enabled or active then
			return
		end
		local char = localPlayer.Character
		if not char then
			return
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		local hitbox = char:FindFirstChild("FE2_Hitbox") or root
		if not hitbox then
			return
		end

		local pos = hitbox.Position
		local multiplayer = workspace:FindFirstChild("Multiplayer")
		local activeMap = multiplayer and (multiplayer:FindFirstChild("Map") or multiplayer:FindFirstChild("NewMap"))
		if not activeMap then
			return
		end

		for _, desc in ipairs(activeMap:GetChildren()) do
			if desc:IsA("Model") and (desc.Name == "RopeModel" or desc:FindFirstChild("RopeStart")) then
				local ropeStart = desc:FindFirstChild("RopeStart")
				if ropeStart and ropeStart:IsA("BasePart") then
					if (pos - ropeStart.Position).Magnitude < 10 then
						triggerZipline(desc)
						break
					end
				end
			end
		end
	end

	local api = {
		getEndpoints = getEndpoints,
		subdividePath = subdividePath,
		reconstructRopeGeometry = reconstructRopeGeometry,
		findRopeModel = findRopeModel,
	}

	function api.setEnabled(state)
		enabled = state == true
	end

	function api.isEnabled()
		return enabled
	end

	function api.check()
		checkProximityToRopes()
	end

	function api.trigger(ropeModel)
		triggerZipline(ropeModel)
	end

	function api.destroy()
		enabled = false
		for _, conn in ipairs(connections) do
			if conn and conn.Disconnect then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end
		connections = {}
		table.clear(canonicalRopes)
	end

	return api
end
