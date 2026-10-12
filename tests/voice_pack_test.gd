extends SceneTree
const VOICE := preload("res://scripts/voice_bank.gd")

func _initialize() -> void:
	call_deferred("run")

func sample(stereo := false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = stereo
	var channels := 2 if stereo else 1
	var bytes := PackedByteArray()
	bytes.resize(22050 * channels * 2)
	for frame in range(4410, 13230):
		# Stereo fixture has voice only in the right channel.
		bytes.encode_s16((frame * channels + channels - 1) * 2, int(sin(frame * 0.2) * 8000))
	wav.data = bytes
	return wav

func run() -> void:
	var mono := VOICE._trim(sample())
	var stereo := VOICE._trim(sample(true))
	assert(mono != null and stereo != null)
	assert(mono.get_length() < 0.7 and stereo.stereo)
	assert(mono.data.decode_s16(0) == 0)
	assert(stereo.data.decode_s16(stereo.data.size() - 2) == 0)
	var silent := sample()
	var quiet := silent.data
	quiet.fill(0)
	silent.data = quiet
	assert(VOICE._trim(silent) == null)
	var folder := "res://.godot/voice-test-%d/" % Time.get_ticks_usec()
	var bank := VOICE.new()
	bank.storage_folder = folder
	root.add_child(bank)
	bank.cries[0].append(mono)
	bank.banks[0]["victory"] = [stereo]
	bank.banks[0]["defeat"] = [mono]
	bank.banks[0]["move_ish_jab"] = [mono, stereo]
	# Exercise recorder controls with a synthetic source, never the microphone.
	bank._mic.stream = mono
	bank.start(0, "hit")
	assert(bank.recording_player == 0 and bank.recording_event == "hit")
	assert(bank.time_left() <= bank.duration("hit"))
	bank.cancel()
	assert(bank.recording_player == -1 and bank.count(0, "hit") == 0)
	assert(bank._save(0))
	assert(bank._save(0, "victory"))
	assert(bank._save(0, "defeat"))
	assert(bank._save(0, "move_ish_jab"))
	assert(bank.resolve_event(0, "victory") == "victory")
	assert(bank.resolve_event(0, "move_ish_drive") == "general")
	assert(bank.resolve_event(0, "hit").is_empty())
	assert(bank.resolve_event(1, "victory").is_empty())
	bank.preview(0, "move_ish_jab", 0)
	assert(bank._voices[0].stream == mono)
	bank._last_shout[0] = Time.get_ticks_msec() / 1000.0
	bank.shout(0, false, "victory")
	assert(bank._voices[0].stream == mono, "Cooldown prevents repeated lines")
	bank.shout(0, true, "victory")
	assert(bank._voices[0].stream == stereo, "Result priority replaces the previous line")
	bank.set_enabled(0, false)
	bank.shout(0, true, "defeat")
	assert(not bank._voices[0].playing)
	bank.set_level(0, 0.4)
	bank.free()
	var restored := VOICE.new()
	restored.storage_folder = folder
	root.add_child(restored)
	assert(restored.count(0) == 1 and restored.count(0, "move_ish_jab") == 2)
	assert(restored.count(0, "victory") == 1 and restored.count(0, "defeat") == 1)
	assert(restored.count(1) == 0)
	assert(not restored.enabled[0] and is_equal_approx(restored.levels[0], 0.4))
	restored.clear(0, "move_ish_jab")
	assert(restored.count(0, "move_ish_jab") == 1 and restored.count(0, "victory") == 1)
	restored.free()
	for filename in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(folder + filename))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	print("VOICE_PACK_TEST: ALL PASS")
	quit()
