shader_type spatial;
render_mode cull_disabled, unshaded;

varying vec3 sketch_light_direction_view;

void vertex() {
	float phase = COLOR.a * TAU;
	float speed = 2.0 + fract(COLOR.r * 13.0) * 0.7;
	float swing = sin(TIME * speed + phase);
	float part = UV.x;
	if (part > 0.5 && part < 1.5) {
		float side = sign(VERTEX.x);
		vec2 pivot = vec2(side * 0.52, 1.56);
		float angle = swing * 0.34 * side;
		vec2 relative = VERTEX.xy - pivot;
		vec2 rotated = vec2(cos(angle) * relative.x - sin(angle) * relative.y, sin(angle) * relative.x + cos(angle) * relative.y);
		VERTEX.xy = pivot + rotated;
	} else if (part > 1.5 && part < 2.5) {
		float side = sign(VERTEX.x);
		vec2 pivot = vec2(side * 0.21, 0.86);
		float angle = sin(TIME * speed + phase + (side * 1.7)) * 0.42;
		vec2 relative = VERTEX.xy - pivot;
		vec2 rotated = vec2(cos(angle) * relative.x - sin(angle) * relative.y, sin(angle) * relative.x + cos(angle) * relative.y);
		VERTEX.xy = pivot + rotated;
	} else if (part < 0.5) {
	VERTEX.x += swing * 0.025;
	VERTEX.y += abs(swing) * 0.025;
	}
	sketch_light_direction_view = normalize((VIEW_MATRIX * vec4(vec3(-0.42, 0.82, 0.38), 0.0)).xyz);
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	float diffuse = max(dot(normal, normalize(sketch_light_direction_view)), 0.0);
	float shade = clamp(0.68 - diffuse * 0.44, 0.0, 1.0);
	vec2 pencil = FRAGCOORD.xy * 0.14;
	float line_a = 1.0 - smoothstep(0.055, 0.21,
		abs(fract(pencil.x + pencil.y * 0.66) - 0.5));
	float line_b = 1.0 - smoothstep(0.055, 0.21,
		abs(fract(pencil.x - pencil.y * 0.72) - 0.5));
	float hatching = line_a * smoothstep(0.30, 0.65, shade)
		+ line_b * smoothstep(0.65, 0.90, shade);
	float contour = pow(1.0 - clamp(abs(dot(normal, normalize(VIEW))), 0.0, 1.0), 2.1);
	float ink = clamp(0.08 + shade * 0.34 + hatching * 0.30
		+ contour * 0.58, 0.0, 0.94);
	ALBEDO = mix(vec3(0.91, 0.895, 0.86), vec3(0.075, 0.078, 0.087), ink);
	ROUGHNESS = 1.0;
}
