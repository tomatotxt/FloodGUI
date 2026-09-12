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
	local localChoice, bundledChoice
	local function select(name, source)
		selected = name
		local other = source == "Local" and bundledChoice or localChoice
		if other then
			other:Set(nil, true)
		end
		info:Set(
			name and (source .. ": " .. name .. "\nChoose Inspect to view its duration and metadata.")
				or "Select a file to inspect or convert."
		)
	end
	localChoice = tab:Dropdown({
		Name = "Local files",
		Options = {},
		SearchAfter = 0,
		Callback = function(name)
			select(name, "Local")
		end,
	})
	bundledChoice = tab:Dropdown({
		Name = "Bundled files",
		Desc = "Available to download. Files already saved locally appear above.",
		Options = {},
		SearchAfter = 0,
		Callback = function(name)
			select(name, "Bundled")
		end,
	})
	local refreshing = false
	local function refresh()
		if refreshing or tab.Window._destroyed then
			return
		end
		refreshing = true
		localFiles, bundled = {}, {}
		local ok, files = pcall(function()
			return listfiles(Runtime.path("TAS FILES"))
		end)
		if ok and type(files) == "table" then
			for _, path in ipairs(files) do
				local name = path:match("([^/\\]+)$")
				if name and (name:match("%.json$") or name:match("%.fe2tomatas$")) then
					table.insert(localFiles, name)
				end
			end
		end
		local catalogOK, catalog = pcall(Runtime.catalog)
		if catalogOK and type(catalog) == "table" then
			for _, item in ipairs(catalog) do
				if not table.find(localFiles, item.name) then
					table.insert(bundled, item.name)
				end
			end
		end
		table.sort(localFiles)
		table.sort(bundled)
		refreshing = false
		if tab.Window._destroyed then
			return
		end
		localChoice:Refresh(localFiles, true)
		bundledChoice:Refresh(bundled, true)
		if selected and table.find(localFiles, selected) then
			localChoice:Set(selected, true)
			bundledChoice:Set(nil, true)
		elseif selected and table.find(bundled, selected) then
			bundledChoice:Set(selected, true)
			localChoice:Set(nil, true)
		else
			selected = nil
			localChoice:Set(nil, true)
			bundledChoice:Set(nil, true)
			info:Set("Select a file to inspect or convert.")
		end
		inventory:Set(
			string.format(
				"%d local • %d available to download%s",
				#localFiles,
				#bundled,
				ok and "" or " • Local listing unavailable"
			)
		)
		if not catalogOK then
			alert("Catalog unavailable: " .. tostring(catalog), "Warning")
		end
	end
	local busy = false
	local function useSelection(action)
		if busy or tab.Window._destroyed then
			return
		end
		if not selected then
			alert("Select a recording first.", "Warning")
			return
		end
		busy = true
		local name = selected
		local ok, result = pcall(action, name)
		busy = false
		if tab.Window._destroyed then
			return
		end
		alert(ok and tostring(result) or ("Recording error: " .. tostring(result)), ok and "Success" or "Error")
	end
	tab:Button({
		Name = "Inspect recording",
		Icon = "file-search",
		Callback = function()
			useSelection(function(name)
				local frames, metadata = Recordings.loadFile(name)
				if tab.Window._destroyed or selected ~= name then
					return "Inspection finished: " .. name
				end
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
			if importing or busy or tab.Window._destroyed then
				return
			end
			importing = true
			busy = true
			local ok, result = pcall(function()
				local address = url:Get():match("^%s*(.-)%s*$")
				local mapName = map:Get():match("^%s*(.-)%s*$")
				assert(address:match("^https://%S+$"), "Enter an HTTPS recording URL")
				assert(mapName ~= "", "Enter a map name")
				local frames, metadata = Recordings.codec.decode(game:HttpGet(address))
				metadata.mapName = mapName
				return Recordings.save(mapName, frames, metadata)
			end)
			importing = false
			busy = false
			if tab.Window._destroyed then
				return
			end
			alert(ok and ("Imported: " .. result) or tostring(result), ok and "Success" or "Error")
			if ok then
				refresh()
			end
		end,
	})
	task.spawn(refresh)
	return { refresh = refresh }
end
