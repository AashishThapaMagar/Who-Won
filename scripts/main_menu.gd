extends Control
## Title screen: the living square. The real 3D arena is the menu's
## backdrop, with two fighters squaring off on the flagstones, and every
## entry moves the camera to its own place in the square (see
## menu_backdrop.gd SHOTS). Over it, only type: the logo, a list whose chosen
## entry grows large beside a flickering diya, one line explaining it, the
## arena's name and the player's record.
const UI := preload("res://scripts/ui_kit.gd")
const BACKDROP := preload("res://scripts/menu_backdrop.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
## The four fight modes; they lead to fighter select.
const MODE_KEYS := ["arcade", "story", "local", "ai"]
## The list, [key, title, description]; a gap follows the fight entries.
const ENTRIES := [
	["arcade", "ARCADE", "Fight the whole roster, one rival after another, then face the final boss."],
	["story", "STORY", "Follow the road through every rival to the final showdown with Ananta."],
	["local", "VS BATTLE", "Two players, one keyboard. Pick your fighters and your arena and settle the score."],
	["ai", "VS COMPUTER", "Pick your rival and the difficulty. The best place to master your combos."],
	["practice", "PRACTICE", "Train against a dummy that guards, grabs and fights back."],
	["fighters", "FIGHTERS", "Meet the seven fighters of the square: their styles, strengths and supers."],
	["records", "RECORDS", "Your fights, wins, streaks, perfects and favourite fighter."],
	["settings", "SETTINGS", "Display, sound, graphics, fight rules, controls and how to play."],
	["exit", "EXIT", "Leave the square. Your records are saved."],
]
const FIGHT_ENTRIES := 5
## Each entry's name in Nepali, beside the chosen entry.
const NEPALI := {"arcade": "आर्केड", "story": "कथा", "local": "भिडन्त", "ai": "कम्प्युटरसँग", "practice": "अभ्यास",
	"fighters": "योद्धाहरू", "records": "रेकर्ड", "settings": "सेटिङ", "exit": "बाहिर"}
const LIST_X := 40.0
const LIST_TOP := 158.0
const ROW_SMALL := 26.0
const ROW_LARGE := 44.0
const GROUP_GAP := 12.0
const ROW_WIDTH := 360.0
## The logo's finish: brushed gold to white-hot to deep gold by screen
## height, with a slow glint crossing it.
const LOGO_METAL := """shader_type canvas_item;
uniform float top = 0.06;
uniform float bottom = 0.17;
void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	float y = clamp((SCREEN_UV.y - top) / (bottom - top), 0.0, 1.0);
	vec3 metal = mix(vec3(1.0, 0.86, 0.48), vec3(1.0, 0.99, 0.94), smoothstep(0.1, 0.45, y));
	metal = mix(metal, vec3(0.92, 0.62, 0.2), smoothstep(0.55, 1.0, y));
	float sweep = fract(TIME * 0.12) * 3.2 - 1.1;
	float glint = 1.0 - smoothstep(0.0, 0.035, abs(SCREEN_UV.x * 0.8 + SCREEN_UV.y * 0.6 - sweep));
	float fill = step(0.98, min(COLOR.r, min(COLOR.g, COLOR.b)));
	COLOR = vec4(mix(COLOR.rgb, metal + glint * 0.5, fill), glyph.a * COLOR.a);
}
"""
## Just enough shade for the type: a soft fall-off from the left edge and
## the foot, the scene itself left open.
const BACKDROP_GRADE := """shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	float left = 1.0 - smoothstep(0.0, 0.5, uv.x);
	float foot = smoothstep(0.74, 1.0, uv.y);
	vec2 c = (uv - vec2(0.6, 0.45)) * vec2(1.2, 1.0);
	float vignette = smoothstep(0.45, 1.0, length(c));
	float a = clamp(left * 0.8 + foot * 0.5 + vignette * 0.35, 0.0, 0.92);
	COLOR = vec4(0.012, 0.014, 0.03, a);
}
"""

var backdrop: Control
## Row dictionaries {button, key, title, desc, heading, nepali}.
var rows: Array[Dictionary] = []
var cursor := 2
## Fight mode rows by key, for clicks and tests.
var home_modes: Dictionary = {}
## Highlighted non-mode entry, or "" when a fight mode is highlighted.
var cursor_key := ""
var diya: TextureRect
var mode_desc_label: Label
var arena_label: Label
var record_strip: Label
var play_button: Button
var modal: Control
var modal_content: Control
var return_focus: Control
var transitioning: bool = false
## Buttons navigated by keys that never take focus.
var nav_buttons: Array[Button] = []
var _flicker := 0.0

func _ready() -> void:
	theme = UI.theme()
	backdrop = BACKDROP.new()
	add_child(backdrop)
	backdrop.shade_width = 0.0
	if DisplayServer.get_name() != "headless":
		backdrop.add_fighters(MatchSetup.selected_fighters[0], MatchSetup.selected_fighters[1])
	var grade := ColorRect.new()
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade.material = _shader_material(BACKDROP_GRADE)
	add_child(grade)
	_build_logo()
	_build_list()
	_build_corner()
	_build_footer()
	_choose_home_mode(_selected_mode())
	_layout(false)
	play_button.grab_focus()
	_entrance()

## A material for a canvas shader. The code is set before the shader joins
## the material: one given its code afterwards drew solid white.
static func _shader_material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _build_logo() -> void:
	var title := UI.label(self, "WHO WON?", Vector2(LIST_X - 4, 24), Vector2(520, 76), 62, Color.WHITE)
	title.name = "GameTitle"
	title.add_theme_font_override("font", UI.saira(900, 112, true))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color("1a1206"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.material = _shader_material(LOGO_METAL)
	var nepali := UI.label(self, "को जित्यो?", Vector2(LIST_X, 94), Vector2(240, 32), 26, UI.GOLD)
	nepali.name = "NepaliTitle"
	nepali.add_theme_font_override("font", UI.teko(500))
	for node in [title, nepali]:
		node.modulate.a = 0.0
		node.position.y += 12
		var rise: Tween = node.create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		rise.tween_property(node, "position:y", node.position.y - 12, 0.9)
		rise.tween_property(node, "modulate:a", 1.0, 0.7)

func _build_list() -> void:
	# The diya: a small butter-lamp flame that marks the chosen entry.
	diya = TextureRect.new()
	var flame := GradientTexture2D.new()
	flame.fill = GradientTexture2D.FILL_RADIAL
	flame.fill_from = Vector2(0.5, 0.5)
	flame.fill_to = Vector2(1.0, 0.5)
	flame.gradient = Gradient.new()
	flame.gradient.set_color(0, Color(1.0, 0.97, 0.85, 1.0))
	flame.gradient.set_color(1, Color(1.0, 0.45, 0.05, 0.0))
	flame.gradient.add_point(0.3, Color(1.0, 0.72, 0.2, 0.95))
	diya.texture = flame
	diya.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	diya.size = Vector2(22, 22)
	diya.pivot_offset = Vector2(11, 11)
	diya.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(diya)
	for i in ENTRIES.size():
		var key: String = ENTRIES[i][0]
		var button := UI.button(self, "", Vector2(LIST_X, LIST_TOP), Vector2(ROW_WIDTH, ROW_SMALL))
		button.name = String(ENTRIES[i][1]).replace(" ", "").capitalize().replace(" ", "") + "Mode"
		button.focus_mode = Control.FOCUS_NONE
		var clear := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, clear)
		var heading := UI.label(button, ENTRIES[i][1], Vector2(26, 0), Vector2(ROW_WIDTH - 26, ROW_SMALL), 17, UI.WHITE)
		heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		heading.add_theme_font_override("font", UI.saira(600, 104, true))
		heading.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		heading.add_theme_constant_override("shadow_offset_y", 2)
		var nepali := UI.label(button, NEPALI.get(key, ""), Vector2(26, 4), Vector2(170, ROW_LARGE), 22, UI.GOLD)
		nepali.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nepali.add_theme_font_override("font", UI.teko(500))
		if key in MODE_KEYS:
			button.pressed.connect(_enter_door.bind(key))
			home_modes[key] = button
		else:
			button.pressed.connect(_activate_extra.bind(key))
		button.mouse_entered.connect(_select.bind(i))
		nav_buttons.append(button)
		rows.append({"button": button, "key": key, "title": ENTRIES[i][1], "desc": ENTRIES[i][2], "heading": heading, "nepali": nepali})
	var rule := ColorRect.new()
	rule.color = UI.GOLD
	rule.position = Vector2(LIST_X, 446)
	rule.size = Vector2(28, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	mode_desc_label = UI.label(self, "", Vector2(LIST_X, 454), Vector2(400, 40), 13, Color(UI.WHITE, 0.78))
	mode_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_desc_label.add_theme_font_override("font", UI.saira(400, 100))

## The player's record (top right) and the arena on screen (bottom right).
func _build_corner() -> void:
	var player := UI.label(self, "PLAYER ONE", Vector2(620, 26), Vector2(312, 16), 10, UI.GOLD)
	player.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player.add_theme_font_override("font", UI.saira(700, 112))
	record_strip = UI.label(self, "", Vector2(520, 42), Vector2(412, 20), 13, UI.WHITE)
	record_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	record_strip.add_theme_font_override("font", UI.saira(600, 100))
	record_strip.add_theme_constant_override("outline_size", 4)
	record_strip.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	_refresh_record_strip()
	arena_label = UI.label(self, "", Vector2(520, 474), Vector2(412, 18), 12, Color(UI.WHITE, 0.8))
	arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arena_label.add_theme_font_override("font", UI.saira(700, 112))
	arena_label.add_theme_constant_override("outline_size", 4)
	arena_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))

