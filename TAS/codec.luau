-- FE2T translation API. Reads experimental v2 and extended v3; writes v3.
-- Canonical frames use the existing JSON fields so both engines share one model.
local Codec = { VERSION = 3, MAX_FRAMES = 2000000 }
local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function vector(value, count, field)
	assert(type(value) == "table", "Missing " .. field)
	for index = 1, count do
		assert(finite(value[index]), "Invalid " .. field)
	end
end
function Codec.validate(frames)
	assert(type(frames) == "table" and #frames > 0 and #frames <= Codec.MAX_FRAMES, "Invalid frame count")
	local count = #frames
	local entries = 0
	for key in pairs(frames) do
		assert(
			type(key) == "number" and key % 1 == 0 and key >= 1 and key <= count,
			"Frames must be a continuous array"
		)
		entries += 1
	end
	assert(entries == count, "Frames must be a continuous array")
	for _, frame in ipairs(frames) do
		assert(type(frame) == "table" and finite(frame.time), "Invalid frame timestamp")
		vector(frame.CCFrame, 6, "CCFrame")
		vector(frame.CCameraCFrame, 6, "CCameraCFrame")
		vector(frame.VVelocity, 3, "VVelocity")
		if frame.AAnimation ~= nil then
			assert(
				type(frame.AAnimation) == "table"
					and type(frame.AAnimation[1]) == "string"
					and finite(frame.AAnimation[2]),
				"Invalid animation"
			)
		end
		assert(frame.AAnimationChanged == nil or finite(frame.AAnimationChanged), "Invalid animation marker")
	end
	return frames
end
local function quaternion(cf)
	local sx, cx = math.sin(cf[4] / 2), math.cos(cf[4] / 2)
	local sy, cy = math.sin(cf[5] / 2), math.cos(cf[5] / 2)
	local sz, cz = math.sin(cf[6] / 2), math.cos(cf[6] / 2)
	return sx * cy * cz + cx * sy * sz,
		cx * sy * cz - sx * cy * sz,
		cx * cy * sz + sx * sy * cz,
		cx * cy * cz - sx * sy * sz
end
local function euler(x, y, z, w)
	local norm = math.sqrt(x * x + y * y + z * z + w * w)
	assert(norm > 0.000001, "Invalid rotation quaternion")
	x, y, z, w = x / norm, y / norm, z / norm, w / norm
	local m00, m01, m02 = 1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)
	local m11, m12 = 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)
	local m21, m22 = 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)
	local ry = math.asin(math.clamp(m02, -1, 1))
	if math.abs(m02) < 0.9999999 then
		return math.atan2(-m12, m22), ry, math.atan2(-m01, m00)
	end
	return math.atan2(m21, m11), ry, 0
