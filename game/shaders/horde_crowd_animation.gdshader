shader_type spatial;
render_mode cull_disabled, unshaded;

uniform sampler2D body_albedo : source_color, filter_linear_mipmap, repeat_disable;
varying float shape_light;

// The crowd mesh stores its limb and skin weight in the integer part of
// its UVs. The fractional coordinates use the close zombie's clothing atlas.
void vertex() {
	float phase = COLOR.a * TAU;
	float speed = 2.0 + fract(COLOR.r * 13.0) * 0.7;
	float gait = sin(TIME * speed + phase);
	float part = floor(UV.x);
	float weight = clamp(floor(UV.y) / 7.0, 0.0, 1.0);
	UV = fract(UV);
	if (part > 0.5) {
		bool leg = part > 2.5;
		float side = leg ? (part > 3.5 ? -1.0 : 1.0) : (part > 1.5 ? -1.0 : 1.0);
		vec2 pivot = leg ? vec2(0.95, 0.0) : vec2(1.52, -0.04);
		float angle = gait * side * weight * (leg ? 0.17 : -0.12);
		mat2 turn = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
		VERTEX.yz = pivot + turn * (VERTEX.yz - pivot);
		NORMAL.yz = turn * NORMAL.yz;
	}
	VERTEX.x += gait * 0.022 * smoothstep(0.78, 1.65, VERTEX.y);
	VERTEX.y += (1.0 - abs(gait)) * 0.014;
	// Shade the surface once per vertex so the reserve's face, arms and
	// coat read in the beam without another light or draw call.
	vec3 wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	shape_light = 0.48 + 0.46 * max(dot(wn, vec3(-0.45, 0.72, 0.52)), 0.0);
}

void fragment() {
	ALBEDO = texture(body_albedo, UV).rgb * COLOR.rgb * shape_light;
}
