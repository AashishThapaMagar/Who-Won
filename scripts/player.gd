extends CharacterBody2D
## Combat and animation share one physics clock.
signal health_changed(new_health: int, max_health: int)
signal ko
signal impact(point: Vector2, blocked: bool, heavy: bool)
## Fired on the attacker when its blow lands (or is guarded), for follow-through.
signal strike_connected(blocked: bool, force: float)
## A super's opening strike landed: the cinematic begins (see super_moves.gd).
signal super_started

const ROSTER := preload("res://scripts/fighter_roster.gd")
const MOVES := preload("res://scripts/move_catalog.gd")
const MOTIONS := preload("res://scripts/motion_input.gd")
const ACTION_MOVES := preload("res://scripts/action_moves.gd")
const THROW := preload("res://scripts/throw_data.gd")
const SUPERS := preload("res://scripts/super_moves.gd")
const BATTLE_CRY := preload("res://scripts/battle_cry.gd")

enum State { IDLE, WALK, JUMP, PUNCH, KICK, BLOCK, HITSTUN, KO, BLOCKSTUN, DASH, JUMP_START, LAND, THROWING, THROWN, KNOCKDOWN, SUPER, STRUCK }

@export var player_id: int = 1
@export var max_health: int = 100
@export var style: FightStyle = null
@export_group("Movement")
@export var move_speed: float = 260.0
@export var jump_velocity: float = -760.0
@export var acceleration: float = 3800.0
@export var braking: float = 5200.0
@export var backward_speed_ratio: float = 0.72
@export var input_buffer_time: float = 0.13
@export_group("Punch")
@export var punch_damage: int = 6
@export var punch_startup_time: float = 0.05
@export var punch_active_time: float = 0.08
@export var punch_total_time: float = 0.22
@export var punch_knockback: float = 220.0
@export_group("Kick")
@export var kick_damage: int = 12
@export var kick_startup_time: float = 0.1
@export var kick_active_time: float = 0.12
@export var kick_total_time: float = 0.38
@export var kick_knockback: float = 380.0
@export_group("Hook")
@export var hook_damage: int = 9
@export var hook_startup_time: float = 0.075
@export var hook_active_time: float = 0.09
@export var hook_total_time: float = 0.26
@export var hook_knockback: float = 260.0
@export_group("Guard & Stun")
@export var hitstun_time_light: float = 0.25
@export var hitstun_time_heavy: float = 0.5
@export var block_chip_multiplier: float = 0.15
@export_group("Appearance")
@export var base_color: Color = Color(0.2, 0.4, 0.9, 1)

@onready var hitbox: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var visual: Node2D = $Visual
var health: int
var state: int = State.IDLE
var facing: int = 1
var attack_timer: float = 0.0
var attack_variant: String = "jab"
var stun_timer: float = 0.0
var input_prefix: String = "p1_"
var opponent: Node = null
var current_style: FightStyle = null
var character_index: int = 0
var character_profile: Dictionary = ROSTER.profile(0)
var block_hold_time: float = 999.0
var combo_stacks: int = 0
var hitstop_remaining: float = 0.0
## Where and how hard the last blow landed, read by the visual to pick the
## body's recoil: "high" snaps the head back, "mid" folds the trunk, "low"
## buckles the knees. Force runs 0..1 from a light jab to a counter finisher.
var last_hit_height: String = "high"
var last_hit_force: float = 0.0
## Where the last blow really touched (see hit_detection_3d.gd contact()):
## point, part, height, side, speed, direction. Empty when not measured.
var last_contact: Dictionary = {}
## Handed over by the hit detector just before take_hit.
var pending_contact: Dictionary = {}
var last_hit_counter: bool = false
## Counter hits and the heaviest blows knock the fighter off balance.
var last_hit_stagger: bool = false
## Speed the current knockback started at; the slide eases out from it.
var _knockback_start: float = 0.0
var controls_enabled: bool = true
## A practice dummy: takes no input but still takes hits and damage.
var dummy: bool = false
var combat_paused: bool = false
var running: bool = false
const WALK_SPEED_RATIO := 0.65
var action_timer: float = 0.0
var combat_time: float = 0.0
var attack_connected: bool = false
var current_move: Dictionary = {}
var chain_step: int = 0
var combo_hits: int = 0
var combo_damage: int = 0
var motion_input := MOTIONS.new()
var _buffered_move: String = ""
var _motion_facing: int = 1
var combat_notice: String = ""
var notice_until: float = 0.0
var _combo_attacker: Node = null
var _received_hits: int = 0
var _buffered_direction: int = 0
var _buffered_action: String = ""
var _buffer_remaining: float = 0.0
var _last_tap_dir: int = 0
var _last_tap_time: float = -999.0
var _dash_dir: int = 1
var _jump_direction: float = 0.0
var _last_land_type: String = ""
var _last_land_time: float = -999.0
var _finisher_cooldown_until: float = -999.0
var _flash_tween: Tween
var stamina: float = 100.0
## A landed grab locks both fighters into one throw: the attacker
## (THROWING) runs the clock for both, the victim (THROWN) is carried, and
## the damage lands on the slam, not on the grab.
var throw_partner: Node = null
var throw_time: float = 0.0
var throw_damage: int = 0
var throw_slammed: bool = false
var throw_contact: bool = false
## Mount after a takedown: ground punches thrown, the current swing's time
## left, a press waiting for the swing before it, and when the attacker
## started rising (INF while still mounted).
var ground_hits: int = 0
var ground_timer: float = 0.0
var ground_queued: bool = false
var ground_landed: bool = false
var throw_rise_at: float = INF
var mount_slide_at: float = INF
var _mount_idle: float = 0.0
## The victim of a takedown stays down (KNOCKDOWN) and can't be hit until
## it is back on its feet; time spent down so far.
var knockdown_time: float = 0.0
## Knocked out by a slam: the body stays where it landed.
var thrown_down: bool = false
## How this knockdown ends: "" (stand up in place), "roll" or "late", plus
## an attack pressed while rising, thrown the moment the fighter is up.
var wake_choice: String = ""
## Super meter (0..SUPERS.METER_MAX), the running super's clock, how many of
## its blows have landed, and the rival locked in it.
var super_meter: float = 0.0
var super_time: float = 0.0
var super_hits: int = 0
var super_partner: Node = null
var _super_gap: float = 0.0
var wake_attack: String = ""
var stamina_delay: float = 0.0
var taunt_ready_at: float = 0.0
var throw_tech_until: float = -1.0
## Down held on the ground: the fighter crouches, ducks high blows, guards
## low strikes (with back or guard held) and its punch and kick become the
## rising uppercut and the sweep.
var crouching: bool = false
## Knocked off its feet by a sweep: KNOCKDOWN starts below zero, the fall
## playing out before the fighter lies and gets up as after a throw.
var swept: bool = false
## The swing's whoosh has played for the current strike (it sounds as the
## limb whips through, just before it lands, not when the wind-up starts).
var _swing_heard: bool = false
const SWEEP_FALL := 0.45

