local addonName, addon = ...

-- ==========================================
-- GUI: Enhanced Database with Tabs
-- ==========================================

local selectedPlayer = nil
local currentTab = "list"
local browserScrollStatus = {}

local function GetColoredName(fullName, classToken)
    if classToken and RAID_CLASS_COLORS[classToken] then
        local c = RAID_CLASS_COLORS[classToken]
        local hex = string.format("FF%02x%02x%02x", c.r*255, c.g*255, c.b*255)
        return "|c" .. hex .. fullName .. "|r"
    end
    return fullName
end

addon.GetColoredName = GetColoredName

-- Format time difference
local function FormatTimeDiff(seconds)
    if seconds < 60 then return "Just now" end
    if seconds < 3600 then return math.floor(seconds / 60) .. "m ago" end
    if seconds < 86400 then return math.floor(seconds / 3600) .. "h ago" end
    return math.floor(seconds / 86400) .. "d ago"
end

-- Format timestamp to date/time
local function FormatTimestamp(timestamp)
    return date("%Y-%m-%d %H:%M", timestamp)
end

local AceGUI = LibStub("AceGUI-3.0", true)

if AceGUI then
    -- Register our custom side-by-side layout (only once on load)
    AceGUI:RegisterLayout("PathCrosserSplit", function(content, children)
        if children[1] then
            local f = children[1].frame
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
            f:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
            f:SetWidth(260)
            f:Show()
        end
        if children[2] then
            local f = children[2].frame
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", content, "TOPLEFT", 270, 0)
            f:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
            f:Show()
        end
    end)

    -- Register a strict vertical layout for the Left Pane to clip the ScrollFrame correctly
    AceGUI:RegisterLayout("PathCrosserLeftPane", function(content, children)
        local yOffset = 0
        
        -- children[1] = SearchBox
        if children[1] then
            local f = children[1].frame
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
            f:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yOffset)
            f:Show()
            yOffset = yOffset - f:GetHeight() - 5
        end
        
        -- children[2] = Sort Dropdown
        if children[2] then
            local f = children[2].frame
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
            f:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yOffset)
            f:Show()
            yOffset = yOffset - f:GetHeight() - 5
        end
        
        -- children[3] = Filter Dropdown
        if children[3] then
            local f = children[3].frame
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
            f:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yOffset)
            f:Show()
            yOffset = yOffset - f:GetHeight() - 10
        end
        
        -- children[4] = ScrollFrame
        -- Crucially, pin this all the way exactly to the BOTTOM edges
        if children[4] then
            local f = children[4].frame
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
            f:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
            f:Show()
        end
    end)
end

