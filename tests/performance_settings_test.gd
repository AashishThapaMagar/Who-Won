extends SceneTree
## Verify automatic quality changes cannot rebuild scenery during combat,
## while a player's explicit graphics change still updates the stage.
class StageProbe extends "res://scripts/nepal_stage_3d.gd":
	var rebuilds := 0
	func show_round(index: int) -> void:
		rebuilds += 1
		current_round = index
		built_lite = _lite_scenery()
		built_detailed = get_node("/root/Settings").detailed_textures

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var settings := root.get_node("Settings")
	settings.adaptive_quality = false
	settings.quality = settings.Quality.HIGH
	settings.shadows = 1
	settings.detailed_textures = false
	var stage := StageProbe.new()
	root.add_child(stage)
	stage.current_round = 0
	stage.built_lite = false
	stage.built_detailed = false
	settings.adaptive_adjusting = true
	settings.quality = settings.Quality.MEDIUM
	settings.shadows = settings.PRESETS[1][2]
	settings.apply_graphics()
	assert(stage.rebuilds == 0, "Automatic quality change must not rebuild the arena")
	assert(not stage.sun.shadow_enabled, "Cheaper shadows must apply immediately")
	settings.adaptive_adjusting = false
	settings.graphics_changed.emit()
	assert(stage.rebuilds == 1, "Explicit graphics change must rebuild scenery")
	assert(stage.built_lite)
	assert(settings.PRESETS[0][0] < settings.PRESETS[1][0])
	assert(root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED)
	stage.free()
	print("PERFORMANCE_SETTINGS_TEST: ALL PASS")
	quit()
