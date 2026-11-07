shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D zombie_group_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float silhouette_opacity : hint_range(0.0, 1.0) = 0.40;
uniform float animation_time_scale : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	// Keep the detailed cutout recognizable while giving the group a barely
	// perceptible stagger and breathing motion at the flashlight boundary.
	float effect_time = TIME * animation_time_scale;
	vec2 uv = UV;
	float sway = sin(effect_time * 0.72 + UV.y * 4.6 + UV.x * 2.3);
	uv.x += sway * 0.004;
	uv.y += sin(effect_time * 1.65 + UV.x * 5.2 + UV.y * 2.0) * 0.0015;

	vec4 zombie_group = texture(zombie_group_texture, uv);
	float cutout = smoothstep(0.015, 0.085, zombie_group.a);
	ALBEDO = zombie_group.rgb;
	ALPHA = cutout * silhouette_opacity;
}
