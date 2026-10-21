extends RefCounted
## Per-fighter move tables for live (action.tres) matches: starts from the
## shared "action" style's generic six normals + two enders, then reskins
## names/poses and swaps in signature moves per character id. Player.gd
## reads these through available_moves() instead of move_catalog's
## style-generic tables whenever is_action_fight() is true.
const BASE := preload("res://scripts/move_catalog.gd")
## Fight pace: strikes wind up and recover like a real exchange instead of
## flickering. Stun grows with the startups so every combo still links.
const PACE_STARTUP := 1.8
const PACE_RECOVERY := 1.35
const CLIP_REACH := preload("res://scripts/clip_reach.gd")
## Metres a strike reaches past its clip's fist or foot: the rival's body in
## front of their hips (~0.15) and the step in (fighter_animated.gd).
const REACH_ALLOWANCE := 0.27
## Real timing (see the LOOK pass): impacts read earlier than this are an
## arm already forward at the first frame, not a blow; and the share of a
## clip's return to guard that the recovery lasts (the rest is cancelled
## into the next move or blended back to the stance).
const MIN_READ_IMPACT := 0.06
## Longest wind-up a strike keeps (seconds): the slowest kicks of the pack
## play a touch quicker than performed, so a string still links without a
## stun long enough to lock a rival under repeated jabs.
const MAX_REAL_STARTUP := 0.32
const RECOVERY_SHARE := 0.4
## Stun past the slowest follow-up's wind-up, so a timed press always links.
const LINK_SLACK := 0.08
## Each fighter's own tempo on top of that (x startup, recovery and stun):
## Vajraveer flicks, Agasthya is quick, Sarvochcha flows, Mahabali's blows
## take their time and land like a wall falling.
const TEMPO := {"bib": 0.85, "ish": 0.9, "sup": 0.95, "anug": 1.0, "anant": 1.0, "abhi": 1.05, "sab": 1.2}
## How each fighter's moves look: slot -> [name, clip from Fighting Animset
## Pro (assets/fighters/animset/, played by fighter_animated.gd), optional
## height]. No two fighters share a strike: Agasthya boxes, Mahabali swings
## heavy, Vajraveer flicks jabs and rabbit kicks, Kri spins, Anug keeps a
## keeper's straight kicks and elbows, Sarvochcha circles with round elbows
## and kicks, Ananta has the clean complete game. Frame data and combo routes
## stay as set above; a height is given where the new strike lands at
## another height than the slot's old one.
const LOOK := {
	"ish": {
		# From the crouch: 2 and 4.
		"crouch_rp": ["Ducking jab", "KB_crouch_p_Jab_R"], "crouch_rk": ["Low thigh kick", "KB_p_LowKick_R_1", -40],
		# Signature moves (forward / back + 2 and 4).
		"f_rp": ["Flash lunge", "KB_crouch_p_Jab_R"], "b_rp": ["Hammer fall", "KB_Projectile_3"],
		"f_rk": ["Toppling kick", "KB_p_HighKick_R_1", -84], "b_rk": ["Thigh chop", "KB_p_MidKick_R_1", -40],
		"jab": ["Flash jab", "KB_p_Jab_L_1"], "cross": ["Hammer cross", "KB_p_Jab_R_1"],
		"hook": ["Flash hook", "KB_p_Hook_L"], "rp": ["Rear hook", "KB_p_Hook_R"],
		"elbow_upper": ["Sky hammer", "KB_p_Uppercut_R"], "body_elbow": ["Three-cup combo", "KB_p_OneTwoThree"],
		"chain_bridge": ["Flash flurry", "KB_p_Jab_LRL_combo"], "chain_finish": ["Flash rising fist", "KB_p_Uppercut_L"],
		"combo_finish": ["Hammer Drop", "KB_p_DoubleHooks"], "drive": ["Flash one-two", "KB_p_OneTwo"],
		"crouch_punch": ["Rising uppercut", "KB_p_Uppercut_L"],
		"kick": ["Snap kick", "KB_p_MidKickFront_R"], "forward_heavy": ["Body kick", "KB_p_MidKick_R_1"],
		"back_heavy": ["Low kick", "KB_p_LowKick_R_1", -40], "rk": ["High kick", "KB_p_HighKick_R_1", -84],
		"roundhouse": ["Turning body kick", "KB_p_MidKick_R_1"], "side_kick": ["Push kick", "KB_p_MidKickFront_R"],
		"breaker": ["Flying knee", "KB_m_KneeLeft", -72], "sweep": ["Hammer sweep", "KB_p_LowKick_R_1", -40],
	},
	"sab": {
		# From the crouch: 2 and 4.
		"crouch_rp": ["Low anvil", "KB_crouch_m_Uppercut_R"], "crouch_rk": ["Low chop", "KB_crouch_m_LowKickRound_R"],
		# Signature moves (forward / back + 2 and 4).
		"f_rp": ["Battering palm", "KB_Projectile_1"], "b_rp": ["Hammer elbow", "KB_p_Elbow_Top_L"],
		"f_rk": ["Iron axe drop", "KB_AxeKick", -86], "b_rk": ["Low chop", "KB_m_LowKickRound_R"],
		"jab": ["Club jab", "KB_m_Overhand_L"], "cross": ["Anvil overhand", "KB_m_Overhand_R"],
		"hook": ["Anvil hook", "KB_m_Backswing_L"], "rp": ["Backswing", "KB_m_Backswing_R"],
		"chain_bridge": ["Iron body hook", "KB_p_MidHook_R", -64], "chain_finish": ["Anvil body hook", "KB_p_MidHook_L", -66],
		"combo_finish": ["Anvil Drop", "KB_m_Backelbow_Uppercut_R"], "drive": ["Battering ram", "KB_p_MidHook_L", -66],
		"breaker": ["Hammer elbow", "KB_p_Elbow_Top_L"], "crouch_punch": ["Rising uppercut", "KB_crouch_m_Uppercut_R"],
		"kick": ["Iron knee", "KB_m_KneeRight", -68], "forward_heavy": ["Iron axe kick", "KB_AxeKick", -86],
		"back_heavy": ["Low chop", "KB_m_LowKickRound_R", -28], "rk": ["Stomp axe", "KB_AxeKick", -86],
		"sweep": ["Iron sweep", "KB_crouch_m_LowKickRound_R"],
	},
	"bib": {
		# From the crouch: 2 and 4.
		"crouch_rp": ["Low needle", "KB_p_MidJab_L", -40], "crouch_rk": ["Low flick", "KB_p_LowKick_L_1"],
		# Signature moves (forward / back + 2 and 4).
		"f_rp": ["Needle rush", "KB_p_Jab_LL_combo"], "b_rp": ["Falling wheel", "KB_m_HighKickRound_R_1", -86],
		"f_rk": ["Rabbit topple", "KB_m_MidRabbitKick_R"], "b_rk": ["Low flick", "KB_p_LowKick_L_1"],
		"jab": ["Needle jab", "KB_p_MidJab_L"], "cross": ["Rapid straight", "KB_p_MidJab_R"],
		"hook": ["Double needle", "KB_p_DoubleJab"], "rp": ["Relay one-two", "KB_p_Jab_LR_combo"],
		"knee": ["Relay double", "KB_p_Jab_LL_combo"], "rising": ["Rising uppercut", "KB_p_MidUppercut_R"],
		"chain_bridge": ["Relay jabs", "KB_p_DoubleJab"], "drive": ["Rush one-two", "KB_p_Jab_LR_combo"],
		"crouch_punch": ["Rising uppercut", "KB_p_MidUppercut_R"],
		"kick": ["Running arc", "KB_p_MidKick_L_1"], "forward_heavy": ["Front kick", "KB_p_MidKickFront_L"],
		"back_heavy": ["Low kick", "KB_p_LowKick_L_1", -28], "rk": ["Relay high kick", "KB_m_HighKickRound_R_1", -86],
		"roundhouse": ["Rabbit kick", "KB_m_MidRabbitKick_R"], "side_kick": ["Relay side kick", "KB_m_SideKickLeft"],
		"chain_finish": ["Relay side kick", "KB_m_SideKickLeft"], "combo_finish": ["Endless Rush", "KB_m_MidRabbitKick_R_combo"],
		"breaker": ["Relay wheel", "KB_m_HighKickRound_R_1", -86], "sweep": ["Relay sweep", "KB_p_LowKick_L_1"],
	},
	"abhi": {
		# From the crouch: 2 and 4.
		"crouch_rp": ["Low thunder", "KB_crouch_m_Uppercut_R_2"], "crouch_rk": ["Low special", "KB_m_LowKickL_Special"],
		# Signature moves (forward / back + 2 and 4).
		"f_rp": ["Thunder lunge", "KB_m_BackfistRoundFar_R"], "b_rp": ["Mic slam", "KB_m_BackfistRound_L"],
		"f_rk": ["Thunder launch", "KB_m_KickUppercut_R", -84], "b_rk": ["Low special", "KB_m_LowKickL_Special"],
		"jab": ["Thunder jab", "KB_m_Jab_LR_combo"], "cross": ["Spinning backfist", "KB_m_BackfistRound_R"],
		"hook": ["Mic drop", "KB_m_BackfistRound_L"], "rp": ["Short elbow", "KB_m_Backelbow_R"],
		"elbow": ["Spinning elbow", "KB_m_Backelbow_L"], "drive": ["Loud thunder", "KB_m_BackfistRoundFar_R"],
		"chain_bridge": ["Thunder elbow", "KB_m_Backelbow_R"], "chain_finish": ["Thunder overhand", "KB_m_BackfistRoundFar_R"],
		"combo_finish": ["Thunderclap", "KB_m_Uppercut_R"], "crouch_punch": ["Rising uppercut", "KB_crouch_m_Uppercut_R_2"],
		"kick": ["Thunder roundhouse", "KB_m_RoundhouseKickRight", -76], "rk": ["High round kick", "KB_m_HighKickRound_L_1", -86],
		"rear_front": ["Spinning back kick", "KB_m_BackKick_R"], "forward_heavy": ["Low special", "KB_m_LowKickL_Special", -26],
		"breaker": ["Rising kick", "KB_m_KickUppercut_R", -84], "sweep": ["Thunder sweep", "KB_m_LowKickL_Special"],
	},
	"anug": {
		# From the crouch: 2 and 4.
		"crouch_rp": ["Low keeper jab", "KB_crouch_p_Jab_L"], "crouch_rk": ["Low clearance", "KB_p_LowKick_R_2"],
		# Signature moves (forward / back + 2 and 4).
		"f_rp": ["Diving punch", "KB_crouch_p_Jab_L"], "b_rp": ["Keeper slam", "KB_Projectile_2"],
		"f_rk": ["Clearance high kick", "KB_p_HighKickStraight_R", -84], "b_rk": ["Slide tackle", "KB_p_LowKick_R_2"],
		"jab": ["Keeper jab", "KB_p_RabbitPunch_End"], "cross": ["Clearance uppercut", "KB_p_MidUppercut_L"],
		"hook": ["Glove elbow", "KB_p_Elbow_L"], "rp": ["Keeper elbow", "KB_p_Elbow_R"],
		"chain_bridge": ["Keeper palm", "KB_p_MidUppercut_L"], "breaker": ["High-ball punch", "KB_p_MidUppercut_L"],
		"drive": ["Diving clearance", "KB_p_RabbitPunch_End"], "back_heavy": ["Low save", "KB_crouch_p_Uppercut_L"],
		"crouch_punch": ["Rising uppercut", "KB_crouch_p_Uppercut_L"],
		"kick": ["Teep", "KB_p_MidKickStraight_R", -62], "forward_heavy": ["Push kick", "KB_m_MidKickStraight_R", -62],
		"rk": ["Straight high kick", "KB_p_HighKickStraight_R", -84], "chain_finish": ["Goal-line clearance", "KB_m_MidKickStraight_R", -62],
		"combo_finish": ["Goal Kick", "KB_MidKickStraightLong", -64], "sweep": ["Slide tackle", "KB_p_LowKick_R_2"],
	},
	"sup": {
		# From the crouch: 2 and 4.
		"crouch_rp": ["Low spiral palm", "KB_crouch_p_Uppercut_R"], "crouch_rk": ["Low spiral kick", "KB_crouch_p_LowKickRound_R"],
		# Signature moves (forward / back + 2 and 4).
		"f_rp": ["Spiral palm rush", "KB_Projectile_4"], "b_rp": ["Spiral drop", "KB_m_BackfistRound_L2"],
		"f_rk": ["Spiral wheel", "KB_m_MidKickRoud_L_1"], "b_rk": ["Low spiral", "KB_crouch_p_LowKickRound_R"],
		"jab": ["Spiral hooks", "KB_m_Hook_LR_combo"], "cross": ["Spiral backfist", "KB_m_BackfistRound_L2"],
		"hook": ["Swaying elbow", "KB_m_ElbowRound_L"], "rp": ["Spiral elbow", "KB_m_ElbowRound_R"],
		"chain_bridge": ["Spiral palm", "KB_m_ElbowRound_L2"], "crouch_punch": ["Rising uppercut", "KB_crouch_p_Uppercut_R"],
		"kick": ["Low spiral", "KB_crouch_p_LowKickRound_R", -28], "forward_heavy": ["Spiral body kick", "KB_m_MidKickRoud_R_1"],
		"drive": ["Spiral hammer kick", "KB_m_HighKick_R_2", -84], "breaker": ["Spiral wheel", "KB_m_MidKickRoud_L_1"],
		"combo_finish": ["Spiral Storm", "KB_m_HighKick_R_2", -84], "rk": ["Spiral roundhouse", "KB_m_MidKick_R_2"],
		"chain_finish": ["Spiral heel", "KB_m_MidKick_L_2"], "back_heavy": ["Slip away", "KB_m_Duck_L"],
		"sweep": ["Spiral sweep", "KB_crouch_p_LowKickRound_R"],
	},
	"anant": {
		# From the crouch: 2 and 4.
		"crouch_rp": ["Crown low jab", "KB_m_Jab_L", -40], "crouch_rk": ["Crown low kick", "KB_crouch_p_LowKick_L"],
		# Signature moves (forward / back + 2 and 4).
		"f_rp": ["Sovereign rush", "KB_m_OneTwo"], "b_rp": ["Crown axe", "KB_m_HighKick_R", -86],
		"f_rk": ["Crown double", "KB_m_MidKick_LL_2_combo"], "b_rk": ["Crown low kick", "KB_crouch_p_LowKick_L"],
		"jab": ["Snap jab", "KB_m_Jab_L"], "cross": ["Straight cross", "KB_m_Jab_R"],
		"hook": ["Rear hook", "KB_m_Hook_R"], "rp": ["Sovereign one-two", "KB_m_OneTwo"],
		"chain_bridge": ["Crown hook", "KB_m_Hook_L"], "drive": ["Rising uppercut", "KB_m_Uppercut_L"],
		"combo_finish": ["The Final Word", "KB_m_Jab_RLhook_combo"], "crouch_punch": ["Rising uppercut", "KB_m_Uppercut_L"],
		"kick": ["Body kick", "KB_m_MidKick_R"], "forward_heavy": ["Front kick", "KB_m_MidKick_L"],
		"breaker": ["Crown high kick", "KB_m_HighKick_R", -86], "rk": ["Crown roundhouse", "KB_m_HighKick_R", -86],
		"side_kick": ["Crown combination", "KB_m_Jab_RLhookRMidKick_combo"], "snap_advance": ["Advancing double kick", "KB_m_MidKick_LL_2_combo"],
		"chain_finish": ["Crown double kick", "KB_m_MidKick_LL_2_combo"], "back_heavy": ["Low kick", "KB_crouch_p_LowKick_L"],
		"sweep": ["Crown sweep", "KB_crouch_p_LowKick_L"],
	},
}

