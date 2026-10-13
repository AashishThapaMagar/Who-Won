extends SceneTree
## Bakes Story Mode's composed pictures ("plates") to images in
## assets/story/<fighter>/plates/<beat>_<line>.jpg (1200x900, what ships in
## the game) and, full size, art/story_plates/<fighter>/<beat>_<line>.png
## (the original to paint over; art/ is outside the game), which the storybook
## shows instead of drawing the moment live. For each plate the story is
## played up to its line (so the cast stands where the story put them and
## strikes the line's pose), then the plate's own camera, light and mood
## are set, the scene is rendered large in ink and flat washes
## (storybook_look.gd) and finished as a watercolour on paper
## (shaders/storybook_plate.gdshader).
##
## The finished images are ordinary pictures: they can be opened in Krita or
## Procreate and painted over by hand, and the book shows whatever is there.
##
##   godot --path . --resolution 1280x720 -s res://tools/bake_story_plates.gd [-- <plate key or fighter id> ...]

const LOOK := preload("res://scripts/storybook_look.gd")
const PLATE_SHADER := preload("res://shaders/storybook_plate.gdshader")
const MITHILA_SHADER := preload("res://shaders/storybook_mithila.gdshader")
## The finish: "watercolour", "mithila" (the whole picture repainted in
## Mithila colours and patterns) or "mithila_frame" (the watercolour inside
## a Mithila border on lokta paper) (PLATE_STYLE in the environment
## overrides it for a run; PLATE_OUT bakes into another folder instead).
const STYLE := "kurosawa"
const SIZE := Vector2i(1600, 1200)

const DAWN := Color(1.0, 0.86, 0.66)
const MORNING := Color(1.0, 0.95, 0.84)
const DUSK := Color(1.0, 0.78, 0.72)

## Each plate: who the story is about, which beat and line, and how the
## picture is composed. "eye"/"look" are world positions, "fov" the lens,
## "sun" [pitch, yaw, colour, energy], "ambient" [colour, energy], "mood"
## the paint's tint, "paper" places the newspaper prop, "sun_disc"
## [x, y, z, radius] paints the sun into the sky, "place" moves actors for
## the picture ({actor: [x, z, face_x, face_z]}), and "poses" sets actors
## to a gesture held at a moment: {actor: [clip, seconds into it]}.
## "chapter" is the tournament round (so the arena matches the game's),
## "stage" stages the picture in another set, "hide" leaves actors out,
## "letter" lays the sealed letter prop, and "page": "letter" draws the
## letter itself instead of a scene.
const COLD := Color(0.84, 0.88, 1.0)

