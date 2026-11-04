-- Native FE2 zipline assistant, controller, and trajectory recovery.
-- Grounded in Flood Escape 2 client reverse engineering:
--   - FE2_Character lines 790-890 (startZipline, RopeSpeed clamp 20..200, default 40)
--   - FE2_Character lines 917-967 (math-exact curve lerping, swing delta tilt)
--   - FE2_Character lines 1039-1052 (RopeStart touch validation, 8-stud radius)
--   - CL_AntiSideClip line 11 (script.Ziplining:Fire)
--   - CL_MAIN_GameScript (ToggleVelocity:Fire)
--   - UpdRopeData remote and community map alias oBoPcLGDkNQjGAPHvlWujHyuqmatLeGx

local readUpvalue = debug and debug.getupvalue or getupvalue
local writeUpvalue = debug and debug.setupvalue or setupvalue
local getScriptEnv = getsenv

local Vector3 = Vector3 or _G.Vector3 or (function()
	local V3 = {}
	V3.__index = function(self, key)
		if key == "Magnitude" then
			return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		elseif key == "Unit" then
			local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
			return m > 0 and V3.new(self.X / m, self.Y / m, self.Z / m) or self
		elseif key == "Lerp" then
			return function(this, target, alpha)
				return V3.new(
					this.X + (target.X - this.X) * alpha,
					this.Y + (target.Y - this.Y) * alpha,
					this.Z + (target.Z - this.Z) * alpha
				)
			end
		end
		return rawget(V3, key)
	end
	function V3.new(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
	end
	function V3.__add(a, b)
		return V3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end
	function V3.__sub(a, b)
		return V3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end
	function V3.__mul(a, b)
		if type(b) == "number" then
			return V3.new(a.X * b, a.Y * b, a.Z * b)
		end
		return V3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end
	function V3.__eq(a, b)
		return a.X == b.X and a.Y == b.Y and a.Z == b.Z
	end
	return V3
end)()

local CFrame = CFrame or _G.CFrame or {
	new = function(pos, look)
		local p = (type(pos) == "table" and pos.X ~= nil) and pos or (Vector3.new(pos or 0, look or 0, 0))
		local lv = Vector3.new(0, 0, -1)
		if type(look) == "table" and look.X ~= nil and (look - p).Magnitude > 0 then
			local diff = look - p
			lv = diff * (1 / diff.Magnitude)
		end
		local cf = {
			Position = p,
			LookVector = lv,
			RightVector = Vector3.new(1, 0, 0),
			UpVector = Vector3.new(0, 1, 0),
			XVector = { Z = 0 },
			ZVector = { Z = 0 },
		}
		return setmetatable(cf, {
			__mul = function(a, b)
				return a
			end,
			__index = function(self, k)
				if k == "XVector" or k == "ZVector" then
					return { Z = 0 }
				end
				return rawget(self, k)
			end,
		})
	end,
	Angles = function(rx, ry, rz)
		local cf = {
			Position = Vector3.new(),
			LookVector = Vector3.new(0, 0, -1),
		}
		return setmetatable(cf, {
			__mul = function(a, b)
				return a
			end,
		})
	end,
}

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

-- Math-exact FE2 curve projection: finds closest point on segmented rope and returns normalized progress [0, 1]
local function calculateProgress(rope, point)
	local positions = rope and rope.positions
	if not positions or #positions < 2 then
		return 0, math.huge
	end
	local bestProgress = 0
	local minDistance = math.huge
	local count = #positions
	for i = 1, count - 1 do
		local p0 = positions[i]
		local p1 = positions[i + 1]
		local v = p1 - p0
		local w = point - p0
		local c1 = w.X * v.X + w.Y * v.Y + w.Z * v.Z
		local segFrac = 0
		if c1 > 0 then
			local c2 = v.X * v.X + v.Y * v.Y + v.Z * v.Z
			if c2 <= c1 then
				segFrac = 1
			elseif c2 > 0 then
				segFrac = c1 / c2
			end
		end
		local closest = p0:Lerp(p1, segFrac)
		local dist = (point - closest).Magnitude
		if dist < minDistance then
			minDistance = dist
			bestProgress = (i - 1 + segFrac) / (count - 1)
		end
	end
	return math.clamp(bestProgress, 0, 1), minDistance
end

-- Math-exact FE2 pose evaluation from FE2_Character lines 923-956
local function evaluate(rope, progress, lastSegmentCF, currentSwing)
	local positions = rope and rope.positions
	if not positions or #positions == 0 then
		return CFrame.new(), CFrame.new(), 0
	end
	local count = #positions
	if count == 1 then
		return CFrame.new(positions[1]), CFrame.new(positions[1]), 0
	end
	local t = math.clamp(progress or 0, 0, 1)
	local idx = math.clamp(math.floor(count * t), 0, count - 2)
	local nextIdx = idx + 1
	local t0 = idx / count
	local t1 = nextIdx / count
	local segT = (t1 > t0) and math.clamp((t - t0) / (t1 - t0), 0, 1) or 0
	local pCurrent = positions[idx + 1]
	local pNext = positions[nextIdx + 1] or pCurrent
	local curPos = pCurrent:Lerp(pNext, segT)
	local lookPos = nil
	if positions[nextIdx + 2] ~= nil then
		lookPos = positions[idx + 2]:Lerp(positions[nextIdx + 2], segT)
	end
	local targetLook = lookPos or pNext
	local segmentCF = CFrame.new(curPos, targetLook)
	if segmentCF.Position.X ~= segmentCF.Position.X then
		segmentCF = CFrame.new(curPos)
	end

	local currentTilt = currentSwing or 0
	local lookVector = segmentCF.LookVector
	local lookX = math.abs(lookVector.X)
	local lookZ = math.abs(lookVector.Z)
	local primaryAxis = (lookZ < lookX) and "X" or "Z"
	local secondaryAxis = (primaryAxis ~= "X") and "X" or "Z"
	local sign = (lookVector[secondaryAxis] < 0) and -1 or 1

	local swingDelta = 0
	if lastSegmentCF then
		local curZ = segmentCF[primaryAxis .. "Vector"].Z
		local lastZ = lastSegmentCF[primaryAxis .. "Vector"].Z
		swingDelta = math.floor(((curZ - lastZ) * 400) + 0.5) * 40
	end
	local targetSwing = math.clamp(sign * swingDelta, -68, 68)
	currentTilt = currentTilt + ((targetSwing - currentTilt) * 0.04)

	local finalCF = segmentCF * CFrame.Angles(0, 0, math.rad(currentTilt)) * CFrame.new(0, -2.5, 0)
	return finalCF, segmentCF, currentTilt
end

local function findRope(ropesTable, startPos)
	if not ropesTable then
		return nil
	end
	for _, rope in pairs(ropesTable) do
		if type(rope) == "table" and type(rope.positions) == "table" and #rope.positions > 0 then
			if (startPos - rope.positions[1]).Magnitude < 2 then
				return rope
			end
		end
	end
	return nil
end

local function createZiplineController(localPlayer, remotes, trackConnection)
	local connections = {}
	local active = false
	local enabled = false
	local canonicalRopes = {}

	-- Active zipline tracking for mid-zipline pausing, frame-stepping, and seeking
	local activeRope = nil
	local activeProgress = 0
	local activeSwing = 0
	local lastSegmentCF = nil
	local isPausedState = false
	local currentBodyPos = nil
	local currentSparklePart = nil
	local activeSpeed = 40
	local attachedChar = nil
	local originalStartZipline = nil

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

	local function isZipliningUpvalue(startZiplineFn)
		if type(readUpvalue) ~= "function" then
			return false
		end
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
		local char = localPlayer and localPlayer.Character
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

		if isZipliningUpvalue(startZipline) then
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

		local rawSpeed = ropeModel:GetAttribute("RopeSpeed")
		local speed = math.clamp(tonumber(rawSpeed) or 40, 20, 200)

		local upvalueIdx, ropesTable = findRopeTableUpvalue(startZipline)
		ropesTable = ropesTable or canonicalRopes

		local foundRope = findRope(ropesTable, ropeStart.Position)

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
		local char = localPlayer and localPlayer.Character
		if not char then
			return
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		local hitbox = char:FindFirstChild("FE2_Hitbox") or root
		if not hitbox then
			return
		end

		local pos = hitbox.Position
		local multiplayer = workspace and workspace:FindFirstChild("Multiplayer")
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
		calculateProgress = calculateProgress,
		evaluate = evaluate,
		findRope = findRope,
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

	function api.isZiplining()
		if activeRope ~= nil then
			return true
		end
		local char = localPlayer and localPlayer.Character
		local fe2Char = char and char:FindFirstChild("FE2_Character")
		if fe2Char and type(getScriptEnv) == "function" then
			local ok, env = pcall(getScriptEnv, fe2Char)
			if ok and env and type(env.startZipline) == "function" then
				return isZipliningUpvalue(env.startZipline)
			end
		end
		return false
	end

	function api.isPaused()
		return isPausedState
	end

	function api.setPaused(state)
		isPausedState = state == true
		local char = localPlayer and localPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if isPausedState and root and activeRope then
			root.Velocity = Vector3.new()
			root.RotVelocity = Vector3.new()
			root.Anchored = true
		elseif not isPausedState and root and activeRope then
			root.Anchored = false
		end
	end

	function api.pause()
		api.setPaused(true)
	end

	function api.resume()
		api.setPaused(false)
	end

	function api.step(dt)
		if not activeRope or not localPlayer then
			return
		end
		local char = localPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local length = activeRope.length or 100
		local rate = 1 / (length / (activeSpeed > 0 and activeSpeed or 40))
		activeProgress = math.clamp(activeProgress + rate * (dt or (1 / 60)), 0, 1)

		local finalCF, segCF, tilt = evaluate(activeRope, activeProgress, lastSegmentCF, activeSwing)
		lastSegmentCF = segCF
		activeSwing = tilt
		root.CFrame = finalCF
		root.Velocity = Vector3.new()
		root.RotVelocity = Vector3.new()
		if currentBodyPos and currentBodyPos.Parent then
			currentBodyPos.Position = finalCF.Position
		end
	end

	function api.setCanonicalRopes(ropes)
		canonicalRopes = ropes or {}
	end

	function api.getActiveRope()
		return activeRope
	end

	function api.setActiveRope(rope)
		activeRope = rope
	end

	function api.seek(progress)
		if not activeRope or not localPlayer then
			return
		end
		local char = localPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		activeProgress = math.clamp(progress or 0, 0, 1)
		local finalCF, segCF, tilt = evaluate(activeRope, activeProgress, lastSegmentCF, activeSwing)
		lastSegmentCF = segCF
		activeSwing = tilt
		root.CFrame = finalCF
		root.Velocity = Vector3.new()
		root.RotVelocity = Vector3.new()
		if currentBodyPos and currentBodyPos.Parent then
			currentBodyPos.Position = finalCF.Position
		end
	end

	function api.seekPosition(pos, candidateRope)
		local rope = candidateRope or activeRope
		if not rope then
			local ropes = canonicalRopes
			local bestRope, bestDist, bestProg = nil, math.huge, 0
			for _, r in pairs(ropes) do
				if type(r) == "table" and type(r.positions) == "table" and #r.positions > 1 then
					local prog, dist = calculateProgress(r, pos)
					if dist < bestDist then
						bestDist = dist
						bestRope = r
						bestProg = prog
					end
				end
			end
			if bestRope and bestDist < 15 then
				activeRope = bestRope
				activeProgress = bestProg
				rope = bestRope
			end
		end
		if rope then
			activeRope = rope
			local prog = calculateProgress(rope, pos)
			api.seek(prog)
		end
	end

	function api.cancel()
		if currentBodyPos then
			pcall(function()
				currentBodyPos:Destroy()
			end)
			currentBodyPos = nil
		end
		if currentSparklePart then
			pcall(function()
				currentSparklePart:Destroy()
			end)
			currentSparklePart = nil
		end
		activeRope = nil
		activeProgress = 0
		activeSwing = 0
		lastSegmentCF = nil
		isPausedState = false
		local char = localPlayer and localPlayer.Character
		local hum = char and char:FindFirstChild("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and hum.Parent then
			hum.AutoRotate = true
			pcall(function()
				hum:ChangeState(Enum.HumanoidStateType.Freefall)
			end)
			pcall(function()
				hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			end)
		end
		if root and root.Parent then
			root.Anchored = false
		end
		if char then
			local anim = char:FindFirstChild("Animate")
			if anim and anim:FindFirstChild("Swinging") then
				pcall(function()
					anim.Swinging:Fire(false)
				end)
			end
			local sideClip = char:FindFirstChild("CL_AntiSideClip")
			if sideClip and sideClip:FindFirstChild("Ziplining") then
				pcall(function()
					sideClip.Ziplining:Fire(false)
				end)
			end
		end
	end

	-- Interconnect with FE2_Character to make native zipline pauseable mid-run without frame drops
	function api.attach(char)
		if not char then
			return
		end
		attachedChar = char
		local fe2Script = char:WaitForChild("FE2_Character", 5)
		if not fe2Script or type(getScriptEnv) ~= "function" then
			return
		end
		local env = nil
		pcall(function()
			env = getScriptEnv(fe2Script)
		end)
		if not env or type(env.startZipline) ~= "function" then
			return
		end
		originalStartZipline = env.startZipline

		-- Hook / wrap startZipline in FE2_Character environment
		local function managedStartZipline(ropeStart)
			if not ropeStart or not ropeStart.Parent then
				return
			end
			local ropeModel = ropeStart.Parent
			local rawSpeed = ropeModel:GetAttribute("RopeSpeed")
			activeSpeed = math.clamp(tonumber(rawSpeed) or 40, 20, 200)

			local ropesTable = canonicalRopes
			local upvalueIdx, scriptRopes = findRopeTableUpvalue(originalStartZipline)
			ropesTable = scriptRopes or ropesTable

			local found = findRope(ropesTable, ropeStart.Position)
			if not found then
				local geom, dist = reconstructRopeGeometry(ropeModel)
				if geom and #geom > 1 then
					found = { positions = geom, length = dist }
					if ropesTable and type(writeUpvalue) == "function" and upvalueIdx then
						table.insert(ropesTable, found)
						pcall(writeUpvalue, originalStartZipline, upvalueIdx, ropesTable)
					end
				end
			end
			if found then
				activeRope = found
				activeProgress = 0
				activeSwing = 0
				lastSegmentCF = nil
			end

			-- Invoke native zipline logic
			originalStartZipline(ropeStart)
		end

		env.startZipline = managedStartZipline
		pcall(function()
			if type(hookfunction) == "function" then
				hookfunction(originalStartZipline, managedStartZipline)
			end
		end)
	end

	function api.destroy()
		enabled = false
		api.cancel()
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

local module = setmetatable({
	create = createZiplineController,
	calculateProgress = calculateProgress,
	evaluate = evaluate,
	findRope = findRope,
	getEndpoints = getEndpoints,
	subdividePath = subdividePath,
	reconstructRopeGeometry = reconstructRopeGeometry,
	findRopeModel = findRopeModel,
}, {
	__call = function(_, ...)
		return createZiplineController(...)
	end,
})
return module
