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

- Unified interface, independent collection, movement tools, map selection and difficulty controls.
- Binary TAS recording, savestates, rewind/advance, preview, mobile touch controls and local timeline support when available.
- Automatic playback of the 178 bundled legacy JSON recordings and new binary recordings.
- JSON/binary conversion API and creator conversion/export controls.
- Manual play after buttons, farm/reset delays, and a stop-automation control.
- Optional fast load, direct buttons, forced win, boosts and challenge cycling. New options start off. Unavailable integrations are marked disabled; detected errors are isolated by feature.

The forced-win option stays disabled when its escape lock cannot be identified safely. Spending options state their expected costs; estimates are inherited from the source scripts. Community Maps and standalone animation/zipline replacements remain separate.

## Upload

Upload the **contents of this folder** to the repository root, not inside another FloodGUI folder. The code must be on `live`, with `loader.lua`, `runtime.luau`, `FloodGUI.luau`, `TAS/`, `TAS FILES/` and `vendor/` at the root.

For a fresh extraction of the upload ZIP:

```sh
git init -b live
git add .
git commit -m "Prepare FloodGUI live"
git remote add origin https://github.com/tomatotxt/FloodGUI.git
git push -u origin live
```

The prepared local repository already has branch `live` and `origin` configured. Commit it with your Git identity, then push. No GitHub repository was created or changed during preparation. The public loader URL becomes available after that upload.

## Maintain

`FloodGUI.luau` is the main app. `TAS/CREATOR/` and `TAS/PLAYER/` contain the integrated engines. `TAS/codec.luau` and `TAS/recordings.luau` define the translation and file APIs.

With Node.js and the official Luau CLI installed:

```sh
node scripts/check.mjs
```

You can pass `--luau-dir PATH` if the Luau executables are not on PATH. After adding or changing bundled recordings, run `node scripts/catalog.mjs` to update the catalog.

See [recording API](docs/BINARY-API.md), [integration review](docs/FEATURE-REVIEW.md), and [credits](THIRD_PARTY.md).

## Validation limits

Static compilation, conversion roundtrips, mocked feature failures, local/remote loading and packaged-path checks are automated. Roblox gameplay, real executor behavior and server-side acceptance were not tested here. Capability checks catch missing or changed APIs; they cannot guarantee compatibility with a future game update.