## Sarvochcha's story: "THE MISSING MASTER".
const PLATES := [
	# ── Act I: the missing master ──
	{"key": "prologue_01", "fighter": "sup", "phase": "prologue", "line": 0,
		# Years ago: the boy kicks, the master guards, on the hilltop at morning.
		"eye": [-3.2, 1.1, 3.2], "look": [-0.8, 1.2, 0.0], "fov": 40,
		"sun": [-18, -37, Color("ffd9a0"), 1.4], "ambient": [Color("b8a8c0"), 0.6], "mood": MORNING,
		"place": {"player": [0.0, 0.6, -1.6, -1.2], "anant": [-1.6, -0.6, 1.6, 1.2]},
		"poses": {"player": ["kick", 1.0], "anant": ["block", 0.3]}},
	{"key": "prologue_02", "fighter": "sup", "phase": "prologue", "line": 1,
		# The master gone: the student alone by the empty dummy at dusk.
		"eye": [-3.6, 1.4, 2.6], "look": [-1.0, 1.0, -1.6], "fov": 46,
		"sun": [-6, 210, Color("ff9558"), 1.3], "ambient": [Color("8a7fa6"), 0.6], "mood": DUSK,
		"hide": ["anant"], "place": {"player": [-0.6, 0.4, -2.0, -2.8]},
		"poses": {"player": ["sob", 2.6]}},
	{"key": "prologue_03", "fighter": "sup", "phase": "prologue", "line": 2,
		# Years later: a man at his village door, looking out at the mountains.
		"eye": [1.3, 1.25, 3.0], "look": [-2.4, 2.1, -9.0], "fov": 44,
		"sun": [-8, 180, Color("ffb066"), 1.5], "ambient": [Color("9aa8c8"), 0.6], "mood": DAWN,
		"place": {"player": [-0.2, 0.6, -0.15, -1.0]},
		"poses": {"player": ["bow", 0.2]}},
	{"key": "prologue_05", "fighter": "sup", "phase": "prologue", "line": 4,
		# Making ready to leave: walking the road toward the bus shelter.
		"eye": [-1.6, 1.25, 2.8], "look": [5.5, 1.2, -0.6], "fov": 40,
		"sun": [-30, -40, Color("fff0d8"), 1.25], "ambient": [Color("b7c6d8"), 0.6], "mood": MORNING,
		"place": {"player": [2.0, 0.4, 1.0, -0.2]},
		"poses": {"player": ["walk", 0.5]}},
	{"key": "prologue_06", "fighter": "sup", "phase": "prologue", "line": 5,
		# A letter on the doorstep, seen from the ground; he looks down at it.
		"eye": [-3.8, 0.55, -2.0], "look": [-4.9, 0.35, -4.4], "fov": 52,
		"sun": [-25, -30, Color("fff0d8"), 1.25], "ambient": [Color("b7c6d8"), 0.6], "mood": MORNING,
		"place": {"player": [-5.0, -4.6, 0.3, 1.0]},
		"poses": {"player": ["bow", 2.4]},
		"letter": {"at": [-4.45, 0.03, -3.3], "turn": [0, 25, 0]}},
	{"key": "prologue_07", "fighter": "sup", "page": "letter"},
	{"key": "prologue_11", "fighter": "sup", "phase": "prologue", "line": 10,
		# He accepts: on the road, the Himalaya behind him, nodding to himself.
		"eye": [-2.4, 1.0, 2.2], "look": [0.0, 1.45, 0.3], "fov": 38,
		"sun": [-20, -60, Color("fff0d8"), 1.3], "ambient": [Color("b7c6d8"), 0.6], "mood": MORNING,
		"place": {"player": [0.0, 0.4, -1.0, 0.0]},
		"poses": {"player": ["agree", 2.6]}},
	{"key": "prologue_12", "fighter": "sup", "phase": "prologue", "line": 11,
		# Bowing to his home and his mother before he goes.
		"eye": [0.2, 1.3, 0.4], "look": [-4.8, 1.2, -5.4], "fov": 42,
		"sun": [-10, 30, Color("ffb066"), 1.4], "ambient": [Color("9aa8c8"), 0.6], "mood": DAWN,
		"place": {"player": [-3.6, -2.0, -2.4, -6.0]},
		"poses": {"player": ["bow", 2.9]}},
	# ── Act II: the fight between friends ──
	{"key": "sab_intro_01", "fighter": "sup", "phase": "sab_intro", "line": 0, "chapter": 4,
		# Two friends face each other across the arena.
		"eye": [0.0, 0.9, 4.4], "look": [0.0, 1.25, 0.0], "fov": 44, "mood": MORNING},
	{"key": "sab_intro_03", "fighter": "sup", "phase": "sab_intro", "line": 2, "chapter": 4,
		# Over Mahabali's shoulder: "do you think our master is still alive?"
		"eye": [2.3, 1.65, 1.2], "look": [-1.15, 1.5, 0.0], "fov": 30, "mood": MORNING,
		"poses": {"player": ["agree", 2.6]}},
	{"key": "sab_intro_06", "fighter": "sup", "phase": "sab_intro", "line": 5, "chapter": 4,
		# Neither can afford to lose: low between their raised guards.
		"eye": [0.0, 0.8, 2.7], "look": [0.0, 1.45, 0.0], "fov": 48, "mood": MORNING},
	{"key": "sab_victory_01", "fighter": "sup", "phase": "sab_victory", "line": 0, "chapter": 4,
		# Mahabali struggles to rise; Sarvochcha stands over him.
		"eye": [2.6, 0.6, 1.8], "look": [0.0, 0.8, 0.0], "fov": 40, "mood": MORNING,
		"poses": {"rival": ["injured", 0.5], "player": ["bow", 0.2]}},
	{"key": "sab_victory_03", "fighter": "sup", "phase": "sab_victory", "line": 2, "chapter": 4,
		# He walks on; his friend lies behind him.
		"eye": [2.8, 0.9, 1.6], "look": [-2.4, 1.0, -0.9], "fov": 40, "mood": MORNING,
		"place": {"player": [-2.6, -0.9, -1.0, -0.4]},
		"poses": {"rival": ["ko", 1.6], "player": ["walk", 0.5]}},
	# ── Act III: the final revelation ──
	{"key": "anant_intro_01", "fighter": "sup", "phase": "anant_intro", "line": 0, "chapter": 5,
		# The final opponent walks in; Sarvochcha's back in the foreground.
		"eye": [-2.8, 1.5, 1.3], "look": [1.8, 1.4, -0.5], "fov": 34, "mood": DUSK,
		"place": {"rival": [2.6, -0.6, -1.0, 0.2]},
		"poses": {"rival": ["walk", 0.4]}},
	{"key": "anant_intro_03", "fighter": "sup", "phase": "anant_intro", "line": 2, "chapter": 5,
		# "MASTER?!"
		"eye": [0.35, 1.6, 0.95], "look": [-1.15, 1.58, 0.0], "fov": 30, "mood": DUSK,
		"poses": {"player": ["angry", 0.9]}},
	{"key": "anant_intro_04", "fighter": "sup", "phase": "anant_intro", "line": 3, "chapter": 5,
		# Ananta says nothing and raises his guard: low, looking up at him.
		"eye": [-0.1, 0.85, 1.15], "look": [1.15, 1.62, 0.0], "fov": 34, "mood": DUSK},
	{"key": "finale_01", "fighter": "sup", "phase": "finale", "line": 0,
		# The master sits defeated; his student stands over him.
		"eye": [-2.2, 1.4, 2.4], "look": [0.6, 0.7, 0.0], "fov": 40, "mood": DUSK,
		"place": {"player": [-0.6, 0.2, 1.0, 0.0], "anant": [0.9, -0.1, -1.0, 0.0]},
		"poses": {"anant": ["getup", 1.2], "player": ["bow", 0.2]}},
	{"key": "finale_03", "fighter": "sup", "phase": "finale", "line": 2,
		# Memory: the master beaten in an international final, alone on the canvas.
		"eye": [2.2, 2.6, 2.6], "look": [0.0, 0.3, 0.0], "fov": 40, "mood": COLD,
		"hide": ["player"], "place": {"anant": [0.0, 0.0, 1.0, 0.3]},
		"poses": {"anant": ["ko", 2.5]}},
	{"key": "finale_05", "fighter": "sup", "phase": "finale", "line": 4, "stage": "ananta_ground",
		# Memory: hiding in a remote village, sitting alone on a hilltop.
		"eye": [3.4, 1.2, 3.4], "look": [-0.7, 1.0, -2.0], "fov": 42,
		"sun": [-6, 210, Color("ff9558"), 1.3], "ambient": [Color("8a7fa6"), 0.6], "mood": DUSK,
		"hide": ["player", "rival"], "place": {"anant": [1.4, -0.9, -1.0, -0.6]},
		"poses": {"anant": ["getup", 1.2]}},
	{"key": "finale_10", "fighter": "sup", "phase": "finale", "line": 9,
		# "Everything you taught me has stayed with me": the student bows.
		"eye": [0.1, 1.3, 2.6], "look": [0.0, 1.1, 0.0], "fov": 40, "mood": DUSK,
		"place": {"player": [-0.7, 0.2, 1.0, 0.0], "anant": [0.8, 0.0, -1.0, 0.0]},
		"poses": {"player": ["bow", 2.9], "anant": ["taunt", 1.0]}},
	{"key": "finale_15", "fighter": "sup", "phase": "finale", "line": 14,
		# Teacher and disciple, side by side, looking out together.
		"eye": [0.0, 1.15, 3.6], "look": [0.0, 1.7, -8.0], "fov": 44, "mood": DUSK,
		"place": {"player": [-0.45, 0.4, 0.0, -1.0], "anant": [0.45, 0.4, 0.0, -1.0]},
		"poses": {"player": ["bow", 0.2], "anant": ["taunt", 1.0]}},
	# ── Agasthya: "The Fastest Hands" (story shots unless composed) ──
	{"key": "prologue_01", "fighter": "ish", "phase": "prologue", "line": 0,
		"eye": [-0.4, 1.5, 3.4], "look": [-4.4, 1.3, -1.8], "fov": 40},
	{"key": "prologue_04", "fighter": "ish", "phase": "prologue", "line": 3,
		# His face, the lamplit stall behind him.
		"eye": [-1.4, 1.6, 0.9], "look": [-3.6, 1.55, -1.0], "fov": 30},
	{"key": "prologue_07", "fighter": "ish", "page": "letter"},
	{"key": "prologue_08", "fighter": "ish", "phase": "prologue", "line": 7},
	{"key": "anant_intro_02", "fighter": "ish", "phase": "anant_intro", "line": 1, "chapter": 5, "mood": DUSK,
		# Over Agasthya's shoulder onto his Guruji.
		"eye": [-1.75, 1.62, 1.0], "look": [1.15, 1.5, 0.0], "fov": 32},
	{"key": "finale_01", "fighter": "ish", "phase": "finale", "line": 0, "mood": DUSK},
	{"key": "finale_03", "fighter": "ish", "phase": "finale", "line": 2, "mood": DUSK},
	# ── Vajraveer: "The Endless Rush" ──
	{"key": "prologue_01", "fighter": "bib", "phase": "prologue", "line": 0, "mood": DAWN,
		"eye": [-2.6, 1.3, 4.0], "look": [0.2, 1.5, -1.6], "fov": 40, "poses": {"player": ["kick", 0.7]}},
	{"key": "prologue_03", "fighter": "bib", "phase": "prologue", "line": 2, "mood": DAWN,
		# His face, the tank and the dawn range behind him.
		"eye": [0.9, 1.55, -1.6], "look": [0.0, 1.5, 0.6], "fov": 32},
	{"key": "prologue_06", "fighter": "bib", "page": "letter"},
	{"key": "prologue_07", "fighter": "bib", "phase": "prologue", "line": 6, "mood": DAWN},
	{"key": "anant_intro_02", "fighter": "bib", "phase": "anant_intro", "line": 1, "chapter": 5, "mood": DUSK,
		"eye": [-1.75, 1.62, 1.0], "look": [1.15, 1.5, 0.0], "fov": 32},
	{"key": "finale_01", "fighter": "bib", "phase": "finale", "line": 0, "mood": DUSK},
	{"key": "finale_04", "fighter": "bib", "phase": "finale", "line": 3, "mood": DUSK},
	# ── Mahabali: "The Lazy Giant" ──
	{"key": "prologue_01", "fighter": "sab", "phase": "prologue", "line": 0, "mood": MORNING,
		"eye": [6.8, 1.4, 4.6], "look": [2.8, 0.9, -1.4], "fov": 36},
	{"key": "prologue_03", "fighter": "sab", "phase": "prologue", "line": 2, "mood": MORNING,
		"eye": [5.0, 1.45, 2.2], "look": [2.4, 1.25, -0.9], "fov": 32, "poses": {"player": ["taunt", 0.8]}},
	{"key": "prologue_06", "fighter": "sab", "page": "letter"},
	{"key": "prologue_08", "fighter": "sab", "phase": "prologue", "line": 7, "mood": MORNING,
		"eye": [0.6, 1.3, 2.6], "look": [2.4, 1.4, -0.9], "fov": 34},
	{"key": "sup_intro_01", "fighter": "sab", "phase": "sup_intro", "line": 0, "chapter": 4, "mood": MORNING},
	{"key": "anant_intro_02", "fighter": "sab", "phase": "anant_intro", "line": 1, "chapter": 5, "mood": DUSK,
		"eye": [-1.75, 1.62, 1.0], "look": [1.15, 1.5, 0.0], "fov": 32},
	{"key": "finale_01", "fighter": "sab", "phase": "finale", "line": 0, "mood": DUSK},
	{"key": "finale_04", "fighter": "sab", "phase": "finale", "line": 3, "mood": DUSK},
	# ── Ananta: "The Final Word" ──
	{"key": "prologue_01", "fighter": "anant", "phase": "prologue", "line": 0, "mood": COLD,
		# Low, looking up past the ropes into the dark stadium.
		"eye": [-2.6, 0.7, 2.9], "look": [0.0, 1.5, 0.0], "fov": 40},
	{"key": "prologue_03", "fighter": "anant", "phase": "prologue", "line": 2, "mood": COLD,
		# Down on one knee in the ring, the dark crowd behind him.
		"eye": [2.3, 0.75, 2.1], "look": [0.0, 0.75, 0.0], "fov": 38, "poses": {"player": ["getup", 1.2]}},
	{"key": "prologue_05", "fighter": "anant", "phase": "prologue", "line": 4, "mood": DUSK,
		"eye": [-1.0, 1.6, 4.0], "look": [-5.0, 1.3, -3.6], "fov": 40},
	{"key": "prologue_08", "fighter": "anant", "page": "letter"},
	{"key": "bib_intro_02", "fighter": "anant", "phase": "bib_intro", "line": 1, "chapter": 0},
	{"key": "sup_intro_02", "fighter": "anant", "phase": "sup_intro", "line": 1, "chapter": 5, "mood": DUSK,
		"eye": [1.75, 1.62, 1.0], "look": [-1.15, 1.5, 0.0], "fov": 32},
	{"key": "finale_01", "fighter": "anant", "phase": "finale", "line": 0, "mood": DUSK},
	{"key": "finale_06", "fighter": "anant", "phase": "finale", "line": 5, "mood": DUSK},
	# ── Anug: the letter and his Guruji ──
	{"key": "prologue_09", "fighter": "anug", "page": "letter"},
	{"key": "anant_intro_02", "fighter": "anug", "phase": "anant_intro", "line": 1, "chapter": 5, "mood": DUSK,
		"eye": [-1.75, 1.62, 1.0], "look": [1.15, 1.5, 0.0], "fov": 32},
	# ── Kri: "The Unknown" ──
	{"key": "prologue_01", "fighter": "abhi", "phase": "prologue", "line": 0,
		"eye": [-4.4, 1.3, 2.8], "look": [-1.2, 1.6, -1.4], "fov": 40, "poses": {"player": ["jab", 0.4]}},
	{"key": "prologue_03", "fighter": "abhi", "page": "letter"},
	{"key": "prologue_06", "fighter": "abhi", "phase": "prologue", "line": 5,
		"poses": {"player": ["taunt", 0.8]}},
	{"key": "anant_intro_03", "fighter": "abhi", "phase": "anant_intro", "line": 2, "chapter": 5, "mood": DUSK,
		"eye": [-1.75, 1.62, 1.0], "look": [1.15, 1.5, 0.0], "fov": 32},
	{"key": "finale_02", "fighter": "abhi", "phase": "finale", "line": 1, "mood": DUSK},
	{"key": "finale_07", "fighter": "abhi", "phase": "finale", "line": 6, "mood": DUSK},
	# Hand framings where the automatic ones failed.
	{"key": "prologue_02", "fighter": "anant", "phase": "prologue", "line": 1, "mood": COLD,
		# Winning: in the ring under the lights, seen from the ropes.
		"eye": [-3.6, 1.4, 0.3], "look": [0.0, 1.2, 0.0], "fov": 38, "poses": {"player": ["victory", 1.6]}},
	{"key": "finale_08", "fighter": "abhi", "phase": "finale", "line": 7, "mood": DUSK,
		# "Lock in": Kri's face as he says it, his master beside him.
		"eye": [1.6, 1.5, 1.4], "look": [0.9, 1.45, -0.7], "fov": 32},
	# ── Kurosawa trials (bake with PLATE_STYLE=kurosawa) ──
	{"key": "k_ring", "fighter": "anant", "phase": "prologue", "line": 2, "sky": "arena", "haze": 0.012, "weather": "mist", "weather_amount": 0.5,
		"sun_at": [0.6, 0.12, 0.06], "horizon_y": 0.25,
		# Low on the canvas, looking up: he stands alone, doubled over, in
		# the white haze of the spotlights.
		"eye": [2.4, 0.3, 1.6], "look": [0.0, 1.5, 0.0], "fov": 40, "poses": {"player": ["hit_heavy", 0.35]}},
	{"key": "k_ridge", "fighter": "sup", "phase": "finale", "line": 14, "sky": "dusk", "haze": 0.02, "weather": "dust",
		"sun_at": [0.5, 0.6, 0.06], "horizon_y": 0.68,
		"eye": [0.0, 0.45, 4.6], "look": [0.0, 1.6, -8.0], "fov": 40,
		"place": {"player": [-0.5, 0.2, 0.0, -1.0], "anant": [0.5, 0.2, 0.0, -1.0]},
		"poses": {"player": ["bow", 0.2], "anant": ["taunt", 1.0]}},
	{"key": "k_lamp", "fighter": "abhi", "phase": "prologue", "line": 0, "sky": "night", "haze": 0.015, "weather": "rain",
		"sun_at": [0.3, 0.24, 0.03], "horizon_y": 0.72,
		# Low and close: the lone figure punching under the lamp.
		"eye": [2.6, 0.3, 0.9], "look": [-8.0, 1.6, 0.4], "fov": 32,
		"place": {"player": [-0.4, 0.5, -1.0, 0.0]}, "poses": {"player": ["jab", 0.4]}},
]

