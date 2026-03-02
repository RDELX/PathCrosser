local addonName, addon = ...
addon.frame = CreateFrame("Frame")
addon.PRUNE_DAYS = 90 -- Increased due to detailed history

-- Version for migration
addon.DB_VERSION = 2

addon.frame:RegisterEvent("ADDON_LOADED")
addon.frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
addon.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
addon.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
addon.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
addon.frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")



addon.frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize Database
        if not PathCrosser_DB then PathCrosser_DB = {} end
        if not PathCrosser_DB.players then PathCrosser_DB.players = {} end
        if not PathCrosser_DB.options then 
            PathCrosser_DB.options = { 
                trackInCities = false,
                trackNearby = true,
                notifyRareEncounters = true,
                notifyFriends = true,
                scanRadius = 100 -- yards
            } 
        end
        if not PathCrosser_DB.minimap then PathCrosser_DB.minimap = { hide = false } end
        if not PathCrosser_DB.version then PathCrosser_DB.version = 1 end
        
        -- Migrate old database to new format
        if PathCrosser_DB.version < addon.DB_VERSION then
            addon.MigrateDatabase()
        end
        
        -- Run Pruning
        addon.PruneOldEncounters()
        
        -- Hook Tooltip
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, addon.OnTooltipSetUnit)
        
        -- Init Options & Minimap
        if addon.CreateOptionsPanel then addon.CreateOptionsPanel() end
        if addon.InitMinimap then addon.InitMinimap() end
        
        -- Timer for sweeping nearby nameplates continuously
        C_Timer.NewTicker(2, function()
            if not PathCrosser_DB.options.trackNearby then return end
            -- Use the modern API to get all currently active nameplates
            local nameplates = C_NamePlate.GetNamePlates()
            if nameplates then
                for _, nameplate in ipairs(nameplates) do
                    local unit = nameplate.namePlateUnitToken
                    if unit and UnitIsPlayer(unit) then
                        addon.TrackPlayer(unit)
                    end
                end
            end
        end)
        

        
        print("|cFF00FF00[PathCrosser]|r Loaded! Use /pc to open database or /pc help for commands.")
        
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        addon.TrackPlayer("mouseover")
        
    elseif event == "PLAYER_TARGET_CHANGED" then
        addon.TrackPlayer("target")
        
    elseif event == "GROUP_ROSTER_UPDATE" then
        if PathCrosser_DB.options.trackParty then
            addon.TrackPartyMembers()
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- (Left for future hooks if needed)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if PathCrosser_DB.options.trackNearby then
            addon.TrackPlayer(arg1)
        end

    end
end)

-- Migrate database from old format to new
function addon.MigrateDatabase()
    print("|cFF00FF00[PathCrosser]|r Migrating database to version " .. addon.DB_VERSION .. "...")
    
    for fullName, data in pairs(PathCrosser_DB.players) do
        -- Old format: { count, lastSeen, class, level, zone }
        -- New format: { class, level, faction, race, guild, encounters = {}, notes = "", tags = {}, relation = "neutral" }
        
        if data.count and not data.encounters then
            -- This is old format, migrate it in-place
            data.level = data.level or 0
            data.encounters = {
                {
                    timestamp = data.lastSeen,
                    zone = data.zone or "Unknown",
                    subzone = "",
                    x = 0,
                    y = 0,
                    activity = "unknown",
                    inCombat = false,
                    isDead = false,
                    isMounted = false,
                    isAFK = false,
                    isPvP = false
                }
            }
            data.notes = data.notes or ""
            data.tags = data.tags or {}
            data.relation = data.relation or "neutral"
            
            -- Remove old keys
            data.count = nil
            data.lastSeen = nil
            data.zone = nil
        end
    end
    
    PathCrosser_DB.version = addon.DB_VERSION
    print("|cFF00FF00[PathCrosser]|r Migration complete!")
end

-- Prune old encounters
function addon.PruneOldEncounters()
    local currentTime = time()
    local cutoffTime = addon.PRUNE_DAYS * 86400
    local pruned = 0
    
    for fullName, data in pairs(PathCrosser_DB.players) do
        if data.encounters then
            -- Remove old encounters but keep player record if they have notes/tags
            local newEncounters = {}
            for _, enc in ipairs(data.encounters) do
                if (currentTime - enc.timestamp) <= cutoffTime then
                    table.insert(newEncounters, enc)
                end
            end
            
            data.encounters = newEncounters
            
            -- Remove player entirely if no encounters and no notes/tags
            if #data.encounters == 0 and (not data.notes or data.notes == "") and 
               (not data.tags or #data.tags == 0) and data.relation == "neutral" then
                PathCrosser_DB.players[fullName] = nil
                pruned = pruned + 1
            end
        end
    end
    
    if pruned > 0 then
        print("|cFF00FF00[PathCrosser]|r Pruned " .. pruned .. " old player records.")
    end
end
