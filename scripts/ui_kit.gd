extends RefCounted
## Shared visual language for menus and match overlays: Saira type (heavy
## italic for display, clean for text, Teko for Devanagari), thin glass
## buttons with a gold edge and a Nepal crimson / gold palette on deep navy.
const INK := Color("07080f")
const PANEL := Color(0.055, 0.065, 0.11, 0.9)
const LINE := Color("3b3f58")
const WHITE := Color("f6f3ec")
const MUTED := Color("a8afc4")
## Primary accent (gold). Kept under its historical name for existing callers.
const LIME := Color("ffc53d")
const GOLD := LIME
## Player two / secondary accent (sky blue).
const VIOLET := Color("6fb4ff")
const RED := Color("ff4a5a")
const CRIMSON := Color("d7263d")
## Horizontal slant shared by every parallelogram in the interface.
const SLANT := 0.12
static var _display: Font
static var _body: Font
static var _strong: Font

## Heavy italic Saira, semi-condensed, for titles, names and big callouts.
static func display_font() -> Font:
	if _display == null:
		_display = saira(900, 88, true)
	return _display

static func body_font() -> Font:
	if _body == null:
		_body = saira(500, 100)
	return _body

## Bold condensed face for buttons and option labels.
## Yatra One (assets/fonts, SIL Open Font License): a Devanagari display
## face for Nepali titles. Read straight from the .ttf when the editor has
## not imported it yet; Windows' Nirmala UI stands in if the file is gone.
static var _devanagari: Font
static func devanagari_font() -> Font:
	if _devanagari == null:
		var path := "res://assets/fonts/YatraOne-Regular.ttf"
		if ResourceLoader.exists(path):
			_devanagari = load(path)
		elif FileAccess.file_exists(path):
			var file := FontFile.new()
			file.load_dynamic_font(path)
			_devanagari = file
		else:
			var fallback := SystemFont.new()
			fallback.font_names = PackedStringArray(["Nirmala UI", "Mangal", "Noto Sans Devanagari"])
			_devanagari = fallback
	return _devanagari

## Teko (assets/fonts, SIL Open Font License): one condensed family for
## Latin and Devanagari alike, at any weight from 300 (light) to 700
## (bold). The modern menus are set in it.
static var _teko_file: Font
static var _teko: Dictionary = {}
static func teko(weight: int = 500) -> Font:
	if not _teko.has(weight):
		if _teko_file == null:
			var path := "res://assets/fonts/Teko.ttf"
			if ResourceLoader.exists(path):
				_teko_file = load(path)
			elif FileAccess.file_exists(path):
				var file := FontFile.new()
				file.load_dynamic_font(path)
				_teko_file = file
			else:
				return _system_font(600)
		var font := FontVariation.new()
		font.base_font = _teko_file
		font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_teko[weight] = font
	return _teko[weight]

## Saira (assets/fonts, SIL Open Font License): heavy, wide, athletic
## Latin for titles and menus, any weight 100-900 and width 50-125, upright
## or italic. Devanagari stays in Teko.
static var _saira_files: Dictionary = {}
static var _saira: Dictionary = {}
static func saira(weight: int = 600, width: int = 100, italic := false) -> Font:
	var key := "%d/%d/%s" % [weight, width, italic]
	if not _saira.has(key):
		var path := "res://assets/fonts/Saira-Italic.ttf" if italic else "res://assets/fonts/Saira.ttf"
		if not _saira_files.has(path):
			if ResourceLoader.exists(path):
				_saira_files[path] = load(path)
			elif FileAccess.file_exists(path):
				var file := FontFile.new()
				file.load_dynamic_font(path)
				_saira_files[path] = file
			else:
				return _system_font(weight)
		var ts := TextServerManager.get_primary_interface()
		var font := FontVariation.new()
		font.base_font = _saira_files[path]
		font.variation_opentype = {ts.name_to_tag("wght"): weight, ts.name_to_tag("wdth"): width}
		# Devanagari falls back to Teko inside the same label. Teko draws
		# Devanagari numerals as Western ones, so the digits come first
		# from a numerals-only cut of Mukta.
		var numerals := _numerals()
		font.fallbacks = [numerals, teko(500)] if numerals != null else [teko(500)]
		_saira[key] = font
	return _saira[key]

## Devanagari digits only (WhoWonNumerals, cut from Mukta Bold, OFL).
static var _numerals_font: Font
static func _numerals() -> Font:
	if _numerals_font == null:
		var path := "res://assets/fonts/WhoWonNumerals-Bold.ttf"
		if ResourceLoader.exists(path):
			_numerals_font = load(path)
		elif FileAccess.file_exists(path):
			var file := FontFile.new()
			file.load_dynamic_font(path)
			_numerals_font = file
		# The cut keeps no Devanagari shaping tables, so it must be told it
		# serves the script, or Teko is chosen ahead of it.
		if _numerals_font is FontFile:
			(_numerals_font as FontFile).set_script_support_override("Deva", true)
	return _numerals_font