const S_OUT := "res://assets/story/%s/plates/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var only := OS.get_cmdline_user_args()
	# "--fill <fighter> ...": bake the moments a fighter's book still lacks,
	# up to BOOK_SIZE pictures, in the story's own shots.
	# "--only fighter:key ...": re-bake single pages, composed or automatic.
	if "--only" in only:
		for item in only:
			if not ":" in item:
				continue
			var fighter: String = item.get_slice(":", 0)
			var key: String = item.get_slice(":", 1)
			var found := false
			for plate: Dictionary in PLATES:
				if plate.fighter == fighter and plate.key == key:
					await _bake(plate)
					found = true
			if not found:
				for plate in _auto_plates(fighter, true):
					if plate.key == key:
						await _bake(plate)
		quit()
		return
	if "--fill" in only:
		for id in only:
			if id != "--fill":
				for plate in _auto_plates(id):
					await _bake(plate)
		quit()
		return
	for plate: Dictionary in PLATES:
		# Arguments pick plates by key or by fighter id (e.g. -- ish).
		if not only.is_empty() and not only.has(plate.key) and not only.has(plate.fighter):
			continue
		# Style trials (k_*) bake only when named.
		if plate.key.begins_with("k_") and not only.has(plate.key):
			continue
		await _bake(plate)
	quit()