## "action" is the style_id of resources/styles/action.tres, the one style
## resource live matches now use for all four rounds. Archived styles
## (karate/muay_thai/boxing/mma) still load in the regression tests, so this
## flag is how stamina, throws, guard breaks and per-fighter moves stay
## opt-in instead of changing behavior for that legacy coverage.
func is_action_fight() -> bool:
	return current_style != null and current_style.style_id == "action"

func spend_stamina(amount: float) -> bool:
	if not is_action_fight():
		return true
	if stamina < amount:
		combat_notice = "CATCH YOUR BREATH"
		notice_until = combat_time + 0.6
		return false
	stamina -= amount
	stamina_delay = 0.65
	return true

func available_moves() -> Dictionary:
	if is_action_fight():
		return ACTION_MOVES.for_fighter(character_profile.id)
	return MOVES.for_style(current_style.style_id if current_style != null else "karate")

const GRAVITY := 2200.0
const DASH_DURATION := 0.16
const JUMP_START_TIME := 0.05
const LAND_TIME := 0.05

func _ready() -> void:
	health = max_health
	input_prefix = "p1_" if player_id == 1 else "p2_"
	hitbox.owner_player = self
	hitbox.set_active(false)
	if style != null:
		apply_style(style)
	_update_animation()

func apply_style(new_style: FightStyle) -> void:
	current_style = new_style
	if new_style == null:
		return
	for property in ["move_speed", "jump_velocity", "punch_damage", "punch_startup_time",
		"punch_active_time", "punch_total_time", "punch_knockback", "kick_damage",
		"kick_startup_time", "kick_active_time", "kick_total_time", "kick_knockback",
		"hook_damage", "hook_startup_time", "hook_active_time", "hook_total_time",
		"hook_knockback", "block_chip_multiplier"]:
		set(property, new_style.get(property))
	# Always start with resource values so bonuses cannot stack between rounds.
	move_speed *= float(character_profile.speed)
	punch_damage += int(character_profile.punch_bonus)
	hook_damage += int(character_profile.punch_bonus)
	kick_damage += int(character_profile.kick_bonus)
	block_chip_multiplier = maxf(0.0, block_chip_multiplier + float(character_profile.chip_bonus))

func apply_character(index: int) -> void:
	character_index = clampi(index, 0, ROSTER.PROFILES.size() - 1)
	character_profile = ROSTER.profile(character_index)
	stamina = character_profile.stamina
	base_color = character_profile.color
	if current_style != null:
		apply_style(current_style)
	if is_node_ready():
		_update_animation()

func _physics_process(delta: float) -> void:
	running = false
	# Capture presses during hit-stop, but pause their expiry and the combat clock
	# so an impact freeze does not swallow the player's follow-up input.
	if controls_enabled and state != State.KO:
		_capture_input()
	if hitstop_remaining > 0.0:
		hitstop_remaining = maxf(0.0, hitstop_remaining - delta)
		return
	combat_time += delta
	stamina_delay = maxf(0.0, stamina_delay - delta)
	if is_action_fight() and controls_enabled and stamina_delay <= 0.0 and state in [State.IDLE, State.WALK, State.JUMP]:
		stamina = minf(character_profile.stamina, stamina + float(character_profile.regen) * delta)
	if combat_time - _last_land_time > (current_style.combo_window if current_style != null else 0.6):
		combo_stacks = 0
	_update_facing()
	if state not in [State.IDLE, State.WALK, State.BLOCK, State.BLOCKSTUN] and not (state in [State.PUNCH, State.KICK] and current_move.get("crouch", false)):
		crouching = false
	var was_grounded := _is_grounded()
	velocity.y += GRAVITY * delta
	# A throw or a super that ends the round plays out to its last frame.
	if (not controls_enabled or state == State.KO) and state not in [State.THROWING, State.SUPER]:
		velocity.x = move_toward(velocity.x, 0.0, braking * delta)
	else:
		match state:
			State.HITSTUN, State.BLOCKSTUN:
				_process_hitstun(delta)
			State.THROWING:
				_process_throw(delta)
			State.THROWN:
				velocity = Vector2.ZERO
			State.KNOCKDOWN:
				_process_knockdown(delta)
			State.SUPER:
				_process_super(delta)
			State.STRUCK:
				velocity = Vector2.ZERO
			State.PUNCH, State.KICK:
				_process_attack(delta)
			State.BLOCK:
				_process_block(delta)
			State.DASH:
				running = _dash_dir == facing
				action_timer -= delta
				velocity.x = _dash_dir * move_speed * (1.85 if _dash_dir == facing else 1.45)
				if action_timer <= 0.0:
					state = State.IDLE
				if _dash_dir == facing:
					_consume_action()
				if Input.is_action_pressed(input_prefix + "block"):
					_enter_block()
			State.JUMP_START:
				action_timer -= delta
				if action_timer <= 0.0:
					velocity.y = jump_velocity
					velocity.x = _jump_direction * move_speed
					state = State.JUMP
					preload("res://scripts/sfx.gd").fire("jump", -8.0)
			State.LAND:
				velocity.x = move_toward(velocity.x, 0.0, braking * delta)
				action_timer -= delta
				if action_timer <= 0.0:
					state = State.IDLE
					_process_move_and_actions(delta)
			_:
				_process_move_and_actions(delta)
	_move_combat_body(delta)
	if not was_grounded and _is_grounded() and state == State.JUMP:
		state = State.LAND
		action_timer = LAND_TIME
		preload("res://scripts/sfx.gd").fire("land", -6.0)
	# Consume before aging: a queued action remains valid on the recovery tick.
	_buffer_remaining -= delta
	if _buffer_remaining <= 0.0:
		_buffered_action = ""
		_buffered_move = ""
	_update_animation()

## Down on the stick or keys: the crouch action, or guard on rigs and
## legacy layouts that have no crouch.
func _down_held() -> bool:
	if InputMap.has_action(input_prefix + "crouch"):
		return Input.is_action_pressed(input_prefix + "crouch")
	return Input.is_action_pressed(input_prefix + "block")

# Spatial hooks let the 3D body share the same combat rules and timing.
func _is_grounded() -> bool:
	return is_on_floor()

func _movement_axis() -> float:
	return Input.get_axis(input_prefix + "left", input_prefix + "right")

func _opponent_distance(other: Node) -> float:
	return absf(global_position.x - other.global_position.x)

func _move_combat_body(_delta: float) -> void:
	move_and_slide()
	global_position.x = clampf(global_position.x, 34.0, 926.0)
	_resolve_body_overlap()

