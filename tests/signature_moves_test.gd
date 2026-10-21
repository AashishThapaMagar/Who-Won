extends SceneTree
## Every fighter's signature moves (forward / back + 2 and 4) and crouch 2 /
## 4 start from their inputs and land, and the knockdown puts the rival on
## the floor.
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

func run() -> void:
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = false
	var arena: Node = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var p1: Node = arena.player1
	var p2: Node = arena.player2
	# [buffered action, direction, move slot]
	var inputs := [["rpunch", 1, "f_rp"], ["rpunch", -1, "b_rp"], ["rkick", 1, "f_rk"], ["rkick", -1, "b_rk"],
		["crouch_rp", 0, "crouch_rp"], ["crouch_rk", 0, "crouch_rk"]]
	for index in 7:
		p1.apply_character(index)
		p2.apply_character(0 if index != 0 else 1)
		var who: String = p1.character_profile.id
		for entry in inputs:
			arena._begin_round(0)
			arena.intro_timer = 0
			arena._hide_banner()
			# Both standing again (the knockdown before leaves the rival down).
			for wait in 240:
				if p1.state == p1.State.IDLE and p2.state == p2.State.IDLE:
					break
				await frames(1)
			p1.body.position = Vector3(-0.45, 0.02, 0)
			p2.body.position = Vector3(0.45, 0.02, 0)
			await frames(6)
			p1._buffered_action = entry[0]
			p1._buffered_direction = entry[1]
			p1._buffer_remaining = 0.2
			await frames(2)
			var expected: Dictionary = p1.available_moves()[entry[2]]
			check(p1.current_move.get("name", "") == expected.name, "%s: %s starts %s (got %s)" % [who, entry[2], expected.name, p1.current_move.get("name", "")])
			var hit := false
			var down := false
			for frame in 60:
				await frames(1)
				hit = hit or p1.attack_connected
				down = down or p2.state == p2.State.KNOCKDOWN
			check(hit, "%s: %s lands" % [who, expected.name])
			if entry[2] == "f_rk":
				check(down, "%s: %s knocks the rival down" % [who, expected.name])
	print("SIGNATURE_MOVES_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
