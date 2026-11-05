shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, fog_disabled, depth_draw_never;

uniform sampler2D zombie_fog_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float panel_phase = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

void fragment() {
	float x = UV.x;
	float y = 1.0 - UV.y;

	// Each 40 m panel repeats its assigned 16:9 art four times without
	// stretching the silhouettes. Alternate tiles are mirrored to soften repetition.
	float tile = floor(x * 4.0);
	float tile_u = fract(x * 4.0);
	if (mod(tile + panel_phase, 2.0) > 0.5) {
		tile_u = 1.0 - tile_u;
	}
	float warp = (value_noise(vec2(x * 10.0 - TIME * 0.045 + panel_phase * 2.7,
		y * 6.0 + TIME * 0.025)) - 0.5) * 0.012;
	vec3 image = texture(zombie_fog_texture, vec2(fract(tile_u + warp), y)).rgb;
	float luminance = dot(image, vec3(0.2126, 0.7152, 0.0722));
	float silhouette = 1.0 - smoothstep(0.045, 0.32, luminance);
	float haze_motion = value_noise(vec2(x * 13.0 + TIME * 0.035 + panel_phase * 4.1,
		y * 8.0 - TIME * 0.022));

	float horizontal_fade = smoothstep(0.0, 0.025, x) * (1.0 - smoothstep(0.975, 1.0, x));
	float vertical_fade = smoothstep(0.0, 0.10, y) * (1.0 - smoothstep(0.78, 1.0, y));
	float alpha = mix(0.34, 0.66, silhouette) + (haze_motion - 0.5) * 0.08;

	ALBEDO = image;
	ALPHA = clamp(alpha * horizontal_fade * vertical_fade, 0.0, 0.72);
}
