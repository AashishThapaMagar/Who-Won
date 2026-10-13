extends Control
## First launch only, straight after the Aananda card: नेपाली or ENGLISH.
## Black like the splash, a warm bloom, the two words side by side. Arrow
## keys, a pad, a click or a tap pick one; the choice is saved and the
## main menu opens. Settings ▸ Language changes it later.
const UI := preload("res://scripts/ui_kit.gd")
var _buttons: Array[Button] = []
var _chosen := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Both languages are written out on purpose: nothing here translates.
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme = UI.theme()
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var bloom := ColorRect.new()
	bloom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec2 d = (UV - vec2(0.5, 0.56)) * vec2(1.4, 2.6); COLOR = vec4(1.0, 0.72, 0.38, exp(-dot(d, d) * 2.2) * 0.13); }"
	var glow := ShaderMaterial.new()
	glow.shader = shader
	bloom.material = glow
	add_child(bloom)
	var title := _word("भाषा छान्नुहोस्", Vector2(0, 104), Vector2(960, 70), 48, UI.devanagari_font(), Color.WHITE)
	var spaced := FontVariation.new()
	spaced.base_font = UI.teko(400)
	spaced.spacing_glyph = 10
	var subtitle := _word("CHOOSE YOUR LANGUAGE", Vector2(0, 176), Vector2(960, 30), 20, spaced, Color(1.0, 0.86, 0.62))
	var rule := ColorRect.new()
	rule.color = Color(1.0, 0.86, 0.62, 0.6)
	rule.position = Vector2(400, 214)
	rule.size = Vector2(160, 1)
	add_child(rule)
	_buttons.append(_choice("नेपाली", "ne", Vector2(196, 262), UI.devanagari_font(), 44))
	_buttons.append(_choice("ENGLISH", "en", Vector2(500, 262), UI.display_font(), 34))
	_buttons[0].focus_neighbor_right = _buttons[1].get_path()
	_buttons[1].focus_neighbor_left = _buttons[0].get_path()
	var note := _word("सेटिङमा जुनसुकै बेला बदल्न सकिन्छ।   /   You can change it any time in Settings.", Vector2(0, 412), Vector2(960, 24), 15, UI.body_font(), Color(1, 1, 1, 0.5))
	# Fade in like the splash card it follows.
	for node: CanvasItem in [title, subtitle, rule, note, _buttons[0], _buttons[1]]:
		node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(title, "modulate:a", 1.0, 0.6)
	tween.parallel().tween_property(subtitle, "modulate:a", 1.0, 0.6).set_delay(0.2)
	tween.parallel().tween_property(rule, "modulate:a", 1.0, 0.6).set_delay(0.2)
	tween.parallel().tween_property(_buttons[0], "modulate:a", 1.0, 0.5).set_delay(0.4)
	tween.parallel().tween_property(_buttons[1], "modulate:a", 1.0, 0.5).set_delay(0.5)
	tween.parallel().tween_property(note, "modulate:a", 1.0, 0.5).set_delay(0.7)
	_buttons[0 if Settings.language == "ne" else 1].grab_focus()

func _word(text: String, pos: Vector2, dimensions: Vector2, font_size: int, font: Font, color: Color) -> Label:
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

func _choice(text: String, code: String, pos: Vector2, font: Font, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = Vector2(264, 104)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(_pick.bind(code))
	button.focus_entered.connect(func():
		if button.modulate.a > 0.5:
			preload("res://scripts/sfx.gd").fire("menu_move"))
	add_child(button)
	return button

func _pick(code: String) -> void:
	if _chosen:
		return
	_chosen = true
	Settings.set_language(code)
	preload("res://scripts/sfx.gd").fire("menu_confirm")
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var tween := create_tween()
	tween.tween_property(cover, "color:a", 1.0, 0.45)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
