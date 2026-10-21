extends SceneTree
## Every move of every fighter lands where it claims to: thrown at a
## standing rival from close in (bodies at the pushbox) and from the edge
## of its own reach (where the AI starts throwing it), it must connect.
## A move that only grazes at one of those ranges reads as a broken button.
##   godot --headless --path . -s res://tests/move_reach_test.gd [-- verbose]
var failures: Array[String] = []
## Bodies as close as the pushbox lets them stand, and the share of a
## move's reach it is tested at (a little inside the edge, as the AI uses it).
const CLOSE := 0.76
const FAR_SHARE := 0.85
## Moves thrown some other way (air, utility, the super's opener).
const SKIP := ["jump_punch", "jump_kick", "grapple"]

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	var verbose := "verbose" in OS.get_cmdline_user_args()
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = false
	var arena: Node = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var p1: Node = arena.player1
	var p2: Node = arena.player2
	for index in 7:
		p1.apply_character(index)
		p2.apply_character(0 if index != 0 else 1)
		var who: String = p1.character_profile.id
		var moves: Dictionary = p1.available_moves()
		var line := []
		for slot in moves:
			var move: Dictionary = moves[slot]
			if slot in SKIP or move.get("utility", "") != "" or move.get("air", false):
				continue
			var reach := float(move.reach) / 64.0
			for gap in [CLOSE, maxf(CLOSE, reach * FAR_SHARE)]:
				arena._begin_round(0)
				arena.intro_timer = 0
				arena._hide_banner()
				for wait in 240:
					if p1.state == p1.State.IDLE and p2.state == p2.State.IDLE:
						break
					await frames(1)
				p1.stamina = 999.0
				p1.body.position = Vector3(-gap * 0.5, 0.02, 0)
				p2.body.position = Vector3(gap * 0.5, 0.02, 0)
				await frames(4)
				p1._start_style_move(slot)
				var hit := false
				for frame in 90:
					await frames(1)
					hit = hit or p1.attack_connected
					if hit:
						break
				if not hit:
					var where := "close" if gap == CLOSE else "at %.2fm" % gap
					check(false, "%s: %s (%s) misses %s" % [who, move.name, slot, where])
				elif verbose:
					line.append("%s@%.2f" % [slot, gap])
		if verbose:
			print(who, " ok: ", ", ".join(line))
	print("MOVE_REACH_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
