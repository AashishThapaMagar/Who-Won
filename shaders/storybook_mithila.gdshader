shader_type canvas_item;
// The Mithila (Janakpur) finish for a baked storybook picture
// (tools/bake_story_plates.gd, "style": "mithila"): the inked render
// repainted in the flat, bright colours of Mithila painting, every shape
// edged in a bold black line with a thinner second line inside it, the
// colours filled with dots, stripes and hatching, a painted border of
// lotus petals and triangles, all on fibrous lokta paper. Bake-time only.

uniform vec3 lokta : source_color = vec3(0.93, 0.86, 0.72);
uniform vec3 ink : source_color = vec3(0.10, 0.07, 0.06);
uniform float seed = 1.0;
// Width of the painted border, as a fraction of the picture's height.
uniform float border = 0.075;
// Frame only: the picture inside (already finished, e.g. as a watercolour)
// is kept and only warmed toward the Mithila palette; the border and paper
// are added around it.
uniform bool frame_only = false;

const int COLOURS = 10;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}

vec3 palette(int i) {
	if (i == 0) return vec3(0.78, 0.18, 0.15);   // sindur vermilion
	if (i == 1) return vec3(0.91, 0.70, 0.18);   // turmeric yellow
	if (i == 2) return vec3(0.30, 0.54, 0.24);   // leaf green
	if (i == 3) return vec3(0.17, 0.27, 0.52);   // indigo
	if (i == 4) return vec3(0.82, 0.31, 0.47);   // rani pink
	if (i == 5) return vec3(0.87, 0.58, 0.36);   // skin ochre
	if (i == 6) return vec3(0.47, 0.67, 0.80);   // sky blue
	if (i == 7) return vec3(0.52, 0.30, 0.17);   // earth brown
	if (i == 8) return vec3(0.93, 0.86, 0.72);   // bare paper
	return vec3(0.12, 0.09, 0.08);               // black
}

// The palette colour a spot of the render is painted in (the scene is
// already in flat palette colours, shaders/storybook_flat.gdshader; the
// sky and anything else unmatched goes to the nearest).
int nearest(vec3 c) {
	int best = 8;
	float best_d = 1e9;
	for (int i = 0; i < COLOURS; i++) {
		vec3 d = c - palette(i);
		float dist = dot(d, d);
		if (dist < best_d) { best_d = dist; best = i; }
	}
	return best;
}

// The colour most of the spot's neighbourhood is painted in, so specks and
// slivers fill in with the shape around them like a painter's fill.
int paint_index(sampler2D tex, vec2 uv, vec2 px) {
	int votes[COLOURS];
	for (int i = 0; i < COLOURS; i++) votes[i] = 0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			votes[nearest(texture(tex, uv + vec2(float(x), float(y)) * px * 3.0).rgb)] += 1;
		}
	}
	int best = 8;
	for (int i = 0; i < COLOURS; i++) {
		if (votes[i] > votes[best]) best = i;
	}
	return best;
}

// Is there a change of colour within radius r of this spot?
float boundary(sampler2D tex, vec2 uv, vec2 px, float r, int here) {
	float hit = 0.0;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398;
		vec2 o = vec2(cos(a), sin(a)) * px * r;
		if (paint_index(tex, uv + o, px) != here) hit = 1.0;
	}
	return hit;
}

// The fill pattern laid inside each colour.
float pattern(int i, vec2 p) {
	if (i == 1) {
		// Turmeric: little dots in rows.
		vec2 g = fract(p / 11.0) - 0.5;
		return step(length(g), 0.16);
	}
	if (i == 2) {
		// Leaf green: fine stripes, like leaf veins.
		return step(0.82, fract((p.x + p.y * 0.4) / 7.0));
	}
	if (i == 3) {
		// Indigo: cross-hatching.
		return max(step(0.86, fract((p.x + p.y) / 8.0)), step(0.86, fract((p.x - p.y) / 8.0)));
	}
	if (i == 0 || i == 4) {
		// Vermilion and pink: small rings.
		vec2 g = fract(p / 14.0) - 0.5;
		float r = length(g);
		return step(0.18, r) * step(r, 0.24);
	}
	if (i == 7) {
		// Earth: short dashes.
		vec2 g = fract(p / vec2(12.0, 8.0));
		return step(0.55, g.x) * step(g.x, 0.9) * step(0.45, g.y) * step(g.y, 0.6);
	}
	return 0.0;
}

