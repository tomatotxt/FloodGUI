local Runtime = assert(getgenv().FloodGUIRuntime, "Start FloodGUI through loader.lua")
local UI = Runtime.run("ui/service.luau")
return function(context)
	local window = UI.window("player", "TAS Player", "FloodGUI • playback", Enum.KeyCode.F5)
	local playback = window:Tab({ Name = "Playback", Icon = "play", Desc = context.mapName })
	local options = window:Tab({ Name = "Options", Icon = "sliders-horizontal", Desc = "Live playback settings" })
	local manual = window:Tab({ Name = "Manual", Icon = "hand", Desc = "Hold controls and keyboard guide" })
	playback:Section("Playback",false)
	local status = playback:Paragraph({ Name = "Now playing", Content = context.mapName })
	local progress = playback:Progress({ Name = "Recording progress", Default = 0 })
	local pause = playback:Toggle({
		Name = "Pause playback",
		Desc = "Hold the player at this point. Live map hazards and server time continue.",
		Default = false,
		Callback = context.pause,
	})
	playback:Section("Session",true)
	playback:Button({
		Name = "Stop playback",
		Desc = "Switches off auto-play too.",
		Icon = "square",
		Callback = context.stop,
	})
	options:Section("Speed",false)
	local speed = options:Slider({
		Name = "Playback speed",
		Min = 0.1,
		Max = 20,
		Step = 0.05,
		Suffix = "×",
		Default = context.status().speed,
		Callback = context.setSpeed,
	})
	options:Button({
		Name = "Reset speed to 1×",
		Icon = "rotate-ccw",
		Callback = function()
			context.setSpeed(1)
		end,
	})
	options:Section("Swim orientation",true)
	options:Slider({
		Name = "Swim rotation response",
		Min = 0.01,
		Max = 0.1,
		Step = 0.01,
		Default = context.smoothness,
		Callback = context.setSmoothness,
	})
	options:Toggle({
		Name = "Smooth swim orientation",
		Desc = "Optional presentation aid. Off preserves the recorded orientation.",
		Default = false,
		Callback = context.setSwimSmoothing or function() end,
	})
	options:Section("Playback details",true)
	options:Paragraph({
		Name = "Map events",
		Content = "Playback follows the game's numeric speed when available. Live map and server state are not rewound; use a recording made for the same layout.",
	})
	manual:Section("Hold controls",false)
	local _, releaseZipline = UI.hold(
		manual,
		"Hold zipline / swing",
		"Release to return to recorded motion.",
		function()
			context.zipline(true)
		end,
		function()
			context.zipline(false)
		end,
		context.track
	)
	local _, releaseSlide = UI.hold(manual, "Hold slide", "Release to return to recorded motion.", function()
		context.slide(true)
	end, function()
		context.slide(false)
	end, context.track)
	manual:Section("Keyboard guide",true)
	manual:Paragraph({
		Name = "Keyboard controls",
		Content = "P: pause / resume\nUp / Down: adjust speed\nHold Z: zipline / swing\nHold S: slide\nF5: show / hide player",
	})
	local closed = false
	local function destroy()
		if closed then
			return
		end
		closed = true
		releaseZipline()
		releaseSlide()
		window:Destroy()
	end
	task.spawn(function()
		while not closed and not window._destroyed do
			local state = context.status()
			if state.finished then
				break
			end
			progress:Set(math.clamp(state.elapsed / math.max(state.duration, 0.001), 0, 1))
			pause:Set(state.pausePending or state.paused, true)
			speed:Set(state.speed, true)
			status:Set(
				string.format(
					"%s\n%.2f / %.2f s • %.2f× effective speed\n%s",
					context.mapName,
					state.elapsed,
					state.duration,
					state.effectiveSpeed,
					state.pausePending and "Waiting to land…" or state.paused and "Paused" or "Playing"
				)
			)
			task.wait(0.2)
		end
	end)
	return { Destroy = destroy, Window = window }
end
