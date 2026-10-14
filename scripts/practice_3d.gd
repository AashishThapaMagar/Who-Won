extends "res://scripts/arena_3d.gd"
## Immediate playable practice with the selected fighter and a training
## dummy. F2 (or clicking the left stick) cycles what the dummy does: stand, guard everything, guard
## once hit, escape grabs, or fight back as the computer.
##
## The dummy is a full fighter (it recovers from hits, gets up from
## knockdowns) driven through its own input actions, which no key is bound
## to: each mode presses them the way a player or the AI would.
const UI := preload("res://scripts/ui_kit.gd")
const DUMMY_PREFIX := "dummy_3d_"
const DUMMY_ACTIONS := ["left", "right", "far", "near", "jump", "block", "punch", "kick", "rpunch", "rkick", "grapple", "run"]
const DUMMY_MODES := ["STAND", "GUARD ALL", "GUARD AFTER FIRST HIT", "ESCAPE GRABS", "FIGHT BACK"]
var dummy_mode := 0
var dummy_ai: Node
## What each behaviour does, one line under its name.
const DUMMY_NOTES := ["Stands still and takes every hit.", "Blocks everything it can.",
	"Takes the first hit, then guards.", "Breaks out of your grabs.", "Fights back like a real rival."]
var training_card: Control
var _mode_name: Label
var _mode_note: Label
var _mode_dots: Array[Panel] = []
var _guard_hold := 0.0
var _f2_was_down := false

func _ready() -> void:
	var previous_ai := MatchSetup.vs_ai
	MatchSetup.vs_ai = false
	replay_enabled = false
	for action in DUMMY_ACTIONS:
		if not InputMap.has_action(DUMMY_PREFIX + action):
			InputMap.add_action(DUMMY_PREFIX + action)
	super._ready()
	MatchSetup.vs_ai = previous_ai
	player2.input_prefix = DUMMY_PREFIX
	$UI/P2Label.text = player2.character_profile.name + " / PRACTICE DUMMY"
	$UI/ControlsHint.text = "A/D WALK   W JUMP   S GUARD   SHIFT + FORWARD RUN   DOUBLE-TAP + HOLD FORWARD TO RUN\nF 1   V 2   G 3   B 4   H THROW   R RESET   F2 DUMMY   F1 MOVES   ESC PAUSE"
	_build_dummy_card()
	set_dummy_mode(0)

func _begin_round(index: int) -> void:
	super._begin_round(index)
	intro_timer = 0.0
	_hide_banner()
	player2.controls_enabled = true
	player2.dummy = true
	round_label.text = "FREE PRACTICE"
	pips1.hide()
	pips2.hide()

func _process(delta: float) -> void:
	if training_card != null:
		training_card.visible = not move_guide.visible and not is_paused()
	time_remaining = 9999.0
	if not move_guide.visible and not is_paused() and Input.is_action_just_pressed("restart"):
		_reset_practice()
	# F2, or clicking the left stick on the first pad.
	var f2 := Input.is_physical_key_pressed(KEY_F2) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_STICK)
	if f2 and not _f2_was_down and not move_guide.visible and not is_paused():
		step_dummy(1)
	_f2_was_down = f2
	_drive_dummy(delta)
	super._process(delta)
	timer_label.text = "--"

## The dummy card: a slim band under the timer, in the fight's own style.
## The behaviour's name large between arrows, what it does beneath, a pip
## for each of the five, and the keys that change it and reset the round.
func _build_dummy_card() -> void:
	training_card = Control.new()
	training_card.position = Vector2(250, 106)
	training_card.size = Vector2(460, 66)
	training_card.process_mode = Node.PROCESS_MODE_ALWAYS
	training_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(training_card)
	var band := Panel.new()
	band.size = Vector2(460, 62)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := UI.box(Color(0.02, 0.025, 0.045, 0.84), Color(UI.GOLD, 0.55), 0, UI.SLANT)
	face.border_width_top = 1
	face.border_width_bottom = 1
	band.add_theme_stylebox_override("panel", face)
	training_card.add_child(band)
	var eyebrow := UI.eyebrow(training_card, "DUMMY BEHAVIOUR", Vector2(0, 4), Vector2(460, 14), Color(UI.GOLD, 0.85))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_name = UI.label(training_card, "", Vector2(60, 16), Vector2(340, 24), 20, UI.WHITE)
	_mode_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_name.add_theme_font_override("font", UI.display_font())
	_mode_note = UI.label(training_card, "", Vector2(60, 37), Vector2(340, 16), 11, UI.MUTED)
	_mode_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for side in [-1, 1]:
		var arrow := Button.new()
		arrow.text = "‹" if side < 0 else "›"
		arrow.flat = true
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.position = Vector2(14 if side < 0 else 402, 12)
		arrow.size = Vector2(44, 34)
		arrow.add_theme_font_size_override("font_size", 30)
		arrow.add_theme_color_override("font_color", Color(UI.GOLD, 0.8))
		arrow.add_theme_color_override("font_hover_color", UI.GOLD)
		arrow.add_theme_color_override("font_pressed_color", UI.WHITE)
		for state in ["normal", "hover", "pressed", "focus"]:
			arrow.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		arrow.pressed.connect(func(): step_dummy(side))
		training_card.add_child(arrow)
	# One pip per behaviour, along the band's bottom edge.
	for k in DUMMY_MODES.size():
		var pip := Panel.new()
		pip.size = Vector2(14, 3)
		pip.position = Vector2(230 - DUMMY_MODES.size() * 9 + k * 18 + 2, 56)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		training_card.add_child(pip)
		_mode_dots.append(pip)
	# The keys, beneath the band: F2 changes it, R (or a click) resets.
	var keys := Control.new()
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	training_card.add_child(keys)
	var x := UI.key_hint(keys, "F2", "CHANGE", Vector2(0, 68))
	var reset_width := UI.key_hint(keys, "R", "RESET", Vector2(x, 68))
	keys.position.x = 230.0 - (x + reset_width - 16.0) * 0.5
	var reset := Button.new()
	reset.flat = true
	reset.focus_mode = Control.FOCUS_NONE
	reset.position = Vector2(keys.position.x + x - 4, 64)
	reset.size = Vector2(reset_width, 24)
	for state in ["normal", "hover", "pressed", "focus"]:
		reset.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	reset.tooltip_text = "Reset the round"
	reset.pressed.connect(_reset_practice)
	training_card.add_child(reset)

