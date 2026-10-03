extends SceneTree
## Run with: godot --headless --path . -s res://tests/clip_cache_test.gd
## A fighter's clip set loaded from the cache (memory or disk) must play
## exactly like a freshly built one: same clips, paces and impact timings.
const ANIMATED := preload("res://scripts/fighter_animated.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func snapshot(fighter: Node) -> Dictionary:
	var animated = fighter.get_node("Visual").animated
	var lengths := {}
	for logical in animated.clip_names:
		var animation: Animation = animated.player.get_animation(animated.clip_names[logical])
		lengths[logical] = snappedf(animation.length, 0.001) if animation != null else -1.0
	return {"clips": animated.clip_names.duplicate(), "lengths": lengths,
		"pace": animated.clip_pace.duplicate(), "timing": animated.config.get("timing", {}).duplicate(true)}

func run() -> void:
	root.get_node("Settings").touch_controls = false
	var arena = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await frames(3)
	var fighter = arena.player1
	if not fighter.get_node("Visual").animated.active:
		print("CLIP_CACHE_TEST: SKIPPED (no fighter clips on this machine)")
		quit(0)
		return
	for index in [1, 0, 4]:
		# Fresh build: empty the session cache and remove the saved copies.
		ANIMATED._clip_cache.clear()
		for file in DirAccess.get_files_at(ANIMATED.CLIP_CACHE_DIR):
			DirAccess.remove_absolute(ANIMATED.CLIP_CACHE_DIR + file)
		fighter.apply_character((index + 1) % 7)
		fighter.apply_character(index)
		var fresh := snapshot(fighter)
		check(not DirAccess.get_files_at(ANIMATED.CLIP_CACHE_DIR).is_empty(), "Fighter %d clip set is saved to disk" % index)
		# From memory.
		fighter.apply_character((index + 1) % 7)
		fighter.apply_character(index)
		check(snapshot(fighter) == fresh, "Fighter %d clip set from memory matches a fresh build" % index)
		# From disk, as on the next launch.
		ANIMATED._clip_cache.clear()
		fighter.apply_character((index + 1) % 7)
		fighter.apply_character(index)
		check(snapshot(fighter) == fresh, "Fighter %d clip set from disk matches a fresh build" % index)
	print("CLIP_CACHE_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
