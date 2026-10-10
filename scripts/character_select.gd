extends Control
## Fighter select for every mode. The live arena sits behind at dusk; each
## player's fighter stands full length over a faint gold mandala, with a
## chamfered dossier panel on their outer side; the roster runs along the
## foot as slanted portrait cards; the centre column holds VS, the rules and
## Start. Arcade and Story show the ladder or the chapter instead of a
## second fighter.
const ROSTER := preload("res://scripts/fighter_roster.gd")
const UI := preload("res://scripts/ui_kit.gd")
const PORTRAIT := preload("res://scripts/roster_portrait.gd")
const SUPERS := preload("res://scripts/super_moves.gd")
var selections: Array[int] = [0, 1]
var ready_players: Array[bool] = [false, false]
## Live bust render per roster card.
var previews: Array[Node] = []
var cards: Array[Button] = []
var markers: Array[Label] = []
var selectors: Array[OptionButton] = []
var ready_buttons: Array[Button] = []
## Each player's Voice Studio entry under LOCK IN.
var cry_rows: Array = []
var voice_studio: Control
var player_tabs: Array[Button] = []
var portraits: Array[TextureRect] = []
var names: Array[Label] = []
var details: Array[Label] = []
var start_button: Button
var status_label: Label
var editing_player := 0
var transitioning := false
var mode_id := "local"
var mode_accent := Color("65e4dd")
var difficulty_picker: OptionButton
var backdrop: Control
## Portrait tile behind each roster card, and the card's slanted frame.
var tiles: Array[ColorRect] = []
var frames: Array[Line2D] = []
## The mandala behind each player's fighter, tinted by the fighter.
var rings: Array[ColorRect] = []
## Arcade ladder: one row per rival in fight order, then the final boss.
var ladder_faces: Array[TextureRect] = []
var ladder_names: Array[Label] = []
## Per player: the dossier (strengths, weaknesses and super), the
## Devanagari name and the title line.
var dossiers: Array[RichTextLabel] = []
var watermarks: Array[Label] = []
var titles: Array[Label] = []
var arena_label: Label
var arena_caption: Label
var arena_number: Label
## The chosen arena's photo, faint behind its name in the picker.
var arena_thumb: TextureRect
## The start button's wording for this mode.
var start_text_ready := ""
var info_modal: Control
## Versus arena options, in cycling order (see MatchSetup.stage_choice).
const STAGE_OPTIONS := [-1, 0, 1, 2, 3, 4, 99]
## Random pick roulette per player: the portrait spins through the roster,
## slowing down until it lands, then locks in.
var rolling: Array[bool] = [false, false]
var random_buttons: Array[Button] = []
## Trait phrases that name a weakness rather than a strength.
const WEAK_WORDS := ["low ", "vulnerable", "weak ", "light "]
const P1_COLOR := Color("ffc53d")
const P2_COLOR := Color("6fb4ff")
## Roster strip geometry: slanted cards along the foot.
const CARD_W := 100.0
const CARD_H := 84.0
const CARD_GAP := 8.0
const CARD_SKEW := 16.0
const STRIP_Y := 418.0
const PANEL_W := 184.0
const SUMMARIES := {
	"anug": ["Dives & saves", "Low stamina"],
	"ish": ["Fast, heavy punches", "Weak to low strikes"],
	"sab": ["Heavy punches & kicks", "Low stamina"],
	"bib": ["Fast, high stamina", "Light punches"],
	"abhi": ["Stamina & power", "Weak guard"],
	"sup": ["Spinning kicks", "Sway & retreat feints"],
	"anant": ["Complete toolkit", "Final boss"]
}
## Dusk grade over the live arena: dark and cool, darkest at the foot and
## edges, so the fighters and type carry the light.
const SELECT_GRADE := """shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec2 c = (uv - vec2(0.5, 0.42)) * vec2(1.25, 1.0);
	float a = 0.62 + smoothstep(0.35, 0.95, length(c)) * 0.3 + smoothstep(0.7, 1.0, uv.y) * 0.3;
	COLOR = vec4(0.012, 0.018, 0.035, clamp(a, 0.0, 0.95));
}
"""
## A faint gold mandala: three rings, a ring of ticks and eight petals,
## turning slowly over a soft glow in the fighter's colour.
const MANDALA := """shader_type canvas_item;
uniform vec4 glow : source_color = vec4(1.0, 0.6, 0.3, 1.0);
uniform float spin = 1.0;
float ring(float r, float at, float width) { return 1.0 - smoothstep(0.0, width, abs(r - at)); }
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.y, p.x) + TIME * 0.05 * spin;
	float lines = ring(r, 0.94, 0.008) + ring(r, 0.82, 0.006) * 0.8 + ring(r, 0.56, 0.006) * 0.6;
	float ticks = step(0.86, r) * step(r, 0.92) * step(0.82, abs(sin(a * 36.0)));
	float petals = ring(r, 0.56 + 0.18 * abs(cos(a * 4.0)), 0.006) * step(r, 0.8);
	float gold = clamp(lines + ticks * 0.7 + petals * 0.55, 0.0, 1.0);
	float halo = (1.0 - smoothstep(0.0, 1.0, r)) * 0.32;
	vec3 col = mix(glow.rgb, vec3(1.0, 0.82, 0.45), gold);
	COLOR = vec4(col, gold * 0.32 + halo * glow.a);
}
"""
## Slanted card: the fighter's colour lit from above, falling to near black,
## cut to a parallelogram.
const TILE_SHADER := """shader_type canvas_item;
uniform vec4 top_color : source_color;
uniform vec4 bottom_color : source_color;
uniform float slant = 0.14;
void fragment() {
	vec2 uv = UV;
	float left = slant * (1.0 - uv.y);
	float inside = step(left, uv.x) * step(uv.x, left + 1.0 - slant);
	vec3 base = mix(top_color.rgb, bottom_color.rgb, uv.y) * 0.5;
	float spot = 1.0 - smoothstep(0.0, 0.7, length((uv - vec2(0.5, 0.3)) * vec2(1.1, 1.2)));
	vec3 col = (base + top_color.rgb * spot * 0.3) * (1.0 - 0.65 * smoothstep(0.5, 1.0, uv.y));
	COLOR = vec4(col, inside);
}
"""
## The bust render cut to the same parallelogram.
const CARD_MASK := """shader_type canvas_item;
uniform float slant = 0.14;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float left = slant * (1.0 - UV.y);
	float inside = step(left, UV.x) * step(UV.x, left + 1.0 - slant);
	COLOR = vec4(tex.rgb, tex.a * inside) * COLOR;
}
"""

