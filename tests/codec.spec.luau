local Codec = require("../TAS/codec")
local fixtures = require("./recording-fixtures")
local function close(a, b)
	assert(math.abs(a - b) <= 0.0001 + math.abs(a) * 0.000001, tostring(a) .. " differs from " .. tostring(b))
end
local function rotation(cf)
	local sx, cx, sy, cy, sz, cz =
		math.sin(cf[4]), math.cos(cf[4]), math.sin(cf[5]), math.cos(cf[5]), math.sin(cf[6]), math.cos(cf[6])
	return { cy * cz, -cy * sz, sy, cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy, sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy }
end
local function compare(a, b)
	close(a.time, b.time)
	assert(a.AAnimationChanged == b.AAnimationChanged)
	if a.AAnimation then
		assert(a.AAnimation[1] == b.AAnimation[1])
		close(a.AAnimation[2], b.AAnimation[2])
	else
		assert(b.AAnimation == nil)
	end
	for _, key in ipairs({ "CCFrame", "CCameraCFrame", "VVelocity" }) do
		for i = 1, 3 do
			close(a[key][i], b[key][i])
		end
		if key ~= "VVelocity" then
			local left, right = rotation(a[key]), rotation(b[key])
			for i = 1, 9 do
				close(left[i], right[i])
			end
		end
	end
end
local bytes = Codec.encodeBinary(fixtures, { author = "Tomato", mapName = "Roundtrip", fps = 60 })
local decoded, metadata = Codec.decodeBinary(bytes)
assert(#decoded == 178 and metadata.version == 3 and metadata.mapName == "Roundtrip")
for i, frame in ipairs(fixtures) do
	compare(frame, decoded[i])
end
local edge = {
	time = 0,
	CCFrame = { 0, 1000, 0, 0, math.pi / 2, math.pi },
	CCameraCFrame = { 0, 1000, 0, math.pi, -math.pi / 2, 1 },
	VVelocity = { 0, 0, 0 },
}
compare(edge, Codec.decodeBinary(Codec.encodeBinary({ edge }))[1])
local frame = {
	time = 1,
	CCFrame = { 1, 2, 3, 0.1, 0.2, 0.3 },
	CCameraCFrame = { 4, 5, 6, 0.4, 0.5, 0.6 },
	VVelocity = { 7, 8, 9 },
	AAnimation = { "walk", 0.5 },
}
local v3 = Codec.encodeBinary({ frame })
-- Independent v2 fixture: same header/frames but no per-frame v3 flags.
local v2 = v3:sub(1, 4) .. string.char(2) .. v3:sub(6, -2)
local old, oldMetadata = Codec.decodeBinary(v2)
assert(oldMetadata.version == 2 and old[1].AAnimationChanged == 0.5)
frame.AAnimationChanged = 0.5
compare(frame, old[1])
for _, invalid in ipairs({ "", "FE2T", bytes:sub(1, -2), bytes .. "extra", bytes:sub(1, 4) .. string.char(99) .. bytes:sub(
	6
) }) do
	assert(not pcall(Codec.decodeBinary, invalid), "Malformed binary accepted")
end
assert(not pcall(Codec.encodeBinary, {}))
local bad = table.clone(frame)
bad.time = 0 / 0
assert(not pcall(Codec.encodeBinary, { bad }))
for _, malformed in ipairs({
	{ [1] = frame, [3] = frame },
	{ [0] = frame, [1] = frame },
	{ [1] = frame, extra = frame },
	{ [1] = frame, [1.5] = frame },
}) do
	assert(not pcall(Codec.encodeBinary, malformed), "Sparse or non-array recordings must not silently lose frames")
end
assert(not pcall(Codec.encodeBinary, { frame }, "bad metadata"))
assert(not pcall(Codec.decode, nil))
assert(not pcall(Codec.decode, ""))
local jsonFrames
local json = {
	JSONDecode = function(_, text)
		assert(text == "legacy-json")
		return fixtures
	end,
	JSONEncode = function(_, frames)
		jsonFrames = frames
		return "exported-json"
	end,
}
local converted = Codec.convert("legacy-json", "binary", { mapName = "Legacy" }, json)
assert(Codec.convert(converted, "json", nil, json) == "exported-json" and #jsonFrames == 178)
assert(#Codec.decode("\239\187\191legacy-json", json) == 178, "UTF-8 BOM JSON should be importable")
print(
	"PASS: 178 recording roundtrips, rotations/gimbal lock, v2 compatibility, metadata, JSON conversion, malformed data rejection"
)
