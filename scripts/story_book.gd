extends Control
## Story Mode as an old Nepali storybook: an open book on a desk, a drawn
## picture of the moment in a painted frame on the left page and the words
## on the right, set
## in a book face (Tiro Devanagari Hindi) with a Devanagari chapter heading
## and page numbers in Nepali numerals. A full page turns over to a fresh one.
##
## story_dialogue.gd still stages the scene, the camera and the lines; it
## hands this book each title card (chapter), each line, the typing progress
## of the line being shown, and calls draw_picture() once the actors
## have struck their pose. The picture is that one moment, drawn in ink and
## washes (storybook_look.gd) and kept still on the page: the 3D scene itself
## is never shown moving.

const UI := preload("res://scripts/ui_kit.gd")
const LOOK := preload("res://scripts/storybook_look.gd")
const SIZE := Vector2(960, 540)
## The open book on the desk, and the spine down its middle.
const BOOK := Rect2(22, 56, 916, 470)
const SPINE := 480.0
## The picture frame on the left page: a book plate, taller than the
## screen's 16:9 (the scene is rendered at this shape when drawn).
const PICTURE := Rect2(54, 92, 400, 300)
## The writing area of the right page.
const TEXT_LEFT := 512.0
const TEXT_WIDTH := 392.0
const ENTRIES_TOP := 170.0
const ENTRIES_BOTTOM := 462.0
## Entries kept on a page before it turns.
const MAX_ENTRIES := 3

const INK := Color("2e2118")
const INK_SOFT := Color("5a4636")
const VERMILION := Color("a3271c")
const OCHRE := Color("b07a2a")
const PAPER := Color("efe2c4")

const DEVANAGARI_DIGITS := ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]

const PAPER_SHADER := """shader_type canvas_item;
uniform vec3 paper : source_color = vec3(0.94, 0.88, 0.75);
// Which side the spine is on: -1 left edge, 1 right edge.
uniform float spine_side = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * vec2(460.0, 470.0);
	// Fibres and blotches of old paper.
	float fibre = noise(p * vec2(1.5, 6.0)) * 0.4 + noise(p * 0.3) * 0.3 + noise(p * 0.05) * 0.3;
	vec3 c = paper * (0.95 + 0.06 * fibre);
	// Foxing: a few faint, soft brown age spots.
	float blot = noise(p * 0.02 + 3.1) * 0.6 + noise(p * 0.07 + 9.7) * 0.4;
	float spot = smoothstep(0.7, 0.9, blot);
	c = mix(c, c * vec3(0.88, 0.8, 0.66), spot * 0.25);
	// Darker toward the outer edges, shadowed into the spine.
	float outer = spine_side > 0.0 ? UV.x : 1.0 - UV.x;
	float inner = 1.0 - outer;
	c *= mix(1.0, 0.72, pow(clamp(1.0 - inner * 9.0, 0.0, 1.0), 2.0));
	c *= mix(1.0, 0.88, pow(clamp(1.0 - outer * 14.0, 0.0, 1.0), 1.5));
	float edge_y = min(UV.y, 1.0 - UV.y);
	c *= mix(1.0, 0.9, pow(clamp(1.0 - edge_y * 18.0, 0.0, 1.0), 1.5));
	COLOR = vec4(c, 1.0);
}
"""

## The drawn picture on the page: colours soaked into the paper, its grain
## showing through, and edges that soften into the mat like a painting.
const PRINT_SHADER := """shader_type canvas_item;
uniform vec3 paper : source_color = vec3(0.94, 0.88, 0.75);
// 0 for a finished plate, which is already painted on paper.
uniform float strength = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), 0.18);
	c = mix(c, c * paper * 1.08, 0.35);
	c = mix(c, paper, 0.08);
	c *= 0.96 + 0.06 * hash(floor(UV * vec2(800.0, 450.0)));
	vec2 e = min(UV, 1.0 - UV) * vec2(4.0 / 3.0, 1.0);
	c = mix(paper * 0.8, c, smoothstep(0.0, 0.025, min(e.x, e.y)));
	COLOR = vec4(mix(texture(TEXTURE, UV).rgb, c, strength), 1.0);
}
"""

var picture: TextureRect
## The previous drawing, fading out under the new one.
var picture_back: TextureRect
var _drawing := false
var caption: Label
var heading_np: Label
var heading_en: Label
var page_number: Label
var entries: VBoxContainer
var leaf: ColorRect
## The entry being typed: its text label, revealed with the line's typing.
var _typing_label: Label
var _page := 1
var _accent := VERMILION

