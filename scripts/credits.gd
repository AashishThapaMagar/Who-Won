extends Control
## The end credits, to Supreme Khatiwada's theme, the way a film ends: the
## title over one last storybook picture, then the credit roll climbing
## slowly up a black screen in Roman capitals, then a closing card.
## Opened after a story's finale and from the main menu; any key or tap
## after the first moments lets the curtain fall early.

const UI := preload("res://scripts/ui_kit.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")
const NEXT_SCENE := "res://scenes/MainMenu.tscn"
const PICTURE := "res://assets/story/anant/plates/finale_03.jpg"
## Seconds, fitted to the theme (1:26): title card, roll, closing card.
const TITLE_TIME := 9.0
const ROLL_START := 9.5
const ROLL_END := 75.0
const CLOSING_TIME := 11.0
const COLUMN_GAP := 18.0
const PALE := Color("e9e2d0")
const ROLE := Color("b9b09b")
const GILT := Color("c9a45c")

var _roll: Control
var _roll_height := 0.0
var _elapsed := 0.0
var _leaving := false

func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	_roll = Control.new()
	_roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll.position.y = 540.0
	add_child(_roll)
	_build_roll()
	add_child(_grain())
	var music := get_node_or_null("/root/Music")
	if music != null:
		music.play_credits()
	_run()

func _nepali() -> bool:
	return Settings.is_nepali()

func _title() -> String:
	return "कसले जित्यो?" if _nepali() else "WHO WON?"

## Letter spacing suits Roman capitals; it would break Devanagari apart.
func _spaced(amount: int) -> int:
	return 0 if _nepali() else amount

## ── The roll ──
func _build_roll() -> void:
	var y := 0.0
	y = _heading("A GAME BY", y)
	y = _star("AASHISH THAPA MAGAR", y) + 110.0
	y = _heading("THE FIGHTERS", y)
	for i in ROSTER.PROFILES.size():
		var fighter := ROSTER.profile(i)
		# A cast list: the name each fighter goes by, and the fighter.
		if _nepali():
			y = _centred(tr(fighter.name), y, 21, PALE) + 6.0
		else:
			y = _pair(String(fighter.title), fighter.name, y)
	y += 110.0
	y = _heading("THEME MUSIC", y)
	y = _star("SUPREME KHATIWADA", y) + 110.0
	y = _heading("MADE IN", y)
	y = _star("CLAUDE", y) + 110.0
	y = _heading("MADE WITH", y)
	y = _pair("Character Animation", "MIXAMO", y)
	y = _pair("3D Models", "TRIPO AI", y)
	y = _pair("3D Models", "MESHY AI", y)
	y = _pair("Music, Narration and Sound", "ELEVENLABS", y)
	_roll_height = y

func _label(parent: Node, text: String, at: Vector2, width: float, size: int, color: Color, font: Font, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(width, size * 1.6)
	label.horizontal_alignment = align
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	parent.add_child(label)
	return label

## A section's name: small, spaced gilt capitals over a hairline.
func _heading(text: String, y: float) -> float:
	_label(_roll, tr(text), Vector2(0, y), 960, 13, GILT, UI.cinema(600, _spaced(5)), HORIZONTAL_ALIGNMENT_CENTER)
	var rule := ColorRect.new()
	rule.color = Color(GILT, 0.55)
	rule.size = Vector2(56, 1)
	rule.position = Vector2(452, y + 28)
	_roll.add_child(rule)
	return y + 46.0

## One name alone, large.
func _star(text: String, y: float) -> float:
	_label(_roll, tr(text), Vector2(0, y), 960, 34, PALE, UI.cinema(500, _spaced(3)), HORIZONTAL_ALIGNMENT_CENTER)
	return y + 56.0

func _centred(text: String, y: float, size: int, color: Color) -> float:
	_label(_roll, text, Vector2(0, y), 960, size, color, UI.cinema(500), HORIZONTAL_ALIGNMENT_CENTER)
	return y + size * 1.6

## Role on the left, name on the right, either side of the centre line.
func _pair(role: String, name: String, y: float) -> float:
	var half := 480.0 - COLUMN_GAP
	_label(_roll, tr(role), Vector2(0, y + 4), half, 15, ROLE, UI.cinema(500, _spaced(1)), HORIZONTAL_ALIGNMENT_RIGHT)
	_label(_roll, tr(name), Vector2(480.0 + COLUMN_GAP, y), half, 19, PALE, UI.cinema(600, _spaced(2)), HORIZONTAL_ALIGNMENT_LEFT)
	return y + 36.0

## ── Running order ──
func _run() -> void:
	await _title_card()
	if _leaving or not is_inside_tree():
		return
	create_tween().tween_property(_roll, "position:y", -_roll_height, ROLL_END - ROLL_START)
	await get_tree().create_timer(ROLL_END - ROLL_START).timeout
	if _leaving or not is_inside_tree():
		return
	await _closing_card()
	_leave()

## The title over the storybook's last fight, fading up and away.
func _title_card() -> void:
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	add_child(card)
	move_child(card, 1)
	if ResourceLoader.exists(PICTURE):
		var picture := TextureRect.new()
		picture.texture = load(PICTURE)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.pivot_offset = Vector2(480, 270)
		picture.modulate = Color(0.55, 0.55, 0.55)
		card.add_child(picture)
		create_tween().tween_property(picture, "scale", Vector2.ONE * 1.08, TITLE_TIME + 1.0)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.35)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(veil)
	_label(card, _title(), Vector2(0, 228), 960, 52, PALE, UI.cinema(700, _spaced(10)), HORIZONTAL_ALIGNMENT_CENTER)
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 2.4).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(TITLE_TIME - 2.4 - 2.2)
	tween.tween_property(card, "modulate:a", 0.0, 2.2).set_trans(Tween.TRANS_SINE)
	await tween.finished
	card.queue_free()
	await get_tree().create_timer(ROLL_START - TITLE_TIME).timeout

## After the roll: thanks, then the title once more, on black.
func _closing_card() -> void:
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	add_child(card)
	_label(card, tr("THANK YOU FOR PLAYING"), Vector2(0, 222), 960, 15, ROLE, UI.cinema(500, _spaced(6)), HORIZONTAL_ALIGNMENT_CENTER)
	_label(card, _title(), Vector2(0, 252), 960, 40, PALE, UI.cinema(700, _spaced(8)), HORIZONTAL_ALIGNMENT_CENTER)
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 2.8).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(CLOSING_TIME - 2.8)
	await tween.finished

## A faint flicker of film grain over the black.
func _grain() -> ColorRect:
	var grain := ColorRect.new()
	grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = """
shader_type canvas_item;
void fragment() {
	float n = fract(sin(dot(floor(UV * vec2(480.0, 270.0)) + floor(TIME * 18.0), vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(vec3(n), 0.02);
}
"""
	grain.material = material
	return grain

func _unhandled_input(event: InputEvent) -> void:
	if _elapsed < 1.5 or _leaving:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		_leave()

func _process(delta: float) -> void:
	_elapsed += delta

## The curtain falls, the soundtrack returns, back to the menu.
func _leave() -> void:
	if _leaving or not is_inside_tree():
		return
	_leaving = true
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 2.2).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		var music := get_node_or_null("/root/Music")
		if music != null:
			music.play_main()
		get_tree().change_scene_to_file(NEXT_SCENE))
