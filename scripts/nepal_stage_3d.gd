extends Node3D
## Four supplied Kathmandu-valley GLB arenas, dressed with live lighting,
## weathered materials, atmospheric skies and animated practical details.
## Procedural construction helpers remain below for future scenery edits.
const ROUNDS := [
	{"name": "HERITAGE SQUARE", "night": true, "detail": "NIGHT / Lamplit carvings and a three-tier pagoda under the moon"},
	{"name": "TERAI PLAINS", "night": false, "detail": "MORNING / A Tharu village on the green plains of the south"},
	{"name": "HILL VILLAGE", "night": false, "detail": "MORNING / A ridge village above terraced valleys and the Himalaya"},
	{"name": "GOMPA COURTYARD", "night": false, "detail": "SUNSET / A monastery courtyard glowing gold at dusk"},
	{"name": "HIMALAYAN PASS", "night": false, "detail": "HIGH NOON / Prayer flags and a chorten among the snows"},
	{"name": "DASHAIN GROUND", "night": false, "detail": "GOLDEN HOUR / Kites, a bamboo swing and marigolds on a festival ridge"},
]
const ARENA_MODELS := [
	"res://assets/arenas/models/heritage-square.glb",
	"res://assets/arenas/models/lantern-square.glb",
	"res://assets/arenas/models/terrace-overlook.glb",
	"res://assets/arenas/models/moonlit-stupa.glb",
	# The pass is dressed from scratch on a plain dais.
	"res://assets/arenas/models/terrace-overlook.glb",
	# The Dashain ground: the hill village's ridge, dressed for the festival.
	"res://assets/arenas/models/terrace-overlook.glb",
]
## Decode the source GLB with the running engine, not another version's
## binary import cache. Cache packed scenes for menu/round reuse.
static var arena_cache: Dictionary = {}
const PHOTO_SURFACE := preload("res://scripts/arena_photo_surface.gdshader")
const HIMALAYA := preload("res://scripts/himalaya_backdrop.gd")
## Sculpted Meshy props (tools/prepare_meshy_props.py) that replace the
## arena model's block-built landmarks, per round. Missing files keep the
## original pieces.
const PROPS := {
	0: "res://assets/arenas/props/heritage/",
	1: "res://assets/arenas/props/terai/",
	2: "res://assets/arenas/props/hill/",
	3: "res://assets/arenas/props/stupa/",
	4: "res://assets/arenas/props/himalaya/",
	5: "res://assets/arenas/props/hill/",
}
## Photo-scanned surfaces from Poly Haven (CC0), in assets/arenas/textures/:
## kind -> [texture folder, metres per repeat, tint, normal strength, saturation].
const PHOTO_TEXTURES := {
	"wall_brick": ["red_bricks_04", 2.5, Color(1.25, 0.95, 0.82), 1.0, 1.35],
	"paving_brick": ["red_brick", 1.4, Color(1.1, 0.92, 0.84), 0.8, 1.15],
	"roof": ["roof_09", 3.2, Color(1.05, 0.9, 0.82), 1.0, 1.15],
	"wood": ["weathered_brown_planks", 1.8, Color(0.78, 0.5, 0.34), 0.9, 1.4],
	"plaster": ["painted_plaster_wall", 2.0, Color(1.05, 0.98, 0.86), 0.8, 1.0],
	"stone": ["medieval_blocks_03", 2.0, Color(0.95, 0.93, 0.9), 1.0, 0.9],
	"whitewash": ["white_plaster_02", 1.5, Color(1.08, 1.08, 1.06), 0.6, 0.7],
}
static var photo_materials: Dictionary = {}
const IMPORTED_SURFACE := preload("res://scripts/arena_surface.gdshader")
## Five traditional prayer-flag colours, in their customary order.
const FLAG_COLORS := [Color("2f6fc4"), Color("f1ede2"), Color("c8342c"), Color("2f8f4e"), Color("e6b62f")]
## Per-round ambient life: [kind, colour, amount]. The squares keep their
## air clear: floating motes read as stray pixels over a real scene. Only
## the finale keeps its sky lanterns, rising far behind the stupa.
const AMBIENCE := [
	["none", Color.WHITE, 0],
	["none", Color.WHITE, 0],
	["none", Color.WHITE, 0],
	["sky_lanterns", Color(1.0, 0.66, 0.3, 0.95), 16],
	["snow", Color(1.0, 1.0, 1.0, 0.9), 70],
	["none", Color.WHITE, 0],
]
## Sky and light per round: [sky top, horizon, sun colour, sun energy,
## ambient colour, ambient energy, sun pitch, sun yaw, mountain tint].
## Clear Himalayan daylight: a deep blue sky over white peaks, a clean,
## nearly white sun high enough to light faces, and a soft sky-blue fill.
const MOODS := [
	[Color("2f6fd6"), Color("bcd8f2"), Color("fff6ea"), 0.9, Color("b4c8e4"), 0.34, -40.0, -35.0, Color(1, 1, 1)],
	# Terai: a humid, golden morning over flat green plains.
	[Color("4f86cf"), Color("a9c6d2"), Color("fff0d2"), 0.95, Color("b9c9b0"), 0.38, -30.0, 40.0, Color(1, 1, 1)],
	[Color("2c6cd4"), Color("b8d6f2"), Color("fff4e4"), 0.92, Color("b2c6e2"), 0.33, -42.0, 28.0, Color(1, 1, 1)],
	# Boudha at sunset: a violet-blue sky warming to peach at the horizon,
	# a low golden sun from the side that rakes across the fighters and
	# throws long shadows, and a cool dusk fill in the shadows.
	[Color("3d5591"), Color("e9bfa0"), Color("ffd3a6"), 1.1, Color("8f98b8"), 0.4, -14.0, -65.0, Color(1.0, 0.93, 0.88)],
	# The pass: a deep high-altitude blue, hard white sun, cold blue fill.
	[Color("1f4fb0"), Color("c7d8ee"), Color("fffbf4"), 1.15, Color("a8bcdc"), 0.36, -48.0, -30.0, Color(1, 1, 1)],
	# Dashain: late golden afternoon, the sun low and warm across the ridge,
	# a soft lilac fill, the peaks blushing.
	[Color("4a6db4"), Color("f2c99c"), Color("ffcf94"), 1.08, Color("a79fbc"), 0.42, -17.0, 52.0, Color(1.0, 0.94, 0.88)],
]
## Finishing grade per round (arena_grade.gdshader): [shadow tint,
## highlight tint, saturation, contrast, vignette, exposure, glow intensity,
## glow threshold]. Night squares lean teal in the darks and amber in the
## lamplight; the sunset warms everything; the stupa finale is cold and clean.
## Bright, vivid and clean: prayer-flag colour, red brick and green hills
## at full strength, neutral highlights (no yellow cast), a hint of cool in
## the shadows and a light vignette.
const GRADES := [
	[Color(0.96, 0.99, 1.04), Color(1.01, 1.0, 0.98), 1.2, 1.07, 0.2, 1.04, 0.6, 0.95],
	# Terai: warm, lush and golden; greens rich, shadows a touch warm.
	[Color(1.0, 0.99, 0.93), Color(1.05, 1.0, 0.9), 1.16, 1.06, 0.22, 1.03, 0.6, 0.95],
	[Color(0.96, 0.99, 1.04), Color(1.01, 1.0, 0.98), 1.22, 1.07, 0.18, 1.05, 0.6, 0.95],
	# Golden hour, not orange: warm highlights, cool shadows, whites kept
	# white (a strong warm cast turned whitewash and snow to sand).
	[Color(0.94, 0.97, 1.05), Color(1.04, 1.0, 0.95), 1.06, 1.08, 0.24, 1.0, 0.7, 0.92],
	# Crisp and cold: blue shadows, clean whites, a little extra contrast.
	[Color(0.92, 0.97, 1.08), Color(1.0, 1.0, 1.0), 1.1, 1.1, 0.22, 1.0, 0.6, 0.95],
	# Dashain: warm highlights, cool shadows, festival colour at full.
	[Color(0.95, 0.97, 1.04), Color(1.05, 1.0, 0.94), 1.14, 1.07, 0.24, 1.02, 0.7, 0.92],
]
## Night version of any arena (cinematics set force_night): the starlit sky,
## lamp glow and teal-and-amber grade Heritage Square used to have.
const NIGHT_MOOD := [Color("050a1c"), Color("22305a"), Color("c4d3ff"), 0.42, Color("4b5684"), 0.36, -38.0, -40.0, Color(0.42, 0.47, 0.68)]
const NIGHT_GRADE := [Color(0.86, 0.92, 1.08), Color(1.06, 0.98, 0.9), 1.12, 1.08, 0.34, 1.05, 1.1, 0.72]
var force_night := false
const GRADE_SHADER := preload("res://scripts/arena_grade.gdshader")
const SURFACE_SHADER := """shader_type spatial;
// World-space procedural surfaces: 0 brick, 1 cut stone, 2 roof tiles,
// 3 plaster, 4 timber, 5 flagstone, 6 carved lattice.
uniform int pattern = 0;
uniform vec3 base_color : source_color = vec3(0.6, 0.3, 0.2);
uniform vec3 joint_color : source_color = vec3(0.3, 0.26, 0.22);
uniform float scale = 1.0;
// Rain on the flagstones: puddles in the low slabs at night.
uniform float wetness = 0.0;
varying vec3 wp;
varying vec3 wn;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec3 an = abs(wn);
	vec2 uv = an.y > max(an.x, an.z) ? wp.xz : (an.x > an.z ? vec2(wp.z, wp.y) : wp.xy);
	uv /= scale;
	vec3 col = base_color;
	float rough = 0.88;
	float spec = 0.3;
	float grime = noise(uv * 1.3) * 0.18 + noise(uv * 7.0) * 0.08;
	if (pattern == 0) {
		vec2 b = uv / vec2(0.23, 0.075);
		b.x += mod(floor(b.y), 2.0) * 0.5;
		vec2 f = fract(b);
		float face = step(0.05, f.x) * step(0.12, f.y);
		col = mix(joint_color, base_color * (0.78 + 0.4 * hash(floor(b))), face);
	} else if (pattern == 1) {
		vec2 b = uv / vec2(0.6, 0.3);
		b.x += mod(floor(b.y), 2.0) * 0.5;
		vec2 f = fract(b);
		float face = step(0.02, f.x) * step(0.04, f.y);
		col = mix(joint_color, base_color * (0.86 + 0.22 * hash(floor(b))), face);
	} else if (pattern == 2) {
		vec2 b = uv / vec2(0.16, 0.11);
		b.x += mod(floor(b.y), 2.0) * 0.5;
		vec2 f = fract(b);
		col = base_color * (0.62 + 0.5 * f.y) * (0.85 + 0.25 * hash(floor(b)));
		col = mix(joint_color, col, step(0.06, f.x));
		rough = 0.7;
	} else if (pattern == 3) {
		col = base_color * (0.92 + noise(uv * 3.0) * 0.12);
	} else if (pattern == 4) {
		col = base_color * (0.8 + 0.25 * noise(vec2(uv.x * 40.0, uv.y * 2.0)));
		rough = 0.75;
	} else if (pattern == 5) {
		vec2 b = uv / vec2(0.9, 0.62);
		b.x += mod(floor(b.y), 2.0) * 0.37;
		vec2 f = fract(b);
		vec2 edge = min(f, 1.0 - f);
		float face = smoothstep(0.008, 0.023, edge.x) * smoothstep(0.012, 0.03, edge.y);
		float grain = noise(uv * 65.0);
		float veins = smoothstep(0.46, 0.54, noise(uv * 3.8 + noise(uv * 12.0)));
		// Each slab gets its own shade and a warm or cool cast, so no two
		// neighbouring stones read as copies.
		vec3 slab_tint = mix(vec3(1.05, 1.0, 0.93), vec3(0.94, 0.98, 1.05), hash(floor(b) + 17.3));
		col = mix(joint_color, base_color * slab_tint * (0.72 + 0.32 * hash(floor(b))) * (0.86 + grain * 0.18 + veins * 0.08), face);
		rough = mix(0.94, 0.66 + grain * 0.16, face);
		// Standing water darkens the low slabs into mirrors for the lamps;
		// the rest of the dais is merely damp.
		float puddle = smoothstep(0.52, 0.7, noise(uv * 0.55 + 3.1)) * wetness * face;
		col *= 1.0 - puddle * 0.45 - wetness * 0.08;
		rough = mix(rough, 0.08, puddle) - wetness * 0.12;
		spec = mix(0.32, 0.65, puddle);
	} else if (pattern == 6) {
		vec2 b = uv / 0.09;
		vec2 f = abs(fract(b) - 0.5);
		float lattice = step(0.36, max(f.x, f.y)) + step(0.46, f.x + f.y);
		col = mix(joint_color, base_color, clamp(lattice, 0.0, 1.0));
	}
	ALBEDO = col * (1.0 - grime * 0.6);
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = spec;
}
"""
const SKY_SHADER := """shader_type sky;
uniform vec3 top_color : source_color;
uniform vec3 horizon_color : source_color;
uniform vec3 sun_color : source_color;
uniform vec3 sun_dir = vec3(0.0, 0.5, -1.0);
uniform float disc = 0.9994;
uniform float stars = 0.0;
// 1 at night: the disc becomes a moon with a soft halo instead of a sun.
uniform float moon = 0.0;
// 0 skips the clouds and stars (the LOW graphics preset).
uniform float detail = 1.0;
// Sine-free hash (Dave Hoskins): sin() of large numbers loses precision on
// many GPUs, which broke the clouds into hard angular facets.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
float fbm(vec2 p) {
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float sum = 0.0;
	float weight = 0.5;
	for (int o = 0; o < 3; o++) {
		sum += noise(p) * weight;
		p = turn * p * 2.07 + vec2(3.1, 7.7);
		weight *= 0.5;
	}
	return sum / 0.875;
}
// One layer of stars: at most one per cell of a 3D grid laid through the
// sky, each a round soft point (a gaussian on its distance) at a random spot
// well inside its cell. Most are faint and a few bright, each coloured by
// its temperature: blue-white, white or orange. `sigma` is the point's
// radius in cells; `glare` a soft glow round the bright ones for the bloom.
vec3 star_layer(vec3 dir, float scale, float density, float sigma, float gain, float glare, float shimmer, float time) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	vec3 h = hash33(cell);
	if (h.x > density) {
		return vec3(0.0);
	}
	vec3 centre = cell + 0.3 + 0.4 * hash33(cell + 19.19);
	float dist = length(p - centre);
	float magnitude = pow(h.y, 3.0);
	float core = exp(-dist * dist / (sigma * sigma));
	float halo = glare * magnitude * exp(-dist / (sigma * 2.5));
	vec3 tint = mix(vec3(0.72, 0.82, 1.0), vec3(1.0, 0.98, 0.95), smoothstep(0.0, 0.35, h.z));
	tint = mix(tint, vec3(1.0, 0.8, 0.58), smoothstep(0.7, 1.0, h.z));
	float twinkle = 1.0 - shimmer * (0.5 + 0.5 * sin(time * (2.3 + h.y * 6.0) + h.x * 80.0));
	return tint * (core * (0.2 + magnitude) + halo) * gain * twinkle;
}
void sky() {
	float y = EYEDIR.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(-0.02, 0.55, y));
	// A warm band just above the horizon: dust and city glow at night, the
	// afterglow at sunset.
	col += horizon_color * 0.35 * exp(-max(y, 0.0) * 9.0) * (1.0 - stars * 0.5);
	vec3 s = normalize(sun_dir);
	float d = dot(EYEDIR, s);
	if (moon > 0.5) {
		// Crescent-lit moon: a bright disc with a soft, cool halo.
		float body = smoothstep(disc, disc + 0.0004, d);
		vec3 shade_dir = normalize(s + vec3(0.45, 0.2, 0.0));
		float phase = smoothstep(disc - 0.0015, disc + 0.0015, dot(EYEDIR, shade_dir));
		col += sun_color * body * (0.55 + 0.45 * (1.0 - phase));
		col += sun_color * 0.18 * pow(max(d, 0.0), 220.0);
		col += sun_color * 0.05 * pow(max(d, 0.0), 24.0);
	} else {
		col += sun_color * smoothstep(disc, disc + 0.0003, d) * 2.5;
		col += sun_color * 0.5 * pow(max(d, 0.0), 18.0);
		col += sun_color * 0.22 * pow(max(d, 0.0), 4.0);
	}
	float cover = 0.0;
	if (detail > 0.5) {
	// Soft fair-weather clouds: three octaves of smooth noise (the finest
	// two were lost at this distance and cost a sixth of the frame on
	// integrated graphics), each turned against the last so no grid shows.
	vec2 cloud_uv = EYEDIR.xz / max(y + 0.22, 0.1) * 1.6 + vec2(TIME * 0.006, 0.0);
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float cloud = 0.0;
	float weight = 0.5;
	vec2 q = cloud_uv;
	for (int o = 0; o < 3; o++) {
		cloud += noise(q) * weight;
		q = turn * q * 2.03 + vec2(1.7, 9.2);
		weight *= 0.5;
	}
	cloud /= 0.875;
	cover = smoothstep(0.48, 0.82, cloud) * smoothstep(0.0, 0.2, y);
	// Clouds catch the light on their sunward side.
	float lit = 0.3 + 0.5 * max(d, 0.0);
	col = mix(col, mix(horizon_color, sun_color, lit), cover * (0.58 - stars * 0.3));
	if (stars > 0.0) {
		// Thick air low down dims the stars and makes them scintillate;
		// the moon's glare and the clouds hide the faint ones.
		float clear = smoothstep(0.0, 0.12, y) * (0.6 + 0.4 * smoothstep(0.1, 0.45, y)) * (1.0 - cover);
		clear *= 1.0 - 0.9 * pow(max(d, 0.0), 40.0);
		float shimmer = mix(0.55, 0.12, smoothstep(0.05, 0.6, y));
		// The Milky Way: a tilted band of glow broken by dark dust lanes,
		// thick with tiny stars.
		float across = dot(EYEDIR, normalize(vec3(0.62, 0.3, -0.72)));
		float band = exp(-across * across * 14.0);
		vec2 along = EYEDIR.xz / max(y + 0.35, 0.2) * 2.2;
		float glow = band * (0.45 + 0.75 * fbm(along * 1.3));
		float lanes = smoothstep(0.52, 0.78, fbm(along * 2.6 + 11.0)) * exp(-across * across * 60.0);
		glow *= 1.0 - 0.75 * lanes;
		col += mix(vec3(0.42, 0.48, 0.7), vec3(0.7, 0.62, 0.55), band * band) * glow * 0.15 * stars * clear;
		vec3 field = star_layer(EYEDIR, 180.0, 0.32 + 0.4 * band * (1.0 - lanes), 0.14, 0.55, 0.0, shimmer, TIME);
		field += star_layer(EYEDIR, 72.0, 0.22, 0.085, 1.1, 0.0, shimmer, TIME + 3.0);
		field += star_layer(EYEDIR, 29.0, 0.1, 0.045, 2.2, 0.35, shimmer * 0.7, TIME + 7.0);
		col += field * stars * clear;
	}
	}
	COLOR = col;
}
"""
var content: Node3D
var environment: WorldEnvironment
var sun: DirectionalLight3D
var current_round := -1
var night := false
var elapsed := 0.0
## The fighting dais surface; tests and previews use it to confirm a
## textured, solid floor exists for every round.
var floor_material: ShaderMaterial
var sky_material: ShaderMaterial
var surface_shader: Shader
var materials: Dictionary = {}
## Prayer-flag pivots; flutter samples the stage clock so the move-guide
## pause (which stops animate()) also freezes them.
var flags: Array[Node3D] = []
var lamp_lights: Array[OmniLight3D] = []
var lanterns: Array[Node3D] = []
## How many separate scenery meshes were merged into shared batches for the
## current round (see _batch_static); the arena's piece count, for tests.
var batched_pieces := 0
var fade: ColorRect
## Full-screen finishing pass (arena_grade.gdshader), drawn under the HUD.
var grade: ShaderMaterial
var grade_rect: ColorRect
var punch_level := 0.0
var flash_level := 0.0
var drain_level := 0.0
## Shadow-casting key light over the dais; the sun handles the daytime.
var key_light: SpotLight3D

