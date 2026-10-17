extends SceneTree
## Prints which animation each fighter gets for every logical move, and
## where it comes from (shared, style, pack, low kit, Meshy/Tripo), so gaps
## in the roster's animation coverage show at a glance.
##
##   godot --headless --path . -s res://tools/audit_fighter_clips.gd
const MODELS := preload("res://scripts/fighter_models.gd")
const IDS := ["anug", "ish", "sab", "bib", "abhi", "sup", "anant"]
const LOGICAL := ["idle", "walk", "walk_back", "sidestep_left", "sidestep_right", "run", "dash", "backdash",
	"jump", "land", "crouch", "block", "block_hit", "jab", "cross", "hook", "punch_heavy", "uppercut",
	"kick", "kick_front", "kick_spin", "strike_sweep", "grapple", "thrown", "getup", "finisher", "taunt",
	"victory", "hit", "hit_heavy", "hit_head", "hit_head_heavy", "hit_body", "hit_body_alt", "hit_side",
	"hit_liver", "ko", "injured"]

func _initialize() -> void:
	var table := {}
	for id in IDS:
		table[id] = MODELS.entry(id)
	var header := "%-15s" % "move"
	for id in IDS:
		header += "%-22s" % id
	print(header)
	for logical in LOGICAL:
		var row := "%-15s" % logical
		for id in IDS:
			var config: Dictionary = table[id]
			var clip: String = config.get("clips", {}).get(logical, "")
			var source := "-"
			if clip != "":
				var file: String = config.get("files", {}).get(clip, "")
				source = file.get_file().get_basename() if file != "" else clip
				if clip.begins_with("meshy_"):
					source = "meshy:" + logical
			row += "%-22s" % source.left(21)
		print(row)
	quit()
