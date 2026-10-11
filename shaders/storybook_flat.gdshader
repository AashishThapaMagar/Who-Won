shader_type spatial;
// Mithila colouring for a model (storybook_look.gd, "mithila" style): each
// spot painted in the one palette colour a Mithila painter would choose for
// it, read from the model's own colour by hue (no light, no shade), and
// softened first so fine texture detail doesn't break shapes into specks.
// shaders/storybook_mithila.gdshader then edges, patterns and frames it.
render_mode unshaded;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_texture = true;
// Mip bias: how much texture detail is smoothed away.
uniform float soften = 4.5;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// The same palette as storybook_mithila.gdshader.
vec3 mithila(vec3 c) {
	vec3 hsv = rgb_to_hsv(c);
	float h = hsv.x * 360.0;
	float s = hsv.y;
	float v = hsv.z;
	// A thing's colour is its hue: light and dark folds of one cloth stay
	// one colour. Only near-black, near-white and grey are judged by
	// brightness.
	if (v < 0.07) return vec3(0.12, 0.09, 0.08);
	if (s < 0.18) {
		if (v > 0.62) return vec3(0.93, 0.86, 0.72);                     // bare paper (snow, white cloth)
		if (v > 0.3) return h > 160.0 && h < 280.0 ? vec3(0.47, 0.67, 0.80) : vec3(0.52, 0.30, 0.17);
		return vec3(0.17, 0.27, 0.52);                                   // dark grey -> indigo
	}
	if (h < 12.0 || h >= 340.0) return vec3(0.78, 0.18, 0.15);          // vermilion
	if (h < 32.0) return s < 0.45 && v < 0.5 ? vec3(0.52, 0.30, 0.17) : vec3(0.87, 0.58, 0.36);   // skin, earth
	if (h < 68.0) return vec3(0.91, 0.70, 0.18);                         // turmeric, gold
	if (h < 170.0) return vec3(0.30, 0.54, 0.24);                        // leaf green
	if (h < 215.0) return vec3(0.47, 0.67, 0.80);                        // sky blue
	if (h < 280.0) return vec3(0.17, 0.27, 0.52);                        // indigo
	return vec3(0.82, 0.31, 0.47);
}

void fragment() {
	vec4 c = albedo;
	if (use_texture) {
		c *= texture(albedo_texture, UV, soften);
	}
	ALBEDO = mithila(c.rgb);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
