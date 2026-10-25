shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 flashlight_origin = vec3(0.0);
uniform vec3 flashlight_forward = vec3(0.0, 0.0, -1.0);
uniform float bright_radius = 22.0;
uniform float max_radius = 30.0;
uniform float player_keep_radius = 2.1;
uniform bool flashlight_enabled = true;

void vertex() {
	// A camera-local QuadMesh spans the viewport in clip space. This single
	// transparent pass darkens the already-rendered scene after other transparents.
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

void fragment() {
	if (!flashlight_enabled) {
		discard;
	}

	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 view_position_xyz = view_position.xyz / view_position.w;
	vec3 world_position = (INV_VIEW_MATRIX * vec4(view_position_xyz, 1.0)).xyz;

	vec2 offset = world_position.xz - flashlight_origin.xz;
	float distance_to_player = length(offset);
	vec2 forward = normalize(flashlight_forward.xz);
	float signed_forward_distance = dot(offset, forward);
	// A small soft edge removes pixel crawl while keeping the ground sector at
	// 180 degrees. The player exemption keeps the third-person model readable.
	float sector_weight = smoothstep(-0.22, 0.22, signed_forward_distance);
	float fade_position = clamp((distance_to_player - bright_radius) / (max_radius - bright_radius), 0.0, 1.0);
	float range_weight = 1.0 - fade_position * fade_position * (3.0 - 2.0 * fade_position);
	float player_weight = 1.0 - smoothstep(player_keep_radius * 0.72, player_keep_radius, distance_to_player);
	float illuminated_weight = max(sector_weight * range_weight, player_weight);

	ALBEDO = vec3(0.0);
	ALPHA = 1.0 - illuminated_weight;
}
