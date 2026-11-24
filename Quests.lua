local _, ns = ...
local L = ns.L

-- Which maps hold the current expansion's world quests -----------------------
--
-- The list does not follow the map the player looks at: it always covers the latest
-- expansion. Its maps are found in two ways, as a wrong map ID must not hide a zone:
--
-- * Seeds: the expansion's maps known when this was written. A seed the client does not
--   know is skipped; a continent brings all its zones.
-- * A scan of the map IDs the expansion added, keeping every zone. That range also holds
--   maps of the previous expansion, so a quest found only by the scan is kept only when
--   the game says it belongs to the current expansion.

-- Midnight: Quel'Thalas, Silvermoon City, Eversong Woods, Voidstorm, Harandar,
-- Isle of Quel'Danas, Zul'Aman.
ns.SEED_MAPS = { 2537, 2393, 2395, 2405, 2413, 2424, 2437 }
ns.SCAN_FIRST, ns.SCAN_LAST = 2390, 2800

local resolved

local function isMapType(info, typeName)
    return info and Enum.UIMapType and info.mapType == Enum.UIMapType[typeName]
end

-- maps: every map to ask for quests, in ID order. trusted: the maps that come from the
-- seeds, whose quests need no expansion check.
function ns.ResolveMaps()
    if resolved then
        return resolved.maps, resolved.trusted
    end
    local set, trusted = {}, {}

    for _, mapID in ipairs(ns.SEED_MAPS) do
        local info = C_Map.GetMapInfo(mapID)
        if info then
            set[mapID], trusted[mapID] = true, true
            local children = C_Map.GetMapChildrenInfo(mapID, nil, true) or {}
            for _, child in ipairs(children) do
                if isMapType(child, "Zone") then
                    set[child.mapID], trusted[child.mapID] = true, true
                end
            end
        end
    end

    for mapID = ns.SCAN_FIRST, ns.SCAN_LAST do
        if not set[mapID] and isMapType(C_Map.GetMapInfo(mapID), "Zone") then
            set[mapID] = true
        end
    end

    local maps = {}
    for mapID in pairs(set) do
        table.insert(maps, mapID)
    end
    table.sort(maps)
    resolved = { maps = maps, trusted = trusted }
    return maps, trusted
end

-- Forgets the maps found, for the tests.
function ns.ResetMaps()
    resolved = nil
end

function ns.CurrentExpansion()
    if GetServerExpansionLevel then
        return GetServerExpansionLevel()
    end
    return LE_EXPANSION_LEVEL_CURRENT
end

-- nil when the game does not say.
local function questExpansion(questID)
    if not GetQuestExpansion then
        return nil
    end
    local expansion = GetQuestExpansion(questID)
    if type(expansion) == "number" and expansion >= 0 then
        return expansion
    end
    return nil
end

function ns.PrintMaps()
    local maps, trusted = ns.ResolveMaps()
    print("|cff33ff99World Quest Essentials|r " .. L["Maps scanned:"])
    local counts = {}
    for _, quest in ipairs(ns.quests or {}) do
        counts[quest.mapID] = (counts[quest.mapID] or 0) + 1
    end
    for _, mapID in ipairs(maps) do
        local info = C_Map.GetMapInfo(mapID)
        print(string.format("  %d %s%s: %d", mapID, info and info.name or "?", trusted[mapID] and " *" or "", counts[mapID] or 0))
    end
end

-- Rewards -------------------------------------------------------------------

ns.CATEGORIES = { "all", "gear", "gold", "currency", "reputation", "items" }
ns.CATEGORY_LABELS = {
    all = "All", gear = "Gear", gold = "Gold", currency = "Currency", reputation = "Reputation", items = "Items",
}
-- The order of the main reward, which the list shows and sorts by.
local CATEGORY_RANK = { gear = 1, items = 2, currency = 3, gold = 4, reputation = 5 }

ns.GOLD_ICON = "Interface\\Icons\\INV_Misc_Coin_01"
ns.REPUTATION_ICON = "Interface\\Icons\\Achievement_Reputation_01"

local function isGear(itemID)
    if not itemID then
        return false
    end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
    return equipLoc ~= nil and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
end

local function factionName(factionID)
    if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
        local data = C_MajorFactions.GetMajorFactionData(factionID)
        if data and data.name then
            return data.name
        end
    end
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local data = C_Reputation.GetFactionDataByID(factionID)
        if data and data.name then
            return data.name
        end
    end
    return nil
