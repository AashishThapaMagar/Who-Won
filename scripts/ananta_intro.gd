extends Node3D
## Ananta's character intro, shot the way Kurosawa shoots a swordsman: alone
## in Heritage Square on a long lens with dust blowing across, low angles,
## hard wipes between shots, his combat in short decisive bursts with
## slow-motion finishers, then the face and his name. 30 seconds. Recorded with
##   godot --path . --fixed-fps 30 --write-movie intro.avi res://scenes/AnantaIntro.tscn
const UI := preload("res://scripts/ui_kit.gd")
const STAGE := preload("res://scripts/nepal_stage_3d.gd")
const ANANTA := 6
const RIVAL := 0
const LENGTH := 30.0
const SIZE := Vector2(960, 540)
const BAR := 62.0

var stage: Node3D
var camera: Camera3D
var hero: Dictionary
var rival: Dictionary
var t := 0.0
var beats: Array = []
var next_beat := 0
var shot: Dictionary = {}
var shot_start := 0.0
var fade: ColorRect
var flash: ColorRect
var overlay: Control
var dust: CPUParticles3D
var walk_from := Vector3.ZERO
var walk_to := Vector3.ZERO
var walk_start := -1.0
var walk_time := 1.0

func _ready() -> void:
	Settings.show_fps = false
	stage = STAGE.new()
	add_child(stage)
	stage.show_round(0)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 500
	add_child(camera)
	camera.current = true
	# Ananta alone in the square, facing across it.
	hero = _spawn(ANANTA)
	_place(hero, Vector3(0, 0, -2), 0.0)
	_wind()
	_overlay()
	_timeline()

func _spawn(index: int) -> Dictionary:
	var fighter: Node = load("res://scenes/Player.tscn").instantiate()
	var old: Node = fighter.get_node("Visual")
	fighter.remove_child(old)
	old.free()
	var visual := preload("res://scripts/fighter_visual_3d.gd").new()
	visual.name = "Visual"
	var rig := Node3D.new()
	rig.scale = Vector3.ONE / 64.0
	add_child(rig)
	visual.world_root = rig
	fighter.add_child(visual)
	fighter.set_physics_process(false)
	add_child(fighter)
	fighter.controls_enabled = false
	fighter.apply_character(index)
	fighter.apply_style(load("res://resources/styles/action.tres"))
	fighter._update_animation()
	return {"fighter": fighter, "rig": rig}

func _place(actor: Dictionary, at: Vector3, turn: float) -> void:
	var rig: Node3D = actor.rig
	rig.position = at + Vector3(0, 0.02, 0)
	rig.rotation.y = turn

func _animated(actor: Dictionary):
	return actor.fighter.get_node("Visual").get("animated")

## Plays a move from the start of the part of its clip the game uses.
func _move(actor: Dictionary, clip: String) -> void:
	var animated = _animated(actor)
	if animated == null:
		return
	animated.pose_override = clip
	animated.replay()
	await get_tree().process_frame
	var cut: Array = animated.config.get("timing", {}).get(clip, [])
	if cut.size() == 3 and animated.player.is_playing():
		animated.player.seek(cut[0], true)

func _head(actor: Dictionary) -> Vector3:
	var animated = _animated(actor)
	if animated != null and animated.active and animated.skeleton != null:
		var bone: int = animated.skeleton.find_bone("mixamorig_Head")
		if bone >= 0:
			return animated.skeleton.global_transform * animated.skeleton.get_bone_global_pose(bone).origin
	return (actor.rig as Node3D).position + Vector3(0, 1.6, 0)

func _walk(from: Vector3, to: Vector3, seconds: float) -> void:
	walk_from = from
	walk_to = to
	walk_start = t
	walk_time = seconds
	var d := to - from
	_place(hero, from, atan2(-d.z, d.x))
	_move(hero, "walk")

## Dust driven sideways across the square, Kurosawa's wind.
func _wind() -> void:
	dust = CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.03)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.93, 0.84, 0.7, 0.6)
	quad.material = material
	dust.mesh = quad
	dust.amount = 500
	dust.lifetime = 3.5
	dust.preprocess = 3.5
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1, 1.3, 11)
	dust.position = Vector3(-8, 1.0, -2)
	dust.direction = Vector3(1, 0.05, 0.05)
	dust.spread = 7
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 7.0
	add_child(dust)

