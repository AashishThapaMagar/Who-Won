extends Control
## A voice pack editor, opened from either player's fighter-select panel.
const UI := preload("res://scripts/ui_kit.gd")
const MOVES := preload("res://scripts/action_moves.gd")
var player := 0
var profile: Dictionary
var bank: Node
var event := "general"
var event_keys: Array[String] = []
var picker: OptionButton
var mic_picker: OptionButton
var call_button: Button
var takes: OptionButton
var record_button: Button
var preview_button: Button
var undo_button: Button
var status_label: Label
var slot_label: Label
var timer_label: Label
var meter: ProgressBar
var timer: ProgressBar
var waveform: VoiceWaveform

class VoiceWaveform extends Control:
	var stream: AudioStreamWAV
	var tint := UI.GOLD
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("080b13"))
		draw_line(Vector2(0, size.y / 2), Vector2(size.x, size.y / 2), Color("303647"))
		if stream == null:
			return
		var data := stream.data
		if data.is_empty():
			return
		var channels := 2 if stream.stereo else 1
		var frames := data.size() / (channels * 2)
		for column in 160:
			var peak := 0.0
			var begin := int(float(column) / 160.0 * frames)
			var end := int(float(column + 1) / 160.0 * frames)
			for frame in range(begin, end, maxi(1, (end - begin) / 16)):
				for channel in channels:
					peak = maxf(peak, absf(float(data.decode_s16((frame * channels + channel) * 2))) / 32768.0)
			var x := (column + 0.5) * size.x / 160.0
			draw_line(Vector2(x, size.y * 0.5 - peak * size.y * 0.45), Vector2(x, size.y * 0.5 + peak * size.y * 0.45), tint, 2)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	bank = get_node("/root/BattleCry")
	var color := UI.GOLD if player == 0 else UI.VIOLET
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.9)
	add_child(shade)
	UI.panel(self, Vector2(136, 54), Vector2(688, 434), UI.INK, color)
	UI.label(self, "P%d / %s / VOICE PACK" % [player + 1, profile.name], Vector2(164, 72), Vector2(530, 20), 12, color)
	UI.heading(self, "VOICE STUDIO", Vector2(164, 96), Vector2(550, 44), 30)
	UI.label(self, "Choose a slot. Record, listen, then add variations.", Vector2(164, 146), Vector2(374, 24), 12, UI.MUTED)
	mic_picker = OptionButton.new()
	mic_picker.position = Vector2(552, 146)
	mic_picker.size = Vector2(240, 28)
	mic_picker.fit_to_longest_item = false
	mic_picker.clip_text = true
	mic_picker.add_theme_font_size_override("font_size", 11)
	for device in AudioServer.get_input_device_list():
		mic_picker.add_item("MIC / " + device)
		mic_picker.set_item_metadata(mic_picker.item_count - 1, device)
	if mic_picker.item_count == 0:
		mic_picker.add_item("NO MICROPHONE FOUND")
	mic_picker.item_selected.connect(func(index: int): bank.set_input_device(str(mic_picker.get_item_metadata(index))))
	add_child(mic_picker)
	picker = OptionButton.new()
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.position = Vector2(164, 185)
	picker.size = Vector2(376, 32)
	add_child(picker)
	for entry in [["general", "GENERAL / BATTLE CRY"], ["call_enemy", "TAUNT / CALL ENEMY"], ["hit", "REACTION / TAKING A HIT"], ["landed_hit", "REACTION / HIT LANDED"], ["super", "SUPER / SIGNATURE LINE"], ["victory", "RESULT / VICTORY"], ["defeat", "RESULT / DEFEAT"]]:
		_add_event(entry[0], entry[1])
	var moves := MOVES.for_fighter(str(profile.id))
	var keys := moves.keys()
	keys.sort()
	for key in keys:
		_add_event(bank.move_event(str(profile.id), str(key)), "MOVE / " + str(moves[key].name))
	picker.get_popup().max_size = Vector2i(620, 320)
	var call_slot := UI.button(self, "RECORD CALL", Vector2(652, 108), Vector2(140, 30))
	call_button = call_slot
	call_slot.tooltip_text = "Record your callout here; play it in a fight with T (P1) or U (P2)"
	call_slot.pressed.connect(func():
		if bank.recording_player < 0:
			picker.select(event_keys.find("call_enemy"))
			event = "call_enemy"
			bank.status = "Record your challenge. In fights: P1 T / P2 U, or the Call Enemy button."
			_refresh()
			bank.start(player, event))
	picker.item_selected.connect(func(index: int):
		event = event_keys[index]
		bank.status = "Choose Record Take to add a line for this slot."
		_refresh())
	slot_label = UI.label(self, "", Vector2(552, 190), Vector2(238, 24), 12, color)
	waveform = VoiceWaveform.new()
	waveform.position = Vector2(164, 232)
	waveform.size = Vector2(628, 60)
	waveform.tint = color
	add_child(waveform)
	meter = ProgressBar.new()
	meter.position = Vector2(164, 298)
	meter.size = Vector2(628, 6)
	meter.show_percentage = false
	meter.max_value = 1.0
	add_child(meter)
	timer_label = UI.label(self, "", Vector2(164, 311), Vector2(628, 20), 12, color)
	timer = ProgressBar.new()
	timer.position = Vector2(164, 335)
	timer.size = Vector2(628, 4)
	timer.show_percentage = false
	add_child(timer)
	# Compact meters should not inherit the text/padding height of a full bar.
	for bar in [meter, timer]:
		bar.add_theme_font_size_override("font_size", 1)
		for style in ["background", "fill"]:
			var box := UI.box(Color("202638") if style == "background" else color, Color.TRANSPARENT, 0)
			box.content_margin_top = 0
			box.content_margin_bottom = 0
			box.content_margin_left = 0
			box.content_margin_right = 0
			bar.add_theme_stylebox_override(style, box)
	meter.size.y = 6
	timer.size.y = 4
	record_button = UI.button(self, "RECORD", Vector2(164, 350), Vector2(144, 34), true)
	record_button.pressed.connect(func():
		if bank.recording_player >= 0:
			bank.stop()
		else:
			bank.start(player, event))
	takes = OptionButton.new()
	takes.position = Vector2(318, 350)
	takes.size = Vector2(140, 34)
	add_child(takes)
	takes.item_selected.connect(func(_index): _refresh_waveform())
	preview_button = UI.button(self, "PLAY TAKE", Vector2(468, 350), Vector2(150, 34))
	preview_button.pressed.connect(func(): bank.preview(player, event, takes.selected))
	undo_button = UI.button(self, "UNDO LAST", Vector2(628, 350), Vector2(164, 34))
	undo_button.pressed.connect(func(): bank.clear(player, event))
	undo_button.tooltip_text = "Remove only the newest recording in this slot"
	status_label = UI.label(self, "", Vector2(164, 390), Vector2(628, 30), 12, UI.MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var enabled := CheckButton.new()
	enabled.text = "IN-GAME VOICE"
	enabled.position = Vector2(158, 438)
	enabled.size = Vector2(198, 30)
	enabled.button_pressed = bank.enabled[player]
	enabled.toggled.connect(func(value: bool): bank.set_enabled(player, value))
	add_child(enabled)
	var volume := HSlider.new()
	volume.position = Vector2(368, 444)
	volume.size = Vector2(148, 20)
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = bank.levels[player]
	volume.tooltip_text = "Voice volume (also follows Sound Effects and Master Volume)"
	var volume_label := UI.label(self, "%d%%" % roundi(volume.value * 100), Vector2(524, 440), Vector2(54, 24), 12, color)
	volume.value_changed.connect(func(value: float): bank.set_level(player, value); volume_label.text = "%d%%" % roundi(value * 100))
	add_child(volume)
	var close := UI.button(self, "DONE / ESC", Vector2(634, 434), Vector2(158, 34))
	close.pressed.connect(close_studio)
	bank.changed.connect(_on_changed)
	_refresh()
	record_button.grab_focus()

func _add_event(key: String, label: String) -> void:
	event_keys.append(key)
	picker.add_item(label)

func _on_changed(_player: int) -> void:
	_refresh()

func _refresh() -> void:
	var live: bool = bank.recording_player >= 0
	var no_mic := AudioServer.get_input_device_list().is_empty()
	var count: int = bank.count(player, event)
	picker.disabled = live
	mic_picker.disabled = live or AudioServer.get_input_device_list().is_empty()
	for index in mic_picker.item_count:
		if mic_picker.get_item_metadata(index) == AudioServer.input_device:
			mic_picker.select(index)
	mic_picker.tooltip_text = "MICROPHONE: " + AudioServer.input_device
	call_button.disabled = live or not bank.available() or no_mic
	picker.tooltip_text = picker.get_item_text(picker.selected)
	takes.disabled = live or count == 0
	preview_button.disabled = live or count == 0
	undo_button.disabled = live or count == 0
	record_button.disabled = not bank.available() or no_mic or (count >= bank.MAX_TAKES and not live)
	record_button.text = "STOP & SAVE" if live else "RECORD TAKE"
	record_button.tooltip_text = "Stop and save this recording" if live else ("Slot full: Undo Last frees one take" if count >= bank.MAX_TAKES else "Speak immediately after pressing Record Take")
	slot_label.text = "%d / %d TAKES" % [count, bank.MAX_TAKES]
	takes.clear()
	for index in count:
		takes.add_item("TAKE %02d" % (index + 1))
	if count > 0:
		takes.select(count - 1)
	status_label.text = bank.status if bank.available() else "Microphone input is disabled. Enable audio input in the project to record."
	if no_mic:
		status_label.text = "No microphone found. Connect a mic and reopen Voice Studio."
	_refresh_waveform()

func _refresh_waveform() -> void:
	waveform.stream = bank.banks[player][event][takes.selected] if bank.has_cry(player, event) and takes.selected >= 0 else null
	waveform.queue_redraw()

func _process(_delta: float) -> void:
	var live: bool = bank.recording_player >= 0
	meter.value = bank.mic_level() if live else 0.0
	timer.max_value = bank.duration(event)
	timer.value = bank.duration(event) - bank.time_left() if live else 0.0
	timer_label.text = "● RECORDING  /  %.1f s LEFT" % bank.time_left() if live else "UP TO %.1f s  /  %s" % [bank.duration(event), "VARIATIONS PLAY AT RANDOM" if bank.count(player, event) > 1 else "SILENCE TRIMMED • VOLUME BALANCED"]

func close_studio() -> void:
	bank.cancel()
	queue_free()

func _exit_tree() -> void:
	if bank != null and bank.recording_player == player:
		bank.cancel()
