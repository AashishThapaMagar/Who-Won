extends RefCounted
## Cinematic supers: a full meter and buttons 2 + 4 together throw the
## opening strike; if it lands, attacker and victim lock into the fighter's
## combo clip, every blow landing at the time it lands in the clip, and the
## last one sends the victim flying (into the railing when it is close).
##
## Blow times are clip seconds where a fist reaches furthest from the hips,
## measured with tools/measure_strike_clips.gd. "clip" is the Fighting
## Animset Pro clip (fighter_models.gd loads it for the fighter).
const SUPERS := {
	"ish": {
		"name": "FLASH HAMMER", "clip": "KB_p_RabbitPunch",
		# The boxer's flurry: left, right, left, and the last right hand.
		"start": 0.15, "hits": [0.27, 0.43, 0.6, 0.93], "end": 1.0,
		"damage": [7, 6, 7, 12], "travel": 0.9,
	},
	"anant": {
		"name": "CROWN BARRAGE", "clip": "KB_Superpunch",
		# The master's charged barrage: the left and right that open it, the
		# driving right, and the closing straight.
		"start": 1.2, "hits": [1.33, 1.47, 2.0, 2.7], "end": 3.3,
		"damage": [6, 6, 7, 13], "travel": 0.6,
	},
	"sab": {
		"name": "IRON QUAKE", "clip": "KB_GroundAttack",
		# The brawler hammers down: right, left, the low right, the slam.
		"start": 0.2, "hits": [0.27, 0.47, 0.73, 1.17], "end": 1.7,
		"damage": [7, 6, 7, 14], "travel": 0.5,
	},
	"bib": {
		"name": "ENDLESS RUSH", "clip": "KB_m_MidRabbitKick_R_combo",
		# Two quick hands, then the rabbit kicks.
		"start": 0.1, "hits": [0.17, 0.33, 0.43, 0.6], "end": 1.0,
		"damage": [5, 6, 7, 12], "travel": 1.0,
	},
	"abhi": {
		"name": "LOUD THUNDER", "clip": "KB_Projectile_5",
		# The showman's double palm: left, right, both hands, the push.
		"start": 0.12, "hits": [0.2, 0.4, 0.63, 1.17], "end": 1.4,
		"damage": [6, 6, 8, 12], "travel": 0.8,
	},
	"anug": {
		"name": "GOAL KICK", "clip": "KB_MidKickStraightLong",
		# Both hands to set it up, then the long straight kick.
		"start": 0.3, "hits": [0.37, 0.5, 0.57], "end": 1.2,
		"damage": [7, 7, 16], "travel": 1.0,
	},
	"sup": {
		"name": "SPIRAL STORM", "clip": "KB_m_HighKick_R_2",
		# Left hand, right hand, left again, and the spinning high kick.
		"start": 0.05, "hits": [0.1, 0.23, 0.33, 0.5], "end": 1.0,
		"damage": [6, 6, 7, 13], "travel": 0.8,
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
