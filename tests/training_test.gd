extends SceneTree
## Run with: godot --headless --path . -s res://tests/training_test.gd
## Practice mode's training dummy: it recovers from hits and knockdowns,
## each F2 mode does what it says, and the readout reports frame advantage
## and combo totals.
var arena: Node
var p1: Node
var p2: Node
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
	arena._reset_practice()
	p1.body.position = Vector3(-gap * 0.5, 0.02, 0)
	p2.body.position = Vector3(gap * 0.5, 0.02, 0)
	await frames(8)

## Player one's jab, from its own move list.
func jab() -> void:
	p1._start_style_move("jab")

func run() -> void:
	root.get_node("Settings").touch_controls = false
	arena = load("res://scenes/Practice3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await frames(10)
	p1 = arena.player1
	p2 = arena.player2
	# STAND: a plain dummy still recovers like a fighter.
	arena.set_dummy_mode(0)
	await reset()
	jab()
	await frames(10)
	check(p2.state == p2.State.HITSTUN, "Standing dummy takes the jab")
	await frames(60)
	check(p2.state == p2.State.IDLE, "Dummy recovers from hit-stun (state %d)" % p2.state)
	# GUARD ALL.
	arena.set_dummy_mode(1)
	await reset()
	var health: int = p2.health
	jab()
	await frames(12)
	# Guarded: at most chip damage gets through.
	check(p2.state in [p2.State.BLOCK, p2.State.BLOCKSTUN] and health - p2.health < 4, "Guard-all dummy blocks (state %d, took %d)" % [p2.state, health - p2.health])
	# GUARD AFTER FIRST HIT: the first jab lands, the next is blocked.
	arena.set_dummy_mode(2)
	await reset()
	jab()
	await frames(10)
	check(p2.state == p2.State.HITSTUN, "Guard-after-hit dummy takes the first blow")
	await frames(30)
	jab()
	await frames(12)
	check(p2.state in [p2.State.BLOCK, p2.State.BLOCKSTUN], "Guard-after-hit dummy blocks the follow-up (state %d)" % p2.state)
	# FIGHT BACK: the computer takes over and lands something.
	arena.set_dummy_mode(4)
	await reset(1.2)
	health = p1.health
	var attacked := false
	for frame in 300:
		await frames(1)
		if p2.state in [p2.State.PUNCH, p2.State.KICK]:
			attacked = true
			break
	check(attacked and p2.ai_controlled and arena.dummy_ai != null, "Fight-back dummy attacks")
	arena.set_dummy_mode(0)
	check(arena.dummy_ai == null and not p2.ai_controlled, "Leaving fight-back hands the dummy back")
	# Readout: frame advantage on every blow, combo totals from the second.
	await reset()
	jab()
	await frames(4)
	var hud: Node = arena.match_hud if "match_hud" in arena else null
	if hud == null:
		for child in arena.get_children():
			if child.get("readout") != null:
				hud = child
	check(hud != null and hud.readout != null, "Practice shows the strike readout")
	if hud != null and hud.readout != null:
		var first: String = hud.readout.text
		var sign_shown := first.contains(" +") or first.contains(" -")
		check(sign_shown, "Readout shows frame advantage (%s)" % first)
		# Chain the next punch the way a player would: pressed while the
		# first one is still connecting.
		for frame in 30:
			if p1.chain_step >= 1:
				break
			p1._buffered_action = "punch"
			p1._buffered_direction = 0
			p1._buffer_remaining = p1.input_buffer_time
			await frames(1)
		# The cross's startup at fight pace (~0.2 s) plus a margin.
		await frames(24)
		check(hud.readout.text.contains("COMBO 2 HITS"), "Readout totals the combo (%s)" % hud.readout.text)
	print("TRAINING_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
