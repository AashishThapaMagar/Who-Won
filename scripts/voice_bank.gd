extends Node
## Persistent, event-specific voice packs for each player.
const MAX_SECONDS := 1.6
const MAX_TAKES := 8
const FOLDER := "user://battle_cries/"
const BIG_MOVES := ["drive", "breaker", "combo_finish", "finisher"]
const COOLDOWN := 1.2
const VOLUME_DB := 0.0
signal changed(player: int)
var recording_player := -1
var recording_event := "general"
var cries: Array = [[], []]
var banks: Array = [{}, {}]
var enabled: Array[bool] = [true, true]
var levels: Array[float] = [0.85, 0.85]
var status := "Choose a voice slot, then record a short line."
var storage_folder := FOLDER
var _record: AudioEffectRecord
var _mic: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _stop_at := 0.0
var _last_shout: Array[float] = [-100.0, -100.0]
var _last_take: Array = [{}, {}]
var _priority: Array[int] = [0, 0]
var _last_call: Array[float] = [-100.0, -100.0]
const CALL_COOLDOWN := 3.0
## Least time between two lines of the same kind from one player (s), and
## the chance a qualifying moment actually speaks: a voice on every jab is
## noise, a voice on the big moments is character.
## ("move" covers every signature-move shout.)
const EVENT_GAP := {"hit": 5.0, "landed_hit": 8.0, "move": 4.0}
const EVENT_CHANCE := {"landed_hit": 0.4}
var _last_event: Array = [{}, {}]
var _record_bus := -1

static func move_event(fighter: String, move: String) -> String:
	return "move_" + fighter + "_" + move

static func fire(player: int, always := false, event := "general") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node := tree.root.get_node_or_null("BattleCry")
		if node != null:
			node.shout(player, always, event)

static func path(player: int, take: int, event := "general", folder := FOLDER) -> String:
	return folder + ("p%d_%d.wav" % [player + 1, take] if event == "general" else "p%d@%s@%d.wav" % [player + 1, event, take])

func _path(player: int, take: int, event := "general") -> String:
	return path(player, take, event, storage_folder)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_record_bus = AudioServer.get_bus_index("Record")
	if _record_bus == -1:
		AudioServer.add_bus()
		_record_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_record_bus, "Record")
	AudioServer.set_bus_mute(_record_bus, true)
	_record = AudioEffectRecord.new()
	_record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(_record_bus, _record)
	_mic = AudioStreamPlayer.new()
	_mic.stream = AudioStreamMicrophone.new()
	_mic.bus = "Record"
	add_child(_mic)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(storage_folder))
	for player in 2:
		banks[player]["general"] = cries[player]
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(voice)
		_voices.append(voice)
		var old := "user://battle_cry_p%d.wav" % (player + 1)
		if storage_folder == FOLDER and FileAccess.file_exists(old) and not FileAccess.file_exists(_path(player, 0)):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(old), ProjectSettings.globalize_path(_path(player, 0)))
		for take in MAX_TAKES:
			_load_take(player, "general", _path(player, take))
	var files := DirAccess.get_files_at(storage_folder)
	files.sort()
	for filename in files:
		var parts := filename.trim_suffix(".wav").split("@")
		if filename.ends_with(".wav") and parts.size() == 3 and parts[0] in ["p1", "p2"]:
			_load_take(0 if parts[0] == "p1" else 1, parts[1], storage_folder + filename)
	var config := ConfigFile.new()
	if config.load(storage_folder + "voice.cfg") == OK:
		var device: String = config.get_value("input", "device", "Default")
		if device in AudioServer.get_input_device_list():
			AudioServer.input_device = device
		for player in 2:
			enabled[player] = config.get_value(str(player), "enabled", true)
			levels[player] = clampf(config.get_value(str(player), "level", 0.85), 0.0, 1.0)

func _load_take(player: int, event: String, filename: String) -> void:
	if not FileAccess.file_exists(filename):
		return
	var stream := AudioStreamWAV.load_from_file(filename)
	if stream != null and count(player, event) < MAX_TAKES:
		if not banks[player].has(event):
			banks[player][event] = []
		banks[player][event].append(stream)

func available() -> bool:
	return bool(ProjectSettings.get_setting("audio/driver/enable_input", false))

func count(player: int, event := "general") -> int:
	return banks[player].get(event, []).size()

func has_cry(player: int, event := "general") -> bool:
	return count(player, event) > 0

func total(player: int) -> int:
	var result := 0
	for list in banks[player].values():
		result += list.size()
	return result

