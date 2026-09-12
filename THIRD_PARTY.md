# Third-party code and credits

- FloodGUI derives from tomatotxt/Flood-GUI: main `a2e0fba`, backup `8475fee`, testing `783a315`, v4beta `f6f219e`. Original TAS work credits Voiz#5668; original GUI and subsequent integrations credit Tomato.
- The previous Kavo UI (xHeptc, via tomatotxt's fork) has been replaced by Airflow. Its snapshot remains in Git history and the workspace archive.
- `vendor/input.luau`: InputAPI from `tomatotxt/-`, commit `8a22551c68d7c518b30e19d9077727803cdf4f7a`, file `input.luau`.
- `vendor/airflow.luau`: Airflow UI source supplied directly by the project owner. Its provenance and license were not supplied. It is the shared UI dependency for FloodGUI, the TAS creator, and the TAS player. FloodGUI attempts ValleySans font loading and keeps BuilderSans when unavailable.
- Airflow includes a Lucide asset-map fallback snapshot from [Footagesus/Icons](https://github.com/Footagesus/Icons/blob/main/lucide/dist/Icons.lua), retrieved 2026-09-11. The map references Roblox-hosted images; those assets still require Roblox access. The library refreshes the map asynchronously, reads asset entries without executing remote Lua, and retains the snapshot if refresh fails. Icons originate from [Lucide](https://lucide.dev/); no new license grant is asserted for the hosted assets.
- The optional Infinite Yield button loads the upstream `edgeiy/infiniteyield` script only when clicked.

The two vendored source snapshots were retrieved and their source endpoints verified on 2026-09-11. Local changes replace legacy Roblox asset HTTP URLs with equivalent asset IDs and add explicit input-listener cleanup. Original file headers are retained. No new license grant is asserted for upstream code or recordings.