func _resolve_body_overlap() -> void:
	# Rivals are horizontal pushboxes, never floors or moving platforms.
	# Leave room to jump over them, then separate sideways while landing.
	if not is_instance_valid(opponent):
		return
	if absf(global_position.y - opponent.global_position.y) >= 100.0:
		return
	var distance: float = opponent.global_position.x - global_position.x
	var overlap := 38.0 - absf(distance)
	if overlap <= 0.0:
		return
	var side := signf(distance) if absf(distance) > 0.01 else float(facing)
	var own_x := global_position.x
	var other_x: float = opponent.global_position.x
	global_position.x = clampf(own_x - side * overlap * 0.5, 34.0, 926.0)
	var moved := absf(global_position.x - own_x)
	opponent.global_position.x = clampf(other_x + side * (overlap - moved), 34.0, 926.0)
	var remaining: float = 38.0 - absf(opponent.global_position.x - global_position.x)
	if remaining > 0.0:
		global_position.x = clampf(global_position.x - side * remaining, 34.0, 926.0)
	if velocity.x * side > 0.0:
		velocity.x = 0.0

func _capture_input() -> void:
	# Throw tech: tapping Light + Heavy together opens a 0.16s window (checked
	# in take_hit) during which an incoming grapple is escaped instead of landing.
	if Input.is_action_pressed(input_prefix + "punch") and Input.is_action_pressed(input_prefix + "kick") and (Input.is_action_just_pressed(input_prefix + "punch") or Input.is_action_just_pressed(input_prefix + "kick")):
		throw_tech_until = combat_time + 0.16
		if is_action_fight() and state in [State.IDLE, State.WALK, State.BLOCK] and _is_grounded():
			_buffered_action = "grapple"
			_buffered_move = ""
			_buffered_direction = 0
			_buffer_remaining = input_buffer_time
		return
	# Super: buttons 2 and 4 together with a full meter.
	if super_ready() and InputMap.has_action(input_prefix + "rpunch") and Input.is_action_pressed(input_prefix + "rpunch") and Input.is_action_pressed(input_prefix + "rkick") \
			and (Input.is_action_just_pressed(input_prefix + "rpunch") or Input.is_action_just_pressed(input_prefix + "rkick")):
		_buffered_action = "super"
		_buffered_move = ""
		_buffered_direction = 0
		_buffer_remaining = input_buffer_time
		return
	if facing != _motion_facing:
		motion_input.reset()
		_motion_facing = facing
	var horizontal := int(_movement_axis()) * facing
	var down := _down_held()
	motion_input.record((2 + horizontal) if down else (5 + horizontal), combat_time)
	for action in ["jump", "punch", "kick", "rpunch", "rkick"]:
		if InputMap.has_action(input_prefix + action) and Input.is_action_just_pressed(input_prefix + action):
			_buffered_action = action
			_buffer_remaining = input_buffer_time
			_buffered_direction = int(_movement_axis()) * facing
			_buffered_move = motion_input.consume(combat_time) if action in ["kick", "rkick"] else ""
	for direction in [-1, 1]:
		var action: String = "left" if direction < 0 else "right"
		if Input.is_action_just_pressed(input_prefix + action):
			if direction == _last_tap_dir and combat_time - _last_tap_time <= 0.22:
				if state in [State.IDLE, State.WALK] and _is_grounded() and spend_stamina(7.0):
					state = State.DASH
					_dash_dir = direction
					action_timer = DASH_DURATION
				_last_tap_dir = 0
			else:
				_last_tap_dir = direction
			_last_tap_time = combat_time

func _update_facing() -> void:
	# Strikes and jumps commit to their initial facing.
	if opponent != null and state in [State.IDLE, State.WALK, State.BLOCK, State.LAND]:
		var distance: float = opponent.global_position.x - global_position.x
		if absf(distance) > 1.0:
			facing = 1 if distance > 0.0 else -1

func _update_animation() -> void:
	if visual.has_method("sync_pose"):
		visual.sync_pose(self)
	elif visual is AnimatedSprite2D:
		visual.flip_h = facing < 0
		var names := ["idle", "walk", "jump", "punch", "kick", "block", "hitstun", "ko", "block", "walk", "jump", "idle", "punch", "hitstun", "ko", "punch", "hitstun"]
		var anim: String = names[state]
		if state == State.PUNCH and attack_variant == "hook":
			anim = "hook"
		visual.play(anim)
		if state in [State.PUNCH, State.KICK]:
			visual.pause()
			visual.frame = 0 if attack_timer < attack_startup() else (1 if attack_timer < attack_startup() + attack_active_time() else 2)

func _process_move_and_actions(delta: float = 1.0 / 60.0) -> void:
	var direction := _movement_axis()
	if _is_grounded():
		crouching = _down_held() and controls_enabled
		if Input.is_action_pressed(input_prefix + "block"):
			_enter_block()
			return
		if _consume_action():
			return
		if crouching:
			# Down: squat where you stand.
			velocity.x = move_toward(velocity.x, 0.0, braking * delta)
			state = State.IDLE
			return
		running = direction * facing > 0.0 and Input.is_action_pressed(input_prefix + "run")
		var speed := move_speed * (1.0 if running else WALK_SPEED_RATIO)
		if not running and direction * facing < 0.0:
			speed *= backward_speed_ratio
		velocity.x = move_toward(velocity.x, direction * speed, (braking if direction == 0.0 else acceleration) * delta)
		state = State.WALK if absf(velocity.x) > 8.0 else State.IDLE
	else:
		if direction != 0.0:
			velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * 0.12 * delta)
		state = State.JUMP

func _consume_action() -> bool:
	if _buffered_action.is_empty() or not _is_grounded():
		return false
	var action := _buffered_action
	var direction := _buffered_direction
	var command := _buffered_move
	# A neutral (no-direction) buffer continues the current chain; a directional
	# press always starts a fresh directional move instead of linking.
	var next_id := _next_chain_move(action) if direction == 0 else ""
	_buffered_action = ""
	_buffered_move = ""
	_buffer_remaining = 0.0
	if action == "super":
		_start_super_strike()
	elif action == "grapple":
		# Grabs are switched off: the button does nothing.
		if available_moves().has("grapple"):
			_start_style_move("grapple")
	elif action in ["sweep", "crouch_punch"]:
		# Asked for by name (the AI): squat into it.
		if available_moves().has(action):
			_start_style_move(action)
	elif action == "jump":
		crouching = false
		state = State.JUMP_START
		action_timer = JUMP_START_TIME
		_jump_direction = _movement_axis()
	else:
		if crouching and command.is_empty() and available_moves().has("sweep") and state not in [State.PUNCH, State.KICK]:
			# From the crouch: punches rise into the uppercut, kicks sweep.
			_start_style_move("crouch_punch" if action in ["punch", "rpunch"] else "sweep")
		elif not command.is_empty():
			_start_style_move(command, chain_step + 1 if state in [State.PUNCH, State.KICK] else 0)
		elif not next_id.is_empty():
			_start_style_move(next_id, chain_step + 1)
		elif action in ["rpunch", "rkick"]:
			# Buttons 2 and 4: the fighter's right punch / right kick.
			var moves := available_moves()
			var own := "rp" if action == "rpunch" else "rk"
			_start_style_move(own if moves.has(own) else ("cross" if action == "rpunch" else "forward_heavy"))
		else:
			var move_id := "jab" if action == "punch" else "kick"
			if direction > 0:
				move_id = "cross" if action == "punch" else "forward_heavy"
			elif direction < 0:
				move_id = "hook" if action == "punch" else "back_heavy"
			_start_style_move(move_id)
	return true

