# Menu responsiveness

The home menu keeps Heritage Square loaded as one living background.
Navigation changes its camera shot, title highlight and mode description
immediately, without rebuilding a different arena for each mode. The arena
caption names the environment actually displayed.

Rows have a crimson selection panel and a gold marker. Navigation cancels
unfinished entrance and layout animations, so rapid input cannot leave
rows drifting toward stale positions. Layout settles in 160 ms, the initial
row entrance finishes in about 250 ms, and the confirmation wipe takes
250 ms before loading character select. All five play entries remain
grouped above Fighters, Records, Settings and Exit.

The background updates at 30 Hz, or 24 Hz on Low, independently of menu
controls. It uses lighter scenery and contact shadows. Low and Medium cap
the 3D background at 1280x720; text and controls keep the main viewport's
resolution. Anti-aliasing follows the player's setting. Settings panels
freeze background animation, and closing a panel restores keyboard focus.

Character select still supports stage changes. Rapid queued mode changes
are cancelled when its arena picker makes an explicit selection.

## Measurements

`tools/menu_benchmark.gd` measures synchronous scene creation, selection
handler execution and rendered frame intervals during eight mode changes.
At 1280x720 on Intel UHD Graphics, one before/after pair measured:

| Measurement | Before | After |
|---|---:|---:|
| Maximum selection-handler time | 51.0 ms | 6.1 ms |
| 95th-percentile frame interval | 893.7 ms | 43.4 ms |
| Maximum frame interval | 27,569 ms | 101 ms |
| Scene creation | 13.1 s | 10.9 s |

These samples include hardware/system-load variability and shader/resource
warming. Handler timings do not measure input-to-display latency. First
entry still loads 3D assets; this change principally removes navigation
stalls rather than making cold loading instantaneous.

```powershell
godot --path . -s res://tools/menu_benchmark.gd
godot --headless --path . -s res://tests/menu_responsiveness_test.gd
godot --headless --path . -s res://tests/door_menu_test.gd
godot --headless --path . -s res://tests/ui_flow_test.gd
```
