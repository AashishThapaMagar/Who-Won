extends SceneTree
## Bakes Story Mode's composed pictures ("plates") to images in
## assets/story/<fighter>/plates/<beat>_<line>.png, which the storybook
## shows instead of drawing the moment live. For each plate the story is
## played up to its line (so the cast stands where the story put them and
## strikes the line's pose), then the plate's own camera, light and mood
## are set, the scene is rendered large in ink and flat washes
## (storybook_look.gd) and finished as a watercolour on paper
## (shaders/storybook_plate.gdshader).
##
## The finished images are ordinary pictures: they can be opened in Krita or
## Procreate and painted over by hand, and the book shows whatever is there.
##
##   godot --path . --resolution 1280x720 -s res://tools/bake_story_plates.gd [-- <plate key> ...]

const LOOK := preload("res://scripts/storybook_look.gd")
const PLATE_SHADER := preload("res://shaders/storybook_plate.gdshader")
const SIZE := Vector2i(1600, 1200)

const DAWN := Color(1.0, 0.86, 0.66)
const MORNING := Color(1.0, 0.95, 0.84)
const DUSK := Color(1.0, 0.78, 0.72)

## Each plate: who the story is about, which beat and line, and how the
## picture is composed. "eye"/"look" are world positions, "fov" the lens,
## "sun" [pitch, yaw, colour, energy], "ambient" [colour, energy], "mood"
## the paint's tint, "paper" places the newspaper prop, "sun_disc"
## [x, y, z, radius] paints the sun into the sky, "place" moves actors for
## the picture ({actor: [x, z, face_x, face_z]}), and "poses" sets actors
## to a gesture held at a moment: {actor: [clip, seconds into it]}.
const PLATES := [
	{"key": "prologue_01", "fighter": "sup", "phase": "prologue", "line": 0,
		# Dawn on the ridge: he steps out by his house and stretches up toward
		# the sun rising over the Himalaya, seen from behind his shoulder.
		"eye": [1.3, 1.25, 3.0], "look": [-2.4, 2.1, -9.0], "fov": 44,
		"sun": [-8, 180, Color("ffb066"), 1.5], "ambient": [Color("9aa8c8"), 0.6], "mood": DAWN,
		"sun_disc": [-2.6, 4.2, -30.0, 2.2],
		"place": {"player": [-0.2, 0.6, -0.15, -1.0]},
		"poses": {"player": ["victory", 2.0]}},
	{"key": "prologue_06", "fighter": "sup", "phase": "prologue", "line": 5,
		# The wind brings the newspaper: it tumbles in big in the foreground,
		# he turns toward it on the road, prayer flags behind.
		"eye": [-3.2, 1.35, 2.6], "look": [0.2, 1.45, 0.4], "fov": 36,
		"sun": [-30, -40, Color("fff0d8"), 1.25], "ambient": [Color("b7c6d8"), 0.6], "mood": MORNING,
		"paper": {"at": [0.05, 1.6, 1.45], "turn": [35, 25, -30]},
		"poses": {"player": ["hug", 1.3]}},
	{"key": "anant_intro_03", "fighter": "sup", "phase": "anant_intro", "line": 2,
		# Guruji revealed: over Sarvochcha's shoulder, the old man standing by
		# his dummy with the sunset blazing behind him.
		"eye": [0.05, 1.62, 2.75], "look": [-2.0, 1.45, -1.4], "fov": 30,
		"sun": [-5, 180, Color("ff9558"), 1.35], "ambient": [Color("8a7fa6"), 0.6], "mood": DUSK,
		"sun_disc": [-5.2, 3.0, -16.0, 1.5]},
]

const S_OUT := "res://assets/story/%s/plates/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var only := OS.get_cmdline_user_args()
	for plate: Dictionary in PLATES:
		if not only.is_empty() and not only.has(plate.key):
			continue
		await _bake(plate)
	quit()