func _next_chain_move(action: String) -> String:
	if current_move.is_empty() or not attack_connected or chain_step >= 3:
		return ""
	var next: String = current_move.next_light if action == "punch" else (current_move.next_heavy if action == "kick" else "")
	if action == "rpunch":
		next = str(current_move.get("next_rp", ""))
	elif action == "rkick":
		next = str(current_move.get("next_rk", ""))
	if next != "" and not available_moves().has(next):
		return ""
	# Chains are three hits; only a signature finisher may be the fourth.
	if chain_step >= 2 and next != "combo_finish":
		return ""
	return next

func _start_style_move(move_id: String, step: int = 0) -> void:
	var data: Dictionary = available_moves()[move_id]
	# "utility" moves (Kri's taunt, Sarvochcha's feint) deal no damage and never
	# open a hitbox (see _process_attack) — they're on their own cooldown gate.
	if data.get("utility", "") == "taunt" and combat_time < taunt_ready_at:
		combat_notice = "LET THE FISTS TALK"
		notice_until = combat_time + 0.6
		return
	if not spend_stamina(float(data.get("cost", 0.0))):
		return
	if data.get("utility", "") == "taunt":
		taunt_ready_at = combat_time + 5.0
		combat_notice = "IS THAT ALL YOU GOT?"
		notice_until = combat_time + 0.9
	_start_attack(State.KICK if data.kind == "kick" else State.PUNCH, data.pose)
	current_move = data
	chain_step = step
	# The sweep stays down at the floor; everything else stands up.
	crouching = data.get("crouch", false)
	BATTLE_CRY.fire(player_id - 1, false, BATTLE_CRY.move_event(str(character_profile.id), move_id))
	_update_animation()

func move_name() -> String:
	if not current_move.is_empty():
		return str(current_move.name) + (" / FINISHER" if attack_variant == "finisher" else "")
	return attack_variant.capitalize()

func _enter_block() -> void:
	state = State.BLOCK
	block_hold_time = 0.0
	velocity.x = 0.0

func attack_startup() -> float:
	if not current_move.is_empty():
		return current_move.startup
	return hook_startup_time if attack_variant == "hook" else (kick_startup_time if attack_variant in ["kick", "finisher"] else punch_startup_time)

func attack_active_time() -> float:
	if not current_move.is_empty():
		return current_move.active
	return hook_active_time if attack_variant == "hook" else (kick_active_time if attack_variant in ["kick", "finisher"] else punch_active_time)

func attack_duration() -> float:
	if not current_move.is_empty():
		return current_move.startup + current_move.active + current_move.recovery
	# Style data may shorten total duration, but every move still needs recovery.
	var total := hook_total_time if attack_variant == "hook" else (kick_total_time if attack_variant in ["kick", "finisher"] else punch_total_time)
	return maxf(total, attack_startup() + attack_active_time() + 0.05)

func _start_attack(new_state: int, variant: String = "jab") -> void:
	current_move = {}
	chain_step = 0
	hitbox.set_active(false)
	state = new_state
	attack_timer = 0.0
	attack_connected = false
	velocity.x = 0.0
	attack_variant = variant
	# The whoosh waits for the limb to whip through (_process_attack).
	_swing_heard = false
	if variant == "kick" and current_style != null and current_style.has_finisher:
		if _last_land_type == "punch" and combat_time - _last_land_time <= current_style.finisher_window and combat_time >= _finisher_cooldown_until:
			attack_variant = "finisher"
			_finisher_cooldown_until = combat_time + current_style.finisher_cooldown
			_flash(Color(0.85, 0.55, 1.0))
	_update_animation()

func _process_attack(delta: float) -> void:
	attack_timer += delta
	if not _swing_heard and attack_timer >= attack_startup() * 0.6 and current_move.get("utility", "") == "":
		_swing_heard = true
		var swing := "sweep" if attack_variant == "strike_sweep" else ("whoosh_heavy" if state == State.KICK else "whoosh")
		preload("res://scripts/sfx.gd").fire(swing, -6.0)
	velocity.x = move_toward(velocity.x, 0.0, braking * delta)
	var heavy: bool = attack_variant in ["kick", "finisher"]
	var damage: int = kick_damage if heavy else (hook_damage if attack_variant == "hook" else punch_damage)
	var knockback: float = kick_knockback if heavy else (hook_knockback if attack_variant == "hook" else punch_knockback)
	if not current_move.is_empty():
		heavy = current_move.kind == "kick"
		var base: int = punch_damage if current_move.base == "punch" else (hook_damage if current_move.base == "hook" else kick_damage)
		# Scaling is applied by the defender to every uninterrupted combo,
		# including manual links. Early punches retain close-range pressure.
		damage = maxi(1, int(round(base * float(current_move.damage))))
		knockback = (kick_knockback if heavy else punch_knockback) * float(current_move.push)
		velocity.x = facing * float(current_move.lunge) / attack_startup() if attack_timer < attack_startup() else 0.0
	if attack_variant == "finisher":
		damage = int(round(damage * current_style.finisher_damage_mult))
		knockback *= current_style.finisher_knockback_mult
	hitbox.damage = damage + _combo_bonus()
	hitbox.knockback = knockback
	hitbox.attack_type = "kick" if heavy else "punch"
	var reach := 64.0 if heavy else (44.0 if attack_variant == "hook" else 58.0)
	hitbox.position = Vector2(facing * reach, -66.0 if heavy else -88.0)
	if not current_move.is_empty():
		hitbox.position = Vector2(facing * float(current_move.reach), float(current_move.height))
	hitbox.set_active(current_move.get("utility", "").is_empty() and attack_timer >= attack_startup() and attack_timer < attack_startup() + attack_active_time())
	# A fresh buffered press and a confirmed hit are required. Cancels close
	# six frames into recovery; holding an attack never advances the string.
	if not current_move.is_empty():
		var active_end := attack_startup() + attack_active_time()
		var cancel_open: bool = attack_connected and attack_timer >= active_end and attack_timer <= active_end + float(current_move.cancel_window)
		var normal_route: bool = _buffered_move.is_empty() and _buffered_direction == 0 and not _next_chain_move(_buffered_action).is_empty()
		var special_route: bool = not _buffered_move.is_empty() and current_move.special_cancel and chain_step < 2
		if cancel_open and _buffer_remaining > 0.0 and (normal_route or special_route):
			_consume_action()
			return
	# A confirmed jab can cancel into the heavy button once contact ends.
	if current_move.is_empty() and attack_connected and attack_variant == "jab" and _buffered_action == "kick" and attack_timer >= attack_startup() + attack_active_time():
		_consume_action()
		return
	if attack_timer >= attack_duration():
		# Reaching the end of the animation uninterrupted is the payoff for
		# taunting; take_hit clears current_move on interruption, so a hit
		# taken mid-taunt never reaches this branch and grants nothing.
		if current_move.get("utility", "") == "taunt":
			stamina = minf(character_profile.stamina, stamina + 24.0)
		hitbox.set_active(false)
		current_move = {}
		chain_step = 0
		state = State.IDLE
		_process_move_and_actions(delta)