-- Draw Split-Pane Browser Tab
local function DrawBrowser(container, searchQuery, sortBy, filterRelation)
    container:ReleaseChildren()
    
    local AceGUI = LibStub("AceGUI-3.0")
    
    -- Main horizontal split
    local splitGroup = AceGUI:Create("SimpleGroup")
    splitGroup:SetFullWidth(true)
    splitGroup:SetFullHeight(true)
    splitGroup:SetLayout("PathCrosserSplit")
    container:AddChild(splitGroup)
    
    -- Left Pane: Player List
    local leftPane = AceGUI:Create("SimpleGroup")
    leftPane:SetLayout("PathCrosserLeftPane")
    splitGroup:AddChild(leftPane)
    
    -- Right Pane: Player Details
    local rightPane = AceGUI:Create("SimpleGroup")
    rightPane:SetLayout("Fill")
    splitGroup:AddChild(rightPane)
    
    -- ================= LEFT PANE =================
    
    -- Search box
    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel("Search:")
    searchBox:SetFullWidth(true)
    searchBox:DisableButton(true)
    searchBox:SetText(searchQuery or "")
    searchBox:SetCallback("OnTextChanged", function(widget, event, text)
        DrawBrowser(container, text, sortBy, filterRelation)
    end)
    leftPane:AddChild(searchBox)
    
    -- Sort dropdown
    local sortDropdown = AceGUI:Create("Dropdown")
    sortDropdown:SetLabel("Sort by:")
    sortDropdown:SetFullWidth(true)
    sortDropdown:SetList({
        recent = "Recently Seen",
        encounters = "Most Encounters",
        alpha = "Alphabetical",
        level = "Level"
    })
    sortDropdown:SetValue(sortBy or "recent")
    sortDropdown:SetCallback("OnValueChanged", function(widget, event, key)
        DrawBrowser(container, searchQuery, key, filterRelation)
    end)
    leftPane:AddChild(sortDropdown)
    
    -- Filter Dropdown
    local relationFilter = AceGUI:Create("Dropdown")
    relationFilter:SetLabel("Filter:")
    relationFilter:SetFullWidth(true)
    relationFilter:SetList({
        all = "All Players",
        friend = "Friends",
        rival = "Rivals",
        neutral = "Neutral",
        tagged = "Tagged"
    })
    relationFilter:SetValue(filterRelation or "all")
    relationFilter:SetCallback("OnValueChanged", function(widget, event, key)
        DrawBrowser(container, searchQuery, sortBy, key)
    end)
    leftPane:AddChild(relationFilter)
    
    -- Scroll container for player list
    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("Flow")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetFullHeight(true)
    leftPane:AddChild(scrollFrame)
    
    -- Sort and filter the database
    local sortedPlayers = {}
    for name, data in pairs(PathCrosser_DB.players) do
        local matchesSearch = not searchQuery or searchQuery == "" or 
            string.find(string.lower(name), string.lower(searchQuery), 1, true)
            
        local matchesRelation = (filterRelation == "all") or
            (filterRelation == "tagged" and data.tags and #data.tags > 0) or
            (data.relation == filterRelation)
            
        if matchesSearch and matchesRelation then
            table.insert(sortedPlayers, {name = name, data = data})
        end
    end
    
    sortBy = sortBy or "recent"
    if sortBy == "recent" then
        table.sort(sortedPlayers, function(a, b)
            local aLast = #a.data.encounters > 0 and a.data.encounters[#a.data.encounters].timestamp or 0
            local bLast = #b.data.encounters > 0 and b.data.encounters[#b.data.encounters].timestamp or 0
            return aLast > bLast
        end)
    elseif sortBy == "encounters" then
        table.sort(sortedPlayers, function(a, b)
            return #a.data.encounters > #b.data.encounters
        end)
    elseif sortBy == "alpha" then
        table.sort(sortedPlayers, function(a, b) return a.name < b.name end)
    elseif sortBy == "level" then
        table.sort(sortedPlayers, function(a, b)
            return (a.data.level or 0) > (b.data.level or 0)
        end)
    end
    
    -- Draw player entries
    for _, p in ipairs(sortedPlayers) do
        local entry = AceGUI:Create("InteractiveLabel")
        
        local classColor = p.data.class and RAID_CLASS_COLORS[p.data.class] or {r=1, g=1, b=1}
        local hexColor = string.format("FF%02x%02x%02x", classColor.r*255, classColor.g*255, classColor.b*255)
        
        local encounters = #p.data.encounters
        local timeStr = "Never"
        if encounters > 0 then
            local lastEnc = p.data.encounters[encounters]
            timeStr = FormatTimeDiff(time() - lastEnc.timestamp)
        end
        
        local relIcon = ""
        if p.data.relation == "friend" then relIcon = "★ "
        elseif p.data.relation == "rival" then relIcon = "⚔ " end
        
        local tagStr = ""
        if p.data.tags and #p.data.tags > 0 then
            tagStr = " [" .. table.concat(p.data.tags, ", ") .. "]"
        end
        
        -- Highlight selected player
        local prefix = (selectedPlayer == p.name) and ">> " or ""
        
        local text = string.format("%s%s|c%s%s|r\n   %s encounters - %s%s", 
            prefix,
            relIcon,
            hexColor, 
            p.name, 
            encounters,
            timeStr,
            tagStr
        )
        
        entry:SetText(text)
        entry:SetFullWidth(true)
        entry:SetCallback("OnClick", function()
            selectedPlayer = p.name
            DrawBrowser(container, searchQuery, sortBy, filterRelation)
        end)
        
        scrollFrame:AddChild(entry)
    end
    
    if #sortedPlayers == 0 then
        local noResults = AceGUI:Create("Label")
        noResults:SetText("No players found.")
        noResults:SetFullWidth(true)
        scrollFrame:AddChild(noResults)
    end
    
    -- Now that elements are in, apply the state table so scroll value restores properly without clamping to 0
    scrollFrame:SetStatusTable(browserScrollStatus)
    
    -- ================= RIGHT PANE =================
    
    if not selectedPlayer or not PathCrosser_DB.players[selectedPlayer] then
        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetLayout("Flow")
        rightPane:AddChild(scroll)
        
        local msg = AceGUI:Create("Label")
        msg:SetText("\n\n\n\n\nSelect a player from the list to view their details.")
        msg:SetJustifyH("CENTER")
        msg:SetFullWidth(true)
        msg:SetColor(0.5, 0.5, 0.5)
        scroll:AddChild(msg)
        return
    end
    
    local data = PathCrosser_DB.players[selectedPlayer]
    local detailsScroll = AceGUI:Create("ScrollFrame")
    detailsScroll:SetLayout("Flow")
    rightPane:AddChild(detailsScroll)
    
    -- Player header
    local header = AceGUI:Create("Heading")
    header:SetText(GetColoredName(selectedPlayer, data.class))
    header:SetFullWidth(true)
    detailsScroll:AddChild(header)
    
    local infoGroup = AceGUI:Create("SimpleGroup")
    infoGroup:SetFullWidth(true)
    infoGroup:SetLayout("Flow")
    detailsScroll:AddChild(infoGroup)
    
    local infoText = string.format("Level %s %s %s", 
        data.level or "?",
        data.race or "Unknown",
        data.class or "Unknown"
    )
    if data.guild then infoText = infoText .. "\nGuild: <" .. data.guild .. ">" end
    if data.faction then infoText = infoText .. "\nFaction: " .. data.faction end
    infoText = infoText .. "\nTotal Encounters: " .. #data.encounters
    
    local infoLabel = AceGUI:Create("Label")
    infoLabel:SetText(infoText)
    infoLabel:SetFullWidth(true)
    infoGroup:AddChild(infoLabel)
    
    -- Controls Layout
    local controlsGroup = AceGUI:Create("SimpleGroup")
    controlsGroup:SetFullWidth(true)
    controlsGroup:SetLayout("Flow")
    detailsScroll:AddChild(controlsGroup)
    
    local relationDropdownRight = AceGUI:Create("Dropdown")
    relationDropdownRight:SetLabel("Relation:")
    relationDropdownRight:SetWidth(150)
    relationDropdownRight:SetList({neutral = "Neutral", friend = "Friend", rival = "Rival"})
    relationDropdownRight:SetValue(data.relation or "neutral")
    relationDropdownRight:SetCallback("OnValueChanged", function(widget, event, key)
        data.relation = key
        print("|cFF00FF00[PathCrosser]|r Relation updated for " .. selectedPlayer)
        -- Quick refresh to update icon in list
        DrawBrowser(container, searchQuery, sortBy, filterRelation)
    end)
    controlsGroup:AddChild(relationDropdownRight)
    
    local tagsEdit = AceGUI:Create("EditBox")
    tagsEdit:SetLabel("Tags (comma-separated):")
    tagsEdit:SetWidth(250)
    tagsEdit:SetText(data.tags and table.concat(data.tags, ", ") or "")
    tagsEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        local tags = {}
        for tag in string.gmatch(text, "([^,]+)") do
            tag = strtrim(tag)
            if tag ~= "" then table.insert(tags, tag) end
        end
        data.tags = tags
        print("|cFF00FF00[PathCrosser]|r Tags updated for " .. selectedPlayer)
        DrawBrowser(container, searchQuery, sortBy, filterRelation)
    end)
    controlsGroup:AddChild(tagsEdit)
    
    local notesEdit = AceGUI:Create("MultiLineEditBox")
    notesEdit:SetLabel("Notes:")
    notesEdit:SetFullWidth(true)
    notesEdit:SetNumLines(3)
    notesEdit:SetText(data.notes or "")
    notesEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        data.notes = text
        print("|cFF00FF00[PathCrosser]|r Notes saved for " .. selectedPlayer)
    end)
    detailsScroll:AddChild(notesEdit)
    
    local encountersHeader = AceGUI:Create("Heading")
    encountersHeader:SetText("Encounter History")
    encountersHeader:SetFullWidth(true)
    detailsScroll:AddChild(encountersHeader)
    
    for i = #data.encounters, 1, -1 do
        local enc = data.encounters[i]
        local activityIcon = {
            combat = "⚔", dead = "☠", ghost = "👻", afk = "💤",
            fishing = "🎣", casting = "✨", exploring = "🔍"
        }
        local icon = activityIcon[enc.activity] or "•"
        local flags = ""
        if enc.isPvP then flags = flags .. " [PvP]" end
        if enc.inCombat then flags = flags .. " [Combat]" end
        if enc.isAFK then flags = flags .. " [AFK]" end
        
        local location = enc.zone
        if enc.subzone and enc.subzone ~= "" then location = location .. " - " .. enc.subzone end
        if enc.x > 0 and enc.y > 0 then location = location .. string.format(" (%.1f, %.1f)", enc.x, enc.y) end
        
        local encLabel = AceGUI:Create("Label")
        encLabel:SetText(string.format("%s %s\n   %s | %s%s", icon, FormatTimestamp(enc.timestamp), location, enc.activity, flags))
        encLabel:SetFullWidth(true)
        detailsScroll:AddChild(encLabel)
    end
