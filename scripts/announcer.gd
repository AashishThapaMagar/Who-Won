extends Node3D
## The match announcer: Aamai, a Nepali village grandmother (Tripo model,
## assets/announcer/hajurama.glb with idle / greet / clap / cheer / victory /
## walk).
##
## Like a ring announcer she stands in the middle of the stage, between and
## just behind the two fighters, facing the camera. She appears on her spot,
## calls the round (the round's name big over her head, her call beneath),
## and when the fight starts turns sideways and walks past, across the stage
## and off to the side. She is back on her spot to clap the round's winner
## and dance for the match winner.
const MODEL := "res://assets/announcer/hajurama.glb"
## How far behind the fighters' line she stands (metres, away from camera).
const BACK := 1.1
## How far she walks past when the fight starts (metres).
const WALK_OUT := 5.0
const WALK_SPEED := 1.25
## Gone from view once she has walked this far away.
const FADE_AFTER := 3.6

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
var _hip := -1

func _ready() -> void:
	visible = false
	if not ResourceLoader.exists(MODEL):
		return
	_model = (load(MODEL) as PackedScene).instantiate()
	add_child(_model)
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
	_title = _label(Vector3(0, 2.12, 0), 120, Color("ffd34d"))
	_call = _label(Vector3(0, 1.84, 0), 60, Color("fff3dc"))

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
		_walking = false
		global_position = _spot
		scale = Vector3.ONE * 0.6
		create_tween().tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
func round_call(round_text: String) -> void:
	var lines := ["LADAI SURU!", "RAMRO SANGA LADA!", "TAYAR? LADAI SURU!"]
	call_out(round_text, lines[randi() % lines.size()], "greet", 0.0)

## The round or match winner ("" for a draw).
func winner_call(winner_name: String, match_won: bool) -> void:
	if winner_name == "":
		call_out("BARABARI!", "", "clap", 3.0)
	elif match_won:
		call_out("SHABASH, %s!" % winner_name, "KHEL JITYO!", "victory", 0.0)
	else:
		call_out("SHABASH, %s!" % winner_name, "", ["clap", "cheer"][randi() % 2], 3.0)

## Turns sideways and walks past, across the stage behind the fighters
## and off to the side.
func leave() -> void:
	if not _shown or _leaving:
		return
	_leaving = true
	_hide_at = 0.0
	_title.visible = false
	_call.visible = false
	var across := _to_camera.cross(Vector3.UP).normalized()
	_face(across)
	_walk(global_position + across * WALK_OUT, "")

func _process(delta: float) -> void:
	_clock += delta
	if _player != null and visible:
		_player.advance(delta)
		_pin_hip()
	if _hide_at > 0.0 and _clock >= _hide_at:
		leave()
	if not _walking:
		return
	var step := _walk_to - global_position
	step.y = 0.0
	var travel := WALK_SPEED * delta
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
	if _leaving and global_position.distance_to(_spot) > FADE_AFTER:
		_walking = false
		_shown = false
		_leaving = false
		visible = false
