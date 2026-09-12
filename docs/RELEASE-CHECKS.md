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
- Actual Airflow library tests (mock Roblox services) cover bundled Lucide fallback, asynchronous refresh without executing remote source, retry throttling, icon aliases, invalid font responses and corrupt cache repair. Drag tests cover empty window areas, control exclusion, pointer ownership, cancellation, touch scrolling, overlapping windows and dialogs.

Airflow interaction changes: empty content/paragraph areas now drag the window as well as the sidebar. Buttons, inputs, sliders and touch-scrollable areas keep their normal behavior. Window dragging clamps immediately to screen edges. Stepper repeat stops on pointer release/focus loss/window hiding, old repeat timers cannot resume after a new press, and resize retains its selected base size. The launcher button measures total drag distance, including slow movement.

In-game checklist: confirm Lucide images and ValleySans render in the target executor; drag from both panels; use sliders and text fields; scroll on a phone; release a held stepper outside its button; hide/reopen the window mid-gesture. Roblox asset availability and actual rendering cannot be proven by the local mocked tests.

The future public FloodGUI loader endpoint cannot serve this release until the repository contents are uploaded to `live`. No remote repository was created or updated. No Roblox session was used; server acceptance, UI appearance and gameplay remain unverified in-game.

Run `node scripts/check.mjs --luau-dir PATH_TO_LUAU` to repeat the local checks.
