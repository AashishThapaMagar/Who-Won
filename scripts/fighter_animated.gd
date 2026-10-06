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
const LOOPING := ["idle", "walk", "walk_back", "sidestep", "sidestep_left", "sidestep_right", "run", "dash", "backdash", "block", "injured"]
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
## Clips allowed to move the hips across the floor. Everything else plays in
## place: the game moves the fighter, so baked-in travel (a walk, a flip kick,
## a diving catch) would drift away from the body and snap back.
const TRAVELLING := ["ko"]
## Attack-like clips driven by the fighter's attack timer.
const SCRUBBED := ["jab", "cross", "hook", "punch_heavy", "uppercut", "kick", "kick_spin", "kick_front", "grapple", "taunt", "finisher"]
## Meshy's biped skeleton names -> Mixamo bone keys (see _bone_key); every
## other bone already shares the Mixamo name.
const MESHY_BONES := {"spine02": "spine", "spine01": "spine1", "spine": "spine2", "neck": "neck",
	"head_end": "headtop_end", "lefthand_end": "", "righthand_end": "", "headfront": "",
	"lefttoe_end": "lefttoe_end", "righttoe_end": "righttoe_end"}
## Tripo's auto-rig (spec "tripo") names -> Mixamo bone keys. Twist bones
## and the pelvis stay unmapped; their rest pose holds.
const TRIPO_BONES := {"hip": "hips", "waist": "spine", "spine01": "spine1", "spine02": "spine2",
	"necktwist01": "neck", "head": "head",
	"l_clavicle": "leftshoulder", "l_upperarm": "leftarm", "l_forearm": "leftforearm", "l_hand": "lefthand",
	"r_clavicle": "rightshoulder", "r_upperarm": "rightarm", "r_forearm": "rightforearm", "r_hand": "righthand",
	"l_thigh": "leftupleg", "l_calf": "leftleg", "l_foot": "leftfoot", "l_toebase": "lefttoebase",
	"r_thigh": "rightupleg", "r_calf": "rightleg", "r_foot": "rightfoot", "r_toebase": "righttoebase"}
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
const MAX_REACH_STEP := 0.3
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
const ATTACK_BLEND := 0.09
## Into the thrown clip from a guard, and from lying into the get-up.
const THROW_BLEND := 0.15
## Procedural layers on top of the clips: a knee tuck for rigs with no
## jump clip and a lean back for guarded hits. Bones are found by name and
## their bend direction is calibrated once, so any humanoid rig works.
var _tuck := 0.0
var _lean := 0.0
## Extra lean back of the trunk set by the throw each frame (Ish's spear).
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

## Swaps the shared body's meshes for a generated one (body.glb from
## tools/build_fighter_body.py). It is skinned to the same Mixamo rig, so its
## binds are re-expressed against this skeleton's rest pose and every clip
## plays on it unchanged.
func _graft_body(path: String) -> void:
	var packed: PackedScene = load(path) if ResourceLoader.exists(path) else null
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
		# Skinning ignores the node's own transform; this only places its
		# bounds, which _fit measures.
		mesh.transform = placed
		mesh.skin = skin
		mesh.skeleton = NodePath("..")
	scene.free()

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

## Mixamo-style one-move-per-file downloads, retargeted onto this skeleton.
## Retargeted clip sets, built once per fighter and reused: in memory for
## the rest of the session, and on disk (user://clip_cache) for the next
## launch. Building one means opening and converting every clip file (about
## fifty for a full move pack, ~10 s); a cached set loads in a fraction of
## that. Bump CLIP_CACHE_VERSION whenever the conversion below changes.
const CLIP_CACHE_VERSION := 1
const CLIP_CACHE_DIR := "user://clip_cache/"
static var _clip_cache := {}

