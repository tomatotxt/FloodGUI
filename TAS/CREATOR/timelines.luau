-- Experimental creator timeline support, confined to the cloned map.
local Timelines = {}
function Timelines.bind(map, player, track, report, isActive)
    local storage = game:GetService("ReplicatedStorage")
    local modules = storage:FindFirstChild("Modules")
    local client = modules and modules:FindFirstChild("Client")
    local folder = client and client:FindFirstChild("Timelines")
    local scriptModule = folder and folder:FindFirstChild("TimelinePlayer")
    if not scriptModule then return false, "TimelinePlayer module unavailable" end
    local ok, engine = pcall(require, scriptModule)
    if not ok or type(engine) ~= "table" or type(engine.ValidateIsTimeline) ~= "function" or type(engine.PlayTimeline) ~= "function" then
        return false, "Timeline API changed"
    end
    local enabled = true
    local function failed(reason) enabled = false; report("Local timelines disabled: " .. tostring(reason)) end
    local descendants = map:GetDescendants()
    for _, object in ipairs(descendants) do
        if object:IsA("Configuration") then
            local valid, isTimeline = pcall(engine.ValidateIsTimeline, object)
            if not valid then return false, "Timeline validation failed" end
            local name = object:GetAttribute("LocalTrigger_Touch")
            if isTimeline and type(name) == "string" and name ~= "" then
                local busy = false
                local cooldown = object:GetAttribute("Touch_Debounce")
                cooldown = type(cooldown) == "number" and math.max(0.1, cooldown) or 1
                for _, part in ipairs(descendants) do
                    if part:IsA("BasePart") and part.Name == name then
                        track(part.Touched:Connect(function(hit)
                            local character = player.Character
                            if not enabled or busy or not isActive() or not character or not hit:IsDescendantOf(character) then return end
                            busy = true
                            local worked, err = pcall(engine.PlayTimeline, nil, object, player, nil, map, 1)
                            if not worked then failed(err) end
                            task.wait(cooldown)
                            busy = false
                        end))
                    end
                end
            end
        end
    end
    return true
end
return Timelines
