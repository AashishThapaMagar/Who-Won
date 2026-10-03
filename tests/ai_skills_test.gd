extends SceneTree
## Run with: godot --headless --path . -s res://tests/ai_skills_test.gd
## The AI's skills scale with difficulty: escaping grabs, punishing whiffs,
## ground punches after its takedown, and waiting out a downed rival.
var arena: Node
var p1: Node
var p2: Node
var ai: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func reset(gap := 0.8) -> void:
	for action in ["left", "right", "block", "grapple", "punch", "kick", "far", "near"]:
		Input.action_release("p1_3d_" + action)
	arena._begin_round(0)
	arena.intro_timer = 0
	arena._hide_banner()
	p1.body.position = Vector3(-gap * 0.5, 0.02, 0)
	p2.body.position = Vector3(gap * 0.5, 0.02, 0)
	await frames(6)

func run() -> void:
	seed(1234)
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = true
	arena = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	p1 = arena.player1
	p2 = arena.player2
	ai = arena.ai_controller
	check(ai != null and p2.ai_controlled, "Versus-computer arena drives player two")
	p1.apply_character(0)
	p2.apply_character(1)
	await escapes()
	await punishes()
	await ground_punches()
	await downed_rival()
	await ai_versus_ai()
	print("AI_SKILLS_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

## Player one grabs the AI over and over; count the escapes.
func escapes() -> void:
	for level in [0, 2]:
		root.get_node("MatchSetup").ai_difficulty = level
		var escaped := 0
		var landed := 0
		for trial in 20:
			await reset(0.7)
			p1._start_style_move("grapple")
			for frame in 40:
				await frames(1)
				if p2.state == p2.State.THROWN:
					landed += 1
					break
				# Only the timed escape counts; a grab can also be stuffed by a
				# jab or stepped away from.
				if p2.combat_notice == "THROW ESCAPE":
					escaped += 1
					break
				if p1.state not in [p1.State.PUNCH, p1.State.KICK]:
					break
		if level == 0:
			check(escaped == 0 and landed >= 6, "Relaxed AI never escapes grabs (escaped %d, landed %d)" % [escaped, landed])
		else:
			check(escaped >= 3 and landed >= 2, "Challenging AI escapes some grabs, not all (escaped %d, landed %d)" % [escaped, landed])

## Player one whiffs a slow kick just inside the AI's reach.
func punishes() -> void:
	var rates := {}
	for level in [0, 2]:
		root.get_node("MatchSetup").ai_difficulty = level
		var punished := 0
		for trial in 12:
			await reset(1.45)
			var health: int = p1.health
			p1._start_style_move("kick")
			p1.current_move.reach = 4.0
			for frame in 70:
				await frames(1)
				if p1.health < health:
					punished += 1
					break
		rates[level] = punished
	check(rates[2] >= 6 and rates[2] > rates[0], "Challenging AI punishes whiffs far more than relaxed (%d vs %d of 12)" % [rates[2], rates[0]])

## The AI lands its takedown, then mounts and throws its ground punches.
func ground_punches() -> void:
	for level in [0, 1, 2]:
		root.get_node("MatchSetup").ai_difficulty = level
		await reset(0.7)
		p2.current_move = p2.available_moves().grapple
		p2.start_throw(p1, 10)
		for frame in 260:
			await frames(1)
			if p2.state != p2.State.THROWING:
				break
		check(p2.ground_hits == ai.GROUND_PUNCHES[level], "AI throws %d ground punches on difficulty %d (threw %d)" % [ai.GROUND_PUNCHES[level], level, p2.ground_hits])

## While the rival lies on the floor the AI holds off instead of swinging.
func downed_rival() -> void:
	root.get_node("MatchSetup").ai_difficulty = 1
	await reset(1.0)
	p1.state = p1.State.KNOCKDOWN
	p1.knockdown_time = 0.0
	var swung := false
	for frame in 40:
		await frames(1)
		p1.knockdown_time = 0.0
		if p2.state in [p2.State.PUNCH, p2.State.KICK]:
			swung = true
	check(not swung, "AI does not attack a downed, invulnerable rival")
	p1.state = p1.State.IDLE

## Two AIs fight a stretch of every difficulty without errors.
func ai_versus_ai() -> void:
	var mirror = load("res://scripts/ai_controller_3d.gd").new()
	mirror.fighter = p1
	mirror.opponent = p2
	p1.ai_controlled = true
	arena.add_child(mirror)
	for level in [0, 1, 2]:
		root.get_node("MatchSetup").ai_difficulty = level
		await reset(2.0)
		arena.time_remaining = 99.0
		await frames(600)
		var dealt: int = (p1.max_health - p1.health) + (p2.max_health - p2.health)
		check(dealt > 0 or not arena.round_active, "AI versus AI trades blows on difficulty %d" % level)
	mirror.queue_free()
	p1.ai_controlled = false
