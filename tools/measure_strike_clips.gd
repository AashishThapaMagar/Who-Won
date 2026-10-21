extends SceneTree
## Prints when each blow lands in a Fighting Animset Pro clip: the moments a
## fist or foot reaches out furthest from the hips (local peaks of its reach
## along the floor), with the limb and the reach. These are the numbers
## super_moves.gd "hits" and fighter_models.gd TIMING want.
##
##   godot --headless --path . -s res://tools/measure_strike_clips.gd -- KB_Superpunch KB_p_RabbitPunch
const MODELS := preload("res://scripts/fighter_models.gd")
const LIMBS := ["LeftHand", "RightHand", "LeftFoot", "RightFoot"]

func _initialize() -> void:
	for clip_name in OS.get_cmdline_user_args():
		var scene: Node = (load(MODELS.pack_file(clip_name)) as PackedScene).instantiate()
		var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var clip := player.get_animation(clip_name)
		var tracks := {}
		var positions := {}
		for track in clip.get_track_count():
			var bone := skeleton.find_bone(String(clip.track_get_path(track).get_concatenated_subnames()))
			if bone >= 0 and clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				tracks[bone] = track
			elif bone >= 0 and clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
				positions[bone] = track
		var hips := skeleton.find_bone("Hips")
		var reach := {}
		var t := 0.0
		while t <= clip.length:
			var world := {}
			for bone in skeleton.get_bone_count():
				var local := skeleton.get_bone_rest(bone)
				if tracks.has(bone):
					local.basis = Basis(clip.rotation_track_interpolate(tracks[bone], t))
				if positions.has(bone):
					local.origin = clip.position_track_interpolate(positions[bone], t)
				var parent := skeleton.get_bone_parent(bone)
				world[bone] = (world[parent] if parent >= 0 else Transform3D()) * local
			for limb in LIMBS:
				var d: Vector3 = (world[skeleton.find_bone(limb)] as Transform3D).origin - (world[hips] as Transform3D).origin
				if not reach.has(limb):
					reach[limb] = []
				reach[limb].append([snappedf(t, 0.01), Vector2(d.x, d.z).length(), d.y])
			t += 1.0 / 30.0
		print("== %s  %.2fs" % [clip_name, clip.length])
		for limb in LIMBS:
			var series: Array = reach[limb]
			var peaks := []
			for i in range(1, series.size() - 1):
				var r: float = series[i][1]
				if r >= series[i - 1][1] and r > series[i + 1][1] and r > 0.45:
					peaks.append("%.2fs %.2fm (h %.2f)" % [series[i][0], r, series[i][2]])
			if not peaks.is_empty():
				print("   %-10s %s" % [limb, ", ".join(peaks)])
		scene.free()
	quit()
