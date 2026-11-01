# Native swimming query

The menu's TAS swim mode and the creator's auto-swim use `CL_MAIN_GameScript.isSwimming`, the game's BindableFunction queried by FE2_Character. They no longer spoof HumanoidRootPart.Position through `__index`.

The supplied decompilation assigns the callback at `55784_CL_MAIN_GameScript.LocalScript.luau:262`; it returns the game's local swimming state. FE2_Character invokes this query for movement and animation decisions, including its ToggleSwim update around line 1024. This query is distinct from the main script's internal water detection and is not a server-side swimming API.

`swimming.luau` reads the original callback using `getcallbackvalue` when supplied, with a protected direct-read fallback. Unreadable or missing callbacks are left untouched. Active requests temporarily wrap OnInvoke; inactive requests delegate to the original, preserving arguments and results. The menu request yields to active TAS engines; the creator requests swimming only while its auto-swim detection says it is in water and spoofing is not paused.

Disabling the last request restores the original callback on the next heartbeat. Invocation checks ownership immediately, so an inactive request stops overriding before that restoration. Game-script replacements are rediscovered. Cleanup restores only a callback still owned by this adapter and preserves external changes. The creator's unrelated optional Archivable hook and player's MoveDirection hook remain separate.

Tests cover true/false precedence, native delegation, capability probes without writes, unavailable callbacks, disable/unload restoration, external replacements and game-script replacement. Real executor and Roblox movement/animation behavior still need live validation; overriding the query does not recreate the game's internal water simulation.
