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
	# Anug: a goalkeeper in a country with no football to pay him, and one of
	# the six students of the master who vanished (see Sarvochcha's story).
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
			{"speaker": "anug", "text": "Football is all I know. Football... and how to fight. Guruji taught me that much, before he disappeared."},
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
			# Walking home: the letter, the same one Sarvochcha finds.
			{"speaker": "", "text": "Then one night, walking home, a stranger presses a sealed letter into his hand and is gone.",
				"set": "street", "cast": {"player": {"at": [-5.0, 0.3], "face": [1, 0]}},
				"do": [{"who": "player", "walk": [1.3, -1.6], "speed": 1.1, "then_face": [0, -1]}],
				"shot": {"follow": "player", "offset": [1.9, 0.05, 2.4]}},
			{"speaker": "", "text": "At the top of it, a single word.",
				"banner": {"eyebrow": "AN INVITATION", "title": "ANANTA", "subtitle": "A TOURNAMENT OF MASTERS", "red": true},
				"cast": {"player": {"at": [1.3, -1.6], "face": [0, -1]}},
				"shot": {"eye": [-0.8, 1.9, 1.6], "look": [0.4, 1.85, -3.3], "eye_to": [-0.1, 1.87, 0.4], "look_to": [0.4, 1.85, -3.3], "time": 5}},
			{"speaker": "anug", "text": "Five crore... and the whereabouts of the missing Master? Guruji... is this about you?",
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
					{"speaker": "", "text": "The final opponent steps out of the dark, and Anug knows that walk.", "shot": "wide"},
					{"speaker": "anug", "text": "...Guruji?"},
					{"speaker": "anant", "text": "Hands up. Chin down. You still remember."},
					{"speaker": "anug", "text": "I teach it every week. Three students. Just like you taught six of us."},
					{"speaker": "anant", "text": "Then show me what the keeper learned."},
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
			{"speaker": "", "text": "Afterwards, the master told him everything: the international final he lost, the shame, the years in hiding, the five crore he could never spend.", "shot": "hero"},
			{"speaker": "anant", "text": "I wanted it to go to one of you. To the one who would use it best."},
			{"speaker": "anug", "text": "Then it's going to every kid who only has one dream. No kid here should have to choose between football and food."},
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
	# Agasthya: the fastest hands in the valley, who can't stop seeing the
	# people around him who are too poor to chase their dreams. He fights so
	# that their lives can change.
	"ish": {
		"title": "THE FASTEST HANDS",
		"subtitle": "THE STORY OF AGASTHYA",
		"finale_title": "A BETTER CHANGE",
		"cinematic": true,
		"still": true,
		"ladder": ["bib", "abhi", "anug", "sab", "sup", "anant"],
		"prologue": [
			{"speaker": "", "text": "Every evening, Agasthya drinks his tea at the same roadside stall in the city.",
				"set": "tea_stall", "cast": {"player": {"at": "stall", "face": [1, 0.6]}}, "shot": "wide"},
			{"speaker": "", "text": "The boy who washes the glasses wants to be a doctor. The tea-maker's daughter paints on old newspapers."},
			{"speaker": "", "text": "The porter on the next bench once ran for his district. Now he carries gas cylinders up four floors."},
			{"speaker": "ish", "text": "Every one of them has a dream. And not one of them can afford it."},
			{"speaker": "ish", "text": "Guruji used to say a fist is only as good as what it protects. I never knew what mine was for."},
			{"speaker": "", "text": "Then the letter came. The same one, sealed, to all six of the master's old students.",
				"banner": {"eyebrow": "AN INVITATION", "title": "ANANTA", "subtitle": "A TOURNAMENT OF MASTERS", "red": true}},
			{"speaker": "", "text": "\"The strongest shall claim a reward of NPR 5 crore. The final victor shall discover the whereabouts of the missing Master.\""},
			{"speaker": "ish", "text": "Five crore. A doctor. A painter. A runner. That's what my hands are for."},
		],
		"chapters": {
			"bib": {
				"intro": [
					{"speaker": "bib", "text": "Agasthya... you were always the brave one. I'm only here to stop being scared."},
					{"speaker": "ish", "text": "Then don't be scared of me. Fight me like you mean it."},
				],
				"victory": [
					{"speaker": "bib", "text": "I didn't run. That's... a first."},
					{"speaker": "ish", "text": "Keep that. It's worth more than winning."},
				],
				"defeat": [{"speaker": "bib", "text": "Sorry... I think I just got brave."}],
			},
			"abhi": {
				"intro": [
					{"speaker": "abhi", "text": "The Flash Hammer! Fighting for strangers now? Very noble. Very loud of you."},
					{"speaker": "ish", "text": "They're not strangers, Kri. They're my neighbours."},
				],
				"victory": [{"speaker": "abhi", "text": "Fine. Buy your neighbours a good dinner on me."}],
				"defeat": [{"speaker": "abhi", "text": "Noble AND slow? Again!"}],
			},
			"anug": {
				"intro": [
					{"speaker": "anug", "text": "You want the money for other people too, don't you? I can see it."},
					{"speaker": "ish", "text": "Every kid with a dream and no money. Same as yours, keeper."},
					{"speaker": "anug", "text": "Then only one of us can carry it. Come on."},
				],
				"victory": [{"speaker": "anug", "text": "Carry it for both of us, then."}],
				"defeat": [{"speaker": "anug", "text": "Saved. Your heart's right. Your guard's not."}],
			},
			"sab": {
				"intro": [
					{"speaker": "sab", "text": "Ah, the saviour of the tea stall. Did you bring me a cup?"},
					{"speaker": "ish", "text": "Get up and fight, Mahabali. For once in your life."},
					{"speaker": "sab", "text": "For once in my life? Now you've made it personal."},
				],
				"victory": [{"speaker": "sab", "text": "Good. Now go and change some lives. I'll watch. Lying down, probably."}],
				"defeat": [{"speaker": "sab", "text": "See? Even I get up sometimes. Your turn."}],
			},
			"sup": {
				"intro": [
					{"speaker": "sup", "text": "My family needs this, Agasthya."},
					{"speaker": "ish", "text": "So does mine. A whole street of it."},
				],
				"victory": [{"speaker": "sup", "text": "...Then make it count. For all of them."}],
				"defeat": [{"speaker": "sup", "text": "Too fast for your own good. Breathe, and come again."}],
			},
			"anant": {
				"intro": [
					{"speaker": "", "text": "The final opponent waits. And Agasthya knows him at once."},
					{"speaker": "ish", "text": "Guruji. All these years... and you were the one who called us."},
					{"speaker": "anant", "text": "Show me what your hands are for, Agasthya."},
				],
				"victory": [],
				"defeat": [{"speaker": "anant", "text": "Fast. Not yet wise. Again."}],
			},
		},
		"finale": [
			{"speaker": "", "text": "When it was over, Ananta told him the truth: the final he lost, the shame, the years in hiding, the five crore he could not bring himself to spend.",
				"set": "ananta_ground", "cast": {"player": {"at": "log_left", "face": "log_right"}, "anant": {"fighter": "anant", "at": "log_right", "face": "player"}}, "shot": "wide"},
			{"speaker": "anant", "text": "It was meant for whichever of you would use it best."},
			{"speaker": "ish", "text": "Then it isn't mine. It belongs to a doctor, a painter and a runner who never got the chance."},
			{"speaker": "anant", "text": "I taught you to hit fast. You learned what to hit for. That I never taught."},
			{"speaker": "", "text": "A month later, at the same roadside stall, a boy opened his first medical book.", "shot": "two"},
			{"speaker": "", "text": "THE END.", "shot": "wide"},
		],
	},
	# Vajraveer: the most athletic of the six, and the most afraid. He has
	# never taken a risk in his life; he enters to face his own fear.
	"bib": {
		"title": "THE ENDLESS RUSH",
		"subtitle": "THE STORY OF VAJRAVEER",
		"finale_title": "NO MORE RUNNING",
		"cinematic": true,
		"still": true,
		"ladder": ["anug", "abhi", "ish", "sab", "sup", "anant"],
		"prologue": [
			{"speaker": "", "text": "Before sunrise, while the city sleeps, Vajraveer trains alone on a rooftop.",
				"set": "rooftop", "cast": {"player": {"at": "center", "face": [0, -1]}}, "shot": "wide"},
			{"speaker": "", "text": "He can run all day. He can kick higher than anyone Guruji ever trained. Nobody has ever seen it."},
			{"speaker": "bib", "text": "Fights, trials, tournaments... I always find a reason not to go. What if I freeze? What if they laugh?"},
			{"speaker": "", "text": "So he stays where it is safe. And every year, he stays exactly who he was."},
			{"speaker": "", "text": "Then a letter slid under his door.",
				"banner": {"eyebrow": "AN INVITATION", "title": "ANANTA", "subtitle": "A TOURNAMENT OF MASTERS", "red": true}},
			{"speaker": "", "text": "Six names. His own among them. And the whereabouts of the master who once told him he was ready."},
			{"speaker": "bib", "text": "My hands are shaking. That's how I know I have to go."},
			{"speaker": "bib", "text": "Not for the money. For once, I'm not going to run from it."},
		],
		"chapters": {
			"anug": {
				"intro": [
					{"speaker": "anug", "text": "Vajraveer? You actually came? You never came to anything."},
					{"speaker": "bib", "text": "I know. That's why I'm here. Please... don't go easy on me."},
				],
				"victory": [{"speaker": "anug", "text": "Where have you been hiding THAT for ten years?"}],
				"defeat": [{"speaker": "anug", "text": "You flinched. Don't. You're better than you think."}],
			},
			"abhi": {
				"intro": [
					{"speaker": "abhi", "text": "Look who left his room! Say something, quiet one! The crowd wants a speech!"},
					{"speaker": "bib", "text": "...I'll let my feet talk."},
				],
				"victory": [{"speaker": "abhi", "text": "Okay. That was a speech. A loud one."}],
				"defeat": [{"speaker": "abhi", "text": "Too quiet! Again, and louder this time!"}],
			},
			"ish": {
				"intro": [
					{"speaker": "ish", "text": "You were always faster than me in training. You just never believed it."},
					{"speaker": "bib", "text": "Today I'm trying to."},
				],
				"victory": [{"speaker": "ish", "text": "Believe it now. You earned that one."}],
				"defeat": [{"speaker": "ish", "text": "You stopped trusting your legs halfway. Don't."}],
			},
			"sab": {
				"intro": [
					{"speaker": "sab", "text": "Our little hermit! If you win, will you finally come to my birthday?"},
					{"speaker": "bib", "text": "If I win... yes. I'll come."},
					{"speaker": "sab", "text": "Ha! Now I have to lose on purpose. Just kidding. Come at me."},
				],
				"victory": [{"speaker": "sab", "text": "Saturday. Seven o'clock. Don't you dare hide."}],
				"defeat": [{"speaker": "sab", "text": "Nope. You're not getting out of my birthday that easily. Up."}],
			},
			"sup": {
				"intro": [
					{"speaker": "sup", "text": "Race you to the end of this?"},
					{"speaker": "bib", "text": "I've raced only myself for years. Let's see what happens with a real rival."},
				],
				"victory": [{"speaker": "sup", "text": "You weren't running away this time. I could feel it."}],
				"defeat": [{"speaker": "sup", "text": "Climb, don't race. You'll get there."}],
			},
			"anant": {
				"intro": [
					{"speaker": "", "text": "The final fight. The opponent steps forward, and Vajraveer's breath stops."},
					{"speaker": "bib", "text": "Guruji... you told me I was ready. And then you were gone."},
					{"speaker": "anant", "text": "You were ready then. Are you brave enough now?"},
				],
				"victory": [],
				"defeat": [{"speaker": "anant", "text": "You held back the last step. Again. Take it this time."}],
			},
		},
		"finale": [
			{"speaker": "", "text": "Afterwards, the master told him why he left: one lost final, a whole country's laughter, and a shame he could not face.",
				"set": "ananta_ground", "cast": {"player": {"at": "log_left", "face": "log_right"}, "anant": {"fighter": "anant", "at": "log_right", "face": "player"}}, "shot": "wide"},
			{"speaker": "bib", "text": "So you ran too. Just like me."},
			{"speaker": "anant", "text": "For years. You stopped running today. Which of us is the master now?"},
			{"speaker": "bib", "text": "Then let's stop together. Come back with me, Guruji."},
			{"speaker": "", "text": "That Saturday, Vajraveer walked into a crowded birthday party. And stayed until the very end.", "shot": "two"},
			{"speaker": "", "text": "THE END.", "shot": "wide"},
		],
	},
	# Mahabali: strong enough to win everything and too lazy to try. He jokes
	# and teases, but every jab is a push: he wants everyone he meets to
	# succeed and be happy. At last he decides to use his own strength.
	"sab": {
		"title": "THE LAZY GIANT",
		"subtitle": "THE STORY OF MAHABALI",
		"finale_title": "GET UP, MAHABALI",
		"cinematic": true,
		"still": true,
		"ladder": ["bib", "anug", "abhi", "ish", "sup", "anant"],
		"prologue": [
			{"speaker": "", "text": "In his village, everyone knows Mahabali. Mostly lying on a rope bed under the pipal tree.",
				"set": "village_tree", "cast": {"player": {"at": "cot", "face": "camera"}}, "shot": "wide"},
			{"speaker": "", "text": "He is the strongest of the master's six students. And the laziest."},
			{"speaker": "sab", "text": "Work? Today? The tree is giving me shade. It would be rude to leave."},
			{"speaker": "", "text": "But his teasing has a habit of changing lives. The boy he called 'too slow' now runs for the district. The girl he said 'could never pass' topped her exams."},
			{"speaker": "sab", "text": "Me? I didn't do anything. I just talk too much."},
			{"speaker": "", "text": "Then the letter came, and for the first time in years, Mahabali sat up.",
				"banner": {"eyebrow": "AN INVITATION", "title": "ANANTA", "subtitle": "A TOURNAMENT OF MASTERS", "red": true}},
			{"speaker": "sab", "text": "Guruji's whereabouts... and all my old friends, in one place. Fighting."},
			{"speaker": "sab", "text": "Everyone I've ever pushed has climbed higher than me. Maybe it's time I pushed myself."},
		],
		"chapters": {
			"bib": {
				"intro": [
					{"speaker": "sab", "text": "Vajraveer! Out of your shell! Who are you and what have you done with my shy friend?"},
					{"speaker": "bib", "text": "I'm facing my fears today. You're the first one."},
					{"speaker": "sab", "text": "Wonderful. I'll be very scary, then."},
				],
				"victory": [{"speaker": "sab", "text": "You came out. That's the real win. I just got the points."}],
				"defeat": [{"speaker": "bib", "text": "You let me win... didn't you?"}],
			},
			"anug": {
				"intro": [
					{"speaker": "anug", "text": "You, standing? This tournament really is special."},
					{"speaker": "sab", "text": "Don't get used to it, keeper."},
				],
				"victory": [{"speaker": "anug", "text": "Lazy, my foot. You've been hiding this."}],
				"defeat": [{"speaker": "anug", "text": "Nothing gets past me. Not even you, giant."}],
			},
			"abhi": {
				"intro": [
					{"speaker": "abhi", "text": "The only man in Nepal louder than me!"},
					{"speaker": "sab", "text": "Louder AND stronger. Let's settle the first one quickly."},
				],
				"victory": [{"speaker": "abhi", "text": "Fine! But I'm still funnier."}],
				"defeat": [{"speaker": "abhi", "text": "Too much talking, Mahabali. Not enough punching."}],
			},
			"ish": {
				"intro": [
					{"speaker": "ish", "text": "You actually want this? I thought you'd sleep through the whole tournament."},
					{"speaker": "sab", "text": "I tried. The fights kept waking me up."},
				],
				"victory": [{"speaker": "ish", "text": "Use it well, giant. You always told us to."}],
				"defeat": [{"speaker": "ish", "text": "Too slow, Mahabali. You'd tease anyone else for that."}],
			},
			"sup": {
				"intro": [
					{"speaker": "", "text": "Two old friends. One fight. Neither can afford to lose.",
						"banner": {"eyebrow": "THE FIGHT BETWEEN FRIENDS", "title": "SARVOCHCHA", "subtitle": "BROTHERS IN TRAINING"}},
					{"speaker": "sup", "text": "It's been a long time, hasn't it?"},
					{"speaker": "sab", "text": "Too long. And you still drop your left hand when you're tired. I'll be kind and only use it a little."},
				],
				"victory": [
					{"speaker": "sab", "text": "Get up, brother. You taught me to stop being lazy just by never stopping."},
					{"speaker": "sup", "text": "...I'll see you again, my friend."},
				],
				"defeat": [{"speaker": "sup", "text": "Guruji never let us stop halfway. Neither will I."}],
			},
			"anant": {
				"intro": [
					{"speaker": "", "text": "The last opponent waits in silence. Mahabali stops joking."},
					{"speaker": "sab", "text": "...Guruji."},
					{"speaker": "anant", "text": "The strongest of my students. Finally standing up."},
					{"speaker": "sab", "text": "You always said I'd only fight when it really mattered. It matters now."},
				],
				"victory": [],
				"defeat": [{"speaker": "anant", "text": "Strength without effort. Again, and mean it."}],
			},
		},
		"finale": [
			{"speaker": "", "text": "When it was over, the master told him the truth: the final he lost, the shame, the years in hiding, the five crore saved for one of his students.",
				"set": "ananta_ground", "cast": {"player": {"at": "log_left", "face": "log_right"}, "anant": {"fighter": "anant", "at": "log_right", "face": "player"}}, "shot": "wide"},
			{"speaker": "sab", "text": "You lost one fight and hid for years. I won nothing and lay under a tree for years. We're quite a pair, Guruji."},
			{"speaker": "anant", "text": "And yet everyone you teased became something. You were teaching all along."},
			{"speaker": "sab", "text": "Then let's build a training hall. I'll do the teasing. You do the teaching."},
			{"speaker": "", "text": "The rope bed under the pipal tree stayed empty after that. Mostly.", "shot": "two"},
			{"speaker": "", "text": "THE END.", "shot": "wide"},
		],
	},
	# Ananta: the master's own story. An international final lost in front of
	# the whole country, years of shame and hiding in a remote village, five
	# crore he could never spend, and the tournament he made to find which of
	# his six students had truly earned it. His last opponent is Sarvochcha.
	"anant": {
		"title": "THE FINAL WORD",
		"subtitle": "THE STORY OF ANANTA",
		"finale_title": "THE STRENGTH HE LEFT BEHIND",
		"cinematic": true,
		"still": true,
		"prologue_arena": 0,
		"ladder": ["bib", "abhi", "anug", "ish", "sab", "sup"],
		"prologue": [
			{"speaker": "", "text": "Years ago, Ananta stood in an international final, with the whole of Nepal watching.",
				"set": "final_ring", "cast": {"player": {"at": "ring", "face": [1, 0]}}, "shot": "wide"},
			{"speaker": "", "text": "He was winning. One round from glory, he dropped his guard to celebrate before the bell."},
			{"speaker": "", "text": "One mistake. One punch. The crowd went silent, and then it laughed.",
				"banner": {"eyebrow": "INTERNATIONAL FINAL", "title": "DEFEAT", "subtitle": "ONE MISTAKE BEFORE THE BELL", "red": true}},
			{"speaker": "anant", "text": "In the streets they said my name like a joke. I could not look my own students in the eye."},
			{"speaker": "", "text": "So he disappeared. A stone hut, high in a remote village, far from anyone who knew him.",
				"set": "goth", "cast": {"player": {"at": "door", "face": "camera"}}, "shot": "wide"},
			{"speaker": "", "text": "For years he kept the prize money from that last tournament: five crore. He never spent a rupee of it."},
			{"speaker": "anant", "text": "This money belongs to someone who deserves it. One of them. But which?"},
			{"speaker": "", "text": "So he wrote six letters, one to each of his old students, and signed them with a single word.",
				"banner": {"eyebrow": "SIX LETTERS", "title": "ANANTA", "subtitle": "A TOURNAMENT OF MASTERS", "red": true}},
			{"speaker": "anant", "text": "I will test each of them myself. Every lesson I ever taught. Let them show me what remains."},
		],
		"chapters": {
			"bib": {
				"intro": [
					{"speaker": "", "text": "First, the quiet one. The one who never came to anything."},
					{"speaker": "bib", "text": "...Guruji? You're alive?"},
					{"speaker": "anant", "text": "You came. That is already more than I expected. Now fight."},
				],
				"victory": [{"speaker": "anant", "text": "He held nothing back. The boy who never took a risk just took the biggest one."}],
				"defeat": [{"speaker": "bib", "text": "I... I beat you? Then come back, Guruji. Please."}],
			},
			"abhi": {
				"intro": [
					{"speaker": "abhi", "text": "GURUJI! The legend returns! The crowd will go wild!"},
					{"speaker": "anant", "text": "The crowd is what drove me away, Kri. Let us see if you fight louder than you talk."},
				],
				"victory": [{"speaker": "anant", "text": "Still all noise. But a good heart under it."}],
				"defeat": [{"speaker": "abhi", "text": "Ha! Don't worry. I won't tell anyone. Loudly."}],
			},
			"anug": {
				"intro": [
					{"speaker": "anug", "text": "Hands up, chin down. I teach it every week. Your words, Guruji."},
					{"speaker": "anant", "text": "Then show me the keeper's guard."},
				],
				"victory": [{"speaker": "anant", "text": "He guards other people's dreams better than his own."}],
				"defeat": [{"speaker": "anug", "text": "Nothing gets past me. Not even you."}],
			},
			"ish": {
				"intro": [
					{"speaker": "ish", "text": "All these years, and you send a letter? People needed you, Guruji."},
					{"speaker": "anant", "text": "I know. Show me who you fight for."},
				],
				"victory": [{"speaker": "anant", "text": "Fast hands, and a whole street behind them. Good."}],
				"defeat": [{"speaker": "ish", "text": "Is this what you wanted to see? Then watch closely."}],
			},
			"sab": {
				"intro": [
					{"speaker": "sab", "text": "Guruji! I got off my rope bed for you. Be impressed."},
					{"speaker": "anant", "text": "I am. Now get off it for good."},
				],
				"victory": [{"speaker": "anant", "text": "The laziest strength I ever trained. And the kindest."}],
				"defeat": [{"speaker": "sab", "text": "I got up, Guruji. And I'm staying up."}],
			},
			"sup": {
				"intro": [
					{"speaker": "", "text": "The last letter. The last student. The one who reminds him most of himself.",
						"banner": {"eyebrow": "FINAL CHAPTER", "title": "SARVOCHCHA", "subtitle": "THE STUDENT"}},
					{"speaker": "sup", "text": "MASTER?!"},
					{"speaker": "anant", "text": "No words, Sarvochcha. Not yet. Show me everything I taught you."},
				],
				"victory": [],
				"defeat": [{"speaker": "anant", "text": "Again. You still drop your left hand. Again."}],
			},
		},
		"finale": [
			{"speaker": "", "text": "Sarvochcha fell. And got up. And fell. And got up again.",
				"set": "ananta_ground", "cast": {"player": {"at": "log_right", "face": "log_left"}, "sup": {"fighter": "sup", "at": "log_left", "face": "player"}}, "shot": "wide"},
			{"speaker": "anant", "text": "That is what I never did. After one defeat, I never got up."},
			{"speaker": "sup", "text": "Master... where have you been all these years?"},
			{"speaker": "anant", "text": "Hiding from one mistake. The five crore was never the prize, Sarvochcha. You are."},
			{"speaker": "anant", "text": "Everything I taught, they carried. Patience. Courage. Kindness. Even laziness, used well."},
			{"speaker": "anant", "text": "A master's greatest victory is not the battles he wins. It is the strength he leaves behind."},
			{"speaker": "", "text": "The next morning, Ananta walked down into the city. As himself.", "shot": "two"},
			{"speaker": "", "text": "THE END.", "shot": "wide"},
		],
	},
	# Kri: the unknown newcomer nobody recognises, loud and fearless. Only
	# after beating Ananta does he reveal who he was: the last student in
	# Guruji's class, the one who knew nothing, whom the master never once
	# made to feel ashamed. He trained alone for years, to show others that
	# the past is not the whole journey.
	"abhi": {
		"title": "THE UNKNOWN",
		"subtitle": "THE STORY OF KRI",
		"finale_title": "LOCK IN",
		"cinematic": true,
		"still": true,
		"ladder": ["anug", "ish", "bib", "sab", "sup", "anant"],
		"prologue": [
			{"speaker": "", "text": "Late at night, under a single street lamp, a fighter nobody knows trains alone.",
				"set": "street", "cast": {"player": {"at": "lamp", "face": [1, 0.4]}},
				"do": [{"who": "player", "pose": "jab", "repeat": 1.2, "delay": 0.2}], "shot": "wide"},
			{"speaker": "", "text": "No coach. No crowd. The same strike, a thousand times, until it is right."},
			{"speaker": "", "text": "A letter lies open on the bench. Six names. One of them is his.",
				"banner": {"eyebrow": "AN INVITATION", "title": "ANANTA", "subtitle": "A TOURNAMENT OF MASTERS", "red": true}},
			{"speaker": "abhi", "text": "They won't remember me. Good. Let them meet who I am now."},
			{"speaker": "", "text": "And so, at the tournament, the loudest voice belongs to a stranger.", "shot": "hero"},
			{"speaker": "abhi", "text": "The name's Kri. Remember it. You'll be hearing it a lot."},
		],
		"chapters": {
			"anug": {
				"intro": [
					{"speaker": "anug", "text": "Kri? I don't know you. Were you even one of us?"},
					{"speaker": "abhi", "text": "Keep your gloves up, keeper. You'll know me soon enough."},
				],
				"victory": [{"speaker": "anug", "text": "Where did you come from? Nobody fights like that out of nowhere."}],
				"defeat": [{"speaker": "anug", "text": "Loud. Fast. Not enough. Who ARE you?"}],
			},
			"ish": {
				"intro": [
					{"speaker": "ish", "text": "You talk a lot for a man nobody's heard of."},
					{"speaker": "abhi", "text": "I spent years being quiet. I'm making up for it."},
				],
				"victory": [{"speaker": "ish", "text": "...I feel like I've seen that guard before. Somewhere."}],
				"defeat": [{"speaker": "ish", "text": "Talk less. Train more. Come back."}],
			},
			"bib": {
				"intro": [
					{"speaker": "bib", "text": "You're not scared at all, are you?"},
					{"speaker": "abhi", "text": "I was scared for years. Then I got tired of it. Want to try?"},
				],
				"victory": [{"speaker": "bib", "text": "Tired of being scared... I'll remember that."}],
				"defeat": [{"speaker": "bib", "text": "Sorry. I think you inspired me a little too much."}],
			},
			"sab": {
				"intro": [
					{"speaker": "sab", "text": "Finally, someone louder than me! I hate it. Who are you?"},
					{"speaker": "abhi", "text": "Someone you used to tease, maybe. You wouldn't remember."},
					{"speaker": "sab", "text": "Then I owe you an apology. After I win."},
				],
				"victory": [{"speaker": "sab", "text": "Fine. Apology first, then. Whoever you are, well fought."}],
				"defeat": [{"speaker": "sab", "text": "You fight angry, stranger. Fight hungry instead."}],
			},
			"sup": {
				"intro": [
					{"speaker": "sup", "text": "You trained alone, didn't you? I can see it. Nobody ever corrected your stance."},
					{"speaker": "abhi", "text": "Somebody did, once. A long time ago."},
				],
				"victory": [{"speaker": "sup", "text": "...You hold your left hand exactly like Guruji taught us."}],
				"defeat": [{"speaker": "sup", "text": "Strong. But you still fight like you have something to prove."}],
			},
			"anant": {
				"intro": [
					{"speaker": "", "text": "The final opponent steps forward. Kri goes quiet for the first time in the whole tournament."},
					{"speaker": "anant", "text": "Hands up. Chin down."},
					{"speaker": "abhi", "text": "...Every day, Guruji. Every single day."},
				],
				"victory": [],
				"defeat": [{"speaker": "anant", "text": "Again. You were never slow. Only unsure. Again."}],
			},
		},
		"finale": [
			{"speaker": "", "text": "Ananta looked at the stranger who had beaten him, and slowly, he understood.",
				"set": "ananta_ground", "cast": {"player": {"at": "log_left", "face": "log_right"}, "anant": {"fighter": "anant", "at": "log_right", "face": "player"}}, "shot": "wide"},
			{"speaker": "anant", "text": "...Kri. The boy at the back of the class."},
			{"speaker": "abhi", "text": "The last one. Last to arrive, last to learn, last at everything. I didn't know anything, Guruji."},
			{"speaker": "abhi", "text": "The others laughed. You never did. Not once. You just said: again."},
			{"speaker": "abhi", "text": "When you left, I kept saying it to myself. Every night, alone. Again. Again."},
			{"speaker": "anant", "text": "And I hid for years, because of one defeat."},
			{"speaker": "abhi", "text": "Then hear what you taught me. Your past doesn't describe your whole journey."},
			{"speaker": "abhi", "text": "It's just a time. A time when you lock in on what you want to be."},
			{"speaker": "", "text": "Kri opened a small hall on that same street. Its first class was full, and nobody had to stand at the back.", "shot": "two"},
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
