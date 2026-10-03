extends Control
## Arcade title screen: a live 3D arena behind one slanted menu column (fight
## modes, then everything else), with the highlighted entry's splash card on
## the right.
const UI := preload("res://scripts/ui_kit.gd")
const BACKDROP := preload("res://scripts/menu_backdrop.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
const MODES := [
	["arcade", "ARCADE", "Fight the whole roster, then face the final boss."],
	["story", "STORY", "Follow the road through every rival to the final showdown."],
	["local", "VS BATTLE", "Two players. One keyboard. Settle the score."],
	["ai", "VS COMPUTER", "Pick your rival and your difficulty. Master your combos."],
]
const MODE_KEYS := ["arcade", "story", "local", "ai"]
## Non-fight entries that follow the modes in the list: [key, title, text, accent].
const EXTRAS := [
	["practice", "PRACTICE", "Train against a dummy: guard, grab escapes, fight back. F2 changes what it does.", Color("4cd6a0")],
	["records", "RECORDS", "Your fights, wins, streaks, perfects and favourite fighter.", Color("6fb4ff")],
	["settings", "SETTINGS", "Display, sound, graphics, fight options, controls and how to play.", Color("c9cfdf")],
	["exit", "EXIT", "Leave the championship. See you next time.", Color("ff4a5a")],
]
## Each entry's name in Nepali, beside the English.
const NEPALI := {"arcade": "आर्केड", "story": "कथा", "local": "भिडन्त", "ai": "कम्प्युटरसँग",
	"practice": "अभ्यास", "records": "रेकर्ड", "settings": "सेटिङ", "exit": "बाहिर"}
## Order the arrow keys walk through the list.
const ENTRIES := ["arcade", "story", "local", "ai", "practice", "records", "settings", "exit"]
## Gold light sweeping across the title, arcade attract-mode style.
const SHIMMER := """shader_type canvas_item;
// Chrome letters: bright steel at the top, a dark horizon band across the
// middle, warm reflected fire at the bottom, and a white glint sweeping
// across now and then. Graded by screen height (the logo spans top..bottom
// of the screen), since a label's UV is per glyph.
uniform float top = 0.135;
uniform float bottom = 0.325;
void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	float y = clamp((SCREEN_UV.y - top) / (bottom - top), 0.0, 1.0);
	vec3 steel = mix(vec3(1.0, 1.0, 0.98), vec3(0.7, 0.74, 0.82), smoothstep(0.05, 0.47, y));
	steel = mix(steel, vec3(0.22, 0.24, 0.32), smoothstep(0.46, 0.5, y) * (1.0 - smoothstep(0.5, 0.6, y)));
	steel = mix(steel, vec3(0.95, 0.9, 0.85), smoothstep(0.55, 0.7, y));
	steel = mix(steel, vec3(1.0, 0.55, 0.15), smoothstep(0.72, 1.0, y));
	float sweep = fract(TIME * 0.18) * 3.0 - 1.0;
	float glint = 1.0 - smoothstep(0.0, 0.05, abs(SCREEN_UV.x + SCREEN_UV.y * 0.5 - sweep));
	// Only the white letter fill turns to chrome; outline and shadow keep
	// their own colours.
	float fill = step(0.98, min(COLOR.r, min(COLOR.g, COLOR.b)));
	COLOR = vec4(mix(COLOR.rgb, steel + glint * 0.5, fill), glyph.a * COLOR.a);
}
"""
## Fire behind the logo: noise flames licking upward, white-hot at the
## base through orange to deep red, fading out at the edges.
const FLAMES := """shader_type canvas_item;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
void fragment() {
	vec2 uv = UV;
	vec2 q = vec2(uv.x * 4.0, uv.y * 2.4 + TIME * 1.1);
	float n = fbm(q + fbm(q + vec2(0.0, TIME * 0.4)));
	// Taller flames in the middle, none at the sides.
	float body = (1.0 - smoothstep(0.08, 0.5, abs(uv.x - 0.5))) * smoothstep(0.0, 0.85, uv.y);
	float heat = clamp(n * 1.5 * body - (1.0 - uv.y) * 0.55, 0.0, 1.0);
	// Burns out before the bottom edge instead of stopping on a line.
	heat *= 1.0 - smoothstep(0.7, 1.0, uv.y);
	vec3 col = mix(vec3(0.45, 0.02, 0.0), vec3(1.0, 0.35, 0.02), smoothstep(0.15, 0.55, heat));
	col = mix(col, vec3(1.0, 0.85, 0.45), smoothstep(0.6, 0.95, heat));
	COLOR = vec4(col, smoothstep(0.05, 0.35, heat) * 0.95);
}
"""
## Embers drifting up through the dark.
const EMBERS := """shader_type canvas_item;
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 31871.13); }
void fragment() {
	vec2 grid = vec2(48.0, 27.0);
	vec2 uv = UV * grid;
	uv.y += TIME * 1.6;
	vec2 cell = floor(uv);
	float r = hash(cell);
	vec2 at = fract(uv) - vec2(hash(cell + 3.1), hash(cell + 7.7));
	float spark = (1.0 - smoothstep(0.0, 0.06, length(at))) * step(0.9, r);
	float flicker = 0.5 + 0.5 * sin(TIME * 6.0 + r * 40.0);
	COLOR = vec4(1.0, 0.45, 0.1, spark * flicker * 0.8 * smoothstep(0.0, 0.6, UV.y));
}
"""
## Menu geometry, Tekken style: one centred column under the logo.
const ROW_TOP := 222.0
const ROW_STEP := 27.0
const ROW_HEIGHT := 26.0
const GROUP_GAP := 8.0
const ROW_WIDTH := 360.0
## Grades the live arena into a backdrop: a deep reading panel on the left,
## the scene dimmed and cooled behind the featured fighter, darker at the
## top and bottom edges.
const BACKDROP_GRADE := '''shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	float panel = 1.0 - smoothstep(0.2, 0.58, uv.x);
	float edges = smoothstep(0.62, 1.0, uv.y) * 0.55 + (1.0 - smoothstep(0.0, 0.2, uv.y)) * 0.3;
	float a = clamp(0.84 + panel * 0.0 + edges * 0.3, 0.0, 0.96);
	COLOR = vec4(0.02, 0.025, 0.055, a);
}
'''
var backdrop: Control
var extra_rows: Dictionary = {}
## Highlighted non-mode entry (a key from EXTRAS), or "" when a mode is.
var cursor_key := ""
var home_modes: Dictionary = {}
var mode_rows: Dictionary = {}
var mode_desc_label: Label
var mode_title_label: Label
var modal: Control
var modal_content: Control
var play_button: Button
var return_focus: Control
var transitioning: bool = false
var record_strip: Label
var hero: TextureRect
var hero_glow: ColorRect
## Featured fighter showcase: name, title and three stat bars beside the
## hero; the roster rotates until the player browses with Left / Right.
var hero_name: Label
var hero_title: Label
var hero_eyebrow: Label
var hero_stats: Array[ColorRect] = []
var showcase_time := 0.0
var browsing := false
const SHOWCASE_EVERY := 5.0
func _ready() -> void:
	theme = UI.theme()
	backdrop = BACKDROP.new()
	add_child(backdrop)
	backdrop.shade_width = 0.0
	var grade := ColorRect.new()
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade.material = _shader_material(BACKDROP_GRADE)
	add_child(grade)
	var embers := ColorRect.new()
	embers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	embers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	embers.material = _shader_material(EMBERS)
	add_child(embers)
	var flames := ColorRect.new()
	flames.position = Vector2(140, 8)
	flames.size = Vector2(680, 230)
	flames.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flames.material = _shader_material(FLAMES)
	add_child(flames)
	var title := UI.heading(self, "WHO WON?", Vector2(80, 50), Vector2(800, 130), 118, Color.WHITE, Color("8a0a0a"))
	title.name = "GameTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color("1a0505"))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.material = _shader_material(SHIMMER)
	# The logo slams down out of the fire as the screen opens.
	title.pivot_offset = Vector2(400, 65)
	title.scale = Vector2.ONE * 1.35
	title.modulate.a = 0.0
	var land := title.create_tween().set_parallel(true)
	land.tween_property(title, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	land.tween_property(title, "modulate:a", 1.0, 0.2)
	var tagline := UI.eyebrow(self, "KATHMANDU FIGHTING CHAMPIONSHIP", Vector2(180, 34), Vector2(600, 16), UI.GOLD)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The title again in Nepali, burning under the chrome.
	var nepali := UI.label(self, "को जित्यो?", Vector2(180, 172), Vector2(600, 44), 30, Color("ffd257"))
	nepali.name = "NepaliTitle"
	nepali.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nepali.add_theme_font_override("font", UI.devanagari_font())
	nepali.add_theme_constant_override("outline_size", 8)
	nepali.add_theme_color_override("font_outline_color", Color("5a0606"))
	nepali.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	nepali.add_theme_constant_override("shadow_offset_y", 3)
	nepali.modulate.a = 0.0
	nepali.create_tween().tween_property(nepali, "modulate:a", 1.0, 0.5).set_delay(0.35)
	for i in MODES.size():
		var data: Array = MODES[i]
		var row := _mode_row(data[0], data[1], data[2], float(i))
		row.button.pressed.connect(_enter_door.bind(data[0]))
		row.button.mouse_entered.connect(_choose_home_mode.bind(data[0]))
		row.button.focus_entered.connect(_choose_home_mode.bind(data[0]))
		home_modes[data[0]] = row.button
		mode_rows[data[0]] = row
	for i in EXTRAS.size():
		var extra: Array = EXTRAS[i]
		var row := _mode_row(extra[0], extra[1], extra[2], float(MODES.size() + i), extra[3])
		row.button.pressed.connect(_activate_extra.bind(extra[0]))
		row.button.mouse_entered.connect(_point_at.bind(extra[0]))
		extra_rows[extra[0]] = row
	# Start lives on the splash card; clicking a mode or pressing Enter also starts.
	play_button = UI.button(self, "START  ▶", Vector2(786, 452), Vector2(146, 38), true)
	play_button.name = "StartGame"
	play_button.add_theme_font_override("font", UI.display_font())
	play_button.add_theme_font_size_override("font_size", 21)
	play_button.add_theme_stylebox_override("hover", UI.blade(Color("f03a52"), UI.GOLD, 8))
	play_button.add_theme_color_override("font_hover_color", UI.WHITE)
	play_button.pressed.connect(_confirm)
	# Splash card for the highlighted mode.
	# The highlighted entry, explained once, under the list.
	mode_title_label = UI.eyebrow(self, "", Vector2(-1000, -1000), Vector2(10, 10), UI.GOLD)
	mode_title_label.visible = false
	mode_desc_label = UI.label(self, "", Vector2(180, 448), Vector2(600, 18), 12, Color(UI.WHITE, 0.75))
	mode_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The player's ledger sits under the splash card, arcade high-score style.
	record_strip = UI.label(self, "", Vector2(180, 470), Vector2(600, 30), 11, UI.MUTED)
	record_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_strip.add_theme_font_override("font", UI.strong_font())
	record_strip.add_theme_constant_override("outline_size", 4)
	_refresh_record_strip()
	var hint_x := 40.0
	for hint in [["↑↓", "SELECT"], ["ENTER", "CONFIRM"], ["F2", "PRACTICE"]]:
		hint_x += UI.key_hint(self, hint[0], hint[1], Vector2(hint_x, 514))
	UI.label(self, "v1.0  /  PRESS ENTER TO FIGHT", Vector2(640, 514), Vector2(290, 18), 11, UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_refresh_mode_summary()
	play_button.grab_focus()
	_entrance()

## The menu column slides in row by row as the screen opens.
func _entrance() -> void:
	var rows: Array = []
	for key in ENTRIES:
		rows.append(mode_rows.get(key, extra_rows.get(key)))
	for i in rows.size():
		var btn: Button = rows[i].button
		var home: Vector2 = btn.position
		btn.position = home - Vector2(60, 0)
		btn.modulate.a = 0.0
		var tween := btn.create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "position", home, 0.5).set_delay(0.06 * i)
		tween.tween_property(btn, "modulate:a", 1.0, 0.3).set_delay(0.06 * i)

## A material for a canvas shader. The code is set before the shader joins
## the material: one given its code afterwards drew solid white.
static func _shader_material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

## Puts a fighter in the spotlight: portrait, name, title and stats. With
## animate, the old one dips out and the new one comes up.
func _show_hero(index: int, animate := true) -> void:
	# Claimed now, so quick repeated presses step on from the new pick.
	hero.index = index
	var profile := ROSTER.profile(index)
	var apply := func():
		hero.show_fighter(index)
		hero_name.text = profile.name
		hero_name.add_theme_color_override("font_shadow_color", (profile.color as Color).darkened(0.1))
		hero_title.text = String(profile.title).to_upper()
		var values := [
			clampf((float(profile.get("punch_bonus", 0)) + 3.0) / 7.0, 0.1, 1.0),
			clampf((float(profile.get("speed", 1.0)) - 0.8) / 0.45, 0.1, 1.0),
			clampf(float(profile.get("stamina", 100.0)) / 140.0, 0.1, 1.0),
		]
		for row in hero_stats.size():
			var fill: ColorRect = hero_stats[row]
			if fill.is_inside_tree():
				fill.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(fill, "size:x", 104.0 * values[row], 0.4)
			else:
				fill.size.x = 104.0 * values[row]
	if not animate:
		apply.call()
		return
	var tween := create_tween()
	tween.tween_property(hero, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(hero_name, "modulate:a", 0.0, 0.18)
	tween.tween_callback(apply)
	tween.tween_property(hero, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(hero_name, "modulate:a", 1.0, 0.3)

## Left / Right (or the arrows) choose the featured fighter, who becomes
## player one's pick; browsing stops the showcase rotation.
func _browse_hero(step: int) -> void:
	if hero == null or transitioning or is_instance_valid(modal):
		return
	browsing = true
	hero_eyebrow.text = "YOUR FIGHTER"
	var next := posmod(hero.index + step, ROSTER.PROFILES.size())
	MatchSetup.selected_fighters[0] = next
	_show_hero(next)
	preload("res://scripts/sfx.gd").fire("menu_move")

## Until the player browses, the spotlight tours the roster.
func _process(delta: float) -> void:
	if hero == null or browsing or transitioning or is_instance_valid(modal):
		return
	showcase_time += delta
	if showcase_time >= SHOWCASE_EVERY:
		showcase_time = 0.0
		hero_eyebrow.text = "THE ROSTER"
		_show_hero(posmod(hero.index + 1, ROSTER.PROFILES.size()))

func _enter_door(mode: String) -> void:
	if transitioning or is_instance_valid(modal):
		return
	_choose_home_mode(mode)
	_start_fight()

func _start_practice() -> void:
	if transitioning or is_instance_valid(modal):
		return
	transitioning = true
	get_tree().change_scene_to_file("res://scenes/Practice3D.tscn")

## One slanted bar in the menu column: its name on an accent edge. Fight
## modes come first; a small gap separates them from the other entries.
func _mode_row(mode_key: String, title: String, desc: String, index: float, accent := Color.TRANSPARENT) -> Dictionary:
	var y := ROW_TOP + index * ROW_STEP + (GROUP_GAP if index >= MODES.size() else 0.0)
	if accent.a == 0.0:
		accent = BACKDROP.ACCENTS[BACKDROP.MODE_ORDER.find(mode_key)]
	var x := 480.0 - ROW_WIDTH * 0.5
	var btn := UI.button(self, "", Vector2(x, y), Vector2(ROW_WIDTH, ROW_HEIGHT))
	btn.name = title.replace(" ", "") + "Mode"
	btn.focus_mode = Control.FOCUS_NONE
	var band := TextureRect.new()
	band.texture = _band_texture()
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.size = Vector2(ROW_WIDTH, ROW_HEIGHT)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.modulate.a = 0.0
	btn.add_child(band)
	var heading := UI.heading(btn, title + " MODE" if index < MODES.size() else title, Vector2(0, 0), Vector2(ROW_WIDTH, ROW_HEIGHT), 19, UI.GOLD, Color(0, 0, 0, 0.8))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_constant_override("shadow_offset_x", 2)
	heading.add_theme_constant_override("shadow_offset_y", 2)
	var local := UI.label(btn, NEPALI.get(mode_key, ""), Vector2(ROW_WIDTH - 130, -3), Vector2(120, ROW_HEIGHT), 15, Color(1.0, 0.78, 0.25, 0.55))
	local.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	local.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	local.add_theme_font_override("font", UI.devanagari_font())
	return {"button": btn, "title": title, "desc": desc, "accent": accent, "heading": heading, "band": band, "local": local, "home": Vector2(x, y)}

## The selection band: red glowing in the middle, fading out both ways,
## with thin gold rules top and bottom.
static var _band: Texture2D
static func _band_texture() -> Texture2D:
	if _band == null:
		var image := Image.create(128, 16, false, Image.FORMAT_RGBA8)
		for x in 128:
			var fade := 1.0 - absf(x / 127.0 - 0.5) * 2.0
			fade = smoothstep(0.0, 0.55, fade)
			for y in 16:
				var rule := y == 0 or y == 15
				var color := Color(1.0, 0.78, 0.25, fade) if rule else Color(0.72, 0.05, 0.06, fade * 0.85)
				image.set_pixel(x, y, color)
		_band = ImageTexture.create_from_image(image)
	return _band

func _style_row(row: Dictionary, active: bool) -> void:
	var btn: Button = row.button
	var accent: Color = row.accent
	# Idle rows are plain gold text; the chosen one sits on the glowing red
	# band in white, Tekken style.
	var clear := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, clear)
	row.heading.add_theme_color_override("font_color", UI.WHITE if active else Color(1.0, 0.78, 0.25, 0.85))
	row.heading.add_theme_color_override("font_shadow_color", Color("6a0606") if active else Color(0, 0, 0, 0.8))
	row.heading.add_theme_constant_override("outline_size", 3)
	row.band.modulate.a = 1.0 if active else 0.0
	row.local.add_theme_color_override("font_color", Color(1, 0.92, 0.7, 0.95) if active else Color(1.0, 0.78, 0.25, 0.5))
	var target: Vector2 = row.home
	if btn.is_inside_tree():
		btn.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(btn, "position", target, 0.22)
	else:
		btn.position = target
	if active:
		mode_title_label.text = row.title
		mode_title_label.add_theme_color_override("font_color", accent)
		mode_desc_label.text = row.desc
		if hero_glow != null:
			hero_glow.material.set_shader_parameter("tint", Color(accent, 0.55))

func _choose_home_mode(mode: String) -> void:
	if transitioning or is_instance_valid(modal):
		return
	MatchSetup.story = mode == "story"
	MatchSetup.arcade = mode in ["story", "arcade"]
	MatchSetup.vs_ai = mode != "local"
	cursor_key = ""
	_refresh_mode_summary()

## Highlight a non-mode entry without changing the chosen fight mode.
func _point_at(key: String) -> void:
	if transitioning or is_instance_valid(modal):
		return
	cursor_key = key
	_refresh_mode_summary()

func _step_entries(step: int) -> void:
	var current := cursor_key if not cursor_key.is_empty() else _selected_mode()
	var next: String = ENTRIES[posmod(ENTRIES.find(current) + step, ENTRIES.size())]
	if next in MODE_KEYS:
		_choose_home_mode(next)
	else:
		_point_at(next)
	preload("res://scripts/sfx.gd").fire("menu_move")
	play_button.grab_focus()

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
			_start_practice()
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

## Two lines under the splash card: the last fight and the running record.
func _refresh_record_strip() -> void:
	var records := get_node_or_null("/root/Records")
	if records == null or record_strip == null:
		return
	if records.totals.matches == 0:
		record_strip.text = "NO FIGHTS ON RECORD YET\nSTEP IN AND MAKE ONE"
		return
	var last: Dictionary = records.last
	var first := ""
	if not last.is_empty():
		var p1: String = ROSTER.profile(_roster_index(last.p1)).name
		var p2: String = ROSTER.profile(_roster_index(last.p2)).name
		var verdict: String = "DREW WITH" if last.draw else ("BEAT" if last.won else "LOST TO")
		first = "LAST  %s %s %s  %d : %d" % [p1, verdict, p2, last.score[0], last.score[1]]
	record_strip.text = "%s\nRECORD  %dW  %dL  /  STREAK %d  /  WIN RATE %d%%" % [first, records.totals.wins, records.totals.losses, records.totals.streak, records.win_rate()]

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

func _refresh_mode_summary() -> void:
	var selected := _selected_mode()
	backdrop.selected = BACKDROP.MODE_ORDER.find(selected)
	var highlighted := cursor_key if not cursor_key.is_empty() else selected
	for mode in mode_rows:
		_style_row(mode_rows[mode], mode == highlighted)
	for key in extra_rows:
		_style_row(extra_rows[key], key == highlighted)
	play_button.text = "START  ▶" if cursor_key.is_empty() else ("QUIT  ▶" if cursor_key == "exit" else "OPEN  ▶")

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
		["2 + 4", "SUPER", "When the gold meter is full (Ish, Ananta)"],
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
		if child is Button and not child in home_modes.values() and not extra_rows.values().any(func(row): return row.button == child):
			child.focus_mode = Control.FOCUS_ALL
	if is_instance_valid(return_focus):
		return_focus.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_modal()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if transitioning or is_instance_valid(modal):
		return
	# Gamepad: up and down walk the list, left and right browse the
	# featured fighter, A confirms.
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.is_action_pressed("ui_down"):
			_step_entries(1)
		elif event.is_action_pressed("ui_up"):
			_step_entries(-1)
		elif event.is_action_pressed("ui_right"):
			_step_entries(1)
		elif event.is_action_pressed("ui_left"):
			_step_entries(-1)
		elif event.is_action_pressed("ui_accept"):
			_confirm()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F2:
		_start_practice()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		_step_entries(1 if event.physical_keycode in [KEY_DOWN, KEY_RIGHT] else -1)
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ENTER and (play_button.has_focus() or home_modes.values().has(get_viewport().gui_get_focus_owner())):
		_confirm()
		get_viewport().set_input_as_handled()
