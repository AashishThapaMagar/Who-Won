extends RefCounted
## Which fighters use a skinned, animated 3D model instead of the procedural
## rig (see fighter_animated.gd). A fighter with no entry, or with "enabled"
## false, keeps the procedural model, so characters can be swapped in one at
## a time.
##
## Entry keys:
##   scene      res:// path of the character (.glb/.fbx/.tscn, rigged)
##   enabled    set true to use it in game
##   height     standing height in metres the model is scaled to
##   width      extra horizontal scale for a heavier or slighter build
##   tint       [body colour, joint colour] painted over the model's materials
##   yaw        extra turn so the model faces the game's +X (glTF faces +Z)
##   clips      logical clip -> animation name inside `scene` or `files`
##   files      optional extra animation files (e.g. one Mixamo download per
##              move, "Without Skin"); their animations are added under the
##              file key, and can be named in `clips`
##   timing     attack clip -> [start, impact, end] seconds of the clip to use;
##              the game's hit frame is lined up with `impact`
##   impact     attack clip -> fraction of the clip where the blow lands, used
##              when there is no `timing` entry (default 0.45)
##
## Logical clips (any missing one falls back, see FALLBACK in
## fighter_animated.gd): idle, walk, walk_back, sidestep, sidestep_left,
## sidestep_right, run, dash, backdash, jump, land, block, block_hit, hit,
## hit_heavy, ko, jab, punch_heavy, uppercut, kick, kick_front, kick_spin,
## grapple, taunt, victory, injured.
##
## Every Mixamo fighter shares the X Bot body and the shared clips below
## (assets/fighters/anug/, downloaded "With Skin"); each fighter's own style
## clips live in assets/fighters/<id>/style/ ("Without Skin"). Mixamo files
## are not redistributable, so they stay local (.gitignore); without them a
## fighter falls back to the procedural rig. Dropping a rigged body.fbx in a
## fighter's folder gives them their own textured model; a body.glb built by
## tools/build_fighter_body.py is grafted onto the shared skeleton instead.
const SHARED := "res://assets/fighters/anug/"
const SHARED_FILES := {
	"idle": "idle", "walk": "walking", "walk_back": "walking_backwards",
	"jab": "lead_jab", "cross": "jab_cross", "hit": "head_hit", "hit_body": "hit_to_body",
	"kick_mid": "mma_kick_2", "kick_front": "mma_kick_1", "kick_high": "mma_kick",
	"ko": "knocked_out", "block": "body_block", "run": "running", "injured": "injured_run",
	"hit_body_alt": "hit_to_body_1", "hit_side": "hit_on_side_of_body", "hit_react": "reaction",
}
const SHARED_CLIPS := {
	"idle": "idle", "walk": "walk", "walk_back": "walk_back", "jab": "jab",
	"punch_heavy": "cross", "hit": "hit", "hit_heavy": "hit_body", "ko": "ko",
	"kick": "kick_mid", "kick_front": "kick_front", "kick_spin": "kick_high",
	"block": "block", "block_hit": "block", "run": "run", "injured": "injured",
	# Reactions picked by where and how hard each blow lands.
	"hit_head": "hit", "hit_head_heavy": "hit_react", "hit_body": "hit_body",
	"hit_body_alt": "hit_body_alt", "hit_side": "hit_side",
}
## [start, impact, end] seconds, measured from where each fist or foot is
## fully extended. Jab Cross is two punches; heavy punches use the cross.
## Second the shared knocked_out clip's body starts to drop.
const KO_FALL_START := 1.78
const SHARED_TIMING := {
	"jab": [0.0, 0.5, 1.2], "punch_heavy": [0.45, 0.7, 1.5],
	"kick": [0.25, 0.6, 1.3], "kick_front": [0.2, 0.6, 1.2], "kick_spin": [0.3, 0.7, 1.4],
}
## Everyone moves the same way: one idle, walk, back-step, strafes and run
## for the whole roster (the shared clips above plus these from
## MOVES_FOLDER). Fighters differ only in their strikes (STRIKES).
const MOVES_FOLDER := "res://assets/fighters/anug/style/"
const STYLE_MOVES := {
	# No walk_back here: the style download twists the upper body ~120° away
	# from the opponent; the shared Mixamo back-step keeps facing forward.
	"walk": "walk_forward", "sidestep_left": "strafe_left",
	"sidestep_right": "strafe_right", "run": "run",
}
## The only clips a fighter's style folder may override.
const STRIKES := ["jab", "cross", "hook", "punch_heavy", "uppercut", "kick", "kick_front", "kick_spin", "grapple", "taunt", "victory"]
## The crouch: a squat to stand (and guard) in and the leg sweep. Every
## clip is Mixamo, so a fighter whose own pack lacks one borrows it from a
## fighter that has it. [file under assets/fighters/, [start, impact, end]]
## (impacts measured with tools/measure_strike_clips.gd: the sweeping foot
## furthest out along the floor). The sweep is the capoeira rasteira, hand
## on the floor and the leg flat out; Mixamo's "low block" and "front leg
## sweep" are standing moves, so neither is used.
const LOW_KIT := {
	"crouch": ["abhi/fight/crouch_idle"],
	"strike_sweep": ["anant/capoeira/rasteira_1", [0.25, 0.7, 1.5]],
}
const OWN_LOW := {
	"ish": {"crouch": ["ish/fight/crouching_idle"]},
	"anant": {"crouch": ["anant/fight/crouching_idle"]},
	"bib": {"crouch": ["bib/fight/crouch_idle"]},
}
## Moves from Meshy's animation library (tools/fetch_meshy_animations.py,
## kept local in assets/fighters/meshy/): Meshy animated one rigged body and
## fighter_animated.gd retargets the motion onto every fighter (MESHY_BONES),
## so the whole roster shares them. logical clip -> [file, [start, impact,
## end] or none].
## Windows read off each clip frame by frame: the diving fist comes down
## at 1.5 s, the flying kick is fully out at 2.93 s, the sweeping kick's
## leg crosses the floor at 1.24 s.
const MESHY_KIT := {
	"strike_jump_punch": ["Jumping_Punch", [1.1, 1.5, 1.9]],
	"strike_flying_kick": ["Flying_Fist_Kick", [2.55, 2.93, 3.4]],
	"strike_sweeping_kick": ["Sweeping_Kick", [0.7, 1.24, 1.9]],
}
## Fighters' own Meshy clips: logical clip -> Meshy file. Mahabali beats
## his chest when he wins; Anug, who had no win of his own, cheers.
const MESHY_OWN := {
	"sab": {"victory": "Chest_Pound_Taunt", "taunt": "Chest_Pound_Taunt"},
	"anug": {"victory": "Victory_Cheer"},
	# Ananta, the master, moves entirely in his own Meshy set: a low guard
	# and fighting steps, guard-stance jab, cross, hook and rising hook, the
	# kung fu punch, roundhouse, Spartan and lunging spin kicks, a dodge and
	# counter to end his strings, a stunt sweep, his guard, his reactions,
	# and a formal bow when he wins. Each strike's impact is measured from
	# the clip as it loads (fighter_animated.gd _add_meshy_clips).
	# (Moves whose GLB isn't downloaded yet keep his Mixamo clips: see
	# meshy_file.)
	"anant": {
		"idle": "Fight_Idle", "walk": "Walk_Fight_Forward", "walk_back": "Walk_Fight_Back",
		"run": "Run_2", "jump": "Regular_Jump", "backdash": "Stand_Dodge",
		"jab": "Left_Jab_from_Guard", "cross": "Right_Jab_from_Guard", "hook": "Left_Hook_from_Guard",
		"uppercut": "Right_Upper_Hook_from_Guard", "punch_heavy": "Kung_Fu_Punch",
		"kick": "Roundhouse_Kick", "kick_front": "Spartan_Kick", "kick_spin": "Lunge_Spin_Kick",
		# Dodge and Counter once its GLB is in; the kung fu punch until then.
		"finisher": ["Dodge_and_Counter", "Kung_Fu_Punch"], "strike_sweep": "Sweep_Kick", "block": "Block1",
		"hit": "Hit_Reaction", "hit_head": "Face_Punch_Reaction", "hit_head_heavy": "Face_Punch_Reaction_2",
		"hit_body": "Hit_Reaction_to_Waist", "victory": ["Formal_Bow", "Victory_Cheer"], "taunt": "Gentlemans_Bow",
		# A body blow folds him at the waist; his Mixamo liver-shot buckled
		# his knees and dropped him into his rival.
		"hit_liver": "Hit_Reaction_to_Waist", "hit_heavy": "Hit_Reaction_to_Waist",
		# The strikes his move table names (action_moves.gd); his low kick
		# stays the Mixamo one, Meshy has none.
		"strike_roundhouse": "Roundhouse_Kick", "strike_side_kick": "Spartan_Kick",
		"strike_advancing_snap": "Step_in_High_Kick",
	},
}
## Meshy routines whose strike is picked by hand: [start, impact, end].
## The kung fu punch is a seven-second form; its standing straight punch
## lands at 3.0 s (the measured "furthest reach" found a low move after it).
const MESHY_CLIP_TIMING := {
	"Kung_Fu_Punch": [2.6, 3.0, 3.45],
}
## Fighters whose sweep is Meshy's floor-level Sweeping Kick (the rest keep
## the capoeira rasteira of LOW_KIT).
const MESHY_SWEEPERS := ["ish", "sab", "bib"]
## Fighters with Meshy's own moves (a "Merged Animations" .fbx, kept local
## like the Mixamo files): logical clip -> Meshy animation name. These
## replace the shared strikes, so each hit of a combo has its own motion.
## Animations made with Tripo (auto-rig + preset retarget) for one fighter,
## one clip per .glb in assets/fighters/<id>/tripo/: logical move ->
## [file, clip name, optional [start, impact, end] window]. Without a window
## a strike's impact is measured from the clip (furthest reach).
const TRIPO_MOVES := {
	"anant": {
		# A spinning high kick: he turns his back, whips the leg up head
		# high and lands facing forward again.
		# Windowed by hand: the measured "furthest reach" caught the leg still
		# chambered at hip height (0.7 s); the foot peaks head high at 0.8 s.
		"kick_spin": ["spin_kick.glb", "front_kick_02", [0.3, 0.8, 1.35]],
	},
	"sup": {
		# His win and taunt, and the story's gestures: cutscene lines play
		# these by name ("pose": "bow").
		"victory": ["victory_celebration.glb", "victory_celebration"],
		"taunt": ["dance_03.glb", "dance_03"],
		"bow": ["bow.glb", "bow"],
		"hug": ["hug.glb", "hug"],
		"sob": ["sob.glb", "sob"],
		"angry": ["angry_01.glb", "angry_01"],
		"agree": ["agree.glb", "agree"],
		"laugh": ["laugh_01.glb", "laugh_01"],
		"swagger": ["swagger.glb", "swagger"],
		"warm_up": ["warm_up.glb", "warm_up"],
		"dance": ["dance_01.glb", "dance_01"],
	},
}
const MESHY_MOVES := {
	"anug": {
		"jab": "Left_Jab_from_Guard", "cross": "Right_Jab_from_Guard", "hook": "Left_Hook_from_Guard",
		"uppercut": "Right_Uppercut_from_Guard", "punch_heavy": "Punch_Combo",
		"kick": "Roundhouse_Kick", "kick_front": "High_Kick", "kick_spin": "Sweep_Kick",
	},
	# Vajraveer's biped download: named moves plus three id-named ones (a stepping
	# power punch, a jumping kick and a taunt), measured the same way.
	# Vajraveer's Mixamo fight pack (STYLES bib.pack) covers his moves now; his
	# Meshy set adds only the leg sweep the pack lacks.
	# Ananta's Meshy set exports with id names; each is [id, second the blow
	# lands], measured from the peak reach of the striking hand or foot.
}
## Every fighter stands the same height (metres) and none is stretched
## wider: blows meet at the same heights, reach matches the hitboxes, and
## nothing passes over a head or stops short of a chest. Weight still
## differs (the roster's build: knockback, footwork, landings).
const FIGHTER_HEIGHT := 1.8
## Per-fighter style: body build and tint, plus style clips (file in
## style/ -> logical clip) and their timing. Impact times were measured
## from each download (peak extension of the striking hand, foot or head).
const STYLES := {
	"anug": {
		"height": FIGHTER_HEIGHT, "width": 1.0, "tint": [Color("2c5a3e"), Color("d9b45c")],
		"clips": {"idle": "idle", "block_hit": "goalkeeper_catch", "backdash": "dodging"},
	},
	"ish": {
		"height": FIGHTER_HEIGHT, "width": 1.0, "tint": [Color("a2322c"), Color("2a2227")],
		# His takedown is a spear: the chest comes up through the shot so
		# the shoulder drives into the stomach, not the thighs.
		"throw_posture": 0.34,
		"clips": {"idle": "bouncing_fight_idle", "punch_heavy": "hook_punch", "uppercut": "uppercut"},
		"timing": {"punch_heavy": [0.55, 1.13, 1.75], "uppercut": [0.05, 0.47, 1.0]},
		# His 50-clip Mixamo set (Downloads/Ish_MMA) in assets/fighters/ish/fight/
		# (kept local), "With Skin" on his cleaned-up, fisted T-pose body.
		# After a knockout he celebrates with his boxing victory.
		"pack": {
			"folder": "fight/",
			"reversed": ["walk"],
			"body": "mma_standing_idle",
			"moves": {
				"idle": "bouncing_fight_idle", "walk": "boxing_walk_backward", "walk_back": "boxing_walk_backward",
				"sidestep_left": "walk_strafe_left", "sidestep_right": "walk_strafe_right",
				"run": "unarmed_run_forward", "dash": "boxing_dodge_advance", "backdash": "boxing_dodge_retreat",
				"jump": "jump_in_place",
				"jab": "jab_punch", "cross": "cross_punch", "hook": "rear_hand_hook",
				"uppercut": "left_uppercut", "punch_heavy": "four_punch_combo",
				"kick": "mma_medium_kick", "kick_front": "lead_foot_front_snap_kick", "kick_spin": "mma_spinning_back_kick",
				"grapple": "double_leg_takedown_attacker", "thrown": "double_leg_takedown_victim", "getup": "get_up_from_back",
				"finisher": "punch_to_elbow_combo",
				"block": "high_right_block", "block_hit": "block_reaction",
				"hit": "light_head_hit", "hit_heavy": "livershot_knockdown",
				# Reactions picked by where and how hard each blow lands.
				"hit_head": "light_head_hit", "hit_head_heavy": "heavy_head_hit",
				"hit_body": "body_hit_by_straight_punch", "hit_liver": "livershot_knockdown",
				"taunt": "boxing_taunt", "victory": "boxing_victory",
				# Extra strikes, played by moves whose pose names them.
				"strike_elbow": "elbow_punch", "strike_elbow_upper": "elbow_uppercut_combo",
				"strike_body_elbow": "punch_to_elbow_combo", "strike_flying_knee": "flying_knee_punch_combo",
				"strike_high_kick": "mma_high_kick", "strike_roundhouse": "mma_roundhouse_kick",
				"strike_side_kick": "mma_side_kick", "strike_low_kick": "mma_low_kick",
			},
			# [start, impact, end], read off the clips frame by frame.
			"timing": {
				"jab": [0.25, 0.57, 0.95], "cross": [0.75, 1.13, 1.6], "hook": [0.1, 0.4, 0.85],
				"uppercut": [0.15, 0.47, 1.0], "punch_heavy": [0.3, 0.63, 1.5],
				"kick": [0.3, 0.67, 1.2], "kick_front": [0.6, 1.1, 1.5], "kick_spin": [0.45, 0.97, 1.5],
				"grapple": [0.1, 0.9, 1.5], "finisher": [0.15, 0.6, 1.4],
				"strike_elbow": [0.2, 0.65, 1.2], "strike_elbow_upper": [0.75, 1.3, 1.9],
				"strike_body_elbow": [1.5, 2.35, 3.2], "strike_flying_knee": [0.7, 1.33, 2.2],
				"strike_high_kick": [0.35, 0.73, 1.3], "strike_roundhouse": [0.35, 0.77, 1.3],
				"strike_side_kick": [0.25, 0.63, 1.2], "strike_low_kick": [0.25, 0.6, 1.1],
			},
		},
	},
	"sab": {
		"height": FIGHTER_HEIGHT, "width": 1.0, "tint": [Color("27375a"), Color("c48f49")],
		"clips": {"idle": "wrestling_idle_mmaidle", "punch_heavy": "headbutt", "grapple": "grab_and_slam"},
		"timing": {"punch_heavy": [0.2, 0.73, 1.5], "grapple": [0.3, 0.93, 3.3]},
		# His own set is small (stance, steps, headbutt, slam): the rest of
		# a full fighter's moves come from the roster's Mixamo clips, picked
		# for a big brawler (the swinging hooks and haymaker, a boxer's
		# steps). Timings are those measured for the clip's owner.
		"borrow": {
			# His own wrestler's stance (in his style folder, which only
			# strikes are taken from).
			"idle": ["sab/style/wrestling_idle_mmaidle"],
			"cross": ["abhi/fight/cross", [0.15, 0.37, 0.8]],
			"hook": ["abhi/fight/right_hook", [0.1, 0.33, 0.9]],
			"uppercut": ["ish/fight/left_uppercut", [0.15, 0.47, 1.0]],
			"finisher": ["abhi/style/punching_haymaker", [0.0, 0.4, 1.0]],
			"dash": ["ish/fight/boxing_dodge_advance"],
			"backdash": ["ish/fight/boxing_dodge_retreat"],
			"jump": ["abhi/fight/jump"],
			"thrown": ["ish/fight/double_leg_takedown_victim"],
			"getup": ["ish/fight/get_up_from_back"],
			"hit_liver": ["ish/fight/livershot_knockdown"],
			# (His win and taunt are Meshy's Chest Pound: MESHY_OWN.)
		},
	},
	"bib": {
		"height": FIGHTER_HEIGHT, "width": 1.0, "tint": [Color("223f8a"), Color("9fe0c8")],
		# The Tripo body's arms came out thin: fuller sleeves and forearms.
		"thicken": {"arm": 1.4, "forearm": 1.45, "hand": 1.2},
		"clips": {"idle": "idle", "jab": "jab", "run": "fast_run", "backdash": "dodging"},
		"timing": {"jab": [0.15, 0.57, 1.0]},
		# Bibek: the Tripo-built Vajraveer (Downloads/Bib_Tripo_Mixamo) with his
		# Mixamo set (Fighting_Game_Animations: 39 clips, real Mixamo names) in
		# assets/fighters/bib/fight/ (kept local); combat_idle carries the skin.
		"pack": {
			"folder": "fight/",
			"reversed": ["walk_back"],
			"body": "combat_idle",
			"moves": {
				"idle": "combat_idle", "walk": "walk_forward_combat", "walk_back": "walk_forward_combat",
				"sidestep_left": "walk_left_combat", "sidestep_right": "walk_right_combat",
				"run": "run_forward", "dash": "run_forward", "backdash": "step_backward_combat",
				"jump": "jump_standing",
				"jab": "punch_jab", "cross": "punch_cross", "hook": "punch_hook_lead",
				"uppercut": "punch_uppercut_rear", "punch_heavy": "combo_jabcross",
				"kick": "kick_roundhouse", "kick_spin": "kick_high",
				"getup": "getup", "finisher": "kick_high",
				"block": "block_high", "block_hit": "block_low",
				# Reactions: head blows alternate left and right, hooks and
				# roundhouses rock him sideways, straight body shots fold him.
				"hit": "hit_left", "hit_heavy": "hit_right",
				"hit_head": "hit_left", "hit_head_alt": "hit_right", "hit_head_heavy": "hit_right",
				"hit_body": "hit_body", "hit_side": "hit_left", "hit_liver": "hit_body",
				# The shared reactions and limp land badly on his rig (it is
				# turned under its parent): the alternate body hit started
				# folded nearly flat, so every other body blow looked like a
				# fall. His own clips stand in for them.
				"hit_body_alt": "hit_body", "injured": "walk_forward_combat",
				"kick_front": "kick_low",
				"ko": "knockout_back", "victory": "victory", "taunt": "taunt",
				# Extra strikes, played by moves whose pose names them.
				"strike_rear_hook": "punch_hook_rear", "strike_lead_uppercut": "punch_uppercut_lead",
				"strike_rear_uppercut": "punch_uppercut_rear", "strike_one_two": "combo_jabcross",
				"strike_high_kick": "kick_high", "strike_roundhouse": "kick_roundhouse",
				"strike_side_kick": "kick_side", "strike_low_kick": "kick_low",
			},
			# [start, impact, end]: impact at the furthest reach of the fist or
			# foot (measured from each clip); the tails are trimmed so he is
			# back in guard quickly.
			"timing": {
				"jab": [0.17, 0.47, 0.92], "cross": [0.37, 0.67, 1.12], "hook": [0.17, 0.47, 0.95],
				"uppercut": [0.4, 0.7, 1.15], "punch_heavy": [0.37, 0.67, 1.15],
				"kick": [0.42, 0.77, 1.3], "kick_spin": [0.35, 0.7, 1.3], "finisher": [0.35, 0.7, 1.4],
				"strike_rear_hook": [0.37, 0.67, 1.12], "strike_lead_uppercut": [0.4, 0.7, 1.15],
				"strike_rear_uppercut": [0.4, 0.7, 1.15], "strike_one_two": [0.37, 0.67, 1.15],
				"strike_high_kick": [0.35, 0.7, 1.3], "strike_roundhouse": [0.42, 0.77, 1.3],
				"strike_side_kick": [0.28, 0.63, 1.15], "strike_low_kick": [0.25, 0.6, 1.1],
			},
		},
	},
	"abhi": {
		"height": FIGHTER_HEIGHT, "width": 1.0, "tint": [Color("5c2f78"), Color("dbb258")],
		"clips": {"idle": "idle", "punch_heavy": "punching_haymaker", "taunt": "taunt", "victory": "victory"},
		"timing": {"punch_heavy": [0.0, 0.4, 1.0], "taunt": [0.0, 0.8, 1.63]},
		# His 46-clip Mixamo set (Downloads/Abhi_MMA) in assets/fighters/abhi/fight/
		# (kept local), "With Skin" on his fisted T-pose body.
		"pack": {
			"folder": "fight/",
			"reversed": ["walk"],
			"body": "regular_mma_idle",
			"moves": {
				"idle": "regular_mma_idle", "walk": "boxing_walk_back", "walk_back": "boxing_walk_back",
				"sidestep_left": "strafe_left", "sidestep_right": "strafe_right",
				"run": "run_forward", "dash": "run_forward", "backdash": "dodge_back",
				"jump": "jump",
				"jab": "jab", "cross": "cross", "hook": "lead_hook",
				"uppercut": "long_body_hook", "punch_heavy": "right_hook",
				"kick": "rear_roundhouse", "kick_front": "double_front_kick", "kick_spin": "advancing_roundhouse",
				"grapple": "double_leg_takedown_attacker", "thrown": "double_leg_takedown_victim", "getup": "get_up_from_back",
				"finisher": "eight_punch_combo",
				"block": "chest_block", "block_hit": "block_reaction",
				"hit": "body_hit", "hit_heavy": "liver_shot_knockdown",
				# Reactions picked by where and how hard each blow lands.
				"hit_head": "light_head_hit", "hit_head_heavy": "heavy_head_hit",
				"hit_body": "body_hit", "hit_liver": "liver_shot_knockdown",
				"victory": "victory", "taunt": "boxing_taunt",
				# Extra strikes, played by moves whose pose names them.
				"strike_short_hook": "short_head_hook", "strike_jab_elbow": "jab_elbow_combo",
				"strike_front_sweep": "front_leg_sweep", "strike_back_sweep": "back_leg_sweep",
				"strike_lead_front": "lead_front_kick", "strike_rear_front": "rear_front_kick",
			},
			# [start, impact, end], measured from each clip.
			"timing": {
				"jab": [0.3, 0.57, 0.95], "cross": [0.15, 0.37, 0.8], "hook": [0.25, 0.57, 1.1],
				"uppercut": [0.8, 1.2, 2.0], "punch_heavy": [0.1, 0.33, 0.9],
				"kick": [0.35, 0.67, 1.3], "kick_front": [0.3, 0.63, 1.2], "kick_spin": [0.7, 1.0, 1.7],
				"grapple": [0.1, 0.9, 1.5], "finisher": [0.9, 1.23, 2.1],
				"strike_short_hook": [0.15, 0.4, 1.0], "strike_jab_elbow": [1.5, 2.0, 2.8],
				"strike_front_sweep": [0.5, 0.87, 1.4], "strike_back_sweep": [0.6, 1.07, 1.7],
				"strike_lead_front": [0.9, 1.37, 2.0], "strike_rear_front": [0.9, 1.2, 1.9],
			},
		},
	},
	"sup": {
		"height": FIGHTER_HEIGHT, "width": 1.0, "tint": [Color("c29a3c"), Color("2f8a86")],
		"clips": {"idle": "idle", "kick": "roundhouse_kick", "kick_spin": "flip_kick"},
		"timing": {"kick": [0.45, 1.07, 1.9], "kick_spin": [0.4, 1.0, 1.8]},
		# The Spiral fights in capoeira (the Mixamo capoeira set in
		# assets/fighters/anant/capoeira/): he sways in the ginga, kicks
		# with the martelo, the bencao push kick, the meia-lua de compasso
		# spinning heel, and ends strings on the armada. Impacts measured
		# with tools/measure_strike_clips.gd.
		"borrow": {
			"idle": ["anant/capoeira/ginga_variation_1"],
			"walk": ["anant/capoeira/ginga_forward"],
			"walk_back": ["anant/capoeira/ginga_backward"],
			"kick": ["anant/capoeira/martelo_2", [0.15, 0.46, 1.0]],
			"kick_front": ["anant/capoeira/bencao", [0.3, 0.64, 1.2]],
			"kick_spin": ["anant/capoeira/meia_lua_de_compasso", [0.8, 1.32, 1.73]],
			"finisher": ["anant/capoeira/armada", [0.85, 1.34, 1.63]],
		},
	},
	"anant": {
		"height": FIGHTER_HEIGHT, "width": 1.0, "tint": [Color("5a2f6a"), Color("d3ac62")],
		"clips": {"idle": "mma_idle", "kick": "martial_arts_kick", "kick_spin": "martial_arts_kick", "victory": "fireball"},
		"timing": {"kick": [0.2, 0.73, 1.5], "kick_spin": [0.2, 0.73, 1.5]},
		# MMA: his 47-clip Mixamo set (Downloads/Ananta_MMA) in
		# assets/fighters/anant/fight/ (kept local), "With Skin" on his
		# cleaned-up T-pose body. Every fighting clip is used.
		"pack": {
			"folder": "fight/",
			"reversed": ["walk"],
			"body": "boxing_victory",
			"moves": {
				"idle": "mma_standing_idle", "walk": "boxing_walk_backward", "walk_back": "boxing_walk_backward",
				"sidestep_left": "walk_strafe_left", "sidestep_right": "walk_strafe_right",
				"run": "unarmed_run_forward", "dash": "unarmed_run_forward", "backdash": "unarmed_run_backward",
				"jump": "jump_in_place",
				"jab": "jab_punch", "cross": "cross_punch", "hook": "rear_hand_hook",
				"uppercut": "left_uppercut", "punch_heavy": "four_punch_combo",
				"kick": "mma_medium_kick", "kick_front": "lead_foot_front_snap_kick", "kick_spin": "mma_spinning_back_kick",
				"grapple": "double_leg_takedown_attacker", "thrown": "double_leg_takedown_victim", "getup": "get_up_from_back",
				"finisher": "four_punch_combo",
				"block": "high_right_block", "block_hit": "block_reaction",
				# Body-shot reactions: the head-hit clips whip his head so far
				# back that the collar and neck stretch.
				"hit": "body_hit_by_straight_punch", "hit_heavy": "body_hit_by_straight_punch",
				# Reactions picked by where and how hard each blow lands.
				"hit_head": "medium_head_hit", "hit_head_alt": "taking_punch_reaction", "hit_head_heavy": "heavy_head_hit",
				"hit_body": "body_hit_by_straight_punch", "hit_liver": "body_hit_by_straight_punch",
				"victory": "boxing_victory", "taunt": "boxing_taunt",
				# Extra strikes, played by moves whose pose names them.
				"strike_roundhouse": "mma_roundhouse_kick", "strike_side_kick": "mma_side_kick",
				"strike_low_kick": "mma_low_kick", "strike_advancing_snap": "rear_foot_advancing_front_snap_kick",
			},
			# [start, impact, end] around the frame the fist, knee or foot
			# reaches furthest (measured from each clip).
			"timing": {
				"jab": [0.25, 0.57, 0.95], "cross": [0.75, 1.13, 1.6], "hook": [0.1, 0.4, 0.85],
				"uppercut": [0.15, 0.47, 1.0], "punch_heavy": [0.3, 0.63, 1.5],
				"kick": [0.35, 0.73, 1.3], "kick_front": [0.6, 1.1, 1.5], "kick_spin": [0.45, 0.97, 1.5],
				"grapple": [0.1, 0.9, 1.5], "finisher": [0.95, 1.37, 2.1],
				"strike_roundhouse": [0.35, 0.77, 1.3], "strike_side_kick": [0.25, 0.63, 1.2],
				"strike_low_kick": [0.25, 0.6, 1.1], "strike_advancing_snap": [0.9, 1.37, 1.9],
			},
		},
	},
}
## Other entries, kept as examples of the format.
const MODELS := {
	# Test dummy: Kenney "Mini Characters" (CC0), a simple 7-bone rig with
	# idle/walk/sprint/jump/punch/kick/die clips. Rename the key to a fighter
	# id and set enabled to try it.
	"kenney_test": {
		"scene": "res://assets/fighters/test-kenney/character-male-a.glb",
		"enabled": false,
		"height": 1.85,
		"yaw": PI / 2.0,
		"clips": {
			"idle": "idle", "walk": "walk", "run": "sprint", "jump": "jump",
			"land": "fall", "jab": "attack-melee-right", "punch_heavy": "attack-melee-left",
			"kick": "attack-kick-right", "kick_spin": "attack-kick-left", "ko": "die",
			"hit": "emote-no", "block": "crouch", "taunt": "emote-yes", "grapple": "pick-up",
		},
		"impact": {"jab": 0.45, "punch_heavy": 0.45, "kick": 0.5, "kick_spin": 0.5},
	},
}

