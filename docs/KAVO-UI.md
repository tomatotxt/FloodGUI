# Kavo interface

FloodGUI uses the same tomatotxt Kavo fork as Flood-GUI v4beta. The window keeps the original 525×318 layout, Gotham text, blue accent, gray surfaces, left tabs and floating reopen button. Interface scale also fits smaller viewports.

The main menu has the original six tabs. TAS groups the session controls, recording/playback launchers, maps and recording files; Auto Farm contains farming controls; Local Player contains movement controls; Blatant contains optional advanced features; Other contains preferences and unload; Credits contains attribution. The creator and player use the same Kavo renderer.

The existing TAS engines and controllers remain in place. `ui/kavo.luau` translates their control API into the vendored fork, including silent state updates, disabled controls, refreshed file lists, fractional sliders, key capture, confirmation dialogs and notifications. Window hiding, tab changes, focus loss and unload cancel held interactions. Each window owns its input listeners and removes them on destruction.

`tests/kavo-harness.luau` executes the actual fork and adapter against a mocked Roblox environment. It checks the original dimensions/theme, native control callbacks, touch sliders, input persistence, dropdown refresh, key capture, dialog cancellation and listener cleanup. The broader suite covers the existing creator, player and main controllers. A real Roblox/executor visual and gameplay check is still required; these tests do not simulate Roblox rendering or server behavior.
