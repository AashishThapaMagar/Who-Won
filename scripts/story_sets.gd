extends Node3D
## Story Mode sets: places a fighter's life happens outside the tournament
## arenas, built from simple shapes and the arena photo textures. Each set
## brings its own sky and light, named marks for the cast to stand on, and
## a default wide camera move.
##
##   gym      a rented MMA hall: mats, heavy bags, tube lights
##   street   a city street at night; a temple wall with the tournament poster
##   pitch    a dusty neighbourhood pitch at dusk, one goal
##   academy  the same pitch rebuilt: grass, floodlights, academy banner
##   hill_road      Sarvochcha's hill village road on a bright morning: his home,
##                  the teahouse, a bus shelter, a stone water spout; the
##                  set's ball is a newspaper the wind carries to him
##   ananta_ground  a hilltop at dusk: Ananta's old training dummy and a log
##                  to sit on, prayer flags, the range glowing behind
##   (both dressed with Tripo models from assets/arenas/props/hill and
##   props/story_sup)
##
## Sets face the camera from +Z like the arenas, with the floor at y = 0.
const PHOTO_SURFACE := preload("res://scripts/arena_photo_surface.gdshader")
const UI := preload("res://scripts/ui_kit.gd")
const NAMES := ["gym", "street", "pitch", "academy", "hill_road", "ananta_ground"]
const HIMALAYA := preload("res://scripts/himalaya_backdrop.gd")
const HILL_PROPS := "res://assets/arenas/props/hill/"
const SUP_PROPS := "res://assets/arenas/props/story_sup/"

## Mark name -> Vector3 on the floor.
var marks: Dictionary = {}
## Default establishing move: [eye from, look from, eye to, look to].
var wide: Array = []
## The football, for sets that have one (moved by the cutscene).
var ball: MeshInstance3D
var night := false
var _flicker: Array[OmniLight3D] = []
var _flutter: Array[Node3D] = []
var _elapsed := 0.0

static func make(set_name: String) -> Node3D:
	var node: Node3D = load("res://scripts/story_sets.gd").new()
	node.name = "Set_" + set_name
	node.build(set_name)
	return node

func build(set_name: String) -> void:
	match set_name:
		"gym":
			_gym()
		"street":
			_street()
		"pitch":
			_pitch(false)
		"academy":
			_pitch(true)
		"hill_road":
			_hill_road()
		"ananta_ground":
			_ananta_ground()
		_:
			push_warning("Unknown story set %s" % set_name)

func animate(delta: float) -> void:
	_elapsed += delta
	# Prayer flags flutter in the wind.
	for i in _flutter.size():
		_flutter[i].rotation.x = sin(_elapsed * 3.0 - i * 0.5) * 0.35
	# A tired tube light that never quite settles.
	for i in _flicker.size():
		var buzz := sin(_elapsed * 37.0 + i * 5.0) * sin(_elapsed * 3.1 + i)
		_flicker[i].light_energy = 1.15 if buzz > -0.93 else 0.35

# ── Sets ─────────────────────────────────────────────────────────────────