## The next (+1) or previous (-1) behaviour: the arrows and F2.
func step_dummy(direction: int) -> void:
	_slide = direction
	set_dummy_mode(posmod(dummy_mode + direction, DUMMY_MODES.size()))

var _slide := 0

func _show_dummy_mode(mode: int) -> void:
	if _mode_name == null:
		return
	_mode_name.text = DUMMY_MODES[mode]
	_mode_note.text = DUMMY_NOTES[mode]
	for k in _mode_dots.size():
		var lit := k == mode
		_mode_dots[k].add_theme_stylebox_override("panel", UI.box(UI.GOLD if lit else Color(1, 1, 1, 0.22), Color.TRANSPARENT, 0))
	# The new name slides in from the side it was asked for.
	if _slide != 0:
		for node: Label in [_mode_name, _mode_note]:
			var home := node.position.x
			node.position.x = home + 18.0 * _slide
			node.modulate.a = 0.0
			var tween := node.create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tween.tween_property(node, "position:x", home, 0.28)
			tween.tween_property(node, "modulate:a", 1.0, 0.2)
	_slide = 0

## Switches the dummy's behaviour; FIGHT BACK hands it to the computer.
func set_dummy_mode(mode: int) -> void:
	dummy_mode = mode
	_release_dummy()
	_guard_hold = 0.0
	var fighting: bool = DUMMY_MODES[mode] == "FIGHT BACK"
	if fighting and dummy_ai == null:
		dummy_ai = preload("res://scripts/ai_controller_3d.gd").new()
		dummy_ai.fighter = player2
		dummy_ai.opponent = player1
		add_child(dummy_ai)
	elif not fighting and dummy_ai != null:
		dummy_ai.queue_free()
		dummy_ai = null
	player2.ai_controlled = fighting
	_show_dummy_mode(mode)

func _drive_dummy(delta: float) -> void:
	if player2 == null or DUMMY_MODES[dummy_mode] == "FIGHT BACK":
		return
	var guard := false
	match DUMMY_MODES[dummy_mode]:
		"GUARD ALL":
			guard = true
		"GUARD AFTER FIRST HIT":
			# Up the moment it is hit, kept up for a second after the last blow.
			if player2.state in [player2.State.HITSTUN, player2.State.BLOCKSTUN]:
				_guard_hold = 1.0
			_guard_hold = maxf(0.0, _guard_hold - delta)
			guard = _guard_hold > 0.0
		"ESCAPE GRABS":
			var grabbing: bool = player1.state in [player1.State.PUNCH, player1.State.KICK] and player1.current_move.get("kind", "") == "grapple"
			if grabbing and player1.attack_timer >= player1.attack_startup() - 0.1:
				player2.throw_tech_until = player2.combat_time + 0.16
	if guard:
		Input.action_press(DUMMY_PREFIX + "block")
	else:
		Input.action_release(DUMMY_PREFIX + "block")

func _release_dummy() -> void:
	for action in DUMMY_ACTIONS:
		Input.action_release(DUMMY_PREFIX + action)

func _end_round(_winner: int) -> void:
	_reset_practice.call_deferred()

func _reset_practice() -> void:
	for fighter in [player1, player2]:
		fighter.reset_for_new_round()
	player2.controls_enabled = true
	player2.dummy = true
	combat_effects.reset()

func _exit_tree() -> void:
	_release_dummy()
