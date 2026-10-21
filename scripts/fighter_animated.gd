extends RefCounted
## Skinned, animated stand-in for the procedural fighter rig. Owned by
## fighter_visual_3d.gd: when fighter_models.gd has an enabled entry for the
## fighter, the character scene is placed where the procedural model is,
## that model is hidden, and a clip is chosen every frame from the fighter's
## combat state. Combat, hit detection and timings are untouched.
##
## Attacks are scrubbed rather than played: the fighter's own attack_timer
## picks the frame, so the blow lands exactly on the active frames, and
## hitstop or the pause menu freeze it for free. Loops are advanced by hand
## each frame (frozen at speed 0), then the guard overlay is applied.
##
## Guard overlay: while stepping, backing up, sidestepping or dashing, the
## spine, arms and head keep the boxing guard from the idle clip and only the
## legs use the locomotion clip, the way fighting games layer upper and lower
## body. Locomotion clips play at the speed that matches the fighter's real
## ground speed (measured from how far each clip travels) so feet don't skate.
const MODELS := preload("res://scripts/fighter_models.gd")
const THROW := preload("res://scripts/throw_data.gd")
const SUPERS := preload("res://scripts/super_moves.gd")
## Missing logical clips fall back along these links until one exists.
const FALLBACK := {
	"walk_back": "walk", "sidestep": "walk", "run": "walk", "dash": "run", "backdash": "walk_back",
	"sidestep_left": "sidestep", "sidestep_right": "sidestep", "victory": "taunt", "uppercut": "punch_heavy",
	"land": "idle", "block_hit": "block", "block": "idle", "hit_heavy": "hit",
	"hit": "idle", "punch_heavy": "jab", "kick_spin": "kick", "kick_front": "kick", "grapple": "jab",
	"taunt": "idle", "jump": "idle", "ko": "idle", "kick": "jab", "jab": "idle",
	"cross": "punch_heavy", "hook": "punch_heavy",
}
## Attack variants (from move data poses) that use the heavy-punch clip.
const HEAVY_PUNCHES := ["cross", "hook", "rear_hook", "uppercut", "overhand", "backfist", "body_hook"]
const LOOPING := ["idle", "walk", "walk_back", "sidestep", "sidestep_left", "sidestep_right", "run", "dash", "backdash", "block", "injured", "crouch", "crouch_block"]
## Movement that keeps the guard up on the upper body.
const GUARDED := ["walk", "walk_back", "sidestep", "sidestep_left", "sidestep_right", "dash", "backdash"]
## Bones the guard overlay drives (substring match on the bone name).
const UPPER_BODY := ["Spine", "Neck", "Head", "Shoulder", "Arm", "Hand"]
## Playback speed limits for locomotion: beyond these the legs look frantic
## (too fast) or floaty (too slow), so a little foot slide is accepted.
const MOVE_SPEED_RANGE := {"walk": [0.45, 2.2], "walk_back": [0.45, 2.2], "sidestep": [0.45, 2.2],
	"sidestep_left": [0.45, 2.2], "sidestep_right": [0.45, 2.2],
	"run": [0.55, 2.0], "injured": [0.7, 1.6], "dash": [1.0, 2.2], "backdash": [1.0, 2.4]}
## Health fraction at or below which forward movement limps.
const INJURED_HEALTH := 0.25
## Strikes thrown in the air: their clips' own leap is flattened, the
## jump's physics carries the body.
const AIR_STRIKES := ["KB_JumpPunch", "KB_Jump_Loop2Kick"]
## Attack-like clips driven by the fighter's attack timer (plus every pack
## strike a move names, "KB_...": see _is_strike).
const SCRUBBED := ["jab", "cross", "hook", "punch_heavy", "uppercut", "kick", "kick_spin", "kick_front", "grapple", "taunt", "finisher"]
## Pack bone keys (see _bone_key) worn by another bone of this skeleton: the
## pack's chest is Spine1, which carries the shoulders, as Mixamo's Spine2 does.
const PACK_BONES := {"spine1": "spine2", "root": ""}
## Share of the pack's collarbone roll the bodies wear (see _add_pack_clips).
const SHOULDER_ROLL := 0.45
var visual: Node
var root: Node3D
var character: Node3D
var player: AnimationPlayer
var config: Dictionary = {}
var clip_names: Dictionary = {}
var current := ""
var active := false
var _last_state := -1
## Set from the fighter's impact signal: kicks land as heavy hits.
var last_hit_heavy := false
## A hit landed this frame: the reaction restarts even mid-hitstun, so every
## blow of a combo gets its own flinch.
var _react := false
var _jump_rate := 1.0
## Metres the attacker is stepped toward the rival so the striking fist or
## foot actually meets the body (visual only; see _reach_step).
var _reach := 0.0
## Horizontal world offset of the knockout clip's hips at its start.
var _ko_shift := Vector3.ZERO
var _ko_measure := false
var _last_hips := Vector3.ZERO
const REACTIONS := ["hit", "hit_heavy", "block_hit", "hit_head", "hit_head_alt", "hit_head_heavy", "hit_body", "hit_body_alt", "hit_side", "hit_liver"]
## Rigs with their own reaction set (see fighter_models.gd) pick one by
## where and how hard each blow landed; picked on impact, held for the stun.
var _reaction := ""
var _head_flip := false
var _body_flip := false
## Upper-body rotation tracks of the strike clips, for ground punches thrown
## over the kneeling mount pose: {clip: [[track, bone], ...]}.
var _overlay_tracks := {}
## Distance from the rival's chest bone at which a strike reads as touching.
const CONTACT := 0.16
## The step never brings the two bodies nearer than BODY_GAP (hips to hips,
## metres): stepping in from close range drove the attacker into the
## rival's body; from further out it still closes the distance.
const MAX_REACH_STEP := 0.3
const BODY_GAP := 0.58
## Metres per second each locomotion clip travels at normal speed, keyed by
## animation name (measured before its hips are pinned).
var clip_pace: Dictionary = {}
var _react_speed := 0.0
## The reaction still finishing after the stun ended ("" when none): a
## fighter left standing plays out the rest of the flinch.
var _tail := ""
## Fastest a reaction clip is played to fit a short stun; the rest of it
## plays out as the tail.
const REACT_MAX_SPEED := 1.5
var skeleton: Skeleton3D
var guard_clip: Animation
## [track, bone] pairs of the idle clip's upper-body rotation tracks.
var guard_tracks: Array = []
var guard_weight := 0.0
## Cutscenes (story_dialogue.gd) pose a fighter directly: this logical clip
## plays as-is whatever the fight state says. Empty leaves the fight in charge.
var pose_override := ""
var guard_time := 0.0
## Blend into a scrubbed attack from whatever pose the rig was in, so a
## jab never snaps from the guard to the clip's first frame.
var _blend_from: Dictionary = {}
var _blend_time := 0.0
## The hips' position when the blend began (rotations alone left the body
## hopping between two clips whose hips sit at different heights), and how
## long this blend lasts.
var _blend_hips := Vector3.ZERO
var _blend_span := 0.0
## attack_timer last frame: a new strike restarts it, which is how a move
## repeated in a combo (the same clip again) is told from one carrying on.
var _last_attack_time := 0.0
var _last_scrub_time := 0.0
const ATTACK_BLEND := 0.12
## Into a reaction restarting on the same clip (consecutive blows).
const REACT_BLEND := 0.1
## Fastest a strike clip's wind-up may play (x its own speed): the move's
## startup is short, so the clip starts that much later in its wind-up
## instead of racing through all of it.
const WINDUP_RATE := 1.5
## Share of every wind-up that always plays.
const WINDUP_KEEP := 0.45
## Blend from the end of a strike back into guard (s).
const STRIKE_SETTLE := 0.26
var _from_strike := false
## Into the thrown clip from a guard, and from lying into the get-up.
const THROW_BLEND := 0.15
## Procedural layers on top of the clips: a knee tuck for rigs with no
## jump clip and a lean back for guarded hits. Bones are found by name and
## their bend direction is calibrated once, so any humanoid rig works.
var _tuck := 0.0
var _lean := 0.0
## Extra lean back of the trunk set by the throw each frame (Agasthya's spear).
var _posture := 0.0
## Hit recoil on a damped spring: x leans the trunk back (+) or folds it
## forward (-), y twists the body, z buckles the knees. A blow snaps it to
## the hit pose on contact (held through hit-stop), then it swings back with
## a little overshoot, which is what reads as a body taking weight.
var _recoil := Vector3.ZERO
var _recoil_vel := Vector3.ZERO
var _recoil_side := 1.0
## Share of the trunk lean per spine bone, hips to chest: head snaps bend
## high, body blows fold from the belly.
var _recoil_spread := [0.2, 0.3, 0.5]
## Soft and heavy: a struck body sways back over about half a second
## instead of twitching.
const RECOIL_STIFFNESS := 85.0
const RECOIL_DAMPING := 8.2
## A stagger loosens the spring for a moment so the body wobbles longer.
var _damping := RECOIL_DAMPING
## Whole-body lurch along the facing in metres (+ toward the rival), on the
## same spring: attackers carry into a landed blow, staggered fighters reel.
var _push := 0.0
var _push_vel := 0.0
## Head snapped to one side by a blow (radians), on its own spring, and the
## head bone's [axis, sign] that rolls the face sideways.
var _snap := 0.0
var _snap_vel := 0.0
var _head_roll: Array = []
## Eyes on the rival: the head-local axis the face looks along (from the
## rest pose), and how strongly / how far the neck is turned this frame.
var _face_axis := Vector3.ZERO
var _aim_weight := 0.0
var _aim := 0.0
## Most the spine, neck and head turn to find the rival (radians), and each
## one's share of that turn.
const AIM_LIMIT := 1.2
## Fastest the head/neck turn toward the rival may change (rad/s).
const AIM_SPEED := 3.0
const AIM_CHAIN := [["spine2", 0.2], ["neck", 0.35], ["head", 0.45]]
var _legs: Array = []      # [[upper bone, knee bone, upper sign, knee sign, axis], ...]
var _spine: Array = []     # [[bone, sign, axis], ...]

func configure(owner_visual: Node, profile: Dictionary) -> void:
	visual = owner_visual
	if is_instance_valid(root):
		root.get_parent().remove_child(root)
		root.queue_free()
	root = null
	active = false
	current = ""
	# Switching fighters starts from a clean slate: no clips, paces or guard
	# bones may carry over from the previous character.
	clip_names.clear()
	clip_pace.clear()
	guard_tracks.clear()
	guard_clip = null
	skeleton = null
	guard_weight = 0.0
	_last_state = -1
	_face_bones = []
	config = MODELS.entry(str(profile.id))
	if config.is_empty() or visual.model == null:
		visual.model.visible = true if visual.model != null else false
		return
	character = _load_character(config.scene)
	if character == null:
		push_warning("Fighter model %s missing; using the procedural rig." % config.scene)
		visual.model.visible = true
		return
	root = Node3D.new()
	root.name = "AnimatedFighter"
	visual.model.get_parent().add_child(root)
	root.add_child(character)
	player = character.find_children("*", "AnimationPlayer", true, false).front() if not character.find_children("*", "AnimationPlayer", true, false).is_empty() else null
	if player == null:
		player = AnimationPlayer.new()
		character.add_child(player)
	# Advanced by hand in update(), so the guard overlay lands after the clip.
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if str(config.get("body", "")) != "":
		_graft_body(config.body)
	_add_clip_files()
	_resolve_clips()
	_prepare_guard()
	_thicken(config.get("thicken", {}))
	_fit(float(config.get("height", 1.8)))
	_tint(config.get("tint", []))
	_polish_materials()
	_calibrate()
	visual.model.visible = false
	active = true
	var fighter: Node = visual.fighter
	if fighter != null and fighter.has_signal("impact") and not fighter.impact.is_connected(_on_impact):
		fighter.impact.connect(_on_impact)
	if fighter != null and fighter.has_signal("strike_connected") and not fighter.strike_connected.is_connected(_on_strike):
		fighter.strike_connected.connect(_on_strike)
	if fighter != null and fighter.has_signal("wall_hit") and not fighter.wall_hit.is_connected(_on_wall_hit):
		fighter.wall_hit.connect(_on_wall_hit)

## The character scene: the imported resource when the editor has seen
## the file, otherwise a glTF decoded on the spot (a rig dropped into the
## folder plays without opening the editor first).
static func _load_character(path: String) -> Node3D:
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path)
		if packed != null and packed.can_instantiate():
			return packed.instantiate() as Node3D
	if path.get_extension().to_lower() in ["glb", "gltf"] and FileAccess.file_exists(path):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(path, state) == OK:
			return document.generate_scene(state) as Node3D
	return null

func _on_impact(_point: Vector2, blocked: bool, heavy: bool) -> void:
	_react = true
	var fighter: Node = visual.fighter if visual != null else null
	var slammed: bool = fighter != null and fighter.get("thrown_down") != null and (fighter.state in [fighter.State.THROWN, fighter.State.KNOCKDOWN] or fighter.thrown_down)
	if slammed and fighter.state in [fighter.State.KNOCKDOWN, fighter.State.KO]:
		# A ground punch: the downed body curls up around it.
		_recoil_side = -_recoil_side
		_recoil = Vector3(-0.12 if heavy else -0.06, 0.0, 0.0)
		# Punched in the face: the head is knocked to the side.
		_snap = (0.75 if heavy else 0.55) * _recoil_side
		_snap_vel = 0.0
		_recoil_vel = Vector3.ZERO
		_recoil_spread = [0.5, 0.3, 0.2]
		_damping = RECOIL_DAMPING
	elif slammed and fighter.state == fighter.State.THROWN and fighter.throw_partner != null and not fighter.throw_partner.throw_slammed:
		# Winded by the shoulder: the trunk folds over it as the legs go.
		_recoil = Vector3(-0.5, 0.0, 0.12)
		_recoil_vel = Vector3.ZERO
		_recoil_spread = [0.5, 0.3, 0.2]
		_damping = RECOIL_DAMPING
	elif fighter != null and fighter.get("last_hit_force") != null and not slammed:
		var force: float = 0.45 + 0.55 * float(fighter.last_hit_force)
		# Where the blow really touched: a faster limb hits harder, and the
		# body turns away from the side it came in on.
		var touch: Dictionary = fighter.get("last_contact") if fighter.get("last_contact") is Dictionary else {}
		if touch.has("speed"):
			force *= clampf(0.75 + float(touch.speed) / 16.0, 0.8, 1.3)
		if blocked:
			_recoil = Vector3(0.1 * force, 0.0, 0.08 * force)
			_recoil_spread = [0.34, 0.33, 0.33]
		else:
			# Turn away from the side struck; a blow square on alternates the
			# twist so a combo never replays one identical flinch.
			if touch.has("side") and float(touch.side) != 0.0:
				_recoil_side = float(touch.side)
			else:
				_recoil_side = -_recoil_side
			match fighter.last_hit_height:
				"low":
					_recoil = Vector3(-0.14 * force, 0.18 * force * _recoil_side, 0.55 * force)
					_recoil_spread = [0.5, 0.3, 0.2]
				"mid":
					_recoil = Vector3(-0.42 * force, 0.22 * force * _recoil_side, 0.22 * force)
					_recoil_spread = [0.5, 0.3, 0.2]
				_:
					_recoil = Vector3(0.4 * force, 0.26 * force * _recoil_side, 0.06 * force)
					_recoil_spread = [0.15, 0.3, 0.55]
					_snap = 0.3 * force * _recoil_side
					_snap_vel = 0.0
		_recoil_vel = Vector3.ZERO
		_damping = RECOIL_DAMPING
		if not blocked and fighter.get("last_hit_stagger"):
			# Off balance: a bigger, looser recoil and a lurch back that the
			# legs catch with a dip, on top of the longer physics slide.
			_recoil *= 1.1
			_recoil.z = maxf(_recoil.z, 0.15)
			_damping = 5.5
			_push_vel = -2.2
	if not blocked:
		# Heavy reaction for kicks and for the harder punches and finishers.
		var attacker = visual.fighter.get("opponent") if visual != null and visual.fighter != null else null
		var move: Dictionary = attacker.current_move if attacker != null and attacker.get("current_move") != null else {}
		last_hit_heavy = heavy or float(move.get("damage", 1.0)) >= 1.2 or bool(visual.fighter.get("last_hit_stagger"))
		_reaction = _pick_reaction(visual.fighter, attacker)