static func _shader_material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _ready() -> void:
	theme = UI.theme()
	mode_id = "practice" if MatchSetup.practice else ("story" if MatchSetup.story else ("arcade" if MatchSetup.arcade else ("ai" if MatchSetup.vs_ai else "local")))
	name = mode_id.capitalize() + "Selection"
	var colors := {"local": UI.RED, "ai": UI.VIOLET, "arcade": UI.GOLD, "story": Color("e59bff"), "practice": Color("4cd6a0")}
	mode_accent = colors[mode_id]
	selections.assign(MatchSetup.selected_fighters)
	if MatchSetup.arcade:
		selections[1] = 1 if selections[0] == 0 else 0
	backdrop = preload("res://scripts/menu_backdrop.gd").new()
	backdrop.shade_width = 0.0
	backdrop.picture_mode = true
	add_child(backdrop)
	var ids := []
	for i in ROSTER.PROFILES.size():
		ids.append(ROSTER.profile(i).id)
	preload("res://scripts/fighter_animated.gd").warm(ids)
	backdrop.selected = maxi(0, backdrop.MODE_ORDER.find(mode_id))
	var grade := ColorRect.new()
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade.material = _shader_material(SELECT_GRADE)
	add_child(grade)
	_build_title()
	for player in 2:
		_build_player(player)
	if mode_id == "arcade":
		_build_ladder()
	elif mode_id == "story":
		_build_campaign()
	_build_centre()
	_build_strip()
	_build_footer()
	var cries := get_node_or_null("/root/BattleCry")
	if cries != null:
		cries.changed.connect(func(_player): _refresh_cries())
	_refresh_cries()
	if mode_id == "arcade":
		ready_players.assign([true, true])
	if MatchSetup.vs_ai:
		ready_players[1] = true
	_refresh()

## The Voice Studio entries summarize each player's saved pack.
func _refresh_cries() -> void:
	var cries := get_node_or_null("/root/BattleCry")
	if cries == null:
		return
	for player in cry_rows.size():
		var button: Button = cry_rows[player][0]
		var takes: int = cries.total(player)
		button.text = "VOICE STUDIO" if takes == 0 else "VOICE STUDIO  /  %d TAKE%s" % [takes, "" if takes == 1 else "S"]

func _open_voice_studio(player: int) -> void:
	if transitioning or is_instance_valid(voice_studio):
		return
	voice_studio = preload("res://scripts/voice_studio.gd").new()
	voice_studio.player = player
	voice_studio.profile = ROSTER.profile(selections[player])
	add_child(voice_studio)

func _process(_delta: float) -> void:
	var cries := get_node_or_null("/root/BattleCry")
	if cries != null and cries.recording_player >= 0:
		_refresh_cries()

func _exit_tree() -> void:
	var cries := get_node_or_null("/root/BattleCry")
	if cries != null and cries.recording_player >= 0:
		cries.cancel()

