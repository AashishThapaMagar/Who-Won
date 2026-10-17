extends RefCounted
## Per-fighter move tables for live (action.tres) matches: starts from the
## shared "action" style's generic six normals + two enders, then reskins
## names/poses and swaps in signature moves per character id. Player.gd
## reads these through available_moves() instead of move_catalog's
## style-generic tables whenever is_action_fight() is true.
const BASE := preload("res://scripts/move_catalog.gd")
## Fight pace: strikes wind up and recover like a real exchange instead of
## flickering. Stun grows with the startups so every combo still links.
const PACE_STARTUP := 1.5
const PACE_RECOVERY := 1.25

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
			# The lunging punch-to-elbow from his fight set ends the 1,1,1,3 string.
			m.combo_finish = BASE._move("Hammer Drop", "finisher_clip", "punch", "hook", 48, -96, 0.12, 0.08, 0.36, 1.75, 1.7, 24)
			# Button 2 is his elbow; its strings use his own clips.
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
			# His haymaker (fighter_models.gd sab borrow) ends the 1,1,1,3 string.
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
			# heavy for the capoeira flip kick.
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
			m.combo_finish = BASE._move("The Final Word", "finisher_clip", "punch", "hook", 70, -92, 0.16, 0.10, 0.42, 2.0, 1.9, 30)
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
			# His own kicks on buttons 2/4 strings (clips from his MMA set).
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
		"abhi": "Thunder sweep", "sup": "Spiral sweep", "anant": "Rasteira"}
	m.sweep = BASE._move(sweeps.get(id, "Leg sweep"), "strike_sweep", "kick", "kick", 70, -10, 0.16, 0.10, 0.42, 1.1, 0.6, 6)
	m.sweep.blockstun = 0.18
	m.sweep.low = true
	m.sweep.knockdown = true
	m.sweep.crouch = true
	# In the air: punch is a diving fist, kick a flying kick (Meshy's
	# Jumping Punch and Flying Fist Kick). Both are overheads: a crouching
	# guard can't stop them, the answer to a fighter sitting on the sweep.
	# They stay live into the landing; landing ends them (player.gd).
	m.jump_punch = BASE._move("Diving fist", "strike_jump_punch", "punch", "hook", 50, -96, 0.10, 0.22, 0.20, 1.3, 1.1, 0)
	m.jump_kick = BASE._move("Flying kick", "strike_flying_kick", "kick", "kick", 66, -92, 0.10, 0.22, 0.20, 1.35, 1.4, 0)
	for air in [m.jump_punch, m.jump_kick]:
		air.air = true
		air.overhead = true
		air.hitstun = 0.42
		air.blockstun = 0.2
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
	for key in m:
		m[key].startup = float(m[key].startup) * PACE_STARTUP
		m[key].recovery = float(m[key].recovery) * PACE_RECOVERY
		# The blow stays live through the same share of the follow-through.
		m[key].active = float(m[key].active) * PACE_RECOVERY
		# Stun grows with the startups so the next blow still lands in it.
		m[key].hitstun = float(m[key].get("hitstun", 0.25)) * PACE_STARTUP
		m[key].blockstun = float(m[key].get("blockstun", 0.15)) * PACE_RECOVERY
	# Chains end in strikes, not unavoidable grabs or utility actions.
	return m