## Button prompts along the foot; Start is the focused button.
func _build_footer() -> void:
	play_button = UI.button(self, "START", Vector2(LIST_X, 509), Vector2(96, 20), true)
	play_button.name = "StartGame"
	play_button.custom_minimum_size = Vector2(96, 20)
	play_button.add_theme_font_override("font", UI.saira(700, 100))
	play_button.add_theme_font_size_override("font_size", 11)
	var chip := UI.box(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.5), 1)
	var lit := UI.box(Color(UI.GOLD, 0.3), UI.GOLD, 1)
	for box in [chip, lit]:
		box.content_margin_top = 1
		box.content_margin_bottom = 1
	play_button.add_theme_stylebox_override("normal", chip)
	play_button.add_theme_stylebox_override("focus", chip)
	play_button.add_theme_stylebox_override("hover", lit)
	play_button.add_theme_stylebox_override("pressed", lit)
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		play_button.add_theme_color_override(state, UI.WHITE)
	play_button.pressed.connect(_confirm)
	var x := LIST_X + 108.0
	for hint in [["ENTER", "CONFIRM"], ["↑↓", "SELECT"], ["F2", "QUICK PRACTICE"]]:
		x += UI.key_hint(self, hint[0], hint[1], Vector2(x, 513))

## The rows slide in one after another as the screen opens.
func _entrance() -> void:
	for i in rows.size():
		var button: Button = rows[i].button
		var home: Vector2 = button.position
		button.position = home - Vector2(40, 0)
		button.modulate.a = 0.0
		var tween := button.create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "position", home, 0.5).set_delay(0.25 + 0.05 * i)
		tween.tween_property(button, "modulate:a", 1.0, 0.3).set_delay(0.25 + 0.05 * i)

