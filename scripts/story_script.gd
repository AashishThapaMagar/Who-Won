extends RefCounted
## ── WRITE YOUR STORY HERE ──────────────────────────────────────────────
## This is the only file Story Mode reads for dialogue. Nothing outside
## this file needs to change to rewrite the story — see story_director.gd
## / story_dialogue.gd only if you want to change how it's presented.
##
## Story Mode runs the same matchup order as Arcade (every roster fighter
## once, in the order they're beaten, always ending with Anant) and fires
## these beats around each fight:
##   PROLOGUE          → once, before the very first fight.
##   CHAPTERS[id].intro    → before you fight that opponent.
##   CHAPTERS[id].victory  → right after you beat them.
##   CHAPTERS[id].defeat   → if they beat you (you then retry the same fight).
##   FINALE             → once, after Anant falls.
##
## Each block is an Array of lines, shown one at a time (advance with
## Enter/Space/click, or Esc to skip the whole block):
##   {"speaker": "ish", "text": "Keep up if you can."}
## "speaker" is a fighter id from fighter_roster.gd's PROFILES ("anug",
## "ish", "sab", "bib", "abhi", "sup", "anant"), "player" for whichever
## fighter the player chose, or "" for narration. An empty array ([]) skips
## that beat entirely — e.g. leave CHAPTERS[id].defeat as [] if you don't
## want a loss line for that fighter.
##
## Each fighter can also have their own storyline in ROUTES, keyed by the
## fighter the player chose. A route can replace the prologue and finale,
## and rewrite any beat of any chapter (the rest stay shared):
##   "prologue_arena" / "finale_arena"  arena mood (nepal_stage_3d.gd ROUNDS)
##   "title" / "subtitle"               the prologue's title card
##   "style": "book"                    tell it as an illustrated book: a
##                                      line's "image" turns to that drawn
##                                      page (assets/story/<fighter>/<name>.jpg)
##   "chapter_images": {id: image}      the page each rival's chapter opens on
##   "cinematic": true                  film camera: eased arcs, push-ins, lenses
##   "still": true                      each line freezes like a photograph;
##                                      only the camera moves
##   "ladder": [ids]                    the order of rivals (ending "anant")
##   "finale_title"                     the finale's title card
## Any line can carry a "banner" that slams a card across the screen before
## the line plays (a poster, a headline):
##   {"speaker": "", "text": "...", "banner": {"eyebrow": "...", "title": "...", "subtitle": "...", "red": true}}
##
## Lines can leave the arenas for story_sets.gd sets and direct the actors:
##   "set": "gym" | "street" | "pitch" | "academy"   (dips to black to change)
##   "cast": {"player": {"at": "coach", "face": [0, 1]},
##            "s1": {"fighter": "bib", "at": "s1", "face": "player", "scale": 0.62}}
##       "at" is a mark of the set or [x, z]; "face" is [dx, dz], a mark, an
##       actor or "camera"; any roster fighter can be cast under any name.
##   "do": [{"who": "player", "walk": "poster", "speed": 1.2, "then_face": [0, -1]},
##          {"who": "s1", "pose": "jab", "repeat": 1.3, "delay": 0.4},
##          {"who": "player", "pose": "kick", "hold": 1.5},
##          {"ball": {"from": [8, 0.11, 0], "to": [12.5, 1, -1], "time": 0.7}, "delay": 1.4}]
##       poses are animation names: idle, walk, run, jab, punch_heavy, kick,
##       kick_spin, block, block_hit, hit, ko, taunt, victory ("" = back to idle).
##       Fighters with story gestures (fighter_models.gd TRIPO_MOVES; Sarvochcha
##       so far) also have bow, hug, sob, angry, agree, laugh, swagger,
##       warm_up and dance. In a "still" storyline, "settle" is how long the
##       gesture plays before the picture freezes (a bow at its lowest).
##   "shot": {"eye": [x,y,z], "look": [x,y,z], "eye_to": ..., "look_to": ..., "time": 6}
##           {"follow": "player", "offset": [x, y, z]}     {"close": "s1"}
##
## Narration: drop a recording for any line at
##   audio/story/<chosen fighter>/<beat>_<line number>.ogg   (.wav / .mp3 too)
## e.g. audio/story/anug/prologue_01.ogg, audio/story/anug/ish_intro_02.ogg,
## audio/story/anug/finale_03.ogg. It plays with the line, and the scene moves
## on by itself when it ends.
##
## The cutscene camera picks its own shot (a close-up on whoever speaks,
## wide shots and two-shots for narration). Add a "shot" key to choose one:
## "wide", "two", "hero", "close_player" or "close_rival".
##
## Dubbing a line is optional and opt-in per line — add a "voice" key with
## the clip's res:// path (.ogg/.wav/.mp3, imported like any other Godot
## audio asset) and story_dialogue.gd plays it the instant that line shows:
##   {"speaker": "ish", "text": "Keep up if you can.", "voice": "res://audio/voice/ish_intro_01.ogg"}
## Lines with no "voice" key (every line right now) just stay silent — text
## alone is never blocked on a clip existing, so you can dub incrementally,
## one character or one chapter at a time, and leave the rest untouched.

