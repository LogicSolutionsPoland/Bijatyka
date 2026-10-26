shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform bool use_albedo_texture = false;
uniform bool use_vertex_color = false;
uniform vec3 sketch_light_direction = vec3(-0.42, 0.82, 0.38);

varying vec3 sketch_light_direction_view;

void vertex() {
	sketch_light_direction_view = normalize((VIEW_MATRIX * vec4(sketch_light_direction, 0.0)).xyz);
}

void fragment() {
	vec4 source = albedo_tint;
	if (use_albedo_texture) {
		source *= texture(albedo_texture, UV);
	}
	if (use_vertex_color) {
		source *= COLOR;
	}

	vec3 normal = normalize(NORMAL);
	float light = max(dot(normal, normalize(sketch_light_direction_view)), 0.0);
	float source_value = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float shade = clamp(0.86 - light * 0.65 + (0.48 - source_value) * 0.18, 0.0, 1.0);

	// Screen-sized strokes remain legible at the default half-resolution mobile render.
	// Crosshatching appears only in deeper shade, like repeated pencil passes.
	vec2 pencil = FRAGCOORD.xy * 0.14;
	float aa_a = max(fwidth(pencil.x + pencil.y * 0.66), 0.035);
	float aa_b = max(fwidth(pencil.x - pencil.y * 0.72), 0.035);
	float stroke_a = 1.0 - smoothstep(0.055, 0.055 + aa_a,
		abs(fract(pencil.x + pencil.y * 0.66) - 0.5));
	float stroke_b = 1.0 - smoothstep(0.055, 0.055 + aa_b,
		abs(fract(pencil.x - pencil.y * 0.72) - 0.5));
	float strokes = stroke_a * smoothstep(0.15, 0.52, shade)
		+ stroke_b * smoothstep(0.40, 0.78, shade);

	float contour = pow(1.0 - clamp(abs(dot(normal, normalize(VIEW))), 0.0, 1.0), 2.1);
	float graphite = clamp(0.06 + shade * 0.32 + (1.0 - source_value) * 0.12
		+ strokes * 0.50 + contour * 0.64, 0.0, 0.94);
	vec3 paper = vec3(0.91, 0.895, 0.86);
	vec3 lead = vec3(0.075, 0.078, 0.087);
	vec3 drawn = mix(paper, lead, graphite);
	// Only a trace of the material hue remains; magic and emissive FX keep color.
	ALBEDO = mix(drawn, drawn * (0.75 + source.rgb * 0.25), 0.07);
}
