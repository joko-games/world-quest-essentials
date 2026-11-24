-- The test suite. Returns true when a test failed.

local Mock = dofile("tests/wow_mock.lua")

local FILES = { "Locales/frFR.lua", "Locales.lua", "Core.lua", "Quests.lua", "UI/Panel.lua" }

local tests, failures = {}, 0

local function test(name, fn)
    table.insert(tests, { name = name, fn = fn })
end

local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
    end
end

local function ids(quests)
    local result = {}
    for _, quest in ipairs(quests) do
        table.insert(result, quest.questID)
    end
    return table.concat(result, ",")
end

-- A fresh client and addon, with the Midnight continent (a seed), one of its zones,
-- and a zone found only by the scan.
local function setup()
    Mock.Reset()
    Mock.timers = {}
    Mock.printed = {}
    WorldQuestEssentialsDB = nil
    local zone = Enum.UIMapType.Zone
    local w = Mock.world
    w.maps[2537] = { name = "Quel'Thalas", mapType = Enum.UIMapType.Continent, parent = 947 }
    w.maps[2395] = { name = "Eversong Woods", mapType = zone, parent = 2537 }
    w.maps[2600] = { name = "New Zone", mapType = zone, parent = 2537 }
    w.maps[2601] = { name = "Unrelated Zone", mapType = zone, parent = 1 }
    w.maps[2602] = { name = "A Micro Map", mapType = Enum.UIMapType.Micro, parent = 2601 }
    local ns = Mock.LoadAddon(FILES)
    Mock.Fire("ADDON_LOADED", "WorldQuestEssentials")
    Mock.Fire("PLAYER_LOGIN")
    return ns, w
end

local function addQuest(w, mapID, questID, fields)
    w.onMap[mapID] = w.onMap[mapID] or {}
    table.insert(w.onMap[mapID], { questID = questID, mapID = fields.onMap or mapID })
    fields.title = fields.title or ("Quest " .. questID)
    fields.timeLeft = fields.timeLeft or 3600
    if fields.rewards == nil and not fields.noRewards then
        fields.rewards = { money = 0, items = {}, currencies = {}, reputations = {} }
    end
    w.quests[questID] = fields
end

-- Formatting ----------------------------------------------------------------

test("time left keeps the two largest units", function()
    local ns = setup()
    eq(ns.FormatTimeLeft(2 * 86400 + 4 * 3600 + 59), "2d 4h")
    eq(ns.FormatTimeLeft(3 * 3600 + 20 * 60), "3h 20m")
    eq(ns.FormatTimeLeft(45 * 60 + 30), "45m")
    eq(ns.FormatTimeLeft(20), "1m")
    eq(ns.FormatTimeLeft(0), "")
end)

test("gold and amounts are grouped by thousands", function()
    local ns = setup()
    eq(ns.FormatGold(12345678 * 10000 + 99), "12,345,678g")
    eq(ns.FormatGold(500 * 10000), "500g")
    eq(ns.FormatAmount(1250), "1,250")
end)

test("saved data gets its defaults", function()
    local ns = setup()
    eq(ns.db.sortKey, "time")
    eq(ns.db.sortAscending, true)
    eq(ns.db.category, "all")
end)

-- Maps ----------------------------------------------------------------------

test("maps come from the seeds, their zones and the scan", function()
    local ns = setup()
    local maps, trusted = ns.ResolveMaps()
    eq(table.concat(maps, ","), "2395,2537,2600,2601")
    eq(trusted[2537], true, "seed continent")
    eq(trusted[2600], true, "zone of a seed continent")
    eq(trusted[2601], nil, "zone found by the scan only")
end)

test("a seed the client does not know is skipped", function()
    local ns = setup()
    ns.ResetMaps()
    local maps = ns.ResolveMaps()
    for _, mapID in ipairs(maps) do
        if mapID == 2405 then
            error("unknown seed kept")
        end
    end
end)

-- Collecting ----------------------------------------------------------------

