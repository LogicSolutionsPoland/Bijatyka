shader_type spatial;
render_mode cull_disabled;

uniform vec3 player_position = vec3(0.0, 0.0, 0.0);
uniform vec3 floor_color : source_color = vec3(0.105, 0.118, 0.135);
uniform vec3 flashlight_forward = vec3(0.0, 0.0, -1.0);
uniform bool floor_skip_enabled = false;
uniform bool floor_fast_detail = false;
varying vec3 world_position;

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

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 ground_position = world_position.xz;
	float radius = distance(ground_position, player_position.xz);
	if (radius > 30.0) {
		discard;
	}
	// The later flashlight composite is opaque black where its sector weight
	// and player keep weight are both zero. Reject those floor fragments before
	// the noise and fracture layers; retain the soft edge and the keep area.
	if (floor_skip_enabled && radius >= 2.1
			&& dot(ground_position - player_position.xz, flashlight_forward.xz) <= -0.22) {
		discard;
	}

	float broad = value_noise(ground_position * 0.075);
	float middle = value_noise(ground_position * 0.31 + vec2(8.4, -3.7));
	// On phones, keep the two smooth ash layers and the original cracks, but
	// replace only the subtle fine grit with one cell hash. The warm stain uses
	// those same layers. This removes two full value-noise evaluations in the
	// lit floor without changing its range, base color or silhouette.
	float fine = floor_fast_detail
		? hash21(floor(ground_position * 3.2))
		: value_noise(ground_position * 3.2);
	float soot = smoothstep(0.43, 0.79, broad * 0.66 + middle * 0.34);
	float rust_noise = floor_fast_detail
		? broad * 0.62 + middle * 0.38
		: value_noise(ground_position * 0.17 + vec2(-5.2, 7.8));
	float rust = smoothstep(0.72, 0.90, rust_noise);
	vec3 concrete = floor_color * (0.74 + broad * 0.47);
	concrete += (middle - 0.5) * vec3(0.045, 0.043, 0.040);
	concrete *= 0.94 + fine * 0.13;
	vec3 color = mix(concrete, vec3(0.026, 0.029, 0.035), soot * 0.69);
	color = mix(color, vec3(0.15, 0.057, 0.030), rust * (1.0 - soot) * 0.24);

	vec2 crack_grid = ground_position * 0.34;
	vec2 cell = floor(crack_grid);
	vec2 local = fract(crack_grid);
	float shift_x = (hash21(cell + vec2(7.4, 2.1)) - 0.5) * 0.18;
	float shift_y = (hash21(cell + vec2(3.6, 9.2)) - 0.5) * 0.18;
	float crack_x = (1.0 - smoothstep(0.006, 0.026, abs(local.x - 0.5 - shift_x)))
		* step(0.34, hash21(cell + vec2(12.3, 1.8)));
	float crack_y = (1.0 - smoothstep(0.006, 0.026, abs(local.y - 0.5 - shift_y)))
		* step(0.38, hash21(cell + vec2(2.9, 14.1)));
	float cracks = max(crack_x, crack_y);
	color = mix(color, vec3(0.018, 0.019, 0.022), cracks * 0.62);

	float ember_cell = hash21(floor(ground_position * 2.0));
	float embers = step(0.994, ember_cell) * (1.0 - smoothstep(14.0, 27.0, radius));
	float haze = smoothstep(23.0, 30.0, radius);
	color = mix(color, vec3(0.161, 0.105, 0.098), haze * 0.82);

	vec2 sketch_position = ground_position * 0.72;
	float hatch_a = step(0.93, fract(sketch_position.x + sketch_position.y));
	float hatch_b = step(0.95, fract(sketch_position.x - sketch_position.y));
	float shadow_hatching = max(hatch_a, hatch_b * 0.62) * (1.0 - smoothstep(0.22, 0.72, broad));
	color *= 1.0 - shadow_hatching * 0.11;
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luminance), color, 0.38);

	ALBEDO = color;
	EMISSION = vec3(0.92, 0.19, 0.025) * embers * 0.72;
	ROUGHNESS = mix(0.86, 0.99, soot);
	METALLIC = 0.035;
}