## A rigged model dropped straight into the fighter's folder (a Meshy
## auto-rig export, a Mixamo character with clips baked in, any rigged
## glTF): assets/fighters/<id>/meshy_rig.glb, rig.glb or <id>.glb. It is
## used as-is, its own animations matched to the game's clips by name (see
## fighter_animated.gd match_clip), so no table entry is needed. Open the
## project in the editor once so the file imports.
const DROP_NAMES := ["meshy_rig.glb", "rig.glb", "meshy_rig.gltf", "rig.gltf"]

## A Meshy library move as saved by tools/fetch_meshy_animations.py: its
## GLB download (Mixamo bone names, glTF axes). The FBX download retargets
## twisted (the body hunched and turned), so a move with only an FBX is
## left out and the fighter keeps the clip it had.
static func meshy_file(name: String) -> String:
	return "res://assets/fighters/meshy/%s.glb" % name

static func dropped_scene(fighter_id: String) -> String:
	var folder := "res://assets/fighters/%s/" % fighter_id
	for name in DROP_NAMES + [fighter_id + ".glb", fighter_id + ".gltf"]:
		if FileAccess.file_exists(folder + name):
			return folder + name
	return ""

static func entry(fighter_id: String) -> Dictionary:
	var dropped := dropped_scene(fighter_id)
	if dropped != "":
		var style: Dictionary = STYLES.get(fighter_id, {})
		return {
			"scene": dropped, "enabled": true, "body": "",
			"height": style.get("height", 1.8), "width": 1.0, "tint": [],
			"yaw": PI / 2.0, "files": {}, "clips": {}, "timing": {},
		}
	if STYLES.has(fighter_id):
		return _mixamo(fighter_id)
	var data: Dictionary = MODELS.get(fighter_id, {})
	return data if data.get("enabled", false) else {}

