shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.24, 0.255, 0.27, 1.0);
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.85;
uniform float surface_metallic : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_position;
varying vec3 world_normal;

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

float fracture_lines(vec2 p) {
	vec2 grid = p * 0.30;
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	float offset_x = (hash21(cell + vec2(7.4, 2.1)) - 0.5) * 0.18;
	float offset_y = (hash21(cell + vec2(3.6, 9.2)) - 0.5) * 0.18;
	float vertical = 1.0 - smoothstep(0.006, 0.028, abs(local.x - 0.5 - offset_x));
	float horizontal = 1.0 - smoothstep(0.006, 0.028, abs(local.y - 0.5 - offset_y));
	vertical *= step(0.34, hash21(cell + vec2(12.3, 1.8)));
	horizontal *= step(0.38, hash21(cell + vec2(2.9, 14.1)));
	return max(vertical, horizontal);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 normal = normalize(world_normal);
	vec3 weights = pow(abs(normal), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.001);

	vec2 on_x = world_position.zy;
	vec2 on_y = world_position.xz;
	vec2 on_z = world_position.xy;
	float broad = value_noise(on_x * 0.15) * weights.x
		+ value_noise(on_y * 0.15) * weights.y
		+ value_noise(on_z * 0.15) * weights.z;
	float medium = value_noise(on_x * 0.72 + vec2(5.1, 1.7)) * weights.x
		+ value_noise(on_y * 0.72 + vec2(5.1, 1.7)) * weights.y
		+ value_noise(on_z * 0.72 + vec2(5.1, 1.7)) * weights.z;
	float grit = value_noise(on_x * 4.2) * weights.x
		+ value_noise(on_y * 4.2) * weights.y
		+ value_noise(on_z * 4.2) * weights.z;
	float cracks = fracture_lines(on_x) * weights.x
		+ fracture_lines(on_y) * weights.y
		+ fracture_lines(on_z) * weights.z;

	float wear = smoothstep(0.13, 0.88, broad * 0.62 + medium * 0.38);
	vec3 color = base_color.rgb * mix(0.72, 1.16, wear);
	color *= 0.91 + grit * 0.17;
	float rust_stain = smoothstep(0.68, 0.91, medium) * 0.22;
	color = mix(color, color * vec3(1.18, 0.70, 0.48), rust_stain);
	color = mix(color, base_color.rgb * 0.31, clamp(cracks, 0.0, 1.0) * 0.62);

	ALBEDO = color;
	ROUGHNESS = clamp(surface_roughness + (medium - 0.5) * 0.18, 0.58, 1.0);
	METALLIC = surface_metallic;
}
