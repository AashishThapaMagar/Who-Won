extends "res://scripts/player.gd"
## Combat controller in legacy pose units; CharacterBody3D owns all movement.
## Keeping combat in one implementation preserves hit confirms and frame data.
const UNITS := 64.0
const LANE_HALF_DEPTH := 0.65
const LANE_HALF_WIDTH := 4.25
const SIDESTEP_RATIO := 0.35
var body: CharacterBody3D
var pivot: Node3D
var forward := Vector3.RIGHT
var spawn_position := Vector3.ZERO
var ai_controlled := false
var lateral_speed := 0.0
var travel := 0.0
var dash_vector := Vector3.RIGHT
var dash_run_held := false
## Speed of the fight relative to real time. Below 1.0 every attack, stun,
## recovery, walk, dash and jump plays out slower and weightier, while frame
## advantage, combo links and jump arcs keep their shape because the whole
## combat clock is scaled together. Menus, camera and round timer ignore it.
const COMBAT_TEMPO := 0.8
## Share of a blow's listed damage the 3D fight takes off: rounds are long
## exchanges, not a few clean hits. Applies to strikes, supers and throws.
const DAMAGE_SCALE := 0.6
## Footwork with weight (combat units/s^2): about a sixth of a second to
## reach a run and a short, eased stop, instead of starting and stopping dead.
const LOCO_ACCEL := 1500.0
const LOCO_BRAKE := 2300.0
## Throw path, fixed when the grab lands (see _begin_throw).
var _throw_anchor := Vector3.ZERO
var _throw_victim_anchor := Vector3.ZERO
var _throw_forward := Vector3.RIGHT
var _throw_reach := 1.0
var _throw_shift := Vector3.ZERO
var _throw_rest := Vector3.ZERO
## Knocked into a railing hard enough, a fighter slams into it, bounces
## off and stays stunned a beat longer: a follow-up chance (see _wall_hit).
signal wall_hit(point: Vector3)
## Off while the arena ends have no visible railing (nepal_stage_3d RAILINGS):
## a fighter slamming into thin air would look broken.
const WALL_HITS := false
const WALL_SPEED := 150.0
const WALL_STUN := 0.42
var _wall_hit_done := false
## Fighters locked in a throw or lying after one are placed directly, not
## moved by physics, and are not pushboxes.
const PLACED_STATES := [State.THROWING, State.THROWN, State.KNOCKDOWN, State.SUPER, State.STRUCK]
## The super's line, fixed when its opening strike lands (see _begin_super).
var _super_anchor := Vector3.ZERO
var _super_forward := Vector3.RIGHT

func _physics_process(delta: float) -> void:
	super._physics_process(delta * COMBAT_TEMPO)

func scaled_damage(amount: int) -> int:
	return 0 if amount <= 0 else maxi(1, roundi(amount * DAMAGE_SCALE))

func _ready() -> void:
	super._ready()
	input_prefix = "p%d_3d_" % player_id
	collision_layer = 0
	collision_mask = 0
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 0
	hitbox.collision_layer = 0
	hitbox.collision_mask = 0
	hitbox.set_physics_process(false)
	$CollisionShape2D.disabled = true
	$Hurtbox/CollisionShape2D.disabled = true
	$Hitbox/CollisionShape2D.disabled = true

func world_input() -> Vector3:
	if ai_controlled:
		var direction := forward * Input.get_axis(input_prefix + "left", input_prefix + "right")
		direction.z *= SIDESTEP_RATIO
		# Sidesteps use the same screen axes as a player's (see below).
		var side := Input.get_axis(input_prefix + "far", input_prefix + "near")
		if side != 0.0:
			var along := fight_axis()
			direction += Vector3(-along.z, 0.0, along.x) * side * SIDESTEP_RATIO
		return direction
	var axes := Input.get_vector(input_prefix + "left", input_prefix + "right", input_prefix + "far", input_prefix + "near")
	# Tekken-style: left/right run along the fight axis as seen on screen, and
	# up/down step into or out of the background at right angles to it. The
	# camera stays square-on to that axis, so this is always screen-relative.
	var along := fight_axis()
	var toward_camera := Vector3(-along.z, 0.0, along.x)
	var sidestep := toward_camera * axes.y * SIDESTEP_RATIO
	# At the edge of the fighting strip a held sidestep simply stops, instead
	# of its sideways share sliding the fighter along the lane.
	if body != null and absf(body.position.z) >= LANE_HALF_DEPTH - 0.01 and signf(sidestep.z) == signf(body.position.z):
		sidestep = Vector3.ZERO
	return along * axes.x + sidestep

