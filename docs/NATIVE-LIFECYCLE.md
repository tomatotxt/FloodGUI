# Native FE2 lifecycle, button tracking, and outcome confirmation

FloodGUI combines physical world-zone authority with Flood Escape 2's native client remotes (`CL_MAIN_GameScript`, `CL_Buttons`, and `CL_QuickInfo`) so round transitions, lift queueing, button navigation, and escape confirmation stay synchronized across solo and public servers.

## Physical zone truth vs. UI round state

FE2's lobby, waiting lift, and active map zones occupy disjoint regions in world space:
- **Lobby:** `X < 50` and `Z <= 70`
- **Waiting lift:** `X < 50` and `Z > 70` (around `(-25, -144, 139)`)
- **Active map:** `X > 50` (spawned far from the lobby)

`ReplicatedStorage.Remote.UpdateGameState` (`gamestate.luau`) broadcasts server UI phases (`"waiting"`, `"loading"`, `"ingame"`, etc.), which apply to the round lifecycle rather than an individual character's physical position (for example, `"loading"` fires while players are still standing inside the lift, and `"ingame"` can persist for other survivors after a local reset).

Accordingly:
- `Check("InLift")` and `Check("InGame")` use `HumanoidRootPart.Position` as ground truth for the local character's location.
- Lift entry calls `AddedWaiting:FireServer()` cleanly when the character is alive in the lobby (`not Check("InLift") and not Check("InGame")`) without overwriting `HumanoidRootPart.CFrame` onto `WaitTeleport`.
- `StartAutoFarm` uses a two-stage round-start handshake:
  1. Wait for physical map arrival (`Check("InGame")`) without setting `CurrentlyFarming` prematurely (so lobby players are never locked out of joining the next lift).
  2. Wait for FE2's intro countdown to release `HumanoidRootPart.Anchored == false` before capturing spawn, collecting `_LostPage` / `_Rescue`, or moving to buttons.

## Button scanning and exit navigation

In `StartAutoFarm`:
1. **Button phase:** Scans map models (both uppercase-obfuscated and `Button*` models, plus dynamic `DescendantAdded` additions) for active `TouchInterest` + `BillboardGui` hitboxes, with an automatic `TouchInterest`-only fallback after 2.5s for no-locator map events. For each active button, it resolves the exact `TouchInterest` owner `BasePart` (`u3` in `CL_Buttons`), moves onto the hitbox, steps a single `RunService.Heartbeat` frame (eliminating the legacy `0.05s + 0.05s` jump/run sleep), and fires `ReplicatedStorage.Remote.PressedMapButton:FireServer(targetPart)` directly with `CL_Buttons`'s native `0.05s` per-part debounce. Between scans, `HumanoidRootPart.Anchored = true` with zeroed linear/angular velocity prevents `Noclip(true)` from dropping the character through the floor into the void.
2. **Exit phase:** As soon as FE2 spawns `ExitRegion` into `Map`, `StartAutoFarm` disables `Noclip(false)`, focuses `CurrentCamera.CameraSubject` on `ExitRegion`, and samples interior points via `GetRandomPointInPart(exit)` on `RunService.Heartbeat` until escape is confirmed (or returns to `initialPosition` when `PlayAfterButtons` is enabled).

## Server-confirmed win / escape outcome

Round completion is tracked redundantly via:
- `ReplicatedStorage.Remote.Survived.OnClientEvent(survived, escapeTime, runXP)` (`survived == true` records the official `escapeTime` and increments `SessionEscapes` / `EscapeSerial`).
- `ReplicatedStorage.Remote.Alert.OnClientEvent` matching `"escaped"` or `"survived"` as a secondary fallback.
