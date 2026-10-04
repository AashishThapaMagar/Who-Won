extends Control
## Studio card, the way a console game opens: black, then आनन्द (Aananda)
## settling slowly into place in Devanagari, a hairline of light opening
## beneath, PRESENTS, and back to black. Any key skips it. The Devanagari is
## never letter-spaced: spacing would break the headline joining it.
const UI := preload("res://scripts/ui_kit.gd")
var _advanced := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# A faint warm bloom behind the name.
	var bloom := ColorRect.new()
	bloom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float level = 0.0; void fragment(){ vec2 d = (UV - vec2(0.5, 0.48)) * vec2(1.6, 3.2); float g = exp(-dot(d, d) * 2.5); COLOR = vec4(1.0, 0.72, 0.38, g * 0.16 * level); }"
	var glow := ShaderMaterial.new()
	glow.shader = shader
	glow.set_shader_parameter("level", 0.0)
	bloom.material = glow
	add_child(bloom)
	# Yatra One draws आनन्द with one continuous headline (shirorekha) of its
	# own; Teko broke it into pieces at this size.
	var name_label := _word("आनन्द", Vector2(0, 166), Vector2(960, 140), 104, UI.devanagari_font(), Color.WHITE)
	name_label.name = "PublisherTitle"
	name_label.pivot_offset = Vector2(480, 70)
	name_label.scale = Vector2.ONE * 1.06
	# Faded through colour, never alpha: the glyphs overlap at their joins,
	# and a half-transparent word shows those overlaps as bright specks.
	name_label.modulate = Color.BLACK
	var line := ColorRect.new()
	line.color = Color(1.0, 0.86, 0.62)
	line.position = Vector2(480, 306)
	line.size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var spaced := FontVariation.new()
	spaced.base_font = UI.teko(400)
	spaced.spacing_glyph = 12
	var presents := _word("PRESENTS", Vector2(0, 314), Vector2(960, 34), 22, spaced, Color(1.0, 0.86, 0.62, 0))
	presents.name = "Presents"
	# The card fades out under a black cover, for the same reason.
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(name_label, "modulate", Color.WHITE, 1.2)
	tween.parallel().tween_property(name_label, "scale", Vector2.ONE, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(glow, "shader_parameter/level", 1.0, 1.6)
	tween.parallel().tween_property(line, "size:x", 260.0, 1.4).set_delay(0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(line, "position:x", 350.0, 1.4).set_delay(0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(presents, "theme_override_colors/font_color:a", 1.0, 0.8).set_delay(1.2)
	tween.tween_interval(0.9)
	tween.tween_property(cover, "color:a", 1.0, 0.7)
	tween.tween_callback(_advance)

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

func _advance() -> void:
	if _advanced:
		return
	_advanced = true
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_advance()
	elif event is InputEventMouseButton and event.pressed:
		_advance()
	elif event is InputEventScreenTouch and event.pressed:
		_advance()
