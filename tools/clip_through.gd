extends SceneTree
## Finds limbs passing through the rival: in computer-vs-computer fights,
## every frame a fist, forearm, foot or shin sits deeper inside the rival's
## body than a real blow can (closer to the line of their spine, hips to
## head, than BODY_RADIUS) is counted, by fighter and move.
##
##   godot --path . --fixed-fps 60 -s res://tools/clip_through.gd -- <seconds per fight> [pairs like 1-6,2-3]
## (needs a window: bones are read from the drawn pose)
const LIMBS := ["lefthand", "righthand", "leftforearm", "rightforearm", "leftfoot", "rightfoot", "leftleg", "rightleg"]
## A torso is about 30 cm deep: a limb whose bone sits nearer the spine
## line than this is through the body, not on it.
const BODY_RADIUS := 0.1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[0]) if args.size() > 0 else 20.0
	var pairs: Array = (args[1] if args.size() > 1 else "1-6,2-3,4-5,0-6").split(",")
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = true
	root.get_node("MatchSetup").ai_difficulty = 2
	var hits := {}
	var frames_total := 0
	for pair in pairs:
		var ids: Array = pair.split("-")
		var arena: Node = load("res://scenes/Arena3D.tscn").instantiate()
		root.add_child(arena)
		current_scene = arena
		arena.player1.apply_character(int(ids[0]))
		arena.player2.apply_character(int(ids[1]))
		var mirror = load("res://scripts/ai_controller_3d.gd").new()
		mirror.fighter = arena.player1
		mirror.opponent = arena.player2
		arena.player1.ai_controlled = true
		arena.add_child(mirror)
		for frame in int(seconds * 60.0):
			await process_frame
			frames_total += 1
			for fighter in [arena.player1, arena.player2]:
				var rival: Node = fighter.opponent
				var mine = fighter.get_node("Visual").get("animated")
				var theirs = rival.get_node("Visual").get("animated")
				if mine == null or theirs == null or not mine.active or not theirs.active:
					continue
				if rival.state in [rival.State.KO, rival.State.KNOCKDOWN]:
					continue
				var hips: Vector3 = theirs.skeleton.global_transform * theirs.skeleton.get_bone_global_pose(theirs._bone("hips")).origin
				var head: Vector3 = theirs.skeleton.global_transform * theirs.skeleton.get_bone_global_pose(theirs._bone("head")).origin
				for key in LIMBS:
					var bone: int = mine._bone(key)
					if bone < 0:
						continue
					var at: Vector3 = mine.skeleton.global_transform * mine.skeleton.get_bone_global_pose(bone).origin
					var line := head - hips
					var t := clampf((at - hips).dot(line) / maxf(line.length_squared(), 0.0001), 0.0, 1.0)
					var depth := at.distance_to(hips + line * t)
					if depth < BODY_RADIUS:
						var what: String = "%s %s %s" % [fighter.character_profile.id, fighter.State.find_key(fighter.state), str(fighter.current_move.get("name", "")) if fighter.state in [fighter.State.PUNCH, fighter.State.KICK] else ""]
						hits[what] = hits.get(what, 0) + 1
						break
		arena.queue_free()
		await process_frame
	var total := 0
	for k in hits:
		total += hits[k]
	print("THROUGH: %d frames of %d (%.1f%%)" % [total, frames_total * 2, 100.0 * total / maxf(frames_total * 2, 1)])
	var keys := hits.keys()
	keys.sort_custom(func(a, b): return hits[a] > hits[b])
	for k in keys.slice(0, 25):
		print("  %4d  %s" % [hits[k], k])
	quit()
