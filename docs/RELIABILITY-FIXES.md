# TAS reliability changes — 31 October 2026

Applied to `FloodGUI/live`, based on commit `be0470c4c2558d458812fddc0495ff0b7d5edfdc`. The separate `Flood-GUI/v4beta` checkout and all bundled recording files are unchanged.

## Changes

- **Launch ownership:** immutable player/creator generations invalidate pending downloads before execution. Engine dependency loads use the same guard. Partial initialization resources are registered immediately and released on cancellation. Stop, unload, replacement, and late callbacks cannot acquire a newer session's ownership.
- **Save collisions:** reservations are shared by recording APIs and by overlapping runtimes for the same workspace root. Two factories can no longer independently reserve the same filename while an executor's write yields. Existing revision numbering and byte readback verification remain.
- **Recording time:** new writes require nonnegative, nondecreasing timestamps. Legacy JSON and FE2T readers preserve sample order and clamp backward jitter of at most 10 ms in memory, reporting `timestampRepairs` in metadata. Larger reversals fail with a frame-specific diagnostic. No source recording is rewritten. Equal timestamps retain last-sample-wins sampling.
- **Playback rate:** FE2's numeric `UpdIngameStats.gamespeedMultiplier` takes precedence. HUD parsing remains a fallback, with explicit refresh when entering a map. User rate and game rate are applied once; slide duration is measured in authored time.
- **Presentation:** recorded orientation is the default. Optional swim smoothing handles opposite directions and uses delta time. Slide property changes restore the values the player actually owned. End-of-file is reported as playback ending, rather than a confirmed game win. Unused mirroring declarations were removed; automatic layout mirroring is not claimed.
- **Preview:** validates the recording and available map/character/camera before acquiring state, checks map-name metadata, installs cleanup before setup, and catches frame errors. Cleanup restores pose, velocity, camera, animation, button state, and captured environment time. Repeated preview and initial/final-sample behavior keep their existing protections.
- **Environment rewind:** a shared capture module tracks instance creation, removal, reparenting, supported property changes, and attributes. Dynamic clones receive distinct identities even when they inherit a TAS UUID. Removed objects are retained for reversal. Lighting and its supported effects use the same seek clock. Rewinding no longer forces transparent parts opaque or substitutes ending lighting for the initial baseline.
- **Native timelines:** the editor no longer calls native `PlayTimeline`. Native actions can spawn uncancellable wall-clock work and target the real player/camera/remotes despite living under a cloned map. Captured map and lighting changes are replayed on the editor clock instead. Uncaptured native player actions are explicitly unsupported.
- **Main controls:** movement overrides start off. Root-moving collection is cancelled before engine handoff and cannot resume over the editor's pose. Collection/rebirth are suspended when opening the creator; main modifiers yield to engines. Selected-map Farm now arms farming, cooldown vote eligibility is checked, ready-map waits are cancellable/bounded, and a player launched after map preparation can find the existing Map.
- **Restoration:** creator movement setup uses the captured character's movement values instead of hardcoded cleanup defaults. Hooks are scoped to the active launch and local character. Session cleanup retains its own connections and stop handles.

## Validation

Command:

```sh
node scripts/check.mjs --luau-dir PATH_TO_LUAU
```

Passed using official Luau 0.744:

- 47 Lua/Luau files compiled.
- 177 bundled recordings / 985,086 frames checked.
- Existing codec, filesystem, runtime, preference, feature, rejoin, touch, and actual Airflow/engine harnesses passed.
- New tests cover stopped/unloaded downloads, partial-resource disposal, two-factory and cross-runtime saves, out-of-order time, bounded legacy jitter, map compatibility, rate conversion, antiparallel facing, cooldown voting, actual preview failure rollback, main defaults, selected Farm, and suspended collection handoff.
- Reversible environment tests cover dynamic creation, inherited duplicate UUIDs, removal, reparenting, attributes, transparency, anchoring, lighting changes/effects, and timeline isolation.
- The actual codec migrated the timestamp sequences of all 14 affected bundled runs in memory; source files stayed unchanged.
- `git diff --check` passed.

## Scope

These are code and mocked-integration checks. Roblox rendering, physics, executor behavior, and server acceptance still require controlled runtime testing. Recording files remain trajectory interchange, not complete portable environment/physics/server snapshots. The current binary format does not store this session's environment capture; loading against another map/layout cannot guarantee equivalent behavior. Map-name metadata is checked when present; legacy JSON lacks that identity. No automatic mirror transform or guessed native-action simulator was added.

To try this working copy, copy the complete `FloodGUI` directory into the executor workspace and use:

```lua
loadfile("FloodGUI/loader.lua")({localOnly = true})
```

The online loader reads the published GitHub branch. Local-only mode is useful for testing further working-copy changes before publication.
