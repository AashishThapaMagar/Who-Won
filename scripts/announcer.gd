extends Node3D
## The arena's host: a local character for each arena (a Newar hajurbuwa,
## a Tharu didi, Aamai the village grandmother, a lama, a Sherpa dai; Tripo
## models in assets/announcer/ with idle / greet / clap / cheer / victory /
## walk).
##
## The rounds are called on screen (ROUND n, then FIGHT!); the host is part
## of the scenery (spectate()): a local walking past behind the fight now
## and then. The
## walk-up call (call_out, round_call, leave) is kept for cutscenes.
const MODEL := "res://assets/announcer/hajurama.glb"
## Each arena has its own announcer (stage index as in nepal_stage_3d
## ROUNDS): model and the greeting that opens their round call. A missing
## model falls back to Aamai.
## The call keeps to the arcade's logic: the round, "Ready?", then FIGHT!
## on screen as the host steps away. Only the first time they walk out do
## they greet the crowd in their own tradition (a Newar ज्वजलपा, a Tharu राम
## राम, a lama's टासी देलेक, a Sherpa's कि कि सो सो). Each language keeps
## its own script.
const HOSTS := {
	# Heritage Square: a Newar hajurbuwa.
	0: {"model": "res://assets/announcer/hajurbuwa.glb", "height": 1.64,
		# The pagoda at the back of the square: the foot and top of its front
		# steps and a point just inside its door (world positions).
		"temple": {"foot": Vector3(0, -0.12, -19.2), "top": Vector3(0, 1.0, -20.9), "door": Vector3(0, 1.0, -22.6)},
		"hello": {"ne": "ज्वजलपा!", "en": "JWAJALAPA!"},
		"match": {"ne": "खेल जित्यो!", "en": "THE MATCH IS WON!"}},
	# Terai Plains: a Tharu didi.
	1: {"model": "res://assets/announcer/tharu_didi.glb", "height": 1.58,
		"hello": {"ne": "राम राम!", "en": "RAM RAM!"},
		"match": {"ne": "खेल जित्यो!", "en": "THE MATCH IS WON!"}},
	# Hill Village: Aamai, a village hajuramaa.
	2: {"model": MODEL,
		"hello": {"ne": "नमस्ते!", "en": "NAMASTE!"},
		"match": {"ne": "खेल जित्यो!", "en": "THE MATCH IS WON!"}},
	# Gompa Courtyard: a lama.
	3: {"model": "res://assets/announcer/lama.glb", "height": 1.68,
		"hello": {"ne": "टासी देलेक!", "en": "TASHI DELEK!"},
		"match": {"ne": "टासी देलेक!", "en": "TASHI DELEK!"}},
	# Himalayan Pass: a Sherpa dai.
	4: {"model": "res://assets/announcer/sherpa_dai.glb", "height": 1.72,
		"hello": {"ne": "कि कि सो सो!", "en": "KI KI SO SO!"},
		"match": {"ne": "ल्हा ग्यालो!", "en": "LHA GYALO!"}},
	# Dashain Ground: Aamai again, under the kites.
	5: {"model": MODEL,
		"hello": {"ne": "जय होस्!", "en": "VICTORY TO THE BRAVE!"},
		"match": {"ne": "जय होस्!", "en": "VICTORY TO THE BRAVE!"}},
}
## Which arena this match is in (set by the arena before she is added).
var stage := 2
var _host: Dictionary = {}
## How far behind the fighters' line she stands (metres, away from camera).
const BACK := 1.1
## Her walk in to her spot, and on past the camera when the fight starts
## (metres).
const WALK_IN := 1.2
const WALK_OUT := 6.0
## Out of view once she is this close to the camera (metres).
const CAMERA_CLEAR := 1.6
## An unhurried grandmother's pace (m/s): in to her spot, a little brisker
## on the way out. CLIP_SPEED is how far her walk clip carries her per
## second at 1x, so the steps play at the speed she really moves and her
## feet don't skate.
const WALK_SPEED := 0.95
const LEAVE_SPEED := 1.6
const CLIP_SPEED := 1.07
## Gone once she has walked this far away, or out of the camera's view.
const FADE_AFTER := 5.0
## When her round call waits (round one: the VS card plays first).
var _start_at := -1.0
var _greeted := false
var _pending := {}