## Pictures per storybook.
const BOOK_SIZE := 21

## The moments of a fighter's story still without a picture: every
## prologue and finale line, then the first and last line of each rival's
## chapter intro and the first of its victory, in that order, until the
## book has BOOK_SIZE pictures (composed plates in PLATES count first).
func _auto_plates(fighter: String, everything := false) -> Array:
	var route: Dictionary = preload("res://scripts/story_script.gd").ROUTES.get(fighter, {})
	var have := {}
	for plate: Dictionary in PLATES:
		if plate.fighter == fighter and not str(plate.key).begins_with("k_"):
			have[plate.key] = true
	var wanted: Array = []
	var add := func(phase: String, line: int, chapter: int, lines: Array) -> void:
		if line < 0 or line >= lines.size():
			return
		var key := "%s_%02d" % [phase, line + 1]
		if have.has(key):
			return
		have[key] = true
		var mood: Color = DUSK if phase.begins_with("anant") or phase == "finale" else MORNING
		# Each page frames its moment differently (see _vary_camera).
		wanted.append({"key": key, "fighter": fighter, "phase": phase, "line": line, "chapter": chapter, "mood": mood, "vary": wanted.size()})
	var prologue: Array = route.get("prologue", [])
	for i in prologue.size():
		add.call("prologue", i, 0, prologue)
	var finale: Array = route.get("finale", [])
	for i in finale.size():
		add.call("finale", i, 0, finale)
	var ladder: Array = route.get("ladder", [])
	var chapters: Dictionary = route.get("chapters", {})
	for pass_index in 3:
		for c in ladder.size():
			var beats: Dictionary = chapters.get(ladder[c], {})
			var intro: Array = beats.get("intro", [])
			var victory: Array = beats.get("victory", [])
			match pass_index:
				0: add.call(ladder[c] + "_intro", 0, c, intro)
				1: add.call(ladder[c] + "_intro", intro.size() - 1, c, intro)
				2: add.call(ladder[c] + "_victory", 0, c, victory)
	if everything:
		return wanted
	var room := maxi(0, BOOK_SIZE - (have.size() - wanted.size()))
	return wanted.slice(0, room)

func _bake(plate: Dictionary) -> void:
	var setup: Node = root.get_node("MatchSetup")
	var director: Node = root.get_node("StoryDirector")
	var roster := preload("res://scripts/fighter_roster.gd")
	var index := 0
	for i in roster.PROFILES.size():
		if roster.PROFILES[i].id == plate.fighter:
			index = i
	setup.story = true
	setup.selected_fighters.assign([index, 0])
	if plate.get("page", "") == "letter":
		var page := await _letter_page()
		var drawn := await _finish(page, plate, "frame_only")
		var out: String = OS.get_environment("PLATE_OUT") if OS.has_environment("PLATE_OUT") else S_OUT % plate.fighter
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
		_save_plate(drawn, out, plate)
		print("PLATE ", plate.key)
		return
	setup.arcade_index = int(plate.get("chapter", 0))
	director.start_run()
	var phase: String = plate.phase
	if phase.ends_with("_intro"):
		director.begin_intro(phase.trim_suffix("_intro"))
	elif phase.ends_with("_victory"):
		director.report_result(phase.trim_suffix("_victory"), true, false)
	elif phase == "finale":
		director.report_result("anant", true, true)
	change_scene_to_file("res://scenes/StoryDialogue.tscn")
	for i in 600:
		await process_frame
		if current_scene != null and current_scene.get("started") == true:
			break
	var d: Node = current_scene
	await create_timer(0.8).timeout
	if d.carding:
		d._end_card()
	# Play the beat up to the plate's line, so everyone ends up where the
	# story puts them (still storylines place walkers at once).
	while d.line_index < int(plate.line):
		await create_timer(0.3).timeout
		d._finish_typing()
		d._next_line()
		await create_timer(0.5 if not d.pending.is_valid() else 1.4)
	# Let the line's pose land and the picture freeze.
	for i in 80:
		await create_timer(0.1).timeout
		if d._frozen:
			break
	# The book draws its own quick picture on the freeze; let it finish
	# before taking over the view.
	await create_timer(0.5).timeout
	d.set_process(false)
	var viewport: SubViewport = d.viewport
	if plate.has("stage"):
		d._use_set(plate.stage, 0)
		await process_frame
		await process_frame
	var style: String = OS.get_environment("PLATE_STYLE") if OS.has_environment("PLATE_STYLE") else plate.get("style", STYLE)
	_compose(d, plate)
	viewport.size = SIZE
	if style == "kurosawa":
		plate = _kuro_defaults(d, plate)
		if not plate.get("keep_camera", false):
			_low_camera(d)
		_ink_world(viewport, plate)
		if not plate.get("keep_camera", false) and not str(d.get("set_name")) in ["street", "tea_stall", "gym"]:
			await _open_sky_angle(d, viewport)
	else:
		LOOK.apply(viewport, "mithila" if style == "mithila" else "wash")
	if style == "mithila":
		# Mithila paintings sit on bare paper: no sky, fog or film curve.
		for world: WorldEnvironment in viewport.find_children("*", "WorldEnvironment", true, false):
			var env := world.environment
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.93, 0.86, 0.72)
			env.fog_enabled = false
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 4:
		await RenderingServer.frame_post_draw
	var render := viewport.get_texture().get_image()
	var finished := await _finish(render, plate, style)
	var folder: String = OS.get_environment("PLATE_OUT") if OS.has_environment("PLATE_OUT") else S_OUT % plate.fighter
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_save_plate(finished, folder, plate)
	print("PLATE ", plate.key)

