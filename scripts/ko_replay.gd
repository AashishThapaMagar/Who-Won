extends Node
## Knockout replay. Every frame of a round, both fighters' bodies, rig parts
## and skeleton poses go into a rolling buffer. After a knockout the last
## seconds play back as a kung fu film: a warm, high-contrast grade, the
## run-up at full speed, then a snap into slow motion for the finishing blow,
## a freeze-frame crash zoom on the knockout and the fall. The camera stays
## on the fight camera's side throughout. Then the winner celebrates: a low
## hero shot, the VICTORY title and marigold petals falling. Enter or Esc
## skips each part.

## How much of the fight is shown: from LEAD seconds before the knockout to
## TAIL seconds after it (the fall). The finishing blow, SLOW_FROM before the
## knockout to SLOW_TO after it, plays at SLOW_RATE, with a FREEZE-second
## hold on the knockout frame. With these numbers the replay runs 7 seconds:
## 2.4 + 1.25 + 0.5 + 1.75 + 1.1.
const LEAD := 2.9
const TAIL := 1.8
const SLOW_FROM := 0.5
const SLOW_TO := 0.7
const SLOW_RATE := 0.4
const FREEZE := 0.5
## Seconds of fight kept in the buffer.
const KEEP := LEAD + TAIL + 1.0
## Real seconds after the knockout before the replay starts, so the live
## fall and the KO callout play first. Recording runs until then.
const START_DELAY := 2.3
const UI := preload("res://scripts/ui_kit.gd")

var arena: Node
## Game-time clock of the recording, and its frames, oldest first:
## {t, fighters: [{body, nodes, visible, bones}, ...]}.
var clock := 0.0
var frames: Array[Dictionary] = []
## Impacts during recording: {t, fighter, blocked, heavy}.
var impacts: Array[Dictionary] = []
## Per fighter: the Node3Ds under its rig and the skeletons among them.
var _nodes: Array = [[], []]
var _skeletons: Array = [[], []]
var ko_time := -1.0
var ko_index := 0
var playing := false
## The victory celebration after the replay, and how long it lasts.
var celebrating := false
var _celebrate_time := 0.0
const CELEBRATE := 3.5
var _celebration: Array[Node] = []
var _play_time := 0.0
var _last_t := 0.0
var _live: Array = []
var _overlay: CanvasLayer
var _flash: ColorRect
var _badge: Control
var _lines: ColorRect
var _pending := false
## The side the fight camera watched from when the replay began; every shot
## is taken from this side.
var _view := Vector3.BACK
## Crash-zoom kick (field-of-view degrees) and shake left from the last hit.
var _kick := 0.0
var _shake := 0.0
## The stage grade as it was, restored after the replay.
var _grade_before: Dictionary = {}
## Kung fu film grade: teal-green shadows, warm amber highlights, hard
## contrast, a heavy vignette and film grain.
const FILM_GRADE := {"shadow_tint": Color(0.84, 0.99, 0.95), "highlight_tint": Color(1.12, 1.0, 0.8),
	"saturation": 1.12, "contrast": 1.28, "vignette": 0.62, "grain": 0.07, "drain": 0.0}
## The badge's finish: gold through white-hot to deep amber, by screen
## height, with a glint crossing it.
const BADGE_METAL := """shader_type canvas_item;
uniform float top = 0.03;
uniform float bottom = 0.11;
void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	float y = clamp((SCREEN_UV.y - top) / (bottom - top), 0.0, 1.0);
	vec3 metal = mix(vec3(1.0, 0.9, 0.55), vec3(1.0, 1.0, 0.96), smoothstep(0.1, 0.45, y));
	metal = mix(metal, vec3(0.95, 0.58, 0.16), smoothstep(0.55, 1.0, y));
	float sweep = fract(TIME * 0.5) * 2.4 - 0.7;
	float glint = 1.0 - smoothstep(0.0, 0.03, abs(SCREEN_UV.x * 0.9 + SCREEN_UV.y * 0.5 - sweep));
	float fill = step(0.98, min(COLOR.r, min(COLOR.g, COLOR.b)));
	COLOR = vec4(mix(COLOR.rgb, metal + glint * 0.6, fill), glyph.a * COLOR.a);
}
"""
## Ink speed lines bursting from the centre on the freeze-frame.
const SPEED_LINES := """shader_type canvas_item;
uniform float strength = 0.0;
uniform float aspect = 1.78;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float angle = atan(p.y, p.x);
	float slot = (angle + 3.14159) / 6.28318 * 220.0;
	float ray = floor(slot);
	float r = length(p);
	float reach = 0.38 + hash(ray) * 0.3;
	float thin = 1.0 - smoothstep(0.0, 0.18 + hash(ray + 3.0) * 0.2, abs(fract(slot) - 0.5));
	float line = step(0.62, hash(ray + 7.0)) * thin * smoothstep(reach, reach + 0.3, r);
	COLOR = vec4(0.02, 0.015, 0.01, line * strength * 0.85);
}
"""

