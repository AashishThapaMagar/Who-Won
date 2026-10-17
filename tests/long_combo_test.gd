extends SceneTree
## Long combos: a landed string carries on for up to eight blows when each
## button is pressed as the last blow connects, punches and kicks mixed,
## ending on the finisher; the rival keeps counterplay (damage scales down).
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

func tap(action: String) -> void:
	Input.action_press("p1_3d_" + action)
	await frames(1)
	Input.action_release("p1_3d_" + action)

func run() -> void:
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = false
	arena = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	p1 = arena.player1
	p2 = arena.player2
	var rhythm := ["punch", "punch", "rpunch", "punch", "kick", "rkick", "punch", "kick"]
	for index in 7:
		p1.apply_character(index)
		p2.apply_character(0 if index != 0 else 1)
		arena._begin_round(0)
		arena.intro_timer = 0
		arena._hide_banner()
		p1.body.position = Vector3(-0.4, 0.02, 0)
		p2.body.position = Vector3(0.4, 0.02, 0)
		p1.stamina = 999.0
		await frames(4)
		var step := 0
		await tap(rhythm[0])
		var best := 0
		for frame in 400:
			await frames(1)
			p1.stamina = 999.0
			best = maxi(best, p1.combo_hits)
			if step < rhythm.size() - 1 and p1.attack_connected and p1.chain_step == step \
					and p1.attack_timer >= p1.attack_startup() + p1.attack_active_time():
				step += 1
				await tap(rhythm[step])
			if step >= rhythm.size() - 1 and p1.state not in [p1.State.PUNCH, p1.State.KICK]:
				break
		check(best >= 7, "%s strings a combo of 7+ blows (got %d)" % [p1.character_profile.id, best])
		check(p2.health > 0, "%s's long combo leaves the rival standing (health %d)" % [p1.character_profile.id, p2.health])
	print("LONG_COMBO_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
