shader_type canvas_item;
render_mode blend_mix;

uniform float silhouette_opacity : hint_range(0.0, 1.0) = 0.40;
uniform float animation_time_scale : hint_range(0.0, 2.0) = 1.0;
uniform vec3 silhouette_color : source_color = vec3(0.53, 0.60, 0.68);
uniform vec3 fog_color : source_color = vec3(0.50, 0.58, 0.68);

float sd_segment(vec2 point, vec2 start, vec2 finish, float radius) {
	vec2 segment = finish - start;
	float projection = clamp(dot(point - start, segment) / max(dot(segment, segment), 0.0001), 0.0, 1.0);
	return length(point - start - segment * projection) - radius;
}

float edge_mask(float distance_value) {
	float feather = max(fwidth(distance_value) * 0.7, 0.0015);
	return 1.0 - smoothstep(-feather, feather, distance_value);
}

float zombie_shape(vec2 uv, float center_x, float height, float phase) {
	float time = TIME * animation_time_scale;
	float stride = sin(time * 2.1 + phase);
	float sway = sin(time * 1.15 + phase) * 0.045;
	float bob = sin(time * 2.8 + phase) * 0.012;
	vec2 point = vec2((uv.x - center_x) / height, (0.91 - uv.y - bob) / height);

	float head = length(point - vec2(sway * 0.45, 0.79)) - 0.095;
	float torso = sd_segment(point, vec2(sway * 0.35, 0.68), vec2(-0.035 + sway, 0.34), 0.105);
	float left_arm = sd_segment(point, vec2(-0.015 + sway, 0.62), vec2(-0.24 + sway - stride * 0.055, 0.39), 0.052);
	float right_arm = sd_segment(point, vec2(0.01 + sway, 0.61), vec2(0.21 + sway + stride * 0.055, 0.42), 0.052);
	float left_leg = sd_segment(point, vec2(-0.025 + sway, 0.35), vec2(-0.13 + stride * 0.11, 0.035), 0.058);
	float right_leg = sd_segment(point, vec2(0.005 + sway, 0.35), vec2(0.12 - stride * 0.11, 0.035), 0.058);
	float shape_distance = min(head, min(torso, min(left_arm, min(right_arm, min(left_leg, right_leg)))));
	return edge_mask(shape_distance);
}

float mist_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(cell + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

void fragment() {
	vec2 uv = UV;
	float effect_time = TIME * animation_time_scale;
	float drift = sin(effect_time * 0.48) * 0.018;
	float rear = zombie_shape(uv, 0.29 + drift, 0.73, 1.1);
	float center = zombie_shape(uv, 0.51 - drift * 0.6, 0.88, 3.0);
	float near = zombie_shape(uv, 0.73 + drift * 0.8, 0.68, 4.7);
	float silhouettes = max(rear, max(center, near));

	vec2 fog_center = vec2(0.5 + sin(effect_time * 0.33) * 0.035, 0.55 + cos(effect_time * 0.41) * 0.025);
	vec2 fog_delta = (uv - fog_center) / vec2(0.49, 0.45);
	float fog_shape = 1.0 - smoothstep(0.22, 1.0, dot(fog_delta, fog_delta));
	float fog_motion = 0.72 + mist_noise(uv * vec2(10.0, 7.0) + vec2(effect_time * 0.18, -effect_time * 0.11)) * 0.28;
	float fog_alpha = fog_shape * fog_motion * 0.12;

	vec3 color = mix(fog_color, silhouette_color, silhouettes);
	float alpha = max(fog_alpha, silhouettes * silhouette_opacity);
	COLOR = vec4(color, alpha);
}
