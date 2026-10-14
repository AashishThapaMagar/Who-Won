extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu._show_settings()
	var back: Control = menu.modal_content.get_node("ModalBack")
	for button in menu.modal_content.find_children("*", "Button", true, false):
		if button != back:
			assert(not back.get_global_rect().intersects(button.get_global_rect()), "Settings Back must not overlap another action")
	menu._close_modal()
	menu._show_records()
	menu._confirm_reset_records()
	assert(root.gui_get_focus_owner().text == "KEEP RECORDS", "Record reset defaults to keeping the ledger")
	menu.queue_free()
	await process_frame
	var setup := root.get_node("MatchSetup")
	setup.practice = true
	setup.vs_ai = false
	setup.story = false
	setup.arcade = false
	var arena: Node = load("res://scenes/Practice3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.step_dummy(1)
	assert(arena.dummy_mode == 1, "The training card's arrows change the dummy")
	arena.step_dummy(-1)
	arena.step_dummy(-1)
	assert(arena.dummy_mode == arena.DUMMY_MODES.size() - 1, "The arrows wrap round the behaviours")
	arena.set_dummy_mode(1)
	arena.player1.health = 25
	arena._reset_practice()
	assert(arena.player1.health == arena.player1.max_health)
	arena._pause()
	var pause: Node = arena.pause_menu
	for button in pause.rows:
		assert(button.position.y + button.size.y < 480, "Pause actions must leave room for the footer")
	pause._show_settings()
	await process_frame
	assert(root.gui_get_focus_owner() is HSlider, "Pause settings can be adjusted from the keyboard")
	pause._confirm_quit()
	await process_frame
	assert(root.gui_get_focus_owner().text == "KEEP FIGHTING", "Quit confirmation defaults to the safe action")
	var accept := InputEventKey.new()
	accept.physical_keycode = KEY_ENTER
	accept.pressed = true
	var requested := [false]
	pause.quit_requested.connect(func(): requested[0] = true)
	pause._input(accept)
	assert(not requested[0], "Pause page input must not automatically quit")
	print("FEATURE_UI_TEST: ALL PASS")
	quit()
