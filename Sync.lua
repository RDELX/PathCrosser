local addonName, addon = ...

-- ==========================================
-- Sync: Data Sharing between players
-- ==========================================

addon.Sync = CreateFrame("Frame")
local PREFIX = "PCross"

-- Register Addon Message prefix
addon.Sync:RegisterEvent("PLAYER_LOGIN")
addon.Sync:RegisterEvent("CHAT_MSG_ADDON")

addon.Sync:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == PREFIX and sender ~= UnitName("player") .. "-" .. GetRealmName() then
            addon.Sync.OnMessageReceived(message, sender, channel)
        end
    end
end)

local broadcastDebounce = {}

-- Broadcast a new encounter
function addon.Sync.BroadcastEncounter(playerName, encounter)
    local now = time()
    if broadcastDebounce[playerName] and (now - broadcastDebounce[playerName] < 60) then
        return
    end
    broadcastDebounce[playerName] = now

    -- Ensure we have the serialization module
    if not addon.Serialization then return end
    
    local dataStr = addon.Serialization.SerializeEncounter(playerName, encounter)
    if not dataStr then return end
    
    -- Send to Party or Raid if in one
    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        C_ChatInfo.SendAddonMessage(PREFIX, dataStr, channel)
    end
    
    -- Send to Guild if in one
    if IsInGuild() then
        C_ChatInfo.SendAddonMessage(PREFIX, dataStr, "GUILD")
    end
end

-- Handle incoming sync message
function addon.Sync.OnMessageReceived(message, sender, channel)
    -- Ensure we have the serialization module
    if not addon.Serialization then return end
    
    local playerName, class, level, encounter = addon.Serialization.DeserializeEncounter(message)
    if playerName and encounter then
        -- Initialize player if missing
        if not PathCrosser_DB.players[playerName] then
            PathCrosser_DB.players[playerName] = {
                class = class,
                level = level,
                encounters = {},
                tags = {},
                relation = "neutral"
            }
        end
        
        local p = PathCrosser_DB.players[playerName]
        
        -- Check if it's a duplicate
        local isDuplicate = false
        for _, existing in ipairs(p.encounters) do
            if existing.timestamp == encounter.timestamp then
                isDuplicate = true
                break
            end
        end
        
        if not isDuplicate then
            table.insert(p.encounters, encounter)
            
            -- Keep only last 100 encounters
            if #p.encounters > 100 then
                table.sort(p.encounters, function(a, b) return a.timestamp < b.timestamp end)
                while #p.encounters > 100 do
                    table.remove(p.encounters, 1)
                end
            end
        end
    end
end
