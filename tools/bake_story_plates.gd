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
const MITHILA_SHADER := preload("res://shaders/storybook_mithila.gdshader")
## The finish: "watercolour", "mithila" (the whole picture repainted in
## Mithila colours and patterns) or "mithila_frame" (the watercolour inside
## a Mithila border on lokta paper) (PLATE_STYLE in the environment
## overrides it for a run; PLATE_OUT bakes into another folder instead).
const STYLE := "mithila_frame"
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
## "chapter" is the tournament round (so the arena matches the game's),
## "stage" stages the picture in another set, "hide" leaves actors out,
## "letter" lays the sealed letter prop, and "page": "letter" draws the
## letter itself instead of a scene.
const COLD := Color(0.84, 0.88, 1.0)

## Sarvochcha's story: "THE MISSING MASTER".
const PLATES := [
	# ── Act I: the missing master ──
	{"key": "prologue_01", "fighter": "sup", "phase": "prologue", "line": 0,
		# Years ago: the boy kicks, the master guards, on the hilltop at morning.
		"eye": [-3.2, 1.1, 3.2], "look": [-0.8, 1.2, 0.0], "fov": 40,
		"sun": [-18, -37, Color("ffd9a0"), 1.4], "ambient": [Color("b8a8c0"), 0.6], "mood": MORNING,
		"place": {"player": [0.0, 0.6, -1.6, -1.2], "anant": [-1.6, -0.6, 1.6, 1.2]},
		"poses": {"player": ["kick", 1.0], "anant": ["block", 0.3]}},
	{"key": "prologue_02", "fighter": "sup", "phase": "prologue", "line": 1,
		# The master gone: the student alone by the empty dummy at dusk.
		"eye": [-3.6, 1.4, 2.6], "look": [-1.0, 1.0, -1.6], "fov": 46,
		"sun": [-6, 210, Color("ff9558"), 1.3], "ambient": [Color("8a7fa6"), 0.6], "mood": DUSK,
		"hide": ["anant"], "place": {"player": [-0.6, 0.4, -2.0, -2.8]},
		"poses": {"player": ["sob", 2.6]}},
	{"key": "prologue_03", "fighter": "sup", "phase": "prologue", "line": 2,
		# Years later: a man at his village door, looking out at the mountains.
		"eye": [1.3, 1.25, 3.0], "look": [-2.4, 2.1, -9.0], "fov": 44,
		"sun": [-8, 180, Color("ffb066"), 1.5], "ambient": [Color("9aa8c8"), 0.6], "mood": DAWN,
		"place": {"player": [-0.2, 0.6, -0.15, -1.0]},
		"poses": {"player": ["bow", 0.2]}},
	{"key": "prologue_05", "fighter": "sup", "phase": "prologue", "line": 4,
		# Making ready to leave: walking the road toward the bus shelter.
		"eye": [-1.6, 1.25, 2.8], "look": [5.5, 1.2, -0.6], "fov": 40,
		"sun": [-30, -40, Color("fff0d8"), 1.25], "ambient": [Color("b7c6d8"), 0.6], "mood": MORNING,
		"place": {"player": [2.0, 0.4, 1.0, -0.2]},
		"poses": {"player": ["walk", 0.5]}},
	{"key": "prologue_06", "fighter": "sup", "phase": "prologue", "line": 5,
		# A letter on the doorstep, seen from the ground; he looks down at it.
		"eye": [-3.8, 0.55, -2.0], "look": [-4.9, 0.35, -4.4], "fov": 52,
		"sun": [-25, -30, Color("fff0d8"), 1.25], "ambient": [Color("b7c6d8"), 0.6], "mood": MORNING,
		"place": {"player": [-5.0, -4.6, 0.3, 1.0]},
		"poses": {"player": ["bow", 2.4]},
		"letter": {"at": [-4.45, 0.03, -3.3], "turn": [0, 25, 0]}},
	{"key": "prologue_07", "fighter": "sup", "page": "letter"},
	{"key": "prologue_11", "fighter": "sup", "phase": "prologue", "line": 10,
		# He accepts: on the road, the Himalaya behind him, nodding to himself.
		"eye": [-2.4, 1.0, 2.2], "look": [0.0, 1.45, 0.3], "fov": 38,
		"sun": [-20, -60, Color("fff0d8"), 1.3], "ambient": [Color("b7c6d8"), 0.6], "mood": MORNING,
		"place": {"player": [0.0, 0.4, -1.0, 0.0]},
		"poses": {"player": ["agree", 2.6]}},
	{"key": "prologue_12", "fighter": "sup", "phase": "prologue", "line": 11,
		# Bowing to his home and his mother before he goes.
		"eye": [0.2, 1.3, 0.4], "look": [-4.8, 1.2, -5.4], "fov": 42,
		"sun": [-10, 30, Color("ffb066"), 1.4], "ambient": [Color("9aa8c8"), 0.6], "mood": DAWN,
		"place": {"player": [-3.6, -2.0, -2.4, -6.0]},
		"poses": {"player": ["bow", 2.9]}},
	# ── Act II: the fight between friends ──
	{"key": "sab_intro_01", "fighter": "sup", "phase": "sab_intro", "line": 0, "chapter": 4,
		# Two friends face each other across the arena.
		"eye": [0.0, 0.9, 4.4], "look": [0.0, 1.25, 0.0], "fov": 44, "mood": MORNING},
	{"key": "sab_intro_03", "fighter": "sup", "phase": "sab_intro", "line": 2, "chapter": 4,
		# Over Mahabali's shoulder: "do you think our master is still alive?"
		"eye": [2.3, 1.65, 1.2], "look": [-1.15, 1.5, 0.0], "fov": 30, "mood": MORNING,
		"poses": {"player": ["agree", 2.6]}},
	{"key": "sab_intro_06", "fighter": "sup", "phase": "sab_intro", "line": 5, "chapter": 4,
		# Neither can afford to lose: low between their raised guards.
		"eye": [0.0, 0.8, 2.7], "look": [0.0, 1.45, 0.0], "fov": 48, "mood": MORNING},
	{"key": "sab_victory_01", "fighter": "sup", "phase": "sab_victory", "line": 0, "chapter": 4,
		# Mahabali struggles to rise; Sarvochcha stands over him.
		"eye": [2.6, 0.6, 1.8], "look": [0.0, 0.8, 0.0], "fov": 40, "mood": MORNING,
		"poses": {"rival": ["injured", 0.5], "player": ["bow", 0.2]}},
	{"key": "sab_victory_03", "fighter": "sup", "phase": "sab_victory", "line": 2, "chapter": 4,
		# He walks on; his friend lies behind him.
		"eye": [2.8, 0.9, 1.6], "look": [-2.4, 1.0, -0.9], "fov": 40, "mood": MORNING,
		"place": {"player": [-2.6, -0.9, -1.0, -0.4]},
		"poses": {"rival": ["ko", 1.6], "player": ["walk", 0.5]}},
	# ── Act III: the final revelation ──
	{"key": "anant_intro_01", "fighter": "sup", "phase": "anant_intro", "line": 0, "chapter": 5,
		# The final opponent walks in; Sarvochcha's back in the foreground.
		"eye": [-2.8, 1.5, 1.3], "look": [1.8, 1.4, -0.5], "fov": 34, "mood": DUSK,
		"place": {"rival": [2.6, -0.6, -1.0, 0.2]},
		"poses": {"rival": ["walk", 0.4]}},
	{"key": "anant_intro_03", "fighter": "sup", "phase": "anant_intro", "line": 2, "chapter": 5,
		# "MASTER?!"
		"eye": [0.35, 1.6, 0.95], "look": [-1.15, 1.58, 0.0], "fov": 30, "mood": DUSK,
		"poses": {"player": ["angry", 0.9]}},
	{"key": "anant_intro_04", "fighter": "sup", "phase": "anant_intro", "line": 3, "chapter": 5,
		# Ananta says nothing and raises his guard: low, looking up at him.
		"eye": [-0.1, 0.85, 1.15], "look": [1.15, 1.62, 0.0], "fov": 34, "mood": DUSK},
	{"key": "finale_01", "fighter": "sup", "phase": "finale", "line": 0,
		# The master sits defeated; his student stands over him.
		"eye": [-2.2, 1.4, 2.4], "look": [0.6, 0.7, 0.0], "fov": 40, "mood": DUSK,
		"place": {"player": [-0.6, 0.2, 1.0, 0.0], "anant": [0.9, -0.1, -1.0, 0.0]},
		"poses": {"anant": ["getup", 1.2], "player": ["bow", 0.2]}},
	{"key": "finale_03", "fighter": "sup", "phase": "finale", "line": 2,
		# Memory: the master beaten in an international final, alone on the canvas.
		"eye": [2.2, 2.6, 2.6], "look": [0.0, 0.3, 0.0], "fov": 40, "mood": COLD,
		"hide": ["player"], "place": {"anant": [0.0, 0.0, 1.0, 0.3]},
		"poses": {"anant": ["ko", 2.5]}},
	{"key": "finale_05", "fighter": "sup", "phase": "finale", "line": 4, "stage": "ananta_ground",
		# Memory: hiding in a remote village, sitting alone on a hilltop.
		"eye": [3.4, 1.2, 3.4], "look": [-0.7, 1.0, -2.0], "fov": 42,
		"sun": [-6, 210, Color("ff9558"), 1.3], "ambient": [Color("8a7fa6"), 0.6], "mood": DUSK,
		"hide": ["player", "rival"], "place": {"anant": [1.4, -0.9, -1.0, -0.6]},
		"poses": {"anant": ["getup", 1.2]}},
	{"key": "finale_10", "fighter": "sup", "phase": "finale", "line": 9,
		# "Everything you taught me has stayed with me": the student bows.
		"eye": [0.1, 1.3, 2.6], "look": [0.0, 1.1, 0.0], "fov": 40, "mood": DUSK,
		"place": {"player": [-0.7, 0.2, 1.0, 0.0], "anant": [0.8, 0.0, -1.0, 0.0]},
		"poses": {"player": ["bow", 2.9], "anant": ["taunt", 1.0]}},
	{"key": "finale_15", "fighter": "sup", "phase": "finale", "line": 14,
		# Teacher and disciple, side by side, looking out together.
		"eye": [0.0, 1.15, 3.6], "look": [0.0, 1.7, -8.0], "fov": 44, "mood": DUSK,
		"place": {"player": [-0.45, 0.4, 0.0, -1.0], "anant": [0.45, 0.4, 0.0, -1.0]},
		"poses": {"player": ["bow", 0.2], "anant": ["taunt", 1.0]}},
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
	if plate.get("page", "") == "letter":
		var page := await _letter_page()
		var drawn := await _finish(page, plate, "frame_only")
		var out: String = OS.get_environment("PLATE_OUT") if OS.has_environment("PLATE_OUT") else S_OUT % plate.fighter
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
		drawn.save_png(out + plate.key + ".png")
		print("PLATE ", plate.key)
		return
	setup.arcade_index = int(plate.get("chapter", 0))
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
	if plate.has("stage"):
		d._use_set(plate.stage, 0)
		await process_frame
		await process_frame
	var style: String = OS.get_environment("PLATE_STYLE") if OS.has_environment("PLATE_STYLE") else plate.get("style", STYLE)
	_compose(d, plate)
	viewport.size = SIZE
	LOOK.apply(viewport, "mithila" if style == "mithila" else "wash")
	if style == "mithila":
		# Mithila paintings sit on bare paper: no sky, fog or film curve.
		for world: WorldEnvironment in viewport.find_children("*", "WorldEnvironment", true, false):
			var env := world.environment
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.93, 0.86, 0.72)
			env.fog_enabled = false
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 4:
		await RenderingServer.frame_post_draw
	var render := viewport.get_texture().get_image()
	var finished := await _finish(render, plate, style)
	var folder: String = OS.get_environment("PLATE_OUT") if OS.has_environment("PLATE_OUT") else S_OUT % plate.fighter
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
		disc.set_meta("storybook", "keep")
		disc.position = Vector3(spec[0], spec[1], spec[2])
		d.viewport.add_child(disc)
	for key in plate.get("hide", []):
		if d.actors.has(key):
			d.actors[key].rig.visible = false
	if plate.has("letter"):
		_lay_letter(d, plate.letter)
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

