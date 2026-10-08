extends Node3D
## The match announcer: Hajurama, a Nepali village grandmother (Tripo model,
## assets/announcer/hajurama.glb with idle / greet / clap / cheer / victory).
##
## Like a ring announcer she stands in the middle of the stage, between and
## just behind the two fighters, facing the camera: she greets the crowd
## and calls each round, steps away when the fight starts, and comes back to
## clap the round's winner and dance for the match winner. Her call floats
## over her head.
const MODEL := "res://assets/announcer/hajurama.glb"
## How far behind the fighters' line she stands (metres, away from camera).
const BACK := 1.1

var _model: Node3D
var _player: AnimationPlayer
var _call: Label3D
var _hide_at := 0.0
var _clock := 0.0
var _shown := false

func _ready() -> void:
	visible = false
	if not ResourceLoader.exists(MODEL):
		return
	_model = (load(MODEL) as PackedScene).instantiate()
	add_child(_model)
	var found := _model.find_children("*", "AnimationPlayer", true, false)
	_player = found.front() if not found.is_empty() else null
	if _player != null:
		for loop in ["idle", "clap", "cheer"]:
			var name := _clip(loop)
			if name != "":
				_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	_call = Label3D.new()
	_call.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_call.position = Vector3(0, 2.05, 0)
	_call.pixel_size = 0.0042
	_call.font_size = 64
	_call.outline_size = 18
	_call.modulate = Color("ffd34d")
	_call.outline_modulate = Color("3a0a00")
	_call.no_depth_test = true
	_call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font_path := "res://assets/fonts/Teko.ttf"
	if ResourceLoader.exists(font_path):
		_call.font = load(font_path)
	add_child(_call)

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

## Stands her centre stage between `a` and `b` (world positions), behind
## their line and turned to `camera`.
func place(a: Vector3, b: Vector3, camera: Camera3D) -> void:
	var mid := (a + b) * 0.5
	mid.y = minf(a.y, b.y)
	var to_camera := Vector3.BACK
	if camera != null:
		to_camera = camera.global_position - mid
	to_camera.y = 0.0
	to_camera = to_camera.normalized() if to_camera.length() > 0.01 else Vector3.BACK
	global_position = mid - to_camera * BACK
	# The model faces its own +X: turn that onto the camera.
	rotation.y = atan2(-to_camera.z, to_camera.x)

## Steps in with a call; `move` is her clip. `seconds` <= 0 keeps her there
## until leave().
func call_out(text: String, move: String, seconds: float) -> void:
	_call.text = text
	_play(move, move in ["greet", "victory"])
	_hide_at = _clock + seconds if seconds > 0.0 else 0.0
	if not _shown:
		_shown = true
		visible = true
		scale = Vector3.ONE * 0.6
		create_tween().tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## The round call as it starts; she stays until the fight is on.
func round_call(round_text: String) -> void:
	var lines := ["LADAI SURU!", "RAMRO SANGA LADA!", "TAYAR? LADAI SURU!"]
	call_out("%s\n%s" % [round_text, lines[randi() % lines.size()]], "greet", 0.0)

## The round or match winner ("" for a draw).
func winner_call(winner_name: String, match_won: bool) -> void:
	if winner_name == "":
		call_out("BARABARI!", "clap", 3.0)
	elif match_won:
		call_out("SHABASH, %s!\nKHEL JITYO!" % winner_name, "victory", 0.0)
	else:
		call_out("SHABASH, %s!" % winner_name, ["clap", "cheer"][randi() % 2], 3.0)

## Steps off stage.
func leave() -> void:
	if not _shown:
		return
	_shown = false
	_hide_at = 0.0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): visible = _shown)

func _process(delta: float) -> void:
	_clock += delta
	if _hide_at > 0.0 and _clock >= _hide_at:
		leave()
