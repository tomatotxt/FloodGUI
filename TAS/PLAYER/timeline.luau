-- Pure timeline operations shared by the live player and creator preview.
local Timeline = {}

function Timeline.sample(frames, elapsed, cursor)
    local count = #frames
    if count == 0 then return nil, nil, 0, 0, true end
    cursor = math.clamp(cursor or 1, 1, count)
    -- Rewinding or changing the source can invalidate a previously cached cursor.
    while cursor > 1 and frames[cursor].time > elapsed do cursor -= 1 end
    while cursor < count and frames[cursor + 1].time <= elapsed do cursor += 1 end
    local first = frames[cursor]
    local second = frames[math.min(cursor + 1, count)]
    local duration = second.time - first.time
    local alpha = duration > 0 and math.clamp((elapsed - first.time) / duration, 0, 1) or 0
    return first, second, alpha, cursor, elapsed >= frames[count].time
end

function Timeline.speed(value, fallback)
    if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
        return fallback or 1
    end
    return math.clamp(value, 0.1, 20)
end

function Timeline.eventModifier(text)
    local modifier = 1
    -- Rich-text and plain-text HUDs are both supported. Clearing the HUD resets
    -- the modifier instead of retaining the previous round's speed event.
    text = tostring(text or ""):lower():gsub("<[^>]*>", " ")
    text = text:gsub("speed%s+up", "speedup"):gsub("slow%s+down", "slowdown")
    for event in text:gmatch("[%a]+") do
        if event == "speedup" then modifier *= 1 / 1.1225
        elseif event == "slowdown" then modifier *= 1 / (1 - 0.1091) end
    end
    return modifier
end

return Timeline
