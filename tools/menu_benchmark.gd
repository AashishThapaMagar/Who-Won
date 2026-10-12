extends SceneTree
## Rendered navigation benchmark. Captures frame stalls as modes change.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.get_node("Settings").adaptive_quality = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(1280, 720)
	var start := Time.get_ticks_usec()
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	var load_ms := float(Time.get_ticks_usec() - start) / 1000.0
	await create_timer(1.2).timeout
	var frames: Array[float] = []
	var inputs: Array[float] = []
	var previous := Time.get_ticks_usec()
	var modes := ["story", "arcade", "ai", "local"]
	for frame in 160:
		if frame % 20 == 0:
			start = Time.get_ticks_usec()
			menu._choose_home_mode(modes[(frame / 20) % modes.size()])
			inputs.append(float(Time.get_ticks_usec() - start) / 1000.0)
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now - previous) / 1000.0)
		previous = now
	frames.sort()
	inputs.sort()
	var result := {"load_ms": load_ms, "frame_p95_ms": frames[int(frames.size() * 0.95)], "frame_max_ms": frames[-1], "selection_max_ms": inputs[-1], "resolution": "1280x720", "adapter": RenderingServer.get_video_adapter_name()}
	var output := "res://.godot/menu-benchmark.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	print("MENU_BENCHMARK: ", JSON.stringify(result))
	quit()
