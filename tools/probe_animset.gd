extends SceneTree
## Lists what the Fighting Animset Pro files hold once imported: each file's
## animations and lengths, its skeleton's bone tree and rest frame, and
## whether the clips travel on the Root bone or the hips.
##   godot --headless --path . -s res://tools/probe_animset.gd

const DIR := "res://assets/fighters/animset/"


func _init() -> void:
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".fbx"):
			continue
		var scene: Node = (load(DIR + file) as PackedScene).instantiate()
		var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var skeleton: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		print("== ", file, "  anims ", player.get_animation_list().size())
		if file == "KB_Movement.fbx":
			var node := skeleton as Node
			while node != null and node != scene:
				print("   node ", node.name, " ", (node as Node3D).transform if node is Node3D else "")
				node = node.get_parent()
			for b in skeleton.get_bone_count():
				var parent := skeleton.get_bone_parent(b)
				if b < 12 or skeleton.get_bone_name(b).contains("Leg") or skeleton.get_bone_name(b).contains("Foot"):
					print("   bone %-18s parent %-16s rest %s" % [skeleton.get_bone_name(b), skeleton.get_bone_name(parent) if parent >= 0 else "-",
						skeleton.get_bone_global_rest(b).origin.snapped(Vector3.ONE * 0.01)])
		for anim_name in player.get_animation_list():
			var anim := player.get_animation(anim_name)
			var travel := ""
			for t in anim.get_track_count():
				var bone := String(anim.track_get_path(t).get_concatenated_subnames())
				if bone in ["Root", "Hips"] and anim.track_get_type(t) == Animation.TYPE_POSITION_3D and anim.track_get_key_count(t) > 1:
					var a: Vector3 = anim.track_get_key_value(t, 0)
					var b: Vector3 = anim.track_get_key_value(t, anim.track_get_key_count(t) - 1)
					travel += "  %s %s -> %s" % [bone, a.snapped(Vector3.ONE * 0.01), b.snapped(Vector3.ONE * 0.01)]
			print("   %-36s %5.2fs%s" % [anim_name, anim.length, travel])
		scene.free()
	quit()
