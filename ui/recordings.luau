-- Recording library inside the Airflow window; local files retain priority.
return function(tab, context)
	local Runtime, Recordings, alert = context.runtime, context.recordings, context.alert
	local selected, bundled, localFiles = nil, {}, {}
	tab:Paragraph({
		Name = "Recording library",
		Content = "Browse local runs or bundled maps. New imports and conversions are saved as binary revisions; existing recordings are preserved.",
	})
	local inventory = tab:Label({ Text = "Reading recordings…" })
	local info = tab:Paragraph({ Name = "Selected recording", Content = "Select a file to inspect or convert." })
	local localChoice = tab:Dropdown({
		Name = "Local files",
		Options = {},
		SearchAfter = 0,
		Callback = function(name)
			selected = name
		end,
	})
	local bundledChoice = tab:Dropdown({
		Name = "Bundled files",
		Options = {},
		SearchAfter = 0,
		Callback = function(name)
			selected = name
		end,
	})
	local function refresh()
		localFiles, bundled = {}, {}
		local ok, files = pcall(function()
			return listfiles(Runtime.path("TAS FILES"))
		end)
		if ok then
			for _, path in ipairs(files) do
				local name = path:match("([^/\\]+)$")
				if name and (name:match("%.json$") or name:match("%.fe2tomatas$")) then
					table.insert(localFiles, name)
				end
			end
		end
		local catalogOK, catalog = pcall(Runtime.catalog)
		if catalogOK then
			for _, item in ipairs(catalog) do
				table.insert(bundled, item.name)
			end
		end
		table.sort(localFiles)
		table.sort(bundled)
		localChoice:Refresh(localFiles, true)
		bundledChoice:Refresh(bundled, true)
		inventory:Set(
			string.format(
				"%d local • %d bundled%s",
				#localFiles,
				#bundled,
				ok and "" or " • Local listing unavailable"
			)
		)
		if not catalogOK then
			alert("Catalog unavailable: " .. tostring(catalog), "Warning")
		end
	end
	local function useSelection(action)
		if not selected then
			alert("Select a recording first.", "Warning")
			return
		end
		local ok, result = pcall(action, selected)
		alert(ok and tostring(result) or ("Recording error: " .. tostring(result)), ok and "Success" or "Error")
	end
	tab:Button({
		Name = "Inspect recording",
		Icon = "file-search",
		Callback = function()
			useSelection(function(name)
				local frames, metadata = Recordings.loadFile(name)
				info:Set(
					string.format(
						"%s\n%d frames • %.2f seconds\nMap: %s • Author: %s",
						name,
						#frames,
						frames[#frames].time,
						metadata.mapName or "Unknown",
						metadata.author or "Unknown"
					)
				)
				return "Recording validated."
			end)
		end,
	})
	tab:Button({
		Name = "Save selected as binary",
		Desc = "Downloads bundled selections too. Creates a new revision if needed.",
		Icon = "file-down",
		Callback = function()
			useSelection(function(name)
				local path = Recordings.convertFile(name, "binary")
				refresh()
				return "Saved: " .. path
			end)
		end,
	})
	tab:Button({
		Name = "Export selected to JSON",
		Desc = "Keeps legacy compatibility. Reports an error if the destination exists.",
		Icon = "file-json",
		Callback = function()
			useSelection(function(name)
				local path = Recordings.convertFile(name, "json")
				refresh()
				return "Exported: " .. path
			end)
		end,
	})
	tab:Button({ Name = "Refresh recordings", Icon = "refresh-cw", Callback = refresh })
	tab:Section("Import a recording")
	local url = tab:Input({ Name = "Recording URL", Placeholder = "https://…", Default = "" })
	local map = tab:Input({ Name = "Map name", Placeholder = "Exact map name", Default = "" })
	local importing = false
	tab:Button({
		Name = "Import and save binary",
		Style = "Primary",
		Icon = "download",
		Callback = function()
			if importing then
				return
			end
			importing = true
			local ok, result = pcall(function()
				assert(url:Get():match("^https://"), "Enter an HTTPS recording URL")
				assert(map:Get():match("%S"), "Enter a map name")
				local frames, metadata = Recordings.codec.decode(game:HttpGet(url:Get()))
				metadata.mapName = map:Get()
				return Recordings.save(map:Get(), frames, metadata)
			end)
			importing = false
			alert(ok and ("Imported: " .. result) or tostring(result), ok and "Success" or "Error")
			if ok then
				refresh()
			end
		end,
	})
	task.spawn(refresh)
	return { refresh = refresh }
end