## The sealed letter on the doorstep: a cream envelope with a red seal.
func _lay_letter(d: Node, spec: Dictionary) -> void:
	var page := Image.create(260, 180, false, Image.FORMAT_RGB8)
	page.fill(Color("efe6cf"))
	var ink := Color("7a5a3a")
	for i in 3:
		page.fill_rect(Rect2i(8 + i, 8 + i, 244 - i * 2, 1), ink)
		page.fill_rect(Rect2i(8 + i, 171 - i, 244 - i * 2, 1), ink)
		page.fill_rect(Rect2i(8 + i, 8 + i, 1, 164 - i * 2), ink)
		page.fill_rect(Rect2i(251 - i, 8 + i, 1, 164 - i * 2), ink)
	for y in 180:
		for x in 260:
			if Vector2(x - 130, y - 90).length() < 26.0:
				page.set_pixel(x, y, Color("a3271c"))
	var sheet := StandardMaterial3D.new()
	sheet.albedo_texture = ImageTexture.create_from_image(page)
	var letter := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.26, 0.006, 0.18)
	letter.mesh = box
	letter.material_override = sheet
	var at: Array = spec.at
	var turn: Array = spec.turn
	letter.position = Vector3(at[0], at[1], at[2])
	letter.rotation_degrees = Vector3(turn[0], turn[1], turn[2])
	d.viewport.add_child(letter)

