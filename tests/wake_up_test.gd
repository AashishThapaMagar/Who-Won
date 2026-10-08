extends SceneTree
## Run with: godot --headless --path . -s res://tests/wake_up_test.gd
## Getting up from a knockdown: standing in place, rolling clear, staying
## down, rising with an attack; and a broken grab shoving both apart.
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

func release() -> void:
	for action in ["left", "right", "block", "grapple", "punch", "kick"]:
		Input.action_release("p1_3d_" + action)

func reset() -> void:
	release()
	arena._begin_round(0)
	arena.intro_timer = 0
	arena._hide_banner()
	p1.body.position = Vector3(-0.6, 0.02, 0)
	p2.body.position = Vector3(0.6, 0.02, 0)
	await frames(6)

## Knocks player one down and runs until it is up; returns [combat seconds
## spent down, metres travelled, state on the first frame up].
func knockdown(hold: String = "", tap_late: String = "") -> Array:
	await reset()
	p1.state = p1.State.KNOCKDOWN
	p1.knockdown_time = 0.0
	p1.throw_partner = null
	var start: float = p1.combat_time
	var from: Vector3 = p1.body.position
	if hold != "":
		Input.action_press("p1_3d_" + hold)
	var tapped := false
	for frame in 200:
		await frames(1)
		if tap_late != "" and not tapped and p1.state == p1.State.KNOCKDOWN and p1.knockdown_time > p1.THROW.LIE_TIME + 0.2:
			tapped = true
			Input.action_press("p1_3d_" + tap_late)
			await frames(1)
			Input.action_release("p1_3d_" + tap_late)
		if p1.state != p1.State.KNOCKDOWN:
			break
	release()
	return [p1.combat_time - start, p1.body.position.distance_to(from), p1.state]

func run() -> void:
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = false
	arena = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	p1 = arena.player1
	p2 = arena.player2
	var full: float = p1.THROW.LIE_TIME + p1.THROW.GETUP_TIME
	var stand := await knockdown()
	check(absf(stand[0] - full) < 0.1 and stand[1] < 0.05, "Standing up takes the full get-up in place (%.2fs, %.2fm)" % [stand[0], stand[1]])
	check(not p1.take_hit(10, 100, 1, p2) or p1.state != p1.State.KNOCKDOWN, "Knocked-down fighters can't be hit")
	# Player one faces right, so back is left.
	var roll := await knockdown("left")
	check(roll[0] < full - 0.4 and roll[1] > 0.8, "Holding back rolls clear and up early (%.2fs, %.2fm)" % [roll[0], roll[1]])
	var late := await knockdown("block")
	check(late[0] > full + 0.3, "Holding guard stays down longer (%.2fs)" % late[0])
	var rising := await knockdown("", "kick")
	check(rising[2] in [p1.State.PUNCH, p1.State.KICK], "An attack pressed while rising is thrown the moment the fighter is up (state %d)" % rising[2])
	print("WAKE_UP_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