## Shared body and clips, overlaid with the fighter's own style folder.
static func _mixamo(fighter_id: String) -> Dictionary:
	var style: Dictionary = STYLES[fighter_id]
	var folder := "res://assets/fighters/%s/style/" % fighter_id
	var files := {}
	for key in SHARED_FILES:
		files[key] = SHARED + SHARED_FILES[key] + ".fbx"
	var clips: Dictionary = SHARED_CLIPS.duplicate()
	for logical in STYLE_MOVES:
		var path: String = MOVES_FOLDER + STYLE_MOVES[logical] + ".fbx"
		if ResourceLoader.exists(path):
			files["move_" + logical] = path
			clips[logical] = "move_" + logical
	var own: Dictionary = style.get("clips", {})
	for logical in own:
		var path: String = folder + own[logical] + ".fbx"
		if logical in STRIKES and ResourceLoader.exists(path):
			files["style_" + logical] = path
			clips[logical] = "style_" + logical
	var timing: Dictionary = SHARED_TIMING.duplicate()
	timing.merge(style.get("timing", {}), true)
	# A full move pack (a fighting style's whole Mixamo set): its clips cover
	# stance and steps too, not only strikes.
	var pack: Dictionary = style.get("pack", {})
	var pack_scene := ""
	var pack_folder := "res://assets/fighters/%s/%s" % [fighter_id, pack.get("folder", "")]
	if not pack.is_empty() and DirAccess.dir_exists_absolute(pack_folder):
		for logical in pack.moves:
			var path: String = pack_folder + pack.moves[logical] + ".fbx"
			if ResourceLoader.exists(path):
				files["pack_" + logical] = path
				clips[logical] = "pack_" + logical
				timing.erase(logical)
		timing.merge(pack.get("timing", {}), true)
		var pack_body: String = pack_folder + str(pack.get("body", "")) + ".fbx"
		if pack.has("body") and ResourceLoader.exists(pack_body):
			pack_scene = pack_body
	# Clips borrowed from other fighters' Mixamo sets to fill this one's
	# gaps: [file under assets/fighters/, optional [start, impact, end]].
	var borrowed: Dictionary = style.get("borrow", {})
	for logical in borrowed:
		var entry: Array = borrowed[logical]
		var path := "res://assets/fighters/%s.fbx" % entry[0]
		if ResourceLoader.exists(path):
			files["borrow_" + logical] = path
			clips[logical] = "borrow_" + logical
			if entry.size() > 1:
				timing[logical] = entry[1]
			else:
				timing.erase(logical)
	for logical in LOW_KIT:
		var entry: Array = OWN_LOW.get(fighter_id, {}).get(logical, LOW_KIT[logical])
		var path := "res://assets/fighters/%s.fbx" % entry[0]
		if not ResourceLoader.exists(path):
			entry = LOW_KIT[logical]
			path = "res://assets/fighters/%s.fbx" % entry[0]
		if ResourceLoader.exists(path):
			files["low_" + logical] = path
			clips[logical] = "low_" + logical
			if entry.size() > 1:
				timing[logical] = entry[1]
	var meshy := {}
	var meshy_file := "res://assets/fighters/%s/meshy_moves.fbx" % fighter_id
	if not ResourceLoader.exists(meshy_file):
		meshy_file = meshy_file.get_basename() + ".glb"
	if MESHY_MOVES.has(fighter_id) and ResourceLoader.exists(meshy_file):
		var names := {}
		for logical in MESHY_MOVES[fighter_id]:
			var entry = MESHY_MOVES[fighter_id][logical]
			clips[logical] = "meshy_" + logical
			if entry is Array:
				# [name, impact second]: a window around the blow.
				names[logical] = entry[0]
				timing[logical] = [maxf(0.0, entry[1] - 0.35), entry[1], entry[1] + 0.55]
			else:
				# Whole moves; the impact sits at 45%.
				names[logical] = entry
				timing.erase(logical)
		meshy = {"file": meshy_file, "clips": names}
	var tripo: Array = []
	for logical in TRIPO_MOVES.get(fighter_id, {}):
		var entry: Array = TRIPO_MOVES[fighter_id][logical]
		var tripo_file := "res://assets/fighters/%s/tripo/%s" % [fighter_id, entry[0]]
		if not ResourceLoader.exists(tripo_file):
			continue
		tripo.append({"file": tripo_file, "clips": {logical: entry[1]}})
		clips[logical] = "meshy_" + logical
		if entry.size() > 2:
			timing[logical] = entry[2]
		else:
			timing.erase(logical)
	for logical in MESHY_KIT:
		var entry: Array = MESHY_KIT[logical]
		var kit_file := meshy_file(entry[0])
		if not ResourceLoader.exists(kit_file):
			continue
		# "" takes the file's one animation, whatever Meshy named it.
		tripo.append({"file": kit_file, "clips": {logical: ""}})
		clips[logical] = "meshy_" + logical
		if entry.size() > 1:
			timing[logical] = entry[1]
		else:
			timing.erase(logical)
	var own_meshy: Dictionary = MESHY_OWN.get(fighter_id, {})
	var reversed: Array = pack.get("reversed", []).duplicate()
	for logical in own_meshy:
		# A name, or names in order of preference (the first downloaded).
		var names: Array = own_meshy[logical] if own_meshy[logical] is Array else [own_meshy[logical]]
		for name in names:
			var own_file := meshy_file(name)
			if ResourceLoader.exists(own_file):
				tripo.append({"file": own_file, "clips": {logical: ""}})
				clips[logical] = "meshy_" + logical
				timing.erase(logical)
				if MESHY_CLIP_TIMING.has(name):
					timing[logical] = MESHY_CLIP_TIMING[name]
				# The pack played its own clip for this backwards (a walk-back
				# used as the walk); the Meshy clip plays the right way round.
				reversed.erase(logical)
				break
	if fighter_id in MESHY_SWEEPERS and clips.has("strike_sweeping_kick"):
		clips["strike_sweep"] = clips["strike_sweeping_kick"]
		timing["strike_sweep"] = timing["strike_sweeping_kick"]
	# A fighter's own rigged body (assets/fighters/<id>/body.fbx, from Mixamo
	# "With Skin") replaces the X Bot and keeps its real textures untinted.
	var body := "res://assets/fighters/%s/body.fbx" % fighter_id
	if pack_scene != "":
		body = pack_scene
	var own_body := ResourceLoader.exists(body)
	var built := "res://assets/fighters/%s/body.glb" % fighter_id
	var graft := "" if own_body or not ResourceLoader.exists(built) else built
	# The high-detail Meshy body (Meshy_Models, rigged by
	# tools/rig_meshy_body.py) is fitted to the shared X Bot skeleton, so it
	# goes on that skeleton: grafted onto a fighter's own older rig (whose
	# rest pose and joints differ: Vajraveer's is turned under its parent)
	# it bent and twisted. The fighter's own Mixamo clips still play: every
	# Mixamo clip fits every Mixamo skeleton.
	var meshy_body := "res://assets/fighters/%s/meshy_body.glb" % fighter_id
	if ResourceLoader.exists(meshy_body):
		graft = meshy_body
		own_body = false
	return {
		"scene": body if own_body else SHARED + "idle.fbx",
		"body": graft,
		"enabled": ResourceLoader.exists(SHARED + "idle.fbx"),
		"height": style.get("height", 1.8),
		"width": style.get("width", 1.0),
		# The Meshy bodies have their own limbs; only the old ones were filled out.
		"thicken": {} if graft.ends_with("meshy_body.glb") else style.get("thicken", {}),
		"tint": [] if own_body or graft != "" else style.get("tint", []),
		"yaw": PI / 2.0,
		"files": files,
		"clips": clips,
		"timing": timing,
		"meshy": meshy,
		"tripo": tripo,
		"reversed": reversed,
		"throw_posture": style.get("throw_posture", 0.0),
		# The shared knockout stands still for 1.6 s before the body drops:
		# a knockout starts at the drop, so the fall is the blow's reaction.
		"starts": {"ko": KO_FALL_START} if clips.get("ko", "") == "ko" else {},
	} if ResourceLoader.exists(SHARED + "idle.fbx") else {}