## Letter-spaced title between gold hairlines, the mode beneath it, and the
## outlined player marks in the top corners.
func _build_title() -> void:
	var spaced := FontVariation.new()
	spaced.base_font = UI.saira(600, 112)
	spaced.spacing_glyph = 5
	var text := "CHOOSE YOUR FIGHTER"
	var title := UI.label(self, text, Vector2(180, 12), Vector2(600, 26), 17, UI.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", spaced)
	var half := spaced.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x * 0.5
	for side in [-1, 1]:
		var inner: float = 480.0 + side * (half + 18.0)
		var outer: float = 480.0 + side * (half + 150.0)
		var line := ColorRect.new()
		line.color = Color(UI.GOLD, 0.55)
		line.position = Vector2(minf(inner, outer), 24)
		line.size = Vector2(absf(outer - inner), 1)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
		var diamond := UI.label(self, "◆", Vector2(inner - 6, 15), Vector2(12, 18), 9, UI.GOLD)
		diamond.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mode_names := {"local": "VERSUS", "ai": "VS COMPUTER", "arcade": "ARCADE", "story": "STORY", "practice": "PRACTICE"}
	var nepali := {"local": "भिडन्त", "ai": "कम्प्युटरसँग", "arcade": "आर्केड", "story": "कथा", "practice": "अभ्यास"}
	var mode := UI.label(self, "%s   ·   %s" % [mode_names[mode_id], nepali[mode_id]], Vector2(280, 36), Vector2(400, 22), 17, Color(UI.WHITE, 0.7))
	mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode.add_theme_font_override("font", UI.teko(400))
	var second := "P2"
	if MatchSetup.vs_ai:
		second = "CPU"
	if mode_id == "practice":
		second = "DUMMY"
	if mode_id in ["arcade", "story"]:
		second = "RIVALS" if mode_id == "arcade" else "STORY"
	for player in 2:
		var mark := UI.label(self, "P1" if player == 0 else second, Vector2(20, 2) if player == 0 else Vector2(640, 2), Vector2(300, 66), 54, Color(0, 0, 0, 0))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if player == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		mark.add_theme_font_override("font", UI.saira(900, 100, true))
		mark.add_theme_constant_override("outline_size", 3)
		mark.add_theme_color_override("font_outline_color", P1_COLOR if player == 0 else P2_COLOR)

## One side: the mandala, the full-length fighter and the dossier panel with
## its lock-in controls.
func _build_player(player: int) -> void:
	var single := mode_id in ["arcade", "story"] and player == 1
	var color := P1_COLOR if player == 0 else P2_COLOR
	var centre_x := 315.0 if player == 0 else 645.0
	var ring := ColorRect.new()
	ring.position = Vector2(centre_x - 150, 104)
	ring.size = Vector2(300, 300)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.material = _shader_material(MANDALA)
	ring.material.set_shader_parameter("spin", 1.0 if player == 0 else -1.0)
	ring.visible = not single
	add_child(ring)
	rings.append(ring)
	var portrait := PORTRAIT.new()
	portrait.index = selections[player]
	portrait.facing_left = player == 1
	portrait.hero = not single
	portrait.position = Vector2(centre_x - 175, 48)
	portrait.size = Vector2(350, 370)
	add_child(portrait)
	portrait.visible = not single
	if not single:
		portrait.viewport.size = Vector2i(700, 740)
		portrait.camera.h_offset = 0.0
		portrait.camera.size = 124
	portraits.append(portrait)
	# The dossier panel on the player's outer side, its inner top corner cut.
	var at := Vector2(16, 92) if player == 0 else Vector2(960 - 16 - PANEL_W, 92)
	var panel := Control.new()
	panel.position = at
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = not single
	add_child(panel)
	var cut := 18.0
	var outline := PackedVector2Array([Vector2(0, 0), Vector2(PANEL_W - cut, 0), Vector2(PANEL_W, cut), Vector2(PANEL_W, 248), Vector2(0, 248)]) if player == 0 \
		else PackedVector2Array([Vector2(cut, 0), Vector2(PANEL_W, 0), Vector2(PANEL_W, 248), Vector2(0, 248), Vector2(0, cut)])
	var face := Polygon2D.new()
	face.polygon = outline
	face.color = Color(0.02, 0.03, 0.06, 0.82)
	panel.add_child(face)
	var edge := Line2D.new()
	var loop := outline.duplicate()
	loop.append(outline[0])
	edge.points = loop
	edge.width = 1.0
	edge.default_color = Color(UI.GOLD, 0.45)
	panel.add_child(edge)
	var stripe := ColorRect.new()
	stripe.color = color
	stripe.position = Vector2(0, 0) if player == 0 else Vector2(PANEL_W - 3, 0)
	stripe.size = Vector2(3, 248)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stripe)
	var label := UI.label(panel, "", Vector2(14, 8), Vector2(PANEL_W - 24, 40), 30, UI.WHITE)
	label.add_theme_font_override("font", UI.saira(900, 104, true))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_y", 2)
	names.append(label)
	var title := UI.label(panel, "", Vector2(14, 44), Vector2(PANEL_W - 24, 20), 17, UI.GOLD)
	title.add_theme_font_override("font", UI.teko(500))
	titles.append(title)
	var mark := UI.label(panel, "", Vector2(14, 62), Vector2(PANEL_W - 24, 22), 18, Color(UI.WHITE, 0.55))
	mark.add_theme_font_override("font", UI.teko(400))
	watermarks.append(mark)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.12)
	rule.position = Vector2(14, 88)
	rule.size = Vector2(PANEL_W - 28, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rule)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.position = Vector2(14, 96)
	text.custom_minimum_size = Vector2(PANEL_W - 28, 0)
	text.size = Vector2(PANEL_W - 28, 110)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_override("normal_font", UI.strong_font())
	text.add_theme_font_size_override("normal_font_size", 11)
	text.add_theme_constant_override("line_separation", 3)
	panel.add_child(text)
	dossiers.append(text)
	# The win record rides the header row, right of the Devanagari name.
	var detail := UI.label(panel, "", Vector2(14, 64), Vector2(PANEL_W - 28, 18), 10, Color(UI.WHITE, 0.6))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	detail.add_theme_font_override("font", UI.saira(600, 100))
	details.append(detail)
	var info := UI.button(self, "FIGHTER INFO  +", at + Vector2(14, 214), Vector2(PANEL_W - 28, 24))
	info.add_theme_font_size_override("font_size", 11)
	info.visible = not single
	info.pressed.connect(_show_fighter_info.bind(player))
	# Who is picking, the dice and lock-in, under the panel.
	var tab := UI.button(self, "", at + Vector2(0, -26), Vector2(PANEL_W, 22))
	tab.add_theme_font_override("font", UI.saira(700, 104))
	tab.add_theme_font_size_override("font_size", 11)
	tab.pressed.connect(func(): editing_player = player; _refresh())
	tab.visible = not single and mode_id != "arcade"
	player_tabs.append(tab)
	var computer := MatchSetup.vs_ai and player == 1
	var random := UI.button(self, "?", at + Vector2(0, 256), Vector2(40, 28))
	random.tooltip_text = "Random fighter"
	random.add_theme_font_override("font", UI.saira(900, 100, true))
	random.add_theme_font_size_override("font_size", 16)
	random.pressed.connect(_roulette.bind(player))
	random.visible = not single and not computer and mode_id != "arcade"
	random_buttons.append(random)
	var lock := UI.button(self, "LOCK IN", at + Vector2(46, 256), Vector2(PANEL_W - 46, 28))
	lock.add_theme_font_override("font", UI.saira(800, 104, true))
	lock.add_theme_font_size_override("font_size", 13)
	lock.pressed.connect(_toggle_ready.bind(player))
	lock.visible = not single and not computer and mode_id != "arcade"
	ready_buttons.append(lock)
	# Voice packs: moves and match moments, edited in a dedicated studio.
	var voice := UI.button(self, "VOICE STUDIO", at + Vector2(0, 290), Vector2(PANEL_W, 24))
	voice.add_theme_font_override("font", UI.saira(700, 104))
	voice.add_theme_font_size_override("font_size", 11)
	voice.visible = not single
	voice.tooltip_text = "Record move lines, hit reactions, victory and defeat"
	voice.pressed.connect(_open_voice_studio.bind(player))
	cry_rows.append([voice])