## The reaction clip for a landed blow, for rigs that have a set: light
## head snaps for jabs, a heavy whip for hooks, uppercuts and head kicks, a
## fold for body shots and the liver-shot crumple for hard body and low
## kicks and counters. "" falls back to the plain hit / heavy hit.
func _pick_reaction(fighter: Node, attacker) -> String:
	if fighter == null or not clip_names.has("hit_body") or fighter.get("last_hit_height") == null:
		return ""
	var height: String = fighter.last_hit_height
	var force: float = fighter.last_hit_force
	if height != "high" and (fighter.last_hit_stagger or force >= 0.7) and clip_names.has("hit_liver"):
		return "hit_liver"
	if height == "high":
		var variant: String = attacker.attack_variant if attacker != null else ""
		var kicked: bool = attacker != null and attacker.state == attacker.State.KICK
		if (force >= 0.45 or kicked or variant in ["hook", "rear_hook", "uppercut", "overhand", "finisher", "spin"]) and clip_names.has("hit_head_heavy"):
			return "hit_head_heavy"
		# Repeated jabs alternate between two snaps when the rig has both.
		_head_flip = not _head_flip
		if _head_flip and clip_names.has("hit_head_alt"):
			return "hit_head_alt"
		return "hit_head" if clip_names.has("hit_head") else ""
	# Hooks and roundhouses dig into the side; straight shots fold the front.
	var round_blow: bool = attacker != null and (attacker.attack_variant in ["hook", "rear_hook", "body_hook", "spin"] or attacker.state == attacker.State.KICK)
	if round_blow and clip_names.has("hit_side"):
		return "hit_side"
	_body_flip = not _body_flip
	if _body_flip and clip_names.has("hit_body_alt"):
		return "hit_body_alt"
	return "hit_body"

## Slammed back-first into a railing: the chest is thrown forward off the
## stone, the head whips, and the body lurches back toward the attacker.
func _on_wall_hit(_point: Vector3) -> void:
	_recoil = Vector3(-0.45, 0.12 * _recoil_side, 0.2)
	_recoil_vel = Vector3.ZERO
	_recoil_spread = [0.3, 0.35, 0.35]
	_damping = 7.0
	_push = -0.12
	_push_vel = 2.0
	_snap = 0.35 * _recoil_side
	_snap_vel = 0.0
	_react = true

## The attacker's side of a landed blow: once hit-stop releases, the trunk
## drives on through the target and the body carries a little forward, so
## the strike reads as hitting something solid instead of stopping in air.
func _on_strike(blocked: bool, force: float) -> void:
	var weight := (0.5 + 0.5 * force) * (0.45 if blocked else 1.0)
	_recoil = Vector3(-0.2 * weight, 0.0, 0.08 * weight)
	_recoil_vel = Vector3.ZERO
	_recoil_spread = [0.4, 0.35, 0.25]
	_damping = RECOIL_DAMPING
	_push_vel = 1.4 * weight

## Scales the model to its configured height, feet on the floor, turned to
## face the game's +X like the procedural rig.
func _fit(height: float) -> void:
	character.rotation.y = float(config.get("yaw", PI / 2.0))
	var bounds := AABB()
	var first := true
	# Measured in the character's own space, before the rig's scale.
	var to_local := character.global_transform.affine_inverse()
	for mesh in character.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (to_local * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var model_height := maxf(bounds.size.y, 0.01)
	# The fight rig works in pixels-per-metre units (64 per metre).
	var units := 64.0
	var width: float = config.get("width", 1.0)
	character.scale = Vector3(width, 1.0, width) * (height / model_height) * units
	character.position.y = -bounds.position.y * (height / model_height) * units - (64.0 if visual.world_root == null else 0.0)

## Fills out thin limbs: {"arm": 1.3} pushes every vertex skinned to the
## upper arms out from the bone's line by 30%, in the bind pose, so the
## arm keeps its length and joints and every clip plays on it unchanged.
## Keys are bone names without the Left/Right side.
static var _thickened := {}

func _thicken(factors: Dictionary) -> void:
	if factors.is_empty():
		return
	for mesh: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false):
		var skin: Skin = mesh.skin
		var source := mesh.mesh as ArrayMesh
		var skeleton_node := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if skin == null or source == null or skeleton_node == null:
			continue
		# Built once per mesh and shared by every later copy of the fighter.
		var cache_key := "%d|%s" % [source.get_instance_id(), str(factors)]
		if _thickened.has(cache_key):
			_swap_mesh(mesh, _thickened[cache_key])
			continue
		# Per bind: [factor, bind pose, the bone's own axis in its space].
		var binds := {}
		for i in skin.get_bind_count():
			var name := String(skin.get_bind_name(i))
			if name == "" and skin.get_bind_bone(i) >= 0:
				name = skeleton_node.get_bone_name(skin.get_bind_bone(i))
			var key := name.to_lower().get_slice(":", name.get_slice_count(":") - 1).trim_prefix("mixamorig_").trim_prefix("left").trim_prefix("right")
			if not factors.has(key):
				continue
			var bone := skeleton_node.find_bone(name)
			var child := -1
			for c in skeleton_node.get_bone_children(bone) if bone >= 0 else PackedInt32Array():
				child = c
				break
			var axis := Vector3.UP
			if child >= 0:
				# The child's head, carried into this bone's bind space.
				var child_rest := skeleton_node.get_bone_rest(child).origin
				if child_rest.length() > 0.0001:
					axis = child_rest.normalized()
			binds[i] = [float(factors[key]), skin.get_bind_pose(i), axis]
		if binds.is_empty():
			continue
		var built := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if bones.is_empty() or verts.is_empty():
				built.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
				built.surface_set_material(surface, source.surface_get_material(surface))
				continue
			var per := bones.size() / verts.size()
			for v in verts.size():
				var p := verts[v]
				var moved := Vector3.ZERO
				for j in per:
					var b := bones[v * per + j]
					var w := weights[v * per + j]
					if w <= 0.0 or not binds.has(b):
						continue
					var data: Array = binds[b]
					var pose: Transform3D = data[1]
					var axis: Vector3 = data[2]
					var local := pose * p
					var along := axis * local.dot(axis)
					var out := along + (local - along) * float(data[0])
					moved += (pose.affine_inverse() * out - p) * w
				verts[v] = p + moved
			arrays[Mesh.ARRAY_VERTEX] = verts
			var flags := source.surface_get_format(surface) & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS | Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
			built.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, [], {}, flags)
			built.surface_set_material(surface, source.surface_get_material(surface))
		_thickened[cache_key] = built
		_swap_mesh(mesh, built)

static func _swap_mesh(mesh: MeshInstance3D, built: ArrayMesh) -> void:
	var overrides := []
	for surface in mesh.get_surface_override_material_count():
		overrides.append(mesh.get_surface_override_material(surface))
	mesh.mesh = built
	for surface in overrides.size():
		mesh.set_surface_override_material(surface, overrides[surface])

## Swaps the shared body's meshes for the fighter's own (meshy_body.glb from
## tools/rig_meshy_body.py). It is skinned to the same Mixamo rig, so its
## binds are re-expressed against this skeleton's rest pose and every clip
## plays on it unchanged.
func _graft_body(path: String) -> void:
	var packed: PackedScene = null
	if ResourceLoader.load_threaded_get_status(path) in [ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_IN_PROGRESS]:
		packed = ResourceLoader.load_threaded_get(path)
	elif ResourceLoader.exists(path):
		packed = load(path)
	var targets := character.find_children("*", "Skeleton3D", true, false)
	if packed == null or targets.is_empty():
		return
	var target: Skeleton3D = targets[0]
	var scene := packed.instantiate()
	var sources := scene.find_children("*", "Skeleton3D", true, false)
	if sources.is_empty():
		scene.free()
		return
	var source: Skeleton3D = sources[0]
	var bones := {}
	for bone in target.get_bone_count():
		bones[_bone_key(target.get_bone_name(bone))] = bone
	# Same rig in both files, so one similarity transform maps the body's
	# skeleton space onto this one; found from the hips, head and hands.
	var mapping := _skeleton_mapping(source, target, bones)
	for mesh in target.find_children("*", "MeshInstance3D", true, false):
		mesh.get_parent().remove_child(mesh)
		mesh.free()
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null:
			continue
		var skin := Skin.new()
		var placed := Transform3D()
		for i in mesh.skin.get_bind_count():
			var name := String(mesh.skin.get_bind_name(i))
			if name == "":
				name = source.get_bone_name(mesh.skin.get_bind_bone(i))
			var from := source.find_bone(name)
			var key := _bone_key(name)
			if from < 0 or not bones.has(key):
				continue
			var to: int = bones[key]
			var rest_space := mapping * source.get_bone_global_rest(from) * mesh.skin.get_bind_pose(i)
			placed = rest_space
			skin.add_named_bind(target.get_bone_name(to), target.get_bone_global_rest(to).affine_inverse() * rest_space)
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		target.add_child(mesh)
		# The skinned vertices come out in the skeleton's space, and Godot
		# draws them through the mesh node's transform; so the vertices are
		# moved into the skeleton's space (its units: a Mixamo FBX rig is in
		# centimetres) and the node sits at the skeleton's origin. Left in
		# their own space under a scaled node, a body grafted onto a
		# centimetre rig came out a hundred times too big.
		if not placed.is_equal_approx(Transform3D.IDENTITY):
			mesh.mesh = _moved_mesh(mesh.mesh, placed)
			for i in skin.get_bind_count():
				skin.set_bind_pose(i, skin.get_bind_pose(i) * placed.affine_inverse())
		mesh.transform = Transform3D.IDENTITY
		# Skin and fingers are finished before the mesh takes its skin (binds
		# added to a skin already in use weren't picked up).
		mesh.mesh = _shoulder_weights(mesh.mesh, skin, target)
		mesh.mesh = _finger_weights(mesh.mesh, skin, target)
		mesh.skin = skin
		mesh.skeleton = NodePath("..")
	scene.free()

## The Meshy bodies' auto-rig glued the vest, hood and chest beside each
## shoulder to the upper arm, so every punch dragged a slab of clothing
## forward with the arm. A vertex inside the shoulder joint (nearer the
## spine than the joint is) hands its upper-arm weight to the collarbone,
## fully once it is a little way in: the torso and clothes follow the
## chest, the sleeve still follows the arm. Built once per body mesh.
static var _reweighted := {}

