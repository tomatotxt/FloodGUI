# Recording translation API

New recordings save as `.fe2tomatas`. Playback automatically prefers the newest valid local binary revision, then the local JSON recording, then a recording from the live repository catalog. Existing JSON recordings are not modified. Spaces in map names are preserved.

After starting FloodGUI:

```lua
local api = getgenv().FloodGUIRecordings
local frames, metadata = api.loadMap("Blue Moon")
local savedPath = api.save("Blue Moon", frames, {
    mapName = "Blue Moon", author = "Your name", fps = 60,
})
local binaryPath = api.convertFile("Blue Moon.json", "binary")
local jsonPath = api.convertFile("Another Run.fe2tomatas", "json")
```

`save` creates a revision after the highest existing number, even when earlier revisions have been deleted or moved. Overlapping saves reserve different names. Binary saves and JSON exports read the written file back before reporting success; a failed verification reports an error and the creator retains its in-memory frames. JSON export refuses to overwrite an existing destination. The creator exposes conversion and export buttons; saves from the keyboard, touch controls and automatic exit detection all use the binary writer.

If every suitable local recording is corrupt, `loadMap` can try the matching bundled recording in online mode, including when it has the same filename. This fallback never replaces the damaged local file. `loadFile` still inspects the explicitly selected local file, so corruption remains visible. Local-only mode never uses remote fallback.

For memory-only conversion:

```lua
local codec = getgenv().FloodGUIRecordings.codec
local frames, metadata = codec.decode(bytes) -- Sniffs JSON versus FE2T
local binary = codec.encodeBinary(frames, metadata)
local json = codec.encodeJSON(frames)
local translated = codec.convert(bytes, "binary", metadata)
```

Frames retain the established JSON model: `time`, `CCFrame`, `CCameraCFrame`, `VVelocity`, optional `AAnimation` and optional `AAnimationChanged`. This is the translation boundary between the legacy recordings and the integrated creator/player. Positions and camera coordinates retain their map-relative convention.

## Binary format

All numbers use the Luau buffer API's little-endian representation. The reader accepts experimental FE2T version 2 and the extended version 3 written by this repository. Old experimental players do not understand version 3; use FloodGUI's player or export JSON.

Header: `FE2T` magic, u8 version, u8 FPS, u32 frame count, u16-prefixed UTF-8 author, u16-prefixed UTF-8 map name.

Each frame: f64 time; three f32 velocity components; seven f32 character-transform values (position XYZ, quaternion XYZW); seven f32 camera-transform values; f32 animation speed; u16-prefixed animation name. Version 3 appends a flags byte: bit 0 means the original animation field was absent; bit 1 means an f64 `AAnimationChanged` follows.

Version 3 preserves legacy animation markers that the experimental format discarded. Coordinates, rotations, velocity and animation speed use float32 precision, so conversions are numerically equivalent within that precision, not byte-for-byte JSON roundtrips. Timestamps and legacy animation markers use float64. Unknown versions, truncated buffers, unreasonable counts, invalid quaternions and non-finite values are rejected. Existing frame order is preserved.