end

-- What a quest gives, by kind, and whether the game had it ready. Not ready, the client
-- is asked for it, and QUEST_DATA_LOAD_RESULT tells when it comes.
function ns.ReadRewards(questID)
    local rewards = { money = 0, items = {}, currencies = {}, reputations = {}, loaded = true }
    if not HaveQuestRewardData(questID) then
        rewards.loaded = false
        C_TaskQuest.RequestPreloadRewardData(questID)
        return rewards
    end

    rewards.money = GetQuestLogRewardMoney(questID) or 0

    for index = 1, GetNumQuestLogRewards(questID) or 0 do
        local name, texture, count, quality, _, itemID, itemLevel = GetQuestLogRewardInfo(index, questID)
        if name or itemID then
            table.insert(rewards.items, {
                name = name, texture = texture, count = count or 1, quality = quality,
                itemID = itemID, itemLevel = itemLevel, gear = isGear(itemID),
            })
        end
    end

    for _, info in ipairs(C_QuestLog.GetQuestRewardCurrencies(questID) or {}) do
        local amount = info.totalRewardAmount or info.baseRewardAmount or info.quantity or 0
        local faction = C_CurrencyInfo.GetFactionGrantedByCurrency and C_CurrencyInfo.GetFactionGrantedByCurrency(info.currencyID)
        if faction then
            table.insert(rewards.reputations, { name = info.name, texture = info.texture, amount = amount })
        else
            table.insert(rewards.currencies, {
                name = info.name, texture = info.texture, amount = amount, currencyID = info.currencyID,
            })
        end
    end

    if C_QuestLog.GetQuestLogMajorFactionReputationRewards then
        for _, info in ipairs(C_QuestLog.GetQuestLogMajorFactionReputationRewards(questID) or {}) do
            table.insert(rewards.reputations, {
                name = factionName(info.factionID), texture = ns.REPUTATION_ICON, amount = info.rewardAmount or 0,
            })
        end
    end
    return rewards
end

-- The kinds of reward a quest gives, as a set of categories.
function ns.RewardCategories(rewards)
    local categories = {}
    for _, item in ipairs(rewards.items) do
        categories[item.gear and "gear" or "items"] = true
    end
    if rewards.money > 0 then
        categories.gold = true
    end
    if #rewards.currencies > 0 then
        categories.currency = true
    end
    if #rewards.reputations > 0 then
        categories.reputation = true
    end
    return categories
end

-- The reward the list shows: its category, icon, short text and a value to sort by.
function ns.MainReward(rewards)
    for _, item in ipairs(rewards.items) do
        if item.gear then
            return { category = "gear", texture = item.texture, quality = item.quality,
                text = item.itemLevel and item.itemLevel > 0 and tostring(item.itemLevel) or "", value = item.itemLevel or 0 }
        end
    end
    local item = rewards.items[1]
    if item then
        return { category = "items", texture = item.texture, quality = item.quality,
            text = item.count > 1 and tostring(item.count) or "", value = item.count }
    end
    local best
    for _, currency in ipairs(rewards.currencies) do
        if not best or currency.amount > best.amount then
            best = currency
        end
    end
    if best then
        return { category = "currency", texture = best.texture, text = ns.FormatAmount(best.amount), value = best.amount }
    end
    if rewards.money > 0 then
        return { category = "gold", texture = ns.GOLD_ICON, text = ns.FormatGold(rewards.money), value = rewards.money }
    end
    local reputation = rewards.reputations[1]
    if reputation then
        return { category = "reputation", texture = reputation.texture or ns.REPUTATION_ICON,
            text = ns.FormatAmount(reputation.amount), value = reputation.amount }
    end
    return nil
end

-- Collecting ----------------------------------------------------------------

local function questTitle(questID)
    local title = C_TaskQuest.GetQuestInfoByQuestID(questID)
    if not title or title == "" then
        title = C_QuestLog.GetTitleForQuestID(questID)
    end
    if not title or title == "" then
        C_QuestLog.RequestLoadQuestByID(questID)
        return nil
    end
    return title
end

local zoneNames = {}
local function zoneName(mapID)
    if zoneNames[mapID] == nil then
        local info = C_Map.GetMapInfo(mapID)
        zoneNames[mapID] = info and info.name or ""
    end
    return zoneNames[mapID]