func _gym() -> void:
	night = true
	_environment(Color("15161c"), Color("6d6456"), 0.55, 0.0)
	_sun(Vector3(-50, 30, 0), Color("ffe2b8"), 0.35)
	_box(Vector3(16, 0.1, 12), Vector3(0, -0.05, 0), _flat(Color("4a4744"), 0.9))
	# Blue training mats with a red border.
	_box(Vector3(8.4, 0.05, 6.4), Vector3(0, 0.02, 0.4), _flat(Color("9e2a2f"), 0.8))
	_box(Vector3(8.0, 0.06, 6.0), Vector3(0, 0.03, 0.4), _flat(Color("27487d"), 0.8))
	for x in [-2.0, 0.0, 2.0]:
		_box(Vector3(0.02, 0.065, 6.0), Vector3(x, 0.03, 0.4), _flat(Color("1d3764"), 0.8))
	# Plaster walls over a wood dado.
	_box(Vector3(16, 4.2, 0.2), Vector3(0, 2.1, -3.6), _photo("plaster"))
	_box(Vector3(16, 1.0, 0.24), Vector3(0, 0.5, -3.56), _photo("wood"))
	for side in [-1.0, 1.0]:
		_box(Vector3(0.2, 4.2, 12), Vector3(side * 8.0, 2.1, 0), _photo("plaster"))
	_box(Vector3(16, 0.2, 12), Vector3(0, 4.2, 0), _flat(Color("2b2a2a"), 1.0))
	# A high window letting in the cold city night.
	_box(Vector3(2.6, 1.3, 0.05), Vector3(-4.2, 2.9, -3.48), _glow(Color("6f8fc8"), 1.3))
	for x in [-4.2 - 0.65, -4.2, -4.2 + 0.65]:
		_box(Vector3(0.06, 1.3, 0.08), Vector3(x, 2.9, -3.45), _flat(Color("1c1c1f"), 0.6))
	_light(Vector3(-4.2, 2.6, -2.6), Color("8aa6e0"), 0.8, 5.0)
	# Heavy bags hanging from the beams.
	for spot in [Vector3(4.6, 0, -1.8), Vector3(-5.6, 0, -0.6)]:
		_cylinder(0.22, 1.15, spot + Vector3(0, 1.2, 0), _flat(Color("6b1f1c"), 0.45))
		_cylinder(0.225, 0.08, spot + Vector3(0, 1.72, 0), _flat(Color("1a1a1a"), 0.5))
		_cylinder(0.015, 2.4, spot + Vector3(0, 3.0, 0), _flat(Color("777777"), 0.3, 0.8))
	# Tube lights; the middle one buzzes.
	for i in 3:
		var x := -3.2 + i * 3.2
		_box(Vector3(1.4, 0.06, 0.12), Vector3(x, 3.9, 0.2), _glow(Color("fff4de"), 2.0))
		var lamp := _light(Vector3(x, 3.5, 0.2), Color("fff0d6"), 1.15, 7.5, i == 1)
		if i == 1:
			_flicker.append(lamp)
	# Bench, water bottles and the hand-painted sign.
	_box(Vector3(2.2, 0.08, 0.45), Vector3(-5.2, 0.48, -2.9), _photo("wood"))
	for x in [-6.0, -4.4]:
		_box(Vector3(0.08, 0.46, 0.4), Vector3(x, 0.23, -2.9), _flat(Color("222222"), 0.6))
	for x in [-5.6, -5.4, -4.9]:
		_cylinder(0.04, 0.22, Vector3(x, 0.63, -2.85), _flat(Color("4fa0d8"), 0.2))
	_box(Vector3(3.6, 1.1, 0.05), Vector3(1.6, 2.7, -3.47), _flat(Color("f1e6c8"), 0.9))
	_text("ANUG MMA", Vector3(1.6, 2.92, -3.43), 0.42, Color("9e1f24"), true)
	_text("CLASSES  /  RS 500 A MONTH", Vector3(1.6, 2.5, -3.43), 0.16, Color("202020"))
	marks = {
		"coach": Vector3(0, 0, -1.2), "s1": Vector3(-1.6, 0, 1.2), "s2": Vector3(0, 0, 1.5),
		"s3": Vector3(1.6, 0, 1.2), "door": Vector3(-7.0, 0, 1.5),
	}
	wide = [Vector3(-3.4, 2.5, 6.6), Vector3(-0.6, 1.2, -1.0), Vector3(2.8, 2.0, 5.6), Vector3(0.4, 1.1, -1.4)]