## The Meshy bodies' hands came rigged as one rigid piece: every finger
## weight was folded into the hand (tools/rig_meshy_body.py), so the fingers
## stood frozen half-open whatever a clip did, and the shared skeleton's
## finger bones don't sit where any model's fingers are. Each hand is
## measured from its own mesh in the bind pose (T-pose, palm down, fingers
## running out along the arm): how far the fingertips reach, which side the
## thumb is on, how wide the fingers spread. The finger bones of this
## character's skeleton are moved onto the joints that gives (knuckles a
## little under half way out, then two more joints), and the mesh is
## skinned to them: past the knuckles by which of four bands across the
## hand it falls in, joint by joint along its length with a soft blend at
## each joint; the thumb by its own side. Fingers the model fused close as
## one, like a fist in a glove. The fist pose (_fist_pose) curls them.
static var _fingered := {}
const FINGER_NAMES := ["index", "middle", "ring", "pinky"]
## Joints as shares of the fingertip reach from the wrist.
const KNUCKLE := 0.46
const FINGER_JOINTS := [0.46, 0.67, 0.84]
const THUMB_JOINTS := [0.12, 0.28, 0.42]
func _finger_weights(source: Mesh, skin: Skin, skeleton: Skeleton3D) -> Mesh:
	var keys := {}
	for b in skeleton.get_bone_count():
		keys[_bone_key(skeleton.get_bone_name(b))] = b
	var binds := {}
	for i in skin.get_bind_count():
		binds[_bone_key(String(skin.get_bind_name(i)))] = i
	var hands := []
	for side in ["left", "right"]:
		if not keys.has(side + "hand") or not binds.has(side + "hand") or not keys.has(side + "handthumb2") or not keys.has(side + "forearm"):
			continue
		var hand: Vector3 = skeleton.get_bone_global_rest(keys[side + "hand"]).origin
		var out: Vector3 = (hand - skeleton.get_bone_global_rest(keys[side + "forearm"]).origin).normalized()
		var thumb: Vector3 = skeleton.get_bone_global_rest(keys[side + "handthumb2"]).origin - hand
		var across: Vector3 = (thumb - out * thumb.dot(out)).normalized()
		hands.append({"side": side, "bind": binds[side + "hand"], "hand": hand, "out": out, "across": across})
	if hands.is_empty():
		return source
	# Measure each hand: fingertip reach and the spread of the fingers.
	var surfaces := []
	for surface in source.get_surface_count():
		surfaces.append(source.surface_get_arrays(surface))
	for h in hands:
		var reaches: Array[float] = []
		for arrays in surfaces:
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null or points.is_empty():
				continue
			var per := (bones as Array).size() / points.size()
			for v in points.size():
				for k in per:
					if bones[v * per + k] == h.bind and weights[v * per + k] > 0.5:
						reaches.append((points[v] - (h.hand as Vector3)).dot(h.out))
		if reaches.size() < 40:
			h.tip = 0.0
			continue
		reaches.sort()
		h.tip = reaches[int(reaches.size() * 0.98)]
		var spread: Array[float] = []
		for arrays in surfaces:
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null or points.is_empty():
				continue
			var per := (bones as Array).size() / points.size()
			for v in points.size():
				var d: Vector3 = points[v] - (h.hand as Vector3)
				if d.dot(h.out) < h.tip * (KNUCKLE + 0.08):
					continue
				for k in per:
					if bones[v * per + k] == h.bind and weights[v * per + k] > 0.5:
						spread.append(d.dot(h.across))
		if spread.size() < 20:
			h.tip = 0.0
			continue
		spread.sort()
		h.low = spread[int(spread.size() * 0.04)]
		h.high = spread[int(spread.size() * 0.96)]
		_place_finger_bones(skeleton, keys, h)
	# Every finger joint gets a fresh bind, made after the bones were moved
	# (the body's skin may list the fingers, bound where they used to be,
	# with no weight on them).
	var fresh := {}
	var bind_of := func(key: String) -> int:
		if fresh.has(key):
			return fresh[key]
		if not key.contains("thumb") and not FINGER_NAMES.any(func(name): return key.contains(name)) and binds.has(key):
			return binds[key]
		if not keys.has(key):
			return -1
		var bone: int = keys[key]
		# Bound exactly as the hand is (its bind carries the body's fit onto
		# this skeleton), so at rest the finger sits where it was modelled.
		var hand_key := ("left" if key.begins_with("left") else "right") + "hand"
		var hand_bind: int = binds[hand_key]
		var fitted := _global_rest(skeleton, keys[hand_key]) * skin.get_bind_pose(hand_bind)
		skin.add_named_bind(skeleton.get_bone_name(bone), _global_rest(skeleton, bone).affine_inverse() * fitted)
		fresh[key] = skin.get_bind_count() - 1
		return fresh[key]
	if _fingered.has(source):
		for h in hands:
			for name in FINGER_NAMES + ["thumb"]:
				for n in [1, 2, 3]:
					bind_of.call("%shand%s%d" % [h.side, name, n])
		return _fingered[source]
	var built := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays: Array = surfaces[surface]
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		if bones == null or weights == null or points.is_empty():
			built.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
			built.surface_set_material(surface, source.surface_get_material(surface))
			continue
		var per := (bones as Array).size() / points.size()
		for v in points.size():
			for h in hands:
				if float(h.get("tip", 0.0)) <= 0.0:
					continue
				var slot := -1
				for k in per:
					if bones[v * per + k] == h.bind and weights[v * per + k] > 0.0:
						slot = v * per + k
				if slot < 0:
					continue
				var pick := _finger_for(points[v], h)
				if pick.is_empty():
					continue
				var to: int = bind_of.call(pick[0])
				var parent: int = bind_of.call(pick[1]) if pick[1] != "" else int(h.bind)
				if to < 0 or parent < 0:
					continue
				var share: float = weights[slot]
				var blend: float = pick[2]
				# This slot takes the joint; a free slot the blend back toward
				# the joint before it, so the skin bends softly.
				bones[slot] = to
				weights[slot] = share * blend
				var rest := share * (1.0 - blend)
				if rest > 0.0001:
					var free := -1
					for k in per:
						if v * per + k != slot and weights[v * per + k] <= 0.0001:
							free = v * per + k
					if free >= 0:
						bones[free] = parent
						weights[free] = rest
					else:
						weights[slot] = share
				break
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		var format: int = source.surface_get_format(surface) if source is ArrayMesh else 0
		built.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, [], {}, format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		built.surface_set_material(surface, source.surface_get_material(surface))
	_fingered[source] = built
	return built

## Moves this skeleton's finger bones onto the measured hand: each finger's
## three joints out along the hand at FINGER_JOINTS of the fingertip reach,
## in its own band across the fingers (index by the thumb, pinky furthest);
## the thumb's joints out from the wrist on the thumb's side.
static func _place_finger_bones(skeleton: Skeleton3D, keys: Dictionary, h: Dictionary) -> void:
	var targets := {}
	for c in 4:
		var band: float = lerpf(float(h.high), float(h.low), (c + 0.5) / 4.0)
		for j in 3:
			targets["%shand%s%d" % [h.side, FINGER_NAMES[c], j + 1]] = (h.hand as Vector3) + (h.out as Vector3) * (float(h.tip) * float(FINGER_JOINTS[j])) + (h.across as Vector3) * band
	for j in 3:
		targets["%shandthumb%d" % [h.side, j + 1]] = (h.hand as Vector3) + (h.out as Vector3) * (float(h.tip) * float(THUMB_JOINTS[j])) + (h.across as Vector3) * (float(h.high) + float(h.tip) * (0.12 + 0.06 * j))
	# Parents first, so each local offset is taken from the placed parent.
	var order := targets.keys()
	order.sort_custom(func(a, b): return int(keys[a]) < int(keys[b]))
	for c in 4:
		var tip_key := "%shand%s4" % [h.side, FINGER_NAMES[c]]
		if keys.has(tip_key):
			targets[tip_key] = (targets["%shand%s3" % [h.side, FINGER_NAMES[c]]] as Vector3) + (h.out as Vector3) * (float(h.tip) * 0.16)
			order.append(tip_key)
	order.sort_custom(func(a, b): return int(keys[a]) < int(keys[b]))
	for key in order:
		var bone: int = keys[key]
		var parent := skeleton.get_bone_parent(bone)
		var rest := skeleton.get_bone_rest(bone)
		# The parent's rest as it now stands (Skeleton3D refreshes its global
		# rests lazily, so a just-moved parent reads stale).
		rest.origin = _global_rest(skeleton, parent).affine_inverse() * (targets[key] as Vector3)
		skeleton.set_bone_rest(bone, rest)
		skeleton.set_bone_pose_position(bone, rest.origin)

## A bone's rest in skeleton space, chained from the local rests (always
## current, unlike Skeleton3D's cached global rest after set_bone_rest).
static func _global_rest(skeleton: Skeleton3D, bone: int) -> Transform3D:
	var at := Transform3D()
	while bone >= 0:
		at = skeleton.get_bone_rest(bone) * at
		bone = skeleton.get_bone_parent(bone)
	return at

## The finger joint a hand vertex belongs to: [joint key, the joint before's
## key ("" for the hand), share of the joint], or [] for the palm and wrist.
static func _finger_for(point: Vector3, h: Dictionary) -> Array:
	var d: Vector3 = point - (h.hand as Vector3)
	var reach: float = d.dot(h.out) / float(h.tip)
	var side: float = d.dot(h.across)
	var width: float = float(h.high) - float(h.low)
	# The thumb: out on its own side, short of the knuckles.
	var thumb_side: bool = side > float(h.high) + width * 0.12 and reach < KNUCKLE + 0.1
	# Short of the knuckles, the thumb's root fills the thumb side of the palm.
	thumb_side = thumb_side or (side > float(h.high) - width * 0.2 and reach < KNUCKLE - 0.04)
	if thumb_side and reach > 0.06:
		var j := 0
		for k in range(1, 3):
			if reach >= float(THUMB_JOINTS[k]):
				j = k
		var key := "%shandthumb%d" % [h.side, j + 1]
		var before: String = "" if j == 0 else "%shandthumb%d" % [h.side, j]
		return [key, before, smoothstep(float(THUMB_JOINTS[j]) - 0.05, float(THUMB_JOINTS[j]) + 0.03, reach)]
	if reach < KNUCKLE - 0.06:
		return []
	var band := clampi(int(floor((float(h.high) - side) / maxf(width, 0.0001) * 4.0)), 0, 3)
	var joint := 0
	for k in range(1, 3):
		if reach >= float(FINGER_JOINTS[k]):
			joint = k
	var key := "%shand%s%d" % [h.side, FINGER_NAMES[band], joint + 1]
	var before: String = "" if joint == 0 else "%shand%s%d" % [h.side, FINGER_NAMES[band], joint]
	var at: float = float(FINGER_JOINTS[joint])
	return [key, before, smoothstep(at - 0.06, at + 0.04, reach)]

static func _shoulder_weights(source: Mesh, skin: Skin, skeleton: Skeleton3D) -> Mesh:
	if _reweighted.has(source):
		return _reweighted[source]
	var binds := {}
	for i in skin.get_bind_count():
		binds[_bone_key(String(skin.get_bind_name(i)))] = i
	var bone := func(key: String) -> int:
		for b in skeleton.get_bone_count():
			if _bone_key(skeleton.get_bone_name(b)) == key:
				return b
		return -1
	var hips: int = bone.call("hips")
	var head: int = bone.call("head")
	if hips < 0 or head < 0:
		return source
	var size := skeleton.get_bone_global_rest(head).origin.distance_to(skeleton.get_bone_global_rest(hips).origin)
	var sides := []
	for side in ["left", "right"]:
		var arm: int = bone.call(side + "arm")
		if arm < 0 or not binds.has(side + "arm") or not binds.has(side + "shoulder"):
			continue
		var joint := skeleton.get_bone_global_rest(arm).origin
		var outward := joint - skeleton.get_bone_global_rest(hips).origin
		outward.y = 0.0
		sides.append([binds[side + "arm"], binds[side + "shoulder"], joint, outward.normalized()])
	if sides.is_empty():
		return source
	var built := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		if bones == null or weights == null or points.is_empty():
			built.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
			built.surface_set_material(surface, source.surface_get_material(surface))
			continue
		var per := (bones as Array).size() / points.size()
		for v in points.size():
			for entry in sides:
				var inside := -(points[v] - (entry[2] as Vector3)).dot(entry[3])
				if inside <= 0.0:
					continue
				var hand_over := smoothstep(0.0, size * 0.12, inside)
				for k in per:
					if bones[v * per + k] == entry[0] and weights[v * per + k] > 0.0:
						var moved: float = weights[v * per + k] * hand_over
						weights[v * per + k] -= moved
						# Onto the collarbone's slot if the vertex has one, else
						# this slot becomes the collarbone's.
						var given := false
						for j in per:
							if bones[v * per + j] == entry[1]:
								weights[v * per + j] += moved
								given = true
						if not given:
							if weights[v * per + k] <= 0.0001:
								bones[v * per + k] = entry[1]
								weights[v * per + k] = moved
							else:
								weights[v * per + k] += moved
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		var format: int = source.surface_get_format(surface) if source is ArrayMesh else 0
		built.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, [], {}, format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		built.surface_set_material(surface, source.surface_get_material(surface))
	_reweighted[source] = built
	return built

static func _bone_key(name: String) -> String:
	return name.get_slice(":", name.get_slice_count(":") - 1).trim_prefix("mixamorig_").to_lower()

func _skeleton_mapping(source: Skeleton3D, target: Skeleton3D, bones: Dictionary) -> Transform3D:
	var frames: Array[Transform3D] = []
	for skeleton: Skeleton3D in [source, target]:
		var point := func(bone_name: String) -> Vector3:
			for bone in skeleton.get_bone_count():
				if _bone_key(skeleton.get_bone_name(bone)) == bone_name:
					return skeleton.get_bone_global_rest(bone).origin
			return Vector3.ZERO
		var hips: Vector3 = point.call("hips")
		var up: Vector3 = point.call("head") - hips
		var across: Vector3 = point.call("lefthand") - point.call("righthand")
		var size := up.length()
		var basis := Basis(across.normalized(), up.normalized(), across.cross(up).normalized()).orthonormalized()
		frames.append(Transform3D(basis.scaled(Vector3.ONE * size), hips))
	return frames[1] * frames[0].affine_inverse()

