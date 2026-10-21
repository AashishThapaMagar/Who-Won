extends RefCounted
## Timing and travel of the paired takedown, shared by the combat clock
## (player.gd / player_3d.gd) and the animated model (fighter_animated.gd).
##
## The throw plays the Mixamo "double leg takedown" pair: the attacker's and
## the victim's clips were authored together, so both are scrubbed with one
## clock. Clips play with their hips pinned in place (see _pin_hips), and the
## physics bodies instead travel along the hip paths sampled below, which is
## what keeps the two models locked together through the slam.

## Clip seconds where the throw starts (the grab's impact frame), where the
## victim's back meets the floor, and where both bodies have settled. Throws
## are switched off (action_moves.gd); kept for when they return.
const CLIP_START := 0.9
## The attacker's shoulder meets the rival's body.
const CLIP_CONTACT := 1.05
const CLIP_SLAM := 1.62
const CLIP_END := 2.45
## Clip seconds per combat second. The fight runs at COMBAT_TEMPO 0.8, so
## 1.5 plays the pair a little faster than it was captured.
const RATE := 1.5
## Combat seconds after the grab connects.
const CONTACT_TIME := (CLIP_CONTACT - CLIP_START) / RATE
const SLAM_TIME := (CLIP_SLAM - CLIP_START) / RATE
const END_TIME := (CLIP_END - CLIP_START) / RATE
## The attacker rises off the downed rival and steps back to a safe gap.
const RECOVERY_TIME := 0.4
const RECOVERY_GAP := 0.78
## Hip-to-hip distance once the attacker is driven on top of the rival.
const END_GAP := 0.45
## The victim stays down, then plays the get-up clip from GETUP_START to
## GETUP_END (the part where it actually rises) over GETUP_TIME.
const LIE_TIME := 0.35
const GETUP_TIME := 0.9
const GETUP_START := 3.9
const GETUP_END := 5.9
const STEP := 0.05
## Getting up: hold back while down to roll clear (the get-up plays at
## ROLL_RATE while the body slides ROLL_DISTANCE metres away), hold guard
## to stay down LATE_EXTRA longer, or press an attack while rising to
## strike the moment the fighter is up.
const ROLL_RATE := 2.0
const ROLL_DISTANCE := 1.5
const LATE_EXTRA := 0.45
## Ground punches from the mount (fighters whose grapple has ground_pound):
## each press throws one, up to GROUND_MAX, landing GROUND_IMPACT into a
## GROUND_PUNCH_TIME swing. Left alone for MOUNT_WAIT, the attacker rises.
const GROUND_MAX := 3
const GROUND_PUNCH_TIME := 0.3
const GROUND_IMPACT := 0.13
const GROUND_DAMAGE := [4, 4, 7]
const MOUNT_WAIT := 0.22
## Before the first punch the attacker slides up from the hips to the chest
## (MOUNT_ADVANCE metres over MOUNT_SLIDE seconds) so the punches reach the face.
const MOUNT_ADVANCE := 0.55
const MOUNT_SLIDE := 0.14
## Hip travel in metres from CLIP_START, every STEP clip seconds, along each
## fighter's own facing: the attacker drives forward, the victim is carried
## backward (away from the attacker).
const ATTACKER := [0.0, 0.098, 0.19, 0.264, 0.337, 0.405, 0.449, 0.488, 0.542, 0.613, 0.691,
	0.776, 0.869, 0.97, 1.075, 1.179, 1.282, 1.382, 1.485, 1.593, 1.694, 1.768, 1.829, 1.889,
	1.946, 1.997, 2.043, 2.085, 2.12, 2.145, 2.167, 2.184]
const VICTIM := [0.0, 0.044, 0.106, 0.172, 0.231, 0.294, 0.365, 0.437, 0.501, 0.563, 0.629,
	0.705, 0.788, 0.875, 0.956, 1.018, 1.074, 1.133, 1.191, 1.234, 1.262, 1.289, 1.312, 1.319,
	1.316, 1.306, 1.295, 1.286, 1.281, 1.282, 1.286, 1.293]

static func clip_time(throw_time: float) -> float:
	return minf(CLIP_START + throw_time * RATE, CLIP_END)

## Travel at a throw time, linearly between samples.
static func travel(table: Array, throw_time: float) -> float:
	var at := (clip_time(throw_time) - CLIP_START) / STEP
	var i := clampi(int(at), 0, table.size() - 2)
	return lerpf(table[i], table[i + 1], clampf(at - i, 0.0, 1.0))
