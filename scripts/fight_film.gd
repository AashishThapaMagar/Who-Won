extends Node
## A 40-second fight film introducing Ish, against Ananta, shot and graded the way Kung Fu
## Hustle is: golden-olive colour with crushed blacks, letterboxed, low wide
## lenses, crash zooms and whip pans, speed ramps on the big blows and
## freeze frames that stamp each fighter's name on screen.
##
## Record it with Godot's movie maker (30 fps, 1920x1080):
##   godot --path . --fixed-fps 30 --resolution 1920x1080 --write-movie fight_film.avi res://scenes/FightFilm.tscn
## It plays the real game: the real fighters, moves and reactions, driven
## through their own input actions by the beats below, with the arena's own
## super and knockout cameras taking over for those moments.
const UI := preload("res://scripts/ui_kit.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
const ISH := 1
const ANANTA := 6
const LENGTH := 40.0
## The UI is laid out at 960x540; 2.39:1 bars.
const SIZE := Vector2(960, 540)
const BAR := 69.0

var arena: Node
var ish: Node
var ananta: Node
var overlay: Control
var fade: ColorRect
var t := 0.0
var beats: Array = []
var held: Dictionary = {}
var taps: Array = []
## Current shot: a Callable(seconds into the shot) -> [eye, look, fov, roll].
var shot: Callable
var shot_start := 0.0
var director := true
var ramp_until := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	process_physics_priority = -1000
	Settings.show_fps = false
	Settings.touch_controls = false
	MatchSetup.vs_ai = false
	MatchSetup.camera_shake = true
	arena = load("res://scenes/Arena3D.tscn").instantiate()
	# The arena pauses for freeze frames; the director keeps running.
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	ish = arena.player1
	ananta = arena.player2
	ish.apply_character(ISH)
	ananta.apply_character(ANANTA)
	arena._begin_round(0)
	arena.intro_timer = 0.0
	arena._hide_banner()
	arena.time_remaining = 999.0
	_grade()
	_hide_hud()
	_build_overlay()
	_place(-3.0, 3.0)
	_build_beats()
	ish.impact.connect(func(_p, blocked, _h): _on_impact(ish, blocked))
	ananta.impact.connect(func(_p, blocked, _h): _on_impact(ananta, blocked))

## Kung Fu Hustle colour: olive-teal shadows under amber-gold highlights,
## crushed blacks, heavy vignette and grain.
func _grade() -> void:
	var grade: ShaderMaterial = arena.nepal_stage.grade
	grade.set_shader_parameter("shadow_tint", Color(0.78, 0.93, 0.84))
	grade.set_shader_parameter("highlight_tint", Color(1.16, 1.03, 0.74))
	grade.set_shader_parameter("saturation", 0.92)
	grade.set_shader_parameter("contrast", 1.32)
	grade.set_shader_parameter("vignette", 0.6)
	grade.set_shader_parameter("grain", 0.06)
	grade.set_shader_parameter("sharpen", 0.3)

func _hide_hud() -> void:
	for child in arena.get_children():
		if child is CanvasLayer:
			child.visible = false
		for layer in child.get_children():
			if layer is CanvasLayer and child != arena.nepal_stage:
				layer.visible = false

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var root := Control.new()
	root.size = SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	layer.add_child(root)
	overlay = Control.new()
	overlay.size = SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	for edge in [0.0, SIZE.y - BAR]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.position = Vector2(0, edge)
		bar.size = Vector2(SIZE.x, BAR)
		root.add_child(bar)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.size = SIZE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

# --- Timeline ---------------------------------------------------------------

func _at(time: float, action: Callable) -> void:
	beats.append([time, action])

func _build_beats() -> void:
	# Opening: the square at dusk, craning down to the dais.
	_at(0.0, func():
		_fade(0.0, 1.2)
		_shot_crane(Vector3(0, 7.5, 12), Vector3(0, 1.4, 5.8), Vector3(0, 1.6, -4), Vector3(0, 1.0, 0), 50.0, 3.2))
	_at(0.8, func(): _caption("HERITAGE SQUARE  ·  KATHMANDU  ·  DUSK"))
	# Ish walks in from the ground up; crash zoom on his face; freeze; his name.
	_at(3.2, func():
		_clear_text()
		_hold("p1_3d_right", 1.6)
		_shot_low_hero(ish, 1.0))
	_at(4.8, func(): _shot_crash_zoom(ish, 0.3))
	_at(5.2, func(): _freeze_card(ish, 2.4))
	# His rival steps in, seen past Ish's shoulder: no name, just a threat.
	_at(7.6, func():
		_hold("p2_3d_left", 1.1)
		_shot_over_shoulder(ish, ananta))
	# The standoff: symmetrical, low, dust on the wind.
	_at(9.7, func():
		_release_all()
		_place(-0.8, 0.8)
		_shot_standoff()
		_dust())
	_at(10.6, func(): _dust())
	# Exchange one: Ish's string into a guard, Ananta's counter kick.
	_at(11.6, func():
		_whip()
		_shot_side_track(7.0)
		_hold("p2_3d_block", 1.0))
	_at(11.7, func(): _tap("p1_3d_punch"))
	_at(11.95, func(): _tap("p1_3d_punch"))
	_at(12.2, func(): _tap("p1_3d_punch"))
	_at(12.75, func(): _tap("p2_3d_kick"))
	# Exchange two: over Ananta's shoulder, Ish's forward kick lands.
	_at(14.2, func():
		_place_gap(0.85)
		_shot_over_shoulder(ananta, ish))
	_at(14.3, func():
		_hold("p1_3d_right", 0.25)
		_tap("p1_3d_kick"))
	# Exchange three: Ananta's punches, the first one guarded.
	_at(15.6, func():
		_place_gap(0.8)
		_shot_low_side()
		_hold("p1_3d_block", 0.3))
	_at(15.7, func(): _tap("p2_3d_punch"))
	_at(15.95, func(): _tap("p2_3d_punch"))
	_at(16.2, func(): _tap("p2_3d_punch"))
	# Ish shoots the takedown, then rains down punches from the mount.
	_at(17.4, func():
		_place_gap(0.6)
		_shot_low_front()
		_tap("p1_3d_grapple"))
	_at(18.7, func(): _shot_mount())
	_at(19.0, func(): _tap("p1_3d_punch"))
	_at(19.5, func(): _tap("p1_3d_punch"))
	_at(20.0, func(): _tap("p1_3d_punch"))
	# Ananta rolls clear and rises.
	_at(21.2, func():
		_shot_low_side()
		_hold("p2_3d_right", 0.9))
	# Close, tilted standoff; a guarded jab and Ananta's answer.
	_at(22.6, func():
		_release_all()
		_place_gap(0.85)
		_shot_dutch_orbit())
	_at(22.8, func(): _hold("p2_3d_block", 0.6))
	_at(23.0, func(): _tap("p1_3d_punch"))
	_at(23.6, func(): _hold("p2_3d_right", 0.2); _tap("p2_3d_rpunch"))
	# The super: a crash zoom into Ish's eyes, then FLASH HAMMER.
	_at(24.6, func():
		_release_all()
		ananta.health = 62
		ananta.health_changed.emit(ananta.health, ananta.max_health)
		ish.super_meter = 100.0
		_place_gap(0.75)
		_shot_crash_zoom(ish, 0.5))
	_at(25.3, func():
		director = false
		_hold("p1_3d_rpunch", 0.1)
		_hold("p1_3d_rkick", 0.1))
	# After the hammer: Ananta on the floor, wide.
	_at(28.9, func():
		director = true
		_shot_low_side())
	# The finish: Ananta charges, Ish's kick ends it; the knockout camera.
	_at(30.0, func():
		ananta.health = 6
		ananta.health_changed.emit(ananta.health, ananta.max_health)
		_place_gap(1.3)
		_shot_behind(ananta))
	_at(30.05, func(): _hold("p2_3d_left", 0.5))
	_at(30.45, func(): _tap("p1_3d_kick"))
	_at(30.5, func(): director = false)
	# Freeze on the fallen; the winner's name; WHO WON?
	_at(32.4, func():
		get_tree().paused = true
		_release_all()
		_desaturate(0.55)
		_winner_card())
	_at(35.6, func(): _fade(1.0, 1.0))
	_at(36.7, func(): _title())
	_at(LENGTH, func(): get_tree().quit())

func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	t += real
	while not beats.is_empty() and t >= beats[0][0]:
		var beat: Array = beats.pop_front()
		beat[1].call()
	if Engine.time_scale < 1.0 and t >= ramp_until and not get_tree().paused:
		Engine.time_scale = 1.0
	_update_inputs(real)
	_update_camera()

# --- Fighters ---------------------------------------------------------------

func _place(x1: float, x2: float) -> void:
	for pair in [[ish, x1], [ananta, x2]]:
		var fighter: Node = pair[0]
		fighter.body.position = Vector3(pair[1], 0.02, 0.0)
		fighter.body.velocity = Vector3.ZERO
		fighter.body.reset_physics_interpolation()
	ish.forward = Vector3.RIGHT
	ananta.forward = Vector3.LEFT

## Re-spaces the fighters about their midpoint (a cut hides the move).
func _place_gap(gap: float) -> void:
	var middle: float = clampf((ish.body.position.x + ananta.body.position.x) * 0.5, -2.5, 2.5)
	_place(middle - gap * 0.5, middle + gap * 0.5)

func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	held[action] = t + seconds

func _tap(action: String) -> void:
	_hold(action, 0.05)

func _update_inputs(_real: float) -> void:
	for action in held.keys():
		if t >= held[action]:
			Input.action_release(action)
			held.erase(action)

func _release_all() -> void:
	for action in held.keys():
		Input.action_release(action)
	held.clear()

## Big blows ramp to slow motion for a beat.
func _on_impact(victim: Node, blocked: bool) -> void:
	if blocked or not director:
		return
	var heavy: bool = victim.last_hit_force >= 0.5 or victim.state in [victim.State.THROWN, victim.State.KNOCKDOWN]
	if heavy:
		Engine.time_scale = 0.28
		ramp_until = t + 0.55

# --- Camera -------------------------------------------------------------------

func _set_shot(fn: Callable) -> void:
	shot = fn
	shot_start = t
	arena.camera_3d.reset_physics_interpolation()

func _update_camera() -> void:
	var camera: Camera3D = arena.camera_3d
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	# The arena's own super and knockout shots take over for those moments.
	if not director or not shot.is_valid():
		return
	var frame: Array = shot.call(t - shot_start)
	camera.position = frame[0]
	camera.look_at(frame[1])
	camera.fov = frame[2]
	camera.rotate_object_local(Vector3.FORWARD, deg_to_rad(frame[3]))

func _ease(x: float) -> float:
	return smoothstep(0.0, 1.0, clampf(x, 0.0, 1.0))

func _mid() -> Vector3:
	return (ish.body.position + ananta.body.position) * 0.5

func _head(fighter: Node) -> Vector3:
	return fighter.body.position + Vector3.UP * 1.62

func _shot_crane(eye_a: Vector3, eye_b: Vector3, look_a: Vector3, look_b: Vector3, fov: float, seconds: float) -> void:
	_set_shot(func(s: float) -> Array:
		var k := _ease(s / seconds)
		return [eye_a.lerp(eye_b, k), look_a.lerp(look_b, k), fov, 0.0])

## Low from the ground, the fighter towering up out of frame.
func _shot_low_hero(fighter: Node, side: float) -> void:
	_set_shot(func(s: float) -> Array:
		var at: Vector3 = fighter.body.position
		return [at + Vector3(0.95 * side, 0.22, 1.5 - s * 0.08), at + Vector3(0.0, 1.4, 0.0), 40.0, 3.0 * side])

## A snap from wide to a tight face in a fraction of a second.
func _shot_crash_zoom(fighter: Node, seconds: float) -> void:
	_set_shot(func(s: float) -> Array:
		var face: Vector3 = _head(fighter) + Vector3(0, -0.05, 0)
		var k := _ease(s / seconds)
		k = k * k
		return [face + Vector3(fighter.forward.x * 0.45, 0.02, 1.25), face + Vector3(0, -0.08, 0), lerpf(52.0, 26.0, k), 0.0])

func _shot_standoff() -> void:
	_set_shot(func(s: float) -> Array:
		var middle := _mid()
		return [middle + Vector3(0, 0.5, 5.4 - minf(s, 2.0) * 0.45), middle + Vector3(0, 1.0, 0), 40.0, 0.0])

func _shot_side_track(roll: float) -> void:
	_set_shot(func(s: float) -> Array:
		var middle := _mid()
		return [middle + Vector3(0.6 - s * 0.2, 1.05, 2.9), middle + Vector3(0, 1.05, 0), 46.0, roll])

func _shot_over_shoulder(near: Node, far: Node) -> void:
	_set_shot(func(_s: float) -> Array:
		var behind: Vector3 = near.body.position - near.forward * 0.85
		return [behind + Vector3(0, 1.55, 0.75), far.body.position + Vector3(0, 1.15, 0), 44.0, -4.0])

func _shot_low_side() -> void:
	_set_shot(func(s: float) -> Array:
		var middle := _mid()
		return [middle + Vector3(-0.3 + s * 0.12, 0.42, 3.6), middle + Vector3(0, 0.9, 0), 44.0, 0.0])

func _shot_low_front() -> void:
	_set_shot(func(_s: float) -> Array:
		var middle := _mid()
		return [middle + Vector3(0.9, 0.35, 2.7), middle + Vector3(0.1, 0.85, 0), 48.0, 5.0])

## High over the mount, looking down at the ground punches.
func _shot_mount() -> void:
	_set_shot(func(s: float) -> Array:
		var down: Vector3 = ananta.body.position
		return [down + Vector3(-0.3 - s * 0.05, 2.3, 1.5), down + Vector3(-0.2, 0.25, 0), 44.0, -6.0])

func _shot_dutch_orbit() -> void:
	_set_shot(func(s: float) -> Array:
		var middle := _mid()
		var orbit := Vector3(0, 0, 2.7).rotated(Vector3.UP, -0.35 + s * 0.12)
		return [middle + orbit + Vector3(0, 1.0, 0), middle + Vector3(0, 1.1, 0), 42.0, -9.0])

func _shot_behind(fighter: Node) -> void:
	_set_shot(func(_s: float) -> Array:
		var at: Vector3 = fighter.body.position
		return [at - fighter.forward * 1.4 + Vector3(0, 0.6, 1.1), ananta.body.position + Vector3(0, 1.0, 0), 40.0, 4.0])

## A whip pan: the shot opens on a fast blurred swing.
func _whip() -> void:
	var streak := ColorRect.new()
	streak.color = Color(1.0, 0.92, 0.7, 0.0)
	streak.size = SIZE
	streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(streak)
	var tween := streak.create_tween()
	tween.tween_property(streak, "color:a", 0.35, 0.05)
	tween.tween_property(streak, "color:a", 0.0, 0.18)
	tween.tween_callback(streak.queue_free)

func _dust() -> void:
	arena._dust(_mid() + Vector3(0, 0.05, 0), 26, Color(0.78, 0.68, 0.5, 0.5), 1.2)

# --- Titles -------------------------------------------------------------------

func _clear_text() -> void:
	for child in overlay.get_children():
		child.queue_free()

func _fade(to: float, seconds: float) -> void:
	var tween := fade.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade, "color:a", to, seconds)