test("only the current expansion's open world quests are kept", function()
    local ns, w = setup()
    addQuest(w, 2395, 1, { expansion = 11 })
    addQuest(w, 2395, 2, { expansion = 11, completed = true })
    addQuest(w, 2395, 3, { expansion = 11, worldQuest = false })
    addQuest(w, 2601, 4, { expansion = 11 })              -- scanned map, current expansion
    addQuest(w, 2601, 5, { expansion = 10 })              -- scanned map, older expansion
    addQuest(w, 2601, 6, {})                              -- scanned map, expansion unknown
    addQuest(w, 2395, 7, { expansion = 11, expired = true })
    addQuest(w, 2600, 8, {})                              -- trusted map, expansion unknown
    local quests = ns.CollectQuests()
    ns.SortQuests(quests, "title", true)
    eq(ids(quests), "1,4,8")
end)

test("a quest on several maps is listed once, under its own zone", function()
    local ns, w = setup()
    addQuest(w, 2537, 1, { expansion = 11, onMap = 2395 })
    addQuest(w, 2395, 1, { expansion = 11 })
    local quests = ns.CollectQuests()
    eq(#quests, 1)
    eq(quests[1].zone, "Eversong Woods")
    eq(quests[1].expiresAt, 1000 + 3600)
end)

test("missing rewards and titles are asked for and reported as pending", function()
    local ns, w = setup()
    addQuest(w, 2395, 1, { expansion = 11, noRewards = true })
    addQuest(w, 2395, 2, { expansion = 11, title = "", timeLeft = 7200 })
    local quests, pending = ns.CollectQuests()
    eq(pending, true)
    eq(Mock.world.preloadRequests[1], 1)
    eq(Mock.world.loadRequests[1], 2)
    ns.SortQuests(quests, "time", true)
    eq(quests[1].rewards.loaded, false)
    eq(quests[2].title, "Loading")
end)

test("nothing pending once everything is there", function()
    local ns, w = setup()
    addQuest(w, 2395, 1, { expansion = 11 })
    local _, pending = ns.CollectQuests()
    eq(pending, false)
end)

-- Rewards -------------------------------------------------------------------

test("rewards are sorted by kind, and gear shows its item level", function()
    local ns, w = setup()
    w.items[100] = "INVTYPE_CHEST"
    w.factionCurrencies[3000] = 2600
    w.majorFactions[2700] = "The Singularity"
    addQuest(w, 2395, 1, { expansion = 11, rewards = {
        money = 250 * 10000,
        items = { { name = "Robe", texture = "robe", count = 1, itemID = 100, itemLevel = 720 } },
        currencies = {
            { name = "Crests", texture = "crest", currencyID = 10, totalRewardAmount = 15 },
            { name = "Rep token", texture = "rep", currencyID = 3000, baseRewardAmount = 75 },
        },
        reputations = { { factionID = 2700, rewardAmount = 150 } },
    } })
    local quest = ns.CollectQuests()[1]
    eq(quest.reward.category, "gear")
    eq(quest.reward.text, "720")
    for _, category in ipairs({ "gear", "gold", "currency", "reputation" }) do
        eq(quest.categories[category], true, category)
    end
    eq(quest.categories.items, nil, "items")
    eq(#quest.rewards.currencies, 1, "currencies")
    eq(#quest.rewards.reputations, 2, "reputations")
    eq(quest.rewards.reputations[2].name, "The Singularity")
end)

test("the main reward falls back from items to currency, gold and reputation", function()
    local ns, w = setup()
    addQuest(w, 2395, 1, { expansion = 11, rewards = { money = 0, items = {
        { name = "Ore", texture = "ore", count = 5, itemID = 200 } }, currencies = {}, reputations = {} } })
    addQuest(w, 2395, 2, { expansion = 11, timeLeft = 3601, rewards = { money = 100, items = {}, currencies = {
        { name = "A", texture = "a", currencyID = 1, totalRewardAmount = 10 },
        { name = "B", texture = "b", currencyID = 2, totalRewardAmount = 1500 } }, reputations = {} } })
    addQuest(w, 2395, 3, { expansion = 11, timeLeft = 3602, rewards = { money = 1234 * 10000, items = {}, currencies = {}, reputations = {} } })
    addQuest(w, 2395, 4, { expansion = 11, timeLeft = 3603, rewards = { money = 0, items = {}, currencies = {},
        reputations = { { factionID = 1, rewardAmount = 75 } } } })
    local quests = ns.SortQuests(ns.CollectQuests(), "time", true)
    eq(quests[1].reward.category, "items")
    eq(quests[1].reward.text, "5")
    eq(quests[2].reward.category, "currency")
    eq(quests[2].reward.text, "1,500")
    eq(quests[3].reward.text, "1,234g")
    eq(quests[4].reward.category, "reputation")
end)

-- Filtering and sorting -----------------------------------------------------

local function sample(ns, w)
    w.items[100] = "INVTYPE_HAND"
    addQuest(w, 2395, 1, { expansion = 11, title = "Bats in the Belfry", timeLeft = 500, rewards = {
        money = 0, items = { { name = "Void Gloves", texture = "g", count = 1, itemID = 100, itemLevel = 700 } },
        currencies = {}, reputations = {} } })
    addQuest(w, 2600, 2, { expansion = 11, title = "Arcane Cleanup", timeLeft = 9000, rewards = {
        money = 50 * 10000, items = {}, currencies = {}, reputations = {} } })
    addQuest(w, 2395, 3, { expansion = 11, title = "Clear the Path", timeLeft = 100, rewards = {
        money = 0, items = {}, currencies = { { name = "Valorstones", texture = "v", currencyID = 5, totalRewardAmount = 30 } },
        reputations = {} } })
    return ns.CollectQuests()
end

test("the category filter keeps the quests that give that kind", function()
    local ns, w = setup()
    local quests = sample(ns, w)
    eq(ids(ns.SortQuests(ns.FilterQuests(quests, "gear", ""), "time", true)), "1")
    eq(ids(ns.SortQuests(ns.FilterQuests(quests, "gold", ""), "time", true)), "2")
    eq(ids(ns.SortQuests(ns.FilterQuests(quests, "all", ""), "time", true)), "3,1,2")
end)

test("the search needs every word, in the title, zone or rewards", function()
    local ns, w = setup()
    local quests = sample(ns, w)
    eq(ids(ns.SortQuests(ns.FilterQuests(quests, "all", "gloves"), "time", true)), "1")
    eq(ids(ns.SortQuests(ns.FilterQuests(quests, "all", "eversong"), "time", true)), "3,1")
    eq(ids(ns.SortQuests(ns.FilterQuests(quests, "all", "EVERSONG valor"), "time", true)), "3")
    eq(ids(ns.FilterQuests(quests, "all", "nothing")), "")
end)

test("sorting by each column, both ways", function()
    local ns, w = setup()
    local quests = sample(ns, w)
    eq(ids(ns.SortQuests(quests, "time", false)), "2,1,3")
    eq(ids(ns.SortQuests(quests, "title", true)), "2,1,3")
    eq(ids(ns.SortQuests(quests, "zone", true)), "3,1,2")
    eq(ids(ns.SortQuests(quests, "reward", true)), "1,3,2")
    eq(ids(ns.SortQuests(quests, "type", true)), "1,3,2")
    eq(ids(ns.SortQuests(quests, "type", false)), "2,3,1")
end)

test("the maps command lists the maps scanned", function()
    local ns, w = setup()
    ns.quests = sample(ns, w)
    SlashCmdList.WORLDQUESTESSENTIALS("maps")
    eq(Mock.printed[2], "  2395 Eversong Woods *: 2")
end)

-- Run -----------------------------------------------------------------------

-- The mock replaces print to capture the addon's chat lines, so the results use io.write.
for _, entry in ipairs(tests) do
    local ok, message = pcall(entry.fn)
    if ok then
        io.write("ok   ", entry.name, "\n")
    else
        failures = failures + 1
        io.write("FAIL ", entry.name, "\n     ", tostring(message), "\n")
    end
end
io.write(string.format("%d tests, %d failed\n", #tests, failures))
return failures > 0