## `source` with every vertex, normal and tangent carried by `move`
## (materials kept). Blend shapes are dropped; grafted bodies have none.
static func _moved_mesh(source: Mesh, move: Transform3D) -> ArrayMesh:
	var moved := ArrayMesh.new()
	var turn := move.basis.orthonormalized()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in points.size():
			points[i] = move * points[i]
		arrays[Mesh.ARRAY_VERTEX] = points
		if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in normals.size():
				normals[i] = (turn * normals[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
		if arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for i in range(0, tangents.size(), 4):
				var t := (turn * Vector3(tangents[i], tangents[i + 1], tangents[i + 2])).normalized()
				tangents[i] = t.x
				tangents[i + 1] = t.y
				tangents[i + 2] = t.z
			arrays[Mesh.ARRAY_TANGENT] = tangents
		moved.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		moved.surface_set_material(surface, source.surface_get_material(surface))
	return moved

## Paints the shared body in the fighter's colours: [body, joints]. Meshes
## named like joints or trims take the second colour.
func _tint(colors: Array) -> void:
	if colors.size() < 2:
		return
	for mesh in character.find_children("*", "MeshInstance3D", true, false):
		var paint := StandardMaterial3D.new()
		var joint: bool = String(mesh.name).to_lower().contains("joint")
		paint.albedo_color = colors[1] if joint else colors[0]
		paint.roughness = 0.45 if joint else 0.7
		paint.metallic = 0.35 if joint else 0.0
		mesh.material_override = paint

## Each fighter's Fighting Animset Pro clips, retargeted onto this skeleton
## (_add_pack_clips), built once per fighter and reused: in memory for the
## rest of the session, and on disk (user://clip_cache) for the next launch.
## Building one means converting about fifty clips (several seconds); a
## cached set loads in a fraction of that. Bump CLIP_CACHE_VERSION whenever
## the conversion below changes.
const CLIP_CACHE_VERSION := 30
const CLIP_CACHE_DIR := "user://clip_cache/"
static var _clip_cache := {}

## Starts loading every fighter's model and saved clip set on worker
## threads (the select screen calls this), so picking a fighter later builds
## from memory instead of stalling on the disk.
static func warm(fighter_ids: Array) -> void:
	for id in fighter_ids:
		var entry: Dictionary = MODELS.entry(str(id))
		# The model, and the separate body some fighters wear over it.
		for path in [str(entry.get("scene", "")), str(entry.get("body", ""))]:
			if path != "" and ResourceLoader.exists(path):
				ResourceLoader.load_threaded_request(path)
	if DirAccess.dir_exists_absolute(CLIP_CACHE_DIR):
		for file in DirAccess.get_files_at(CLIP_CACHE_DIR):
			if file.ends_with(".res"):
				ResourceLoader.load_threaded_request(CLIP_CACHE_DIR + file, "AnimationLibrary")

func _add_clip_files() -> void:
	var pack: Dictionary = config.get("pack", {})
	if pack.is_empty():
		return
	var skeleton := character.find_children("*", "Skeleton3D", true, false)
	if skeleton.is_empty():
		return
	var to_skeleton := player.get_node(player.root_node).get_path_to(skeleton[0])
	var key := _clip_cache_key(pack, skeleton[0], to_skeleton)
	var library: AnimationLibrary = _clip_cache.get(key)
	if library == null:
		var saved := CLIP_CACHE_DIR + key + ".res"
		if ResourceLoader.load_threaded_get_status(saved) in [ResourceLoader.THREAD_LOAD_LOADED, ResourceLoader.THREAD_LOAD_IN_PROGRESS]:
			library = ResourceLoader.load_threaded_get(saved) as AnimationLibrary
		elif ResourceLoader.exists(saved):
			library = ResourceLoader.load(saved, "AnimationLibrary", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
	if library == null or not library.has_meta("pace"):
		var timing_before: Dictionary = config.get("timing", {}).duplicate(true)
		library = AnimationLibrary.new()
		for file in pack:
			_add_pack_clips(library, file, pack[file], skeleton[0], to_skeleton)
		# What the build learned besides the clips: each clip's travel pace
		# and any impact times it measured, replayed on a cached load.
		var measured := {}
		var timing_after: Dictionary = config.get("timing", {})
		for logical in timing_after:
			if not timing_before.has(logical):
				measured[logical] = timing_after[logical]
		library.set_meta("pace", clip_pace.duplicate())
		library.set_meta("timing", measured)
		DirAccess.make_dir_recursive_absolute(CLIP_CACHE_DIR)
		ResourceSaver.save(library, CLIP_CACHE_DIR + key + ".res", ResourceSaver.FLAG_COMPRESS)
	else:
		clip_pace.merge(library.get_meta("pace", {}), true)
		var timing: Dictionary = config.get("timing", {})
		timing.merge(library.get_meta("timing", {}), false)
		config["timing"] = timing
	_clip_cache[key] = library
	player.add_animation_library("files", library)

## Names one fighter's clip set: the conversion version, every pack file
## with its modification time and the clips taken from it, and the skeleton
## the clips are fitted to.
func _clip_cache_key(pack: Dictionary, skeleton: Skeleton3D, to_skeleton: NodePath) -> String:
	var parts := [CLIP_CACHE_VERSION, str(to_skeleton), skeleton.get_bone_count(), snappedf(_hips_height(skeleton), 0.0001), config.get("scene", "")]
	var files := pack.keys()
	files.sort()
	for file in files:
		var clips: Dictionary = pack[file]
		var logicals := clips.keys()
		logicals.sort()
		parts.append([file, FileAccess.get_modified_time(file), logicals.map(func(logical): return [logical, clips[logical]])])
	var timing_keys: Array = config.get("timing", {}).keys()
	timing_keys.sort()
	parts.append(timing_keys)
	return str(parts).sha256_text().substr(0, 24)

## The pack's T-pose (its "tpose" clip; every pack file shares one skeleton):
## bone name -> world rotation, plus the hips' local position. The pack rests
## in a fighting stance while this skeleton rests in a T-pose, so the T-pose
## is what lines the two up.
static var _pack_tpose := {}

static func _tpose(source: Skeleton3D, from: AnimationPlayer) -> Dictionary:
	if not _pack_tpose.is_empty():
		return _pack_tpose
	if not from.has_animation("tpose"):
		var other: Node = (load(MODELS.pack_file("KB_Idle_1")) as PackedScene).instantiate()
		var result := _tpose(other.find_children("*", "Skeleton3D", true, false)[0], other.find_children("*", "AnimationPlayer", true, false)[0])
		other.free()
		return result
	var clip := from.get_animation("tpose")
	var local := {}
	for track in clip.get_track_count():
		var bone := source.find_bone(String(clip.track_get_path(track).get_concatenated_subnames()))
		if bone < 0:
			continue
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			local[bone] = clip.rotation_track_interpolate(track, 0.0)
		elif clip.track_get_type(track) == Animation.TYPE_POSITION_3D and _bone_key(source.get_bone_name(bone)) == "hips":
			_pack_tpose["@hips"] = clip.position_track_interpolate(track, 0.0)
	var world := {}
	for bone in source.get_bone_count():
		var parent := source.get_bone_parent(bone)
		var rotation: Quaternion = local.get(bone, source.get_bone_rest(bone).basis.get_rotation_quaternion())
		world[bone] = (world[parent] if parent >= 0 else Quaternion.IDENTITY) * rotation
		_pack_tpose[source.get_bone_name(bone)] = world[bone]
	return _pack_tpose

## How far each finger joint curls into the fist (radians): knuckle, middle,
## tip; the thumb folds less, across the front of the fingers.
const FIST_CURL := [1.35, 1.6, 1.2]
const THUMB_CURL := [0.35, 0.45, 0.4]

## Bone -> local rotation of a clenched fist for every finger bone of this
## skeleton: each joint turned from its rest (the T-pose, palm down) about
## the axis that folds the finger toward the palm, so it fits any hand.
static func _fist_pose(skeleton: Skeleton3D, node: Quaternion) -> Dictionary:
	var fist := {}
	for bone in skeleton.get_bone_count():
		var key := _bone_key(skeleton.get_bone_name(bone))
		if not key.contains("hand") or key.ends_with("hand"):
			continue
		var digit := ""
		for name in ["thumb", "index", "middle", "ring", "pinky"]:
			if key.contains(name):
				digit = name
		var joint := key.right(1).to_int() - 1
		if digit == "" or joint < 0 or joint > 2:
			continue
		var children := skeleton.get_bone_children(bone)
		if children.is_empty():
			continue
		var global := _global_rest(skeleton, bone)
		var along: Vector3 = node * (_global_rest(skeleton, children[0]).origin - global.origin)
		if along.length() < 0.00001:
			continue
		# The palm faces down in the T-pose; the thumb folds in toward it.
		var axis := along.normalized().cross(Vector3.DOWN)
		if axis.length() < 0.1:
			continue
		var turn: float = (THUMB_CURL if digit == "thumb" else FIST_CURL)[joint]
		var local_axis := ((node * global.basis.get_rotation_quaternion()).inverse() * axis.normalized()).normalized()
		fist[bone] = (skeleton.get_bone_rest(bone).basis.get_rotation_quaternion() * Quaternion(local_axis, turn)).normalized()
	return fist

## Fighting Animset Pro clips from one pack file, retargeted onto this
## skeleton: wanted is logical clip -> pack clip name. A bone's world
## rotation keeps the same offset from its T-pose that the pack's bone has
## from the pack's T-pose; the hips' bob and sway are scaled by the ratio of
## hip heights. The pack travels on its Root bone, which is left behind (the
## game moves the fighter); its speed is kept as the clip's pace so feet
## match the ground speed.
func _add_pack_clips(library: AnimationLibrary, path: String, wanted: Dictionary, target: Skeleton3D, to_skeleton: NodePath) -> void:
	if not ResourceLoader.exists(path):
		return
	var scene: Node = (load(path) as PackedScene).instantiate()
	var sources := scene.find_children("*", "Skeleton3D", true, false)
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	if sources.is_empty() or players.is_empty():
		scene.free()
		return
	var source: Skeleton3D = sources[0]
	var from: AnimationPlayer = players[0]
	var tpose := _tpose(source, from)
	var target_keys := {}
	for bone in target.get_bone_count():
		target_keys[_bone_key(target.get_bone_name(bone))] = bone
	# Source bone -> target bone; the pack's twist ("Roll") and end bones have
	# no partner and only pass their rotation on to their children.
	var pairs := {}
	for bone in source.get_bone_count():
		var key := _bone_key(source.get_bone_name(bone))
		key = PACK_BONES.get(key, key)
		if key != "" and target_keys.has(key):
			pairs[bone] = target_keys[key]
	# Fingers hold a clenched fist (_fist_pose) instead of the pack's relaxed,
	# half-open hands, which bent the bodies' fingers into claws.
	var fist := _fist_pose(target, _node_rotation(target, character))
	for bone in pairs.keys():
		if fist.has(pairs[bone]):
			pairs.erase(bone)
	var source_hips := source.find_bone("Hips")
	var source_root := source.find_bone("Root")
	var target_hips: int = target_keys.get("hips", 0)
	var t_node := _node_rotation(target, character)
	# Pack T-pose -> this skeleton's rest (a T-pose), per pair: the offset
	# each frame's pack rotation is carried by.
	var offset := {}
	for bone in pairs:
		var to: int = pairs[bone]
		offset[bone] = (tpose[source.get_bone_name(bone)] as Quaternion).inverse() * t_node * target.get_bone_global_rest(to).basis.get_rotation_quaternion()
	var inverse_pairs := {}
	for bone in pairs:
		inverse_pairs[pairs[bone]] = bone
	var s_hips_rest: Vector3 = tpose.get("@hips", source.get_bone_rest(source_hips).origin)
	var scale := target.get_bone_global_rest(target_hips).origin.length() / maxf(s_hips_rest.length(), 0.0001)
	var limbs: Array[int] = []
	for key in ["lefthand", "righthand", "leftfoot", "rightfoot"]:
		if target_keys.has(key):
			limbs.append(target_keys[key])
	var middle: int = target_keys.get("spine1", -1)
	var chest: int = target_keys.get("spine2", -1)
	if middle < 0 or chest < 0 or inverse_pairs.has(middle) or not inverse_pairs.has(chest) or target.get_bone_parent(chest) != middle:
		middle = -1
	var damped := {}
	for key in ["leftshoulder", "rightshoulder"]:
		if target_keys.has(key):
			damped[target_keys[key]] = true
	for logical in wanted:
		var clip_name: String = wanted[logical]
		if not from.has_animation(clip_name):
			push_warning("Fighting Animset Pro has no clip %s in %s" % [clip_name, path])
			continue
		var clip := from.get_animation(clip_name)
		var rotation_tracks := {}
		var hips_track := -1
		var root_track := -1
		for track in clip.get_track_count():
			var bone := source.find_bone(String(clip.track_get_path(track).get_concatenated_subnames()))
			if bone < 0:
				continue
			if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				rotation_tracks[bone] = track
			elif clip.track_get_type(track) == Animation.TYPE_POSITION_3D and bone == source_hips:
				hips_track = track
			elif clip.track_get_type(track) == Animation.TYPE_POSITION_3D and bone == source_root:
				root_track = track
		var out := Animation.new()
		out.length = clip.length
		var out_tracks := {}
		for bone in pairs.values():
			var track := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(track, NodePath(str(to_skeleton) + ":" + target.get_bone_name(bone)))
			out_tracks[bone] = track
		# Every other bone is keyed at its rest too (Spine1, which the pack has
		# no bone for): a bone no clip keys is never reset, so the hit recoil
		# and head turn laid on it each frame piled up, folding the fighter
		# lower with every exchange.
		for bone in target.get_bone_count():
			if bone == middle:
				var track := out.add_track(Animation.TYPE_ROTATION_3D)
				out.track_set_path(track, NodePath(str(to_skeleton) + ":" + target.get_bone_name(bone)))
				out_tracks[bone] = track
			elif not inverse_pairs.has(bone):
				var track := out.add_track(Animation.TYPE_ROTATION_3D)
				out.track_set_path(track, NodePath(str(to_skeleton) + ":" + target.get_bone_name(bone)))
				out.rotation_track_insert_key(track, 0.0, fist.get(bone, target.get_bone_rest(bone).basis.get_rotation_quaternion()))
		var out_hips := out.add_track(Animation.TYPE_POSITION_3D)
		out.track_set_path(out_hips, NodePath(str(to_skeleton) + ":" + target.get_bone_name(target_hips)))
		# Strikes with no timing given have their impact measured at the frame
		# the hands or feet reach furthest from the hips.
		var measure: bool = _is_strike(logical) and not config.get("timing", {}).has(logical)
		var peak_extent := -1.0
		var peak_time := -1.0
		var step := 1.0 / 30.0
		var time := 0.0
		while time <= clip.length + 0.0001:
			var at := minf(time, clip.length)
			var s_world := {}
			for bone in source.get_bone_count():
				var local := source.get_bone_rest(bone).basis.get_rotation_quaternion()
				if rotation_tracks.has(bone):
					local = clip.rotation_track_interpolate(rotation_tracks[bone], at)
				var parent := source.get_bone_parent(bone)
				s_world[bone] = (s_world[parent] if parent >= 0 else Quaternion.IDENTITY) * local
			var t_world := {}
			for bone in target.get_bone_count():
				var parent := target.get_bone_parent(bone)
				var parent_world: Quaternion = t_world[parent] if parent >= 0 else t_node
				var source_bone = inverse_pairs.get(bone)
				if source_bone != null:
					t_world[bone] = (s_world[source_bone] as Quaternion) * (offset[source_bone] as Quaternion)
					var local: Quaternion = (parent_world.inverse() * t_world[bone]).normalized()
					if damped.has(bone):
						# The collarbones roll only part way: the pack's boxers drive
						# the shoulder far forward on every punch, and the bodies'
						# vests and hoods (skinned to it) tore forward with it. The
						# arm below keeps its own world turn, so the fist still
						# reaches where the clip sends it.
						local = target.get_bone_rest(bone).basis.get_rotation_quaternion().slerp(local, SHOULDER_ROLL)
						t_world[bone] = parent_world * local
					out.rotation_track_insert_key(out_tracks[bone], at, local)
				elif bone == middle:
					# The pack bends its back at two joints, this skeleton at three:
					# the middle one takes half of the turn from the lower spine to
					# the chest, so the twist of a punch runs up the whole back
					# instead of folding at one joint under the chest.
					var chest_world: Quaternion = (s_world[inverse_pairs[chest]] as Quaternion) * (offset[inverse_pairs[chest]] as Quaternion)
					var rest_mid := target.get_bone_rest(bone).basis.get_rotation_quaternion()
					var rest_chest := target.get_bone_rest(chest).basis.get_rotation_quaternion()
					var bend := (parent_world.inverse() * chest_world) * (rest_mid * rest_chest).inverse()
					var local := (Quaternion.IDENTITY.slerp(bend.normalized(), 0.5) * rest_mid).normalized()
					t_world[bone] = parent_world * local
					out.rotation_track_insert_key(out_tracks[bone], at, local)
				else:
					t_world[bone] = parent_world * target.get_bone_rest(bone).basis.get_rotation_quaternion()
			if measure:
				var t_pos := {}
				for bone in target.get_bone_count():
					var parent := target.get_bone_parent(bone)
					t_pos[bone] = Vector3.ZERO if parent < 0 else (t_pos[parent] as Vector3) + (t_world[parent] as Quaternion) * target.get_bone_rest(bone).origin
				for limb in limbs:
					var d: Vector3 = (t_pos[limb] as Vector3) - (t_pos[target_hips] as Vector3)
					# Furthest ahead, toward the rival (+Z here): measured in every
					# direction, a back kick's impact was read off the moment its
					# foot was out behind the fighter.
					var extent := d.z
					if extent > peak_extent:
						peak_extent = extent
						peak_time = at
			var hips := target.get_bone_rest(target_hips).origin
			if hips_track >= 0:
				var moved: Vector3 = clip.position_track_interpolate(hips_track, at) - s_hips_rest
				var parent_world: Quaternion = s_world[source.get_bone_parent(source_hips)] if source.get_bone_parent(source_hips) >= 0 else Quaternion.IDENTITY
				hips += t_node.inverse() * (parent_world * moved) * scale
			out.position_track_insert_key(out_hips, at, hips)
			time += step
		var key: String = "pack_" + logical
		if measure and peak_time >= 0.0:
			# The blow lands at full extension, not at a guessed fraction.
			var timing: Dictionary = config.get("timing", {})
			timing[logical] = [maxf(0.0, peak_time - 0.4), peak_time, minf(clip.length, peak_time + 0.55)]
			config["timing"] = timing
		_pin_hips(out)
		# How fast the clip walks (its Root's travel), in metres per second of
		# a fighter of the game's height (the pack's actor is about 1.75 m).
		var pace := 0.0
		if root_track >= 0 and clip.track_get_key_count(root_track) > 1:
			var first: Vector3 = clip.track_get_key_value(root_track, 0)
			var last: Vector3 = clip.track_get_key_value(root_track, clip.track_get_key_count(root_track) - 1)
			pace = Vector2(last.x - first.x, last.z - first.z).length() / maxf(clip.length, 0.01) * MODELS.FIGHTER_HEIGHT / 1.75
		clip_pace["files/" + key] = pace
		_centre_hips(out, target.get_bone_rest(target_hips).origin)
		if logical in AIR_STRIKES:
			# Recorded mid-jump, these clips hold the hips low (the pack lifts
			# its jumper on the Root); the game's physics lifts the body, so the
			# hips are raised back to standing height or the fighter squatted
			# in the air.
			var first: Vector3 = out.track_get_key_value(out_hips, 0)
			var lift := target.get_bone_rest(target_hips).origin.y - first.y
			for k in out.track_get_key_count(out_hips):
				out.track_set_key_value(out_hips, k, (out.track_get_key_value(out_hips, k) as Vector3) + Vector3(0.0, lift, 0.0))
		elif logical == "jump":
			# The game's physics lifts the body; the clip keeps only the
			# tuck, or the fighter would rise twice as high.
			var ground: Vector3 = out.track_get_key_value(out_hips, 0)
			for k in out.track_get_key_count(out_hips):
				var v: Vector3 = out.track_get_key_value(out_hips, k)
				out.track_set_key_value(out_hips, k, Vector3(v.x, minf(v.y, ground.y), v.z))
		elif not logical in UNGROUNDED:
			_ground_feet(out, target)
		library.add_animation(key, out)
	scene.free()

## Puts a retargeted clip's hips over the rig's own (pinned by _pin_hips
## to wherever the clip began): a clip that starts with the hips off to one
## side would play the whole body away from the fighter's real spot, hitbox
## and shadow for the length of the move.
static func _centre_hips(animation: Animation, rest: Vector3) -> void:
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D or animation.track_get_key_count(track) == 0:
			continue
		var first: Vector3 = animation.track_get_key_value(track, 0)
		var shift := Vector3(rest.x - first.x, 0.0, rest.z - first.z)
		for k in animation.track_get_key_count(track):
			animation.track_set_key_value(track, k, (animation.track_get_key_value(track, k) as Vector3) + shift)

## Moves left off the floor by _ground_feet: in the air, or lying down.
const UNGROUNDED := ["jump", "ko", "fall", "getup"]

## Lifts or lowers a retargeted clip so its lowest foot rests where the
## rig's feet rest: the pack's performer is proportioned a little
## differently, so after retargeting the hips can sit low and the feet sink
## into the floor. Measured by posing the target skeleton from the clip's
## own tracks every few frames.
func _ground_feet(animation: Animation, target: Skeleton3D) -> void:
	var feet: Array[int] = []
	for key in ["leftfoot", "rightfoot"]:
		for bone in target.get_bone_count():
			if _bone_key(target.get_bone_name(bone)) == key:
				feet.append(bone)
	if feet.size() < 2:
		return
	var tracks := {}
	var hips_track := -1
	for track in animation.get_track_count():
		var bone := target.find_bone(String(animation.track_get_path(track).get_concatenated_subnames()))
		if bone < 0:
			continue
		if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			tracks[bone] = track
		elif animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
			hips_track = track
	if hips_track < 0:
		return
	var hips_bone := target.find_bone(String(animation.track_get_path(hips_track).get_concatenated_subnames()))
	var rest_floor := minf(target.get_bone_global_rest(feet[0]).origin.y, target.get_bone_global_rest(feet[1]).origin.y)
	var lowest := INF
	var t := 0.0
	while t <= animation.length:
		for foot in feet:
			var chain: Array[int] = []
			var bone := foot
			while bone >= 0:
				chain.push_front(bone)
				bone = target.get_bone_parent(bone)
			var at := Transform3D()
			for link in chain:
				var local := target.get_bone_rest(link)
				if tracks.has(link):
					local.basis = Basis(animation.rotation_track_interpolate(tracks[link], t))
				if link == hips_bone:
					local.origin = animation.position_track_interpolate(hips_track, t)
				at = at * local
			lowest = minf(lowest, at.origin.y)
		t += 0.1
	var lift := rest_floor - lowest
	if absf(lift) < 0.01 or absf(lift) > 0.5:
		return
	for k in animation.track_get_key_count(hips_track):
		var v: Vector3 = animation.track_get_key_value(hips_track, k)
		animation.track_set_key_value(hips_track, k, v + Vector3(0.0, lift, 0.0))

## Plays a whole jump clip (take-off, tuck, landing) across the time the
## fighter will actually spend in the air.
func _jump_speed(fighter: Node, clip: String) -> float:
	var animation := player.get_animation(clip)
	var body = fighter.get("body")
	if animation == null or body == null:
		return 1.0
	var gravity: float = absf(float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)))
	var tempo: float = fighter.get_script().get_script_constant_map().get("COMBAT_TEMPO", 1.0)
	var rise: float = maxf(body.velocity.y, 0.0)
	var air := 2.0 * rise / maxf(gravity, 0.1) / maxf(tempo, 0.1)
	if air < 0.2:
		return 1.0
	return clampf(animation.length / air, 0.6, 3.0)

static func _hips_height(skeleton: Skeleton3D) -> float:
	for bone in skeleton.get_bone_count():
		if _bone_key(skeleton.get_bone_name(bone)) == "hips":
			return skeleton.get_bone_global_rest(bone).origin.length()
	return 0.0

static func _node_rotation(skeleton: Skeleton3D, top: Node) -> Quaternion:
	var rotation := Quaternion.IDENTITY
	var node: Node = skeleton
	while node != null and node != top:
		if node is Node3D:
			rotation = (node as Node3D).transform.basis.get_rotation_quaternion() * rotation
		node = node.get_parent()
	return rotation

## Holds the root bone's horizontal position at its first key (keeping the
## up-down bob), making a travelling clip play in place. Returns how fast
## the clip travelled, in metres per second.
func _pin_hips(animation: Animation) -> float:
	var pace := 0.0
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		var bone := String(animation.track_get_path(track).get_concatenated_subnames())
		if not bone.to_lower().ends_with("hips") and bone != "root":
			continue
		var first: Vector3 = animation.track_get_key_value(track, 0)
		var last: Vector3 = animation.track_get_key_value(track, animation.track_get_key_count(track) - 1)
		pace = Vector2(last.x - first.x, last.z - first.z).length() / maxf(animation.length, 0.01)
		for key in animation.track_get_key_count(track):
			var value: Vector3 = animation.track_get_key_value(track, key)
			animation.track_set_key_value(track, key, Vector3(first.x, value.y, first.z))
	return pace

## Finds the idle clip's upper-body rotation tracks for the guard overlay.
func _prepare_guard() -> void:
	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty() or not clip_names.has("idle"):
		return
	skeleton = skeletons[0]
	guard_clip = player.get_animation(clip_names.idle)
	for track in guard_clip.get_track_count():
		if guard_clip.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(guard_clip.track_get_path(track).get_concatenated_subnames())
		if UPPER_BODY.any(func(part): return bone_name.contains(part)):
			var bone := skeleton.find_bone(bone_name)
			if bone >= 0:
				guard_tracks.append([track, bone])

## What a clip is usually called in a downloaded rig, per logical clip;
## the first keyword that appears in an animation's name wins, earlier
## keywords first. Lets a rigged model dropped into a fighter's folder play
## without a hand-written clip table.
const CLIP_KEYWORDS := {
	"idle": ["fight_idle", "boxing_idle", "idle", "stand", "breath"],
	"walk": ["walk_forward", "walking", "walk"],
	"walk_back": ["walk_back", "walking_back", "backward", "backwards"],
	"sidestep_left": ["strafe_left", "step_left", "side_left"],
	"sidestep_right": ["strafe_right", "step_right", "side_right"],
	"run": ["run", "sprint", "jog"],
	"dash": ["dash"], "backdash": ["dodge", "evade"],
	"jump": ["jump"], "land": ["land", "fall"],
	"block": ["block", "guard", "defend"], "block_hit": ["block_hit", "guard_hit"],
	"hit": ["head_hit", "hit_react", "hit", "hurt", "impact", "damage", "react", "flinch"],
	"hit_heavy": ["body_hit", "big_hit", "heavy_hit", "knockback", "stagger"],
	"ko": ["knocked_out", "knockout", "death", "dying", "die", "dead", "ko", "defeat"],
	"jab": ["jab", "left_punch", "punch", "attack-melee", "melee", "attack"],
	"punch_heavy": ["hook", "haymaker", "heavy_punch", "right_punch", "cross", "punch"],
	"uppercut": ["upper"], "kick": ["kick"], "kick_spin": ["spin", "roundhouse", "flip"],
	"kick_front": ["front_kick", "push_kick"], "grapple": ["throw", "grab", "grapple", "slam"],
	"taunt": ["taunt"], "victory": ["victory", "win", "cheer", "celebrat", "dance"],
	"injured": ["injured", "limp"],
	"thrown": ["takedown_victim", "thrown", "grabbed"],
	"getup": ["get_up_from_back", "get_up", "getting_up", "stand_up"],
}

## The animation in `names` that best fits `logical`, or "" when none does.
## Names are compared lower-case with spaces and dashes folded to
## underscores; bind-pose leftovers ("Take 001", "bind") never match.
static func match_clip(logical: String, names: Array) -> String:
	var keywords: Array = CLIP_KEYWORDS.get(logical, [])
	for keyword in keywords:
		var key: String = String(keyword).replace("-", "_")
		for name in names:
			var folded := String(name).to_lower().replace(" ", "_").replace("-", "_").replace("|", "_")
			if folded.begins_with("take_") or folded.contains("bind") or folded.contains("t_pose") or folded.contains("tpose"):
				continue
			if folded.contains(key):
				return String(name)
	return ""

func _resolve_clips() -> void:
	var available := player.get_animation_list()
	var wanted: Dictionary = config.get("clips", {})
	for logical in wanted:
		var name: String = wanted[logical]
		for candidate in [name, "files/" + name]:
			if available.has(candidate):
				clip_names[logical] = candidate
	# Anything the table did not name is matched by keyword, so a rig
	# dropped into the folder with its own animations plays as it is.
	for logical in CLIP_KEYWORDS:
		if not clip_names.has(logical):
			var guess := match_clip(logical, Array(available))
			if guess != "":
				clip_names[logical] = guess
	for logical in FALLBACK.keys() + ["idle"]:
		var probe: String = logical
		var guard := 0
		while not clip_names.has(probe) and FALLBACK.has(probe) and guard < 8:
			probe = FALLBACK[probe]
			guard += 1
		if clip_names.has(probe):
			clip_names[logical] = clip_names[probe]
	for name in clip_names.values():
		var animation := player.get_animation(name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR if clip_names.find_key(name) in LOOPING else Animation.LOOP_NONE
	_measure_ko_start()

## A knockout plays from just before the body drops: knockout clips open
## with a second or more of reeling, which the KO's slow motion stretched
## so long the fighter was still on his feet when the replay began. Found
## from the hips' height in the clip (the shared clip's is set in
## fighter_models.gd KO_FALL_START).
func _measure_ko_start() -> void:
	var starts: Dictionary = config.get("starts", {})
	var animation := player.get_animation(clip_names.get("ko", ""))
	if starts.has("ko") or animation == null:
		return
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D or _bone_key(String(animation.track_get_path(track).get_concatenated_subnames())) != "hips":
			continue
		if animation.track_get_key_count(track) < 2:
			return
		var opening: float = (animation.track_get_key_value(track, 0) as Vector3).y
		for key in animation.track_get_key_count(track):
			if (animation.track_get_key_value(track, key) as Vector3).y < opening * 0.85:
				starts["ko"] = maxf(0.0, animation.track_get_key_time(track, key) - 0.2)
				config["starts"] = starts
				return
		return

## Sounds that belong to the body, read off the pose last drawn: a step
## each time a foot plants while walking or running, and the thud of a
## falling fighter the moment its hips reach the ground (a knockout or a
## sweep), not when the blow landed. A plant is the foot coming back down
## to its own resting height (each rig's ankle rests at its own height)
## after lifting off it; speed can't tell, as feet creep over the floor
## when a clip and the ground speed don't quite match. Heights in metres.
const FOOT_LIFT := 0.02
const FOOT_REST := 0.01
const FOOT_GAP := 0.2
const HIPS_DOWN := 0.42
var _foot_lifted := {}
var _foot_floor := {}
var _foot_planted_at := {}
var _cue_clock := 0.0
var _fell := false
var _cue_bones := {}
func _sound_cues(fighter: Node, step: float) -> void:
	if skeleton == null or root == null or fighter.get("body") == null:
		return
	var floor_y: float = fighter.body.global_position.y
	var S: Dictionary = fighter.State
	var walking: bool = fighter.state in [S.WALK, S.DASH] and fighter_grounded() and fighter.get("crouching") != true
	for key in ["leftfoot", "rightfoot", "hips"]:
		if not _cue_bones.has(key):
			_cue_bones[key] = _bone(key)
	_cue_clock += step
	for key in ["leftfoot", "rightfoot"]:
		var bone: int = _cue_bones[key]
		if bone < 0:
			continue
		var height: float = (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin.y - floor_y
		# The foot's resting height: the lowest it has been lately.
		var rest: float = minf(_foot_floor.get(key, height) + step * 0.05, height)
		_foot_floor[key] = rest
		if height > rest + FOOT_LIFT:
			_foot_lifted[key] = true
		elif height < rest + FOOT_REST and _foot_lifted.get(key, false):
			_foot_lifted[key] = false
			if walking and _cue_clock - float(_foot_planted_at.get(key, -1.0)) >= FOOT_GAP:
				_foot_planted_at[key] = _cue_clock
				var run: bool = fighter.running or fighter.state == S.DASH
				preload("res://scripts/sfx.gd").fire("step_run" if run else "step_walk", -12.0 if run else -15.0)
	var falling: bool = fighter.state == S.KO or (fighter.state == S.KNOCKDOWN and fighter.get("swept") == true)
	var hips: int = _cue_bones["hips"]
	if falling and hips >= 0:
		var hips_height: float = (skeleton.global_transform * skeleton.get_bone_global_pose(hips)).origin.y - floor_y
		if not _fell and hips_height < HIPS_DOWN:
			_fell = true
			preload("res://scripts/sfx.gd").fire("ko" if fighter.state == S.KO else "fall", 0.0 if fighter.state == S.KO else -2.0)
	else:
		_fell = false

## Picks and poses the clip for this frame. Called from the visual's
## _process and sync_pose.
func update(delta: float) -> void:
	_update_pose(delta)

## Every pack stance leads with the left foot, which turns the chest to the
## fighter's right: from the camera the fighter on the left shows the chest,
## the one on the right showed the back. As in 2D fighting games, a fighter
## whose right side faces away from the camera is drawn mirrored (a
## southpaw), so both always face the camera. Switched only while standing,
## stepping or guarding (never mid-strike or mid-fall), with a margin so
## circling side-on can't flicker between the two.
var mirrored := false
func _mirror_basis(fighter: Node) -> Basis:
	var camera := root.get_viewport().get_camera_3d() if root.is_inside_tree() else null
	if camera != null and fighter.get("body") != null:
		var S: Dictionary = fighter.State
		var busy: bool = fighter.state in [S.PUNCH, S.KICK, S.HITSTUN, S.STRUCK, S.BLOCKSTUN, S.KO, S.KNOCKDOWN, S.THROWN, S.THROWING, S.SUPER]
		if not busy or pose_override != "":
			# The fighter's right: forward x up (the model's own turn is 0; the
			# facing is set on a parent).
			var forward: Vector3 = fighter.get("forward") if fighter.get("forward") is Vector3 else Vector3.RIGHT
			var right := forward.cross(Vector3.UP)
			var to_camera: Vector3 = camera.global_position - fighter.body.global_position
			to_camera.y = 0.0
			var side := right.dot(to_camera.normalized()) if to_camera.length() > 0.01 else 1.0
			if side < -0.15:
				mirrored = true
			elif side > 0.15:
				mirrored = false
	return Basis.from_scale(Vector3(1.0, 1.0, -1.0)) if mirrored else Basis.IDENTITY

func _update_pose(delta: float) -> void:
	if not active or visual.fighter == null:
		return
	var fighter: Node = visual.fighter
	_sound_cues(fighter, delta)
	# Only the facing turn: the procedural rig's knockdown/hit spin would
	# double up with the clips' own falls and sink the model into the floor.
	root.transform = Transform3D(Basis(Vector3.UP, visual.model.rotation.y) * _mirror_basis(fighter), visual.model.position)
	var frozen: bool = fighter.combat_paused or fighter.hitstop_remaining > 0.0
	var S: Dictionary = fighter.State
	var state: int = fighter.state
	var logical := "idle"
	var crouched: bool = fighter.get("crouching") == true and clip_names.has("crouch")
	match state:
		S.IDLE:
			logical = "crouch" if crouched else "idle"
		S.PUNCH, S.KICK:
			logical = _attack_clip(fighter)
		S.WALK:
			logical = "crouch" if crouched else _move_clip(fighter)
		S.DASH:
			logical = "dash" if fighter._dash_dir == fighter.facing else "backdash"
		S.JUMP, S.JUMP_START:
			logical = "jump"
		S.LAND:
			logical = "land"
		S.BLOCK:
			logical = ("crouch_block" if clip_names.has("crouch_block") else "crouch") if crouched else "block"
		S.BLOCKSTUN:
			logical = ("crouch_block_hit" if clip_names.has("crouch_block_hit") else "crouch") if crouched else "block_hit"
		S.HITSTUN, S.STRUCK:
			logical = _reaction if _reaction != "" else ("hit_heavy" if last_hit_heavy else "hit")
		S.SUPER:
			logical = "super_combo"
		S.KO:
			logical = "downed" if fighter.get("thrown_down") else "ko"
		S.THROWING:
			logical = "throw" if fighter.throw_time < fighter.throw_rise_at else "idle"
		S.THROWN:
			logical = "thrown"
		S.KNOCKDOWN:
			logical = "downed" if fighter.knockdown_time < THROW.LIE_TIME else "getup"
			if fighter.get("swept") == true and fighter.knockdown_time < 0.0:
				logical = "swept"
	# The winner celebrates over a knocked-out rival.
	var rival = fighter.get("opponent")
	if state == S.IDLE and rival != null and rival.state == rival.State.KO:
		logical = "victory"
	# The stun is over but the body is still recovering: standing still, the
	# fighter finishes its flinch; moving, guarding or striking cuts it off.
	var tailing := false
	if state in [S.HITSTUN, S.STRUCK] and logical in REACTIONS:
		_tail = logical
	elif state == S.IDLE and logical == "idle" and _tail != "" and pose_override == "" and clip_names.get(_tail, "") == current:
		logical = _tail
		tailing = true
	else:
		_tail = ""
	if pose_override != "":
		logical = pose_override
	var clip: String = clip_names.get(logical, clip_names.get("idle", ""))
	if clip.is_empty():
		return
	var entered := state != _last_state
	_last_state = state
	_posture = 0.0
	if state == S.PUNCH and fighter.attack_variant == "super":
		logical = "super_open"
	if logical in ["super_open", "super_combo"] and _play_super(fighter, logical, delta, frozen):
		guard_weight = 0.0
		_procedural(fighter, logical, delta, frozen)
		_reach_step(fighter, delta, false)
		return
	if logical in ["super_open", "super_combo"]:
		logical = "punch_heavy"
		clip = clip_names.get(logical, clip_names.get("idle", ""))
	if logical in ["throw", "thrown", "downed", "swept"] or (logical == "getup" and _has_own("getup")):
		guard_weight = 0.0
		_play_throw(fighter, logical, delta, frozen)
		_procedural(fighter, logical, delta, frozen)
		_reach_step(fighter, delta, false)
		return
	if logical == "getup":
		logical = "idle"
		clip = clip_names.get("idle", "")
	if _is_strike(logical) and pose_override == "":
		guard_weight = 0.0
		_scrub_attack(fighter, logical, clip, delta, frozen)
		_procedural(fighter, logical, delta, frozen)
		_lock_hips()
		_reach_step(fighter, delta, true)
		return
	_reach_step(fighter, delta, false)
	var restart := _react and logical in REACTIONS
	_react = false
	if clip != current or (entered and not logical in LOOPING and not tailing) or restart:
		# Snap into a flinch; ease back out of one.
		var was_reaction: bool = current != "" and REACTIONS.any(func(name): return clip_names.get(name, "") == current)
		# Footwork changes (stand, walk, run, step) melt into each other.
		var stepping: bool = logical in LOOPING and current != "" and current in LOOPING.map(func(name): return clip_names.get(name, ""))
		var settle := 0.12
		if was_reaction:
			settle = 0.22
		elif stepping:
			settle = 0.24
		if _from_strike and not logical in REACTIONS:
			# Flow out of a punch or kick back into guard, don't snap.
			settle = maxf(settle, STRIKE_SETTLE)
		_from_strike = false
		# Into a flinch fast, but over a few frames: a cut in a single frame
		# threw the hands and head a metre between two frames.
		# The same clip starting over (a second blow's flinch, a reaction
		# into the same reaction) has nothing to cross-fade from, so the
		# pose it leaves is blended by hand once the clip has moved on.
		var again := clip == current
		if again:
			_capture_pose(REACT_BLEND)
		elif not _is_strike(logical):
			_blend_from.clear()
		player.play(clip, 0.0 if logical == "ko" else 0.12 if logical in REACTIONS else settle)
		if restart or again:
			player.seek(0.0, true)
		# Clips that open with a still beat (the knockout) start where the
		# motion starts.
		var start: float = float(config.get("starts", {}).get(logical, 0.0))
		if start > 0.0:
			player.seek(start, true)
		_ko_measure = logical == "ko"
		if not _ko_measure:
			_ko_shift = Vector3.ZERO
		current = clip
	player.speed_scale = 0.0 if frozen else _loop_speed(fighter, logical, clip)
	if logical == "jump" and not frozen and entered:
		_jump_rate = _jump_speed(fighter, clip)
	if logical == "jump" and not frozen:
		player.speed_scale = _jump_rate
	if logical in REACTIONS and not frozen:
		# The recoil plays out inside the stun instead of being cut off
		# halfway and snapping back to the stance: the first ~0.9 s of the
		# clip (its flinch and recovery) is fitted to the stun length,
		# worked out once as the reaction starts.
		var useful := minf(player.get_animation(clip).length, 0.9)
		if tailing:
			_react_speed = move_toward(_react_speed, 1.0, delta * 3.0)
			if player.current_animation_position >= useful:
				_tail = ""
		elif restart or entered or _react_speed <= 0.0:
			var stun: float = float(fighter.get("stun_timer")) if fighter.get("stun_timer") != null else 0.3
			_react_speed = clampf(useful / maxf(stun, 0.18), 0.9, REACT_MAX_SPEED)
		player.speed_scale = _react_speed
	else:
		_react_speed = 0.0
	player.advance(delta)
	if frozen:
		# Held at speed 0 (hit-stop, pause) the clip may not write its pose
		# again, and the layers below would pile onto last frame's: rewrite it.
		player.seek(player.current_animation_position, true)
	_blend_in(delta, frozen)
	# The knockout travels from where the fighter stood, not from where the
	# clip's hips happen to be at the moment it starts (that offset snapped
	# the body ~75 cm sideways in the first frames of the fall): the jump
	# on the first knockout frame is measured and cancelled from then on.
	var hips_bone := _bone("hips")
	if logical == "ko" and root != null and hips_bone >= 0:
		skeleton.force_update_all_bone_transforms()
		var hips_at: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hips_bone).origin
		if _ko_measure:
			_ko_measure = false
			_ko_shift = hips_at - _last_hips
			_ko_shift.y = 0.0
		var parent := root.get_parent() as Node3D
		root.position -= parent.global_transform.basis.inverse() * _ko_shift
	elif hips_bone >= 0 and skeleton != null:
		_last_hips = skeleton.global_transform * skeleton.get_bone_global_pose(hips_bone).origin
	if not frozen:
		guard_time += delta
		guard_weight = move_toward(guard_weight, 1.0 if logical in GUARDED else 0.0, delta * 8.0)
	_apply_guard()
	_procedural(fighter, logical, delta, frozen)

## The super on the fighter's combo clip. The opening strike plays the run-up
## so the clip reaches the super's start just as the strike connects, then
## carries on (a whiff) or hands over to the combo on the super's own clock.
## False when the rig has no clip for it.
func _play_super(fighter: Node, logical: String, delta: float, frozen: bool) -> bool:
	var data := SUPERS.get_super(str(fighter.character_profile.id))
	var clip: String = clip_names.get(str(data.get("clip", "")), "")
	if data.is_empty() or clip == "":
		return false
	var start := float(data.start)
	var time: float = fighter.super_clip_time() if logical == "super_combo" else 0.0
	if logical == "super_open":
		var startup: float = maxf(fighter.attack_startup(), 0.01)
		var t: float = fighter.attack_timer
		time = lerpf(maxf(0.0, start - 0.35), start, clampf(t / startup, 0.0, 1.0))
		if t > startup:
			time = start + 0.45 * clampf((t - startup) / maxf(fighter.attack_duration() - startup, 0.01), 0.0, 1.0)
	_scrub_clip(clip, time, delta, frozen)
	return true

## Whether the rig has its own clip for `logical`, not a fallback.
func _has_own(logical: String) -> bool:
	return clip_names.has(logical) and clip_names[logical] != clip_names.get("idle", "")

## The paired takedown, scrubbed on the throw's own clock so the attacker's
## and the victim's clips stay in step (see throw_data.gd). The bodies are
## carried by player_3d.gd along the clips' hip travel.
func _play_throw(fighter: Node, logical: String, delta: float, frozen: bool) -> void:
	var paired := _has_own("thrown")
	match logical:
		"throw":
			var time := THROW.clip_time(fighter.throw_time)
			if not paired:
				# A rig with its own grab (Mahabali's slam) plays it from its
				# impact frame to its end over the throw.
				var cut: Array = config.get("timing", {}).get("grapple", [])
				var animation := player.get_animation(clip_names.get("grapple", ""))
				if cut.size() == 3:
					time = lerpf(cut[1], cut[2], clampf(fighter.throw_time / THROW.END_TIME, 0.0, 1.0))
				elif animation != null:
					time = animation.length * lerpf(0.45, 1.0, clampf(fighter.throw_time / THROW.END_TIME, 0.0, 1.0))
			_scrub_clip(clip_names.get("grapple", ""), time, delta, frozen)
			if paired:
				# Chest up through the shot, back down for the drive to the floor.
				_posture = float(config.get("throw_posture", 0.0)) * smoothstep(0.85, 1.0, time) * (1.0 - smoothstep(1.3, 1.6, time))
			if fighter.ground_timer > 0.0:
				_ground_punch(fighter)
		"thrown":
			if paired:
				_scrub_clip(clip_names.thrown, THROW.clip_time(fighter.throw_time), delta, frozen)
			else:
				_fall(fighter.throw_time / THROW.END_TIME, delta, frozen)
		"swept":
			# Legs taken: the back half of the takedown's fall, quick.
			var fall := clampf(1.0 + fighter.knockdown_time / fighter.SWEEP_FALL, 0.0, 1.0)
			if paired:
				_scrub_clip(clip_names.thrown, lerpf(THROW.CLIP_CONTACT, THROW.CLIP_END, fall), delta, frozen)
			else:
				_fall(fall, delta, frozen)
		"downed":
			if paired:
				_scrub_clip(clip_names.thrown, THROW.CLIP_END, delta, frozen)
			else:
				_fall(1.0, delta, frozen)
		"getup":
			var rise := clampf((fighter.knockdown_time - THROW.LIE_TIME) / THROW.GETUP_TIME, 0.0, 1.0)
			var animation := player.get_animation(clip_names.getup)
			_scrub_clip(clip_names.getup, rise * animation.length, delta, frozen)

## A punch thrown down from the mount: the arms and shoulders of the jab
## or cross clip (alternating hands) laid over the kneeling pose, the trunk
## folding forward so the fist travels down into the rival.
func _ground_punch(fighter: Node) -> void:
	var logical := "cross" if fighter.ground_hits % 2 == 0 else "jab"
	var clip: String = clip_names.get(logical, "")
	var animation := player.get_animation(clip) if clip != "" else null
	if animation == null or skeleton == null:
		return
	if not _overlay_tracks.has(clip):
		var tracks := []
		for track in animation.get_track_count():
			if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
				continue
			var bone_name := String(animation.track_get_path(track).get_concatenated_subnames())
			# Arms only: the spine keeps the mount and is folded below.
			if ["Shoulder", "Arm", "Hand"].any(func(part): return bone_name.contains(part)):
				var bone := skeleton.find_bone(bone_name)
				if bone >= 0:
					tracks.append([track, bone])
		_overlay_tracks[clip] = tracks
	var progress := clampf(1.0 - fighter.ground_timer / THROW.GROUND_PUNCH_TIME, 0.0, 1.0)
	var cut: Array = config.get("timing", {}).get(logical, [0.0, animation.length * 0.45, animation.length])
	var landed: float = THROW.GROUND_IMPACT / THROW.GROUND_PUNCH_TIME
	var time: float = lerpf(cut[0], cut[1], progress / landed) if progress < landed else lerpf(cut[1], cut[2], (progress - landed) / (1.0 - landed))
	var weight := smoothstep(0.0, 0.25, progress) * (1.0 - smoothstep(0.7, 1.0, progress))
	for pair in _overlay_tracks[clip]:
		var rotation: Quaternion = animation.rotation_track_interpolate(pair[0], minf(time, animation.length - 0.001))
		skeleton.set_bone_pose_rotation(pair[1], skeleton.get_bone_pose_rotation(pair[1]).slerp(rotation, weight))
	# Rear back to load the punch, drop the trunk into it on impact, settle.
	var load := smoothstep(0.0, landed * 0.8, progress) * (1.0 - smoothstep(landed * 0.8, landed, progress))
	var drive := smoothstep(landed * 0.75, landed, progress) * (1.0 - smoothstep(landed + 0.15, 1.0, progress))
	_posture = 0.3 * load - 0.32 * drive

## Taken off the feet (a sweep, a knockdown): the fall clip from standing
## to flat on the back, progress 0 to 1 (or the knockout's, without one).
func _fall(progress: float, delta: float, frozen: bool) -> void:
	var own := clip_names.has("fall")
	var clip: String = clip_names.get("fall", clip_names.get("ko", ""))
	var animation := player.get_animation(clip) if clip != "" else null
	if animation == null:
		return
	var time := clampf(progress, 0.0, 1.0) * (animation.length if own else 1.1)
	_scrub_clip(clip, minf(time, animation.length - 0.001), delta, frozen)

## Holds `clip` at `time`, blending in from the previous pose by hand when
## the clip changes (the player sits at speed 0, so its cross-fade can't).
func _scrub_clip(clip: String, time: float, delta: float, frozen: bool) -> void:
	var animation := player.get_animation(clip) if clip != "" else null
	if animation == null:
		return
	# A new clip, or this one jumping back (a super's next blow, a fall
	# after a get-up): blend from the pose the rig was in.
	if clip != current or time < _last_scrub_time - 0.05:
		_capture_pose(THROW_BLEND)
		player.play(clip, 0.0)
		current = clip
	_last_scrub_time = time
	player.speed_scale = 0.0
	player.seek(clampf(time, 0.0, animation.length - 0.001), true)
	_blend_in(delta, frozen)

## Keeps the hips over the fighter's physics body through a strike. Some
## clips (spinning and jumping kicks especially) drift the hips sideways or
## forward on their own, which would put the foot or fist metres from where
## the game lands the hit; the whole model slides back under the body.
func _lock_hips() -> void:
	var hips := _bone("hips")
	if hips < 0 or skeleton == null or root == null:
		return
	var at: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(hips).origin
	var home: Vector3 = root.global_position
	var drift := Vector3(at.x - home.x, 0.0, at.z - home.z)
	if drift.length() < 0.02:
		return
	var parent := root.get_parent() as Node3D
	root.position -= parent.global_transform.basis.inverse() * drift

## Steps the attacker in during a strike so the fist or foot meets the
## rival's body instead of stopping short of it (gameplay reach and hit
## timing are unchanged; this only moves the model). Eases in through the
## wind-up and back out through recovery.
func _reach_step(fighter: Node, delta: float, attacking: bool) -> void:
	var goal := 0.0
	var rival = fighter.get("opponent")
	var direction := Vector3.ZERO
	if attacking and skeleton != null and rival != null and rival.get_node_or_null("Visual") != null:
		var other = rival.get_node("Visual").get("animated")
		if other != null and other.active and other.skeleton != null:
			var chest_bone: int = other._bone("spine2")
			var chest: Vector3 = other.skeleton.global_transform * other.skeleton.get_bone_global_pose(chest_bone).origin
			var here: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(_bone("hips")).origin
			direction = Vector3(chest.x - here.x, 0.0, chest.z - here.z)
			var apart := direction.length()
			if apart > 0.01 and apart < 1.6:
				direction /= apart
				# The limb furthest forward is the one striking: feet and
				# shins for a kick, hands and elbows for a punch.
				var tip := -INF
				var kicking: bool = fighter.state == fighter.State.KICK
				for key in (["leftfoot", "rightfoot", "leftleg", "rightleg"] if kicking else ["lefthand", "righthand", "leftforearm", "rightforearm"]):
					var bone := _bone(key)
					if bone >= 0:
						var at: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
						tip = maxf(tip, (at - here).dot(direction))
				# root was reset this frame, so tip is measured without the step.
				var short := apart - tip - CONTACT
				# Full step by the moment the blow lands, held through the active
				# frames, released over the recovery.
				var t: float = fighter.attack_timer
				var startup: float = maxf(fighter.attack_startup(), 0.01)
				var total: float = maxf(fighter.attack_duration(), startup + 0.01)
				var envelope := smoothstep(0.0, startup * 0.8, t) * (1.0 - smoothstep(startup + (total - startup) * 0.45, total, t))
				goal = clampf(minf(short, apart - BODY_GAP), 0.0, MAX_REACH_STEP * (1.5 if kicking else 1.0)) * envelope
	_reach = lerpf(_reach, goal, 1.0 - exp(-30.0 * delta))
	if _reach > 0.001 and direction != Vector3.ZERO:
		var parent := root.get_parent() as Node3D
		root.position += parent.global_transform.basis.inverse() * (direction * _reach)

## Bones by the Mixamo-style key their name ends with (see _bone_key).
func _bone(key: String) -> int:
	if skeleton == null:
		return -1
	for bone in skeleton.get_bone_count():
		if _bone_key(skeleton.get_bone_name(bone)) == key:
			return bone
	return -1

## Finds the spine and leg bones and works out, for each, which local axis
## and sign bends it the way the layers below want: knees folding the foot
## back, hips lifting the knee forward, the spine leaning the head back.
func _calibrate() -> void:
	_legs.clear()
	_spine.clear()
	if skeleton == null:
		var skeletons := character.find_children("*", "Skeleton3D", true, false)
		if skeletons.is_empty():
			return
		skeleton = skeletons[0]
	var forward: Vector3 = skeleton.global_transform.basis.inverse() * root.global_transform.basis.x
	var up: Vector3 = skeleton.global_transform.basis.inverse() * root.global_transform.basis.y
	for side in ["left", "right"]:
		var upper := _bone(side + "upleg")
		var knee := _bone(side + "leg")
		var foot := _bone(side + "foot")
		if upper < 0 or knee < 0 or foot < 0:
			continue
		var knee_axis := _best_axis(knee, foot, -forward)
		var hip_axis := _best_axis(upper, knee, forward + up * 0.5)
		if knee_axis.is_empty() or hip_axis.is_empty():
			continue
		_legs.append([upper, knee, hip_axis[1], knee_axis[1], hip_axis[0], knee_axis[0]])
	var head := _bone("head")
	for key in ["spine", "spine1", "spine2"]:
		var bone := _bone(key)
		if bone < 0 or head < 0:
			continue
		var axis := _best_axis(bone, head, -forward)
		if not axis.is_empty():
			_spine.append([bone, axis[1], axis[0]])
	var top := _bone("headtop_end")
	_head_roll = []
	if head >= 0 and top >= 0:
		var side: Vector3 = skeleton.global_transform.basis.inverse() * root.global_transform.basis.z
		_head_roll = _best_axis(head, top, side)
	# Measured from the live stance on the first idle frame (see
	# _aim_at_rival): some imported rigs have rest poses far from how the
	# head is actually held.
	_face_axis = Vector3.ZERO

## [axis, sign] for rotating `bone` so that `tip` moves along `want`, or
## [] when no local axis moves it there. Probes with a test rotation and
## restores the pose.
func _best_axis(bone: int, tip: int, want: Vector3) -> Array:
	var rest := skeleton.get_bone_pose_rotation(bone)
	skeleton.force_update_all_bone_transforms()
	var before := skeleton.get_bone_global_pose(tip).origin
	var best: Array = []
	var best_dot := 0.05
	for axis in [Vector3.RIGHT, Vector3.FORWARD, Vector3.UP]:
		skeleton.set_bone_pose_rotation(bone, rest * Quaternion(axis, 0.6))
		skeleton.force_update_all_bone_transforms()
		var moved := skeleton.get_bone_global_pose(tip).origin - before
		var along := moved.dot(want.normalized())
		if absf(along) > best_dot:
			best_dot = absf(along)
			best = [axis, signf(along)]
	skeleton.set_bone_pose_rotation(bone, rest)
	return best

## Jump tuck (only when the rig has no jump clip of its own) and the lean
## back of a guarded hit, both eased so they read as weight, not a switch.
func _procedural(fighter: Node, logical: String, delta: float, frozen: bool) -> void:
	if skeleton == null:
		return
	var S: Dictionary = fighter.State
	var tuck_target := 0.0
	if clip_names.get("jump", "") == clip_names.get("idle", "") and pose_override == "":
		match fighter.state:
			S.JUMP_START:
				tuck_target = 0.35
			S.JUMP:
				tuck_target = 0.9 if fighter.velocity.y < 0.0 else 0.55
			S.LAND:
				tuck_target = 0.4
	var lean_target := 0.0
	if fighter.state == S.BLOCKSTUN and clip_names.get("block_hit", "") == clip_names.get("block", ""):
		lean_target = 0.32 * visual._recoil()
	if not frozen:
		_tuck = move_toward(_tuck, tuck_target, delta * 9.0)
		_lean = move_toward(_lean, lean_target, delta * 12.0)
		# Semi-implicit spring, sub-stepped so a slow frame cannot blow it up.
		var steps := ceili(delta / 0.02)
		var step := delta / maxf(steps, 1)
		for i in steps:
			_recoil_vel += (-RECOIL_STIFFNESS * _recoil - _damping * _recoil_vel) * step
			_recoil += _recoil_vel * step
			_push_vel += (-RECOIL_STIFFNESS * _push - _damping * _push_vel) * step
			_push += _push_vel * step
			_snap_vel += (-RECOIL_STIFFNESS * 1.3 * _snap - RECOIL_DAMPING * _snap_vel) * step
			_snap += _snap_vel * step
		_damping = move_toward(_damping, RECOIL_DAMPING, delta * 6.0)
		if _recoil.length_squared() < 0.000001 and _recoil_vel.length_squared() < 0.0001:
			_recoil = Vector3.ZERO
			_recoil_vel = Vector3.ZERO
		if absf(_push) < 0.0005 and absf(_push_vel) < 0.005:
			_push = 0.0
			_push_vel = 0.0
	_apply_layers()
	_limit_facing(fighter)
	_aim_at_rival(fighter, delta, frozen)

## A blow turns a fighter, it doesn't spin him round. Some reaction clips
## (Vajraveer's hit_left / hit_right, Anug's hit_react) swing the whole body
## past 110 degrees, so the back of the head ended up facing the attacker.
## Real fighters turn 45-70 degrees from a hit, so the hips are turned back
## until the chest is no more than FACE_LIMIT off the line to the rival.
## Only while reacting, guarding or striking: the ground, throws, the super
## and cutscene poses keep their own turn.
const FACE_LIMIT := deg_to_rad(75.0)
var _face_bones: Array = []
## The last chest angle off the rival before the limit (radians), for tests.
var last_face := 0.0

func _limit_facing(fighter: Node) -> void:
	var S: Dictionary = fighter.State
	var rival = fighter.get("opponent")
	if pose_override != "" or rival == null or rival.get("body") == null:
		return
	if not fighter.state in [S.HITSTUN, S.BLOCKSTUN, S.STRUCK, S.PUNCH, S.KICK]:
		return
	if _face_bones.is_empty():
		_face_bones = [_bone("hips"), _bone("leftarm"), _bone("rightarm")]
	if _face_bones.has(-1):
		return
	var to_skeleton := skeleton.global_transform.basis.orthonormalized().inverse()
	var up: Vector3 = (to_skeleton * Vector3.UP).normalized()
	var shoulders: Vector3 = skeleton.get_bone_global_pose(_face_bones[2]).origin - skeleton.get_bone_global_pose(_face_bones[1]).origin
	shoulders -= up * shoulders.dot(up)
	var to_rival: Vector3 = to_skeleton * (rival.body.global_position - fighter.body.global_position)
	to_rival -= up * to_rival.dot(up)
	if shoulders.length_squared() < 0.0001 or to_rival.length_squared() < 0.0001:
		return
	var chest := up.cross(shoulders)
	var off := chest.signed_angle_to(to_rival, up)
	last_face = off
	if absf(off) <= FACE_LIMIT:
		return
	var turn := off - signf(off) * FACE_LIMIT
	var hips: int = _face_bones[0]
	var axis: Vector3 = (skeleton.get_bone_global_pose(hips).basis.orthonormalized().inverse() * up).normalized()
	skeleton.set_bone_pose_rotation(hips, skeleton.get_bone_pose_rotation(hips) * Quaternion(axis, turn))

## A fighter keeps its eyes on the rival whatever its body does: walk and
## stance clips turn the head with a bladed chest, which read as looking
## where it walks. After the clip's pose, the upper spine, neck and head
## turn about the vertical until the face points at the rival's head.
## Eased off where the clip owns the head (being hit, thrown, knocked down,
## the super, cutscene poses) and half way through strikes.
func _aim_at_rival(fighter: Node, delta: float, frozen: bool) -> void:
	var rival = fighter.get("opponent")
	var S: Dictionary = fighter.State
	var want := 1.0
	if rival == null or rival.get("body") == null or fighter.get("body") == null or pose_override != "":
		want = 0.0
	elif fighter.state in [S.HITSTUN, S.KO, S.THROWN, S.THROWING, S.KNOCKDOWN, S.SUPER, S.STRUCK]:
		want = 0.0
	elif fighter.state in [S.PUNCH, S.KICK]:
		# Strike clips already face the rival; turning the head on top of
		# the clip's own twist whips it around.
		want = 0.0
	if not frozen:
		_aim_weight = move_toward(_aim_weight, want, delta * (6.0 if want > _aim_weight else 10.0))
	if _aim_weight < 0.01:
		_aim = 0.0
		return
	var head := _bone("head")
	if head < 0:
		return
	# How far the body is off-line from the rival, read off the fighter's
	# own facing, never off a bone: the clip's head and chest sway (a
	# boxer's bob, a walk's twist) then can't feed back into the turn,
	# which swung the head with every step.
	var basis := skeleton.global_transform.basis.orthonormalized()
	var face: Vector3 = root.global_transform.basis.x
	face.y = 0.0
	var to_rival: Vector3 = rival.body.global_position - fighter.body.global_position
	to_rival.y = 0.0
	if face.length_squared() < 0.0001 or to_rival.length_squared() < 0.01:
		return
	var need := clampf(face.normalized().signed_angle_to(to_rival.normalized(), Vector3.UP), -AIM_LIMIT, AIM_LIMIT)
	if not frozen:
		# Eased and speed-capped: the head turns, it never snaps.
		var eased := lerpf(_aim, need, 1.0 - exp(-12.0 * delta))
		_aim = move_toward(_aim, eased, AIM_SPEED * delta)
	var up_local: Vector3 = basis.inverse() * Vector3.UP
	for link in AIM_CHAIN:
		var bone := _bone(link[0])
		if bone < 0:
			continue
		var axis: Vector3 = (skeleton.get_bone_global_pose(bone).basis.orthonormalized().inverse() * up_local).normalized()
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(axis, _aim * _aim_weight * link[1]))

## How much of the recoil spring reaches the body. The pack's reactions are
## full mocap flinches; the spring at full strength on top of them folded a
## struck fighter backwards like rubber, so it adds only a little weight.
const RECOIL_GAIN := 0.35

## Bends the calibrated bones by the current tuck, lean and recoil amounts.
func _apply_layers() -> void:
	if skeleton == null:
		return
	var recoil := _recoil * RECOIL_GAIN
	var push := _push * RECOIL_GAIN
	var snap := _snap * RECOIL_GAIN
	# Knees only ever buckle; the spring's overshoot must not lock them back.
	var buckle := maxf(recoil.z, 0.0) if fighter_grounded() else 0.0
	var bend := _tuck + buckle
	if bend > 0.001:
		for leg in _legs:
			var hip := skeleton.get_bone_pose_rotation(leg[0])
			skeleton.set_bone_pose_rotation(leg[0], hip * Quaternion(leg[4], leg[2] * 0.5 * bend))
			var knee := skeleton.get_bone_pose_rotation(leg[1])
			skeleton.set_bone_pose_rotation(leg[1], knee * Quaternion(leg[5], leg[3] * 1.05 * bend))
	var lean := _lean + recoil.x + _posture
	if absf(lean) > 0.001:
		for i in _spine.size():
			var part: Array = _spine[i]
			var share: float = _recoil_spread[i] if _spine.size() == 3 else 1.0 / _spine.size()
			# The guard lean stays even; only the recoil follows the spread.
			var angle: float = (_lean + _posture) / _spine.size() + recoil.x * share
			var pose := skeleton.get_bone_pose_rotation(part[0])
			skeleton.set_bone_pose_rotation(part[0], pose * Quaternion(part[2], part[1] * angle))
	if absf(snap) > 0.001 and not _head_roll.is_empty():
		var head := _bone("head")
		skeleton.set_bone_pose_rotation(head, skeleton.get_bone_pose_rotation(head) * Quaternion(_head_roll[0], _head_roll[1] * snap))
	if root == null or (absf(recoil.y) < 0.001 and buckle < 0.001 and absf(push) < 0.0005):
		return
	var parent := root.get_parent() as Node3D
	if absf(push) >= 0.0005:
		var ahead := root.global_transform.basis.x
		ahead.y = 0.0
		root.position += parent.global_transform.basis.inverse() * (ahead.normalized() * push)
	# The blow turns the whole body a touch, and a knee buckle lowers the
	# hips by what the bent legs lose in height, so the feet stay planted.
	root.rotate_object_local(Vector3.UP, recoil.y)
	if buckle > 0.001 and not _legs.is_empty():
		var leg: Array = _legs[0]
		var hip_at: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(leg[0]).origin
		var knee_at: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(leg[1]).origin
		var foot := _bone("leftfoot") if _bone("leftfoot") >= 0 else _bone("rightfoot")
		var length := hip_at.distance_to(knee_at)
		if foot >= 0:
			length += knee_at.distance_to(skeleton.global_transform * skeleton.get_bone_global_pose(foot).origin)
		var drop := length * (1.0 - cos(0.52 * buckle))
		root.position += parent.global_transform.basis.inverse() * Vector3(0.0, -drop, 0.0)

func fighter_grounded() -> bool:
	var fighter: Node = visual.fighter if visual != null else null
	return fighter == null or not fighter.has_method("_is_grounded") or fighter._is_grounded()

## Imported bodies arrive with whatever finish their exporter chose, often
## a metallic, glossy plastic. Each opaque material becomes the cinematic
## fighter finish (fighter_skin.gdshader: warm skin held off blowing out,
## tamed cloth saturation, a soft rim); see-through ones (hair cards) keep
## a matte standard finish.
const FIGHTER_FINISH := preload("res://scripts/fighter_skin.gdshader")
static var _finished: Dictionary = {}
func _polish_materials() -> void:
	for mesh: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override is StandardMaterial3D:
			mesh.material_override = _finish(mesh.material_override)
			continue
		for surface in mesh.mesh.get_surface_count() if mesh.mesh != null else 0:
			var material := mesh.get_active_material(surface)
			if material is StandardMaterial3D:
				mesh.set_surface_override_material(surface, _finish(material))

static func _finish(material: StandardMaterial3D) -> Material:
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		if not material.has_meta("polished"):
			material.set_meta("polished", true)
			material.metallic = minf(material.metallic, 0.12)
			material.roughness = maxf(material.roughness, 0.72)
			material.rim_enabled = true
			material.rim = 0.24
			material.rim_tint = 0.75
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		return material
	if _finished.has(material):
		return _finished[material]
	var finish := ShaderMaterial.new()
	finish.shader = FIGHTER_FINISH
	finish.set_shader_parameter("albedo_color", material.albedo_color)
	if material.albedo_texture != null:
		finish.set_shader_parameter("albedo_tex", material.albedo_texture)
	if material.normal_enabled and material.normal_texture != null:
		finish.set_shader_parameter("normal_tex", material.normal_texture)
		finish.set_shader_parameter("normal_strength", material.normal_scale)
	var channels := [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1), Vector4(0.333, 0.333, 0.333, 0)]
	finish.set_shader_parameter("roughness", material.roughness)
	if material.roughness_texture != null:
		finish.set_shader_parameter("roughness_tex", material.roughness_texture)
		finish.set_shader_parameter("roughness_channel", channels[material.roughness_texture_channel])
	else:
		finish.set_shader_parameter("roughness_channel", Vector4(1, 0, 0, 0))
	finish.set_shader_parameter("metallic", material.metallic)
	if material.metallic_texture != null:
		finish.set_shader_parameter("metallic_tex", material.metallic_texture)
		finish.set_shader_parameter("metallic_channel", channels[material.metallic_texture_channel])
	else:
		finish.set_shader_parameter("metallic_channel", Vector4(1, 0, 0, 0))
	_finished[material] = finish
	return finish

