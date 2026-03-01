local addonName, addon = ...

-- Calculate statistics from the database
function addon.CalculateStatistics()
    local stats = {
        totalPlayers = 0,
        totalEncounters = 0,
        friends = 0,
        rivals = 0,
        tagged = 0,
        topPlayers = {},
        topZones = {},
        classCounts = {},
        factionCounts = {},
        timeDistribution = { morning = 0, afternoon = 0, evening = 0, night = 0 },
        averageLevel = 0,
        oldestEncounter = nil,
        newestEncounter = nil
    }
    
    local zoneCounts = {}
    local levelSum = 0
    local levelCount = 0
    
    -- Calculate basic stats
    for fullName, data in pairs(PathCrosser_DB.players) do
        if data.encounters and #data.encounters > 0 then
            stats.totalPlayers = stats.totalPlayers + 1
            stats.totalEncounters = stats.totalEncounters + #data.encounters
            
            -- Count relations
            if data.relation == "friend" then
                stats.friends = stats.friends + 1
            elseif data.relation == "rival" then
                stats.rivals = stats.rivals + 1
            end
            
            -- Count tagged players
            if data.tags and #data.tags > 0 then
                stats.tagged = stats.tagged + 1
            end
            
            -- Class distribution
            if data.class then
                stats.classCounts[data.class] = (stats.classCounts[data.class] or 0) + 1
            end
            
            -- Faction distribution
            if data.faction then
                stats.factionCounts[data.faction] = (stats.factionCounts[data.faction] or 0) + 1
            end
            
            -- Level average
            if data.level and data.level > 0 then
                levelSum = levelSum + data.level
                levelCount = levelCount + 1
            end
            
            -- Top players by encounter count
            table.insert(stats.topPlayers, {
                name = fullName,
                class = data.class,
                count = #data.encounters
            })
            
            -- Zone analysis
            for _, enc in ipairs(data.encounters) do
                if enc.zone then
                    zoneCounts[enc.zone] = (zoneCounts[enc.zone] or 0) + 1
                end
                
                -- Track oldest and newest encounters
                if not stats.oldestEncounter or enc.timestamp < stats.oldestEncounter then
                    stats.oldestEncounter = enc.timestamp
                end
                if not stats.newestEncounter or enc.timestamp > stats.newestEncounter then
                    stats.newestEncounter = enc.timestamp
                end
                
                -- Time distribution aggregation
                local hour = tonumber(date("%H", enc.timestamp))
                if hour >= 6 and hour < 12 then
                    stats.timeDistribution.morning = stats.timeDistribution.morning + 1
                elseif hour >= 12 and hour < 18 then
                    stats.timeDistribution.afternoon = stats.timeDistribution.afternoon + 1
                elseif hour >= 18 and hour < 24 then
                    stats.timeDistribution.evening = stats.timeDistribution.evening + 1
                else
                    stats.timeDistribution.night = stats.timeDistribution.night + 1
                end
            end
        end
    end
    
    -- Calculate average level
    if levelCount > 0 then
        stats.averageLevel = math.floor(levelSum / levelCount)
    end
    
    -- Sort top players
    table.sort(stats.topPlayers, function(a, b) return a.count > b.count end)
    -- Keep only top 10
    while #stats.topPlayers > 10 do
        table.remove(stats.topPlayers)
    end
    
    -- Convert zone counts to sorted list
    for zone, count in pairs(zoneCounts) do
        table.insert(stats.topZones, {name = zone, count = count})
    end
    table.sort(stats.topZones, function(a, b) return a.count > b.count end)
    -- Keep only top 10
    while #stats.topZones > 10 do
        table.remove(stats.topZones)
    end
    
    return stats
end

-- Get encounter activity breakdown for a player
function addon.GetPlayerActivityBreakdown(playerName)
    local data = PathCrosser_DB.players[playerName]
    if not data or not data.encounters then return nil end
    
    local activities = {}
    local zones = {}
    local timeDistribution = {
        morning = 0,   -- 6-12
        afternoon = 0, -- 12-18
        evening = 0,   -- 18-24
        night = 0      -- 0-6
    }
    
    for _, enc in ipairs(data.encounters) do
        -- Activity breakdown
        activities[enc.activity] = (activities[enc.activity] or 0) + 1
        
        -- Zone distribution
        if enc.zone then
            zones[enc.zone] = (zones[enc.zone] or 0) + 1
        end
        
        -- Time distribution
        local hour = tonumber(date("%H", enc.timestamp))
        if hour >= 6 and hour < 12 then
            timeDistribution.morning = timeDistribution.morning + 1
        elseif hour >= 12 and hour < 18 then
            timeDistribution.afternoon = timeDistribution.afternoon + 1
        elseif hour >= 18 and hour < 24 then
            timeDistribution.evening = timeDistribution.evening + 1
        else
            timeDistribution.night = timeDistribution.night + 1
        end
    end
    
    return {
        activities = activities,
        zones = zones,
        timeDistribution = timeDistribution,
        totalEncounters = #data.encounters
    }
end

-- Get players encountered in a specific zone
function addon.GetPlayersInZone(zoneName)
    local players = {}
    
    for fullName, data in pairs(PathCrosser_DB.players) do
        if data.encounters then
            for _, enc in ipairs(data.encounters) do
                if enc.zone == zoneName then
                    if not players[fullName] then
                        players[fullName] = {
                            name = fullName,
                            class = data.class,
                            encounters = 0
                        }
                    end
                    players[fullName].encounters = players[fullName].encounters + 1
                    break
                end
            end
        end
    end
    
    local sorted = {}
    for _, p in pairs(players) do
        table.insert(sorted, p)
    end
    table.sort(sorted, function(a, b) return a.encounters > b.encounters end)
    
    return sorted
end


-- Find players you haven't seen in X days
function addon.GetInactivePlayers(days)
    local cutoffTime = time() - (days * 86400)
    local inactive = {}
    
    for fullName, data in pairs(PathCrosser_DB.players) do
        if data.encounters and #data.encounters > 0 then
            local lastEnc = data.encounters[#data.encounters]
            if lastEnc.timestamp < cutoffTime then
                table.insert(inactive, {
                    name = fullName,
                    class = data.class,
                    lastSeen = lastEnc.timestamp,
                    encounters = #data.encounters
                })
            end
        end
    end
    
    table.sort(inactive, function(a, b) return a.lastSeen < b.lastSeen end)
    return inactive
end

-- Find players you frequently encounter
function addon.GetFrequentEncounters(minEncounters)
    minEncounters = minEncounters or 5
    local frequent = {}
    
    for fullName, data in pairs(PathCrosser_DB.players) do
        if data.encounters and #data.encounters >= minEncounters then
            table.insert(frequent, {
                name = fullName,
                class = data.class,
                encounters = #data.encounters,
                relation = data.relation
            })
        end
    end
    
    table.sort(frequent, function(a, b) return a.encounters > b.encounters end)
    return frequent
end

-- Get recent encounters (last X hours)
function addon.GetRecentEncounters(hours)
    hours = hours or 24
    local cutoffTime = time() - (hours * 3600)
    local recent = {}
    
    for fullName, data in pairs(PathCrosser_DB.players) do
        if data.encounters then
            for _, enc in ipairs(data.encounters) do
                if enc.timestamp >= cutoffTime then
                    table.insert(recent, {
                        name = fullName,
                        class = data.class,
                        timestamp = enc.timestamp,
                        zone = enc.zone,
                        activity = enc.activity
                    })
                end
            end
        end
    end
    
    table.sort(recent, function(a, b) return a.timestamp > b.timestamp end)
    return recent
end