## The full-size original into art/story_plates/<fighter>/ and the game's
## lighter copy (1200x900 JPEG) into the plates folder.
func _save_plate(image: Image, folder: String, plate: Dictionary) -> void:
	var originals := "res://art/story_plates/%s/" % plate.fighter
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(originals))
	image.save_png(originals + plate.key + ".png")
	var copy := image.duplicate() as Image
	copy.resize(1200, 900, Image.INTERPOLATE_LANCZOS)
	copy.save_jpg(folder + plate.key + ".jpg", 0.88)

## The plate's camera, light and props.
func _compose(d: Node, plate: Dictionary) -> void:
	var camera: Camera3D = d.camera
	# Without "eye" the picture keeps the story's own shot for the line.
	if plate.has("eye"):
		var eye: Array = plate.eye
		var look: Array = plate.look
		camera.global_position = Vector3(eye[0], eye[1], eye[2])
		camera.look_at(Vector3(look[0], look[1], look[2]))
		camera.fov = float(plate.get("fov", 36))
	if plate.has("vary") and not plate.has("eye"):
		_vary_camera(d, int(plate.vary))
	var sun_spec: Array = plate.get("sun", [])
	for sun: DirectionalLight3D in d.viewport.find_children("*", "DirectionalLight3D", true, false):
		if sun_spec.size() == 4:
			sun.rotation_degrees = Vector3(sun_spec[0], sun_spec[1], 0)
			sun.light_color = sun_spec[2]
			sun.light_energy = sun_spec[3]
	var ambient: Array = plate.get("ambient", [])
	for world: WorldEnvironment in d.viewport.find_children("*", "WorldEnvironment", true, false):
		if ambient.size() == 2 and world.environment != null:
			world.environment.ambient_light_color = ambient[0]
			world.environment.ambient_light_energy = ambient[1]
	if plate.has("paper") and d.story_set != null and d.story_set.get("ball") != null:
		var paper: MeshInstance3D = d.story_set.ball
		var at: Array = plate.paper.at
		var turn: Array = plate.paper.turn
		paper.global_position = Vector3(at[0], at[1], at[2])
		paper.rotation_degrees = Vector3(turn[0], turn[1], turn[2])
		_print_newspaper(paper)
	# The village road's flat strip renders blown-out white in these
	# pictures; the earth under it reads as the path on its own.
	if d.story_set != null:
		for strip: MeshInstance3D in d.story_set.find_children("*", "MeshInstance3D", true, false):
			if strip.mesh is BoxMesh and strip.mesh.size.y < 0.05 and strip.mesh.size.x > 20.0:
				strip.visible = false
	if plate.has("sun_disc"):
		var spec: Array = plate.sun_disc
		var disc := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = spec[3]
		sphere.height = spec[3] * 2.0
		disc.mesh = sphere
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color("ffc074")
		disc.material_override = glow
		disc.set_meta("storybook", "keep")
		disc.position = Vector3(spec[0], spec[1], spec[2])
		d.viewport.add_child(disc)
	for key in plate.get("hide", []):
		if d.actors.has(key):
			d.actors[key].rig.visible = false
	if plate.has("letter"):
		_lay_letter(d, plate.letter)
	for key in plate.get("place", {}):
		if d.actors.has(key):
			var spot: Array = plate.place[key]
			var rig: Node3D = d.actors[key].rig
			rig.position = Vector3(spot[0], rig.position.y, spot[1])
			d._face(key, [spot[2], spot[3]])
	# Gestures held at a chosen moment: the clip is started and run forward
	# to that second, then held for the picture.
	for key in plate.get("poses", {}):
		if not d.actors.has(key):
			continue
		var spec: Array = plate.poses[key]
		var visual: Node = d.actors[key].fighter.get_node("Visual")
		var animated = visual.get("animated")
		if animated == null or animated.player == null:
			continue
		animated.pose_override = spec[0]
		animated.replay()
		animated.player.play()
		visual._process(0.016)
		var left := float(spec[1])
		while left > 0.0:
			visual._process(minf(left, 0.1))
			left -= 0.1
		animated.player.pause()

## A different framing for each automatic page, so neighbouring pictures
## of one scene don't repeat: the story's shot, a wide establishing view,
## a low heroic angle, an over-the-shoulder two-shot and a close portrait,
## all centred on whoever the line is about.
func _vary_camera(d: Node, index: int) -> void:
	var camera: Camera3D = d.camera
	var subject := Vector3.ZERO
	var count := 0
	for key in d.actors:
		var rig: Node3D = d.actors[key].rig
		if rig.visible:
			subject += rig.global_position
			count += 1
	if count == 0:
		return
	subject = subject / count + Vector3(0, 1.3, 0)
	var flat := camera.global_position - subject
	flat.y = 0.0
	if flat.length() < 0.1:
		flat = Vector3(0, 0, 3)
	var distance := flat.length()
	var dir := flat.normalized()
	var eye := camera.global_position
	match index % 5:
		1: # Wide: pulled back and a little higher, the place around them.
			eye = subject + dir.rotated(Vector3.UP, deg_to_rad(18)) * (distance * 1.9 + 2.0) + Vector3(0, 1.0, 0)
			camera.fov = 44
		2: # Low and heroic, from the other side.
			eye = subject + dir.rotated(Vector3.UP, deg_to_rad(-38)) * maxf(2.2, distance * 0.9) + Vector3(0, -0.5, 0)
			camera.fov = 40
		3: # Over the shoulder, swung well round.
			eye = subject + dir.rotated(Vector3.UP, deg_to_rad(62)) * (distance * 0.75) + Vector3(0, 0.25, 0)
			camera.fov = 34
		4: # Close portrait.
			eye = subject + dir.rotated(Vector3.UP, deg_to_rad(-15)) * maxf(1.4, distance * 0.55) + Vector3(0, 0.25, 0)
			camera.fov = 30
		_:
			return
	camera.global_position = eye
	camera.look_at(subject)