// Lokta paper: a warm sheet with long fibres running through it.
vec3 paper(vec2 p) {
	vec3 c = lokta * (0.95 + 0.06 * fbm(p * 0.02));
	float fibre = 0.0;
	for (int k = 0; k < 3; k++) {
		float a = hash(vec2(float(k), seed)) * 3.14159;
		vec2 dir = vec2(cos(a), sin(a));
		float along = dot(p, dir) * 0.012;
		float across = dot(p, vec2(-dir.y, dir.x)) * 0.6;
		fibre += smoothstep(0.92, 1.0, noise(vec2(along, across + float(k) * 13.0)));
	}
	return c * (1.0 - fibre * 0.12);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 res = 1.0 / px;
	vec2 p = UV * res;
	// The painted border around the picture.
	float b = border;
	vec2 edge_uv = vec2(min(UV.x, 1.0 - UV.x) * res.x / res.y, min(UV.y, 1.0 - UV.y));
	float inset = min(edge_uv.x, edge_uv.y);
	if (inset < b) {
		vec3 c = paper(p);
		float t = inset / b;
		// Along the border: distance along whichever edge is nearest.
		float along = (edge_uv.x < edge_uv.y ? UV.y * res.y : UV.x * res.x);
		float cell = res.y * b * 0.55;
		float u = fract(along / cell);
		if (t < 0.12 || (t > 0.5 && t < 0.56) || t > 0.94) {
			c = palette(9);
		} else if (t < 0.5) {
			// Outer band: triangles, vermilion and turmeric in turn.
			float k = (t - 0.12) / 0.38;
			bool tri = abs(u - 0.5) * 2.0 < 1.0 - k;
			c = tri ? palette(int(mod(floor(along / cell), 2.0)) == 0 ? 0 : 1) : palette(2);
			if (abs(abs(u - 0.5) * 2.0 - (1.0 - k)) < 0.06) c = palette(9);
		} else {
			// Inner band: lotus petals on indigo.
			float k = (t - 0.56) / 0.38;
			vec2 q = vec2((u - 0.5) * 2.0, k * 2.0 - 1.0);
			float petal = length(q * vec2(1.0, 1.4)) - 0.85;
			c = petal < 0.0 ? palette(4) : palette(3);
			if (abs(petal) < 0.09) c = palette(9);
			if (petal < -0.45) c = palette(1);
		}
		c *= 0.94 + 0.08 * fbm(p * 0.3);
		COLOR = vec4(c, 1.0);
	} else if (frame_only) {
		vec3 c = texture(TEXTURE, UV).rgb;
		// Richer, warmer colour, nearer the painted palette.
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(vec3(l), c, 1.25);
		c = mix(c, c * vec3(1.06, 0.98, 0.88), 0.5);
		// A thin black rule where the picture meets the border.
		float rule = smoothstep(b + 0.004, b + 0.002, inset);
		c = mix(c, palette(9), rule);
		COLOR = vec4(c, 1.0);
	} else {
		int here = paint_index(TEXTURE, UV, px);
		// Black is for lines: a broad black area (a dark ridge, a deep
		// shadow) is painted indigo inside its outline.
		bool broad_black = here == 9 && boundary(TEXTURE, UV, px, 7.0, here) < 0.5;
		vec3 c = here == 8 ? paper(p) : palette(broad_black ? 3 : here);
		// Brush texture: colour laid by hand, a little uneven.
		c *= 0.92 + 0.12 * fbm(p * 0.08 + float(here) * 3.0);
		// Patterns stay clear of the outlines.
		float inner = 1.0 - boundary(TEXTURE, UV, px, 9.0, here);
		c = mix(c, palette(9), pattern(broad_black ? 3 : here, p) * inner * 0.85);
		// Bold outline at each change of colour, and a thinner second line
		// just inside it, with paper showing between: the Mithila double line.
		float outer = boundary(TEXTURE, UV, px, 2.0, here);
		float second = boundary(TEXTURE, UV, px, 6.5, here) * (1.0 - boundary(TEXTURE, UV, px, 5.0, here));
		if (here != 9 && here != 8) {
			float gap = boundary(TEXTURE, UV, px, 4.6, here) * (1.0 - outer);
			c = mix(c, lokta, gap * 0.85);
		}
		c = mix(c, palette(9), max(outer, second * 0.9));
		// The paper's fibres show through thin paint.
		c *= 0.96 + 0.05 * fbm(p * 0.5);
		COLOR = vec4(c, 1.0);
	}
}
