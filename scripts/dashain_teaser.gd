extends Node
## WHO WON? — the Dashain teaser: a one-minute vertical short (1080x1920)
## shot in the manner of Akira Kurosawa: long telephoto lenses that press
## figures against the land, weather that never stops moving (wind, kites,
## dust, rain), still frontal frames with movement inside them, the rain
## battle of Seven Samurai, a line of fighters standing in the wind, and
## his hard wipes from scene to scene.
##
## Dashain, Nepal's great autumn festival, celebrates the victory of good
## over evil; families gather, kites fill the sky, bamboo swings (linge
## ping) go up in every village, and elders press red tika and jamara on
## the young. The teaser carries the game's story into it: six students of
## one vanished master, and a tournament this Dashain.
##
##   0-5    आनन्द PRESENTS: the game's own studio card (splash.gd)
##   5-12   kites over the ridge at dawn: दशैं / DASHAIN
##   12-18  a linge ping against the sky
##   18-25  tika: Sarvochcha bows to his master over the thali
##   25-28  THIS DASHAIN...
##   28-40  slow-motion strikes in the rain, Heritage Square at night
##   40-46  six students in a line, wind and dust at the gompa
##   46-52  one master, lit by lightning: अनन्त
##   52-60  WHO WON?  COMING SOON  विजया दशमीको शुभकामना
##
## The film is drawn into a 1080x1920 canvas of its own (any monitor can
## show it scaled down). Record it with tools/record_teaser.py: the movie
## maker captures the sound, and TEASER_FRAMES saves every full-size frame.

const UI := preload("res://scripts/ui_kit.gd")
const STAGE := preload("res://scripts/nepal_stage_3d.gd")
const SETS := preload("res://scripts/story_sets.gd")
const MUSIC := "res://assets/audio/music/game_intro_1.mp3"
const LENGTH := 60.0
const W := 1080.0
const H := 1920.0
## Roster indices.
const ANUG := 0
const AGASTHYA := 1
const MAHABALI := 2
const VAJRAVEER := 3
const KRI := 4
const SARVOCHCHA := 5
const ANANTA := 6

## [start second, shot name, wipe in].
const SHOTS := [
	[0.0, "presents", false],
	[5.0, "kites", false],
	[12.0, "ping", true],
	[18.0, "tika", true],
	[25.0, "this_dashain", false],
	[28.0, "rain_1", false],
	[31.0, "rain_2", false],
	[34.0, "rain_3", false],
	[37.0, "rain_4", false],
	[40.0, "lineup", true],
	[46.0, "master", false],
	[52.0, "title", false],
]

var t := 0.0
## The 1080x1920 canvas the film is drawn in.
var film: SubViewport
var frames_out := ""
var frame_number := 0
var shot_index := -1
var shot_start := 0.0
var world: Node3D
var camera: Camera3D
var place: Node3D
var actors: Array = []
var kites: Array = []
var lightning: DirectionalLight3D
var cam_from: Array = []
var cam_to: Array = []

var overlay: Control
var rain: ColorRect
var dust: ColorRect
var flash: ColorRect
var black: ColorRect
var texts: Control
var wipe_clip: Control
var wipe_image: TextureRect

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
	camera.far = 600.0
	film.add_child(camera)
	camera.current = true
	_build_overlay()
	# The window shows the film scaled to fit.
	var screen := CanvasLayer.new()
	add_child(screen)
	var view := TextureRect.new()
	view.texture = film.get_texture()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screen.add_child(view)
	frames_out = OS.get_environment("TEASER_FRAMES")
	if frames_out != "":
		RenderingServer.frame_post_draw.connect(_save_frame)
	# Stills for reviewing shots: TEASER_STILLS="6,14,20" saves a frame at
	# each of those seconds (TEASER_OUT folder) and quits.
	if OS.has_environment("TEASER_STILLS"):
		_stills.call_deferred()
		return
	var music := AudioStreamPlayer.new()
	if ResourceLoader.exists(MUSIC):
		music.stream = load(MUSIC)
		music.volume_db = -3.0
		add_child(music)
		music.play()

func _save_frame() -> void:
	if t > LENGTH + 0.1:
		return
	film.get_texture().get_image().save_jpg(frames_out + "/f%05d.jpg" % frame_number, 0.92)
	frame_number += 1

