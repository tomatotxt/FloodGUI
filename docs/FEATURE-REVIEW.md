# Miscellaneous script integration

All 20 source scripts were reviewed. Originals remain in the separate local workspace archive and are not part of this repository's runtime.

| Source | Final handling |
| --- | --- |
| quickfarm | Integrated start/reset delays, manual play after buttons, direct button handling, guarded fast load/forced win, boosts, smart/timed challenges and stop controls. Spending options start off. |
| reach + testing variant | Integrated vote-cost calculation and explicit map/mode selection. The variants differed only in branch URLs. |
| tashelper | Integrated missing-recording preference and exclusive handoff to the creator. |
| win | Existing farming, anti-idle and queue behavior retained; added alert control and safer cleanup. |
| minigui | Redundant mini UI omitted. Its automatic external wildcard script is not executed. |
| mobile | Integrated touch recording controls, held rewind/advance and the frame-advance scope fix. |
| mobile2 | Incorporated collapsible, draggable touch controls into the existing creator instead of maintaining another creator. |
| EXPERIMENTS/creator | Integrated binary recording through a shared translation API, monotonic timing, smooth button traversal, post-touch timestamps, NoSwim filtering and guarded cloned-map timelines. |
| EXPERIMENTS/player | Integrated FE2T reading through the translation layer while retaining current manual/mobile player controls. |
| EXPERIMENTS/new.luau | Minified experimental implementation overlaps the above; its useful mechanisms are maintained in readable modules. |
| TAS Editor, TAS Record Voiz, Beta-Creator | Older recording/rewind/savestate/export implementations are superseded by the integrated creator. |
| TAS Player + backup variant | Superseded by the shared current player with JSON/binary support. |
| CREATOR/fe2cm.luau | Integrated into creator.luau: added Community Maps obfuscated rope remote alias oBoPcLGDkNQjGAPHvlWujHyuqmatLeGx, unanchoring on scan completion, and CM respawn handling. |
| ZiplineFix | Ported as native zipline assistant (zipline.luau): respects native 40 default RopeSpeed clamped to 20..200, uses canonical UpdRopeData before visual reconstruction, and hooks RopeStart proximity cleanly. Upgraded with full Zipline Controller supporting mid-zipline pause, resume, single-frame advance, and geometric seek. |
| reach, tashelper, minigui | Ported as standalone entry points (reach.luau, tashelper.luau, minigui.luau) powered by FloodGUI's runtime and native lifecycle. |

## TAS Creator & Player FE2 Interconnections

- **Mid-Zipline Pause & Resume:** Hooks `FE2_Character.startZipline` to suspend progression along ropes when paused, keeping `HumanoidRootPart` anchored and oriented without letting FE2's `RenderStepped` loop advance or terminate the zipline in the background. Resuming continues seamlessly along the rope.
- **Accurate Mathematical Model:** Uses pure curve projection (`calculateProgress`) and pose evaluation (`evaluate`) matching FE2 client internals (`55953_FE2_Character.LocalScript.luau` lines 923-956), computing segment lerps and swing tilt angles deterministically.
- **Frame-Accurate Advance:** `StepForward()` advances ziplines by exact `RECORD_INTERVAL` slices, capturing each frame without desync.
- **No Lost Frames on Hitch/Lag:** The frame recording loop drains accumulated intervals (`while RecordAccumulator >= RECORD_INTERVAL`), preventing lost frames during momentary frame-rate drops while clamping lag debt.
- **Monotonic Timestamps:** Enforces non-decreasing timestamps in `CaptureFrameData()` (`math.max(LastRecordedTime, curTime)`), eliminating micro-jitter and preventing recording validation rejections.
- **TAS Player Physics Decoupling:** Inhibits unmanaged `FE2_Character.startZipline` during playback to prevent competing `BodyPosition` forces from fighting TAS interpolation, while signaling FE2 client/server subsystems (`RideZipline:FireServer`, `CL_AntiSideClip.Ziplining:Fire`, `CL_MAIN_GameScript.ToggleVelocity:Fire`).
- **Authoritative Sliding & Swimming Flags:** Frame data encodes `Sliding` (bit 2) and `Swimming` (bit 3) in the binary v3 `flags` byte (and as booleans in JSON). Recording captures FE2 sliding state via `HumanoidRootPart.Size`, `Humanoid.HipHeight`, `SlideParticles`, and current animation; swimming is queried authoritatively from `CL_MAIN_GameScript.isSwimming:Invoke()` with spatial bounding box fallback. Playback in `newtasplayer.luau` applies authoritative slide and swim states without reliance on downward raycast debounces or false floor collisions, while preserving full backward compatibility for legacy recordings without flags.
- **Enhanced Animation Engine Interconnection:** Intercepts and binds to `Animate.setAnimationSpeed` across recording, playback, and savestate restoration. Pausing in creator and player freezes the current animation pose (`setAnimationSpeed(0)`) rather than playing idle over a mid-air jump, swing, or dive; resuming restores the exact authored animation speed. Animation speed is dynamically modulated during playback for walking and variable-speed actions. When savestates are restored or stepped backwards/forwards in the creator, the exact animation frame and playback speed are restored into `CurrentAnim` and the character animator.

## Capability checks

Optional quickfarm features are probed without firing remotes or installing hooks. Missing remotes, wrong remote classes, missing hook APIs and an unidentifiable escape lock produce disabled labels at startup. Each optional feature has its own failure boundary; detected payload/API changes disable that feature and update its status instead of stopping the app.

The old forced-win script cleared every boolean upvalue in the game-state function. FloodGUI only enables the patch when a boolean upvalue explicitly named `escapeLock` or `escapeLocked` can be identified and revalidated. Obfuscated or unknown layouts are marked disabled.

Smart challenge cycling uses the original description heuristics; they are not proof that a challenge is impossible. Spending estimates in the UI come from the source script (20 gems for a full boost, 50 coins for a challenge cycle), not a verified server price contract. Missing or malformed challenge data is isolated. Timed cycling is subordinate to smart cycling if both are selected.

Probes cannot prove that a server still accepts an unchanged-looking call or detect silent server-side rejection. In-game testing remains necessary after a game update. No features have been exercised against a live game during this preparation.
