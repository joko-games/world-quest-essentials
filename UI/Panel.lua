local _, ns = ...
local L = ns.L

-- The panel beside the world map ---------------------------------------------
--
-- It is a child of the world map, so it shows and hides with it, whatever map is open
-- and whatever its size. It sits to the left of the map when the screen has room, and
-- over the map's top left corner otherwise (a maximized map, or a map at the screen's
-- left edge). It is as tall as its lines need, up to the map's height, and half
-- see-through.

local WIDTH = 350
local ROW_HEIGHT = 15
local PADDING = 6
local TYPE_WIDTH = 52
local VALUE_WIDTH = 50
local ZONE_WIDTH = 66
local TIME_WIDTH = 40
local GAP = 4
local TOP_HEIGHT = 80          -- title, search, filters and column headers
local MIN_ROWS = 3             -- room for the "no quest" message

-- Each kind of reward has its own colour in the Type column.
local TYPE_COLORS = {
    gear = { 0.70, 0.40, 1.00 },
    items = { 0.20, 0.90, 0.20 },
    currency = { 0.35, 0.75, 1.00 },
    gold = { 1.00, 0.82, 0.00 },
    reputation = { 1.00, 0.50, 0.30 },
}
-- Short, to fit the column; a translation gives its own in ns.TypeLabels.
local TYPE_LABELS = {
    gear = "Gear", items = "Item", currency = "Currency", gold = "Gold", reputation = "Rep.",
}

local panel, scrollBox, titleText, emptyText, searchBox
local chips, headers = {}, {}
local inside = false
local dirty = true
local retries = 0

local function qualityColor(quality)
    local colors = WORLD_QUEST_QUALITY_COLORS and WORLD_QUEST_QUALITY_COLORS[quality]
    if colors and colors.color then
        return colors.color:GetRGB()
    end
    return 1, 0.82, 0
end

-- Tooltip: the rewards ------------------------------------------------------

local function addRewardLines(tooltip, rewards)
    if rewards.money > 0 then
        tooltip:AddLine(GetMoneyString and GetMoneyString(rewards.money) or ns.FormatGold(rewards.money), 1, 1, 1)
    end
    for _, item in ipairs(rewards.items) do
        local text = (item.count > 1 and (item.count .. " x ") or "") .. (item.name or "")
        if item.gear and item.itemLevel and item.itemLevel > 0 then
            text = text .. " (" .. item.itemLevel .. ")"
        end
        tooltip:AddLine("|T" .. (item.texture or "") .. ":0|t " .. text, 1, 1, 1)
    end
    for _, list in ipairs({ rewards.currencies, rewards.reputations }) do
        for _, entry in ipairs(list) do
            tooltip:AddLine("|T" .. (entry.texture or "") .. ":0|t " .. ns.FormatAmount(entry.amount) .. " " .. (entry.name or ""), 1, 1, 1)
        end
    end
end

local function showTooltip(row)
    local quest = row.quest
    if not quest then
        return
    end
    local tooltip = GameTooltip
    tooltip:SetOwner(row, inside and "ANCHOR_RIGHT" or "ANCHOR_LEFT")
    tooltip:SetText(quest.title, qualityColor(quest.quality))
    local remaining = quest.expiresAt - GetTime()
    tooltip:AddLine(quest.zone .. "  ·  " .. ns.FormatTimeLeft(remaining), 0.7, 0.7, 0.7)

    if not HaveQuestRewardData(quest.questID) then
        C_TaskQuest.RequestPreloadRewardData(quest.questID)
        tooltip:AddLine(RETRIEVING_DATA or L["Loading"], 1, 0.25, 0.25)
    else
        -- The game's own reward block, with the item and its comparison; ours if it fails.
        local shown = false
        if GameTooltip_AddQuestRewardsToTooltip and TOOLTIP_QUEST_REWARDS_STYLE_WORLD_QUEST then
            shown = pcall(GameTooltip_AddQuestRewardsToTooltip, tooltip, quest.questID, TOOLTIP_QUEST_REWARDS_STYLE_WORLD_QUEST)
        end
        if not shown then
            tooltip:AddLine(" ")
            tooltip:AddLine(L["Rewards"], 1, 0.82, 0)
            addRewardLines(tooltip, ns.ReadRewards(quest.questID))
        end
    end
    tooltip:Show()