## Recording length per slot (seconds): grunts short, lines with room.
const DURATIONS := {"hit": 1.0, "landed_hit": 1.2, "super": 3.5, "call_enemy": 3.0, "victory": 5.0, "defeat": 4.0}
const DEFAULT_SECONDS := 2.5

func duration(event: String) -> float:
	return float(DURATIONS.get(event, DEFAULT_SECONDS))

func time_left() -> float:
	return maxf(_stop_at - Time.get_ticks_msec() / 1000.0, 0.0) if recording_player >= 0 else 0.0

func mic_level() -> float:
	return clampf(db_to_linear(maxf(AudioServer.get_bus_peak_volume_left_db(_record_bus, 0), AudioServer.get_bus_peak_volume_right_db(_record_bus, 0))), 0.0, 1.0)

func start(player: int, event := "general") -> void:
	if player not in [0, 1] or recording_player >= 0 or not available():
		return
	if count(player, event) >= MAX_TAKES:
		status = "Slot is full. Remove a take before recording again."
		changed.emit(player)
		return
	for voice in _voices:
		voice.stop()
	recording_player = player
	recording_event = event
	_stop_at = Time.get_ticks_msec() / 1000.0 + duration(event)
	status = "Recording… speak now."
	var music := get_node_or_null("/root/Music")
	if music != null and music.has_method("duck_for_voice"):
		music.duck_for_voice(true, 0.0, true)
	_mic.play()
	_record.set_recording_active(true)
	changed.emit(player)

func _process(delta: float) -> void:
	if recording_player >= 0 and time_left() <= 0.0:
		stop()
	var music := get_node_or_null("/root/Music")
	if music != null and music.has_method("duck_for_voice"):
		music.duck_for_voice(_voices.any(func(voice): return voice.playing), delta, recording_player >= 0)

func stop() -> void:
	if recording_player < 0:
		return
	var player := recording_player
	var event := recording_event
	recording_player = -1
	_record.set_recording_active(false)
	_mic.stop()
	var take := _trim(_record.get_recording())
	if take == null:
		status = "No clear voice detected. Move closer to the mic and try again."
	else:
		if not banks[player].has(event):
			banks[player][event] = []
		var list: Array = banks[player][event]
		if list.size() >= MAX_TAKES:
			status = "Slot is full. Remove a take before recording again."
		else:
			list.append(take)
			status = "Take saved. Listen back or add a variation."
			if not _save(player, event):
				status = "Take kept for this session; could not save it to disk."
			_play(player, event, list.size() - 1)
	changed.emit(player)

func cancel() -> void:
	if recording_player < 0:
		return
	var player := recording_player
	recording_player = -1
	_record.set_recording_active(false)
	_mic.stop()
	status = "Recording cancelled."
	changed.emit(player)

func clear(player: int, event := "general") -> void:
	if recording_player >= 0 or not has_cry(player, event):
		return
	_voices[player].stop()
	banks[player][event].pop_back()
	_save(player, event)
	status = "Newest take removed from this slot."
	changed.emit(player)

func _save(player: int, event := "general") -> bool:
	var list: Array = banks[player].get(event, [])
	for take in list.size():
		if list[take].save_to_wav(_path(player, take, event)) != OK:
			return false
	for take in range(list.size(), MAX_TAKES):
		if FileAccess.file_exists(_path(player, take, event)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(player, take, event)))
	return true

func set_input_device(device: String) -> void:
	if recording_player >= 0 or device not in AudioServer.get_input_device_list():
		return
	AudioServer.input_device = device
	status = "Microphone selected. Record a short line, then play it back."
	_save_options()
	changed.emit(0)
	changed.emit(1)

func set_level(player: int, value: float) -> void:
	levels[player] = clampf(value, 0.0, 1.0)
	_voices[player].volume_db = -80.0 if value <= 0.0 else linear_to_db(levels[player])
	_save_options()

func set_enabled(player: int, value: bool) -> void:
	enabled[player] = value
	if not value:
		_voices[player].stop()
	_save_options()

func _save_options() -> void:
	var config := ConfigFile.new()
	config.set_value("input", "device", AudioServer.input_device)
	for player in 2:
		config.set_value(str(player), "enabled", enabled[player])
		config.set_value(str(player), "level", levels[player])
	config.save(storage_folder + "voice.cfg")

func _exit_tree() -> void:
	_mic.stop()
	_record.set_recording_active(false)
	for index in AudioServer.get_bus_effect_count(_record_bus):
		if AudioServer.get_bus_effect(_record_bus, index) == _record:
			AudioServer.remove_bus_effect(_record_bus, index)
			break