func _fighters() -> Array:
	return [arena.player1, arena.player2]

## A new round: forget the previous one and re-read the rigs.
func reset() -> void:
	if playing:
		_finish()
	if celebrating:
		_end_celebration()
	frames.clear()
	impacts.clear()
	clock = 0.0
	ko_time = -1.0
	_pending = false
	_nodes = [[], []]
	_skeletons = [[], []]

func _collect(i: int) -> void:
	var fighter: Node = _fighters()[i]
	var pivot: Node3D = fighter.pivot
	var nodes: Array = [pivot]
	var skeletons: Array = []
	for node in pivot.find_children("*", "Node3D", true, false):
		if node is BoneAttachment3D:
			continue
		nodes.append(node)
		if node is Skeleton3D:
			skeletons.append(node)
	_nodes[i] = nodes
	_skeletons[i] = skeletons

func _snapshot() -> Array:
	var shot: Array = []
	for i in 2:
		if _nodes[i].is_empty() or not is_instance_valid(_nodes[i][0]):
			_collect(i)
		var transforms: Array[Transform3D] = []
		var shown := PackedByteArray()
		for node in _nodes[i]:
			var valid := is_instance_valid(node)
			transforms.append(node.transform if valid else Transform3D.IDENTITY)
			shown.append(1 if valid and node.visible else 0)
		var bones: Array = []
		for skeleton: Skeleton3D in _skeletons[i]:
			if not is_instance_valid(skeleton):
				bones.append([])
				continue
			var count := skeleton.get_bone_count()
			var positions := PackedVector3Array()
			var rotations: Array[Quaternion] = []
			var scales := PackedVector3Array()
			positions.resize(count)
			scales.resize(count)
			for bone in count:
				positions[bone] = skeleton.get_bone_pose_position(bone)
				rotations.append(skeleton.get_bone_pose_rotation(bone))
				scales[bone] = skeleton.get_bone_pose_scale(bone)
			bones.append([positions, rotations, scales])
		var fighter: Node = _fighters()[i]
		shot.append({"body": fighter.body.global_transform, "nodes": transforms, "visible": shown, "bones": bones})
	return shot

## Called by the arena every rendered frame with the game-time delta.
func record(delta: float) -> void:
	if playing:
		return
	clock += delta
	frames.append({"t": clock, "fighters": _snapshot()})
	while frames.size() > 2 and frames[0].t < clock - KEEP:
		frames.pop_front()
	while not impacts.is_empty() and impacts[0].t < clock - KEEP:
		impacts.pop_front()

func note_impact(fighter: Node, blocked: bool, heavy: bool) -> void:
	if playing:
		return
	impacts.append({"t": clock, "fighter": _fighters().find(fighter), "blocked": blocked, "heavy": heavy})

func note_ko(fighter: Node) -> void:
	if playing or ko_time >= 0.0:
		return
	ko_time = clock
	ko_index = _fighters().find(fighter)
	_pending = true
	get_tree().create_timer(START_DELAY, true, false, true).timeout.connect(_start)

## Length of the replay in real seconds.
static func duration() -> float:
	return (LEAD - SLOW_FROM) + (SLOW_FROM + SLOW_TO) / SLOW_RATE + FREEZE + (TAIL - SLOW_TO)

## Fight time (relative to the knockout) shown at a real second into the
## replay: full speed, slow, a held knockout frame, slow, full speed.
static func fight_time(real: float) -> float:
	var fast_in := LEAD - SLOW_FROM
	if real <= fast_in:
		return -LEAD + real
	real -= fast_in
	var slow_in := SLOW_FROM / SLOW_RATE
	if real <= slow_in:
		return -SLOW_FROM + real * SLOW_RATE
	real -= slow_in
	if real <= FREEZE:
		return 0.0
	real -= FREEZE
	var slow_out := SLOW_TO / SLOW_RATE
	if real <= slow_out:
		return real * SLOW_RATE
	return SLOW_TO + (real - slow_out)

