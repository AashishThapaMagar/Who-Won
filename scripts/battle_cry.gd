extends Node
## Autoload "BattleCry": each player's own recorded shouts.
##
## Recorded on character select (the buttons under LOCK IN). Every take a
## player records is kept, up to MAX_TAKES each, in
## user://battle_cries/p1_0.wav, p1_1.wav ... and in a fight one of them, at
## random (never the same twice running), is shouted when that player throws
## a big move (drive, breaker, combo finisher, super) and when they take a
## round.
##
## Call from anywhere: preload("res://scripts/battle_cry.gd").fire(0)
const MAX_SECONDS := 1.6
const MAX_TAKES := 8
const FOLDER := "user://battle_cries/"
## Moves that earn a shout; supers and round wins always do.
const BIG_MOVES := ["drive", "breaker", "combo_finish", "finisher"]
## Least time between two shouts by the same player, so it stays special.
const COOLDOWN := 2.5
const VOLUME_DB := 2.0

signal changed(player: int)

var recording_player := -1
## Per player, every take they recorded (AudioStreamWAV), oldest first.
var cries: Array = [[], []]
var _record: AudioEffectRecord
var _mic: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _stop_at := 0.0
var _last_shout: Array[float] = [-100.0, -100.0]
var _last_take: Array[int] = [-1, -1]

## Shout through the autoload if it exists (safe in any context).
static func fire(player: int, always := false) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var node := tree.root.get_node_or_null("BattleCry")
	if node != null:
		node.shout(player, always)

static func path(player: int, take: int) -> String:
	return FOLDER + "p%d_%d.wav" % [player + 1, take]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The mic plays into its own muted bus: recorded there, never heard live.
	var bus := AudioServer.get_bus_index("Record")
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Record")
	AudioServer.set_bus_mute(bus, true)
	_record = AudioEffectRecord.new()
	_record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, _record)
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = "Record"
	add_child(_mic)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	for i in 2:
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		voice.volume_db = VOLUME_DB
		add_child(voice)
		_voices.append(voice)
		# A cry from the one-take version becomes the first of the set.
		var old := "user://battle_cry_p%d.wav" % (i + 1)
		if FileAccess.file_exists(old) and not FileAccess.file_exists(path(i, 0)):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(old), ProjectSettings.globalize_path(path(i, 0)))
		for take in MAX_TAKES:
			if FileAccess.file_exists(path(i, take)):
				var stream := AudioStreamWAV.load_from_file(path(i, take))
				if stream != null:
					cries[i].append(stream)

## Whether the game can hear a microphone at all.
func available() -> bool:
	return bool(ProjectSettings.get_setting("audio/driver/enable_input", false))

func has_cry(player: int) -> bool:
	return not cries[player].is_empty()

func count(player: int) -> int:
	return cries[player].size()

## Seconds left on the take being recorded.
func time_left() -> float:
	return maxf(_stop_at - Time.get_ticks_msec() / 1000.0, 0.0) if recording_player >= 0 else 0.0

## Starts a take for `player`; it stops by itself after MAX_SECONDS.
func start(player: int) -> void:
	if recording_player >= 0 or not available():
		return
	recording_player = player
	_stop_at = Time.get_ticks_msec() / 1000.0 + MAX_SECONDS
	_mic.play()
	_record.set_recording_active(true)
	changed.emit(player)

func _process(_delta: float) -> void:
	if recording_player >= 0 and time_left() <= 0.0:
		stop()

## Ends the take and adds it to the player's cries (trimmed of the silence
## around the shout; the oldest goes once there are MAX_TAKES), then plays
## it back.
func stop() -> void:
	if recording_player < 0:
		return
	var player := recording_player
	recording_player = -1
	_record.set_recording_active(false)
	_mic.stop()
	var take := _trim(_record.get_recording())
	if take != null:
		var list: Array = cries[player]
		if list.size() >= MAX_TAKES:
			list.pop_front()
		list.append(take)
		_save(player)
		_play(player, list.size() - 1)
	changed.emit(player)

## Drops the player's newest take.
func clear(player: int) -> void:
	if cries[player].is_empty():
		return
	cries[player].pop_back()
	_save(player)
	changed.emit(player)

## Rewrites the player's files to match their list.
func _save(player: int) -> void:
	for take in MAX_TAKES:
		if FileAccess.file_exists(path(player, take)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path(player, take)))
	for take in cries[player].size():
		(cries[player][take] as AudioStreamWAV).save_to_wav(path(player, take))

func preview(player: int) -> void:
	shout(player, true)

## Plays one of `player`'s cries, picked at random but never the one just
## heard, unless they shouted a moment ago (`always` skips the wait, for
## supers, wins and previews).
func shout(player: int, always := false) -> void:
	if player < 0 or player > 1 or cries[player].is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not always and now - _last_shout[player] < COOLDOWN:
		return
	_last_shout[player] = now
	var size: int = cries[player].size()
	var pick := randi() % size
	if size > 1 and pick == _last_take[player]:
		pick = (pick + 1 + randi() % (size - 1)) % size
	_play(player, pick)

func _play(player: int, take: int) -> void:
	_last_take[player] = take
	_voices[player].stream = cries[player][take]
	_voices[player].play()

## The take cut to the shout itself: leading and trailing quiet removed,
## short fades so it doesn't click. Null when nothing was heard.
static func _trim(take: AudioStreamWAV) -> AudioStreamWAV:
	if take == null or take.data.size() < 4:
		return null
	var channels := 2 if take.stereo else 1
	var frame_bytes := 2 * channels
	var frames := take.data.size() / frame_bytes
	var threshold := 1200
	var first := -1
	var last := -1
	for i in frames:
		var level := absi(take.data.decode_s16(i * frame_bytes))
		if level > threshold:
			if first < 0:
				first = i
			last = i
	if first < 0:
		return null
	var pad := int(take.mix_rate * 0.04)
	first = maxi(first - pad, 0)
	last = mini(last + pad * 2, frames - 1)
	var data := take.data.slice(first * frame_bytes, (last + 1) * frame_bytes)
	var count := last - first + 1
	var fade := mini(int(take.mix_rate * 0.01), count / 2)
	for i in fade:
		for c in channels:
			var head := (i * channels + c) * 2
			var tail := ((count - 1 - i) * channels + c) * 2
			var k := float(i) / fade
			data.encode_s16(head, int(data.decode_s16(head) * k))
			data.encode_s16(tail, int(data.decode_s16(tail) * k))
	var cut := AudioStreamWAV.new()
	cut.format = AudioStreamWAV.FORMAT_16_BITS
	cut.mix_rate = take.mix_rate
	cut.stereo = take.stereo
	cut.data = data
	return cut
