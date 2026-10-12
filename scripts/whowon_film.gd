extends Node
## WHO WON? — a 90-second cinematic film of the game, shot the way Akira
## Kurosawa shot: in scope (2.39:1) inside 1920x1080, long patient takes
## with a still or slowly travelling camera, long lenses from far away that
## press people against the land, weather and cloth always moving in the
## frame (kites, banners, prayer flags, butter lamps), a lateral tracking
## shot along a line of fighters as in Seven Samurai, golden-hour light, slow
## dissolves between scenes and a single wipe. No fighting: it shows the
## game: the fighters, the arenas (with the new Dashain Ground), the
## storybook and the voice studio, and closes with a Dashain greeting.
##
##   0-5    the game's own आनन्द PRESENTS card (splash.gd)
##   5-14   the sky over the ridge: an eagle glides across the snow peaks
##   14-23  the Dashain Ground: a slow track past banners and the swing
##   23-31  festival details: jamara, the tika thali, butter lamps
##   31-47  the arenas of Nepal, one still frame each
##   47-56  the story, told as a Nepali picture book
##   56-63  the voice studio: record your own voice
##   63-73  evening on the Dashain Ground: banners and swing against the sky
##   73-82  Ananta and Sarvochcha watch the sun go down (the one wipe)
##   82-90  WHO WON?  COMING SOON  विजया दशमीको शुभकामना
##
## Record: python tools/record_film.py <folder>  (frames from the 1920x1080
## canvas, sound from the movie maker, joined into an MP4).