func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

## Shows the line's baked plate straight away, if it has one.
func show_plate(path: String) -> bool:
	var baked := _load_plate(path)
	if baked == null:
		return false
	_lay(baked, true)
	return true

## Lays this moment's picture on the page: its baked plate when there is
## one (assets/story/<fighter>/plates/, see tools/bake_story_plates.gd),
## otherwise the scene as it stands now, drawn on the spot: the models are
## repainted in ink and washes first (once each), then one frame is
## rendered and kept.
func draw_picture(viewport: SubViewport, plate := "") -> void:
	if not is_inside_tree():
		return
	var baked := _load_plate(plate)
	if baked != null:
		_lay(baked, true)
		return
	if _drawing:
		return
	_drawing = true
	var plate_size := Vector2i(PICTURE.size * 2.0)
	if viewport.size != plate_size:
		viewport.size = plate_size
	LOOK.apply(viewport)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_drawing = false
	if not is_inside_tree():
		return
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return
	# Nothing on the page moves until the next drawing.
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_lay(ImageTexture.create_from_image(image), false)

## Fades a new picture in over the last one.
func _lay(drawing: Texture2D, finished: bool) -> void:
	if drawing == picture.texture:
		return
	picture_back.texture = picture.texture
	(picture_back.material as ShaderMaterial).set_shader_parameter("strength", (picture.material as ShaderMaterial).get_shader_parameter("strength"))
	picture_back.modulate.a = 1.0
	picture.texture = drawing
	(picture.material as ShaderMaterial).set_shader_parameter("strength", 0.0 if finished else 1.0)
	picture.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(picture, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	fade.parallel().tween_property(picture_back, "modulate:a", 0.0, 0.6)

func _build() -> void:
	# The desk the book lies on.
	var desk := ColorRect.new()
	desk.color = Color("2a1a12")
	desk.size = SIZE
	desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(desk)
	# The cover peeking out around the pages, and its shadow on the desk.
	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.45)
	shadow.position = BOOK.position + Vector2(6, 10)
	shadow.size = BOOK.size
	add_child(shadow)
	var cover := ColorRect.new()
	cover.color = Color("6b1f17")
	cover.position = BOOK.position - Vector2(8, 8)
	cover.size = BOOK.size + Vector2(16, 16)
	add_child(cover)
	for side in [-1.0, 1.0]:
		var page := ColorRect.new()
		page.position = Vector2(BOOK.position.x if side < 0 else SPINE, BOOK.position.y)
		page.size = Vector2(SPINE - BOOK.position.x if side < 0 else BOOK.end.x - SPINE, BOOK.size.y)
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var paper := ShaderMaterial.new()
		paper.shader = Shader.new()
		paper.shader.code = PAPER_SHADER
		paper.set_shader_parameter("spine_side", -side)
		page.material = paper
		add_child(page)
	add_child(_Stitches.new())
	# Left page: the picture in a painted double frame, a caption, and a
	# border of dhaka-cloth diamonds.
	var frame := Panel.new()
	frame.position = PICTURE.position - Vector2(10, 10)
	frame.size = PICTURE.size + Vector2(20, 20)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("e8d6ae")
	frame_style.border_color = VERMILION
	frame_style.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var inner := Panel.new()
	inner.position = PICTURE.position - Vector2(4, 4)
	inner.size = PICTURE.size + Vector2(8, 8)
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color.TRANSPARENT
	inner_style.border_color = OCHRE
	inner_style.set_border_width_all(1)
	inner.add_theme_stylebox_override("panel", inner_style)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inner)
	var print_shader := Shader.new()
	print_shader.code = PRINT_SHADER
	for i in 2:
		var print_look := ShaderMaterial.new()
		print_look.shader = print_shader
		var rect := TextureRect.new()
		rect.position = PICTURE.position
		rect.size = PICTURE.size
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = print_look
		add_child(rect)
		if i == 0:
			picture_back = rect
		else:
			picture = rect
	caption = _label("", Vector2(PICTURE.position.x, PICTURE.end.y + 16), Vector2(PICTURE.size.x, 22), 15, INK_SOFT, true)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var band := _Dhaka.new()
	band.position = Vector2(PICTURE.position.x, PICTURE.end.y + 46)
	band.size = Vector2(PICTURE.size.x, 18)
	add_child(band)
	var motto := _label("॥ कथा ॥", Vector2(PICTURE.position.x, BOOK.end.y - 48), Vector2(PICTURE.size.x, 34), 20, OCHRE)
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	motto.add_theme_font_override("font", UI.devanagari_font())
	# Right page: the chapter heading, a rule, the entries, the page number.
	heading_np = _label("", Vector2(TEXT_LEFT, 82), Vector2(TEXT_WIDTH, 44), 30, VERMILION)
	heading_np.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_np.add_theme_font_override("font", UI.devanagari_font())
	heading_en = _label("", Vector2(TEXT_LEFT, 126), Vector2(TEXT_WIDTH, 18), 11, INK_SOFT)
	heading_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_en.add_theme_font_override("font", UI.strong_font())
	var rule := _Rule.new()
	rule.position = Vector2(TEXT_LEFT + 96, 150)
	rule.size = Vector2(TEXT_WIDTH - 192, 8)
	add_child(rule)
	entries = VBoxContainer.new()
	entries.position = Vector2(TEXT_LEFT, ENTRIES_TOP)
	entries.size = Vector2(TEXT_WIDTH, ENTRIES_BOTTOM - ENTRIES_TOP)
	entries.add_theme_constant_override("separation", 12)
	entries.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(entries)
	page_number = _label("", Vector2(TEXT_LEFT, BOOK.end.y - 40), Vector2(TEXT_WIDTH, 24), 16, INK_SOFT)
	page_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_page()
	# The leaf that folds over toward the spine when a page turns.
	leaf = ColorRect.new()
	leaf.color = PAPER
	leaf.position = Vector2(SPINE, BOOK.position.y)
	leaf.size = Vector2(BOOK.end.x - SPINE, BOOK.size.y)
	leaf.pivot_offset = Vector2(0, BOOK.size.y * 0.5)
	leaf.visible = false
	leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(leaf)

