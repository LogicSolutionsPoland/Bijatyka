shader_type spatial;
// Respect opaque foreground depth: tip fog must never paint through walls.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D tip_artwork : source_color, filter_linear_mipmap, repeat_disable;
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

// Five short, hard-edged scan slices change positions together at 13 steps per second.
float fast_cut_mask(vec2 point, float frame_index) {
	float mask = 0.0;
	for (int line_index = 0; line_index < 5; line_index++) {
		float index = float(line_index);
		vec2 seed = vec2(frame_index + index * 13.17, index * 7.3 + 2.9);
		float visible = step(0.23, hash21(seed));
		float line_y = hash21(seed + vec2(17.7, 4.1));
		float half_height = mix(0.0018, 0.0065, hash21(seed + vec2(3.4, 29.1)));
		float segment_start = hash21(seed + vec2(51.2, 8.3)) * 0.72;
		float segment_length = mix(0.18, 0.60, hash21(seed + vec2(11.8, 63.5)));
		float line = 1.0 - smoothstep(half_height, half_height + 0.001, abs(point.y - line_y));
		float segment = smoothstep(segment_start, segment_start + 0.002, point.x)
			* (1.0 - smoothstep(segment_start + segment_length - 0.002,
				segment_start + segment_length, point.x));
		mask = max(mask, line * segment * visible);
	}
	return mask;
}

void fragment() {
	float effect_time = TIME * animation_time_scale;
	vec2 uv = UV;
	// A slight animated warp keeps the uploaded, already blurred figures alive.
	uv.x += sin(effect_time * 0.43 + UV.y * 4.1 + UV.x * 1.8) * 0.0035;
	uv.y += sin(effect_time * 0.31 + UV.x * 3.8 + UV.y * 2.0) * 0.0025;

	float cut_frame = floor(effect_time * 13.0);
	float cut_mask = fast_cut_mask(UV, cut_frame);
	vec2 sliced_uv = uv;
	float slice_jump = (hash21(vec2(cut_frame, 37.1)) - 0.5) * 0.018;
	sliced_uv.x += cut_mask * slice_jump;
	vec4 artwork = texture(tip_artwork, sliced_uv);
	artwork.rgb = mix(artwork.rgb, vec3(0.006, 0.008, 0.011), cut_mask * 0.92);

	vec2 moving_fog_uv = UV * vec2(8.0, 5.0) + vec2(effect_time * 0.045, -effect_time * 0.032);
	float cloud = fog_noise(moving_fog_uv);
	float edge_noise = fog_noise(UV * vec2(15.0, 11.0) + vec2(-effect_time * 0.07, effect_time * 0.05));
	float artwork_density = 0.78 + edge_noise * 0.22;
	float artwork_alpha = artwork.a * artwork_density * silhouette_opacity;

	vec2 fog_center = vec2(0.5 + sin(effect_time * 0.20) * 0.025, 0.53 + cos(effect_time * 0.27) * 0.025);
	vec2 fog_delta = (UV - fog_center) / vec2(0.53, 0.46);
	float fog_shape = 1.0 - smoothstep(0.18, 1.0, dot(fog_delta, fog_delta));
	float fog_density = smoothstep(0.13, 0.63, cloud) * fog_shape;
	float mist_alpha = fog_density * fog_opacity;

	// Draw the supplied image with its own soft transparency, then blend moving mist behind it.
	float combined_alpha = artwork_alpha + mist_alpha * (1.0 - artwork_alpha);
	vec3 fog_color = vec3(0.38, 0.37, 0.35);
	vec3 premultiplied_color = artwork.rgb * artwork_alpha
		+ fog_color * mist_alpha * (1.0 - artwork_alpha);
	ALBEDO = premultiplied_color / max(combined_alpha, 0.001);
	// The source art and moving mist must feather to a transparent oval at
	// every image border; never show the underlying quad as a rectangle.
	vec2 artwork_ellipse = (UV - vec2(0.5)) / vec2(0.5);
	float artwork_edge_fade = 1.0 - smoothstep(0.70, 1.0, length(artwork_ellipse));
	ALPHA = combined_alpha * artwork_edge_fade;
}