## Restarts the current clip on the next update (cutscenes repeating a move).
func replay() -> void:
	if player != null:
		player.stop()
	current = ""

## Blends the upper body toward the idle clip's boxing guard.
func _apply_guard() -> void:
	if guard_weight <= 0.0 or guard_clip == null:
		return
	var t := fmod(guard_time, guard_clip.length)
	for pair in guard_tracks:
		var guard: Quaternion = guard_clip.rotation_track_interpolate(pair[0], t)
		var pose := skeleton.get_bone_pose_rotation(pair[1])
		skeleton.set_bone_pose_rotation(pair[1], pose.slerp(guard, guard_weight))

## Attack clips, played scrubbed against the move's timing: the generic
## strikes and every pack strike a move names ("KB_...").
func _is_strike(logical: String) -> bool:
	return logical in SCRUBBED or logical.begins_with("KB_") or logical.begins_with("strike_")

func _attack_clip(fighter: Node) -> String:
	var variant: String = fighter.attack_variant
	# Every move names its own clip (action_moves.gd LOOK).
	var own := str(fighter.current_move.get("clip", "")) if fighter.get("current_move") is Dictionary else ""
	if own != "" and clip_names.has(own):
		return own
	if variant.begins_with("strike_") and clip_names.has(variant):
		return variant
	if variant in ["grapple"]:
		return "grapple"
	# A fighter's signature finisher has its own clip when they have one.
	if variant == "finisher_clip" and clip_names.has("finisher"):
		return "finisher"
	if variant == "taunt":
		return "taunt"
	if fighter.state == fighter.State.KICK or variant in ["kick", "finisher", "front_kick"]:
		if variant in ["spin", "finisher"]:
			return "kick_spin"
		return "kick_front" if variant == "front_kick" else "kick"
	if variant == "spin":
		return "kick_spin"
	if variant in ["uppercut", "overhand", "body_hook"]:
		return "uppercut"
	# Punch chains show a different strike for each hit when the fighter
	# has them (they fall back to the heavy punch otherwise).
	if variant == "cross":
		return "cross"
	if variant in ["hook", "rear_hook", "backfist"]:
		return "hook"
	return "punch_heavy" if variant in HEAVY_PUNCHES else "jab"

