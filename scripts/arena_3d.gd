extends "res://scripts/arena.gd"
## Canvas HUD and shared round rules around one real 3D world.
var world: Node3D
var camera_3d: Camera3D
## The arena this match is in (nepal_stage_3d ROUNDS index).
var stage_index := -1
var camera_target := Vector3(0, CAMERA_HEIGHT, 0)
var camera_distance := CAMERA_CLOSE
var camera_zoom_hold := 0.0
## Tekken/Street Fighter framing: a low, nearly level camera at chest height
## that keeps the fighters large, turns to stay square-on to their fighting
## line, and sweeps in from the side while the round is announced.
const CAMERA_BACK := Vector3(0, 0.07, 0.9975)
const CAMERA_HEIGHT := 1.05
const CAMERA_CLOSE := 4.9
const CAMERA_FOV := 38.0
## Furthest the fight camera turns (radians, ~25 degrees) to follow a
## sidestep. The arenas are built to be seen from the front; turned further
## the view ran off the end of the scenery into empty ground. Past this the
## fighters are simply seen at an angle.
const CAMERA_MAX_TURN := 0.44
var camera_yaw := 0.0
## Short-lived hit effects: {mesh, age, life, update: Callable}.
var impact_meshes: Array[Dictionary] = []
## Ask for a jolt by raising this (metres, old scale); it feeds `trauma`.
var shake_3d := 0.0
## Camera trauma 0..1: the shake is its square, so a jab barely stirs the
## lens and a heavy blow knocks it about, both fading out smoothly.
var trauma := 0.0
var _cam_time := 0.0
var _cam_noise := FastNoiseLite.new()
## Metres the lens is shoved along a heavy blow; eases back to rest.
var camera_nudge := Vector3.ZERO
## The super cinematic: who is performing it, and how far the camera has
## swung into its close-up (0 = fight camera, 1 = full close-up).
var super_fighter: Node = null
var cinematic := 0.0
## The knockout shot: the fallen fighter, and until when (real milliseconds,
## since the fall plays in slow motion) the camera holds low on the fall.
var ko_fighter: Node = null
var ko_until := 0
var fov_kick := 0.0
## Lens push-in held through a knockout (field-of-view degrees, eased).
var ko_push := 0.0
var ko_hold := 0.0
## Dash and heavy-attack afterimages, per fighter: {mesh, age, life}.
var ghosts: Array[Dictionary] = []
var ghost_clock: Array[float] = [0.0, 0.0]
var last_states: Array[int] = [-1, -1]
var contact_shadows: Array[MeshInstance3D] = []
const UI_KIT := preload("res://scripts/ui_kit.gd")
const RING_SHADER := preload("res://scripts/impact_ring.gdshader")
const CONTACT_SHADOW := preload("res://scripts/contact_shadow.gdshader")
## Motion-trail tint per player: barely tinted so trails read as blur.
const TEAM_COLORS := [Color("cfdcef"), Color("efd6cf")]
var nepal_stage: Node3D
## Arena every round uses when a versus mode picked one; -1 plays the journey.
var fixed_stage := -1
## Plays the last seconds back after a knockout (see ko_replay.gd); null
## where there is no replay (headless runs, practice).
var ko_replay: Node = null
var replay_enabled := true

func _enter_tree() -> void:
	world = Node3D.new()
	world.name = "World3D"
	# Physics interpolation smooths the 60 Hz fighter bodies on any refresh
	# rate. Only the bodies (and the rig pivots they turn) are interpolated;
	# the camera, scenery, effects and the pose-driven rig parts all move in
	# _process and would lag a tick behind if they were.
	world.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(world)
	_build_stage()
	for i in 2:
		var fighter: Node = get_node("Player%d" % (i + 1))
		var body := CharacterBody3D.new()
		body.name = "Fighter%d" % (i + 1)
		body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		body.collision_layer = 8
		body.collision_mask = 1
		body.floor_snap_length = 0.15
		body.safe_margin = 0.002
		world.add_child(body)
		var collider := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.30
		capsule.height = 1.7
		collider.shape = capsule
		collider.position.y = 0.85
		body.add_child(collider)
		var hurt := Area3D.new()
		hurt.name = "Hurtbox3D"
		hurt.collision_layer = 2
		hurt.collision_mask = 0
		hurt.monitoring = false
		hurt.set_meta("fighter", fighter)
		body.add_child(hurt)
		var hurt_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.66, 1.78, 0.56)
		hurt_shape.shape = box
		hurt_shape.position.y = 0.89
		hurt.add_child(hurt_shape)
		var pivot := Node3D.new()
		pivot.name = "Rig"
		pivot.scale = Vector3.ONE / 64.0
		body.add_child(pivot)
		fighter.body = body
		fighter.pivot = pivot
		fighter.spawn_position = Vector3(-1.3 if i == 0 else 1.3, 0.02, 0)
		body.position = fighter.spawn_position
		fighter.get_node("Visual").world_root = pivot

