-- Map-selection rules adapted from reach and tashelper, isolated for testing.
local Automation = {}
local ranks = {None = 999, Easy = 1, Normal = 2, Hard = 3, Insane = 4, Crazy = 5, ["Crazy+"] = 6}
function Automation.voteCost(map, vote)
    if vote and vote.mapID == map.ID then
        return math.clamp((tonumber(map.extraVoteCost) or 0) + ((tonumber(vote.voteCount) or 1) - 1) * 10, 0, 50)
    end
    return map.locked and math.max(0, tonumber(map.unlockCost) or 0) or 0
end
function Automation.select(maps, vote, options, hasFile)
    local chosen, price, priority = nil, math.huge, math.huge
    local target = (options.TargetMapName or ""):lower():match("^%s*(.-)%s*$")
    for _, map in pairs(maps) do
        local name = tostring(map.name or ""):gsub("\160", " "):match("^%s*(.-)%s*$")
        local allowed = not options.EnforceDifficulty or (ranks[map.difficulty] or 999) <= (ranks[options.TargetDifficulty] or 999)
        if map.displayMap and allowed and (target == "" or name:lower() == target) then
            local exists = hasFile(name)
            local eligible = options.Mode == "Record" and not exists
                or options.Mode == "Play" and exists
                or options.Mode == "Farm"
            if target ~= "" then eligible = options.Mode ~= "Play" or exists end
            local candidatePriority = options.PreferMissingTAS and not exists and 0 or 1
            local cost = Automation.voteCost(map, vote)
            if eligible and (candidatePriority < priority or candidatePriority == priority and cost < price) then
                chosen, price, priority = map, cost, candidatePriority
            end
        end
    end
    return chosen, chosen and price or 0
end
return Automation