## How far into the knockout freeze-frame a real second is (0..1), or -1.
static func freeze_progress(real: float) -> float:
	var at := (LEAD - SLOW_FROM) + SLOW_FROM / SLOW_RATE
	if real < at or real > at + FREEZE:
		return -1.0
	return (real - at) / FREEZE

func _start() -> void:
	if not _pending:
		return
	_pending = false
	if playing or ko_time < 0.0 or frames.size() < 2 or not is_instance_valid(arena) or not arena.is_inside_tree():
		return
	playing = true
	_play_time = 0.0
	_kick = 0.0
	_shake = 0.0
	_last_t = ko_time - LEAD - 0.001
	_live = _snapshot()
	# Every shot is taken from the side the fight was watched from.
	var middle: Vector3 = (arena.player1.body.global_position + arena.player2.body.global_position) * 0.5
	_view = arena.camera_3d.global_position - middle
	_view.y = 0.0
	_view = _view.normalized() if _view.length() > 0.01 else Vector3.BACK
	arena._freeze(true)
	for fighter in _fighters():
		fighter.get_node("Visual").set_process(false)
		fighter.body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var ui: CanvasLayer = arena.get_node_or_null("UI")
	if ui != null:
		ui.visible = false
	_set_grade(FILM_GRADE)
	_build_overlay()
	_apply_time(ko_time - LEAD)

func _set_grade(values: Dictionary) -> void:
	var grade: ShaderMaterial = arena.nepal_stage.get("grade")
	if grade == null:
		return
	for key in values:
		if not _grade_before.has(key):
			_grade_before[key] = grade.get_shader_parameter(key)
		grade.set_shader_parameter(key, values[key])

func _restore_grade() -> void:
	var grade: ShaderMaterial = arena.nepal_stage.get("grade")
	if grade != null:
		for key in _grade_before:
			grade.set_shader_parameter(key, _grade_before[key])
	_grade_before.clear()

static func _shader(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 40
	arena.add_child(_overlay)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(root)
	_lines = ColorRect.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.material = _shader(SPEED_LINES)
	root.add_child(_lines)
	# Cinema bars slide in from the edges.
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.0, 0.0, 0.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.offset_top = 0.0 if top else -50.0
		bar.offset_bottom = 50.0 if top else 0.0
		root.add_child(bar)
		bar.position.y += -50.0 if top else 50.0
		bar.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(bar, "position:y", bar.position.y + (50.0 if top else -50.0), 0.35)
	_build_badge(root)
	var skip := UI.label(root, "ENTER  SKIP", Vector2(730, 508), Vector2(200, 20), 11, Color(UI.WHITE, 0.4))
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.add_theme_font_override("font", UI.saira(600, 100))
	# A white flash hides the cut into the replay and out of it.
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0.85)
	root.add_child(_flash)
	_flash.create_tween().tween_property(_flash, "color:a", 0.0, 0.3)