end

local function hideTooltip()
    GameTooltip:Hide()
end

-- Click: the waypoint; shift-click: tracking.
local function onRowClick(row)
    local questID = row.quest and row.quest.questID
    if not questID then
        return
    end
    if IsShiftKeyDown() then
        if C_QuestLog.GetQuestWatchType(questID) then
            C_QuestLog.RemoveWorldQuestWatch(questID)
        else
            C_QuestLog.AddWorldQuestWatch(questID, Enum.QuestWatchType.Manual)
        end
    elseif C_SuperTrack.GetSuperTrackedQuestID() == questID then
        C_SuperTrack.SetSuperTrackedQuestID(0)
    else
        C_SuperTrack.SetSuperTrackedQuestID(questID)
    end
end

-- Rows ----------------------------------------------------------------------

local function buildRow(row)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    row.Type = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Type:SetPoint("LEFT", GAP, 0)
    row.Type:SetWidth(TYPE_WIDTH)
    row.Type:SetJustifyH("LEFT")
    row.Type:SetWordWrap(false)

    row.Reward = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Reward:SetPoint("LEFT", row.Type, "RIGHT", GAP, 0)
    row.Reward:SetWidth(VALUE_WIDTH)
    row.Reward:SetJustifyH("RIGHT")
    row.Reward:SetWordWrap(false)

    row.Time = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Time:SetPoint("RIGHT", -GAP, 0)
    row.Time:SetWidth(TIME_WIDTH)
    row.Time:SetJustifyH("RIGHT")

    row.Zone = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    row.Zone:SetPoint("RIGHT", row.Time, "LEFT", -GAP, 0)
    row.Zone:SetWidth(ZONE_WIDTH)
    row.Zone:SetJustifyH("LEFT")
    row.Zone:SetWordWrap(false)

    row.Title = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.Title:SetPoint("LEFT", row.Reward, "RIGHT", GAP + 4, 0)
    row.Title:SetPoint("RIGHT", row.Zone, "LEFT", -GAP, 0)
    row.Title:SetJustifyH("LEFT")
    row.Title:SetWordWrap(false)

    row:SetScript("OnEnter", showTooltip)
    row:SetScript("OnLeave", hideTooltip)
    row:SetScript("OnClick", onRowClick)
end

local function updateTime(row)
    local quest = row.quest
    if not quest then
        return
    end
    local remaining = quest.expiresAt - GetTime()
    row.Time:SetText(ns.FormatTimeLeft(remaining))
    row.Time:SetTextColor(ns.TimeLeftColor(remaining))
end

local function initRow(row, quest)
    if not row.Title then
        buildRow(row)
    end
    row.quest = quest

    local reward = quest.reward
    if reward then
        row.Type:SetText((ns.TypeLabels or TYPE_LABELS)[reward.category])
        row.Type:SetTextColor(unpack(TYPE_COLORS[reward.category]))
        row.Reward:SetText(reward.text)
    else
        row.Type:SetText(quest.rewards.loaded and "" or "...")
        row.Type:SetTextColor(0.6, 0.6, 0.6)
        row.Reward:SetText("")
    end
    row.Title:SetText(quest.title)
    row.Title:SetTextColor(qualityColor(quest.quality))
    row.Zone:SetText(quest.zone)
    updateTime(row)
end

-- Content -------------------------------------------------------------------