func _desaturate(amount: float) -> void:
	arena.nepal_stage.grade.set_shader_parameter("drain", amount)

func _caption(text: String) -> void:
	_clear_text()
	var label := UI.eyebrow(overlay, text, Vector2(0, SIZE.y - BAR - 30), Vector2(SIZE.x, 20), UI.GOLD)
	label.add_theme_font_size_override("font_size", 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.8)

## Freeze frame: the picture stops and drains to sepia, an ink slash cuts
## across it and the fighter's name is stamped on, with a red seal.
func _freeze_card(fighter: Node, seconds: float) -> void:
	get_tree().paused = true
	_desaturate(0.6)
	_clear_text()
	var profile: Dictionary = fighter.character_profile
	var left: bool = fighter == ish
	var box := Control.new()
	box.size = SIZE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(box)
	var slash := ColorRect.new()
	slash.color = Color(0.05, 0.03, 0.02, 0.82)
	slash.size = Vector2(SIZE.x * 1.3, 118)
	slash.position = Vector2(-SIZE.x * 0.15, 300)
	slash.rotation = deg_to_rad(-4.0)
	slash.pivot_offset = slash.size * 0.5
	slash.scale = Vector2(0.0, 1.0)
	box.add_child(slash)
	var x := 70.0 if left else 430.0
	var name_label := UI.heading(box, String(profile.name).to_upper(), Vector2(x, 300), Vector2(460, 80), 74, UI.GOLD, Color("b8241c"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	var title := UI.eyebrow(box, String(profile.title).to_upper(), Vector2(x + (4 if left else -4), 376), Vector2(460, 20), UI.WHITE)
	title.add_theme_font_size_override("font_size", 15)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	var seal := ColorRect.new()
	seal.color = Color("b8241c")
	seal.size = Vector2(46, 46)
	seal.position = Vector2(x + 470, 306) if left else Vector2(x - 56, 306)
	box.add_child(seal)
	var mark := UI.heading(seal, String(profile.name).substr(0, 1).to_upper(), Vector2(0, 2), Vector2(46, 42), 30, UI.WHITE, Color.BLACK)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.modulate.a = 0.0
	title.modulate.a = 0.0
	seal.scale = Vector2.ONE * 2.2
	seal.pivot_offset = seal.size * 0.5
	seal.modulate.a = 0.0
	var tween := box.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(slash, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(name_label, "modulate:a", 1.0, 0.08)
	tween.tween_property(title, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(seal, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(seal, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(0.1, seconds - 0.7))
	tween.tween_property(box, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func():
		box.queue_free()
		_desaturate(0.0)
		get_tree().paused = false)

func _winner_card() -> void:
	_clear_text()
	var box := Control.new()
	box.size = SIZE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(box)
	var slash := ColorRect.new()
	slash.color = Color(0.05, 0.03, 0.02, 0.85)
	slash.size = Vector2(SIZE.x * 1.3, 140)
	slash.position = Vector2(-SIZE.x * 0.15, 200)
	slash.rotation = deg_to_rad(3.0)
	slash.pivot_offset = slash.size * 0.5
	slash.scale = Vector2(0.0, 1.0)
	box.add_child(slash)
	var name_label := UI.heading(box, "ISH", Vector2(0, 196), Vector2(SIZE.x, 90), 86, UI.GOLD, Color("b8241c"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var wins := UI.eyebrow(box, "T H E   F L A S H   H A M M E R", Vector2(0, 290), Vector2(SIZE.x, 22), UI.WHITE)
	wins.add_theme_font_size_override("font_size", 16)
	wins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.modulate.a = 0.0
	wins.modulate.a = 0.0
	var tween := box.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(slash, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(name_label, "modulate:a", 1.0, 0.1)
	tween.tween_property(wins, "modulate:a", 1.0, 0.4)

func _title() -> void:
	_clear_text()
	var who := UI.heading(overlay, "WHO WON?", Vector2(0, 200), Vector2(SIZE.x, 100), 92, UI.GOLD, UI.CRIMSON)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.pivot_offset = Vector2(SIZE.x / 2.0, 50)
	who.scale = Vector2.ONE * 1.2
	who.modulate.a = 0.0
	who.z_index = 5
	# Above the fade to black.
	overlay.move_to_front()
	fade.get_parent().move_child(overlay, -1)
	var tween := who.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(who, "modulate:a", 1.0, 0.9)
	tween.parallel().tween_property(who, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