func _ready() -> void:
	player1.opponent = player2
	player2.opponent = player1
	player1.apply_character(MatchSetup.selected_fighters[0])
	player2.apply_character(MatchSetup.selected_fighters[1])
	$UI/P1Label.text = "P1 / " + player1.character_profile.name
	$UI/P2Label.text = "P2 / " + player2.character_profile.name + (" / AI" if MatchSetup.vs_ai else "")
	p1_start_pos = player1.position
	p2_start_pos = player2.position
	if MatchSetup.vs_ai:
		player2.ai_controlled = true
		ai_controller = preload("res://scripts/ai_controller_3d.gd").new()
		ai_controller.fighter = player2
		ai_controller.opponent = player1
		add_child(ai_controller)
	var hit_detection := preload("res://scripts/hit_detection_3d.gd").new()
	hit_detection.fighters = [player1, player2]
	world.add_child(hit_detection)
	# Round manager calls reset() on this shared effects interface.
	combat_effects = preload("res://scripts/combat_effects.gd").new()
	combat_effects.visible = false
	combat_effects.set_process(false)
	add_child(combat_effects)
	for fighter in [player1, player2]:
		fighter.impact.connect(func(_point: Vector2, blocked: bool, heavy: bool): _impact_3d(fighter, blocked, heavy))
		fighter.wall_hit.connect(_wall_impact)
		fighter.super_started.connect(_super_cinematic.bind(fighter))
	health_bar1.max_value = player1.max_health
	health_bar2.max_value = player2.max_health
	player1.health_changed.connect(func(h, _mh): health_bar1.value = h)
	player2.health_changed.connect(func(h, _mh): health_bar2.value = h)
	player1.ko.connect(func(): _end_round(2))
	player2.ko.connect(func(): _end_round(1))
	for fighter in [player1, player2]:
		fighter.ko.connect(func(): preload("res://scripts/sfx.gd").fire("ko"))
		fighter.ko.connect(_ko_3d.bind(fighter))
	_contact_shadows()
	_build_burst_pool()
	if replay_enabled and DisplayServer.get_name() != "headless":
		ko_replay = preload("res://scripts/ko_replay.gd").new()
		ko_replay.arena = self
		# Bake the replay's film look now; building it at the knockout froze
		# the frame for a moment.
		var film: Dictionary = ko_replay.FILM_GRADE
		nepal_stage._grade_lut([film.shadow_tint, film.highlight_tint, film.saturation, film.contrast])
		add_child(ko_replay)
	_build_move_ui()
	add_child(preload("res://scripts/match_hud.gd").new())
	if Settings.touch_controls:
		add_child(preload("res://scripts/touch_controls_3d.gd").new())
	result_label.visible = false
	_update_pips()
	fixed_stage = _resolve_stage()
	_begin_round(0)

## The versus arena choice as a concrete arena index, or -1 for the journey.
func _resolve_stage() -> int:
	if MatchSetup.arcade or MatchSetup.stage_choice == MatchSetup.JOURNEY_STAGE:
		return -1
	if MatchSetup.stage_choice == MatchSetup.RANDOM_STAGE:
		return randi() % nepal_stage.ROUNDS.size()
	return clampi(MatchSetup.stage_choice, 0, nepal_stage.ROUNDS.size() - 1)

func _begin_round(index: int) -> void:
	# One arena for the whole match; the journey moves on after a won match.
	var stage: int = fixed_stage if fixed_stage >= 0 else MatchSetup.journey_stage % nepal_stage.ROUNDS.size()
	stage_index = stage
	nepal_stage.show_round(stage)
	super._begin_round(index)
	# One short comment under the round call: where the fight is, plus the
	# arcade ladder position when there is one.
	var place: String = tr(nepal_stage.ROUNDS[stage].name)
	if MatchSetup.arcade:
		place += "   /   " + (tr("FINAL BOSS") if MatchSetup.is_final_boss() else Settings.fmt("RIVAL %d OF %d", [MatchSetup.arcade_index + 1, MatchSetup.arcade_opponents.size()]))
	banner_tagline.text = place
	$UI/ControlsHint.text = "P1  A/D move  W/S sidestep  |  F 1  V 2  G 3  B 4  E guard     |     P2  Left/Right move  Up/Down sidestep  |  K 1  , 2  L 3  . 4  O guard\nSpace / Enter jump   |   F1 combos     |     Esc pause"
	guide_text.text = guide_text.text.replace("Down is S (P1) / Down arrow (P2).", "Hold E (P1) / O (P2) for the command's down input.")
	guide_text.text = "MOVEMENT: A/D or Left/Right approach and retreat. W/S or Up/Down make short sidesteps. Space / Enter jump. E / O guard.\nForward and back are relative to your opponent. Sidestep committed strikes to evade them.\n\n" + guide_text.text
	camera_target = Vector3(0, CAMERA_HEIGHT, 0)
	camera_distance = CAMERA_CLOSE
	camera_zoom_hold = 0.0
	camera_yaw = 0.0
	_update_fight_camera(0.0)
	shake_3d = 0
	camera_nudge = Vector3.ZERO
	super_fighter = null
	cinematic = 0.0
	ko_fighter = null
	ko_until = 0
	fov_kick = 0
	if ko_replay != null:
		ko_replay.reset()
	for spark in impact_meshes:
		# Pooled bursts are kept for the next round, only hidden.
		if spark.get("pooled", false):
			spark.mesh.visible = false
		else:
			spark.mesh.queue_free()
	impact_meshes.clear()
	for ghost in ghosts:
		ghost.mesh.queue_free()
	ghosts.clear()
	last_states = [-1, -1]

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(player1) or player1.body == null:
		return
	if move_guide.visible or is_paused():
		return
	if is_replaying():
		nepal_stage.animate(delta)
		_update_impacts(delta)
		_update_contact_shadows()
		return
	if ko_replay != null:
		ko_replay.record(delta)
	if shake_3d > 0.0:
		trauma = maxf(trauma, minf(shake_3d * 14.0, 0.85))
		shake_3d = 0.0
	trauma = move_toward(trauma, 0.0, delta * 1.2)
	_update_fight_camera(delta)
	fov_kick = move_toward(fov_kick, 0.0, delta * 18.0)
	camera_nudge = camera_nudge.lerp(Vector3.ZERO, 1.0 - exp(-5.0 * delta))
	nepal_stage.animate(delta)
	_update_impacts(delta)
	_update_ghosts(delta)
	_update_contact_shadows()
	_footwork_dust()

