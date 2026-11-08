// Francisco Cidade | fcidade.com | fcidade.itch.io
// GENERATED from pencil_screen.gdshader by ferramentas/variantes_tela.py. Do not edit.
// Forward+ ONLY: creases use the normal the engine already rendered instead of rebuilding it from depth.
// It does not compile in Compatibility or Mobile; use pencil_screen_vulkan.gdshader on Mobile.
// Pencil screen pass: a pencil line drawn on the finished image wherever the depth jumps (silhouettes) or the
// surface bends (creases), wavering and breaking as a hand does, then paper: its colour, its fibres, a vignette
// of unpainted edge. It reads only the depth texture and rebuilds the surface normals from it.
// This file is for the Compatibility renderer; Forward+ and Mobile use pencil_screen_vulkan.gdshader (depth
// runs 0 to 1 there). Pencil.add_screen_pass picks the right one.
// Put it on a QuadMesh child of the camera (Pencil.add_screen_pass does it).
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;

// How the shader reads the screen and writes the result. Forward+ and Mobile keep the screen in linear light,
// so their variants convert to and from sRGB around the effect; here they are plain.
// Forward+ and Mobile keep the screen in linear light: read it as sRGB and write it back, so the effect works on
// the same values as in Compatibility.
vec3 to_srgb(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(pow(c, vec3(1.0 / 2.4)) * 1.055 - 0.055, c * 12.92, step(c, vec3(0.0031308)));
}
vec3 to_linear(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}
#define SCREEN_RGB(uv) to_srgb(texture(screen_tex, (uv)).rgb)
#define OUT_RGB(c) to_linear(c)

group_uniforms line;
// Colour of the pencil line drawn on the finished image.
uniform vec4 line_color : source_color = vec4(0.2, 0.2, 0.24, 1.0);
// Line width in pixels of the rendered image.
uniform float line_width : hint_range(0.5, 6.0) = 1.2;
// How far apart two neighbouring depths must be (as a share of the depth) to draw a silhouette line.
uniform float depth_threshold : hint_range(0.001, 0.5) = 0.04;
// How sharply the surface must bend to draw a crease line. Lower draws more lines.
uniform float crease_threshold : hint_range(0.02, 1.0) = 0.3;
// 0 draws only silhouettes, 1 silhouettes and creases.
uniform float creases : hint_range(0.0, 1.0) = 1.0;
// How far the line wavers off its place, in pixels. 0 is a ruled line.
uniform float wobble : hint_range(0.0, 8.0) = 1.5;
// How much the pencil skips and breaks along the line. 0 is unbroken.
uniform float line_roughness : hint_range(0.0, 1.0) = 0.4;
// Distance from the camera where the line starts to fade out. The fade is off while the end is not beyond the start.
uniform float fade_start = 0.0;
// Distance from the camera where the line is gone.
uniform float fade_end = 0.0;

group_uniforms paper;
// 0 turns the image grey, 1 leaves its colours, above 1 makes them stronger.
uniform float saturation : hint_range(0.0, 2.0) = 0.85;
// Below 1 flattens the image towards grey, above 1 pushes light and dark apart.
uniform float contrast : hint_range(0.5, 1.5) = 1.0;
// Colour of the paper under the picture. White leaves the image as it is.
uniform vec4 paper_color : source_color = vec4(0.97, 0.94, 0.86, 1.0);
// How much the paper colour and its fibres show through the picture.
uniform float paper_amount : hint_range(0.0, 1.0) = 0.6;
// How coarse the paper is: bigger shows larger fibres.
uniform float paper_scale : hint_range(0.2, 4.0) = 1.0;
// Fades the picture into bare paper towards the edges of the screen. 0 turns it off.
uniform float edge_fade : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

vec3 view_pos(vec2 uv, mat4 inv_proj) {
	// Forward+ and Mobile depth is already in clip space (0 to 1)
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, texture(depth_tex, uv).r, 1.0);
	return v.xyz / v.w;
}

// Surface normal as the engine rendered it (view space).
vec3 view_normal(vec2 uv, vec2 px, mat4 inv_proj) {
	return normalize(texture(normal_tex, uv).xyz * 2.0 - 1.0);
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

void fragment() {
	vec2 frag = SCREEN_UV * VIEWPORT_SIZE;
	// the line is looked up a little off its place, by a slow noise: it wavers
	vec2 shift = (vec2(value_noise(frag * 0.035), value_noise(frag * 0.035 + 17.0)) - 0.5) * 2.0 * wobble / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV + shift;
	vec2 px = line_width / VIEWPORT_SIZE;
	mat4 ip = INV_PROJECTION_MATRIX;
	vec3 p0 = view_pos(uv, ip);
	float d0 = -p0.z;
	float dx = -view_pos(uv + vec2(px.x, 0.0), ip).z;
	float dy = -view_pos(uv + vec2(0.0, px.y), ip).z;
	float silhouette = step(depth_threshold * d0, abs(dx - d0) + abs(dy - d0));
	float crease = 0.0;
	if (creases > 0.0) {
		vec3 n0 = view_normal(uv, px, ip);
		vec3 n1 = view_normal(uv + vec2(px.x, 0.0), px, ip);
		vec3 n2 = view_normal(uv + vec2(0.0, px.y), px, ip);
		crease = step(crease_threshold, (1.0 - dot(n0, n1)) + (1.0 - dot(n0, n2))) * creases;
	}
	float fade = fade_end > fade_start ? 1.0 - smoothstep(fade_start, fade_end, d0) : 1.0;
	float skip = mix(1.0, smoothstep(0.25, 0.65, value_noise(frag * 0.5)), line_roughness);
	float line = max(silhouette, crease) * fade * line_color.a * skip;

	vec3 c = SCREEN_RGB(SCREEN_UV);
	c = mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	float fibre = 0.9 + 0.1 * value_noise(frag * 0.4 / paper_scale) + 0.06 * value_noise(frag * 1.9 / paper_scale)
			+ (hash12(floor(frag)) - 0.5) * 0.05;
	c = mix(c, c * paper_color.rgb * fibre, paper_amount);
	if (edge_fade > 0.0) {
		vec2 q = abs(SCREEN_UV - 0.5) * 2.0;
		float edge = smoothstep(1.0 - edge_fade * 0.6, 1.0, max(q.x, q.y) + (value_noise(frag * 0.03) - 0.5) * 0.25 * edge_fade);
		c = mix(c, paper_color.rgb * fibre, edge);
	}
	ALBEDO = OUT_RGB(mix(c, line_color.rgb * fibre, line));
}