end



-- Draw Statistics Tab
local function DrawStatistics(container)
    container:ReleaseChildren()
    
    local AceGUI = LibStub("AceGUI-3.0")
    local stats = addon.CalculateStatistics()
    
    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("Flow")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetFullHeight(true)
    container:AddChild(scrollFrame)
    
    local heading = AceGUI:Create("Heading")
    heading:SetText("Database Statistics")
    heading:SetFullWidth(true)
    scrollFrame:AddChild(heading)
    
    -- General stats
    local generalText = string.format([[
Total Players Tracked: %d
Total Encounters: %d
Friends: %d
Rivals: %d
Tagged Players: %d

Most Active Zones:
]], stats.totalPlayers, stats.totalEncounters, stats.friends, stats.rivals, stats.tagged)
    
    for i, zone in ipairs(stats.topZones) do
        generalText = generalText .. string.format("%d. %s (%d encounters)\n", i, zone.name, zone.count)
    end
    
    local generalLabel = AceGUI:Create("Label")
    generalLabel:SetText(generalText)
    generalLabel:SetFullWidth(true)
    scrollFrame:AddChild(generalLabel)
    
    -- Most encountered players
    local topHeading = AceGUI:Create("Heading")
    topHeading:SetText("Most Encountered Players")
    topHeading:SetFullWidth(true)
    scrollFrame:AddChild(topHeading)
    
    for i, player in ipairs(stats.topPlayers) do
        local text = string.format("%d. %s - %d encounters",
            i,
            GetColoredName(player.name, player.class),
            player.count
        )
        local label = AceGUI:Create("Label")
        label:SetText(text)
        label:SetFullWidth(true)
        scrollFrame:AddChild(label)
    end
    
    -- Class breakdown
    local classHeading = AceGUI:Create("Heading")
    classHeading:SetText("Class Distribution")
    classHeading:SetFullWidth(true)
    scrollFrame:AddChild(classHeading)
    
    for class, count in pairs(stats.classCounts) do
        local classColor = RAID_CLASS_COLORS[class]
        local text = string.format("%s: %d players", class, count)
        local label = AceGUI:Create("Label")
        label:SetText(text)
        label:SetFullWidth(true)
        if classColor then
            label:SetColor(classColor.r, classColor.g, classColor.b)
        end
        scrollFrame:AddChild(label)
    end
    
    -- Faction breakdown
    local factionHeading = AceGUI:Create("Heading")
    factionHeading:SetText("Faction Distribution")
    factionHeading:SetFullWidth(true)
    scrollFrame:AddChild(factionHeading)
    
    for faction, count in pairs(stats.factionCounts) do
        local text = string.format("%s: %d players", faction, count)
        local label = AceGUI:Create("Label")
        label:SetText(text)
        label:SetFullWidth(true)
        if faction == "Horde" then
            label:SetColor(1, 0.2, 0.2)
        elseif faction == "Alliance" then
            label:SetColor(0.2, 0.5, 1)
        end
        scrollFrame:AddChild(label)
    end

    -- Time of Day breakdown
    local timeHeading = AceGUI:Create("Heading")
    timeHeading:SetText("Time of Day Distribution")
    timeHeading:SetFullWidth(true)
    scrollFrame:AddChild(timeHeading)
    
    local timeLabels = {
        {name = "Morning (06:00 - 12:00)", count = stats.timeDistribution.morning},
        {name = "Afternoon (12:00 - 18:00)", count = stats.timeDistribution.afternoon},
        {name = "Evening (18:00 - 00:00)", count = stats.timeDistribution.evening},
        {name = "Night (00:00 - 06:00)", count = stats.timeDistribution.night},
    }
    
    for _, t in ipairs(timeLabels) do
        local text = string.format("%s: %d encounters", t.name, t.count)
        local label = AceGUI:Create("Label")
        label:SetText(text)
        label:SetFullWidth(true)
        scrollFrame:AddChild(label)
    end
