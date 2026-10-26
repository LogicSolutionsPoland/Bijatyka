shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform bool use_albedo_texture = false;
uniform bool use_vertex_color = false;
uniform float hatch_density : hint_range(32.0, 160.0, 1.0) = 92.0;
uniform float hatch_strength : hint_range(0.0, 0.35, 0.01) = 0.18;
uniform float contour_strength : hint_range(0.0, 0.75, 0.01) = 0.48;
uniform float color_retention : hint_range(0.0, 1.0, 0.01) = 0.44;
uniform vec3 sketch_light_direction = vec3(-0.42, 0.82, 0.38);

varying vec3 sketch_light_direction_view;

void vertex() {
	sketch_light_direction_view = normalize((VIEW_MATRIX * vec4(sketch_light_direction, 0.0)).xyz);
}

void fragment() {
	vec4 source = albedo_tint;
	if (use_albedo_texture) {
		source *= texture(albedo_texture, UV);
	}
	if (use_vertex_color) {
		source *= COLOR;
	}

	vec3 normal = normalize(NORMAL);
	vec3 view_direction = normalize(VIEW);
	float diffuse = max(dot(normal, normalize(sketch_light_direction_view)), 0.0);
	float tone_band = diffuse < 0.20 ? 0.26
		: diffuse < 0.46 ? 0.46
		: diffuse < 0.74 ? 0.70
		: 0.94;
	float tone = 0.22 + tone_band * 0.72;

	vec2 hatch_uv = UV * hatch_density;
	float hatch_aa = max(fwidth(hatch_uv.x + hatch_uv.y) * 0.85, 0.035);
	float diagonal_a = abs(fract(hatch_uv.x + hatch_uv.y) - 0.5);
	float diagonal_b = abs(fract(hatch_uv.x - hatch_uv.y) - 0.5);
	float line_a = 1.0 - smoothstep(0.0, hatch_aa, diagonal_a);
	float line_b = 1.0 - smoothstep(0.0, hatch_aa, diagonal_b);
	float shadow_a = 1.0 - smoothstep(0.18, 0.58, diffuse);
	float shadow_b = 1.0 - smoothstep(0.04, 0.30, diffuse);
	float hatching = clamp(max(line_a * shadow_a, line_b * shadow_b), 0.0, 1.0);

	float contour = pow(1.0 - clamp(abs(dot(normal, view_direction)), 0.0, 1.0), 3.0);
	float ink_coverage = clamp(1.0 - hatching * hatch_strength - contour * contour_strength, 0.16, 1.0);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 graphite_color = mix(vec3(luminance), source.rgb, color_retention);
	ALBEDO = graphite_color * tone * ink_coverage;
}
