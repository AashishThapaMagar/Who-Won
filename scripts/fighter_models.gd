extends RefCounted
## Every fighter's model and motion. The body is the fighter's Meshy model
## (assets/fighters/<id>/meshy_body.glb) worn on the shared Mixamo skeleton
## (assets/fighters/anug/idle.fbx); every clip comes from one mocap pack,
## Kubold's Fighting Animset Pro (assets/fighters/animset/, kept local: the
## licence allows use in the game but not sharing the files), retargeted
## onto that skeleton by fighter_animated.gd. One performer, one skeleton:
## every move of every fighter blends into every other.
##
## A fighter's look is three tables:
##   STANCES   their guard, footwork and knockout (no two alike)
##   SHARED    reactions, jumps, crouch and guard everyone uses
##   action_moves.gd LOOK   their strikes, one clip per move, never shared
## The clip a move plays is its "clip" key; fighter_animated.gd plays a move
## by that name, so every clip named in LOOK is loaded here.
##
## Logical clips the animation layer knows (fighter_animated.gd): idle,
## walk, walk_back, sidestep_left, sidestep_right, run, dash, backdash, jump,
## land, crouch, block, block_hit, hit, hit_heavy, hit_head, hit_head_alt,
## hit_head_heavy, hit_body, hit_body_alt, hit_side, hit_liver, ko, fall,
## getup, taunt, victory; jab, cross, hook, kick (story poses); and any
## pack clip name ("KB_...") a move or super plays.
const ACTION_MOVES := preload("res://scripts/action_moves.gd")
const SUPERS := preload("res://scripts/super_moves.gd")
const ANIMSET := "res://assets/fighters/animset/"
## The skeleton every fighter's clips are fitted to and every body is worn on.
const SKELETON := "res://assets/fighters/anug/idle.fbx"
## Every fighter stands the same height (metres) and none is stretched
## wider: blows meet at the same heights and reach matches the hitboxes.
const FIGHTER_HEIGHT := 1.8