func _update_fight_camera(delta: float) -> void:
	# Scene transitions can detach this arena before its last callback runs.
	if not is_inside_tree() or get_viewport() == null or not is_instance_valid(camera_3d):
		return
	var a: Vector3 = player1.body.position
	var b: Vector3 = player2.body.position
	var midpoint: Vector3 = (a + b) * 0.5
	# Tekken-style: stay square-on to the line between the fighters, so they
	# are always seen in profile and sidesteps turn the stage behind them
	# instead of swinging the view round to a front angle. Measured
	# left-to-right so the camera never flips when fighters cross over.
	var axis: Vector3 = preload("res://scripts/player_3d.gd").axis_between(a, b)
	var target_yaw := clampf(atan2(axis.z, axis.x), -CAMERA_MAX_TURN, CAMERA_MAX_TURN)
	# Follow closely (a lagging camera is what shows the fighters' fronts),
	# ignoring only sub-degree jitter.
	if absf(angle_difference(camera_yaw, target_yaw)) > 0.01:
		camera_yaw = lerp_angle(camera_yaw, target_yaw, 1.0 - exp(-4.5 * delta))
	var turn := Basis(Vector3.UP, -camera_yaw)
	var back: Vector3 = turn * CAMERA_BACK
	var along: Vector3 = turn * Vector3.RIGHT
	var desired := camera_target
	var offset: Vector3 = midpoint - camera_target
	offset.y = 0.0
	var sideways := offset.dot(along)
	if absf(sideways) > 0.3:
		desired += along * (sideways - signf(sideways) * 0.3)
	var depth_offset := offset.dot(turn * Vector3.BACK)
	if absf(depth_offset) > 0.3:
		desired += (turn * Vector3.BACK) * (depth_offset - signf(depth_offset) * 0.3)
	# Jumps never pull the view up; the level horizon stays put.
	desired.y = CAMERA_HEIGHT
	# A heavy dolly: the frame glides after the fight rather than snapping.
	camera_target = camera_target.lerp(desired, 1.0 - exp(-2.4 * delta))
	var size := get_viewport().get_visible_rect().size
	var tan_v := tan(deg_to_rad(camera_3d.fov) * 0.5)
	var tan_h := tan_v * size.x / maxf(size.y, 1.0)
	var screen_up: Vector3 = (turn * Vector3(0, CAMERA_BACK.z, -CAMERA_BACK.y))
	var required := CAMERA_CLOSE
	# Fit both standing silhouettes. Zoom out promptly as fighters separate and
	# ease back in once they close the gap again.
	for fighter in [player1, player2]:
		for height in [0.0, 2.1]:
			var point: Vector3 = fighter.body.position
			point.y = height
			var relative := point - camera_target
			var depth := relative.dot(back)
			var vertical := relative.dot(screen_up)
			required = maxf(required, depth + absf(relative.dot(along)) / (tan_h * 0.8))
			required = maxf(required, depth + absf(vertical) / (tan_v * (0.68 if vertical > 0.0 else 0.8)))
	if required > camera_distance:
		camera_zoom_hold = 0.6
		camera_distance = lerpf(camera_distance, required, 1.0 - exp(-3.2 * delta))
	else:
		camera_zoom_hold = maxf(0.0, camera_zoom_hold - delta)
		if camera_zoom_hold == 0.0 and camera_distance - required > 0.35:
			camera_distance = lerpf(camera_distance, required, 1.0 - exp(-0.9 * delta))
	var eye: Vector3 = camera_target + back * camera_distance
	# Round intro: crane down from high in front of the fighters while the
	# round is announced, landing on the fight view as the banner clears. The
	# swing stays small so neither fighter is ever seen from behind.
	var intro := clampf(intro_timer / intro_length, 0.0, 1.0)
	if intro > 0.0:
		var ease_in := intro * intro * (3.0 - 2.0 * intro)
		var orbit := Basis(Vector3.UP, ease_in * 0.22)
		eye = camera_target + orbit * (back * camera_distance * (1.0 + 0.55 * ease_in)) + Vector3.UP * (1.6 * ease_in)
	# A heavy hit kicks the lens in for a few frames.
	ko_hold = maxf(0.0, ko_hold - delta)
	ko_push = move_toward(ko_push, 8.0 if ko_hold > 0.0 else 0.0, delta * (40.0 if ko_hold > 0.0 else 16.0))
	camera_3d.fov = CAMERA_FOV - (fov_kick if MatchSetup.camera_shake else 0.0) - ko_push
	var nudge := camera_nudge if MatchSetup.camera_shake else Vector3.ZERO
	var look: Vector3 = camera_target
	# Super: swing to a low close-up from the attacker's front quarter and
	# ease back out once the combo is over.
	var performing: bool = is_instance_valid(super_fighter) and super_fighter.state == super_fighter.State.SUPER
	var falling: bool = is_instance_valid(ko_fighter) and Time.get_ticks_msec() < ko_until
	# The knockout cuts straight in (no ease) so the fall reads as instant.
	if falling and cinematic < 1.0 and not performing:
		cinematic = 1.0
	cinematic = move_toward(cinematic, 1.0 if performing or falling else 0.0, delta * (2.6 if performing or falling else 1.4))
	# The knockout shot holds while the camera eases back out of it.
	if cinematic > 0.001 and is_instance_valid(ko_fighter) and not performing:
		# Low and close on the fallen fighter from the camera's side, the
		# winner standing over them in the back of the frame.
		var down: Vector3 = ko_fighter.body.position
		var winner: Node = ko_fighter.opponent
		var toward_winner: Vector3 = (winner.body.position - down) if winner != null else Vector3.RIGHT
		toward_winner.y = 0.0
		var side: float = signf(toward_winner.dot(along)) if absf(toward_winner.dot(along)) > 0.01 else 1.0
		var middle: Vector3 = (down + winner.body.position) * 0.5 if winner != null else down
		var swing: Vector3 = (turn * Vector3.BACK).rotated(Vector3.UP, -0.3 * side)
		var k := smoothstep(0.0, 1.0, cinematic)
		eye = eye.lerp(middle + swing * 4.4 + Vector3.UP * 0.45, k)
		look = look.lerp(down.lerp(middle, 0.35) + Vector3.UP * 0.8, k)
	elif cinematic > 0.001 and is_instance_valid(super_fighter):
		var rival: Node = super_fighter.opponent
		var middle: Vector3 = (super_fighter.body.position + rival.body.position) * 0.5 + Vector3.UP * 1.05
		var toward_face: float = signf(super_fighter.forward.dot(along)) if absf(super_fighter.forward.dot(along)) > 0.01 else 1.0
		# A low profile shot, turned a little toward the attacker's front so
		# both fighters stay in frame with the attacker's face toward us.
		var swing: Vector3 = (turn * Vector3.BACK).rotated(Vector3.UP, 0.35 * toward_face)
		var close: Vector3 = middle + swing * 3.4 + Vector3.UP * -0.25
		var k := smoothstep(0.0, 1.0, cinematic)
		eye = eye.lerp(close, k)
		look = look.lerp(middle, k)
		camera_3d.fov -= 8.0 * k
	# Handheld: a slow sway that never quite stops, and on top of it the
	# impact shake, smooth noise with a little roll rather than a buzz.
	_cam_time += delta
	var feel := 1.0 if MatchSetup.camera_shake else 0.0
	var shake := trauma * trauma * feel
	var sway := Vector3(_wobble(1, 0.23), _wobble(2, 0.19), _wobble(3, 0.21)) * 0.022 * feel
	var jolt := Vector3(_wobble(4, 11.0), _wobble(5, 11.0), _wobble(6, 11.0)) * 0.11 * shake
	camera_3d.h_offset = 0.0
	camera_3d.v_offset = 0.0
	camera_3d.position = eye + nudge + sway + jolt
	camera_3d.look_at(look + nudge * 0.6 + sway * 0.4)
	camera_3d.rotate_object_local(Vector3.BACK, _wobble(7, 0.17) * 0.005 * feel + _wobble(8, 9.0) * 0.045 * shake)

