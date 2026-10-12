extends Node
## Presentation only: combat and round state remain owned by Arena.
const UI := preload("res://scripts/ui_kit.gd")
var arena: Node
var health_labels: Array[Label] = []
var damage_bars: Array[ProgressBar] = []
var damage_tweens: Array[Tween] = []
var result_panel: Panel
var next_button: Button
var result_detail: Label
var stamina_bars: Array[ProgressBar] = []
## Gold super meters under the names (fighters with a super only), and the
## SUPER READY tag that pulses beside a full one.
var super_bars: Array[ProgressBar] = []
var super_tags: Array[Label] = []
## A one-time tip the first time anyone's super meter fills.
var super_tip: Control
var callout_style := false
## Hand-drawn gauges and clock plate (hud_gauges.gd); the ProgressBars
## below stay as invisible data holders for combat code and tests.
var gauges: Control
var movebook: Control
## Match-opening "VS" clash over the round-one intro, the PERFECT callout
## and the training-style input history.
var clash: Control
var perfect_label: Label
var input_display: Control
var input_history: Array = [[], []]
var last_result_visible := false
## Whether the clash has played for the current match (round one's intro),
## and how long it has been up (the round call waits behind it).
var clash_played := false
var clash_time := 0.0
const CLASH_HOLD := 1.15
## Per-player match statistics for the results card: damage dealt, best
## combo, knockouts and perfect rounds. Reset when round one opens.
var stats: Array = [{}, {}]
var stat_values: Array = [[], []]
var last_health: Array = [0, 0]
var ko_label: Label
var fx: Control
var title_tags: Array[Label] = []
## Practice mode: what the last strike was and what it did.
var readout: Label
var readout_pending := -1
var readout_move := ""
var readout_blocked := false
## Damage of the combo the readout is following, per defender.
var readout_combo: Array = [0, 0]
var call_buttons: Array[Button] = []
var intro_hud_alpha := 1.0
var name_plates: Array[Polygon2D] = []

