return function(Runtime)
	local Codec = Runtime.run("TAS/codec.luau")
	local API = { codec = Codec }
	local pending = {}
	local function clean(name)
		assert(type(name) == "string", "Expected a map/file name")
		name = name:match("^%s*(.-)%s*$")
		local extension = name:lower():match("(%.[^.]*)$")
		if extension == ".fe2tomatas" or extension == ".json" then
			name = name:sub(1, -#extension - 1)
		end
		assert(
			name ~= "" and not name:find('[<>:"/\\|?*%c]') and not name:find("..", 1, true),
			"Invalid recording name"
		)
		assert(not name:find("[. ]$"), "Recording names cannot end with a dot or space")
		local device = (name:match("^[^.]+") or name):upper()
		assert(
			not ({ CON = true, PRN = true, AUX = true, NUL = true })[device]
				and not device:match("^COM[1-9]$")
				and not device:match("^LPT[1-9]$"),
			"Reserved recording name"
		)
		return name
	end
	function API.loadFile(filename)
		assert(
			type(filename) == "string"
				and (filename:lower():match("%.json$") or filename:lower():match("%.fe2tomatas$")),
			"Unsupported recording file"
		)
		clean(filename)
		return Codec.decode(Runtime.read("TAS FILES/" .. filename))
	end
	local function binaryCandidates(base)
		local candidates = { { file = base .. ".fe2tomatas", revision = 1 } }
		local seen = { [base:lower() .. ".fe2tomatas"] = true }
		if type(listfiles) == "function" then
			local ok, files = pcall(listfiles, Runtime.path("TAS FILES"))
			if ok and type(files) == "table" then
				local pattern = "^" .. base:lower():gsub("(%W)", "%%%1") .. " %((%d+)%)%.fe2tomatas$"
				for _, path in ipairs(files) do
					local filename = type(path) == "string" and path:match("([^/\\]+)$")
					local revision = filename and tonumber(filename:lower():match(pattern))
					if revision and revision >= 2 and revision < 9007199254740991 and not seen[filename:lower()] then
						seen[filename:lower()] = true
						table.insert(candidates, { file = filename, revision = revision })
					end
				end
			end
		end
		table.sort(candidates, function(a, b)
			if a.revision == b.revision then
				return a.file < b.file
			end
			return a.revision > b.revision
		end)
		return candidates
	end
	function API.loadMap(name)
		local base = clean(name)
		local failures = {}
		local candidates = binaryCandidates(base)
		table.insert(candidates, { file = base .. ".json", revision = 0 })
		for _, candidate in ipairs(candidates) do
			local file = candidate.file
			if isfile(Runtime.path("TAS FILES/" .. file)) then
				local ok, frames, metadata = pcall(API.loadFile, file)
				if ok then
					return frames, metadata, file
				end
				table.insert(failures, tostring(frames))
			end
		end
		if not Runtime.localOnly and Runtime.catalog then
			local ok, catalog = pcall(Runtime.catalog)
			if ok and type(catalog) == "table" then
				for _, extension in ipairs({ ".fe2tomatas", ".json" }) do
					for _, item in ipairs(catalog) do
						if type(item) == "table" and item.name == base .. extension then
							-- The local candidate already failed. Read the remote bytes explicitly
							-- so a damaged local copy cannot mask its bundled counterpart.
							local loaded, frames, metadata = pcall(function()
								local read = Runtime.readRemote or Runtime.read
								return Codec.decode(read("TAS FILES/" .. item.name))
							end)
							if loaded then
								return frames, metadata, item.name
							end
							table.insert(failures, tostring(frames))
						end
					end
				end
			end
		end
		error("No usable recording for " .. base .. (#failures > 0 and (": " .. table.concat(failures, "; ")) or ""))
	end
	function API.hasMap(name)
		local base = clean(name)
		local candidates = binaryCandidates(base)
		table.insert(candidates, { file = base .. ".json" })
		for _, candidate in ipairs(candidates) do
			if isfile(Runtime.path("TAS FILES/" .. candidate.file)) then
				local ok = pcall(API.loadMap, name)
				if ok then
					return true
				end
				return false
			end
		end
		if Runtime.localOnly then
			return false
		end
		local ok, catalog = pcall(Runtime.catalog)
		if ok and type(catalog) == "table" then
			for _, item in ipairs(catalog) do
				if type(item) == "table" and (item.name == base .. ".json" or item.name == base .. ".fe2tomatas") then
					return true
				end
			end
		end
		return false
	end
	function API.save(name, frames, metadata)
		local base = clean(name)
		assert(metadata == nil or type(metadata) == "table", "Expected recording metadata")
		metadata = metadata and table.clone(metadata) or {}
		if metadata.mapName == nil or metadata.mapName == "" then
			metadata.mapName = base
		end
		local bytes = Codec.encodeBinary(frames, metadata)
		local folder = Runtime.path("TAS FILES")
		if not isfolder(folder) then
			makefolder(folder)
		end
		-- New recordings get distinct filenames; existing runs are never overwritten silently.
		-- Start after the newest revision, even when earlier files have been moved/deleted.
		local suffix = 1
		for _, candidate in ipairs(binaryCandidates(base)) do
			local relative = "TAS FILES/" .. candidate.file
			if isfile(Runtime.path(relative)) or pending[relative:lower()] then
				suffix = math.max(suffix, candidate.revision + 1)
			end
		end
		local relative
		repeat
			assert(suffix <= 9007199254740991, "Recording revision limit reached; choose a different name")
			relative = "TAS FILES/"
				.. base
				.. (suffix > 1 and (" (" .. string.format("%.0f", suffix) .. ")") or "")
				.. ".fe2tomatas"
			suffix += 1
		until not isfile(Runtime.path(relative)) and not pending[relative:lower()]
		pending[relative:lower()] = true
		local ok, err = pcall(function()
			writefile(Runtime.path(relative), bytes)
			assert(
				readfile(Runtime.path(relative)) == bytes,
				"Recording write verification failed; keep the current recording and retry"
			)
		end)
		pending[relative:lower()] = nil
		assert(ok, err)
		return relative
	end
	function API.convertFile(filename, target)
		assert(target == "json" or target == "binary", "Expected json or binary")
		local frames, metadata = API.loadFile(filename)
		local base = clean(filename)
		if metadata.mapName == nil or metadata.mapName == "" then
			metadata.mapName = base
		end
		if target == "binary" then
			return API.save(base, frames, metadata)
		end
		local relative = "TAS FILES/" .. base .. ".json"
		local bytes = Codec.encodeJSON(frames)
		assert(
			not isfile(Runtime.path(relative)) and not pending[relative:lower()],
			"Destination exists; choose a different filename"
		)
		pending[relative:lower()] = true
		local ok, err = pcall(function()
			local folder = Runtime.path("TAS FILES")
			if not isfolder(folder) then
				makefolder(folder)
			end
			writefile(Runtime.path(relative), bytes)
			assert(
				readfile(Runtime.path(relative)) == bytes,
				"JSON export verification failed; the source recording is unchanged"
			)
		end)
		pending[relative:lower()] = nil
		assert(ok, err)
		return relative
	end
	return API
end