func _street() -> void:
	night = true
	_environment(Color("0a0f22"), Color("39426a"), 0.45, 0.04)
	_sun(Vector3(-35, -40, 0), Color("8ea2e6"), 0.25)
	_box(Vector3(40, 0.1, 14), Vector3(0, -0.05, 1), _flat(Color("26272b"), 0.55))
	_box(Vector3(40, 0.14, 1.4), Vector3(0, 0.07, -2.9), _photo("stone"))
	# Old brick terrace along the back, windows lit here and there.
	_box(Vector3(40, 6.0, 0.4), Vector3(0, 3.0, -3.8), _photo("wall_brick"))
	for i in 12:
		var x := -17.0 + i * 3.1
		var lit := i % 3 != 1
		_box(Vector3(0.9, 1.1, 0.05), Vector3(x, 3.9, -3.58), _glow(Color("ffc36b") if lit else Color("141821"), 1.2 if lit else 0.0))
		_box(Vector3(1.1, 0.12, 0.2), Vector3(x, 3.3, -3.5), _photo("wood"))
	# The temple wall: whitewash, a small shrine, and the poster.
	_box(Vector3(4.6, 3.2, 0.3), Vector3(1.0, 1.6, -3.5), _photo("whitewash"))
	_box(Vector3(4.9, 0.25, 0.5), Vector3(1.0, 3.25, -3.45), _photo("roof"))
	_box(Vector3(0.9, 1.2, 0.5), Vector3(2.7, 0.75, -3.2), _photo("stone"))
	_box(Vector3(1.1, 0.12, 0.7), Vector3(2.7, 1.4, -3.2), _photo("roof"))
	_cylinder(0.08, 0.14, Vector3(2.7, 1.08, -2.9), _glow(Color("ffb347"), 3.0))
	_light(Vector3(2.7, 1.3, -2.6), Color("ff9f40"), 0.7, 2.5)
	_poster(Vector3(0.4, 1.85, -3.33))
	# An older torn poster beside it.
	_box(Vector3(0.9, 1.2, 0.02), Vector3(-1.1, 1.7, -3.34), _flat(Color("a9a08c"), 0.9))
	# Street lamp over the poster.
	_cylinder(0.06, 3.6, Vector3(-0.9, 1.8, -2.7), _flat(Color("2a2c30"), 0.4, 0.6))
	_box(Vector3(0.9, 0.06, 0.06), Vector3(-0.5, 3.55, -2.7), _flat(Color("2a2c30"), 0.4, 0.6))
	_box(Vector3(0.3, 0.12, 0.2), Vector3(-0.1, 3.48, -2.7), _glow(Color("ffd08a"), 3.0))
	_light(Vector3(-0.1, 3.2, -2.3), Color("ffc27a"), 2.2, 7.0, true)
	# Tangled wires overhead, as on every Kathmandu street.
	for i in 5:
		_box(Vector3(40, 0.02, 0.02), Vector3(0, 4.6 + i * 0.12, -2.4 + i * 0.35), _flat(Color("111111"), 0.8))
	marks = {"far": Vector3(-7.0, 0, 0.6), "poster": Vector3(0.4, 0, -1.7), "lamp": Vector3(-1.2, 0, -1.4)}
	wide = [Vector3(-7.0, 1.8, 5.2), Vector3(-3.0, 1.4, -2.0), Vector3(-2.8, 1.6, 4.4), Vector3(0.0, 1.6, -3.0)]

func _poster(at: Vector3) -> void:
	_box(Vector3(1.5, 2.0, 0.02), at, _glow(Color("8f1826"), 0.25))
	_box(Vector3(1.36, 0.02, 0.025), at + Vector3(0, 0.62, 0.005), _flat(Color("ffc53d"), 0.5))
	_text("OPEN TOURNAMENT", at + Vector3(0, 0.78, 0.02), 0.1, Color("ffc53d"))
	_text("THE ROAD TO", at + Vector3(0, 0.42, 0.02), 0.13, Color("f6f3ec"), true)
	_text("ANANTA", at + Vector3(0, 0.16, 0.02), 0.34, Color("f6f3ec"), true)
	_text("BEAT ANANTA", at + Vector3(0, -0.22, 0.02), 0.12, Color("f6f3ec"))
	_text("WIN RS", at + Vector3(0, -0.44, 0.02), 0.13, Color("ffc53d"), true)
	_text("5 CRORE", at + Vector3(0, -0.72, 0.02), 0.3, Color("ffc53d"), true)