## Sky, weather and haze for a page that names none, from where it
## happens: the story set, or the tournament arena by its time of day.
const SET_MOODS := {
	"street": ["night", "rain", 0.02], "tea_stall": ["night", "rain", 0.02],
	"gym": ["night", "rain", 0.02], "rooftop": ["dawn", "clear", 0.012],
	"hill_road": ["dawn", "dust", 0.012], "village_tree": ["dawn", "dust", 0.012],
	"pitch": ["dusk", "dust", 0.012], "academy": ["night", "clear", 0.02],
	"ananta_ground": ["dusk", "dust", 0.012], "goth": ["dusk", "mist", 0.012],
	"final_ring": ["arena", "mist", 0.012],
}
const ARENA_MOODS := [
	["night", "rain", 0.015],   # Heritage Square
	["dawn", "mist", 0.012],    # Terai Plains
	["dawn", "dust", 0.012],    # Hill Village
	["dusk", "dust", 0.012],    # Gompa Courtyard
	["storm", "mist", 0.012],   # Himalayan Pass
	["dusk", "dust", 0.012],    # Dashain Ground
]

func _kuro_defaults(d: Node, plate: Dictionary) -> Dictionary:
	var out := plate.duplicate()
	var mood: Array = ARENA_MOODS[0]
	var set_name: String = str(d.get("set_name"))
	if SET_MOODS.has(set_name):
		mood = SET_MOODS[set_name]
	elif d.get("stage") != null:
		mood = ARENA_MOODS[clampi(int(d.stage.current_round), 0, ARENA_MOODS.size() - 1)]
	if not out.has("sky"):
		out["sky"] = mood[0]
	if not out.has("weather"):
		out["weather"] = mood[1]
		# A defeat always plays in the rain.
		if str(out.get("phase", "")).ends_with("_defeat"):
			out["weather"] = "rain"
	if not out.has("haze"):
		out["haze"] = mood[2]
	if not out.has("sun_at"):
		# A low sun or moon off to one side, never behind a head.
		var side := 0.3 if hash(str(out.key)) % 2 == 0 else 0.72
		out["sun_at"] = [side, 0.5, 0.05]
	return out

## Walks the low camera round the figures (six angles) and keeps the one
## that sees the most open sky through the middle of the frame, so no page
## is spent staring into a wall, a water tank or the back of a house.
func _open_sky_angle(d: Node, viewport: SubViewport) -> void:
	var camera: Camera3D = d.camera
	var subject := Vector3.ZERO
	var count := 0
	for key in d.actors:
		var rig: Node3D = d.actors[key].rig
		if rig.visible:
			subject += rig.global_position
			count += 1
	if count == 0:
		return
	subject /= count
	var start := camera.global_position
	var offset := Vector2(start.x - subject.x, start.z - subject.z)
	var best := -1.0
	var best_eye := start
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for step in 6:
		var turned := offset.rotated(deg_to_rad(60.0 * step))
		camera.global_position = Vector3(subject.x + turned.x, start.y, subject.z + turned.y)
		camera.look_at(subject + Vector3(0, 1.45, 0))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.resize(64, 48)
		# Brightness in the middle band = haze and sky; ink there is a wall.
		var light := 0.0
		for y in range(10, 38):
			for x in range(12, 52):
				light += image.get_pixel(x, y).v
		# Prefer the story's own angle when it is nearly as open.
		if step == 0:
			light *= 1.15
		if light > best:
			best = light
			best_eye = camera.global_position
	camera.global_position = best_eye
	camera.look_at(subject + Vector3(0, 1.45, 0))

## The Kurosawa camera: brought down near the ground and tilted up, so the
## figures stand against the sky instead of a wall.
func _low_camera(d: Node) -> void:
	var camera: Camera3D = d.camera
	var subject := Vector3.ZERO
	var floor_y := 0.0
	var count := 0
	for key in d.actors:
		var rig: Node3D = d.actors[key].rig
		if rig.visible:
			subject += rig.global_position
			count += 1
	if count == 0:
		return
	subject /= count
	floor_y = subject.y
	# Walled sets (the city street, the hall): look down the open street,
	# where the sky is, not into the walls.
	if str(d.get("set_name")) in ["street", "tea_stall", "gym"]:
		# Behind and below him, looking past his shoulder down the street.
		camera.global_position = subject + Vector3(3.0, 0.42, 0.45)
		camera.look_at(subject + Vector3(-9.0, 1.9, -0.6))
		camera.fov = 34.0
		return
	var eye := camera.global_position
	var flat := Vector2(eye.x - subject.x, eye.z - subject.z)
	# Keep some distance so heads and the sky both fit.
	if flat.length() < 2.2:
		flat = flat.normalized() * 2.2 if flat.length() > 0.01 else Vector2(0, 2.2)
	eye = Vector3(subject.x + flat.x, floor_y + 0.42, subject.z + flat.y)
	camera.global_position = eye
	camera.look_at(subject + Vector3(0, 1.45, 0))
	camera.fov = clampf(camera.fov, 30.0, 44.0)

## ── Kurosawa style ─────────────────────────────────────────────────────
## Every shape becomes black ink and the air between them white haze, so
## the render is pure depth: near things black, far things fading into the
## sky. The finish then paints that sky (a deep top, a glowing horizon,
## a low sun or moon) through the haze, leaving the figures as silhouettes
## against it, with film grain and a heavy vignette.
const SKIES := {
	"dusk": [Color("2a1626"), Color("e8823a"), Color("ffd08a")],
	"dawn": [Color("2c3550"), Color("f2b07a"), Color("fff0c8")],
	"night": [Color("070a18"), Color("7d8cb8"), Color("ffd59a")],
	"storm": [Color("10141c"), Color("8c96a3"), Color("e8ecf2")],
	"arena": [Color("1c2230"), Color("e2e8f2"), Color("ffffff")],
}
const INK := Color("0b0807")

func _ink_world(viewport: SubViewport, plate: Dictionary) -> void:
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color.BLACK
	var cutouts := {}
	for mesh: MeshInstance3D in viewport.find_children("*", "MeshInstance3D", true, false):
		var count := mesh.mesh.get_surface_count() if mesh.mesh != null else 0
		for s in count:
			var source := mesh.get_active_material(s)
			var material: Material = ink
			# Leaves, flags and kites keep their cut-out edges.
			if source is BaseMaterial3D and source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and source.albedo_texture != null:
				if not cutouts.has(source):
					var cut := ink.duplicate() as StandardMaterial3D
					cut.albedo_texture = source.albedo_texture
					cut.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					cut.cull_mode = BaseMaterial3D.CULL_DISABLED
					cutouts[source] = cut
				material = cutouts[source]
			mesh.set_surface_override_material(s, material)
		if mesh.material_override != null:
			mesh.material_override = ink
		# The fighters' hit-flash and rim overlays would paint the ink white.
		mesh.material_overlay = null
		mesh.transparency = 0.0
	for label: Label3D in viewport.find_children("*", "Label3D", true, false):
		label.visible = false
	for light: Light3D in viewport.find_children("*", "Light3D", true, false):
		light.visible = false
	# The camera's own environment outranks any set's (night sets keep a
	# sky of their own): white air, white haze thickening with distance.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_light_color = Color.WHITE
	env.fog_light_energy = 1.0
	env.fog_density = float(plate.get("haze", 0.03))
	env.fog_sky_affect = 0.0
	(viewport.get_camera_3d() as Camera3D).environment = env