func _ready() -> void:
	arena = get_parent()
	var layer: CanvasLayer = arena.get_node("UI")
	for player in 2:
		var key := "T" if player == 0 else "U"
		var button := UI.button(layer, "P%d CALL ENEMY [%s]" % [player + 1, key], Vector2(18 + player * 186, 434 if MatchSetup.practice else 468), Vector2(176, 28))
		button.name = "CallEnemyP%d" % (player + 1)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 11)
		button.visible = player == 0 or (not MatchSetup.vs_ai and not MatchSetup.practice)
		button.pressed.connect(_call_enemy.bind(player))
		call_buttons.append(button)
	gauges = preload("res://scripts/hud_gauges.gd").new()
	gauges.hud = self
	gauges.arena = arena
	layer.add_child(gauges)
	layer.move_child(gauges, 0)
	UI.panel(layer, Vector2(0, 506), Vector2(960, 34), Color(0.0, 0.0, 0.02, 0.5)).z_index = -1
	for i in 2:
		var color := UI.LIME if i == 0 else UI.VIOLET
		var x := 36.0 if i == 0 else 552.0
		var bar: ProgressBar = arena.health_bar1 if i == 0 else arena.health_bar2
		var name_label: Label = layer.get_node("P1Label" if i == 0 else "P2Label")
		# Big italic fighter name under the gauge, outer-aligned.
		name_label.position = Vector2(34 if i == 0 else 546, 52)
		name_label.size = Vector2(380, 34)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		name_label.add_theme_font_override("font", UI.display_font())
		name_label.add_theme_font_size_override("font_size", 25)
		name_label.add_theme_color_override("font_color", UI.WHITE)
		name_label.add_theme_color_override("font_shadow_color", Color("d7263d") if i == 0 else Color("2f6fd1"))
		name_label.add_theme_constant_override("shadow_offset_x", 3)
		name_label.add_theme_constant_override("shadow_offset_y", 3)
		name_label.add_theme_color_override("font_outline_color", UI.INK)
		name_label.add_theme_constant_override("outline_size", 6)
		bar.position = Vector2(x, 36)
		bar.size = Vector2(372, 18)
		bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 0 else ProgressBar.FILL_END_TO_BEGIN
		bar.add_theme_stylebox_override("background", UI.box(Color("282c36"), UI.LINE, 0))
		bar.add_theme_stylebox_override("fill", UI.box(color, color, 0))
		var damage := ProgressBar.new()
		damage.position = bar.position
		damage.size = bar.size
		damage.max_value = bar.max_value
		damage.value = bar.value
		damage.fill_mode = bar.fill_mode
		damage.show_percentage = false
		damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		damage.add_theme_stylebox_override("background", UI.box(Color("282c36"), UI.LINE, 0))
		damage.add_theme_stylebox_override("fill", UI.box(UI.RED, UI.RED, 0))
		damage.size = bar.size
		layer.add_child(damage)
		damage.set_deferred("size", Vector2(372, 18))
		layer.move_child(damage, bar.get_index())
		bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		bar.modulate.a = 0.0
		damage.modulate.a = 0.0
		damage_bars.append(damage)
		damage_tweens.append(null)
		var pips: Label = arena.pips1 if i == 0 else arena.pips2
		pips.position = Vector2(x, 54)
		pips.size = Vector2(372, 22)
		pips.add_theme_color_override("font_color", color)
		pips.add_theme_font_size_override("font_size", 15)
		pips.hide()
		var health := UI.label(layer, "100 / 100", Vector2(x + 245 if i == 0 else x, 70), Vector2(127, 20), 11, UI.MUTED)
		health.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 0 else HORIZONTAL_ALIGNMENT_LEFT
		health.hide()
		health_labels.append(health)
		var fighter: Node = arena.player1 if i == 0 else arena.player2
		var stamina_bar := ProgressBar.new()
		stamina_bar.position = Vector2(x + 90, 61)
		stamina_bar.size = Vector2(145, 6)
		stamina_bar.show_percentage = false
		stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stamina_bar.add_theme_stylebox_override("background", UI.box(Color("282c36"), UI.LINE, 0))
		stamina_bar.add_theme_stylebox_override("fill", UI.box(Color("56cbbc"), Color("56cbbc"), 0))
		layer.add_child(stamina_bar)
		stamina_bar.set_deferred("size", Vector2(145, 6))
		stamina_bar.visible = false
		stamina_bars.append(stamina_bar)
		var meter := ProgressBar.new()
		meter.position = Vector2(x if i == 0 else x + 372 - 170, 103)
		meter.size = Vector2(170, 5)
		meter.max_value = fighter.SUPERS.METER_MAX
		meter.show_percentage = false
		meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meter.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 0 else ProgressBar.FILL_END_TO_BEGIN
		meter.add_theme_stylebox_override("background", UI.box(Color(0.02, 0.02, 0.05, 0.85), UI.LINE, 0))
		meter.add_theme_stylebox_override("fill", UI.box(UI.GOLD, UI.GOLD, 0))
		layer.add_child(meter)
		meter.set_deferred("size", Vector2(170, 5))
		super_bars.append(meter)
		var tag := UI.label(layer, "", Vector2(x + 176 if i == 0 else x + 372 - 170 - 186, 97), Vector2(180, 16), 10, UI.GOLD)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		tag.add_theme_font_override("font", UI.strong_font())
		tag.add_theme_constant_override("outline_size", 4)
		tag.add_theme_color_override("font_outline_color", UI.INK)
		super_tags.append(tag)
		UI.label(layer, "", Vector2(x + 90, 66), Vector2(145, 13), 8, UI.MUTED)
		fighter.health_changed.connect(_health_changed.bind(i))
		arena.combo_labels[i].position.y = 110
		arena.combo_labels[i].add_theme_font_size_override("font_size", 17)
		arena.combo_labels[i].add_theme_color_override("font_color", color)
		arena.combo_labels[i].add_theme_color_override("font_outline_color", UI.INK)
		arena.combo_labels[i].add_theme_constant_override("outline_size", 5)
	# Countdown in the shield plate: big italic numerals, red when low.
	arena.timer_label.position = Vector2(426, 6)
	arena.timer_label.size = Vector2(108, 56)
	arena.timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena.timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arena.timer_label.add_theme_font_override("font", UI.display_font())
	arena.timer_label.add_theme_font_size_override("font_size", 46)
	arena.timer_label.add_theme_color_override("font_shadow_color", UI.CRIMSON)
	arena.timer_label.add_theme_constant_override("shadow_offset_x", 2)
	arena.timer_label.add_theme_constant_override("shadow_offset_y", 3)
	arena.timer_label.add_theme_color_override("font_outline_color", UI.INK)
	arena.timer_label.add_theme_constant_override("outline_size", 5)
	arena.timer_label.pivot_offset = arena.timer_label.size * 0.5
	arena.round_label.position = Vector2(430, 58)
	arena.round_label.size = Vector2(100, 16)
	arena.round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena.round_label.add_theme_font_override("font", UI.strong_font())
	arena.round_label.add_theme_font_size_override("font_size", 11)
	arena.round_label.add_theme_color_override("font_color", UI.GOLD)
	# No backing box: a big italic round call and one comment line float over
	# the fight, outlined so they read against any arena.
	arena.banner.color = Color(0, 0, 0, 0)
	arena.banner.z_index = 5
	arena.banner_name.visible = false
	arena.banner_round.position = Vector2(0, 0)
	arena.banner_round.size = Vector2(700, 104)
	arena.banner_round.add_theme_font_override("font", UI.display_font())
	arena.banner_round.add_theme_font_size_override("font_size", 92)
	arena.banner_round.add_theme_color_override("font_color", UI.GOLD)
	arena.banner_round.add_theme_color_override("font_shadow_color", UI.CRIMSON)
	arena.banner_round.add_theme_constant_override("shadow_offset_x", 5)
	arena.banner_round.add_theme_constant_override("shadow_offset_y", 5)
	arena.banner_round.add_theme_color_override("font_outline_color", UI.INK)
	arena.banner_round.add_theme_constant_override("outline_size", 8)
	arena.banner_tagline.position = Vector2(0, 106)
	arena.banner_tagline.size = Vector2(700, 30)
	arena.banner_tagline.add_theme_font_override("font", UI.strong_font())
	arena.banner_tagline.add_theme_font_size_override("font_size", 20)
	arena.banner_tagline.add_theme_color_override("font_color", UI.WHITE)
	arena.banner_tagline.add_theme_color_override("font_outline_color", UI.INK)
	arena.banner_tagline.add_theme_constant_override("outline_size", 6)
	for child in layer.get_children():
		if child is Button and child.name == "MovesButton":
			child.theme = UI.theme()
			child.position = Vector2(815, 462)
			child.add_theme_font_size_override("font_size", 12)
	# The move list becomes a full-screen movebook (movebook.gd); the old text
	# column stays hidden underneath as the data the tests read.
	arena.move_guide.theme = UI.theme()
	arena.move_guide.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	arena.move_guide.position = Vector2.ZERO
	arena.move_guide.size = Vector2(960, 540)
	arena.move_guide.z_index = 25
	arena.move_guide.get_child(0).hide()
	movebook = preload("res://scripts/movebook.gd").new()
	movebook.arena = arena
	arena.move_guide.add_child(movebook)
	arena.move_guide.visibility_changed.connect(func():
		if arena.move_guide.visible:
			movebook.refresh())

	# Results card: dark glass under a crimson slash, the verdict in big
	# type, then both fighters' match statistics side by side.
	result_panel = UI.panel(layer, Vector2(130, 118), Vector2(700, 316), Color(0.02, 0.022, 0.05, 0.96), UI.GOLD)
	result_panel.z_index = 10
	var slash := Polygon2D.new()
	slash.polygon = PackedVector2Array([Vector2(0, 0), Vector2(700, 0), Vector2(700, 8), Vector2(0, 30)])
	slash.color = Color(UI.CRIMSON, 0.95)
	result_panel.add_child(slash)
	UI.eyebrow(result_panel, "MATCH RESULT", Vector2(24, 40), Vector2(400, 16))
	result_detail = UI.label(result_panel, "", Vector2(24, 108), Vector2(652, 22), 13, UI.MUTED)
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail.add_theme_font_override("font", UI.strong_font())
	var columns := ["ROUNDS", "DAMAGE", "COMBO", "KOs", "PERFECT"]
	for side in 2:
		var color := UI.GOLD if side == 0 else UI.VIOLET
		var name_label := UI.heading(result_panel, "", Vector2(24 if side == 0 else 356, 146), Vector2(320, 26), 18, color, Color(0, 0, 0, 0.7))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		name_label.name = "StatsName%d" % side
		for i in columns.size():
			var x := (24 if side == 0 else 356) + i * 66
			UI.panel(result_panel, Vector2(x, 176), Vector2(60, 50), Color(color, 0.08), Color(color, 0.45), 0.06)
			var caption := UI.label(result_panel, columns[i], Vector2(x + 4, 180), Vector2(56, 12), 8, UI.MUTED)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.add_theme_font_override("font", UI.strong_font())
			caption.tooltip_text = ["Rounds won", "Damage dealt", "Best hit combo", "Knockouts", "Perfect rounds"][i]
			caption.mouse_filter = Control.MOUSE_FILTER_PASS
			var value := UI.heading(result_panel, "0", Vector2(x, 194), Vector2(60, 28), 20, UI.WHITE, Color(0, 0, 0, 0.6))
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stat_values[side].append(value)
	next_button = UI.button(result_panel, "NEXT ROUND / R", Vector2(24, 250), Vector2(380, 44), true)
	next_button.theme = UI.theme()
	next_button.focus_mode = Control.FOCUS_ALL
	next_button.add_theme_font_override("font", UI.display_font())
	next_button.add_theme_font_size_override("font_size", 20)
	next_button.pressed.connect(_continue_match)
	var menu := UI.button(result_panel, "MAIN MENU", Vector2(416, 250), Vector2(260, 44))
	menu.theme = UI.theme()
	menu.focus_mode = Control.FOCUS_ALL
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	arena.result_label.position = Vector2(154, 172)
	arena.result_label.size = Vector2(652, 56)
	arena.result_label.add_theme_font_size_override("font_size", 33)
	arena.result_label.add_theme_color_override("font_color", UI.WHITE)
	arena.result_label.z_index = 11
	result_panel.hide()
	# "K.O." slams in ahead of the winner callout on a knockout.
	ko_label = UI.heading(layer, "K.O.", Vector2(180, 150), Vector2(600, 150), 132, Color("ff3b30"), UI.INK)
	ko_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ko_label.add_theme_color_override("font_outline_color", UI.GOLD)
	ko_label.add_theme_constant_override("outline_size", 14)
	ko_label.add_theme_constant_override("shadow_offset_x", 8)
	ko_label.add_theme_constant_override("shadow_offset_y", 9)
	ko_label.z_index = 12
	ko_label.hide()
	for i in 2:
		var fighter: Node = arena.player1 if i == 0 else arena.player2
		fighter.ko.connect(_knockout.bind(i))
		fighter.health_changed.connect(_track_damage.bind(i))
		fighter.impact.connect(_note_impact.bind(i))
		last_health[i] = fighter.health
	_reset_stats()
	if str(arena.get_script().resource_path).ends_with("practice_3d.gd"):
		readout = UI.label(layer, "", Vector2(36, 470), Vector2(640, 20), 12, UI.GOLD)
		readout.add_theme_font_override("font", UI.strong_font())
		readout.add_theme_constant_override("outline_size", 4)
		readout.add_theme_color_override("font_outline_color", UI.INK)
	# Slanted plates behind the fighter names, in each player's colour.
	for i in 2:
		var plate := Polygon2D.new()
		var x := 28.0 if i == 0 else 932.0
		var dir := 1.0 if i == 0 else -1.0
		plate.polygon = PackedVector2Array([Vector2(x, 54), Vector2(x + dir * 300, 54), Vector2(x + dir * 288, 86), Vector2(x - dir * 6, 86)])
		plate.color = Color(UI.GOLD if i == 0 else Color("2f6fd1"), 0.22)
		plate.z_index = -1
		layer.add_child(plate)
		name_plates.append(plate)
	layer.move_child(arena.move_guide, -1)
	perfect_label = UI.heading(layer, "PERFECT!", Vector2(230, 282), Vector2(500, 44), 34, UI.WHITE, UI.CRIMSON)
	perfect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perfect_label.z_index = 11
	perfect_label.hide()
	input_display = preload("res://scripts/input_display.gd").new()
	input_display.hud = self
	layer.add_child(input_display)
	fx = preload("res://scripts/fight_fx.gd").new()
	fx.hud = self
	fx.arena = arena
	layer.add_child(fx)
	# A small title tag under each name plate.
	for i in 2:
		var tag := UI.label(layer, "", Vector2(36 if i == 0 else 524, 90), Vector2(400, 14), 10, UI.WHITE)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		tag.add_theme_font_override("font", UI.strong_font())
		tag.add_theme_constant_override("outline_size", 5)
		tag.add_theme_color_override("font_outline_color", UI.INK)
		title_tags.append(tag)
	var hint: Label = layer.get_node("ControlsHint")
	# Two lines at the 11 px floor need 30 px; sits clear of the screen edge.
	hint.position = Vector2(12, 502)
	hint.size = Vector2(936, 36)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_constant_override("line_spacing", -6)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_font_override("font", UI.strong_font())
	hint.add_theme_color_override("font_color", Color(UI.WHITE, 0.7))