## Smooth noise in -1..1 at `rate` wobbles a second, one strand per `strand`.
func _wobble(strand: int, rate: float) -> float:
	return clampf(_cam_noise.get_noise_2d(_cam_time * rate * 100.0, strand * 1000.0) * 1.6, -1.0, 1.0)

func _update_impacts(delta: float) -> void:
	for spark in impact_meshes:
		spark.age += delta
		spark.update.call(spark)
		if spark.age >= spark.life:
			if spark.get("pooled", false):
				spark.mesh.visible = false
			else:
				spark.mesh.queue_free()
	impact_meshes = impact_meshes.filter(func(spark): return spark.age < spark.life)

## After a knockout Aamai's call waits for the victory moment (the
## celebration after the replay), never over the replay itself.
func _host_winner(host: Node, winner_name: String, match_won: bool) -> void:
	# The round ends on the KO signal before the replay notes the knockout,
	# so a knockout is read off the fighters.
	var knocked: bool = player1.state == player1.State.KO or player2.state == player2.State.KO
	if ko_replay != null and knocked and not ko_replay.celebrating:
		host.queue(host.winner_call.bind(winner_name, match_won), func(): return ko_replay.celebrating)
	else:
		host.winner_call(winner_name, match_won)

func is_replaying() -> bool:
	return ko_replay != null and (ko_replay.playing or ko_replay.celebrating)

