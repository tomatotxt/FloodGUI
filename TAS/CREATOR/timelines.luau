-- Native PlayTimeline spawns wall-clock tasks and can target the real player,
-- camera and remotes even for a Configuration inside a clone. The editor uses
-- its captured, seekable environment instead of dispatching those actions.
local Timelines = {}
function Timelines.bind(_map, _player, _track, _report, _isActive)
    return false, "Native action timelines are not replayed; captured map and lighting effects follow the editor clock."
end
return Timelines
