extends SceneTree
## The round announcer (announcer.gd): each arena's own host, her walk in
## toward the camera to her spot, the round called over her head, her walk
## on past the camera when the fight starts, and vanish() for FIGHT!.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 1.45, 6)
	var script := preload("res://scripts/announcer.gd")
	# Every arena has a host model, and they load.
	for stage in script.HOSTS:
		assert(ResourceLoader.exists(script.HOSTS[stage].model), "Arena %d has its announcer model" % stage)
	var host: Node3D = script.new()
	host.stage = 2
	world.add_child(host)
	host.set_process(false)
	assert(host._model != null and host._model.scene_file_path == script.MODEL, "Aamai hosts the hill village")
	for motion in ["idle", "walk", "greet"]:
		assert(not host._clip(motion).is_empty(), "Aamai has the " + motion + " animation")
	assert(not host.visible, "She is hidden until a round is called")
	# Centre stage, behind the fighters' line.
	host.place(Vector3(-1, 0, 0), Vector3(1, 0, 0), camera)
	assert(host._spot.z < 0.0 and absf(host._spot.x) < 0.01, "Her spot is centre stage, behind the fighters")
	host.round_call("ROUND 1")
	assert(host.visible and host._walking, "She walks in when the round is called")
	var start: Vector3 = host.global_position
	assert(start.z < host._spot.z, "She starts further back and walks toward the camera")
	for frame in 200:
		host._process(1.0 / 60.0)
		if not host._walking:
			break
	assert(not host._walking and host.global_position.is_equal_approx(host._spot), "She stops on her spot")
	assert(host._title.visible and host._title.text == "ROUND 1", "The round is called over her head")
	assert(host._call.visible and host._call.text != "", "Her call shows beneath it")
	# The fight starts: she walks on toward the camera and out of view.
	host.leave()
	assert(host._leaving and not host._title.visible, "Leaving hides the words")
	assert((host._walk_to - host._spot).dot(host._to_camera) > 0.0, "She leaves toward the camera")
	for frame in 400:
		host._process(1.0 / 60.0)
		if not host.visible:
			break
	assert(not host.visible, "She is gone once past the fighters")
	# Called again and cut short for FIGHT!.
	host.round_call("ROUND 2")
	assert(host.visible)
	host.vanish()
	await create_timer(0.3).timeout
	assert(not host.visible and host.scale == Vector3.ONE, "vanish() hides her and restores her size")
	# Another arena brings its own host at its own height.
	var other: Node3D = script.new()
	other.stage = 0
	world.add_child(other)
	assert(other._model != null and other._model.scene_file_path == script.HOSTS[0].model, "Heritage Square has its own host")
	world.free()
	print("ANNOUNCER_TEST: ALL PASS")
	quit()
