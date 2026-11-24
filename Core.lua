local addonName, ns = ...
local L = ns.L

-- Global handle for inspecting data in game, e.g. /dump WorldQuestEssentials.quests[1]
WorldQuestEssentials = ns

ns.addonName = addonName

-- Game events ---------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

function ns.OnEvent(event, handler)
    local handlers = eventHandlers[event]
    if not handlers then
        handlers = {}
        eventHandlers[event] = handlers
        eventFrame:RegisterEvent(event)
    end
    table.insert(handlers, handler)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, handler in ipairs(eventHandlers[event]) do
        handler(...)
    end
end)

local debounced = {}

-- Runs fn once after delay, however many times it is requested in between.
function ns.Debounce(key, delay, fn)
    if debounced[key] then
        return
    end
    debounced[key] = true
    C_Timer.After(delay, function()
        debounced[key] = nil
        fn()
    end)
end

-- Saved data ----------------------------------------------------------------

local DEFAULTS = {
    sortKey = "time",   -- "time", "title", "zone", "type" or "reward"
    sortAscending = true,
    category = "all",   -- see ns.CATEGORIES
}

function ns.LoadSavedData()
    if type(WorldQuestEssentialsDB) ~= "table" then
        WorldQuestEssentialsDB = {}
    end
    local db = WorldQuestEssentialsDB
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end
    ns.db = db
end

ns.OnEvent("ADDON_LOADED", function(name)
    if name == addonName then
        ns.LoadSavedData()
    end
end)

-- Formatting ----------------------------------------------------------------

-- "2d 4h", "3h 20m", "45m": the two largest units are enough to compare.
function ns.FormatTimeLeft(seconds)
    if not seconds or seconds <= 0 then
        return ""
    end
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    local days = math.floor(hours / 24)
    if days > 0 then
        return string.format("%dd %dh", days, hours % 24)
    elseif hours > 0 then
        return string.format("%dh %02dm", hours, minutes % 60)
    end
    return string.format("%dm", math.max(minutes, 1))
end

-- Red under an hour, orange under four, white otherwise.
function ns.TimeLeftColor(seconds)
    if seconds and seconds < 3600 then
        return 1, 0.25, 0.25
    elseif seconds and seconds < 4 * 3600 then
        return 1, 0.6, 0.1
    end
    return 0.9, 0.9, 0.9
end

-- Whole gold, with thousands separated: rewards are never worth counting the silver.
function ns.FormatGold(copper)
    local gold = math.floor((copper or 0) / 10000)
    local text = tostring(gold)
    local formatted
    repeat
        text, formatted = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
    until formatted == 0
    return text .. "g"
end

-- "1,250" for big currency amounts, as the game shows them.
function ns.FormatAmount(amount)
    local text = tostring(amount or 0)
    local formatted
    repeat
        text, formatted = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
    until formatted == 0
    return text
end

-- Command -------------------------------------------------------------------

SLASH_WORLDQUESTESSENTIALS1 = "/wqe"
SLASH_WORLDQUESTESSENTIALS2 = "/worldquestessentials"
SlashCmdList.WORLDQUESTESSENTIALS = function(input)
    local command = string.lower(strtrim(input or ""))
    if command == "maps" then
        ns.PrintMaps()
    else
        print("|cff33ff99World Quest Essentials|r " .. L["Commands: /wqe maps (the maps scanned)."])
    end
end
