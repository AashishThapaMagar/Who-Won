extends SceneTree
## Capture the actual feature screens without recording a microphone or
## updating the player's match ledger. Images go under screenshots/.
func _initialize() -> void:
	call_deferred("run")

func snap(name: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://screenshots/feature-" + name + ".png")
	print("UI GALLERY: ", name)

func remove_scene() -> void:
	current_scene.queue_free()
	current_scene = null
	await process_frame

func run() -> void:
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for page in ["settings", "graphics", "controls", "fight_options", "records", "guide"]:
		menu.call("_show_" + page)
		await snap(page)
		menu._close_modal()
		await process_frame
	menu._show_records()
	menu._confirm_reset_records()
	await snap("record-confirmation")
	await remove_scene()
	var setup := root.get_node("MatchSetup")
	setup.vs_ai = false
	setup.arcade = false
	setup.story = false
	setup.practice = false
	setup.stage_choice = 0
	var selection: Node = load("res://scenes/CharacterSelect.tscn").instantiate()
	root.add_child(selection)
	current_scene = selection
	await snap("character-select")
	selection._open_voice_studio(0)
	await snap("voice-studio")
	selection.voice_studio.close_studio()
	await remove_scene()
	var arena: Node = load("res://scenes/Arena3D.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.intro_timer = 0.0
	arena._hide_banner()
	await process_frame
	arena._pause()
	await snap("pause")
	arena.pause_menu._show_settings()
	await snap("pause-settings")
	arena.pause_menu._confirm_quit()
	await snap("quit-confirmation")
	arena._resume()
	arena._toggle_move_guide()
	await snap("movebook")
	arena._toggle_move_guide()
	arena.round_active = false
	arena.match_over = true
	arena.advancing = false
	arena.round_wins = [2, 2]
	arena.result_label.text = "MATCH DRAW"
	arena.result_label.show()
	await snap("results")
	await remove_scene()
	setup.practice = true
	var practice: Node = load("res://scenes/Practice3D.tscn").instantiate()
	root.add_child(practice)
	current_scene = practice
	await snap("training")
	print("UI_GALLERY: COMPLETE")
	quit()