## Fight Options can switch the sparks, dust, trails and punch off.
func _effects_on() -> bool:
	var settings := get_node_or_null("/root/Settings")
	return settings == null or settings.hit_effects

func _impact_3d(fighter: Node, blocked: bool, heavy: bool) -> void:
	if ko_replay != null:
		ko_replay.note_impact(fighter, blocked, heavy)
	preload("res://scripts/sfx.gd").fire("block" if blocked else ("hit_heavy" if heavy else "hit_light"))
	if not _effects_on():
		if not blocked:
			shake_3d = 0.045 if heavy else 0.022
		return
	var point: Vector3 = fighter.body.position + fighter.forward * 0.25 + Vector3.UP * (1.03 if heavy else 1.37)
	# The spark sits where the limb really touched the body.
	var touch = fighter.get("last_contact")
	if touch is Dictionary and touch.has("point"):
		point = world.to_local(touch.point) if world != null else touch.point
	# A throw's slam lands on the floor, not where a punch would.
	var partner = fighter.get("throw_partner")
	var slammed: bool = fighter.state == fighter.State.KNOCKDOWN or fighter.thrown_down or (fighter.state == fighter.State.THROWN and partner != null and partner.throw_slammed)
	if slammed:
		point = fighter.body.position - fighter.forward * 0.35 + Vector3.UP * 0.25
		if fighter.state in [fighter.State.KNOCKDOWN, fighter.State.KO] and partner != null and partner.ground_hits > 0:
			# A ground punch to the face of the downed rival.
			point = fighter.body.position - fighter.forward * 0.8 + Vector3.UP * 0.18
	var color := Color("8bdeff") if blocked else (Color("ffb347") if heavy else Color("ffd78b"))
	_impact_burst(point, color, blocked, heavy)
	if not blocked and heavy:
		_dust(fighter.body.position, 22 if slammed else 10, Color(0.62, 0.55, 0.46, 0.5), 0.55 if slammed else 0.35)
	if blocked:
		shake_3d = 0.012
	else:
		shake_3d = 0.045 if heavy else 0.022
		fov_kick = 1.6 if heavy else 0.0
		# The lens is knocked the way the blow travels (the struck fighter
		# faces the attacker, so away from its facing), harder for big hits.
		var force: float = fighter.get("last_hit_force") if fighter.get("last_hit_force") != null else 0.0
		if heavy or force > 0.5 or fighter.get("last_hit_stagger"):
			var blow: Vector3 = -fighter.forward
			blow.y = 0.0
			camera_nudge = blow.normalized() * (0.04 + 0.08 * force) * (1.4 if fighter.get("last_hit_stagger") else 1.0)
	if is_instance_valid(camera_3d) and is_inside_tree() and get_viewport() != null:
		var size := get_viewport().get_visible_rect().size
		var screen := camera_3d.unproject_position(point) / size
		nepal_stage.punch(screen, 0.25 if blocked else (1.0 if heavy else 0.45))