func _health_changed(health: int, maximum: int, player: int) -> void:
	health_labels[player].text = "%d / %d" % [health, maximum]
	var bar: ProgressBar = arena.health_bar1 if player == 0 else arena.health_bar2
	var color := UI.RED if health <= maximum * 0.25 else (UI.LIME if player == 0 else UI.VIOLET)
	bar.add_theme_stylebox_override("fill", UI.box(color, color, 0))
	if damage_tweens[player] != null:
		damage_tweens[player].kill()
	if health >= damage_bars[player].value:
		damage_bars[player].value = health
	else:
		damage_tweens[player] = create_tween()
		damage_tweens[player].tween_interval(0.25)
		damage_tweens[player].tween_property(damage_bars[player], "value", float(health), 0.35)

## Round-winner callout (big, centred, no panel) or the match result line
## that sits inside the end-of-match panel.
func _style_result(callout: bool) -> void:
	callout_style = callout
	var label: Label = arena.result_label
	if callout:
		label.position = Vector2(80, 190)
		label.size = Vector2(800, 100)
		label.add_theme_font_override("font", UI.display_font())
		label.add_theme_font_size_override("font_size", 78)
		label.add_theme_color_override("font_color", UI.GOLD)
		label.add_theme_color_override("font_shadow_color", UI.CRIMSON)
		label.add_theme_constant_override("shadow_offset_x", 5)
		label.add_theme_constant_override("shadow_offset_y", 5)
		label.add_theme_color_override("font_outline_color", UI.INK)
		label.add_theme_constant_override("outline_size", 8)
		label.pivot_offset = label.size * 0.5
		label.scale = Vector2.ONE * 1.5
		label.create_tween().tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		label.position = Vector2(154, 166)
		label.size = Vector2(652, 56)
		label.scale = Vector2.ONE
		label.remove_theme_font_override("font")
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_color_override("font_color", UI.WHITE)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_constant_override("outline_size", 0)

