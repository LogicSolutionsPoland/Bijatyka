// Francisco Cidade | fcidade.com | fcidade.itch.io
// Pencil: washed colour like watercolour on paper, with the shade drawn in graphite hatching that wavers
// and breaks as a hand does. The lines can be laid on the screen or stuck to the surfaces. Light is read
// from the lights of the scene; nothing is baked.
// Pair it with pencil_outline.gdshader as `next_pass`.
shader_type spatial;
render_mode ambient_light_disabled;

group_uniforms surface;
// Base colour. Multiplies the texture.
uniform vec4 albedo : source_color = vec4(1.0);
// The picture of the surface, multiplied by the colour. Without one the surface is plain white.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
// How many times the picture repeats over the surface, across and down.
uniform vec2 uv_scale = vec2(1.0);
// Slides the picture over the surface, as a share of its size.
uniform vec2 uv_offset = vec2(0.0);
// Multiply the colour by the mesh's vertex colours.
uniform bool use_vertex_color = false;
// Light added to the surface whether or not any reaches it.
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);

group_uniforms wash;
// How much the colour is thinned like a watercolour wash: 0 keeps it, 1 pales it towards the paper tone.
uniform float wash : hint_range(0.0, 1.0) = 0.35;
// The tone the wash pales towards. A warm off-white looks like paper.
uniform vec4 wash_color : source_color = vec4(0.97, 0.94, 0.86, 1.0);
// How much the colour pools and darkens in patches, as pigment does in a wash. 0 is flat.
uniform float blotch : hint_range(0.0, 1.0) = 0.25;
// Size of the patches, in patches a metre.
uniform float blotch_scale : hint_range(0.2, 8.0) = 1.5;

group_uniforms shading;
// What the surface colour is multiplied by where it is shaded. A pale tint keeps the hatching doing the work.
uniform vec4 shadow_color : source_color = vec4(0.82, 0.8, 0.86, 1.0);
// Where the light gives way to shade, as the cosine of the angle to the light. Raise it to shrink the lit side.
uniform float light_threshold : hint_range(-0.5, 0.9) = 0.5;
// How far past the threshold the lines take to grow into solid shade. Small is graphic, large is gradual.
uniform float shade_reach : hint_range(0.05, 1.5) = 1.1;
// Cut the sun's shadows and the lamps' pools to a crisp edge, one pixel wide. Off keeps them soft.
uniform bool crisp_shadows = true;

group_uniforms graphite;
// Colour of the pencil lines. Only the sun (a directional light) draws them; other lights just light the surface.
uniform vec4 graphite_color : source_color = vec4(0.2, 0.2, 0.24, 1.0);
// How strong the pencil is: 0 draws no lines, 1 draws them at full dark.
uniform float graphite_strength : hint_range(0.0, 1.0) = 0.85;
// Where the lines are laid: Screen keeps them the same size at any distance (they stay still as the camera moves), Surface sticks them to the objects.
uniform int hatch_space : hint_enum("Screen", "Surface") = 1;
// Distance between two lines: in screen pixels for Screen, in centimetres for Surface.
uniform float hatch_spacing : hint_range(2.0, 80.0) = 9.0;
// Angle of the lines in degrees.
uniform float hatch_angle : hint_range(0.0, 180.0) = 35.0;
// Where the darkest shade gets a second set of lines across the first. 0 turns the crossing off.
uniform float crosshatch : hint_range(0.0, 1.0) = 0.5;

group_uniforms hand;
// How much the lines waver off straight, as a hand does. 0 is ruled.
uniform float waver : hint_range(0.0, 1.0) = 0.35;
// How much the pencil skips and breaks along a line, as it does on rough paper. 0 is an unbroken line.
uniform float roughness : hint_range(0.0, 1.0) = 0.5;

group_uniforms rim;
// Strength of a pale rim of light round the silhouette. 0 turns it off.
uniform float rim : hint_range(0.0, 1.0) = 0.0;
// Colour of the rim of light.
uniform vec4 rim_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
// How far in from the silhouette the rim reaches.
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	UV = UV * uv_scale + uv_offset;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise, 0 to 1.
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

