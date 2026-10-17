extends Node
## Drives a Player node the same way a human would: by faking presses on its
## own p1_/p2_ input actions each physics tick, rather than touching Player
## internals. That keeps it decoupled from player.gd entirely.
##
## Reaction/decision timers keep it beatable — it doesn't re-plan every frame,
## and it only reacts to an incoming attack after a short human-like delay.

var fighter: Node
var opponent: Node

## Units between bodies (64 per metre) a jab really reaches across: strikes
## only land when the fist touches (hit_detection_3d.gd).
const ATTACK_RANGE := 72.0
const CLOSE_RANGE := 50.0
const APPROACH_RANGE := 230.0
const BLOCK_REACTION_TIME := 0.14
const DECISION_INTERVAL := 0.32
## Skill by difficulty (relaxed, standard, challenging). Anant, the boss,
## plays one step above the chosen difficulty for these.
const BLOCK_CHANCE := [0.35, 0.65, 0.85]
## Attacking into a rival's whiffed or blocked move while it recovers.
const PUNISH_CHANCE := [0.15, 0.5, 0.85]
## Breaking a grab with the timed escape just before it connects.
const TECH_CHANCE := [0.0, 0.3, 0.6]
## Grabbing a rival who keeps holding guard up close.
const TURTLE_GRAB := [0.2, 0.45, 0.75]
## Ground punches thrown from the mount after a takedown.
const GROUND_PUNCHES := [1, 2, 3]
## Stepping off the line of a heavy strike (3D only, see ai_controller_3d).
const SIDESTEP_CHANCE := [0.0, 0.12, 0.25]
## Firing a ready super when the rival is in reach (per decision).
const SUPER_CHANCE := [0.15, 0.35, 0.6]
## How many blows the AI strings together once a combo lands.
const COMBO_LENGTH := [2, 4, 7]
## Reading a sweep coming and guarding it low.
const LOW_READ := [0.2, 0.6, 0.9]
## Meeting a jump-in with the rising uppercut.
const ANTI_AIR := [0.1, 0.35, 0.65]
## Reaching for the sweep in a decision at striking range.
const SWEEP_CHANCE := [0.08, 0.14, 0.18]
## Jumping in from just outside striking range with an overhead.
const JUMP_IN := [0.06, 0.12, 0.18]
var _air_plan := false
## Getting up from a knockdown: roll clear, stay down, or rise striking.
const WAKE_ROLL := [0.1, 0.3, 0.35]
const WAKE_LATE := [0.0, 0.15, 0.25]
const WAKE_ATTACK := [0.05, 0.2, 0.3]

var _prefix: String = "p2_"
var _reaction_cooldown: float = 0.0
var _decision_timer: float = 0.0
var _held_block: bool = false
var _held_dir: int = 0
var _jump_cooldown: float = 0.0
var _attack_seen_time: float = 0.0
var _combo_reaction: float = 0.0
## One punish / escape roll per rival attack, not one per frame.
var _punish_plan: int = -1
var _tech_judged: bool = false
var _rival_guard_time: float = 0.0
var _ground_delay: float = 0.0
## This knockdown's plan: "" undecided, then "stand", "roll", "late" or "attack".
var _wake_plan: String = ""

func skill() -> int:
	var level: int = MatchSetup.ai_difficulty
	if fighter.character_profile.id == "anant":
		level += 1
	return clampi(level, 0, 2)

func _ready() -> void:
	process_physics_priority = -100
	if fighter != null:
		_prefix = "p1_" if fighter.player_id == 1 else "p2_"