## The line between the fighters, pointing screen-right (+x side). The fight
## camera (arena_3d.gd) turns to stay square-on to it.
func fight_axis() -> Vector3:
	if body == null or opponent == null or opponent.body == null:
		return Vector3.RIGHT
	return axis_between(body.position, opponent.body.position)

static func axis_between(a: Vector3, b: Vector3) -> Vector3:
	var line := (b - a) if a.x <= b.x else (a - b)
	line.y = 0.0
	return line.normalized() if line.length() > 0.05 else Vector3.RIGHT

func _movement_axis() -> float:
	var projection := world_input().dot(forward)
	return signf(projection) if absf(projection) > 0.35 else 0.0

func _is_grounded() -> bool:
	return body != null and body.is_on_floor()

func _opponent_distance(other: Node) -> float:
	return body.global_position.distance_to(other.body.global_position) * UNITS

func _update_facing() -> void:
	facing = 1
	if body == null or opponent == null or opponent.body == null:
		return
	if state in [State.IDLE, State.WALK, State.BLOCK, State.LAND]:
		var offset: Vector3 = opponent.body.global_position - body.global_position
		offset.y = 0.0
		if offset.length_squared() > 0.01:
			forward = offset.normalized()

func _capture_input() -> void:
	# Commands use opponent-relative forward/back plus the dedicated guard
	# button as their down input. A/D double taps dash along the input vector.
	var before := state
	super._capture_input()
	if Input.is_action_just_pressed(input_prefix + "grapple"):
		throw_tech_until = combat_time + 0.16
		if state in [State.IDLE, State.WALK, State.BLOCK] and _is_grounded():
			_buffered_action = "grapple"
			_buffered_move = ""
			_buffered_direction = 0
			_buffer_remaining = input_buffer_time
	if before != State.DASH and state == State.DASH:
		dash_vector = world_input().normalized()
		if dash_vector.length_squared() < 0.01:
			dash_vector = forward * _dash_dir
		dash_run_held = dash_vector.dot(forward) > 0.35
		_dash_dir = 1 if dash_run_held else -1