## Stack the rows: the chosen one large, the rest small, with a gap after
## the fight entries; the diya moves to the chosen one.
func _layout(animate := true) -> void:
	var y := LIST_TOP
	for i in rows.size():
		var row: Dictionary = rows[i]
		var active := i == cursor
		var height := ROW_LARGE if active else ROW_SMALL
		row.heading.add_theme_font_size_override("font_size", 30 if active else 17)
		row.heading.add_theme_font_override("font", UI.saira(900 if active else 600, 104, true))
		row.heading.add_theme_color_override("font_color", UI.WHITE if active else Color(1, 1, 1, 0.55))
		row.heading.size.y = height
		row.button.size.y = height
		row.nepali.visible = active
		row.nepali.position.x = 26 + row.heading.get_minimum_size().x + 14
		var target := Vector2(LIST_X + (6.0 if active else 0.0), y)
		if animate and row.button.is_inside_tree():
			row.button.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(row.button, "position", target, 0.25)
		else:
			row.button.position = target
		if active:
			var spot := Vector2(LIST_X - 2, y + height * 0.5 - 11)
			if animate and diya.is_inside_tree():
				diya.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(diya, "position", spot, 0.25)
			else:
				diya.position = spot
			mode_desc_label.text = row.desc
		y += height + (GROUP_GAP if i == FIGHT_ENTRIES - 1 else 0.0)

## The diya flickers like a real flame.
func _process(delta: float) -> void:
	_flicker += delta
	if diya != null:
		var wobble := 0.85 + 0.1 * sin(_flicker * 13.0) + 0.06 * sin(_flicker * 31.0 + 1.3)
		diya.scale = Vector2(wobble, wobble * 1.08)
		diya.modulate.a = 0.82 + 0.18 * sin(_flicker * 9.0)

## Highlight entry `index`: a fight mode becomes the chosen mode; anything
## else is pointed at without changing it.
func _select(index: int) -> void:
	if transitioning or is_instance_valid(modal):
		return
	var key: String = ENTRIES[index][0]
	if key in MODE_KEYS:
		_choose_home_mode(key)
	else:
		_point_at(key)

func _choose_home_mode(mode: String) -> void:
	if transitioning or is_instance_valid(modal):
		return
	MatchSetup.practice = false
	MatchSetup.story = mode == "story"
	MatchSetup.arcade = mode in ["story", "arcade"]
	MatchSetup.vs_ai = mode != "local"
	cursor_key = ""
	_set_cursor(mode)

