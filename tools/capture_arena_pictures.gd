extends SceneTree
## Photographs each arena from the menu backdrop's own camera, for the
## character select's instant arena previews (assets/menu/arenas/arena_<n>.jpg).
## Run after adding or changing an arena:
##   godot --path . --resolution 1600x900 -s res://tools/capture_arena_pictures.gd
const OUT := "res://assets/menu/arenas/"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var backdrop: Control = load("res://scripts/menu_backdrop.gd").new()
	backdrop.shade_width = 0.0
	backdrop.selected = 1
	holder.add_child(backdrop)
	await create_timer(1.0).timeout
	for i in backdrop.STAGE.ROUNDS.size():
		backdrop.show_stage(i)
		# Settle the scenery and the camera glide.
		for f in 90:
			await process_frame
		backdrop.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = backdrop.viewport.get_texture().get_image()
		img.resize(1600, 900, Image.INTERPOLATE_LANCZOS)
		img.save_jpg(OUT + "arena_%d.jpg" % i, 0.88)
		print("SAVED ", i, " ", img.get_size())
	quit()
