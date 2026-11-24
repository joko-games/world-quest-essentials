-- A small stand-in for the WoW client, enough to run the addon's logic outside the game:
-- Core.lua and Quests.lua. The panel (UI\) is checked in game.
--
-- The world is a table the tests fill: maps, the quests on each map, and what each quest
-- gives. Mock.Reset() empties it.

local Mock = {}

local world

function Mock.Reset()
    world = {
        maps = {},        -- [mapID] = { name, mapType, parent }
        onMap = {},       -- [mapID] = { { questID, mapID }, ... }
        quests = {},      -- [questID] = { title, expansion, worldQuest, completed, timeLeft, tag, rewards }
        items = {},       -- [itemID] = equipLoc
        factionCurrencies = {}, -- [currencyID] = factionID
        majorFactions = {},     -- [factionID] = name
        now = 1000,
        expansion = 11,
        preloadRequests = {},
        loadRequests = {},
    }
    Mock.world = world
end

Mock.Reset()

local function quest(questID)
    return world.quests[questID] or {}
end

-- Frames: only the event frame of Core.lua.
function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event)
        self.events[event] = true
    end
    function frame:SetScript(name, fn)
        self[name] = fn
    end
    Mock.eventFrame = frame
    return frame
end

function Mock.Fire(event, ...)
    Mock.eventFrame.OnEvent(Mock.eventFrame, event, ...)
end

Mock.timers = {}
C_Timer = {
    After = function(_, fn)
        table.insert(Mock.timers, fn)
    end,
}

function Mock.RunTimers()
    local timers = Mock.timers
    Mock.timers = {}
    for _, fn in ipairs(timers) do
        fn()
    end
end

function GetLocale()
    return Mock.locale or "enUS"
end

function GetTime()
    return world.now
end

function strtrim(text)
    return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

SlashCmdList = {}

Mock.printed = {}
function print(...)
    table.insert(Mock.printed, table.concat({ ... }, " "))
end

Enum = {
    UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 },
}

function GetServerExpansionLevel()
    return world.expansion
end

function GetQuestExpansion(questID)
    return quest(questID).expansion
end

C_Map = {
    GetMapInfo = function(mapID)
        local map = world.maps[mapID]
        if not map then
            return nil
        end
        return { mapID = mapID, name = map.name, mapType = map.mapType, parentMapID = map.parent or 0 }
    end,
    -- All descendants when allDescendants is true; the filter by type is not used.
    GetMapChildrenInfo = function(mapID, _, allDescendants)
        local result = {}
        local function add(parent)
            for id, map in pairs(world.maps) do
                if map.parent == parent then
                    table.insert(result, { mapID = id, name = map.name, mapType = map.mapType, parentMapID = parent })
                    if allDescendants then
                        add(id)
                    end
                end
            end
        end
        add(mapID)
        return result
    end,
}

C_TaskQuest = {
    GetQuestsOnMap = function(mapID)
        return world.onMap[mapID]
    end,
    GetQuestInfoByQuestID = function(questID)
        return quest(questID).title
    end,
    GetQuestTimeLeftSeconds = function(questID)
        return quest(questID).timeLeft
    end,
    IsActive = function(questID)
        return world.quests[questID] ~= nil and not quest(questID).expired
    end,
    RequestPreloadRewardData = function(questID)
        table.insert(world.preloadRequests, questID)
    end,
}

C_QuestLog = {
    IsWorldQuest = function(questID)
        return quest(questID).worldQuest ~= false
    end,
    IsQuestFlaggedCompleted = function(questID)
        return quest(questID).completed == true
    end,
    GetTitleForQuestID = function()
        return nil
    end,
    RequestLoadQuestByID = function(questID)
        table.insert(world.loadRequests, questID)
    end,
    GetQuestTagInfo = function(questID)
        return quest(questID).tag
    end,
    GetQuestRewardCurrencies = function(questID)
        local rewards = quest(questID).rewards
        return rewards and rewards.currencies or {}
    end,
    GetQuestLogMajorFactionReputationRewards = function(questID)
        local rewards = quest(questID).rewards
        return rewards and rewards.reputations or {}
    end,
}

C_Item = {
    GetItemInfoInstant = function(itemID)
        return itemID, nil, nil, world.items[itemID] or ""
    end,
}

C_CurrencyInfo = {
    GetFactionGrantedByCurrency = function(currencyID)
        return world.factionCurrencies[currencyID]
    end,
}

C_MajorFactions = {
    GetMajorFactionData = function(factionID)
        local name = world.majorFactions[factionID]
        return name and { name = name } or nil
    end,
}

C_Reputation = {
    GetFactionDataByID = function()
        return nil
    end,
}

-- A quest without a rewards table has its rewards not loaded yet.
function HaveQuestRewardData(questID)
    return quest(questID).rewards ~= nil
end

function GetQuestLogRewardMoney(questID)
    return quest(questID).rewards.money or 0
end

function GetNumQuestLogRewards(questID)
    return #(quest(questID).rewards.items or {})
end

function GetQuestLogRewardInfo(index, questID)
    local item = quest(questID).rewards.items[index]
    return item.name, item.texture, item.count, item.quality, true, item.itemID, item.itemLevel
end

-- Loads an addon file the way the client does, with the addon's name and table.
function Mock.LoadAddon(files)
    local ns = {}
    for _, path in ipairs(files) do
        local chunk = assert(loadfile(path))
        chunk("WorldQuestEssentials", ns)
    end
    return ns
end

return Mock