func _pitch(academy: bool) -> void:
	night = academy
	if academy:
		_environment(Color("070b1a"), Color("3a4670"), 0.5, 0.02)
		_sun(Vector3(-45, 20, 0), Color("b8c6f0"), 0.3)
	else:
		_environment(Color("d9a27a"), Color("9a8a8e"), 0.55, 0.004, Color("4a5a8e"))
		_sun(Vector3(-14, -60, 0), Color("ffc08a"), 0.8)
	var ground := Color("3c7a34") if academy else Color("7a6248")
	_box(Vector3(60, 0.1, 34), Vector3(0, -0.05, -2), _flat(ground, 0.95))
	if not academy:
		# Worn grass clinging on at the edges of a dirt pitch.
		for spot in [Vector3(-6, 0, 4), Vector3(4, 0, 5), Vector3(-9, 0, -5), Vector3(9, 0, -6)]:
			_box(Vector3(4, 0.02, 3), spot + Vector3(0, 0.005, 0), _flat(Color("5e7a3a"), 1.0))
	var line := _flat(Color("f2f0e8") if academy else Color("d8cdb4"), 0.8)
	_box(Vector3(0.08, 0.02, 20), Vector3(0, 0.01, -1), line)
	_box(Vector3(26, 0.02, 0.08), Vector3(0, 0.01, 9), line)
	_box(Vector3(26, 0.02, 0.08), Vector3(0, 0.01, -11), line)
	_box(Vector3(0.08, 0.02, 20), Vector3(13, 0.01, -1), line)
	_box(Vector3(4.2, 0.02, 0.08), Vector3(10.9, 0.01, 2.6), line)
	_box(Vector3(4.2, 0.02, 0.08), Vector3(10.9, 0.01, -4.6), line)
	_box(Vector3(0.08, 0.02, 7.2), Vector3(8.8, 0.01, -1), line)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.9
	torus.outer_radius = 3.0
	torus.rings = 48
	ring.mesh = torus
	ring.scale = Vector3(1, 0.02, 1)
	ring.position = Vector3(0, 0.01, -1)
	ring.material_override = line
	add_child(ring)
	# The goal, with a see-through net.
	var post := _flat(Color("f4f4f4"), 0.3)
	for z in [-2.8, 0.8]:
		_cylinder(0.06, 2.3, Vector3(13, 1.15, z), post)
	_box(Vector3(0.12, 0.12, 3.7), Vector3(13, 2.3, -1), post)
	var net := StandardMaterial3D.new()
	net.albedo_color = Color(1, 1, 1, 0.22)
	net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box(Vector3(0.02, 2.3, 3.6), Vector3(14.1, 1.15, -1), net)
	_box(Vector3(1.1, 0.02, 3.6), Vector3(13.55, 2.3, -1), net)
	for z in [-2.8, 0.8]:
		_box(Vector3(1.1, 2.3, 0.02), Vector3(13.55, 1.15, z), net)
	ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	ball.mesh = sphere
	ball.material_override = _flat(Color("f5f5f5"), 0.45)
	ball.position = Vector3(8.2, 0.11, 0.2)
	add_child(ball)
	# Fence and city silhouette beyond.
	for i in 25:
		_cylinder(0.04, 1.8, Vector3(-24 + i * 2.0, 0.9, -12), _flat(Color("3a3d42"), 0.5, 0.6))
	_box(Vector3(48, 0.03, 0.03), Vector3(0, 1.75, -12), _flat(Color("3a3d42"), 0.5, 0.6))
	for i in 9:
		var h := 4.0 + float((i * 37) % 7)
		_box(Vector3(5.5, h, 3), Vector3(-26 + i * 6.5, h * 0.5, -22), _flat(Color("141827") if academy else Color("6a5a5e"), 1.0))
		if not academy:
			# Evening windows coming on across the city.
			for w in 3:
				_box(Vector3(0.6, 0.7, 0.05), Vector3(-27.5 + i * 6.5 + w * 1.4, h * 0.6, -20.45), _glow(Color("ffcf7a"), 1.0))
	if academy:
		# The academy sign on the fence and floodlights at the corners.
		_box(Vector3(9, 1.5, 0.08), Vector3(4, 1.6, -11.9), _glow(Color("a51b2e"), 0.4))
		_box(Vector3(8.8, 0.05, 0.1), Vector3(4, 2.25, -11.85), _flat(Color("ffc53d"), 0.5))
		_text("ANUG FOOTBALL ACADEMY", Vector3(4, 1.75, -11.8), 0.46, Color("f6f3ec"), true)
		_text("FREE FOR EVERY KID WHO SHOWS UP", Vector3(4, 1.2, -11.8), 0.2, Color("ffc53d"))
		for corner in [Vector3(-8, 0, -10), Vector3(16, 0, -10), Vector3(16, 0, 8)]:
			_cylinder(0.12, 9.0, corner + Vector3(0, 4.5, 0), _flat(Color("2a2c30"), 0.4, 0.6))
			_box(Vector3(1.6, 0.9, 0.3), corner + Vector3(0, 9.1, 0), _glow(Color("f4f7ff"), 4.0))
			var flood := SpotLight3D.new()
			flood.position = corner + Vector3(0, 9.0, 0)
			flood.look_at_from_position(flood.position, Vector3(8, 0, -1), Vector3.UP)
			flood.light_color = Color("eef2ff")
			flood.light_energy = 6.0
			flood.spot_range = 40.0
			flood.spot_angle = 32.0
			flood.shadow_enabled = corner.x > 15 and corner.z < 0
			add_child(flood)
	marks = {"goal": Vector3(12.2, 0, -1), "spot": Vector3(7.6, 0, 0.2), "centre": Vector3(0, 0, -1),
		"k1": Vector3(6.4, 0, -2.6), "k2": Vector3(6.0, 0, -1.2), "k3": Vector3(6.4, 0, 0.4)}
	wide = [Vector3(0.0, 2.6, 8.0), Vector3(8.0, 1.0, -1.0), Vector3(4.0, 1.9, 6.2), Vector3(10.0, 1.1, -1.0)]

