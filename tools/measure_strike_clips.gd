extends SceneTree
## Prints, for each Mixamo clip given, its length and when its striking
## hand or foot reaches furthest out in front of the hips (the impact),
## with that limb's height: the numbers fighter_models.gd timing wants.
##
##   godot --headless --path . -s res://tools/measure_strike_clips.gd -- res://a.fbx [res://b.fbx ...]

func _initialize() -> void:
	for path in OS.get_cmdline_user_args():
		_measure(path)
	quit()

func _measure(path: String) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		print(path, ": no rig")
		scene.free()
		return
	var player: AnimationPlayer = players[0]
	var skeleton: Skeleton3D = skeletons[0]
	var clip: String = ""
	for name in player.get_animation_list():
		if not String(name).to_lower().begins_with("take") or clip == "":
			clip = name
	var animation := player.get_animation(clip)
	var hips := _find(skeleton, "hips")
	var limbs := {"left_hand": _find(skeleton, "lefthand"), "right_hand": _find(skeleton, "righthand"),
		"left_foot": _find(skeleton, "leftfoot"), "right_foot": _find(skeleton, "rightfoot")}
	player.play(clip)
	var best := {"reach": -INF}
	var start_hips := Vector3.ZERO
	var steps := int(animation.length / 0.02)
	for i in steps + 1:
		var t := minf(i * 0.02, animation.length)
		_pose(skeleton, animation, t)
		var hip: Vector3 = _global(skeleton, hips).origin
		if i == 0:
			start_hips = hip
		for limb in limbs:
			var at: Vector3 = _global(skeleton, limbs[limb]).origin
			# Reach: how far out from the hips, along the floor.
			var reach := Vector2(at.x - hip.x, at.z - hip.z).length()
			if reach > best.reach:
				best = {"reach": reach, "t": t, "limb": limb, "height": at.y}
	# When the hips first sink below 85% of their opening height (a fall).
	var drop := -1.0
	var opening := _global(skeleton, hips).origin.y
	_pose(skeleton, animation, 0.0)
	opening = _global(skeleton, hips).origin.y
	for i in steps + 1:
		_pose(skeleton, animation, i * 0.02)
		if drop < 0.0 and _global(skeleton, hips).origin.y < opening * 0.85:
			drop = i * 0.02
	print("%s  hips drop=%.2f" % [path.get_file(), drop])
	_pose(skeleton, animation, 0.0)
	var ground := INF
	for limb in ["left_foot", "right_foot"]:
		ground = minf(ground, _global(skeleton, limbs[limb]).origin.y)
	print("%s  len=%.2f  impact=%.2f  limb=%s  reach=%.2f  limb_height=%.2f  hips_start=%.2f  feet=%.2f (units as imported)" % [
		path.get_file(), animation.length, best.t, best.limb, best.reach, best.height, start_hips.y, ground])
	scene.free()

## Poses the skeleton straight from the clip's bone tracks at `t`.
func _pose(skeleton: Skeleton3D, animation: Animation, t: float) -> void:
	for track in animation.get_track_count():
		var bone := skeleton.find_bone(String(animation.track_get_path(track).get_concatenated_subnames()))
		if bone < 0:
			continue
		match animation.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, animation.rotation_track_interpolate(track, t))
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone, animation.position_track_interpolate(track, t))

## A bone's pose in skeleton space, chained up from its own local pose
## (the skeleton's cached globals only refresh on a drawn frame).
func _global(skeleton: Skeleton3D, bone: int) -> Transform3D:
	var result := skeleton.get_bone_pose(bone)
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0:
		result = skeleton.get_bone_pose(parent) * result
		parent = skeleton.get_bone_parent(parent)
	return result

func _find(skeleton: Skeleton3D, key: String) -> int:
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i).to_lower()
		if name.ends_with(key) or name.ends_with(":" + key):
			return i
	return -1