end

local function buildQuest(questID, mapID, now)
    local tag = C_QuestLog.GetQuestTagInfo(questID) or {}
    local rewards = ns.ReadRewards(questID)
    local title = questTitle(questID)
    local quest = {
        questID = questID,
        mapID = mapID,
        zone = zoneName(mapID),
        title = title or L["Loading"],
        titleLoaded = title ~= nil,
        expiresAt = now + (C_TaskQuest.GetQuestTimeLeftSeconds(questID) or 0),
        quality = tag.quality,
        isElite = tag.isElite,
        tagName = tag.tagName,
        rewards = rewards,
        categories = ns.RewardCategories(rewards),
        reward = ns.MainReward(rewards),
    }

    local words = { quest.title, quest.zone, quest.tagName or "" }
    for _, list in ipairs({ rewards.items, rewards.currencies, rewards.reputations }) do
        for _, entry in ipairs(list) do
            table.insert(words, entry.name or "")
        end
    end
    quest.searchText = string.lower(table.concat(words, "\n"))
    return quest
end

-- Every world quest of the current expansion the character can do now, and whether some
-- of their data is still on its way from the server.
function ns.CollectQuests()
    local maps, trusted = ns.ResolveMaps()
    local expansion = ns.CurrentExpansion()
    local now = GetTime()
    local seen, quests, pending = {}, {}, false

    for _, mapID in ipairs(maps) do
        for _, poi in ipairs(C_TaskQuest.GetQuestsOnMap(mapID) or {}) do
            local questID = poi.questID
            local questMap = poi.mapID or mapID
            if questID and not seen[questID] then
                seen[questID] = true
                local belongs = trusted[questMap] or trusted[mapID] or questExpansion(questID) == expansion
                if belongs
                    and C_QuestLog.IsWorldQuest(questID)
                    and not C_QuestLog.IsQuestFlaggedCompleted(questID)
                    and (not C_TaskQuest.IsActive or C_TaskQuest.IsActive(questID)) then
                    local quest = buildQuest(questID, questMap, now)
                    if not quest.rewards.loaded or not quest.titleLoaded then
                        pending = true
                    end
                    table.insert(quests, quest)
                end
            end
        end
    end
    return quests, pending
end

-- Filtering and sorting -----------------------------------------------------

-- Every word of the search must appear somewhere in the quest.
function ns.MatchesSearch(quest, search)
    for word in string.gmatch(string.lower(search or ""), "%S+") do
        if not string.find(quest.searchText, word, 1, true) then
            return false
        end
    end
    return true
end

function ns.FilterQuests(quests, category, search)
    local result = {}
    for _, quest in ipairs(quests) do
        if (category == "all" or quest.categories[category]) and ns.MatchesSearch(quest, search) then
            table.insert(result, quest)
        end
    end
    return result
end

local function rewardKey(quest)
    local reward = quest.reward
    if not reward then
        return 99, 0
    end
    return CATEGORY_RANK[reward.category], reward.value
end

local COMPARE = {
    time = function(a, b)
        return a.expiresAt < b.expiresAt
    end,
    title = function(a, b)
        return a.title < b.title
    end,
    zone = function(a, b)
        return a.zone < b.zone
    end,
    -- By kind of reward only (gear first); ties go by time left.
    type = function(a, b)
        return (rewardKey(a)) < (rewardKey(b))
    end,
    -- By kind of reward, then the biggest first.
    reward = function(a, b)
        local rankA, valueA = rewardKey(a)
        local rankB, valueB = rewardKey(b)
        if rankA ~= rankB then
            return rankA < rankB
        end
        return valueA > valueB
    end,
}

local function equal(compare, a, b)
    return not compare(a, b) and not compare(b, a)
end

-- Sorts in place. Ties fall back on the time left, then the title, so the order never
-- jumps between refreshes.
function ns.SortQuests(quests, key, ascending)
    local compare = COMPARE[key] or COMPARE.time
    table.sort(quests, function(a, b)
        if not equal(compare, a, b) then
            if ascending then
                return compare(a, b)
            end
            return compare(b, a)
        end
        if a.expiresAt ~= b.expiresAt then
            return a.expiresAt < b.expiresAt
        end
        if a.title ~= b.title then
            return a.title < b.title
        end
        return a.questID < b.questID
    end)
    return quests
end