func _move_clip(fighter: Node) -> String:
	# Menu portraits use the 2D fighter, which has no physics body.
	var body = fighter.get("body")
	if body == null:
		return "walk"
	var velocity: Vector3 = body.velocity
	velocity.y = 0.0
	var hurt: bool = clip_names.has("injured") and fighter.health <= fighter.max_health * INJURED_HEALTH
	if fighter.running:
		return "injured" if hurt else "run"
	var ahead: float = velocity.dot(fighter.get("forward") if fighter.get("forward") != null else Vector3.RIGHT)
	var across := velocity.length() - absf(ahead)
	if across > absf(ahead):
		# The fighter's right is forward x up; +z when facing +x.
		var forward: Vector3 = fighter.get("forward") if fighter.get("forward") != null else Vector3.RIGHT
		var right := Vector3(-forward.z, 0.0, forward.x)
		return "sidestep_right" if velocity.dot(right) > 0.0 else "sidestep_left"
	if ahead < -0.05:
		return "walk_back"
	return "injured" if hurt else "walk"

## Locomotion plays at the speed that matches the fighter's ground speed;
## walking back plays the walk reversed when there's no dedicated clip.
func _loop_speed(fighter: Node, logical: String, clip: String) -> float:
	var body = fighter.get("body")
	if body == null or not MOVE_SPEED_RANGE.has(logical):
		return 1.0
	# Body velocity is in combat time; the fight runs at COMBAT_TEMPO.
	var tempo: float = fighter.get_script().get_script_constant_map().get("COMBAT_TEMPO", 1.0)
	var pace: float = Vector3(body.velocity.x, 0.0, body.velocity.z).length() * tempo
	var native: float = clip_pace.get(clip, 0.0)
	var limits: Array = MOVE_SPEED_RANGE[logical]
	var speed: float = clampf(pace / native if native > 0.2 else pace / 1.6, limits[0], limits[1])
	var reversed: bool = logical in ["walk_back", "backdash"] and clip_names.get(logical) == clip_names.get("walk")
	return -speed if reversed else speed

