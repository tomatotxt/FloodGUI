-- Optional quickfarm features. No remote is fired or hook installed during probing.
return function(context)
    local Runtime, folder, env = context.runtime, context.remotes, context.environment or {}
    local guard = Runtime.run("feature-guard.luau").new(function(message) context.alert(message, "Warning") end)
    local refs = {}
    local function remote(name, class)
        local item = folder:FindFirstChild(name)
        if item and item:IsA(class or "RemoteEvent") then refs[name] = item; return true end
        return false
    end
    local function fire(name, ...)
        local item = assert(refs[name], name .. " unavailable")
        assert(item.Parent == folder and item:IsA("RemoteEvent"), name .. " changed")
        item:FireServer(...)
    end
    local passkey = remote("ReqPasskey", "RemoteFunction")
    local loaded = remote("LoadedMap")
    local survived = remote("Survived")
    local boost = remote("BoostIntensity")
    local cycle = remote("CycleNewChallenges")
    local dataRemote = remote("UpdPlayerData")
    local goals = remote("UpdGoalLocator")
    local buttons = remote("PressedMapButton")
    local hook = hookfunction or replaceclosure
    local readUpvalue = debug and debug.getupvalue or getupvalue
    local writeUpvalue = debug and debug.setupvalue or setupvalue
    local escapeLock
    -- Only a semantically named lock can be verified. Do not clear every boolean.
    if type(env.updGameState) == "function" and type(readUpvalue) == "function" and type(writeUpvalue) == "function" then
        for index = 1, 150 do
            local ok, name, value = pcall(readUpvalue, env.updGameState, index)
            if not ok or name == nil then break end
            if (name == "escapeLock" or name == "escapeLocked") and type(value) == "boolean" then
                escapeLock = {index = index, name = name}
                break
            end
        end
    end
    guard.add("Fast load", loaded and passkey and type(hook) == "function" and type(env.updGameState) == "function" and type(env.screenFade) == "function", "Requires LoadedMap, ReqPasskey and hookable game-state/fade functions")
    guard.add("Forced win", survived and passkey and escapeLock ~= nil, "Escape lock could not be identified safely; arbitrary boolean patches are unsupported")
    guard.add("Direct buttons", buttons and goals, "Requires PressedMapButton and UpdGoalLocator events")
    guard.add("Auto boost", boost, "BoostIntensity event missing")
    guard.add("Manual boost", boost, "BoostIntensity event missing")
    guard.add("Smart challenges", cycle and dataRemote, "Requires challenge cycling and player-data events")
    guard.add("Timed challenges", cycle, "CycleNewChallenges event missing")
    local self = {guard = guard}
    local originalState, originalFade
    local pending, coins, challenges, goal, button, nextButton = false, 0, nil, nil, nil, nil
    local lastCycle, lastForced, lastManualBoost = os.clock(), -math.huge, -math.huge
    local currentMap
    local function active(name) return guard.features[name].enabled and not context.session.Cancelled end
    local function key()
        assert(refs.ReqPasskey and refs.ReqPasskey.Parent == folder, "ReqPasskey changed")
        local value = refs.ReqPasskey:InvokeServer()
        assert(type(value) == "number", "Unexpected passkey response")
        return -value
    end
    function self.enable(name, value)
        if not guard.enable(name, value) then return end
        if name == "Timed challenges" then lastCycle = os.clock() end
        if name == "Fast load" and not originalState then
            guard.run(name, function()
                originalState = hook(env.updGameState, function(state, mapData, ...)
                    if active(name) and state == "loading" then
                        guard.run(name, function()
                            assert(type(mapData) == "table" and type(mapData.assetCount) == "number", "Loading payload changed")
                            mapData.assetCount = 1
                        end)
                    end
                    if originalState then return originalState(state, mapData, ...) end
                end)
                assert(type(originalState) == "function", "Hook returned no original function")
                originalFade = hook(env.screenFade, function(...)
                    if active(name) then
                        local ok = guard.run(name, function()
                            local lighting = game:GetService("Lighting")
                            for _, childName in ipairs({"Fade_Blur", "Fade_ColorCorrection"}) do
                                local effect = lighting:FindFirstChild(childName)
                                if effect then effect.Enabled = false end
                            end
                        end)
                        if ok then return end
                    end
                    if originalFade then return originalFade(...) end
                end)
                assert(type(originalFade) == "function", "Fade hook returned no original function")
            end)
        end
    end
    local function boostNow(name)
        guard.run(name, function()
            for _ = 1, 4 do fire("BoostIntensity", 5) end
            context.alert("Boost requests sent (script expects 20 gems total).", "Warning")
        end)
    end
    function self.manualBoost()
        if os.clock() - lastManualBoost < 5 then return end
        lastManualBoost = os.clock()
        boostNow("Manual boost")
    end
    function self.onMap(map)
        if currentMap == map then return end
        currentMap = map
        goal, button, nextButton = nil, nil, nil
        if active("Auto boost") then boostNow("Auto boost") end
        if active("Fast load") then guard.run("Fast load", function() fire("LoadedMap", key()) end) end
    end
    function self.forceWin()
        if not active("Forced win") or os.clock() - lastForced < 1 then return end
        lastForced = os.clock()
        guard.run("Forced win", function()
            local lockName, previous = readUpvalue(env.updGameState, escapeLock.index)
            assert(lockName == escapeLock.name and type(previous) == "boolean", "Escape lock layout changed")
            writeUpvalue(env.updGameState, escapeLock.index, false)
            local ok, err = pcall(function() fire("Survived", key(), 100) end)
            writeUpvalue(env.updGameState, escapeLock.index, previous)
            assert(ok, err)
        end)
    end
    local function resolve(value, seen, depth)
        if typeof(value) == "Instance" then return value:IsA("BasePart") and value or nil end
        if type(value) ~= "table" or depth > 8 or seen[value] then return nil end
        seen[value] = true
        for _, child in pairs(value) do
            local found = resolve(child, seen, depth + 1)
            if found then return found end
        end
    end
    function self.directTarget(map)
        if not active("Direct buttons") then return nil end
        local ok, target = guard.run("Direct buttons", function()
            for _, value in pairs({button, nextButton, goal}) do
                local part = resolve(value, {}, 0)
                if part and part:IsDescendantOf(map) then
                    local lower = part.Name:lower()
                    if not lower:find("exit", 1, true) and not lower:find("region", 1, true) then
                        fire("PressedMapButton", part)
                        return part
                    end
                end
            end
        end)
        return ok and target or nil
    end
    if goals then
        context.track(refs.UpdGoalLocator.OnClientEvent:Connect(function(p1, p2, _, p4)
            guard.run("Direct buttons", function()
                for _, value in pairs({p1, p2, p4}) do
                    assert(typeof(value) == "Instance" or type(value) == "table", "Goal payload changed")
                end
                goal, button, nextButton = p1, p2, p4
            end)
        end))
    end
    local rules = Runtime.run("challenge-rules.luau")
    if dataRemote then
        context.track(refs.UpdPlayerData.OnClientEvent:Connect(function(data)
            guard.run("Smart challenges", function()
                assert(type(data) == "table", "Player-data payload changed")
                if data.stats and data.stats.coins ~= nil then
                    assert(type(data.stats.coins) == "number", "Coin field changed")
                    coins = data.stats.coins
                end
                if data.dailyChallenges ~= nil then
                    rules.evaluate(data.dailyChallenges, false) -- Validate schema before keeping it.
                    challenges, pending = data.dailyChallenges, false
                end
            end)
        end))
    end
    function self.tick()
        if active("Smart challenges") and challenges and not pending and coins >= 50 and os.clock() - lastCycle >= 10 then
            guard.run("Smart challenges", function()
                local premium = context.player.MembershipType == Enum.MembershipType.Premium
                if rules.evaluate(challenges, premium) then
                    fire("CycleNewChallenges")
                    pending, lastCycle, coins = true, os.clock(), coins - 50
                    context.alert("Cycling challenges using quickfarm's description rules (50 coins expected).", "Warning")
                end
            end)
        end
        local interval = context.settings and context.settings.ChallengeInterval or 600
        if active("Timed challenges") and not active("Smart challenges") and os.clock() - lastCycle >= math.clamp(interval, 60, 1800) then
            guard.run("Timed challenges", function() fire("CycleNewChallenges"); lastCycle = os.clock() end)
        end
    end
    function self.cleanup()
        for name in pairs(guard.features) do guard.enable(name, false) end
        if originalFade then pcall(hook, env.screenFade, originalFade) end
        if originalState then pcall(hook, env.updGameState, originalState) end
        originalFade, originalState = nil, nil
    end
    return self
end
