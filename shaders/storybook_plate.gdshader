shader_type canvas_item;
// The finish for a baked storybook picture (tools/bake_story_plates.gd): the
// inked, flat-washed render turned into a watercolour on paper. A faint
// pencil sketch under the paint, pigment pooling dark at the rims of each
// colour area, paint bleeding a little past the ink, the paper's grain
// catching the pigment, a colour mood, and a brushed, deckled edge where
// the picture fades into the page. Heavy (many samples): bake-time only.

uniform vec3 paper : source_color = vec3(0.95, 0.90, 0.78);
uniform vec3 graphite : source_color = vec3(0.30, 0.27, 0.26);
// The mood's tint, mixed over the paint (dawn gold, dusk rose, ...).
uniform vec3 mood : source_color = vec3(1.0, 0.92, 0.78);
uniform float mood_amount = 0.18;
uniform float seed = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

vec3 blur(sampler2D tex, vec2 uv, vec2 px, float r) {
	vec3 s = vec3(0.0);
	float w = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float k = exp(-float(x * x + y * y) / 8.0);
			s += texture(tex, uv + vec2(float(x), float(y)) * px * r).rgb * k;
			w += k;
		}
	}
	return s / w;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 res = 1.0 / px;
	// Wet paint wanders: sample through a slowly warped grid.
	vec2 warp = (vec2(fbm(UV * 6.0), fbm(UV * 6.0 + 4.7)) - 0.5) * px * 7.0;
	vec3 sharp = texture(TEXTURE, UV + warp).rgb;
	vec3 soft = blur(TEXTURE, UV + warp, px, 2.2);
	vec3 wide = blur(TEXTURE, UV + warp * 2.0, px, 6.0);
	// Washes are soft; ink lines stay crisp (they are darker than the blur).
	float ink = clamp((luma(soft) - luma(sharp)) * 4.0, 0.0, 1.0);
	vec3 wash = mix(soft, wide, 0.25);
	// Pigment pools at the rims of a colour area.
	float rim = clamp(length(soft - wide) * 2.4, 0.0, 1.0);
	wash *= 1.0 - rim * 0.22;
	// Lift into paper: transparent watercolour, never opaque paint.
	wash = mix(paper, wash * paper * 1.12, 0.82);
	// Colour mood.
	wash = mix(wash, wash * mood * 1.08, mood_amount);
	// Granulation: pigment settles in the paper's tooth, more in dark washes.
	float tooth = fbm(UV * res / 3.0);
	float dark = 1.0 - luma(wash);
	wash *= 1.0 - (tooth - 0.5) * 0.22 * (0.4 + dark);
	// Blooms: a few soft water-marks where paint dried unevenly.
	float bloom = smoothstep(0.62, 0.7, fbm(UV * 3.0 + seed)) - smoothstep(0.7, 0.78, fbm(UV * 3.0 + seed));
	wash *= 1.0 - bloom * 0.08;
	// The ink, slightly broken like a dip pen.
	vec3 colour = mix(wash, vec3(0.16, 0.11, 0.09), ink * (0.75 + 0.25 * noise(UV * res / 6.0)));
	// Pencil under-drawing: faint, slightly offset strokes along strong edges.
	vec2 off = vec2(1.6, -1.1) * px;
	float e = 0.0;
	e += abs(luma(texture(TEXTURE, UV + off + vec2(px.x, 0)).rgb) - luma(texture(TEXTURE, UV + off - vec2(px.x, 0)).rgb));
	e += abs(luma(texture(TEXTURE, UV + off + vec2(0, px.y)).rgb) - luma(texture(TEXTURE, UV + off - vec2(0, px.y)).rgb));
	colour = mix(colour, graphite, clamp(e * 2.0, 0.0, 0.35) * step(0.4, noise(UV * res / 3.0)));
	// Paper grain everywhere.
	colour *= 0.95 + 0.07 * fbm(UV * res / 1.6);
	// Deckled, brushed edge: the painting thins out into bare paper.
	vec2 c = UV - 0.5;
	float edge = max(abs(c.x) * 2.0, abs(c.y) * 2.0);
	float ragged = edge + (fbm(UV * 9.0 + seed * 3.0) - 0.5) * 0.16;
	float paint = 1.0 - smoothstep(0.84, 0.97, ragged);
	colour = mix(paper, colour, paint);
	COLOR = vec4(colour, 1.0);
}