## The REPLAY badge: a slanted crimson blade with a gold edge, the word in
## heavy italic metal over it and two play chevrons; it slams in from the
## left.
func _build_badge(root: Control) -> void:
	_badge = Control.new()
	_badge.position = Vector2(30, 6)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_badge)
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([Vector2(14, 8), Vector2(236, 8), Vector2(222, 44), Vector2(0, 44)])
	blade.color = Color("b3162d")
	_badge.add_child(blade)
	var edge := Polygon2D.new()
	edge.polygon = PackedVector2Array([Vector2(0, 44), Vector2(222, 44), Vector2(220, 48), Vector2(-2, 48)])
	edge.color = UI.GOLD
	_badge.add_child(edge)
	var chevrons := UI.label(_badge, "▶▶", Vector2(18, 10), Vector2(40, 34), 17, Color(1, 1, 1, 0.9))
	chevrons.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var word := UI.label(_badge, "REPLAY", Vector2(52, -4), Vector2(200, 56), 38, Color.WHITE)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word.add_theme_font_override("font", UI.saira(900, 112, true))
	word.add_theme_constant_override("outline_size", 6)
	word.add_theme_color_override("font_outline_color", Color("2a0508"))
	word.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	word.add_theme_constant_override("shadow_offset_x", 2)
	word.add_theme_constant_override("shadow_offset_y", 3)
	word.material = _shader(BADGE_METAL)
	_badge.position.x = -280
	_badge.scale = Vector2(1.25, 1.25)
	var slam := _badge.create_tween().set_parallel(true)
	slam.tween_property(_badge, "position:x", 30.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
	slam.tween_property(_badge, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)

func _process(delta: float) -> void:
	if celebrating:
		_celebrate_step(delta / maxf(Engine.time_scale, 0.01))
		return
	if not playing:
		return
	# Real time: the replay keeps its own pace whatever the engine scale is.
	var step := delta / maxf(Engine.time_scale, 0.01)
	_play_time += step
	_kick = move_toward(_kick, 0.0, step * 30.0)
	_shake = move_toward(_shake, 0.0, step * 0.5)
	if _play_time >= duration():
		_finish()
		return
	# The knockout freeze: ink lines burst out and the colour drains.
	var frozen := freeze_progress(_play_time)
	if is_instance_valid(_lines):
		var strength := 0.0 if frozen < 0.0 else (1.0 - frozen * 0.6)
		_lines.material.set_shader_parameter("strength", strength)
		var size := _lines.get_viewport_rect().size
		_lines.material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	var grade: ShaderMaterial = arena.nepal_stage.get("grade")
	if grade != null:
		grade.set_shader_parameter("drain", 0.0 if frozen < 0.0 else 0.55 * (1.0 - frozen))
	_apply_time(ko_time + fight_time(_play_time))

func _input(event: InputEvent) -> void:
	if not (playing or celebrating) or event.is_echo():
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if celebrating:
			_end_celebration()
		else:
			_finish()

## Pose both fighters as they were at fight time t, blending the two
## recorded frames either side of it; replays the impacts passed on the way.
func _apply_time(t: float) -> void:
	var hi := frames.size() - 1
	for k in frames.size():
		if frames[k].t >= t:
			hi = k
			break
	var lo := maxi(hi - 1, 0)
	var a: Dictionary = frames[lo]
	var b: Dictionary = frames[hi]
	var span: float = b.t - a.t
	var w := clampf((t - a.t) / span, 0.0, 1.0) if span > 0.0 else 1.0
	for i in 2:
		_pose(i, a.fighters[i], b.fighters[i], w)
	for hit in impacts:
		if hit.t > _last_t and hit.t <= t and hit.fighter >= 0:
			arena._impact_3d(_fighters()[hit.fighter], hit.blocked, hit.heavy)
			if not hit.blocked:
				# Every clean hit crash-zooms the lens.
				_kick = maxf(_kick, 7.0 if hit.heavy else 4.0)
				_shake = maxf(_shake, 0.05 if hit.heavy else 0.03)
	if _last_t < ko_time and t >= ko_time:
		arena.nepal_stage.flash(Color(1.0, 0.98, 0.94), 0.3, 0.3)
		_kick = 12.0
		_shake = 0.08
	_last_t = t
	_camera(t)

func _pose(i: int, a: Dictionary, b: Dictionary, w: float) -> void:
	var fighter: Node = _fighters()[i]
	fighter.body.global_transform = (a.body as Transform3D).interpolate_with(b.body, w)
	var nodes: Array = _nodes[i]
	for n in mini(nodes.size(), a.nodes.size()):
		var node = nodes[n]
		if not is_instance_valid(node):
			continue
		node.transform = (a.nodes[n] as Transform3D).interpolate_with(b.nodes[n], w)
		node.visible = a.visible[n] == 1
	for s in mini(_skeletons[i].size(), a.bones.size()):
		var skeleton: Skeleton3D = _skeletons[i][s]
		if not is_instance_valid(skeleton) or a.bones[s].is_empty() or b.bones[s].is_empty():
			continue
		var pa: PackedVector3Array = a.bones[s][0]
		var pb: PackedVector3Array = b.bones[s][0]
		var ra: Array = a.bones[s][1]
		var rb: Array = b.bones[s][1]
		var sa: PackedVector3Array = a.bones[s][2]
		var sb: PackedVector3Array = b.bones[s][2]
		for bone in mini(skeleton.get_bone_count(), pa.size()):
			skeleton.set_bone_pose_position(bone, pa[bone].lerp(pb[bone], w))
			skeleton.set_bone_pose_rotation(bone, (ra[bone] as Quaternion).slerp(rb[bone], w))
			skeleton.set_bone_pose_scale(bone, sa[bone].lerp(sb[bone], w))

## Every shot from the fight camera's side, square-on to the fighters:
## a wide run-up drifting in, a cut to a tight tilted two-shot for the slow
## finishing blow, a crash zoom on the knockout frame, then a pull back that
## follows the body to the floor.
func _camera(t: float) -> void:
	var camera: Camera3D = arena.camera_3d
	var loser: Node = _fighters()[ko_index]
	var winner: Node = _fighters()[1 - ko_index]
	var a: Vector3 = winner.body.global_position
	var b: Vector3 = loser.body.global_position
	var middle := (a + b) * 0.5
	var since := t - ko_time
	var frozen := freeze_progress(_play_time)
	var target: Vector3
	var distance: float
	var height: float
	var aim: float
	var fov: float
	var roll := 0.0
	if since < -SLOW_FROM:
		var k := clampf((since + LEAD) / (LEAD - SLOW_FROM), 0.0, 1.0)
		target = middle
		distance = lerpf(5.6, 4.8, k)
		height = 1.15
		aim = 1.0
		fov = 40.0
	elif frozen >= 0.0 or since <= 0.0:
		# The blow, tight and tilted; on the freeze the lens crashes in on
		# the loser.
		var k := clampf((since + SLOW_FROM) / SLOW_FROM, 0.0, 1.0)
		target = middle.lerp(b, 0.15)
		distance = lerpf(3.6, 3.3, k)
		height = 1.05
		aim = 1.1
		fov = 36.0
		roll = deg_to_rad(5.0)
		if frozen >= 0.0:
			var crash := 1.0 - pow(1.0 - minf(frozen * 3.0, 1.0), 3.0)
			target = target.lerp(b, 0.3 * crash)
			fov = lerpf(36.0, 24.0, crash)
			aim = lerpf(1.1, 1.3, crash)
			roll = deg_to_rad(lerpf(5.0, 9.0, crash))
	else:
		# The fall: pull back and drop with the body as it hits the floor.
		var k := clampf(since / TAIL, 0.0, 1.0)
		var ease_out := 1.0 - pow(1.0 - k, 2.0)
		target = middle.lerp(b, lerpf(0.45, 0.6, ease_out))
		distance = lerpf(3.4, 4.4, ease_out)
		height = lerpf(1.0, 0.6, ease_out)
		aim = lerpf(1.2, 0.45, ease_out)
		fov = lerpf(26.0, 36.0, ease_out)
		roll = deg_to_rad(lerpf(9.0, 2.0, ease_out))
	var eye := target + _view * distance + Vector3.UP * height
	var jolt := Vector3(sin(_play_time * 97.0), cos(_play_time * 71.0), 0.0) * _shake
	camera.h_offset = jolt.x
	camera.v_offset = jolt.y
	camera.position = eye
	camera.look_at(target + Vector3.UP * aim)
	camera.rotate_object_local(Vector3.BACK, roll)
	camera.fov = fov - _kick

## Back to the live fight exactly as it was when the replay began, then
## into the winner's celebration.
func _finish() -> void:
	if not playing:
		return
	playing = false
	ko_time = -1.0
	for i in 2:
		_pose(i, _live[i], _live[i], 0.0)
	for fighter in _fighters():
		fighter.get_node("Visual").set_process(true)
		fighter.body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		fighter.body.reset_physics_interpolation()
	arena._freeze(false)
	_restore_grade()
	if is_instance_valid(_overlay):
		_flash.color.a = 0.85
		_flash.create_tween().tween_property(_flash, "color:a", 0.0, 0.4)
		if is_instance_valid(_badge):
			_badge.visible = false
		if is_instance_valid(_lines):
			_lines.visible = false
		_celebrate()
	else:
		_end_celebration()

## The winner's moment: their victory animation from a low hero angle on the
## fight camera's side, the VICTORY title and marigold petals.
func _celebrate() -> void:
	celebrating = true
	_celebrate_time = 0.0
	var root: Control = _overlay.get_child(0)
	var winner: Node = _fighters()[1 - ko_index]
	var petals := CPUParticles2D.new()
	petals.position = Vector2(480, -20)
	petals.amount = 90
	petals.lifetime = 4.0
	petals.preprocess = 0.6
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(520, 10)
	petals.direction = Vector2(0.2, 1.0)
	petals.spread = 25.0
	petals.gravity = Vector2(0, 60)
	petals.initial_velocity_min = 40.0
	petals.initial_velocity_max = 110.0
	petals.angular_velocity_min = -220.0
	petals.angular_velocity_max = 220.0
	petals.angle_min = 0.0
	petals.angle_max = 360.0
	petals.scale_amount_min = 6.0
	petals.scale_amount_max = 11.0
	var colors := Gradient.new()
	colors.set_color(0, Color("ff9a1f"))
	colors.set_color(1, Color("ffd23f"))
	colors.add_point(0.5, Color("e8541c"))
	petals.color_initial_ramp = colors
	root.add_child(petals)
	root.move_child(petals, 0)
	_celebration.append(petals)
	# The titles stand on the right; the winner is framed on the left.
	var tag := UI.label(root, "विजयी", Vector2(470, 196), Vector2(440, 40), 34, UI.GOLD)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.add_theme_font_override("font", UI.teko(500))
	tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	tag.add_theme_constant_override("shadow_offset_y", 2)
	var title := UI.label(root, "VICTORY", Vector2(410, 228), Vector2(500, 90), 78, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_override("font", UI.saira(900, 112, true))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color("2a0508"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 5)
	var metal := _shader(BADGE_METAL)
	metal.set_shader_parameter("top", 0.44)
	metal.set_shader_parameter("bottom", 0.58)
	title.material = metal
	var winner_name := UI.label(root, winner.character_profile.name, Vector2(470, 318), Vector2(440, 34), 26, Color.WHITE)
	winner_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	winner_name.add_theme_constant_override("outline_size", 6)
	winner_name.add_theme_color_override("font_outline_color", Color("2a0508"))
	winner_name.add_theme_font_override("font", UI.saira(800, 125, true))
	_celebration.append_array([tag, title, winner_name])
	# The title slams down, the rest rises in after it.
	title.pivot_offset = Vector2(420, 45)
	title.scale = Vector2.ONE * 2.2
	title.modulate.a = 0.0
	var slam := title.create_tween().set_parallel(true)
	slam.tween_property(title, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.35)
	slam.tween_property(title, "modulate:a", 1.0, 0.15).set_delay(0.35)
	for node in [tag, winner_name]:
		node.modulate.a = 0.0
		node.position.y += 12
		var rise: Tween = node.create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		rise.tween_property(node, "position:y", node.position.y - 12, 0.5).set_delay(0.6)
		rise.tween_property(node, "modulate:a", 1.0, 0.4).set_delay(0.6)
	get_tree().create_timer(0.67, true, false, true).timeout.connect(func():
		if celebrating:
			arena.shake_3d = 0.04
			arena.nepal_stage.flash(Color(1.0, 0.92, 0.7), 0.25, 0.3))

func _celebrate_step(step: float) -> void:
	_celebrate_time += step
	if _celebrate_time >= CELEBRATE:
		_end_celebration()
		return
	# Low on the winner from the fight camera's side, turned a little toward
	# their front, pushing slowly in and looking up.
	var camera: Camera3D = arena.camera_3d
	var winner: Node = _fighters()[1 - ko_index]
	var loser: Node = _fighters()[ko_index]
	var at: Vector3 = winner.body.global_position
	var facing: Vector3 = loser.body.global_position - at
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.RIGHT
	var k := 1.0 - pow(1.0 - clampf(_celebrate_time / CELEBRATE, 0.0, 1.0), 2.0)
	var around := (_view * cos(0.5) + facing * sin(0.5)).normalized()
	# Shift the lens so the winner stands in the left third.
	camera.h_offset = 0.75
	camera.v_offset = 0.0
	camera.position = at + around * lerpf(3.9, 3.2, k) + Vector3.UP * lerpf(0.55, 0.7, k)
	camera.look_at(at + Vector3.UP * 1.15 + facing * 0.15)
	camera.fov = 36.0

func _end_celebration() -> void:
	celebrating = false
	_celebration.clear()
	arena.camera_3d.h_offset = 0.0
	arena.camera_3d.v_offset = 0.0
	var ui: CanvasLayer = arena.get_node_or_null("UI")
	if ui != null:
		ui.visible = true
	if is_instance_valid(_overlay):
		var overlay := _overlay
		var root: Control = overlay.get_child(0)
		var fade := root.create_tween()
		fade.tween_property(root, "modulate:a", 0.0, 0.35)
		fade.tween_callback(overlay.queue_free)
	_overlay = null