## A super's opening strike landed: the scene darkens, the move's name
## slams onto the screen, and the camera swings into its close-up.
func _super_cinematic(fighter: Node) -> void:
	super_fighter = fighter
	preload("res://scripts/sfx.gd").fire("hit_heavy")
	nepal_stage.flash(Color(0.08, 0.02, 0.02), 0.55, 0.6)
	shake_3d = 0.03
	var data: Dictionary = fighter.SUPERS.get_super(str(fighter.character_profile.id))
	var ui := get_node_or_null("UI")
	if ui == null:
		return
	var title := UI_KIT.heading(ui, str(data.get("name", "SUPER")), Vector2(130, 196), Vector2(700, 90), 58, UI_KIT.GOLD, UI_KIT.CRIMSON)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.z_index = 12
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2.ONE * 1.8
	var show := title.create_tween()
	show.tween_property(title, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_interval(0.55)
	show.tween_property(title, "modulate:a", 0.0, 0.3)
	show.tween_callback(title.queue_free)

## A fighter slammed into a railing: a heavy thud, stone dust bursting off
## the balustrade, sparks where the back meets it and a hard camera knock.
func _wall_impact(point: Vector3) -> void:
	preload("res://scripts/sfx.gd").fire("hit_heavy")
	shake_3d = 0.06
	fov_kick = 2.0
	if not _effects_on():
		return
	var toward_centre := Vector3(-signf(point.x), 0.0, 0.0)
	_impact_burst(point + Vector3.UP * 1.0 + toward_centre * 0.1, Color("ffcf8a"), false, true)
	_dust(Vector3(point.x, 0.0, point.z), 24, Color(0.72, 0.68, 0.6, 0.55), 0.6)
	_dust(point + Vector3.UP * 0.9, 14, Color(0.78, 0.74, 0.66, 0.45), 0.45)
	if is_instance_valid(camera_3d) and is_inside_tree() and get_viewport() != null:
		var size := get_viewport().get_visible_rect().size
		nepal_stage.punch(camera_3d.unproject_position(point + Vector3.UP) / size, 1.0)

## Core flash, a camera-facing shock ring and a burst of sparks. Guarded
## hits are cold blue chips that die fast; clean hits are hot and fling
## sparks that fall under gravity.
## Impact bursts are pooled: building a fresh glow ball, ring and spark
## emitter (meshes, materials, a particle system) on every hit stalled the
## renderer for 70-280 ms per hit on integrated graphics. A few are built
## once, drawn on the first frame out of sight so their shaders are ready,
## and reused round-robin.
const BURST_POOL := 6
var _bursts: Array[Dictionary] = []
var _next_burst := 0

func _build_burst_pool() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1
	sphere.radial_segments = 12
	sphere.rings = 6
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var chip := QuadMesh.new()
	chip.size = Vector2(0.065, 0.065)
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_material.vertex_color_use_as_albedo = true
	spark_material.albedo_texture = nepal_stage.soft_dot()
	chip.material = spark_material
	for i in BURST_POOL:
		var core := MeshInstance3D.new()
		core.mesh = sphere
		var glow := StandardMaterial3D.new()
		glow.emission_enabled = true
		glow.emission_energy_multiplier = 1.6
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		core.material_override = glow
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ring := MeshInstance3D.new()
		ring.mesh = quad
		var rim := ShaderMaterial.new()
		rim.shader = RING_SHADER
		ring.material_override = rim
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sparks := CPUParticles3D.new()
		sparks.one_shot = true
		sparks.explosiveness = 1.0
		sparks.amount = 14
		sparks.emitting = false
		sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		sparks.emission_sphere_radius = 0.06
		sparks.direction = Vector3.UP
		sparks.spread = 180.0
		sparks.damping_min = 2.0
		sparks.damping_max = 5.0
		sparks.scale_amount_min = 0.5
		sparks.scale_amount_max = 1.0
		var ramp := Gradient.new()
		ramp.add_point(0.35, Color.WHITE)
		sparks.color_ramp = ramp
		sparks.mesh = chip
		sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for node in [core, ring, sparks]:
			world.add_child(node)
			# First frame: drawn in view but invisible (fully transparent,
			# tiny) so the GPU prepares them during the round intro.
			node.position = Vector3(0, 1.0, 0)
		core.scale = Vector3.ONE * 0.001
		ring.scale = Vector3.ONE * 0.001
		glow.albedo_color = Color(1, 1, 1, 0)
		ramp.set_color(0, Color(1, 1, 1, 0))
		ramp.set_color(1, Color(1, 1, 1, 0))
		ramp.set_color(2, Color(1, 1, 1, 0))
		sparks.emitting = true
		_bursts.append({"core": core, "ring": ring, "sparks": sparks, "ramp": ramp})
	get_tree().process_frame.connect(func():
		for burst in _bursts:
			for key in ["core", "ring"]:
				burst[key].visible = false, CONNECT_ONE_SHOT)

func _impact_burst(point: Vector3, color: Color, blocked: bool, heavy: bool) -> void:
	if _bursts.is_empty():
		return
	var burst: Dictionary = _bursts[_next_burst]
	_next_burst = (_next_burst + 1) % _bursts.size()
	var size := (0.7 if heavy else 0.5) * (0.7 if blocked else 1.0)
	var core: MeshInstance3D = burst.core
	var glow: StandardMaterial3D = core.material_override
	glow.albedo_color = color.lightened(0.5)
	glow.emission = color
	core.position = point
	core.scale = Vector3.ONE * 0.05
	core.visible = true
	impact_meshes.append({"mesh": core, "pooled": true, "age": 0.0, "life": 0.14, "update": func(fx: Dictionary):
		var k: float = clampf(fx.age / fx.life, 0.0, 1.0)
		fx.mesh.scale = Vector3.ONE * size * 0.32 * (0.3 + 0.7 * sqrt(k))
		fx.mesh.material_override.albedo_color.a = 1.0 - k})
	var ring: MeshInstance3D = burst.ring
	(ring.material_override as ShaderMaterial).set_shader_parameter("color", color)
	(ring.material_override as ShaderMaterial).set_shader_parameter("progress", 0.0)
	ring.position = point
	ring.visible = true
	impact_meshes.append({"mesh": ring, "pooled": true, "age": 0.0, "life": 0.22 if heavy else 0.17, "update": func(fx: Dictionary):
		var k: float = clampf(fx.age / fx.life, 0.0, 1.0)
		fx.mesh.scale = Vector3.ONE * size * 1.6 * (0.25 + 0.75 * (1.0 - pow(1.0 - k, 2.5)))
		fx.mesh.material_override.set_shader_parameter("progress", k)})
	var sparks: CPUParticles3D = burst.sparks
	var ramp: Gradient = burst.ramp
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, color)
	ramp.set_color(2, Color(color.r, color.g, color.b, 0.0))
	sparks.lifetime = 0.28 if blocked else 0.45
	sparks.initial_velocity_min = 2.0 if blocked else 3.0
	sparks.initial_velocity_max = 4.5 if blocked else (7.5 if heavy else 5.5)
	sparks.gravity = Vector3(0, -6.0 if blocked else -14.0, 0)
	# A one-shot emitter's count is fixed per burst; fewer sparks for a
	# guarded hit come from a shorter, weaker spray instead.
	sparks.position = point
	sparks.restart()
	sparks.emitting = true

