extends SceneTree
## Run with: godot --headless --path . -s res://tests/wall_hit_test.gd
## A fighter knocked hard into an end railing slams into it: stunned a beat
## longer, rebounding, once per blow. Soft pushes and guarded hits don't.
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

## Player one strikes player two, who stands `room` metres from the wall.
## Returns how many wall hits followed within a second.
func knock(knockback: float, room: float, guard := false) -> int:
	arena._begin_round(0)
	arena.intro_timer = 0
	arena._hide_banner()
	var wall: float = p2.LANE_HALF_WIDTH - 0.05
	p2.body.position = Vector3(wall - room, 0.02, 0)
	p1.body.position = Vector3(wall - room - 0.8, 0.02, 0)
	await frames(8)
	if guard:
		p2.state = p2.State.BLOCK
		p2.block_hold_time = 1.0
	p1.state = p1.State.KICK
	p1.current_move = {"height": -70.0, "kind": "kick", "hitstun": 0.4, "blockstun": 0.12, "damage": 1.0}
	p2.take_hit(10, knockback, 1, p1, "kick")
	p1.state = p1.State.IDLE
	p1.current_move = {}
	var hits := 0
	var was := false
	for frame in 60:
		await frames(1)
		if p2._wall_hit_done and not was:
			hits += 1
			if hits == 1:
				check(p2.stun_timer > 0.3 and p2.velocity.x > 0.0, "A wall hit stretches the stun and rebounds the fighter (stun %.2f, vx %.1f)" % [p2.stun_timer, p2.velocity.x])
				check(p1.combat_notice == "WALL HIT", "The attacker is told it was a wall hit")
		was = p2._wall_hit_done
	return hits

func run() -> void:
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = false
	arena = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	p1 = arena.player1
	p2 = arena.player2
	await frames(5)
	check(await knock(420.0, 0.6) == 1, "A hard blow near the railing slams the fighter into it, once")
	check(await knock(90.0, 0.25) == 0, "A soft push into the railing is not a wall hit")
	check(await knock(420.0, 0.6, true) == 0, "A guarded blow is not a wall hit")
	check(await knock(420.0, 3.0) == 0, "A blow far from the railing never reaches it")
	print("WALL_HIT_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
