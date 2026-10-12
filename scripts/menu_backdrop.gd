extends Control
## Live 3D arena behind the menus. Home modes share one ready courtyard;
## other screens can select an arena. `opening` drives the crimson
## slash wipe that carries the player into the next screen.
const ACCENTS := [Color("ffc53d"), Color("ff4a5a"), Color("6fb4ff"), Color("e59bff"), Color("bfe3ff")]
const MODE_ORDER := ["arcade", "local", "ai", "story"]
## Arena round shown for each mode, in MODE_ORDER.
const MODE_ROUND := [0, 1, 2, 3]
const STAGE := preload("res://scripts/nepal_stage_3d.gd")
var elapsed := 0.0
## The home menu keeps one courtyard ready while its camera changes shots.
## Fighter select can still change arenas normally.
var locked_round := -1
var render_hz := 30.0
var _render_elapsed := 0.0
var _visual_elapsed := 0.0
var suspended := false
var _round_tween: Tween
var _pending_round := -1
var selected := 0:
	set(value):
		var changed := value != selected
		selected = value
		if stage != null and changed and locked_round < 0:
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
## Picture mode (character select): each arena is a photograph taken from
## this camera (assets/menu/arenas/, made by tools/capture_arena_pictures)
## instead of the live 3D stage, so changing the arena is instant: building
## a stage takes seconds, and would on a phone far longer. Set before the
## backdrop enters the tree.
var picture_mode := false
const PICTURE := "res://assets/menu/arenas/arena_%d.jpg"
var _pictures: Array[TextureRect] = []
var _front := 0
var _drift := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	# The 3D preview follows the window, with a quality-dependent size cap.
	var window := DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else Vector2i(960, 540)
	viewport.size = Vector2i(clampi(window.x, 960, 1920), clampi(window.y, 540, 1080))
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	stage = STAGE.new()
	stage.light_scenery_override = locked_round >= 0
	stage.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	viewport.add_child(stage)
	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
	_round_shown = locked_round if locked_round >= 0 else MODE_ROUND[selected]
	if picture_mode and ResourceLoader.exists(PICTURE % _round_shown):
		for i in 2:
			var picture := TextureRect.new()
			picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			picture.show_behind_parent = true
			picture.modulate.a = 0.0
			add_child(picture)
			_pictures.append(picture)
		view.visible = false
		_show_picture(_round_shown, false)
		# The rest load on worker threads, ready before anyone presses a key.
		for i in STAGE.ROUNDS.size():
			if i != _round_shown and ResourceLoader.exists(PICTURE % i):
				ResourceLoader.load_threaded_request(PICTURE % i)
	else:
		picture_mode = false
		stage.show_round(_round_shown)
	_apply_render_quality()
	Settings.graphics_changed.connect(_apply_render_quality)
	get_viewport().size_changed.connect(_apply_render_quality)
	_place_camera(0.0)

func _process(delta: float) -> void:
	if suspended:
		return
	elapsed += delta
	if picture_mode:
		# A slow push-in on the photograph, the way the live camera glides.
		_drift += delta
		for picture in _pictures:
			picture.pivot_offset = picture.size * 0.5
			picture.scale = Vector2.ONE * (1.04 + 0.02 * sin(_drift * 0.25))
		queue_redraw()
		return
	_render_elapsed += delta
	_visual_elapsed += delta
	if _render_elapsed >= 1.0 / render_hz:
		var frame_delta := _visual_elapsed
		_visual_elapsed = 0.0
		_render_elapsed = fmod(_render_elapsed, 1.0 / render_hz)
		if stage != null:
			stage.animate(frame_delta)
		for fighter in fighters:
			fighter.get_node("Visual")._process(frame_delta)
		_place_camera(frame_delta)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()

