# Release verification — 2026-09-11

Target repository: `tomatotxt/FloodGUI`. Target branch: `live`.

- All active Lua/Luau files, including vendored libraries and tests, compiled with official Luau 0.737.
- Conversion roundtrips passed for representative frames from all 178 recordings, plus rotation edge cases, experimental FE2T v2, extended metadata and malformed buffers.
- All 177 bundled JSON recordings were parsed and their coordinates validated: 985,086 frames total. The original fixture set still includes the removed one-frame placeholder as a codec edge case.
- Feature tests exercised missing APIs, read-only startup probes, remote removal, independent failure disabling, challenge schemas and map selection.
- File tests exercised online JSON fallback, binary priority, numbered revisions, corrupt-file fallback and overwrite protection.
- Touch tests exercised fast release, multiple fingers and focus-loss cancellation.
- The actual loader source was exercised in mocked online and local modes. The live base URL, path escaping, caching, local-file precedence and all literal project imports were checked.
- Airflow UI integration tests exercise all three interfaces with mock controls: existing feature coverage, toggle synchronization, guarded feature failures, spending confirmation, recording import/conversion, creator actions and shortcut editing, player settings, and window cleanup.
- No active application code references Kavo or the old UI API. All UI modules resolve through the same `live` runtime as the rest of FloodGUI.

The future public FloodGUI loader endpoint cannot serve this release until the repository contents are uploaded to `live`. No remote repository was created or updated. No Roblox session was used; server acceptance, UI appearance and gameplay remain unverified in-game.

Run `node scripts/check.mjs --luau-dir PATH_TO_LUAU` to repeat the local checks.
