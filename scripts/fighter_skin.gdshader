shader_type spatial;
render_mode cull_disabled;
// Cinematic finish for the imported fighters (fighter_animated.gd
// _polish_materials swaps their materials for this one). Meshy bodies come
// as one painted texture, so skin and cloth are told apart per pixel by
// colour, then graded the way a film colourist would:
//  - skin warms a touch, is held back from blowing out to pink-white, gets a
//    soft sheen, and lets a little light bleed through at its edges, a cheap
//    stand-in for the glow of light under real skin;
//  - cloth keeps its colour but loses the clipped, neon saturation, and its
//    darks deepen for contrast;
//  - nothing is brighter than real-world surfaces get (about 85% albedo),
//    so arms facing a lamp keep their shape.
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_strength = 0.0;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap;
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform float roughness = 0.8;
uniform sampler2D metallic_tex : hint_default_white, filter_linear_mipmap;
uniform vec4 metallic_channel = vec4(0.0, 0.0, 1.0, 0.0);
uniform float metallic = 0.0;
// How strongly the grade is applied (0 = the texture as painted).
uniform float grade = 1.0;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// 1 where a colour reads as skin: red over green over blue, with a
// moderate saturation and not too dark. Smooth, so edges never band.
float skin_mask(vec3 c) {
	float l = luma(c);
	float r_g = c.r - c.g;
	float g_b = c.g - c.b;
	float sat = (max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b))) / max(max(c.r, max(c.g, c.b)), 0.001);
	float hue = smoothstep(0.015, 0.06, r_g) * smoothstep(-0.02, 0.03, g_b) * (1.0 - smoothstep(0.32, 0.42, r_g));
	float band = smoothstep(0.05, 0.15, sat) * (1.0 - smoothstep(0.62, 0.78, sat));
	float lit = smoothstep(0.16, 0.3, l);
	return hue * band * lit;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * albedo_color;
	vec3 c = tex.rgb;
	float skin = skin_mask(c) * grade;
	// Cloth: compress saturation above a point so neon purples and reds keep
	// their weave, and deepen the darks.
	float l = luma(c);
	vec3 grey = vec3(l);
	float sat = length(c - grey);
	float squeeze = mix(1.0, 0.82, smoothstep(0.18, 0.5, sat) * grade);
	vec3 cloth = grey + (c - grey) * squeeze;
	cloth = mix(cloth, pow(cloth, vec3(1.12)), grade);
	// Skin: warm, a little richer, and brought to the brightness real skin
	// has (about 35-60% albedo; painted textures run far paler), easing in
	// so darker skin tones are untouched.
	vec3 warm = c * vec3(1.03, 0.95, 0.87);
	float bright = luma(warm);
	float target = mix(bright, 0.5 + 0.12 * smoothstep(0.5, 1.0, bright), smoothstep(0.45, 0.75, bright));
	warm *= target / max(bright, 0.001);
	vec3 col = mix(cloth, warm, skin);
	// No surface brighter than about 85%: highlights come from the lights.
	col *= min(1.0, 0.82 / max(max(col.r, max(col.g, col.b)), 0.001));
	ALBEDO = col;
	float rough = roughness * dot(texture(roughness_tex, UV), roughness_channel);
	ROUGHNESS = mix(clamp(rough, 0.6, 1.0), 0.5, skin);
	METALLIC = min(metallic * dot(texture(metallic_tex, UV), metallic_channel), 0.3);
	SPECULAR = mix(0.3, 0.42, skin);
	if (normal_strength > 0.0) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	// A soft edge light that separates the fighter from the scene.
	RIM = 0.3;
	RIM_TINT = 0.65;
	// Light glowing through thin skin (ears, fingers, the edge of an arm).
	BACKLIGHT = warm * vec3(0.5, 0.22, 0.12) * skin * 0.35;
}
