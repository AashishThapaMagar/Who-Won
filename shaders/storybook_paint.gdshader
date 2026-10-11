shader_type spatial;
// Storybook colouring for a model: its own colours laid on in flat washes
// (a lit tone, a shadow tone and a soft step between), the way a
// hand-coloured illustration is painted, instead of glossy 3D shading.
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_texture = true;
// Shadow colour mixed into the unlit side: warm ink, not grey.
uniform vec3 shade : source_color = vec3(0.55, 0.42, 0.40);
uniform float shade_amount = 0.45;
// Lift colours toward paper so the picture stays light.
uniform vec3 paper : source_color = vec3(0.97, 0.92, 0.80);
uniform float paper_amount = 0.12;

void fragment() {
	vec4 c = albedo;
	if (use_texture) {
		c *= texture(albedo_texture, UV);
	}
	// Fewer fine details: the wash keeps the colour, softens the texture.
	vec3 col = mix(c.rgb, vec3(dot(c.rgb, vec3(0.333))), 0.1);
	ALBEDO = mix(col, paper, paper_amount);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

void light() {
	float lambert = dot(NORMAL, LIGHT);
	// Two flat tones with a narrow soft edge between them.
	float lit = smoothstep(-0.05, 0.15, lambert) * ATTENUATION;
	vec3 shadow_tone = mix(vec3(1.0), shade, shade_amount);
	DIFFUSE_LIGHT += mix(shadow_tone, vec3(1.0), lit) * LIGHT_COLOR / PI * 0.9;
}