var _model: Node3D
var _player: AnimationPlayer
var _title: Label3D
var _call: Label3D
var _hide_at := 0.0
var _clock := 0.0
var _shown := false
## Her spot and the flat direction from it toward the camera.
var _spot := Vector3.ZERO
var _to_camera := Vector3.BACK
## The walk under way: where to, and what she does on arrival.
var _walking := false
var _walk_to := Vector3.ZERO
var _arrive_move := ""
var _leaving := false
var _skeleton: Skeleton3D
## A call held until `_queued_ready` says go (or the wait runs out).
var _queued_call := Callable()
var _queued_ready := Callable()
var _queued_until := 0.0
var _camera: Camera3D
var _hip := -1

func _ready() -> void:
	visible = false
	_host = HOSTS.get(stage, HOSTS[2])
	var path: String = _host.model if ResourceLoader.exists(_host.model) else MODEL
	if path == MODEL and not stage in [2, 5]:
		_host = HOSTS[2]
	if not ResourceLoader.exists(path):
		return
	_model = (load(path) as PackedScene).instantiate()
	add_child(_model)
	# Each model comes out of Tripo at its own size: stand them at their
	# real heights.
	if _host.has("height"):
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		if bounds.size.y > 0.1:
			_model.scale = Vector3.ONE * float(_host.height) / bounds.size.y
	var found := _model.find_children("*", "AnimationPlayer", true, false)
	_player = found.front() if not found.is_empty() else null
	if _player != null:
		for loop in ["idle", "clap", "cheer", "walk"]:
			var name := _clip(loop)
			if name != "":
				_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
		# Advanced by hand so the hip can be held in place after each step.
		_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0]
		_hip = _skeleton.find_bone("Hip")
	_title = _label(Vector3(0, 2.04, 0), 120, Color("ffd34d"))
	_call = _label(Vector3(0, 1.8, 0), 60, Color("fff3dc"))

## Holds the hip over her spot: some clips (the greeting) carry her most
## of a metre across the floor, and the game moves her itself. Only the
## up-down bob is kept.
func _pin_hip() -> void:
	if _skeleton == null or _hip < 0:
		return
	# The hip's position is in its parent's (rotated) space: compare in the
	# skeleton's own upright space and keep only the vertical part.
	var parent := _skeleton.get_bone_parent(_hip)
	var to_skeleton := _skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	var rest := to_skeleton * _skeleton.get_bone_rest(_hip).origin
	var at := to_skeleton * _skeleton.get_bone_pose_position(_hip)
	_skeleton.set_bone_pose_position(_hip, to_skeleton.inverse() * Vector3(rest.x, at.y, rest.z))

