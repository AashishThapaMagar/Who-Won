extends Node3D
## Ananta showcase reel in Heritage Square at night: stance, his signature
## combo, kicks, a knockdown in slow motion and his victory. Recorded with
##   godot --path . --fixed-fps 30 --write-movie reel.avi res://scenes/AnantaDemo.tscn
const UI := preload("res://scripts/ui_kit.gd")
const STAGE := preload("res://scripts/nepal_stage_3d.gd")
const ANANTA := 6
const RIVAL := 0
const LENGTH := 30.0

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
var caption: Label
var title_box: Control

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
	# Close enough that strikes actually land.
	hero = _spawn(ANANTA, Vector3(-0.4, 0, 0), 0.0)
	rival = _spawn(RIVAL, Vector3(0.4, 0, 0), PI)
	_overlay()
	_timeline()

func _spawn(index: int, at: Vector3, turn: float) -> Dictionary:
	var fighter: Node = load("res://scenes/Player.tscn").instantiate()
	var old: Node = fighter.get_node("Visual")
	fighter.remove_child(old)
	old.free()
	var visual := preload("res://scripts/fighter_visual_3d.gd").new()
	visual.name = "Visual"
	var rig := Node3D.new()
	rig.scale = Vector3.ONE / 64.0
	rig.position = at + Vector3(0, 0.02, 0)
	rig.rotation.y = turn
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

func _animated(actor: Dictionary):
	return actor.fighter.get_node("Visual").get("animated")

## Plays a move, starting at its wind-up (the part of the clip the game
## uses), so strikes land in rhythm.
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

# ── Overlay ──────────────────────────────────────────────────────────────

func _overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	for edge in [0.0, 540.0 - 58.0]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.position = Vector2(0, edge)
		bar.size = Vector2(960, 58)
		layer.add_child(bar)
	flash = ColorRect.new()
	flash.color = Color(1, 0.93, 0.8, 0)
	flash.size = Vector2(960, 540)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	caption = UI.heading(layer, "", Vector2(40, 402), Vector2(880, 60), 44, UI.GOLD, UI.CRIMSON)
	caption.modulate.a = 0.0
	title_box = Control.new()
	title_box.size = Vector2(960, 540)
	title_box.modulate.a = 0.0
	layer.add_child(title_box)
	var name_label := UI.heading(title_box, "ANANTA", Vector2(0, 360), Vector2(960, 80), 72, UI.WHITE, UI.CRIMSON)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := UI.eyebrow(title_box, "THE FINAL WORD", Vector2(0, 440), Vector2(960, 24), UI.GOLD)
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.size = Vector2(960, 540)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)

func _caption(text: String) -> void:
	caption.text = text
	var tween := caption.create_tween()
	caption.modulate.a = 0.0
	tween.tween_property(caption, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.8)
	tween.tween_property(caption, "modulate:a", 0.0, 0.3)

func _hit(strength := 0.5) -> void:
	flash.color.a = strength
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.18)

func _slowmo(scale: float, seconds: float) -> void:
	Engine.time_scale = scale
	get_tree().create_timer(seconds * scale).timeout.connect(func(): Engine.time_scale = 1.0)

# ── Camera ───────────────────────────────────────────────────────────────

## eye / look are offsets from the midpoint between the fighters, or from
## an actor's head with "on".
func _cut(spec: Dictionary) -> void:
	shot = spec
	shot_start = t
	camera.fov = float(spec.get("fov", 34.0))