func _move_combat_body(delta: float) -> void:
	if body == null:
		return
	if state in PLACED_STATES or thrown_down:
		_hold_placed_body()
		return
	var input := world_input() if controls_enabled else Vector3.ZERO
	# A held second forward tap carries the dash into a sustained run.
	# Releasing, reversing, guarding or attacking ends that commitment.
	if input.dot(forward) <= 0.35 or state not in [State.IDLE, State.WALK, State.DASH] or not controls_enabled:
		dash_run_held = false
	var lateral := Vector3(-forward.z, 0.0, forward.x)
	var can_move := controls_enabled and state in [State.IDLE, State.WALK, State.JUMP, State.JUMP_START]
	var wants_run := input.dot(forward) > 0.35 and (dash_run_held or Input.is_action_pressed(input_prefix + "run"))
	var speed := move_speed * (1.0 if wants_run else WALK_SPEED_RATIO)
	var lateral_target := input.dot(lateral) * speed if can_move else 0.0
	lateral_speed = move_toward(lateral_speed, lateral_target, (acceleration if can_move else braking) * delta)
	var planar := forward * velocity.x + lateral * lateral_speed
	if can_move and state in [State.IDLE, State.WALK]:
		# Both axes use one normalized vector, so diagonals never move faster.
		running = wants_run
		var target := input * speed
		if input.dot(forward) < -0.35 and not running:
			target *= backward_speed_ratio
		var current := Vector3(body.velocity.x, 0.0, body.velocity.z) * UNITS
		planar = current.move_toward(target, (LOCO_BRAKE if input.is_zero_approx() else LOCO_ACCEL) * delta)
		state = State.WALK if planar.length() > 8.0 else State.IDLE
	if state == State.DASH:
		planar = dash_vector * move_speed * (1.85 if dash_vector.dot(forward) >= 0 else 1.45)
	if state in [State.HITSTUN, State.BLOCKSTUN, State.KO]:
		lateral_speed = 0.0
		planar = forward * velocity.x
	if state == State.JUMP:
		planar = planar.limit_length(move_speed)
	body.get_node("Hurtbox3D").rotation.y = atan2(-forward.z, forward.x)
	# Velocities stay in combat time; the body moves at the tempo-scaled rate
	# for one real physics step and the velocity is restored afterwards.
	body.velocity = (planar / UNITS + Vector3.UP * -velocity.y / UNITS) * COMBAT_TEMPO
	var previous := body.position
	_separate_bodies()
	body.move_and_slide()
	body.velocity /= COMBAT_TEMPO
	_separate_bodies()
	# Keep sidesteps on the fighting strip, including pushback and jumps.
	# Stopped by the end wall (its collider halts the body just short of
	# the clamp) while still being driven toward it.
	var pressed := body.is_on_wall() or absf(body.position.x) >= LANE_HALF_WIDTH - 0.01
	var into_wall := pressed and absf(body.position.x) > LANE_HALF_WIDTH - 0.25 and signf(planar.x) == signf(body.position.x)
	body.position.x = clampf(body.position.x, -LANE_HALF_WIDTH, LANE_HALF_WIDTH)
	if WALL_HITS and into_wall and not _wall_hit_done and state in [State.HITSTUN, State.KO] and absf(velocity.x) >= WALL_SPEED:
		_wall_hit()
	body.position.z = clampf(body.position.z, -LANE_HALF_DEPTH, LANE_HALF_DEPTH)
	if absf(body.position.z) >= LANE_HALF_DEPTH:
		body.velocity.z = 0.0
		lateral_speed = 0.0
	velocity.y = -body.velocity.y * UNITS
	var displacement := body.position - previous
	var signed_distance := Vector2(displacement.x, displacement.z).length() * (-1.0 if planar.dot(forward) < -0.1 else 1.0)
	travel += signed_distance * UNITS
	global_position = Vector2(travel, -body.position.y * UNITS)
	var target_angle := atan2(-forward.z, forward.x)
	pivot.rotation.y = lerp_angle(pivot.rotation.y, target_angle, 1.0 - exp(-22.0 * delta))

func _separate_bodies() -> void:
	# Grounded fighters are circular pushboxes, never platforms. They still
	# collide with the environment using the engine's 3D capsule solver.
	if opponent == null or opponent.body == null:
		return
	if absf(body.position.y - opponent.body.position.y) > 1.65:
		return
	if opponent.state in PLACED_STATES or opponent.thrown_down:
		return
	var offset: Vector3 = body.position - opponent.body.position
	offset.y = 0
	var distance := offset.length()
	if distance >= 0.64:
		return
	var normal := offset / distance if distance > 0.001 else -forward
	var push := normal * (0.64 - distance + 0.001)
	body.move_and_collide(push * 0.5)
	opponent.body.move_and_collide(-push * 0.5)
	# Give the free fighter the remaining space when the rival is at a wall.
	var gap: Vector3 = body.position - opponent.body.position
	gap.y = 0
	if gap.length() < 0.64:
		body.move_and_collide(normal * (0.64 - gap.length()))
		gap = body.position - opponent.body.position
		gap.y = 0
		if gap.length() < 0.64:
			opponent.body.move_and_collide(-normal * (0.64 - gap.length()))

## Keeps a placed body still and its facing, hurtbox and 2D shadow in step
## with wherever _place_throw put it.
func _hold_placed_body() -> void:
	body.velocity = Vector3.ZERO
	velocity = Vector2.ZERO
	lateral_speed = 0.0
	body.get_node("Hurtbox3D").rotation.y = atan2(-forward.z, forward.x)
	pivot.rotation.y = atan2(-forward.z, forward.x)
	global_position = Vector2(travel, -body.position.y * UNITS)