## Each fighter's own reactions to a blow: how the head snaps (hit_head,
## and hit_head_alt for the next jab), the heavy whip of a hook or a head
## kick (hit_head_heavy), the fold of a body shot (hit_body, hit_body_alt),
## a blow to the side (hit_side) and the crumple of a hard body blow
## (hit_liver). Light fighters snap quick; the heavy one barely rocks; no
## two fighters take a punch the same way.
const HITS := {
	"ish": {"hit_head": "KB_Hit_p_HighFront_Weak", "hit_head_alt": "KB_Hit_p_HighLeft_Weak",
		"hit_head_heavy": "KB_Hit_m_HighFront_Med", "hit_body": "KB_Hit_p_MidFront_Weak",
		"hit_body_alt": "KB_Hit_p_MidLeft_Weak", "hit_side": "KB_Hit_p_MidRight_Weak", "hit_liver": "KB_Hit_m_MidFront_Stagger"},
	"sab": {"hit_head": "KB_Hit_m_HighFront_Weak", "hit_head_alt": "KB_Hit_m_HighRight_Weak",
		"hit_head_heavy": "KB_Hit_m_HighLeft_Weak", "hit_body": "KB_Hit_m_MidFront_Weak",
		"hit_body_alt": "KB_Hit_m_MidRight_Weak", "hit_side": "KB_Hit_m_LowRight_Weak", "hit_liver": "KB_Hit_m_MidFront_Med"},
	"bib": {"hit_head": "KB_Hit_p_HighRight_Weak", "hit_head_alt": "KB_Hit_p_HighUpper_Weak",
		"hit_head_heavy": "KB_Hit_m_HighLeft_Med", "hit_body": "KB_Hit_p_MidRight_Weak",
		"hit_body_alt": "KB_Hit_p_LowLeft_Weak", "hit_side": "KB_Hit_p_LowRight_Weak", "hit_liver": "KB_Hit_m_MidLeft_Stagger"},
	"abhi": {"hit_head": "KB_Hit_m_HighRight_Med", "hit_head_alt": "KB_Hit_m_HighLeft_Weak",
		"hit_head_heavy": "KB_Hit_m_HighFront_Stagger", "hit_body": "KB_Hit_m_MidFront_Med",
		"hit_body_alt": "KB_Hit_m_MidLeft_Med", "hit_side": "KB_Hit_m_MidRight_Med", "hit_liver": "KB_Hit_m_MidRight_Stagger"},
	"anug": {"hit_head": "KB_Hit_m_HighLeft_Weak", "hit_head_alt": "KB_Hit_m_HighFront_Weak",
		"hit_head_heavy": "KB_Hit_m_HighRight_Med", "hit_body": "KB_Hit_m_MidLeft_Weak",
		"hit_body_alt": "KB_Hit_m_MidFront_Weak", "hit_side": "KB_Hit_m_LowLeft_Med", "hit_liver": "KB_Hit_m_MidTop_Med"},
	"sup": {"hit_head": "KB_Hit_p_HighUpper_Weak", "hit_head_alt": "KB_Hit_p_HighRight_Weak",
		"hit_head_heavy": "KB_Hit_m_HighLeft_Med", "hit_body": "KB_Hit_p_MidLeft_Weak",
		"hit_body_alt": "KB_Hit_p_MidRight_Weak", "hit_side": "KB_Hit_m_LowRight_Med", "hit_liver": "KB_Hit_m_MidLeft_Stagger"},
	# The master barely gives ground: short, composed flinches.
	"anant": {"hit_head": "KB_Hit_m_HighRight_Weak", "hit_head_alt": "KB_Hit_p_HighLeft_Weak",
		"hit_head_heavy": "KB_Hit_m_HighRight_Med", "hit_body": "KB_Hit_m_MidRight_Weak",
		"hit_body_alt": "KB_Hit_m_MidLeft_Weak", "hit_side": "KB_Hit_m_LowLeft_Weak", "hit_liver": "KB_Hit_m_MidRight_Med"},
}
## Each fighter's own stance, footwork, reactions ("hits") and fall, and
## the tint used when their Meshy body is missing.
const STANCES := {
	# Agasthya: the boxer, bouncing on his toes.
	"ish": {"tint": [Color("a2322c"), Color("2a2227")],
		"idle": "KB_Idle_2", "walk": "KB_WalkFwd2", "walk_back": "KB_WalkBwd",
		"run": "KB_SkipFwd_1", "dash": "KB_SkipFwd_1", "backdash": "KB_SkipBwd_1", "ko": "KB_HighKO_R",
		"victory": "KB_p_OneTwoThree"},
	# Mahabali: planted and heavy.
	"sab": {"tint": [Color("27375a"), Color("c48f49")],
		"idle": "KB_Idle_3", "walk": "KB_WalkFwd1", "walk_back": "KB_WalkBwd",
		"run": "KB_WalkFwd2", "dash": "KB_WalkFwd2", "backdash": "KB_WalkBwd", "ko": "KB_MidKO_Powerful",
		"victory": "KB_GroundAttack"},
	# Vajraveer: light, always moving, bouncing in and out, slipping aside.
	"bib": {"tint": [Color("223f8a"), Color("9fe0c8")],
		"idle": "KB_Idle_4", "walk": "KB_SkipFwd_2", "walk_back": "KB_SkipBwd_2",
		"run": "KB_SkipFwd_2", "dash": "KB_SkipFwd_2", "backdash": "KB_Dodge_L", "ko": "KB_HighKO_L",
		"victory": "KB_m_Duck_R"},
	# Kri: the showman, strutting in on a skip.
	"abhi": {"tint": [Color("5c2f78"), Color("dbb258")],
		"idle": "KB_Idle_5", "walk": "KB_SkipFwd_1", "walk_back": "KB_SkipBwd_1",
		"run": "KB_SkipFwd_1", "dash": "KB_SkipFwd_1", "backdash": "KB_SkipBwd_2", "ko": "KB_UpperKO_2",
		"victory": "KB_Projectile_Up"},
	# Anug: the keeper, hands ready, shuffling low across his line.
	"anug": {"tint": [Color("2c5a3e"), Color("d9b45c")],
		"idle": "KB_Idle_1", "walk": "KB_crouch_WalkFwd", "walk_back": "KB_crouch_WalkBwd",
		"run": "KB_SkipFwd_2", "dash": "KB_SkipFwd_2", "backdash": "KB_SkipBwd_1", "ko": "KB_TopKO",
		"block_hit": "KB_MidBlock_R_Single", "victory": "KB_MidBlock_L_Single"},
	# Sarvochcha: always weaving, circling.
	"sup": {"tint": [Color("c29a3c"), Color("2f8a86")],
		"idle": "KB_m_Duck", "walk": "KB_WalkFwd1", "walk_back": "KB_WalkBwd",
		"sidestep_left": "KB_WalkLeft45", "sidestep_right": "KB_WalkRight45",
		"run": "KB_SkipFwd_2", "dash": "KB_SkipFwd_2", "backdash": "KB_Dodge_R", "ko": "KB_UpperKO_Flip",
		"victory": "KB_TurnR_180"},
	# Ananta: the master, still and complete.
	"anant": {"tint": [Color("5a2f6a"), Color("d3ac62")],
		"idle": "KB_Idle_6", "walk": "KB_WalkFwd1", "walk_back": "KB_WalkBwd",
		"run": "KB_SkipFwd_1", "dash": "KB_SkipFwd_1", "backdash": "KB_SkipBwd_2", "ko": "KB_KO_Head"},
}
## What every fighter shares: reactions, guard, crouch, jumps, falls.
const SHARED := {
	"sidestep_left": "KB_Sidestep_L", "sidestep_right": "KB_Sidestep_R",
	"jump": "KB_Jump_Arcade_RootJump", "land": "KB_Land",
	"crouch": "KB_crouch_Idle", "block": "KB_Block", "block_hit": "KB_Block_Single",
	# Guarding low: arms down over the body, and the jolt of a blocked low.
	"crouch_block": "KB_crouch_Block", "crouch_block_hit": "KB_crouch_Block_Single",
	# Reactions picked by where and how hard each blow lands.
	"hit": "KB_Hit_m_HighFront_Weak", "hit_heavy": "KB_Hit_m_HighFront_Stagger",
	"hit_head": "KB_Hit_m_HighFront_Weak", "hit_head_alt": "KB_Hit_m_HighLeft_Weak",
	"hit_head_heavy": "KB_Hit_m_HighFront_Med", "hit_body": "KB_Hit_m_MidFront_Weak",
	"hit_body_alt": "KB_Hit_m_MidLeft_Weak", "hit_side": "KB_Hit_m_MidRight_Med",
	"hit_liver": "KB_Hit_m_MidFront_Stagger",
	# Swept or knocked down onto the back, and up again.
	"fall": "KB_HighKO_Air", "getup": "KB_GetUpBack",
	"taunt": "KB_Idle_5", "victory": "KB_Stretch",  # (each fighter's own in STANCES)
}
## Air strikes everyone throws (action_moves.gd jump_punch / jump_kick).
const AIR := ["KB_JumpPunch", "KB_Jump_Loop2Kick"]
## [start, impact, end] seconds for clips whose blow can't be measured from
## the furthest reach of a fist or foot (fighter_animated.gd measures the rest).
const TIMING := {
	"KB_Idle_5": [0.0, 1.0, 2.2],
	"KB_m_Duck_L": [0.0, 0.35, 0.8],
	"KB_crouch_p_Uppercut_L": [0.1, 0.45, 1.0],
	# Round low kicks sweep across the front: the shin lands at the widest
	# reach (tools/measure_strike_clips.gd), not furthest straight ahead.
	"KB_p_LowKick_R_1": [0.0, 0.23, 0.75],
	"KB_p_LowKick_L_1": [0.0, 0.2, 0.7],
	"KB_p_LowKick_R_2": [0.0, 0.27, 0.8],
}

