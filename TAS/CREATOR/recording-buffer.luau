-- Savestates are consecutive recording segments, not copies of the full run.
local Buffer = {}

function Buffer.rewind(states, frames)
    -- Move the newest segment back into the editable buffer when crossing a
    -- checkpoint. Empty checkpoints must not trap rewind at the same frame.
    while #frames == 0 and #states > 1 do
        frames = table.remove(states)
    end
    if #frames > 0 then table.remove(frames) end
    while #frames == 0 and #states > 1 do
        frames = table.remove(states)
    end
    local initial = states[1]
    return frames, frames[#frames] or (initial and initial[#initial])
end

function Buffer.count(states, frames)
    local count = #frames
    for _, state in ipairs(states) do count += #state end
    return count
end

return Buffer
