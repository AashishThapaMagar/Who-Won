extends "res://scripts/ai_controller.gd"

func _ready() -> void:
	super._ready()
	_prefix = fighter.input_prefix

var _evade_time: float = 0.0
var _evade_judged: bool = false

func _opponent_distance() -> float:
	# AI forward/back inputs follow the opponent around the ring.
	return fighter._opponent_distance(opponent)

## Sidesteps a committed heavy strike (a kick or a heavy punch) instead of
## guarding it, holding the step just long enough to clear the blow.
func _try_evade(attacking: bool, abs_distance: float) -> bool:
	if _evade_time > 0.0:
		_evade_time -= get_physics_process_delta_time()
		if _evade_time <= 0.0:
			Input.action_release(_prefix + "far")
			Input.action_release(_prefix + "near")
		return true
	var heavy: bool = attacking and (opponent.state == opponent.State.KICK or opponent.current_move.get("base", "") != "punch")
	if not heavy:
		_evade_judged = false
		return false
	if _evade_judged or abs_distance > ATTACK_RANGE + 24.0 or fighter.state not in [fighter.State.IDLE, fighter.State.WALK]:
		return false
	_evade_judged = true
	if randf() >= SIDESTEP_CHANCE[skill()]:
		return false
	_set_move(0)
	# Step off the line of the blow, either way.
	Input.action_press(_prefix + ["near", "far"][randi() % 2])
	_evade_time = 0.3
	return true
