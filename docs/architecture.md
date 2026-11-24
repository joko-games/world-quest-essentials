# Architecture

## Finding the quests (`Quests.lua`)

The list covers the current expansion, never the map the player looks at. The game only
gives world quests map by map (`C_TaskQuest.GetQuestsOnMap(uiMapID)`), so the addon needs
the expansion's maps. No public list of Midnight's map IDs was found while writing it, so
they are found in two ways, and a wrong ID cannot hide a zone:

- **Seeds** (`ns.SEED_MAPS`): the Midnight maps believed known (Quel'Thalas, Silvermoon City,
  Eversong Woods, Voidstorm, Harandar, Isle of Quel'Danas, Zul'Aman). A seed the client does
  not know is skipped; a continent brings all its zones. Their quests are kept as they are.
- **Scan** (`ns.SCAN_FIRST` to `ns.SCAN_LAST`, 2390 to 2800): every map of type Zone in the
  range of IDs added since the end of The War Within. That range also holds some maps of The
  War Within, so a quest found only by the scan is kept only when `GetQuestExpansion` gives the
  current expansion (`GetServerExpansionLevel`).

The maps are resolved once per session. `/wqe maps` prints them, seeds marked with `*`.

A quest is kept when it is a world quest (`C_QuestLog.IsWorldQuest`), not done today
(`IsQuestFlaggedCompleted`) and still active. A quest seen on several maps is listed once,
under the map the game gives for it.

Rewards come from the quest log reward functions: money, items (gear when the item has an
equipment slot), currencies (a currency that grants reputation counts as reputation) and
major faction reputation. When the client does not have them yet, it is asked for them
(`C_TaskQuest.RequestPreloadRewardData`), and the list collects again on
`QUEST_DATA_LOAD_RESULT`, and every 1.5 s for at most 10 tries while something is missing.

## The panel (`UI/Panel.lua`)

A child of `WorldMapFrame`, so it shows and hides with the map. It is 350 px wide and half
see-through, and only as tall as its lines need, up to the map's height. It anchors to the
left of the map when the screen has room for it, and otherwise over the map's top left
corner; it places itself again when the map changes size.

The lines are 15 px tall, so they carry no icon: the kind of the main reward is a word in its
own colour (Type column), and its value a number beside it. It changes nothing in
the map and calls no protected function, to keep the map free of taint.

The rows are a `WowScrollBoxList` with a linear view. Collecting happens when the map opens
and on quest events while it is open (debounced); filtering and sorting are done again on
every change of the search, filter or sort. The time left is computed from the time of the
collection and updated every 15 s.

The tooltip uses the game's own reward block (`GameTooltip_AddQuestRewardsToTooltip`, as the
map's quest pins do), and falls back on a plain list of the rewards if it fails.