## Fixes the throw's line and reach. The attacker's drive is scaled so it
## ends on top of the rival from whatever gap the grab landed at, and the
## pair is eased away from a wall the victim would otherwise land inside.
func _begin_throw() -> void:
	var victim: Node = throw_partner
	_throw_anchor = body.position
	_throw_victim_anchor = victim.body.position
	var line: Vector3 = _throw_victim_anchor - _throw_anchor
	line.y = 0.0
	_throw_forward = line.normalized() if line.length() > 0.05 else forward
	forward = _throw_forward
	victim.forward = -_throw_forward
	var gap := maxf(line.length(), 0.3)
	_throw_reach = clampf((gap + THROW.VICTIM[-1] - THROW.END_GAP) / THROW.ATTACKER[-1], 0.3, 1.2)
	var landing: Vector3 = _throw_victim_anchor + _throw_forward * THROW.VICTIM[-1]
	# The victim's head lands well past its hips: keep that inside the lane.
	var head: Vector3 = landing + _throw_forward * 0.8
	var inside := Vector3(clampf(head.x, -LANE_HALF_WIDTH, LANE_HALF_WIDTH), head.y, clampf(head.z, -LANE_HALF_DEPTH, LANE_HALF_DEPTH))
	_throw_shift = inside - head
	_throw_shift.y = 0.0
	_throw_rest = landing + _throw_shift - _throw_forward * THROW.RECOVERY_GAP

func _place_throw() -> void:
	var victim: Node = throw_partner
	if victim == null or victim.body == null:
		return
	var t := minf(throw_time, THROW.END_TIME)
	var settle := smoothstep(0.0, THROW.END_TIME, t)
	var to: Vector3 = _throw_anchor + _throw_forward * (_throw_reach * THROW.travel(THROW.ATTACKER, t)) + _throw_shift * settle
	if not is_inf(mount_slide_at):
		to += _throw_forward * THROW.MOUNT_ADVANCE * smoothstep(0.0, THROW.MOUNT_SLIDE, throw_time - mount_slide_at)
	if throw_time > throw_rise_at:
		# Up off the downed rival and a step back to a safe gap.
		var rise := smoothstep(0.0, THROW.RECOVERY_TIME, throw_time - throw_rise_at)
		to = to.lerp(_throw_rest, rise)
	_set_placed(to)
	# A victim rolling clear moves itself (see _roll_away).
	if victim.wake_choice == "roll":
		return
	victim._set_placed(_throw_victim_anchor + _throw_forward * THROW.travel(THROW.VICTIM, t) + _throw_shift * settle)

func _roll_away(distance: float) -> void:
	var away: Vector3 = -forward
	away.y = 0.0
	var to: Vector3 = body.position + away.normalized() * distance
	to.x = clampf(to.x, -LANE_HALF_WIDTH, LANE_HALF_WIDTH)
	to.z = clampf(to.z, -LANE_HALF_DEPTH, LANE_HALF_DEPTH)
	_set_placed(to)

func _begin_super() -> void:
	var victim: Node = super_partner
	_super_anchor = body.position
	var line: Vector3 = victim.body.position - body.position
	line.y = 0.0
	_super_forward = line.normalized() if line.length() > 0.05 else forward
	forward = _super_forward
	victim.forward = -_super_forward
	_super_gap = clampf(line.length(), 0.55, 1.0)

## The attacker drives forward through the combo; the victim, locked until
## the last blow, is kept in front of it and driven back a step per blow.
func _place_super() -> void:
	var data := SUPERS.get_super(str(character_profile.id))
	var span: float = maxf(float(data.end) - float(data.start), 0.01)
	var progress := clampf((super_clip_time() - float(data.start)) / span, 0.0, 1.0)
	var to: Vector3 = _super_anchor + _super_forward * float(data.travel) * smoothstep(0.0, 1.0, progress)
	to.x = clampf(to.x, -LANE_HALF_WIDTH, LANE_HALF_WIDTH)
	_set_placed(to)
	var victim: Node = super_partner
	if victim != null and victim.state == State.STRUCK:
		var back: Vector3 = to + _super_forward * (_super_gap + SUPERS.STEP_BACK * super_hits)
		back.x = clampf(back.x, -LANE_HALF_WIDTH, LANE_HALF_WIDTH)
		victim._set_placed(back)

