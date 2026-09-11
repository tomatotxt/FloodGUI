-- These are farming heuristics from quickfarm, not claims of actual impossibility.
local patterns = {"slide under", "walljump", "zipline", "without pressing", "air bubble", "regenerate air", "vote multiple times", "exploding button"}
local Rules = {}
function Rules.evaluate(data, premium)
    assert(type(data) == "table" and type(data.standard) == "table" and type(data.master) == "table", "Challenge list schema changed")
    local function remaining(list)
        local result = {}
        for _, item in pairs(list) do
            assert(type(item) == "table" and type(item.desc) == "string" and type(item.amtCurrent) == "number" and type(item.amtRequired) == "number", "Challenge entry schema changed")
            if item.completed ~= true and item.amtCurrent < item.amtRequired then table.insert(result, item) end
        end
        return result
    end
    local standards, masters = remaining(data.standard), remaining(data.master)
    local function blocked(item)
        if item.isPremium == true and not premium then return true end
        local text = item.desc:lower()
        for _, pattern in ipairs(patterns) do if text:find(pattern, 1, true) then return true end end
        return false
    end
    local allStandards = #standards > 0
    for _, item in ipairs(standards) do if not blocked(item) then allStandards = false end end
    for _, item in ipairs(standards) do if not blocked(item) then return false end end
    for _, item in ipairs(masters) do
        if not blocked(item) and not (allStandards and item.desc:lower():find("standard challenges", 1, true)) then return false end
    end
    return #standards + #masters > 0
end
return Rules