static var _plates := {}
## A baked plate, imported or dropped in as a plain image (a hand-painted
## version replaces the file and shows as it is).
static func _load_plate(path: String) -> Texture2D:
	if path == "":
		return null
	if _plates.has(path):
		return _plates[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path)
	elif FileAccess.file_exists(path):
		texture = ImageTexture.create_from_image(Image.load_from_file(path))
	_plates[path] = texture
	return texture

func _label(text: String, pos: Vector2, dimensions: Vector2, font_size: int, colour: Color, italic := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_override("font", _book_font(italic))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

static var _fonts := {}
static func _book_font(italic := false) -> Font:
	var path := "res://assets/fonts/TiroDevanagariHindi-%s.ttf" % ("Italic" if italic else "Regular")
	if not _fonts.has(path):
		if ResourceLoader.exists(path):
			_fonts[path] = load(path)
		else:
			var file := FontFile.new()
			file.load_dynamic_font(path)
			_fonts[path] = file
	return _fonts[path]

## A title card becomes the right page's chapter heading on a fresh page.
func chapter(eyebrow: String, title: String, subtitle: String, accent: Color) -> void:
	_accent = accent.darkened(0.35) if accent != Color.WHITE else VERMILION
	heading_np.text = _in_nepali(eyebrow)
	heading_en.text = "  ".join((eyebrow + "  ·  " + title).split(" "))
	caption.text = subtitle.capitalize() if subtitle != "" else title.capitalize()
	_turn_page()

## A new line written on the right page: speech as a quotation signed by
## its speaker, narration as a plain paragraph. Revealed by reveal().
func line(speaker: String, text: String, tint: Color) -> void:
	if entries.get_child_count() >= MAX_ENTRIES or _overfull(text):
		_turn_page()
	# The line before is written out in full (it may have been skipped while
	# still typing), and earlier entries fade back so the new one leads.
	if is_instance_valid(_typing_label):
		_typing_label.visible_ratio = 1.0
	for old in entries.get_children():
		old.modulate.a = 0.55
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entries.add_child(entry)
	var body := Label.new()
	body.text = ("“%s”" % text) if speaker != "" else text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	body.add_theme_font_override("font", _book_font(speaker == ""))
	body.add_theme_font_size_override("font_size", 19 if speaker != "" else 17)
	body.add_theme_color_override("font_color", INK if speaker != "" else INK_SOFT)
	body.add_theme_constant_override("line_spacing", 2)
	body.visible_ratio = 0.0
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(body)
	if speaker != "":
		var sign := Label.new()
		sign.text = "— " + speaker.replace(" ", "")
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sign.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
		sign.add_theme_font_override("font", UI.strong_font())
		sign.add_theme_font_size_override("font_size", 12)
		sign.add_theme_color_override("font_color", Color(tint.darkened(0.55), 1.0))
		sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(sign)
	_typing_label = body

## How much of the newest line is written (follows the line's typing).
func reveal(ratio: float) -> void:
	if is_instance_valid(_typing_label):
		_typing_label.visible_ratio = ratio

## Would this text spill past the bottom of the page?
func _overfull(text: String) -> bool:
	var font := _book_font()
	var lines_needed := ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x / TEXT_WIDTH) + 1.0
	var used := 0.0
	for entry in entries.get_children():
		used += entry.size.y + 12.0
	return used + lines_needed * 28.0 > ENTRIES_BOTTOM - ENTRIES_TOP

