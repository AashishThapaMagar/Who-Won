extends "res://scripts/touch_controls.gd"
## Phone controls for the 3D fight, the way mobile fighting games play:
##
##  * Left thumb: a floating joystick. Touch anywhere in the movement zone
##    and the stick appears under the thumb; slide left/right to walk, far
##    to run, up to jump, down to crouch (the same as W/A/S/D). Pulled down,
##    1/2 rise into the uppercut and 3/4 sweep.
##  * Right thumb: four big attack buttons in Tekken's 1 2 / 3 4 layout
##    (punches above, kicks below), a large GUARD, GRAB, SUPER (2 + 4
##    together) and CALL.
##
## Every finger is tracked on its own (screen touch index), so moving,
## guarding and attacking all work at once; standard Buttons only follow
## one finger. Presses go through the same p1_3d_* / p2_3d_* actions as
## the keyboard, so nothing downstream knows the difference. Drawn by hand
## in _draw: translucent, lit while held, a short buzz on each attack.

var using_touch := OS.has_feature("mobile")

const STICK_RADIUS := 62.0
const STICK_DEAD := 16.0
const STICK_RUN := 58.0
const STICK_VERTICAL := 40.0

## One per player: {prefix, zone, rest, base, knob, touch, held}.
var _sticks: Array[Dictionary] = []
## {actions, center, radius, label, caption, color, kind ("hold"/"tap"),
##  touch (index or -1), callback}
var _pads: Array[Dictionary] = []
var _owner := {}   # touch index -> ["stick", i] or ["pad", i]

func _ready() -> void:
	super._ready()
	_ready_pause()
	visible = using_touch
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		using_touch = true
	elif event is InputEventKey and event.pressed:
		if using_touch:
			_exit_tree()
		using_touch = false
	if not using_touch or not visible:
		return
	if event is InputEventScreenTouch:
		var at: Vector2 = (make_input_local(event) as InputEventScreenTouch).position
		if event.pressed:
			_touch_down(event.index, at)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		var at: Vector2 = (make_input_local(event) as InputEventScreenDrag).position
		_touch_drag(event.index, at)

func _process(_delta: float) -> void:
	var was := visible
	visible = using_touch and not arena.move_guide.visible and arena.round_active
	if was and not visible:
		_release_all()
	# Keyboard labels sit where the thumbs go: hidden while playing by touch.
	for path in ["UI/ControlsHint", "UI/MovesButton", "UI/CallEnemyP1", "UI/CallEnemyP2"]:
		var item := arena.get_node_or_null(path) as CanvasItem
		if item != null and using_touch:
			item.visible = false
	if visible:
		queue_redraw()

func _exit_tree() -> void:
	_release_all()
	for player in [1, 2]:
		for suffix in ["left", "right", "far", "near", "jump", "block", "crouch", "punch", "kick", "rpunch", "rkick", "grapple", "run"]:
			Input.action_release("p%d_3d_%s" % [player, suffix])

## ── Layout ──
## Called by the base class: once for a lone touch player (full width), or
## once per side in local two-player (each keeps to its own half).
func _build_player(prefix: String, move_anchor: float, action_anchor: float, tint: Color) -> void:
	var p := prefix + "3d_"
	var solo := absf(move_anchor - action_anchor) > 500.0
	var left_side := move_anchor < 480.0
	# The movement zone: the near third of the screen (its own strip in 2P).
	var zone := Rect2(0, 130, 430, 410) if solo else (Rect2(0, 150, 175, 390) if left_side else Rect2(785, 150, 175, 390))
	_sticks.append({"prefix": p, "zone": zone, "rest": Vector2(move_anchor + (20.0 if left_side else -20.0), 430.0),
		"base": Vector2.ZERO, "knob": Vector2.ZERO, "touch": -1, "held": {}})
	var a := action_anchor
	var punch := Color("ffc53d")
	var kick := Color("ff8a4c")
	# 1 2 / 3 4: punches above, kicks below.
	_pad([p + "punch"], Vector2(a - 42, 388), 35, "1", "PUNCH", punch)
	_pad([p + "rpunch"], Vector2(a + 42, 388), 35, "2", "PUNCH", punch)
	_pad([p + "kick"], Vector2(a - 42, 470), 35, "3", "KICK", kick)
	_pad([p + "rkick"], Vector2(a + 42, 470), 35, "4", "KICK", kick)
	if solo:
		_pad([p + "block"], Vector2(a - 132, 462), 38, "GUARD", "", Color("7fd3ff"))
		_pad([p + "grapple"], Vector2(a - 132, 376), 28, "GRAB", "", Color("d7b8ff"))
		_pad([p + "rpunch", p + "rkick"], Vector2(a + 42, 306), 26, "SUPER", "2+4", Color("ffe28a"))
		_pad([], Vector2(a - 52, 306), 24, "CALL", "", Color(tint, 0.9), "tap", func(): _call_enemy(prefix))
	else:
		_pad([p + "block"], Vector2(a - 42, 306), 30, "GUARD", "", Color("7fd3ff"))
		_pad([p + "grapple"], Vector2(a + 42, 306), 26, "GRAB", "", Color("d7b8ff"))

func _pad(actions: Array, center: Vector2, radius: float, label: String, caption: String, color: Color, kind := "hold", callback := Callable()) -> void:
	_pads.append({"actions": actions, "center": center, "radius": radius, "label": label, "caption": caption,
		"color": color, "kind": kind, "touch": -1, "callback": callback})

func _call_enemy(prefix: String) -> void:
	for child in arena.get_children():
		if child.has_method("_call_enemy"):
			child._call_enemy(0 if prefix == "p1_" else 1)