func _add_clip_files() -> void:
	var files: Dictionary = config.get("files", {})
	if files.is_empty():
		return
	var skeleton := character.find_children("*", "Skeleton3D", true, false)
	if skeleton.is_empty():
		return
	var to_skeleton := player.get_node(player.root_node).get_path_to(skeleton[0])
	var meshy: Dictionary = config.get("meshy", {})
	var key := _clip_cache_key(files, meshy, skeleton[0], to_skeleton)
	var library: AnimationLibrary = _clip_cache.get(key)
	if library == null:
		var saved := CLIP_CACHE_DIR + key + ".res"
		if ResourceLoader.exists(saved):
			library = ResourceLoader.load(saved, "AnimationLibrary", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
	if library == null or not library.has_meta("pace"):
		var timing_before: Dictionary = config.get("timing", {}).duplicate(true)
		library = _build_clip_files(files, meshy, skeleton[0], to_skeleton)
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

## Names one fighter's clip set: the conversion version, every source file
## with its modification time, and the skeleton the clips are fitted to.
func _clip_cache_key(files: Dictionary, meshy: Dictionary, skeleton: Skeleton3D, to_skeleton: NodePath) -> String:
	var parts := [CLIP_CACHE_VERSION, str(to_skeleton), skeleton.get_bone_count(), snappedf(_hips_height(skeleton), 0.0001), config.get("scene", ""), config.get("body", "")]
	var keys := files.keys()
	keys.sort()
	for name in keys:
		parts.append([name, files[name], FileAccess.get_modified_time(files[name])])
	if not meshy.is_empty():
		parts.append([meshy.get("file", ""), FileAccess.get_modified_time(str(meshy.get("file", ""))), meshy.get("clips", {})])
	for extra in config.get("tripo", []):
		parts.append([extra.file, FileAccess.get_modified_time(str(extra.file)), extra.clips])
	var timing_keys: Array = config.get("timing", {}).keys()
	timing_keys.sort()
	parts.append(timing_keys)
	return str(parts).sha256_text().substr(0, 24)

func _build_clip_files(files: Dictionary, meshy: Dictionary, target: Skeleton3D, to_skeleton: NodePath) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var skeleton := [target]
	for key in files:
		var source: PackedScene = load(files[key])
		if source == null:
			continue
		var scene := source.instantiate()
		var source_players := scene.find_children("*", "AnimationPlayer", true, false)
		if not source_players.is_empty():
			var from: AnimationPlayer = source_players[0]
			# Mixamo files also carry a leftover bind-pose "Take 001"; the
			# real clip is "mixamo_com", otherwise take the longest.
			var names := Array(from.get_animation_list())
			names.sort_custom(func(x, y): return x == "mixamo_com" or (y != "mixamo_com" and from.get_animation(x).length > from.get_animation(y).length))
			for name in names:
				var animation: Animation = from.get_animation(name).duplicate()
				# Point every bone track at this character's skeleton.
				for track in animation.get_track_count():
					var path := animation.track_get_path(track)
					if path.get_subname_count() > 0:
						animation.track_set_path(track, NodePath(str(to_skeleton) + ":" + path.get_concatenated_subnames()))
				# Same bone names but maybe another unit scale (a body exported
				# in metres, clips from a centimetre rig): positions follow
				# the ratio of hip heights, or the fighter sinks to the floor.
				var source_skeletons := scene.find_children("*", "Skeleton3D", true, false)
				if not source_skeletons.is_empty():
					_scale_positions(animation, _hips_height(skeleton[0]) / maxf(_hips_height(source_skeletons[0]), 0.0001))
				if not key in TRAVELLING:
					clip_pace["files/" + key] = _pin_hips(animation)
				if key.ends_with("jump"):
					_ground_jump(animation)
				library.add_animation(key, animation)
				break
		scene.free()
	if not meshy.is_empty() and ResourceLoader.exists(meshy.file):
		_add_meshy_clips(library, meshy.file, meshy.clips, skeleton[0], to_skeleton)
	# Tripo animations (one clip per file), retargeted the same way.
	for extra in config.get("tripo", []):
		if ResourceLoader.exists(extra.file):
			_add_meshy_clips(library, extra.file, extra.clips, skeleton[0], to_skeleton)
	return library

## Meshy's own animations (its "Merged Animations" download) retargeted onto
## this skeleton. The two rigs share a hierarchy but not bone names, rest
## orientations or scale, so each frame is rebuilt: a bone's world rotation
## keeps the same offset from its rest that the Meshy bone has from its own
## rest, and the hips' travel is scaled by the ratio of hip heights.
func _add_meshy_clips(library: AnimationLibrary, path: String, wanted: Dictionary, target: Skeleton3D, to_skeleton: NodePath) -> void:
	var scene: Node = (load(path) as PackedScene).instantiate()
	var sources := scene.find_children("*", "Skeleton3D", true, false)
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	if sources.is_empty() or players.is_empty():
		scene.free()
		return
	var source: Skeleton3D = sources[0]
	var from: AnimationPlayer = players[0]
	# Source bone -> target bone.
	var pairs := {}
	var target_keys := {}
	for bone in target.get_bone_count():
		target_keys[_bone_key(target.get_bone_name(bone))] = bone
	# Meshy's own names only when the rig uses them (its biped FBX); its
	# rigged .glb already uses Mixamo's.
	var native := false
	var tripo := false
	for bone in source.get_bone_count():
		tripo = tripo or _bone_key(source.get_bone_name(bone)) == "l_thigh"
	for bone in source.get_bone_count():
		native = native or (_bone_key(source.get_bone_name(bone)) == "spine02" and not tripo)
	for bone in source.get_bone_count():
		var key := _bone_key(source.get_bone_name(bone))
		if tripo:
			key = TRIPO_BONES.get(key, "")
		elif native:
			key = MESHY_BONES.get(key, key)
		elif key in ["headfront", "lefthandmiddle4", "righthandmiddle4"]:
			key = ""
		if key != "" and target_keys.has(key):
			pairs[bone] = target_keys[key]
	var source_hips := source.find_bone(source.get_bone_name(0))
	for bone in pairs:
		if _bone_key(source.get_bone_name(bone)) == "hips":
			source_hips = bone
	var target_hips: int = target_keys.get("hips", 0)
	# The rigs rest in different poses (Meshy's A-pose, Mixamo's T-pose), so
	# bones are matched by where they point, not by their rest rotation: each
	# mapped bone gets a frame built from its direction in the rest pose, and
	# the target bone is turned so its frame follows the source bone's.
	var s_node := _node_rotation(source, scene)
	var t_node := _node_rotation(target, character)
	var inverse_pairs := {}
	for bone in pairs:
		inverse_pairs[pairs[bone]] = bone
	var s_frame := {}  # source bone -> frame in bone-local space
	var t_frame := {}
	for bone in pairs:
		var target_bone: int = pairs[bone]
		var s_dir := _rest_direction(source, s_node, bone, pairs.keys())
		var t_dir := _rest_direction(target, t_node, target_bone, inverse_pairs.keys())
		s_frame[bone] = (s_node * source.get_bone_global_rest(bone).basis.get_rotation_quaternion()).inverse() * _frame(s_dir)
		t_frame[target_bone] = (t_node * target.get_bone_global_rest(target_bone).basis.get_rotation_quaternion()).inverse() * _frame(t_dir)
	var s_height := source.get_bone_global_rest(source_hips).origin.length()
	var t_height := target.get_bone_global_rest(target_hips).origin.length()
	var scale := t_height / maxf(s_height, 0.0001)
	var names := from.get_animation_list()
	for logical in wanted:
		var clip_name := ""
		for candidate in names:
			if String(candidate).contains(String(wanted[logical])):
				clip_name = candidate
		if clip_name == "":
			continue
		var clip := from.get_animation(clip_name)
		var rotation_tracks := {}
		var position_track := -1
		for track in clip.get_track_count():
			var bone := source.find_bone(String(clip.track_get_path(track).get_concatenated_subnames()))
			if bone < 0:
				continue
			if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				rotation_tracks[bone] = track
			elif clip.track_get_type(track) == Animation.TYPE_POSITION_3D and bone == source_hips:
				position_track = track
		var out := Animation.new()
		out.length = clip.length
		var out_tracks := {}
		for bone in pairs.values():
			var track := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(track, NodePath(str(to_skeleton) + ":" + target.get_bone_name(bone)))
			out_tracks[bone] = track
		var hips_track := out.add_track(Animation.TYPE_POSITION_3D)
		out.track_set_path(hips_track, NodePath(str(to_skeleton) + ":" + target.get_bone_name(target_hips)))
		# Whole-move strike clips (no timing given) get their impact measured
		# at the frame the hands or feet reach furthest from the hips.
		var measure: bool = _is_strike(logical) and not config.get("timing", {}).has(logical)
		var limbs: Array[int] = []
		for key in ["lefthand", "righthand", "leftfoot", "rightfoot"]:
			if target_keys.has(key):
				limbs.append(target_keys[key])
		var peak_extent := -1.0
		var peak_time := -1.0
		var t_node_scale := 1.0
		var step := 1.0 / 30.0
		var time := 0.0
		while time <= clip.length + 0.0001:
			var at := minf(time, clip.length)
			# Source world rotations, parents before children.
			var s_world := {}
			for bone in source.get_bone_count():
				var local := source.get_bone_rest(bone).basis.get_rotation_quaternion()
				if rotation_tracks.has(bone):
					local = clip.rotation_track_interpolate(rotation_tracks[bone], at)
				var parent := source.get_bone_parent(bone)
				s_world[bone] = (s_world[parent] if parent >= 0 else s_node) * local
			var t_world := {}
			for bone in target.get_bone_count():
				var parent := target.get_bone_parent(bone)
				var parent_world: Quaternion = t_world[parent] if parent >= 0 else t_node
				var source_bone = pairs.find_key(bone)
				if source_bone != null:
					t_world[bone] = (s_world[source_bone] as Quaternion) * (s_frame[source_bone] as Quaternion) * (t_frame[bone] as Quaternion).inverse()
					out.rotation_track_insert_key(out_tracks[bone], at, (parent_world.inverse() * t_world[bone]).normalized())
				else:
					t_world[bone] = parent_world * target.get_bone_rest(bone).basis.get_rotation_quaternion()
			if measure:
				# Forward kinematics on the rebuilt rotations: how far the
				# hands and feet reach from the hips at this moment.
				var t_pos := {}
				for bone in target.get_bone_count():
					var parent := target.get_bone_parent(bone)
					if parent < 0:
						t_pos[bone] = Vector3.ZERO
					else:
						var parent_rot: Quaternion = t_world[parent]
						t_pos[bone] = (t_pos[parent] as Vector3) + parent_rot * (target.get_bone_rest(bone).origin * t_node_scale)
				var hips_at: Vector3 = t_pos[target_hips]
				for limb in limbs:
					var d: Vector3 = (t_pos[limb] as Vector3) - hips_at
					var extent := Vector2(d.x, d.z).length()
					if extent > peak_extent:
						peak_extent = extent
						peak_time = at
			var hips := target.get_bone_rest(target_hips).origin
			if position_track >= 0:
				var moved: Vector3 = clip.position_track_interpolate(position_track, at) - source.get_bone_rest(source_hips).origin
				hips += t_node.inverse() * (s_node * moved) * scale
			out.position_track_insert_key(hips_track, at, hips)
			time += step
		var key: String = "meshy_" + logical
		if measure and peak_time >= 0.0:
			# The blow lands at full extension, not at a guessed fraction.
			var timing: Dictionary = config.get("timing", {})
			timing[logical] = [maxf(0.0, peak_time - 0.4), peak_time, minf(clip.length, peak_time + 0.55)]
			config["timing"] = timing
		clip_pace["files/" + key] = _pin_hips(out)
		if logical == "jump":
			# The game's physics lifts the body; the clip keeps only the
			# tuck, or the fighter would rise twice as high.
			for track in out.get_track_count():
				if out.track_get_type(track) == Animation.TYPE_POSITION_3D:
					var ground: Vector3 = out.track_get_key_value(track, 0)
					for k in out.track_get_key_count(track):
						var v: Vector3 = out.track_get_key_value(track, k)
						out.track_set_key_value(track, k, Vector3(v.x, minf(v.y, ground.y), v.z))
		library.add_animation(key, out)
	scene.free()

## Where a bone points in the rest pose (world space): toward its main
## mapped child (the spine, neck or head over the shoulders and legs), or on
## from its parent for end bones.
static func _rest_direction(skeleton: Skeleton3D, node: Quaternion, bone: int, mapped: Array) -> Vector3:
	var here := skeleton.get_bone_global_rest(bone).origin
	var best := -1
	for child in skeleton.get_bone_children(bone):
		if not mapped.has(child):
			continue
		var key := _bone_key(skeleton.get_bone_name(child))
		if best < 0 or key.contains("spine") or key.contains("neck") or key.contains("head"):
			best = child
	var direction := Vector3.ZERO
	if best >= 0:
		direction = skeleton.get_bone_global_rest(best).origin - here
	elif skeleton.get_bone_parent(bone) >= 0:
		direction = here - skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone)).origin
	if direction.length() < 0.00001:
		direction = Vector3.UP
	return (node * direction).normalized()

