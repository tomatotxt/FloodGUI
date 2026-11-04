# Native FE2 lifecycle, button tracking, and outcome confirmation

FloodGUI integrates with Flood Escape 2's native client remotes identified through reverse engineering of `CL_MAIN_GameScript`, `CL_Buttons`, and `CL_QuickInfo`.

## Round lifecycle and phase tracking

Previously, the script used coordinate thresholds (`hrp.Position.X < 50 and hrp.Position.Z > 70` for lift, and `hrp.Position.X > 50` for in-game) to guess player state. In complex maps or custom lobbies, coordinate tests can produce false positives or negatives.

FE2's client drives its state machine from `ReplicatedStorage.Remote.UpdateGameState.OnClientEvent`:
- `nil` or lobby: waiting UI hidden, lobby waters active.
- `"waiting"`: exit-lift waiting state. The client fires `AddedWaiting` and positions `HumanoidRootPart` at `Workspace.Lobby.WaitingArea.WaitTeleport.CFrame`.
- `"loading"`: map preparation.
- `"ingame"`: round active.

`gamestate.luau` tracks these transitions. `Check("InLift")` and `Check("InGame")` consult native phase state first, falling back to coordinate checks only if `UpdateGameState` is missing or has not yet fired.

## Button progress and active goal targeting

FE2's button system is coordinated across two main remotes:
- `ReplicatedStorage.Remote.UpdIngameStats.OnClientEvent`: broadcasts `stats.currentButton`, the number of buttons remaining before the exit unlocks. When `currentButton == 0`, all buttons are complete and the exit opens.
- `ReplicatedStorage.Remote.UpdGoalLocator.OnClientEvent`: broadcasts `(goal, buttonPart, locatorGui, nextGoalPart, nextLocatorGui)`. When a button is active, `buttonPart` references the current button `BasePart`.

In `StartAutoFarm`:
1. Remaining button count from `UpdIngameStats` determines whether buttons are still active. `ExitRegion` is only targeted once `currentButton == 0` (or after all scanned buttons are cleared).
2. The active button part from `UpdGoalLocator` is prioritized as the target before falling back to blind descendant scans.
3. Exit navigation sets `root.CFrame = exit.CFrame`, centering the character directly inside `ExitRegion.Size * 0.5` object space to reliably satisfy `CL_MAIN_GameScript`'s native half-bounds check (`PointToObjectSpace`).

## Server-confirmed win / escape outcome

Previously, win tracking checked `Alert.OnClientEvent` for message strings matching `"escaped"` or `"survived"`. This approach depended on localized English text and alert timing.

Authoritative round completion is signaled by `ReplicatedStorage.Remote.Survived.OnClientEvent(survived, escapeTime, runXP)`:
- `survived == true` confirms that the server verified the escape.
- `escapeTime` is the official round duration recorded by the game.

FloodGUI hooks `Survived.OnClientEvent` directly to increment `State.EscapeSerial` and display the official escape time, while retaining `Alert.OnClientEvent` as a secondary fallback.
