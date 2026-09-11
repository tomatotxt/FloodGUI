return function(context)
    local UI, State, Advanced = context.ui, context.state, context.advanced
    local window=UI.window("main","FloodGUI","FE2 • live",Enum.KeyCode.J)
    local controls, bindings, tabs = {}, {}, {}
    local function tab(id,name,icon,description)
        local result=window:Tab({Name=name,Icon=icon,Desc=description})
        tabs[id]=result
        return result
    end
    local function set(key,value)
        State[key]=value
        if key=="AutoFarm" then
            State.PracticeMap=nil
            getgenv().TomatoAutoFarm=value
        elseif key=="Noclip" then context.noclip(value)
        elseif key=="Notifications" then UI.notifications=value
        elseif key=="InterfaceScale" then UI.setScale(value) end
    end
    local function bind(page,kind,key,name,description,extra)
        local options={Name=name,Desc=description,Default=State[key],Callback=function(value) set(key,value) end}
        for k,v in pairs(extra or {}) do options[k]=v end
        local control=page[kind](page,options)
        controls[key]=control
        table.insert(bindings,{key=key,control=control})
        return control
    end
    local function button(page,id,name,description,icon,action,primary)
        local control=page:Button({Name=name,Desc=description,Icon=icon,Style=primary and "Primary" or nil,Callback=action})
        controls[id]=control
        return control
    end
    local function sync()
        for _,item in ipairs(bindings) do
            if item.control:Get()~=State[item.key] then item.control:Set(State[item.key],true) end
        end
    end
    local function stop()
        context.stop()
        sync()
    end
    local home=tab("home","Overview","layout-dashboard","Session status and quick actions")
    home:Paragraph({Name="FloodGUI",Content="Record, replay, and manage Flood Escape 2 runs. Farming and advanced actions start off; use the tabs to choose your setup."})
    local status=home:Paragraph({Name="Session",Content="Ready"})
    button(home,"Stop","Stop automation","Stops farm, playback, map selection, collection, rebirth, and advanced actions.","square",stop,true)
    button(home,"Creator","Open TAS creator","Pauses automation and switches into recording mode.","clapperboard",function()
        context.execute("Record"); sync()
    end)
    button(home,"Player","Start TAS player","Loads the recording for the current map.","play",function() context.execute("Play") end)

    local farm=tab("farm","Farming","sprout","Automation and round timing")
    farm:Section("Run mode")
    bind(farm,"Toggle","AutoFarm","Auto farm","Navigate through map buttons and the exit.")
    bind(farm,"Toggle","AutoPlay","TAS auto-play","Automatically replay a matching recording each round.")
    bind(farm,"Toggle","FallbackToFarm","Farm if TAS is missing","Use auto farm when no recording matches the map.")
    farm:Section("Round behavior")
    bind(farm,"Toggle","PlayAfterButtons","Finish the map manually","Collect buttons, return to the starting point, then hand control back to you.")
    bind(farm,"Slider","StartDelay","Start delay","Wait before farm movement begins.",{Min=0,Max=30,Step=0.5,Suffix=" s"})
    bind(farm,"Toggle","ResetAfterEscape","Reset after escape","Wait for server escape confirmation before resetting.")
    bind(farm,"Slider","ResetDelay","Reset delay","Delay after a confirmed escape.",{Min=0,Max=15,Step=0.5,Suffix=" s"})
    bind(farm,"Toggle","AutoJoinLift","Automatically join lift","Queue again while farm, TAS, or map selection is enabled.")
    farm:Section("Collection and progression")
    bind(farm,"Toggle","AutoCollect","Collect pages and escapees","Runs independently of farm and TAS playback.")
    bind(farm,"Toggle","AutoRebirth","Auto rebirth","Periodically send a rebirth request when enabled.")
    bind(farm,"Slider","RebirthInterval","Rebirth interval","Seconds between rebirth attempts.",{Min=60,Max=600,Step=15,Suffix=" s"})

    local maps=tab("maps","Maps","map","Voting, targets, and difficulty")
    bind(maps,"Toggle","SelectTASMaps","Select target maps","Vote using the mode and filters below.")
    bind(maps,"Dropdown","Mode","After selecting a map","Farm, replay a recording, or open the creator.",{Options={"Farm","Play","Record"}})
    bind(maps,"Input","TargetMapName","Exact map target","Leave empty to choose from eligible maps.",{Placeholder="Map name"})
    button(maps,"ClearTarget","Clear map target",nil,"x",function() set("TargetMapName",""); sync() end)
    bind(maps,"Toggle","PreferMissingTAS","Prefer unrecorded maps","Prioritize maps that still need a TAS recording.")
    maps:Section("Difficulty")
    bind(maps,"Dropdown","TargetDifficulty","Maximum difficulty","None allows all difficulties.",{Options={"None","Easy","Normal","Hard","Insane","Crazy","Crazy+"}})
    bind(maps,"Toggle","EnforceDifficulty","Enforce difficulty limit","Reset and requeue when a harder map is loaded.")

    local tas=tab("tas","TAS","film","Playback and creator preferences")
    button(tas,"LaunchCreator","Create a recording","New runs use binary format; legacy JSON files remain supported.","video",function() context.execute("Record"); sync() end,true)
    button(tas,"LaunchPlayer","Play current map",nil,"play",function() context.execute("Play") end)
    button(tas,"StopPlayer","Stop TAS playback","Also switches off automatic playback.","square",function()
        set("AutoPlay",false)
        if getgenv().FloodGUIStopPlayer then getgenv().FloodGUIStopPlayer(false) end
        sync()
    end)
    tas:Section("Next playback")
    bind(tas,"Slider","PlaybackSpeed","Playback speed","Initial speed for the next run; live controls appear in the player.",{Min=0.25,Max=3,Step=0.05,Suffix="×"})
    bind(tas,"Slider","SwimSmoothness","Swim rotation response","Higher values respond faster.",{Min=0.01,Max=0.1,Step=0.01})
    tas:Paragraph({Name="Creator controls",Content="The creator has its own Airflow tabs for recording, visualization, files, and shortcuts, plus buttons for holding rewind and frame advance."})
    local files=tab("files","Recordings","folder-open","Local and bundled recording library")
    context.runtime.run("ui/recordings.luau")(files,{runtime=context.runtime,recordings=context.recordings,alert=context.alert})

    local player=tab("movement","Movement","person-standing","Touch toggles and keyboard shortcuts")
    bind(player,"Toggle","MovementOverrides","Override movement values","Pauses automatically while TAS is recording or playing.")
    bind(player,"Slider","WalkSpeed","Walk speed",nil,{Min=1,Max=100,Step=1})
    bind(player,"Slider","JumpPower","Jump power",nil,{Min=0,Max=200,Step=1})
    button(player,"ResetMovement","Restore movement defaults",nil,"rotate-ccw",function()
        set("WalkSpeed",20); set("JumpPower",50); sync()
    end)
    bind(player,"Toggle","GodMode","Infinite air / health","Keep the character's health topped up.")
    bind(player,"Toggle","Noclip","Noclip","Move through solid map geometry.")
    bind(player,"Toggle","AirJump","Air jump","Use the jump button while airborne.")
    local swim=bind(player,"Toggle","SwimEnabled","TAS swim mode","Spoof the swimming position used by TAS.")
    if not context.swimAvailable then
        if swim.SetDisabled then swim:SetDisabled(true,"Swim hook unavailable") end
        player:Paragraph({Name="Swim unavailable",Content="This executor does not provide the required hook functions."})
    end

    local advanced=tab("advanced","Advanced","flask-conical","Capability checks and optional quickfarm features")
    advanced:Paragraph({Name="Feature availability",Content="Each integration is checked independently. Unavailable features explain why; a runtime failure switches off only the affected feature."})
    local descriptions={
        ["Fast load"]="Shorten supported loading transitions.",
        ["Forced win"]="Requires an identifiable escape lock in the game's internals.",
        ["Direct buttons"]="Use supported button and locator events.",
        ["Auto boost"]="Sends boosts each round; approximately 20 gems expected.",
        ["Smart challenges"]="Cycle challenges using description rules; about 50 coins expected.",
        ["Timed challenges"]="Cycle challenges on a timer; may spend coins.",
    }
    for _,name in ipairs({"Fast load","Forced win","Direct buttons","Auto boost","Manual boost","Smart challenges","Timed challenges"}) do
        local feature=Advanced.guard.features[name]
        if not feature then
            advanced:Paragraph({Name=name.." • unavailable",Content="The advanced module could not initialize."})
        else
            local control
            local note=advanced:Paragraph({Name=name,Content="Checking…"})
            if name=="Manual boost" then
                control=button(advanced,"ManualBoost","Request full boost","Spends approximately 20 gems.","zap",function()
                    if not feature.available then return end
                    UI.confirm(window,"Spend gems on boosts?","Four boost requests will be sent. Expected total: 20 gems.",Advanced.manualBoost)
                end)
            else
                local function enable(value)
                    Advanced.enable(name,value)
                end
                control=advanced:Toggle({Name=name,Desc=descriptions[name],Default=false,Callback=function(value)
                    if value and (name=="Auto boost" or name=="Smart challenges" or name=="Timed challenges") then
                        control:Set(false,true)
                        UI.confirm(window,"Enable "..name.."?",descriptions[name],function() enable(true) end)
                    else enable(value) end
                end})
                controls["Advanced:"..name]=control
            end
            local function changed(f)
                note:Set(f.available and (f.enabled and "Enabled" or "Available • off") or ("Disabled: "..tostring(f.reason)))
                if control.Set and name~="Manual boost" then control:Set(f.enabled,true) end
                if control.SetDisabled then control:SetDisabled(not f.available,name.." unavailable") end
            end
            feature.changed=changed
            changed(feature)
        end
    end
    bind(advanced,"Slider","ChallengeInterval","Challenge cycle interval","Applies to timed challenge cycling.",{Min=60,Max=1800,Step=60,Suffix=" s"})

    local settings=tab("settings","Settings","settings","Interface, shortcuts, and session tools")
    bind(settings,"Toggle","AlertsEnabled","Game alerts","Show messages in the game's alert feed.")
    bind(settings,"Toggle","Notifications","Airflow notifications","Show FloodGUI notification cards.")
    bind(settings,"Slider","InterfaceScale","Interface scale","Scale the main, creator, and player windows.",{Min=0.8,Max=1.25,Step=0.05,Suffix="×"})
    bind(settings,"Toggle","AntiAFK","Prevent idle disconnect","Keep the session active while idle.")
    bind(settings,"Toggle","AutoLeave","Leave when a player joins","Disconnect if another player enters the server.")
    settings:Section("Keyboard shortcuts")
    for _,item in ipairs({{"GodMode","Infinite air / health",Enum.KeyCode.R},{"Noclip","Noclip",Enum.KeyCode.G},{"AirJump","Air jump",Enum.KeyCode.M},{"SwimEnabled","TAS swim mode",Enum.KeyCode.Y}}) do
        settings:Keybind({Name=item[2],Default=item[3],Callback=function() set(item[1],not State[item[1]]); sync() end})
    end
    settings:Keybind({Name="Show / hide main UI",Default=Enum.KeyCode.J,OnChanged=function(key) window:SetKeybind(key) end})
    settings:Section("Session tools")
    button(settings,"Rejoin","Rejoin game",nil,"log-in",context.rejoin)
    button(settings,"InfiniteYield","Load Infinite Yield","Launch the external administration script.","terminal",context.infiniteYield)
    button(settings,"Hide","Hide interface","Use the floating FloodGUI button to reopen it.","eye-off",function() window:Toggle(false) end)
    local about=tab("about","About","info","FloodGUI • tomato red and black")
    about:Paragraph({Name="Credits",Content="TAS system: Tomato; original foundation: Voiz#5668.\nGUI and integration: Tomato.\nInterface: Airflow with Lucide icons and ValleySans font fallback."})
    button(about,"Support","Copy support invite",nil,"message-circle",context.copyInvite)
    about:Paragraph({Name="Recording formats",Content="New recordings: FE2T binary (.fe2tomatas).\nCompatible input: legacy JSON and experimental binary recordings.\nConversions are available in Recordings."})
    task.spawn(function()
        while not context.session.Cancelled and not window._destroyed do
            sync()
            status:Set(string.format("Farm: %s • TAS: %s • Creator: %s\nTarget: %s • Limit: %s",State.AutoFarm and "on" or "off",
                getgenv().IsTASPlaying and "playing" or State.AutoPlay and "waiting" or "off",getgenv().TAS_Active and "active" or "idle",
                State.TargetMapName~="" and State.TargetMapName or "Any eligible map",State.EnforceDifficulty and State.TargetDifficulty or "None"))
            task.wait(0.3)
        end
    end)
    return {window=window,controls=controls,tabs=tabs,sync=sync}
end
