return function(context)
	local UI, State, Advanced = context.ui, context.state, context.advanced
	local defaultVoteState = {
		VoteStrategy = "Lowest cost",
		MinDifficulty = "None",
		PartialMapMatch = false,
		RequireTASFile = false,
		VoteDuringAutomation = true,
		AllowPaidVotes = true,
		MaxVoteCost = 50,
		VoteMultiplier = 1,
	}
	for k, v in pairs(defaultVoteState) do
		if State[k] == nil then
			State[k] = v
		end
	end
	local diffRanks = { Easy = 1, Normal = 2, Hard = 3, Insane = 4, Crazy = 5, ["Crazy+"] = 6 }
	local window = UI.window("main", "FloodGUI", "FE2 | live", Enum.KeyCode.J)
	local controls, bindings, tabs = {}, {}, {}
	local pages = {}
	local groups = {
		home={"Create & Play","Recording and playback","TAS",1}, tas={"Playback","Playback controls","TAS",2},
		voting={"Voting","Auto vote",nil,4}, maps={"Voting","Auto vote",nil,4}, files={"Recordings","Your recording library","TAS",3},
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
		if id~="advanced" and id~="farm" and id~="voting" and id~="maps" then result:Section(group[2], id=="about")end
		tabs[id] = result
		if id == "voting" or id == "maps" then
			tabs.voting = result
			tabs.maps = result
		end
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
			State.FarmPhase = value and "Starting" or "Idle"
			if not value then State.CurrentMapName = "" end
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
		elseif key == "SelectTASMaps" then
			if value and State.LastVotePacket ~= nil and context.voteNow then
				context.voteNow()
			end
		elseif key == "PreferMissingTAS" and value then
			State.RequireTASFile = false
		elseif key == "RequireTASFile" and value then
			State.PreferMissingTAS = false
		elseif key == "MinDifficulty" and value ~= "None" and State.TargetDifficulty ~= "None" then
			if (diffRanks[value] or 0) > (diffRanks[State.TargetDifficulty] or 999) then
				State.TargetDifficulty = value
			end
		elseif key == "TargetDifficulty" and value ~= "None" and State.MinDifficulty and State.MinDifficulty ~= "None" then
			if (diffRanks[value] or 999) < (diffRanks[State.MinDifficulty] or 0) then
				State.MinDifficulty = value
			end
		elseif key == "AutoZipline" then
			if context.zipline then context.zipline.setEnabled(value) end
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
			if not (item.control.IsEditing and item.control:IsEditing()) and item.control:Get() ~= State[item.key] then
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
	local farmStatus = farm:Paragraph({
		Name = "Farm status",
		Content = "Idle | Escapes: 0",
	})
	controls.FarmStatus = farmStatus
	bind(farm, "Toggle", "AutoFarm", "Auto farm", "Navigate map buttons and the exit automatically.")
	bind(
		farm,
		"Toggle",
		"AutoJoinLift",
		"Automatically join lift",
		"Enter the waiting lift from the lobby while farm, TAS, or map selection is on."
	)
	button(farm, "StopTools", "Stop automation", "Stops active farming, playback, and auxiliary loops.", "square", stop)

	farm:Section("Round behavior", true)
	bind(
		farm,
		"Toggle",
		"ResetAfterEscape",
		"Reset after escape",
		"Respawn after server escape confirmation to requeue faster in public servers."
	)
	bind(
		farm,
		"Slider",
		"ResetDelay",
		"Reset delay",
		"Wait after a confirmed escape before respawning.",
		{ Min = 0, Max = 15, Step = 0.5, Suffix = " s" }
	)
	bind(
		farm,
		"Toggle",
		"PlayAfterButtons",
		"Finish the map manually",
		"Press all buttons, return to spawn, and hand movement back to you."
	)
	bind(
		farm,
		"Slider",
		"StartDelay",
		"Start delay",
		"Wait after round start before farm movement begins.",
		{ Min = 0, Max = 30, Step = 0.5, Suffix = " s" }
	)

	farm:Section("Collection and progression", true)
	bind(farm, "Toggle", "AutoCollect", "Collect pages and escapees", "Grab Lost Page and Escapee after round start.")
	bind(farm, "Toggle", "AutoRebirth", "Auto rebirth", "Send rebirth requests between rounds when ready.")
	bind(
		farm,
		"Slider",
		"RebirthInterval",
		"Rebirth interval",
		"Seconds between rebirth attempts.",
		{ Min = 60, Max = 600, Step = 15, Suffix = " s" }
	)

	local voting = tab("voting", "Voting", "map", "Auto vote, strategies, sniping, and coin budget")
	local voteStatus = voting:Paragraph({
		Name = "Vote status",
		Content = "Auto vote: OFF | Votes: 0",
	})
	controls.VoteStatus = voteStatus
	local autoVoteToggle = bind(
		voting,
		"Toggle",
		"SelectTASMaps",
		"Auto vote",
		"Automatically vote on every map ballot using your strategy and filters."
	)
	controls.AutoVote = autoVoteToggle
	bind(
		voting,
		"Dropdown",
		"VoteStrategy",
		"Vote strategy",
		"How FloodGUI chooses among eligible maps on the board.",
		{
			Options = {
				"Lowest cost",
				"Easiest",
				"Hardest",
				"Most popular",
				"Underdog",
				"Highlight / Community",
				"Random",
			},
		}
	)
	bind(
		voting,
		"Dropdown",
		"Mode",
		"After voting",
		"Manual votes only; Farm, Play, or Record also runs that mode when your map loads.",
		{ Options = { "Manual", "Farm", "Play", "Record" } }
	)
	button(
		voting,
		"VoteNow",
		"Vote now",
		"Cast a vote immediately on the active lobby ballot.",
		"play",
		function()
			if context.voteNow then
				context.voteNow()
			elseif context.alert then
				context.alert("No active map ballot right now.", "Info")
			end
			sync()
		end,
		true
	)

	voting:Section("Map sniping & roulette", true)
	bind(
		voting,
		"Input",
		"TargetMapName",
		"Target map",
		"Leave empty to vote by strategy, or enter a map name to snipe.",
		{ Placeholder = "Map name (e.g. Blue Moon)" }
	)
	bind(
		voting,
		"Toggle",
		"PartialMapMatch",
		"Allow partial map name",
		"Match any ballot map containing your target text (e.g. 'boreas')."
	)
	local roulettePool
	button(
		voting,
		"RandomTarget",
		"Random map roulette",
		"Pick a random map from FE2 / catalog as your snipe target.",
		"rotate-ccw",
		function()
			if not roulettePool then
				roulettePool = {}
				local seen = {}
				for _, m in ipairs(State.CatalogMaps or {}) do
					if type(m) == "string" and m ~= "" and not seen[m] then
						seen[m] = true
						table.insert(roulettePool, m)
					end
				end
				if context.runtime and context.runtime.catalog then
					local ok, entries = pcall(context.runtime.catalog)
					if ok and type(entries) == "table" then
						for _, entry in ipairs(entries) do
							local raw = type(entry) == "table" and entry.name or nil
							if type(raw) == "string" then
								local clean = raw:gsub("%.fe2tomatas$", ""):gsub("%.json$", "")
								if clean ~= "" and not seen[clean] then
									seen[clean] = true
									table.insert(roulettePool, clean)
								end
							end
						end
					end
				end
				table.sort(roulettePool)
			end
			if #roulettePool == 0 then
				if context.alert then
					context.alert("No map list available for roulette yet.", "Warning")
				end
				return
			end
			local pick = roulettePool[math.random(#roulettePool)]
			if #roulettePool > 1 and pick == State.TargetMapName then
				local idx = table.find(roulettePool, pick) or 1
				pick = roulettePool[(idx % #roulettePool) + 1]
			end
			set("TargetMapName", pick)
			sync()
			if context.alert then
				context.alert("Map roulette target: " .. pick, "Info")
			end
		end
	)
	button(voting, "ClearTarget", "Clear map target", "Return to strategy-based voting.", "x", function()
		set("TargetMapName", "")
		sync()
	end)

	voting:Section("Difficulty & TAS filters", true)
	bind(
		voting,
		"Dropdown",
		"MinDifficulty",
		"Minimum difficulty",
		"None allows all difficulties; raise to skip easy maps.",
		{ Options = { "None", "Easy", "Normal", "Hard", "Insane", "Crazy", "Crazy+" } }
	)
	bind(
		voting,
		"Dropdown",
		"TargetDifficulty",
		"Maximum difficulty",
		"None allows all difficulties up to Crazy+.",
		{ Options = { "None", "Easy", "Normal", "Hard", "Insane", "Crazy", "Crazy+" } }
	)
	bind(
		voting,
		"Toggle",
		"EnforceDifficulty",
		"Enforce difficulty range",
		"Filter ballot choices and reset/requeue if an out-of-range map loads."
	)
	bind(
		voting,
		"Toggle",
		"PreferMissingTAS",
		"Prefer unrecorded maps",
		"Prioritize maps that still need a TAS recording."
	)
	bind(
		voting,
		"Toggle",
		"RequireTASFile",
		"Only recorded TAS maps",
		"Only vote for maps that already have a local or bundled TAS recording."
	)

	voting:Section("Vote power & coin budget", true)
	bind(
		voting,
		"Toggle",
		"VoteDuringAutomation",
		"Auto-vote while farming / TAS",
		"Cast votes using these filters while Auto-Farm or TAS Auto-Play is running."
	)
	bind(
		voting,
		"Toggle",
		"AllowPaidVotes",
		"Allow paid / unlock votes",
		"Turn off to strictly cast free (0 coin) votes only."
	)
	bind(
		voting,
		"Slider",
		"MaxVoteCost",
		"Max coins per ballot",
		"Maximum coins allowed for map unlocks or extra stacked votes.",
		{ Min = 0, Max = 200, Step = 5, Suffix = " coins" }
	)
	bind(
		voting,
		"Slider",
		"VoteMultiplier",
		"Vote power (stack votes)",
		"Stack up to 5 votes on your chosen map (extra votes spend coins within budget).",
		{ Min = 1, Max = 5, Step = 1, Suffix = "x" }
	)
	button(
		voting,
		"InspectBallot",
		"Inspect current ballot",
		"Show every map, difficulty, vote count, and coin cost on the active ballot.",
		"info",
		function()
			if context.inspectBallot then
				context.inspectBallot()
			elseif context.alert then
				context.alert("No active map ballot right now.", "Info")
			end
		end
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
	local swim = bind(player, "Toggle", "SwimEnabled", "TAS swim mode", "Use the game's native swimming query.")
	bind(player, "Toggle", "AutoZipline", "Zipline assistant", "Automatically trigger and smooth ziplines using native rope data.")
	if not context.swimAvailable then
		if swim.SetDisabled then
			swim:SetDisabled(true, "Native swimming query unavailable")
		end
		player:Paragraph({
			Name = "Swim unavailable",
			Content = "The native isSwimming callback could not be read safely.",
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
		{ "AutoFarm", "Auto farm", Enum.KeyCode.Unknown },
		{ "SelectTASMaps", "Auto vote", Enum.KeyCode.Unknown },
		{ "GodMode", "Infinite air / health", Enum.KeyCode.R },
		{ "Noclip", "Noclip", Enum.KeyCode.G },
		{ "AirJump", "Air jump", Enum.KeyCode.M },
		{ "SwimEnabled", "TAS swim mode", Enum.KeyCode.Y },
	}) do
		local boundKey = item[3]
		controls["Shortcut:" .. item[1]] = settings:Keybind({
			Name = item[2],
			Default = boundKey,
			OnChanged = function(key)
				boundKey = key
			end,
			Callback = function(pressedKey)
				if not boundKey or boundKey == Enum.KeyCode.Unknown or boundKey.Name == "Unknown" then
					return
				end
				if pressedKey ~= nil and pressedKey ~= boundKey then
					return
				end
				if getgenv().TAS_Active then
					return
				end
				local nextVal = not State[item[1]]
				set(item[1], nextVal)
				sync()
				if (item[1] == "AutoFarm" or item[1] == "SelectTASMaps") and context.alert then
					context.alert(item[2] .. " " .. (nextVal and "enabled." or "disabled."), nextVal and "Success" or "Info")
				end
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
	local function formatFarmSummary()
		local phase = State.CurrentlyFarming and (State.FarmPhase or "Active")
			or State.AutoFarm and (State.FarmPhase and State.FarmPhase ~= "Idle" and State.FarmPhase or "Waiting")
			or (State.FarmPhase == "Manual finish" and "Manual finish" or "Idle")
		local mapPart = (State.CurrentMapName and State.CurrentMapName ~= "" and (State.CurrentlyFarming or State.AutoFarm))
			and (" - " .. tostring(State.CurrentMapName))
			or ""
		local escapes = tonumber(State.SessionEscapes) or 0
		local last = (State.LastEscapeTime and State.LastEscapeTime ~= "") and (" (" .. tostring(State.LastEscapeTime) .. ")") or ""
		return phase .. mapPart .. " | Escapes: " .. tostring(escapes) .. last
	end
	local function formatVoteSummary()
		local activeText
		if State.SelectTASMaps then
			activeText = "Auto vote: ON (" .. tostring(State.VoteStrategy or "Lowest cost") .. " -> " .. tostring(State.Mode or "Farm") .. ")"
		elseif State.VoteDuringAutomation ~= false and (State.AutoFarm or State.AutoPlay) then
			activeText = "Auto vote: Passive (" .. tostring(State.VoteStrategy or "Lowest cost") .. ")"
		else
			activeText = "Auto vote: OFF"
		end
		local targetPart = (State.TargetMapName and State.TargetMapName ~= "") and (" | Target: " .. tostring(State.TargetMapName)) or ""
		local votes = tonumber(State.SessionVotes) or 0
		local detail = ""
		if State.CurrentBallotSummary and State.CurrentBallotSummary ~= "" then
			detail = "\nBallot: " .. tostring(State.CurrentBallotSummary)
		elseif State.LastVotedMap and State.LastVotedMap ~= "" then
			detail = "\nLast vote: " .. tostring(State.LastVotedMap) .. " (" .. tostring(State.LastVoteCost or 0) .. " coins)"
		end
		return activeText .. targetPart .. " | Votes: " .. tostring(votes) .. detail
	end
	local function formatWindowStatus()
		if getgenv().TAS_Active then
			return "Creator open"
		elseif getgenv().IsTASPlaying then
			return "Playing TAS"
		elseif State.CurrentlyFarming then
			local mapName = State.CurrentMapName and State.CurrentMapName ~= "" and (" - " .. tostring(State.CurrentMapName)) or ""
			return (State.FarmPhase or "Farming") .. mapName
		elseif State.AutoFarm then
			return (State.FarmPhase and State.FarmPhase ~= "" and State.FarmPhase ~= "Idle")
				and ("Farm - " .. tostring(State.FarmPhase))
				or "Farm waiting"
		elseif State.AutoPlay then
			return "TAS waiting"
		elseif State.SelectTASMaps then
			return "Auto vote on"
		end
		return "Idle"
	end
	task.spawn(function()
		while not context.session.Cancelled and not window._destroyed do
			sync()
			if farmStatus and farmStatus.Set then
				farmStatus:Set(formatFarmSummary(), true)
			end
			if voteStatus and voteStatus.Set then
				voteStatus:Set(formatVoteSummary(), true)
			end
			window:SetStatus(formatWindowStatus())
			task.wait(0.3)
		end
	end)
	return { window = window, controls = controls, tabs = tabs, sync = sync }
end
