-- Map-selection rules, voting strategies, and ballot inspection isolated for testing.
local Automation = {}
local ranks = {
	None = 999,
	Easy = 1,
	Normal = 2,
	Hard = 3,
	Insane = 4,
	Crazy = 5,
	["Crazy+"] = 6,
}

Automation.STRATEGIES = {
	"Lowest cost",
	"Easiest",
	"Hardest",
	"Most popular",
	"Underdog",
	"Highlight / Community",
	"Random",
}

local function cleanMapName(raw)
	return tostring(raw or ""):gsub("\160", " "):match("^%s*(.-)%s*$")
end

function Automation.voteCost(map, vote)
	if vote and vote.mapID == map.ID then
		return math.clamp((tonumber(map.extraVoteCost) or 0) + ((tonumber(vote.voteCount) or 1) - 1) * 10, 0, 50)
	end
	return map.locked and math.max(0, tonumber(map.unlockCost) or 0) or 0
end

function Automation.tallyVotes(allVotes)
	local totals = {}
	for _, entry in pairs(allVotes or {}) do
		if type(entry) == "table" and entry.mapID ~= nil then
			local count = math.max(1, tonumber(entry.voteCount) or 1)
			totals[entry.mapID] = (totals[entry.mapID] or 0) + count
		end
	end
	return totals
end

function Automation.describeBallot(maps, myVote, allVotes)
	local totals = Automation.tallyVotes(allVotes)
	local items = {}
	for _, map in pairs(maps or {}) do
		if type(map) == "table" and map.displayMap then
			local name = cleanMapName(map.name)
			table.insert(items, {
				id = map.ID,
				name = name ~= "" and name or tostring(map.ID or "Unknown"),
				difficulty = tostring(map.difficulty or "?"),
				cost = Automation.voteCost(map, myVote),
				votes = totals[map.ID] or 0,
				locked = map.locked == true,
				cooldown = map.cooldown == true,
			})
		end
	end
	table.sort(items, function(a, b)
		local ra, rb = ranks[a.difficulty] or 99, ranks[b.difficulty] or 99
		if ra ~= rb then
			return ra < rb
		end
		return a.name < b.name
	end)
	local parts = {}
	for _, item in ipairs(items) do
		local flags = {}
		if item.votes > 0 then
			table.insert(flags, tostring(item.votes) .. "v")
		end
		if item.cost > 0 then
			table.insert(flags, tostring(item.cost) .. "c")
		end
		if item.cooldown then
			table.insert(flags, "CD")
		end
		local suffix = #flags > 0 and (" (" .. table.concat(flags, ", ") .. ")") or ""
		table.insert(parts, string.format("%s [%s]%s", item.name, item.difficulty, suffix))
	end
	return items, table.concat(parts, ", ")
end

function Automation.select(maps, vote, options, hasFile, allVotes)
	options = options or {}
	local target = cleanMapName(options.TargetMapName):lower()
	local strategy = options.VoteStrategy or "Lowest cost"
	local mode = options.Mode or "Farm"
	local minRank = (options.MinDifficulty and options.MinDifficulty ~= "None" and ranks[options.MinDifficulty]) or 0
	local maxRank = ranks[options.TargetDifficulty] or 999
	local maxCost = (options.AllowPaidVotes == false) and 0 or (tonumber(options.MaxVoteCost) or math.huge)
	local totals = Automation.tallyVotes(allVotes)
	local highlightSet = {}
	for _, name in ipairs(options.HighlightMaps or {}) do
		highlightSet[cleanMapName(name):lower()] = true
	end

	local candidates = {}
	for _, map in pairs(maps or {}) do
		local name = cleanMapName(map.name)
		local lowerName = name:lower()
		local mapRank = ranks[map.difficulty] or 999
		local maxAllowed = not options.EnforceDifficulty or mapRank <= maxRank
		local minAllowed = minRank == 0 or (ranks[map.difficulty] ~= nil and mapRank >= minRank)
		local alreadyVoted = vote and vote.mapID == map.ID
		local matchTier = nil
		if target == "" then
			matchTier = 0
		elseif lowerName == target then
			matchTier = 0
		elseif options.PartialMapMatch and lowerName:find(target, 1, true) ~= nil then
			matchTier = 1
		end

		if map.displayMap and maxAllowed and minAllowed and (not map.cooldown or alreadyVoted) and matchTier ~= nil then
			local cost = Automation.voteCost(map, vote)
			if cost <= maxCost then
				local exists = hasFile and hasFile(name) or false
				local eligible = (mode == "Record" and not exists)
					or (mode == "Play" and exists)
					or (mode == "Farm" or mode == "Manual")
				if target ~= "" then
					eligible = mode ~= "Play" or exists
				end
				if options.RequireTASFile and not exists then
					eligible = false
				end
				if eligible then
					local tasPriority = (options.PreferMissingTAS and not exists) and 0 or 1
					local isHighlight = (map.highlight == true or highlightSet[lowerName] == true) and 0 or 1
					table.insert(candidates, {
						map = map,
						name = name,
						cost = cost,
						matchTier = matchTier,
						tasPriority = tasPriority,
						diffRank = ranks[map.difficulty] or 99,
						diffScoreDesc = -(ranks[map.difficulty] or 0),
						votes = totals[map.ID] or 0,
						isHighlight = isHighlight,
					})
				end
			end
		end
	end

	if #candidates == 0 then
		return nil, 0
	end

	if strategy == "Random" then
		table.sort(candidates, function(a, b)
			if a.matchTier ~= b.matchTier then
				return a.matchTier < b.matchTier
			end
			if a.tasPriority ~= b.tasPriority then
				return a.tasPriority < b.tasPriority
			end
			return tostring(a.name) < tostring(b.name)
		end)
		local bestMatch = candidates[1].matchTier
		local bestTas = candidates[1].tasPriority
		local pool = {}
		for _, c in ipairs(candidates) do
			if c.matchTier == bestMatch and c.tasPriority == bestTas then
				table.insert(pool, c)
			end
		end
		local rng = options.Random or math.random
		local pick = pool[math.clamp(rng(#pool), 1, #pool)]
		return pick.map, pick.cost
	end

	local function better(a, b)
		if a.matchTier ~= b.matchTier then
			return a.matchTier < b.matchTier
		end
		if a.tasPriority ~= b.tasPriority then
			return a.tasPriority < b.tasPriority
		end
		if strategy == "Easiest" and a.diffRank ~= b.diffRank then
			return a.diffRank < b.diffRank
		elseif strategy == "Hardest" and a.diffScoreDesc ~= b.diffScoreDesc then
			return a.diffScoreDesc < b.diffScoreDesc
		elseif strategy == "Most popular" and a.votes ~= b.votes then
			return a.votes > b.votes
		elseif strategy == "Underdog" and a.votes ~= b.votes then
			return a.votes < b.votes
		elseif strategy == "Highlight / Community" and a.isHighlight ~= b.isHighlight then
			return a.isHighlight < b.isHighlight
		end
		if a.cost ~= b.cost then
			return a.cost < b.cost
		end
		return false
	end

	local best = candidates[1]
	for i = 2, #candidates do
		if better(candidates[i], best) then
			best = candidates[i]
		end
	end
	return best.map, best.cost
end

return Automation