## VS, the computer's difficulty, the status line, Start and the arena.
func _build_centre() -> void:
	var versus := mode_id not in ["arcade", "story"]
	if versus:
		var vs := UI.label(self, "VS", Vector2(400, 128), Vector2(160, 70), 58, UI.GOLD)
		vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vs.add_theme_font_override("font", UI.saira(900, 100, true))
		vs.add_theme_constant_override("outline_size", 6)
		vs.add_theme_color_override("font_outline_color", Color("6a0d18"))
		vs.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		vs.add_theme_constant_override("shadow_offset_y", 4)
	if mode_id == "ai":
		var caption := UI.label(self, "DIFFICULTY", Vector2(400, 188), Vector2(160, 16), 11, UI.GOLD)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_override("font", UI.saira(700, 112))
		difficulty_picker = OptionButton.new()
		for difficulty in ["RELAXED", "STANDARD", "CHALLENGING"]:
			difficulty_picker.add_item(difficulty)
		difficulty_picker.position = Vector2(400, 206)
		difficulty_picker.size = Vector2(160, 28)
		difficulty_picker.select(MatchSetup.ai_difficulty)
		difficulty_picker.item_selected.connect(func(index: int): MatchSetup.ai_difficulty = index)
		add_child(difficulty_picker)
		selectors.append(difficulty_picker)
	var centre_x := 480.0 if versus else (480.0 if mode_id == "arcade" else 480.0)
	# The status line sits on a soft dark pill so it reads over the fighters.
	status_label = UI.label(self, "", Vector2(centre_x - 108, 236), Vector2(216, 28), 10, Color(UI.WHITE, 0.9))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.02, 0.03, 0.06, 0.72)
	pill.set_corner_radius_all(14)
	pill.content_margin_left = 10
	pill.content_margin_right = 10
	status_label.add_theme_stylebox_override("normal", pill)
	status_label.add_theme_font_override("font", UI.saira(600, 104))
	status_label.visible = mode_id != "arcade"
	start_text_ready = {"local": "START DUEL", "ai": "CHALLENGE", "arcade": "READY TO FIGHT", "story": "BEGIN CHAPTER", "practice": "START TRAINING"}[mode_id]
	start_button = UI.button(self, start_text_ready, Vector2(centre_x - 104, 270), Vector2(208, 36), true)
	start_button.add_theme_font_override("font", UI.saira(800, 100, true))
	start_button.add_theme_font_size_override("font_size", 15)
	# Locked until both fighters are in: a dark slab with a gold hairline,
	# the start line readable but clearly waiting.
	start_button.add_theme_stylebox_override("disabled", UI.box(Color(0.03, 0.04, 0.08, 0.88), Color(UI.GOLD, 0.35), 1, UI.SLANT))
	start_button.add_theme_color_override("font_disabled_color", Color(UI.WHITE, 0.42))
	start_button.pressed.connect(_start_match)
	if not MatchSetup.arcade:
		_build_stage_picker()

func _build_strip() -> void:
	var count := ROSTER.PROFILES.size()
	var total := count * CARD_W + (count - 1) * CARD_GAP
	var start := (960.0 - total - CARD_SKEW) * 0.5
	var slant := CARD_SKEW / (CARD_W + CARD_SKEW)
	for i in count:
		var x := start + i * (CARD_W + CARD_GAP)
		var box := Vector2(CARD_W + CARD_SKEW, CARD_H)
		var profile := ROSTER.profile(i)
		var tile := ColorRect.new()
		tile.position = Vector2(x, STRIP_Y)
		tile.size = box
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.material = _shader_material(TILE_SHADER)
		var base: Color = profile.color
		tile.material.set_shader_parameter("top_color", base.lightened(0.3))
		tile.material.set_shader_parameter("bottom_color", base.darkened(0.3))
		tile.material.set_shader_parameter("slant", slant)
		add_child(tile)
		tiles.append(tile)
		# Baked busts (tools/bake_roster_busts.gd): every fighter in the same
		# pose and framing, and no live 3D render per card.
		var bust_path := "res://assets/menu/busts/bust_%s.png" % profile.id
		var thumbnail: Control
		if ResourceLoader.exists(bust_path):
			var picture := TextureRect.new()
			picture.texture = load(bust_path)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			thumbnail = picture
		else:
			thumbnail = PORTRAIT.new()
			thumbnail.index = i
			thumbnail.bust = true
		thumbnail.position = Vector2(x, STRIP_Y)
		thumbnail.size = box
		thumbnail.material = _shader_material(CARD_MASK)
		thumbnail.material.set_shader_parameter("slant", slant)
		add_child(thumbnail)
		previews.append(thumbnail)
		var frame := Line2D.new()
		frame.points = PackedVector2Array([Vector2(x + CARD_SKEW, STRIP_Y), Vector2(x + box.x, STRIP_Y), Vector2(x + CARD_W, STRIP_Y + CARD_H), Vector2(x, STRIP_Y + CARD_H), Vector2(x + CARD_SKEW, STRIP_Y)])
		frame.width = 1.0
		frame.joint_mode = Line2D.LINE_JOINT_SHARP
		add_child(frame)
		frames.append(frame)
		var card := UI.button(self, "", Vector2(x, STRIP_Y), box)
		card.focus_mode = Control.FOCUS_NONE
		var clear := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus"]:
			card.add_theme_stylebox_override(state, clear)
		card.pressed.connect(_choose.bind(i))
		cards.append(card)
		var card_name := UI.label(self, profile.name, Vector2(x, STRIP_Y + CARD_H - 20), Vector2(CARD_W, 18), 12, UI.WHITE)
		card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_name.add_theme_font_override("font", UI.saira(800, 104, true))
		card_name.add_theme_constant_override("outline_size", 4)
		card_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		var marker := UI.label(self, "", Vector2(x + CARD_SKEW + 4, STRIP_Y + 3), Vector2(80, 16), 10, UI.WHITE)
		marker.add_theme_color_override("font_outline_color", UI.INK)
		marker.add_theme_constant_override("outline_size", 4)
		marker.add_theme_font_override("font", UI.saira(800, 100))
		markers.append(marker)