func _update_camera() -> void:
	if shot.is_empty():
		return
	var k := clampf((t - shot_start) / float(shot.get("time", 3.0)), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var base := ((hero.rig as Node3D).position + (rival.rig as Node3D).position) * 0.5
	if shot.has("on"):
		base = _head(hero if shot.on == "hero" else rival)
	if shot.has("orbit"):
		var angle: float = lerpf(shot.orbit[0], shot.orbit[1], k)
		var radius: float = shot.get("radius", 3.0)
		camera.position = base + Vector3(sin(angle) * radius, shot.get("height", 1.2), cos(angle) * radius)
	else:
		camera.position = base + (shot.eye as Vector3).lerp(shot.get("eye_to", shot.eye), k)
	camera.look_at(base + (shot.get("look", Vector3(0, 1.0, 0)) as Vector3), Vector3.UP)

# ── Timeline ─────────────────────────────────────────────────────────────

func _at(time: float, action: Callable) -> void:
	beats.append([time, action])

func _timeline() -> void:
	# 0-4: the square, then down to the two fighters.
	_at(0.0, func():
		fade.create_tween().tween_property(fade, "color:a", 0.0, 1.2)
		_cut({"eye": Vector3(0, 7.5, 14), "eye_to": Vector3(0.8, 1.6, 5.2), "look": Vector3(0, 1.2, -4), "fov": 40, "time": 4.0}))
	# 4-7: Ananta in his stance, close.
	_at(4.0, func():
		_cut({"on": "hero", "eye": Vector3(1.1, -0.15, 1.3), "eye_to": Vector3(0.8, -0.1, 1.0), "look": Vector3(0, -0.1, 0), "fov": 30, "time": 3.0})
		_caption("ANANTA"))
	# 7-12: the signature combo, jab > straight > backfist > The Final Word.
	_at(7.0, func():
		_cut({"eye": Vector3(0.3, 0.2, 3.4), "eye_to": Vector3(-0.2, 0.1, 3.0), "look": Vector3(0, 1.0, 0), "fov": 36, "time": 5.0})
		_caption("SIGNATURE COMBO")
		_move(hero, "jab"))
	_at(7.35, func(): _move(rival, "hit"); _hit(0.25))
	_at(7.9, func(): _move(hero, "cross"))
	_at(8.25, func(): _move(rival, "hit"); _hit(0.3))
	_at(8.8, func(): _move(hero, "hook"))
	_at(9.15, func(): _move(rival, "hit_heavy"); _hit(0.35))
	_at(9.8, func():
		_move(hero, "kick_spin")
		_cut({"orbit": [0.25, 0.6], "radius": 3.0, "height": 1.0, "look": Vector3(0, 1.0, 0), "fov": 38, "time": 2.4}))
	_at(10.6, func():
		_move(rival, "hit_heavy")
		_hit(0.6)
		_slowmo(0.35, 1.0))
	# 12-16: kicks.
	_at(12.4, func():
		_move(hero, "idle")
		_move(rival, "idle")
		_caption("MARTIAL ARTS KICKS")
		_cut({"eye": Vector3(-0.6, 0.35, 2.8), "eye_to": Vector3(-0.2, 0.3, 2.6), "look": Vector3(0, 0.9, 0), "fov": 36, "time": 4.0}))
	_at(13.0, func(): _move(hero, "kick"))
	_at(13.8, func(): _move(rival, "block_hit"); _hit(0.2))
	_at(14.6, func(): _move(hero, "kick_front"))
	_at(15.5, func(): _move(rival, "hit"); _hit(0.3))
	# 16-21: uppercut into the power punch, knockdown in slow motion.
	_at(16.4, func():
		_move(hero, "uppercut")
		_cut({"on": "hero", "eye": Vector3(-0.5, -0.45, 1.9), "eye_to": Vector3(-0.3, -0.4, 1.7), "look": Vector3(0.4, -0.3, 0), "fov": 34, "time": 2.0}))
	_at(17.3, func(): _move(rival, "hit_heavy"); _hit(0.4))
	_at(18.2, func():
		_move(hero, "punch_heavy")
		_cut({"orbit": [-0.3, 0.25], "radius": 3.0, "height": 1.0, "look": Vector3(0, 0.9, 0), "fov": 36, "time": 3.0}))
	_at(19.0, func():
		_move(rival, "ko")
		_hit(0.8)
		_caption("K.O.")
		_slowmo(0.3, 1.6))
	# 21-26: victory.
	_at(21.6, func():
		_move(hero, "victory")
		_cut({"on": "hero", "orbit": [-0.5, 0.4], "radius": 2.4, "height": -0.2, "look": Vector3(0, -0.4, 0), "fov": 32, "time": 4.5}))
	_at(26.0, func():
		_move(hero, "idle")
		_cut({"on": "hero", "eye": Vector3(-0.5, -0.1, 1.5), "eye_to": Vector3(-0.35, -0.08, 1.2), "look": Vector3(0, -0.2, 0), "fov": 28, "time": 3.0})
		title_box.create_tween().tween_property(title_box, "modulate:a", 1.0, 0.8))
	_at(29.0, func(): fade.create_tween().tween_property(fade, "color:a", 1.0, 0.9))
	beats.sort_custom(func(a, b): return a[0] < b[0])

func _process(delta: float) -> void:
	# Timeline runs in real (unscaled) seconds so slow motion stretches the
	# action, not the schedule.
	t += delta / maxf(Engine.time_scale, 0.01) if Engine.time_scale < 1.0 else delta
	while next_beat < beats.size() and beats[next_beat][0] <= t:
		beats[next_beat][1].call()
		next_beat += 1
	stage.animate(delta)
	_update_camera()
	if t >= LENGTH:
		get_tree().quit()
