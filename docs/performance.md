# Smooth-play settings

Medium keeps full 3D resolution, lighter arena scenery and the finishing
grade. It uses the existing contact shadows instead of rendering a shadow
map. High retains dynamic shadows and the full scenery. Low uses 75% 3D
resolution and disables shadows and the finishing grade.

Auto-adjust responds when a fight averages below 55 FPS over two seconds,
after a warmup. Shadows and render resolution change immediately. Scenery
changes wait for the next round, including matches that repeat one arena,
so auto-adjust does not rebuild the environment during an exchange. Custom
graphics settings remain under the player's control. If Low is still too
slow, auto-adjust can reduce 3D resolution to 50%.

## Measurements

Run the rendered benchmark with VSync disabled at 1280x720:

```powershell
godot --path . -s res://tools/frame_benchmark.gd
```

It measures 600 frames per preset after loading and warmup, using MAHABALI
against an AI-controlled AGASTHYA in Heritage Square. The report is written to
`.godot/frame-benchmark.json`. It does not measure input latency or loading
time, and results vary with system load and the exchange between fighters.

On Intel UHD Graphics, the previous Medium preset averaged about 60 FPS.
Two runs of the revised Medium preset averaged about 83 and 65 FPS. The
revised preset rendered about 461,000 primitives rather than 632,000 in
the earlier run. These samples show less rendering work; they do not
guarantee 60 FPS at every resolution or with every fighter.

Regression checks:

```powershell
godot --headless --path . -s res://tests/performance_settings_test.gd
godot --headless --path . --fixed-fps 60 -s res://tests/arena_3d_test.gd
```