const KUROSAWA_SHADER := """shader_type canvas_item;
uniform vec3 top : source_color;
uniform vec3 horizon : source_color;
uniform vec3 sun_color : source_color;
uniform vec3 ink : source_color;
uniform vec2 sun = vec2(0.5, 0.62);
uniform float sun_size = 0.07;
uniform float horizon_y = 0.66;
uniform float seed = 1.0;
// Kurosawa's weather: 0 clear, 1 driving rain, 2 wind-blown dust, 3 low mist.
uniform int weather = 0;
uniform float weather_amount = 1.0;
// Scope bars across the page (fraction of height, each).
uniform float bars = 0.11;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 res = 1.0 / TEXTURE_PIXEL_SIZE;
	float depth = dot(texture(TEXTURE, UV).rgb, vec3(0.333));
	// The sky: deep at the top, burning at the horizon, a low sun with a
	// halo, and long torn bands of cloud.
	float h = clamp(UV.y / horizon_y, 0.0, 1.0);
	vec3 sky = mix(top, horizon, pow(h, 1.6));
	vec2 d = (UV - sun) * vec2(res.x / res.y, 1.0);
	float r = length(d);
	sky = mix(sky, sun_color, smoothstep(sun_size * 4.0, 0.0, r) * 0.55);
	// Halation: old film blooms around a bright light.
	sky += sun_color * exp(-r / (sun_size * 3.5)) * 0.18;
	sky = mix(sky, sun_color, smoothstep(sun_size, sun_size * 0.92, r));
	float band = noise(vec2(UV.x * 3.0, UV.y * 26.0) + seed) * noise(vec2(UV.x * 7.0, UV.y * 40.0));
	sky = mix(sky, mix(top, horizon, 0.35), smoothstep(0.35, 0.6, band) * (1.0 - h) * 0.6);
	// Through the haze: far shapes melt into the sky, near ones are ink.
	float air = smoothstep(0.3, 0.98, depth);
	vec3 col = mix(ink, sky, air);
	// A whisper of warm rim where the ink meets the haze.
	col += sun_color * 0.05 * smoothstep(0.3, 0.45, depth) * (1.0 - smoothstep(0.45, 0.6, depth));
	// Weather in the air, over everything.
	if (weather == 1) {
		// Driving rain: long slanted streaks in two layers, catching the light.
		vec2 q = vec2(UV.x * 1.0 + UV.y * 0.22, UV.y);
		float s1 = step(0.985, hash(floor(vec2(q.x * 260.0, q.y * 9.0 + floor(q.x * 260.0) * 0.37))));
		float s2 = step(0.99, hash(floor(vec2(q.x * 520.0 + 7.0, q.y * 14.0 + floor(q.x * 520.0) * 0.53))));
		col = mix(col, mix(sky, vec3(1.0), 0.4), (s1 * 0.5 + s2 * 0.3) * weather_amount);
		col = mix(col, sky, 0.12 * weather_amount);
	} else if (weather == 2) {
		// Wind-blown dust: warm streaks racing sideways, thickest near the ground.
		float streak = noise(vec2(UV.x * 2.2 - UV.y * 0.8, UV.y * 18.0) + seed) * 0.6 + noise(vec2(UV.x * 5.0, UV.y * 30.0) + seed * 2.0) * 0.4;
		float low = smoothstep(0.45, 1.0, UV.y);
		// Dust drifts through the air, not over the ink of the figures.
		col = mix(col, mix(horizon, sun_color, 0.3), smoothstep(0.45, 0.8, streak) * (0.12 + 0.35 * low) * weather_amount * air);
		float grit = step(0.996, hash(floor(UV * res / 2.0) + seed));
		col = mix(col, sun_color, grit * 0.6 * weather_amount * (0.3 + 0.7 * air));
	} else if (weather == 3) {
		// Low mist creeping over the ground, swallowing the feet.
		float bank = smoothstep(0.62, 1.0, UV.y) * (0.55 + 0.45 * noise(vec2(UV.x * 5.0, UV.y * 8.0) + seed));
		col = mix(col, mix(sky, horizon, 0.5), bank * 0.75 * weather_amount);
	}
	// Film: gate weave and heavy grain, a deep vignette.
	col *= 0.9 + 0.16 * hash(floor(UV * res / 1.8) + seed);
	vec2 v = UV - 0.5;
	col *= 1.0 - smoothstep(0.3, 0.85, length(v * vec2(1.1, 1.3))) * 0.6;
	// Scope bars, a cinema frame on the page.
	float bar = step(UV.y, bars) + step(1.0 - bars, UV.y);
	col = mix(col, vec3(0.03, 0.025, 0.02), clamp(bar, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
"""

func _kurosawa(render: Image, plate: Dictionary) -> Image:
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(render)
	rect.size = Vector2(SIZE)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = KUROSAWA_SHADER
	var sky: Array = SKIES.get(plate.get("sky", "dusk"), SKIES.dusk)
	material.set_shader_parameter("top", sky[0])
	material.set_shader_parameter("horizon", sky[1])
	material.set_shader_parameter("sun_color", sky[2])
	material.set_shader_parameter("ink", INK)
	var sun: Array = plate.get("sun_at", [0.5, 0.62, 0.07])
	material.set_shader_parameter("sun", Vector2(sun[0], sun[1]))
	material.set_shader_parameter("sun_size", sun[2])
	material.set_shader_parameter("horizon_y", float(plate.get("horizon_y", 0.66)))
	material.set_shader_parameter("weather", ["clear", "rain", "dust", "mist"].find(str(plate.get("weather", "clear"))))
	material.set_shader_parameter("weather_amount", float(plate.get("weather_amount", 1.0)))
	material.set_shader_parameter("bars", float(plate.get("bars", 0.11)))
	material.set_shader_parameter("seed", float(hash(plate.key) % 1000) / 100.0)
	rect.material = material
	canvas.add_child(rect)
	for i in 3:
		await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	canvas.queue_free()
	return image

