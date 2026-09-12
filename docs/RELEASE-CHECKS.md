# Release verification — 2026-09-12

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
- TAS tests cover first/final/single-frame playback, interpolation, event-speed reset, rewinding across checkpoints, held frame advance without deadlock, stop-during-advance cancellation, and immediate reversible pause. The creator/player control harness executes their actual function source.
- Storage tests cover revision gaps, revision-only discovery, concurrent save reservations, verified disk writes, corrupt-local remote fallback without replacement, sparse-frame rejection, UTF-8 BOM imports, and invalid Windows paths before any directory creation.
- Preferences tests cover the safe allowlist, types/ranges, unsupported-version protection, defaults, and storage failure isolation. Reversible-property tests ensure cleanup respects newer game-side values.
- UI tests cover exclusive recording selection, refresh-during-save, remembered setting callbacks, unload/reset confirmation, disabled/deferred touch input, cancellation before closing animation, and service recreation after unloading. Airflow tests include disabled dropdowns, key capture cancellation, exact-once dialogs, and resilient control/window destruction.
- Capability regressions reproduce the reported `lacking capability Plugin` error when a notification is parented beneath a protected container, then construct the actual Airflow notification under PlayerGui. All FloodGUI windows explicitly use PlayerGui, and Airflow's default host no longer selects gethui/CoreGui. Failed instance construction disposes of the unfinished object; notification failures are contained and reported once without disabling later successful notifications.
- Main, creator, and player game alerts use `compat.luau` worker threads. Tests cover yielding callbacks, nil arguments, all supplied UNC identity aliases, original-identity restoration, missing/throwing APIs, and game-alert errors without changing the UI caller's thread. No hard-coded privileged identity is set.

The supplied UNC checker was reviewed as source, not executed or treated as evidence that APIs passed. The supplied sUNC HTML was the documentation index; function semantics were checked against [getthreadidentity](https://docs.sunc.io/Reflection/getthreadidentity/), [setthreadidentity](https://docs.sunc.io/Reflection/setthreadidentity/), and [gethui](https://docs.sunc.io/Instances/gethui/). The screenshot confirms the protected-parent failure; game-alert context changes are a possible trigger, not a runtime observation from this environment.

Airflow interaction changes: empty content/paragraph areas now drag the window as well as the sidebar. Buttons, inputs, sliders and touch-scrollable areas keep their normal behavior. Window dragging clamps immediately to screen edges. Stepper repeat stops on pointer release/focus loss/window hiding, old repeat timers cannot resume after a new press, and resize retains its selected base size. The launcher button measures total drag distance, including slow movement.

In-game checklist: confirm Lucide images and ValleySans render in the target executor; drag from both panels; use sliders and text fields; scroll on a phone; release a held stepper outside its button; switch tabs and hide/reopen mid-gesture. Record, rewind across a savestate, advance while holding, save/reload a revision, pause in midair, and verify the final playback pose. Change preferences and reload, then unload and verify movement/UI cleanup. Roblox asset availability and actual rendering cannot be proven by the local mocked tests.

These changes must be uploaded to `live` before the public loader can use them. This improvement pass did not publish to GitHub. No Roblox session was used; server acceptance, UI appearance and gameplay remain unverified in-game.

Run `node scripts/check.mjs --luau-dir PATH_TO_LUAU` to repeat the local checks.
