# Kavo interface

FloodGUI uses the same tomatotxt Kavo fork as Flood-GUI v4beta. The window keeps its 525×318 layout, Gotham text, gray surfaces, left tabs and floating reopen button. Interface scale also fits smaller viewports.

The title-bar switch changes between blue **TAS** and red **Tools** modes. TAS contains Create & Play, Playback and Recordings. Tools contains Farming, Movement and Advanced. Maps serves both farming and recording workflows; Settings is shared and includes expandable credits. The creator and player use the same Kavo renderer and keep their own blue theme.

Switching modes changes the existing window dynamically. It does not reload code, stop automation or reset recording/playback state. Each mode remembers its last selected page, and existing controls retain values and scroll positions. Pending confirmations, key capture and held interactions are cancelled on a switch. Mode/page memory lasts until unload; feature preferences continue to follow the existing safe allowlist.

## Usability decisions

- **Progressive disclosure:** playback tuning, farm round behavior, advanced tool categories, shortcuts and credits start collapsed. The headings remain visible and expand on activation. This defers secondary detail while keeping clear entry points, following [Nielsen Norman Group's progressive-disclosure guidance](https://www.nngroup.com/articles/progressive-disclosure/).
- **Recognition and task grouping:** visible labels describe tasks rather than legacy categories such as Blatant and Other. The mode button names both the current mode and its destination; color is an additional cue. See [recognition rather than recall](https://www.nngroup.com/articles/recognition-and-recall/).
- **Visual hierarchy:** neutral section headers with narrow accent markers and muted selected-tab backgrounds reduce competing color blocks. Primary actions receive an accent outline; the Create & Play page emphasizes opening the creator.
- **Visible status:** the title keeps creator/player/farm status visible across pages and modes. Switching presentation never implies that an active engine has stopped. See [visibility of system status](https://www.nngroup.com/articles/visibility-system-status/).

These are research-informed design choices, not measured usability results for FloodGUI. Practical validation should ask users to create/save a run, find/play a recording, switch to farming and return to their previous TAS page; observe hesitation, wrong destinations and completion time.

The existing TAS engines and controllers remain in place. `ui/kavo.luau` translates their control API into the vendored fork, including silent state updates, disabled controls, refreshed file lists, fractional sliders, key capture, confirmation dialogs and notifications. Window hiding, tab changes, focus loss and unload cancel held interactions. Each window owns its input listeners and removes them on destruction.

`tests/kavo-harness.luau` executes the actual fork and adapter against a mocked Roblox environment. It checks dimensions, mode switching, tab visibility and memory, independent window themes, collapsible sections, preserved control values, native callbacks, touch sliders, input persistence, dropdown refresh, key capture, dialog cancellation and listener cleanup. The broader suite checks main-page grouping and existing creator/player behavior. A real Roblox/executor visual and gameplay check is still required; these tests do not simulate Roblox rendering or server behavior.
