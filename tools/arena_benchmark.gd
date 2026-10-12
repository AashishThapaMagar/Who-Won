extends SceneTree
## Every arena on the LOW and HIGH presets: average and 95th-percentile frame
## time, and the draw calls and triangles per frame that predict how a
## phone will cope (a mid-range phone is comfortable under roughly 300 draw
## calls and 500k triangles). A real fight runs (jabs every second).
##   godot --path . --resolution 1280x720 -s res://tools/arena_benchmark.gd [-- <arena index> ...]
var samples: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var settings := root.get_node("Settings")
	settings.adaptive_quality = false
	settings.vsync = false
	settings.touch_controls = false
	Engine.max_fps = 0
	var setup := root.get_node("MatchSetup")
	setup.selected_fighters.assign([5, 6])
	setup.vs_ai = true
	setup.arcade = false
	setup.story = false
	setup.practice = false
	var stages: Array = preload("res://scripts/nepal_stage_3d.gd").ROUNDS
	var only := OS.get_cmdline_user_args()
	for index in stages.size():
		if not only.is_empty() and not only.has(str(index)):
			continue
		setup.stage_choice = index
		var arena: Node = load("res://scenes/Arena3D.tscn").instantiate()
		root.add_child(arena)
		current_scene = arena
		await create_timer(1.0).timeout
		for preset in ["low", "high"]:
			var level: int = ["low", "medium", "high"].find(preset)
			settings.quality = level
			settings.render_scale = settings.PRESETS[level][0]
			settings.anti_aliasing = settings.PRESETS[level][1]
			settings.shadows = settings.PRESETS[level][2]
			settings.detailed_textures = settings.PRESETS[level][3]
			settings.apply_graphics()
			arena._begin_round(0)
			arena.intro_timer = 0.0
			arena._hide_banner()
			await create_timer(2.0).timeout
			samples.clear()
			var draws := 0.0
			var tris := 0.0
			var previous := Time.get_ticks_usec()
			for frame in 300:
				arena.player1.health = arena.player1.max_health
				arena.player2.health = arena.player2.max_health
				if frame % 60 == 0:
					arena.player1._start_style_move("jab")
				await process_frame
				var now := Time.get_ticks_usec()
				samples.append(float(now - previous) / 1000.0)
				previous = now
				draws = maxf(draws, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				tris = maxf(tris, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			var sum := 0.0
			for value in samples:
				sum += value
			samples.sort()
			print("ARENA %-16s %-4s  %5.0f fps   p95 %5.1f ms   draw calls %4d   triangles %7d" % [stages[index].name, preset, 1000.0 / (sum / samples.size()), samples[int(samples.size() * 0.95)], draws, tris])
		arena.queue_free()
		await process_frame
	quit()