func _physics_process(delta: float) -> void:
	if fighter == null or opponent == null or not is_instance_valid(fighter) or not is_instance_valid(opponent):
		return
	if fighter.state == fighter.State.KO or opponent.state == opponent.State.KO or not fighter.controls_enabled or fighter.combat_paused or not fighter.is_physics_processing():
		_release_all()
		return

	# Locked in a throw or lying down: ground punches or a way to get up.
	if fighter.state in _locked_states():
		if fighter.state != _state(fighter, "KNOCKDOWN"):
			_set_block(false)
			_set_move(0)
		if fighter.state == _state(fighter, "THROWING"):
			_ground_pound(delta)
		elif fighter.state == _state(fighter, "KNOCKDOWN"):
			_wake_up()
		else:
			_wake_plan = ""
		return
	_wake_plan = ""
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	_reaction_cooldown = maxf(0.0, _reaction_cooldown - delta)
	_decision_timer -= delta

	var distance: float = _opponent_distance()
	var abs_distance: float = absf(distance)
	var toward: int = 1 if distance > 0.0 else -1

	# React to an incoming attack: hold guard while it stays in range.
	# Grabs can't be guarded: they're escaped (below) or eaten.
	var rival_grab: bool = opponent.state in [opponent.State.PUNCH, opponent.State.KICK] and opponent.current_move.get("kind", "") == "grapple"
	# A threat from mid wind-up until its active frames end; the recovery
	# after is an opening to punish, not something to keep guarding.
	var opponent_attacking: bool = opponent.state in [opponent.State.PUNCH, opponent.State.KICK] \
		and opponent.attack_timer >= opponent.attack_startup() * 0.5 and not rival_grab \
		and opponent.attack_timer < opponent.attack_startup() + opponent.attack_active_time() + 0.03
	_escape_grab(rival_grab)
	_rival_guard_time = _rival_guard_time + delta if opponent.state in [opponent.State.BLOCK, opponent.State.BLOCKSTUN] else 0.0
	# _attack_seen_time requires an attack to stay visible for a beat before
	# guarding it, rather than reacting on the very first frame it starts.
	_attack_seen_time = _attack_seen_time + delta if opponent_attacking else 0.0
	# Anant is tuned slightly sharper than the regular roster: he reacts to
	# attacks sooner, decides more often, and follows a landed hit into the
	# command ender rather than only jabbing — but with no stat or HP edge.
	var boss: bool = fighter.character_profile.id == "anant"
	var reaction_scale: float = [1.55, 1.0, 0.8][MatchSetup.ai_difficulty]
	# After a landed hit, wait a beat (matching a human's reaction) then
	# continue the chain, same as a buffered player input would.
	if fighter.attack_connected and fighter.state in [fighter.State.PUNCH, fighter.State.KICK]:
		_combo_reaction += delta
		var length: int = COMBO_LENGTH[skill()] + (4 if boss and skill() == 2 else 0)
		if _combo_reaction > 0.07 * reaction_scale and fighter.chain_step < length and fighter._buffered_action.is_empty():
			# Mixes punches and kicks; the last blow is the heavy one (the
			# finisher once the string is deep enough). Ananta on the hardest
			# setting goes for his twelve.
			var last: bool = fighter.chain_step >= length - 1
			_request_move("kick" if last or randf() < 0.3 else "jab")
			_combo_reaction = -0.3
	else:
		_combo_reaction = 0.0
	var can_engage_guard: bool = fighter.state in [fighter.State.IDLE, fighter.State.WALK, fighter.State.BLOCK]
	if opponent_attacking and _attack_seen_time >= (0.12 if boss else 0.18) * reaction_scale and abs_distance < ATTACK_RANGE + 24.0 and can_engage_guard:
		if not _held_block and _reaction_cooldown <= 0.0:
			if randf() < BLOCK_CHANCE[skill()]:
				_set_block(true)
				# A sweep has to be guarded crouching.
				_set_crouch(opponent.current_move.get("low", false) and randf() < LOW_READ[skill()])
			_reaction_cooldown = BLOCK_REACTION_TIME
	elif _held_block and (not opponent_attacking or abs_distance > ATTACK_RANGE + 24.0):
		_set_block(false)

	if _held_block:
		_set_move(0)
		return
	_set_crouch(false)
	# Jumping in: strike as the arc comes down into range.
	if _air_plan and fighter.state == fighter.State.JUMP:
		if abs_distance < ATTACK_RANGE + 30.0 and fighter.velocity.y > -250.0:
			_air_plan = false
			_request_move("jump_kick" if randf() < 0.6 else "jump_punch")
			return
	elif fighter._is_grounded() and fighter.state != fighter.State.JUMP_START:
		_air_plan = false
	# A rival jumping in close: meet it with the uppercut.
	if opponent.state == opponent.State.JUMP and abs_distance < ATTACK_RANGE + 40.0 and _reaction_cooldown <= 0.0 			and fighter.state in [fighter.State.IDLE, fighter.State.WALK] and fighter.available_moves().has("crouch_punch"):
		_reaction_cooldown = 0.6
		if randf() < ANTI_AIR[skill()]:
			_request_move("crouch_punch")
			return
	if _try_evade(opponent_attacking, abs_distance):
		return
	if _punish(abs_distance):
		return
	# A downed rival can't be hit: wait at striking range, and on the
	# hardest setting time a blow for the moment it stands.
	if opponent.state == _state(opponent, "KNOCKDOWN"):
		_set_move(toward if abs_distance > ATTACK_RANGE else (-toward if abs_distance < CLOSE_RANGE else 0))
		var rising: float = opponent.knockdown_time - (opponent.THROW.LIE_TIME + opponent.THROW.GETUP_TIME)
		if skill() == 2 and rising > -0.12 and abs_distance <= ATTACK_RANGE and fighter.state in [fighter.State.IDLE, fighter.State.WALK]:
			_request_move("kick")
		return

	if _decision_timer > 0.0:
		return
	_decision_timer = DECISION_INTERVAL + randf() * 0.25
	_decision_timer *= reaction_scale
	if boss:
		_decision_timer *= 0.7
	# Low on stamina: retreat instead of attacking into a possible guard break.
	if fighter.stamina < 18.0:
		_set_block(false)
		_set_move(-toward if abs_distance < 180.0 else 0)
		return

	if abs_distance > APPROACH_RANGE and _jump_cooldown <= 0.0 and randf() < 0.15:
		_tap(_prefix + "jump")
		_jump_cooldown = 1.8
	elif abs_distance > ATTACK_RANGE + 20.0 and abs_distance < 190.0 and _jump_cooldown <= 0.0 			and fighter.available_moves().has("jump_kick") and randf() < JUMP_IN[skill()]:
		_set_move(toward)
		_tap(_prefix + "jump")
		_jump_cooldown = 2.5
		_air_plan = true
		return

	if abs_distance > ATTACK_RANGE:
		_set_move(toward)
	elif abs_distance < CLOSE_RANGE and randf() < 0.3:
		_set_move(-toward)
	else:
		_set_move(0)
		if fighter.has_method("super_ready") and fighter.super_ready() and abs_distance <= ATTACK_RANGE * 0.8 and randf() < SUPER_CHANCE[skill()]:
			_request_move("super")
			return
		if fighter.state in [fighter.State.IDLE, fighter.State.WALK] and randf() < 0.6:
			var move_id := "jab"
			# Mahabali's forward_heavy is his grab, so he reaches for it in close
			# range; Kri's back_heavy is his taunt, used to bank stamina
			# only when he's not already flush against the opponent.
			var grab_chance: float = 0.5 if fighter.character_profile.id == "sab" else 0.22
			# A rival hiding behind its guard gets grabbed.
			if _rival_guard_time > 0.45:
				grab_chance = maxf(grab_chance, TURTLE_GRAB[skill()])
			if fighter.available_moves().has("grapple") and abs_distance < 58 and randf() < grab_chance:
				move_id = "grapple"
			elif fighter.character_profile.id == "abhi" and fighter.stamina < 55 and abs_distance > 85:
				move_id = "back_heavy"
			elif fighter.available_moves().has("sweep") and randf() < SWEEP_CHANCE[skill()]:
				move_id = "sweep"
			elif randf() < 0.35:
				move_id = "drive" if randf() < 0.5 else "breaker"
			elif randf() < 0.4:
				move_id = "kick"
			_request_move(move_id)