func _stills() -> void:
	set_process(false)
	var out := OS.get_environment("TEASER_OUT")
	for item in OS.get_environment("TEASER_STILLS").split(","):
		var target := float(item)
		var index := 0
		while index + 1 < SHOTS.size() and target >= float(SHOTS[index + 1][0]):
			index += 1
		shot_index = -1
		t = float(SHOTS[index][0])
		_cut_to(index)
		while t < target:
			await get_tree().process_frame
			_process(1.0 / 30.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		film.get_texture().get_image().save_jpg(out + "/t%05.1f.jpg" % target, 0.85)
	get_tree().quit()

# ── Overlay: weather, wipes, words ──────────────────────────────────────────

const RAIN_SHADER := """shader_type canvas_item;
float hash(float n) { return fract(sin(n * 91.3458) * 47453.5453); }
float layer(vec2 uv, float density, float speed, float slant, float seed) {
	uv.x += uv.y * slant;
	uv *= vec2(density, density * 0.06);
	uv.y += TIME * speed + seed;
	float column = floor(uv.x);
	float r = hash(column + seed);
	float y = fract(uv.y + r * 13.0);
	float keep = step(0.45, hash(column * 1.7 + seed));
	float streak = smoothstep(0.0, 0.03, y) * smoothstep(0.22, 0.03, y);
	float thin = 1.0 - smoothstep(0.0, 0.18, abs(fract(uv.x) - 0.5));
	return streak * thin * keep;
}
void fragment() {
	float r = layer(UV, 70.0, 26.0, 0.18, 0.0) * 0.55 + layer(UV, 140.0, 34.0, 0.2, 5.0) * 0.35 + layer(UV, 40.0, 18.0, 0.16, 9.0) * 0.6;
	COLOR = vec4(0.82, 0.87, 0.97, r * 0.55);
}
"""

const DUST_SHADER := """shader_type canvas_item;
uniform vec3 tint : source_color = vec3(0.95, 0.78, 0.55);
uniform float amount = 0.35;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * vec2(3.0, 9.0);
	p.x -= TIME * 1.6;
	float wisps = noise(p) * 0.6 + noise(p * 2.3 + vec2(-TIME * 1.1, 0.0)) * 0.4;
	wisps = smoothstep(0.45, 0.85, wisps);
	// Grit: fine specks racing sideways.
	vec2 g = UV * vec2(260.0, 460.0);
	g.x -= TIME * 220.0;
	float grit = step(0.997, hash(floor(g)));
	COLOR = vec4(tint, wisps * amount + grit * 0.5 * amount);
}
"""

const GRADE_SHADER := """shader_type canvas_item;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + TIME) * 43758.5453); }
void fragment() {
	vec2 c = UV - 0.5;
	float v = smoothstep(0.35, 0.95, length(c * vec2(1.0, 0.75)));
	float grain = hash(floor(UV * vec2(540.0, 960.0))) - 0.5;
	COLOR = vec4(vec3(0.5 + grain * 0.5), 0.0) + vec4(0.0, 0.0, 0.0, v * 0.55);
	COLOR.a = max(COLOR.a, abs(grain) * 0.06);
}
"""

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	film.add_child(layer)
	overlay = Control.new()
	overlay.size = Vector2(W, H)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	dust = _shader_rect(DUST_SHADER)
	rain = _shader_rect(RAIN_SHADER)
	_shader_rect(GRADE_SHADER)
	flash = ColorRect.new()
	flash.color = Color(0.85, 0.9, 1.0, 0.0)
	flash.size = Vector2(W, H)
	overlay.add_child(flash)
	wipe_clip = Control.new()
	wipe_clip.clip_contents = true
	wipe_clip.size = Vector2(W, H)
	wipe_clip.visible = false
	overlay.add_child(wipe_clip)
	wipe_image = TextureRect.new()
	wipe_image.size = Vector2(W, H)
	wipe_clip.add_child(wipe_image)
	black = ColorRect.new()
	black.color = Color.BLACK
	black.size = Vector2(W, H)
	overlay.add_child(black)
	texts = Control.new()
	texts.size = Vector2(W, H)
	overlay.add_child(texts)

func _shader_rect(code: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = Vector2(W, H)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = code
	rect.material = material
	rect.visible = false
	overlay.add_child(rect)
	return rect

## A line of words: Devanagari in Yatra One, English in the display face.
func _words(text: String, y: float, size: int, colour: Color, nepali := false, appear := 0.0, fade := 0.6) -> Label:
	var label := Label.new()
	label.text = text
	label.position = Vector2(0, y)
	label.size = Vector2(W, size * 1.6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI.devanagari_font() if nepali else UI.display_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", maxi(2, size / 14))
	label.modulate.a = 0.0
	texts.add_child(label)
	var tween := create_tween()
	tween.tween_interval(appear)
	tween.tween_property(label, "modulate:a", 1.0, fade)
	return label

func _clear_words() -> void:
	for child in texts.get_children():
		child.queue_free()

## The game's own studio card (scenes/Splash.tscn, splash.gd), played at
## its native 960x540 inside a viewport and shown across the vertical frame.
## Its hand-off to the main menu is switched off.
func _studio_card() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(960, 540)
	stage.transparent_bg = false
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var card: Control = load("res://scripts/splash.gd").new()
	card.set("_advanced", true)
	card.size = Vector2(960, 540)
	stage.add_child(card)
	texts.add_child(stage)
	var view := TextureRect.new()
	view.texture = stage.get_texture()
	view.size = Vector2(W, W * 540.0 / 960.0)
	view.position = Vector2(0, (H - view.size.y) * 0.5)
	view.stretch_mode = TextureRect.STRETCH_SCALE
	texts.add_child(view)

# ── Timeline ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	t += delta
	var next := shot_index
	while next + 1 < SHOTS.size() and t >= float(SHOTS[next + 1][0]):
		next += 1
	if next != shot_index:
		_cut_to(next)
	var local := t - shot_start
	_update(str(SHOTS[shot_index][1]), local, delta)
	if is_instance_valid(place) and place.has_method("animate"):
		place.animate(delta)
	for kite in kites:
		_fly(kite, t)
	if t >= LENGTH + 0.2:
		get_tree().quit()

func _cut_to(index: int) -> void:
	var wipe: bool = SHOTS[index][2]
	if wipe and shot_index >= 0:
		# The Kurosawa wipe: the last frame held, swept off left to right by
		# the hard edge of the next scene.
		var frame := film.get_texture().get_image()
		wipe_image.texture = ImageTexture.create_from_image(frame)
		wipe_clip.visible = true
		wipe_clip.position.x = 0.0
		wipe_clip.size.x = W
		wipe_image.position.x = 0.0
		var sweep := create_tween()
		sweep.tween_method(func(x: float):
			wipe_clip.position.x = x
			wipe_clip.size.x = W - x
			wipe_image.position.x = -x, 0.0, W, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sweep.tween_callback(func(): wipe_clip.visible = false)
		preload("res://scripts/sfx.gd").fire("wipe", -6.0)
	shot_index = index
	shot_start = float(SHOTS[index][0])
	_clear_words()
	_build(str(SHOTS[index][1]))

func _clear_world() -> void:
	for child in world.get_children():
		child.free()
	actors.clear()
	kites.clear()
	place = null
	lightning = null

func _build(name: String) -> void:
	rain.visible = false
	dust.visible = false
	black.visible = false
	match name:
		"presents":
			_clear_world()
			black.visible = true
			_studio_card()
		"kites":
			_use_set("hill_road")
			_light(Vector3(-10, 160, 0), Color("ffb470"), 1.4, Color("9fb0d0"))
			for i in 16:
				_add_kite(i, -9.0)
			_shot([[-6.0, 1.3, 9.0], [-9.0, 3.6, -26.0], 20.0], [[-6.0, 1.2, 9.0], [-9.0, 6.0, -26.0], 19.0])
			dust.visible = true
			_dust(Color("f2c48a"), 0.22)
			_words("दशैं", 230, 190, Color("c0301f"), true, 0.8, 1.2)
			_words("D A S H A I N", 470, 42, Color("fff3d6"), false, 1.8, 1.0)
		"ping":
			_use_set("hill_road")
			_light(Vector3(-8, 180, 0), Color("ffb066"), 1.5, Color("8c9ac0"))
			_prop("res://assets/teaser/linge_ping.glb", Vector3(-9.0, 0.0, -4.0), 0.4, 9.0)
			for i in 10:
				_add_kite(i + 20, -10.0)
			_shot([[-8.6, 0.45, 11.0], [-9.0, 4.0, -4.0], 34.0], [[-8.7, 0.42, 10.0], [-9.0, 3.9, -4.0], 33.0])
			dust.visible = true
			_dust(Color("f2c48a"), 0.18)
			_words("विजयको पर्व", 1560, 74, Color("fff0d0"), true, 0.8, 1.0)
			_words("THE FESTIVAL OF VICTORY", 1680, 36, Color("e9d7b0"), false, 1.5, 1.0)
		"tika":
			_use_set("hill_road")
			_light(Vector3(-14, 120, 0), Color("ffc37e"), 1.4, Color("a09ab8"))
			var master := _actor(ANANTA, Vector3(-5.0, 0.0, -5.7), Vector2(0, 1))
			var student := _actor(SARVOCHCHA, Vector3(-5.0, 0.0, -4.3), Vector2(0, -1))
			_hold(master, "taunt", 1.0)
			_hold(student, "bow", 2.7)
			_prop("res://assets/teaser/tika_thali.glb", Vector3(-5.0, 0.42, -5.0), 0.0, 0.17)
			var stool := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.5, 0.4, 0.5)
			stool.mesh = box
			var wood := StandardMaterial3D.new()
			wood.albedo_color = Color("3a2414")
			stool.material_override = wood
			stool.position = Vector3(-5.0, 0.2, -5.0)
			world.add_child(stool)
			_shot([[2.4, 1.15, -5.0], [-5.0, 0.95, -5.0], 33.0], [[2.0, 1.12, -5.0], [-5.0, 0.95, -5.0], 31.0])
			_words("गुरुको आशीर्वाद", 1560, 72, Color("fff0d0"), true, 1.0, 1.0)
			_words("A BLESSING FROM THE MASTER", 1680, 34, Color("e9d7b0"), false, 1.8, 1.0)
		"this_dashain":
			_clear_world()
			black.visible = true
			_words("यस दशैं...", 820, 96, Color("c0301f"), true, 0.3, 0.8)
			_words("THIS DASHAIN", 990, 60, Color("e9d7b0"), false, 1.1, 0.8)
		"rain_1":
			_rain_square()
			var a := _actor(SARVOCHCHA, Vector3(-0.75, 0.0, 0.0), Vector2(1, 0))
			var b := _actor(MAHABALI, Vector3(0.75, 0.0, 0.0), Vector2(-1, 0))
			_hold(a, "kick", 0.6)
			_hold(b, "idle", 0.2)
			_shot([[0.4, 0.55, 2.6], [0.1, 1.3, 0.0], 40.0], [[0.25, 0.6, 2.1], [0.1, 1.35, 0.0], 38.0])
			_strike_at(0.9)
		"rain_2":
			_rain_square()
			var a := _actor(KRI, Vector3(-0.7, 0.0, 0.0), Vector2(1, 0))
			var b := _actor(VAJRAVEER, Vector3(0.7, 0.0, 0.0), Vector2(-1, 0))
			_hold(a, "punch_heavy", 0.1)
			_hold(b, "block", 0.2)
			_shot([[-2.4, 1.0, 1.4], [0.2, 1.4, 0.0], 30.0], [[-2.0, 1.0, 1.1], [0.2, 1.45, 0.0], 28.0])
			_strike_at(1.0)
		"rain_3":
			_rain_square()
			var a := _actor(AGASTHYA, Vector3(-0.7, 0.0, 0.0), Vector2(1, 0))
			var b := _actor(ANUG, Vector3(0.7, 0.0, 0.0), Vector2(-1, 0))
			_hold(a, "uppercut", 0.3)
			_hold(b, "idle", 0.2)
			_shot([[2.2, 0.5, 1.6], [-0.2, 1.4, 0.0], 32.0], [[1.8, 0.45, 1.3], [-0.2, 1.5, 0.0], 30.0])
			_strike_at(1.1)
		"rain_4":
			_rain_square()
			var a := _actor(MAHABALI, Vector3(0.0, 0.0, -0.6), Vector2(0, 1))
			_hold(a, "punch_heavy", 0.0)
			# Axial cuts: the same line of sight, three steps closer.
			_shot([[0.0, 1.5, 4.5], [0.0, 1.45, -0.6], 30.0], [[0.0, 1.5, 4.5], [0.0, 1.45, -0.6], 30.0])
			_strike_at(0.6)
		"lineup":
			_clear_world()
			place = STAGE.new()
			world.add_child(place)
			place.show_round(3)
			var order := [ANUG, AGASTHYA, MAHABALI, KRI, VAJRAVEER, SARVOCHCHA]
			# Deep staging: a diagonal file receding from the lens, pressed
			# together by a long telephoto.
			for i in order.size():
				var who := _actor(order[i], Vector3(-1.1 + i * 0.55, 0.0, 2.0 - i * 1.3), Vector2(0.15, 1))
				_hold(who, "idle", 0.1 * i)
			_shot([[-3.2, 1.2, 15.0], [0.3, 1.1, -1.2], 15.0], [[-3.2, 1.18, 14.0], [0.3, 1.12, -1.2], 14.5])
			dust.visible = true
			_dust(Color("e8b47a"), 0.5)
			_words("छ जना चेला", 230, 84, Color("fff0d0"), true, 1.0, 1.0)
			_words("SIX STUDENTS", 360, 44, Color("e9d7b0"), false, 1.8, 1.0)
		"master":
			_rain_square()
			var master := _actor(ANANTA, Vector3(0.0, 0.0, 0.0), Vector2(0, 1))
			_hold(master, "taunt", 2.2)
			_shot([[0.0, 1.62, 2.6], [0.0, 1.6, 0.0], 24.0], [[0.0, 1.62, 1.6], [0.0, 1.62, 0.0], 22.0])
			_words("एक गुरु", 230, 84, Color("fff0d0"), true, 1.2, 1.0)
			_words("ONE MASTER", 360, 44, Color("e9d7b0"), false, 2.0, 1.0)
			_words("अनन्त", 1560, 150, Color("c0301f"), true, 3.6, 1.0)
		"title":
			_clear_world()
			black.visible = true
			var big := _words("WHO WON?", 700, 150, Color("f4e6c4"), false, 0.4, 0.15)
			big.pivot_offset = Vector2(W * 0.5, 120)
			big.scale = Vector2.ONE * 1.6
			create_tween().tween_property(big, "scale", Vector2.ONE, 0.35).set_delay(0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			preload("res://scripts/sfx.gd").fire("hit_heavy")
			_words("C O M I N G   S O O N", 1000, 46, Color("e9d7b0"), false, 2.4, 1.0)
			_words("विजया दशमीको शुभकामना", 1400, 70, Color("f2c230"), true, 3.6, 1.0)
			_words("HAPPY BIJAYA DASHAMI", 1530, 38, Color("e9d7b0"), false, 4.2, 1.0)
			_words("AANANDA", 1760, 30, Color("8c7b5c"), false, 5.0, 1.0)

func _update(name: String, local: float, delta: float) -> void:
	# Camera: an eased move from the shot's first framing to its last.
	if not cam_from.is_empty():
		var length := 6.0
		var next_start := LENGTH
		if shot_index + 1 < SHOTS.size():
			next_start = float(SHOTS[shot_index + 1][0])
		length = next_start - shot_start
		var k := smoothstep(0.0, 1.0, clampf(local / length, 0.0, 1.0))
		var eye: Vector3 = _v(cam_from[0]).lerp(_v(cam_to[0]), k)
		var look: Vector3 = _v(cam_from[1]).lerp(_v(cam_to[1]), k)
		if name == "rain_4":
			# Three axial jumps toward the fist instead of a smooth push.
			var step := floorf(clampf(local / 0.9, 0.0, 2.0))
			eye = _v(cam_from[0]).lerp(_v(cam_from[1]), step * 0.28)
		camera.global_position = eye
		camera.look_at(look)
		camera.fov = lerpf(cam_from[2], cam_to[2], k)
	# Slow motion inside the rain: each fighter's move plays at a third.
	var rate := 0.33 if name.begins_with("rain") else 1.0
	if name in ["tika", "lineup", "master"]:
		rate = 0.0
	for actor in actors:
		if rate > 0.0:
			actor.visual._process(delta * rate)
	# Lightning in the rain shots: a white flash and the sky light jumping.
	if is_instance_valid(lightning):
		var strike := float(lightning.get_meta("strike", -1.0))
		var since := local - strike
		var flare := 0.0
		if since >= 0.0 and since < 0.5:
			flare = (1.0 - since / 0.5) * (0.6 + 0.4 * sin(since * 60.0))
		if name == "master":
			for s: float in [0.4, 2.6, 4.1]:
				var d := local - s
				if d >= 0.0 and d < 0.6:
					flare = maxf(flare, (1.0 - d / 0.6) * (0.7 + 0.3 * sin(d * 50.0)))
		lightning.light_energy = flare * 3.2
		flash.color.a = flare * 0.35

func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func _shot(from: Array, to: Array) -> void:
	cam_from = from
	cam_to = to

# ── Places, light and props ─────────────────────────────────────────────────

func _use_set(name: String) -> void:
	_clear_world()
	place = SETS.make(name)
	world.add_child(place)

func _rain_square() -> void:
	_clear_world()
	place = STAGE.new()
	world.add_child(place)
	place.show_round(0)
	rain.visible = true
	lightning = DirectionalLight3D.new()
	lightning.rotation_degrees = Vector3(-55, 30, 0)
	lightning.light_color = Color(0.8, 0.86, 1.0)
	lightning.light_energy = 0.0
	world.add_child(lightning)
	preload("res://scripts/sfx.gd").fire("hit_heavy", -14.0, 0.5)

func _strike_at(second: float) -> void:
	if is_instance_valid(lightning):
		lightning.set_meta("strike", second)

func _light(angles: Vector3, colour: Color, energy: float, ambient: Color) -> void:
	for sun: DirectionalLight3D in world.find_children("*", "DirectionalLight3D", true, false):
		sun.rotation_degrees = angles
		sun.light_color = colour
		sun.light_energy = energy
	for env: WorldEnvironment in world.find_children("*", "WorldEnvironment", true, false):
		if env.environment != null:
			env.environment.ambient_light_color = ambient

func _dust(colour: Color, amount: float) -> void:
	var material := dust.material as ShaderMaterial
	material.set_shader_parameter("tint", colour)
	material.set_shader_parameter("amount", amount)

func _prop(path: String, at: Vector3, turn: float, size: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var node: Node3D = load(path).instantiate()
	node.position = at
	node.rotation.y = turn
	node.scale = Vector3.ONE * size
	world.add_child(node)

# ── Kites ───────────────────────────────────────────────────────────────────

const KITE_COLOURS := [["c0301f", "f2c230"], ["1f4fa3", "f4ead2"], ["2e7d32", "f2c230"], ["c2185b", "f4ead2"], ["f57c00", "1f4fa3"], ["6a1b9a", "f2c230"]]

## A Nepali changa: a tailless diamond of paper in two colours, on a long
## string, dancing in the wind.
func _add_kite(seed: int, centre_x := 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	var colours: Array = KITE_COLOURS[seed % KITE_COLOURS.size()]
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in 64:
		for x in 64:
			var d := absf(x - 31.5) + absf(y - 31.5)
			if d < 31.0:
				var c := Color(colours[0]) if y < 32 else Color(colours[1])
				if d > 28.5:
					c = Color("2a1d14")
				image.set_pixel(x, y, c)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var kite := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	kite.mesh = quad
	kite.material_override = material
	var home := Vector3(centre_x + rng.randf_range(-3.0, 3.0), rng.randf_range(4.0, 11.0), rng.randf_range(-30.0, -14.0))
	kite.position = home
	kite.set_meta("home", home)
	kite.set_meta("phase", rng.randf() * TAU)
	kite.set_meta("speed", rng.randf_range(0.7, 1.4))
	world.add_child(kite)
	# The string, angling down toward a rooftop somewhere below.
	var line := MeshInstance3D.new()
	var thread := CylinderMesh.new()
	thread.top_radius = 0.008
	thread.bottom_radius = 0.008
	thread.height = 14.0
	line.mesh = thread
	var string_material := StandardMaterial3D.new()
	string_material.albedo_color = Color(0.95, 0.92, 0.85, 0.8)
	string_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.material_override = string_material
	line.position = Vector3(0, -7.0, 2.0)
	line.rotation_degrees = Vector3(18, 0, 0)
	kite.add_child(line)
	kites.append(kite)

func _fly(kite: MeshInstance3D, time: float) -> void:
	if not is_instance_valid(kite):
		return
	var home: Vector3 = kite.get_meta("home")
	var phase: float = kite.get_meta("phase")
	var speed: float = kite.get_meta("speed")
	var s := time * speed + phase
	# Swoops and tugs: a wide figure-eight with quick dives.
	kite.position = home + Vector3(sin(s * 0.9) * 1.6, sin(s * 1.8) * 0.7 - maxf(0.0, sin(s * 0.37)) * 1.4, 0.0)
	kite.rotation = Vector3(sin(s * 2.3) * 0.3, sin(s * 1.1) * 0.5, PI * 0.25 + sin(s * 1.7) * 0.6)

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

## Starts a clip and runs it forward to a moment; the shot then plays it on
## (slowly, in the rain) or holds it still.
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