## Match opener: both names slam in from either side under a big VS while
## the intro camera cranes down, then the whole card wipes away before the
## round call. Only on round one, never in practice.
func _show_clash() -> void:
	var layer: CanvasLayer = arena.get_node("UI")
	clash = Control.new()
	clash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clash.z_index = 12
	layer.add_child(clash)
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(0, 178), Vector2(960, 150), Vector2(960, 330), Vector2(0, 358)])
	band.color = Color(0.02, 0.02, 0.05, 0.82)
	clash.add_child(band)
	var slash := Polygon2D.new()
	slash.polygon = PackedVector2Array([Vector2(492, 150), Vector2(526, 150), Vector2(434, 358), Vector2(400, 358)])
	slash.color = Color(UI.CRIMSON, 0.95)
	clash.add_child(slash)
	# Each half of the band glows in its fighter's colour, with speed
	# streaks racing across toward the clash.
	for i in 2:
		var tint := Polygon2D.new()
		tint.polygon = PackedVector2Array([Vector2(0, 178), Vector2(492, 150), Vector2(400, 358), Vector2(0, 358)]) if i == 0 			else PackedVector2Array([Vector2(526, 150), Vector2(960, 150), Vector2(960, 330), Vector2(434, 358)])
		tint.color = Color(UI.CRIMSON if i == 0 else Color("2f6fd1"), 0.26)
		clash.add_child(tint)
		clash.move_child(tint, 1)
	for k in 9:
		var streak := Polygon2D.new()
		var y := 158.0 + 22.0 * k
		var length := 140.0 + 60.0 * float(k % 3)
		streak.polygon = PackedVector2Array([Vector2(0, y), Vector2(length, y - 6), Vector2(length - 14, y), Vector2(0, y + 3)])
		streak.color = Color(1, 1, 1, 0.16)
		var from_left := k % 2 == 0
		streak.position = Vector2(-length if from_left else 960.0 + length, 0)
		streak.scale.x = 1.0 if from_left else -1.0
		clash.add_child(streak)
		streak.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(streak, "position:x", (440.0 - length * 0.5) if from_left else 520.0 + length * 0.5, 0.55).set_delay(0.04 * k)
	var names := [arena.player1.character_profile.name, arena.player2.character_profile.name]
	var labels: Array[Label] = []
	for i in 2:
		var color := UI.RED if i == 0 else UI.VIOLET
		var label := UI.heading(clash, names[i], Vector2(20 if i == 0 else 580, 204), Vector2(360, 84), 60, UI.WHITE, color.darkened(0.15))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 0 else HORIZONTAL_ALIGNMENT_LEFT
		label.add_theme_constant_override("shadow_offset_x", 5)
		label.add_theme_constant_override("shadow_offset_y", 5)
		var eyebrow := UI.eyebrow(clash, "PLAYER %d" % (i + 1) if not (MatchSetup.vs_ai and i == 1) else "COMPUTER", Vector2(20 if i == 0 else 580, 290), Vector2(360, 16), color)
		eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 0 else HORIZONTAL_ALIGNMENT_LEFT
		var fighter_title: String = str((arena.player1 if i == 0 else arena.player2).character_profile.get("title", ""))
		var subtitle := UI.heading(clash, str(fighter_title).to_upper(), Vector2(20 if i == 0 else 580, 312), Vector2(360, 24), 16, UI.GOLD, UI.INK)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 0 else HORIZONTAL_ALIGNMENT_LEFT
		subtitle.modulate.a = 0.0
		subtitle.create_tween().tween_property(subtitle, "modulate:a", 1.0, 0.25).set_delay(0.5)
		var home := label.position
		label.position.x += -520.0 if i == 0 else 520.0
		label.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(label, "position", home, 0.45).set_delay(0.1 + 0.08 * i)
		labels.append(label)
	var vs := UI.heading(clash, "VS", Vector2(400, 190), Vector2(160, 110), 92, UI.GOLD, UI.CRIMSON)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.pivot_offset = vs.size * 0.5
	vs.scale = Vector2.ONE * 2.6
	vs.modulate.a = 0.0
	var pop := vs.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(vs, "scale", Vector2.ONE, 0.4).set_delay(0.35)
	pop.tween_property(vs, "modulate:a", 1.0, 0.2).set_delay(0.35)
	var leave := clash.create_tween()
	leave.tween_interval(CLASH_HOLD)
	leave.tween_property(clash, "modulate:a", 0.0, 0.22)
	leave.tween_callback(clash.queue_free)
	clash_time = 0.0