func _label(at: Vector3, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	label.pixel_size = 0.0036
	label.font_size = size
	label.outline_size = size / 4
	label.modulate = color
	label.outline_modulate = Color("3a0a00")
	label.no_depth_test = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Nepali in a Devanagari face with true Devanagari numerals; English
	# in Teko.
	if Settings.is_nepali():
		label.font = preload("res://scripts/ui_kit.gd").devanagari_font()
	else:
		var font_path := "res://assets/fonts/Teko.ttf"
		if ResourceLoader.exists(font_path):
			label.font = load(font_path)
	add_child(label)
	return label

func _clip(key: String) -> String:
	if _player == null:
		return ""
	for name in _player.get_animation_list():
		if String(name).to_lower().contains(key):
			return name
	return ""

func _play(key: String, then_idle := false) -> void:
	var name := _clip(key)
	if name == "":
		return
	_player.play(name, 0.25)
	if then_idle and _clip("idle") != "":
		_player.queue(_clip("idle"))

## Turns her own front (the model's +X) onto the flat direction `facing`.
func _face(facing: Vector3) -> void:
	rotation.y = atan2(-facing.z, facing.x)

## Her spot: centre stage between `a` and `b` (world positions), behind
## their line, turned to `camera`.
func place(a: Vector3, b: Vector3, camera: Camera3D) -> void:
	var mid := (a + b) * 0.5
	mid.y = minf(a.y, b.y)
	var to_camera := Vector3.BACK
	if camera != null:
		to_camera = camera.global_position - mid
	to_camera.y = 0.0
	_to_camera = to_camera.normalized() if to_camera.length() > 0.01 else Vector3.BACK
	_spot = mid - _to_camera * BACK
	_camera = camera

## Her call: she appears on her spot if she isn't there, then plays
## `move`. `seconds` <= 0 keeps her there until leave().
func call_out(title: String, text: String, move: String, seconds: float) -> void:
	_title.text = title
	_call.text = text
	_title.visible = false
	_call.visible = false
	_hide_at = _clock + seconds if seconds > 0.0 else 0.0
	if not _shown or _leaving:
		_shown = true
		_leaving = false
		visible = true
		# From further back, walking toward the camera.
		global_position = _spot - _to_camera * WALK_IN
		_face(_to_camera)
		_walk(_spot, move)
	else:
		_arrive(move)

func _walk(to: Vector3, then_move: String) -> void:
	_walking = true
	_walk_to = to
	_arrive_move = then_move
	_play("walk")

func _arrive(move: String) -> void:
	_walking = false
	_face(_to_camera)
	_title.visible = _title.text != ""
	_call.visible = _call.text != ""
	_play(move, move in ["greet", "victory"])

## The round call as it starts: the round over her head, her call below;
## she stays until the fight is on.
func round_call(round_text: String, delay := 0.0) -> void:
	# "Ready?" every round; the greeting only on the host's first walk out.
	var line: String = tr("READY?")
	if not _greeted:
		_greeted = true
		line = str(_lines("hello")) + "  " + line
	if delay > 0.0:
		# Waits off stage (round one's VS card), then walks up.
		_pending = {"title": round_text, "text": line}
		_start_at = _clock + delay
		return
	call_out(round_text, line, "greet", 0.0)

## This host's lines for `key` in the player's language.
func _lines(key: String) -> Variant:
	var entry: Dictionary = _host.get(key, HOSTS[2][key])
	return entry.get("ne" if Settings.is_nepali() else "en")

## The round or match winner ("" for a draw).
func winner_call(winner_name: String, match_won: bool) -> void:
	var shown := tr(winner_name)
	if winner_name == "":
		call_out(tr("DRAW") + "!", "", "clap", 3.0)
	elif match_won:
		call_out(tr("WELL FOUGHT, %s!") % shown, str(_lines("match")), "victory", 0.0)
	else:
		call_out(tr("WELL FOUGHT, %s!") % shown, "", ["clap", "cheer"][randi() % 2], 3.0)

## ── Passer-by ──────────────────────────────────────────────────────────
## The host no longer calls the rounds (ROUND 1 / FIGHT! is on screen) and
## never claps or cheers: they are just a local walking past behind the
## fight now and then, side to side at an unhurried pace, a little nearer
## or further each time, then gone for a while.
const CROSS_HALF := 7.0
const CROSS_DEPTH := [2.6, 4.8]
const CROSS_WAIT := [6.0, 18.0]
var spectating := false
var _crossing := false
var _path: Array[Vector3] = []
## Heritage Square: whether he went into the temple last time.
var _inside := false
var _next_cross := 0.0
var _centre := Vector3.ZERO

func spectate(a: Vector3, b: Vector3, camera: Camera3D) -> void:
	if spectating:
		return
	place(a, b, camera)
	_centre = _spot + _to_camera * BACK
	spectating = true
	_title.visible = false
	_call.visible = false
	visible = false
	_next_cross = _clock + randf_range(1.5, 5.0)

## Kept for callers: a passer-by doesn't react to the fight.
func react() -> void:
	pass

func _cross_tick(delta: float) -> void:
	if not spectating:
		return
	if not _crossing:
		if _clock < _next_cross:
			return
		_path = _temple_path() if _host.has("temple") else _side_path()
		global_position = _path.pop_front()
		_crossing = true
		_shown = true
		visible = true
		_play("walk")
		return
	if _path.is_empty():
		_crossing = false
		_shown = false
		visible = false
		_next_cross = _clock + randf_range(CROSS_WAIT[0], CROSS_WAIT[1])
		return
	# Along the path at walking pace (the height follows the steps); facing
	# where he is going.
	var step: Vector3 = _path[0] - global_position
	var flat := Vector3(step.x, 0.0, step.z)
	if flat.length() > 0.01:
		_face(flat.normalized())
	var travel := WALK_SPEED * delta
	if step.length() <= travel:
		global_position = _path.pop_front()
		return
	global_position += step.normalized() * travel

## Side to side behind the fight, a little nearer or further each time.
func _side_path() -> Array[Vector3]:
	var side := _to_camera.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
	var lane := _centre - _to_camera * randf_range(CROSS_DEPTH[0], CROSS_DEPTH[1])
	return [lane + side * CROSS_HALF, lane - side * CROSS_HALF]

## Heritage Square: across the square, up the pagoda steps and in through
## its door; the next time, out of the door, down the steps and away.
func _temple_path() -> Array[Vector3]:
	var temple: Dictionary = _host.temple
	var side := _to_camera.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
	var start := _centre - _to_camera * randf_range(CROSS_DEPTH[0], CROSS_DEPTH[1]) + side * CROSS_HALF
	var into: Array[Vector3] = [start, temple.foot, temple.top, temple.door]
	_inside = not _inside
	if _inside:
		return into
	into[0] = _centre - _to_camera * randf_range(CROSS_DEPTH[0], CROSS_DEPTH[1]) - side * CROSS_HALF
	into.reverse()
	return into

## Where the camera looks when it frames her: her spot at head height, so
## her call fits in the shot. Fixed while she walks.
func focus() -> Vector3:
	return _spot + Vector3.UP * 1.58

## FIGHT!: a call still waiting is dropped; if she is already walking off
## she carries on (a quick shrink only if she never got going).
func vanish() -> void:
	_pending = {}
	_start_at = -1.0
	if not _shown or _leaving:
		return
	_shown = false
	_leaving = false
	_walking = false
	_hide_at = 0.0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		visible = _shown
		scale = Vector3.ONE)