func _combo_bonus() -> int:
	if current_style != null and current_style.combo_damage_step > 0 and combat_time - _last_land_time <= current_style.combo_window:
		return combo_stacks * current_style.combo_damage_step
	return 0

func _on_hit_landed(attack_type: String, continued: bool = false, dealt: int = 0) -> void:
	attack_connected = true
	combo_hits = combo_hits + 1 if continued else 1
	combo_damage = combo_damage + dealt if continued else dealt
	if current_style != null and current_style.combo_damage_step > 0:
		combo_stacks = mini(combo_stacks + 1, current_style.combo_max_stacks - 1) if combat_time - _last_land_time <= current_style.combo_window else mini(1, current_style.combo_max_stacks - 1)
	_last_land_type = attack_type
	_last_land_time = combat_time

func _process_block(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, braking * delta)
	block_hold_time += delta
	crouching = _down_held()
	if not Input.is_action_pressed(input_prefix + "block"):
		state = State.IDLE
		_process_move_and_actions(delta)

func _process_hitstun(delta: float) -> void:
	stun_timer -= delta
	# The push is hardest at the moment of impact and eases into a short
	# creep, like a body absorbing the blow. Braking scales with the speed
	# left, tuned (x0.82) so a hit slides about as far as the old linear stop.
	var remaining := minf(absf(velocity.x) / maxf(_knockback_start, 1.0), 1.0)
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 3.0 * 0.82 * (0.35 + 1.3 * remaining) * delta)
	if state == State.BLOCKSTUN:
		block_hold_time += delta
	if stun_timer <= 0.0:
		if state == State.BLOCKSTUN and Input.is_action_pressed(input_prefix + "block") and _is_grounded():
			# Holding guard through blockstun must not re-arm Karate's parry.
			state = State.BLOCK
			return
		state = State.IDLE if _is_grounded() else State.JUMP
		_process_move_and_actions(delta)

## Returns true only for an unblocked hit; chip and parries cannot grant a cancel.
func take_hit(damage: int, knockback: float, attacker_facing: int, attacker: Node = null, attack_type: String = "punch") -> bool:
	var touch := pending_contact
	pending_contact = {}
	if state in [State.KO, State.THROWN, State.KNOCKDOWN, State.STRUCK] or not (controls_enabled or dummy):
		return false
	last_contact = touch
	var move: Dictionary = attacker.current_move if attacker != null else {}
	var grapple: bool = move.get("kind", "") == "grapple"
	if grapple:
		# Throws lose to jumps, active hitstun, spacing, or a timed two-button tech.
		if not _is_grounded() or state in [State.HITSTUN, State.BLOCKSTUN] or _opponent_distance(attacker) > 64.0:
			return false
		if combat_time <= throw_tech_until:
			combat_notice = "THROW ESCAPE"
			notice_until = combat_time + 0.9
			throw_tech_until = -1.0
			# The clinch breaks: both are shoved apart into a guard reaction,
			# a guarded-hit spark and thud between them.
			attacker.apply_parry_punish()
			hitbox.set_active(false)
			current_move = {}
			state = State.BLOCKSTUN
			stun_timer = 0.2
			velocity.x = attacker_facing * 180.0
			hitstop_remaining = 0.05
			attacker.hitstop_remaining = 0.05
			impact.emit(global_position + Vector2(-attacker_facing * 16.0, -88.0), true, false)
			_update_animation()
			return false
		if attacker != null and attacker.has_method("start_throw"):
			attacker.start_throw(self, damage)
			return true
	var blocked: bool = state in [State.BLOCK, State.BLOCKSTUN] and attacker_facing != facing
	# Holding away from the rival guards grounded strikes without turning
	# the fighter around. Retreat still loses to throws and guard breaks.
	var back_held := _movement_axis() * facing < 0.0
	if is_action_fight() and _is_grounded() and state in [State.IDLE, State.WALK] and back_held and attacker_facing != facing:
		blocked = true
	blocked = blocked and not grapple
	# A low strike gets under a standing guard: only a crouching guard stops it.
	var low: bool = move.get("low", false)
	if blocked and low and not crouching:
		blocked = false
		if attacker != null:
			attacker.combat_notice = "LOW HIT"
			attacker.notice_until = attacker.combat_time + 0.8
	var attacking := state in [State.PUNCH, State.KICK]
	var counter: bool = not blocked and attacking and attack_timer < attack_startup()
	var punish: bool = not blocked and attacking and attack_timer >= attack_startup() + attack_active_time()
	var continued: bool = state == State.HITSTUN and stun_timer > 0.0 and _combo_attacker == attacker
	var parry_window: float = current_style.perfect_block_window if current_style != null else 0.0
	if is_action_fight() and character_profile.id == "anug":
		parry_window = 0.12
	var perfect: bool = blocked and state == State.BLOCK and parry_window > 0.0 and block_hold_time <= parry_window
	var guard_broken := false
	if blocked and not perfect and is_action_fight():
		# Kri's trait is extra guard chip: blocking him drains stamina faster.
		var guard_cost := damage * (1.1 if character_profile.id == "abhi" else 0.6)
		guard_broken = stamina < guard_cost
		stamina = maxf(0.0, stamina - guard_cost)
		stamina_delay = 0.8
		if guard_broken:
			blocked = false
			combat_notice = "GUARD BREAK"
			notice_until = combat_time + 1.0
	hitbox.set_active(false)
	var heavy := attack_type == "kick"
	# The freeze grows with the blow: a jab barely ticks, a big kick or a
	# counter hangs for a beat. Guarded hits stay short and crisp. Both
	# fighters freeze together, so frame advantage is unchanged.
	var force := clampf((damage - 4.0) / 14.0 + (0.15 if heavy else 0.0) + (0.25 if counter else 0.0), 0.0, 1.0)
	var freeze := lerpf(0.04, 0.11, force)
	if blocked:
		freeze = lerpf(0.035, 0.06, force)
	last_hit_height = "mid" if heavy else "high"
	if not move.is_empty():
		var height := float(move.get("height", -88.0))
		last_hit_height = "high" if height <= -80.0 else ("mid" if height < -65.0 else "low")
	# The part the blow actually touched beats the move's nominal height.
	if touch.has("height"):
		last_hit_height = touch.height
	last_hit_force = force
	last_hit_counter = counter
	last_hit_stagger = not blocked and not grapple and (counter or force >= 0.75)
	hitstop_remaining = freeze
	if attacker != null:
		attacker.hitstop_remaining = freeze
	impact.emit(global_position + Vector2(-attacker_facing * 16.0, -66.0 if heavy else -88.0), blocked, heavy)
	if perfect:
		velocity.x = attacker_facing * knockback * 0.15
		_flash(Color(1.0, 0.9, 0.3))
		if attacker != null and attacker.has_method("apply_parry_punish"):
			attacker.apply_parry_punish()
		return false
	# A super's opening strike landed clean: into the cinematic.
	if not blocked and move.get("super", false) and attacker != null and attacker.has_method("start_super"):
		attacker.start_super(self)
		return true
	if attacker != null and attacker.has_signal("strike_connected"):
		attacker.strike_connected.emit(blocked, force)
	var dealt := damage
	# Agasthya's weak knee: unblocked low strikes (height close to the ground,
	# i.e. not a punch/kick aimed at the torso or head) deal 25% extra.
	if is_action_fight() and character_profile.id == "ish" and not blocked and float(move.get("height", -88.0)) >= -65.0:
		damage = roundi(damage * 1.25)
		dealt = damage
	if not blocked:
		motion_input.reset()
		_received_hits = _received_hits + 1 if continued else 1
		_combo_attacker = attacker
		if not move.is_empty():
			var scaling := maxf(0.4, 1.0 - (_received_hits - 1) * 0.15)
			dealt = maxi(1, roundi(damage * scaling * (1.2 if counter else 1.0)))
		if attacker != null and (counter or punish):
			attacker.combat_notice = "COUNTER HIT" if counter else "PUNISH"
			attacker.notice_until = attacker.combat_time + 0.9
	if blocked:
		var chip := block_chip_multiplier
		if heavy and attacker != null and attacker.current_style != null:
			chip += attacker.current_style.kick_chip_bonus
		dealt = int(ceil(damage * chip))
		state = State.BLOCKSTUN
		stun_timer = float(move.blockstun) if not move.is_empty() else (0.12 if heavy else 0.08)
	else:
		state = State.HITSTUN
		stun_timer = float(move.hitstun) if not move.is_empty() else (hitstun_time_heavy if heavy else hitstun_time_light)
		if counter and not move.is_empty():
			stun_timer += 6.0 / 60.0
		if guard_broken:
			stun_timer = maxf(stun_timer, 0.55)
	dealt = scaled_damage(dealt)
	health = maxi(0, health - dealt)
	if not blocked and move.get("knockdown", false) and health > 0 and _is_grounded():
		# Swept off the feet: down on the back, then up again.
		state = State.KNOCKDOWN
		swept = true
		crouching = false
		knockdown_time = -SWEEP_FALL
		wake_choice = ""
		throw_partner = null
		knockback *= 0.35
	_gain_meter(attacker, dealt, blocked)
	velocity.x = attacker_facing * knockback * (0.3 if blocked else (1.3 if last_hit_stagger else 1.0))
	_knockback_start = absf(velocity.x)
	health_changed.emit(health, max_health)
	if not blocked:
		_voice_impact(attacker)
	current_move = {}
	attack_connected = false
	chain_step = 0
	_flash(Color(0.65, 0.85, 1.0) if blocked else Color(1.0, 0.65, 0.55))
	if health <= 0:
		state = State.KO
		hurtbox.set_deferred("monitorable", false)
		# Barely a beat of freeze: the body goes the moment the blow lands.
		hitstop_remaining = minf(hitstop_remaining, 0.03)
		if attacker != null:
			attacker.hitstop_remaining = minf(attacker.hitstop_remaining, 0.03)
		ko.emit()
	_update_animation()
	return not blocked

