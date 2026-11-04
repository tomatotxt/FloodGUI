if not Vector3 then
	local V3 = {}
	V3.__index = function(self, key)
		if key == "Magnitude" then
			return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
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
	function V3:Lerp(target, alpha)
		return V3.new(
			self.X + (target.X - self.X) * alpha,
			self.Y + (target.Y - self.Y) * alpha,
			self.Z + (target.Z - self.Z) * alpha
		)
	end
	getfenv().Vector3 = V3
end

if not CFrame then
	local CF = {}
	CF.__index = CF
	function CF.new(x, y, z)
		local pos = (type(x) == "table" and x.X ~= nil) and x or (Vector3.new(x, y, z))
		return setmetatable({
			Position = pos,
			RightVector = Vector3.new(1, 0, 0),
			UpVector = Vector3.new(0, 1, 0),
			LookVector = Vector3.new(0, 0, -1),
		}, CF)
	end
	getfenv().CFrame = CF
end

local createZipline = require("../zipline")

local mockPlayer = { Character = nil }
local mockRemotes = {
	FindFirstChild = function()
		return nil
	end,
}
local zip = createZipline(mockPlayer, mockRemotes)

-- 1. Test getEndpoints geometry
local mockPart = {
	Size = Vector3.new(10, 2, 2),
	CFrame = CFrame.new(0, 0, 0),
	IsA = function(_, class)
		return class == "BasePart"
	end,
}
local p1, p2 = zip.getEndpoints(mockPart)
assert(p1.X == 5 and p2.X == -5, "X axis endpoints incorrect")

local mockPartY = {
	Size = Vector3.new(2, 20, 2),
	CFrame = CFrame.new(0, 10, 0),
	IsA = function(_, class)
		return class == "BasePart"
	end,
}
local py1, py2 = zip.getEndpoints(mockPartY)
assert(py1.Y == 20 and py2.Y == 0, "Y axis endpoints incorrect")

-- 2. Test subdividePath
local nodes = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(20, 0, 0) }
local path, totalDist = zip.subdividePath(nodes, 10)
assert(totalDist == 20, "Total distance should be 20")
assert(#path == 11, "Expected 11 points for 10 subdivisions")
assert(path[1] == Vector3.new(0, 0, 0), "Start node incorrect")
assert(path[#path] == Vector3.new(20, 0, 0), "End node incorrect")
assert(math.abs(path[6].X - 10) < 0.001, "Midpoint should be at X=10")

-- 3. Test findRopeModel
local ropeStart = {
	Name = "RopeStart",
	IsA = function(_, c)
		return c == "BasePart"
	end,
}
local visualFolder = {
	Name = "Visual",
	IsA = function(_, c)
		return c == "Folder"
	end,
	GetChildren = function()
		return {}
	end,
}
local mockRopeModel = {
	Name = "RopeModel",
	IsA = function(_, c)
		return c == "Model"
	end,
	FindFirstChild = function(self, name)
		if name == "RopeStart" then
			return ropeStart
		end
		if name == "Visual" then
			return visualFolder
		end
		return nil
	end,
	GetAttribute = function(self, attr)
		if attr == "RopeSpeed" then
			return 50
		end
		return nil
	end,
}
ropeStart.Parent = mockRopeModel
visualFolder.Parent = mockRopeModel

local found = zip.findRopeModel(ropeStart)
assert(found == mockRopeModel, "Failed to resolve parent RopeModel")

-- 4. Test reconstructRopeGeometry
local segment1 = {
	Size = Vector3.new(10, 1, 1),
	CFrame = CFrame.new(5, 0, 0),
	Position = Vector3.new(5, 0, 0),
	IsA = function(_, c)
		return c == "BasePart"
	end,
}
local segment2 = {
	Size = Vector3.new(10, 1, 1),
	CFrame = CFrame.new(15, 0, 0),
	Position = Vector3.new(15, 0, 0),
	IsA = function(_, c)
		return c == "BasePart"
	end,
}
visualFolder.GetChildren = function()
	return { segment2, segment1 } -- Intentionally unordered
end
ropeStart.Position = Vector3.new(0, 0, 0)

local geomPath, geomDist = zip.reconstructRopeGeometry(mockRopeModel)
assert(geomPath ~= nil and #geomPath > 1, "Expected reconstructed geometry path")
assert(geomDist > 15, "Expected positive length")

-- 5. Test calculateProgress and evaluate mathematics
local testRope = {
	positions = { Vector3.new(0, 0, 0), Vector3.new(50, 0, 0), Vector3.new(100, 0, 0) },
	length = 100,
	speed = 50,
}
local prog0, d0 = zip.calculateProgress(testRope, Vector3.new(0, 0, 0))
assert(prog0 == 0 and d0 == 0, "Progress at start should be 0")
local progMid, dMid = zip.calculateProgress(testRope, Vector3.new(50, 0, 0))
assert(math.abs(progMid - 0.5) < 0.001 and dMid == 0, "Progress at middle should be 0.5")
local progEnd, dEnd = zip.calculateProgress(testRope, Vector3.new(100, 0, 0))
assert(math.abs(progEnd - 1.0) < 0.001 and dEnd == 0, "Progress at end should be 1.0")

local evalCF0, segCF0, tilt0 = zip.evaluate(testRope, 0)
assert(evalCF0 ~= nil and segCF0 ~= nil and type(tilt0) == "number", "Expected valid evaluation at 0")
local evalCFMid = zip.evaluate(testRope, 0.5)
assert(evalCFMid ~= nil, "Expected valid evaluation at midpoint")

-- 6. Test mid-zipline pause, step, and seek controls
local mockHRP = {
	Position = Vector3.new(0, 0, 0),
	CFrame = CFrame.new(0, 0, 0),
	Velocity = Vector3.new(10, 0, 0),
	RotVelocity = Vector3.new(0, 0, 0),
	Anchored = false,
}
local mockHumanoid = {
	AutoRotate = true,
	Parent = true,
	ChangeState = function() end,
	SetStateEnabled = function() end,
}
local mockChar = {
	HumanoidRootPart = mockHRP,
	Humanoid = mockHumanoid,
	FindFirstChild = function(_, name)
		if name == "HumanoidRootPart" then return mockHRP end
		if name == "Humanoid" then return mockHumanoid end
		return nil
	end,
}
mockPlayer.Character = mockChar

assert(not zip.isPaused(), "Should not be paused initially")
zip.pause()
assert(zip.isPaused(), "Should be paused after pause()")
zip.resume()
assert(not zip.isPaused(), "Should not be paused after resume()")

zip.setCanonicalRopes({ testRope })
zip.seekPosition(Vector3.new(50, 0, 0))
assert(zip.isZiplining(), "Should be ziplining after seekPosition near rope")
zip.pause()
assert(mockHRP.Anchored, "HumanoidRootPart should be anchored when paused mid-zipline")
zip.step(1 / 60)
zip.resume()
assert(not mockHRP.Anchored, "HumanoidRootPart should be unanchored when resumed")
zip.cancel()
assert(not zip.isZiplining(), "Should not be ziplining after cancel")

-- 7. Test API lifecycle
assert(not zip.isEnabled(), "Should be disabled by default")
zip.setEnabled(true)
assert(zip.isEnabled(), "Should be enabled after setEnabled(true)")
zip.check()
zip.destroy()
assert(not zip.isEnabled(), "Should be disabled after destroy")

print("PASS: FE2 zipline trajectory reconstruction, endpoint calculation, and native lifecycle")