static func for_fighter(id: String) -> Dictionary:
	var m := BASE.for_style("action")
	m.jab.name = "Quick check"
	m.cross.name = "Step straight"
	m.hook.name = "Turnaround fist"
	m.kick.name = "Arc kick"
	m.forward_heavy.name = "Push kick"
	m.back_heavy.name = "Rising knee"
	match id:
		"anug":
			m.jab.name = "Glove check"
			m.cross.name = "Clearance punch"
			m.hook.name = "Palm deflection"
			m.drive = BASE._move("Diving clearance", "dive", "punch", "hook", 66, -69, 0.22, 0.10, 0.42, 1.55, 1.25, 52)
			m.breaker = BASE._move("High-ball punch", "uppercut", "punch", "hook", 42, -98, 0.18, 0.08, 0.38, 1.65, 1.5, 16)
			m.combo_finish = BASE._move("Goal Kick", "spin", "kick", "kick", 72, -40, 0.14, 0.09, 0.38, 1.7, 1.8, 20)
			m.back_heavy = BASE._move("Low save", "save", "punch", "hook", 47, -50, 0.14, 0.07, 0.28, 1.1, 1.0, 18)
		"ish":
			m.jab.name = "Flash jab"
			m.cross.name = "Hammer straight"
			m.drive.name = "Flash hammer"
			m.drive.lunge = 46.0
			m.breaker = BASE._move("Sky hammer", "uppercut", "punch", "hook", 42, -96, 0.25, 0.07, 0.43, 1.8, 1.5, 20)
			# His double hooks (LOOK) end the 1,1,1,3 string.
			m.combo_finish = BASE._move("Hammer Drop", "finisher_clip", "punch", "hook", 48, -96, 0.12, 0.08, 0.36, 1.75, 1.7, 24)
			# Button 2 is his rear hook (LOOK); 2,2 and 2,1 follow it.
			m.rp = BASE._move("Flash elbow", "strike_elbow", "punch", "hook", 40, -92, 0.08, 0.06, 0.24, 1.3, 0.9, 20)
			m.elbow_upper = BASE._move("Elbow uppercut", "strike_elbow_upper", "punch", "hook", 42, -96, 0.10, 0.07, 0.32, 1.6, 1.4, 16)
			m.elbow_upper.hitstun = 0.5
			m.body_elbow = BASE._move("Liver elbow", "strike_body_elbow", "punch", "hook", 45, -80, 0.12, 0.08, 0.34, 1.7, 1.5, 22)
			m.body_elbow.hitstun = 0.45
			m.rp.next_rp = "elbow_upper"      # 2,2
			m.rp.next_light = "body_elbow"    # 2,1
			m.cross.next_rp = "elbow_upper"   # 1,2,2 and 1,1,2
			# His MMA kicks: 4 is a high kick, 4,4 adds the roundhouse,
			# 3,3,4 ends on a side kick, back+3 is a low kick, and the
			# breaker command is his flying knee.
			m.rk = BASE._move("High kick", "strike_high_kick", "kick", "kick", 66, -84, 0.13, 0.08, 0.27, 1.2, 1.1, 10)
			m.rk.hitstun = 0.32
			m.roundhouse = BASE._move("Roundhouse kick", "strike_roundhouse", "kick", "kick", 68, -76, 0.13, 0.08, 0.28, 1.3, 1.3, 10)
			m.roundhouse.hitstun = 0.4
			m.side_kick = BASE._move("Side kick", "strike_side_kick", "kick", "kick", 72, -66, 0.12, 0.08, 0.28, 1.35, 1.6, 12)
			m.side_kick.hitstun = 0.4
			m.back_heavy = BASE._move("Low kick", "strike_low_kick", "kick", "kick", 62, -28, 0.11, 0.07, 0.24, 1.1, 0.8, 8)
			m.forward_heavy = BASE._move("Front snap kick", "front_kick", "kick", "kick", 66, -60, 0.11, 0.07, 0.24, 1.1, 1.2, 10)
			m.forward_heavy.hitstun = 0.32
			m.breaker = BASE._move("Flying knee", "strike_flying_knee", "kick", "kick", 60, -80, 0.2, 0.09, 0.4, 1.8, 1.7, 36)
			m.rk.next_rk = "roundhouse"             # 4,4
			m.kick.next_heavy = "forward_heavy"      # 3,3
			m.forward_heavy.next_rk = "side_kick"    # 3,3,4
		"sab":
			m.jab.name = "Iron check"
			m.hook.name = "Anvil hook"
			m.forward_heavy = BASE._move("Iron front kick", "front_kick", "kick", "kick", 66, -60, 0.12, 0.07, 0.26, 1.2, 1.3, 10)
			m.breaker = BASE._move("Iron uppercut", "uppercut", "punch", "hook", 42, -96, 0.2, 0.08, 0.4, 1.8, 1.6, 16)
			m.drive.name = "Battering ram"
			m.drive.pose = "overhand"
			# His spinning back-elbow uppercut (LOOK) ends the 1,1,1,3 string.
			m.combo_finish = BASE._move("Anvil Drop", "finisher_clip", "punch", "hook", 50, -92, 0.16, 0.09, 0.42, 1.9, 1.9, 18)
		"bib":
			m.jab.name = "Needle check"
			m.cross.name = "Rapid straight"
			m.kick.name = "Running arc"
			m.drive = BASE._move("Rush kick", "side_kick", "kick", "kick", 68, -65, 0.17, 0.07, 0.30, 1.1, 1.0, 43)
			m.breaker.name = "Relay wheel"
			m.breaker.pose = "spin"
			# Signature four-hit combo: three quick punches, then heavy for a
			# leaping kick.
			m.combo_finish = BASE._move("Endless Rush", "finisher_clip", "kick", "kick", 74, -84, 0.13, 0.09, 0.34, 1.7, 1.8, 26)
			m.combo_finish.hitstun = 0.55
			# Bibek, the boxer who kicks. 1,1,1 is jab, cross, lead hook and
			# 1,1,1,3 ends on his high kick. 2 is the rear hook: 2,2 a lead
			# uppercut, 1,2,2 a rear uppercut that lifts, 2,4 a roundhouse.
			# 4 is a high kick, 4,4 the roundhouse; 3,3,4 ends on a side kick;
			# back+3 is a low kick; the drive is a rushing one-two.
			m.jab.name = "Needle jab"
			m.cross.name = "Rapid cross"
			m.hook.name = "Relay lead hook"
			m.rp = BASE._move("Relay rear hook", "strike_rear_hook", "punch", "hook", 42, -76, 0.11, 0.07, 0.26, 1.4, 1.2, 14)
			m.rp.hitstun = 0.32
			m.knee = BASE._move("Relay uppercut", "strike_lead_uppercut", "punch", "hook", 40, -96, 0.11, 0.07, 0.28, 1.4, 1.2, 14)
			m.knee.hitstun = 0.36
			m.rising = BASE._move("Rising uppercut", "strike_rear_uppercut", "punch", "hook", 42, -98, 0.13, 0.08, 0.32, 1.7, 1.5, 18)
			m.rising.hitstun = 0.5
			m.rk = BASE._move("Relay high kick", "strike_high_kick", "kick", "kick", 68, -86, 0.13, 0.08, 0.27, 1.3, 1.2, 10)
			m.rk.hitstun = 0.34
			m.roundhouse = BASE._move("Relay roundhouse", "strike_roundhouse", "kick", "kick", 70, -78, 0.14, 0.08, 0.28, 1.45, 1.5, 12)
			m.roundhouse.hitstun = 0.42
			m.side_kick = BASE._move("Relay side kick", "strike_side_kick", "kick", "kick", 74, -66, 0.12, 0.08, 0.28, 1.4, 1.7, 12)
			m.side_kick.hitstun = 0.42
			m.back_heavy = BASE._move("Low kick", "strike_low_kick", "kick", "kick", 62, -28, 0.11, 0.07, 0.22, 1.1, 0.8, 8)
			m.drive = BASE._move("Rush one-two", "strike_one_two", "punch", "punch", 66, -74, 0.17, 0.09, 0.34, 1.6, 1.7, 46)
			m.rp.next_rp = "knee"                  # 2,2
			m.rp.next_rk = "roundhouse"            # 2,4
			m.cross.next_rp = "rising"             # 1,2,2 / 1,1,2
			m.rk.next_rk = "roundhouse"            # 4,4
			m.forward_heavy.next_rk = "side_kick"  # 3,3,4
		"abhi":
			m.cross.name = "Thunder straight"
			m.hook.name = "Mic drop"
			m.drive.name = "Loud thunder"
			m.drive.pose = "overhand"
			m.back_heavy = BASE._move("Big talk / recover 24 stamina", "taunt", "punch", "punch", 0, -88, 0.22, 0.02, 0.66, 0, 0)
			m.back_heavy.utility = "taunt"
			m.combo_finish = BASE._move("Thunderclap", "finisher_clip", "punch", "hook", 55, -92, 0.14, 0.09, 0.40, 1.8, 1.8, 22)
			# Tekken buttons: 2 is a short hook into the jab-elbow, 4 a lead
			# front kick into the rear front kick; the sweeps go low.
			m.rp = BASE._move("Short hook", "strike_short_hook", "punch", "hook", 46, -92, 0.09, 0.06, 0.24, 1.2, 0.9, 18)
			m.elbow = BASE._move("Jab elbow", "strike_jab_elbow", "punch", "hook", 42, -92, 0.12, 0.07, 0.30, 1.5, 1.2, 18)
			m.elbow.hitstun = 0.4
			m.rp.next_rp = "elbow"       # 2,2
			m.cross.next_rp = "elbow"    # 1,2,2
			m.rk = BASE._move("Lead front kick", "strike_lead_front", "kick", "kick", 68, -62, 0.14, 0.08, 0.30, 1.2, 1.3, 14)
			m.rk.hitstun = 0.34
			m.rear_front = BASE._move("Rear front kick", "strike_rear_front", "kick", "kick", 70, -66, 0.14, 0.08, 0.32, 1.45, 1.5, 20)
			m.rear_front.hitstun = 0.42
			m.rk.next_rk = "rear_front"  # 4,4
			m.forward_heavy = BASE._move("Front leg sweep", "strike_front_sweep", "kick", "kick", 60, -26, 0.12, 0.08, 0.30, 1.0, 0.8, 12)
			m.forward_heavy.hitstun = 0.45
			m.breaker = BASE._move("Back leg sweep", "strike_back_sweep", "kick", "kick", 66, -24, 0.15, 0.09, 0.36, 1.3, 1.0, 16)
			m.breaker.hitstun = 0.5
		"sup":
			m.jab.name = "Swaying palm"
			m.kick = BASE._move("Low spiral", "sweep", "kick", "kick", 62, -28, 0.17, 0.08, 0.30, 0.95, 0.8)
			m.drive = BASE._move("Cartwheel strike", "cartwheel", "kick", "kick", 65, -70, 0.24, 0.10, 0.39, 1.4, 1.25, 30)
			m.breaker.name = "Spiral wheel"
			m.breaker.pose = "spin"
			m.back_heavy = BASE._move("Slip away / retreat feint", "feint", "punch", "punch", 0, -88, 0.18, 0.02, 0.20, 0, 0, -45)
			m.back_heavy.utility = "feint"
			# Signature four-hit combo: swaying palm, straight, hook, then
			# heavy for his high spiral kick.
			m.combo_finish = BASE._move("Spiral Storm", "spin", "kick", "kick", 74, -70, 0.15, 0.09, 0.40, 1.75, 1.8, 24)
			m.combo_finish.hitstun = 0.55
		"anant":
			m.jab.name = "First word"
			m.cross.name = "Sovereign straight"
			m.hook.name = "Royal backfist"
			m.hook.pose = "backfist"
			m.drive.name = "Final word"
			m.breaker.name = "Crown wheel"
			m.breaker.pose = "spin"
			m.back_heavy = BASE._move("Crown low kick", "strike_low_kick", "kick", "kick", 62, -28, 0.11, 0.07, 0.24, 1.1, 0.8, 8)
			# Tekken-style strings. 1,1,2 into the flying knee: jab, cross,
			# hook, then heavy for The Final Word.
			m.jab.name = "Snap jab"
			m.cross.name = "Straight cross"
			m.hook.name = "Rear hook"
			m.hook.pose = "hook"
			# The boss's finisher: heavier, live for longer, reaching further,
			# connecting readily (hit_detection_3d.gd) and filmed close
			# (arena_3d.gd _finisher_cinematic).
			m.combo_finish = BASE._move("The Final Word", "finisher_clip", "punch", "hook", 80, -88, 0.16, 0.18, 0.42, 2.9, 2.2, 34)
			m.combo_finish.finisher = true
			m.combo_finish.hitstun = 0.7
			m.combo_finish.hitstun = 0.6
			# 3,3,4 kick string: body kick, front kick, spinning back kick.
			m.kick.name = "Body kick"
			m.forward_heavy = BASE._move("Front kick", "front_kick", "kick", "kick", 66, -60, 0.11, 0.07, 0.24, 1.1, 1.2, 10)
			m.breaker = BASE._move("Spinning back kick", "spin", "kick", "kick", 72, -70, 0.16, 0.09, 0.36, 1.7, 1.8, 16)
			m.kick.next_heavy = "forward_heavy"
			m.forward_heavy.next_heavy = "breaker"
			m.forward_heavy.hitstun = 0.32
			# Launcher: the uppercut pops the rival up for a follow-up.
			m.drive = BASE._move("Rising uppercut", "uppercut", "punch", "hook", 45, -96, 0.13, 0.08, 0.34, 1.5, 1.4, 14)
			m.drive.hitstun = 0.5
			# His own kicks on buttons 2/4 strings.
			m.rk = BASE._move("Roundhouse kick", "strike_roundhouse", "kick", "kick", 68, -78, 0.13, 0.08, 0.27, 1.25, 1.2, 10)
			m.rk.hitstun = 0.32
			m.side_kick = BASE._move("Side kick", "strike_side_kick", "kick", "kick", 72, -66, 0.12, 0.08, 0.28, 1.35, 1.6, 12)
			m.side_kick.hitstun = 0.4
			m.snap_advance = BASE._move("Advancing snap kick", "strike_advancing_snap", "kick", "kick", 70, -62, 0.14, 0.08, 0.30, 1.4, 1.5, 30)
			m.snap_advance.hitstun = 0.4
			m.back_heavy = BASE._move("Low kick", "strike_low_kick", "kick", "kick", 62, -28, 0.11, 0.07, 0.24, 1.1, 0.8, 8)
			m.rk.next_rk = "side_kick"             # 4,4
			m.forward_heavy.next_rk = "side_kick"  # 3,3,4
			m.cross.next_rk = "snap_advance"       # 1,2,4
	# Original, character-specific strike routes. Finishers use separate slots
	# so learning an easy chain does not replace directional signature moves.
	var finishers := {
		"anug": ["Goal-line clearance", "front_kick", 64, -65, 0.12, 1.10, 1.35],
		"ish": ["Flash rising fist", "uppercut", 57, -94, 0.10, 1.35, 1.1],
		"sab": ["Anvil elbow", "elbow", 53, -85, 0.14, 1.45, 1.0],
		# His chain finisher plays his own side kick (pose "side_kick" fell
		# back to the roundhouse).
		"bib": ["Relay side kick", "strike_side_kick", 70, -66, 0.09, 1.15, 1.2],
		"abhi": ["Thunder overhand", "overhand", 61, -89, 0.15, 1.55, 1.4],
		"sup": ["Spiral heel", "spin", 69, -65, 0.13, 1.25, 1.3],
		"anant": ["Crown knee", "knee", 53, -70, 0.12, 1.35, 1.2]
	}
	var f: Array = finishers.get(id, finishers.anug)
	var kind := "punch" if id in ["ish", "sab", "abhi"] else "kick"
	m.chain_finish = BASE._move(f[0], f[1], kind, "hook" if kind == "punch" else "kick", f[2], f[3], f[4], 0.07, 0.33, f[5], f[6], 18)
	m.chain_bridge = m.cross.duplicate(true)
	m.chain_bridge.name = {"anug":"Keeper palm", "ish":"Flash body shot", "sab":"Iron body hook", "bib":"Relay backfist", "abhi":"Thunder body shot", "sup":"Spiral palm", "anant":"Crown backfist"}.get(id, "Follow-up palm")
	m.chain_bridge.pose = "body_hook" if id in ["ish", "sab", "abhi"] else "backfist"
	m.chain_bridge.startup = 0.09
	m.chain_bridge.reach = 65.0
	m.chain_bridge.lunge = 16.0
	m.chain_bridge.next_light = ""
	m.chain_bridge.next_heavy = "chain_finish"
	m.chain_bridge.special_cancel = false
	m.chain_bridge.hitstun = 0.30
	m.kick.next_light = "chain_bridge"
	m.kick.hitstun = 0.30
	m.kick.push = 0.25
	m.cross.hitstun = 0.30
	m.cross.next_heavy = "chain_finish"
	# Every fighter's signature combo: three punches, then heavy.
	if m.has("combo_finish"):
		m.combo_finish.hitstun = maxf(float(m.combo_finish.get("hitstun", 0.25)), 0.5)
		m.hook.next_heavy = "combo_finish"
	# Tekken's buttons 2 and 4 (right punch, right kick) for everyone, with
	# the classic strings 1,2 / 1,2,4 / 3,4. A fighter's own "rp" (set above)
	# replaces the plain straight on 2.
	if not m.has("rp"):
		m.rp = m.cross.duplicate(true)
		m.rp.name = "Right straight"
		m.rp.next_light = "hook"
	# Fighters with their own spinning kick throw it; the rest a high front kick.
	var own_spin: bool = id in ["anug", "bib", "sup", "anant"]
	if not m.has("rk"):
		m.rk = BASE._move("Right roundhouse" if own_spin else "Right high kick", "spin" if own_spin else "front_kick", "kick", "kick", 66, -78, 0.13, 0.08, 0.27, 1.2, 1.2, 10)
		m.rk.hitstun = 0.32
	m.jab.next_rp = "cross"
	if not m.cross.has("next_rp"):
		m.cross.next_rp = ""
	for key in ["cross", "rp", "kick"]:
		if str(m[key].get("next_rk", "")) == "":
			m[key].next_rk = "rk"
	# Every character has a short-range throw, with different commitment/payoff.
	var throws := {
		"anug": ["Keeper catch", "clinch_shove", 0.24, 1.15, 1.25],
		"ish": ["Flash shoulder toss", "shoulder_throw", 0.22, 1.10, 1.05],
		"sab": ["Iron hip toss", "hip_throw", 0.28, 1.65, 1.45],
		"bib": ["Relay ankle reap", "trip_throw", 0.23, 1.00, 0.9],
		"abhi": ["Thunder clinch", "clinch_shove", 0.30, 1.50, 1.5],
		"sup": ["Spiral reap", "trip_throw", 0.25, 1.20, 1.1],
		"anant": ["Crown shoulder toss", "shoulder_throw", 0.27, 1.40, 1.3]
	}
	var g: Array = throws.get(id, throws.anug)
	m.grapple = BASE._move(g[0], g[1], "grapple", "hook", 32, -72, g[2], 0.07, 0.42, g[3], g[4], 6)
	m.grapple.hitstun = 0.48
	if id in ["ish", "anant", "abhi"]:
		# Their double-leg takedown clip.
		m.grapple.name = {"ish": "Flash takedown", "anant": "Crown takedown", "abhi": "Thunder takedown"}[id]
		m.grapple.pose = "grapple"
	if id in ["ish", "anant"]:
		# Mounted after the takedown, punch rains up to three blows down.
		m.grapple.ground_pound = true
	# From the crouch: punch rises into an uppercut that meets a jump-in,
	# kick sweeps the legs (a low blow: only a crouching guard stops it,
	# and it puts the rival on the floor; whiffed or guarded it leaves the
	# sweeper down there, open).
	m.crouch_punch = BASE._move("Rising uppercut", "uppercut", "punch", "hook", 44, -96, 0.09, 0.08, 0.30, 1.3, 1.2, 6)
	m.crouch_punch.hitstun = 0.4
	var sweeps := {"anug": "Slide tackle", "ish": "Hammer sweep", "sab": "Iron sweep", "bib": "Relay sweep",
		"abhi": "Thunder sweep", "sup": "Spiral sweep", "anant": "Crown sweep"}
	m.sweep = BASE._move(sweeps.get(id, "Leg sweep"), "strike_sweep", "kick", "kick", 70, -10, 0.16, 0.10, 0.42, 1.1, 0.6, 6)
	m.sweep.blockstun = 0.18
	m.sweep.low = true
	m.sweep.knockdown = true
	m.sweep.crouch = true
	# In the air: punch is a diving fist, kick a flying kick (the pack's
	# jump punch and jump kick, fighter_models.gd AIR). Both are overheads: a crouching
	# guard can't stop them, the answer to a fighter sitting on the sweep.
	# They stay live into the landing; landing ends them (player.gd).
	# Reach and height are from the jumper's feet: in the air they reach
	# the rival's head and chest at the close range a jump-in ends at (the
	# bodies push apart as the jumper comes in), not the air beyond them.
	m.jump_punch = BASE._move("Diving fist", "strike_jump_punch", "punch", "hook", 36, -52, 0.10, 0.22, 0.20, 1.3, 1.1, 0)
	m.jump_kick = BASE._move("Flying kick", "strike_flying_kick", "kick", "kick", 42, -46, 0.10, 0.22, 0.20, 1.35, 1.4, 0)
	for air in [m.jump_punch, m.jump_kick]:
		air.air = true
		air.overhead = true
		air.hitstun = 0.42
		air.blockstun = 0.2
	# Signature moves on forward / back + buttons 2 and 4, each a different
	# answer: the lunge closes ground and drives the rival back, the overhead
	# comes down through a crouching guard, the knockdown puts the rival on
	# the floor, and the low kick slips under a standing guard. Their looks
	# are each fighter's own (LOOK).
	m.f_rp = BASE._move("Lunge", "cross", "punch", "punch", 70, -86, 0.15, 0.08, 0.36, 1.5, 2.2, 46)
	m.f_rp.hitstun = 0.42
	m.b_rp = BASE._move("Overhead", "overhand", "punch", "hook", 50, -92, 0.17, 0.07, 0.34, 1.35, 1.0, 14)
	m.b_rp.overhead = true
	m.b_rp.hitstun = 0.4
	m.f_rk = BASE._move("Knockdown", "kick", "kick", "kick", 66, -66, 0.19, 0.08, 0.42, 1.6, 1.4, 16)
	m.f_rk.knockdown = true
	# Live a little longer: a round low kick sweeps across the shins fast.
	m.b_rk = BASE._move("Low kick", "kick", "kick", "kick", 62, -26, 0.13, 0.11, 0.30, 1.0, 0.6, 6)
	m.b_rk.low = true
	m.b_rk.hitstun = 0.32
	# From the crouch, 2 and 4: a quick low jab and a low kick. Both slip under
	# a standing guard and keep the fighter down there; neither knocks down,
	# so they are the safe low pokes beside the sweep's big gamble.
	m.crouch_rp = BASE._move("Low jab", "jab", "punch", "punch", 56, -40, 0.07, 0.05, 0.20, 0.7, 0.3, 4)
	m.crouch_rk = BASE._move("Low kick", "kick", "kick", "kick", 62, -22, 0.12, 0.07, 0.28, 0.95, 0.6, 4)
	for low in [m.crouch_rp, m.crouch_rk]:
		low.low = true
		low.crouch = true
		low.hitstun = 0.28
		low.blockstun = 0.12
	m.jump_punch.clip = "KB_JumpPunch"
	# The air kick chambering and snapping out (the held kick pose alone
	# hung stiff in the air).
	m.jump_kick.clip = "KB_Jump_Loop2Kick"
	for slot in LOOK.get(id, {}):
		if m.has(slot):
			var look: Array = LOOK[id][slot]
			m[slot].name = look[0]
			m[slot].clip = look[1]
			if look.size() > 2:
				m[slot].height = float(look[2])
	# Every move reaches as far as its clip really does (clip_reach.gd): the
	# fist or foot's furthest reach ahead of the hips, plus the rival's body
	# in front of their hips and the short step a strike takes. Hitboxes, the
	# AI's spacing and the drawn blow then agree: elbows from close in, long
	# kicks from out.
	for key in m:
		var clip := str(m[key].get("clip", ""))
		if CLIP_REACH.REACH.has(clip) and not m[key].get("air", false):
			m[key].reach = (float(CLIP_REACH.REACH[clip]) + REACH_ALLOWANCE) * 64.0
		# Real timing: the wind-up lasts as long as the performer took from
		# guard to the blow, and the recovery a share of the real way back to
		# guard (the pacing below then applies each fighter's tempo). The clip
		# plays at its own speed and the blow lands on the very frame the
		# fist or foot arrives. A clip whose blow can't be read (an elbow
		# already forward at its first frame) keeps the slot's timing.
		if CLIP_REACH.IMPACT.has(clip) and not m[key].get("air", false):
			var impact: float = CLIP_REACH.IMPACT[clip]
			if impact >= MIN_READ_IMPACT:
				m[key].startup = clampf(impact, 0.08, MAX_REAL_STARTUP) / PACE_STARTUP
				var back: float = float(CLIP_REACH.LENGTH[clip]) - impact
				m[key].recovery = clampf(back * RECOVERY_SHARE, 0.16, 0.55) / PACE_RECOVERY
	# Stamina costs are assigned by move slot/kind here rather than per-move
	# above, so every fighter's moves stay priced consistently even though
	# their reach/damage/timing differ.
	for key in m:
		m[key].cost = 5.0 if key in ["jab", "cross", "hook", "chain_bridge", "rp"] else (18.0 if key in ["drive", "breaker"] else 11.0)
		if m[key].get("utility", "") == "taunt":
			m[key].cost = 0.0
		if m[key].kind == "grapple":
			m[key].cost = 20.0
		if key in ["drive", "breaker"]:
			m[key].hitstun = 0.34
	# No grabs or throws for now: every fighter fights with strikes only.
	for key in m.keys():
		if m[key].kind == "grapple":
			m.erase(key)
	var tempo: float = TEMPO.get(id, 1.0)
	for key in m:
		m[key].startup = float(m[key].startup) * PACE_STARTUP * tempo
		m[key].recovery = float(m[key].recovery) * PACE_RECOVERY * tempo
		# The blow stays live through the same share of the follow-through.
		m[key].active = float(m[key].active) * PACE_RECOVERY * tempo
		# Stun grows with the startups so the next blow still lands in it.
		m[key].hitstun = float(m[key].get("hitstun", 0.25)) * PACE_STARTUP * tempo
		m[key].blockstun = float(m[key].get("blockstun", 0.15)) * PACE_RECOVERY * tempo
	# With each strike on its real timing, the slowest follow-up of a string
	# winds up longer than a quick blow used to stun for: every landed blow
	# holds the rival long enough for any of the fighter's strikes to land
	# next, so a string links when it is timed, and only then.
	var slowest := 0.0
	for key in m:
		if m[key].has("clip") and not m[key].get("air", false) and key not in ["drive", "breaker"]:
			slowest = maxf(slowest, float(m[key].startup))
	for key in m:
		if m[key].kind != "grapple" and not m[key].get("knockdown", false):
			m[key].hitstun = maxf(float(m[key].hitstun), slowest + float(m[key].active) + LINK_SLACK)
	# Chains end in strikes, not unavoidable grabs or utility actions.
	return m
