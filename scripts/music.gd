extends Node
## One persistent soundtrack, starting with the studio splash and continuing
## across scene changes. Music routes through Master for the existing slider.
const TRACK := "res://assets/audio/music/game_intro_1.mp3"
var player: AudioStreamPlayer
const BASE_VOLUME_DB := -10.0

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

func duck_for_voice(active: bool, delta: float, recording := false) -> void:
	if player != null:
		if recording:
			player.volume_db = -80.0
			return
		player.volume_db = lerpf(player.volume_db, BASE_VOLUME_DB - 8.0 if active else BASE_VOLUME_DB, 1.0 - exp(-8.0 * delta))
