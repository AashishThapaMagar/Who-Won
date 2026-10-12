extends SceneTree
## Rendered match benchmark at 1280x720. Excludes loading and warmup.
## godot --path . -s res://tools/frame_benchmark.gd -- --output=.godot/frame-benchmark.json
var samples: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var settings := root.get_node("Settings")
	settings.adaptive_quality = false
	settings.vsync = false
	settings.fullscreen = false
	settings.touch_controls = false
	settings.quality = settings.Quality.HIGH
	settings.render_scale = settings.PRESETS[2][0]
	settings.anti_aliasing = settings.PRESETS[2][1]
	settings.shadows = settings.PRESETS[2][2]
	settings.detailed_textures = settings.PRESETS[2][3]
	settings.apply_graphics()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1280, 720)
	Engine.max_fps = 0
	var setup := root.get_node("MatchSetup")
	setup.selected_fighters.assign([2, 1])
	setup.stage_choice = 0
	setup.vs_ai = true
	setup.arcade = false
	setup.story = false
	setup.practice = false
	var arena: Node = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await create_timer(1.0).timeout
	arena.intro_timer = 0.0
	arena._hide_banner()
	var results: Array[Dictionary] = []
	for case in ["high", "medium", "low"]:
		var level: int = ["low", "medium", "high"].find(case)
		settings.quality = level
		settings.render_scale = settings.PRESETS[level][0]
		settings.anti_aliasing = settings.PRESETS[level][1]
		settings.shadows = settings.PRESETS[level][2]
		settings.detailed_textures = settings.PRESETS[level][3]
		settings.apply_graphics()
		seed(12345)
		arena._begin_round(0)
		arena.intro_timer = 0.0
		arena._hide_banner()
		await create_timer(2.0).timeout
		samples.clear()
		var previous := Time.get_ticks_usec()
		for frame in 600:
			arena.player1.health = arena.player1.max_health
			arena.player2.health = arena.player2.max_health
			if frame % 60 == 0:
				arena.player1._start_style_move("jab")
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now - previous) / 1000.0)
			previous = now
		var sum := 0.0
		for value in samples:
			sum += value
		samples.sort()
		results.append({"preset": case, "mean_ms": sum / samples.size(), "p95_ms": samples[int(samples.size() * 0.95)], "fps": 1000.0 / (sum / samples.size()), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
		print("FRAME BENCHMARK: ", JSON.stringify(results[-1]))
	var output := "res://.godot/frame-benchmark.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"resolution": "1280x720", "adapter": RenderingServer.get_video_adapter_name(), "results": results}, "  "))
	quit()
