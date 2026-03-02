local addonName, addon = ...

function addon.CreateOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "PathCrosser"
    
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("PathCrosser Options")
    
    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure how PathCrosser tracks and displays player encounters")
    
    -- Register the panel in WoW's modern settings menu
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    
    local yOffset = -60
    local function CreateCheckbox(labelText, optionKey, tooltip)
        local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
        cb.Text:SetText(labelText)
        
        if tooltip then
            cb.tooltipText = tooltip
        end
        
        cb:SetScript("OnShow", function(self)
            self:SetChecked(PathCrosser_DB.options[optionKey])
        end)
        
        cb:SetScript("OnClick", function(self)
            PathCrosser_DB.options[optionKey] = self:GetChecked()
        end)
        
        yOffset = yOffset - 30
        return cb
    end
    
    -- Tracking Options Section
    local trackingHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    trackingHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
    trackingHeader:SetText("Tracking Options")
    yOffset = yOffset - 25
    
    CreateCheckbox(
        "Track players in Sanctuaries/Major Cities",
        "trackInCities",
        "When enabled, tracks players even while resting in cities"
    )
    
    CreateCheckbox(
        "Track nearby players (via nameplates)",
        "trackNearby",
        "Automatically tracks players with visible nameplates every 5 seconds"
    )
    
    CreateCheckbox(
        "Track party/raid members",
        "trackParty",
        "Automatically tracks players in your group"
    )
    
    yOffset = yOffset - 10
    
    -- Notification Options Section
    local notifHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    notifHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
    notifHeader:SetText("Notifications")
    yOffset = yOffset - 25
    
    CreateCheckbox(
        "Notify on first-time encounters",
        "notifyRareEncounters",
        "Shows a message when you encounter a player for the first time"
    )
    
    CreateCheckbox(
        "Notify when friends are spotted",
        "notifyFriends",
        "Shows a message when you encounter a player marked as friend"
    )
    
    yOffset = yOffset - 10
    
    -- Database Management Section
    local dbHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dbHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
    dbHeader:SetText("Database Management")
    yOffset = yOffset - 25
    
    -- Prune button
    local pruneBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    pruneBtn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
    pruneBtn:SetWidth(200)
    pruneBtn:SetHeight(25)
    pruneBtn:SetText("Prune Old Encounters")
    pruneBtn:SetScript("OnClick", function()
        addon.PruneOldEncounters()
        print("|cFF00FF00[PathCrosser]|r Database pruned!")
    end)
    yOffset = yOffset - 30
    
    local pruneInfo = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    pruneInfo:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
    pruneInfo:SetText(string.format("Automatically removes encounters older than %d days", addon.PRUNE_DAYS))
    pruneInfo:SetTextColor(0.7, 0.7, 0.7)
    yOffset = yOffset - 30
    
    -- Clear database button
    local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearBtn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
    clearBtn:SetWidth(200)
    clearBtn:SetHeight(25)
    clearBtn:SetText("Clear All Data")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("PATHCROSSER_CLEAR_CONFIRM")
    end)
    yOffset = yOffset - 30
    
    local clearWarning = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    clearWarning:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
    clearWarning:SetText("⚠ Warning: This will permanently delete all tracked players and encounters!")
    clearWarning:SetTextColor(1, 0.3, 0.3)
    yOffset = yOffset - 40
    
    -- Info Section
    local infoHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    infoHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
    infoHeader:SetText("Commands")
    yOffset = yOffset - 25
    
    local commandsText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    commandsText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, yOffset)
    commandsText:SetText(
        "/pc or /pathcrosser - Open main window\n" ..
        "/pc stats - Show quick statistics\n" ..
        "/pc prune - Manually prune old encounters\n" ..
        "/pc help - Show all commands"
    )
    commandsText:SetJustifyH("LEFT")
    
    yOffset = yOffset - 80
    
    -- Version info
    local versionText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    versionText:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16)
    versionText:SetText("PathCrosser v0.1.0 - Enhanced Player Tracker")
    versionText:SetTextColor(0.5, 0.5, 0.5)
end

-- Confirmation dialog for clearing database
StaticPopupDialogs["PATHCROSSER_CLEAR_CONFIRM"] = {
    text = "Are you sure you want to clear ALL PathCrosser data?\n\nThis will delete all tracked players, encounters, notes, and tags.\n\nThis action cannot be undone!",
    button1 = "Yes, Delete Everything",
    button2 = "Cancel",
    OnAccept = function()
        PathCrosser_DB.players = {}
        print("|cFF00FF00[PathCrosser]|r All data has been cleared.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
