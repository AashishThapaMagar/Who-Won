extends SceneTree
## Balance check: the computer plays the computer, every pairing from both
## sides, at one difficulty. Each bout runs a fixed stretch of fight time;
## a fighter who drops low is topped back up (and the knockdown counted), so
## every bout measures the whole stretch. Prints each fighter's damage dealt
## and taken, their damage ratio, and bouts won (out-damaging the rival).
##
##   godot --headless --fixed-fps 60 --path . -s res://tools/balance_sim.gd -- [seconds per bout] [difficulty] [rounds]
## (--fixed-fps runs the fight as fast as the machine allows)
const IDS := ["anug", "ish", "sab", "bib", "abhi", "sup", "anant"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[0]) if args.size() > 0 else 40.0
	var difficulty := int(args[1]) if args.size() > 1 else 2
	var rounds := int(args[2]) if args.size() > 2 else 1
	seed(20261020)
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = true
	root.get_node("MatchSetup").ai_difficulty = difficulty
	var arena: Node = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var p1: Node = arena.player1
	var p2: Node = arena.player2
	var mirror = load("res://scripts/ai_controller_3d.gd").new()
	mirror.fighter = p1
	mirror.opponent = p2
	p1.ai_controlled = true
	arena.add_child(mirror)
	var dealt := {}
	var taken := {}
	var wins := {}
	var bouts := {}
	var downs := {}
	var table := {}
	for id in IDS:
		dealt[id] = 0
		taken[id] = 0
		wins[id] = 0
		bouts[id] = 0
		downs[id] = 0
	for repeat in rounds:
		for a in IDS.size():
			for b in IDS.size():
				if a == b:
					continue
				p1.apply_character(a)
				p2.apply_character(b)
				arena._begin_round(0)
				arena.intro_timer = 0
				arena._hide_banner()
				var score := {IDS[a]: 0, IDS[b]: 0}
				var last := {p1: p1.health, p2: p2.health}
				var frames := int(seconds * 60.0)
				for frame in frames:
					await physics_frame
					arena.time_remaining = 99.0
					for fighter in [p1, p2]:
						var lost: int = int(last[fighter]) - int(fighter.health)
						if lost > 0:
							var other: Node = p2 if fighter == p1 else p1
							score[other.character_profile.id] += lost
							dealt[other.character_profile.id] += lost
							taken[fighter.character_profile.id] += lost
						if fighter.health < fighter.max_health * 0.3 or fighter.state == fighter.State.KO:
							downs[fighter.character_profile.id] += 1
							fighter.health = fighter.max_health
							if fighter.state == fighter.State.KO:
								arena._begin_round(0)
								arena.intro_timer = 0
								arena._hide_banner()
						last[fighter] = fighter.health
					last[p1] = p1.health
					last[p2] = p2.health
				var key := "%s vs %s" % [IDS[a], IDS[b]]
				table[key] = [score[IDS[a]], score[IDS[b]]]
				bouts[IDS[a]] += 1
				bouts[IDS[b]] += 1
				if score[IDS[a]] > score[IDS[b]]:
					wins[IDS[a]] += 1
				elif score[IDS[b]] > score[IDS[a]]:
					wins[IDS[b]] += 1
				print("  %-14s %4d - %-4d" % [key, score[IDS[a]], score[IDS[b]]])
	print("BALANCE (difficulty %d, %ds bouts):" % [difficulty, int(seconds)])
	var order := IDS.duplicate()
	order.sort_custom(func(x, y): return float(dealt[x]) / maxf(taken[x], 1.0) > float(dealt[y]) / maxf(taken[y], 1.0))
	for id in order:
		print("  %-6s won %2d/%-2d  dealt %5d  taken %5d  ratio %.2f  times dropped %d" % [id, wins[id], bouts[id], dealt[id], taken[id], float(dealt[id]) / maxf(taken[id], 1.0), downs[id]])
	quit()
