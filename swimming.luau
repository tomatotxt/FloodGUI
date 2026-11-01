-- Scoped overrides of FE2's native swimming query; never spoofs Instance properties.
return function(player, heartbeat)
    local api, leases = {}, {}
    local attached, original, wrapper
    local destroyed=false
    local function readCallback(target)
        if type(getcallbackvalue)=="function" then
            local ok,value=pcall(getcallbackvalue,target,"OnInvoke")
            if ok and type(value)=="function" then return value end
        end
        local ok,value=pcall(function()return target.OnInvoke end)
        if ok and type(value)=="function" then return value end
    end
    local function query()
        local scripts=player:FindFirstChild("PlayerScripts")
        local main=scripts and scripts:FindFirstChild("CL_MAIN_GameScript")
        local target=main and main:FindFirstChild("isSwimming")
        return target and target:IsA("BindableFunction") and target or nil
    end
    local function desired()
        for i=#leases,1,-1 do
            local lease=leases[i]
            if not lease.released then
                local ok,value=pcall(lease.predicate)
                if ok and type(value)=="boolean" then return value end
            end
        end
    end
    local function detach()
        if attached and readCallback(attached)==wrapper then
            pcall(function()attached.OnInvoke=original end)
        end
        attached,original,wrapper=nil,nil,nil
    end
    function api.available()
        if destroyed then return false end
        local target=query()
        return target~=nil and readCallback(target)~=nil
    end
    function api.step()
        if destroyed then return end
        local target=query()
        if attached and (target~=attached or readCallback(attached)~=wrapper)then detach()end
        if desired()==nil then detach();return end
        if attached or not target then return end
        local callback=readCallback(target)
        if not callback then return end
        local replacement=function(...)
            local value
            if not destroyed then value=desired()end
            if value~=nil then return value end
            return callback(...)
        end
        local ok=pcall(function()target.OnInvoke=replacement end)
        if ok then attached,original,wrapper=target,callback,replacement end
    end
    function api.override(predicate)
        assert(type(predicate)=="function","Expected a swimming predicate")
        if destroyed then return function()end end
        local lease={predicate=predicate}
        table.insert(leases,lease)
        api.step()
        return function()
            if lease.released then return end
            lease.released=true
            local index=table.find(leases,lease)
            if index then table.remove(leases,index)end
            api.step()
        end
    end
    local connection=heartbeat:Connect(api.step)
    function api.destroy()
        if destroyed then return end
        destroyed=true
        connection:Disconnect()
        table.clear(leases)
        detach()
    end
    return api
end
