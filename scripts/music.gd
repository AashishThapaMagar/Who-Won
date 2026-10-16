extends Node
## One persistent soundtrack, starting with the studio splash and continuing
## across scene changes. Music routes through Master for the existing slider.
## The menu, story and arena music is made with ElevenLabs Music
## (tools/compose_eleven_music.py); Supreme Khatiwada's theme plays over the
## end credits.
const TRACK := "res://assets/audio/music/menu_theme.ogg"
const STORY_TRACK := "res://assets/audio/music/story_theme.ogg"
const CREDITS_TRACK := "res://assets/audio/music/game_intro_1.mp3"
var player: AudioStreamPlayer
const BASE_VOLUME_DB := -10.0
## An arena with music of its own (stage index as in nepal_stage_3d ROUNDS)
## crossfades to it for the fight and back to the soundtrack after.
const ARENA_TRACKS := {
	0: "res://assets/audio/music/heritage_square.ogg",
	1: "res://assets/audio/music/terai_plains.ogg",
	2: "res://assets/audio/music/hill_village.ogg",
	3: "res://assets/audio/music/gompa_courtyard.ogg",
	4: "res://assets/audio/music/himalayan_pass.ogg",
	5: "res://assets/audio/music/dashain_ground.ogg",
}
const CROSSFADE := 1.8
const SILENT_DB := -60.0
## Two players for the arena, story and credits music, taking turns so one
## such track can crossfade into another.
var arena_player: AudioStreamPlayer
var _side_players: Array[AudioStreamPlayer] = []
## The player now heard (the soundtrack or the arena's).
var active: AudioStreamPlayer
var _arena_path := ""
var _fades: Array[Tween] = []
## True while the storybook narrator is reading (story_dialogue.gd).
var narrating := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, "Music")
		AudioServer.set_bus_send(index, "Master")
	var stream := _load(TRACK)
	if stream == null or stream.get_length() <= 0.0:
		push_error("Unable to load game soundtrack: " + TRACK)
		return
	stream.loop = true
	player = AudioStreamPlayer.new()
	player.name = "Soundtrack"
	player.bus = "Music"
	player.stream = stream
	player.volume_db = BASE_VOLUME_DB
	add_child(player)
	player.play()
	active = player

## The fight's arena: its own music if it has one, else the soundtrack.
func play_arena(stage: int) -> void:
	play_track(ARENA_TRACKS.get(stage, ""))

## The storybook's quiet theme, under the narrator.
func play_story() -> void:
	play_track(STORY_TRACK)

## Supreme Khatiwada's theme, for the end credits (once through).
func play_credits() -> void:
	play_track(CREDITS_TRACK, false)

## Back to the soundtrack (menus, another arena).
func play_main() -> void:
	play_track("")

## Crossfades to a track ("" is the soundtrack).
func play_track(path: String, loop := true) -> void:
	if path == _arena_path:
		return
	_arena_path = path
	var stream: AudioStream = _load(path) if path != "" else null
	if stream == null:
		_crossfade(player)
		return
	if "loop" in stream:
		stream.loop = loop
	if _side_players.is_empty():
		for i in 2:
			var side := AudioStreamPlayer.new()
			side.name = "TrackMusic%d" % i
			side.bus = "Music"
			side.volume_db = SILENT_DB
			add_child(side)
			_side_players.append(side)
	arena_player = _side_players[1] if active == _side_players[0] else _side_players[0]
	arena_player.stream = stream
	arena_player.volume_db = SILENT_DB
	arena_player.play()
	_crossfade(arena_player)

func _load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	# Play even before the editor has imported a new file.
	if FileAccess.file_exists(path):
		match path.get_extension().to_lower():
			"ogg":
				return AudioStreamOggVorbis.load_from_file(path)
			"mp3":
				return AudioStreamMP3.load_from_file(path)
	return null

func _crossfade(to: AudioStreamPlayer) -> void:
	if player == null:
		return
	for fade in _fades:
		if fade.is_valid():
			fade.kill()
	_fades.clear()
	var from := active
	active = to
	var fade_in := create_tween()
	fade_in.tween_property(to, "volume_db", BASE_VOLUME_DB, CROSSFADE).set_trans(Tween.TRANS_SINE)
	_fades.append(fade_in)
	if from != null and from != to:
		var fade_out := create_tween()
		fade_out.tween_property(from, "volume_db", SILENT_DB, CROSSFADE).set_trans(Tween.TRANS_SINE)
		# Other music stops once it is silent; the soundtrack keeps its
		# place so it carries on where it was.
		if from != player:
			fade_out.tween_callback(from.stop)
		_fades.append(fade_out)

func duck_for_voice(speaking: bool, delta: float, recording := false) -> void:
	if active != null:
		if recording:
			active.volume_db = -80.0
			return
		active.volume_db = lerpf(active.volume_db, BASE_VOLUME_DB - 8.0 if speaking or narrating else BASE_VOLUME_DB, 1.0 - exp(-8.0 * delta))
