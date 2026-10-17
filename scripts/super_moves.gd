extends RefCounted
## Cinematic supers: a full meter and buttons 2 + 4 together throw the
## opening strike; if it lands, attacker and victim lock into the fighter's
## combo clip, every blow landing at the time it lands in the clip, and the
## last one sends the victim flying (into the railing when it is close).
##
## Blow times are clip seconds where a fist, knee or foot reaches furthest
## from the hips, measured from each clip. "clip" names the logical clip in
## the fighter's pack (fighter_models.gd).
const SUPERS := {
	"ish": {
		"name": "FLASH HAMMER", "clip": "strike_flying_knee",
		# Flying knee, left, right, then both hands to finish.
		"start": 0.55, "hits": [0.9, 1.33, 1.8, 2.28], "end": 2.62,
		"damage": [7, 6, 7, 12], "travel": 0.9,
	},
	"anant": {
		"name": "CROWN BARRAGE", "clip": "punch_heavy",
		# His Meshy kung fu form: the lunging punch (the opener lands on its
		# way out), the high kick, the straight punch, the closing punch.
		"start": 1.0, "hits": [1.05, 2.75, 3.0, 4.25], "end": 4.55,
		"damage": [6, 6, 7, 13], "travel": 0.6,
	},
}
const METER_MAX := 100.0
## Meter earned per point of damage dealt and taken.
const GAIN_DEALT := 1.2
const GAIN_TAKEN := 1.0
## The opening strike: quick, but it commits (a whiff or a guard leaves the
## attacker open for a long recovery).
const STARTUP := 0.12
const ACTIVE := 0.1
const RECOVERY := 0.65
const REACH := 70.0
## The screen holds still this long as the super is announced.
const FREEZE := 0.45
## Each blow nudges the victim back; the last throws it.
const STEP_BACK := 0.1
const LAUNCH := 620.0
const LAUNCH_STUN := 0.7

static func has(fighter_id: String) -> bool:
	return SUPERS.has(fighter_id)

static func get_super(fighter_id: String) -> Dictionary:
	return SUPERS.get(fighter_id, {})

## The opening strike as a move dictionary, like those in move_catalog.gd.
static func opener(fighter_id: String) -> Dictionary:
	var data := get_super(fighter_id)
	return {"name": data.get("name", "SUPER"), "pose": "super", "kind": "punch", "base": "punch",
		"reach": REACH, "height": -88.0, "startup": STARTUP, "active": ACTIVE, "recovery": RECOVERY,
		"damage": 1.0, "push": 0.0, "lunge": 10.0, "next_light": "", "next_heavy": "",
		"hitstun": 0.3, "blockstun": 0.22, "cancel_window": 0.0, "special_cancel": false,
		"super": true, "cost": 0.0}