## A puff of courtyard dust at floor level: landings, dashes and the
## stagger of a heavy hit.
func _dust(at: Vector3, amount: int, color: Color, speed: float) -> void:
	if not _effects_on():
		return
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.amount = amount
	puff.lifetime = 0.55
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 0.18
	puff.direction = Vector3.UP
	puff.spread = 70.0
	puff.initial_velocity_min = speed * 0.5
	puff.initial_velocity_max = speed * 1.6
	puff.gravity = Vector3(0, 0.6, 0)
	puff.damping_min = 1.5
	puff.damping_max = 3.0
	puff.scale_amount_min = 0.7
	puff.scale_amount_max = 1.6
	puff.scale_amount_curve = null
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	puff.color_ramp = ramp
	var mote := QuadMesh.new()
	mote.size = Vector2(0.26, 0.26)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = nepal_stage.soft_dot()
	mote.material = material
	puff.mesh = mote
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(puff)
	puff.position = Vector3(at.x, 0.06, at.z)
	puff.emitting = true
	impact_meshes.append({"mesh": puff, "age": 0.0, "life": puff.lifetime + 0.05, "update": func(_fx: Dictionary): pass})

## Landings and dashes kick up dust; a knockout is a bright flash that
## drains the colour out of the square for a moment.
func _footwork_dust() -> void:
	for i in 2:
		var fighter: Node = [player1, player2][i]
		var state: int = fighter.state
		if state != last_states[i] and last_states[i] >= 0:
			if state == fighter.State.LAND:
				_dust(fighter.body.position, 8, Color(0.6, 0.54, 0.46, 0.4), 0.6)
			elif state == fighter.State.DASH:
				_dust(fighter.body.position - fighter.forward * 0.2, 6, Color(0.6, 0.54, 0.46, 0.35), 0.5)
		last_states[i] = state