## A rotation whose Y axis runs along direction, twist fixed by the
## character's forward (+Z), or up when the bone points forward.
static func _frame(direction: Vector3) -> Quaternion:
	var reference := Vector3.BACK
	if absf(direction.dot(reference)) > 0.9:
		reference = Vector3.UP
	var x := direction.cross(reference).normalized()
	var z := x.cross(direction).normalized()
	return Basis(x, direction, z).get_rotation_quaternion()

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

static func _scale_positions(animation: Animation, ratio: float) -> void:
	if ratio <= 0.0 or absf(ratio - 1.0) < 0.05:
		return
	for track in animation.get_track_count():
		if animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
			for k in animation.track_get_key_count(track):
				animation.track_set_key_value(track, k, (animation.track_get_key_value(track, k) as Vector3) * ratio)

## Jump clips lift the hips themselves; the game's physics already does,
## so the clip keeps only the crouch and tuck (hips never rise above where
## they start), or the fighter would fly twice as high.
static func _ground_jump(animation: Animation) -> void:
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		if not String(animation.track_get_path(track).get_concatenated_subnames()).to_lower().ends_with("hips"):
			continue
		var ground: Vector3 = animation.track_get_key_value(track, 0)
		for k in animation.track_get_key_count(track):
			var v: Vector3 = animation.track_get_key_value(track, k)
			animation.track_set_key_value(track, k, Vector3(v.x, minf(v.y, ground.y), v.z))

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

