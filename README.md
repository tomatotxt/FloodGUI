# FloodGUI

One Flood Escape 2 interface with TAS recording/playback, map selection, farming controls and optional advanced features.

## Run

After uploading this repository to **tomatotxt/FloodGUI**, branch **live**:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/tomatotxt/FloodGUI/live/loader.lua"))()
```

The online loader retrieves project code and vendored libraries from the same live branch. Bundled recordings download on demand. Local recordings always take priority; code updates never overwrite your recordings.

For local development, copy this folder into your executor workspace as `FloodGUI`:

```lua
loadfile("FloodGUI/loader.lua")({localOnly = true})
```

These scripts require Roblox and executor APIs including local file access and loadstring. They are not a standalone Windows app or a normal Studio LocalScript. Binary recording additionally requires Luau's buffer API.

## Features

- Airflow menus throughout, with a tomato-red and black theme, Lucide icons, and ValleySans with a BuilderSans fallback.
- Organized Overview, Farming, Maps, TAS, Recordings, Movement, Advanced, Settings, and About tabs.
- Independent collection, movement tools, map selection and difficulty controls, with both touch toggles and keyboard shortcuts.
- Binary TAS recording, savestates, rewind/advance, preview, mobile touch controls and local timeline support when available.
- Automatic playback of the 177 bundled legacy JSON recordings and new binary recordings.
- JSON/binary conversion API and creator conversion/export controls.
- Manual play after buttons, farm/reset delays, and a stop-automation control.
- Live playback speed, pause, progress, and hold controls; creator visualization toggles, editable shortcuts, and automatic-save settings.
- Adjustable rebirth/challenge intervals, lift rejoining, idle prevention, notifications, and interface scale.
- Remembered interface/timing preferences, with validation and a restore-defaults action. Active automation, spending and movement toggles are never restored from saved preferences.
- Immediate playback pause, reliable held frame advance and checkpoint rewind, verified recording saves, and a clean unload action.
- Optional fast load, direct buttons, forced win, boosts and challenge cycling. New options start off. Unavailable integrations are marked disabled; detected errors are isolated by feature.

The forced-win option stays disabled when its escape lock cannot be identified safely. Spending options state their expected costs; estimates are inherited from the source scripts. Community Maps and standalone animation/zipline replacements remain separate.

## Upload

Upload the **contents of this folder** to the repository root, not inside another FloodGUI folder. The code must be on `live`, with `loader.lua`, `runtime.luau`, `FloodGUI.luau`, `ui/`, `TAS/`, `TAS FILES/` and `vendor/` at the root. Use this working folder for the latest changes; the older ZIP is not being updated.

The prepared local repository uses branch `live` with `origin` configured. After creating the GitHub repository, publish committed changes with `git push -u origin live`. Uploading or pushing is separate from running the local checks.

## Maintain

`FloodGUI.luau` is the main app. `TAS/CREATOR/` and `TAS/PLAYER/` contain the integrated engines. `TAS/codec.luau` and `TAS/recordings.luau` define the translation and file APIs.

`ui/` contains FloodGUI's Airflow interfaces: `main.luau`, `creator.luau`, `player.luau`, and the integrated `recordings.luau` browser. `service.luau` shares the theme, font loading, and window lifecycle. `vendor/airflow.luau` is the UI dependency used by all of them. Main menu: J; creator: F6; creator hold controls: F7; player: F5. Floating buttons reopen hidden windows on touch devices too.

`preferences.luau` manages device-local `preferences.json` (excluded from Git); `overrides.luau` tracks reversible character properties. Settings → Unload FloodGUI stops the session and removes its windows. Save any active creator recording before unloading.

All FloodGUI windows use `PlayerGui` to avoid protected-container permission failures in game/input callbacks. `compat.luau` isolates game-alert calls on worker threads and optionally restores the worker's previous identity through available UNC/sUNC functions. These identity APIs are not required for the UI. If a notification cannot render, the error is logged without stopping FloodGUI. Lucide icons, custom-font loading, and the theme are unchanged.

With Node.js and the official Luau CLI installed:

```sh
node scripts/check.mjs
```

You can pass `--luau-dir PATH` if the Luau executables are not on PATH. After adding or changing bundled recordings, run `node scripts/catalog.mjs` to update the catalog.

See [recording API](docs/BINARY-API.md), [integration review](docs/FEATURE-REVIEW.md), and [credits](THIRD_PARTY.md).

## Validation limits

Static compilation, conversion roundtrips, mocked feature failures, local/remote loading and packaged-path checks are automated. Roblox gameplay, real executor behavior and server-side acceptance were not tested here. Capability checks catch missing or changed APIs; they cannot guarantee compatibility with a future game update.