## Maps attack_timer onto the clip: wind-up covers the clip up to its
## impact point, and the blow's active frames and recovery cover the rest.
func _scrub_attack(fighter: Node, logical: String, clip: String, delta: float, frozen: bool) -> void:
	var animation := player.get_animation(clip)
	if animation == null:
		return
	# The player is held at speed 0 while scrubbing, so its own cross-fade
	# would never finish. Instead the pose the rig was in is captured and
	# blended toward the clip by hand over the first few frames.
	# A new strike blends from wherever the body was, even when it is the
	# same clip again (a jab repeated in a string snapped back to its start).
	var restarted: bool = fighter.attack_timer < _last_attack_time - 0.0001
	_last_attack_time = fighter.attack_timer
	if clip != current or restarted:
		_capture_pose(ATTACK_BLEND)
		player.play(clip, 0.0)
		current = clip
	player.speed_scale = 0.0
	# Part of the clip to use: [start, impact, end] seconds from "timing",
	# or the whole clip with the impact at the "impact" fraction.
	var cut: Array = config.get("timing", {}).get(logical, [])
	var start := 0.0
	var end := animation.length
	var impact: float = float(config.get("impact", {}).get(logical, 0.45)) * animation.length
	if cut.size() == 3:
		start = cut[0]
		impact = cut[1]
		end = minf(cut[2], animation.length)
	var startup: float = maxf(fighter.attack_startup(), 0.001)
	var total: float = maxf(fighter.attack_duration(), startup + 0.01)
	var t: float = fighter.attack_timer
	_from_strike = true
	# Skip the early part of a long wind-up so what plays runs near natural
	# speed (the blend from guard covers the skipped bit), but keep most of
	# it: a spinning kick needs its whole turn to come round on target.
	start = maxf(start, impact - maxf(startup * WINDUP_RATE, (impact - start) * WINDUP_KEEP))
	player.seek(minf(_strike_time(start, impact, end, startup, total, t), animation.length - 0.001), true)
	_blend_in(delta, frozen)