func _opponent_distance() -> float:
	return opponent.global_position.x - fighter.global_position.x

## A State value by name, or -1 on fighters built before that state existed.
func _state(who: Node, name: String) -> int:
	return who.State.get(name, -1)

func _locked_states() -> Array:
	return [_state(fighter, "THROWING"), _state(fighter, "THROWN"), _state(fighter, "KNOCKDOWN"), _state(fighter, "SUPER"), _state(fighter, "STRUCK")]

## Picks how to get up once per knockdown and holds the matching input:
## back to roll, guard to stay down, an attack while rising.
func _wake_up() -> void:
	if _wake_plan == "":
		var roll: float = randf()
		var level := skill()
		if roll < WAKE_ROLL[level]:
			_wake_plan = "roll"
		elif roll < WAKE_ROLL[level] + WAKE_LATE[level]:
			_wake_plan = "late"
		elif roll < WAKE_ROLL[level] + WAKE_LATE[level] + WAKE_ATTACK[level]:
			_wake_plan = "attack"
		else:
			_wake_plan = "stand"
	var away: int = -1 if _opponent_distance() > 0.0 else 1
	match _wake_plan:
		"roll":
			_set_move(away)
		"late":
			_set_block(true)
		"attack":
			if fighter.knockdown_time > fighter.THROW.LIE_TIME and fighter.wake_attack == "":
				_request_move("kick")