func _ready() -> void:
	environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	add_child(environment)
	sky_material = ShaderMaterial.new()
	sky_material.shader = Shader.new()
	sky_material.shader.code = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_material
	# The sky shader reads TIME (drifting clouds, twinkling stars), which
	# would make Godot rebuild the whole sky lighting cubemap every frame.
	# It is built once per mood at a small size instead (soft reflections are
	# all the fighters need) and the clouds still move in the background.
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = sky
	# ACES keeps saturated lamplight and costume colours from clipping to
	# white the way the plain filmic curve did; exposure is set per round.
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment.tonemap_white = 6.0
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	# One shadow pass, not four cascades: every pass redraws both fighters,
	# and rigged fighters are the dearest thing on screen. The single map
	# covers the dais and the near square at the full 4096 atlas; the far
	# square and houses go unshadowed, which the lamps and haze hide.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 18.0
	sun.directional_shadow_fade_start = 0.8
	sun.shadow_blur = 1.1
	sun.shadow_normal_bias = 1.6
	add_child(sun)
	_grade()
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.graphics_changed.connect(_apply_graphics)
		_apply_graphics()
	surface_shader = Shader.new()
	surface_shader.code = SURFACE_SHADER

func show_round(index: int) -> void:
	index = clampi(index, 0, ROUNDS.size() - 1)
	if index == current_round:
		var settings := get_node_or_null("/root/Settings")
		# A fixed arena can repeat every round. Apply deferred scenery quality
		# here, during the round break, even when the stage index is unchanged.
		if settings == null or (settings.detailed_textures == built_detailed and _lite_scenery() == built_lite):
			return
	current_round = index
	night = ROUNDS[index].night or force_night
	var changing := content != null
	if content != null:
		remove_child(content)
		content.queue_free()
	flags.clear()
	kites.clear()
	eagles.clear()
	yaks.clear()
	lamp_lights.clear()
	lanterns.clear()
	content = Node3D.new()
	content.name = "HeritageScenery"
	add_child(content)
	elapsed = 0
	_lighting()
	_import_arena(index)
	if PROPS.has(index) and ResourceLoader.exists(PROPS[index] + "pagoda.glb"):
		_dress_heritage(PROPS[index])
	elif PROPS.has(index) and ResourceLoader.exists(PROPS[index] + "stupa_game.res"):
		_dress_stupa(PROPS[index])
	elif PROPS.has(index) and ResourceLoader.exists(PROPS[index] + "tharu_house.glb"):
		_dress_terai(PROPS[index])
	elif PROPS.has(index) and ResourceLoader.exists(PROPS[index] + "hill_house.glb"):
		_dress_hill(PROPS[index])
		if index == 5:
			_dress_dashain()
	elif PROPS.has(index) and ResourceLoader.exists(PROPS[index] + "sherpa_lodge.glb"):
		_dress_himalaya(PROPS[index])
	# The Terai is flat: no ranges behind it, a forest line instead.
	if index != 1:
		content.add_child(HIMALAYA.build(_mood()[1], night, index in [2, 3, 5], index == 3))
		_shape_backdrop(index, content.get_node("HimalayaBackdrop"))
	_fight_lighting()
	_arena_inlay()
	if RAILINGS:
		_railings()
	_batch_static()
	if index == 4:
		# The model's green terrace hills sit far below the pass; merged into
		# batches they escape the clear-out, so hide those batches.
		for node in content.get_children():
			if node is MeshInstance3D and String(node.name).begins_with("Batched"):
				var box: AABB = node.get_aabb()
				if box.end.y < -1.0:
					node.visible = false
	_ambience()
	if changing:
		_fade_in()

## Carved stone balustrades closing the fighting strip at both ends: a
## plinth, a row of turned balusters, a cap rail and square end posts with
## pyramid caps, in the temple stone. Their inner face is the invisible wall
## arena_3d.gd stops the fighters at, so a fighter knocked into it is seen
## to hit stone.
## Switched off for now: the arena ends stay open and invisible.
const RAILINGS := false
const RAIL_X := 4.76
## The strip runs z -1.4 (far) to 0.85 (near): stopping short on the camera
## side keeps the near post from filling the corner of the screen.
const RAIL_FAR := -1.4
const RAIL_NEAR := 0.85

func _railings() -> void:
	# Weathered sandstone, darker than the dais so the rail reads apart.
	var stone := _surface("rail_stone", 1, Color("8a7b67"), Color("4a4035"), 1.4)
	var length := RAIL_NEAR - RAIL_FAR
	var middle := (RAIL_NEAR + RAIL_FAR) * 0.5
	for side in [-1.0, 1.0]:
		var x: float = side * RAIL_X
		_box(Vector3(0.42, 0.22, length), Vector3(x, 0.11, middle), stone)
		_box(Vector3(0.36, 0.12, length), Vector3(x, 0.96, middle), stone)
		_box(Vector3(0.3, 0.05, length - 0.1), Vector3(x, 0.245, middle), stone)
		var count := 9
		for i in range(1, count):
			var z := RAIL_FAR + length * i / count
			_frustum(0.06, 0.045, 0.32, Vector3(x, 0.27, z), stone, 8)
			_frustum(0.045, 0.06, 0.32, Vector3(x, 0.59, z), stone, 8)
		for z in [RAIL_FAR, RAIL_NEAR]:
			_box(Vector3(0.46, 1.16, 0.46), Vector3(x, 0.58, z), stone)
			_box(Vector3(0.54, 0.08, 0.54), Vector3(x, 1.2, z), stone)
			_frustum(0.22, 0.03, 0.24, Vector3(x, 1.24, z), stone)

## Imported scenes already include the plaza, dais, flags and practical
## lamps. Keep their transforms intact: the solid fighting floor is y=0.
func _import_arena(index: int) -> void:
	var settings := get_node_or_null("/root/Settings")
	built_detailed = settings == null or settings.detailed_textures
	built_lite = _lite_scenery()
	var packed := _load_arena_model(index)
	if packed == null or not packed.can_instantiate():
		_build_fallback(index)
		return
	var model := packed.instantiate() as Node3D
	model.name = "ArenaModel"
	model.set_meta("source_glb", ARENA_MODELS[index])
	content.add_child(model)
	floor_material = _surface("dais", 5, Color("8a8071"), Color("463f37"))
	floor_material.set_shader_parameter("wetness", 0.75 if night else 0.12)
	var polished: Dictionary = {}
	for node in model.find_children("*", "", true, false):
		if node is OmniLight3D:
			# glTF stores candela; Godot's non-physical renderer uses energy.
			node.light_energy = (0.95 if node.position.y > 2.0 else 1.1) if night else 0.35
			node.set_meta("base", node.light_energy)
			lamp_lights.append(node)
		elif node is MeshInstance3D:
			var bounds: AABB = node.mesh.get_aabb()
			# Identify the supplied dais geometrically, independent of exporter names.
			# Older glTF decoders pad bounds by roughly 0.00001 units.
			if bounds.size.distance_to(Vector3(12.2, 0.12, 3.8)) < 0.001:
				node.material_override = floor_material
				continue
			for surface in node.mesh.get_surface_count():
				var original: Material = node.get_active_material(surface)
				# The models' flat vertex-coloured ridge strips are replaced by
				# the generated Himalaya backdrop (see himalaya_backdrop.gd).
				if node.mesh is ArrayMesh and node.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR and bounds.size.x > 100.0:
					node.visible = false
					break
				if original is StandardMaterial3D and original.emission_enabled:
					var paper: StandardMaterial3D = original.duplicate()
					paper.emission = paper.albedo_color
					paper.emission_energy_multiplier = 0.65
					node.set_surface_override_material(surface, paper)
				if original is StandardMaterial3D and original.albedo_texture != null and not original.emission_enabled:
					var kind := _surface_kind(original.albedo_texture, bounds)
					if not kind.is_empty():
						if built_detailed:
							node.set_surface_override_material(surface, _photo_material(kind))
							continue
					if not polished.has(original):
						var finish := ShaderMaterial.new()
						finish.shader = IMPORTED_SURFACE
						finish.set_shader_parameter("color_texture", original.albedo_texture)
						finish.set_shader_parameter("tint", original.albedo_color)
						finish.set_shader_parameter("roughness", original.roughness)
						finish.set_shader_parameter("wetness", 0.65 if night else 0.15)
						polished[original] = finish
					node.set_surface_override_material(surface, polished[original])
			# The exports preserve the cloth/lantern hanger pivots.
			if node.get_parent() is Node3D and node.get_parent().get_parent() != model and node.get_parent().get_child_count() <= 3:
				var pivot: Node3D = node.get_parent()
				if bounds.size.z < 0.01 and bounds.size.x < 0.5 and bounds.size.y < 0.7 and not flags.has(pivot):
					flags.append(pivot)
				elif index == 1 and bounds.size.distance_to(Vector3(0.26, 0.3, 0.26)) < 0.001 and not lanterns.has(pivot):
					lanterns.append(pivot)
					_lantern_halo(pivot)

## Which photo surface replaces a baked pattern texture, recognised by its
## average colour (the exporter bakes one flat pattern per surface type).
## Returns "" for textures kept as they are (carved lattice, gilt roofs).
static var _kind_cache: Dictionary = {}
func _surface_kind(texture: Texture2D, bounds: AABB) -> String:
	var kind: String
	if _kind_cache.has(texture):
		kind = _kind_cache[texture]
	else:
		var image := texture.get_image()
		if image == null:
			return ""
		image = image.duplicate()
		if image.is_compressed():
			image.decompress()
		image.resize(1, 1, Image.INTERPOLATE_BILINEAR)
		var c := image.get_pixel(0, 0)
		var lum := 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
		if lum < 0.14 or (c.r > 0.6 and c.g > 0.45 and c.b < 0.35 and c.r - c.b > 0.35):
			kind = ""
		elif lum > 0.82:
			kind = "whitewash"
		elif absf(c.r - c.g) < 0.07 and absf(c.g - c.b) < 0.09 and lum > 0.3:
			kind = "stone"
		elif c.r > 0.7 and c.g > 0.65 and c.b > 0.5:
			kind = "plaster"
		elif c.r > c.g * 1.5 and lum > 0.3:
			kind = "brick"
		elif c.r > c.g * 1.7:
			kind = "roof"
		else:
			kind = "wood"
		_kind_cache[texture] = kind
	# The plaza is one huge flat slab; walls and plinths get the older brick.
	if kind == "brick":
		kind = "paving_brick" if bounds.size.y < 0.5 and bounds.size.x > 20.0 else "wall_brick"
	return kind

## Settings' shadow level drives the sun; switching arena textures
## rebuilds the current round so the change shows immediately.
var built_detailed := true
var built_lite := false
## Decorative home-menu scenery can use the lighter prop set independently
## of the player's graphics choice for actual fights.
var light_scenery_override := false
## Lighter scenery props on LOW and MEDIUM; only HIGH (and a custom mix with
## shadows) pays for the full carving.
func _lite_scenery() -> bool:
	if light_scenery_override:
		return true
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return false
	if settings.quality == settings.Quality.CUSTOM:
		return settings.shadows < 2 and settings.anti_aliasing < 2
	return settings.quality != settings.Quality.HIGH
func _apply_graphics() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null or sun == null:
		return
	if sky_material != null:
		sky_material.set_shader_parameter("detail", 0.0 if settings.quality == settings.Quality.LOW else 1.0)
	sun.shadow_enabled = settings.shadows > 0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 18.0 if settings.shadows == 2 else 14.0
	if key_light != null:
		key_light.shadow_enabled = _key_shadow()
	if environment != null and current_round >= 0:
		environment.environment.glow_enabled = _effects_level() > 0
		grade_rect.visible = _effects_level() > 0
	if (settings.detailed_textures != built_detailed or _lite_scenery() != built_lite) and current_round >= 0:
		# Auto-adjust must not stall combat rebuilding the stage. Immediate
		# shadow/effect changes above still apply; new scenery loads next round.
		if settings.adaptive_adjusting:
			return
		var round_index := current_round
		current_round = -1
		show_round(round_index)

## The night key light's shadow is a whole extra scene pass, so only the
## HIGH shadow setting pays for it; the contact blobs ground the fighters
## on MEDIUM and LOW.
func _key_shadow() -> bool:
	var settings := get_node_or_null("/root/Settings")
	return settings == null or settings.shadows == 2

func _photo_material(kind: String) -> ShaderMaterial:
	var key := kind + ("_night" if night else "_day")
	if photo_materials.has(key):
		return photo_materials[key]
	var spec: Array = PHOTO_TEXTURES[kind]
	var folder := "res://assets/arenas/textures/%s/%s_" % [spec[0], spec[0]]
	var material := ShaderMaterial.new()
	material.shader = PHOTO_SURFACE
	material.set_shader_parameter("albedo_map", load(folder + "diff_1k.jpg"))
	material.set_shader_parameter("normal_map", load(folder + "nor_gl_1k.jpg"))
	material.set_shader_parameter("roughness_map", load(folder + "rough_1k.jpg"))
	material.set_shader_parameter("world_size", spec[1])
	material.set_shader_parameter("tint", spec[2])
	material.set_shader_parameter("normal_strength", spec[3])
	material.set_shader_parameter("saturation", spec[4])
	material.set_shader_parameter("wetness", 0.65 if night and kind in ["paving_brick", "stone"] else 0.0)
	photo_materials[key] = material
	return material

