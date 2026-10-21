extends SceneTree
## Checks every fighter's clips against Fighting Animset Pro: each clip a
## fighter needs is in the pack file fighter_models.gd says holds it, and no
## strike is shared between two fighters. Prints each fighter's stance and
## moves.
##
##   godot --headless --path . -s res://tools/audit_fighter_clips.gd
const MODELS := preload("res://scripts/fighter_models.gd")
const MOVES := preload("res://scripts/action_moves.gd")
const IDS := ["ish", "sab", "bib", "abhi", "anug", "sup", "anant"]

func _initialize() -> void:
	var names := {}
	var problems := 0
	var owner := {}
	for id in IDS:
		var config := MODELS.entry(id)
		if config.is_empty():
			print("%s: no config (pack or skeleton missing)" % id)
			problems += 1
			continue
		var count := 0
		for file in config.pack:
			if not names.has(file):
				var scene: Node = (load(file) as PackedScene).instantiate()
				names[file] = Array(scene.find_children("*", "AnimationPlayer", true, false)[0].get_animation_list())
				scene.free()
			for logical in config.pack[file]:
				count += 1
				var clip: String = config.pack[file][logical]
				if not clip in names[file]:
					print("%s: %s -> %s not in %s" % [id, logical, clip, file.get_file()])
					problems += 1
		var moves: Dictionary = MOVES.for_fighter(id)
		var line := []
		for slot in moves:
			var clip := str(moves[slot].get("clip", ""))
			if clip == "" or clip in MODELS.AIR:
				continue
			line.append("%s=%s" % [slot, clip.trim_prefix("KB_")])
			if owner.has(clip) and owner[clip] != id:
				print("%s and %s share %s" % [owner[clip], id, clip])
				problems += 1
			owner[clip] = id
		print("%-6s %d clips  stance %s  ko %s\n       %s" % [id, count, MODELS.STANCES[id].idle, MODELS.STANCES[id].ko, ", ".join(line)])
	print("PROBLEMS: %d" % problems)
	quit()