func _bake(plate: Dictionary) -> void:
	var setup: Node = root.get_node("MatchSetup")
	var director: Node = root.get_node("StoryDirector")
	var roster := preload("res://scripts/fighter_roster.gd")
	var index := 0
	for i in roster.PROFILES.size():
		if roster.PROFILES[i].id == plate.fighter:
			index = i
	setup.story = true
	setup.selected_fighters.assign([index, 0])
	director.start_run()
	var phase: String = plate.phase
	if phase.ends_with("_intro"):
		director.begin_intro(phase.trim_suffix("_intro"))
	elif phase.ends_with("_victory"):
		director.report_result(phase.trim_suffix("_victory"), true, false)
	elif phase == "finale":
		director.report_result("anant", true, true)
	change_scene_to_file("res://scenes/StoryDialogue.tscn")
	for i in 600:
		await process_frame
		if current_scene != null and current_scene.get("started") == true:
			break
	var d: Node = current_scene
	await create_timer(0.8).timeout
	if d.carding:
		d._end_card()
	# Play the beat up to the plate's line, so everyone ends up where the
	# story puts them (still storylines place walkers at once).
	while d.line_index < int(plate.line):
		await create_timer(0.3).timeout
		d._finish_typing()
		d._next_line()
		await create_timer(0.5 if not d.pending.is_valid() else 1.4)
	# Let the line's pose land and the picture freeze.
	for i in 80:
		await create_timer(0.1).timeout
		if d._frozen:
			break
	# The book draws its own quick picture on the freeze; let it finish
	# before taking over the view.
	await create_timer(0.5).timeout
	d.set_process(false)
	var viewport: SubViewport = d.viewport
	_compose(d, plate)
	viewport.size = SIZE
	LOOK.apply(viewport)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 4:
		await RenderingServer.frame_post_draw
	var render := viewport.get_texture().get_image()
	var finished := await _finish(render, plate)
	var folder: String = S_OUT % plate.fighter
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	finished.save_png(folder + plate.key + ".png")
	print("PLATE ", plate.key)

## The plate's camera, light and props.
func _compose(d: Node, plate: Dictionary) -> void:
	var camera: Camera3D = d.camera
	var eye: Array = plate.eye
	var look: Array = plate.look
	camera.global_position = Vector3(eye[0], eye[1], eye[2])
	camera.look_at(Vector3(look[0], look[1], look[2]))
	camera.fov = float(plate.get("fov", 36))
	var sun_spec: Array = plate.get("sun", [])
	for sun: DirectionalLight3D in d.viewport.find_children("*", "DirectionalLight3D", true, false):
		if sun_spec.size() == 4:
			sun.rotation_degrees = Vector3(sun_spec[0], sun_spec[1], 0)
			sun.light_color = sun_spec[2]
			sun.light_energy = sun_spec[3]
	var ambient: Array = plate.get("ambient", [])
	for world: WorldEnvironment in d.viewport.find_children("*", "WorldEnvironment", true, false):
		if ambient.size() == 2 and world.environment != null:
			world.environment.ambient_light_color = ambient[0]
			world.environment.ambient_light_energy = ambient[1]
	if plate.has("paper") and d.story_set != null and d.story_set.get("ball") != null:
		var paper: MeshInstance3D = d.story_set.ball
		var at: Array = plate.paper.at
		var turn: Array = plate.paper.turn
		paper.global_position = Vector3(at[0], at[1], at[2])
		paper.rotation_degrees = Vector3(turn[0], turn[1], turn[2])
		_print_newspaper(paper)
	# The village road's flat strip renders blown-out white in these
	# pictures; the earth under it reads as the path on its own.
	if d.story_set != null:
		for strip: MeshInstance3D in d.story_set.find_children("*", "MeshInstance3D", true, false):
			if strip.mesh is BoxMesh and strip.mesh.size.y < 0.05 and strip.mesh.size.x > 20.0:
				strip.visible = false
	if plate.has("sun_disc"):
		var spec: Array = plate.sun_disc
		var disc := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = spec[3]
		sphere.height = spec[3] * 2.0
		disc.mesh = sphere
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("ffc074")
		disc.material_override = glow
		disc.set_meta("storybook", true)
		disc.position = Vector3(spec[0], spec[1], spec[2])
		d.viewport.add_child(disc)
	for key in plate.get("place", {}):
		if d.actors.has(key):
			var spot: Array = plate.place[key]
			var rig: Node3D = d.actors[key].rig
			rig.position = Vector3(spot[0], rig.position.y, spot[1])
			d._face(key, [spot[2], spot[3]])
	# Gestures held at a chosen moment: the clip is started and run forward
	# to that second, then held for the picture.
	for key in plate.get("poses", {}):
		if not d.actors.has(key):
			continue
		var spec: Array = plate.poses[key]
		var visual: Node = d.actors[key].fighter.get_node("Visual")
		var animated = visual.get("animated")
		if animated == null or animated.player == null:
			continue
		animated.pose_override = spec[0]
		animated.replay()
		animated.player.play()
		visual._process(0.016)
		var left := float(spec[1])
		while left > 0.0:
			visual._process(minf(left, 0.1))
			left -= 0.1
		animated.player.pause()