## Picks and poses the clip for this frame. Called from the visual's
## _process and sync_pose.
func update(delta: float) -> void:
	if not active or visual.fighter == null:
		return
	var fighter: Node = visual.fighter
	# Only the facing turn: the procedural rig's knockdown/hit spin would
	# double up with the clips' own falls and sink the model into the floor.
	root.transform = Transform3D(Basis(Vector3.UP, visual.model.rotation.y), visual.model.position)
	var frozen: bool = fighter.combat_paused or fighter.hitstop_remaining > 0.0
	var S: Dictionary = fighter.State
	var state: int = fighter.state
	var logical := "idle"
	match state:
		S.PUNCH, S.KICK:
			logical = _attack_clip(fighter)
		S.WALK:
			logical = _move_clip(fighter)
		S.DASH:
			logical = "dash" if fighter._dash_dir == fighter.facing else "backdash"
		S.JUMP, S.JUMP_START:
			logical = "jump"
		S.LAND:
			logical = "land"
		S.BLOCK:
			logical = "block"
		S.BLOCKSTUN:
			logical = "block_hit"
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
	if logical in ["throw", "thrown", "downed"] or (logical == "getup" and _has_own("getup")):
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
		player.play(clip, 0.05 if logical in REACTIONS or logical == "ko" else (0.22 if was_reaction else (0.24 if stepping else 0.12)))
		if restart:
			player.seek(0.0, true)
		# Clips that open with a still beat (the knockout) start where the
		# motion starts.
		var start: float = float(config.get("starts", {}).get(logical, 0.0))
		if start > 0.0:
			player.seek(start, true)
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
				# A rig with its own grab (Sab's slam) plays it from its
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
		"downed":
			if paired:
				_scrub_clip(clip_names.thrown, THROW.CLIP_END, delta, frozen)
			else:
				_fall(1.0, delta, frozen)
		"getup":
			var rise := clampf((fighter.knockdown_time - THROW.LIE_TIME) / THROW.GETUP_TIME, 0.0, 1.0)
			_scrub_clip(clip_names.getup, lerpf(THROW.GETUP_START, THROW.GETUP_END, rise), delta, frozen)

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