## Which pack file holds a clip (the eleven files group the moves by kind).
static func pack_file(clip: String) -> String:
	var file := "KB_Punches"
	if clip.contains("KO") or clip.contains("GetUp") or clip.begins_with("KB_LayBack"):
		file = "KB_KOs"
	elif clip.begins_with("LayOn"):
		file = "KB_Lay"
	elif clip.contains("Stretch"):
		file = "KB_Stretch"
	elif clip.begins_with("KB_crouch_Block"):
		file = "KB_Blocks"
	elif clip.begins_with("KB_crouch_"):
		file = "KB_Crouched"
	elif clip.begins_with("KB_Hit"):
		file = "KB_Hits"
	elif clip.begins_with("KB_Jump") or clip.begins_with("KB_Land"):
		file = "KB_Jumping"
	elif clip.contains("Block") or clip.contains("Duck"):
		file = "KB_Blocks"
	elif ["Projectile", "Superpunch", "GroundAttack"].any(func(part): return clip.contains(part)):
		file = "KB_Specials"
	elif ["Idle", "Walk", "Turn", "Sidestep", "Skip", "Dodge"].any(func(part): return clip.contains(part)):
		file = "KB_Movement"
	elif clip.contains("Kick") or clip.contains("Knee"):
		file = "KB_Kicks"
	return ANIMSET + file + ".fbx"

