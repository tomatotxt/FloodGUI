# Third-party code and credits

- FloodGUI derives from tomatotxt/Flood-GUI: main `a2e0fba`, backup `8475fee`, testing `783a315`, v4beta `f6f219e`. Original TAS work credits Voiz#5668; original GUI and subsequent integrations credit Tomato.
- `vendor/kavo.luau`: tomatotxt's Kavo UI fork, originating with xHeptc. Snapshot from `tomatotxt/Kavo-UI-Library`, commit `330f649263760c9523953ca6d8edf1714b881ab4`, file `source.lua`.
- `vendor/input.luau`: InputAPI from `tomatotxt/-`, commit `8a22551c68d7c518b30e19d9077727803cdf4f7a`, file `input.luau`.
- `vendor/airflow.luau`: Airflow UI source supplied directly by the project owner. Its provenance and license were not supplied. It is included as an optional, vendored UI library and is not yet the application UI. FloodGUI changes use touch sizing on all touch-capable devices, associate slider/color-picker drags with their initiating pointer, and disable external icon/font downloads.
- The optional Infinite Yield button loads the upstream `edgeiy/infiniteyield` script only when clicked.

The two vendored source snapshots were retrieved and their source endpoints verified on 2026-09-11. Local changes replace legacy Roblox asset HTTP URLs with equivalent asset IDs and add explicit input-listener cleanup. Original file headers are retained. No new license grant is asserted for upstream code or recordings.
