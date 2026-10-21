extends SceneTree
## Close-ups of fighters' hands in a pose, to check fingers and fists.
##   godot --path . -s res://tools/hand_closeup.gd -- <out.png> <logical clip> <time> <ids...>
const ANIM := preload("res://scripts/fighter_animated.gd")
const MODELS := preload("res://scripts/fighter_models.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var logical: String = args[1]
	var time := float(args[2])
	var ids: Array = args.slice(3)
	root.size = Vector2i(360, 360)
	var shots: Array[Image] = []
	for id in ids:
		var world := Node3D.new()
		root.add_child(world)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.8, 0.78, 0.74)
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.7
		world.add_child(environment)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 25, 0)
		world.add_child(sun)
		var animated := ANIM.new()
		animated.config = MODELS.entry(id)
		animated.character = ANIM._load_character(animated.config.scene)
		var holder := Node3D.new()
		holder.rotation_degrees.y = 30.0
		world.add_child(holder)
		holder.add_child(animated.character)
		animated.root = holder
		var players := animated.character.find_children("*", "AnimationPlayer", true, false)
		animated.player = players[0]
		if str(animated.config.body) != "":
			animated._graft_body(animated.config.body)
		animated._add_clip_files()
		animated._resolve_clips()
		animated.skeleton = animated.character.find_children("*", "Skeleton3D", true, false)[0]
		if logical == "rest":
			animated.skeleton.reset_bone_poses()
		else:
			animated.player.play(animated.clip_names.get(logical, animated.clip_names.idle))
			animated.player.seek(time, true)
			animated.player.pause()
		await process_frame
		var hand: int = animated._bone("righthand")
		var at: Vector3 = animated.skeleton.global_transform * animated.skeleton.get_bone_global_pose(hand).origin
		var camera := Camera3D.new()
		camera.fov = 30.0
		world.add_child(camera)
		camera.global_position = at + (Vector3(0.0, 0.35, 0.25) if logical == "rest" else Vector3(0.0, 0.05, 0.55))
		camera.look_at(at)
		camera.make_current()
		root.size = Vector2i(360, 360)
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		shots.append(root.get_texture().get_image())
		world.queue_free()
		await process_frame
	var sheet := Image.create(360 * shots.size(), 360, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, 360, 360), Vector2i(i * 360, 0))
	sheet.save_png(out)
	quit()
