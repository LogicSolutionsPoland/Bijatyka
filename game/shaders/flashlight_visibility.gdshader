shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 flashlight_origin = vec3(0.0);
uniform vec3 flashlight_forward = vec3(0.0, 0.0, -1.0);
uniform vec3 beam_origin = vec3(0.0);
uniform vec3 beam_forward = vec3(0.0, 0.0, -1.0);
uniform float bright_radius = 22.0;
uniform float max_radius = 30.0;
uniform float player_keep_radius = 2.1;
uniform vec2 oval_center_uv = vec2(0.44, 0.60);
uniform vec2 oval_radius_uv = vec2(0.29, 0.22);
uniform float oval_feather = 0.055;
uniform bool flashlight_enabled = true;
uniform bool rooftop_sky_visible = false;

float beam_density(vec3 position) {
	vec3 offset = position - beam_origin;
	float axial = dot(offset, beam_forward);
	if (axial <= 0.0 || axial >= max_radius) {
		return 0.0;
	}
	float radius = max(0.4, axial * 0.46630766); // tan(25 degrees)
	float lateral = length(offset - beam_forward * axial);
	float edge = 1.0 - smoothstep(0.45, 1.0, lateral / radius);
	return edge * smoothstep(0.0, 2.0, axial)
		* (1.0 - smoothstep(bright_radius, max_radius, axial));
}

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
	if (rooftop_sky_visible && sky_depth) {
		// The environment sky already displays the correctly projected city
		// below the horizon and the original procedural sky overhead.
		// Do not replace it with a second full-sphere texture lookup here.
		discard;
	}
	// Integrate a few samples along the view ray, stopping at the first solid
	// surface in the depth buffer. Thus light is visible in the air ahead of
	// the player, while a wall hides the part of the shaft behind it. This is
	// one low-resolution fullscreen pass, with no fog volume or cone mesh.
	vec4 far_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 camera_world = INV_VIEW_MATRIX[3].xyz;
	vec3 ray_direction = normalize((INV_VIEW_MATRIX * vec4(far_view.xyz / far_view.w, 0.0)).xyz);
	float ray_end = max_radius + 6.0;
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
		ray_end = min(length(world_position - camera_world), ray_end);

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
		// The third-person character crosses the oval edge. Exempt its raised
		// geometry without leaving a bright disc on the floor underneath it.
		float player_weight = (1.0 - smoothstep(player_keep_radius * 0.72, player_keep_radius, distance_to_player))
			* smoothstep(0.005, 0.08, world_position.y - flashlight_origin.y);
		illuminated_weight = max(sector_weight * range_weight * oval_weight, player_weight);
	}
	float integrated_density = 0.0;
	for (int sample_index = 0; sample_index < 8; sample_index++) {
		float travel = ray_end * (float(sample_index) + 0.5) / 8.0;
		integrated_density += beam_density(camera_world + ray_direction * travel);
	}
	float air_glow = min(integrated_density * ray_end * 0.012 / 8.0, 0.22);
	ALPHA = 1.0 - illuminated_weight * (1.0 - air_glow);
	ALBEDO = vec3(0.72, 0.80, 0.92) * air_glow / max(ALPHA, 0.001);
}