# ── Overlay ──────────────────────────────────────────────────────────────

func _overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	for edge in [0.0, SIZE.y - BAR]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.position = Vector2(0, edge)
		bar.size = Vector2(SIZE.x, BAR)
		layer.add_child(bar)
	flash = ColorRect.new()
	flash.color = Color(1, 0.95, 0.85, 0)
	flash.size = SIZE
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.size = SIZE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	overlay = Control.new()
	overlay.size = SIZE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)

func _hit(strength := 0.4) -> void:
	flash.color.a = strength
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.16)

func _slowmo(scale: float, seconds: float) -> void:
	Engine.time_scale = scale
	get_tree().create_timer(seconds * scale).timeout.connect(func(): Engine.time_scale = 1.0)

## Kurosawa's wipe: a hard vertical edge pushes the frozen old shot away.
func _wipe(left_to_right := true) -> void:
	var image := get_viewport().get_texture().get_image()
	var clip := Control.new()
	clip.clip_contents = true
	clip.size = SIZE
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var still := TextureRect.new()
	still.texture = ImageTexture.create_from_image(image)
	still.size = SIZE
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	still.stretch_mode = TextureRect.STRETCH_SCALE
	clip.add_child(still)
	overlay.get_parent().add_child(clip)
	overlay.get_parent().move_child(clip, flash.get_index())
	var tween := clip.create_tween()
	tween.tween_method(func(k: float):
		var edge := SIZE.x * k
		if left_to_right:
			clip.position.x = edge
			clip.size.x = SIZE.x - edge
			still.position.x = -edge
		else:
			clip.size.x = SIZE.x - edge, 0.0, 1.0, 0.45)
	tween.tween_callback(clip.queue_free)

func _title(lines: Array, y: float, hold: float) -> void:
	var box := Control.new()
	box.size = SIZE
	box.modulate.a = 0.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(box)
	var at := y
	for line in lines:
		var label: Label
		if line[1] >= 30:
			label = UI.heading(box, line[0], Vector2(0, at), Vector2(SIZE.x, line[1] + 14), line[1], line[2], UI.CRIMSON)
		else:
			label = UI.eyebrow(box, line[0], Vector2(0, at), Vector2(SIZE.x, line[1] + 6), line[2])
			label.add_theme_font_size_override("font_size", line[1])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		at += line[1] + 14
	var tween := box.create_tween()
	tween.tween_property(box, "modulate:a", 1.0, 0.9)
	tween.tween_interval(hold)
	tween.tween_property(box, "modulate:a", 0.0, 0.8)

# ── Camera ───────────────────────────────────────────────────────────────

## Shots: "eye"/"look" world points (eased to "eye_to"/"look_to"), or
## "follow": actor with "offset"/"aim" relative to their head.
func _cut(spec: Dictionary) -> void:
	shot = spec
	shot_start = t
	camera.fov = float(spec.get("fov", 30.0))