func _super_hit(index: int) -> void:
	super._super_hit(index)
	var victim: Node = super_partner
	# The launch may carry the victim into a railing.
	if victim != null and victim.state in [State.HITSTUN, State.KO]:
		victim._wall_hit_done = false

func _set_placed(to: Vector3) -> void:
	to.y = body.position.y
	var moved: Vector3 = to - body.position
	travel += Vector2(moved.x, moved.z).length() * UNITS * (1.0 if moved.dot(forward) >= 0.0 else -1.0)
	body.position = to

func take_hit(damage: int, knockback: float, _attacker_facing: int, attacker: Node = null, attack_type: String = "punch") -> bool:
	# Momentum: a limb arriving fast shoves harder than one that barely
	# reached (a few tenths either way; frame data is untouched).
	if pending_contact.has("speed"):
		knockback *= clampf(0.85 + float(pending_contact.speed) / 40.0, 0.85, 1.2)
	var guarded_from_front := true
	if attacker != null:
		var offset: Vector3 = attacker.body.position - body.position
		offset.y = 0
		guarded_from_front = forward.dot(offset.normalized()) > 0.25
	var result := super.take_hit(damage, knockback, -1 if guarded_from_front else 1, attacker, attack_type)
	if state in [State.HITSTUN, State.KO]:
		# Each new blow may carry the fighter into the wall again.
		_wall_hit_done = false
	if attacker != null and state in [State.HITSTUN, State.BLOCKSTUN, State.KO]:
		var away: Vector3 = body.position - attacker.body.position
		away.y = 0
		forward = -away.normalized() if away.length_squared() > 0.001 else -attacker.forward
		velocity.x = -absf(velocity.x)
	return result

## The slam: the body stops dead against the stone, freezes a moment and
## rebounds a little toward the attacker, its stun stretched so the
## attacker can follow up. Once per blow.
func _wall_hit() -> void:
	_wall_hit_done = true
	velocity.x = 50.0
	if state == State.HITSTUN:
		stun_timer = maxf(stun_timer, WALL_STUN)
	hitstop_remaining = maxf(hitstop_remaining, 0.08)
	if opponent != null:
		opponent.combat_notice = "WALL HIT"
		opponent.notice_until = opponent.combat_time + 0.9
	var contact: Vector3 = body.position
	contact.x = signf(contact.x) * (LANE_HALF_WIDTH + 0.3)
	wall_hit.emit(contact)

func reset_for_new_round() -> void:
	_wall_hit_done = false
	if body != null:
		body.position = spawn_position
		body.velocity = Vector3.ZERO
		# A teleport, not a move: don't smear the fighter across the arena.
		body.reset_physics_interpolation()
	lateral_speed = 0.0
	travel = 0.0
	dash_run_held = false
	super.reset_for_new_round()
	# Face the rival's spawn: the facing left over from the last round can
	# point anywhere, and fighters are frozen through the round intro.
	if opponent != null and opponent.get("spawn_position") != null:
		var toward: Vector3 = opponent.spawn_position - spawn_position
		toward.y = 0.0
		if toward.length_squared() > 0.01:
			forward = toward.normalized()
	if pivot != null:
		pivot.rotation.y = atan2(-forward.z, forward.x)
	if visual != null:
		for surface in visual.materials.values():
			surface.emission_energy_multiplier = 0.0

func _flash(color: Color) -> void:
	if visual == null or visual.materials.is_empty():
		return
	if _flash_tween != null:
		_flash_tween.kill()
	# A brief warm flush in the hit colour: enough to register the contact,
	# never so bright that the fighter turns into a glowing cut-out.
	for surface in visual.materials.values():
		surface.emission_enabled = true
		surface.emission = color
		surface.emission_energy_multiplier = 0.32
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(amount: float):
		for surface in visual.materials.values():
			surface.emission_energy_multiplier = amount, 0.32, 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
