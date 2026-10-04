extends Control
## Live 3D arena behind the menus. Each mode shows a different mood of the
## Nepal arena under a slowly drifting camera; `opening` drives the crimson
## slash wipe that carries the player into the next screen.
const ACCENTS := [Color("ffc53d"), Color("ff4a5a"), Color("6fb4ff"), Color("e59bff")]
const MODE_ORDER := ["arcade", "local", "ai", "story"]
## Arena round shown for each mode, in MODE_ORDER.
const MODE_ROUND := [0, 1, 2, 3]
const STAGE := preload("res://scripts/nepal_stage_3d.gd")
var elapsed := 0.0
var selected := 0:
	set(value):
		var changed := value != selected
		selected = value
		if stage != null and changed:
			_change_round(MODE_ROUND[clampi(value, 0, 3)])
var opening := 0.0:
	set(value):
		opening = value
		queue_redraw()
		if is_instance_valid(wipe_canvas):
			wipe_canvas.queue_redraw()
## Topmost control the transition slash is drawn on, above the menu itself.
var wipe_canvas: Control
## How far the dark reading panel covers the left of the screen (0..1).
var shade_width := 0.62
var stage: Node3D
var camera: Camera3D
var view: TextureRect
var viewport: SubViewport
## Main menu camera work: named shots around the square, each a camera
## position and a point to look at (metres, the fight ground at the origin),
## and how far the subject is pushed right of centre. "" keeps the drifting
## crane used behind fighter select.
const SHOTS := {
	"arcade": [Vector3(3.0, 2.4, 7.5), Vector3(0.0, 3.6, -20.0), -1.5],
	"story": [Vector3(3.2, 0.6, 6.8), Vector3(0.2, 4.6, -20.0), -0.9],
	"local": [Vector3(0.4, 1.2, 4.4), Vector3(0.2, 1.05, 0.0), -0.95],
	"ai": [Vector3(-2.7, 1.55, 1.5), Vector3(1.3, 1.2, 0.0), -0.55],
	"practice": [Vector3(-0.6, 0.75, 2.8), Vector3(-1.3, 1.1, 0.0), -0.75],
	"fighters": [Vector3(0.1, 1.55, 1.7), Vector3(1.3, 1.45, 0.0), -0.45],
	"records": [Vector3(0.6, 6.2, 6.8), Vector3(0.0, 0.2, -1.5), -0.6],
	"settings": [Vector3(0.2, 0.35, 3.2), Vector3(0.3, 2.0, 0.0), -0.8],
	"exit": [Vector3(0.0, 3.0, 13.5), Vector3(0.0, 2.0, -12.0), 0.0],
}
var shot := ""
var _eye := Vector3(1.5, 2.1, 6.5)
var _look := Vector3(-0.5, 3.4, -20.0)
var _offset := 0.0
var _framed := false
## Dip to black (0..1) that hides an arena change.
var dip := 0.0
var _round_shown := -1
## Fighters standing in the square on the main menu.
var fighters: Array[Node] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	# Rendered at the window's resolution (up to 1080p), not the 960 x 540
	# layout size, so the scene is sharp behind the menu.
	var window := DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else Vector2i(960, 540)
	viewport.size = Vector2i(clampi(window.x, 960, 1920), clampi(window.y, 540, 1080))
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	stage = STAGE.new()
	viewport.add_child(stage)
	camera = Camera3D.new()
	camera.fov = 50
	camera.far = 400
	viewport.add_child(camera)
	camera.current = true
	view = TextureRect.new()
	view.texture = viewport.get_texture()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.stretch_mode = TextureRect.STRETCH_SCALE
	# The render is larger than the layout; it must not grow the rect.
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.show_behind_parent = true
	add_child(view)
	stage.show_round(MODE_ROUND[selected])
	_round_shown = MODE_ROUND[selected]
	_place_camera(0.0)

func _process(delta: float) -> void:
	elapsed += delta
	if stage != null:
		stage.animate(delta)
	_place_camera(delta)
	queue_redraw()

## Glide to a named shot (see SHOTS).
func frame(shot_name: String) -> void:
	shot = shot_name