const PROLOGUE := [
	{"speaker": "", "text": "Kathmandu. Old stone, older rivalries."},
	{"speaker": "", "text": "Seven fighters. One title. Five crore rupees to whoever beats Ananta.", "banner": {"eyebrow": "OPEN TOURNAMENT", "title": "THE ROAD TO ANANTA", "subtitle": "BEAT ANANTA  /  WIN RS 5 CRORE", "red": true}},
	{"speaker": "player", "text": "Then I'll settle all of them."},
	{"speaker": "", "text": "The road to the top starts now.", "shot": "hero"},
]

const CHAPTERS := {
	"anug": {
		"intro": [
			{"speaker": "", "text": "Anug has never let anything past him. Not a ball. Not a punch."},
			{"speaker": "anug", "text": "Nothing gets past me. Not today."},
			{"speaker": "player", "text": "Then stand still and try to stop this."},
		],
		"victory": [
			{"speaker": "anug", "text": "...Huh. Didn't see that one coming."},
			{"speaker": "player", "text": "Nobody ever does."},
		],
		"defeat": [
			{"speaker": "anug", "text": "Saved. Come back when you've got a real shot."},
		],
	},
	"ish": {
		"intro": [
			{"speaker": "", "text": "Agasthya hits first and asks questions never."},
			{"speaker": "ish", "text": "Blink and it's over."},
			{"speaker": "player", "text": "Then I won't blink."},
		],
		"victory": [
			{"speaker": "ish", "text": "Okay. Okay! That one counts, I guess."},
		],
		"defeat": [
			{"speaker": "ish", "text": "Too slow. Told you."},
		],
	},
	"sab": {
		"intro": [
			{"speaker": "", "text": "They call Mahabali the Iron Grip. Nobody has ever pulled free."},
			{"speaker": "sab", "text": "Once I've got you, you're not leaving."},
			{"speaker": "player", "text": "You have to catch me first."},
		],
		"victory": [
			{"speaker": "sab", "text": "Strong grip. Stronger will. Respect."},
		],
		"defeat": [
			{"speaker": "sab", "text": "Told you. Nobody leaves."},
		],
	},
	"bib": {
		"intro": [
			{"speaker": "", "text": "Vajraveer never runs out of breath. His rivals always do."},
			{"speaker": "bib", "text": "Catch me if you can!"},
			{"speaker": "player", "text": "I don't need to catch you. Just once."},
		],
		"victory": [
			{"speaker": "bib", "text": "Guess I ran out of road."},
		],
		"defeat": [
			{"speaker": "bib", "text": "Still fresh. You?"},
		],
	},
	"abhi": {
		"intro": [
			{"speaker": "", "text": "Kri fights loud. The crowd loves it. His rivals hate it."},
			{"speaker": "abhi", "text": "Let me tell you exactly how this ends."},
			{"speaker": "player", "text": "Less talking."},
		],
		"victory": [
			{"speaker": "abhi", "text": "...I was talking. That's not fair."},
		],
		"defeat": [
			{"speaker": "abhi", "text": "See? Exactly how I said."},
		],
	},
	"sup": {
		"intro": [
			{"speaker": "", "text": "Sarvochcha moves like the wind through prayer flags. Never where you aim."},
			{"speaker": "sup", "text": "Catch the wind if you can."},
			{"speaker": "player", "text": "Wind stops eventually."},
		],
		"victory": [
			{"speaker": "sup", "text": "The spiral breaks. Well fought."},
			{"speaker": "sup", "text": "He's waiting at the stupa. He's been waiting for you."},
		],
		"defeat": [
			{"speaker": "sup", "text": "Too straight. Flow, or fall."},
		],
	},
	"anant": {
		"intro": [
			{"speaker": "", "text": "Night at the stupa. The flags go quiet."},
			{"speaker": "anant", "text": "Everyone who reached me thought they were ready."},
			{"speaker": "player", "text": "I'm not everyone."},
			{"speaker": "anant", "text": "We'll see."},
		],
		"victory": [
			{"speaker": "anant", "text": "...The final word belongs to you, then."},
		],
		"defeat": [
			{"speaker": "anant", "text": "Not yet. Come back when you mean it."},
		],
	},
}