func _continue_match() -> void:
	if arena.round_active or arena.move_guide.visible:
		return
	if arena.match_over:
		arena._start_new_match()
	else:
		arena._begin_round(arena.round_index + 1)

func _reset_stats() -> void:
	for i in 2:
		stats[i] = {"damage": 0, "combo": 0, "kos": 0, "perfects": 0}

## A damage number pops off the struck fighter and drifts up: gold for a
## clean hit, white and smaller for chip damage through the guard.
func _damage_number(player: int, amount: int, blocked: bool) -> void:
	if not ("camera_3d" in arena) or arena.camera_3d == null or not arena.is_inside_tree():
		return
	var fighter: Node = arena.player1 if player == 0 else arena.player2
	var screen: Vector2 = arena.camera_3d.unproject_position(fighter.body.position + Vector3.UP * 1.75)
	var at: Vector2 = get_viewport().get_final_transform().affine_inverse() * screen
	var number := UI.heading(arena.get_node("UI"), str(amount), at + Vector2(-60, -30), Vector2(120, 40), 16 if blocked else 26, Color(0.9, 0.93, 1.0) if blocked else UI.GOLD, UI.CRIMSON)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.z_index = 9
	number.pivot_offset = number.size * 0.5
	number.scale = Vector2.ONE * 1.5
	var rise := number.create_tween().set_parallel(true)
	rise.tween_property(number, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(number, "position:y", at.y - 78, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(number, "modulate:a", 0.0, 0.3).set_delay(0.45)
	rise.chain().tween_callback(number.queue_free)

func _track_damage(health: int, _maximum: int, player: int) -> void:
	if health < last_health[player]:
		stats[1 - player].damage += last_health[player] - health
		_damage_number(player, last_health[player] - health, readout_blocked_for(player))
		if readout != null and readout_pending == player:
			var attacker: Node = arena.player2 if player == 0 else arena.player1
			var verdict := "BLOCKED" if readout_blocked else ("COUNTER HIT" if attacker.combat_notice == "COUNTER HIT" and attacker.combat_time < attacker.notice_until else "HIT")
			var dealt: int = last_health[player] - health
			readout.text = "LAST STRIKE   %s   /   %d DMG   /   %s" % [readout_move.to_upper().replace("_", " "), dealt, verdict]
			var defender: Node = arena.player1 if player == 0 else arena.player2
			# Frame advantage: who acts first once this blow is over, in
			# 60ths of a second (+ the attacker, - the defender).
			if attacker.state in [attacker.State.PUNCH, attacker.State.KICK] and defender.state in [defender.State.HITSTUN, defender.State.BLOCKSTUN]:
				var advantage := roundi((defender.stun_timer - maxf(0.0, attacker.attack_duration() - attacker.attack_timer)) * 60.0)
				readout.text += "   %+d" % advantage
			# Combo so far: hits in this string and their total damage.
			var hits: int = defender.get("_received_hits") if defender.get("_received_hits") != null else 1
			readout_combo[player] = dealt if hits <= 1 or readout_blocked else readout_combo[player] + dealt
			if hits >= 2 and not readout_blocked:
				readout.text += "   /   COMBO %d HITS  %d DMG" % [hits, readout_combo[player]]
			readout.modulate.a = 1.0
			readout.create_tween().tween_property(readout, "modulate:a", 0.0, 0.6).set_delay(2.4)
			readout_pending = -1
	last_health[player] = health

## The defender emits the impact before its health changes; remember which
## move landed and whether it was guarded, for the readout and the number.
var last_blocked: Array = [false, false]

func _note_impact(_point: Vector2, blocked: bool, _heavy: bool, defender: int) -> void:
	last_blocked[defender] = blocked
	if readout == null:
		return
	var attacker: Node = arena.player2 if defender == 0 else arena.player1
	readout_pending = defender
	readout_move = str(attacker.attack_variant)
	readout_blocked = blocked

func readout_blocked_for(defender: int) -> bool:
	return last_blocked[defender]

## Where the K.O. callout slams in (above the fighters' heads) and where it
## settles, tucked under the clock.
const KO_HIGH := 78.0
const KO_RESTING := 26.0

func _knockout(loser: int) -> void:
	stats[1 - loser].kos += 1
	_slam("K.O.", 132)
	if fx != null:
		fx.knockout()

## First full meter ever: a banner under the HUD says what it is and how to
## use it, then is never shown again.
func _show_super_tip(fighter: Node) -> void:
	Settings.set_option("super_tip_seen", true)
	var layer: Node = arena.get_node("UI")
	super_tip = Control.new()
	super_tip.position = Vector2(255, 132)
	super_tip.z_index = 8
	super_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(super_tip)
	UI.panel(super_tip, Vector2.ZERO, Vector2(450, 58), Color(0.04, 0.04, 0.08, 0.92), UI.GOLD, 0.05)
	UI.heading(super_tip, "SUPER READY", Vector2(18, 6), Vector2(220, 30), 22, UI.GOLD, UI.CRIMSON)
	UI.key_hint(super_tip, "LT + R3" if Settings.using_pad else "2 + 4", "", Vector2(176, 11))
	UI.label(super_tip, "Press together up close. Land the first hit and the combo plays out.", Vector2(18, 34), Vector2(420, 16), 11, UI.WHITE)
	super_tip.modulate.a = 0.0
	var show := super_tip.create_tween()
	show.tween_property(super_tip, "modulate:a", 1.0, 0.25)
	show.tween_interval(4.5)
	show.tween_property(super_tip, "modulate:a", 0.0, 0.4)
	show.tween_callback(super_tip.queue_free)

## The big callout (K.O., TIME UP) slams in and holds the winner line back
## for a beat.
func _slam(text: String, size: int) -> void:
	ko_label.text = text
	ko_label.add_theme_font_size_override("font_size", size)
	ko_label.show()
	# Above the fighters, not over them: the knockout fall is the moment, so
	# the callout slams in high, then rises and shrinks under the clock.
	ko_label.position.y = KO_HIGH
	ko_label.pivot_offset = ko_label.size * 0.5
	ko_label.scale = Vector2.ONE * 2.2
	ko_label.modulate.a = 0.0
	var slam := ko_label.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_property(ko_label, "scale", Vector2.ONE * 0.8, 0.22)
	slam.tween_property(ko_label, "modulate:a", 1.0, 0.1)
	var leave := ko_label.create_tween()
	leave.tween_interval(0.45)
	leave.tween_property(ko_label, "scale", Vector2.ONE * 0.42, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	leave.parallel().tween_property(ko_label, "position:y", KO_RESTING, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	leave.tween_interval(0.6)
	leave.tween_property(ko_label, "modulate:a", 0.0, 0.25)
	leave.tween_callback(ko_label.hide)
	# The winner callout waits its turn behind the K.O.
	arena.result_label.modulate.a = 0.0
	arena.result_label.create_tween().tween_property(arena.result_label, "modulate:a", 1.0, 0.25).set_delay(0.95)

func _can_call() -> bool:
	return arena.round_active and arena.intro_timer <= 0.0 and not arena.is_paused() and not arena.is_replaying() and not arena.move_guide.visible

func _call_enemy(player: int) -> void:
	if not _can_call():
		return
	var bank := get_node("/root/BattleCry")
	if not bank.has_cry(player, "call_enemy"):
		Settings.notify("RECORD A CALL ENEMY LINE IN VOICE STUDIO FIRST")
		return
	bank.call_enemy(player)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_T:
			_call_enemy(0)
		elif event.physical_keycode == KEY_U and not MatchSetup.vs_ai and not MatchSetup.practice:
			_call_enemy(1)

func _process(_delta: float) -> void:
	var bank := get_node("/root/BattleCry")
	for player in call_buttons.size():
		var wait: float = bank.call_time_left(player)
		call_buttons[player].disabled = not _can_call() or not bank.can_call_enemy(player)
		call_buttons[player].text = "P%d CALL ENEMY [%s]" % [player + 1, "T" if player == 0 else "U"] if wait <= 0.0 else "P%d CALL / %.1f s" % [player + 1, wait]
		call_buttons[player].tooltip_text = "Play your recorded challenge" if bank.has_cry(player, "call_enemy") else "Record a Call Enemy line in Voice Studio on character select"
	# Name plates: the fighter's name alone, the title and player tag below.
	for i in 2:
		var fighter: Node = arena.player1 if i == 0 else arena.player2
		var label: Label = arena.get_node("UI/P1Label" if i == 0 else "UI/P2Label")
		label.text = str(fighter.character_profile.name)
		if i < title_tags.size():
			var who := "P%d" % (i + 1) if not (MatchSetup.vs_ai and i == 1) else "CPU"
			var title := str(fighter.character_profile.get("title", "")).to_upper()
			title_tags[i].text = ("%s   /   %s" % [who, title]) if i == 0 else ("%s   /   %s" % [title, who])
	# The opener plays over round one's intro; a rematch gets a fresh one.
	if arena.round_index != 0:
		clash_played = false
	elif arena.intro_timer > 0.0 and not clash_played:
		clash_played = true
		_reset_stats()
		_show_clash()
	for i in 2:
		var fighter: Node = arena.player1 if i == 0 else arena.player2
		stats[1 - i].combo = maxi(stats[1 - i].combo, int(fighter._received_hits))
	# The round call waits behind the clash, then fades up as it clears.
	if is_instance_valid(clash):
		var before: float = clash_time
		clash_time += _delta
		if clash_time < CLASH_HOLD:
			arena.banner.modulate.a = 0.0
		elif before < CLASH_HOLD:
			arena.banner.create_tween().tween_property(arena.banner, "modulate:a", 1.0, 0.25)
	for i in 2:
		var fighter: Node = arena.player1 if i == 0 else arena.player2
		stamina_bars[i].max_value = fighter.character_profile.stamina
		stamina_bars[i].value = fighter.stamina
		stamina_bars[i].modulate = UI.RED if fighter.stamina < 18.0 else Color.WHITE
		var has_super: bool = fighter.has_super()
		super_bars[i].visible = has_super
		super_bars[i].value = fighter.super_meter
		var full: bool = has_super and fighter.super_meter >= fighter.SUPERS.METER_MAX
		var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.009)
		super_bars[i].modulate = Color(1.25, 1.15, 0.9) * pulse if full else Color.WHITE
		super_tags[i].text = ("SUPER READY  " + ("LT+R3" if Settings.using_pad else "2+4")) if full else ""
		var moves := arena.get_node_or_null("UI/MovesButton")
		if moves != null:
			moves.text = "MOVES [BACK]" if Settings.using_pad else "MOVES [F1]"
		super_tags[i].modulate.a = pulse
		if full and not Settings.super_tip_seen and not is_instance_valid(super_tip) and not (MatchSetup.vs_ai and i == 1):
			_show_super_tip(fighter)
	var show_result: bool = arena.result_label.visible
	# Between rounds only the winner callout shows; the panel with Rematch /
	# Next Rival / Main Menu is kept for the end of the match.
	var callout: bool = show_result and (not arena.match_over or arena.advancing)
	if callout != callout_style:
		_style_result(callout)
	# A round won without a scratch earns a PERFECT under the callout.
	if show_result and not last_result_visible and arena.time_remaining <= 0.0 and arena.player1.state != arena.player1.State.KO and arena.player2.state != arena.player2.State.KO:
		_slam("TIME UP", 96)
	if show_result and not last_result_visible:
		# Between rounds the PERFECT rides under the callout; at the end of
		# the match it is counted on the results card instead.
		perfect_label.visible = arena.perfect_round and not arena.match_over
		if arena.perfect_round:
			stats[0 if arena.player1.health > arena.player2.health else 1].perfects += 1
			perfect_label.position.y = callout_style if false else (282.0 if callout else 150.0)
			perfect_label.modulate.a = 0.0
			perfect_label.pivot_offset = perfect_label.size * 0.5
			perfect_label.scale = Vector2.ONE * 1.6
			var flourish := perfect_label.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			# With the winner line, once the knockout fall has played out.
			flourish.tween_property(perfect_label, "scale", Vector2.ONE, 0.35).set_delay(1.05)
			flourish.tween_property(perfect_label, "modulate:a", 1.0, 0.2).set_delay(1.05)
	elif not show_result:
		perfect_label.hide()
	last_result_visible = show_result
	show_result = show_result and arena.match_over and not arena.advancing
	if show_result and not result_panel.visible:
		UI.enter(result_panel)
		result_panel.show()
		next_button.grab_focus()
	result_panel.visible = show_result
	if show_result:
		next_button.text = "REMATCH / " + ("A" if Settings.using_pad else "R")
		result_detail.text = "%s  /  SCORE %d : %d" % ["MATCH COMPLETE" if arena.match_over else "ROUND %d COMPLETE" % (arena.round_index + 1), arena.round_wins[0], arena.round_wins[1]]
		for side in 2:
			var fighter: Node = arena.player1 if side == 0 else arena.player2
			result_panel.get_node("StatsName%d" % side).text = fighter.character_profile.name + (" / CPU" if MatchSetup.vs_ai and side == 1 else "")
			var values := [arena.round_wins[side], stats[side].damage, stats[side].combo, stats[side].kos, stats[side].perfects]
			for i in values.size():
				stat_values[side][i].text = str(values[i])
		if arena.match_over and MatchSetup.arcade:
			var won: bool = arena.round_wins[0] > arena.round_wins[1]
			next_button.text = ("NEW RUN / R" if MatchSetup.is_final_boss() else "NEXT RIVAL / R") if won else "RETRY RIVAL / R"
			if won and MatchSetup.is_final_boss():
				result_detail.text = "ANANTA DEFEATED / ARCADE COMPLETE"
	var low: bool = arena.time_remaining <= 10 and arena.round_active
	arena.timer_label.add_theme_color_override("font_color", Color("ff5a4a") if low else UI.WHITE)
	# The last ten seconds throb once per second.
	var beat := fposmod(arena.time_remaining, 1.0)
	arena.timer_label.scale = Vector2.ONE * (1.0 + (0.18 * beat * beat if low else 0.0))
	_update_intro_hud(_delta)

func _update_intro_hud(delta: float) -> void:
	var ceremony: bool = is_instance_valid(arena.announcer) and arena.intro_timer > 0.65
	intro_hud_alpha = move_toward(intro_hud_alpha, 0.0 if ceremony else 1.0, delta * 6.0)
	var chrome: Array = [gauges, arena.get_node("UI/P1Label"), arena.get_node("UI/P2Label"), arena.timer_label, arena.round_label]
	chrome.append_array(name_plates)
	chrome.append_array(title_tags)
	chrome.append_array(stamina_bars)
	chrome.append_array(super_bars)
	chrome.append_array(super_tags)
	for item in chrome:
		item.modulate.a = intro_hud_alpha
	for path in ["UI/ControlsHint", "UI/MovesButton"]:
		var item := arena.get_node_or_null(path)
		if item != null:
			item.visible = not ceremony
	for player in call_buttons.size():
		call_buttons[player].visible = not ceremony and (player == 0 or (not MatchSetup.vs_ai and not MatchSetup.practice))
	if is_instance_valid(input_display):
		input_display.visible = not ceremony and Settings.input_display
