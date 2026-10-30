shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

// Thin cross-sections make the shaft visible when the third-person camera
// looks straight down the beam. Each fragment still depth-tests against walls.
uniform vec3 beam_color : source_color = vec3(0.61, 0.80, 1.0);
uniform float section_opacity = 0.16;
uniform float beam_range = 30.0;
uniform float fade_end_start = 24.0;

varying vec2 radial_uv;
varying float axial_distance;

void vertex() {
	radial_uv = UV * 2.0 - 1.0;
	axial_distance = -VERTEX.z;
}

void fragment() {
	float radial = length(radial_uv);
	float edge = 1.0 - smoothstep(0.78, 1.0, radial);
	float core = 1.0 - smoothstep(0.0, 0.65, radial);
	float radial_weight = edge * (0.35 + 0.65 * core);
	float start_fade = smoothstep(0.5, 2.2, axial_distance);
	float end_fade = 1.0 - smoothstep(fade_end_start, beam_range, axial_distance);
	ALBEDO = beam_color;
	ALPHA = section_opacity * radial_weight * start_fade * end_fade;
}