## Ground punches from the mount, spaced like a human pressing the button.
func _ground_pound(delta: float) -> void:
	_ground_delay -= delta
	if not fighter.current_move.get("ground_pound", false) or not fighter.throw_slammed:
		return
	if fighter.ground_hits >= GROUND_PUNCHES[skill()] or fighter.ground_queued or fighter.ground_timer > 0.0 or _ground_delay > 0.0:
		return
	fighter._buffered_action = "punch"
	fighter._buffer_remaining = fighter.input_buffer_time
	_ground_delay = 0.12 + randf() * 0.1

## The timed escape: pressed once, a moment before the rival's grab lands.
func _escape_grab(rival_grab: bool) -> void:
	if not rival_grab:
		_tech_judged = false
		return
	if _tech_judged or opponent.attack_timer < opponent.attack_startup() - 0.1:
		return
	_tech_judged = true
	if randf() < TECH_CHANCE[skill()]:
		fighter.throw_tech_until = fighter.combat_time + 0.16

## Attacks into a rival stuck in the recovery of a whiffed or guarded move,
## stepping in first when it whiffed just out of reach. Decided once per
## rival attack: _punish_plan is -1 undecided, 0 let it go, 1 punishing.
func _punish(abs_distance: float) -> bool:
	var recovering: bool = opponent.state in [opponent.State.PUNCH, opponent.State.KICK] and opponent.attack_timer >= opponent.attack_startup() + opponent.attack_active_time()
	if not recovering:
		_punish_plan = -1
		return false
	if _punish_plan == 0 or fighter.state not in [fighter.State.IDLE, fighter.State.WALK, fighter.State.BLOCK]:
		return false
	# Only worth it if the blow lands before the rival can act again.
	var left: float = opponent.attack_duration() - opponent.attack_timer
	var reachable: bool = abs_distance <= ATTACK_RANGE or (abs_distance < ATTACK_RANGE + 70.0 and left > 0.35)
	if left < fighter.attack_startup() + 0.04 or not reachable:
		return false
	if _punish_plan == -1:
		_punish_plan = 1 if randf() < PUNISH_CHANCE[skill()] else 0
		if _punish_plan == 0:
			return false
	_set_block(false)
	if abs_distance > ATTACK_RANGE:
		_set_move(1 if _opponent_distance() > 0.0 else -1)
		return true
	_set_move(0)
	_request_move("jab")
	_punish_plan = 0
	return true

## Spatial hook: 3D fighters may step off the line of a heavy strike.
func _try_evade(_attacking: bool, _abs_distance: float) -> bool:
	return false

func _request_move(id: String) -> void:
	# AI decisions enter the same expiring buffer and hit-confirm rules as input.
	fighter._buffered_action = id if id in ["grapple", "super", "sweep", "crouch_punch"] else ("punch" if id in ["jab", "jump_punch"] else "kick")
	fighter._buffered_direction = 1 if id == "forward_heavy" else (-1 if id == "back_heavy" else 0)
	fighter._buffered_move = id if id in ["drive", "breaker"] else ""
	fighter._buffer_remaining = fighter.input_buffer_time

func _exit_tree() -> void:
	_release_all()

func _set_move(direction: int) -> void:
	if direction == _held_dir:
		return
	Input.action_release(_prefix + "left")
	Input.action_release(_prefix + "right")
	if direction < 0:
		Input.action_press(_prefix + "left")
	elif direction > 0:
		Input.action_press(_prefix + "right")
	_held_dir = direction

func _set_block(active: bool) -> void:
	_held_block = active
	if active:
		Input.action_press(_prefix + "block")
	else:
		Input.action_release(_prefix + "block")
		_set_crouch(false)

## Holds down (crouch) where the layout has it.
func _set_crouch(active: bool) -> void:
	if not InputMap.has_action(_prefix + "crouch"):
		return
	if active:
		Input.action_press(_prefix + "crouch")
	else:
		Input.action_release(_prefix + "crouch")

func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)

func _release_all() -> void:
	for suffix in ["left", "right", "block", "crouch", "jump", "punch", "kick", "far", "near"]:
		if InputMap.has_action(_prefix + suffix):
			Input.action_release(_prefix + suffix)
	_held_dir = 0
	_held_block = false
