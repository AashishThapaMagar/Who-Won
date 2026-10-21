extends SceneTree
## Records two computer fighters going at it, to check how the fight moves.
##
##   godot --path . --write-movie fight.avi --fixed-fps 30 --always-on-top \
##     -s res://tools/record_ai_fight.gd -- <p1 index> <p2 index> <seconds> [difficulty]
## (roster indices as in the select screen; a window is needed to render)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 1
	var second := int(args[1]) if args.size() > 1 else 6
	var seconds := float(args[2]) if args.size() > 2 else 20.0
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = true
	root.get_node("MatchSetup").ai_difficulty = int(args[3]) if args.size() > 3 else 2
	var arena: Node = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.player1.apply_character(first)
	arena.player2.apply_character(second)
	var mirror = load("res://scripts/ai_controller_3d.gd").new()
	mirror.fighter = arena.player1
	mirror.opponent = arena.player2
	arena.player1.ai_controlled = true
	arena.add_child(mirror)
	await create_timer(seconds).timeout
	quit()
