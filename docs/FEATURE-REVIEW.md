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
| CREATOR/fe2cm.luau | Kept separate as requested; Community Maps is not enabled. |
| Animation, UndoAnimation, ZiplineFix | Kept outside the runtime pending an explicit choice. Whole-controller animation replacement and assumed zipline upvalues can conflict with the integrated TAS engine. |

## Capability checks

Optional quickfarm features are probed without firing remotes or installing hooks. Missing remotes, wrong remote classes, missing hook APIs and an unidentifiable escape lock produce disabled labels at startup. Each optional feature has its own failure boundary; detected payload/API changes disable that feature and update its status instead of stopping the app.

The old forced-win script cleared every boolean upvalue in the game-state function. FloodGUI only enables the patch when a boolean upvalue explicitly named `escapeLock` or `escapeLocked` can be identified and revalidated. Obfuscated or unknown layouts are marked disabled.

Smart challenge cycling uses the original description heuristics; they are not proof that a challenge is impossible. Spending estimates in the UI come from the source script (20 gems for a full boost, 50 coins for a challenge cycle), not a verified server price contract. Missing or malformed challenge data is isolated. Timed cycling is subordinate to smart cycling if both are selected.

Probes cannot prove that a server still accepts an unchanged-looking call or detect silent server-side rejection. In-game testing remains necessary after a game update. No features have been exercised against a live game during this preparation.