## The newspaper as a printed sheet: a headline in Devanagari and English
## over columns of type, so it reads as a newspaper and not a blank board.
func _print_newspaper(paper: MeshInstance3D) -> void:
	for child in paper.get_children():
		child.queue_free()
	var page := Image.create(420, 300, false, Image.FORMAT_RGB8)
	page.fill(Color("efe8d6"))
	var ink := Color("2a2420")
	page.fill_rect(Rect2i(16, 14, 388, 4), ink)
	page.fill_rect(Rect2i(16, 72, 388, 2), ink)
	page.fill_rect(Rect2i(16, 84, 388, 46), Color("b3202a"))
	for column in 3:
		var x := 16 + column * 132
		for row in 15:
			var width := 118 - (17 * ((row * 7 + column * 3) % 5))
			page.fill_rect(Rect2i(x, 142 + row * 10, maxi(width, 60), 4), Color(0.25, 0.22, 0.2))
	page.rotate_90(CLOCKWISE)
	var sheet := StandardMaterial3D.new()
	sheet.albedo_texture = ImageTexture.create_from_image(page)
	paper.material_override = sheet
	paper.set_meta("storybook", null)
	paper.remove_meta("storybook")
	var title := Label3D.new()
	title.text = "अनन्तको बाटो"
	title.font = preload("res://scripts/ui_kit.gd").devanagari_font()
	title.font_size = 64
	title.pixel_size = 0.0011
	title.modulate = Color("2a2420")
	title.outline_size = 0
	title.rotation_degrees = Vector3(-90, 0, 0)
	title.position = Vector3(0, 0.005, -0.1)
	title.shaded = true
	paper.add_child(title)
	var road := Label3D.new()
	road.text = "THE ROAD TO ANANTA  ·  RS 5 CRORE"
	road.font_size = 32
	road.pixel_size = 0.00075
	road.modulate = Color("f4ead6")
	road.outline_size = 0
	road.rotation_degrees = Vector3(-90, 0, 0)
	road.position = Vector3(0, 0.005, -0.025)
	paper.add_child(road)

## The watercolour finish, rendered through a canvas of its own.
func _finish(render: Image, plate: Dictionary) -> Image:
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.transparent_bg = false
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(render)
	rect.size = Vector2(SIZE)
	var material := ShaderMaterial.new()
	material.shader = PLATE_SHADER
	material.set_shader_parameter("mood", plate.get("mood", MORNING))
	material.set_shader_parameter("seed", float(hash(plate.key) % 1000) / 100.0)
	rect.material = material
	canvas.add_child(rect)
	for i in 3:
		await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	canvas.queue_free()
	return image