float rim_amount(vec3 normal, vec3 view) {
	float facing = 1.0 - clamp(dot(normal, view), 0.0, 1.0);
	return smoothstep(1.0 - rim_width, 1.0 - rim_width + 0.04, facing) * rim;
}

void fragment() {
	vec4 c = albedo * texture(albedo_texture, UV);
	if (use_vertex_color) {
		c *= COLOR;
	}
	vec3 col = mix(c.rgb, wash_color.rgb * mix(vec3(1.0), c.rgb, 0.35), wash);
	// pigment pooling: patches of the wash that dry darker
	float patch_ = value_noise(world_pos.xz * blotch_scale + world_pos.y * blotch_scale * 0.7) * 0.6
			+ value_noise(world_pos.zy * blotch_scale * 2.3) * 0.4;
	col *= 1.0 - blotch * 0.35 * patch_;
	ALBEDO = col;
	EMISSION = col * shadow_color.rgb + emission.rgb;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}

// Light's reach, cut to on or off at a one-pixel edge.
float crisp(float a, bool directional) {
	float at = directional ? 0.5 : 0.04;
	float w = max(fwidth(a), 0.0005);
	return smoothstep(at - w, at + w, a);
}

vec2 rotate(vec2 p, float degrees) {
	float a = radians(degrees);
	return vec2(cos(a) * p.x - sin(a) * p.y, sin(a) * p.x + cos(a) * p.y);
}

// 2D coordinates to lay the lines on: the screen, or the plane of the surface the point lies on.
vec2 hatch_coords(vec2 frag, vec3 wp, vec3 wn) {
	if (hatch_space == 0) {
		return frag / hatch_spacing;
	}
	vec3 a = abs(wn);
	vec2 plane = a.y >= a.x && a.y >= a.z ? wp.xz : (a.x >= a.z ? wp.zy : wp.xy);
	return plane * 100.0 / hatch_spacing;
}

// How dark one set of lines is here: 0 paper, 1 full graphite. `shade` makes the lines thicker; the noise wavers and breaks them.
float lines(vec2 p, float angle, float shade) {
	vec2 q = rotate(p, angle);
	q.x += (value_noise(q * 0.6) - 0.5) * 2.2 * waver;
	float across = abs(fract(q.x) * 2.0 - 1.0);
	float edge = max(fwidth(q.x) * 2.0, 0.08);
	float line = 1.0 - smoothstep(shade - edge, shade + edge, across);
	float skip = value_noise(vec2(q.y * 0.9, floor(q.x) * 7.3));
	float pressure = mix(1.0, smoothstep(0.15, 0.7, skip + (1.0 - roughness) * 0.6), roughness);
	return line * pressure;
}

float hatching(vec2 p, float shade) {
	float ink = lines(p, hatch_angle, shade);
	if (crosshatch > 0.0) {
		float cross_shade = clamp((shade - (1.0 - crosshatch)) / max(crosshatch, 0.001), 0.0, 1.0);
		ink = max(ink, lines(p, hatch_angle + 70.0, cross_shade) * step(0.001, cross_shade));
	}
	return ink * step(0.001, shade);
}

void light() {
	float reach = crisp_shadows ? crisp(ATTENUATION, LIGHT_IS_DIRECTIONAL) : ATTENUATION;
	float facing = dot(NORMAL, LIGHT);
	float shade = clamp((light_threshold - facing) / shade_reach, 0.0, 1.0);
	shade = max(shade, 1.0 - reach);
	float ink = hatching(hatch_coords(FRAGCOORD.xy, world_pos, world_normal), shade) * graphite_strength;
	float solid = step(0.999, shade);
	vec3 energy = LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += energy * (1.0 - solid) * (vec3(1.0) - shadow_color.rgb);
	if (LIGHT_IS_DIRECTIONAL) {
		// the pencil is drawn by the sun: it pulls the colour already here towards graphite
		vec3 base = ALBEDO * mix(vec3(1.0), shadow_color.rgb, solid);
		SPECULAR_LIGHT += (graphite_color.rgb - base) * ink;
	}
	if (rim > 0.0) {
		SPECULAR_LIGHT += energy * rim_color.rgb * rim_amount(NORMAL, VIEW) * (1.0 - solid);
	}
}
