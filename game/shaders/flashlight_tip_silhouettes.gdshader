shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, depth_test_disabled;

uniform sampler2D zombie_silhouette_mask : source_color, filter_linear_mipmap, repeat_disable;
uniform float silhouette_opacity : hint_range(0.0, 1.0) = 0.40;
uniform float fog_opacity : hint_range(0.0, 1.0) = 0.72;
uniform float animation_time_scale : hint_range(0.0, 2.0) = 1.0;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float noise21(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float fog_noise(vec2 point) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int octave = 0; octave < 3; octave++) {
		value += noise21(point) * amplitude;
		point = point * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value / 0.9625;
}

void fragment() {
	float effect_time = TIME * animation_time_scale;
	vec2 uv = UV;
	// Use only the irregular alpha contour from the art; discard its surface
	// color so the infected shapes stay silhouetted inside the drifting smoke.
	uv.x += sin(effect_time * 0.43 + UV.y * 4.1 + UV.x * 1.8) * 0.0035;
	uv.y += sin(effect_time * 0.31 + UV.x * 3.8 + UV.y * 2.0) * 0.0025;
	float source_alpha = texture(zombie_silhouette_mask, uv).a;

	vec2 moving_fog_uv = UV * vec2(8.0, 5.0) + vec2(effect_time * 0.045, -effect_time * 0.032);
	float cloud = fog_noise(moving_fog_uv);
	float edge_noise = fog_noise(UV * vec2(15.0, 11.0) + vec2(-effect_time * 0.07, effect_time * 0.05));
	float threshold = 0.16 + cloud * 0.06 + (edge_noise - 0.5) * 0.04;
	float body = smoothstep(threshold, 0.72 + cloud * 0.04, source_alpha);
	float broken_density = 0.62 + edge_noise * 0.38;
	float lower_body_fade = 1.0 - smoothstep(0.66, 1.0, UV.y);
	float silhouette_alpha = body * broken_density * lower_body_fade * silhouette_opacity;

	vec2 fog_center = vec2(0.5 + sin(effect_time * 0.20) * 0.025, 0.53 + cos(effect_time * 0.27) * 0.025);
	vec2 fog_delta = (UV - fog_center) / vec2(0.53, 0.46);
	float fog_shape = 1.0 - smoothstep(0.18, 1.0, dot(fog_delta, fog_delta));
	float fog_density = smoothstep(0.13, 0.63, cloud) * fog_shape;
	float mist_alpha = fog_density * fog_opacity;

	// Composite the smoke behind the dark, partially obscured contours.
	float combined_alpha = silhouette_alpha + mist_alpha * (1.0 - silhouette_alpha);
	vec3 fog_color = vec3(0.38, 0.37, 0.35);
	vec3 shadow_color = vec3(0.008, 0.006, 0.005);
	vec3 premultiplied_color = shadow_color * silhouette_alpha
		+ fog_color * mist_alpha * (1.0 - silhouette_alpha);
	ALBEDO = premultiplied_color / max(combined_alpha, 0.001);
	ALPHA = combined_alpha;
}
