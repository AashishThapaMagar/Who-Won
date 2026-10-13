extends SceneTree
## Nepali / English: every Nepali line exists, keeps the English line's
## placeholders in order, and switching language reaches the labels.
const NEPALI := preload("res://scripts/lang_ne.gd")
const NEPALI_STORY := preload("res://scripts/lang_story_ne.gd")
const STORY := preload("res://scripts/story_script.gd")
## Books translated so far: every line in them must have its Nepali.
const TRANSLATED_BOOKS := ["ish", "sab", "bib", "abhi", "anug"]
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)

func _placeholders(text: String) -> Array:
	var found := []
	var regex := RegEx.create_from_string("%[0-9]*[ds%]")
	for m in regex.search_all(text):
		found.append(m.get_string())
	return found

func _run() -> void:
	await process_frame
	var settings: Node = root.get_node("Settings")
	var keep: String = settings.language
	for strings: Dictionary in [NEPALI.STRINGS, NEPALI_STORY.STRINGS]:
		for key: String in strings:
			var line: String = strings[key]
			_check(not line.strip_edges().is_empty(), "empty Nepali for %s" % key)
			_check(_placeholders(key) == _placeholders(line), "placeholders differ: %s" % key)
	for id: String in TRANSLATED_BOOKS:
		var route: Dictionary = STORY.ROUTES[id]
		var lines: Array = route.prologue + route.finale
		for rival: String in route.chapters:
			for beat: String in route.chapters[rival]:
				lines += route.chapters[rival][beat]
		for line: Dictionary in lines:
			_check(NEPALI_STORY.STRINGS.has(line.text), "%s book untranslated: %s" % [id, line.text])
			if line.has("banner"):
				for part: String in ["eyebrow", "title", "subtitle"]:
					var words: String = line.banner.get(part, "")
					_check(words.is_empty() or NEPALI_STORY.STRINGS.has(words) or NEPALI.STRINGS.has(words), "%s banner untranslated: %s" % [id, words])
		for part: String in ["title", "subtitle", "finale_title"]:
			_check(NEPALI_STORY.STRINGS.has(route[part]), "%s %s untranslated" % [id, part])
	settings.language = "ne"
	TranslationServer.set_locale("ne")
	_check(TranslationServer.translate("SETTINGS") == "सेटिङ", "Settings translates")
	_check(settings.fmt("ROUND %d", [2]) == "राउन्ड २", "numbers in Devanagari")
	var label := Label.new()
	label.text = "PRACTICE"
	root.add_child(label)
	await process_frame
	_check(label.get_text() == "PRACTICE", "label keeps its English key")
	settings.language = "en"
	TranslationServer.set_locale("en")
	_check(settings.fmt("ROUND %d", [2]) == "ROUND 2", "English stays English")
	settings.language = keep
	TranslationServer.set_locale(keep)
	print("LANGUAGE_TEST: ", "ALL PASS" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)