## Rigs without a victim clip go down on their knockout clip.
func _fall(progress: float, delta: float, frozen: bool) -> void:
	var clip: String = clip_names.get("ko", "")
	var animation := player.get_animation(clip) if clip != "" else null
	if animation == null:
		return
	_scrub_clip(clip, minf(clampf(progress, 0.0, 1.0) * 1.1, animation.length - 0.001), delta, frozen)

## Holds `clip` at `time`, blending in from the previous pose by hand when
## the clip changes (the player sits at speed 0, so its cross-fade can't).
func _scrub_clip(clip: String, time: float, delta: float, frozen: bool) -> void:
	var animation := player.get_animation(clip) if clip != "" else null
	if animation == null:
		return
	if clip != current:
		_capture_pose()
		_blend_time = 0.0
		player.play(clip, 0.0)
		current = clip
	player.speed_scale = 0.0
	player.seek(clampf(time, 0.0, animation.length - 0.001), true)
	if not frozen:
		_blend_time += delta
	if _blend_time < THROW_BLEND and skeleton != null and not _blend_from.is_empty():
		var k := smoothstep(0.0, 1.0, _blend_time / THROW_BLEND)
		for bone in _blend_from:
			skeleton.set_bone_pose_rotation(bone, (_blend_from[bone] as Quaternion).slerp(skeleton.get_bone_pose_rotation(bone), k))

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
				goal = clampf(short, 0.0, MAX_REACH_STEP * (1.5 if kicking else 1.0)) * envelope
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
	_aim_at_rival(fighter, delta, frozen)

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
		want = 0.5
	if not frozen:
		_aim_weight = move_toward(_aim_weight, want, delta * (6.0 if want > _aim_weight else 10.0))
	if _aim_weight < 0.01:
		_aim = 0.0
		return
	var head := _bone("head")
	if head < 0:
		return
	# Directions only: some rigs carry a 0.01 (centimetre) scale.
	var basis := skeleton.global_transform.basis.orthonormalized()
	if _face_axis == Vector3.ZERO:
		# A fighting stance looks straight ahead along the model's facing.
		if fighter.state != S.IDLE or current != clip_names.get("idle", ""):
			return
		var ahead: Vector3 = basis.inverse() * root.global_transform.basis.x
		_face_axis = (skeleton.get_bone_global_pose(head).basis.orthonormalized().inverse() * ahead).normalized()
	var head_pose := skeleton.get_bone_global_pose(head)
	var face: Vector3 = basis * (head_pose.basis.orthonormalized() * _face_axis)
	face.y = 0.0
	var eyes: Vector3 = skeleton.global_transform * head_pose.origin
	var to_rival: Vector3 = rival.body.global_position + Vector3.UP * 1.5 - eyes
	to_rival.y = 0.0
	if face.length_squared() < 0.0001 or to_rival.length_squared() < 0.01:
		return
	var need := clampf(face.normalized().signed_angle_to(to_rival.normalized(), Vector3.UP), -AIM_LIMIT, AIM_LIMIT)
	if not frozen:
		_aim = lerpf(_aim, need, 1.0 - exp(-45.0 * delta))
	var up_local: Vector3 = basis.inverse() * Vector3.UP
	for link in AIM_CHAIN:
		var bone := _bone(link[0])
		if bone < 0:
			continue
		var axis: Vector3 = (skeleton.get_bone_global_pose(bone).basis.orthonormalized().inverse() * up_local).normalized()
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(axis, _aim * _aim_weight * link[1]))

