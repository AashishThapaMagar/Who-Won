extends Node
## One persistent soundtrack, starting with the studio splash and continuing
## across scene changes. Music routes through Master for the existing slider.
const TRACK := "res://assets/audio/music/game_intro_1.mp3"
var player: AudioStreamPlayer
const BASE_VOLUME_DB := -10.0
## An arena with music of its own (stage index as in nepal_stage_3d ROUNDS)
## crossfades to it for the fight and back to the soundtrack after.
const ARENA_TRACKS := {
	0: "res://assets/audio/music/heritage_square.ogg",   # calm: sarangi, bansuri, madal
	5: "res://assets/audio/music/dashain_ground.ogg",    # Kung Fu Hustle-style chase
}
const CROSSFADE := 1.8
const SILENT_DB := -60.0
var arena_player: AudioStreamPlayer
## The player now heard (the soundtrack or the arena's).
var active: AudioStreamPlayer
var _arena_path := ""
var _fades: Array[Tween] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, "Music")
		AudioServer.set_bus_send(index, "Master")
	var stream: AudioStreamMP3
	if FileAccess.file_exists(TRACK + ".import"):
		stream = load(TRACK) as AudioStreamMP3
	else:
		# Play immediately even before the editor has imported the new asset.
		stream = AudioStreamMP3.new()
		stream.data = FileAccess.get_file_as_bytes(TRACK)
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
	var path: String = ARENA_TRACKS.get(stage, "")
	if path == _arena_path:
		return
	_arena_path = path
	if path == "":
		_crossfade(player)
		return
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		_crossfade(player)
		return
	if "loop" in stream:
		stream.loop = true
	if arena_player == null:
		arena_player = AudioStreamPlayer.new()
		arena_player.name = "ArenaMusic"
		arena_player.bus = "Music"
		arena_player.volume_db = SILENT_DB
		add_child(arena_player)
	arena_player.stream = stream
	arena_player.volume_db = SILENT_DB
	arena_player.play()
	_crossfade(arena_player)

## Back to the soundtrack (menus, story, another arena).
func play_main() -> void:
	play_arena(-1)

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
		# The arena's music stops once it is silent; the soundtrack keeps its
		# place so it carries on where it was.
		if from == arena_player:
			fade_out.tween_callback(arena_player.stop)
		_fades.append(fade_out)

func duck_for_voice(speaking: bool, delta: float, recording := false) -> void:
	if active != null:
		if recording:
			active.volume_db = -80.0
			return
		active.volume_db = lerpf(active.volume_db, BASE_VOLUME_DB - 8.0 if speaking else BASE_VOLUME_DB, 1.0 - exp(-8.0 * delta))
