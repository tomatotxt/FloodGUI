-- Restore only properties still holding our last applied value. A game-side
-- change takes precedence; cleanup must not overwrite it with an old snapshot.
return function()
	local owned = setmetatable({}, { __mode = "k" })
	local api = {}
	function api.set(object, property, value)
		if object[property] == value then
			return
		end
		local fields = owned[object]
		if not fields then
			fields = {}
			owned[object] = fields
		end
		if not fields[property] then
			fields[property] = { original = object[property] }
		end
		object[property] = value
		fields[property].last = value
	end
	function api.restore(object, property)
		local fields = owned[object]
		local snapshot = fields and fields[property]
		if not snapshot then
			return false
		end
		fields[property] = nil
		local ok = pcall(function()
			if object[property] == snapshot.last then
				object[property] = snapshot.original
			end
		end)
		return ok
	end
	function api.restoreAll()
		for object, fields in pairs(owned) do
			local hadHealth = fields.MaxHealth ~= nil
			for property in pairs(fields) do
				api.restore(object, property)
			end
			if hadHealth then
				pcall(function()
					object.Health = math.min(object.Health, object.MaxHealth)
				end)
			end
		end
		table.clear(owned)
	end
	return api
end