## Bends the calibrated bones by the current tuck, lean and recoil amounts.
func _apply_layers() -> void:
	if skeleton == null:
		return
	# Knees only ever buckle; the spring's overshoot must not lock them back.
	var buckle := maxf(_recoil.z, 0.0) if fighter_grounded() else 0.0
	var bend := _tuck + buckle
	if bend > 0.001:
		for leg in _legs:
			var hip := skeleton.get_bone_pose_rotation(leg[0])
			skeleton.set_bone_pose_rotation(leg[0], hip * Quaternion(leg[4], leg[2] * 0.5 * bend))
			var knee := skeleton.get_bone_pose_rotation(leg[1])
			skeleton.set_bone_pose_rotation(leg[1], knee * Quaternion(leg[5], leg[3] * 1.05 * bend))
	var lean := _lean + _recoil.x + _posture
	if absf(lean) > 0.001:
		for i in _spine.size():
			var part: Array = _spine[i]
			var share: float = _recoil_spread[i] if _spine.size() == 3 else 1.0 / _spine.size()
			# The guard lean stays even; only the recoil follows the spread.
			var angle: float = (_lean + _posture) / _spine.size() + _recoil.x * share
			var pose := skeleton.get_bone_pose_rotation(part[0])
			skeleton.set_bone_pose_rotation(part[0], pose * Quaternion(part[2], part[1] * angle))
	if absf(_snap) > 0.001 and not _head_roll.is_empty():
		var head := _bone("head")
		skeleton.set_bone_pose_rotation(head, skeleton.get_bone_pose_rotation(head) * Quaternion(_head_roll[0], _head_roll[1] * _snap))
	if root == null or (absf(_recoil.y) < 0.001 and buckle < 0.001 and absf(_push) < 0.0005):
		return
	var parent := root.get_parent() as Node3D
	if absf(_push) >= 0.0005:
		var ahead := root.global_transform.basis.x
		ahead.y = 0.0
		root.position += parent.global_transform.basis.inverse() * (ahead.normalized() * _push)
	# The blow turns the whole body a touch, and a knee buckle lowers the
	# hips by what the bent legs lose in height, so the feet stay planted.
	root.rotate_object_local(Vector3.UP, _recoil.y)
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