end
function Codec.encodeBinary(frames, metadata)
	Codec.validate(frames)
	metadata = metadata or {}
	assert(type(metadata) == "table", "Expected recording metadata")
	local author, mapName = metadata.author or "", metadata.mapName or ""
	local fps = metadata.fps or 60
	assert(
		type(author) == "string" and #author <= 65535 and type(mapName) == "string" and #mapName <= 65535,
		"Metadata too long"
	)
	assert(finite(fps) and fps % 1 == 0 and fps >= 1 and fps <= 255, "Invalid recording FPS")
	local length = 14 + #author + #mapName
	for _, f in ipairs(frames) do
		local animation = f.AAnimation or { "idle", 0 }
		assert(#animation[1] <= 65535, "Animation name too long")
		length += 83 + #animation[1] + (f.AAnimationChanged ~= nil and 8 or 0)
	end
	local output, pos = buffer.create(length), 0
	local function write(kind, size, value)
		if kind == "f32" then
			assert(finite(value) and math.abs(value) <= 3.402823466e38, "Value exceeds float32 range")
		end
		buffer["write" .. kind](output, pos, value)
		pos += size
	end
	local function str(value)
		write("u16", 2, #value)
		buffer.writestring(output, pos, value)
		pos += #value
	end
	local function cf(value)
		for i = 1, 3 do
			write("f32", 4, value[i])
		end
		local x, y, z, w = quaternion(value)
		for _, q in ipairs({ x, y, z, w }) do
			write("f32", 4, q)
		end
	end
	buffer.writestring(output, pos, "FE2T")
	pos += 4
	write("u8", 1, Codec.VERSION)
	write("u8", 1, fps)
	write("u32", 4, #frames)
	str(author)
	str(mapName)
	for _, frame in ipairs(frames) do
		write("f64", 8, frame.time)
		for i = 1, 3 do
			write("f32", 4, frame.VVelocity[i])
		end
		cf(frame.CCFrame)
		cf(frame.CCameraCFrame)
		local animation = frame.AAnimation or { "idle", 0 }
		write("f32", 4, animation[2])
		str(animation[1])
		local flags = (frame.AAnimation == nil and 1 or 0) + (frame.AAnimationChanged ~= nil and 2 or 0)
		write("u8", 1, flags)
		if frame.AAnimationChanged ~= nil then
			write("f64", 8, frame.AAnimationChanged)
		end
	end
	assert(pos == length, "Binary size mismatch")
	return buffer.tostring(output)
end
function Codec.decodeBinary(bytes)
	assert(type(bytes) == "string" and #bytes >= 14 and bytes:sub(1, 4) == "FE2T", "Invalid FE2T header")
	local input, pos = buffer.fromstring(bytes), 4
	local function need(size)
		assert(pos + size <= #bytes, "Truncated binary recording")
	end
	local function read(kind, size)
		need(size)
		local value = buffer["read" .. kind](input, pos)
		pos += size
		assert(finite(value), "Non-finite binary value")
		return value
	end
	local function str()
		local size = read("u16", 2)
		need(size)
		local s = buffer.readstring(input, pos, size)
		pos += size
		return s
	end
	local function cf()
		local result = { read("f32", 4), read("f32", 4), read("f32", 4) }
		local x, y, z, w = read("f32", 4), read("f32", 4), read("f32", 4), read("f32", 4)
		result[4], result[5], result[6] = euler(x, y, z, w)
		return result
	end
	local version, fps, count = read("u8", 1), read("u8", 1), read("u32", 4)
	assert(version == 2 or version == 3, "Unsupported FE2T version: " .. version)
	assert(fps > 0 and count > 0 and count <= Codec.MAX_FRAMES, "Invalid binary metadata")
	local author, mapName = str(), str()
	assert(count <= math.floor((#bytes - pos) / (version == 2 and 82 or 83)), "Frame count exceeds binary data")
	local frames = table.create(count)
	for index = 1, count do
		local frame = { time = read("f64", 8), VVelocity = { read("f32", 4), read("f32", 4), read("f32", 4) } }
		frame.CCFrame, frame.CCameraCFrame = cf(), cf()
		local speed = read("f32", 4)
		frame.AAnimation, frame.AAnimationChanged = { str(), speed }, speed
		if version == 3 then
			local flags = read("u8", 1)
			assert(flags <= 3, "Unknown frame flags")
			if flags % 2 == 1 then
				frame.AAnimation = nil
			end
			frame.AAnimationChanged = flags >= 2 and read("f64", 8) or nil
		end
		frames[index] = frame
	end
	assert(pos == #bytes, "Unexpected trailing recording data")
	return Codec.validate(frames),
		{ version = version, fps = fps, author = author, mapName = mapName, format = "binary" }
end
function Codec.decode(bytes, httpService)
	assert(type(bytes) == "string" and #bytes > 0, "Expected nonempty recording bytes")
	if bytes:sub(1, 4) == "FE2T" then
		return Codec.decodeBinary(bytes)
	end
	if bytes:sub(1, 3) == "\239\187\191" then
		bytes = bytes:sub(4)
	end
	local frames = (httpService or game:GetService("HttpService")):JSONDecode(bytes)
	return Codec.validate(frames), { format = "json", fps = 60 }
end
function Codec.encodeJSON(frames, httpService)
	return (httpService or game:GetService("HttpService")):JSONEncode(Codec.validate(frames))
end
function Codec.convert(bytes, target, metadata, httpService)
	local frames, existing = Codec.decode(bytes, httpService)
	if target == "json" then
		return Codec.encodeJSON(frames, httpService)
	end
	assert(target == "binary", "Expected json or binary")
	return Codec.encodeBinary(frames, metadata or existing)
end
return Codec
