shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never;

// One shared, texture-free horizon panel. The layered silhouette and smoke stay cheap on mobile.
float hash(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

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
	vec3 haze = vec3(0.161, 0.105, 0.098);
	vec3 sky = vec3(0.045, 0.038, 0.045);
	float edge = smoothstep(0.0, 0.06, x) * smoothstep(0.0, 0.06, 1.0 - x);

	float far_cell = floor(x * 15.0);
	float far_height = 0.17 + hash(far_cell + 41.0) * 0.26;
	float far_building = (1.0 - step(far_height, y)) * step(0.13, fract(x * 15.0 + 0.08));
	float near_cell = floor(x * 31.0);
	float near_height = 0.25 + hash(near_cell + 7.0) * 0.40;
	float near_building = (1.0 - step(near_height, y)) * step(0.10, fract(x * 31.0));
	float broken_face = step(0.18, hash(near_cell + floor(y * 22.0) * 37.0));
	near_building *= broken_face;
	float building = max(far_building * 0.54, near_building);

	float rows = step(0.70, fract(y * 24.0));
	float columns = step(0.67, fract(x * 138.0));
	float window_on = step(0.55, hash(floor(x * 138.0) + floor(y * 24.0) * 31.0));
	float windows = rows * columns * window_on * near_building;

	float flame_wave = sin(x * 210.0 + TIME * 2.0) * 0.024
		+ sin(x * 383.0 - TIME * 3.0) * 0.017;
	float fire_cell = step(0.61, hash(floor(x * 13.0) + 23.0));
	float fire_height = 0.16 + hash(floor(x * 64.0) + 9.0) * 0.20 + flame_wave;
	float flame = (1.0 - smoothstep(fire_height - 0.08, fire_height, y))
		* smoothstep(0.055, 0.16, y) * fire_cell;

	float smoke_noise = value_noise(vec2(x * 28.0 + TIME * 0.10, y * 9.0 - TIME * 0.07));
	float smoke_band = smoothstep(0.18, 0.34, y) * (1.0 - smoothstep(0.66, 0.94, y));
	float smoke = smoothstep(0.55, 0.80, smoke_noise) * smoke_band;

	vec3 color = mix(haze, sky, smoothstep(0.40, 0.97, y));
	color += vec3(0.095, 0.021, 0.004) * (1.0 - smoothstep(0.10, 0.48, y)) * edge;
	color = mix(color, vec3(0.022, 0.018, 0.022), far_building * edge);
	color = mix(color, vec3(0.032, 0.025, 0.028), near_building * edge);
	color += vec3(0.64, 0.15, 0.018) * windows * edge;
	color += vec3(0.045, 0.030, 0.027) * smoke * edge;
	color = mix(color, vec3(1.0, 0.22 + flame_wave, 0.015), flame * edge * 0.78);

	color = mix(haze, color, smoothstep(0.0, 0.18, y));
	color = mix(color, sky, smoothstep(0.82, 1.0, y));
	ALBEDO = color;
	float vertical_fade = smoothstep(0.0, 0.12, y) * (1.0 - smoothstep(0.72, 1.0, y));
	ALPHA = clamp(0.12 + near_building * 0.24 + far_building * 0.10 + flame * 0.16 + smoke * 0.11, 0.0, 0.56)
		* edge * vertical_fade;
}
