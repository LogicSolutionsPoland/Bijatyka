shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 flashlight_origin = vec3(0.0);
uniform vec3 flashlight_forward = vec3(0.0, 0.0, -1.0);
uniform float bright_radius = 7.333333;
uniform float max_radius = 10.0;
uniform float player_keep_radius = 2.1;
uniform vec2 oval_center_uv = vec2(0.44, 0.60);
uniform vec2 oval_radius_uv = vec2(0.29, 0.22);
uniform float oval_feather = 0.055;
uniform bool flashlight_enabled = true;
uniform bool rooftop_sky_visible = false;

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
	// Compatibility may expose its clear sky depth as zero. Neither extreme
	// represents a foreground surface after the pencil pass stops writing depth.
	bool sky_depth = depth <= 0.000001 || depth >= 0.999999;
	// The depth-tested beam meshes render after this mask. Leave the rooftop
	// panorama alone; the translucent shaft tints only the air it occupies.
	if (rooftop_sky_visible && sky_depth) {
		discard;
	}
	float illuminated_weight = 0.0;
	if (!sky_depth) {
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
		// The camera-following oval limits the visible scene to the reference
		// footprint. Keep the existing world range and facing as further limits.
		vec2 oval_uv = (SCREEN_UV - oval_center_uv) / oval_radius_uv;
		float oval_weight = 1.0 - smoothstep(1.0 - oval_feather, 1.0, length(oval_uv));
		// The third-person character crosses the oval edge. The original height
		// exemption accidentally lit nearby tall elevator/tower posts OUTSIDE
		// the flashlight footprint. Keep it only within the known player
		// framing region, not across the full viewport at any world height.
		// Foundation's camera contract projects the player at x ~0.41 and feet
		// at y ~0.88 for supported viewport shapes.
		vec2 player_screen = (SCREEN_UV - vec2(0.412, 0.665)) / vec2(0.105, 0.265);
		float player_screen_weight = 1.0 - smoothstep(0.82, 1.0, length(player_screen));
		float player_weight = (1.0 - smoothstep(player_keep_radius * 0.72, player_keep_radius, distance_to_player))
			* smoothstep(0.005, 0.08, world_position.y - flashlight_origin.y)
			* player_screen_weight;
		illuminated_weight = max(sector_weight * range_weight * oval_weight, player_weight);
	}
	// This pass only applies the existing surface visibility footprint. The
	// air beam is made by a handful of depth-tested quads, without marching
	// eight samples for every screen pixel on a hot mobile GPU.
	// A fully illuminated fragment has exactly zero blackout alpha. Skip its
	// blend without changing the soft boundary or the player exemption.
	if (illuminated_weight >= 1.0) {
		discard;
	}
	ALBEDO = vec3(0.0);
	ALPHA = 1.0 - illuminated_weight;
}