local function render()
    if not panel then
        return
    end
    local db = ns.db
    local shown = ns.FilterQuests(ns.quests or {}, db.category, searchBox:GetText())
    ns.SortQuests(shown, db.sortKey, db.sortAscending)
    scrollBox:SetDataProvider(CreateDataProvider(shown), ScrollBoxConstants.RetainScrollPosition)

    titleText:SetText(L["World Quests"] .. "  |cff808080" .. #shown .. "|r")
    -- As tall as the lines need, within the room the map leaves.
    local area = inside and (WorldMapFrame.ScrollContainer or WorldMapFrame) or WorldMapFrame
    local room = (area:GetHeight() or 0) - 8
    local wanted = TOP_HEIGHT + math.max(#shown, MIN_ROWS) * ROW_HEIGHT + PADDING
    panel:SetHeight(room > 0 and math.min(wanted, room) or wanted)
    if #shown == 0 then
        emptyText:SetText(#(ns.quests or {}) == 0 and L["No world quest available."] or L["No world quest matches."])
        emptyText:Show()
    else
        emptyText:Hide()
    end

    for _, chip in ipairs(chips) do
        local selected = chip.category == db.category
        chip.Text:SetTextColor(selected and 1 or 0.6, selected and 0.82 or 0.6, selected and 0 or 0.6)
        chip.Selected:SetShown(selected)
    end
    for _, header in ipairs(headers) do
        local arrow = ""
        if header.key == db.sortKey then
            arrow = db.sortAscending and " |TInterface\\Buttons\\Arrow-Up-Up:10|t" or " |TInterface\\Buttons\\Arrow-Down-Up:10|t"
        end
        header.Text:SetText(header.label .. arrow)
    end
end
ns.Render = render

-- Collects again, and once more a little later while the server still sends data.
local function refresh()
    if not panel or not panel:IsVisible() then
        dirty = true
        return
    end
    dirty = false
    local quests, pending = ns.CollectQuests()
    ns.quests = quests
    render()
    if pending and retries < 10 then
        retries = retries + 1
        ns.Debounce("retry", 1.5, refresh)
    elseif not pending then
        retries = 0
    end
end

local function requestRefresh()
    ns.Debounce("refresh", 0.3, refresh)
end

for _, event in ipairs({
    "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT", "QUEST_TURNED_IN", "WORLD_QUEST_COMPLETED_BY_SPELL",
    "TASK_PROGRESS_UPDATE", "PLAYER_ENTERING_WORLD",
}) do
    ns.OnEvent(event, function()
        if panel and panel:IsVisible() then
            requestRefresh()
        else
            dirty = true
        end
    end)
end

-- Placement -----------------------------------------------------------------

local function place()
    local map = WorldMapFrame
    panel:ClearAllPoints()
    local scale = panel:GetEffectiveScale()
    local mapLeft = (map:GetLeft() or 0) * map:GetEffectiveScale()
    local screenLeft = (UIParent:GetLeft() or 0) * UIParent:GetEffectiveScale()
    inside = mapLeft - (WIDTH + 4) * scale < screenLeft

    if inside then
        local area = map.ScrollContainer or map
        panel:SetPoint("TOPLEFT", area, "TOPLEFT", 4, -4)
    else
        panel:SetPoint("TOPRIGHT", map, "TOPLEFT", -2, 0)
    end
end

-- Building ------------------------------------------------------------------

local function createChip(parent, category, previous)
    local chip = CreateFrame("Button", nil, parent)
    chip.category = category
    chip.Text = chip:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    chip.Text:SetPoint("CENTER")
    chip.Text:SetText(L[ns.CATEGORY_LABELS[category]])
    chip:SetHeight(16)
    if previous then
        chip:SetPoint("LEFT", previous, "RIGHT", 1, 0)
    else
        chip:SetPoint("TOPLEFT", PADDING, -44)
    end

    chip.Selected = chip:CreateTexture(nil, "BACKGROUND")
    chip.Selected:SetAllPoints()
    chip.Selected:SetColorTexture(1, 0.82, 0, 0.15)
    local highlight = chip:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    chip:SetScript("OnClick", function()
        ns.db.category = category
        render()
    end)
    return chip
end

local function createHeader(parent, key, label, justify)
    local header = CreateFrame("Button", nil, parent)
    header.key, header.label = key, label
    header:SetHeight(16)
    header.Text = header:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    header.Text:SetAllPoints()
    header.Text:SetJustifyH(justify)
    header:SetScript("OnClick", function()
        local db = ns.db
        if db.sortKey == key then
            db.sortAscending = not db.sortAscending
        else
            db.sortKey, db.sortAscending = key, true
        end
        render()
    end)
    table.insert(headers, header)
    return header
end

local function build()
    local map = WorldMapFrame
    panel = CreateFrame("Frame", "WorldQuestEssentialsPanel", map, "BackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetFrameStrata(map:GetFrameStrata())
    panel:SetFrameLevel(map:GetFrameLevel() + 500)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.03, 0.03, 0.05, 0.72)
    panel:SetBackdropBorderColor(0.35, 0.35, 0.4, 0.6)

    titleText = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    titleText:SetPoint("TOPLEFT", PADDING + 2, -PADDING - 1)
    titleText:SetText(L["World Quests"])

    searchBox = CreateFrame("EditBox", nil, panel, "SearchBoxTemplate")
    searchBox:SetHeight(18)
    searchBox:SetPoint("TOPLEFT", PADDING + 6, -22)
    searchBox:SetPoint("TOPRIGHT", -PADDING, -22)
    searchBox:SetAutoFocus(false)
    if searchBox.Instructions then
        searchBox.Instructions:SetText(L["Search"])
    end
    searchBox:HookScript("OnTextChanged", render)

    local previous
    for _, category in ipairs(ns.CATEGORIES) do
        local chip = createChip(panel, category, previous)
        table.insert(chips, chip)
        previous = chip
    end
    -- The chips share the panel's width: what the labels leave is spread as padding.
    local textWidth = 0
    for _, chip in ipairs(chips) do
        textWidth = textWidth + chip.Text:GetStringWidth()
    end
    local available = WIDTH - 2 * PADDING - (#chips - 1)
    local chipPadding = math.max(math.min((available - textWidth) / #chips, 14), 2)
    for _, chip in ipairs(chips) do
        chip:SetWidth(chip.Text:GetStringWidth() + chipPadding)
    end

    -- Same columns as the rows (buildRow), over the room the scroll bar leaves.
    local typeHeader = createHeader(panel, "type", L["Type"], "LEFT")
    typeHeader:SetPoint("TOPLEFT", PADDING + GAP, -62)
    typeHeader:SetWidth(TYPE_WIDTH)
    local valueHeader = createHeader(panel, "reward", L["Value"], "RIGHT")
    valueHeader:SetPoint("LEFT", typeHeader, "RIGHT", GAP, 0)
    valueHeader:SetWidth(VALUE_WIDTH)
    local timeHeader = createHeader(panel, "time", L["Time"], "RIGHT")
    timeHeader:SetPoint("TOPRIGHT", -PADDING - 14 - GAP, -62)
    timeHeader:SetWidth(TIME_WIDTH)
    local zoneHeader = createHeader(panel, "zone", L["Zone"], "LEFT")
    zoneHeader:SetPoint("RIGHT", timeHeader, "LEFT", -GAP, 0)
    zoneHeader:SetWidth(ZONE_WIDTH)
    local titleHeader = createHeader(panel, "title", L["Quest"], "LEFT")
    titleHeader:SetPoint("LEFT", valueHeader, "RIGHT", GAP + 4, 0)
    titleHeader:SetPoint("RIGHT", zoneHeader, "LEFT", -GAP, 0)

    scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", PADDING, -TOP_HEIGHT)
    scrollBox:SetPoint("BOTTOMRIGHT", -PADDING - 14, PADDING)
    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Button", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    -- The scroll bar only shows when the lines do not fit.
    if ScrollUtil.AddManagedScrollBarVisibilityBehavior then
        ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar)
    end

    emptyText = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    emptyText:SetPoint("TOP", scrollBox, "TOP", 0, -24)

    -- The time left ticks down while the map is open.
    local elapsed = 0
    panel:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 15 then
            elapsed = 0
            scrollBox:ForEachFrame(updateTime)
        end
    end)

    panel:SetScript("OnShow", function()
        place()
        refresh()
    end)
    map:HookScript("OnSizeChanged", function()
        if panel:IsVisible() then
            place()
            render()
        end
    end)

    place()
    if panel:IsVisible() and dirty then
        refresh()
    end
end

local function attach()
    if panel or not WorldMapFrame then
        return
    end
    build()
end

ns.OnEvent("PLAYER_LOGIN", attach)
ns.OnEvent("ADDON_LOADED", function(name)
    if name == "Blizzard_WorldMap" then
        attach()
    end
end)