func _update_camera() -> void:
	if shot.is_empty():
		return
	var k := clampf((t - shot_start) / float(shot.get("time", 4.0)), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	if shot.has("follow"):
		var head := _head(hero)
		camera.position = head + (shot.offset as Vector3).lerp(shot.get("offset_to", shot.offset), k)
		camera.look_at(head + (shot.get("aim", Vector3.ZERO) as Vector3), Vector3.UP)
		return
	camera.position = (shot.eye as Vector3).lerp(shot.get("eye_to", shot.eye), k)
	camera.look_at((shot.look as Vector3).lerp(shot.get("look_to", shot.look), k), Vector3.UP)

# ── Timeline ─────────────────────────────────────────────────────────────

func _at(time: float, action: Callable) -> void:
	beats.append([time, action])

func _timeline() -> void:
	var at := Vector3(0, 0, -2)
	# 0-4: the square on a long lens, Ananta small in the middle of it, the
	# pagoda behind him, dust blowing across. He does not move.
	_at(0.0, func():
		_move(hero, "idle")
		_cut({"fov": 12, "eye": at + Vector3(0.6, 1.4, 20), "look": at + Vector3(0, 1.4, -6), "eye_to": at + Vector3(0.2, 1.3, 17), "time": 4.0})
		fade.create_tween().tween_property(fade, "color:a", 0.0, 1.6))
	# 4-7: close and low on the stance, fists up, the wind on his coat.
	_at(4.0, func():
		_wipe()
		_cut({"fov": 26, "follow": "hero", "offset": Vector3(1.5, -1.2, 1.2), "offset_to": Vector3(1.3, -1.1, 1.0), "aim": Vector3(0, -0.6, 0), "time": 3.0}))
	# 7-11: the combo, jab, cross, hook, then the flying knee.
	_at(7.0, func():
		_wipe(false)
		_cut({"fov": 34, "eye": at + Vector3(0.9, 1.1, 3.2), "look": at + Vector3(0.5, 1.1, 0), "eye_to": at + Vector3(0.6, 1.05, 2.8), "time": 4.0})
		_move(hero, "jab"))
	_at(7.7, func(): _move(hero, "cross"))
	_at(8.5, func(): _move(hero, "hook"))
	_at(9.2, func():
		_move(hero, "finisher")
		_cut({"fov": 44, "eye": at + Vector3(0.6, 1.6, 5.2), "look": at + Vector3(0.3, 1.2, 0), "eye_to": at + Vector3(0.3, 1.5, 4.8), "time": 2.6}))
	_at(10.1, func(): _slowmo(0.35, 1.0))
	# 12-17: the kicks, body kick, front kick, spinning back kick.
	_at(12.0, func():
		_wipe()
		_move(hero, "idle")
		_cut({"fov": 34, "eye": at + Vector3(-0.8, 0.8, 3.4), "look": at + Vector3(0.3, 0.9, 0), "eye_to": at + Vector3(0.2, 0.9, 3.2), "time": 5.0}))
	_at(12.4, func(): _move(hero, "kick"))
	_at(13.8, func(): _move(hero, "kick_front"))
	_at(15.3, func(): _move(hero, "kick_spin"))
	_at(15.9, func(): _slowmo(0.35, 0.9))
	# 17-21: from the ground, the uppercut and the punch combo against the sky.
	_at(17.2, func():
		_wipe(false)
		_move(hero, "idle")
		_cut({"fov": 30, "follow": "hero", "offset": Vector3(1.4, -1.35, 1.1), "aim": Vector3(0.2, -0.1, 0), "time": 4.0}))
	_at(17.6, func(): _move(hero, "uppercut"))
	_at(18.9, func(): _move(hero, "punch_heavy"))
	# 21-24: silhouette on the long lens, one last spinning kick.
	_at(21.3, func():
		_wipe()
		_move(hero, "idle")
		_cut({"fov": 13, "eye": at + Vector3(3.0, 0.5, 15), "look": at + Vector3(0, 1.1, 0), "eye_to": at + Vector3(2.4, 0.5, 13.5), "time": 3.0}))
	_at(21.8, func(): _move(hero, "kick_spin"))
	_at(22.4, func(): _slowmo(0.4, 0.8))
	# 24-30: the face, slowly, then his name.
	_at(24.2, func():
		_wipe(false)
		_move(hero, "idle")
		_place(hero, at, -PI / 2.0 + 0.15)
		_cut({"fov": 20, "follow": "hero", "offset": Vector3(0.12, -0.04, 1.9), "offset_to": Vector3(0.06, -0.02, 1.1), "aim": Vector3(0, -0.04, 0), "time": 5.5}))
	_at(25.2, func(): _title([["ANANTA", 64, UI.WHITE], ["THE FINAL WORD", 15, UI.GOLD]], 360.0, 2.8))
	_at(29.0, func(): fade.create_tween().tween_property(fade, "color:a", 1.0, 0.9))
	beats.sort_custom(func(a, b): return a[0] < b[0])

func _process(delta: float) -> void:
	# The schedule runs in real seconds; slow motion stretches only the action.
	t += delta / maxf(Engine.time_scale, 0.01) if Engine.time_scale < 1.0 else delta
	while next_beat < beats.size() and beats[next_beat][0] <= t:
		beats[next_beat][1].call()
		next_beat += 1
	stage.animate(delta)
	_update_camera()
	if t >= LENGTH:
		Engine.time_scale = 1.0
		get_tree().quit()
