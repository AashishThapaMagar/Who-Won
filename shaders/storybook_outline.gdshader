shader_type spatial;
// The ink outline drawn around a model: its back faces pushed outwards a
// few pixels on screen and painted in ink, so only the rim shows past the
// model. Line width wavers slightly along the model, like a pen.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec3 ink : source_color = vec3(0.16, 0.11, 0.09);
// Width in pixels at 720p (scaled with the screen).
uniform float width = 2.2;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	if (length(dir) > 0.0001) {
		dir = normalize(dir);
	}
	float pen = 0.75 + 0.5 * hash(floor(VERTEX * 40.0));
	vec2 px = width * pen * 2.0 / VIEWPORT_SIZE * (VIEWPORT_SIZE.y / 720.0);
	clip.xy += dir * px * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink;
}