## Health actually lost to a blow of `amount` (the 3D fight scales it down).
func scaled_damage(amount: int) -> int:
	return amount

## Voices on a blow that landed, only on the big ones: a blow that
## staggers (a counter-hit or a heavy strike) gets the victim's "taking a
## hit" line and the attacker's "got you" line. Ordinary hits stay silent;
## the bank spaces the lines out further (voice_bank.gd EVENT_GAP).
func _voice_impact(attacker: Node) -> void:
	if not last_hit_stagger:
		return
	BATTLE_CRY.fire(player_id - 1, false, "hit")
	if attacker != null:
		BATTLE_CRY.fire(attacker.player_id - 1, false, "landed_hit")

func has_super() -> bool:
	return is_action_fight() and SUPERS.has(str(character_profile.id))

func super_ready() -> bool:
	return has_super() and super_meter >= SUPERS.METER_MAX and state in [State.IDLE, State.WALK, State.BLOCK] and _is_grounded()

## Damage dealt builds the attacker's meter and, a little slower, the
## victim's. Guarded chip builds only a sliver.
func _gain_meter(attacker: Node, dealt: int, blocked: bool) -> void:
	if attacker == null or attacker.get("super_meter") == null or attacker.state == State.SUPER:
		return
	var share := 0.3 if blocked else 1.0
	attacker.super_meter = minf(SUPERS.METER_MAX, attacker.super_meter + dealt * SUPERS.GAIN_DEALT * share)
	super_meter = minf(SUPERS.METER_MAX, super_meter + dealt * SUPERS.GAIN_TAKEN * share)

## The opening strike: the meter is spent whether it lands or not.
func _start_super_strike() -> void:
	super_meter = 0.0
	_start_attack(State.PUNCH, "super")
	current_move = SUPERS.opener(str(character_profile.id))
	chain_step = 0
	_update_animation()

## Locks `victim` into the super: a held freeze while it is announced, then
## the combo plays out on the super's own clock.
func start_super(victim: Node) -> void:
	hitbox.set_active(false)
	state = State.SUPER
	super_partner = victim
	super_time = 0.0
	super_hits = 0
	velocity = Vector2.ZERO
	victim.state = State.STRUCK
	victim.super_partner = self
	victim.stun_timer = 0.4
	victim.velocity = Vector2.ZERO
	victim.hitbox.set_active(false)
	victim.current_move = {}
	victim.attack_connected = false
	victim.chain_step = 0
	victim._combo_attacker = self
	victim._received_hits = 1
	hitstop_remaining = SUPERS.FREEZE
	victim.hitstop_remaining = SUPERS.FREEZE
	combat_notice = str(SUPERS.get_super(str(character_profile.id)).get("name", "SUPER"))
	notice_until = combat_time + 1.6
	_begin_super()
	super_started.emit()
	BATTLE_CRY.fire(player_id - 1, true, "super")
	_update_animation()
	victim._update_animation()

