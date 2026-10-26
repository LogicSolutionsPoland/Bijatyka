shader_type spatial;
render_mode cull_disabled, unshaded;

varying vec3 sketch_local_position;
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
	sketch_local_position = VERTEX;
	sketch_light_direction_view = normalize((VIEW_MATRIX * vec4(vec3(-0.42, 0.82, 0.38), 0.0)).xyz);
}

void fragment() {
	vec3 normal = normalize(NORMAL);
	float diffuse = max(dot(normal, normalize(sketch_light_direction_view)), 0.0);
	float tone_band = diffuse < 0.20 ? 0.26
		: diffuse < 0.46 ? 0.46
		: diffuse < 0.74 ? 0.70
		: 0.94;
	float tone = 0.22 + tone_band * 0.72;
	vec2 hatch_uv = sketch_local_position.xy * 34.0;
	float hatch_aa = max(fwidth(hatch_uv.x + hatch_uv.y) * 0.85, 0.05);
	float diagonal_a = abs(fract(hatch_uv.x + hatch_uv.y) - 0.5);
	float diagonal_b = abs(fract(hatch_uv.x - hatch_uv.y) - 0.5);
	float line_a = 1.0 - smoothstep(0.0, hatch_aa, diagonal_a);
	float line_b = 1.0 - smoothstep(0.0, hatch_aa, diagonal_b);
	float hatching = max(line_a * (1.0 - smoothstep(0.18, 0.58, diffuse)),
		line_b * (1.0 - smoothstep(0.04, 0.30, diffuse)));
	float contour = pow(1.0 - clamp(abs(dot(normal, normalize(VIEW))), 0.0, 1.0), 3.0);
	vec3 base = COLOR.rgb * vec3(0.92, 0.94, 0.90);
	float luminance = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 graphite = mix(vec3(luminance), base, 0.22);
	float ink = clamp(1.0 - hatching * 0.13 - contour * 0.40, 0.18, 1.0);
	ALBEDO = graphite * tone * ink;
	ROUGHNESS = 1.0;
}
