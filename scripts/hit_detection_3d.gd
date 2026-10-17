extends Node3D
## Synchronous shape queries avoid an extra frame of Area3D overlap latency.
##
## The hitbox is generous on purpose (it decides the move's range), so a
## blow it finds must also really touch. For skinned fighters the defender's
## body is a set of capsules on its skeleton (head, trunk, arms, legs) and
## the attacker strikes with the fist past the knuckles, the elbow, the shin
## or the foot. Strikers are swept from last frame's pose to this one, so a
## fast kick can't pass through a body between two frames. A blow that only
## brushes the air isn't a hit yet; it may still land later in its active
## frames as the limb extends.
##
## Where it touched becomes the defender's contact (Player.last_contact): the
## spark sits on that spot, and the reaction follows the part struck, the
## side the blow came from and how fast the limb was travelling.
var fighters: Array = []
var shape := BoxShape3D.new()
## Where a strike's zone starts in front of the attacker's centre (metres).
const NEAR := 0.25
## Air allowed between the two surfaces, in metres: cloth and skin.
const SLACK := 0.03
## A little looser for the follow-ups of a combo already landing (the first
## blow pushes the rival back) and for a super's opening strike, the way
## fighting games keep a string connected.
const COMBO_SLACK := 0.1
const SUPER_SLACK := 0.25
## Body capsules: [from bone, to bone, radius, part].
const BODY := [
	["hips", "neck", 0.15, "torso"],
	["neck", "headtop_end", 0.11, "head"],
	["leftarm", "leftforearm", 0.055, "arm"], ["rightarm", "rightforearm", 0.055, "arm"],
	["leftforearm", "lefthand", 0.05, "arm"], ["rightforearm", "righthand", 0.05, "arm"],
	["leftupleg", "leftleg", 0.085, "leg"], ["rightupleg", "rightleg", 0.085, "leg"],
	["leftleg", "leftfoot", 0.06, "leg"], ["rightleg", "rightfoot", 0.06, "leg"],
]
## Striking parts: [from bone, to bone, radius]. "fist" carries the hand on
## past the wrist to the knuckles; "" is a single joint (the elbow).
const STRIKERS := [
	["lefthand", "fist", 0.05], ["righthand", "fist", 0.05],
	["leftforearm", "", 0.045], ["rightforearm", "", 0.045],
	["leftleg", "leftfoot", 0.055], ["rightleg", "rightfoot", 0.055],
	["leftfoot", "lefttoebase", 0.05], ["rightfoot", "righttoebase", 0.05],
]
## Wrist to knuckles, metres.
const FIST := 0.09
## Each fighter's strikers on the previous physics frame: [[a, b], ...].
var _last_strikes: Dictionary = {}
## The strikers of the last few frames, newest first: when a blow goes live
## it also counts a limb that brushed the rival on its way to full
## extension, so a strike played at natural speed isn't lost between frames.
var _strike_history: Dictionary = {}
const LEAD_FRAMES := 4
static var _bone_cache: Dictionary = {}

func _ready() -> void:
	process_physics_priority = 50
	shape.size = Vector3(0.56, 0.41, 0.46)

