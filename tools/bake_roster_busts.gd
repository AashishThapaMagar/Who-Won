extends SceneTree
## Bakes the roster cards' head-and-shoulders portraits to images
## (assets/menu/busts/bust_<id>.png): each fighter in their own guard stance
## with the arms lowered out of the frame, lit bright and warm with a cool
## rim. Run after changing a fighter's model:
##   godot --path . --resolution 1280x720 -s res://tools/bake_roster_busts.gd
const ROSTER := preload("res://scripts/fighter_roster.gd")
const OUT := "res://assets/menu/busts/"
const SIZE := 900

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var holder := Control.new()
	holder.size = Vector2(SIZE, SIZE)
	root.add_child(holder)
	for i in ROSTER.PROFILES.size():
		var portrait: TextureRect = load("res://scripts/roster_portrait.gd").new()
		portrait.index = i
		portrait.bust = true
		portrait.size = Vector2(SIZE, SIZE)
		holder.add_child(portrait)
		portrait.viewport.size = Vector2i(SIZE, SIZE)
		_relight(portrait)
		# Let the stance settle and the camera find the head.
		for f in 12:
			await process_frame
		# The portrait's loop would switch its view off again before drawing,
		# and no animation may re-pose the fighter after the arms are set.
		portrait.set_process(false)
		for player: AnimationPlayer in portrait.viewport.find_children("*", "AnimationPlayer", true, false):
			player.active = false
		_lower_arms(portrait)
		_frame_head(portrait)
		portrait.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = portrait.viewport.get_texture().get_image()
		img.save_png(OUT + "bust_%s.png" % ROSTER.profile(i).id)
		print("BUST ", ROSTER.profile(i).id)
		portrait.queue_free()
		await process_frame
	quit()

## Brighter, warmer light than the live portrait: a strong key, a soft warm
## fill from the other side and the cool rim kept for the silhouette.
func _relight(portrait: Node) -> void:
	for node in portrait.viewport.find_children("*", "WorldEnvironment", true, false):
		node.environment.ambient_light_color = Color("d8dff0")
		node.environment.ambient_light_energy = 0.8
		node.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	for light: DirectionalLight3D in portrait.viewport.find_children("*", "DirectionalLight3D", true, false):
		if light.light_color == Color("ffe5ce"):
			light.light_energy = 1.2
			light.rotation_degrees = Vector3(-24, -38, 0)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 60, 0)
	fill.light_color = Color("ffd2a8")
	fill.light_energy = 0.4
	portrait.viewport.get_child(0).add_child(fill)

## Arms hanging relaxed at the sides (out of a head-and-shoulders frame),
## instead of the guard's fist at the chin.
func _lower_arms(portrait: Node) -> void:
	var animated = portrait.fighter.get_node("Visual").animated
	if animated == null or not animated.active or animated.skeleton == null:
		return
	var sk: Skeleton3D = animated.skeleton
	for side in ["Left", "Right"]:
		var arm := _find(sk, side + "Arm")
		var fore := _find(sk, side + "ForeArm")
		var hand := _find(sk, side + "Hand")
		if arm < 0 or fore < 0:
			continue
		# Straight elbow and wrist: the rest pose is a straight arm.
		sk.set_bone_pose_rotation(fore, sk.get_bone_rest(fore).basis.get_rotation_quaternion())
		if hand >= 0:
			sk.set_bone_pose_rotation(hand, sk.get_bone_rest(hand).basis.get_rotation_quaternion())
		sk.force_update_all_bone_transforms()
		var g := sk.get_bone_global_pose(arm)
		var elbow := sk.get_bone_global_pose(fore).origin
		var now := (elbow - g.origin).normalized()
		# "Down" in the world, carried into this skeleton's own space (some
		# rigs, Vajraveer's, are turned and scaled under their parent).
		var to_local := sk.global_transform.basis.orthonormalized().inverse()
		var side_out: Vector3 = to_local * Vector3(0, 0, 1)
		var want := (to_local * Vector3.DOWN + side_out * 0.0).normalized()
		var lateral := (elbow - g.origin)
		lateral -= want * lateral.dot(want)
		want = (want + lateral.normalized() * 0.18).normalized() if lateral.length() > 0.001 else want
		var turn := Quaternion(now, want)
		g.basis = Basis(turn) * g.basis
		sk.set_bone_global_pose(arm, g)
		sk.force_update_all_bone_transforms()
		# Forearm on the same line (some rigs rest with the elbow bent).
		if hand >= 0:
			var f := sk.get_bone_global_pose(fore)
			var wrist := sk.get_bone_global_pose(hand).origin
			var lean := (wrist - f.origin).normalized()
			f.basis = Basis(Quaternion(lean, want)) * f.basis
			sk.set_bone_global_pose(fore, f)
			sk.force_update_all_bone_transforms()

## Same framing on every card: the head at the same spot and the same
## size, whatever the fighter's height or stance.
func _frame_head(portrait: Node) -> void:
	var animated = portrait.fighter.get_node("Visual").animated
	if animated == null or animated.skeleton == null:
		return
	var sk: Skeleton3D = animated.skeleton
	var head := _find(sk, "Head")
	var neck := _find(sk, "Neck")
	if head < 0:
		return
	var at: Vector3 = sk.global_transform * sk.get_bone_global_pose(head).origin
	# Models stand at their real heights, so one fixed lens on the head
	# frames every fighter the same.
	var unit := 12.0
	var camera: Camera3D = portrait.camera
	camera.size = unit * 6.4
	var target := at + Vector3(0, -unit * 0.5, 0)
	var turn := deg_to_rad(28.0)
	camera.position = target + Vector3(cos(turn) * 230, unit * 0.6, sin(turn) * 230)
	camera.look_at(target)

func _find(sk: Skeleton3D, key: String) -> int:
	for b in sk.get_bone_count():
		var name := sk.get_bone_name(b)
		if name.ends_with(key) and not name.ends_with("Fore" + key) and not (key == "Arm" and name.ends_with("ForeArm")):
			return b
	return -1
