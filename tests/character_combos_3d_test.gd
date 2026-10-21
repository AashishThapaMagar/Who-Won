extends SceneTree
var arena: Node
var p1: Node
var p2: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func reset(index: int) -> void:
	for player in [1, 2]:
		for action in ["punch", "kick", "grapple", "block", "left", "right", "jump"]:
			Input.action_release("p%d_3d_%s" % [player, action])
	p1.apply_character(index)
	p2.apply_character(6)
	arena._begin_round(0)
	arena.intro_timer = 0
	arena._hide_banner()
	p1.body.position = Vector3(-0.4, 0.02, 0)
	p2.body.position = Vector3(0.4, 0.02, 0)
	await frames(4)

func tap(action: String, player := 1) -> void:
	Input.action_press("p%d_3d_%s" % [player, action])
	await frames(1)
	Input.action_release("p%d_3d_%s" % [player, action])

func run() -> void:
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = false
	arena = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	p1 = arena.player1
	p2 = arena.player2
	for index in 7:
		for opener in ["punch", "kick"]:
			await reset(index)
			await tap(opener)
			var captured := false
			var stage := 0
			# Long enough for the slowest fighter's real-timed string.
			for frame in 170:
				if stage < 2 and p1.attack_connected and p1.chain_step == stage and p1.attack_timer >= p1.attack_startup():
					await tap("punch" if stage == 0 else "kick")
					stage += 1
				if "--capture" in OS.get_cmdline_user_args() and not captured and opener == "punch" and p1.chain_step == 2 and p1.attack_connected:
					captured = true
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://.godot/combo-%d.png" % index)
				await frames(1)
			check(p1.combo_hits == 3, "%s %s route lands three uninterrupted hits (got %s)" % [index, opener, p1.combo_hits])
			check(p2.health > 35, "Three-hit route leaves counterplay and health")
	await reset(1)
	Input.action_press("p2_3d_block")
	await frames(20)
	await tap("punch")
	await frames(7)
	await tap("kick")
	await frames(4)
	check(p1.chain_step == 0, "Blocked strikes do not grant a combo cancel")
	print("CHARACTER_COMBOS_3D: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