func _physics_process(delta: float) -> void:
	for fighter in fighters:
		var hitbox: Area2D = fighter.hitbox
		if not hitbox.active or not fighter.controls_enabled or fighter.combat_paused or fighter.hitstop_remaining > 0.0:
			continue
		# The zone runs from just in front of the attacker out to the move's
		# reach: centred at the full reach, a long kick sailed past a rival
		# standing closer than that (a 1.1 m kick missed at 0.8 m). The limb
		# must still really touch (contact below).
		var far: float = absf(hitbox.position.x) / 64.0 + shape.size.x * 0.5
		var depth: float = maxf(shape.size.x, far - NEAR)
		var center: Vector3 = fighter.body.global_position + fighter.forward * (far - depth * 0.5) + Vector3.UP * -hitbox.position.y / 64.0
		var zone := BoxShape3D.new()
		zone.size = Vector3(depth, shape.size.y, shape.size.z)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = zone
		query.transform = Transform3D(Basis(Vector3.UP, atan2(-fighter.forward.z, fighter.forward.x)), center)
		query.collision_mask = 2
		query.collide_with_areas = true
		query.collide_with_bodies = false
		for found in get_world_3d().direct_space_state.intersect_shape(query):
			var victim: Node = found.collider.get_meta("fighter")
			if victim == fighter or victim in hitbox._already_hit:
				continue
			var continued: bool = victim.state == victim.State.HITSTUN and victim._combo_attacker == fighter
			# Grabs take hold at their own range, and so does a super's opening
			# strike (a cinematic, it shouldn't hang on a fist's exact path);
			# other strikes must connect.
			var grab: bool = fighter.current_move.get("kind", "") == "grapple" or fighter.current_move.get("super", false)
			# Ananta's sweep and spin kick are Meshy forms that lunge, and the
			# lunge is held in place (his hips stay on his spot), so their foot
			# falls short of where the move reaches: they land on a rival in
			# their zone. Both commit him (the sweep guarded low, the kick slow).
			if fighter.character_profile.get("id", "") == "anant" and (fighter.current_move.get("knockdown", false) or str(fighter.attack_variant) == "spin"):
				grab = true
			var touch := {}
			if not grab:
				# A super's opener and a jump-in (its limb's path through the
				# air can't be placed to the centimetre) connect more readily.
				var generous: bool = fighter.current_move.get("super", false) or fighter.current_move.get("air", false) 						or fighter.current_move.get("finisher", false) or fighter.current_move.get("knockdown", false) \
						or str(fighter.attack_variant) == "spin"
				var slack := SUPER_SLACK if generous else (COMBO_SLACK if continued else SLACK)
				# The final boss's strikes are retargeted Meshy forms whose
				# limbs can't be placed to the centimetre: they connect as a
				# landed combo's follow-ups do.
				if fighter.character_profile.get("id", "") == "anant":
					slack = maxf(slack, COMBO_SLACK)
				touch = contact(fighter, victim, slack, _last_strikes.get(fighter, []), delta)
				if touch.is_empty() and fighter.attack_timer <= fighter.attack_startup() + delta * 1.5:
					# First live frame: sweep back over the swing's last frames.
					for older in _strike_history.get(fighter, []):
						touch = contact(fighter, victim, slack, older, delta)
						if not touch.is_empty():
							break
				if touch.is_empty():
					continue
			hitbox._already_hit.append(victim)
			victim.pending_contact = touch
			var previous_health: int = victim.health
			if victim.take_hit(hitbox.damage, hitbox.knockback, 1, fighter, hitbox.attack_type):
				fighter._on_hit_landed(hitbox.attack_type, continued, previous_health - victim.health)
	# Remember this frame's strikers for next frame's sweep. Frozen fighters
	# keep their pose, so their sweep is simply a standing limb.
	for fighter in fighters:
		var rig = _rig(fighter)
		if rig != null:
			_last_strikes[fighter] = _strikers(rig)
			var history: Array = _strike_history.get(fighter, [])
			history.push_front(_last_strikes[fighter])
			if history.size() > LEAD_FRAMES:
				history.resize(LEAD_FRAMES)
			_strike_history[fighter] = history

## Whether any striking limb of `attacker` is touching `victim`'s body.
## True when either fighter has no skinned rig to measure.
static func touching(attacker: Node, victim: Node, slack: float = SLACK) -> bool:
	return not contact(attacker, victim, slack).is_empty()

