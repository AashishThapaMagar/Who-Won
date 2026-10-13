extends Control
## First launch only, straight after the Aananda card: नेपाली or ENGLISH.
## A title card in the film's manner: letterbox bars, drifting warm haze and
## grain, a gold hairline down the middle, the two words either side of it.
## Neither is chosen until the player points at one: the word warms up, a
## gold rule draws under it, the other dims, and the heading crossfades to
## that language alone. Each side is set only in its own script (Devanagari
## or Latin). Arrows, a pad, a click or a tap; Settings ▸ Language later.
const UI := preload("res://scripts/ui_kit.gd")
const WARM := Color(1.0, 0.86, 0.62)
const REST := Color(1, 1, 1, 0.42)

var _choices: Array[Dictionary] = []
var _hovered := -1
var _chosen := false
var _ready_for_input := false
var _heading_ne: Label
var _heading_en: Label
var _haze: ShaderMaterial

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Both languages are written out on purpose: nothing here translates.
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Warm light drifting through smoke, film grain and a deep vignette.
	var haze := ColorRect.new()
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float level = 0.0;
uniform float lean = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.035;
	float smoke = noise(uv * vec2(3.0, 5.0) + vec2(t, -t * 0.6)) * 0.6 + noise(uv * vec2(7.0, 11.0) - vec2(t * 1.7, t)) * 0.4;
	// The light leans toward whichever word is pointed at.
	vec2 c = vec2(0.5 + lean * 0.2, 0.55);
	float pool = exp(-dot((uv - c) * vec2(1.5, 2.6), (uv - c) * vec2(1.5, 2.6)) * 2.4);
	vec3 col = vec3(1.0, 0.68, 0.36) * pool * (0.10 + 0.12 * smoke) * level;
	float grain = hash(uv * 900.0 + fract(TIME * 13.0)) - 0.5;
	col += grain * 0.035 * level;
	float v = smoothstep(1.15, 0.35, length((uv - 0.5) * vec2(1.25, 1.6)));
	COLOR = vec4(col * v, 1.0);
}"""
	_haze = ShaderMaterial.new()
	_haze.shader = shader
	_haze.set_shader_parameter("level", 0.0)
	_haze.set_shader_parameter("lean", 0.0)
	haze.material = _haze
	add_child(haze)
	var bars: Array[ColorRect] = []
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.size = Vector2(960, 0)
		bar.position = Vector2(0, 0 if top else 540)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		bars.append(bar)
	# The heading: both languages at rest, each in its own script; pointing
	# at a word leaves only that language.
	_heading_ne = _text("भाषा छान्नुहोस्", Vector2(0, 96), Vector2(960, 56), UI.devanagari_font(), 40, Color.WHITE)
	var spaced := FontVariation.new()
	spaced.base_font = UI.teko(400)
	spaced.spacing_glyph = 12
	_heading_en = _text("CHOOSE YOUR LANGUAGE", Vector2(0, 150), Vector2(960, 30), spaced, 19, WARM)
	var hairline := ColorRect.new()
	hairline.color = Color(WARM, 0.5)
	hairline.position = Vector2(479.5, 352)
	hairline.size = Vector2(1, 0)
	hairline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hairline)
	var caption_en := FontVariation.new()
	caption_en.base_font = UI.teko(400)
	caption_en.spacing_glyph = 6
	_choices.append(_choice("नेपाली", "नेपालीमा खेल्नुहोस्", "ne", 240.0, UI.devanagari_font(), 62, UI.devanagari_font(), 17))
	_choices.append(_choice("ENGLISH", "PLAY IN ENGLISH", "en", 720.0, UI.display_font(), 46, caption_en, 15))
	# Slow open: bars close in, the light comes up, the words surface.
	for node: CanvasItem in [_heading_ne, _heading_en]:
		node.modulate.a = 0.0
	for choice in _choices:
		choice.word.modulate.a = 0.0
		choice.caption.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_haze, "shader_parameter/level", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	for bar in bars:
		tween.parallel().tween_property(bar, "size:y", 62.0, 1.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bars[1], "position:y", 478.0, 1.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_heading_ne, "modulate:a", 1.0, 1.0).set_delay(0.4)
	tween.parallel().tween_property(_heading_en, "modulate:a", 1.0, 1.0).set_delay(0.6)
	tween.parallel().tween_property(hairline, "size:y", 150.0, 1.2).set_delay(0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(hairline, "position:y", 214.0, 1.2).set_delay(0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for i in _choices.size():
		tween.parallel().tween_property(_choices[i].word, "modulate:a", 1.0, 0.9).set_delay(0.9 + i * 0.15)
		tween.parallel().tween_property(_choices[i].caption, "modulate:a", 1.0, 0.9).set_delay(1.1 + i * 0.15)
	tween.tween_callback(func(): _ready_for_input = true)

func _text(text: String, pos: Vector2, dimensions: Vector2, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

## One side: the word, its caption beneath, a gold rule that draws in when
## pointed at, and an invisible hit area over all of it.
func _choice(word: String, caption: String, code: String, center: float, font: Font, size: int, caption_font: Font, caption_size: int) -> Dictionary:
	# A soft pool of lamp light behind the word, up when it is pointed at.
	var glow := ColorRect.new()
	glow.position = Vector2(center - 220, 196)
	glow.size = Vector2(440, 140)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_shader := Shader.new()
	glow_shader.code = "shader_type canvas_item; uniform float level = 0.0; void fragment(){ vec2 d = (UV - 0.5) * vec2(2.0, 2.6); COLOR = vec4(1.0, 0.66, 0.32, exp(-dot(d, d) * 2.2) * 0.32 * level); }"
	var glow_material := ShaderMaterial.new()
	glow_material.shader = glow_shader
	glow_material.set_shader_parameter("level", 0.0)
	glow.material = glow_material
	add_child(glow)
	var label := _text(word, Vector2(center - 200, 218), Vector2(400, 96), font, size, Color.WHITE)
	label.self_modulate = REST
	label.pivot_offset = Vector2(200, 48)
	var under := _text(caption, Vector2(center - 200, 322), Vector2(400, 28), caption_font, caption_size, Color(WARM, 0.55))
	var rule := ColorRect.new()
	rule.color = WARM
	rule.position = Vector2(center, 314)
	rule.size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	var area := Button.new()
	area.flat = true
	area.focus_mode = Control.FOCUS_NONE
	area.position = Vector2(center - 200, 210)
	area.size = Vector2(400, 150)
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		area.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(area)
	var index := _choices.size()
	area.mouse_entered.connect(func(): _point(index))
	area.pressed.connect(func(): _pick(index))
	return {"word": label, "caption": under, "rule": rule, "glow": glow_material, "code": code, "center": center, "tween": null}

## Lights one side and dims the other; the heading keeps only its language.
func _point(index: int) -> void:
	if _chosen or index == _hovered or not _ready_for_input:
		return
	_hovered = index
	preload("res://scripts/sfx.gd").fire("menu_move")
	for i in _choices.size():
		var choice: Dictionary = _choices[i]
		var on := i == index
		if choice.tween != null:
			choice.tween.kill()
		var tween := create_tween().set_parallel()
		tween.tween_property(choice.word, "self_modulate", Color.WHITE if on else Color(1, 1, 1, 0.22), 0.35)
		tween.tween_property(choice.word, "scale", Vector2.ONE * (1.06 if on else 0.97), 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(choice.glow, "shader_parameter/level", 1.0 if on else 0.0, 0.6)
		tween.tween_property(choice.caption, "modulate:a", 1.0 if on else 0.3, 0.35)
		tween.tween_property(choice.rule, "size:x", 150.0 if on else 0.0, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.tween_property(choice.rule, "position:x", choice.center - (75.0 if on else 0.0), 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		choice.tween = tween
	var nepali: bool = _choices[index].code == "ne"
	var heading := create_tween().set_parallel()
	heading.tween_property(_heading_ne, "modulate:a", 1.0 if nepali else 0.0, 0.4)
	heading.tween_property(_heading_en, "modulate:a", 0.0 if nepali else 1.0, 0.4)
	heading.tween_property(_heading_en, "position:y", 110.0 if not nepali else 150.0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	heading.tween_property(_haze, "shader_parameter/lean", -1.0 if nepali else 1.0, 1.2).set_trans(Tween.TRANS_SINE)

func _unhandled_input(event: InputEvent) -> void:
	if _chosen or not _ready_for_input:
		return
	if event.is_action_pressed("ui_left"):
		_point(0)
	elif event.is_action_pressed("ui_right"):
		_point(1)
	elif event.is_action_pressed("ui_accept") and _hovered >= 0:
		_pick(_hovered)

## The chosen word flares and holds, the rest falls away, then black.
func _pick(index: int) -> void:
	if _chosen or not _ready_for_input:
		return
	_point(index)
	_chosen = true
	Settings.set_language(_choices[index].code)
	preload("res://scripts/sfx.gd").fire("menu_confirm")
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	var chosen: Dictionary = _choices[index]
	var other: Dictionary = _choices[1 - index]
	var tween := create_tween()
	tween.tween_property(chosen.word, "scale", Vector2.ONE * 1.12, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(chosen.glow, "shader_parameter/level", 1.8, 0.4)
	tween.parallel().tween_property(other.word, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(other.caption, "modulate:a", 0.0, 0.5)
	tween.tween_interval(0.35)
	tween.tween_property(cover, "color:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