# ── Building blocks ─────────────────────────────────────────────────────

## Sarvochcha's village: a dirt road along a ridge on a clear morning.
func _hill_road() -> void:
	_environment(Color("c9dcef"), Color("b7c6d8"), 0.55, 0.004, Color("3f7bd2"))
	_sun(Vector3(-38, -50, 0), Color("fff1dc"), 1.15)
	_ground(Color(0.66, 0.58, 0.48), Color(0.62, 0.74, 0.46))
	# The road, a strip of packed earth across the set.
	_box(Vector3(60, 0.04, 3.2), Vector3(0, 0.0, 0.4), _flat(Color("9c8268"), 0.95))
	_prop(HILL_PROPS + "hill_house.glb", Vector3(-6.0, 0, -8.0), 20.0, 1.7)
	_prop(HILL_PROPS + "tea_house.glb", Vector3(6.0, 0, -8.5), -15.0, 1.3)
	_prop(SUP_PROPS + "bus_shelter.glb", Vector3(11.0, 0, -2.6), -10.0, 1.0)
	_prop(SUP_PROPS + "dhunge_dhara.glb", Vector3(-11.0, 0, -3.0), 25.0, 1.0)
	_prop(HILL_PROPS + "chautara.glb", Vector3(1.0, 0, -9.5), 0.0, 5.0)
	for spot in [[-9.0, -8.0, 0.0, 8.0], [9.5, -9.5, 80.0, 7.0], [-14.0, -6.5, 160.0, 7.5]]:
		_prop(HILL_PROPS + "rhododendron.glb", Vector3(spot[0], 0, spot[1]), spot[2], spot[3])
	add_child(HIMALAYA.build(Color("c9dcef"), false, false))
	_flags(Vector3(-5.5, 3.6, -7.0), Vector3(5.8, 3.4, -7.6))
	# The newspaper: a folded sheet with a red headline band.
	ball = MeshInstance3D.new()
	var sheet := BoxMesh.new()
	sheet.size = Vector3(0.42, 0.006, 0.3)
	ball.mesh = sheet
	ball.material_override = _flat(Color("ece6d6"), 0.9)
	ball.position = Vector3(-14.0, 2.5, -1.0)
	add_child(ball)
	var band := _box(Vector3(0.4, 0.008, 0.07), Vector3(0, 0.001, -0.1), _flat(Color("b3202a"), 0.8))
	remove_child(band)
	ball.add_child(band)
	marks = {"home": Vector3(-5.2, 0, -4.4), "road": Vector3(0.0, 0, 0.4), "east": Vector3(14.0, 0, 0.4),
		"west": Vector3(-14.0, 0, 0.4), "shelter": Vector3(10.6, 0, -1.4), "tap": Vector3(-10.0, 0, -1.6)}
	wide = [Vector3(-8.0, 2.6, 8.5), Vector3(-2.0, 1.6, -4.0), Vector3(-2.0, 2.2, 7.0), Vector3(1.0, 1.6, -4.0)]

