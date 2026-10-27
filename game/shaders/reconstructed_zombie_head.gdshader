shader_type spatial;
// This is a second, head-only pass over the existing fully skinned mesh.
// No source-model body geometry is displayed; the target UVs are not reused.
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D front_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D back_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform int head_bone = -1;
uniform vec3 head_center = vec3(0.0);
uniform vec3 head_half_span = vec3(0.25);

varying float head_influence;
varying vec3 projection_position;
varying vec3 rest_normal;

void vertex() {
	head_influence = 0.0;
	for (int i = 0; i < 4; i++) {
		if (int(BONE_INDICES[i]) == head_bone) {
			head_influence += BONE_WEIGHTS[i];
		}
	}
	projection_position = (VERTEX - head_center) / max(head_half_span, vec3(0.05));
	rest_normal = NORMAL;
}

void fragment() {
	float coverage = smoothstep(0.20, 0.85, head_influence);
	if (coverage < 0.01) {
		discard;
	}
	// Face-aligned planar projection; source and target GLBs have different UVs.
	vec2 face_uv = clamp(vec2(0.5 + 0.49 * projection_position.x,
		0.5 - 0.49 * projection_position.y), vec2(0.01), vec2(0.99));
	vec2 back_uv = vec2(1.0 - face_uv.x, face_uv.y);
	float facing_front = smoothstep(-0.10, 0.10, normalize(rest_normal).z);
	vec4 source_color = mix(texture(back_texture, back_uv),
		texture(front_texture, face_uv), facing_front);
	ALBEDO = source_color.rgb;
	ROUGHNESS = 0.93;
	METALLIC = 0.0;
	ALPHA = coverage * source_color.a;
}