## Never leave the game in slow motion when the scene is left mid-knockout.
func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _ko_3d(fighter: Node) -> void:
	if ko_replay != null:
		ko_replay.note_ko(fighter)
	shake_3d = 0.07
	fov_kick = 2.2
	# The knockout plays in slow motion with the camera pushed in on the
	# fall (real-time timer, so the slow-mo itself is not slowed down).
	ko_fighter = fighter
	ko_until = Time.get_ticks_msec() + 2000
	if DisplayServer.get_name() != "headless" and MatchSetup.camera_shake:
		# The fall itself plays in slow motion, starting the instant the blow
		# lands; the camera has already cut to it.
		Engine.time_scale = 0.5
		get_tree().create_timer(0.6, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
		ko_hold = 0.6
	nepal_stage.flash(Color(1.0, 0.98, 0.94), 0.22, 0.25)
	_dust(fighter.body.position, 16, Color(0.6, 0.54, 0.46, 0.5), 0.9)

## Afterimages: while a fighter dashes or swings a heavy attack, the big
## pieces of the procedural rig are copied every few frames (sharing their
## meshes, so nothing is built or uploaded) and left behind as a translucent
## ghost in the player's colour. Skinned models are skipped (their
## surfaces would copy in the bind pose).
const GHOST_PARTS := ["torso", "hips", "chest_bulk", "head", "hair", "rear_thigh", "lead_thigh", "rear_shin", "lead_shin",
	"rear_upper", "lead_upper", "rear_forearm", "lead_forearm", "rear_boot", "lead_boot", "rear_hand", "lead_hand", "cape"]

func _update_ghosts(delta: float) -> void:
	for i in 2:
		var fighter: Node = [player1, player2][i]
		ghost_clock[i] -= delta
		if ghost_clock[i] > 0.0 or not _effects_on() or not _wants_ghost(fighter):
			continue
		ghost_clock[i] = 0.065
		var ghost := _snapshot(fighter, TEAM_COLORS[i])
		if ghost != null:
			ghosts.append({"mesh": ghost, "age": 0.0, "life": 0.16})
	for ghost in ghosts:
		ghost.age += delta
		var k: float = clampf(ghost.age / ghost.life, 0.0, 1.0)
		ghost.mesh.material_override.albedo_color.a = 0.1 * (1.0 - k) * (1.0 - k)
		if ghost.age >= ghost.life:
			ghost.mesh.queue_free()
	ghosts = ghosts.filter(func(ghost): return ghost.age < ghost.life)

func _wants_ghost(fighter: Node) -> bool:
	if fighter.hitstop_remaining > 0.0 or fighter.combat_paused:
		return false
	var S: Dictionary = fighter.State
	if fighter.state == S.DASH:
		return true
	if fighter.state in [S.PUNCH, S.KICK]:
		var heavy: bool = fighter.state == S.KICK or fighter.attack_variant in ["cross", "hook", "rear_hook", "uppercut", "overhand", "backfist", "body_hook", "finisher", "spin"]
		return heavy and fighter.attack_timer < fighter.attack_startup() + fighter.attack_active_time()
	return false

func _snapshot(fighter: Node, color: Color) -> MeshInstance3D:
	var visual: Node = fighter.visual
	if visual == null or visual.model == null or not visual.model.visible:
		return null
	var animated = visual.get("animated")
	if animated != null and animated.active:
		return null
	var material := StandardMaterial3D.new()
	# A faint alpha-blended trail in the fighter's own tone, not a neon copy.
	material.albedo_color = Color(color.r, color.g, color.b, 0.1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_BACK
	var ghost := MeshInstance3D.new()
	ghost.material_override = material
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ghost)
	var any := false
	for key in GHOST_PARTS:
		var part: MeshInstance3D = visual.parts.get(key)
		if part == null or part.mesh == null or not part.is_visible_in_tree():
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = part.mesh
		copy.material_override = material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
		copy.global_transform = part.global_transform
		any = true
	if not any:
		ghost.queue_free()
		return null
	return ghost

## A soft dark blob under each fighter, whatever the lamps and moon are
## doing; it shrinks and fades as the fighter leaves the ground.
func _contact_shadows() -> void:
	for i in 2:
		var blob := MeshInstance3D.new()
		blob.name = "ContactShadow%d" % (i + 1)
		var quad := QuadMesh.new()
		quad.size = Vector2(1.15, 1.15)
		quad.orientation = PlaneMesh.FACE_Y
		blob.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = CONTACT_SHADOW
		blob.material_override = material
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(blob)
		contact_shadows.append(blob)

func _update_contact_shadows() -> void:
	for i in contact_shadows.size():
		var fighter: Node = [player1, player2][i]
		var blob := contact_shadows[i]
		var height: float = maxf(fighter.body.position.y, 0.0)
		blob.position = Vector3(fighter.body.position.x, 0.012, fighter.body.position.z)
		var lift := clampf(height / 1.6, 0.0, 1.0)
		blob.scale = Vector3.ONE * (1.0 + lift * 0.6)
		blob.material_override.set_shader_parameter("strength", 0.5 * (1.0 - lift * 0.8))

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

func _box_3d(label: String, size: Vector3, at: Vector3, color: Color, solid: bool = false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = label
	world.add_child(node)
	node.position = at
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	node.add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		node.add_child(collider)
	return node

func _build_stage() -> void:
	_box_3d("Platform", Vector3(14, 0.65, 10), Vector3(0, -0.325, 0), Color("685c4e"), true).get_child(0).hide()
	for edge in [-1, 1]:
		_box_3d("SideWall", Vector3(0.22, 5, 10.4), Vector3(edge * 4.66, 2.0, 0), Color.WHITE, true).get_child(0).hide()
		_box_3d("EndWall", Vector3(14.4, 5, 0.22), Vector3(0, 2.0, edge * 1.06), Color.WHITE, true).get_child(0).hide()
	nepal_stage = preload("res://scripts/nepal_stage_3d.gd").new()
	nepal_stage.name = "NepalJourney"
	world.add_child(nepal_stage)
	camera_3d = Camera3D.new()
	camera_3d.name = "Camera3D"
	camera_3d.fov = CAMERA_FOV
	camera_3d.near = 0.1
	camera_3d.far = 400
	world.add_child(camera_3d)
	camera_3d.position = Vector3(0, 3.25, 10.2)
	camera_3d.look_at(Vector3(0, 0.8, 0))
	camera_3d.current = true