## Turns to a fresh right page: the full leaf folds over to the spine.
func _turn_page() -> void:
	if entries.get_child_count() == 0:
		return
	preload("res://scripts/sfx.gd").fire("menu_move", -10.0)
	for old in entries.get_children():
		old.queue_free()
	_page += 1
	_number_page()
	leaf.visible = true
	leaf.scale = Vector2.ONE
	leaf.color = PAPER
	var turn := create_tween()
	turn.tween_property(leaf, "scale:x", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	turn.parallel().tween_property(leaf, "color", PAPER.darkened(0.3), 0.45)
	turn.tween_callback(func(): leaf.visible = false)

func _number_page() -> void:
	page_number.text = "॥ %s ॥" % _nepali_digits(_page)

static func _nepali_digits(value: int) -> String:
	var out := ""
	for ch in str(value):
		out += DEVANAGARI_DIGITS[int(ch)]
	return out

## The Devanagari heading for a title card's eyebrow.
static func _in_nepali(eyebrow: String) -> String:
	var words := {"PROLOGUE": "प्रस्तावना", "FINALE": "अन्त्य", "FINAL CHAPTER": "अन्तिम अध्याय",
		"CHAPTER CLEARED": "विजय", "OPEN TOURNAMENT": "खुला प्रतियोगिता"}
	if words.has(eyebrow):
		return words[eyebrow]
	if eyebrow.begins_with("CHAPTER"):
		var number := eyebrow.trim_prefix("CHAPTER").strip_edges()
		var named := {"ONE": 1, "TWO": 2, "THREE": 3, "FOUR": 4, "FIVE": 5, "SIX": 6, "SEVEN": 7}
		var n := int(named.get(number, int(number)))
		return "अध्याय " + _nepali_digits(n) if n > 0 else "अध्याय"
	return "कथा"

## Stitches down the spine.
class _Stitches extends Control:
	func _ready() -> void:
		position = Vector2(SPINE - 1, BOOK.position.y)
		size = Vector2(2, BOOK.size.y)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var y := 14.0
		while y < size.y - 14.0:
			draw_line(Vector2(1, y), Vector2(1, y + 9), Color("7a5a3a"), 1.5)
			y += 18.0

## A short ornamental rule with a diamond in the middle.
class _Rule extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var mid := size * 0.5
		draw_line(Vector2(0, mid.y), Vector2(mid.x - 9, mid.y), OCHRE, 1.0)
		draw_line(Vector2(mid.x + 9, mid.y), Vector2(size.x, mid.y), OCHRE, 1.0)
		draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -4), mid + Vector2(5, 0), mid + Vector2(0, 4), mid + Vector2(-5, 0)]), VERMILION)

## A band of dhaka-cloth diamonds in red and ochre.
class _Dhaka extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var h := size.y
		var x := 0.0
		var i := 0
		draw_line(Vector2(0, 0), Vector2(size.x, 0), OCHRE, 1.0)
		draw_line(Vector2(0, h), Vector2(size.x, h), OCHRE, 1.0)
		while x + h <= size.x:
			var c := Vector2(x + h * 0.5, h * 0.5)
			var r := h * 0.42
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), VERMILION if i % 2 == 0 else OCHRE)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.4), c + Vector2(r * 0.4, 0), c + Vector2(0, r * 0.4), c + Vector2(-r * 0.4, 0)]), PAPER)
			x += h
			i += 1