static func _load_arena_model(index: int) -> PackedScene:
	var path: String = ARENA_MODELS[index]
	if arena_cache.has(path):
		return arena_cache[path]
	# The raw .glb is decoded on the spot (see below); an export that left it
	# out (a phone build without the include filter) falls back to the
	# editor's imported scene instead of the old procedural square.
	if not FileAccess.file_exists(path) and ResourceLoader.exists(path):
		var imported := load(path) as PackedScene
		if imported != null:
			arena_cache[path] = imported
			return imported
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_file(path, state)
	if result != OK:
		push_warning("Could not decode arena %s (%s); using procedural scenery." % [path, error_string(result)])
		return null
	var model := document.generate_scene(state)
	if model == null:
		push_warning("Arena %s has no scene; using procedural scenery." % path)
		return null
	var packed := PackedScene.new()
	result = packed.pack(model)
	model.free()
	if result != OK:
		push_warning("Could not cache arena %s; using procedural scenery." % path)
		return null
	arena_cache[path] = packed
	return packed

## Asset failures must still leave a visible floor and complete arena.
func _build_fallback(index: int) -> void:
	_ground()
	_houses()
	match index:
		0, 1:
			_pagoda(Vector3(0, -0.12, -24))
			for side in [-1.0, 1.0]:
				_shikhara(Vector3(side * 8.2, -0.12, -19.5))
		2:
			_overlook()
		3:
			_stupa(Vector3(0, -0.12, -25))
	if index == 1:
		_lantern_strings()
	elif index != 3:
		_flag_line(Vector3(-6.4, 3.7, -4.6), Vector3(6.4, 3.7, -4.6), 0.55, 35)
		_flag_poles(6.4, 3.7, -4.6)
	_butter_lamps()

