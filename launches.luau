-- Tokens outlive Stop: a suspended download cannot acquire a later session.
return function(session)
    local generations = {player=0, creator=0}
    local tokens = {}
    local api = {}
    function api.cancel(kind)
        local disposing={}
        for key in pairs(generations) do
            if not kind or key==kind then
                generations[key]+=1
                local token=tokens[key]
                tokens[key]=nil
                if token then table.insert(disposing,token) end
            end
        end
        for _,token in ipairs(disposing) do
            local resources=token.resources
            token.resources={}
            for i=#resources,1,-1 do pcall(resources[i]) end
        end
    end
    function api.begin(kind)
        assert(generations[kind] ~= nil, "Unknown engine")
        api.cancel()
        local generation = generations[kind]
        local token={resources={}}
        tokens[kind]=token
        local function isCurrent()
            return not session.Cancelled and generations[kind] == generation
        end
        local function own(dispose)
            if dispose==nil then table.clear(token.resources);return end
            assert(type(dispose)=="function","Expected a resource disposer")
            if not isCurrent() then pcall(dispose);return end
            table.insert(token.resources,dispose)
        end
        return isCurrent,own
    end
    return api
end