## True when the text holds any Devanagari letter.
static func is_devanagari(text: String) -> bool:
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 0x0900 and code <= 0x097F:
			return true
	return false

## Bold Saira for buttons and option labels.
static func strong_font() -> Font:
	if _strong == null:
		_strong = saira(700, 92)
	return _strong

## A system face, only when the bundled fonts are missing.
static func _system_font(weight: int) -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "DejaVu Sans"])
	font.font_weight = weight
	return font

static func box(color: Color, border: Color = LINE, width: int = 1, slant: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(0)
	style.skew = Vector2(slant, 0)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.anti_aliasing = true
	return style

## Glass button face: a thin outline, a gold edge on the leading side.
static func glass(color: Color, outline: Color) -> StyleBoxFlat:
	var style := box(color, outline, 1, SLANT)
	style.border_width_left = 3
	style.border_color = outline
	return style

## Slanted button face: a crimson edge on the leading side of dark glass.
static func blade(color: Color, edge: Color, edge_width: int = 4) -> StyleBoxFlat:
	var style := box(color, edge, 0, SLANT)
	style.border_width_left = edge_width
	return style

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = body_font()
	result.default_font_size = 15
	result.set_color("font_color", "Label", WHITE)
	result.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.75))
	result.set_constant("outline_size", "Label", 0)
	for type in ["Button", "OptionButton", "CheckBox"]:
		result.set_font("font", type, strong_font())
		result.set_stylebox("normal", type, glass(Color(0.04, 0.05, 0.09, 0.78), Color(1, 1, 1, 0.22)))
		result.set_stylebox("hover", type, glass(Color(GOLD, 0.2), GOLD))
		result.set_stylebox("pressed", type, glass(Color(GOLD, 0.34), GOLD))
		result.set_stylebox("focus", type, box(Color(0, 0, 0, 0), GOLD, 2, SLANT))
		result.set_stylebox("disabled", type, glass(Color(0.04, 0.05, 0.09, 0.5), Color(1, 1, 1, 0.08)))
		result.set_color("font_color", type, WHITE)
		result.set_color("font_hover_color", type, WHITE)
		result.set_color("font_focus_color", type, WHITE)
		result.set_color("font_pressed_color", type, WHITE)
		result.set_color("font_hover_pressed_color", type, WHITE)
		result.set_color("font_disabled_color", type, Color("9da5b6"))
		# Hovering a toggled control uses its own state; without a style it
		# fell back to a bare face with dark text.
		result.set_stylebox("hover_pressed", type, glass(Color(GOLD, 0.34), GOLD))
	# Checkboxes are toggles, not actions: keep their text readable in every
	# state and show "on" with a gold edge and gold text instead of a fill.
	result.set_stylebox("hover", "CheckBox", blade(Color(0.13, 0.14, 0.22, 0.95), GOLD, 6))
	result.set_stylebox("pressed", "CheckBox", blade(Color(0.09, 0.1, 0.16, 0.95), GOLD, 6))
	result.set_stylebox("hover_pressed", "CheckBox", blade(Color(0.13, 0.14, 0.22, 0.95), GOLD, 8))
	result.set_color("font_hover_color", "CheckBox", WHITE)
	result.set_color("font_pressed_color", "CheckBox", GOLD)
	result.set_color("font_hover_pressed_color", "CheckBox", GOLD)
	result.set_color("font_focus_color", "CheckBox", WHITE)
	result.set_stylebox("panel", "PopupMenu", box(Color("0d0f1a"), GOLD, 2))
	result.set_stylebox("hover", "PopupMenu", box(GOLD, GOLD, 0))
	result.set_color("font_color", "PopupMenu", WHITE)
	result.set_color("font_hover_color", "PopupMenu", INK)
	result.set_font("font", "PopupMenu", strong_font())
	result.set_stylebox("background", "ProgressBar", box(Color("202638"), Color("202638"), 0))
	result.set_stylebox("fill", "ProgressBar", box(GOLD, GOLD, 0))
	var track := box(Color("262a3d"), Color("262a3d"), 0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var active_track := box(GOLD, GOLD, 0)
	active_track.content_margin_top = 4
	active_track.content_margin_bottom = 4
	result.set_stylebox("slider", "HSlider", track)
	result.set_stylebox("grabber_area", "HSlider", active_track)
	result.set_stylebox("grabber_area_highlight", "HSlider", active_track)
	return result

## Smallest text drawn anywhere: the UI is laid out at 960x540, so 11 here
## is 22 pixels on a 1080p screen. Anything smaller was unreadable.
const MIN_TEXT := 11

static func label(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int = 16, color: Color = WHITE) -> Label:
	font_size = maxi(font_size, MIN_TEXT)
	var node := Label.new()
	node.text = text
	node.position = pos
	node.size = dimensions
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

## Big italic display text with a hard drop shadow, as on fighting-game
## title cards and character names.
static func heading(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int, color: Color = WHITE, shadow: Color = CRIMSON) -> Label:
	var node := label(parent, text, pos, dimensions, font_size, color)
	node.add_theme_font_override("font", display_font())
	node.add_theme_color_override("font_shadow_color", shadow)
	node.add_theme_constant_override("shadow_offset_x", 3)
	node.add_theme_constant_override("shadow_offset_y", 3)
	node.add_theme_color_override("font_outline_color", INK)
	node.add_theme_constant_override("outline_size", 4)
	return node

## Small spaced-out caption used above titles and option rows.
static func eyebrow(parent: Node, text: String, pos: Vector2, dimensions: Vector2, color: Color = GOLD) -> Label:
	# Latin is letter-spaced by hand; Devanagari never is, since spacing
	# breaks the headline that joins its letters.
	var shown := TranslationServer.translate(text)
	if not is_devanagari(shown):
		shown = " ".join(shown.split("")).replace("   ", "  ")
	var node := label(parent, shown, pos, dimensions, 11, color)
	node.add_theme_font_override("font", strong_font())
	return node

static func panel(parent: Node, pos: Vector2, dimensions: Vector2, color: Color = PANEL, border: Color = LINE, slant: float = 0.0) -> Panel:
	var node := Panel.new()
	node.position = pos
	node.size = dimensions
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", box(color, border, 1 if border.a > 0.0 else 0, slant))
	parent.add_child(node)
	return node

## Keyboard glyph chip: "[ENTER] CONFIRM".
static func key_hint(parent: Node, key: String, action: String, pos: Vector2) -> float:
	var chip := Label.new()
	chip.text = key
	chip.position = pos
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_font_override("font", strong_font())
	chip.add_theme_font_size_override("font_size", 11)
	chip.add_theme_color_override("font_color", INK)
	var face := box(WHITE, WHITE, 0)
	face.content_margin_left = 6
	face.content_margin_right = 6
	face.content_margin_top = 1
	face.content_margin_bottom = 1
	face.set_corner_radius_all(3)
	chip.add_theme_stylebox_override("normal", face)
	parent.add_child(chip)
	var width := chip.get_minimum_size().x
	var text := label(parent, action, pos + Vector2(width + 6, 0), Vector2(160, 18), 11, WHITE)
	text.add_theme_font_override("font", strong_font())
	return width + 12 + text.get_minimum_size().x + 16

static func button(parent: Node, text: String, pos: Vector2, dimensions: Vector2, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.position = pos
	node.size = dimensions
	node.pivot_offset = dimensions * 0.5
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(node)
	node.mouse_entered.connect(func():
		_pop(node, 1.045, 0.15)
		if not node.disabled:
			preload("res://scripts/sfx.gd").fire("menu_move", -8.0))
	node.pressed.connect(func(): preload("res://scripts/sfx.gd").fire("menu_confirm"))
	node.mouse_exited.connect(func(): _pop(node, 1.0, 0.18))
	node.button_down.connect(func(): _pop(node, 0.93, 0.06))
	node.button_up.connect(func(): _pop(node, 1.045 if node.is_hovered() else 1.0, 0.12))
	if primary:
		node.add_theme_stylebox_override("normal", glass(Color(CRIMSON, 0.9), Color(1, 1, 1, 0.55)))
		node.add_theme_stylebox_override("hover", glass(Color("e8344c"), GOLD))
		node.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), WHITE, 1, SLANT))
		node.add_theme_stylebox_override("pressed", glass(Color("a51b2e"), GOLD))
		node.add_theme_color_override("font_color", WHITE)
		node.add_theme_color_override("font_focus_color", WHITE)
		node.add_theme_color_override("font_hover_color", WHITE)
		node.add_theme_color_override("font_pressed_color", WHITE)
	return node

