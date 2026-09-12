return function(root, options)
	options = options or { localOnly = true }
	assert(type(options) == "table", "Runtime options must be a table")
	assert(options.localOnly == nil or type(options.localOnly) == "boolean", "localOnly must be true or false")
	local cache = {}
	local function validate(relative)
		assert(type(relative) == "string" and relative ~= "", "Expected a relative project path")
		assert(
			not relative:find("\\", 1, true)
				and not relative:find(":", 1, true)
				and not relative:find('[<>"|?*%c]')
				and relative:sub(1, 1) ~= "/"
				and relative:sub(-1) ~= "/"
				and not relative:find("//", 1, true),
			"Expected a relative project path"
		)
		for segment in relative:gmatch("[^/]+") do
			assert(segment ~= ".." and segment ~= "." and not segment:find("[. ]$"), "Invalid project path")
			local device = (segment:match("^[^.]+") or segment):upper()
			assert(
				not ({ CON = true, PRN = true, AUX = true, NUL = true })[device]
					and not device:match("^COM[1-9]$")
					and not device:match("^LPT[1-9]$"),
				"Reserved project path"
			)
		end
		return relative
	end
	validate(root)
	local Runtime = { root = root, localOnly = options.localOnly == true }
	local base = options.baseURL or "https://raw.githubusercontent.com/tomatotxt/FloodGUI/live/"
	assert(type(base) == "string" and base ~= "", "Expected a remote project URL")
	base = base:gsub("/+$", "") .. "/"
	function Runtime.path(relative)
		return root .. "/" .. validate(relative)
	end
	function Runtime.url(relative)
		return base
			.. validate(relative):gsub("([^%w%-%._~/])", function(character)
				return string.format("%%%02X", string.byte(character))
			end)
	end
	function Runtime.readRemote(relative)
		validate(relative)
		assert(not Runtime.localOnly, "Remote access disabled in local-only mode")
		if cache[relative] ~= nil then
			return cache[relative]
		end
		local data = game:HttpGet(Runtime.url(relative))
		assert(
			type(data) == "string" and data ~= "" and data ~= "404: Not Found",
			"Unavailable FloodGUI file: " .. relative
		)
		cache[relative] = data
		return data
	end
	function Runtime.read(relative)
		local path = Runtime.path(relative)
		-- User recordings take priority; online code comes from live once per session.
		if Runtime.localOnly or relative:sub(1, 10) == "TAS FILES/" then
			if isfile(path) then
				return readfile(path)
			end
			assert(not Runtime.localOnly, "Missing FloodGUI file: " .. path)
		end
		return Runtime.readRemote(relative)
	end
	function Runtime.run(relative, ...)
		local chunk, err = loadstring(Runtime.read(relative), "@" .. Runtime.path(relative))
		assert(chunk, err)
		return chunk(...)
	end
	function Runtime.catalog()
		return game:GetService("HttpService"):JSONDecode(Runtime.read("tas-catalog.json"))
	end
	return Runtime
end