const FINALE := [
	{"speaker": "", "text": "Seven names on the board. Now there's only one."},
	{"speaker": "player", "text": "Tell the valley. The title stays here."},
	{"speaker": "", "text": "THE END.", "shot": "wide"},
]

## ── Fighter storylines ─────────────────────────────────────────────────
const ROUTES := {
	# Anug: a goalkeeper in a country with no football to pay him.
	"anug": {
		"title": "NO PITCH, NO PAY",
		"subtitle": "THE STORY OF ANUG",
		"prologue_arena": 1,
		"finale_arena": 2,
		"finale_title": "FIVE CRORE",
		"prologue": [
			# A dusty neighbourhood pitch: the dream.
			{"speaker": "", "text": "Anug grew up with a football at his feet and one dream: to play it for a living.",
				"set": "pitch", "cast": {"player": {"at": "spot", "face": [1, 0]}},
				"do": [{"who": "player", "pose": "kick", "delay": 0.9, "hold": 1.6},
					{"ball": {"from": [8.2, 0.11, 0.2], "to": [13.4, 1.1, -1.6], "time": 0.7, "arc": 0.5}, "delay": 1.5}],
				"shot": {"eye": [5.6, 1.25, 3.4], "look": [9.5, 0.9, -0.4], "eye_to": [6.3, 1.2, 2.9], "look_to": [11.5, 1.0, -0.9], "time": 6}},
			{"speaker": "", "text": "But in Nepal, the pitch doesn't pay. Leagues stop. Clubs fold. The trials never come.",
				"do": [{"who": "player", "walk": "centre", "speed": 0.8, "delay": 0.6}],
				"shot": {"follow": "player", "offset": [-2.4, 0.1, 2.4]}},
			{"speaker": "anug", "text": "Ten years in goal. Not one rupee from it."},
			# The city at night.
			{"speaker": "", "text": "The city doesn't care what you were good at. Rent is due on the first.",
				"set": "street", "cast": {"player": {"at": "far", "face": [1, 0]}},
				"do": [{"who": "player", "walk": [-2.4, 0.4], "speed": 1.0, "delay": 0.4}],
				"shot": {"eye": [-4.8, 1.5, 4.6], "look": [-6.2, 1.2, 0.0], "eye_to": [-2.6, 1.5, 4.0], "look_to": [-2.2, 1.2, -0.6], "time": 6}},
			{"speaker": "anug", "text": "Football is all I know. Football... and how to fight."},
			# The rented hall.
			{"speaker": "", "text": "So he teaches MMA in a rented hall. Three students a week. Just enough to survive.",
				"set": "gym", "cast": {
					"player": {"at": "coach", "face": [0, 1]},
					"s1": {"fighter": "bib", "at": "s1", "face": "coach"},
					"s2": {"fighter": "abhi", "at": "s2", "face": "coach"},
					"s3": {"fighter": "sup", "at": "s3", "face": "coach"}},
				"do": [{"who": "s1", "pose": "jab", "repeat": 1.5, "delay": 0.3},
					{"who": "s2", "pose": "jab", "repeat": 1.5, "delay": 0.8},
					{"who": "s3", "pose": "jab", "repeat": 1.5, "delay": 1.2},
					{"who": "player", "pose": "jab", "repeat": 2.2, "delay": 0.1}],
				"shot": "wide"},
			{"speaker": "anug", "text": "Hands up. Chin down. Again.",
				"shot": {"eye": [-1.2, 1.35, 2.7], "look": [0, 1.4, -1.2], "eye_to": [-0.7, 1.4, 2.2], "look_to": [0, 1.45, -1.2], "time": 5}},
			# Walking home: the poster.
			{"speaker": "", "text": "Then one night, walking home...",
				"set": "street", "cast": {"player": {"at": [-5.0, 0.3], "face": [1, 0]}},
				"do": [{"who": "player", "walk": [1.3, -1.6], "speed": 1.1, "then_face": [0, -1]}],
				"shot": {"follow": "player", "offset": [1.9, 0.05, 2.4]}},
			{"speaker": "", "text": "...a poster on a temple wall.",
				"banner": {"eyebrow": "OPEN TOURNAMENT", "title": "THE ROAD TO ANANTA", "subtitle": "BEAT ANANTA  /  WIN RS 5 CRORE", "red": true},
				"cast": {"player": {"at": [1.3, -1.6], "face": [0, -1]}},
				"shot": {"eye": [-0.8, 1.9, 1.6], "look": [0.4, 1.85, -3.3], "eye_to": [-0.1, 1.87, 0.4], "look_to": [0.4, 1.85, -3.3], "time": 5}},
			{"speaker": "anug", "text": "Five crore...",
				"shot": {"eye": [2.1, 1.75, -0.3], "look": [0.5, 1.8, -3.3], "eye_to": [1.9, 1.78, -0.6], "look_to": [0.45, 1.82, -3.3], "time": 5}},
			{"speaker": "anug", "text": "That's not a prize. That's a pitch. A team. A future for every kid like me.",
				"do": [{"who": "player", "face": [0.4, 1]}], "shot": "hero"},
			{"speaker": "anug", "text": "Nothing gets past me. Not this time.",
				"do": [{"who": "player", "walk": [8.0, 0.9], "speed": 1.4, "delay": 1.2}],
				"shot": {"eye": [-1.6, 1.4, 3.6], "look": [1.5, 1.3, -1.0], "eye_to": [-1.0, 1.5, 3.0], "look_to": [4.5, 1.3, 0.0], "time": 6}},
		],
		"chapters": {
			"ish": {
				"intro": [
					{"speaker": "", "text": "First rival: Agasthya. The fastest hands in the valley."},
					{"speaker": "ish", "text": "A goalkeeper? Go back to your pitch, keeper."},
					{"speaker": "anug", "text": "There's no pitch to go back to. That's why I'm here."},
				],
				"victory": [
					{"speaker": "ish", "text": "Okay... where did a goalkeeper learn to hit like that?"},
					{"speaker": "anug", "text": "Teaching it. Three students a week."},
				],
			},
			"sab": {
				"intro": [
					{"speaker": "sab", "text": "I've heard about you. The footballer who fights."},
					{"speaker": "anug", "text": "The footballer who can't pay rent. That's the one."},
					{"speaker": "sab", "text": "Then let's see how much you want it."},
				],
				"victory": [
					{"speaker": "sab", "text": "Strong grip. Stronger will. Go get your pitch."},
				],
			},
			"bib": {
				"intro": [
					{"speaker": "bib", "text": "Catch me if you can!"},
					{"speaker": "anug", "text": "I've spent my whole life catching things."},
				],
				"victory": [
					{"speaker": "bib", "text": "Guess I ran out of road."},
					{"speaker": "anug", "text": "Nobody outruns the keeper."},
				],
			},
			"abhi": {
				"intro": [
					{"speaker": "abhi", "text": "Five crore? You'll spend it on football? Nobody in Nepal watches football."},
					{"speaker": "anug", "text": "They would. If someone gave them a reason."},
				],
				"victory": [
					{"speaker": "abhi", "text": "...Fine. I'd watch that match."},
				],
			},
			"sup": {
				"intro": [
					{"speaker": "sup", "text": "You fight like you're guarding something."},
					{"speaker": "anug", "text": "I am. Every kid who only knows one thing."},
				],
				"victory": [
					{"speaker": "sup", "text": "The spiral breaks. He's waiting at the stupa, keeper."},
					{"speaker": "anug", "text": "Then let's finish this."},
				],
			},
			"anant": {
				"intro": [
					{"speaker": "", "text": "Night at the stupa. Five crore rests on one fight.", "shot": "wide"},
					{"speaker": "anant", "text": "A footballer. You're a long way from your pitch."},
					{"speaker": "anug", "text": "I never had one. That's what I'm fighting for."},
					{"speaker": "anant", "text": "Everyone who reached me was fighting for something."},
					{"speaker": "anug", "text": "Then you've never faced a keeper."},
				],
				"victory": [
					{"speaker": "anant", "text": "...Nothing gets past you. The final word is yours."},
				],
				"defeat": [
					{"speaker": "anant", "text": "Your dream is heavy, keeper. Come back when you can carry it."},
				],
			},
		},
		"finale": [
			{"speaker": "", "text": "Five crore. The Road to Ananta has its champion, and he wears goalkeeper gloves.", "shot": "hero"},
			{"speaker": "anug", "text": "No kid here should have to choose between football and food."},
			# Months later: the academy.
			{"speaker": "", "text": "Months later, at the edge of the city, floodlights switch on over a brand new pitch.",
				"set": "academy",
				"banner": {"eyebrow": "EPILOGUE", "title": "ANUG FOOTBALL ACADEMY", "subtitle": "FREE FOR EVERY KID WHO SHOWS UP"},
				"cast": {
					"player": {"at": "goal", "face": [-1, 0]},
					"k1": {"fighter": "bib", "at": "k1", "face": "goal", "scale": 0.62},
					"k2": {"fighter": "ish", "at": "k2", "face": "goal", "scale": 0.62},
					"k3": {"fighter": "sup", "at": "k3", "face": "goal", "scale": 0.62}},
				"shot": "wide"},
			{"speaker": "anug", "text": "Alright, everyone. Line up. Let's see who can get one past me.",
				"do": [{"who": "player", "pose": "block"}]},
			{"speaker": "", "text": "The first shot the Anug Football Academy ever faced.",
				"do": [{"ball": {"from": [8.45, 0.11, -0.75], "to": [8.45, 0.11, -0.75], "time": 0.05}},
					{"who": "k2", "walk": [8.0, -0.7], "speed": 1.2, "then_face": "goal"},
					{"who": "k2", "pose": "kick", "delay": 1.7, "hold": 1.6},
					{"ball": {"from": [8.45, 0.11, -0.75], "to": [12.0, 1.05, -1.0], "time": 0.55, "arc": 0.4}, "delay": 2.3},
					{"who": "player", "pose": "block_hit", "delay": 2.5, "hold": 2.2}],
				"shot": {"eye": [6.2, 1.2, 2.8], "look": [9.8, 0.9, -0.9], "eye_to": [7.0, 1.3, 2.3], "look_to": [11.8, 1.2, -1.0], "time": 5}},
			{"speaker": "anug", "text": "Saved! Good shot, though. Again. Harder this time."},
			{"speaker": "", "text": "THE END.", "shot": "wide"},
		],
	},
	# Sarvochcha: his master vanished at the height of his career. Years later,
	# about to leave Nepal to work abroad, he finds a letter at his door: a
	# tournament called ANANTA, five crore, and the whereabouts of the missing
	# master for whoever wins. Told as a storybook (story_book.gd) with baked
	# pictures for its key moments (tools/bake_story_plates.gd).
	"sup": {
		"title": "THE MISSING MASTER",
		"subtitle": "THE STORY OF SARVOCHCHA",
		"finale_title": "TEACHER AND DISCIPLE",
		# Shot like a film: slow eased dolly arcs and push-ins, film lenses.
		"cinematic": true,
		# Every line is a frozen moment the camera moves across.
		"still": true,
		# His old training companions first; his closest friend Mahabali
		# fifth; then the mysterious final opponent.
		"ladder": ["anug", "ish", "bib", "abhi", "sab", "anant"],
		"prologue": [
			# Act I: the missing master.
			{"speaker": "", "text": "Years ago, on a hilltop above his village, a boy named Sarvochcha trained every morning under one master.",
				"set": "ananta_ground",
				"cast": {"player": {"at": "edge", "face": "dummy"}, "anant": {"fighter": "anant", "at": "dummy", "face": "player"}},
				"shot": "wide"},
			{"speaker": "", "text": "Then, at the height of Sarvochcha's career, his master vanished. No letter. No goodbye. Not a trace.",
				"do": [{"who": "player", "pose": "sob", "settle": 2.6, "hold": 4.1}]},
			{"speaker": "", "text": "Years passed. With a family to feed, Sarvochcha let go of his dream of becoming a great fighter.",
				"set": "hill_road", "cast": {"player": {"at": "home", "face": "camera"}},
				"shot": "wide"},
			{"speaker": "sup", "text": "Ama's medicine. Bahini's school fees. There's no money in fighting anymore.", "shot": "hero"},
			{"speaker": "", "text": "So he would go abroad and work. One morning, as he made ready to leave for Kathmandu...",
				"do": [{"who": "player", "walk": "road", "speed": 1.0, "delay": 0.4, "then_face": [1, 0]}],
				"shot": {"follow": "player", "offset": [-2.4, 0.2, 3.2]}},
			{"speaker": "", "text": "...he found a letter lying at his doorstep."},
			{"speaker": "", "text": "At the top of the letter was a single word.",
				"banner": {"eyebrow": "AN INVITATION", "title": "ANANTA", "subtitle": "A TOURNAMENT OF MASTERS", "red": true}},
			{"speaker": "", "text": "\"The strongest shall claim a reward of NPR 5 crore. But money is not the only prize. The final victor shall discover the whereabouts of the missing Master.\""},
			{"speaker": "", "text": "Beneath it, the names of the fighters: Agasthya. Mahabali. Kri. Vajraveer. Anug. Sarvochcha. Every one of them trained by his missing master."},
			{"speaker": "sup", "text": "Guruji... what happened to you? Who is doing this? And why call all of us?", "shot": "close_player"},
			{"speaker": "", "text": "To find his master, and to save his family, Sarvochcha accepted the challenge."},
			{"speaker": "sup", "text": "Ama. I'll be back. With enough for all of us.",
				"do": [{"who": "player", "pose": "bow", "settle": 2.9, "hold": 4.4}]},
		],
		"chapters": {
			"anug": {
				"intro": [
					{"speaker": "anug", "text": "Sarvochcha? So the letter found you too."},
					{"speaker": "sup", "text": "It found all of us, Anug. Same master. Same question."},
					{"speaker": "anug", "text": "Then no holding back, friend. Guruji wouldn't want it."},
				],
				"victory": [
					{"speaker": "anug", "text": "Go on. Find him. Tell him I still keep my hands up."},
					{"speaker": "sup", "text": "I will. And then I'll buy you a real pitch.",
						"do": [{"who": "player", "pose": "laugh", "settle": 1.3, "hold": 2.8}]},
				],
				"defeat": [
					{"speaker": "anug", "text": "Nothing gets past me, hill boy. Try again."},
				],
			},
			"ish": {
				"intro": [
					{"speaker": "ish", "text": "Sarvochcha! Last time we sparred, Guruji made us run the hill for an hour."},
					{"speaker": "sup", "text": "This time it's for my family, Agasthya.",
						"do": [{"who": "player", "pose": "angry", "settle": 0.9, "hold": 2.4}]},
					{"speaker": "ish", "text": "Then I'll hit you twice as fast."},
				],
				"victory": [
					{"speaker": "ish", "text": "...You were always faster than you looked."},
				],
				"defeat": [
					{"speaker": "ish", "text": "Too slow today. Shake it off and come again."},
				],
			},
			"bib": {
				"intro": [
					{"speaker": "bib", "text": "Race you to the end of this, Sarvochcha?"},
					{"speaker": "sup", "text": "It's not a race, Vajraveer. It's a climb. Guruji taught us that."},
				],
				"victory": [
					{"speaker": "bib", "text": "Okay, okay. Go. Don't look back."},
				],
				"defeat": [
					{"speaker": "bib", "text": "Ha! Climb faster!"},
				],
			},
			"abhi": {
				"intro": [
					{"speaker": "abhi", "text": "The quiet one from the hills! Still training like Guruji's watching?"},
					{"speaker": "sup", "text": "Every day, Kri. Maybe he is."},
					{"speaker": "abhi", "text": "...Respect. But I'm still not losing."},
				],
				"victory": [
					{"speaker": "abhi", "text": "The Loud Thunder... gone quiet. Go on, brother."},
				],
				"defeat": [
					{"speaker": "abhi", "text": "Louder next time, hill boy!"},
				],
			},
			# Act II: the fight between friends.
			"sab": {
				"intro": [
					{"speaker": "", "text": "Deep in the tournament, an unexpected opponent: Mahabali, his closest friend from their training days.",
						"banner": {"eyebrow": "CHAPTER FIVE", "title": "MAHABALI", "subtitle": "THE FIGHT BETWEEN FRIENDS"}},
					{"speaker": "sab", "text": "It's been a long time since we last met, hasn't it?"},
					{"speaker": "sup", "text": "How have you been? Tell me something... do you think our master is still alive?"},
					{"speaker": "sab", "text": "I suppose we'll find out at the end. Look at the situation we're in."},
					{"speaker": "sab", "text": "Let's not talk too much. I'm sure you need that prize money just as badly as I do."},
					{"speaker": "", "text": "Friends or not, neither of them could afford to lose."},
				],
				"victory": [
					{"speaker": "", "text": "Mahabali struggles to rise."},
					{"speaker": "sup", "text": "I'll see you again, my friend."},
					{"speaker": "", "text": "Sarvochcha walks on, and leaves his friend behind. The tournament continues."},
				],
				"defeat": [
					{"speaker": "sab", "text": "Get up, Sarvochcha. Guruji never let us stop halfway."},
				],
			},
			# Act III: the final revelation.
			"anant": {
				"intro": [
					{"speaker": "", "text": "One fight left: the championship. The mysterious final opponent steps into the arena."},
					{"speaker": "", "text": "Sarvochcha freezes."},
					{"speaker": "sup", "text": "MASTER?!", "shot": "close_player",
						"do": [{"who": "player", "pose": "angry", "settle": 0.9, "hold": 2.4}]},
					{"speaker": "", "text": "But Ananta says nothing. Without a word of explanation, he takes his fighting stance.", "shot": "close_rival"},
					{"speaker": "", "text": "The only way to the truth is through the man who taught him everything he knows."},
				],
				"victory": [],
				"defeat": [
					{"speaker": "anant", "text": "Again. Everything I taught you. Show me."},
				],
			},
		},
		"finale": [
			{"speaker": "", "text": "Ananta fought with every technique he had ever taught. And still, his student won.",
				"cast": {"anant": {"fighter": "anant", "at": [1.2, 0.0], "face": "player"}}},
			{"speaker": "sup", "text": "Master... where have you been all these years? Why did you disappear without telling us?"},
			{"speaker": "anant", "text": "Years ago, I competed in an international fighting tournament. I lost."},
			{"speaker": "anant", "text": "That defeat changed everything. The humiliation I faced was unbearable. I could no longer face the people who once respected me."},
			{"speaker": "anant", "text": "So I left everything behind, and disappeared into a remote village, far away from everyone I knew."},
			{"speaker": "anant", "text": "I couldn't even bring myself to tell my own students. I was ashamed."},
			{"speaker": "anant", "text": "After my defeat, I had five crore rupees that I could never bring myself to spend."},
			{"speaker": "anant", "text": "In time I understood that the money belonged to someone more deserving. One of my students."},
			{"speaker": "anant", "text": "So I made this tournament, to discover which of you had truly earned it."},
			{"speaker": "sup", "text": "Master, everything you taught me has stayed with me.",
				"do": [{"who": "player", "pose": "bow", "settle": 2.9, "hold": 4.4}]},
			{"speaker": "sup", "text": "Because of you, I have endured every struggle life gave me. You taught me patience, resilience, and the strength to keep moving forward."},
			{"speaker": "sup", "text": "Thank you, Master."},
			{"speaker": "anant", "text": "I spent years believing that defeat had taken everything from me. But today, my student has reminded me..."},
			{"speaker": "anant", "text": "...that a master's greatest victory is not the battles he wins. It is the strength he leaves behind."},
			{"speaker": "", "text": "For the first time in years, master and student stood together. Not as opponents, but as teacher and disciple.", "shot": "two"},
			{"speaker": "", "text": "THE END.", "shot": "wide"},
		],
	},
}
