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
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	if (!flashlight_enabled) {
		discard;
	}

	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	// Uncovered sky has no depth and must be black in the flashlight mode.
	// Skip two inverse matrix transforms for those fullscreen pixels.
	if (depth >= 0.999999) {
		ALBEDO = vec3(0.0);
		ALPHA = 1.0;
	} else {
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#endif
		vec4 view_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		vec3 view_position_xyz = view_position.xyz / view_position.w;
		vec3 world_position = (INV_VIEW_MATRIX * vec4(view_position_xyz, 1.0)).xyz;

		vec2 offset = world_position.xz - flashlight_origin.xz;
		float distance_to_player = length(offset);
		// The CPU supplies a unit-length, horizontal camera direction.
		float signed_forward_distance = dot(offset, flashlight_forward.xz);
		// A small soft edge removes pixel crawl while keeping the ground sector at
		// 180 degrees. The player exemption keeps the third-person model readable.
		float sector_weight = smoothstep(-0.22, 0.22, signed_forward_distance);
		float fade_position = clamp((distance_to_player - bright_radius) / (max_radius - bright_radius), 0.0, 1.0);
		float range_weight = 1.0 - fade_position * fade_position * (3.0 - 2.0 * fade_position);
		float player_weight = 1.0 - smoothstep(player_keep_radius * 0.72, player_keep_radius, distance_to_player);
		float illuminated_weight = max(sector_weight * range_weight, player_weight);

		// Use the existing fullscreen flashlight pass for graphite silhouettes.
		// A second depth difference rejects the smooth slope of the ground and
		// responds to object boundaries without another draw or mesh shell.
		float edge_ink = 0.0;
		if (illuminated_weight > 0.08) {
			vec2 pixel = 1.5 / vec2(textureSize(depth_texture, 0));
			float left_depth = textureLod(depth_texture, SCREEN_UV - vec2(pixel.x, 0.0), 0.0).r;
			float right_depth = textureLod(depth_texture, SCREEN_UV + vec2(pixel.x, 0.0), 0.0).r;
			float up_depth = textureLod(depth_texture, SCREEN_UV - vec2(0.0, pixel.y), 0.0).r;
			float down_depth = textureLod(depth_texture, SCREEN_UV + vec2(0.0, pixel.y), 0.0).r;
			float difference = max(abs(left_depth + right_depth - 2.0 * depth),
				abs(up_depth + down_depth - 2.0 * depth));
			float threshold = max(0.00002, (1.0 - depth) * 0.025);
			edge_ink = smoothstep(threshold, threshold * 3.0, difference) * 0.82;
		}
		ALBEDO = vec3(0.0);
		ALPHA = max(1.0 - illuminated_weight, edge_ink * illuminated_weight);
	}
}
