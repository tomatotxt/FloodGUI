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

function Timeline.gameRate(stats)
    local value = type(stats) == "table" and stats.gamespeedMultiplier
    if type(value) == "number" and value == value and value > 0 and value < math.huge then
        return value
    end
    return nil
end

function Timeline.advance(elapsed, wallDelta, playbackRate, gameRate)
    return elapsed + math.max(0,wallDelta) * Timeline.speed(playbackRate) * (Timeline.gameRate({gamespeedMultiplier=gameRate}) or 1)
end

function Timeline.compatible(metadata, mapName)
    local recorded = metadata and metadata.mapName
    if type(recorded) == "string" and recorded ~= "" and recorded ~= mapName then
        return false, "Recording is for '" .. recorded .. "', not '" .. tostring(mapName) .. "'."
    end
    return true
end

function Timeline.smoothDirection(previous, target, response, dt)
    -- Lerp followed by normalization cannot escape an exact reversal.
    if previous:Dot(target) < -0.999 then return target end
    local alpha = 1 - (1 - math.clamp(response, 0.001, 1)) ^ (math.max(0, dt) * 60)
    local blended = previous:Lerp(target, alpha)
    return blended.Magnitude > 0.00001 and blended.Unit or target
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
