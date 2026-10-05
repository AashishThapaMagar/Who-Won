shader_type spatial;
render_mode cull_disabled;
// Distant terrain: grass and forest on the low slopes, bare rock on steep
// faces, snow on high ground that isn't too steep to hold it. Aerial scans
// (Poly Haven CC0) are laid on from above at kilometre scale, and the whole
// surface fades toward the sky colour with distance (aerial perspective).
// A detail normal carves ridges and gullies finer than the mesh, and mist
// pools in the low ground so each ridge stands out against the next.
uniform sampler2D snow_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_map : source_color, filter_linear_mipmap, repeat_enable;
uniform float snow_line = 999.0;
uniform float terraces = 0.0;
uniform vec3 haze_color : source_color = vec3(0.7, 0.8, 0.9);
uniform float haze_start = 60.0;
uniform float haze_density = 0.004;
uniform float haze_max = 0.7;
// Overall brightness of the scans (they are shot in daylight).
uniform float light_scale = 1.0;
// 1 at night: moonlit snow is silver-grey and the low slopes go to forest
// silhouette.
uniform float night = 0.0;
// Height (metres) below which valley mist gathers, and how thick it is.
uniform float mist_height = 6.0;
uniform float mist_amount = 0.5;
// Strength of the carved detail on the surface.
uniform float relief = 1.0;
// Moonlit snow holds a faint light of its own against the night sky.
uniform float moon_glow = 0.0;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Sine-free hash: sin() of large world coordinates breaks into facets.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
// Ridged detail: sharp crests and soft gullies, like eroded rock.
float ridges(vec2 p) {
	float sum = 0.0;
	float weight = 0.55;
	for (int o = 0; o < 3; o++) {
		sum += (1.0 - abs(noise(p) * 2.0 - 1.0)) * weight;
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.1 + vec2(5.2, 1.3);
		weight *= 0.5;
	}
	return sum;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec2 top = world_pos.xz;
	// Carve the detail into the normal: the gradient of a ridged height
	// field tips the surface, more on steep ground than on gentle slopes.
	float scale = 1.0 / 22.0;
	vec2 e = vec2(0.6, 0.0);
	float gx = ridges((top + e.xy) * scale) - ridges((top - e.xy) * scale);
	float gz = ridges((top + e.yx) * scale) - ridges((top - e.yx) * scale);
	float steep = 1.0 - clamp(n.y, 0.0, 1.0);
	n = normalize(n - vec3(gx, 0.0, gz) * relief * (0.9 + 1.6 * steep));
	float slope = 1.0 - clamp(n.y, 0.0, 1.0);
	vec3 grass = texture(grass_map, top / 60.0).rgb * vec3(0.75, 0.95, 0.6);
	// Darker conifer patches break up the green slopes.
	float forest = smoothstep(0.45, 0.7, noise(top / 28.0));
	grass = mix(grass, grass * vec3(0.45, 0.6, 0.42), forest);
	vec3 rock = texture(rock_map, top / 90.0).rgb * vec3(0.78, 0.76, 0.8);
	vec3 snow = texture(snow_map, top / 140.0).rgb * 1.08;
	if (night > 0.5) {
		// Moonlight takes the colour out: silver snow, slate rock, and the
		// low slopes a dark forest silhouette.
		snow = mix(vec3(dot(snow, vec3(0.33))), snow, 0.35) * vec3(0.92, 0.96, 1.04);
		rock = vec3(dot(rock, vec3(0.33))) * vec3(0.55, 0.58, 0.66);
		grass = vec3(dot(grass, vec3(0.33))) * vec3(0.22, 0.27, 0.3);
	}
	// Grass gives way to rock with height and steepness.
	float rocky = smoothstep(0.35, 0.65, slope) + smoothstep(12.0, 30.0, world_pos.y);
	vec3 col = mix(grass, rock, clamp(rocky, 0.0, 1.0));
	// Snow settles above the snow line, thinning out on steep faces and
	// lying in the gullies longer than on the crests.
	float line = snow_line + (noise(top / 18.0) - 0.5) * 14.0;
	float snowy = smoothstep(line, line + 10.0, world_pos.y) * (1.0 - smoothstep(0.55, 0.85, slope));
	col = mix(col, snow, snowy);
	// Rice-terrace lines along the contours of the foothills.
	if (terraces > 0.5) {
		float band = fract(world_pos.y / 1.4);
		float edge = smoothstep(0.0, 0.08, band) * smoothstep(1.0, 0.85, band);
		col *= mix(0.72, 1.0, edge);
	}
	float dist = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	float haze = clamp(1.0 - exp(-max(dist - haze_start, 0.0) * haze_density), 0.0, haze_max);
	// Mist lying in the valleys, rippled so it drifts in banks.
	float mist = (1.0 - smoothstep(0.0, mist_height, world_pos.y + (noise(top / 40.0 + TIME * 0.01) - 0.5) * mist_height * 0.6)) * mist_amount;
	haze = max(haze, mist);
	ALBEDO = mix(col * light_scale, haze_color, haze * 0.35);
	ROUGHNESS = mix(0.95, 0.55, snowy);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// Haze also veils the lighting itself, so far peaks go soft and pale.
	EMISSION = haze_color * haze * 0.55 + snow * snowy * moon_glow * (1.0 - haze);
}