## The hilltop where Ananta trained his student, at dusk.
func _ananta_ground() -> void:
	_environment(Color("e3a77c"), Color("8f86a8"), 0.5, 0.006, Color("3b4a8c"))
	_sun(Vector3(-10, -70, 0), Color("ffc58c"), 1.2)
	_ground(Color(0.6, 0.55, 0.5), Color(0.55, 0.62, 0.4))
	_prop(SUP_PROPS + "training_dummy.glb", Vector3(-2.6, 0, -2.4), 30.0, 1.0)
	_prop(SUP_PROPS + "sitting_log.glb", Vector3(1.6, 0, -1.2), -10.0, 1.0)
	_prop(HILL_PROPS + "chautara.glb", Vector3(4.5, 0, -7.0), 0.0, 5.5)
	_prop(HILL_PROPS + "rhododendron.glb", Vector3(-6.5, 0, -6.0), 40.0, 7.5)
	add_child(HIMALAYA.build(Color("e3a77c"), false, true))
	_flags(Vector3(-6.0, 3.6, -5.5), Vector3(4.5, 5.2, -6.6))
	marks = {"dummy": Vector3(-2.0, 0, -1.4), "log_left": Vector3(1.0, 0, -0.7), "log_right": Vector3(2.2, 0, -0.8),
		"edge": Vector3(-1.0, 0, 1.4), "far": Vector3(-8.0, 0, 1.0)}
	wide = [Vector3(-5.0, 2.4, 7.0), Vector3(0.0, 1.4, -3.0), Vector3(-1.5, 1.8, 5.6), Vector3(1.0, 1.2, -2.0)]

## Packed earth underfoot and meadow beyond, from the arenas' aerial scans.
func _ground(earth: Color, grass: Color) -> void:
	var near := PlaneMesh.new()
	near.size = Vector2(40, 24)
	var dirt := MeshInstance3D.new()
	dirt.mesh = near
	dirt.position = Vector3(0, -0.01, -2)
	dirt.material_override = _scan("aerial_rocks_02", 5.0, earth)
	add_child(dirt)
	var far := PlaneMesh.new()
	far.size = Vector2(400, 400)
	var meadow := MeshInstance3D.new()
	meadow.mesh = far
	meadow.position = Vector3(0, -0.03, -60)
	meadow.material_override = _scan("aerial_grass_rock", 9.0, grass)
	add_child(meadow)

func _scan(folder: String, world_size: float, tint: Color) -> StandardMaterial3D:
	var path := "res://assets/arenas/textures/%s/%s_" % [folder, folder]
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(path + "diff_1k.jpg")
	material.albedo_color = tint
	material.roughness = 0.95
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / world_size
	return material

