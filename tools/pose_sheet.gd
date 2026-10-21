extends SceneTree
## Renders one fighter in a grid of poses: their stance, footwork, each
## strike frozen on the frame its blow lands, reactions and falls, to check
## the retargeted Fighting Animset Pro clips on the fighter's own body.
##
##   godot --path . -s res://tools/pose_sheet.gd -- ish [out.png]
## (needs a window: it renders, so not --headless)
const ANIM := preload("res://scripts/fighter_animated.gd")
const MODELS := preload("res://scripts/fighter_models.gd")
const MOVES := preload("res://scripts/action_moves.gd")
const COLUMNS := 8

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "ish"
	var out: String = args[1] if args.size() > 1 else "user://pose_sheet_%s.png" % id
	var poses: Array = [["idle", 0.4], ["walk", 0.25], ["walk_back", 0.25], ["crouch", 0.5], ["block", 0.3]]
	var moves: Dictionary = MOVES.for_fighter(id)
	var seen := {}
	for slot in moves:
		var clip := str(moves[slot].get("clip", ""))
		if clip != "" and not seen.has(clip):
			seen[clip] = true
			poses.append([clip, -1.0, slot])
	poses += [["hit_head", 0.3], ["hit_body", 0.3], ["hit_liver", 0.6], ["fall", 1.2], ["ko", 1.6], ["getup", 0.8], ["jump", 0.5], ["victory", 3.0]]
	# -- <id> <out> <clip>: that one clip frame by frame instead.
	if args.size() > 2:
		poses = []
		var length := float(args[3]) if args.size() > 3 else 1.2
		for i in 16:
			poses.append([args[2], length * i / 15.0, "%.2fs" % (length * i / 15.0)])
	var rows := ceili(poses.size() / float(COLUMNS))
	root.size = Vector2i(COLUMNS * 230, rows * 330)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.82, 0.8, 0.76)
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = rows * 2.4
	camera.position = Vector3((COLUMNS - 1) * 1.6 * 0.5, -(rows - 1) * 2.4 * 0.5 + 0.9, 10.0)
	world.add_child(camera)
	camera.make_current()
	var library: AnimationLibrary = null
	for i in poses.size():
		var pose: Array = poses[i]
		var animated := ANIM.new()
		animated.config = MODELS.entry(id)
		animated.character = ANIM._load_character(animated.config.scene)
		var holder := Node3D.new()
		holder.position = Vector3((i % COLUMNS) * 1.6, -(i / COLUMNS) * 2.4, 0.0)
		# Side-on to the camera, facing right like player one, turned a touch.
		holder.rotation_degrees.y = 60.0
		world.add_child(holder)
		holder.add_child(animated.character)
		animated.root = holder
		var players := animated.character.find_children("*", "AnimationPlayer", true, false)
		animated.player = players[0] if not players.is_empty() else AnimationPlayer.new()
		if players.is_empty():
			animated.character.add_child(animated.player)
		if str(animated.config.body) != "":
			animated._graft_body(animated.config.body)
		animated._add_clip_files()
		animated._resolve_clips()
		var logical: String = pose[0]
		var clip: String = animated.clip_names.get(logical, "")
		var label := Label3D.new()
		label.text = (pose[2] if pose.size() > 2 else logical) + "\n" + logical.trim_prefix("KB_")
		label.font_size = 40
		label.pixel_size = 0.004
		label.modulate = Color.BLACK
		label.position = holder.position + Vector3(0, -0.25, 0.5)
		world.add_child(label)
		if clip == "":
			continue
		var time: float = pose[1]
		if time < 0.0:
			time = float(animated.config.get("timing", {}).get(logical, [0, 0.4, 0])[1])
		animated.player.play(clip)
		animated.player.seek(minf(time, animated.player.current_animation_length - 0.01), true)
		animated.player.pause()
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("saved ", ProjectSettings.globalize_path(out))
	quit()
