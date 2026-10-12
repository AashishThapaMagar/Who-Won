extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	var original: Node = menu.backdrop.stage.content
	for mode in ["story", "arcade", "ai", "local", "story", "ai", "arcade", "local"]:
		menu._choose_home_mode(mode)
		assert(menu.rows[menu.cursor].key == mode)
		assert(menu.mode_desc_label.text == menu.rows[menu.cursor].desc)
		assert(menu.rows[menu.cursor].button.modulate.a == 1.0, "Input cancels entrance animation immediately")
	await create_timer(0.4).timeout
	assert(menu.backdrop.stage.content == original, "Mode navigation reuses the existing arena")
	assert(menu.backdrop._round_shown == 0 and menu.backdrop._pending_round == -1)
	assert(not menu.backdrop.stage.sun.shadow_enabled, "Home menu uses lightweight contact shadows")
	assert(menu.backdrop.stage.built_lite, "Decorative scenery uses the lighter prop set")
	for i in range(menu.rows.size() - 1):
		assert(not menu.rows[i].button.get_global_rect().intersects(menu.rows[i + 1].button.get_global_rect()), "Rows settle without overlapping")
	menu._step_entries(1)
	var selected: int = menu.cursor
	menu._hover_select(0)
	assert(menu.cursor == selected, "Layout motion cannot steal keyboard selection")
	var motion := InputEventMouseMotion.new()
	menu._input(motion)
	menu._hover_select(0)
	assert(menu.cursor == 0, "Moving the mouse restores hover selection")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_DOWN
	pad.pressed = true
	menu._input(pad)
	assert(menu.cursor == 1, "Gamepad navigation selects immediately")
	menu._show_settings()
	assert(menu.backdrop.suspended)
	menu._close_modal()
	assert(not menu.backdrop.suspended and menu.play_button.has_focus())
	menu.queue_free()
	await process_frame
	var setup := root.get_node("MatchSetup")
	setup.vs_ai = true
	setup.arcade = false
	setup.story = false
	setup.practice = false
	setup.stage_choice = 0
	var selection: Node = load("res://scenes/CharacterSelect.tscn").instantiate()
	root.add_child(selection)
	current_scene = selection
	await create_timer(0.4).timeout
	# The select screen shows each arena as a photo (instant to change).
	assert(selection.backdrop.picture_mode and selection.backdrop._round_shown == 0 and selection.backdrop._pending_round == -1, "Arena picker cancels stale mode-background transitions")
	print("MENU_RESPONSIVENESS_TEST: ALL PASS")
	quit()