## Diamond-marked prompts along the foot; Back is clickable.
func _build_footer() -> void:
	var hints := [["A/D / ←→", "CHOOSE"], ["F / K", "LOCK IN"], ["R", "RANDOM"], ["TAB", "ARENA"], ["ENTER", "FIGHT"], ["ESC", "BACK"]]
	if mode_id == "practice":
		hints = [["A / D", "YOUR FIGHTER"], ["ARROWS", "THE DUMMY"], ["F / K", "LOCK IN"], ["ENTER", "TRAIN"], ["ESC", "BACK"]]
	elif mode_id == "arcade":
		hints = [["A / D", "CHOOSE"], ["R", "RANDOM"], ["ENTER", "FIGHT"], ["ESC", "BACK"]]
	elif mode_id in ["ai", "story"]:
		hints = [["A / D", "YOUR FIGHTER"], ["ARROWS", "RIVAL"], ["F", "LOCK IN"], ["ENTER", "FIGHT"], ["ESC", "BACK"]] if mode_id == "ai" else [["A / D", "CHOOSE"], ["F", "LOCK IN"], ["ENTER", "BEGIN"], ["ESC", "BACK"]]
	var font := UI.saira(600, 104)
	var widths: Array[float] = []
	var total := 0.0
	for hint in hints:
		var w: float = font.get_string_size("◇  %s  %s" % hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 26.0
		widths.append(w)
		total += w
	var x := 480.0 - total * 0.5
	for i in hints.size():
		var prompt := Button.new()
		prompt.flat = true
		prompt.focus_mode = Control.FOCUS_NONE
		prompt.text = "◇  %s  %s" % hints[i]
		prompt.add_theme_font_override("font", font)
		prompt.add_theme_font_size_override("font_size", 11)
		prompt.add_theme_color_override("font_color", Color(UI.WHITE, 0.75))
		prompt.add_theme_color_override("font_hover_color", UI.GOLD)
		for state in ["normal", "hover", "pressed", "focus"]:
			prompt.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		prompt.position = Vector2(x, 510)
		prompt.size = Vector2(widths[i], 22)
		if hints[i][1] == "BACK":
			prompt.pressed.connect(_back)
		elif hints[i][1] == "RANDOM":
			prompt.pressed.connect(func(): _roulette(editing_player))
		elif hints[i][1] in ["FIGHT", "TRAIN", "BEGIN"]:
			prompt.pressed.connect(_start_match)
		elif hints[i][1] == "ARENA":
			prompt.pressed.connect(_cycle_stage.bind(1))
		add_child(prompt)
		x += widths[i]

## Random select: spin through the roster with a slowing tick, land on a
## fighter the player is not already using, and lock in.
func _roulette(player: int) -> void:
	if transitioning or rolling[player] or (MatchSetup.arcade and player == 1) or (MatchSetup.vs_ai and player == 1):
		return
	rolling[player] = true
	ready_players[player] = false
	editing_player = player
	var landing := posmod(selections[player] + 1 + randi() % (ROSTER.PROFILES.size() - 1), ROSTER.PROFILES.size())
	var steps := 12 + posmod(landing - selections[player], ROSTER.PROFILES.size())
	var tween := create_tween()
	for i in steps:
		var delay := 0.04 + 0.16 * pow(float(i) / steps, 2.5)
		tween.tween_interval(delay)
		tween.tween_callback(func():
			selections[player] = posmod(selections[player] + 1, ROSTER.PROFILES.size())
			if MatchSetup.arcade:
				selections[1] = 1 if selections[0] == 0 else 0
			preload("res://scripts/sfx.gd").fire("menu_move", -6.0, 1.0 + 0.3 * float(i) / steps)
			_refresh())
	tween.tween_callback(func():
		rolling[player] = false
		if selections[player] != landing:
			selections[player] = landing
		if MatchSetup.arcade:
			selections[1] = 1 if selections[0] == 0 else 0
			ready_players[1] = true
		ready_players[player] = true
		preload("res://scripts/sfx.gd").fire("menu_confirm")
		editing_player = 0 if MatchSetup.vs_ai else 1 - player
		_refresh())

## The dossier text for a fighter: each trait phrase as a strength or a
## weakness, then the super.
static func _dossier_text(profile: Dictionary) -> String:
	var lines: Array[String] = []
	for phrase in String(profile.trait).split(" / "):
		var line: String = phrase.strip_edges()
		if line.is_empty():
			continue
		line = line.substr(0, 1).to_upper() + line.substr(1)
		var lower := line.to_lower() + " "
		if WEAK_WORDS.any(func(word): return lower.begins_with(word) or lower.contains(" " + word)):
			lines.append("[color=#ff6b6b]▼  %s[/color]" % line)
		elif lower.begins_with("beat "):
			lines.append("[color=#9aa3bd]◆  %s[/color]" % line)
		else:
			lines.append("[color=#ffd257]▲  %s[/color]" % line)
	var data: Dictionary = SUPERS.get_super(str(profile.id))
	if not data.is_empty():
		lines.append("[color=#ffffff]★  SUPER  %s[/color]" % data.name)
	return "\n".join(lines)

## A chamfered card on the right in place of a second fighter.
func _side_card(heading: String) -> Control:
	var at := Vector2(960 - 16 - PANEL_W - 30, 66)
	var card := Control.new()
	card.position = at
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var w := PANEL_W + 30
	var outline := PackedVector2Array([Vector2(18, 0), Vector2(w, 0), Vector2(w, 300), Vector2(0, 300), Vector2(0, 18)])
	var face := Polygon2D.new()
	face.polygon = outline
	face.color = Color(0.02, 0.03, 0.06, 0.82)
	card.add_child(face)
	var edge := Line2D.new()
	var loop := outline.duplicate()
	loop.append(outline[0])
	edge.points = loop
	edge.width = 1.0
	edge.default_color = Color(UI.GOLD, 0.45)
	card.add_child(edge)
	var title := UI.label(card, heading, Vector2(16, 10), Vector2(w - 28, 20), 12, UI.GOLD)
	title.add_theme_font_override("font", UI.saira(800, 112))
	return card

## Story: the chapter the run begins with.
func _build_campaign() -> void:
	var card := _side_card("CHAPTER 01")
	UI.label(card, "Every rival has a story.", Vector2(16, 36), Vector2(190, 50), 18, UI.WHITE).add_theme_font_override("font", UI.saira(800, 100, true))
	var prose := UI.label(card, "Begin with the prologue. Meet each challenger. Fight your way to Ananta. Your victories carry the journey forward.", Vector2(16, 96), Vector2(186, 120), 12, Color(UI.WHITE, 0.75))
	prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prose.add_theme_font_override("font", UI.saira(400, 100))
	var road := UI.label(card, "PROLOGUE  /  RIVALS  /  FINALE", Vector2(16, 268), Vector2(190, 18), 10, UI.GOLD)
	road.add_theme_font_override("font", UI.saira(700, 104))

## Arcade: the rivals in fight order, then the final boss.
func _build_ladder() -> void:
	var card := _side_card("THE LADDER")
	for k in 6:
		var boss := k == 5
		var y := 36.0 + k * 42.0
		var face := TextureRect.new()
		face.position = Vector2(16, y)
		face.size = Vector2(36, 36)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(face)
		ladder_faces.append(face)
		var number := UI.label(card, "BOSS" if boss else "%02d" % (k + 1), Vector2(60, y + 2), Vector2(50, 16), 10, UI.RED if boss else UI.GOLD)
		number.add_theme_font_override("font", UI.saira(800, 104))
		var rival := UI.label(card, "", Vector2(60, y + 16), Vector2(150, 20), 15, UI.WHITE)
		rival.add_theme_font_override("font", UI.saira(800, 104, true))
		ladder_names.append(rival)

## Versus modes choose their arena here; Arcade and Story keep the journey.
func _build_stage_picker() -> void:
	# One framed card: header row, the arena's photo faint behind its name,
	# and flat chevrons that sit inside the frame.
	var at := Vector2(372, 316)
	var size := Vector2(216, 96)
	var card := UI.panel(self, at, size, Color(0.02, 0.03, 0.06, 0.92), Color(UI.GOLD, 0.55))
	card.clip_contents = true
	arena_thumb = TextureRect.new()
	arena_thumb.position = Vector2(1, 1)
	arena_thumb.size = size - Vector2(2, 2)
	arena_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	arena_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena_thumb.modulate = Color(1, 1, 1, 0.32)
	arena_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(arena_thumb)
	var shade := ColorRect.new()
	shade.position = Vector2(1, 1)
	shade.size = Vector2(size.x - 2, 22)
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shade)
	UI.label(card, "BATTLEGROUND", Vector2(10, 3), Vector2(130, 18), 10, UI.MUTED).add_theme_font_override("font", UI.saira(700, 110))
	arena_number = UI.label(card, "", Vector2(size.x - 50, 3), Vector2(40, 18), 10, UI.GOLD)
	arena_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arena_number.add_theme_font_override("font", UI.saira(700, 100))
	for spec in [["‹", Vector2(4, 28), -1], ["›", Vector2(size.x - 32, 28), 1]]:
		var arrow := Button.new()
		arrow.text = spec[0]
		arrow.flat = true
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.position = spec[1]
		arrow.size = Vector2(28, 44)
		arrow.add_theme_font_size_override("font_size", 30)
		arrow.add_theme_color_override("font_color", Color(UI.WHITE, 0.8))
		arrow.add_theme_color_override("font_hover_color", UI.GOLD)
		arrow.add_theme_color_override("font_pressed_color", UI.GOLD)
		for state in ["normal", "hover", "pressed", "focus"]:
			arrow.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		arrow.pressed.connect(_cycle_stage.bind(spec[2]))
		card.add_child(arrow)
	arena_label = UI.label(card, "", Vector2(32, 26), Vector2(size.x - 64, 30), 14, UI.GOLD)
	arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arena_label.add_theme_font_override("font", UI.saira(800, 100, true))
	arena_label.add_theme_constant_override("outline_size", 4)
	arena_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	arena_caption = UI.label(card, "", Vector2(32, 56), Vector2(size.x - 64, 34), 10, Color(UI.WHITE, 0.82))
	arena_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arena_caption.add_theme_font_override("font", UI.saira(600, 100))
	arena_caption.add_theme_constant_override("outline_size", 3)
	arena_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_show_stage()

