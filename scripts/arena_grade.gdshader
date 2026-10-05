shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// Finishing overlay drawn over the 3D arena and under the HUD (see
// nepal_stage_3d.gd _grade): a soft vignette, fine film grain, the short
// punch that sells an impact and the knockout flash. It never reads the
// screen: the colour grade itself (split toning, saturation, contrast and
// the knockout's drain of colour) runs inside the renderer's own tonemap
// pass as an Environment colour correction built from the values below
// (nepal_stage_3d.gd _sync_grade), which costs almost nothing, where a
// full-screen copy and read cost ~2.5 ms a frame on integrated graphics.
//
// Colour grade values: set here by name like any parameter; the stage reads
// them back and applies them through the Environment.
uniform vec3 shadow_tint : source_color = vec3(1.0);
uniform vec3 highlight_tint : source_color = vec3(1.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float drain = 0.0;
// Kept for older callers; the overlay can't sharpen without reading the
// screen, so it is ignored.
uniform float sharpen = 0.0;
// Overlay effects.
uniform float vignette = 0.3;
uniform float grain = 0.0;
// Impact punch: a soft ring of light spreading out from the hit, fading
// with `punch` (1 at the moment of contact).
uniform float punch = 0.0;
uniform vec2 punch_center = vec2(0.5, 0.5);
uniform vec3 punch_color : source_color = vec3(1.0, 0.85, 0.6);
// Whole-screen flash (round-ending knockouts).
uniform float flash = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	// Premultiplied: the scene is kept at (1 - alpha) and rgb is added.
	vec2 centred = (uv - 0.5) * vec2(1.2, 1.0);
	float dark = vignette * smoothstep(0.42, 0.98, length(centred));
	vec3 light = vec3(0.0);
	if (punch > 0.002) {
		vec2 from_hit = uv - punch_center;
		from_hit.x *= 1.777;
		float radius = (1.0 - punch) * 0.45 + 0.05;
		float ring = exp(-pow((length(from_hit) - radius) * 14.0, 2.0)) * punch * 0.12;
		light += punch_color * ring;
	}
	if (grain > 0.001) {
		float n = fract(sin(dot(uv * 1000.0 + fract(TIME * 7.3) * 37.0, vec2(12.9898, 78.233))) * 43758.5453);
		// Grain as faint specks of shade and light.
		dark += max(0.5 - n, 0.0) * grain * 1.2;
		light += vec3(max(n - 0.5, 0.0) * grain * 0.5);
	}
	float keep = (1.0 - clamp(dark, 0.0, 1.0)) * (1.0 - flash);
	COLOR = vec4(light * (1.0 - flash) + flash_color * flash, 1.0 - keep);
}