## Highlight a non-mode entry without changing the chosen fight mode.
func _point_at(key: String) -> void:
	if transitioning or is_instance_valid(modal):
		return
	cursor_key = key
	_set_cursor(key)

func _set_cursor(key: String) -> void:
	var index := -1
	for i in ENTRIES.size():
		if ENTRIES[i][0] == key:
			index = i
	if index < 0:
		return
	var moved := index != cursor
	cursor = index
	_refresh_mode_summary()
	if moved:
		_layout()

func _refresh_mode_summary() -> void:
	var key: String = ENTRIES[cursor][0]
	if key in MODE_KEYS:
		backdrop.selected = maxi(0, BACKDROP.MODE_ORDER.find(key))
	backdrop.frame(key)
	var arena: Dictionary = backdrop.STAGE.ROUNDS[backdrop.MODE_ROUND[backdrop.selected]]
	arena_label.text = "%s   /   %s" % [arena.name, "KATHMANDU VALLEY"]
	play_button.text = "START" if cursor_key.is_empty() or cursor_key == "practice" else ("QUIT" if cursor_key == "exit" else "OPEN")

func _step_entries(step: int) -> void:
	_select(posmod(cursor + step, ENTRIES.size()))
	preload("res://scripts/sfx.gd").fire("menu_move")
	play_button.grab_focus()

func _enter_door(mode: String) -> void:
	if transitioning or is_instance_valid(modal):
		return
	_choose_home_mode(mode)
	_start_fight()

## F2 drops straight into practice with the last picks.
func _start_practice() -> void:
	if transitioning or is_instance_valid(modal):
		return
	transitioning = true
	get_tree().change_scene_to_file("res://scenes/Practice3D.tscn")

## The menu entry: pick a fighter and a dummy first.
func _choose_practice() -> void:
	if transitioning or is_instance_valid(modal):
		return
	MatchSetup.practice = true
	MatchSetup.story = false
	MatchSetup.arcade = false
	MatchSetup.vs_ai = false
	transitioning = true
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

## Start the highlighted mode, or open / run the highlighted other entry.
func _confirm() -> void:
	if cursor_key.is_empty():
		_start_fight()
	else:
		_activate_extra(cursor_key)

func _activate_extra(key: String) -> void:
	if transitioning or is_instance_valid(modal):
		return
	_point_at(key)
	match key:
		"practice":
			_choose_practice()
		"fighters":
			_show_roster()
		"records":
			_show_records()
		"settings":
			_show_settings()
		"exit":
			_confirm_exit()

## Leaving is one keypress away from the list, so it asks first.
func _confirm_exit() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("LEAVE THE CHAMPIONSHIP?", "EXIT")
	UI.label(modal_content, "Your records and settings are saved. See you next time.", Vector2(28, 110), Vector2(560, 40), 15, UI.WHITE)
	var leave := UI.button(modal_content, "QUIT GAME", Vector2(28, 170), Vector2(200, 44), true)
	leave.pressed.connect(func(): get_tree().quit())
	var stay := UI.button(modal_content, "STAY", Vector2(240, 170), Vector2(160, 44))
	stay.pressed.connect(_close_modal)
	stay.grab_focus()

## The player card's line: the running record.
func _refresh_record_strip() -> void:
	var records := get_node_or_null("/root/Records")
	if records == null or record_strip == null:
		return
	if records.totals.matches == 0:
		record_strip.text = "NO FIGHTS ON RECORD YET"
		return
	record_strip.text = "%dW  %dL   /   STREAK %d   /   %d%%" % [records.totals.wins, records.totals.losses, records.totals.streak, records.win_rate()]

func _hero_index() -> int:
	var records := get_node_or_null("/root/Records")
	if records != null and records.favourite() != "":
		return _roster_index(records.favourite())
	return clampi(MatchSetup.selected_fighters[0], 0, ROSTER.PROFILES.size() - 1)

static func _roster_index(id: String) -> int:
	for i in ROSTER.PROFILES.size():
		if ROSTER.PROFILES[i].id == id:
			return i
	return 0

