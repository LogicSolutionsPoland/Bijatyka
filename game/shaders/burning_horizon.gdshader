shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, fog_disabled, depth_draw_never;

uniform sampler2D zombie_fog_texture_0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D zombie_fog_texture_1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D zombie_fog_texture_2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D zombie_fog_texture_3 : source_color, filter_linear_mipmap, repeat_enable;

// Match the verified mask footprint, supplied from FlashlightVisibilityManager.
uniform vec2 oval_center_uv = vec2(0.44, 0.60);
uniform vec2 oval_radius_uv = vec2(0.29, 0.22);

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

void fragment() {
	float x = UV.x;
	float y = 1.0 - UV.y;

	// Six equal arc sectors give each 16:9 image a roughly matching world-space
	// footprint at the 10 m radius. The four supplied images cycle symmetrically.
	float sector = min(floor(x * 6.0), 5.0);
	float sector_u = fract(x * 6.0);
	float warp = (value_noise(vec2(x * 10.0 - TIME * 0.045,
		y * 6.0 + TIME * 0.025)) - 0.5) * 0.012;
	vec2 image_uv = vec2(clamp(sector_u + warp, 0.0, 1.0), y);

	vec3 image = vec3(0.0);
	if (sector < 0.5) {
		image = texture(zombie_fog_texture_0, image_uv).rgb;
	} else if (sector < 1.5) {
		image = texture(zombie_fog_texture_1, image_uv).rgb;
	} else if (sector < 2.5) {
		image = texture(zombie_fog_texture_2, image_uv).rgb;
	} else if (sector < 3.5) {
		image = texture(zombie_fog_texture_3, image_uv).rgb;
	} else if (sector < 4.5) {
		image = texture(zombie_fog_texture_2, image_uv).rgb;
	} else {
		image = texture(zombie_fog_texture_1, image_uv).rgb;
	}

	float luminance = dot(image, vec3(0.2126, 0.7152, 0.0722));
	float silhouette = 1.0 - smoothstep(0.045, 0.32, luminance);
	float haze_motion = value_noise(vec2(x * 13.0 + TIME * 0.035,
		y * 8.0 - TIME * 0.022));
	float vertical_fade = smoothstep(0.0, 0.10, y) * (1.0 - smoothstep(0.78, 1.0, y));
	float alpha = mix(0.34, 0.66, silhouette) + (haze_motion - 0.5) * 0.08;

	ALBEDO = image;
	// Only intentionally approved decorative art may show after the blackout.
	// Confine it to the actual flashlight footprint: no globally glowing ring
	// behind the player or beside the cone, and no screen-sized black quad.
	vec2 oval_uv = (SCREEN_UV - oval_center_uv) / oval_radius_uv;
	float footprint = 1.0 - smoothstep(0.94, 1.02, length(oval_uv));
	if (footprint <= 0.0) {
		discard;
	}
	ALPHA = clamp(alpha * vertical_fade, 0.0, 0.72) * footprint;
}
