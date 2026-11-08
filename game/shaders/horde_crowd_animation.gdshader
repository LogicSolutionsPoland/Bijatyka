shader_type spatial;
render_mode cull_disabled, unshaded;

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
}

void fragment() {
	ALBEDO = COLOR.rgb * vec3(0.92, 0.94, 0.90);
	ROUGHNESS = 1.0;
}