## Records page: stat tiles, a per-mode line, the roster ledger and reset.
func _show_records() -> void:
	if transitioning or is_instance_valid(modal):
		return
	var records := get_node_or_null("/root/Records")
	_open_modal("YOUR RECORD", "RECORDS")
	if records == null:
		return
	var t: Dictionary = records.totals
	var tiles := [
		["MATCHES", str(t.matches)], ["WINS", str(t.wins)], ["WIN RATE", "%d%%" % records.win_rate()], ["BEST STREAK", str(t.best_streak)],
		["KNOCKOUTS", str(t.kos)], ["PERFECTS", str(t.perfects)], ["ARCADE RUNS", str(t.arcade_clears)], ["PLAY TIME", records.play_time()],
	]
	for i in tiles.size():
		var at := Vector2(28 + (i % 4) * 143, 98 + (i / 4) * 66)
		UI.panel(modal_content, at, Vector2(134, 58), Color(1, 1, 1, 0.05), Color(UI.GOLD, 0.35), 0.06)
		UI.eyebrow(modal_content, tiles[i][0], at + Vector2(12, 8), Vector2(120, 14))
		UI.heading(modal_content, tiles[i][1], at + Vector2(10, 22), Vector2(120, 32), 24, UI.WHITE, Color(0, 0, 0, 0.6))
	var by_mode := ""
	for key in ["arcade", "story", "local", "ai"]:
		var entry: Dictionary = records.modes.get(key, {"matches": 0, "wins": 0})
		by_mode += "%s %d/%d    " % [records.MODE_NAMES[key], entry.wins, entry.matches]
	UI.label(modal_content, "WINS / MATCHES BY MODE:   " + by_mode.strip_edges(), Vector2(28, 234), Vector2(566, 18), 11, UI.MUTED).add_theme_font_override("font", UI.strong_font())
	# The roster ledger: one column per fighter, favourite in gold.
	var favourite: String = records.favourite()
	for i in ROSTER.PROFILES.size():
		var profile := ROSTER.profile(i)
		var record: Dictionary = records.fighter_record(profile.id)
		var x := 28.0 + i * 81
		var mine: bool = profile.id == favourite and record.picks > 0
		var name := UI.heading(modal_content, profile.name, Vector2(x, 258), Vector2(78, 20), 13, UI.GOLD if mine else UI.WHITE, Color(0, 0, 0, 0.7))
		name.add_theme_constant_override("outline_size", 3)
		var line := UI.label(modal_content, "%dW / %d" % [record.wins, record.picks], Vector2(x, 278), Vector2(78, 16), 10, UI.MUTED)
		line.add_theme_font_override("font", UI.strong_font())
	if favourite != "":
		UI.eyebrow(modal_content, "FAVOURITE: " + ROSTER.profile(_roster_index(favourite)).name, Vector2(28, 300), Vector2(300, 16))
	var reset := UI.button(modal_content, "RESET RECORDS", Vector2(28, 311), Vector2(170, 38))
	reset.pressed.connect(func():
		records.reset()
		_refresh_record_strip()
		_close_modal()
		_show_records())

## The mode the current MatchSetup state maps to — shared by
## _refresh_mode_summary (styling every row after a change) and each row's
## own hover handler (restoring its real state once the pointer leaves).
func _selected_mode() -> String:
	return "story" if MatchSetup.story else ("arcade" if MatchSetup.arcade else ("ai" if MatchSetup.vs_ai else "local"))

func _show_fight_options() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("TUNE YOUR FIGHT", "FIGHT OPTIONS")
	_option_label("AI DIFFICULTY", 116)
	var difficulty := OptionButton.new()
	for name in ["RELAXED", "STANDARD", "CHALLENGING"]:
		difficulty.add_item(name)
	difficulty.select(MatchSetup.ai_difficulty)
	difficulty.position = Vector2(306, 108)
	difficulty.size = Vector2(282, 36)
	difficulty.item_selected.connect(func(index: int): MatchSetup.ai_difficulty = index)
	modal_content.add_child(difficulty)
	_option_label("ROUND TIMER", 158)
	var timer := OptionButton.new()
	for seconds in [60, 99, 120]:
		timer.add_item("%d SECONDS" % seconds, seconds)
	timer.select([60, 99, 120].find(MatchSetup.round_seconds))
	timer.position = Vector2(306, 150)
	timer.size = Vector2(282, 36)
	timer.item_selected.connect(func(index: int): MatchSetup.round_seconds = [60, 99, 120][index])
	modal_content.add_child(timer)
	_toggle_row("CAMERA SHAKE", "IMPACT SHAKE AND LENS KICK", 200, MatchSetup.camera_shake, func(enabled: bool): MatchSetup.camera_shake = enabled)
	_toggle_row("HIT EFFECTS", "SPARKS, DUST, TRAILS AND FLASHES", 240, Settings.hit_effects, func(enabled: bool): Settings.set_option("hit_effects", enabled))
	_toggle_row("INPUT DISPLAY", "SHOW EACH PLAYER'S INPUTS", 280, Settings.input_display, func(enabled: bool): Settings.set_option("input_display", enabled))
	UI.label(modal_content, "Four rounds per match. Options apply to your next fight.", Vector2(28, 322), Vector2(400, 26), 11, UI.MUTED)