## Springy scale toward target_scale, replacing any pop still in flight on
## this control so rapid hover in/out doesn't fight itself.
static func _pop(node: Control, target_scale: float, duration: float) -> void:
	var existing: Tween = node.get_meta("_pop_tween") if node.has_meta("_pop_tween") else null
	if existing != null and existing.is_valid():
		existing.kill()
	# A hover/press signal can still fire after the button's scene has
	# already changed out from under it (e.g. a stray mouse_exited the
	# instant a menu button's scene unloads); create_tween() on a node
	# that's left the tree returns null instead of erroring, so guard it
	# explicitly rather than crashing one line down.
	if not node.is_inside_tree():
		return
	var tween := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE * target_scale, duration)
	node.set_meta("_pop_tween", tween)

## Slide in from the right with a fade, used for pages and modals alike.
static func enter(control: Control) -> void:
	var previous: Tween = control.get_meta("_enter_tween") if control.has_meta("_enter_tween") else null
	if previous != null and previous.is_valid():
		previous.kill()
	control.modulate.a = 0.0
	var target_position: Vector2 = control.get_meta("_enter_home", control.position)
	control.set_meta("_enter_home", target_position)
	control.position = target_position + Vector2(16, 0)
	var tween := control.create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.15)
	tween.tween_property(control, "position", target_position, 0.18)
	control.set_meta("_enter_tween", tween)
