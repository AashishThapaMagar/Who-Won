extends SceneTree
## Run with: godot --headless --path . -s res://tests/super_test.gd
## Supers: the meter fills from damage dealt and taken; 2 + 4 with a full
## meter throws the opener; a clean hit plays every blow and launches the
## rival; guarded or whiffed, the meter is spent and nothing more happens;
## fighters without a super never get one.
var arena: Node
var p1: Node
var p2: Node
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

func reset(gap := 0.8) -> void:
	for action in ["rpunch", "rkick", "block"]:
		Input.action_release("p1_3d_" + action)
		Input.action_release("p2_3d_" + action)
	arena._begin_round(0)
	arena.intro_timer = 0
	arena._hide_banner()
	p1.body.position = Vector3(-gap * 0.5, 0.02, 0)
	p2.body.position = Vector3(gap * 0.5, 0.02, 0)
	await frames(6)

func press_super() -> void:
	Input.action_press("p1_3d_rpunch")
	Input.action_press("p1_3d_rkick")
	await frames(2)
	Input.action_release("p1_3d_rpunch")
	Input.action_release("p1_3d_rkick")

func run() -> void:
	root.get_node("Settings").touch_controls = false
	root.get_node("MatchSetup").vs_ai = false
	arena = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	p1 = arena.player1
	p2 = arena.player2
	for pair in [[1, 6], [6, 1]]:
		p1.apply_character(pair[0])
		p2.apply_character(pair[1])
		var who: String = p1.character_profile.id
		var data: Dictionary = p1.SUPERS.get_super(who)
		# The meter fills from both sides of a hit.
		await reset()
		p2.take_hit(10, 100, 1, p1, "punch")
		check(p1.super_meter > p2.super_meter and p2.super_meter > 0.0, "%s: dealing and taking damage both build meter" % who)
		# Not full: 2 + 4 does nothing special.
		await reset()
		p1.super_meter = 50.0
		await press_super()
		check(p1.state != p1.State.SUPER and p1.attack_variant != "super", "%s: a half meter can't super" % who)
		# Full meter, clean hit: every blow lands and the rival is launched.
		await reset()
		p1.super_meter = 100.0
		var health: int = p2.health
		await press_super()
		var entered := false
		var hits := 0
		for frame in 400:
			await frames(1)
			if p1.state == p1.State.SUPER:
				entered = true
				check(p2.state in [p2.State.STRUCK, p2.State.HITSTUN, p2.State.KO], "%s: the rival is locked in the super" % who)
			hits = maxi(hits, p1.super_hits)
			if entered and p1.state == p1.State.IDLE:
				break
		var total := 0
		for d in data.damage:
			total += d
		check(entered and hits == data.hits.size(), "%s: the super plays all %d blows (played %d)" % [who, data.hits.size(), hits])
		check(health - p2.health == total, "%s: the super deals %d (dealt %d)" % [who, total, health - p2.health])
		check(p1.super_meter < 10.0, "%s: the super spends the meter" % who)
		check(p1.body.position.distance_to(p2.body.position) > 1.0, "%s: the last blow launches the rival" % who)
		check(p1.state == p1.State.IDLE and p2.state in [p2.State.HITSTUN, p2.State.IDLE, p2.State.KO], "%s: both fighters come out of the super" % who)
		# Guarded: meter gone, no super.
		await reset()
		p1.super_meter = 100.0
		Input.action_press("p2_3d_block")
		await frames(4)
		health = p2.health
		await press_super()
		for frame in 60:
			await frames(1)
		Input.action_release("p2_3d_block")
		check(p1.state != p1.State.SUPER and p1.super_meter < 10.0 and health - p2.health < 5, "%s: a guarded opener spends the meter and plays nothing" % who)
		# Whiffed from too far: same.
		await reset(2.4)
		p1.super_meter = 100.0
		await press_super()
		for frame in 60:
			await frames(1)
		check(p1.state != p1.State.SUPER and p1.super_meter < 10.0, "%s: a whiffed opener spends the meter" % who)
	# A fighter without a super never gets one, however full the meter.
	p1.apply_character(0)
	await reset()
	check(not p1.has_super(), "Anug has no super")
	p1.super_meter = 100.0
	await press_super()
	await frames(20)
	check(p1.state != p1.State.SUPER and p1.attack_variant != "super", "2 + 4 is not a super for a fighter without one")
	print("SUPER_TEST: ", "ALL PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