func _apply_render_quality() -> void:
	if viewport == null:
		return
	var window := DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else Vector2i(960, 540)
	var lighter := Settings.quality in [Settings.Quality.LOW, Settings.Quality.MEDIUM]
	var cap := Vector2i(1280, 720) if lighter else Vector2i(1920, 1080)
	var factor := minf(1.0, minf(float(cap.x) / maxi(window.x, 1), float(cap.y) / maxi(window.y, 1)))
	viewport.size = Vector2i(maxi(1, roundi(window.x * factor)), maxi(1, roundi(window.y * factor)))
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][Settings.anti_aliasing]
	render_hz = 24.0 if Settings.quality == Settings.Quality.LOW else 30.0
	if locked_round >= 0:
		# Decorative menu fighters use cheap contact shadows; avoid another
		# full skinned-mesh draw for a dynamic shadow map.
		if stage.sun != null:
			stage.sun.shadow_enabled = false
		if stage.key_light != null:
			stage.key_light.shadow_enabled = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func show_stage(index: int) -> void:
	if picture_mode:
		_show_picture(index, true)
		return
	if _round_tween != null and _round_tween.is_valid():
		_round_tween.kill()
	_pending_round = -1
	dip = 0.0
	stage.show_round(index)
	_round_shown = index
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

## Crossfades to the arena's photograph.
func _show_picture(index: int, fade: bool) -> void:
	var path := PICTURE % index
	if not ResourceLoader.exists(path) or (index == _round_shown and _pictures[_front].modulate.a > 0.0):
		return
	_round_shown = index
	_front = 1 - _front
	var incoming := _pictures[_front]
	var outgoing := _pictures[1 - _front]
	var status := ResourceLoader.load_threaded_get_status(path)
	incoming.texture = ResourceLoader.load_threaded_get(path) if status in [ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_IN_PROGRESS] else load(path)
	move_child(incoming, get_child_count() - 1)
	if _round_tween != null and _round_tween.is_valid():
		_round_tween.kill()
	if not fade:
		incoming.modulate.a = 1.0
		outgoing.modulate.a = 0.0
		return
	incoming.modulate.a = 0.0
	_round_tween = create_tween()
	_round_tween.tween_property(incoming, "modulate:a", 1.0, 0.22)
	_round_tween.tween_callback(func(): outgoing.modulate.a = 0.0)

## Glide to a named shot (see SHOTS).
func frame(shot_name: String) -> void:
	shot = shot_name

## The arena changes behind a quick dip to black.
func _change_round(index: int) -> void:
	# In picture mode the arena picker chooses the photo; a mode's default
	# arena must not land on top of it (nor build the live 3D stage).
	if picture_mode or locked_round >= 0 or index == _pending_round:
		return
	if _round_tween != null and _round_tween.is_valid():
		_round_tween.kill()
	_pending_round = -1
	if index == _round_shown:
		dip = 0.0
		return
	_pending_round = index
	_round_tween = create_tween()
	_round_tween.tween_interval(0.12)
	_round_tween.tween_property(self, "dip", 1.0, 0.08)
	_round_tween.tween_callback(func():
		stage.show_round(index)
		_round_shown = index
		_pending_round = -1)
	_round_tween.tween_property(self, "dip", 0.0, 0.12)

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
	var k := 1.0 - exp(-7.0 * delta) if _framed else 1.0
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
		visual.set_process(false)
		fighter.controls_enabled = false
		fighter.collision_layer = 0
		fighter.hurtbox.collision_layer = 0
		fighter.apply_character(first if i == 0 else second)
		fighter.apply_style(load("res://resources/styles/action.tres"))
		fighter._update_animation()
		fighters.append(fighter)
		if locked_round >= 0:
			var blob := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(1.15, 1.15)
			quad.orientation = PlaneMesh.FACE_Y
			blob.mesh = quad
			blob.position = Vector3(-1.3 if i == 0 else 1.3, 0.012, 0.0)
			var material := ShaderMaterial.new()
			material.shader = preload("res://scripts/contact_shadow.gdshader")
			blob.material_override = material
			blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			stage.add_child(blob)

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