## Holds `call` until `ready` returns true (at most `timeout` seconds).
func queue(call: Callable, ready: Callable, timeout := 8.0) -> void:
	_queued_call = call
	_queued_ready = ready
	_queued_until = _clock + timeout

## Steps off the way a ring announcer clears the ring: turns and walks to
## the side and upstage, behind the fighters' line, never through them or
## into the lens.
func leave() -> void:
	if not _shown or _leaving:
		return
	_leaving = true
	_hide_at = 0.0
	_title.visible = false
	_call.visible = false
	var side := _to_camera.cross(Vector3.UP).normalized()
	var away := (side * 0.85 - _to_camera * 0.5).normalized()
	_face(away)
	_walk(global_position + away * WALK_OUT, "")

func _process(delta: float) -> void:
	_clock += delta
	if _start_at >= 0.0 and _clock >= _start_at and not _pending.is_empty():
		_start_at = -1.0
		var call: Dictionary = _pending
		_pending = {}
		call_out(call.title, call.text, "greet", 0.0)
	if _queued_call.is_valid() and (_clock > _queued_until or bool(_queued_ready.call())):
		var call := _queued_call
		_queued_call = Callable()
		call.call()
	if _player != null and visible:
		var rate := 1.0
		if _walking or _crossing:
			rate = (LEAVE_SPEED if _leaving else WALK_SPEED) / CLIP_SPEED
		_player.advance(delta * rate)
		_pin_hip()
	_cross_tick(delta)
	if _hide_at > 0.0 and _clock >= _hide_at:
		leave()
	if not _walking:
		return
	var step := _walk_to - global_position
	step.y = 0.0
	var travel := (LEAVE_SPEED if _leaving else WALK_SPEED) * delta
	if step.length() <= travel:
		global_position = _walk_to
		if _leaving:
			_walking = false
			_shown = false
			_leaving = false
			visible = false
		else:
			_arrive(_arrive_move)
		return
	global_position += step.normalized() * travel
	var near_camera := _camera != null and is_instance_valid(_camera) and global_position.distance_to(_camera.global_position) < CAMERA_CLEAR
	var out_of_shot := _camera != null and is_instance_valid(_camera) and not _camera.is_position_in_frustum(global_position + Vector3.UP * 0.9)
	if _leaving and (near_camera or out_of_shot or global_position.distance_to(_spot) > FADE_AFTER):
		_walking = false
		_shown = false
		_leaving = false
		visible = false