## Option name on the left, a labelled toggle on the right.
func _toggle_row(text: String, caption: String, y: float, on: bool, apply: Callable) -> CheckBox:
	_option_label(text, y)
	var box := CheckBox.new()
	box.text = caption
	box.position = Vector2(306, y - 8)
	box.size = Vector2(282, 34)
	box.button_pressed = on
	box.toggled.connect(apply)
	modal_content.add_child(box)
	return box

## Left-hand option name with a gold tick, as on arcade option screens.
func _option_label(text: String, y: float) -> void:
	UI.panel(modal_content, Vector2(28, y + 4), Vector2(4, 16), UI.GOLD, Color.TRANSPARENT)
	var node := UI.label(modal_content, text, Vector2(42, y), Vector2(250, 24), 15, UI.WHITE)
	node.add_theme_font_override("font", UI.strong_font())

func _start_fight() -> void:
	if transitioning or is_instance_valid(modal):
		return
	transitioning = true
	for child in get_children():
		if child is Button:
			child.disabled = true
	var fade := ColorRect.new()
	fade.color = Color("07080f")
	fade.modulate.a = 0.0
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var wipe := Control.new()
	wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wipe.draw.connect(func(): backdrop.draw_wipe(wipe))
	add_child(wipe)
	backdrop.wipe_canvas = wipe
	move_child(fade, -1)
	preload("res://scripts/sfx.gd").fire("wipe")
	var tween := create_tween()
	tween.tween_property(backdrop, "opening", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn"))

func _show_roster() -> void:
	if is_instance_valid(modal):
		_close_modal()
	_start_fight()

## Full-screen option page: dark scrim, a crimson header slash, then a
## slanted content panel. Content keeps a 620 x 372 coordinate space.
func _open_modal(title: String, eyebrow: String) -> void:
	return_focus = get_viewport().gui_get_focus_owner()
	for child in get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_NONE
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.018, 0.035, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(0, 58), Vector2(960, 30), Vector2(960, 44), Vector2(0, 72)])
	band.color = Color(UI.CRIMSON, 0.85)
	modal.add_child(band)
	modal_content = Control.new()
	modal_content.position = Vector2(170, 87)
	modal.add_child(modal_content)
	var face := UI.box(Color(0.045, 0.05, 0.09, 0.97), UI.GOLD, 0, 0.04)
	face.border_width_left = 6
	var body := Panel.new()
	body.size = Vector2(620, 372)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override("panel", face)
	modal_content.add_child(body)
	UI.eyebrow(modal_content, eyebrow, Vector2(28, 20), Vector2(500, 20))
	UI.heading(modal_content, title, Vector2(26, 40), Vector2(560, 50), 40, UI.WHITE)
	var close := UI.button(modal_content, "BACK  /  ESC", Vector2(440, 311), Vector2(152, 38))
	close.pressed.connect(_close_modal)
	close.grab_focus()
	UI.enter(modal_content)

func _show_settings() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("YOUR SETUP", "SETTINGS")
	_toggle_row("DISPLAY", "FULLSCREEN", 104, Settings.fullscreen, Settings.set_fullscreen)
	_volume_row("MASTER VOLUME", 142, Settings.volume, Settings.set_volume)
	_volume_row("SOUND EFFECTS", 176, Settings.sfx_volume, Settings.set_sfx_volume)
	_toggle_row("TOUCH CONTROLS", "ON-SCREEN BUTTONS", 214, Settings.touch_controls, Settings.set_touch_controls)
	_option_label("GRAPHICS", 250)
	var graphics := UI.button(modal_content, "%s  ▶" % QUALITY_NAMES[Settings.quality], Vector2(306, 242), Vector2(282, 34))
	graphics.pressed.connect(func():
		_close_modal()
		_show_graphics())
	var pages := [["FIGHT OPTIONS  ▶", 28.0, 190.0, _show_fight_options], ["CONTROLS  ▶", 226.0, 150.0, _show_controls], ["HOW TO PLAY  ▶", 384.0, 172.0, _show_guide]]
	for page in pages:
		var open := UI.button(modal_content, page[0], Vector2(page[1], 284), Vector2(page[2], 34))
		open.pressed.connect(func():
			_close_modal()
			page[3].call())
	var reset := UI.button(modal_content, "RESET DEFAULTS", Vector2(28, 326), Vector2(170, 30))
	reset.pressed.connect(func():
		Settings.reset_defaults()
		MatchSetup.camera_shake = true
		_close_modal()
		_show_settings())
	UI.label(modal_content, "Saved automatically.", Vector2(206, 332), Vector2(220, 20), 11, UI.MUTED)

