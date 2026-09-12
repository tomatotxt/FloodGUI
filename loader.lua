-- Online: loadstring(game:HttpGet("https://raw.githubusercontent.com/tomatotxt/FloodGUI/live/loader.lua"))()
-- Local development: loadfile("FloodGUI/loader.lua")({localOnly = true})
local options = ... or {}
assert(type(options) == "table", "Loader options must be a table; branch arguments are no longer supported")
assert(options.localOnly == nil or type(options.localOnly) == "boolean", "localOnly must be true or false")
local root = options.root or "FloodGUI"
assert(type(root) == "string" and root ~= "", "Expected a local workspace folder")
root = root:gsub("\\", "/"):gsub("/+$", "")
assert(
	root ~= "" and root:sub(1, 1) ~= "/" and not root:find('[<>:"|?*%c]') and not root:find("//", 1, true),
	"Use a folder relative to the executor workspace"
)
-- Validate the complete root before creating anything: an invalid later segment
-- must not leave partially created workspace folders behind.
for segment in root:gmatch("[^/]+") do
	assert(
		segment ~= ".." and segment ~= "." and not segment:find("[. ]$"),
		"Use a folder relative to the executor workspace"
	)
	local device = (segment:match("^[^.]+") or segment):upper()
	assert(
		not ({ CON = true, PRN = true, AUX = true, NUL = true })[device]
			and not device:match("^COM[1-9]$")
			and not device:match("^LPT[1-9]$"),
		"Reserved workspace folder name"
	)
end
for _, api in ipairs({ "isfile", "readfile", "writefile", "isfolder", "makefolder", "loadstring" }) do
	assert(type(getfenv()[api]) == "function", "FloodGUI requires executor API: " .. api)
end
local partial = ""
for segment in root:gmatch("[^/]+") do
	partial = partial == "" and segment or partial .. "/" .. segment
	if not isfolder(partial) then
		makefolder(partial)
	end
end
if not isfolder(root .. "/TAS FILES") then
	makefolder(root .. "/TAS FILES")
end
local base = "https://raw.githubusercontent.com/tomatotxt/FloodGUI/live/"
local source
if options.localOnly then
	source = readfile(root .. "/runtime.luau")
else
	source = game:HttpGet(base .. "runtime.luau")
end
local initialize, err = loadstring(source, "@FloodGUI/runtime.luau")
assert(initialize, "FloodGUI runtime failed to compile: " .. tostring(err))
local runtime = initialize()(root, { localOnly = options.localOnly == true, baseURL = base })
getgenv().FloodGUIRuntime = runtime
return runtime.run("FloodGUI.luau")
