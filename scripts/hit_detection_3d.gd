extends Node3D
## Synchronous shape queries avoid an extra frame of Area3D overlap latency.
##
## The hitbox is generous on purpose (it decides the move's range), so a
## blow it finds must also really touch: for skinned fighters, a fist, knee
## or foot of the attacker has to be within CONTACT of the defender's body
## (hips, spine, neck or head joints). A blow that would only brush the air
## isn't a hit yet; it may still land later in its active frames as the
## limb extends.
var fighters: Array = []
var shape := BoxShape3D.new()
## Metres from a limb joint to a body joint that counts as touching: the
## thickness of a fist or foot plus the torso around the spine.
const CONTACT := 0.27
## A little looser for the follow-ups of a combo already landing (the first
## blow pushes the rival back half a step) and for a super's opening strike,
## the way fighting games keep a string connected.
const COMBO_CONTACT := 0.42
## Bodies this close (metres between centres) are chest to chest: any strike
## connects, whatever the clip's limb is doing (a spinning kick's foot can
## be mid-swing behind the fighter on the active frame).
const CLINCH := 0.75
const LIMBS := ["lefthand", "righthand", "leftforearm", "rightforearm", "leftfoot", "rightfoot", "leftleg", "rightleg"]
const BODY := ["hips", "spine", "spine1", "spine2", "neck", "head"]

func _ready() -> void:
	process_physics_priority = 50
	shape.size = Vector3(0.56, 0.41, 0.46)

func _physics_process(_delta: float) -> void:
	for fighter in fighters:
		var hitbox: Area2D = fighter.hitbox
		if not hitbox.active or not fighter.controls_enabled or fighter.combat_paused or fighter.hitstop_remaining > 0.0:
			continue
		var center: Vector3 = fighter.body.global_position + fighter.forward * absf(hitbox.position.x) / 64.0 + Vector3.UP * -hitbox.position.y / 64.0
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(Vector3.UP, atan2(-fighter.forward.z, fighter.forward.x)), center)
		query.collision_mask = 2
		query.collide_with_areas = true
		query.collide_with_bodies = false
		for contact in get_world_3d().direct_space_state.intersect_shape(query):
			var victim: Node = contact.collider.get_meta("fighter")
			if victim == fighter or victim in hitbox._already_hit:
				continue
			# Grabs take hold at their own range; strikes must connect.
			var grab: bool = fighter.current_move.get("kind", "") == "grapple"
			var reach := CONTACT
			if fighter.current_move.get("super", false) or (victim.state == victim.State.HITSTUN and victim._combo_attacker == fighter):
				reach = COMBO_CONTACT
			if not grab and not touching(fighter, victim, reach):
				continue
			hitbox._already_hit.append(victim)
			var continued: bool = victim.state == victim.State.HITSTUN and victim._combo_attacker == fighter
			var previous_health: int = victim.health
			if victim.take_hit(hitbox.damage, hitbox.knockback, 1, fighter, hitbox.attack_type):
				fighter._on_hit_landed(hitbox.attack_type, continued, previous_health - victim.health)

## Whether any striking limb of `attacker` is touching `victim`'s body.
## True when either fighter has no skinned rig to measure.
static func touching(attacker: Node, victim: Node, reach: float = CONTACT) -> bool:
	var a = _rig(attacker)
	var v = _rig(victim)
	if a == null or v == null:
		return true
	if attacker.body.global_position.distance_to(victim.body.global_position) <= CLINCH:
		return true
	var body: Array = []
	for key in BODY:
		var bone: int = v._bone(key)
		if bone >= 0:
			body.append(v.skeleton.global_transform * v.skeleton.get_bone_global_pose(bone).origin)
	if body.is_empty():
		return true
	for key in LIMBS:
		var bone: int = a._bone(key)
		if bone < 0:
			continue
		var at: Vector3 = a.skeleton.global_transform * a.skeleton.get_bone_global_pose(bone).origin
		for point in body:
			if at.distance_to(point) <= reach:
				return true
	return false

static func _rig(fighter: Node):
	var visual: Node = fighter.get_node_or_null("Visual")
	if visual == null:
		return null
	var animated = visual.get("animated")
	if animated == null or not animated.active or animated.skeleton == null:
		return null
	return animated