## Every key for both players, as chips.
func _show_controls() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("KEYS AND COMMANDS", "SETTINGS  /  CONTROLS")
	for player in 2:
		var x := 28.0 + player * 294
		var color := UI.GOLD if player == 0 else UI.VIOLET
		UI.panel(modal_content, Vector2(x, 96), Vector2(270, 212), Color(color, 0.08), Color(color, 0.6), 0.06)
		UI.heading(modal_content, "PLAYER %d" % (player + 1), Vector2(x + 14, 100), Vector2(240, 28), 20, color, Color(0, 0, 0, 0.6))
		var keys := [["A / D", "APPROACH / RETREAT"], ["W / S", "SIDESTEP"], ["SPACE", "JUMP"], ["E", "GUARD"], ["F", "1  LEFT PUNCH"], ["V", "2  RIGHT PUNCH"], ["G", "3  LEFT KICK"], ["B", "4  RIGHT KICK"], ["H", "GRAPPLE"], ["SHIFT", "RUN"]] if player == 0 \
			else [["← / →", "APPROACH / RETREAT"], ["↑ / ↓", "SIDESTEP"], ["ENTER", "JUMP"], ["O", "GUARD"], ["K", "1  LEFT PUNCH"], [",", "2  RIGHT PUNCH"], ["L", "3  LEFT KICK"], [".", "4  RIGHT KICK"], ["J", "GRAPPLE"], ["CTRL", "RUN"]]
		for k in keys.size():
			UI.key_hint(modal_content, keys[k][0], keys[k][1], Vector2(x + 14, 132 + k * 17))
	var tip := UI.label(modal_content, "Double-tap forward to dash, back to backdash. Punch + Kick together grapples; the same tap just before contact escapes a throw.\nF1 movebook  /  Esc pause  /  R next round or rematch.", Vector2(28, 314), Vector2(400, 46), 11, UI.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

const QUALITY_NAMES := ["LOW", "MEDIUM", "HIGH", "CUSTOM"]

## Graphics page: a quality preset plus each option it controls. Picking a
## preset updates the rows below; changing a row switches to CUSTOM.
func _show_graphics() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("GRAPHICS", "SETTINGS  /  GRAPHICS")
	var rows := [
		["QUALITY", "quality", QUALITY_NAMES],
		["RESOLUTION", "render_scale", ["50%  (FASTEST)", "75%", "100%  (SHARPEST)"]],
		["ANTI-ALIASING", "anti_aliasing", ["OFF", "2X", "4X"]],
		["SHADOWS", "shadows", ["OFF", "LOW", "HIGH"]],
		["ARENA TEXTURES", "detailed_textures", ["STANDARD", "PHOTO-REAL"]],
	]
	var pickers: Dictionary = {}
	for i in rows.size():
		var row: Array = rows[i]
		var y := 100.0 + i * 38.0
		_option_label(row[0], y)
		var picker := OptionButton.new()
		for choice in row[2]:
			picker.add_item(choice)
		picker.position = Vector2(306, y - 8)
		picker.size = Vector2(282, 32)
		picker.focus_mode = Control.FOCUS_NONE
		modal_content.add_child(picker)
		pickers[row[1]] = picker
	var refresh := func():
		for key in pickers:
			pickers[key].select(int(Settings.get(key)))
	refresh.call()
	# Custom is a result, not something to pick.
	pickers.quality.set_item_disabled(3, true)
	pickers.quality.item_selected.connect(func(index: int):
		Settings.set_quality(index)
		refresh.call())
	for key in ["render_scale", "anti_aliasing", "shadows"]:
		pickers[key].item_selected.connect(func(index: int):
			Settings.set_graphic(key, index)
			refresh.call())
	pickers.detailed_textures.item_selected.connect(func(index: int):
		Settings.set_graphic("detailed_textures", index == 1)
		refresh.call())
	for pair in [["VSYNC", "vsync", 28.0, 296.0], ["SHOW FPS", "show_fps", 176.0, 296.0], ["BLOOM AND GRADE", "post_effects", 316.0, 296.0], ["AUTO-ADJUST WHEN A FIGHT DROPS UNDER 30 FPS", "adaptive_quality", 28.0, 330.0]]:
		var toggle := CheckBox.new()
		toggle.text = pair[0]
		toggle.position = Vector2(pair[2], pair[3])
		toggle.size = Vector2(140 if pair[2] < 300.0 else 200, 30)
		toggle.button_pressed = Settings.get(pair[1])
		toggle.toggled.connect(func(on: bool):
			Settings.set(pair[1], on)
			Settings.apply_graphics()
			Settings._save())
		modal_content.add_child(toggle)

## Option name, slider and live percentage for one volume setting.
func _volume_row(text: String, y: float, level: float, apply: Callable) -> void:
	_option_label(text, y)
	var value := UI.heading(modal_content, "%d%%" % roundi(level * 100), Vector2(532, y - 7), Vector2(64, 32), 22, UI.GOLD)
	var slider := HSlider.new()
	slider.position = Vector2(306, y + 1)
	slider.size = Vector2(216, 24)
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = level
	slider.value_changed.connect(func(volume: float):
		apply.call(volume)
		value.text = "%d%%" % roundi(volume * 100))
	modal_content.add_child(slider)

func _show_guide() -> void:
	if transitioning or is_instance_valid(modal):
		return
	_open_modal("KNOW YOUR MOVES", "HOW TO PLAY")
	# Left: the basics, both players' keys side by side.
	UI.eyebrow(modal_content, "BASICS", Vector2(28, 98), Vector2(270, 16), UI.GOLD)
	UI.label(modal_content, "P1", Vector2(178, 98), Vector2(40, 16), 11, UI.GOLD)
	UI.label(modal_content, "P2", Vector2(244, 98), Vector2(40, 16), 11, UI.VIOLET)
	var basics := [["MOVE", "A  D", "← →"], ["SIDESTEP", "W  S", "↑ ↓"], ["JUMP", "SPACE", "ENTER"], ["GUARD", "E", "O"],
		["1  2  3  4", "F V G B", "K , L ."], ["GRAB", "H", "J"], ["RUN", "SHIFT", "CTRL"]]
	for row in basics.size():
		var y := 118.0 + row * 23.0
		UI.label(modal_content, basics[row][0], Vector2(28, y), Vector2(140, 20), 12, UI.WHITE).add_theme_font_override("font", UI.strong_font())
		UI.label(modal_content, basics[row][1], Vector2(178, y), Vector2(64, 20), 12, UI.GOLD)
		UI.label(modal_content, basics[row][2], Vector2(244, y), Vector2(64, 20), 12, UI.VIOLET)
	UI.label(modal_content, "1 2 punch, 3 4 kick. Hold back to guard too.
F1 in a fight: every move and combo.", Vector2(28, 282), Vector2(290, 34), 11, UI.MUTED)
	# Right: the big moves.
	UI.eyebrow(modal_content, "BIG MOVES", Vector2(322, 98), Vector2(270, 16), UI.GOLD)
	var moves := [
		["2 + 4", "SUPER", "When the gold meter is full (Agasthya, Ananta)"],
		["GRAB", "TAKEDOWN", "Beats guard. Then tap 1 to punch from on top"],
		["GRAB", "ESCAPE", "Tap grab just as theirs lands"],
		["BACK", "ROLL AWAY", "While knocked down: roll clear"],
		["GUARD", "STAY DOWN", "While knocked down: get up late"],
		["ATTACK", "RISING HIT", "Press while getting up"],
		["F2", "TRAINING", "In Practice: what the dummy does"],
	]
	for row in moves.size():
		var y := 118.0 + row * 27.0
		UI.key_hint(modal_content, moves[row][0], "", Vector2(322, y + 1))
		UI.label(modal_content, moves[row][1], Vector2(390, y - 1), Vector2(200, 16), 12, UI.WHITE).add_theme_font_override("font", UI.strong_font())
		UI.label(modal_content, moves[row][2], Vector2(390, y + 12), Vector2(210, 14), 11, UI.MUTED)

func _close_modal() -> void:
	if not is_instance_valid(modal):
		return
	preload("res://scripts/sfx.gd").fire("menu_back")
	modal.queue_free()
	modal = null
	for child in get_children():
		if child is Button and not child in nav_buttons:
			child.focus_mode = Control.FOCUS_ALL
	if is_instance_valid(return_focus):
		return_focus.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_modal()
		get_viewport().set_input_as_handled()

## Up / Down (or Left / Right) walk the list, Enter or A confirms, F2 jumps
## into practice.
func _input(event: InputEvent) -> void:
	if transitioning or is_instance_valid(modal):
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
			_step_entries(1)
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
			_step_entries(-1)
		elif event.is_action_pressed("ui_accept"):
			_confirm()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code: int = event.physical_keycode
	if code == KEY_F2:
		_start_practice()
	elif code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		_step_entries(1 if code in [KEY_DOWN, KEY_RIGHT] else -1)
	elif code in [KEY_ENTER, KEY_KP_ENTER]:
		_confirm()
	else:
		return
	get_viewport().set_input_as_handled()
