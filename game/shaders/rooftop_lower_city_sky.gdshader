shader_type sky;

// 1536x768 rooftop photograph: a LOWER hemisphere view, not a full-sphere panorama.
uniform sampler2D lower_city_panorama : source_color, repeat_enable, filter_linear_mipmap;

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

void sky() {
	vec3 direction = normalize(EYEDIR);
	float elevation = max(direction.y, 0.0);
	vec2 projected = direction.xz / max(elevation + 0.18, 0.20);
	float cloud_low = value_noise(projected * 0.18 + vec2(TIME * 0.012, -TIME * 0.005));
	float cloud_high = value_noise(projected * 0.47 + vec2(-TIME * 0.009, TIME * 0.004));
	float smoke = smoothstep(0.49, 0.76, cloud_low * 0.68 + cloud_high * 0.32);
	float cloud_band = 1.0 - smoothstep(0.08, 0.55, elevation);

	vec3 horizon = vec3(0.105, 0.040, 0.025);
	vec3 zenith = vec3(0.020, 0.023, 0.032);
	vec3 color = mix(horizon, zenith, smoothstep(0.04, 0.82, elevation));
	color += vec3(0.052, 0.015, 0.004) * (1.0 - smoothstep(0.0, 0.37, elevation));
	color = mix(color, vec3(0.072, 0.052, 0.050), smoke * cloud_band * 0.42);
	color += vec3(0.105, 0.026, 0.004) * smoke * cloud_band * 0.33;

	float sun_alignment = dot(direction, normalize(vec3(-0.38, 0.12, -0.92)));
	float sun_halo = pow(max(sun_alignment, 0.0), 28.0);
	float sun_disc = 1.0 - smoothstep(0.99935, 0.99972, sun_alignment);
	color += vec3(0.11, 0.027, 0.003) * sun_halo;
	color += vec3(0.36, 0.075, 0.008) * sun_disc;

	// Keep the original procedural clouds/ash ABOVE the supplied lower skyline.
	vec3 upper_sky = mix(color, vec3(0.161, 0.105, 0.098), smoothstep(0.0, 0.18, -direction.y));
	float elevation_angle = asin(clamp(direction.y, -1.0, 1.0));
	// The photo's real horizon is ~45% from its top. Align that line with
	// the actual world horizon instead of stretching the picture over 180 degrees.
	float pano_v = elevation_angle >= 0.0
		? 0.45 * (1.0 - clamp(elevation_angle / 0.78539816, 0.0, 1.0))
		: 0.45 + 0.55 * clamp(-elevation_angle / 1.57079633, 0.0, 1.0);
	float pano_u = fract(0.5 + atan(direction.x, -direction.z) / 6.28318531);
	vec3 lower_city = texture(lower_city_panorama, vec2(pano_u, clamp(pano_v, 0.001, 0.999))).rgb;
	// Blend only the cloudy top edge into the upper sky; zombie-filled
	// streets remain visible looking down from the 20 m rooftop.
	float photo_weight = 1.0 - smoothstep(0.59, 0.78, elevation_angle);
	COLOR = mix(upper_sky, lower_city, photo_weight);
}