## Clip time for a strike `t` seconds in: the wind-up [start, impact] fills
## the startup and the follow-through [impact, end] the rest. Each half is a
## Hermite curve sharing one speed at the impact, so the strike accelerates
## through the blow and settles after it with no kink in between.
static func _strike_time(start: float, impact: float, end: float, startup: float, total: float, t: float) -> float:
	var rise := (impact - start) / startup
	var fall := (end - impact) / maxf(total - startup, 0.001)
	var through := minf((rise + fall) * 0.5, minf(rise, fall) * 2.5)
	if t <= startup:
		return _hermite(start, impact, startup, rise * 0.8, through, clampf(t / startup, 0.0, 1.0))
	return _hermite(impact, end, total - startup, through, fall * 0.5, clampf((t - startup) / maxf(total - startup, 0.001), 0.0, 1.0))

## Cubic Hermite from p0 to p1 over `span` seconds with start and end
## speeds m0 and m1 (clip-seconds per second), at fraction u.
static func _hermite(p0: float, p1: float, span: float, m0: float, m1: float, u: float) -> float:
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * p0 + (u3 - 2.0 * u2 + u) * span * m0 + (-2.0 * u3 + 3.0 * u2) * p1 + (u3 - u2) * span * m1

## Remembers the pose drawn last (every bone's turn and the hips' place) to
## blend from over `span` seconds (see _blend_in).
func _capture_pose(span: float = ATTACK_BLEND) -> void:
	_blend_from.clear()
	_blend_time = 0.0
	_blend_span = span
	if skeleton == null:
		return
	for bone in skeleton.get_bone_count():
		_blend_from[bone] = skeleton.get_bone_pose_rotation(bone)
	var hips := _bone("hips")
	if hips >= 0:
		_blend_hips = skeleton.get_bone_pose_position(hips)

## Eases the clip's pose in from the captured one: slow out of the old pose,
## slow into the new, never a cut.
func _blend_in(delta: float, frozen: bool) -> void:
	if not frozen:
		_blend_time += delta
	if _blend_time >= _blend_span or skeleton == null or _blend_from.is_empty():
		return
	var k := smoothstep(0.0, 1.0, _blend_time / _blend_span)
	for bone in _blend_from:
		skeleton.set_bone_pose_rotation(bone, (_blend_from[bone] as Quaternion).slerp(skeleton.get_bone_pose_rotation(bone), k))
	var hips := _bone("hips")
	if hips >= 0:
		skeleton.set_bone_pose_position(hips, _blend_hips.lerp(skeleton.get_bone_pose_position(hips), k))