func _cycle_stage(step: int) -> void:
	if transitioning or not is_instance_valid(arena_label):
		return
	var at := STAGE_OPTIONS.find(MatchSetup.stage_choice)
	MatchSetup.stage_choice = STAGE_OPTIONS[posmod(at + step, STAGE_OPTIONS.size())]
	_show_stage()

## Name the choice and show that arena live behind the roster.
func _show_stage() -> void:
	var rounds: Array = backdrop.STAGE.ROUNDS
	arena_number.text = "%02d/%02d" % [STAGE_OPTIONS.find(MatchSetup.stage_choice) + 1, STAGE_OPTIONS.size()]
	match MatchSetup.stage_choice:
		MatchSetup.JOURNEY_STAGE:
			arena_label.text = "ALL %d ARENAS" % rounds.size()
			arena_caption.text = "The full Nepal journey"
			backdrop.show_stage(0)
			_thumb(0)
		MatchSetup.RANDOM_STAGE:
			arena_label.text = "RANDOM ARENA"
			arena_caption.text = "Let fate choose the stage"
			_thumb(-1)
		_:
			arena_label.text = rounds[MatchSetup.stage_choice].name
			arena_caption.text = String(rounds[MatchSetup.stage_choice].detail).split(" / ")[0]
			backdrop.show_stage(MatchSetup.stage_choice)
			_thumb(MatchSetup.stage_choice)

