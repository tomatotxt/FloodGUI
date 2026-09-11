return function(Runtime)
    local Codec = Runtime.run("TAS/codec.luau")
    local API = {codec = Codec}
    local function clean(name)
        assert(type(name) == "string", "Expected a map/file name")
        name = name:gsub("%.fe2tomatas$", ""):gsub("%.json$", ""):match("^%s*(.-)%s*$")
        assert(name ~= "" and not name:find('[<>:"/\\|?*%c]') and not name:find("..", 1, true), "Invalid recording name")
        return name
    end
    function API.loadFile(filename)
        assert(filename:match("%.json$") or filename:match("%.fe2tomatas$"), "Unsupported recording file")
        clean(filename)
        return Codec.decode(Runtime.read("TAS FILES/" .. filename))
    end
    function API.loadMap(name)
        local base = clean(name)
        local failures = {}
        local candidates = {{file = base .. ".fe2tomatas", revision = 1}}
        if type(listfiles) == "function" then
            local ok, files = pcall(listfiles, Runtime.path("TAS FILES"))
            if ok then
                local pattern = "^" .. base:gsub("(%W)", "%%%1") .. " %((%d+)%)%.fe2tomatas$"
                for _, path in ipairs(files) do
                    local filename = path:match("([^/\\]+)$")
                    local revision = filename and tonumber(filename:match(pattern))
                    if revision then table.insert(candidates, {file = filename, revision = revision}) end
                end
            end
        end
        table.sort(candidates, function(a,b) return a.revision > b.revision end)
        table.insert(candidates, {file = base .. ".json", revision = 0})
        for _, candidate in ipairs(candidates) do
            local file = candidate.file
            if isfile(Runtime.path("TAS FILES/" .. file)) then
                local ok, frames, metadata = pcall(API.loadFile, file)
                if ok then return frames, metadata, file end
                table.insert(failures, tostring(frames))
            end
        end
        if not Runtime.localOnly and Runtime.catalog then
            local ok, catalog = pcall(Runtime.catalog)
            if ok then
                for _, extension in ipairs({".fe2tomatas", ".json"}) do
                    for _, item in ipairs(catalog) do
                        if item.name == base .. extension then
                            local loaded, frames, metadata = pcall(API.loadFile, item.name)
                            if loaded then return frames, metadata, item.name end
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
        for _, extension in ipairs({".fe2tomatas", ".json"}) do
            if isfile(Runtime.path("TAS FILES/" .. base .. extension)) then
                local ok = pcall(API.loadMap, name)
                if ok then return true end
            end
        end
        local ok, catalog = pcall(Runtime.catalog)
        if ok then
            for _, item in ipairs(catalog) do
                if item.name == base .. ".json" or item.name == base .. ".fe2tomatas" then return true end
            end
        end
        return false
    end
    function API.save(name, frames, metadata)
        local base = clean(name)
        metadata = metadata or {mapName = base, fps = 60, author = ""}
        local bytes = Codec.encodeBinary(frames, metadata)
        local folder = Runtime.path("TAS FILES")
        if not isfolder(folder) then makefolder(folder) end
        local relative = "TAS FILES/" .. base .. ".fe2tomatas"
        -- New recordings get distinct filenames; existing runs are never overwritten silently.
        local suffix = 2
        while isfile(Runtime.path(relative)) do
            relative = "TAS FILES/" .. base .. " (" .. suffix .. ").fe2tomatas"; suffix += 1
        end
        writefile(Runtime.path(relative), bytes)
        return relative
    end
    function API.convertFile(filename, target)
        local frames, metadata = API.loadFile(filename)
        local base = clean(filename)
        metadata.mapName = metadata.mapName or base
        if target == "binary" then return API.save(base, frames, metadata) end
        assert(target == "json", "Expected json or binary")
        local relative = "TAS FILES/" .. base .. ".json"
        assert(not isfile(Runtime.path(relative)), "Destination exists; choose a different filename")
        writefile(Runtime.path(relative), Codec.encodeJSON(frames))
        return relative
    end
    return API
end
