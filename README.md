# World Quest Essentials

[![CI](https://github.com/star-racer/world-quest-essentials/actions/workflows/ci.yml/badge.svg)](https://github.com/star-racer/world-quest-essentials/actions/workflows/ci.yml)

World of Warcraft addon (Retail, 12.1.5) that lists every world quest of the current expansion, Midnight, beside the world map. Only the essentials, in a plain list.

Status: v1.0.0. The logic is tested outside the game, and the addon has been seen working in the client; what to check there after a change is under [Check in game](#check-in-game).

## Installation

```powershell
.\install.ps1
```

The script copies `WorldQuestEssentials.toc` and the files it lists into `Interface\AddOns\WorldQuestEssentials`, and nothing else. After changing the code, run it again, then `/reload` in game. If the list of files in the `.toc` changed, restart WoW.

| Option | Effect |
| --- | --- |
| `-Clean` | Also deletes the saved data (sort and filter) on all accounts. You are asked to confirm, and WoW must be closed. |
| `-WowPath <folder>` | The WoW folder, the one containing `_retail_`, if it is not in the standard location. |
| `-WhatIf` | Shows what would be done, without changing anything. |

## Usage

Open the world map, small or maximized: the list is beside it, to its left, or over its top left corner when the screen has no room left. It is small and half see-through, and only as tall as its lines need. It shows **every** world quest of Midnight your character can do now, wherever the map is, even on another continent: the list does not follow the map.

- **Search**: every word typed must appear in the quest's name, its zone, its type or the name of a reward.
- **Filters**: All, Gear, Gold, Currency, Reputation, Items keep the quests that give that kind of reward.
- **Sort**: click a column header (Type, Value, Quest, Zone, Time); a second click reverses it. Type sorts by kind of reward (gear first), Value by kind then amount. The sort and the filter are kept between sessions.
- **Hover** a line: its rewards, as the game shows them on the map.
- **Click** a line: places the waypoint on the quest (click again to remove it). **Shift-click**: tracks it in the objectives, or stops tracking it.

Each line shows the kind of its main reward, each in its own colour (gear, item, currency, gold, reputation), its value (the item level for gear, the amount for an item, a currency or gold), the quest in its rarity colour, its zone and the time left, in orange under four hours and red under one.

`/wqe maps` lists the maps the addon reads, with the number of quests found on each (`*` marks the maps known to be Midnight's).

## Check in game

What only the client can show:

1. The list appears with the map, small and maximized, and follows it when its size changes.
2. It holds the same quests as the Midnight zones' maps, and none from older expansions. `/wqe maps` shows where they come from.
3. Hovering shows the rewards; a quest whose rewards are not loaded yet says so, then fills in.
4. Click and shift-click on a line.
5. No "Interface action blocked" message, in or out of combat.