func _thumb(index: int) -> void:
	if arena_thumb == null:
		return
	var path: String = backdrop.PICTURE % index if index >= 0 else ""
	arena_thumb.texture = load(path) if path != "" and ResourceLoader.exists(path) else null

func _show_fighter_info(player: int) -> void:
	if transitioning or is_instance_valid(info_modal):
		return
	info_modal = Control.new()
	info_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(info_modal)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.85)
	info_modal.add_child(shade)
	var color := P1_COLOR if player == 0 else P2_COLOR
	UI.panel(info_modal, Vector2(250, 110), Vector2(460, 320), UI.INK, color)
	var profile := ROSTER.profile(selections[player])
	UI.heading(info_modal, profile.name, Vector2(278, 128), Vector2(400, 48), 32, color)
	UI.label(info_modal, profile.title, Vector2(278, 180), Vector2(400, 28), 18)
	var text := RichTextLabel.new()
	text.position = Vector2(278, 218)
	text.size = Vector2(404, 148)
	text.bbcode_enabled = true
	text.text = _dossier_text(profile)
	text.add_theme_font_override("normal_font", UI.body_font())
	text.add_theme_font_size_override("normal_font_size", 16)
	info_modal.add_child(text)
	var close := UI.button(info_modal, "BACK / ESC", Vector2(518, 382), Vector2(164, 30))
	close.pressed.connect(_close_fighter_info)
	close.grab_focus()

func _close_fighter_info() -> void:
	info_modal.queue_free()
	info_modal = null
	start_button.grab_focus()

func _back() -> void:
	if not transitioning:
		preload("res://scripts/sfx.gd").fire("menu_back")
		MatchSetup.practice = false
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _choose(index: int) -> void:
	# Arcade: clicking the fighter already chosen goes straight in.
	if mode_id == "arcade" and index == selections[0]:
		_start_match()
		return
	_select_for_player(index, editing_player)

func _select_for_player(index: int, player: int) -> void:
	if transitioning or rolling[player] or (MatchSetup.arcade and player == 1):
		return
	selections[player] = posmod(index, ROSTER.PROFILES.size())
	preload("res://scripts/sfx.gd").fire("menu_move")
	ready_players[player] = MatchSetup.vs_ai and player == 1
	if MatchSetup.arcade:
		selections[1] = 1 if selections[0] == 0 else 0
		ready_players[1] = true
	if mode_id == "arcade":
		ready_players[0] = true
	editing_player = player
	_refresh()

func _toggle_ready(player: int) -> void:
	if transitioning or rolling[player] or (MatchSetup.vs_ai and player == 1):
		return
	if mode_id == "arcade":
		_start_match()
		return
	ready_players[player] = not ready_players[player]
	preload("res://scripts/sfx.gd").fire("menu_confirm" if ready_players[player] else "menu_back")
	editing_player = 0 if MatchSetup.vs_ai else 1 - player
	_refresh()