## Where `attacker` touches `victim`, or {} when nothing does:
## point (on the victim's surface), part ("head", "torso", "arm", "leg"),
## height ("high", "mid", "low" for the reaction), side (+1 the victim's
## left, -1 its right, 0 square on), speed (m/s of the striking limb) and
## direction (the way it was travelling). Fighters without a skinned rig
## always touch, with an empty part.
static func contact(attacker: Node, victim: Node, slack: float = SLACK, previous: Array = [], delta: float = 1.0 / 60.0) -> Dictionary:
	var a = _rig(attacker)
	var v = _rig(victim)
	if a == null or v == null:
		return {"part": ""}
	var body := _body(v)
	if body.is_empty():
		return {"part": ""}
	var strikes := _strikers(a)
	var best_gap := INF
	var best := {}
	for i in strikes.size():
		var strike: Array = strikes[i]
		# The limb where it is now, and the paths its two ends swept since
		# the last frame.
		var paths: Array = [[strike[0], strike[1]]]
		var before: Array = previous[i] if i < previous.size() else []
		if not before.is_empty():
			paths.append([before[0], strike[0]])
			paths.append([before[1], strike[1]])
		for capsule in body:
			for path in paths:
				var closest := _segments(path[0], path[1], capsule[0], capsule[1])
				var gap: float = closest[0].distance_to(closest[1]) - strike[2] - capsule[2]
				if gap < best_gap:
					best_gap = gap
					var travel: Vector3 = (strike[1] - before[1]) if not before.is_empty() else Vector3.ZERO
					best = {"on": closest[1], "toward": closest[0], "radius": capsule[2], "part": capsule[3], "travel": travel}
	if best_gap > slack:
		return {}
	var outward: Vector3 = best.toward - best.on
	var point: Vector3 = best.on + (outward.normalized() * best.radius if outward.length() > 0.001 else Vector3.ZERO)
	var height := "mid"
	match best.part:
		"head":
			height = "high"
		"leg":
			height = "low"
		"arm":
			var neck: float = INF
			for capsule in body:
				if capsule[3] == "head":
					neck = capsule[0].y
			height = "high" if point.y >= neck - 0.05 else "mid"
	var forward: Vector3 = victim.forward if victim.get("forward") != null else Vector3.RIGHT
	var left := Vector3.UP.cross(forward).normalized()
	var across: float = (point - victim.body.global_position).dot(left)
	var travel: Vector3 = best.travel
	return {"point": point, "part": best.part, "height": height,
		"side": signf(across) if absf(across) > 0.05 else 0.0,
		"speed": travel.length() / maxf(delta, 0.001),
		"direction": travel.normalized() if travel.length() > 0.001 else Vector3.ZERO}

## The victim's capsules: [[a, b, radius, part], ...].
static func _body(rig) -> Array:
	var out: Array = []
	for entry in BODY:
		var from = _at(rig, entry[0])
		if from == null:
			continue
		var to = _at(rig, entry[1])
		if to == null and entry[3] == "head":
			var head = _at(rig, "head")
			if head == null:
				continue
			to = head + (head - from).normalized() * 0.16
		if to == null:
			continue
		out.append([from, to, entry[2], entry[3]])
	return out

## The attacker's striking parts this frame, one entry per STRIKERS row (a
## missing bone repeats the nearest joint so the indices stay aligned).
static func _strikers(rig) -> Array:
	var out: Array = []
	for entry in STRIKERS:
		var from = _at(rig, entry[0])
		if from == null:
			from = rig.skeleton.global_position
		var to = from
		if entry[1] == "fist":
			var wrist = _at(rig, entry[0].replace("hand", "forearm"))
			if wrist != null and from.distance_to(wrist) > 0.01:
				to = from + (from - wrist).normalized() * FIST
		elif entry[1] != "":
			var end = _at(rig, entry[1])
			if end != null:
				to = end
		out.append([from, to, entry[2]])
	return out

## A bone's world position by its Mixamo key, or null.
static func _at(rig, key: String):
	var skeleton: Skeleton3D = rig.skeleton
	var id := skeleton.get_instance_id()
	if not _bone_cache.has(id):
		_bone_cache[id] = {}
	var known: Dictionary = _bone_cache[id]
	if not known.has(key):
		known[key] = rig._bone(key)
	var bone: int = known[key]
	if bone < 0:
		return null
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin

## Closest points between segments p1-q1 and p2-q2: [on first, on second].
static func _segments(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Array:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 0.000001 and e <= 0.000001:
		return [p1, p2]
	if a <= 0.000001:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 0.000001:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var denom := a * e - b * b
			s = clampf((b * f - c * e) / denom, 0.0, 1.0) if denom > 0.000001 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return [p1 + d1 * s, p2 + d2 * t]

static func _rig(fighter: Node):
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual == null:
		return null
	var animated = visual.get("animated")
	if animated == null or not animated.active or animated.skeleton == null:
		return null
	return animated