end

-- Draw Options Tab
local function DrawOptions(container)
    container:ReleaseChildren()
    
    local AceGUI = LibStub("AceGUI-3.0")
    
    local scrollFrame = AceGUI:Create("ScrollFrame")
    scrollFrame:SetLayout("Flow")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetFullHeight(true)
    container:AddChild(scrollFrame)
    
    local heading = AceGUI:Create("Heading")
    heading:SetText("PathCrosser Options")
    heading:SetFullWidth(true)
    scrollFrame:AddChild(heading)

    -- Tracking Options
    local trackGroup = AceGUI:Create("InlineGroup")
    trackGroup:SetTitle("Tracking Options")
    trackGroup:SetLayout("Flow")
    trackGroup:SetFullWidth(true)
    scrollFrame:AddChild(trackGroup)

    local function CreateSettingCheckbox(group, label, key, desc)
        local cb = AceGUI:Create("CheckBox")
        cb:SetLabel(label)
        cb:SetDescription(desc)
        cb:SetValue(PathCrosser_DB.options[key])
        cb:SetFullWidth(true)
        cb:SetCallback("OnValueChanged", function(_, _, val)
            PathCrosser_DB.options[key] = val
        end)
        group:AddChild(cb)
    end

    CreateSettingCheckbox(trackGroup, "Track players in Sanctuaries/Major Cities", "trackInCities", "When enabled, tracks players even while resting in cities")
    CreateSettingCheckbox(trackGroup, "Track nearby players (via nameplates)", "trackNearby", "Automatically tracks players with visible nameplates every 5 seconds\n(|cFFFF0000Important:|r Friendly nameplates MUST be enabled (Shift+V) for the addon to scan them)")
    CreateSettingCheckbox(trackGroup, "Track party/raid members", "trackParty", "Automatically tracks players in your group")

    -- Notifications
    local notifGroup = AceGUI:Create("InlineGroup")
    notifGroup:SetTitle("Notifications")
    notifGroup:SetLayout("Flow")
    notifGroup:SetFullWidth(true)
    scrollFrame:AddChild(notifGroup)

    CreateSettingCheckbox(notifGroup, "Notify on first-time encounters", "notifyRareEncounters", "Shows a message when you encounter a player for the first time")
    CreateSettingCheckbox(notifGroup, "Notify when friends are spotted", "notifyFriends", "Shows a message when you encounter a player marked as friend")

    -- Database Management
    local dbGroup = AceGUI:Create("InlineGroup")
    dbGroup:SetTitle("Database Management")
    dbGroup:SetLayout("Flow")
    dbGroup:SetFullWidth(true)
    scrollFrame:AddChild(dbGroup)

    local pruneBtn = AceGUI:Create("Button")
    pruneBtn:SetText("Prune Old Encounters")
    pruneBtn:SetWidth(200)
    pruneBtn:SetCallback("OnClick", function()
        addon.PruneOldEncounters()
        print("|cFF00FF00[PathCrosser]|r Database pruned!")
    end)
    dbGroup:AddChild(pruneBtn)

    local pruneDesc = AceGUI:Create("Label")
    pruneDesc:SetText(string.format("Automatically removes encounters older than %d days.", addon.PRUNE_DAYS))
    pruneDesc:SetFullWidth(true)
    dbGroup:AddChild(pruneDesc)

    local clearSpacer = AceGUI:Create("Label")
    clearSpacer:SetText(" ")
    clearSpacer:SetFullWidth(true)
    dbGroup:AddChild(clearSpacer)

    local clearBtn = AceGUI:Create("Button")
    clearBtn:SetText("Clear All Data")
    clearBtn:SetWidth(200)
    clearBtn:SetCallback("OnClick", function()
        StaticPopup_Show("PATHCROSSER_CLEAR_CONFIRM")
    end)
    dbGroup:AddChild(clearBtn)

    local clearDesc = AceGUI:Create("Label")
    clearDesc:SetText("⚠ Warning: This will permanently delete all tracked players and encounters!")
    clearDesc:SetColor(1, 0.3, 0.3)
    clearDesc:SetFullWidth(true)
    dbGroup:AddChild(clearDesc)

    -- Disclaimer
    local spacer = AceGUI:Create("Label")
    spacer:SetText("\n\nPathCrosser v0.1.1 - Enhanced Player Tracker")
    spacer:SetColor(0.5, 0.5, 0.5)
    spacer:SetFullWidth(true)
    scrollFrame:AddChild(spacer)