func preview(player: int, event := "general", take := -1) -> void:
	if recording_player >= 0 or not has_cry(player, event):
		return
	_play(player, event, _pick(player, event) if take < 0 else clampi(take, 0, count(player, event) - 1))

func resolve_event(player: int, event: String) -> String:
	if has_cry(player, event):
		return event
	# Legacy/general takes remain useful for signature moves, supers and wins.
	if (event == "super" or event == "victory" or (event.begins_with("move_") and BIG_MOVES.any(func(move): return event.ends_with("_" + move)))) and has_cry(player):
		return "general"
	return ""

func call_time_left(player: int) -> float:
	return maxf(0.0, CALL_COOLDOWN - (Time.get_ticks_msec() / 1000.0 - _last_call[player]))

func can_call_enemy(player: int) -> bool:
	if player not in [0, 1] or not enabled[player] or recording_player >= 0 or not has_cry(player, "call_enemy") or call_time_left(player) > 0.0:
		return false
	if _voices[player].playing and _priority[player] >= 2:
		return false
	return true

func call_enemy(player: int) -> bool:
	if not can_call_enemy(player):
		return false
	_last_call[player] = Time.get_ticks_msec() / 1000.0
	shout(player, true, "call_enemy")
	return true

func shout(player: int, always := false, event := "general") -> void:
	if player not in [0, 1] or not enabled[player] or recording_player >= 0:
		return
	var slot := resolve_event(player, event)
	if slot.is_empty():
		return
	var priority := 3 if event in ["victory", "defeat"] else (2 if event in ["super", "call_enemy"] else 1)
	var now := Time.get_ticks_msec() / 1000.0
	if not always:
		var kind := "move" if event.begins_with("move_") else event
		if now - float(_last_event[player].get(kind, -100.0)) < float(EVENT_GAP.get(kind, 0.0)):
			return
		if randf() > float(EVENT_CHANCE.get(kind, 1.0)):
			return
		# Taking a hit cuts off your own shout mid-word; nothing else does.
		var interrupts := event == "hit" and _priority[player] <= 1
		if not interrupts and (now - _last_shout[player] < COOLDOWN or (_voices[player].playing and _priority[player] >= priority)):
			return
	_last_event[player]["move" if event.begins_with("move_") else event] = now
	_last_shout[player] = now
	_priority[player] = priority
	_play(player, slot, _pick(player, slot))

func _pick(player: int, event: String) -> int:
	var size := count(player, event)
	var pick := randi() % size
	var previous: int = _last_take[player].get(event, -1)
	if size > 1 and pick == previous:
		pick = (pick + 1 + randi() % (size - 1)) % size
	return pick

func _play(player: int, event: String, take: int) -> void:
	_last_take[player][event] = take
	_voices[player].stream = banks[player][event][take]
	_voices[player].volume_db = -80.0 if levels[player] <= 0.0 else linear_to_db(levels[player])
	_voices[player].play()

static func _trim(take: AudioStreamWAV) -> AudioStreamWAV:
	if take == null or take.format != AudioStreamWAV.FORMAT_16_BITS:
		return null
	var source := take.data
	if source.size() < 4:
		return null
	var channels := 2 if take.stereo else 1
	var bytes := channels * 2
	var frames := source.size() / bytes
	var peak := 0
	for sample in source.size() / 2:
		peak = maxi(peak, absi(source.decode_s16(sample * 2)))
	if peak < 800:
		return null
	var threshold := maxi(300, int(peak * 0.08))
	var first := -1
	var last := -1
	for frame in frames:
		for channel in channels:
			if absi(source.decode_s16(frame * bytes + channel * 2)) >= threshold:
				if first < 0:
					first = frame
				last = frame
	if first < 0 or last - first < int(take.mix_rate * 0.04):
		return null
	first = maxi(0, first - int(take.mix_rate * 0.035))
	last = mini(frames - 1, last + int(take.mix_rate * 0.06))
	var data := source.slice(first * bytes, (last + 1) * bytes)
	var gain := minf(4.0, 23000.0 / peak)
	var count_frames := last - first + 1
	var fade := maxi(1, mini(int(take.mix_rate * 0.01), count_frames / 2))
	for frame in count_frames:
		var envelope := minf(1.0, minf(float(frame) / fade, float(count_frames - 1 - frame) / fade))
		for channel in channels:
			var at := frame * bytes + channel * 2
			data.encode_s16(at, clampi(int(data.decode_s16(at) * gain * envelope), -32767, 32767))
	var cut := AudioStreamWAV.new()
	cut.format = AudioStreamWAV.FORMAT_16_BITS
	cut.mix_rate = take.mix_rate
	cut.stereo = take.stereo
	cut.data = data
	return cut
