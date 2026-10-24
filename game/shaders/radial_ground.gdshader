shader_type spatial;
render_mode cull_disabled;

uniform vec3 player_position = vec3(0.0, 0.0, 0.0);
uniform vec3 floor_color : source_color = vec3(0.105, 0.118, 0.135);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (distance(world_position.xz, player_position.xz) > 30.0) {
		discard;
	}
	float radius = distance(world_position.xz, player_position.xz);
	ALBEDO = mix(floor_color, vec3(0.161, 0.105, 0.098), smoothstep(24.0, 30.0, radius));
	ROUGHNESS = 0.96;
}
