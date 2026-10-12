extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func tone(value: int) -> AudioStreamWAV:
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(44100 * 3)
	for sample in data.size() / 2:
		data.encode_s16(sample * 2, value)
	clip.data = data
	return clip

func run() -> void:
	var setup := root.get_node("MatchSetup")
	setup.vs_ai = false
	setup.arcade = false
	setup.story = false
	setup.practice = false
	setup.selected_fighters.assign([0, 1])
	var bank := root.get_node("BattleCry")
	var move := tone(1000)
	var hit := tone(2000)
	var win := tone(3000)
	var lose := tone(4000)
	var call := tone(5000)
	bank.banks = [{"move_anug_jab": [move], "defeat": [lose], "call_enemy": [call]}, {"hit": [hit], "victory": [win]}]
	bank.enabled.assign([true, true])
	var arena: Node = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.intro_timer = 0
	arena._hide_banner()
	var hud: Node = arena.get_child(arena.get_child_count() - 1)
	assert(hud.call_buttons.size() == 2)
	assert(not hud.call_buttons[0].get_global_rect().intersects(hud.call_buttons[1].get_global_rect()), "Each player's call button has its own space")
	assert(hud.call_buttons[0].position.x < 400)
	hud.call_buttons[0].pressed.emit()
	assert(bank._voices[0].stream == call, "Call Enemy button plays the assigned taunt")
	assert(not bank.call_enemy(0), "Manual callouts have a cooldown")
	bank._voices[0].stop()
	bank._last_call[0] = -100.0
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	key.pressed = true
	hud._input(key)
	assert(bank._voices[0].stream == call)
	bank._voices[0].stop()
	bank._last_shout[0] = -100.0
	arena.intro_timer = 1.0
	assert(not hud._can_call(), "Callouts wait until the round intro finishes")
	arena.intro_timer = 0.0
	arena.player1._start_style_move("jab")
	assert(bank._voices[0].stream == move, "Starting a specific move plays its assigned line")
	arena.player2.take_hit(6, 0, 1, arena.player1)
	assert(bank._voices[1].stream != hit, "An ordinary hit stays silent")
	arena.player2.take_hit(16, 0, 1, arena.player1)
	assert(bank._voices[1].stream == hit, "A staggering hit plays the victim's hit reaction")
	arena._end_round(2)
	await create_timer(1.65).timeout
	assert(bank._voices[1].stream == win, "The winner gets the victory recording")
	assert(bank._voices[0].stream == lose, "The loser gets the defeat recording")
	assert(bank._priority[0] == 3 and bank._priority[1] == 3)
	print("VOICE_GAMEPLAY_TEST: ALL PASS")
	quit()