func _refresh() -> void:
	for i in cards.size():
		var p1 := selections[0] == i
		var p2 := selections[1] == i and mode_id not in ["arcade", "story"]
		var chosen := p1 or p2
		frames[i].default_color = P1_COLOR if p1 else (P2_COLOR if p2 else Color(1, 1, 1, 0.16))
		frames[i].width = 2.5 if chosen else 1.0
		tiles[i].modulate = Color.WHITE if chosen else Color(0.55, 0.55, 0.62)
		previews[i].modulate = Color.WHITE if chosen else Color(0.6, 0.6, 0.66)
		markers[i].text = ("P1 " if p1 else "") + (("CPU" if MatchSetup.vs_ai else "P2") if p2 else "")
	for player in 2:
		var profile := ROSTER.profile(selections[player])
		if portraits[player].index != selections[player] and portraits[player].is_inside_tree() and portraits[player].visible:
			# A fresh pick lands with a pop of the fighter and its name.
			portraits[player].pivot_offset = portraits[player].size * 0.5
			portraits[player].scale = Vector2.ONE * 1.06
			portraits[player].create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(portraits[player], "scale", Vector2.ONE, 0.28)
			names[player].modulate.a = 0.0
			names[player].create_tween().tween_property(names[player], "modulate:a", 1.0, 0.2)
		# Rebuild a fighter only when that pick changed (the other side keeps
		# its model).
		if portraits[player].index != selections[player] or portraits[player].fighter == null:
			portraits[player].show_fighter(selections[player])
		var tint: Color = profile.color
		rings[player].material.set_shader_parameter("glow", Color(tint.lightened(0.2), 0.9))
		names[player].text = profile.name
		# Long names (SARVOCHCHA) shrink to stay inside the panel.
		var font: Font = names[player].get_theme_font("font")
		var width := font.get_string_size(profile.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		names[player].add_theme_font_size_override("font_size", 30 if width <= names[player].size.x else int(30.0 * names[player].size.x / width))
		titles[player].text = String(profile.title).to_upper()
		watermarks[player].text = ROSTER.NEPALI_NAMES.get(profile.id, "")
		var summary: Array = SUMMARIES[profile.id]
		dossiers[player].text = "[color=#ffd257]%s[/color]\n[color=#d2d8e8]%s[/color]" % summary
		var super_data: Dictionary = SUPERS.get_super(str(profile.id))
		if not super_data.is_empty():
			dossiers[player].text += "\n\n[color=#8e98b4]SUPER[/color]\n%s" % super_data.name
		var ledger := "NO RECORD YET"
		var records := get_node_or_null("/root/Records")
		if records != null:
			var record: Dictionary = records.fighter_record(profile.id)
			if record.picks > 0:
				ledger = "RECORD  %dW / %d" % [record.wins, record.picks]
		details[player].text = ledger
		var who := "P%d" % (player + 1)
		var player_color := P1_COLOR if player == 0 else P2_COLOR
		player_tabs[player].text = "%s  ·  %s" % [who, "LOCKED IN" if ready_players[player] else "SELECTING"]
		player_tabs[player].add_theme_color_override("font_color", player_color)
		player_tabs[player].add_theme_stylebox_override("normal", UI.glass(Color(player_color, 0.12), player_color))
		for state in ["hover", "pressed", "hover_pressed"]:
			player_tabs[player].add_theme_stylebox_override(state, UI.glass(Color(player_color, 0.25), player_color))
			ready_buttons[player].add_theme_stylebox_override(state, UI.glass(Color(player_color, 0.3), player_color))
			ready_buttons[player].add_theme_color_override("font_" + state + "_color", player_color)
		if MatchSetup.vs_ai and player == 1:
			player_tabs[player].text = "CPU  ·  READY"
		if mode_id == "practice" and player == 1:
			player_tabs[player].text = "DUMMY  ·  " + ("LOCKED IN" if ready_players[player] else "SELECTING")
		ready_buttons[player].text = "✓  LOCKED IN" if ready_players[player] else "LOCK IN"
		ready_buttons[player].tooltip_text = "Change your selection" if ready_players[player] else "Confirm this fighter"
		if ready_players[player]:
			ready_buttons[player].add_theme_stylebox_override("normal", UI.glass(Color(player_color, 0.22), player_color))
			ready_buttons[player].add_theme_color_override("font_color", player_color)
		else:
			ready_buttons[player].remove_theme_stylebox_override("normal")
			ready_buttons[player].remove_theme_color_override("font_color")
	if not ladder_faces.is_empty():
		var route: Array[int] = []
		for i in range(ROSTER.PROFILES.size() - 1):
			if i != selections[0]:
				route.append(i)
		route.append(ROSTER.PROFILES.size() - 1)
		for k in mini(route.size(), ladder_faces.size()):
			ladder_faces[k].texture = previews[route[k]].texture
			ladder_names[k].text = ROSTER.profile(route[k]).name
	var was_locked := start_button.disabled
	start_button.disabled = not (ready_players[0] and ready_players[1])
	start_button.text = start_text_ready
	if was_locked and not start_button.disabled:
		# Both locked in: the button lands with a pop.
		start_button.scale = Vector2.ONE * 1.12
		start_button.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(start_button, "scale", Vector2.ONE, 0.3)
	status_label.text = "READY TO FIGHT" if not start_button.disabled else "PICK YOUR FIGHTERS, THEN LOCK IN"
	status_label.add_theme_color_override("font_color", UI.GOLD if not start_button.disabled else Color(UI.WHITE, 0.85))

func _input(event: InputEvent) -> void:
	if is_instance_valid(voice_studio):
		if voice_studio.picker.get_popup().visible or voice_studio.takes.get_popup().visible or voice_studio.mic_picker.get_popup().visible:
			return
		if event.is_action_pressed("ui_cancel"):
			voice_studio.close_studio()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(info_modal):
		if event.is_action_pressed("ui_cancel"):
			_close_fighter_info()
			get_viewport().set_input_as_handled()
		return
	if transitioning or (event is InputEventKey and event.echo):
		return
	for selector in selectors:
		if selector.get_popup().visible:
			return
	if event.is_action_pressed("ui_cancel"):
		_back()
		return
	for player in 2:
		var prefix := "p1_" if player == 0 else "p2_"
		if event.is_action_pressed(prefix + "left"):
			_select_for_player(selections[player] - 1, player)
		elif event.is_action_pressed(prefix + "right"):
			_select_for_player(selections[player] + 1, player)
		elif event.is_action_pressed(prefix + "punch"):
			_toggle_ready(player)
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		_roulette(editing_player)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_TAB and is_instance_valid(arena_label):
		_cycle_stage(-1 if event.shift_pressed else 1)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER:
		_start_match()
	elif event is InputEventJoypadButton and event.is_action_pressed("ui_accept") and ready_players[0] and ready_players[1]:
		_start_match()

func _start_match() -> void:
	if transitioning or not (ready_players[0] and ready_players[1]):
		return
	transitioning = true
	preload("res://scripts/sfx.gd").fire("wipe")
	MatchSetup.selected_fighters.assign(selections)
	if MatchSetup.arcade:
		MatchSetup.begin_arcade()
	if MatchSetup.practice:
		get_tree().change_scene_to_file("res://scenes/Practice3D.tscn")
		return
	if MatchSetup.story:
		StoryDirector.start_run()
		var destination: int = StoryDirector.resolve()
		get_tree().change_scene_to_file("res://scenes/StoryDialogue.tscn" if destination == StoryDirector.Destination.DIALOGUE else "res://scenes/Arena3D.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Arena3D.tscn")