## Attack clips, played scrubbed against the move's timing. "strike_*"
## are a fighter's own extra moves (a move whose pose names one plays it).
func _is_strike(logical: String) -> bool:
	return logical in SCRUBBED or logical.begins_with("strike_")

func _attack_clip(fighter: Node) -> String:
	var variant: String = fighter.attack_variant
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
	# Mixamo FBX clips carry centimetres: no walk is 20 m/s.
	if native > 20.0:
		native *= 0.01
	var limits: Array = MOVE_SPEED_RANGE[logical]
	var speed: float = clampf(pace / native if native > 0.2 else pace / 1.6, limits[0], limits[1])
	var reversed: bool = logical in ["walk_back", "backdash"] and clip_names.get(logical) == clip_names.get("walk")
	# A guarded forward walk made by playing the boxing walk-back in reverse.
	if logical in config.get("reversed", []):
		reversed = true
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
	if clip != current:
		_capture_pose()
		_blend_time = 0.0
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
	var startup: float = fighter.attack_startup()
	var total: float = maxf(fighter.attack_duration(), startup + 0.01)
	var t: float = fighter.attack_timer
	var position := start + (impact - start) * clampf(t / maxf(startup, 0.001), 0.0, 1.0)
	if t > startup:
		position = impact + (end - impact) * clampf((t - startup) / (total - startup), 0.0, 1.0)
	player.seek(minf(position, animation.length - 0.001), true)
	if not frozen:
		_blend_time += delta
	if _blend_time < ATTACK_BLEND and skeleton != null and not _blend_from.is_empty():
		var k := smoothstep(0.0, 1.0, _blend_time / ATTACK_BLEND)
		for bone in _blend_from:
			skeleton.set_bone_pose_rotation(bone, (_blend_from[bone] as Quaternion).slerp(skeleton.get_bone_pose_rotation(bone), k))

func _capture_pose() -> void:
	_blend_from.clear()
	if skeleton == null:
		return
	for bone in skeleton.get_bone_count():
		_blend_from[bone] = skeleton.get_bone_pose_rotation(bone)