## The sealed letter on the doorstep: a cream envelope with a red seal.
func _lay_letter(d: Node, spec: Dictionary) -> void:
	var page := Image.create(260, 180, false, Image.FORMAT_RGB8)
	page.fill(Color("efe6cf"))
	var ink := Color("7a5a3a")
	for i in 3:
		page.fill_rect(Rect2i(8 + i, 8 + i, 244 - i * 2, 1), ink)
		page.fill_rect(Rect2i(8 + i, 171 - i, 244 - i * 2, 1), ink)
		page.fill_rect(Rect2i(8 + i, 8 + i, 1, 164 - i * 2), ink)
		page.fill_rect(Rect2i(251 - i, 8 + i, 1, 164 - i * 2), ink)
	for y in 180:
		for x in 260:
			if Vector2(x - 130, y - 90).length() < 26.0:
				page.set_pixel(x, y, Color("a3271c"))
	var sheet := StandardMaterial3D.new()
	sheet.albedo_texture = ImageTexture.create_from_image(page)
	var letter := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.26, 0.006, 0.18)
	letter.mesh = box
	letter.material_override = sheet
	var at: Array = spec.at
	var turn: Array = spec.turn
	letter.position = Vector3(at[0], at[1], at[2])
	letter.rotation_degrees = Vector3(turn[0], turn[1], turn[2])
	d.viewport.add_child(letter)

## The letter itself, drawn flat: the word ANANTA at the top, the
## invitation, and the six names, on lokta paper with a red seal.
func _letter_page() -> Image:
	const UI := preload("res://scripts/ui_kit.gd")
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var desk := ColorRect.new()
	desk.color = Color("e9dcbc")
	desk.size = Vector2(SIZE)
	canvas.add_child(desk)
	var sheet := ColorRect.new()
	sheet.color = Color("f3ead2")
	sheet.position = Vector2(300, 150)
	sheet.size = Vector2(1000, 900)
	sheet.rotation_degrees = -2.0
	canvas.add_child(sheet)
	var book_font: Font = load("res://assets/fonts/TiroDevanagariHindi-Regular.ttf")
	var italic: Font = load("res://assets/fonts/TiroDevanagariHindi-Italic.ttf")
	var lines := [
		["अनन्त", UI.devanagari_font(), 120, Color("a3271c"), 40],
		["A N A N T A", UI.strong_font(), 34, Color("2e2118"), 190],
		["You are summoned to a tournament of masters.", book_font, 36, Color("2e2118"), 290],
		["The strongest shall claim a reward of NPR 5 crore.", book_font, 36, Color("2e2118"), 345],
		["But money is not the only prize.", italic, 36, Color("5a4636"), 400],
		["The final victor shall discover", italic, 40, Color("2e2118"), 470],
		["the whereabouts of the missing Master.", italic, 40, Color("2e2118"), 520],
		["AGASTHYA   ·   MAHABALI   ·   KRI", UI.strong_font(), 34, Color("5a4636"), 640],
		["VAJRAVEER   ·   ANUG   ·   SARVOCHCHA", UI.strong_font(), 34, Color("5a4636"), 695],
	]
	for spec in lines:
		var label := Label.new()
		label.text = spec[0]
		label.add_theme_font_override("font", spec[1])
		label.add_theme_font_size_override("font_size", spec[2])
		label.add_theme_color_override("font_color", spec[3])
		label.position = Vector2(0, spec[4])
		label.size = Vector2(1000, spec[2] + 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sheet.add_child(label)
	var rule := ColorRect.new()
	rule.color = Color("b07a2a")
	rule.position = Vector2(300, 600)
	rule.size = Vector2(400, 3)
	sheet.add_child(rule)
	var seal := Label.new()
	seal.text = "●"
	seal.add_theme_font_size_override("font_size", 150)
	seal.add_theme_color_override("font_color", Color("a3271c"))
	seal.position = Vector2(780, 700)
	sheet.add_child(seal)
	for i in 3:
		await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	canvas.queue_free()
	return image

## The newspaper as a printed sheet: a headline in Devanagari and English
## over columns of type, so it reads as a newspaper and not a blank board.
func _print_newspaper(paper: MeshInstance3D) -> void:
	for child in paper.get_children():
		child.queue_free()
	var page := Image.create(420, 300, false, Image.FORMAT_RGB8)
	page.fill(Color("efe8d6"))
	var ink := Color("2a2420")
	page.fill_rect(Rect2i(16, 14, 388, 4), ink)
	page.fill_rect(Rect2i(16, 72, 388, 2), ink)
	page.fill_rect(Rect2i(16, 84, 388, 46), Color("b3202a"))
	for column in 3:
		var x := 16 + column * 132
		for row in 15:
			var width := 118 - (17 * ((row * 7 + column * 3) % 5))
			page.fill_rect(Rect2i(x, 142 + row * 10, maxi(width, 60), 4), Color(0.25, 0.22, 0.2))
	page.rotate_90(CLOCKWISE)
	var sheet := StandardMaterial3D.new()
	sheet.albedo_texture = ImageTexture.create_from_image(page)
	paper.material_override = sheet
	paper.set_meta("storybook", null)
	paper.remove_meta("storybook")
	var title := Label3D.new()
	title.text = "अनन्तको बाटो"
	title.font = preload("res://scripts/ui_kit.gd").devanagari_font()
	title.font_size = 64
	title.pixel_size = 0.0011
	title.modulate = Color("2a2420")
	title.outline_size = 0
	title.rotation_degrees = Vector3(-90, 0, 0)
	title.position = Vector3(0, 0.005, -0.1)
	title.shaded = true
	paper.add_child(title)
	var road := Label3D.new()
	road.text = "THE ROAD TO ANANTA  ·  RS 5 CRORE"
	road.font_size = 32
	road.pixel_size = 0.00075
	road.modulate = Color("f4ead6")
	road.outline_size = 0
	road.rotation_degrees = Vector3(-90, 0, 0)
	road.position = Vector3(0, 0.005, -0.025)
	paper.add_child(road)

## The watercolour finish, rendered through a canvas of its own.
func _finish(render: Image, plate: Dictionary, style: String) -> Image:
	if style == "frame_only":
		return await _frame(render, plate)
	if style == "kurosawa":
		return await _kurosawa(render, plate)
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.transparent_bg = false
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(render)
	rect.size = Vector2(SIZE)
	var material := ShaderMaterial.new()
	material.shader = MITHILA_SHADER if style == "mithila" else PLATE_SHADER
	material.set_shader_parameter("mood", plate.get("mood", MORNING))
	material.set_shader_parameter("seed", float(hash(plate.key) % 1000) / 100.0)
	rect.material = material
	canvas.add_child(rect)
	for i in 3:
		await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	canvas.queue_free()
	if style == "mithila_frame":
		image = await _frame(image, plate)
	return image

## The Mithila border on lokta paper around a finished picture.
func _frame(image: Image, plate: Dictionary) -> Image:
	var frame := SubViewport.new()
	frame.size = SIZE
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(frame)
	var framed := TextureRect.new()
	framed.texture = ImageTexture.create_from_image(image)
	framed.size = Vector2(SIZE)
	var border := ShaderMaterial.new()
	border.shader = MITHILA_SHADER
	border.set_shader_parameter("frame_only", true)
	border.set_shader_parameter("seed", float(hash(plate.key) % 1000) / 100.0)
	framed.material = border
	frame.add_child(framed)
	for i in 3:
		await RenderingServer.frame_post_draw
	image = frame.get_texture().get_image()
	frame.queue_free()
	return image
