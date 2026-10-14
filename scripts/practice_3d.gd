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
var mode_label: Label
var training_card: Control
var dummy_picker: OptionButton
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
	# Centred under the timer, clear of both fighters' names and bars.
	training_card = UI.panel($UI, Vector2(230, 112), Vector2(500, 40), Color(0.025, 0.03, 0.055, 0.92), Color(UI.GOLD, 0.5))
	training_card.process_mode = Node.PROCESS_MODE_ALWAYS
	mode_label = UI.label(training_card, "DUMMY", Vector2(14, 11), Vector2(66, 18), 12, UI.GOLD)
	mode_label.add_theme_font_override("font", UI.strong_font())
	mode_label.add_theme_constant_override("outline_size", 4)
	mode_label.add_theme_color_override("font_outline_color", UI.INK)
	dummy_picker = OptionButton.new()
	dummy_picker.position = Vector2(80, 6)
	dummy_picker.size = Vector2(240, 28)
	dummy_picker.fit_to_longest_item = false
	for mode in DUMMY_MODES:
		dummy_picker.add_item(mode)
	dummy_picker.item_selected.connect(set_dummy_mode)
	dummy_picker.get_popup().about_to_popup.connect(func(): get_tree().paused = true)
	dummy_picker.get_popup().popup_hide.connect(func(): get_tree().paused = false)
	training_card.add_child(dummy_picker)
	var reset := UI.button(training_card, "RESET [R]", Vector2(330, 6), Vector2(110, 28))
	reset.add_theme_font_size_override("font_size", 11)
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_reset_practice)
	UI.label(training_card, "F2", Vector2(450, 11), Vector2(40, 18), 11, UI.MUTED).tooltip_text = "Cycle dummy behaviour"
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
		set_dummy_mode((dummy_mode + 1) % DUMMY_MODES.size())
	_f2_was_down = f2
	_drive_dummy(delta)
	super._process(delta)
	timer_label.text = "--"

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
	if mode_label != null:
		mode_label.text = "DUMMY"
	if dummy_picker != null:
		dummy_picker.select(mode)

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
