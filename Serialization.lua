local addonName, addon = ...

-- ==========================================
-- Serialization: Compact Data Export/Import
-- ==========================================

addon.Serialization = {}

-- Bitmask helpers for encounter flags
local function EncodeFlags(enc)
    local flags = 0
    if enc.inCombat then flags = flags + 1 end
    if enc.isDead then flags = flags + 2 end
    if enc.isMounted then flags = flags + 4 end
    if enc.isAFK then flags = flags + 8 end
    if enc.isPvP then flags = flags + 16 end
    return flags
end

local function DecodeFlags(flags, enc)
    flags = tonumber(flags) or 0
    enc.inCombat = bit.band(flags, 1) > 0
    enc.isDead = bit.band(flags, 2) > 0
    enc.isMounted = bit.band(flags, 4) > 0
    enc.isAFK = bit.band(flags, 8) > 0
    enc.isPvP = bit.band(flags, 16) > 0
end

local function EscapeStr(str)
    if not str then return "" end
    str = tostring(str)
    str = string.gsub(str, "~", "~~")
    str = string.gsub(str, "\n", "\\n")
    return str
end

local function UnescapeStr(str)
    if not str or str == "" then return nil end
    str = string.gsub(str, "\\n", "\n")
    str = string.gsub(str, "~~", "~")
    return str
end

-- Export single encounter for Sync
function addon.Serialization.SerializeEncounter(name, enc)
    -- S~Name~class~level~ts~zone~subzone~x~y~activity~flags
    return string.format("S~%s~%s~%s~%s~%s~%s~%s~%s~%s~%s",
        name,
        EscapeStr(PathCrosser_DB.players[name].class),
        tostring(PathCrosser_DB.players[name].level or 0),
        tostring(enc.timestamp),
        EscapeStr(enc.zone),
        EscapeStr(enc.subzone),
        tostring(enc.x),
        tostring(enc.y),
        EscapeStr(enc.activity),
        tostring(EncodeFlags(enc))
    )
end

function addon.Serialization.DeserializeEncounter(str)
    local p1, name, class, level, ts, zone, subzone, x, y, activity, flags = strsplit("~", str)
    if p1 == "S" and name and ts then
        local enc = {
            timestamp = tonumber(ts) or time(),
            zone = UnescapeStr(zone) or "Unknown",
            subzone = UnescapeStr(subzone) or "",
            x = tonumber(x) or 0,
            y = tonumber(y) or 0,
            activity = UnescapeStr(activity) or "unknown"
        }
        DecodeFlags(flags, enc)
        return name, UnescapeStr(class), tonumber(level), enc
    end
    return nil
end