## The letter itself, drawn flat: the word ANANTA at the top, the
## invitation, and the six names, on lokta paper with a red seal.
func _letter_page() -> Image:
	const UI := preload("res://scripts/ui_kit.gd")
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var desk := ColorRect.new()
	desk.color = Color("e9dcbc")
	desk.size = Vector2(SIZE)
	canvas.add_child(desk)
	var sheet := ColorRect.new()
	sheet.color = Color("f3ead2")
	sheet.position = Vector2(300, 150)
	sheet.size = Vector2(1000, 900)
	sheet.rotation_degrees = -2.0
	canvas.add_child(sheet)
	var book_font: Font = load("res://assets/fonts/TiroDevanagariHindi-Regular.ttf")
	var italic: Font = load("res://assets/fonts/TiroDevanagariHindi-Italic.ttf")
	var lines := [
		["अनन्त", UI.devanagari_font(), 120, Color("a3271c"), 40],
		["A N A N T A", UI.strong_font(), 34, Color("2e2118"), 190],
		["You are summoned to a tournament of masters.", book_font, 36, Color("2e2118"), 290],
		["The strongest shall claim a reward of NPR 5 crore.", book_font, 36, Color("2e2118"), 345],
		["But money is not the only prize.", italic, 36, Color("5a4636"), 400],
		["The final victor shall discover", italic, 40, Color("2e2118"), 470],
		["the whereabouts of the missing Master.", italic, 40, Color("2e2118"), 520],
		["AGASTHYA   ·   MAHABALI   ·   KRI", UI.strong_font(), 34, Color("5a4636"), 640],
		["VAJRAVEER   ·   ANUG   ·   SARVOCHCHA", UI.strong_font(), 34, Color("5a4636"), 695],
	]
	for spec in lines:
		var label := Label.new()
		label.text = spec[0]
		label.add_theme_font_override("font", spec[1])
		label.add_theme_font_size_override("font_size", spec[2])
		label.add_theme_color_override("font_color", spec[3])
		label.position = Vector2(0, spec[4])
		label.size = Vector2(1000, spec[2] + 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sheet.add_child(label)
	var rule := ColorRect.new()
	rule.color = Color("b07a2a")
	rule.position = Vector2(300, 600)
	rule.size = Vector2(400, 3)
	sheet.add_child(rule)
	var seal := Label.new()
	seal.text = "●"
	seal.add_theme_font_size_override("font_size", 150)
	seal.add_theme_color_override("font_color", Color("a3271c"))
	seal.position = Vector2(780, 700)
	sheet.add_child(seal)
	for i in 3:
		await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	canvas.queue_free()
	return image

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
func _finish(render: Image, plate: Dictionary, style: String) -> Image:
	if style == "frame_only":
		return await _frame(render, plate)
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.transparent_bg = false
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(render)
	rect.size = Vector2(SIZE)
	var material := ShaderMaterial.new()
	material.shader = MITHILA_SHADER if style == "mithila" else PLATE_SHADER
	material.set_shader_parameter("mood", plate.get("mood", MORNING))
	material.set_shader_parameter("seed", float(hash(plate.key) % 1000) / 100.0)
	rect.material = material
	canvas.add_child(rect)
	for i in 3:
		await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	canvas.queue_free()
	if style == "mithila_frame":
		image = await _frame(image, plate)
	return image

## The Mithila border on lokta paper around a finished picture.
func _frame(image: Image, plate: Dictionary) -> Image:
	var frame := SubViewport.new()
	frame.size = SIZE
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(frame)
	var framed := TextureRect.new()
	framed.texture = ImageTexture.create_from_image(image)
	framed.size = Vector2(SIZE)
	var border := ShaderMaterial.new()
	border.shader = MITHILA_SHADER
	border.set_shader_parameter("frame_only", true)
	border.set_shader_parameter("seed", float(hash(plate.key) % 1000) / 100.0)
	framed.material = border
	frame.add_child(framed)
	for i in 3:
		await RenderingServer.frame_post_draw
	image = frame.get_texture().get_image()
	frame.queue_free()
	return image
