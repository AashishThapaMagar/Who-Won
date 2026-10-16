extends SceneTree
## Writes every Story Mode line with the name the game plays its narration
## under (story_dialogue.gd _line_key: <beat>_<NN>, e.g. prologue_03,
## bib_intro_01, finale_06), per fighter, as JSON. tools/narrate_story.py
## records the narration from it.
##
##   godot --headless --path . -s res://tools/export_story_lines.gd -- out.json
const STORY := preload("res://scripts/story_script.gd")

func _initialize() -> void:
	var out := {}
	for id: String in STORY.ROUTES:
		var route: Dictionary = STORY.ROUTES[id]
		var lines: Array = []
		_add(lines, "prologue", route.get("prologue", []))
		for rival: String in route.get("ladder", route.get("chapters", {}).keys()):
			# The beats as the game plays them: shared, with the route's own
			# over the top (story_director.gd chapter()).
			var beats: Dictionary = STORY.CHAPTERS.get(rival, {}).duplicate()
			beats.merge(route.get("chapters", {}).get(rival, {}), true)
			for beat in ["intro", "victory", "defeat"]:
				_add(lines, "%s_%s" % [rival, beat], beats.get(beat, []))
		_add(lines, "finale", route.get("finale", []))
		out[id] = lines
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if not args.is_empty() else "user://story_lines.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "  "))
	file.close()
	print("wrote ", path)
	quit()

func _add(lines: Array, beat: String, beat_lines: Array) -> void:
	for i in beat_lines.size():
		var line: Dictionary = beat_lines[i]
		lines.append({"key": "%s_%02d" % [beat, i + 1], "speaker": line.get("speaker", ""), "text": line.get("text", "")})