const UI := preload("res://scripts/ui_kit.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
const STAGE := preload("res://scripts/nepal_stage_3d.gd")
const STORYBOOK := preload("res://scripts/story_book.gd")
const MUSIC := "res://assets/audio/music/game_intro_1.mp3"
const LENGTH := 90.0
const W := 1920.0
const H := 1080.0
## Scope bars: 2.39:1 inside 16:9.
const BAR := (1080.0 - 1920.0 / 2.39) / 2.0
const DASHAIN := 5
const DISSOLVE := 1.6

## [start second, shot name, transition in: "cut", "dissolve", "wipe" or "fade"].
const SHOTS := [
	[0.0, "presents", "cut"],
	[5.0, "valley", "fade"],
	[14.0, "ground", "dissolve"],
	[23.0, "details", "dissolve"],
	[31.0, "arena_0", "dissolve"],
	[34.2, "arena_1", "dissolve"],
	[37.4, "arena_2", "dissolve"],
	[40.6, "arena_3", "dissolve"],
	[43.8, "arena_4", "dissolve"],
	[47.0, "story", "dissolve"],
	[56.0, "voice", "dissolve"],
	[63.0, "evening", "dissolve"],
	[73.0, "dusk", "wipe"],
	[82.0, "title", "fade"],
]

var t := 0.0
var shot_index := -1
var shot_start := 0.0
var film: SubViewport
var world: Node3D
var camera: Camera3D
var stage: Node3D
var actors: Array = []
var cam_from: Array = []
var cam_to: Array = []
var overlay: Control
var bars: Array[ColorRect] = []
var black: ColorRect
var veil: TextureRect
var veil_clip: Control
var words: Control
var screen: SubViewport
var screen_view: TextureRect
var book: Control
var studio: Control
var music: AudioStreamPlayer
var frames_out := ""
var frame_number := 0

func _ready() -> void:
	film = SubViewport.new()
	film.size = Vector2i(int(W), int(H))
	film.own_world_3d = true
	film.msaa_3d = Viewport.MSAA_4X
	film.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(film)
	world = Node3D.new()
	film.add_child(world)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 800.0
	film.add_child(camera)
	camera.current = true
	_build_overlay()
	var window := CanvasLayer.new()
	add_child(window)
	var view := TextureRect.new()
	view.texture = film.get_texture()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	window.add_child(view)
	frames_out = OS.get_environment("FILM_FRAMES")
	if frames_out != "":
		RenderingServer.frame_post_draw.connect(_save_frame)
	if OS.has_environment("FILM_STILLS"):
		_stills.call_deferred()
		return
	music = AudioStreamPlayer.new()
	if ResourceLoader.exists(MUSIC):
		music.stream = load(MUSIC)
		music.volume_db = -2.0
		add_child(music)
		music.play()

func _save_frame() -> void:
	if t > LENGTH + 0.05:
		return
	film.get_texture().get_image().save_jpg(frames_out + "/f%05d.jpg" % frame_number, 0.92)
	frame_number += 1

func _stills() -> void:
	set_process(false)
	var out := OS.get_environment("FILM_OUT")
	for item in OS.get_environment("FILM_STILLS").split(","):
		var target := float(item)
		var index := 0
		while index + 1 < SHOTS.size() and target >= float(SHOTS[index + 1][0]):
			index += 1
		shot_index = -1
		t = float(SHOTS[index][0])
		_cut_to(index, false)
		while t < target:
			await get_tree().process_frame
			_process(1.0 / 30.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		film.get_texture().get_image().save_jpg(out + "/t%05.1f.jpg" % target, 0.88)
	get_tree().quit()

# ── Overlay ─────────────────────────────────────────────────────────────────

const GRADE_SHADER := """shader_type canvas_item;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + TIME * 0.7) * 43758.5453); }
void fragment() {
	vec2 c = UV - 0.5;
	float v = smoothstep(0.42, 0.95, length(c * vec2(1.0, 1.35)));
	float grain = hash(floor(UV * vec2(960.0, 540.0))) - 0.5;
	COLOR = vec4(vec3(0.5 + grain), max(v * 0.42, abs(grain) * 0.05));
}
"""

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	film.add_child(layer)
	overlay = Control.new()
	overlay.size = Vector2(W, H)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	# A screen for the game's own 2D pages (the studio card, the storybook,
	# the voice studio), drawn at their native 960x540.
	screen = SubViewport.new()
	screen.size = Vector2i(960, 540)
	screen.transparent_bg = false
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	overlay.add_child(screen)
	screen_view = TextureRect.new()
	screen_view.texture = screen.get_texture()
	screen_view.size = Vector2(W, H)
	screen_view.stretch_mode = TextureRect.STRETCH_SCALE
	screen_view.visible = false
	overlay.add_child(screen_view)
	var grade := ColorRect.new()
	grade.size = Vector2(W, H)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = GRADE_SHADER
	grade.material = material
	overlay.add_child(grade)
	# The held frame a dissolve or wipe leaves on: faded or swept away.
	veil_clip = Control.new()
	veil_clip.clip_contents = true
	veil_clip.size = Vector2(W, H)
	veil_clip.visible = false
	overlay.add_child(veil_clip)
	veil = TextureRect.new()
	veil.size = Vector2(W, H)
	veil_clip.add_child(veil)
	black = ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(W, H)
	black.modulate.a = 0.0
	overlay.add_child(black)
	for edge in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.size = Vector2(W, BAR)
		bar.position = Vector2(0, 0 if edge == 0 else H - BAR)
		overlay.add_child(bar)
		bars.append(bar)
	words = Control.new()
	words.size = Vector2(W, H)
	overlay.add_child(words)

## A caption: Devanagari in Yatra One or English in the book face, small
## and quiet, usually in the lower scope bar.
func _caption(text: String, y: float, size: int, appear: float, hold := 99.0, nepali := false, colour := Color("efe2c4"), spacing := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(0, y)
	label.size = Vector2(W, size * 1.7)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font: Font = UI.devanagari_font() if nepali else _book_font()
	if spacing > 0:
		var spaced := FontVariation.new()
		spaced.base_font = font
		spaced.spacing_glyph = spacing
		font = spaced
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.modulate.a = 0.0
	words.add_child(label)
	var tween := create_tween()
	tween.tween_interval(appear)
	tween.tween_property(label, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	if hold < 90.0:
		tween.tween_interval(hold)
		tween.tween_property(label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	return label

static func _book_font() -> Font:
	var path := "res://assets/fonts/TiroDevanagariHindi-Regular.ttf"
	return load(path) if ResourceLoader.exists(path) else UI.body_font()

# ── Timeline ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	t += delta
	var next := shot_index
	while next + 1 < SHOTS.size() and t >= float(SHOTS[next + 1][0]):
		next += 1
	if next != shot_index:
		_cut_to(next, true)
	_update(str(SHOTS[shot_index][1]), t - shot_start, delta)
	if is_instance_valid(stage):
		stage.animate(delta)
	if is_instance_valid(music) and t > LENGTH - 5.0:
		music.volume_db = lerpf(-2.0, -40.0, clampf((t - (LENGTH - 5.0)) / 5.0, 0.0, 1.0))
	if t >= LENGTH + 0.1:
		get_tree().quit()

func _cut_to(index: int, animate: bool) -> void:
	var how: String = SHOTS[index][2]
	if animate and shot_index >= 0 and how in ["dissolve", "wipe"]:
		veil.texture = ImageTexture.create_from_image(film.get_texture().get_image())
		veil_clip.visible = true
		veil_clip.position.x = 0.0
		veil_clip.size.x = W
		veil.position.x = 0.0
		veil_clip.modulate.a = 1.0
		var go := create_tween()
		if how == "dissolve":
			go.tween_property(veil_clip, "modulate:a", 0.0, DISSOLVE).set_trans(Tween.TRANS_SINE)
		else:
			# The one Kurosawa wipe: a hard vertical edge sweeping across.
			go.tween_method(func(x: float):
				veil_clip.position.x = x
				veil_clip.size.x = W - x
				veil.position.x = -x, 0.0, W, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		go.tween_callback(func(): veil_clip.visible = false)
	if animate and how == "fade":
		black.modulate.a = 1.0
		create_tween().tween_property(black, "modulate:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	shot_index = index
	shot_start = float(SHOTS[index][0])
	for child in words.get_children():
		child.queue_free()
	_build(str(SHOTS[index][1]))

func _clear() -> void:
	for child in world.get_children():
		child.free()
	actors.clear()
	stage = null
	for child in screen.get_children():
		child.free()
	book = null
	studio = null
	screen_view.visible = false
	cam_from = []
	for bar in bars:
		bar.visible = true

func _use_stage(round_index: int) -> void:
	stage = STAGE.new()
	world.add_child(stage)
	stage.show_round(round_index)

func _build(name: String) -> void:
	_clear()
	match name:
		"presents":
			for bar in bars:
				bar.visible = false
			var card: Control = load("res://scripts/splash.gd").new()
			card.set("_advanced", true)
			card.size = Vector2(960, 540)
			screen.add_child(card)
			screen_view.visible = true
			# The card fades itself to black at its end.
		"valley":
			_use_stage(DASHAIN)
			# Low on the ridge, a long lens raised to the sky: the peaks in the
			# haze, an eagle gliding across them. Almost still; the bird moves.
			_shot([[2.0, 1.2, 6.0], [-4.0, 13.0, -70.0], 22.0], [[2.0, 1.2, 6.0], [-3.0, 12.2, -70.0], 21.0])
			if ResourceLoader.exists("res://assets/teaser/eagle.glb"):
				var eagle: Node3D = load("res://assets/teaser/eagle.glb").instantiate()
				eagle.name = "Eagle"
				world.add_child(eagle)
			_caption("पहाडमा दशैं आयो", H - BAR + 18, 40, 1.6, 5.0, true)
			_caption("Dashain has come to the hills", H - BAR + 76, 26, 2.4, 4.2)
		"ground":
			_use_stage(DASHAIN)
			# A slow lateral track past the swing and the banners.
			_shot([[-13.0, 1.6, 2.5], [-9.0, 3.2, -11.5], 32.0], [[-6.5, 1.6, 2.5], [-3.0, 3.0, -12.0], 32.0])
			_caption("DASHAIN GROUND", H - BAR + 22, 34, 2.0, 5.0, false, Color("f2c230"), 10)
			_caption("A new arena: kites, a bamboo swing and marigolds", H - BAR + 78, 24, 2.8, 4.4)
		"details":
			_use_stage(DASHAIN)
			# Close on the festival things by the swing: jamara in clay pots,
			# the thali, a butter lamp's flame. A slow push along the table.
			_shot([[-5.5, 0.95, -8.15], [-6.4, 0.5, -9.2], 32.0], [[-5.7, 0.9, -8.35], [-6.4, 0.5, -9.2], 28.0])
			_caption("जमरा र टीका", H - BAR + 18, 40, 1.4, 5.0, true)
			_caption("Jamara and tika, the blessings of Dashain", H - BAR + 76, 26, 2.2, 4.2)
		"evening":
			_use_stage(DASHAIN)
			_dusk_light()
			# Wide and still as the sun goes: banners and the swing dark
			# against the sky, the butter lamps beginning to glow.
			_shot([[6.0, 1.3, 7.0], [-6.0, 3.0, -14.0], 34.0], [[5.4, 1.3, 6.6], [-6.0, 3.0, -14.0], 33.0])
			_caption("साँझ पर्यो", H - BAR + 18, 40, 1.6, 5.0, true)
			_caption("Evening falls on the ridge", H - BAR + 76, 26, 2.4, 4.2)
		"arena_0", "arena_1", "arena_2", "arena_3", "arena_4":
			var which := int(name.trim_prefix("arena_"))
			_use_stage(which)
			var frames := {0: [[0.0, 2.2, 9.0], [0.0, 3.0, -20.0], 30.0], 1: [[0.0, 2.0, 9.0], [0.0, 2.4, -20.0], 32.0],
				2: [[0.0, 2.0, 9.0], [0.0, 3.0, -20.0], 32.0],
				3: [[0.0, 2.0, 9.0], [0.0, 3.2, -20.0], 32.0], 4: [[0.0, 2.2, 9.0], [0.0, 3.4, -20.0], 32.0]}
			var f: Array = frames[which]
			var drift: Array = [[f[0][0] + 0.8, f[0][1], f[0][2]], f[1], f[2] - 1.0]
			_shot(f, drift)
			_caption(STAGE.ROUNDS[which].name, H - BAR + 26, 30, 0.5, 1.6, false, Color("efe2c4"), 10)
			if name == "arena_0":
				_caption("SIX ARENAS ACROSS NEPAL", BAR - 64, 28, 0.4, 13.5, false, Color("f2c230"), 10)
		"story":
			screen_view.visible = true
			book = STORYBOOK.new()
			screen.add_child(book)
			book.chapter("PROLOGUE", "THE MISSING MASTER", "The Story Of Sarvochcha", Color("a3271c"))
			book.line("", "Years ago, on a hilltop above his village, a boy named Sarvochcha trained every morning under one master.", Color.WHITE)
			book.reveal(1.0)
			book.show_plate("res://assets/story/sup/plates/prologue_01.png")
			_caption("A STORY TOLD AS A NEPALI PICTURE BOOK", H - BAR + 30, 26, 1.0, 6.0, false, Color("efe2c4"), 6)
		"voice":
			screen_view.visible = true
			var backing := ColorRect.new()
			backing.color = Color("140d0a")
			backing.size = Vector2(960, 540)
			screen.add_child(backing)
			studio = load("res://scripts/voice_studio.gd").new()
			studio.player = 0
			studio.profile = ROSTER.profile(5)
			screen.add_child(studio)
			# Never show the recording machine's own microphone name.
			if studio.mic_picker != null:
				for k in studio.mic_picker.item_count:
					studio.mic_picker.set_item_text(k, "MIC / DEFAULT")
			_caption("RECORD YOUR OWN VOICE", H - BAR + 22, 32, 1.0, 5.0, false, Color("f2c230"), 8)
			_caption("Your battle cries, taunts and victory lines, in your own voice", H - BAR + 76, 24, 1.8, 4.2)
		"dusk":
			_use_stage(DASHAIN)
			stage.force_night = false
			var student := _actor(5, Vector3(-0.5, 0.0, -24.5), Vector2(0, -1))
			var master := _actor(6, Vector3(0.5, 0.0, -24.5), Vector2(0, -1))
			_hold(student, "bow", 0.2)
			_hold(master, "taunt", 1.0)
			# Dusk: the sun low behind them, so they stand as silhouettes at
			# the ridge edge with the valley and peaks beyond.
			_dusk_light()
			_shot([[-1.6, 1.0, -14.0], [0.0, 2.2, -40.0], 24.0], [[-1.6, 1.0, -15.5], [0.0, 2.3, -40.0], 23.0])
			_caption("गुरु र चेला", H - BAR + 18, 40, 1.6, 5.0, true)
			_caption("Ananta and Sarvochcha", H - BAR + 76, 26, 2.4, 4.2)
		"title":
			for bar in bars:
				bar.visible = false
			black.modulate.a = 1.0
			var title := _caption("WHO WON?", 330, 150, 0.6, 99.0, false, Color("f4e6c4"))
			title.add_theme_font_override("font", UI.display_font())
			_caption("C O M I N G   S O O N", 560, 34, 2.2, 99.0, false, Color("e9d7b0"))
			_caption("MOBILE  ·  PC", 620, 22, 2.8, 99.0, false, Color("a89878"))
			_caption("विजया दशमीको शुभकामना", 780, 46, 3.8, 99.0, true, Color("f2c230"))
			_caption("Happy Bijaya Dashami", 850, 24, 4.4, 99.0, false, Color("e9d7b0"))
			_caption("AANANDA", 990, 20, 5.2, 99.0, false, Color("7d6d52"), 6)

func _update(name: String, local: float, delta: float) -> void:
	if not cam_from.is_empty():
		var next_start := LENGTH
		if shot_index + 1 < SHOTS.size():
			next_start = float(SHOTS[shot_index + 1][0])
		var length := next_start - shot_start
		var k := smoothstep(0.0, 1.0, clampf(local / length, 0.0, 1.0))
		if name == "fighters":
			k = clampf(local / length, 0.0, 1.0)
		var eye: Vector3 = _v(cam_from[0]).lerp(_v(cam_to[0]), k)
		var look: Vector3 = _v(cam_from[1]).lerp(_v(cam_to[1]), k)
		camera.global_position = eye
		camera.look_at(look)
		camera.fov = lerpf(cam_from[2], cam_to[2], k)
	if name == "valley":
		# The eagle glides across the peaks from right to left in a long,
		# shallow arc, banked into its turn.
		var eagle := world.get_node_or_null("Eagle") as Node3D
		if eagle != null:
			var forward := (_v(cam_from[1]) - camera.global_position).normalized()
			var right := forward.cross(Vector3.UP).normalized()
			var u := clampf((local - 0.5) / 8.5, 0.0, 1.0)
			var centre := camera.global_position + forward * 22.0
			var travel := -right
			eagle.global_position = centre + right * lerpf(9.0, -9.0, u) + Vector3.UP * (sin(u * PI) * 2.2 - 1.0) - forward * sin(u * PI) * 4.0
			eagle.rotation = Vector3(0.0, atan2(-travel.z, travel.x), 0.0)
			eagle.rotate_object_local(Vector3.RIGHT, -0.32)
			eagle.scale = Vector3.ONE * 1.25
	if name == "fighters":
		# They stand easy in their stances: breathing, shifting weight.
		for actor in actors:
			actor.visual._process(delta)
		# Each fighter's name rises as the camera reaches them.
		var x := camera.global_position.x
		for i in 7:
			var key := "named_%d" % i
			if not has_meta(key) or get_meta(key) != shot_start:
				if absf(x - (-4.5 + i * 1.5)) < 0.45:
					set_meta(key, shot_start)
					# One name at a time.
					for old in words.get_children():
						if old.has_meta("name_tag"):
							old.queue_free()
					var profile := ROSTER.profile(i)
					_caption(ROSTER.NEPALI_NAMES.get(profile.id, ""), H - BAR + 14, 40, 0.0, 0.7, true).set_meta("name_tag", true)
					_caption("  ".join(String(profile.name).split("")) + "   ·   " + String(profile.title).to_upper(), H - BAR + 72, 22, 0.15, 0.55).set_meta("name_tag", true)
	if is_instance_valid(studio) and studio.meter != null:
		# A voice being recorded: the level meter breathing.
		studio.meter.value = 35.0 + 45.0 * absf(sin(local * 7.0) * sin(local * 2.3))
	if is_instance_valid(book) and name == "story":
		for step: Array in [[3.0, "prologue_06", "...he found a letter lying at his doorstep."], [6.0, "finale_10", "Master, everything you taught me has stayed with me."]]:
			var key := "page_%s" % step[1]
			if local >= step[0] and get_meta(key, -1.0) != shot_start:
				set_meta(key, shot_start)
				book.line("SARVOCHCHA" if step[1] == "finale_10" else "", step[2], Color("2f8a86"))
				book.reveal(1.0)
				book.show_plate("res://assets/story/sup/plates/%s.png" % step[1])

## The sun low in the west behind the ridge: warm backlight, a lilac fill.
func _dusk_light() -> void:
	for sun: DirectionalLight3D in stage.find_children("*", "DirectionalLight3D", true, false):
		sun.rotation_degrees = Vector3(-5.0, 180.0, 0.0)
		sun.light_color = Color("ff9a5a")
		sun.light_energy = 1.2
	for env: WorldEnvironment in stage.find_children("*", "WorldEnvironment", true, false):
		if env.environment != null:
			env.environment.ambient_light_color = Color("6f5f86")
			env.environment.ambient_light_energy = 0.45

func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func _shot(from: Array, to: Array) -> void:
	cam_from = from
	cam_to = to

# ── Fighters ────────────────────────────────────────────────────────────────

func _actor(index: int, at: Vector3, face: Vector2) -> Dictionary:
	var fighter: Node = load("res://scenes/Player.tscn").instantiate()
	var previous: Node = fighter.get_node("Visual")
	fighter.remove_child(previous)
	previous.free()
	var visual := preload("res://scripts/fighter_visual_3d.gd").new()
	visual.name = "Visual"
	var rig := Node3D.new()
	rig.scale = Vector3.ONE / 64.0
	rig.position = at + Vector3(0, 0.02, 0)
	rig.rotation.y = atan2(-face.y, face.x)
	world.add_child(rig)
	visual.world_root = rig
	fighter.add_child(visual)
	fighter.set_physics_process(false)
	world.add_child(fighter)
	fighter.controls_enabled = false
	fighter.collision_layer = 0
	fighter.hurtbox.collision_layer = 0
	fighter.apply_character(index)
	fighter.apply_style(load("res://resources/styles/action.tres"))
	fighter._update_animation()
	visual.set_process(false)
	var actor := {"fighter": fighter, "rig": rig, "visual": visual}
	actors.append(actor)
	return actor

## Starts a clip and runs it to a moment, then holds it there: in this film
## everyone stands still and the world moves around them.
func _hold(actor: Dictionary, clip: String, at: float) -> void:
	var animated = actor.visual.get("animated")
	if animated == null or animated.player == null:
		return
	animated.pose_override = clip
	animated.replay()
	animated.player.play()
	actor.visual._process(0.016)
	var left := at
	while left > 0.0:
		actor.visual._process(minf(left, 0.1))
		left -= 0.1
