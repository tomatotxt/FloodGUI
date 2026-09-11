# Release verification — 2026-09-11

Target repository: `tomatotxt/FloodGUI`. Target branch: `live`.

- All 23 Lua/Luau files, including vendored libraries and tests, compiled with official Luau 0.737.
- Conversion roundtrips passed for representative frames from all 178 recordings, plus rotation edge cases, experimental FE2T v2, extended metadata and malformed buffers.
- All 178 original JSON recordings were parsed and their coordinates validated: 985,087 frames total.
- Feature tests exercised missing APIs, read-only startup probes, remote removal, independent failure disabling, challenge schemas and map selection.
- File tests exercised online JSON fallback, binary priority, numbered revisions, corrupt-file fallback and overwrite protection.
- Touch tests exercised fast release, multiple fingers and focus-loss cancellation.
- The actual loader source was exercised in mocked online and local modes. The live base URL, path escaping, caching, local-file precedence and all literal project imports were checked.
- Kavo, InputAPI, optional Infinite Yield and the Tomato Hub support invite were reachable when checked. UI and input libraries are packaged locally with attribution.

The future public FloodGUI loader endpoint cannot serve this release until the repository contents are uploaded to `live`. No remote repository was created or updated. No Roblox session was used; server acceptance, UI appearance and gameplay remain unverified in-game.

Run `node scripts/check.mjs --luau-dir PATH_TO_LUAU` to repeat the local checks.