end

local mainFrame = nil

-- Main window
function addon.OpenDatabaseWindow()
    if mainFrame then
        mainFrame:Show()
        return
    end

    local AceGUI = LibStub("AceGUI-3.0", true)
    if not AceGUI then 
        print("|cFFFF0000[PathCrosser]|r Ace3 is missing! Please install Ace3 to use the UI.")
        return 
    end

    mainFrame = AceGUI:Create("Frame")
    mainFrame:SetTitle("PathCrosser - Player Tracker")
    
    -- When window closes, release it and clear the reference
    mainFrame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        mainFrame = nil
    end)
    
    -- Count players for status bar
    local playerCount = 0
    for _ in pairs(PathCrosser_DB.players) do playerCount = playerCount + 1 end
    mainFrame:SetStatusText(string.format("Tracking %d players", playerCount))
    
    mainFrame:SetLayout("Fill")
    mainFrame:SetWidth(800) -- Increased width for split pane
    mainFrame:SetHeight(500)

    -- Tab group
    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetLayout("Fill")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)
    
    tabGroup:SetTabs({
        {text="Browser", value="list"},
        {text="Statistics", value="stats"},
        {text="Options", value="options"}
    })
    
    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        currentTab = group
        container:ReleaseChildren()
        
        if group == "list" then
            DrawBrowser(container, "", "recent", "all")
        elseif group == "stats" then
            DrawStatistics(container)
        elseif group == "options" then
            DrawOptions(container)
        end
    end)
    
    -- Select initial tab
    tabGroup:SelectTab(currentTab)
    
    mainFrame:AddChild(tabGroup)
end

-- Slash Commands
SLASH_PATHCROSSER1 = "/pc"
SLASH_PATHCROSSER2 = "/pathcrosser"
SlashCmdList["PATHCROSSER"] = function(msg)
    msg = strlower(strtrim(msg))
    
    if msg == "help" then
        print("|cFF00FF00[PathCrosser]|r Commands:")
        print("/pc - Open main window")
        print("/pc stats - Show quick statistics")
        print("/pc prune - Manually prune old encounters")
        print("/pc help - Show this help")
    elseif msg == "stats" then
        local stats = addon.CalculateStatistics()
        print("|cFF00FF00[PathCrosser]|r Statistics:")
        print("Players: " .. stats.totalPlayers .. " | Encounters: " .. stats.totalEncounters)
        print("Friends: " .. stats.friends .. " | Rivals: " .. stats.rivals)
    elseif msg == "prune" then
        addon.PruneOldEncounters()
        print("|cFF00FF00[PathCrosser]|r Pruning complete!")
    else
        selectedPlayer = nil
        currentTab = "list"
        addon.OpenDatabaseWindow()
    end
end
