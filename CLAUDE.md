# CLAUDE.md

Memory of the World Quest Essentials repository (`https://github.com/star-racer/world-quest-essentials`):
project context, standing rules and current status. The global rules are in `~/.claude/CLAUDE.md`
(versioned in `primo-ideas/claude/CLAUDE.md`); technical documentation is in `docs/` (index:
`docs/README.md`).

## What it is

World Quest Essentials, a World of Warcraft addon (Retail, 12.1.5). Like its sibling Trading
Essentials (`../trading-essentials`), it gathers only the essentials of one theme, in a simple
interface: here, the complete and filterable list of the current expansion's (Midnight) world quests
the character can do, beside the world map, whatever map is shown and whatever its size. Hovering a
line shows its rewards.

## Layout

The addon is at the repository root (`WorldQuestEssentials.toc`, the `.lua` files it lists, `UI/`,
`Locales/`, `Media/`); `install.ps1` copies only those into a local WoW install. `tests/` holds the test suite
(Lua 5.1 through lupa, against a small fake client). `art/` holds the icon sources.

## Build, test, release

```powershell
py -V:3.12 -m pip install "lupa>=2.0"
py -V:3.12 tests/run.py
.\install.ps1                        # then /reload in game
```

CI (`.github/workflows/ci.yml`, every push to `main`) runs the tests; it deploys nothing.

## Decisions

- 2026-11-24: v1.0.0 covers only the latest expansion. Choosing the context of world quests
  (another expansion) comes in a later version, as a choice in the panel: never by following the
  map the player looks at.
- 2026-11-24: Midnight's map IDs are not documented anywhere found, so the maps come from seeds plus a
  scan of IDs 2390 to 2800 filtered by quest expansion (docs/architecture.md). Check the seeds in game
  with `/wqe maps`.
- 2026-11-24: the names may still change, except "Essentials".
- 2026-11-24: renamed World Quest Essentials (singular "Quest", the natural English noun adjunct):
  `.toc`, folder and saved variables `WorldQuestEssentials`, repository `star-racer/world-quest-essentials`.
  `/wqe` is unchanged. The local folder is still `world-quests-essentials` until the user renames it.
- 2026-11-24: the icon is a globe behind a gold exclamation mark, drawn for the project and dedicated
  to CC0 (`art/icon.svg`); `Media/Icon.tga` is built from it.
- 2026-11-24: history, at the user's request: the first commit, "License" (the `LICENSE` file alone), is
  the user's own, under their global Git identity, and stays so; everything after it is Claude's. No
  commit carries a trailer (global rule since 2026-11-24).
- 2026-11-24: clicking a line only sets the waypoint (shift-click tracks): changing the map from addon
  code risks taint, which Trading Essentials already had to fight.

## Working rules

- **Language:** everything in the repository is in English, except translations (`Locales/`). Talk to
  the user in French.
- The logic is tested outside the game; what only the client can show is checked in game by the user
  (README, "Check in game").

## Status

- 2026-11-24: v1.0.0, seen working in game: panel left of the map (or over its top left corner),
  search, reward filters, sortable columns with a coloured Type column, reward tooltip, waypoint on
  click, `/wqe maps`, its own CC0 icon. The history was squashed into one v1.0.0 commit on top of the
  user's "License" commit, tagged `v1.0.0` locally. The remote `star-racer/world-quest-essentials`
  does not exist yet: nothing pushed.