## The arena changes behind a quick dip to black.
func _change_round(index: int) -> void:
	if index == _round_shown:
		return
	_round_shown = index
	var tween := create_tween()
	tween.tween_property(self, "dip", 1.0, 0.18)
	tween.tween_callback(func(): stage.show_round(index))
	tween.tween_property(self, "dip", 0.0, 0.35)

## Main menu: a shot from SHOTS, eased toward with a slow breath in it.
## Otherwise a slow crane across the square toward the centrepiece.
func _place_camera(delta: float) -> void:
	if camera == null:
		return
	if shot.is_empty() or not SHOTS.has(shot):
		var sweep := sin(elapsed * 0.12)
		camera.position = Vector3(sweep * 3.2 + 1.5, 2.1 + sin(elapsed * 0.2) * 0.25, 6.5)
		camera.look_at(Vector3(sweep * 1.2 - 0.5, 3.4, -20))
		return
	var target: Array = SHOTS[shot]
	var breath := Vector3(sin(elapsed * 0.31) * 0.12, sin(elapsed * 0.23) * 0.06, cos(elapsed * 0.27) * 0.1)
	var k := 1.0 - exp(-2.4 * delta) if _framed else 1.0
	_framed = true
	_eye = _eye.lerp(target[0] + breath, k)
	_look = _look.lerp(target[1], k)
	_offset = lerpf(_offset, target[2], k)
	camera.position = _eye
	camera.look_at(_look)
	camera.h_offset = _offset
	camera.fov = 42.0

## Two fighters squaring off on the fight ground, idling in their guards.
func add_fighters(first: int, second: int) -> void:
	for i in 2:
		var fighter: Node = load("res://scenes/Player.tscn").instantiate()
		var previous: Node = fighter.get_node("Visual")
		fighter.remove_child(previous)
		previous.free()
		var visual := preload("res://scripts/fighter_visual_3d.gd").new()
		visual.name = "Visual"
		var rig := Node3D.new()
		rig.scale = Vector3.ONE / 64.0
		rig.position = Vector3(-1.3 if i == 0 else 1.3, 0.02, 0.0)
		rig.rotation.y = 0.0 if i == 0 else PI
		stage.add_child(rig)
		visual.world_root = rig
		fighter.add_child(visual)
		fighter.set_physics_process(false)
		viewport.add_child(fighter)
		fighter.controls_enabled = false
		fighter.collision_layer = 0
		fighter.hurtbox.collision_layer = 0
		fighter.apply_character(first if i == 0 else second)
		fighter.apply_style(load("res://resources/styles/action.tres"))
		fighter._update_animation()
		fighters.append(fighter)

func _draw() -> void:
	var size := Vector2(960, 540)
	# Reading shade on the left, fading out toward the scene.
	var reach := size.x * shade_width
	if reach > 0.0:
		draw_rect(Rect2(0, 0, reach * 0.55, size.y), Color(0.02, 0.025, 0.05, 0.78))
	if reach > 0.0:
		var dark := Color(0.02, 0.025, 0.05, 0.78)
		var clear := Color(0.02, 0.025, 0.05, 0.0)
		draw_polygon(PackedVector2Array([Vector2(reach * 0.55, 0), Vector2(reach, 0), Vector2(reach, size.y), Vector2(reach * 0.55, size.y)]), PackedColorArray([dark, clear, clear, dark]))
	if dip > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, dip))
	# A footer bar under a thin accent rule.
	draw_rect(Rect2(0, size.y - 34, size.x, 34), Color(0.01, 0.012, 0.025, 0.92))
	draw_rect(Rect2(0, size.y - 35, size.x, 1.5), Color(ACCENTS[selected], 0.8))

## Crimson slash sweeps across with a gold edge until it covers the screen.
func draw_wipe(canvas: CanvasItem) -> void:
	if opening <= 0.0:
		return
	var size := Vector2(960, 540)
	var front := lerpf(-400.0, size.x + 400.0, clampf(opening, 0.0, 1.0))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-800, 0), Vector2(front + 180, 0), Vector2(front - 180, size.y), Vector2(-800, size.y)]), Color("b3162d"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(front + 180, 0), Vector2(front + 206, 0), Vector2(front - 154, size.y), Vector2(front - 180, size.y)]), Color("ffc53d"))
