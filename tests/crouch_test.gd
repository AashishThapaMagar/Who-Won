extends SceneTree
## Crouching (S / Down): the fighter squats and holds its ground; from the
## crouch, kick sweeps and punch rises into the uppercut. A sweep is a low
## blow: a standing guard can't stop it, a crouching one can, and when it
## lands the rival goes down and gets back up.
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

func release_all() -> void:
	for player in [1, 2]:
		for action in ["punch", "kick", "rpunch", "rkick", "block", "crouch", "left", "right", "jump", "run"]:
			Input.action_release("p%d_3d_%s" % [player, action])

func reset() -> void:
	release_all()
	p1.apply_character(1)
	p2.apply_character(6)
	arena._begin_round(0)
	arena.intro_timer = 0
	arena._hide_banner()
	p1.body.position = Vector3(-0.45, 0.02, 0)
	p2.body.position = Vector3(0.45, 0.02, 0)
	await frames(4)

func tap(action: String, player := 1) -> void:
	Input.action_press("p%d_3d_%s" % [player, action])
	await frames(1)
	Input.action_release("p%d_3d_%s" % [player, action])

## Waits until `p1`'s current strike is over (or a frame cap).
func strike_out(cap := 140) -> void:
	for frame in cap:
		await frames(1)
		if p1.state not in [p1.State.PUNCH, p1.State.KICK]:
			return

func run() -> void:
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = false
	arena = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	p1 = arena.player1
	p2 = arena.player2

	# Holding down crouches, and a crouching fighter doesn't walk.
	await reset()
	Input.action_press("p1_3d_crouch")
	Input.action_press("p1_3d_left")
	var start: Vector3 = p1.body.position
	await frames(30)
	check(p1.crouching, "Holding S crouches")
	check(p1.body.position.distance_to(start) < 0.05, "A crouching fighter holds its ground (moved %.2f m)" % p1.body.position.distance_to(start))
	release_all()
	await frames(4)
	check(not p1.crouching, "Letting go of S stands back up")

	# From the crouch, kick is the sweep: it lands and puts the rival down.
	await reset()
	Input.action_press("p1_3d_crouch")
	await frames(6)
	await tap("kick")
	await frames(2)
	check(p1.current_move.get("low", false), "Crouch + kick is the sweep (got %s)" % p1.current_move.get("name", "nothing"))
	var health: int = p2.health
	var went_down := false
	for frame in 140:
		await frames(1)
		if p2.state == p2.State.KNOCKDOWN:
			went_down = true
			break
	check(went_down, "A clean sweep knocks the rival down")
	check(p2.health < health, "The sweep does damage")
	Input.action_release("p1_3d_crouch")
	var stood := false
	for frame in 200:
		await frames(1)
		if p2.state == p2.State.IDLE:
			stood = true
			break
	check(stood, "A swept fighter gets back up")
	check(not p2.swept, "Getting up clears the sweep")

	# A standing guard can't stop a sweep...
	await reset()
	Input.action_press("p2_3d_block")
	Input.action_press("p1_3d_crouch")
	await frames(6)
	await tap("kick")
	var low_hit := false
	for frame in 140:
		await frames(1)
		if p2.state in [p2.State.KNOCKDOWN, p2.State.HITSTUN]:
			low_hit = true
			break
	check(low_hit, "A sweep goes under a standing guard")
	release_all()

	# ...a crouching guard does.
	await reset()
	Input.action_press("p2_3d_block")
	Input.action_press("p2_3d_crouch")
	Input.action_press("p1_3d_crouch")
	await frames(6)
	check(p2.crouching and p2.state == p2.State.BLOCK, "Guard + down is a crouching guard")
	await tap("kick")
	var guarded := false
	for frame in 140:
		await frames(1)
		if p2.state == p2.State.BLOCKSTUN:
			guarded = true
		check(p2.state != p2.State.KNOCKDOWN, "A crouching guard stops the sweep")
		if p1.state not in [p1.State.PUNCH, p1.State.KICK] and frame > 10:
			break
	check(guarded, "The guarded sweep is blocked")
	release_all()

	# From the crouch, punch rises into the uppercut and stands up.
	await reset()
	Input.action_press("p1_3d_crouch")
	await frames(6)
	await tap("punch")
	await frames(2)
	check(p1.current_move.get("name", "") == "Rising uppercut", "Crouch + punch is the rising uppercut (got %s)" % p1.current_move.get("name", "nothing"))
	check(not p1.crouching, "The uppercut rises out of the crouch")
	await strike_out()
	release_all()

	# The AI asks for both by name.
	await reset()
	p1._buffered_action = "sweep"
	p1._buffer_remaining = p1.input_buffer_time
	await frames(2)
	check(p1.current_move.get("low", false), "The AI's sweep request starts the sweep")

	# Jump attacks: kick in the air is the flying kick, an overhead that a
	# crouching guard can't stop and a standing guard can; landing ends it.
	for guard in ["crouch", "stand"]:
		await reset()
		p1.body.position = Vector3(-1.0, 0.02, 0)
		Input.action_press("p2_3d_block")
		if guard == "crouch":
			Input.action_press("p2_3d_crouch")
		await frames(6)
		Input.action_press("p1_3d_right")
		await tap("jump")
		var kicked := false
		var outcome := ""
		for frame in 120:
			await frames(1)
			if not kicked and p1.state == p1.State.JUMP and p1.velocity.y > -300.0:
				await tap("kick")
				kicked = true
				await frames(1)
				check(p1.current_move.get("air", false), "Kick in the air is the flying kick (got %s)" % p1.current_move.get("name", "nothing"))
			if kicked and outcome == "":
				if p2.state == p2.State.HITSTUN:
					outcome = "hit"
				elif p2.state == p2.State.BLOCKSTUN:
					outcome = "blocked"
			if kicked and p1._is_grounded() and p1.state not in [p1.State.PUNCH, p1.State.KICK, p1.State.JUMP] and frame > 30:
				break
		Input.action_release("p1_3d_right")
		if guard == "crouch":
			check(outcome == "hit", "A flying kick comes down over a crouching guard (got %s)" % outcome)
		else:
			check(outcome == "blocked", "A standing guard blocks the flying kick (got %s)" % outcome)
		check(p1.state != p1.State.KICK or p1._is_grounded() == false, "Landing ends the air attack")
		release_all()
	# One air attack per jump.
	await reset()
	p2.body.position = Vector3(3.0, 0.02, 0)
	await tap("jump")
	for frame in 12:
		await frames(1)
	await tap("punch")
	await frames(2)
	var first: String = p1.current_move.get("name", "")
	check(first == "Diving fist", "Punch in the air is the diving fist (got %s)" % first)
	for frame in 40:
		await frames(1)
		if p1.state == p1.State.JUMP:
			break
	await tap("kick")
	await frames(2)
	check(p1.state == p1.State.JUMP or p1._is_grounded() or p1.current_move.get("name", "") == first, "Only one attack per jump")
	release_all()

	print("CROUCH_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
