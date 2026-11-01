return function(context)
	local UI, State, Advanced = context.ui, context.state, context.advanced
	local window = UI.window("main", "FloodGUI", "FE2 | live", Enum.KeyCode.J)
	local controls, bindings, tabs = {}, {}, {}
	local pages = {}
	local groups = {
		home={"Create & Play","Recording and playback","TAS",1}, tas={"Playback","Playback controls","TAS",2},
		maps={"Maps","Choose a map",nil,4}, files={"Recordings","Your recording library","TAS",3},
		farm={"Farming","Auto farm","Tools",1}, movement={"Movement","Speed and jumping","Tools",2},
		advanced={"Advanced","Optional tools","Tools",3}, settings={"Settings","Appearance",nil,5}, about={"Settings","Credits and help",nil,5},
	}
	local function tab(id, name, icon, description)
		local group=groups[id] or {name,name}
		local result=pages[group[1]]
		if not result then
			result=window:Tab({Name=group[1],Icon=icon,Desc=description,Mode=group[3],Order=group[4]})
			pages[group[1]]=result
		end
		if id~="advanced" then result:Section(group[2], id=="about")end
		tabs[id] = result
		return result
	end
	local function set(key, value)
		if key == "SwimEnabled" and not context.swimAvailable then
			value = false
		end
		State[key] = value
		if key == "AutoFarm" then
			if value and context.cancelPlayerLaunch then context.cancelPlayerLaunch() end
			State.PracticeMap = nil
			getgenv().TomatoAutoFarm = value
			if value then
				State.AutoPlay = false
				if getgenv().FloodGUIStopPlayer then
					getgenv().FloodGUIStopPlayer(false)
				end
			end
		elseif key == "AutoPlay" then
			if not value and context.cancelPlayerLaunch then context.cancelPlayerLaunch() end
			if value and getgenv().TAS_Active then
				State.AutoPlay = false
				context.alert("Stop the creator before enabling playback.", "Warning")
				return
			end
			if value then
				State.AutoFarm = false
				getgenv().TomatoAutoFarm = false
			elseif getgenv().FloodGUIStopPlayer then
				getgenv().FloodGUIStopPlayer(false)
			end
		elseif key == "Noclip" then
			context.noclip(value)
		elseif key == "Notifications" then
			UI.notifications = value
		elseif key == "InterfaceScale" then
			UI.setScale(value)
		end
		if context.savePreferences then
			context.savePreferences(key)
		end
	end
	local function bind(page, kind, key, name, description, extra)
		local options = {
			Name = name,
			Desc = description,
			Default = State[key],
			Callback = function(value)
				if kind == "Dropdown" and value == nil then
					return
				end
				set(key, value)
			end,
		}
		for k, v in pairs(extra or {}) do
			options[k] = v
		end
		local control = page[kind](page, options)
		controls[key] = control
		table.insert(bindings, { key = key, control = control })
		return control
	end
	local function button(page, id, name, description, icon, action, primary)
		local control = page:Button({
			Name = name,
			Desc = description,
			Icon = icon,
			Style = primary and "Primary" or nil,
			Callback = action,
		})
		controls[id] = control
		return control
	end
	local function sync()
		for _, item in ipairs(bindings) do
			if item.control:Get() ~= State[item.key] then
				item.control:Set(State[item.key], true)
			end
		end
	end
	local function stop()
		context.stop()
		sync()
	end
	local home = tab("home", "Overview", "layout-dashboard", "Session status and quick actions")
	button(
		home,
		"Creator",
		"Create recording",
		"Pauses automation and switches into recording mode.",
		"clapperboard",
		function()
			context.execute("Record")
			sync()
		end,
		true
	)
	button(home, "Player", "Play current map", "Loads the recording for the current map.", "play", function()
		context.execute("Play")
	end)
	home:Section("Session",true)
	button(home,"Stop","Stop automation","Stops farming, playback and other automation.","square",stop)

	local farm = tab("farm", "Farming", "sprout", "Automation and round timing")
	bind(farm, "Toggle", "AutoFarm", "Auto farm", "Navigate through map buttons and the exit.")
	farm:Section("Collection and progression")
	bind(farm, "Toggle", "AutoCollect", "Collect pages and escapees", "Runs independently of farm and TAS playback.")
	bind(farm, "Toggle", "AutoRebirth", "Auto rebirth", "Periodically send a rebirth request when enabled.")
	bind(
		farm,
		"Slider",
		"RebirthInterval",
		"Rebirth interval",
		"Seconds between rebirth attempts.",
		{ Min = 60, Max = 600, Step = 15, Suffix = " s" }
	)

	farm:Section("Round behavior", true)
	bind(
		farm,
		"Toggle",
		"PlayAfterButtons",
		"Finish the map manually",
		"Collect buttons, return to the starting point, then hand control back to you."
	)
	bind(
		farm,
		"Slider",
		"StartDelay",
		"Start delay",
		"Wait before farm movement begins.",
		{ Min = 0, Max = 30, Step = 0.5, Suffix = " s" }
	)
	bind(
		farm,
		"Toggle",
		"ResetAfterEscape",
		"Reset after escape",
		"Wait for server escape confirmation before resetting."
	)
	bind(
		farm,
		"Slider",
		"ResetDelay",
		"Reset delay",
		"Delay after a confirmed escape.",
		{ Min = 0, Max = 15, Step = 0.5, Suffix = " s" }
	)
	bind(
		farm,
		"Toggle",
		"AutoJoinLift",
		"Automatically join lift",
		"Queue again while farm, TAS, or map selection is enabled."
	)
	farm:Section("Session",true)
	button(farm,"StopTools","Stop automation","Stops active automation across both modes.","square",stop)

	local maps = tab("maps", "Maps", "map", "Voting, targets, and difficulty")
	bind(maps, "Toggle", "SelectTASMaps", "Select target maps", "Vote using the mode and filters below.")
	bind(
		maps,
		"Dropdown",
		"Mode",
		"After selecting a map",
		"Farm, replay a recording, or open the creator.",
		{ Options = { "Farm", "Play", "Record" } }
	)
	bind(
		maps,
		"Input",
		"TargetMapName",
		"Exact map target",
		"Leave empty to choose from eligible maps.",
		{ Placeholder = "Map name" }
	)
	button(maps, "ClearTarget", "Clear map target", nil, "x", function()
		set("TargetMapName", "")
		sync()
	end)
	bind(
		maps,
		"Toggle",
		"PreferMissingTAS",
		"Prefer unrecorded maps",
		"Prioritize maps that still need a TAS recording."
	)
	maps:Section("Difficulty")
	bind(
		maps,
		"Dropdown",
		"TargetDifficulty",
		"Maximum difficulty",
		"None allows all difficulties.",
		{ Options = { "None", "Easy", "Normal", "Hard", "Insane", "Crazy", "Crazy+" } }
	)
	bind(
		maps,
		"Toggle",
		"EnforceDifficulty",
		"Enforce difficulty limit",
		"Reset and requeue when a harder map is loaded."
	)

	local tas = tab("tas", "TAS", "film", "Playback and creator preferences")
	button(tas, "LaunchPlayer", "Play current map", nil, "play", function()
		context.execute("Play")
	end)
	tas:Section("Automatic playback",true)
	bind(tas, "Toggle", "AutoPlay", "Auto-play recordings", "Automatically replay a matching recording each round.")
	bind(tas, "Toggle", "FallbackToFarm", "Farm when no recording exists", "Optional fallback to farming when no recording matches the map.")
	tas:Section("Playback tuning", true)
	bind(
		tas,
		"Slider",
		"PlaybackSpeed",
		"Playback speed",
		"Initial speed for the next run; live controls appear in the player.",
		{ Min = 0.25, Max = 3, Step = 0.05, Suffix = "x" }
	)
	bind(
		tas,
		"Slider",
		"SwimSmoothness",
		"Swim rotation response",
		"Higher values respond faster.",
		{ Min = 0.01, Max = 0.1, Step = 0.01 }
	)
	tas:Section("Create a run",true)
	button(
		tas,
		"LaunchCreator",
		"Create a recording",
		"New runs use binary format; legacy JSON files remain supported.",
		"video",
		function()
			context.execute("Record")
			sync()
		end,
		true
	)
	tas:Section("Session",true)
	button(tas, "StopPlayer", "Stop TAS playback", "Also switches off automatic playback.", "square", function()
		set("AutoPlay", false)
		if getgenv().FloodGUIStopPlayer then
			getgenv().FloodGUIStopPlayer(false)
		end
		sync()
	end)
	local files = tab("files", "Recordings", "folder-open", "Local and bundled recording library")
	context.runtime.run("ui/recordings.luau")(
		files,
		{ runtime = context.runtime, recordings = context.recordings, alert = context.alert }
	)

	local player = tab("movement", "Movement", "person-standing", "Touch toggles and keyboard shortcuts")
	bind(
		player,
		"Toggle",
		"MovementOverrides",
		"Override movement values",
		"Pauses automatically while TAS is recording or playing."
	)
	bind(player, "Slider", "WalkSpeed", "Walk speed", nil, { Min = 1, Max = 100, Step = 1 })
	bind(player, "Slider", "JumpPower", "Jump power", nil, { Min = 0, Max = 200, Step = 1 })
	button(player, "ResetMovement", "Restore movement defaults", nil, "rotate-ccw", function()
		set("WalkSpeed", 20)
		set("JumpPower", 50)
		sync()
	end)
	player:Section("Movement abilities",true)
	bind(player, "Toggle", "GodMode", "Infinite air / health", "Keep the character's health topped up.")
	bind(player, "Toggle", "Noclip", "Noclip", "Move through solid map geometry.")
	bind(player, "Toggle", "AirJump", "Air jump", "Use the jump button while airborne.")
	local swim = bind(player, "Toggle", "SwimEnabled", "TAS swim mode", "Spoof the swimming position used by TAS.")
	if not context.swimAvailable then
		if swim.SetDisabled then
			swim:SetDisabled(true, "Swim hook unavailable")
		end
		player:Paragraph({
			Name = "Swim unavailable",
			Content = "This executor does not provide the required hook functions.",
		})
	end

	local advanced = tab("advanced", "Advanced", "flask-conical", "Capability checks and optional quickfarm features")
	local descriptions = {
		["Fast load"] = "Shorten supported loading transitions.",
		["Forced win"] = "Requires an identifiable escape lock in the game's internals.",
		["Direct buttons"] = "Use supported button and locator events.",
		["Auto boost"] = "Sends boosts each round; approximately 20 gems expected.",
		["Smart challenges"] = "Cycle challenges using description rules; about 50 coins expected.",
		["Timed challenges"] = "Cycle challenges on a timer; may spend coins.",
	}
	for _, name in ipairs({
		"Fast load",
		"Forced win",
		"Direct buttons",
		"Auto boost",
		"Manual boost",
		"Smart challenges",
		"Timed challenges",
	}) do
		if name=="Fast load" then advanced:Section("Loading and map actions",true)
		elseif name=="Auto boost" then advanced:Section("Boosts",true)
		elseif name=="Smart challenges" then advanced:Section("Challenges",true)end
		local feature = Advanced.guard.features[name]
		if not feature then
			advanced:Paragraph({
				Name = name .. " | unavailable",
				Content = "The advanced module could not initialize.",
			})
		else
			local control
			local note = advanced:Paragraph({ Name = name, Content = "Checking..." })
			if name == "Manual boost" then
				control = button(
					advanced,
					"ManualBoost",
					"Request full boost",
					"Spends approximately 20 gems.",
					"zap",
					function()
						if not feature.available then
							return
						end
						UI.confirm(
							window,
							"Spend gems on boosts?",
							"Four boost requests will be sent. Expected total: 20 gems.",
							Advanced.manualBoost
						)
					end
				)
			else
				local function enable(value)
					Advanced.enable(name, value)
				end
				control = advanced:Toggle({
					Name = name,
					Desc = descriptions[name],
					Default = false,
					Callback = function(value)
						if
							value and (name == "Auto boost" or name == "Smart challenges" or name == "Timed challenges")
						then
							control:Set(false, true)
							UI.confirm(window, "Enable " .. name .. "?", descriptions[name], function()
								enable(true)
							end)
						else
							enable(value)
						end
					end,
				})
				controls["Advanced:" .. name] = control
			end
			local function changed(f)
				note:Set(
					f.available
							and (name == "Manual boost" and "Available | ready" or f.enabled and "Enabled" or "Available | off")
						or ("Disabled: " .. tostring(f.reason))
				)
				if control.Set and name ~= "Manual boost" then
					control:Set(f.enabled, true)
				end
				if control.SetDisabled then
					control:SetDisabled(not f.available, name .. " unavailable")
				end
			end
			feature.changed = changed
			changed(feature)
		end
	end
	bind(
		advanced,
		"Slider",
		"ChallengeInterval",
		"Challenge cycle interval",
		"Applies to timed challenge cycling.",
		{ Min = 60, Max = 1800, Step = 60, Suffix = " s" }
	)

	local settings = tab("settings", "Settings", "settings", "Interface, shortcuts, and session tools")
	bind(settings, "Toggle", "AlertsEnabled", "Game alerts", "Show messages in the game's alert feed.")
	bind(settings, "Toggle", "Notifications", "UI notifications", "Show FloodGUI notification cards.")
	bind(
		settings,
		"Slider",
		"InterfaceScale",
		"Interface scale",
		"Scale the main, creator, and player windows.",
		{ Min = 0.8, Max = 1.25, Step = 0.05, Suffix = "x" }
	)
	settings:Section("Connection",true)
	bind(settings, "Toggle", "AntiAFK", "Prevent idle disconnect", "Keep the session active while idle.")
	bind(
		settings,
		"Toggle",
		"AutoLeave",
		"Leave when a player joins",
		"Disconnect if another player enters the server."
	)
	settings:Section("Keyboard shortcuts", true)
	for _, item in ipairs({
		{ "GodMode", "Infinite air / health", Enum.KeyCode.R },
		{ "Noclip", "Noclip", Enum.KeyCode.G },
		{ "AirJump", "Air jump", Enum.KeyCode.M },
		{ "SwimEnabled", "TAS swim mode", Enum.KeyCode.Y },
	}) do
		settings:Keybind({
			Name = item[2],
			Default = item[3],
			Callback = function()
				if getgenv().TAS_Active then
					return
				end
				set(item[1], not State[item[1]])
				sync()
			end,
		})
	end
	settings:Keybind({
		Name = "Show / hide main UI",
		Default = Enum.KeyCode.J,
		OnChanged = function(key)
			window:SetKeybind(key)
		end,
	})
	local about = tab("about", "About", "info", "FloodGUI | Kavo fork")
	about:Paragraph({
		Name = "Credits",
		Content = "TAS system: Tomato; original foundation: Voiz#5668.\nGUI and integration: Tomato.\nInterface: xHeptc Kavo, using tomatotxt's fork and the original Flood-GUI theme.",
	})
	button(about, "Support", "Copy support invite", nil, "message-circle", context.copyInvite)
	about:Paragraph({
		Name = "Recording formats",
		Content = "New recordings: FE2T binary (.fe2tomatas).\nCompatible input: legacy JSON and experimental binary recordings.\nConversions are available in Recordings.",
	})
	settings:Section("Session tools")
	settings:Paragraph({
		Name = "Remembered preferences",
		Content = "Interface scale, notification choices, playback speed, and timing settings save automatically on this device. Automation, movement toggles, and spending actions always start off.",
	})
	button(
		settings,
		"ResetPreferences",
		"Restore preference defaults",
		"Resets remembered settings without deleting recordings.",
		"rotate-ccw",
		function()
			UI.confirm(
				window,
				"Restore preference defaults?",
				"Your recordings and active feature toggles will not be changed.",
				function()
					if context.resetPreferences then
						context.resetPreferences()
						sync()
					end
				end
			)
		end
	)
	button(
		settings,
		"Rejoin",
		"Rejoin game",
		"Hop to baseplate, wait 3.6 seconds, then return to this server. Save your recording first.",
		"log-in",
		context.rejoin
	)
	advanced:Section("External tools",true)
	button(
		advanced,
		"InfiniteYield",
		"Load Infinite Yield",
		"Launch the external administration script.",
		"terminal",
		context.infiniteYield
	)
	button(settings, "Hide", "Hide interface", "Use the floating FloodGUI button to reopen it.", "eye-off", function()
		window:Toggle(false)
	end)
	button(
		settings,
		"Unload",
		"Unload FloodGUI",
		"Stops the current session and removes its windows. Run the loader to reopen.",
		"power",
		function()
			UI.confirm(
				window,
				"Unload FloodGUI?",
				"Automation and TAS playback will stop. Save any creator recording first.",
				function()
					if context.unload then
						context.unload()
					end
				end
			)
		end
	)
	window:ConfigureModes({Default="TAS",
		TAS={Accent=Color3.fromRGB(70,150,255),Header=Color3.fromRGB(25,28,36)},
		Tools={Accent=Color3.fromRGB(245,105,110),Header=Color3.fromRGB(36,25,29)},
	})
	task.spawn(function()
		while not context.session.Cancelled and not window._destroyed do
			sync()
			window:SetStatus((getgenv().TAS_Active and "Creator open" or getgenv().IsTASPlaying and "Playing" or State.AutoPlay and "TAS waiting" or "Idle")..(State.AutoFarm and " | Farm on" or ""))
			task.wait(0.3)
		end
	end)
	return { window = window, controls = controls, tabs = tabs, sync = sync }
end