## A rigged model dropped straight into the fighter's folder (any rigged
## glTF with its own animations): assets/fighters/<id>/rig.glb or <id>.glb.
## It is used as-is, its animations matched to the game's clips by name
## (fighter_animated.gd match_clip).
const DROP_NAMES := ["meshy_rig.glb", "rig.glb", "meshy_rig.gltf", "rig.gltf"]

static func dropped_scene(fighter_id: String) -> String:
	var folder := "res://assets/fighters/%s/" % fighter_id
	for name in DROP_NAMES + [fighter_id + ".glb", fighter_id + ".gltf"]:
		if FileAccess.file_exists(folder + name):
			return folder + name
	return ""

static func entry(fighter_id: String) -> Dictionary:
	var dropped := dropped_scene(fighter_id)
	if dropped != "":
		return {
			"scene": dropped, "enabled": true, "body": "", "height": FIGHTER_HEIGHT, "width": 1.0,
			"tint": [], "yaw": PI / 2.0, "pack": {}, "clips": {}, "timing": {},
		}
	if not STANCES.has(fighter_id) or not ResourceLoader.exists(SKELETON) or not ResourceLoader.exists(pack_file("KB_Idle_1")):
		return {}
	var kit := kit(fighter_id)
	# Grouped by file, so each pack file is opened once.
	var pack := {}
	var clips := {}
	var timing := {}
	for logical in kit:
		var clip: String = kit[logical]
		var file := pack_file(clip)
		if not pack.has(file):
			pack[file] = {}
		pack[file][logical] = clip
		clips[logical] = "pack_" + logical
		if TIMING.has(clip):
			timing[logical] = TIMING[clip]
	var body := "res://assets/fighters/%s/meshy_body.glb" % fighter_id
	var grafted := ResourceLoader.exists(body)
	return {
		"scene": SKELETON, "body": body if grafted else "", "enabled": true,
		"height": FIGHTER_HEIGHT, "width": 1.0, "tint": [] if grafted else STANCES[fighter_id].tint,
		"yaw": PI / 2.0, "pack": pack, "clips": clips, "timing": timing,
	}

## logical clip -> pack clip for one fighter: the shared set, their own
## stance over it, every clip their moves name, and their super's.
static func kit(fighter_id: String) -> Dictionary:
	var kit: Dictionary = SHARED.duplicate()
	var stance: Dictionary = STANCES[fighter_id]
	for logical in stance:
		if logical not in ["tint", "hits"]:
			kit[logical] = stance[logical]
	kit.merge(HITS.get(fighter_id, {}), true)
	var moves: Dictionary = ACTION_MOVES.for_fighter(fighter_id)
	for slot in moves:
		var clip := str(moves[slot].get("clip", ""))
		if clip != "":
			kit[clip] = clip
	for clip in AIR:
		kit[clip] = clip
	# The story's and the ground punch's plain strikes are the fighter's own.
	for slot in ["jab", "cross", "hook", "kick"]:
		if moves.has(slot) and moves[slot].has("clip"):
			kit[slot] = moves[slot].clip
	var super_clip := str(SUPERS.get_super(fighter_id).get("clip", ""))
	if super_clip.begins_with("KB_"):
		kit[super_clip] = super_clip
	return kit
