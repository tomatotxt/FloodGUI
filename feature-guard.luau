local Guard = {}
function Guard.new(notify)
    local self = {features = {}}
    function self.add(name, available, reason)
        local feature = {name = name, available = available == true, enabled = false, reason = reason}
        self.features[name] = feature
        return feature
    end
    function self.disable(name, reason)
        local feature = assert(self.features[name])
        feature.available, feature.enabled, feature.reason = false, false, tostring(reason)
        if feature.changed then pcall(feature.changed, feature) end
        pcall(notify, name .. " disabled: " .. feature.reason)
    end
    function self.enable(name, value)
        local feature = assert(self.features[name])
        feature.enabled = value == true and feature.available
        if feature.changed then pcall(feature.changed, feature) end
        return feature.enabled
    end
    function self.run(name, callback, ...)
        local feature = assert(self.features[name])
        if not feature.available then return false end
        local ok, result = pcall(callback, ...)
        if not ok then self.disable(name, result) end
        return ok, result
    end
    return self
end
return Guard
