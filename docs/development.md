# Development

## Tests

The tests run the addon's logic (`Core.lua`, `Quests.lua`) on Lua 5.1, the version WoW uses, against a small fake client (`tests/wow_mock.lua`) whose maps, quests and rewards each test sets. `UI/Panel.lua` is loaded too, which checks that it compiles; the panel itself is checked in game (README, "Check in game"). They need Python with [lupa](https://pypi.org/project/lupa/) 2.0 or later. lupa has no wheels for brand-new Python releases; Python 3.12 works, and is what CI uses.

```powershell
py install 3.12
py -V:3.12 -m pip install "lupa>=2.0"
py -V:3.12 tests/run.py
```

## Continuous integration

`.github/workflows/ci.yml` runs the test suite on every push to `main`, on pull requests and by hand. It deploys nothing. Releases go through CurseForge, below.

## Publishing on CurseForge

`.pkgmeta` describes the package: a `WorldQuestEssentials` folder holding the `.toc`, the files it lists and `Media/`, the same as `install.ps1`. As for Trading Essentials, a CurseForge webhook on the GitHub repository packages each tag; the tag name becomes the version, and a tag containing `alpha` or `beta` publishes an alpha or beta. A release candidate such as `v1.0.0-rc1` would be published as a stable release, so tag it `v1.0.0-beta1`-style if it should not be.

## Files

| File | Role |
| --- | --- |
| `WorldQuestEssentials.toc` | The addon's description and the files it loads |
| `Core.lua` | Events, saved data, formatting, `/wqe` command |
| `Quests.lua` | The expansion's maps, collecting the quests and their rewards, filtering, sorting |
| `UI/Panel.lua` | The panel beside the world map: search, filters, headers, rows, tooltip |
| `Locales.lua`, `Locales/` | Language selection and translations (English is the key and the fallback) |
| `Media/` | Textures: `Icon.tga`, the addon's icon in the addon list |
| `art/` | Source images, left out of the package: `icon.svg`, the icon's drawing (CC0), and `icon.png`, the icon at 512 x 512, also the CurseForge project icon |
| `install.ps1` | Copies the addon into a local WoW install |
| `tests/` | Fake client and tests |
| `docs/` | This documentation |
| `.github/workflows/` | Continuous integration |

## The icon

The icon is a globe behind a gold exclamation mark, drawn for this project and dedicated to the public domain (CC0 1.0), as its source `art/icon.svg` says. `art/icon.png` is that drawing at 512 x 512 on a transparent background, rendered with a headless browser (Chrome's `--headless --screenshot --default-background-color=00000000 --window-size=512,512` on a page holding only the image).

The client reads TGA (and BLP) textures, with sides a power of two. After changing `art/icon.png`, rebuild `Media/Icon.tga` from it, an uncompressed 32-bit TGA of 64 x 64, with Pillow (`pip install pillow`):

```powershell
py -V:3.12 -c "from PIL import Image; Image.open('art/icon.png').convert('RGBA').resize((64, 64), Image.LANCZOS).save('Media/Icon.tga')"
```

Then restart WoW: a texture file new to the addon folder is only found at launch. On CurseForge, upload `art/icon.png` as the project icon.
