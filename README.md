# Avidity Shard Trim

A World of Warcraft addon that keeps your Soul Shards at a limit you set. When you have more than
you want, it deletes the extras one at a time on your own key presses or clicks.

The game only allows deleting an item during a real key press or click, and only one item per
press. So Shard Trim deletes one extra shard each time you press a key or click, until you're back
at your limit. Movement and every other key still work as normal.

For WoW Forever only (interface 16001).

## Download

[![Download Shard Trim](https://img.shields.io/badge/Download-Shard%20Trim-8f3fda?style=for-the-badge)](https://github.com/AvidityWoW/ShardTrim/releases/latest/download/ShardTrim.zip)

The button always gets the newest version. To install it:

1. Click **Download** above. You get a file called `ShardTrim.zip`.
2. Open the zip. Inside is a folder called `ShardTrim`.
3. Drag that `ShardTrim` folder into your WoW Forever AddOns folder, usually
   `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`.
   If you already have Shard Trim, replace the old folder.
4. Start the game, or type `/reload` if it's already running.

Older versions and the list of changes are on the [Releases page](https://github.com/AvidityWoW/ShardTrim/releases).

## Features

- **Shards to Keep** limit, 0 to 100. It never goes below the slots in your equipped shard bags.
- **Three ways to delete:** automatically on any key press or click, by clicking the banner, or with
  a keybind or macro.
- **On/off toggle** from the settings, a banner middle-click, the minimap button, a data broker
  display, a keybind, or `/strim on`, `/strim off` and `/strim toggle`.
- **Banner** showing your count against your limit, e.g. `12 / 8`. Drag it to move it, and scroll over
  it to change Shards to Keep.
- **Minimap button and data broker** (Titan Panel, ChocolateBar, and so on), with a green tick or red
  cross for on/off.
- **Banner styling:** Icon or Label layout, icon size, font size, count position, 13 styles,
  background opacity, corner rounding, an on/off badge and an optional tooltip.
- **Skinning API** so UI packs and skin addons can add their own banner styles.

## Installing

See [Download](#download) above.

### From this repo

The libraries in `Libs/` aren't kept in the repo. The packager downloads them for release builds
(see `.pkgmeta`). To run the addon straight from a clone, download them once first:

```
./fetch-libs.sh
```

Then copy the folder into your AddOns folder. Run the script again any time to update the libraries.

## Using it

### Banner

| Action | Does |
|---|---|
| Left-click | Deletes one extra shard |
| Middle-click | Turns trimming on or off |
| Mouse wheel | Shards to Keep up or down by 1 (by 5 with Shift held) |
| Right-click | Locks or unlocks the banner |
| Drag | Moves the banner while it's unlocked; the game remembers where you drop it |

### Minimap button and data broker

| Action | Does |
|---|---|
| Left-click | Turns trimming on or off |
| Shift-click | Deletes one extra shard |
| Right-click | Opens the options |

### Slash commands

| Command | Does |
|---|---|
| `/strim` or `/shardtrim` | Opens the options |
| `/strim 10` | Sets Shards to Keep to 10 |
| `/strim on`, `/strim off`, `/strim toggle` | Turns trimming on or off |

### Keybinds

Under Key Bindings > AddOns > Avidity Shard Trim:

- **Turn Trimming On/Off**
- **Delete One Extra Shard**, the same as `/click ShardTrimButton` in a macro

## Options

Esc > Options > AddOns > Avidity Shard Trim. The banner stays on screen while the Options window is
open, so you can see your changes.

**Main page**

| Setting | What it does |
|---|---|
| Enable Trimming | Turns shard deleting on or off |
| Shards to Keep | Shards above this number get deleted |
| Delete Method | Automatic (any key or click), click the banner, or macro / keybind |
| Show Banner | Always, only above the limit, or never |
| Show Minimap Button | Shows or hides the minimap button |

**Banner page**

| Setting | What it does |
|---|---|
| Show Banner | The same setting as on the main page |
| Layout | Icon (the shard icon with your count) or Label (`Soul Shards` text and your count) |
| Icon Size | 12 to 64 pixels |
| Count Position | Automatic, right, left, above, below, or on the icon |
| Style | Tooltip, Dialog, Flat, Gold, Toast, Shadow, Fel, Glass, Void, Ember, Frost, Outline, Stone |
| Font Size | 8 to 24 |
| Background | Turns the background on or off, with an opacity slider |
| Corner Rounding | 0 to 16 pixels, for the plain-colour styles |
| On/Off Badge | A tick or cross on the icon: always, only when off, or never |
| Tooltip | Shows the banner's tooltip on mouseover |

When the count sits on the icon, it shrinks to fit the icon's width. Automatic count position puts it
on icons 32 pixels or bigger, to the right of smaller ones, and below the text in the Label layout.

## Skinning API

Other addons can add banner styles. They show up in the Style dropdown:

```lua
ShardTrim:RegisterSkin("myskin", {
	label = "My Skin",
	backdrop = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 },
	bg = { 0.1, 0.1, 0.1 },     -- alpha comes from the Background opacity slider
	border = { 0, 0, 0 },
	hover = { 1, 0.82, 0 },     -- border colour on mouseover
	height = 24, padding = 6, inset = 2,
	apply = function(banner, db) end,  -- anything extra; skip your background if db.background is false
	remove = function(banner) end,     -- undo apply's extras when another style is picked
})
```

- A backdrop whose `bgFile` and `edgeFile` are both `Interface\Buttons\WHITE8X8` gets Corner Rounding.
- `ShardTrim.banner` is the banner frame. It has `.Icon`, `.Label`, `.Count`, `.Status` (the on/off
  badge), `.Footer` (the strip under an on-icon count) and `.Highlight`.
- `ShardTrim:SetStyle(key)` switches style, and `ShardTrim:Refresh()` reapplies it.
- Callbacks: `ShardTrim.RegisterCallback(you, "BannerStyled", fn)` runs after a style is applied, and
  `"BannerUpdate"` after every redraw, with the count, limit, over-limit flag and on/off state.

The full reference is the comment block above `ShardTrim = { banner = bar }` in `ShardTrim.lua`.

## Releasing

`.github/workflows/package.yml` runs the [BigWigsMods packager](https://github.com/BigWigsMods/packager)
on GitHub Actions:

- **Every push to `main`, and every pull request,** builds `ShardTrim-<version>.zip`. Download it
  from the run's Artifacts section. Nothing is uploaded anywhere.
- **Pushing a tag** builds the zip, uploads it to CurseForge, and makes a GitHub release:

  ```
  git tag v1.15.0
  git push origin v1.15.0
  ```

Set up once:

1. Create the project on CurseForge, then add its project ID to `ShardTrim.toc` as
   `## X-Curse-Project-ID: 123456`.
2. Create an API token at https://authors.curseforge.com/account/api-tokens and add it to this repo
   as an Actions secret named `CF_API_KEY` (Settings > Secrets and variables > Actions).

Tags with `alpha` or `beta` in them upload as alpha or beta files; other tags upload as releases.
The packager picks the game versions from the `## Interface:` line in the TOC. `.pkgmeta` names the
package folder and keeps `README.md` out of the zip.

## Files

| File | What it is |
|---|---|
| `ShardTrim.toc` | Addon manifest: interface versions, title, version, saved variables (`ShardTrimDB`) and load order |
| `ShardTrim.lua` | The whole addon (see below) |
| `Bindings.xml` | The two keybinds under Key Bindings > AddOns |
| `.pkgmeta` | Packager settings: the folder name, the libraries to download (externals), and files left out of the zip |
| `fetch-libs.sh` | Downloads the libraries into `Libs/` for running from a clone |
| `.gitignore` | Keeps the downloaded `Libs/` and the packager's `.release/` out of git |
| `.github/workflows/package.yml` | Builds the zip on every push, and uploads to CurseForge on tags |
| `Libs/LibStub/` | Library version loader the other libraries need (downloaded, not in the repo) |
| `Libs/CallbackHandler-1.0/` | Event callbacks, used by LibDataBroker and the skinning API's `RegisterCallback` (downloaded) |
| `Libs/LibDataBroker-1.1/` | Data broker, for Titan Panel, ChocolateBar and other broker bars (downloaded) |
| `Libs/LibDBIcon-1.0/` | The minimap button (downloaded) |

### ShardTrim.lua, top to bottom

| Section | Does |
|---|---|
| Constants and defaults | Shard item ID, icon, `DEFAULTS` for every setting, layout and count position choices |
| `Scan` | Counts your shards, works out the limit (Shards to Keep or your shard bag slots, whichever is higher), finds the first shard |
| `Trim` | Picks up one extra shard and deletes it; puts it back if anything else ended up on the cursor |
| `Set`, `ShardTrim_Toggle`, `OpenOptions` | Changes settings so the Options panel stays in sync, the on/off toggle, opening the options |
| `FillTooltip` | The shared tooltip for the banner, minimap button and broker |
| Banner frame | The `ShardTrimButton` frame and its icon, label, count, badge, footer and highlight |
| Skinning API | `RegisterSkin`, `SetStyle`, `Refresh`, and the callbacks |
| Corner rounding | Draws rounded backgrounds and borders for plain-colour styles |
| `Layout` | Positions the icon or label, the count and the badge, and sizes the banner |
| `ApplyStyle` | Applies the current style, fonts and sizes |
| Built-in styles | The 13 styles in the Style dropdown |
| Banner scripts | Clicks, middle-click toggle, mouse wheel, hover, tooltip and dragging |
| Data broker and minimap | The broker object and minimap button |
| Key and mouse hooks | Deletes on any key press or world click in Automatic mode |
| `Update` | Redraws the banner, broker text and minimap mark after every bag change or setting change |
| `BuildOptions` | The Options pages |
| Login | Fills in defaults, carries over settings from older versions, registers the minimap button, builds the options |
| Keybinds and slash commands | Binding names and `/strim` |