## Spatial hook: the 3D fighter fixes the line the super travels along.
func _begin_super() -> void:
	pass

## Spatial hook: places both fighters along the super for the current time.
func _place_super() -> void:
	pass

func super_clip_time() -> float:
	var data := SUPERS.get_super(str(character_profile.id))
	return minf(float(data.get("start", 0.0)) + super_time, float(data.get("end", 1.0)))

func _process_super(delta: float) -> void:
	var victim: Node = super_partner
	var data := SUPERS.get_super(str(character_profile.id))
	if victim == null or data.is_empty():
		state = State.IDLE
		return
	super_time += delta
	var hits: Array = data.hits
	while super_hits < hits.size() and super_clip_time() >= float(hits[super_hits]):
		# A rival already knocked out takes no more blows; the move finishes.
		if victim.state == State.KO:
			super_hits = hits.size()
			break
		_super_hit(super_hits)
		super_hits += 1
		if hitstop_remaining > 0.0:
			break
	_place_super()
	if super_clip_time() >= float(data.end) and super_hits >= hits.size():
		victim.super_partner = null
		super_partner = null
		current_move = {}
		state = State.IDLE
		if controls_enabled:
			_process_move_and_actions(delta)

## One blow of the super: its damage, an impact and a reaction; the last
## launches the victim (into the railing when it is close).
func _super_hit(index: int) -> void:
	var victim: Node = super_partner
	var data := SUPERS.get_super(str(character_profile.id))
	var last: bool = index == data.hits.size() - 1
	var dealt: int = victim.scaled_damage(data.damage[index])
	victim.health = maxi(0, victim.health - dealt)
	victim.health_changed.emit(victim.health, victim.max_health)
	victim._voice_impact(self)
	combo_hits = index + 1
	combo_damage += dealt
	victim._received_hits = index + 1
	victim.last_contact = {}
	victim.last_hit_height = "high" if index % 2 == 1 else "mid"
	victim.last_hit_force = 1.0 if last else 0.6
	victim.last_hit_counter = false
	victim.last_hit_stagger = last
	victim.stun_timer = 0.4
	var freeze := 0.15 if last else 0.06
	hitstop_remaining = freeze
	victim.hitstop_remaining = freeze
	victim.impact.emit(victim.global_position + Vector2(-facing * 16.0, -88.0), false, last)
	victim._flash(Color(1.0, 0.65, 0.55))
	if victim.health <= 0:
		victim.state = State.KO
		victim.hurtbox.set_deferred("monitorable", false)
		victim.velocity.x = -victim.facing * SUPERS.LAUNCH
		victim.ko.emit()
	elif last:
		victim.state = State.HITSTUN
		victim.stun_timer = SUPERS.LAUNCH_STUN
		victim.velocity.x = -victim.facing * SUPERS.LAUNCH
		victim._knockback_start = SUPERS.LAUNCH
	victim._update_animation()

## Locks `victim` into this fighter's throw. Escapes and range were already
## checked by the victim's take_hit; `damage` is dealt on the slam.
func start_throw(victim: Node, damage: int) -> void:
	BATTLE_CRY.fire(player_id - 1, false, BATTLE_CRY.move_event(str(character_profile.id), "grapple"))
	hitbox.set_active(false)
	state = State.THROWING
	throw_partner = victim
	throw_time = 0.0
	throw_damage = damage
	throw_slammed = false
	throw_contact = false
	ground_hits = 0
	ground_timer = 0.0
	ground_queued = false
	ground_landed = false
	throw_rise_at = INF
	mount_slide_at = INF
	_mount_idle = 0.0
	velocity = Vector2.ZERO
	victim.state = State.THROWN
	victim.throw_partner = self
	victim.throw_time = 0.0
	victim.velocity = Vector2.ZERO
	victim.hitbox.set_active(false)
	victim.current_move = {}
	victim.attack_connected = false
	victim.chain_step = 0
	victim.motion_input.reset()
	victim._combo_attacker = self
	victim._received_hits = 1
	# A short catch on contact; the big freeze is saved for the slam.
	hitstop_remaining = 0.05
	victim.hitstop_remaining = 0.05
	preload("res://scripts/sfx.gd").fire("block", -4.0)
	_begin_throw()
	_update_animation()
	victim._update_animation()

## Spatial hook: the 3D fighter anchors both bodies for the throw path.
func _begin_throw() -> void:
	pass

## Spatial hook: places both bodies along the throw for the current time.
func _place_throw() -> void:
	if throw_partner != null:
		throw_partner.global_position.x = global_position.x + facing * 48.0

func _process_throw(delta: float) -> void:
	var victim: Node = throw_partner
	if victim == null:
		state = State.IDLE
		return
	throw_time += delta
	if victim.state == State.THROWN:
		victim.throw_time = throw_time
	if not throw_contact and throw_time >= THROW.CONTACT_TIME:
		# The shoulder drives into the stomach: a body blow before the fall.
		throw_contact = true
		hitstop_remaining = 0.06
		victim.hitstop_remaining = 0.06
		victim.impact.emit(victim.global_position + Vector2(0.0, -66.0), false, true)
	if not throw_slammed and throw_time >= THROW.SLAM_TIME:
		_slam()
	if throw_time >= THROW.END_TIME and victim.state == State.THROWN:
		victim.state = State.KNOCKDOWN
		victim.knockdown_time = 0.0
	_process_mount(delta)
	_place_throw()
	if throw_time >= throw_rise_at + THROW.RECOVERY_TIME:
		if victim.get("throw_partner") == self:
			victim.throw_partner = null
		throw_partner = null
		current_move = {}
		state = State.IDLE
		if controls_enabled:
			_process_move_and_actions(delta)

## On top of the downed rival: punch presses (queued from the slam on)
## become ground punches; otherwise, or after the last one, rise.
func _process_mount(delta: float) -> void:
	var victim: Node = throw_partner
	if not is_inf(throw_rise_at):
		return
	if current_move.get("ground_pound", false) and throw_slammed and not ground_queued and ground_hits < THROW.GROUND_MAX and _buffered_action in ["punch", "rpunch"]:
		ground_queued = true
		_buffered_action = ""
		_buffer_remaining = 0.0
	if throw_time < THROW.END_TIME:
		return
	# Pinned: the rival stays flat until the attacker gets off.
	if victim.state == State.KNOCKDOWN:
		victim.knockdown_time = 0.0
	if ground_timer > 0.0:
		ground_timer -= delta
		if not ground_landed and THROW.GROUND_PUNCH_TIME - ground_timer >= THROW.GROUND_IMPACT:
			_ground_hit()
		if ground_timer <= 0.0:
			ground_timer = 0.0
			_mount_idle = 0.0
	elif ground_queued and victim.state != State.KO and is_inf(mount_slide_at):
		# First press: slide up onto the chest, then swing.
		mount_slide_at = throw_time
	elif ground_queued and victim.state != State.KO and throw_time - mount_slide_at >= THROW.MOUNT_SLIDE:
		ground_queued = false
		ground_hits += 1
		ground_timer = THROW.GROUND_PUNCH_TIME
		ground_landed = false
		preload("res://scripts/sfx.gd").fire("whoosh", -6.0)
	elif not ground_queued or victim.state == State.KO:
		ground_queued = false
		_mount_idle += delta
		if _mount_idle >= THROW.MOUNT_WAIT or ground_hits >= THROW.GROUND_MAX or victim.state == State.KO:
			throw_rise_at = throw_time

