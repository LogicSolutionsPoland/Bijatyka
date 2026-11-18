shader_type spatial;

uniform sampler2D deck_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 tower_center;
uniform float tower_width = 9.0;
varying vec2 deck_uv;
varying float top_face;

void vertex() {
	vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	deck_uv = (at.xz - tower_center) / tower_width + vec2(0.5);
	top_face = max(NORMAL.y, 0.0);
}

void fragment() {
	vec3 deck = texture(deck_albedo, deck_uv).rgb;
	ALBEDO = mix(deck * 0.50, deck, top_face);
	ROUGHNESS = 0.92;
}
