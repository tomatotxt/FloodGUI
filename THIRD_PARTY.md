# Third-party code and credits

- FloodGUI derives from tomatotxt/Flood-GUI: main `a2e0fba`, backup `8475fee`, testing `783a315`, v4beta `f6f219e`. Original TAS work credits Voiz#5668; original GUI and subsequent integrations credit Tomato.
- `vendor/kavo.luau`: the active UI, from [tomatotxt's Kavo fork](https://github.com/tomatotxt/Kavo-UI-Library), `source.lua` at commit `330f649263760c9523953ca6d8edf1714b881ab4`, retrieved 2026-10-31. Kavo credits xHeptc. Local changes add owned window cleanup, control handles, silent synchronization support, cancellation and fractional/touch sliders while retaining the fork's layout and visuals. No upstream license file was supplied.
- `vendor/input.luau`: InputAPI from `tomatotxt/-`, commit `8a22551c68d7c518b30e19d9077727803cdf4f7a`, file `input.luau`.
- `vendor/airflow.luau`: retained inactive source and regression coverage from the previous interface, supplied directly by the project owner. Its provenance and license were not supplied. The running app uses Kavo instead.
- Airflow includes a Lucide asset-map fallback snapshot from [Footagesus/Icons](https://github.com/Footagesus/Icons/blob/main/lucide/dist/Icons.lua), retrieved 2026-09-11. The map references Roblox-hosted images; those assets still require Roblox access. The library refreshes the map asynchronously, reads asset entries without executing remote Lua, and retains the snapshot if refresh fails. Icons originate from [Lucide](https://lucide.dev/); no new license grant is asserted for the hosted assets.
- The optional Infinite Yield button loads the upstream `edgeiy/infiniteyield` script only when clicked.

The InputAPI and Airflow snapshots were retrieved and their source endpoints verified on 2026-09-11. Original file headers are retained. No new license grant is asserted for upstream code or recordings.
