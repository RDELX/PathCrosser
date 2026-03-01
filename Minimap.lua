local addonName, addon = ...

function addon.InitMinimap()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local icon = LibStub("LibDBIcon-1.0", true)
    
    if not LDB or not icon then 
        print("|cFFFF0000[PathCrosser]|r LibDBIcon is missing. Minimap button disabled.")
        return 
    end
    
    local minimapData = LDB:NewDataObject(addonName, {
        type = "launcher",
        text = "PathCrosser",
        -- This is a built-in WoW icon of a group/party
        icon = "Interface\\Icons\\Inv_misc_groupneedmore", 
        OnClick = function(self, button)
            if button == "LeftButton" then
                addon.OpenDatabaseWindow()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("PathCrosser", 1, 0.8, 0)
            tooltip:AddLine("Left-click to open the database.", 1, 1, 1)
        end,
    })
    
    -- Registers the button and attaches it to your DB so it remembers its position around the ring
    icon:Register(addonName, minimapData, PathCrosser_DB.minimap)
end