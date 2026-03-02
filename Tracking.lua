local addonName, addon = ...

-- Track a player unit with full details
function addon.TrackPlayer(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    if not PathCrosser_DB.options.trackInCities and IsResting() then return end

    local name, realm = UnitName(unit)
    if not name or name == "Unknown" then return end
    if not realm or realm == "" then realm = GetRealmName() end
    local fullName = name .. "-" .. realm
    
    -- Don't track yourself
    if UnitIsUnit(unit, "player") then return end
    
    -- Gather all player information
    local _, classToken = UnitClass(unit)
    local _, raceToken = UnitRace(unit)
    local level = UnitLevel(unit)
    local faction = UnitFactionGroup(unit)
    local guildName = GetGuildInfo(unit)
    
    -- Location information
    local zone = GetZoneText()
    local subzone = GetSubZoneText()
    local mapID = C_Map.GetBestMapForUnit("player")
    local x, y = 0, 0
    
    if mapID then
        local position = C_Map.GetPlayerMapPosition(mapID, "player")
        if position then
            x = math.floor(position.x * 10000) / 100
            y = math.floor(position.y * 10000) / 100
        end
    end
    
    -- Activity detection
    local activity = addon.DetectActivity(unit)
    local inCombat = UnitAffectingCombat(unit)
    local isDead = UnitIsDead(unit) or UnitIsGhost(unit)
    local isMounted = IsMounted() -- Note: Can't detect if other player is mounted, using player as proxy
    local isAFK = UnitIsAFK(unit)
    local isPvP = UnitIsPVP(unit)
    
    -- Create encounter record
    local encounter = {
        timestamp = time(),
        zone = zone or "Unknown",
        subzone = subzone or "",
        x = x,
        y = y,
        activity = activity,
        inCombat = inCombat,
        isDead = isDead,
        isMounted = isMounted,
        isAFK = isAFK,
        isPvP = isPvP
    }
    
    -- Initialize or update player record
    if not PathCrosser_DB.players[fullName] then
        PathCrosser_DB.players[fullName] = {
            class = classToken,
            level = level > 0 and level or 0,
            faction = faction,
            race = raceToken,
            guild = guildName,
            encounters = { encounter },
            notes = "",
            tags = {},
            relation = "neutral"
        }
        
        -- Broadcast new encounter
        if addon.Sync then addon.Sync.BroadcastEncounter(fullName, encounter) end
        
        -- Notify for first encounter
        if PathCrosser_DB.options.notifyRareEncounters then
            print("|cFF00FF00[PathCrosser]|r New player tracked: " .. addon.GetColoredName(fullName, classToken))
        end
    else
        local p = PathCrosser_DB.players[fullName]
        
        -- Update static info
        p.class = classToken or p.class
        p.level = level > 0 and level or p.level
        p.faction = faction or p.faction
        p.race = raceToken or p.race
        p.guild = guildName or p.guild
        
        -- Check if we should add a new encounter (avoid spam)
        local shouldAddEncounter = true
        if #p.encounters > 0 then
            local lastEnc = p.encounters[#p.encounters]
            local timeDiff = time() - lastEnc.timestamp
            local zoneDiff = (lastEnc.zone ~= zone) or (lastEnc.subzone ~= subzone)
            
            -- Don't add if it's within 60 seconds and same zone
            if timeDiff < 60 and not zoneDiff then
                shouldAddEncounter = false
            end
        end
        
        if shouldAddEncounter then
            table.insert(p.encounters, encounter)
            
            -- Broadcast new encounter
            if addon.Sync then addon.Sync.BroadcastEncounter(fullName, encounter) end
            
            -- Notify for friend encounters
            if p.relation == "friend" and PathCrosser_DB.options.notifyFriends then
                print("|cFF00FF00[PathCrosser]|r Friend spotted: " .. addon.GetColoredName(fullName, classToken) .. " in " .. zone)
            end
        end
        
        -- Keep only last 100 encounters per player to avoid bloat
        if #p.encounters > 100 then
            table.remove(p.encounters, 1)
        end
    end
end

-- Detect what the player is doing
function addon.DetectActivity(unit)
    if UnitIsDead(unit) then return "dead" end
    if UnitIsGhost(unit) then return "ghost" end
    if UnitAffectingCombat(unit) then return "combat" end
    if UnitIsAFK(unit) then return "afk" end
    if UnitCastingInfo(unit) or UnitChannelInfo(unit) then return "casting" end
    
    -- Check for fishing
    local fishingAura = C_UnitAuras.GetPlayerAuraBySpellID(131474) -- Fishing
    if fishingAura then return "fishing" end
    
    return "exploring"
end


-- Track party/raid members
function addon.TrackPartyMembers()
    if not PathCrosser_DB.options.trackParty then return end
    
    local groupType = IsInRaid() and "raid" or "party"
    local numMembers = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
    
    for i = 1, numMembers do
        local unit = groupType .. i
        addon.TrackPlayer(unit)
    end
end

-- Enhanced tooltip
function addon.OnTooltipSetUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    if not unit or not UnitIsPlayer(unit) then return end
    
    local name, realm = UnitName(unit)
    if not realm or realm == "" then realm = GetRealmName() end
    local fullName = name .. "-" .. realm
    
    local data = PathCrosser_DB.players[fullName]
    if not data or not data.encounters or #data.encounters == 0 then return end
    
    -- Add separator
    tooltip:AddLine(" ")
    
    -- Relation indicator
    local relationColor = {neutral = {0.7, 0.7, 0.7}, friend = {0.3, 1, 0.3}, rival = {1, 0.3, 0.3}}
    local relColor = relationColor[data.relation] or relationColor.neutral
    local relText = data.relation == "friend" and "★ Friend" or data.relation == "rival" and "⚔ Rival" or nil
    
    if relText then
        tooltip:AddLine(relText, relColor[1], relColor[2], relColor[3])
    end
    
    -- Encounter count and last seen
    local encounterCount = #data.encounters
    local lastEnc = data.encounters[encounterCount]
    local timeDiff = time() - lastEnc.timestamp
    
    local seenText
    if timeDiff < 60 then
        seenText = "Just now"
    elseif timeDiff < 3600 then
        seenText = math.floor(timeDiff / 60) .. "m ago"
    elseif timeDiff < 86400 then
        seenText = math.floor(timeDiff / 3600) .. "h ago"
    else
        seenText = math.floor(timeDiff / 86400) .. "d ago"
    end
    
    tooltip:AddDoubleLine(
        "Encounters: " .. encounterCount,
        "Last: " .. seenText,
        0.5, 1, 0.5,
        0.5, 1, 0.5
    )
    
    -- Last location
    if lastEnc.zone then
        local locText = lastEnc.zone
        if lastEnc.subzone and lastEnc.subzone ~= "" then
            locText = locText .. " (" .. lastEnc.subzone .. ")"
        end
        if lastEnc.x > 0 and lastEnc.y > 0 then
            locText = locText .. string.format(" [%.1f, %.1f]", lastEnc.x, lastEnc.y)
        end
        tooltip:AddLine("Last seen: " .. locText, 0.7, 0.7, 0.7)
    end
    
    -- Guild
    if data.guild then
        tooltip:AddLine("<" .. data.guild .. ">", 0.5, 0.8, 1)
    end
    
    -- Tags
    if data.tags and #data.tags > 0 then
        local tagText = "Tags: " .. table.concat(data.tags, ", ")
        tooltip:AddLine(tagText, 1, 0.8, 0)
    end
    
    -- Notes preview
    if data.notes and data.notes ~= "" then
        local notePreview = data.notes
        if #notePreview > 50 then
            notePreview = notePreview:sub(1, 47) .. "..."
        end
        tooltip:AddLine("Note: " .. notePreview, 1, 1, 0.5)
    end
    
end