## A Tripo model, turned (degrees) and scaled, standing on the floor (Tripo
## models are centred on their origin).
func _prop(path: String, at: Vector3, turn: float, scale_by: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var prop := (load(path) as PackedScene).instantiate() as Node3D
	var low := INF
	for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		var xform := Transform3D.IDENTITY
		var node: Node = mesh
		while node != null and node != prop:
			if node is Node3D:
				xform = (node as Node3D).transform * xform
			node = node.get_parent()
		low = minf(low, (xform * mesh.get_aabb()).position.y)
	prop.position = at - Vector3(0, low * scale_by if is_finite(low) else 0.0, 0)
	prop.rotation.y = deg_to_rad(turn)
	prop.scale = Vector3.ONE * scale_by
	add_child(prop)

## A line of prayer flags that flutter (see animate).
func _flags(a: Vector3, b: Vector3) -> void:
	var colors := [Color("2f6fc4"), Color("f1ede2"), Color("c8342c"), Color("2f8f4e"), Color("e6b62f")]
	var count := 22
	for i in range(1, count):
		var t := float(i) / count
		var point := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.5, 0)
		var hanger := Node3D.new()
		hanger.position = point
		hanger.rotation.y = -atan2((b - a).z, (b - a).x)
		add_child(hanger)
		var flag := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.22, 0.26)
		flag.mesh = quad
		flag.position = Vector3(0, -0.14, 0)
		var material := _flat(colors[(i - 1) % 5], 0.9)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		flag.material_override = material
		hanger.add_child(flag)
		_flutter.append(hanger)

func _environment(background: Color, ambient: Color, ambient_energy: float, fog: float, horizon := Color()) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	if horizon.a > 0.0:
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = horizon
		sky_material.sky_horizon_color = background
		sky_material.ground_horizon_color = background.darkened(0.3)
		sky_material.ground_bottom_color = background.darkened(0.6)
		var sky := Sky.new()
		sky.sky_material = sky_material
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if fog > 0.0:
		env.fog_enabled = true
		env.fog_light_color = background.lerp(ambient, 0.3)
		env.fog_density = fog
	world.environment = env
	add_child(world)

func _sun(degrees: Vector3, color: Color, energy: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = degrees
	sun.light_color = color
	sun.light_energy = energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)

func _light(at: Vector3, color: Color, energy: float, reach: float, shadow := false) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = shadow
	add_child(lamp)
	return lamp

func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	add_child(node)
	return node

func _cylinder(radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = at
	node.material_override = material
	add_child(node)
	return node

func _text(words: String, at: Vector3, height: float, color: Color, display := false) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.position = at
	label.pixel_size = height / 64.0
	label.font_size = 64
	label.font = UI.display_font() if display else UI.strong_font()
	label.modulate = color
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	add_child(label)
	return label

func _flat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _glow(color: Color, strength: float) -> StandardMaterial3D:
	var material := _flat(color, 0.6)
	material.emission_enabled = strength > 0.0
	material.emission = color
	material.emission_energy_multiplier = strength
	return material

## The arenas' photo-textured surfaces (world projected, so any box works).
func _photo(kind: String) -> Material:
	var spec: Array = preload("res://scripts/nepal_stage_3d.gd").PHOTO_TEXTURES[kind]
	var folder := "res://assets/arenas/textures/%s/%s_" % [spec[0], spec[0]]
	var material := ShaderMaterial.new()
	material.shader = PHOTO_SURFACE
	material.set_shader_parameter("albedo_map", load(folder + "diff_1k.jpg"))
	material.set_shader_parameter("normal_map", load(folder + "nor_gl_1k.jpg"))
	material.set_shader_parameter("roughness_map", load(folder + "rough_1k.jpg"))
	material.set_shader_parameter("world_size", spec[1])
	material.set_shader_parameter("tint", spec[2] * (0.75 if night else 1.0))
	material.set_shader_parameter("normal_strength", spec[3])
	material.set_shader_parameter("saturation", spec[4])
	return material