## A small soft halo works in Compatibility without full-screen bloom.
func _lantern_halo(parent: Node3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://scripts/lantern_glow.gdshader")
	var sprite := _piece(quad, Vector3(0, -0.22, 0), glow, parent)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Broad, low-energy fill separates silhouettes from dark architecture.
## These lights stay outside the fighting lane and never change collision.
func _fight_lighting() -> void:
	var fill := OmniLight3D.new()
	fill.name = "FighterFill"
	fill.position = Vector3(0, 4, 3)
	fill.omni_range = 13
	fill.light_color = Color("b8d9ff") if night else Color("fff0d6")
	fill.light_energy = 0.5 if night else 0.35
	content.add_child(fill)
	var rim := OmniLight3D.new()
	rim.name = "FighterRim"
	rim.position = Vector3(0, 3.4, -3)
	rim.omni_range = 10
	rim.light_color = Color("ffb46e") if current_round in [1, 2, 5] else Color("a0cfff")
	rim.light_energy = 1.1 if night else 0.6
	content.add_child(rim)
	# A shadow-casting key light over the dais. At night the moon's shadows
	# are too faint to ground the fighters, so a warm (cold, for the stupa)
	# spot from high in front does it; by day the sun already does.
	key_light = null
	if night:
		key_light = SpotLight3D.new()
		key_light.name = "DaisKey"
		key_light.position = Vector3(1.5, 6.5, 4.5)
		key_light.look_at_from_position(key_light.position, Vector3(0, 0.9, 0), Vector3.UP)
		key_light.spot_range = 14.0
		key_light.spot_angle = 42.0
		key_light.spot_attenuation = 0.9
		key_light.light_color = Color("ffc98a") if current_round in [0, 1] else Color("b9cdf5")
		key_light.set_meta("base", 1.35 if current_round in [0, 1] else 1.1)
		key_light.light_energy = key_light.get_meta("base")
		key_light.shadow_enabled = _key_shadow()
		key_light.shadow_blur = 1.5
		key_light.shadow_normal_bias = 1.4
		content.add_child(key_light)
	if night:
		for side in [-1.0, 1.0]:
			var wash := OmniLight3D.new()
			wash.position = Vector3(side * 7.5, 3.5, -17)
			wash.omni_range = 15
			wash.light_color = Color("ffaf68") if current_round in [0, 1] else Color("adc7ff")
			wash.light_energy = 0.95
			content.add_child(wash)

## Merges every static scenery mesh that shares a material (and vertex
## layout and shadow setting) into one mesh, the way shipped games bake
## their arenas: ~600 separately drawn bricks, beams, steps and lamps become
## a couple of dozen draws, which is what integrated GPUs choke on. Pieces
## that move (flag and lantern pivots), lights, particles and the shared
## Himalayan backdrop stay as they are. World-space shaders are unaffected
## because merged vertices keep their world positions.
func _batch_static() -> void:
	batched_pieces = 0
	if not is_inside_tree() or content == null:
		return
	var moving := {}
	for pivot in flags:
		moving[pivot] = true
	for pivot in lanterns:
		moving[pivot] = true
	var to_content := content.global_transform.affine_inverse()
	var groups := {}
	var merged: Array[Node] = []
	for node in content.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null or not node.is_visible_in_tree() or _moves_or_shared(node, moving):
			continue
		var parts := []
		for surface in node.mesh.get_surface_count():
			if node.mesh is ArrayMesh and node.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				parts.clear()
				break
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var layout := "%d%d%d%d" % [int(arrays[Mesh.ARRAY_COLOR] != null), int(arrays[Mesh.ARRAY_TEX_UV] != null),
				int(arrays[Mesh.ARRAY_TEX_UV2] != null), int(arrays[Mesh.ARRAY_TANGENT] != null)]
			parts.append([node.get_active_material(surface), layout, surface])
		if parts.is_empty():
			continue
		var place: Transform3D = to_content * node.global_transform
		for part in parts:
			var key := [part[0], part[1], node.cast_shadow]
			if not groups.has(key):
				groups[key] = []
			groups[key].append([node.mesh, part[2], place])
		merged.append(node)
	for key in groups:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for piece in groups[key]:
			tool.append_from(piece[0], piece[1], piece[2])
		var batch := MeshInstance3D.new()
		batch.name = "Batched"
		batch.mesh = tool.commit()
		batch.material_override = key[0]
		batch.cast_shadow = key[2]
		content.add_child(batch)
	for node in merged:
		node.get_parent().remove_child(node)
		node.queue_free()
	batched_pieces = merged.size()

func _moves_or_shared(node: Node, moving: Dictionary) -> bool:
	var parent := node.get_parent()
	while parent != null and parent != content:
		if moving.has(parent) or parent.name == "HimalayaBackdrop" or parent.has_meta("unbatched"):
			return true
		parent = parent.get_parent()
	return false

## Thin brass inlays make the usable lane legible without floating UI.
func _arena_inlay() -> void:
	var brass := _flat("inlay", Color("bc9855"), 0.08, 0.65)
	for side in [-1.0, 1.0]:
		_box(Vector3(11.7, 0.004, 0.018), Vector3(0, 0.003, side * 1.75), brass)
		_box(Vector3(0.018, 0.004, 3.5), Vector3(side * 5.85, 0.003, 0), brass)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.71
	ring.outer_radius = 0.73
	ring.rings = 64
	ring.ring_segments = 8
	var seal := _piece(ring, Vector3(0, 0.004, 0), brass)
	seal.scale.y = 0.12

func animate(delta: float) -> void:
	elapsed += delta
	_wander_yak(delta)
	_sync_grade()
	if punch_level > 0.0 or flash_level > 0.0 or drain_level > 0.0:
		punch_level = move_toward(punch_level, 0.0, delta * 5.5)
		flash_level = move_toward(flash_level, 0.0, delta * 3.5)
		drain_level = move_toward(drain_level, 0.0, delta * 1.6)
		grade.set_shader_parameter("punch", punch_level)
		grade.set_shader_parameter("flash", flash_level)
		grade.set_shader_parameter("drain", drain_level)
	if key_light != null:
		# The key light breathes with the flames it stands for.
		key_light.light_energy = key_light.get_meta("base") * (0.94 + 0.06 * sin(elapsed * 7.0) * sin(elapsed * 3.3))
	for i in flags.size():
		# Wind travels along the rope, so neighbouring flags ripple in sequence.
		flags[i].rotation.x = sin(elapsed * 3.1 - i * 0.55) * 0.35
		flags[i].rotation.z = sin(elapsed * 2.3 - i * 0.4) * 0.08
	for i in lanterns.size():
		lanterns[i].rotation.z = sin(elapsed * 1.6 + i * 0.9) * 0.06
	for kite in kites:
		_fly_kite(kite)
	for eagle in eagles:
		# Soaring in wide circles on the thermal, banked into the turn, now
		# and then a slow wingbeat-free rise and sink.
		var orbit: Array = eagle.get_meta("orbit")
		var a: float = float(orbit[2]) + elapsed * float(orbit[3])
		var centre: Vector3 = orbit[0]
		var radius: float = orbit[1]
		eagle.position = centre + Vector3(cos(a) * radius, sin(elapsed * 0.21 + float(orbit[2])) * 1.6, sin(a) * radius)
		var heading := Vector3(-sin(a), 0.0, cos(a))
		eagle.rotation = Vector3(0.0, atan2(-heading.z, heading.x), 0.0)
		eagle.rotate_object_local(Vector3.RIGHT, -0.38 * signf(float(orbit[3])))
	for i in lamp_lights.size():
		var flicker := 0.86 + 0.14 * sin(elapsed * 11.0 + i * 2.1) * sin(elapsed * 4.7 + i)
		lamp_lights[i].light_energy = lamp_lights[i].get_meta("base") * flicker

# --- materials and primitives -------------------------------------------

func _surface(key: String, pattern: int, base: Color, joint: Color, surface_scale := 1.0) -> ShaderMaterial:
	if not materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = surface_shader
		material.set_shader_parameter("pattern", pattern)
		material.set_shader_parameter("base_color", base)
		material.set_shader_parameter("joint_color", joint)
		material.set_shader_parameter("scale", surface_scale)
		materials[key] = material
	return materials[key]

func _flat(key: String, color: Color, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	if not materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85 if metal == 0.0 else 0.35
		material.metallic = metal
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if glow > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = glow
		materials[key] = material
	return materials[key]

func _brick() -> ShaderMaterial:
	return _surface("brick", 0, Color("a4513a"), Color("5e4a3c"))

func _stone() -> ShaderMaterial:
	return _surface("stone", 1, Color("a09685"), Color("5f584e"))

func _wood() -> ShaderMaterial:
	return _surface("wood", 4, Color("4a2e1d"), Color("2a190f"))

func _roof() -> ShaderMaterial:
	return _surface("roof", 2, Color("6b3b28"), Color("2b1a13"))

func _lattice() -> ShaderMaterial:
	return _surface("lattice", 6, Color("3a2416"), Color("0d0806"))

func _gold() -> StandardMaterial3D:
	return _flat("gold", Color("d4a646"), 0.0, 0.7)

func _piece(shape: Mesh, at: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	node.position = at
	(parent if parent != null else content).add_child(node)
	return node

func _box(size: Vector3, at: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _piece(shape, at, material, parent)

## Square (or n-sided) frustum; four sides are turned so edges follow the axes.
func _frustum(bottom_half: float, top_half: float, height: float, at: Vector3, material: Material, sides := 4) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	var corner := sqrt(2.0) if sides == 4 else 1.0
	shape.bottom_radius = bottom_half * corner
	shape.top_radius = top_half * corner
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	var node := _piece(shape, at + Vector3(0, height * 0.5, 0), material)
	if sides == 4:
		node.rotation.y = PI / 4.0
	return node

func _ball(radius: float, at: Vector3, material: Material, squash := 1.0) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 20
	shape.rings = 10
	var node := _piece(shape, at, material)
	node.scale.y = squash
	return node

# --- sky, light and ground ----------------------------------------------

## Heritage Square: swaps the block pagoda, stone towers, temple lions,
## plank windows and doorways and the corner lamp boxes for Meshy props.
## Pieces are recognised by position and shape in the arena model, so the
## model file itself stays as supplied.
func _dress_heritage(folder: String) -> void:
	var model := content.get_node_or_null("ArenaModel") as Node3D
	if model == null:
		return
	var to_content := content.global_transform.affine_inverse()
	var windows: Array = []  # [centre, width, facing]
	var doors: Array = []
	var doomed: Array[Node] = []
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (to_content * node.global_transform) * node.get_aabb()
		var centre := box.get_center()
		var size := box.size
		var facing := 1.0 if centre.x < 0.0 else -1.0
		var square := absf(size.x - size.z) < 0.05
		if absf(centre.x) < 4.4 and centre.z < -19.0 and centre.z > -33.0 and size.x < 14.0:
			doomed.append(node)  # pagoda, its stairs and lions
		elif absf(centre.x) > 6.2 and absf(centre.x) < 10.3 and centre.z > -21.7 and centre.z < -17.3 and square:
			doomed.append(node)  # stone towers
		elif absf(centre.x) > 5.0 and absf(centre.x) < 6.0 and absf(centre.z + 1.55) < 0.5 and box.end.y < 0.5:
			doomed.append(node)  # lamp box and its clay bowls
		elif size.x < 0.3 and absf(centre.x) > 7.9 and absf(centre.x) < 8.8:
			var wall := box.position.x if facing > 0.0 else box.end.x
			if size.distance_to(Vector3(0.12, 1.5, 1.1)) < 0.05:
				doors.append([Vector3(wall, box.position.y, centre.z), facing])
				doomed.append(node)
			elif size.distance_to(Vector3(0.16, 0.16, 1.5)) < 0.05:
				doomed.append(node)  # door lintel
			elif absf(size.y - 1.05) < 0.03 and size.x < 0.2 and (absf(size.z - 0.96) < 0.03 or absf(size.z - 2.44) < 0.03):
				windows.append([Vector3(wall, centre.y, centre.z), size.z, facing])
				doomed.append(node)
			elif absf(size.y - 0.84) < 0.03 or (absf(size.y - 0.1) < 0.02 and size.z > 1.0):
				doomed.append(node)  # window pane and sill
	for node in doomed:
		node.get_parent().remove_child(node)
		node.free()
	var floor_y := -0.12
	_place_prop(folder + "pagoda.glb", Vector3(0, floor_y, -24.4), 0.0)
	# The real range rises beyond the rooftops, hazed by distance fog.
	var range_path: String = folder + "himalaya.glb"
	if ResourceLoader.exists(range_path):
		var peaks := (load(range_path) as PackedScene).instantiate() as Node3D
		peaks.position = Vector3(0, -4.0, -175.0)
		peaks.scale = Vector3(1.6, 1.5, 1.0)
		content.add_child(peaks)
		# Dressed in the same terrain surface as the far range: snow above a
		# line set from the model's own height, rock, carved relief, valley
		# mist round its feet and the moonlit treatment at night.
		var meshes := peaks.find_children("*", "MeshInstance3D", true, false)
		var low := INF
		var high := -INF
		for mesh: MeshInstance3D in meshes:
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			low = minf(low, box.position.y)
			high = maxf(high, box.end.y)
		var surface := HIMALAYA.peak_material(_mood()[1], night, low, high)
		for mesh: MeshInstance3D in meshes:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.material_override = surface
	if night:
		_heritage_night(floor_y)
	for side in [-1.0, 1.0]:
		# The towers (4 m across) stand at the back corners of the square,
		# beside the pagoda and behind the ends of the house rows (which stop
		# at about z -23), so they frame the temple without hiding the houses.
		_place_prop(folder + "shikhara.glb", Vector3(side * SHIKHARA_X, floor_y, SHIKHARA_Z), 0.0)
		_place_prop(folder + "lion.glb", Vector3(side * 3.0, floor_y, -19.0), 0.0)
		_place_prop(folder + "diyo_stand.glb", Vector3(side * 5.5, 0.0, -1.55), 0.0)
		for z in [-15.0, -8.0]:
			_place_prop(folder + "lamp_post.glb", Vector3(side * 6.9, floor_y, z), -side * PI / 2.0)
	for door in doors:
		_place_prop(folder + "doorway.glb", door[0], door[1] * PI / 2.0, 1.35 / 1.75, CARVED_WOOD)
	# Newari windows come in pairs: each run of three small panes, or one
	# wide pane, becomes two carved windows side by side.
	windows.sort_custom(func(a, b): return [a[0].x, a[0].y, a[0].z] < [b[0].x, b[0].y, b[0].z])
	var runs: Array = []
	for window in windows:
		var last: Array = runs.back() if not runs.is_empty() else []
		var joined := false
		if not last.is_empty():
			var prev: Array = last.back()
			joined = absf(prev[0].x - window[0].x) < 0.05 and absf(prev[0].y - window[0].y) < 0.05 				and window[0].z - window[1] * 0.5 - (prev[0].z + prev[1] * 0.5) < 0.2
		if joined:
			last.append(window)
		else:
			runs.append([window])
	for run: Array in runs:
		var low: float = run[0][0].z - run[0][1] * 0.5
		var high: float = run.back()[0].z + run.back()[1] * 0.5
		var width := (high - low) / 2.0
		for part in 2:
			var at: Vector3 = run[0][0]
			at.z = low + width * (part + 0.5)
			var scale := width / 1.28
			at.y -= 1.15 * scale * 0.5
			_place_prop(folder + "window.glb", at, run[0][2] * PI / 2.0, scale, CARVED_WOOD)
			if night:
				_window_glow(at, run[0][2], width, 1.15 * scale)

## Dark carved wood: lifted and warmed so the blue sky light doesn't read it
## as grey stone.
const CARVED_WOOD := Color(1.3, 0.98, 0.68)
## Tinted copies shared by every placement, so repeats batch together.
var _tinted: Dictionary = {}

## Facade pieces (tinted) sit flat on walls: their shadows would only fall
## on the wall behind, so they skip the shadow pass.
const SHIKHARA_X := 7.5
const SHIKHARA_Z := -26.0
## The lantern on lamp_post.glb, out along its arm (model space, metres).
const LAMP_LANTERN := Vector3(0.17, 2.75, 0.0)

## Night in the square: warm pools under each lamp post, golden light up
## the pagoda's tiers and the towers, and a moonlit rim on the lions.
func _heritage_night(floor_y: float) -> void:
	var lights := [
		# [position, colour, energy, range]
		[Vector3(0, floor_y + 0.6, -20.6), Color("ffb25c"), 2.6, 9.0],   # pagoda steps, up the facade
		[Vector3(0, floor_y + 4.2, -21.4), Color("ffc27a"), 1.6, 7.5],   # lower tiers
		[Vector3(0, floor_y + 7.8, -22.4), Color("ffc27a"), 1.2, 6.5],   # upper tiers
	]
	for side in [-1.0, 1.0]:
		lights.append([Vector3(side * SHIKHARA_X, floor_y + 0.6, SHIKHARA_Z + 2.6), Color("ffb868"), 1.6, 6.5])  # tower base
		for z in [-15.0, -8.0]:
			lights.append([Vector3(side * 6.7, floor_y + 3.0, z), Color("ffb45a"), 1.8, 6.0])  # lamp posts
	for spec in lights:
		var lamp := OmniLight3D.new()
		lamp.position = spec[0]
		lamp.light_color = spec[1]
		lamp.light_energy = spec[2]
		lamp.omni_range = spec[3]
		lamp.omni_attenuation = 1.4
		lamp.set_meta("base", spec[2])
		content.add_child(lamp)
		lamp_lights.append(lamp)
	# The cone of each lamp's light falling from its lantern (which holds
	# its own candle) through the night mist to the flagstones.
	for side in [-1.0, 1.0]:
		for z in [-15.0, -8.0]:
			var lantern: Vector3 = Vector3(side * 6.9, floor_y, z) + Basis(Vector3.UP, -side * PI / 2.0) * LAMP_LANTERN
			_light_cone(lantern - Vector3(0, 0.3, 0), lantern.y - 0.3 - floor_y, 1.0, Color(1.0, 0.7, 0.38, 0.16))
	# Butter lamps glowing on the stands at both ends of the fighting floor.
	for side in [-1.0, 1.0]:
		var diyo := OmniLight3D.new()
		diyo.position = Vector3(side * 5.5, 0.9, -1.35)
		diyo.light_color = Color("ffb35c")
		diyo.omni_range = 3.2
		diyo.omni_attenuation = 1.6
		diyo.set_meta("base", 1.0)
		content.add_child(diyo)
		lamp_lights.append(diyo)
	# Paper lanterns strung high across the back of the square.
	_lantern_strings([[-9.0, 4.6], [-14.0, 4.9]], false, false)

## Lamplight behind a carved window: a warm pane just inside the lattice, so
## the carving reads dark against it. Each window differs, like rooms
## people live in: about a third stay dark, the rest burn a dim oil-lamp
## amber at one of three strengths (bright enough to glow, never so bright
## the bloom turns them flat white).
const WINDOW_LAMPS := [["window_glow_low", Color("b8602a"), 0.35], ["window_glow_dim", Color("d9782f"), 0.55], ["window_glow_warm", Color("ee9140"), 0.8]]

func _window_glow(at: Vector3, facing: float, width: float, height: float) -> void:
	var pick := absi(hash(Vector3i(roundi(at.x * 10.0), roundi(at.y * 10.0), roundi(at.z * 10.0)))) % 100
	if pick < 35:
		return
	var lamp: Array = WINDOW_LAMPS[pick % WINDOW_LAMPS.size()]
	var pane := QuadMesh.new()
	pane.size = Vector2(width * 0.62, height * 0.62)
	var glow := _piece(pane, at + Vector3(facing * 0.012, height * 0.5, 0.0), _flat(lamp[0], lamp[1], lamp[2]))
	glow.rotation.y = facing * PI / 2.0
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A soft cone of light hanging under a lamp: brightest at the flame,
## fading to nothing at the ground and at its edges.
const LIGHT_CONE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.4, 0.15);
void fragment() {
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float fall = pow(1.0 - clamp(UV.y, 0.0, 1.0), 1.6);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * edge * fall;
}
"""
func _light_cone(top: Vector3, length: float, radius: float, tint: Color) -> void:
	if not materials.has("light_cone"):
		var shader := Shader.new()
		shader.code = LIGHT_CONE
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("tint", tint)
		materials["light_cone"] = material
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = radius
	cone.height = length
	cone.radial_segments = 20
	cone.cap_top = false
	cone.cap_bottom = false
	var beam := _piece(cone, top - Vector3(0, length * 0.5, 0), materials["light_cone"])
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Boudha: the arena model's simple white stupa (with its flag lines and
## lamp row) and its houses are cut out; the sculpted Boudhanath stupa
## stands in an open stone courtyard, ringed by a monastery hall, monk
## quarters, prayer wheels, a butter lamp altar and a sang incense burner
## (Meshy props in props/stupa/).
##
## BOUDHA_LAYOUT is the whole arrangement, one row per piece, so it is easy
## to adjust: [file, position (metres; x across the screen, z negative is
## away from the camera, the fight is at the origin), turn (degrees, about
## the vertical), size]. Size is the piece's footprint width in metres for
## the baked .res buildings, a plain scale for the .glb props (1 = as
## modelled at real-world size). Positions sit on the courtyard floor.
const BOUDHA_LAYOUT := [
	# The great stupa, set aside for now (uncomment to bring it back; the
	# gompa then goes behind it at z -88).
	#["stupa_game.res", Vector3(0.0, 0.0, -50.0), 0.0, 18.0],
	# The gompa closes the far end of the courtyard.
	["monastery_hall_35k.glb", Vector3(0.0, 0.0, -56.0), 0.0, 1.6],
	# Monk quarters lining both sides of the approach, facing in.
	["monk_quarters_35k.glb", Vector3(-15.5, 0.0, -10.0), 90.0, 1.45],
	["monk_quarters_35k.glb", Vector3(15.5, 0.0, -10.0), -90.0, 1.45],
	["monk_quarters_35k.glb", Vector3(-15.5, 0.0, -25.0), 90.0, 1.45],
	["monk_quarters_35k.glb", Vector3(15.5, 0.0, -25.0), -90.0, 1.45],
	["monk_quarters_35k.glb", Vector3(-15.5, 0.0, -40.0), 90.0, 1.45],
	["monk_quarters_35k.glb", Vector3(15.5, 0.0, -40.0), -90.0, 1.45],
	# Prayer wheels close behind the fight; the incense burner part way
	# down; the butter lamps burn at the foot of the stupa's steps.
	["prayer_wheels.glb", Vector3(-6.0, 0.0, -12.0), 0.0, 1.0],
	["prayer_wheels.glb", Vector3(6.0, 0.0, -12.0), 0.0, 1.0],
	["incense_burner.glb", Vector3(-8.0, 0.0, -26.0), 0.0, 1.0],
	["butter_lamps.glb", Vector3(0.0, 0.0, -42.0), 0.0, 1.4],
	# Before the hall's steps: the great drum and the long dungchen horns
	# (Tripo), and prayer-flag poles at the corners of the court.
	["monastery_drum.glb", Vector3(-5.5, 0.0, -46.0), 25.0, 2.2],
	["dungchen_horns.glb", Vector3(5.5, 0.0, -46.0), -20.0, 1.6],
	["../himalaya/prayer_pole.glb", Vector3(-9.5, 0.0, -30.0), 0.0, 2.6],
	["../himalaya/prayer_pole.glb", Vector3(9.5, 0.0, -30.0), 90.0, 2.6],
]
## Height of the stupa's spire tip over its footprint width (where the
## prayer-flag lines start).
const STUPA_PEAK := 0.97
## The old stupa, its terrace, flag lines and the pennants lying at its
## foot (flat on the ground, so the region reaches below floor level).
const STUPA_CLEAR := AABB(Vector3(-12.0, -1.0, -45.0), Vector3(24.0, 46.0, 32.0))
func _dress_stupa(folder: String) -> void:
	var model := content.get_node_or_null("ArenaModel") as Node3D
	var floor_y := -0.12
	if model != null:
		# The model's own prayer-flag strings hung from the old stupa; with
		# it gone they would lie across the courtyard.
		for pivot in flags.duplicate():
			if pivot.is_inside_tree() and model.is_ancestor_of(pivot):
				flags.erase(pivot)
				pivot.queue_free()
		_clear_region(model, STUPA_CLEAR)
		for side in [-1.0, 1.0]:
			# Houses, their carved fronts and the eaves over the courtyard.
			_clear_region(model, AABB(Vector3(6.4 if side > 0.0 else -160.0, 0.05, -160.0), Vector3(153.6, 60.0, 260.0)))
		floor_y = _open_ground(model)
	for row: Array in BOUDHA_LAYOUT:
		var at: Vector3 = row[1] + Vector3(0.0, floor_y, 0.0)
		var path: String = folder + row[0]
		if path.ends_with(".res"):
			_place_baked(path, at, deg_to_rad(row[2]), row[3])
		else:
			_place_prop(path, at, deg_to_rad(row[2]), row[3])
	# Prayer-flag lines from the spire down to the terrace edge, as at
	# Boudha; hung still, so they merge with the static scenery.
	var rows := BOUDHA_LAYOUT.filter(func(row): return row[0] == "stupa_game.res")
	if rows.is_empty():
		return
	var stupa: Array = rows[0]
	var base: Vector3 = stupa[1] + Vector3(0.0, floor_y, 0.0)
	var peak := base + Vector3(0, stupa[3] * STUPA_PEAK, 0)
	for i in 6:
		var angle := -1.2 + i * 0.48
		# Tied off at the rim of the stupa's lower terrace, not the ground.
		var reach: float = stupa[3] * 0.5
		_flag_line(peak, base + Vector3(sin(angle) * reach, stupa[3] * 0.14, cos(angle) * reach), 1.0, 22, false)

## Terai Plains: the old square's houses, lanterns and flags are cleared
## and the fight sits in a Tharu village yard of packed earth on open green
## plains: thatched mud houses painted with folk motifs, a bullock cart
## loaded with rice straw, a shrine under a great pipal tree and tall sal
## trees (Tripo models in props/terai/). Rows as BOUDHA_LAYOUT: [file,
## position, turn (degrees), scale]; the Tripo models come small, hence the
## large scales.
const TERAI_LAYOUT := [
	["tharu_house.glb", Vector3(-10.5, 0.0, -15.0), 20.0, 2.0],
	["tharu_house.glb", Vector3(9.5, 0.0, -21.0), -15.0, 2.0],
	["pipal_shrine.glb", Vector3(-1.5, 0.0, -27.0), 0.0, 10.0],
	["bullock_cart.glb", Vector3(5.2, 0.0, -10.5), -35.0, 2.3],
	["sal_tree.glb", Vector3(-16.0, 0.0, -28.0), 0.0, 5.0],
	["sal_tree.glb", Vector3(15.5, 0.0, -34.0), 70.0, 5.6],
	["sal_tree.glb", Vector3(-6.0, 0.0, -42.0), 140.0, 5.3],
	["sal_tree.glb", Vector3(18.0, 0.0, -12.0), 200.0, 4.6],
	["sal_tree.glb", Vector3(-19.0, 0.0, -8.0), 260.0, 4.8],
	["sal_tree.glb", Vector3(6.0, 0.0, -48.0), 310.0, 5.8],
]
## Hill Village: a stone-paved yard on a ridge, with Gurung houses, a bhatti
## teahouse, a chautara under its tree and rhododendrons in bloom; past the
## low stone wall the ground falls away to a valley crossed by a prayer-flag
## suspension bridge, the terraced foothills and the snowy range beyond
## (Tripo models in props/hill/). Rows as BOUDHA_LAYOUT.
const HILL_EDGE := -27.0
const HILL_DROP := 18.0
const HILL_LAYOUT := [
	["hill_house.glb", Vector3(-11.5, 0.0, -14.0), 25.0, 2.8],
	["hill_house.glb", Vector3(12.0, 0.0, -19.5), -30.0, 2.8],
	["tea_house.glb", Vector3(-6.5, 0.0, -22.5), 10.0, 1.9],
	["chautara.glb", Vector3(3.5, 0.0, -21.0), 0.0, 6.0],
	["rhododendron.glb", Vector3(-15.5, 0.0, -24.0), 0.0, 9.0],
	["rhododendron.glb", Vector3(15.5, 0.0, -9.5), 120.0, 8.0],
	["rhododendron.glb", Vector3(-17.5, 0.0, -5.0), 200.0, 8.5],
	["rhododendron.glb", Vector3(9.5, 0.0, -25.5), 60.0, 7.5],
	# Across the valley, below the ridge.
	# Hung across the valley at ridge height (its towers drop out of
	# sight below the wall line).
	["suspension_bridge.glb", Vector3(20.0, -9.0, -85.0), 60.0, 7.0],
]
func _dress_hill(folder: String) -> void:
	var model := content.get_node_or_null("ArenaModel") as Node3D
	var floor_y := -0.12
	if model != null:
		_strip_to_dais(model)
		for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if node.mesh == null:
				continue
			var box: AABB = node.global_transform * node.get_aabb()
			if box.size.x > 80.0 and box.size.y < 0.5:
				floor_y = box.end.y
				node.visible = false
	# The ridge yard of slate-grey stone, a low dry-stone wall at its edge,
	# and the valley floor far below.
	var yard := PlaneMesh.new()
	yard.size = Vector2(44, 40)
	_piece(yard, Vector3(0, floor_y, HILL_EDGE + 20.0), _ground_material("medieval_blocks_03", 2.2, Color(0.8, 0.8, 0.82))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cliff := BoxMesh.new()
	cliff.size = Vector3(44, HILL_DROP, 1.0)
	_piece(cliff, Vector3(0, floor_y - HILL_DROP * 0.5, HILL_EDGE - 0.5), _ground_material("aerial_rocks_02", 8.0, Color(0.72, 0.68, 0.62))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wall := _surface("kerb", 1, Color("7d7466"), Color("3f3a33"))
	_box(Vector3(44, 0.7, 0.6), Vector3(0, floor_y + 0.35, HILL_EDGE + 0.3), wall)
	var valley := PlaneMesh.new()
	valley.size = Vector2(400, 300)
	_piece(valley, Vector3(0, floor_y - HILL_DROP, -160), _ground_material("aerial_grass_rock", 12.0, Color(0.6, 0.72, 0.45))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A broad river along the far side of the valley, where the valley floor
	# meets the foothills (the sky showed through there as a white band).
	var river := PlaneMesh.new()
	river.size = Vector2(900, 170)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("3f6f9c")
	water.roughness = 0.18
	water.metallic = 0.35
	_piece(river, Vector3(0, floor_y - HILL_DROP - 0.05, -390), water).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for row: Array in HILL_LAYOUT:
		_place_prop(folder + row[0], row[1] + Vector3(0.0, floor_y, 0.0), deg_to_rad(row[2]), row[3])
	# Prayer flags strung between the two houses, still in the morning air.
	_flag_line(Vector3(-11.0, floor_y + 6.2, -13.0), Vector3(11.5, floor_y + 6.6, -18.5), 0.9, 34, false)
	yard_y = floor_y

## Kites over the Dashain ground and eagles above the valley, animated in
## animate().
var kites: Array[Node3D] = []
var eagles: Array[Node3D] = []
const EAGLE := "res://assets/teaser/eagle.glb"
## The hill ridge's floor height, set by _dress_hill for later dressing.
var yard_y := -0.12
const KITE_PAPER := [["c0301f", "f2c230"], ["1f4fa3", "f4ead2"], ["2e7d32", "f2c230"], ["c2185b", "f4ead2"], ["f57c00", "1f4fa3"], ["6a1b9a", "f2c230"]]

## Dashain on the ridge: a tall linge ping (bamboo swing), kites over the
## valley, butter lamps at the ends of the floor, and jamara and the tika
## thali beside the floor.
func _dress_dashain() -> void:
	var y := yard_y
	# The linge ping as the ground's centrepiece: four bamboo poles about
	# 8 m tall, standing alone in the open ground behind the floor (clear
	# of the chautara and the houses, with room for the
	# swing's arc), its A-frame spread wide to face the arena.
	_place_prop("res://assets/teaser/linge_ping.glb", Vector3(0.0, y, -10.0), deg_to_rad(90.0), 9.0)
	_place_prop("res://assets/teaser/tika_thali.glb", Vector3(-6.4, y + 0.45, -9.2), 0.0, 0.19)
	var table := BoxMesh.new()
	table.size = Vector3(0.7, 0.45, 0.7)
	_piece(table, Vector3(-6.4, y + 0.225, -9.2), _flat("dashain_table", Color("4a2c18")))
	# Jamara: barley shoots grown for the festival, in clay pots.
	var pot := CylinderMesh.new()
	pot.top_radius = 0.18
	pot.bottom_radius = 0.13
	pot.height = 0.3
	var shoot := CylinderMesh.new()
	shoot.top_radius = 0.0
	shoot.bottom_radius = 0.012
	shoot.height = 0.38
	for p: Vector3 in [Vector3(-7.4, 0, -9.6), Vector3(-5.5, 0, -9.8), Vector3(-6.0, 0, -8.4)]:
		_piece(pot, p + Vector3(0, y + 0.15, 0), _flat("clay", Color("8a4a2a")))
		for k in 14:
			var a := k * 2.39996
			var r := 0.04 + 0.1 * float(k % 4) / 3.0
			var blade := _piece(shoot, p + Vector3(cos(a) * r, y + 0.48, sin(a) * r), _flat("jamara", Color("d8c24a")))
			blade.rotation = Vector3(sin(a) * 0.25, 0, cos(a) * 0.25)
			blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Butter lamps (diyo) on low stands at both ends of the fighting floor.
	var stand := CylinderMesh.new()
	stand.top_radius = 0.22
	stand.bottom_radius = 0.28
	stand.height = 0.5
	var flame := SphereMesh.new()
	flame.radius = 0.035
	flame.height = 0.09
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 5.6, y, -1.4)
		_piece(stand, at + Vector3(0, 0.25, 0), _flat("lamp_stand", Color("8c6a2a"), 0.0, 0.6))
		for k in 5:
			var a := k * TAU / 5.0
			_piece(flame, at + Vector3(cos(a) * 0.14, 0.56, sin(a) * 0.14), _flat("diyo_flame", Color("ffb347"), 3.0))
		var glow := OmniLight3D.new()
		glow.position = at + Vector3(0, 0.75, 0)
		glow.light_color = Color("ffb35c")
		glow.omni_range = 3.4
		glow.omni_attenuation = 1.6
		glow.set_meta("base", 0.9)
		content.add_child(glow)
		lamp_lights.append(glow)
	# A few kites flown from rooftops and the ridge (Dashain afternoons):
	# each rides the wind at the end of its line, held at a steady angle,
	# drifting and dipping with the gusts (animated in animate()).
	var kite_layer := Node3D.new()
	kite_layer.name = "Kites"
	kite_layer.set_meta("unbatched", true)
	content.add_child(kite_layer)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.95, 0.95)
	var segment := CylinderMesh.new()
	segment.top_radius = 0.006
	segment.bottom_radius = 0.006
	segment.height = 1.0
	segment.radial_segments = 4
	var line_material := _flat("kite_string", Color("e9e1d0"))
	# [anchor (where it is flown from), line length, elevation, heading]
	var flights := [
		[Vector3(-11.5, y + 6.4, -14.0), 34.0, 52.0, -18.0],
		[Vector3(12.0, y + 6.4, -19.5), 40.0, 57.0, 14.0],
		[Vector3(-6.5, y + 4.6, -22.5), 28.0, 49.0, -4.0],
		[Vector3(17.5, y + 1.4, -9.0), 46.0, 55.0, 26.0],
		[Vector3(-17.0, y + 1.4, -6.0), 38.0, 50.0, -30.0],
	]
	for i in flights.size():
		var colours: Array = KITE_PAPER[(i * 2 + 1) % KITE_PAPER.size()]
		var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		for py in 48:
			for px in 48:
				var d := absf(px - 23.5) + absf(py - 23.5)
				if d < 23.0:
					image.set_pixel(px, py, Color("2a1d14") if d > 21.5 else (Color(colours[0]) if py < 24 else Color(colours[1])))
		var paper := StandardMaterial3D.new()
		paper.albedo_texture = ImageTexture.create_from_image(image)
		paper.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		paper.cull_mode = BaseMaterial3D.CULL_DISABLED
		var kite := Node3D.new()
		var sail := MeshInstance3D.new()
		sail.mesh = quad
		sail.material_override = paper
		sail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		kite.add_child(sail)
		kite_layer.add_child(kite)
		var line := Node3D.new()
		kite_layer.add_child(line)
		for k in 6:
			var piece := MeshInstance3D.new()
			piece.mesh = segment
			piece.material_override = line_material
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			line.add_child(piece)
		kite.set_meta("flight", flights[i])
		kite.set_meta("line", line)
		kites.append(kite)
	# Himalayan eagles riding a thermal high over the valley.
	if ResourceLoader.exists(EAGLE):
		for i in 3:
			var eagle: Node3D = load(EAGLE).instantiate()
			eagle.scale = Vector3.ONE * 0.9
			eagle.set_meta("orbit", [Vector3(-6.0 + i * 9.0, y + 22.0 + i * 4.0, -55.0 - i * 12.0), 14.0 + i * 5.0, i * 2.1, 0.11 - i * 0.02])
			kite_layer.add_child(eagle)
			eagles.append(eagle)

## A kite at the end of its line: the wind holds it at a steady angle above
## the flier, the heading and the angle wander slowly with the gusts, the
## paper trembles, and the line sags in a shallow curve back to the anchor.
func _fly_kite(kite: Node3D) -> void:
	var flight: Array = kite.get_meta("flight")
	var anchor: Vector3 = flight[0]
	var length: float = flight[1]
	var seed := float(kite.get_index())
	var gust := sin(elapsed * 0.23 + seed * 1.9) * 0.6 + sin(elapsed * 0.61 + seed) * 0.4
	var elevation := deg_to_rad(float(flight[2]) + gust * 4.0)
	var heading := deg_to_rad(float(flight[3]) + sin(elapsed * 0.17 + seed * 2.3) * 7.0)
	# The wind blows out over the valley (toward -Z).
	var direction := Vector3(sin(heading) * cos(elevation), sin(elevation), -cos(heading) * cos(elevation))
	var at := anchor + direction * length
	kite.position = at
	# Face back down the line, nose up, rocking a little on its bridle.
	kite.look_at(anchor, Vector3.UP)
	kite.rotate_object_local(Vector3.FORWARD, PI * 0.25 + sin(elapsed * 2.4 + seed) * 0.12)
	kite.rotate_object_local(Vector3.RIGHT, -0.35 + sin(elapsed * 1.7 + seed * 3.0) * 0.06)
	# The line: a shallow catenary from the flier's hand to the kite.
	var line: Node3D = kite.get_meta("line")
	var count := line.get_child_count()
	var sag := length * 0.045
	var previous := anchor
	for k in count:
		var u := float(k + 1) / count
		var point := anchor.lerp(at, u) - Vector3(0, sin(u * PI) * sag, 0)
		var piece := line.get_child(k) as Node3D
		var mid := (previous + point) * 0.5
		var span := point - previous
		piece.position = mid
		piece.basis = Basis(Quaternion(Vector3.UP, span.normalized())) * Basis.from_scale(Vector3(1, span.length(), 1))
		previous = point

## Himalayan Pass: the final arena, high among the snows. A wind-scoured
## yard of snow and rock with a Sherpa stone lodge, a long mani wall, a
## white chorten, a prayer-flag pole and a yak, flag lines streaming in the
## wind, snow drifting, and the great peaks close behind (Tripo models in
## props/himalaya/). Rows as BOUDHA_LAYOUT.
const HIMALAYA_LAYOUT := [
	["sherpa_lodge.glb", Vector3(-11.0, 0.0, -16.0), 20.0, 2.6],
	["chorten.glb", Vector3(3.0, 0.0, -32.0), 0.0, 2.6],
	["prayer_pole.glb", Vector3(10.5, 0.0, -13.0), 0.0, 2.4],
	["prayer_pole.glb", Vector3(-6.5, 0.0, -24.0), 0.0, 2.2],
]
func _dress_himalaya(folder: String) -> void:
	var model := content.get_node_or_null("ArenaModel") as Node3D
	var floor_y := -0.12
	if model != null:
		_strip_to_dais(model)
		# The model's green terrace hills sit below the floor line.
		_clear_region(model, AABB(Vector3(-300, -80.0, -400), Vector3(600, 79.0, 396)))
		# Snow everywhere: trodden snow in the yard, deep snow beyond.
		floor_y = _open_ground(model, "snow_field_aerial", 4.0, Color(0.9, 0.92, 0.96))
		for node in content.get_children():
			if node is MeshInstance3D and node.mesh is PlaneMesh and (node.mesh as PlaneMesh).size.x > 100.0:
				node.material_override = _ground_material("snow_field_aerial", 10.0, Color(1.0, 1.0, 1.0))
	# Rolling snow foothills between the snowfield and the range, so the
	# ground rises into the mountains instead of meeting them in a line.
	var drift := SphereMesh.new()
	drift.radius = 1.0
	drift.height = 2.0
	drift.radial_segments = 24
	drift.rings = 12
	var snow := _ground_material("snow_field_aerial", 10.0, Color(1.0, 1.0, 1.0))
	for i in 16:
		var x := -135.0 + i * 18.0 + sin(i * 4.7) * 6.0
		var z := -70.0 - fmod(i * 23.0, 45.0)
		var r := 16.0 + fmod(i * 7.3, 14.0)
		var mound := _piece(drift, Vector3(x, floor_y - r * 0.12, z), snow)
		mound.scale = Vector3(r * 1.3, r * 0.34, r)
		mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for row: Array in HIMALAYA_LAYOUT:
		_place_prop(folder + row[0], row[1] + Vector3(0.0, floor_y, 0.0), deg_to_rad(row[2]), row[3])
	_add_yak(folder, floor_y)
	# Flag lines from the chorten's spire, streaming in the wind.
	var peak := Vector3(3.0, floor_y + 11.2, -32.0)
	for target in [Vector3(-11.0, floor_y + 5.5, -14.0), Vector3(10.5, floor_y + 9.0, -13.0), Vector3(-6.5, floor_y + 8.0, -24.0), Vector3(16.0, floor_y + 0.5, -26.0)]:
		_flag_line(peak, target, 0.8, 26)
	# The dais in cold grey slate.
	if model != null:
		var slate := _surface("dais_himalaya", 5, Color("8a8f98"), Color("3c4048"))
		for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if node.material_override == floor_material:
				node.material_override = slate
		floor_material = slate

## Yaks that wander the snow behind the fight: Tripo's quadruped rig and
## walk preset, steered in animate(). Each walks to a random point in its
## pasture, stops and lowers its head to graze, then moves on.
var yaks: Array[Dictionary] = []
var _yak_rng := RandomNumberGenerator.new()
## Pastures (start point, area) behind and to the sides of the fight.
const YAK_HERD := [
	[Vector3(9.0, 0.0, -20.0), AABB(Vector3(5.0, 0.0, -30.0), Vector3(12.0, 0.0, 14.0))],
	[Vector3(-4.0, 0.0, -34.0), AABB(Vector3(-9.0, 0.0, -42.0), Vector3(8.0, 0.0, 10.0))],
]
const YAK_SPEED := 0.9
## The neck and head bones of Tripo's yak rig, bent down to graze.
const YAK_NECK := ["bone_5", "bone_6"]
func _add_yak(folder: String, floor_y: float) -> void:
	yaks.clear()
	var path := folder + "yak_walk.glb"
	if not ResourceLoader.exists(path):
		_place_prop(folder + "yak.glb", Vector3(9.0, floor_y, -20.0), deg_to_rad(-60.0), 1.4)
		return
	_yak_rng.seed = 11
	for spot: Array in YAK_HERD:
		var body := (load(path) as PackedScene).instantiate() as Node3D
		var low := INF
		for mesh: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
			low = minf(low, _local_aabb(body, mesh).position.y)
		var holder := Node3D.new()
		holder.name = "Yak"
		content.add_child(holder)
		holder.add_child(body)
		var size := _yak_rng.randf_range(1.25, 1.5)
		body.scale = Vector3.ONE * size
		body.position.y = -low * size if is_finite(low) else 0.0
		holder.position = spot[0] + Vector3(0.0, floor_y, 0.0)
		holder.rotation.y = _yak_rng.randf_range(0.0, TAU)
		var players := body.find_children("*", "AnimationPlayer", true, false)
		var anim: AnimationPlayer = players[0] if not players.is_empty() else null
		if anim != null:
			var clip: String = anim.get_animation_list()[0]
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			anim.play(clip)
			anim.seek(_yak_rng.randf_range(0.0, anim.current_animation_length), true)
			anim.pause()
		var skeletons := body.find_children("*", "Skeleton3D", true, false)
		yaks.append({"node": holder, "anim": anim, "skeleton": skeletons[0] if not skeletons.is_empty() else null,
			"area": spot[1], "floor": floor_y, "goal": holder.position,
			"rest": _yak_rng.randf_range(1.0, 4.0), "graze": 1.0})

## Walk to a goal, stand and graze a few seconds, pick another goal.
func _wander_yak(delta: float) -> void:
	for yak in yaks:
		var node: Node3D = yak.node
		if not is_instance_valid(node):
			continue
		var anim: AnimationPlayer = yak.anim
		var to: Vector3 = yak.goal - node.position
		to.y = 0.0
		var walking := false
		if yak.rest > 0.0:
			yak.rest -= delta
			if yak.rest <= 0.0:
				var area: AABB = yak.area
				yak.goal = Vector3(_yak_rng.randf_range(area.position.x, area.end.x), yak.floor, _yak_rng.randf_range(area.position.z, area.end.z))
		elif to.length() < 0.25:
			yak.rest = _yak_rng.randf_range(3.0, 7.0)
		else:
			walking = true
			# The model faces -Z: turn that toward the goal before and while
			# walking, as a heavy animal does.
			var want := atan2(-to.x, -to.z)
			node.rotation.y = lerp_angle(node.rotation.y, want, 1.0 - exp(-1.6 * delta))
			var ahead := Vector3(-sin(node.rotation.y), 0.0, -cos(node.rotation.y))
			node.position += ahead * YAK_SPEED * delta * clampf(ahead.dot(to.normalized()), 0.0, 1.0)
		if anim != null:
			if walking and not anim.is_playing():
				anim.play()
			elif not walking and anim.is_playing():
				anim.pause()
		# Grazing: the neck sinks to the snow while it stands, rises to walk.
		yak.graze = move_toward(yak.graze, 0.0 if walking else 1.0, delta * 0.8)
		_bend_neck(yak)

## Bends the yak's neck and head down about its body's side axis by the
## current graze amount (added on top of the walk clip's pose).
func _bend_neck(yak: Dictionary) -> void:
	var skeleton: Skeleton3D = yak.skeleton
	if skeleton == null:
		return
	var amount: float = smoothstep(0.0, 1.0, yak.graze)
	var side: Vector3 = (skeleton.global_transform.basis.orthonormalized().inverse() * (yak.node as Node3D).global_transform.basis.x).normalized()
	for i in YAK_NECK.size():
		var bone := skeleton.find_bone(YAK_NECK[i])
		if bone < 0:
			continue
		if not yak.has("rest_" + str(bone)):
			yak["rest_" + str(bone)] = skeleton.get_bone_pose_rotation(bone)
		var base: Quaternion = yak["rest_" + str(bone)] if not (yak.anim as AnimationPlayer).is_playing() else skeleton.get_bone_pose_rotation(bone)
		var axis: Vector3 = (skeleton.get_bone_global_pose(bone).basis.orthonormalized().inverse() * side).normalized()
		skeleton.set_bone_pose_rotation(bone, base * Quaternion(axis, -0.95 * amount if i == 0 else -0.6 * amount))

## Per-arena changes to the distant ranges, once they are built.
func _shape_backdrop(index: int, backdrop: Node3D) -> void:
	match index:
		2, 5:
			# The terraced foothills rise from the valley floor, not the ridge.
			backdrop.position.y = -0.12 - HILL_DROP + 2.0
		4:
			# The range stands close and high; above the tree line there are
			# no green foothills, and snow lies right down to the valleys.
			backdrop.scale = Vector3(0.62, 1.15, 0.62)
			backdrop.get_node("Foothills").visible = false
			var range_mesh := backdrop.get_node("Himalaya") as MeshInstance3D
			range_mesh.material_override.set_shader_parameter("snow_line", -30.0)

## Strips an imported arena model down to its fighting dais: its buildings,
## flags, lanterns and lamps go, for an arena dressed from scratch.
func _strip_to_dais(model: Node3D) -> void:
	for list in [flags, lanterns]:
		for pivot in list.duplicate():
			if pivot.is_inside_tree() and model.is_ancestor_of(pivot):
				list.erase(pivot)
				pivot.queue_free()
	_clear_region(model, AABB(Vector3(-200, -1.0, -200), Vector3(400, 80, 197.4)))
	_clear_region(model, AABB(Vector3(-200, -1.0, 2.6), Vector3(400, 80, 200)))
	for side in [-1.0, 1.0]:
		_clear_region(model, AABB(Vector3(6.6 if side > 0.0 else -206.6, -1.0, -2.6), Vector3(200, 80, 5.2)))
	_clear_region(model, AABB(Vector3(-6.6, 0.4, -2.6), Vector3(13.2, 80, 5.2)))
	for light in model.find_children("*", "OmniLight3D", true, false):
		lamp_lights.erase(light)
		light.queue_free()

func _dress_terai(folder: String) -> void:
	var model := content.get_node_or_null("ArenaModel") as Node3D
	var floor_y := -0.12
	if model != null:
		_strip_to_dais(model)
		floor_y = _open_ground(model, "aerial_rocks_02", 6.0, Color(0.62, 0.55, 0.47), Color(0.7, 0.86, 0.5))
	for row: Array in TERAI_LAYOUT:
		_place_prop(folder + row[0], row[1] + Vector3(0.0, floor_y, 0.0), deg_to_rad(row[2]), row[3])
	# Jungle right behind the huts: saplings at the edge of the yard, then
	# two thick rows of tall sal trees.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# [near z, far z, trees, smallest, largest]: saplings, then rank on
	# rank of tall sal trees, denser the deeper, so no sky or meadow shows
	# between the trunks.
	for band in [[-24.0, -30.0, 16, 1.4, 2.4], [-30.0, -38.0, 22, 4.4, 6.0], [-38.0, -48.0, 26, 5.5, 7.2],
			[-48.0, -60.0, 30, 6.0, 7.8], [-60.0, -75.0, 34, 6.5, 8.5]]:
		for i in band[2]:
			# Deeper ranks spread wider to fill the edges of the view.
			var reach: float = 42.0 + (-band[0] - 24.0) * 0.7
			var across := lerpf(-reach, reach, (i + rng.randf_range(-0.4, 0.4)) / float(band[2] - 1))
			# Keep the pipal shrine (centre, z -27) clear of saplings.
			if band[0] > -30.0 and absf(across) < 6.0:
				continue
			var depth := rng.randf_range(band[1], band[0])
			# Past the first ranks the trees are far and hazed: the light
			# version (a tenth of the triangles) reads the same there.
			var tree := "sal_tree.glb" if depth > -34.0 else "sal_tree_far.glb"
			_place_prop(folder + tree, Vector3(across, floor_y, depth), rng.randf_range(0.0, TAU), rng.randf_range(band[3], band[4]))
	_forest_wall(floor_y)
	# Sal forest along the horizon beyond the fields (far copies draw at
	# their import LODs).
	for i in 30:
		var across := lerpf(-90.0, 90.0, (i + rng.randf_range(-0.3, 0.3)) / 29.0)
		var depth := -78.0 - rng.randf_range(0.0, 14.0) - absf(across) * 0.1
		_place_prop(folder + "sal_tree_far.glb", Vector3(across, floor_y, depth), rng.randf_range(0.0, TAU), rng.randf_range(5.5, 7.5))
	# Maato tiles: the dais in sun-baked earthen clay instead of grey stone.
	if model != null:
		var clay := _surface("dais_terai", 5, Color("a87b52"), Color("5e3f28"))
		clay.set_shader_parameter("wetness", 0.0)
		for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if node.material_override == floor_material:
				node.material_override = clay
		floor_material = clay

## Deep jungle behind the trees: a curved band of dense foliage with an
## uneven canopy edge, so the gaps between trunks show forest, not sky.
const FOREST_WALL := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 leaf_dark : source_color = vec3(0.03, 0.06, 0.03);
uniform vec3 leaf_light : source_color = vec3(0.1, 0.17, 0.07);
varying vec3 world;
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float noise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y); }
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float around = atan(world.x, world.z) * 60.0;
	vec2 p = vec2(around, world.y);
	float crown = 0.55 * noise(p * vec2(0.18, 0.0)) + 0.3 * noise(p * vec2(0.6, 0.0)) + 0.15 * noise(p * vec2(1.7, 0.0));
	float top = 9.0 + crown * 9.0;
	if (world.y > top) { discard; }
	float leaves = noise(p * 1.4) * 0.6 + noise(p * 4.0) * 0.4;
	float lit = smoothstep(0.0, 1.0, (world.y - 1.0) / (top - 1.0));
	ALBEDO = mix(leaf_dark, leaf_light, leaves * (0.35 + 0.65 * lit));
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
"""
func _forest_wall(floor_y: float) -> void:
	var shader := Shader.new()
	shader.code = FOREST_WALL
	var material := ShaderMaterial.new()
	material.shader = shader
	var band := CylinderMesh.new()
	band.top_radius = 92.0
	band.bottom_radius = 92.0
	band.height = 20.0
	band.radial_segments = 96
	band.rings = 1
	band.cap_top = false
	band.cap_bottom = false
	var wall := _piece(band, Vector3(0, floor_y + 9.5, -20.0), material)
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.set_meta("unbatched", true)

## A Meshy model baked to a game mesh (unit footprint, standing on y = 0),
## placed `width` metres across. Kept out of the static merge so its LODs
## and culling apply; background pieces cast no shadow.
func _place_baked(path: String, at: Vector3, turn: float, width: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var piece := MeshInstance3D.new()
	piece.name = path.get_file().get_basename()
	piece.mesh = load(path)
	piece.position = at
	piece.rotation.y = turn
	piece.scale = Vector3.ONE * width
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.set_meta("unbatched", true)
	content.add_child(piece)

## The open monastery ground: worn stone blocks across the courtyard and
## meadow beyond it out to the foothills, in place of the brick plaza. One
## world-projected texture layer each (the photo materials' full stack is
## the HIGH preset's expensive part).
func _open_ground(model: Node3D, court_folder := "medieval_blocks_03", court_size := 2.4, court_tint := Color(0.96, 0.9, 0.82), meadow_tint := Color(0.62, 0.7, 0.5)) -> float:
	var ground_y := -0.12
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null:
			continue
		var box: AABB = node.global_transform * node.get_aabb()
		if box.size.x > 80.0 and box.size.y < 0.5:
			ground_y = box.end.y
			node.visible = false
	var meadow := _ground_material("aerial_grass_rock", 9.0, meadow_tint)
	var grass := PlaneMesh.new()
	grass.size = Vector2(320, 320)
	_piece(grass, Vector3(0, ground_y - 0.02, -40), meadow).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var court := PlaneMesh.new()
	court.size = Vector2(26, 84)
	_piece(court, Vector3(0, ground_y, -34), _ground_material(court_folder, court_size, court_tint)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ground_y

func _ground_material(folder: String, world_size: float, tint: Color) -> StandardMaterial3D:
	var key := "ground_%s_%s" % [folder, tint.to_html()]
	if materials.has(key):
		return materials[key]
	var path := "res://assets/arenas/textures/%s/%s_" % [folder, folder]
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(path + "diff_1k.jpg")
	material.albedo_color = tint
	if ResourceLoader.exists(path + "nor_gl_1k.jpg"):
		material.normal_enabled = true
		material.normal_texture = load(path + "nor_gl_1k.jpg")
		material.normal_scale = 0.8
	material.roughness = 0.92
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / world_size
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials[key] = material
	return material

## Removes every triangle of `model` whose centre lies in `region` (content
## space), keeping each surface (an emptied one keeps one degenerate
## triangle so surface material overrides stay in step).
func _clear_region(model: Node3D, region: AABB) -> void:
	var to_content := content.global_transform.affine_inverse()
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node.mesh as ArrayMesh
		if mesh == null:
			continue
		var place: Transform3D = to_content * node.global_transform
		if not (place * mesh.get_aabb()).intersects(region):
			continue
		var out := ArrayMesh.new()
		var changed := false
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index = arrays[Mesh.ARRAY_INDEX]
			if index == null or (index as PackedInt32Array).is_empty():
				index = PackedInt32Array(range(verts.size()))
			var keep := PackedInt32Array()
			for t in range(0, index.size(), 3):
				var centre: Vector3 = place * ((verts[index[t]] + verts[index[t + 1]] + verts[index[t + 2]]) / 3.0)
				if region.has_point(centre):
					changed = true
					continue
				keep.append(index[t])
				keep.append(index[t + 1])
				keep.append(index[t + 2])
			if keep.is_empty():
				keep = PackedInt32Array([0, 0, 0])
			arrays[Mesh.ARRAY_INDEX] = keep
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(surface, mesh.surface_get_material(surface))
		if changed:
			node.mesh = out

## Meshy buildings come with faceted normals: flat wall panels tilt this
## way and that, and the ones facing away from the sun catch only blue sky
## light, showing as dark triangles across whitewash. Rebuilt once per mesh
## with shared vertices welded and smooth normals.
static var smooth_cache: Dictionary = {}
static func _smooth_mesh(mesh: ArrayMesh) -> ArrayMesh:
	if smooth_cache.has(mesh):
		return smooth_cache[mesh]
	var out := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var tool := SurfaceTool.new()
		tool.create_from(mesh, surface)
		tool.set_smooth_group(0)
		tool.index()
		tool.generate_normals()
		tool.generate_tangents()
		tool.commit(out)
		out.surface_set_material(surface, mesh.surface_get_material(surface))
	smooth_cache[mesh] = out
	return out

## Prop folders made with Tripo (models centred on their origin).
const TRIPO_PROP_FOLDERS := ["terai", "hill", "himalaya", "teaser"]
## Tripo props in otherwise non-Tripo folders.
const TRIPO_PROPS := ["monastery_drum.glb", "dungchen_horns.glb"]
## A mesh's bounds in its prop's own space, before the prop joins the tree.
static func _local_aabb(prop: Node3D, mesh: MeshInstance3D) -> AABB:
	var xform := Transform3D.IDENTITY
	var node: Node = mesh
	while node != null and node != prop:
		if node is Node3D:
			xform = (node as Node3D).transform * xform
		node = node.get_parent()
	return xform * mesh.get_aabb()

const BACKGROUND_Z := -12.0
const UNBATCHED_PROPS := ["pagoda", "shikhara", "lion"]
func _place_prop(path: String, at: Vector3, turn: float, scale := 1.0, tint := Color.WHITE) -> void:
	# The windows and doorways (dozens of copies of fine carving) have a
	# hand-reduced *_lite.glb the LOW preset uses instead.
	var lite_path := path.get_basename() + "_lite.glb"
	# The carved windows and doorways repeat dozens of times but are small
	# on screen, so every preset uses their reduced versions.
	var always_lite := path.get_file() in ["window.glb", "doorway.glb"]
	if (built_lite or always_lite) and ResourceLoader.exists(lite_path):
		path = lite_path
	if not ResourceLoader.exists(path):
		return
	var prop := (load(path) as PackedScene).instantiate() as Node3D
	# Tripo models are centred on their origin rather than standing on it:
	# lift them so their base sits on the floor.
	var low := INF
	var high := -INF
	for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = prop.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb() if prop.is_inside_tree() else _local_aabb(prop, mesh)
		low = minf(low, box.position.y)
		high = maxf(high, box.end.y)
	if (path.get_base_dir().get_file() in TRIPO_PROP_FOLDERS or path.get_file() in TRIPO_PROPS) and low < -0.05 * (high - low):
		at.y -= low * scale
	prop.position = at
	prop.rotation.y = turn
	prop.scale = Vector3.ONE * scale
	if built_lite:
		for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh is ArrayMesh:
				mesh.mesh = _lite_mesh(mesh.mesh)
	# Props well behind the fight (the pagoda, towers and lions) would only
	# cast moon shadows onto empty plaza: skip the second, shadow-map pass.
	if at.z < BACKGROUND_Z:
		for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The big single props stay separate meshes, so the engine can draw them
	# at the lower detail levels generated on import as they recede, and
	# skip them when off screen (merging would fix them at full detail).
	if path.get_file().get_basename() in UNBATCHED_PROPS:
		prop.set_meta("unbatched", true)
	# Meshy exports whitewash and plaster partly metallic, so walls mirror
	# the sky in dark facets; buildings get a matte, non-metal finish.
	if path.get_file().begins_with("monastery_hall") or path.get_file().begins_with("monk_quarters"):
		for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh is ArrayMesh:
				mesh.mesh = _smooth_mesh(mesh.mesh)
			# A low sun stretched their rooftop shadows into jagged blue
			# shards across the other buildings' whitewash.
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface in mesh.mesh.get_surface_count():
				var finish := mesh.get_active_material(surface) as StandardMaterial3D
				if finish != null and not finish.has_meta("matte"):
					finish.set_meta("matte", true)
					finish.metallic = 0.0
					finish.metallic_texture = null
					finish.roughness = 0.88
					finish.roughness_texture = null
					finish.metallic_specular = 0.3
					# Its baked normal map bends whole wall panels into dark
					# shards at fight distance; the walls read flatter and
					# cleaner without it.
					finish.normal_enabled = false
					# Meshy's walls are slightly lumpy; under a low grazing sun
					# each tilt flipped between lit and unlit. Wrapped diffuse
					# lets light fall off softly across the bumps.
					finish.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		# The import's automatic detail levels fold thin parts (scarves, flags,
	# finials) into stray triangles at fight-camera distance; hold full
	# detail far longer.
	for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		mesh.lod_bias = 6.0
	if tint != Color.WHITE:
		for mesh: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface in mesh.get_surface_override_material_count():
				var material := mesh.get_active_material(surface)
				if material is StandardMaterial3D:
					if not _tinted.has(material):
						var warm: StandardMaterial3D = material.duplicate()
						warm.albedo_color = tint
						warm.metallic = 0.0
						warm.metallic_texture = null
						_tinted[material] = warm
					mesh.set_surface_override_material(surface, _tinted[material])
	content.add_child(prop)

## The LOW preset draws the scenery props (windows, doorways, lions, the
## pagoda: ~350k triangles between them) with about half their triangles,
## using the engine's own mesh simplifier. Built once per mesh.
const LITE_RATIO := 0.5
static var lite_cache: Dictionary = {}
static func _lite_mesh(mesh: ArrayMesh) -> ArrayMesh:
	if lite_cache.has(mesh):
		return lite_cache[mesh]
	var importer := ImporterMesh.new()
	for surface in mesh.get_surface_count():
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(surface), [], {}, mesh.surface_get_material(surface), "")
	importer.generate_lods(25.0, 60.0, [])
	var out := ArrayMesh.new()
	for surface in importer.get_surface_count():
		var arrays: Array = importer.get_surface_arrays(surface)
		var full: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
		var best: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var best_gap := absf(1.0 - LITE_RATIO)
		for lod in importer.get_surface_lod_count(surface):
			var indices := importer.get_surface_lod_indices(surface, lod)
			var gap := absf(float(indices.size()) / maxf(full, 1.0) - LITE_RATIO)
			if gap < best_gap:
				best_gap = gap
				best = indices
		arrays[Mesh.ARRAY_INDEX] = best
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(surface, mesh.surface_get_material(surface))
	lite_cache[mesh] = out
	return out

func _mood() -> Array:
	return NIGHT_MOOD if night else MOODS[current_round]

func _lighting() -> void:
	var mood: Array = _mood()
	var look: Array = NIGHT_GRADE if night else GRADES[current_round]
	sky_material.set_shader_parameter("top_color", mood[0])
	sky_material.set_shader_parameter("horizon_color", mood[1])
	sky_material.set_shader_parameter("sun_color", mood[2])
	sky_material.set_shader_parameter("stars", 0.9 if night else 0.0)
	sky_material.set_shader_parameter("moon", 1.0 if night else 0.0)
	sky_material.set_shader_parameter("disc", 0.9992 if night else 0.99955)
	sun.rotation_degrees = Vector3(mood[6], mood[7], 0)
	# The light travels along -Z of its basis, so the disc sits along +Z.
	sky_material.set_shader_parameter("sun_dir", Basis.from_euler(sun.rotation) * Vector3.BACK)
	sun.light_color = mood[2]
	sun.light_energy = mood[3]
	var env: Environment = environment.environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = mood[4]
	env.ambient_light_energy = mood[5]
	env.tonemap_exposure = look[5]
	# Depth fog leaves the fighters crisp while the distant ridges merge
	# naturally into the sky. Supported by the Compatibility renderer.
	env.fog_enabled = true
	env.fog_light_color = mood[1]
	if current_round == 1:
		# Humid plains air: a warm haze that softens the forest line.
		env.fog_light_color = Color("9fb39a")
		env.fog_density = 0.0045
	if current_round == 3 and not night:
		# Dusk air is cool violet in the distance; a warm haze would turn
		# the snow catching the last light into sand.
		env.fog_light_color = mood[1].lerp(Color("6f78a8"), 0.6)
	env.fog_light_energy = 0.65
	# Thin mountain air: only the far ridges soften, into blue.
	# At night the far range sinks into the dark haze, moonlit but dim.
	env.fog_density = 0.0032 if night else 0.0012
	env.fog_sky_affect = 0.12
	# Sunlight scattered into the haze, so fog glows toward the sun.
	env.fog_sun_scatter = 0.0 if night else 0.2
	# A thin ground mist pools on the night squares: it catches the
	# lamplight low around the dais without dulling the fighters.
	env.fog_height = 0.35 if night else -20.0
	env.fog_height_density = 0.045 if night else 0.0
	if current_round == 4 and not night:
		# The pass: cold, bright high-altitude air. The snowfield runs into a
		# blue-white haze that the peaks rise out of, and spindrift mist
		# lies low over the snow, so ground and range meet softly.
		env.fog_light_color = Color("d6e2f2")
		env.fog_density = 0.0042
		env.fog_sky_affect = 0.25
		env.fog_sun_scatter = 0.3
		env.fog_height = 1.2
		env.fog_height_density = 0.06
	if current_round == 5 and not night:
		# Dashain afternoon: warm sunlit haze thickening with distance, so the
		# far ridges and peaks melt into the air, and a bank of mist lying in
		# the valley below the ridge.
		env.fog_light_color = Color("f1caa0")
		env.fog_density = 0.0048
		env.fog_sky_affect = 0.3
		env.fog_sun_scatter = 0.5
		env.fog_height = -7.0
		env.fog_height_density = 0.09
	# Bloom on flames, lanterns, lit windows and the sun disc. The threshold
	# is set so costume colours and pale stone stay crisp while anything
	# emissive or sunlit-white blooms. Off at the lowest quality preset.
	env.glow_enabled = _effects_level() > 0
	grade_rect.visible = _effects_level() > 0
	env.glow_intensity = look[6]
	env.glow_strength = 1.0
	env.glow_bloom = 0.04 if night else 0.02
	env.glow_hdr_threshold = look[7]
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT if night else Environment.GLOW_BLEND_MODE_ADDITIVE
	if not night:
		env.glow_intensity = look[6] * 0.5
	grade.set_shader_parameter("shadow_tint", look[0])
	grade.set_shader_parameter("highlight_tint", look[1])
	grade.set_shader_parameter("saturation", look[2])
	grade.set_shader_parameter("contrast", look[3])
	grade.set_shader_parameter("vignette", look[4])
	grade.set_shader_parameter("sharpen", 0.35)
	grade.set_shader_parameter("grain", 0.012)
	grade.set_shader_parameter("punch_color", Color("ffd9a0"))
	_sync_grade()

## 0 on the LOW preset (or custom settings with everything off), 1 otherwise:
## gates the post effects and the dais key-light shadow.
func _effects_level() -> int:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return 1
	if not settings.post_effects:
		return 0
	if settings.quality == settings.Quality.LOW:
		return 0
	if settings.quality == settings.Quality.CUSTOM and settings.shadows == 0 and settings.anti_aliasing == 0:
		return 0
	return 1

## The finishing overlay: a ColorRect on its own canvas layer, under every
## HUD layer (which start at 1) and over the 3D world. It only adds the
## vignette, grain, punch and flash; the colour grade set on it by name is
## applied by the renderer (see _sync_grade).
func _grade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Grade"
	layer.layer = 0
	add_child(layer)
	grade = ShaderMaterial.new()
	grade.shader = GRADE_SHADER
	grade_rect = ColorRect.new()
	grade_rect.name = "GradeRect"
	grade_rect.material = grade
	grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(grade_rect)

## The colour grade (split toning, saturation, contrast) runs in the
## tonemap pass as a 3D colour lookup, rebuilt only when its values change;
## the knockout's drain of colour is the Environment's own saturation.
## Callers keep setting these on `grade` by name (the arena mood, the KO
## replay's film look, cutscenes) and they are picked up here each frame.
var _grade_key: Array = []
static var _lut_cache: Dictionary = {}
const LUT_SIZE := 17
func _sync_grade() -> void:
	if grade == null or environment == null:
		return
	var env: Environment = environment.environment
	var on := grade_rect != null and grade_rect.visible
	env.adjustment_enabled = on
	if not on:
		return
	var key := [grade.get_shader_parameter("shadow_tint"), grade.get_shader_parameter("highlight_tint"),
		grade.get_shader_parameter("saturation"), grade.get_shader_parameter("contrast")]
	if key != _grade_key:
		_grade_key = key
		env.adjustment_color_correction = _grade_lut(key)
	var drain = grade.get_shader_parameter("drain")
	env.adjustment_saturation = 1.0 - clampf(float(drain) if drain != null else 0.0, 0.0, 1.0)

## The same grade the screen shader used to apply, baked into a small 3D
## lookup: saturation, then contrast, then shadows and highlights tinted.
static func _grade_lut(key: Array) -> Texture3D:
	var cache_key := str(key)
	if _lut_cache.has(cache_key):
		return _lut_cache[cache_key]
	var shadow: Color = key[0] if key[0] is Color else Color(1, 1, 1)
	var high: Color = key[1] if key[1] is Color else Color(1, 1, 1)
	var sat: float = float(key[2]) if key[2] != null else 1.0
	var con: float = float(key[3]) if key[3] != null else 1.0
	var images: Array[Image] = []
	for b in LUT_SIZE:
		var image := Image.create(LUT_SIZE, LUT_SIZE, false, Image.FORMAT_RGB8)
		for g in LUT_SIZE:
			for r in LUT_SIZE:
				var c := Vector3(r, g, b) / float(LUT_SIZE - 1)
				var luma := c.dot(Vector3(0.3, 0.59, 0.11))
				c = Vector3(luma, luma, luma).lerp(c, sat)
				c = ((c - Vector3(0.5, 0.5, 0.5)) * con + Vector3(0.5, 0.5, 0.5)).max(Vector3.ZERO)
				var t := smoothstep(0.0, 0.85, luma)
				c *= Vector3(shadow.r, shadow.g, shadow.b).lerp(Vector3(high.r, high.g, high.b), t)
				image.set_pixel(r, g, Color(minf(c.x, 1.0), minf(c.y, 1.0), minf(c.z, 1.0)))
		images.append(image)
	var lut := ImageTexture3D.new()
	lut.create(Image.FORMAT_RGB8, LUT_SIZE, LUT_SIZE, LUT_SIZE, false, images)
	_lut_cache[cache_key] = lut
	return lut

## An impact seen at `screen_point` (0..1 across the view): a shock ring and
## a radial colour split that fade over a few frames. `strength` 1 is a
## heavy hit.
func punch(screen_point: Vector2, strength: float) -> void:
	if _effects_level() == 0:
		return
	punch_level = maxf(punch_level, clampf(strength, 0.0, 1.0))
	grade.set_shader_parameter("punch_center", screen_point)
	grade.set_shader_parameter("punch", punch_level)

## A whole-screen flash that decays into a brief drain of colour: the
## knockout hit.
func flash(color: Color, strength: float, drain_after := 0.0) -> void:
	flash_level = maxf(flash_level, strength)
	drain_level = maxf(drain_level, drain_after)
	grade.set_shader_parameter("flash_color", color)
	grade.set_shader_parameter("flash", flash_level)
	grade.set_shader_parameter("drain", drain_level)

func _ground() -> void:
	# Brick plaza one step below the flagstone fighting dais.
	var plaza := PlaneMesh.new()
	plaza.size = Vector2(90, 90)
	_piece(plaza, Vector3(0, -0.12, -10), _surface("plaza", 0, Color("8e4a36"), Color("4b3a30"), 1.25))
	floor_material = _surface("dais", 5, Color("8a8071"), Color("463f37"))
	_box(Vector3(12.2, 0.12, 3.8), Vector3(0, -0.06, 0), floor_material)
	# Carved stone kerb frames the dais.
	var kerb := _surface("kerb", 1, Color("7d7466"), Color("3f3a33"))
	for side in [-1.0, 1.0]:
		_box(Vector3(12.6, 0.16, 0.22), Vector3(0, -0.05, side * 2.0), kerb)
		_box(Vector3(0.22, 0.16, 4.2), Vector3(side * 6.2, -0.05, 0), kerb)

## Two rings of ridges: blue-green foothills and the snowy Himalaya behind.
func _mountains() -> void:
	var tint: Color = _mood()[8]
	_ridge(110.0, 2.0, 7.0, 71, Color("3b5a5e") * tint, Color("6f8f86") * tint, 0.0, 1.3)
	_ridge(190.0, 10.0, 30.0, 97, Color("6a82a0") * tint, Color("f2f4f8") * tint, 0.6, 3.7)

func _ridge(radius: float, low: float, high: float, seed_value: int, base: Color, peak: Color, snow_line: float, frequency: float) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 90
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var offsets: Array[float] = []
	for i in 6:
		offsets.append(rng.randf() * TAU)
	var shoulder := base.lerp(peak, 0.45)
	var snow_height := lerpf(low, high, snow_line)
	var previous_top := Vector3.ZERO
	var previous_base := Vector3.ZERO
	for i in steps + 1:
		var t := float(i) / steps
		var angle := lerpf(-2.1, 2.1, t)
		var ridge := 0.5 + 0.28 * sin(angle * frequency * 2.0 + offsets[0]) + 0.16 * sin(angle * frequency * 5.3 + offsets[1]) + 0.08 * sin(angle * frequency * 11.0 + offsets[2])
		var height := lerpf(low, high, clampf(ridge, 0.0, 1.0))
		var direction := Vector3(sin(angle), 0, -cos(angle))
		var top := direction * radius + Vector3(0, height, 0)
		var bottom := direction * radius + Vector3(0, -2, 0)
		if i > 0:
			var top_color := peak if snow_line > 0.0 and height > snow_height else shoulder
			var previous_color := peak if snow_line > 0.0 and previous_top.y > snow_height else shoulder
			for vertex in [[previous_base, base], [previous_top, previous_color], [top, top_color], [previous_base, base], [top, top_color], [bottom, base]]:
				tool.set_color(vertex[1])
				tool.add_vertex(vertex[0])
		previous_top = top
		previous_base = bottom
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content.add_child(node)

# --- architecture -------------------------------------------------------

## Newari town houses line both sides of the square, facing inward.
func _houses() -> void:
	var plaster := _surface("plaster", 3, Color("d9c6a2"), Color("b19a78"))
	for side in [-1.0, 1.0]:
		var zs := [-20.0, -16.2, -12.4, -8.6, -4.8, -1.0, 2.8, 6.6]
		for i in zs.size():
			var z: float = zs[i]
			var storeys := 3 if (i + (1 if side > 0 else 0)) % 2 == 0 else 2
			var height := 1.1 + storeys * 1.75
			var x: float = side * (10.2 + (i % 2) * 0.4)
			var face: float = x - side * 2.0
			_box(Vector3(4.0, height, 3.7), Vector3(x, height * 0.5 - 0.12, z), _brick() if i % 3 != 2 else plaster)
			# Timber string courses between storeys.
			for storey in storeys:
				var level := 1.05 + storey * 1.75
				_box(Vector3(0.18, 0.14, 3.8), Vector3(face - side * 0.06, level, z), _wood())
			# Ground floor: shop doorway with a carved lintel.
			_box(Vector3(0.12, 1.5, 1.1), Vector3(face - side * 0.04, 0.63, z - 0.8), _flat("doorway", Color("1a110b")))
			_box(Vector3(0.16, 0.16, 1.5), Vector3(face - side * 0.07, 1.45, z - 0.8), _wood())
			# Upper storeys: the classic three-bay window, then a wide sanjhya.
			for storey in range(1, storeys):
				var y := 1.05 + storey * 1.75 - 0.95
				var bays := 3 if storey == 1 else 1
				for bay in bays:
					var width := 0.72 if bays == 3 else 2.2
					var bz: float = z + (bay - 1) * 0.95 if bays == 3 else z
					_box(Vector3(0.16, 1.05, width + 0.24), Vector3(face - side * 0.07, y, bz), _wood())
					_box(Vector3(0.18, 0.84, width), Vector3(face - side * 0.1, y, bz), _lattice())
					_box(Vector3(0.26, 0.1, width + 0.5), Vector3(face - side * 0.12, y - 0.58, bz), _wood())
			# Overhanging tiled gable roof held on carved struts.
			var roof := PrismMesh.new()
			roof.size = Vector3(5.3, 1.3, 4.3)
			_piece(roof, Vector3(x, height + 0.5, z), _roof())
			for strut in 3:
				var brace := _box(Vector3(0.1, 0.8, 0.1), Vector3(face - side * 0.28, height - 0.25, z - 1.3 + strut * 1.3), _wood())
				brace.rotation.z = side * -0.6

func _pagoda(at: Vector3) -> void:
	# Five-step brick plinth with a central stair and guardian lions.
	var step_height := 0.5
	for i in 5:
		var half := 4.2 - i * 0.55
		_box(Vector3(half * 2, step_height, half * 2), at + Vector3(0, step_height * (i + 0.5), 0), _brick())
		_box(Vector3(half * 2 + 0.08, 0.06, half * 2 + 0.08), at + Vector3(0, step_height * (i + 1), 0), _stone())
	for i in 5:
		_box(Vector3(1.4, step_height * (i + 1), 0.55), at + Vector3(0, step_height * (i + 1) * 0.5, 4.5 - i * 0.55), _stone())
	for side in [-1.0, 1.0]:
		_lion(at + Vector3(side * 1.05, 0, 4.6))
	var top := at + Vector3(0, step_height * 5, 0)
	# Sanctum: brick walls with three latticed doors under a gilded arch.
	_box(Vector3(3.4, 2.3, 3.4), top + Vector3(0, 1.15, 0), _brick())
	for door in 3:
		_box(Vector3(0.62, 1.5, 0.1), top + Vector3((door - 1) * 0.85, 0.78, 1.72), _wood())
		_box(Vector3(0.5, 1.2, 0.12), top + Vector3((door - 1) * 0.85, 0.72, 1.74), _lattice())
	var arch := _ball(1.1, top + Vector3(0, 1.62, 1.74), _gold(), 0.5)
	arch.scale.z = 0.05
	# Three diminishing roofs with struts, gilded eaves and corner bells:
	# [eave half-width, top half-width, roof height, storey above].
	var tiers := [[3.3, 1.9, 1.25, 1.2], [2.4, 1.25, 1.05, 1.0], [1.65, 0.12, 1.25, 0.0]]
	var y := 2.3
	for t in tiers.size():
		var tier: Array = tiers[t]
		var eave: float = tier[0]
		_frustum(eave, tier[1], tier[2], top + Vector3(0, y, 0), _roof() if t < 2 else _surface("gilt", 2, Color("c79a3e"), Color("6d5220")))
		for side in [-1.0, 1.0]:
			_box(Vector3(eave * 2 + 0.05, 0.08, 0.1), top + Vector3(0, y + 0.03, side * eave), _gold())
			_box(Vector3(0.1, 0.08, eave * 2 + 0.05), top + Vector3(side * eave, y + 0.03, 0), _gold())
			for corner in [-1.0, 1.0]:
				_ball(0.08, top + Vector3(side * eave * 0.98, y - 0.14, corner * eave * 0.98), _gold())
		# Carved struts brace each eave from the wall below.
		var wall_half: float = 1.7 if t == 0 else float(tiers[t - 1][0]) * 0.62
		for s in 4:
			var angle := s * PI / 2.0
			var normal := Vector3(sin(angle), 0, cos(angle))
			var tangent := Vector3(cos(angle), 0, -sin(angle))
			for k in 3:
				var brace := _box(Vector3(0.09, 0.95, 0.09), top + Vector3(0, y - 0.38, 0) + normal * (wall_half + 0.35) + tangent * ((k - 1) * wall_half * 0.6), _wood())
				brace.rotation.y = angle
				brace.rotate_object_local(Vector3.RIGHT, 0.62)
		y += tier[2]
		if t < 2:
			var body_half: float = float(tiers[t + 1][0]) * 0.62
			_box(Vector3(body_half * 2, tier[3], body_half * 2), top + Vector3(0, y + tier[3] * 0.5, 0), _brick())
			y += tier[3]
	# Gilded pinnacle (gajur).
	for k in 4:
		_ball(0.3 - k * 0.05, top + Vector3(0, y + 0.2 + k * 0.38, 0), _gold(), 0.8)
	_frustum(0.06, 0.02, 0.6, top + Vector3(0, y + 1.6, 0), _gold(), 8)

func _shikhara(at: Vector3) -> void:
	for i in 3:
		var half := 1.9 - i * 0.35
		_box(Vector3(half * 2, 0.45, half * 2), at + Vector3(0, 0.45 * (i + 0.5), 0), _stone())
	var base := at + Vector3(0, 1.35, 0)
	_box(Vector3(2.0, 1.6, 2.0), base + Vector3(0, 0.8, 0), _stone())
	for side in [-1.0, 1.0]:
		for column in [-0.6, 0.0, 0.6]:
			_box(Vector3(0.14, 1.3, 0.14), base + Vector3(column, 0.65, side * 1.05), _stone())
	# Corner pavilions around a tall tapering spire.
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_frustum(0.42, 0.08, 1.4, base + Vector3(cx * 0.8, 1.6, cz * 0.8), _stone(), 8)
	_frustum(0.95, 0.22, 4.4, base + Vector3(0, 1.6, 0), _stone(), 8)
	_ball(0.26, base + Vector3(0, 6.2, 0), _gold())
	_frustum(0.05, 0.01, 0.5, base + Vector3(0, 6.35, 0), _gold(), 6)

func _lion(at: Vector3) -> void:
	var stone := _surface("lion", 1, Color("b4aa98"), Color("6c6558"), 0.4)
	_box(Vector3(0.7, 0.7, 0.7), at + Vector3(0, 0.35, 0), _stone())
	var body := _box(Vector3(0.36, 0.45, 0.6), at + Vector3(0, 0.95, 0), stone)
	body.rotation.x = -0.25
	_ball(0.3, at + Vector3(0, 1.2, 0.08), _flat("mane", Color("a6522f")), 0.9)
	_ball(0.22, at + Vector3(0, 1.3, 0.22), stone)
	_ball(0.13, at + Vector3(0, 1.26, 0.38), stone)

func _stupa(at: Vector3) -> void:
	var white := _surface("whitewash", 3, Color("e4ded2"), Color("c9c2b3"))
	for i in 3:
		var half := 6.0 - i * 0.9
		_box(Vector3(half * 2, 0.55, half * 2), at + Vector3(0, 0.55 * (i + 0.5), 0), white)
	var base_y := 1.65
	_ball(3.7, at + Vector3(0, base_y, 0), white, 0.78)
	# Harmika with the painted watching eyes on every face.
	var harmika := at + Vector3(0, base_y + 3.4, 0)
	_box(Vector3(1.9, 1.3, 1.9), harmika, _gold())
	for face in 4:
		var angle := face * PI / 2.0
		var normal := Vector3(sin(angle), 0, cos(angle))
		var tangent := Vector3(cos(angle), 0, -sin(angle))
		for eye_side in [-1.0, 1.0]:
			var spot: Vector3 = harmika + tangent * eye_side * 0.42 + Vector3(0, 0.08, 0)
			var eye := _ball(0.2, spot + normal * 0.96, _flat("eye_white", Color("f7f2e8")))
			eye.rotation.y = angle
			eye.scale = Vector3(1.4, 0.6, 0.2)
			var pupil := _ball(0.09, spot + normal * 1.0, _flat("ink", Color("141820")))
			pupil.rotation.y = angle
			pupil.scale = Vector3(1, 1, 0.3)
			var brow := _box(Vector3(0.55, 0.06, 0.04), spot + normal * 0.97 + Vector3(0, 0.26, 0), _flat("ink", Color("141820")))
			brow.rotation.y = angle
	# Thirteen gilded steps of the spire, parasol and pinnacle.
	var y := base_y + 4.05
	for step in 13:
		var radius := 1.05 - step * 0.065
		_frustum(radius, radius * 0.93, 0.22, at + Vector3(0, y, 0), _gold(), 12)
		y += 0.22
	_frustum(0.9, 0.12, 0.35, at + Vector3(0, y, 0), _gold(), 12)
	_ball(0.18, at + Vector3(0, y + 0.55, 0), _gold())
	# Prayer-flag lines radiate from the pinnacle down to the terrace edge.
	var peak := at + Vector3(0, y + 0.3, 0)
	for i in 6:
		var angle := -1.2 + i * 0.48
		_flag_line(peak, at + Vector3(sin(angle) * 7.5, 0.6, cos(angle) * 7.5), 0.7, 20)
	# A row of butter lamps along the lower terrace.
	for i in 13:
		_ball(0.07, at + Vector3(-5.4 + i * 0.9, 1.72, 5.1), _flat("flame", Color("ffc15a"), 4.0))

## Sunset lookout: stone parapet, a chautari resting platform with a pipal
## tree, and terraced hills stepping down the valley.
func _overlook() -> void:
	_box(Vector3(19, 0.9, 0.5), Vector3(0, 0.33, -10.0), _stone())
	for i in 9:
		_box(Vector3(0.5, 1.1, 0.6), Vector3(-8 + i * 2.0, 0.43, -10.0), _stone())
	var chautari := Vector3(6.0, -0.12, -13.0)
	for i in 2:
		_box(Vector3(3.6 - i * 0.6, 0.45, 3.6 - i * 0.6), chautari + Vector3(0, 0.45 * (i + 0.5), 0), _stone())
	_frustum(0.35, 0.25, 4.5, chautari + Vector3(0, 0.9, 0), _wood(), 10)
	var leaves := _flat("pipal", Color("3f6b2e"))
	var leaves_light := _flat("pipal_light", Color("5b8a36"))
	for i in 9:
		var angle := i * 0.8
		_ball(1.3 + (i % 3) * 0.4, chautari + Vector3(cos(angle) * 1.6, 5.2 + sin(i * 1.3) * 0.8, sin(angle) * 1.4), leaves if i % 2 == 0 else leaves_light, 0.8)
	var terrace_colors := [Color("5f8a3a"), Color("79a043"), Color("8faf4c")]
	var hills := [[Vector3(-26, -22, -70), 24.0], [Vector3(24, -21, -82), 28.0], [Vector3(-4, -26, -110), 34.0]]
	for h in hills.size():
		var hill: Array = hills[h]
		var center: Vector3 = hill[0]
		var radius: float = hill[1]
		# Stacked discs read as rice terraces from across the valley.
		for level in 12:
			var r := radius * (1.0 - level * 0.075)
			var disc := CylinderMesh.new()
			disc.top_radius = r
			disc.bottom_radius = r + 0.4
			disc.height = 1.4
			disc.radial_segments = 28
			_piece(disc, center + Vector3(0, level * 1.4, 0), _flat("terrace%d" % (level % 3), terrace_colors[level % 3]))
		for k in 5:
			var angle := k * 1.25 + h
			var level := 3 + k
			var r := radius * (1.0 - level * 0.075) - 1.0
			var house_at := center + Vector3(cos(angle) * r, level * 1.4 + 0.9, sin(angle) * r)
			_box(Vector3(1.4, 1.1, 1.0), house_at, _flat("cottage", Color("efe6d4")))
			var roof := PrismMesh.new()
			roof.size = Vector3(1.7, 0.6, 1.2)
			_piece(roof, house_at + Vector3(0, 0.85, 0), _flat("cottage_roof", Color("b3452f")))

# --- festive dressing ---------------------------------------------------

func _flag_poles(span: float, height: float, depth: float) -> void:
	var marigold := _flat("marigold", Color("f09a1c"))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.045
	pole.bottom_radius = 0.06
	pole.height = height + 0.3
	for side in [-1.0, 1.0]:
		_piece(pole, Vector3(side * span, (height + 0.3) * 0.5 - 0.12, depth), _wood())
		_ball(0.07, Vector3(side * span, height + 0.24, depth), _gold())
		for i in 14:
			var angle := i * 1.1
			_ball(0.055, Vector3(side * span + cos(angle) * 0.07, 0.9 + i * 0.1, depth + sin(angle) * 0.07), marigold)

## A sagging rope of five-colour prayer flags (lungta) from a to b.
## `sway` false hangs the flags still so they merge into the static
## scenery (long lines far from the fight).
func _flag_line(a: Vector3, b: Vector3, sag: float, count: int, sway := true) -> void:
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.008
	rope_mesh.bottom_radius = 0.008
	rope_mesh.height = 1.0
	var flag_mesh := QuadMesh.new()
	flag_mesh.size = Vector2(0.2, 0.25)
	var run := b - a
	var heading := -atan2(run.z, run.x)
	var previous := a
	for i in count + 1:
		var t := float(i) / count
		var point := a.lerp(b, t) - Vector3(0, sin(t * PI) * sag, 0)
		if i > 0:
			var segment := _piece(rope_mesh, (previous + point) * 0.5, _flat("rope", Color("3b3129")))
			segment.basis = Basis(Quaternion(Vector3.UP, (point - previous).normalized()))
			segment.scale.y = previous.distance_to(point)
		previous = point
		if i == 0 or i == count:
			continue
		# Each flag hangs from a pivot on the rope so it swings from its top edge.
		var hanger := Node3D.new()
		hanger.position = point
		hanger.rotation.y = heading
		content.add_child(hanger)
		var color: Color = FLAG_COLORS[(i - 1) % FLAG_COLORS.size()]
		var flag := _piece(flag_mesh, Vector3(0, -0.135, 0), _flat("flag%d" % ((i - 1) % 5), color, 0.1 if night else 0.0), hanger)
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if sway:
			flags.append(hanger)

## Strings of paper lanterns cross the square for the night round.
## `sway` false hangs them still, so they merge into the static scenery
## (each swaying lantern is two more draws every frame).
func _lantern_strings(lines: Array = [[-4.2, 3.9], [-9.0, 4.6], [-14.0, 4.9]], lit := true, sway := true) -> void:
	var paper := [_flat("lantern_red", Color("e0452f"), 2.2), _flat("lantern_gold", Color("f2a33a"), 2.2)]
	var rope := CylinderMesh.new()
	rope.top_radius = 0.01
	rope.bottom_radius = 0.01
	rope.height = 1.0
	var body := CylinderMesh.new()
	body.top_radius = 0.13
	body.bottom_radius = 0.13
	body.height = 0.3
	body.radial_segments = 12
	for line in lines:
		var z: float = line[0]
		var height: float = line[1]
		var a := Vector3(-8.2, height, z)
		var b := Vector3(8.2, height, z)
		var previous := a
		for i in 17:
			var t := float(i) / 16.0
			var point := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.8, 0)
			if i > 0:
				var segment := _piece(rope, (previous + point) * 0.5, _flat("rope", Color("3b3129")))
				segment.basis = Basis(Quaternion(Vector3.UP, (point - previous).normalized()))
				segment.scale.y = previous.distance_to(point)
			previous = point
			if i % 2 == 1:
				var hanger := Node3D.new()
				hanger.position = point
				content.add_child(hanger)
				var lamp := _piece(body, Vector3(0, -0.22, 0), paper[(i / 2) % 2], hanger)
				lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_piece(body, Vector3(0, -0.06, 0), _flat("lantern_cap", Color("241a14")), hanger).scale = Vector3(0.8, 0.12, 0.8)
				if sway:
					lanterns.append(hanger)
	for x in ([-4.5, 0.0, 4.5] if lit else []):
		var glow := OmniLight3D.new()
		glow.position = Vector3(x, 3.0, -3.0)
		glow.light_color = Color("ffb66a")
		glow.omni_range = 7.0
		glow.set_meta("base", 0.9)
		glow.light_energy = 0.9
		content.add_child(glow)
		lamp_lights.append(glow)

## Clay butter lamps (diyo) on stone plinths at both ends of the dais.
func _butter_lamps() -> void:
	var clay := _flat("clay", Color("8a4b2c"))
	var flame := _flat("flame", Color("ffc15a"), 4.0)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.07
	bowl.bottom_radius = 0.045
	bowl.height = 0.05
	for side in [-1.0, 1.0]:
		var base := Vector3(side * 5.5, 0.2, -1.55)
		_box(Vector3(0.7, 0.42, 0.5), base + Vector3(0, -0.1, 0), _stone())
		for i in 5:
			var at := base + Vector3(-0.24 + i * 0.12, 0.135, 0.1 * ((i % 2) * 2 - 1))
			_piece(bowl, at, clay)
			_ball(0.022, at + Vector3(0, 0.055, 0), flame, 1.6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var glow := OmniLight3D.new()
		glow.position = base + Vector3(0, 0.45, 0.2)
		glow.light_color = Color("ffb35c")
		glow.omni_range = 2.6 if night else 1.4
		glow.set_meta("base", 1.1 if night else 0.35)
		glow.light_energy = glow.get_meta("base")
		content.add_child(glow)
		lamp_lights.append(glow)

## A soft round dot for every particle quad (embers, sparks, dust): built
## once from a radial gradient, so motes read as points of light and haze
## rather than hard squares.
static var soft_dot_texture: Texture2D
static func soft_dot() -> Texture2D:
	if soft_dot_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.35, Color(1, 1, 1, 0.75))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 32
		texture.height = 32
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		soft_dot_texture = texture
	return soft_dot_texture

## Per-round atmosphere: courtyard dust, lantern embers, drifting rhododendron
## petals and, for the finale, sky lanterns rising behind the stupa.
func _ambience() -> void:
	var spec: Array = AMBIENCE[current_round]
	if spec[0] == "none" and night and current_round == 0:
		spec = ["embers", Color(1.0, 0.7, 0.36, 0.85), 34]
	if spec[0] == "none":
		return
	var particles := CPUParticles3D.new()
	particles.name = "Ambience"
	particles.amount = spec[2]
	particles.lifetime = 9.0
	particles.preprocess = 9.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var quad := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = soft_dot()
	quad.material = material
	particles.mesh = quad
	particles.color = spec[1]
	particles.gravity = Vector3.ZERO
	match spec[0]:
		"dust":
			quad.size = Vector2(0.025, 0.025)
			particles.position = Vector3(0, 1.4, -0.6)
			particles.emission_box_extents = Vector3(6, 1.4, 1.6)
			particles.direction = Vector3(1, 0.2, 0)
			particles.spread = 40
			particles.initial_velocity_min = 0.05
			particles.initial_velocity_max = 0.15
		"embers":
			quad.size = Vector2(0.05, 0.05)
			particles.position = Vector3(0, 0.3, -1.2)
			particles.emission_box_extents = Vector3(6, 0.3, 1.2)
			particles.direction = Vector3(0, 1, 0)
			particles.spread = 25
			particles.initial_velocity_min = 0.15
			particles.initial_velocity_max = 0.35
			particles.lifetime = 7.0
		"petals":
			quad.size = Vector2(0.09, 0.07)
			particles.position = Vector3(0, 4.2, -0.6)
			particles.emission_box_extents = Vector3(7, 0.2, 1.8)
			particles.gravity = Vector3(0.18, -0.32, 0)
			particles.angular_velocity_min = -160
			particles.angular_velocity_max = 160
			particles.angle_max = 360
			particles.lifetime = 11.0
		"snow":
			quad.size = Vector2(0.035, 0.035)
			particles.position = Vector3(0, 5.0, -2.0)
			particles.emission_box_extents = Vector3(9, 0.5, 5)
			particles.gravity = Vector3(0.25, -0.35, 0)
			particles.lifetime = 12.0
			particles.preprocess = 12.0
		"sky_lanterns":
			quad.size = Vector2(0.14, 0.18)
			particles.position = Vector3(0, 2.0, -9.0)
			particles.emission_box_extents = Vector3(9, 0.4, 2.0)
			particles.direction = Vector3(0.15, 1, 0)
			particles.spread = 8
			particles.initial_velocity_min = 0.3
			particles.initial_velocity_max = 0.45
			particles.lifetime = 18.0
			particles.preprocess = 18.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content.add_child(particles)

## A short dip to black carries the journey from one arena into the next
## instead of a hard cut.
func _fade_in() -> void:
	if fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 40
		add_child(layer)
		fade = ColorRect.new()
		fade.color = Color("05070c")
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(fade)
	fade.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_property(fade, "modulate:a", 0.0, 0.7)
