extends "res://scripts/touch_controls.gd"

var using_touch := OS.has_feature("mobile")

func _ready() -> void:
	super._ready()
	_ready_pause()
	visible = using_touch

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		using_touch = true
	elif event is InputEventKey and event.pressed:
		if using_touch:
			_exit_tree()
		using_touch = false

## Tap buttons that aren't held actions: CALL (the player's recorded
## taunt) and pause, which a phone has no key for.
var _taps: Array[Button] = []

func _process(_delta: float) -> void:
	visible = using_touch and not arena.move_guide.visible and arena.round_active
	# Keyboard labels sit where the thumbs go: hidden while playing by touch.
	for path in ["UI/ControlsHint", "UI/MovesButton", "UI/CallEnemyP1", "UI/CallEnemyP2"]:
		var item := arena.get_node_or_null(path) as CanvasItem
		if item != null and using_touch:
			item.visible = false

func _exit_tree() -> void:
	for player in [1, 2]:
		for suffix in ["left", "right", "far", "near", "jump", "block", "punch", "kick", "run"]:
			Input.action_release("p%d_3d_%s" % [player, suffix])

func _build_player(prefix: String, move_anchor: float, action_anchor: float, tint: Color) -> void:
	var action_prefix := prefix + "3d_"
	_button(action_prefix + "left", move_anchor - 38, 425, "L", tint)
	_button(action_prefix + "right", move_anchor + 38, 425, "R", tint)
	_button(action_prefix + "run", move_anchor, 292, "RUN", tint)
	_tap(action_anchor + 35, 327, "CALL", tint, func():
		for child in arena.get_children():
			if child.has_method("_call_enemy"):
				child._call_enemy(0 if prefix == "p1_" else 1))
	_button(action_prefix + "jump", action_anchor - 35, 327, "JUMP", tint)
	_button(action_prefix + "block", action_anchor - 40, 464, "GUARD", tint)
	_button(action_prefix + "punch", action_anchor + 35, 464, "LIGHT", tint)
	_button(action_prefix + "kick", action_anchor, 395, "HEAVY", tint)

## A one-shot tap button in the same round style as the held ones.
func _tap(x: float, y: float, label: String, tint: Color, action: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.size = Vector2(64.0, 64.0)
	btn.position = Vector2(x, y) - btn.size * 0.5
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	var normal := UI.box(Color(0.08, 0.1, 0.16, 0.5), Color(tint, 0.35), 2)
	normal.set_corner_radius_all(32)
	for state in ["normal", "hover", "focus"]:
		btn.add_theme_stylebox_override(state, normal)
	var pressed := UI.box(Color(tint, 0.4), Color(tint, 0.8), 2)
	pressed.set_corner_radius_all(32)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(tint, 0.8))
	btn.pressed.connect(action)
	add_child(btn)
	_taps.append(btn)

func _ready_pause() -> void:
	var pause := Button.new()
	pause.text = "II"
	pause.size = Vector2(46.0, 34.0)
	pause.position = Vector2(480.0 - 23.0, 108.0)
	pause.focus_mode = Control.FOCUS_NONE
	pause.add_theme_font_size_override("font_size", 14)
	var box := UI.box(Color(0.05, 0.06, 0.1, 0.6), Color(1, 1, 1, 0.3), 1)
	box.set_corner_radius_all(8)
	for state in ["normal", "hover", "focus", "pressed"]:
		pause.add_theme_stylebox_override(state, box)
	pause.pressed.connect(func():
		if arena.has_method("_pause"):
			arena._pause())
	add_child(pause)
