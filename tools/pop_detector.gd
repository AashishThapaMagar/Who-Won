extends SceneTree
## Finds pops: frames where a fighter's hand, foot, head or hips jumps
## further in one frame than a body moves (a snap between clips, a blend
## that cut short, a model teleporting). Runs computer-vs-computer fights and
## prints the worst jumps, with the clip before and after, grouped so the
## commonest causes come first.
##
##   godot --path . --fixed-fps 60 -s res://tools/pop_detector.gd -- <seconds per fight> [pairs like 1-6,2-3]
## (needs a window: bones are read from the drawn pose)
const BONES := ["hips", "head", "lefthand", "righthand", "leftfoot", "rightfoot"]
## Metres per frame (60 fps) beyond which a joint "pops": 0.12 m/frame is
## 7 m/s, faster than anything but the fist or foot at the peak of a strike,
## which is allowed more.
const LIMIT := {"hips": 0.08, "head": 0.12, "lefthand": 0.3, "righthand": 0.3, "leftfoot": 0.3, "rightfoot": 0.3}

var pops := []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[0]) if args.size() > 0 else 20.0
	var pairs: Array = (args[1] if args.size() > 1 else "1-6,2-3,4-5,0-6").split(",")
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = true
	root.get_node("MatchSetup").ai_difficulty = 2
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
		var last := {}
		var clips := {}
		var frames := int(seconds * 60.0)
		for frame in frames:
			await process_frame
			for fighter in [arena.player1, arena.player2]:
				var animated = fighter.get_node("Visual").get("animated")
				if animated == null or not animated.active or animated.skeleton == null:
					continue
				var key: int = fighter.get_instance_id()
				var clip: String = animated.current
				var before: String = clips.get(key, clip)
				clips[key] = clip
				if fighter.hitstop_remaining > 0.0 or fighter.combat_paused:
					last.erase(key)
					continue
				var now := {}
				for bone_key in BONES:
					var bone: int = animated._bone(bone_key)
					if bone >= 0:
						# Relative to the physics body: a jump or a knockback moving
						# the whole fighter is motion, not a pop.
						now[bone_key] = animated.skeleton.global_transform * animated.skeleton.get_bone_global_pose(bone).origin - fighter.body.global_position
				if last.has(key):
					for bone_key in now:
						var moved: float = (now[bone_key] as Vector3).distance_to(last[key][bone_key])
						if moved > LIMIT[bone_key]:
							pops.append({"id": fighter.character_profile.id, "bone": bone_key, "moved": moved,
								"state": fighter.State.find_key(fighter.state), "clip": clip.trim_prefix("files/pack_"),
								"from": before.trim_prefix("files/pack_"), "mirror": animated.mirrored})
				last[key] = now
		arena.queue_free()
		await process_frame
	var groups := {}
	for pop in pops:
		var cause: String = "%s %s: %s -> %s (%s)" % [pop.id, pop.state, pop.from, pop.clip, pop.bone] if pop.from != pop.clip else "%s %s: within %s (%s)" % [pop.id, pop.state, pop.clip, pop.bone]
		if not groups.has(cause):
			groups[cause] = [0, 0.0]
		groups[cause][0] += 1
		groups[cause][1] = maxf(groups[cause][1], pop.moved)
	var causes := groups.keys()
	causes.sort_custom(func(a, b): return groups[a][0] > groups[b][0])
	print("POPS: %d over %d fights" % [pops.size(), pairs.size()])
	for cause in causes.slice(0, 40):
		print("  %3d  max %.2fm  %s" % [groups[cause][0], groups[cause][1], cause])
	quit()