## A ground punch lands on the downed rival; the last one hardest.
func _ground_hit() -> void:
	ground_landed = true
	var victim: Node = throw_partner
	var last := ground_hits >= THROW.GROUND_MAX
	var dealt: int = victim.scaled_damage(THROW.GROUND_DAMAGE[clampi(ground_hits - 1, 0, THROW.GROUND_DAMAGE.size() - 1)])
	victim.health = maxi(0, victim.health - dealt)
	victim.health_changed.emit(victim.health, victim.max_health)
	victim._voice_impact(self)
	combo_hits += 1
	combo_damage += dealt
	victim.last_hit_height = "mid"
	victim.last_hit_force = 0.8 if last else 0.4
	victim.last_hit_stagger = false
	var freeze := 0.08 if last else 0.045
	hitstop_remaining = freeze
	victim.hitstop_remaining = freeze
	victim.impact.emit(victim.global_position + Vector2(0.0, -20.0), false, last)
	victim._flash(Color(1.0, 0.65, 0.55))
	if victim.health <= 0:
		victim.state = State.KO
		victim.thrown_down = true
		victim.hurtbox.set_deferred("monitorable", false)
		victim.ko.emit()

## The victim's back meets the floor: the throw's damage, the heaviest
## freeze in the game and the full impact (shake, dust, camera shove).
func _slam() -> void:
	throw_slammed = true
	var victim: Node = throw_partner
	var dealt: int = victim.scaled_damage(throw_damage)
	victim.health = maxi(0, victim.health - dealt)
	victim.health_changed.emit(victim.health, victim.max_health)
	victim._voice_impact(self)
	combo_damage += dealt
	victim.last_hit_height = "mid"
	victim.last_hit_force = 1.0
	victim.last_hit_counter = false
	victim.last_hit_stagger = false
	hitstop_remaining = 0.13
	victim.hitstop_remaining = 0.13
	victim.impact.emit(victim.global_position + Vector2(0.0, -20.0), false, true)
	victim._flash(Color(1.0, 0.65, 0.55))
	if victim.health <= 0:
		victim.state = State.KO
		victim.thrown_down = true
		victim.hurtbox.set_deferred("monitorable", false)
		victim.ko.emit()

func _process_knockdown(delta: float) -> void:
	velocity = Vector2.ZERO
	# Choices open once the attacker has let go (it rises off a mount).
	var free: bool = (throw_partner == null or not is_inf(throw_partner.throw_rise_at)) and knockdown_time >= 0.0
	var lying: bool = knockdown_time < THROW.LIE_TIME
	if free and lying and wake_choice == "" and controls_enabled:
		if _movement_axis() * facing < 0.0:
			# Roll clear: the get-up starts now, fast, sliding away.
			wake_choice = "roll"
			knockdown_time = THROW.LIE_TIME
			lying = false
		elif Input.is_action_pressed(input_prefix + "block"):
			wake_choice = "late"
	var rate := 1.0
	if wake_choice == "late" and lying:
		rate = THROW.LIE_TIME / (THROW.LIE_TIME + THROW.LATE_EXTRA)
	elif wake_choice == "roll":
		rate = THROW.ROLL_RATE
		_roll_away(THROW.ROLL_DISTANCE * THROW.ROLL_RATE / THROW.GETUP_TIME * delta)
	knockdown_time += delta * rate
	# An attack pressed while rising is held until the fighter is up.
	if not lying and _buffered_action in ["punch", "kick", "rpunch", "rkick"]:
		wake_attack = _buffered_action
		_buffered_action = ""
	if knockdown_time >= THROW.LIE_TIME + THROW.GETUP_TIME:
		knockdown_time = 0.0
		swept = false
		wake_choice = ""
		state = State.IDLE
		if wake_attack != "":
			_buffered_action = wake_attack
			_buffered_direction = 0
			_buffered_move = ""
			_buffer_remaining = input_buffer_time
			wake_attack = ""
		if controls_enabled:
			_process_move_and_actions(delta)

## Spatial hook: slides a rolling fighter `distance` away from its rival.
func _roll_away(distance: float) -> void:
	global_position.x -= facing * distance * 64.0

func apply_parry_punish() -> void:
	if state == State.KO:
		return
	hitbox.set_active(false)
	state = State.HITSTUN
	stun_timer = 0.2
	velocity.x = -facing * 160.0
	_knockback_start = 160.0
	_flash(Color(1.0, 0.9, 0.3))
	_update_animation()

func _flash(color: Color) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	visual.modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual, "modulate", Color.WHITE, 0.15)

func reset_for_new_round() -> void:
	running = false
	stamina = character_profile.stamina
	stamina_delay = 0.0
	taunt_ready_at = 0.0
	throw_tech_until = -1.0
	if _flash_tween != null:
		_flash_tween.kill()
	health = max_health
	state = State.IDLE
	velocity = Vector2.ZERO
	throw_partner = null
	throw_time = 0.0
	throw_slammed = false
	super_meter = 0.0
	super_time = 0.0
	super_hits = 0
	super_partner = null
	knockdown_time = 0.0
	thrown_down = false
	wake_choice = ""
	wake_attack = ""
	hurtbox.set_deferred("monitorable", true)
	hitbox.set_active(false)
	visual.modulate = Color.WHITE
	controls_enabled = true
	combat_paused = false
	hitstop_remaining = 0.0
	attack_timer = 0.0
	stun_timer = 0.0
	action_timer = 0.0
	combat_time = 0.0
	block_hold_time = 999.0
	combo_stacks = 0
	attack_connected = false
	current_move = {}
	chain_step = 0
	combo_hits = 0
	combo_damage = 0
	motion_input.reset()
	_motion_facing = facing
	_buffered_move = ""
	combat_notice = ""
	notice_until = 0.0
	_combo_attacker = null
	_received_hits = 0
	_buffered_direction = 0
	attack_variant = "jab"
	_buffered_action = ""
	_buffer_remaining = 0.0
	_last_tap_dir = 0
	_last_tap_time = -999.0
	_last_land_type = ""
	_last_land_time = -999.0
	_finisher_cooldown_until = -999.0
	_update_facing()
	if visual.has_method("reset_pose"):
		visual.reset_pose()
	_update_animation()
	health_changed.emit(health, max_health)