## ── Touches ──
func _touch_down(index: int, at: Vector2) -> void:
	# A pad under the finger (a little forgiving round each button).
	for i in _pads.size():
		var pad: Dictionary = _pads[i]
		if pad.touch < 0 and at.distance_to(pad.center) <= pad.radius + 10.0:
			pad.touch = index
			_owner[index] = ["pad", i]
			if pad.kind == "tap":
				pad.callback.call()
			else:
				for action in pad.actions:
					Input.action_press(action)
				Input.vibrate_handheld(14)
			return
	for i in _sticks.size():
		var stick: Dictionary = _sticks[i]
		if stick.touch < 0 and stick.zone.has_point(at):
			stick.touch = index
			stick.base = at
			stick.knob = at
			_owner[index] = ["stick", i]
			return

func _touch_drag(index: int, at: Vector2) -> void:
	if not _owner.has(index):
		return
	var own: Array = _owner[index]
	if own[0] != "stick":
		return
	var stick: Dictionary = _sticks[own[1]]
	var offset: Vector2 = at - stick.base
	# The base trails a thumb that pushes past the rim, so the stick never
	# runs out of travel.
	if offset.length() > STICK_RADIUS * 1.6:
		stick.base = at - offset.normalized() * STICK_RADIUS * 1.6
		offset = at - stick.base
	stick.knob = stick.base + offset.limit_length(STICK_RADIUS)
	_steer(stick, offset)

func _touch_up(index: int) -> void:
	if not _owner.has(index):
		return
	var own: Array = _owner[index]
	_owner.erase(index)
	if own[0] == "pad":
		var pad: Dictionary = _pads[own[1]]
		pad.touch = -1
		for action in pad.actions:
			# Guard may still be held by the stick.
			if not (action.ends_with("block") and _stick_holds(action)):
				Input.action_release(action)
	else:
		var stick: Dictionary = _sticks[own[1]]
		stick.touch = -1
		_steer(stick, Vector2.ZERO)

## Turns the stick's offset into held directions: left/right past the dead
## zone, run further out, jump up, crouch down.
func _steer(stick: Dictionary, offset: Vector2) -> void:
	var p: String = stick.prefix
	var want := {
		p + "left": offset.x < -STICK_DEAD,
		p + "right": offset.x > STICK_DEAD,
		p + "run": absf(offset.x) > STICK_RUN,
		p + "jump": offset.y < -STICK_VERTICAL,
		p + "crouch": offset.y > STICK_VERTICAL,
	}
	for action: String in want:
		var held: bool = stick.held.get(action, false)
		if want[action] and not held:
			Input.action_press(action)
		elif held and not want[action]:
			# Guard may still be held by the GUARD button.
			if not (action.ends_with("block") and _pad_holds(action)):
				Input.action_release(action)
		stick.held[action] = want[action]

func _pad_holds(action: String) -> bool:
	for pad in _pads:
		if pad.touch >= 0 and action in pad.actions:
			return true
	return false

func _stick_holds(action: String) -> bool:
	for stick in _sticks:
		if stick.held.get(action, false):
			return true
	return false

func _release_all() -> void:
	for index in _owner.keys():
		_touch_up(index)
	_owner.clear()

## ── Drawing ──
func _draw() -> void:
	var font := UI.strong_font()
	for stick in _sticks:
		var active: bool = stick.touch >= 0
		var base: Vector2 = stick.base if active else stick.rest
		var knob: Vector2 = stick.knob if active else stick.rest
		draw_circle(base, STICK_RADIUS, Color(0.05, 0.06, 0.1, 0.32 if active else 0.18))
		draw_arc(base, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.45 if active else 0.22), 2.0, true)
		# Little arrows for the four directions.
		for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var tip: Vector2 = base + dir * (STICK_RADIUS - 10.0)
			var side := Vector2(-dir.y, dir.x) * 6.0
			draw_colored_polygon(PackedVector2Array([tip, tip - dir * 9.0 + side, tip - dir * 9.0 - side]), Color(1, 1, 1, 0.35 if active else 0.2))
		draw_circle(knob, 26.0, Color(1, 1, 1, 0.55 if active else 0.25))
		if not active:
			draw_string(font, base + Vector2(-60, STICK_RADIUS + 18), tr("MOVE"), HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(1, 1, 1, 0.45))
	for pad in _pads:
		var held: bool = pad.touch >= 0
		var c: Color = pad.color
		draw_circle(pad.center, pad.radius, Color(c, 0.42) if held else Color(0.05, 0.06, 0.1, 0.38))
		draw_arc(pad.center, pad.radius, 0, TAU, 48, Color(c, 0.95 if held else 0.55), 2.5 if held else 2.0, true)
		var big: bool = String(pad.label).length() == 1
		var size := 26 if big else (12 if pad.radius < 30 else 13)
		var label_y: float = pad.center.y + (size * 0.36 if pad.caption == "" else (size * 0.2 if big else 0.0))
		var text_color := Color(0.04, 0.05, 0.09) if held else Color(c, 0.95)
		draw_string(font, Vector2(pad.center.x - pad.radius, label_y), tr(pad.label), HORIZONTAL_ALIGNMENT_CENTER, pad.radius * 2.0, size, text_color)
		if pad.caption != "":
			var cap_y: float = pad.center.y + (pad.radius * 0.62 if big else 13.0)
			draw_string(font, Vector2(pad.center.x - pad.radius, cap_y), tr(pad.caption), HORIZONTAL_ALIGNMENT_CENTER, pad.radius * 2.0, 9, Color(text_color, 0.8))

## Pause: a phone has no Esc key.
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
